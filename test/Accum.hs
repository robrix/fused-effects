{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
module Accum
( tests
) where

import qualified Control.Carrier.Accum.Church as C.Accum.Church
import qualified Control.Carrier.Accum.Strict as C.Accum.Strict
import           Control.Effect.Accum
import qualified Control.Monad.Trans.Accum as T.Accum
import           Data.Tuple (swap)
import           Gen
import qualified Monad
import qualified MonadFix
import Data.Bifunctor (first)

tests :: TestTree
tests = testGroup "Accum"
  [ testGroup "AccumC (Church)" $
    [ testMonad
    , testMonadFix
    , testAccum
    ] >>= ($ runC (C.Accum.Church.runAccum (curry pure)))
  , testGroup "AccumC (Strict)" $
    [ testMonad
    , testMonadFix
    , testAccum
    ] >>= ($ runC C.Accum.Strict.runAccum)
  , testGroup "AccumT" $ testAccum (runC (fmap (fmap swap) . flip T.Accum.runAccumT))
  ] where
  testMonad    run = Monad.test    (m (gen0 w) (\_ _ -> [])) a b c initial run
  testMonadFix run = MonadFix.test (m (gen0 w) (\_ _ -> [])) a b   initial run
  testAccum    run = Accum.test    (m (gen0 w) (\_ _ -> [])) a     w       run
  initial = pair <*> w <*> unit

gen0
  :: forall w sig m a
  .  (Has (Accum w) sig m, Arg w, Vary w, Show w)
  => GenTerm w
  -> GenTerm a
  -> [GenTerm (m a)]
gen0 w a =
  [ infixL 4 "<$" (<$) <*> a <*> (label "add" add <*> w)
  , label "looks" (looks @w) <*> fn a
  ]

test
  :: forall w sig m a
  .  (Has (Accum w) sig m, Arg w, Eq a, Eq w, Show a, Show w, Vary w, Monoid w)
  => GenM m
  -> GenTerm a
  -> GenTerm w
  -> Run ((,) w) ((,) w) m
  -> [TestTree]
test m a w (Run runAccum) =
  [ testProperty "look returns the log variable (simple)" . forall (w :. Nil) $
    \ w -> runAccum (w, look) === Identity (mempty, w)
  , testProperty "add appends to the log variable (simple)" . forall (w :. w :. Nil) $
    \ w0 w -> runAccum (w0, add w) === Identity (w, ())
  , testProperty "look returns the log variable (continuation)" . forall (w :. fn (m a) :. Nil) $
    \ w0 k -> runAccum (w0, look >>= k) === runAccum (w0, k w0)
  , testProperty "add appends to the log variable and alters the environment for look" . forall (w :. w :. Nil) $
    \ w0 w -> runAccum (w0, add w >> look) === runAccum (w0 <> w, look @w <* add w)
  , testProperty "add appends to the log variable and alters the environment for continuations" . forall (w :. w :. m a :. Nil) $
    \ w0 w k -> runAccum (w0, add w >> k) === (first (w <>) <$> runAccum (w0 <> w, k))
  ]
