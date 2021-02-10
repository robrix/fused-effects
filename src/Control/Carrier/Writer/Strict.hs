{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{- | A carrier for 'Writer' effects. This carrier performs its append operations strictly and thus avoids the space leaks inherent in lazy writer monads. These appends are left-associative; as such, @[]@ is a poor choice of monoid for computations that entail many calls to 'tell'. The [Seq](http://hackage.haskell.org/package/containersdocs/Data-Sequence.html) or [DList](http://hackage.haskell.org/package/dlist) monoids may be a superior choice.

This implementation is based on a post Gabriel Gonzalez made to the Haskell mailing list: <https://mail.haskell.org/pipermail/libraries/2013-March/019528.html>

@since 1.0.0.0
-}

module Control.Carrier.Writer.Strict
( -- * Writer carrier
  runWriter
, execWriter
, WriterC(WriterC)
  -- * Writer effect
, module Control.Effect.Writer
) where

import Control.Algebra
import Control.Applicative (Alternative)
import Control.Carrier.State.Strict
import Control.Effect.Writer
import Control.Monad (MonadPlus)
import Control.Monad.Catch
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class

-- | Run a 'Writer' effect with a 'Monoid'al log, producing the final log alongside the result value.
--
-- @
-- 'runWriter' ('tell' w) = 'pure' (w, ())
-- @
-- @
-- 'runWriter' ('pure' a) = 'pure' ('mempty', a)
-- @
runWriter :: Monoid w => WriterC w m a -> m (w, a)
runWriter (WriterC m) = runState mempty m
{-# INLINE runWriter #-}

-- | Run a 'Writer' effect with a 'Monoid'al log, producing the final log and discarding the result value.
--
-- @
-- 'execWriter' m = 'fmap' 'fst' ('runWriter' m)
-- @
execWriter :: (Monoid w, Functor m) => WriterC w m a -> m w
execWriter = fmap fst . runWriter
{-# INLINE execWriter #-}


-- | A space-efficient carrier for 'Writer' effects, implemented atop "Control.Carrier.State.Strict".
--
-- @since 1.0.0.0
newtype WriterC w m a = WriterC { runWriterC :: StateC w m a }
  deriving (Alternative, Applicative, Functor, Monad, Fail.MonadFail, MonadFix, MonadIO, MonadPlus, MonadTrans, MonadCatch, MonadThrow, MonadMask)

instance (Monoid w, Algebra sig m) => Algebra (Writer w :+: sig) (WriterC w m) where
  alg hdl sig ctx = WriterC $ case sig of
    L writer -> StateC $ \ w -> case writer of
      Tell w'    -> do
        let !w'' = mappend w w'
        pure (w'', ctx)
      Listen   m -> do
        (w', a) <- runWriter (hdl (m <$ ctx))
        let !w'' = mappend w w'
        pure (w'', (,) w' <$> a)
      Censor f m -> do
        (w', a) <- runWriter (hdl (m <$ ctx))
        let !w'' = mappend w (f w')
        pure (w'', a)
    R other  -> alg (runWriterC . hdl) (R other) ctx
  {-# INLINE alg #-}
