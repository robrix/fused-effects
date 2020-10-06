#!/usr/bin/env cabal exec runghc -- -package=fused-effects
{-# LANGUAGE DeriveFunctor, DeriveGeneric, FlexibleInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, TypeOperators, UndecidableInstances #-}
-- Usage: script/release.hs
-- Walks you through the release checklist
module Main (main) where

import Control.Algebra
import Control.Monad.IO.Class
import Control.Monad (join)
import Data.Foldable (traverse_)
import Data.Monoid (Last(..))
import GHC.Generics (Generic1)
import System.Process

main :: IO ()
main = runTeletype . runDry $ do
  version <- prompt "Version number (w.x.y.z format, *NOT* checked): "
  manual "Make a branch with the name `version-x.y.z.w`."
  manual "Add a heading to the top of `ChangeLog.md` for the current version."
  manual "Change the version of the package in `fused-effects.cabal`."
  manual "Push the branch to GitHub and open a draft PR. Double-check the changes, comparing against a previous release PR, e.g. https://github.com/fused-effects/fused-effects/pull/80. When satisfied, mark the PR as ready for review, and request a review from a collaborator."
  (sdist, docs) <- auto "Build and prepare candidate?" $ do
    command "cabal" ["v2-build"] >>= traverse_ writeQuoted
    let getURL = fmap join . traverse (\ s -> writeQuoted s >> pure (getLast (foldMap (Last . Just) (lines s))))
    (,)
      <$> (command "cabal" ["v2-sdist"] >>= getURL)
      <*> (command "cabal" ["v2-haddock", "--haddock-for-hackage"] >>= getURL)
  auto "Publish candidate?" $ do
    traverse_ (command "cabal" . ("upload":) . pure) sdist
    traverse_ (command "cabal" . ("upload":) . ("--documentation":) . pure) docs
  manual "Once the PR has been approved and you’re satisfied with the candidate release, merge the PR. Publish the release to Hackage by running the above commands with the addition of `--publish`."
  manual "Locally, check out `master` and pull the latest changes to your working copy. Make a new tag, e.g. `git tag x.y.z.w`."
  auto "Push tags to GitHub using `git push --tags`?" $
    command "git" ["push", "--tags"] >>= traverse_ writeQuoted
  where writeQuoted = write . unlines . map ("> " ++) . lines

manual :: Has Teletype sig m => String -> m ()
manual s = write s >> prompt "press enter to continue:" >> write ""

auto :: (Has Command sig m, Has Teletype sig m) => String -> m a -> m a
auto s m = write s >> prompt "press enter to run:" >> m <* write ""


data Command m k
  = Command String [String] (Maybe String -> m k)
  deriving (Functor, Generic1)

instance Effect Command

command :: Has Command sig m => String -> [String] -> m (Maybe String)
command cmd args = send (Command cmd args pure)


newtype LiveC m a = LiveC { runLive :: m a }
  deriving (Applicative, Functor, Monad, MonadIO)

instance (Algebra sig m, MonadIO m) => Algebra (Command :+: sig) (LiveC m) where
  alg (L (Command cmd args k)) = do
    stdout <- liftIO (readProcess cmd args "")
    k (Just stdout)
  alg (R other) = LiveC (handleCoercible other)


newtype DryC m a = DryC { runDry :: m a }
  deriving (Applicative, Functor, Monad, MonadIO)

instance Has Teletype sig m => Algebra (Command :+: sig) (DryC m) where
  alg (L (Command cmd args k)) = do
    write $ "> " ++ cmd ++ " " ++ unwords args
    k Nothing
  alg (R other) = DryC (handleCoercible other)


data Teletype m k
  = Prompt String (String -> m k)
  | Write String (m k)
  deriving (Functor, Generic1)

instance Effect Teletype

prompt :: Has Teletype sig m => String -> m String
prompt s = send (Prompt s pure)

write :: Has Teletype sig m => String -> m ()
write s = send (Write s (pure ()))


newtype TeletypeC m a = TeletypeC { runTeletype :: m a }
  deriving (Applicative, Functor, Monad, MonadIO)

instance (MonadIO m, Algebra sig m) => Algebra (Teletype :+: sig) (TeletypeC m) where
  alg (L (Prompt s k)) = liftIO (putStr s >> getLine) >>= k
  alg (L (Write  s k)) = liftIO (putStrLn s)          >>  k
  alg (R other)        = TeletypeC (handleCoercible other)
