{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{- | A carrier for a 'Throw' effect.

@since 1.0.0.0
-}
module Control.Carrier.Throw.Either
( -- * Throw carrier
  runThrow
, ThrowC(ThrowC)
  -- * Throw effect
, module Control.Effect.Throw
) where

import Control.Algebra
import Control.Applicative (Alternative)
import Control.Carrier.Error.Either
import Control.Effect.Throw
import Control.Monad (MonadPlus)
import Control.Monad.Catch
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class

-- | Run a 'Throw' effect, returning failures in 'Left' and successful computations’ results in 'Right'.
runThrow :: ThrowC e m a -> m (Either e a)
runThrow (ThrowC m) = runError m
{-# INLINE runThrow #-}

-- | @since 1.0.0.0
newtype ThrowC e m a = ThrowC { runThrowC :: ErrorC e m a }
  deriving (Alternative, Applicative, Functor, Monad, Fail.MonadFail, MonadFix, MonadIO, MonadPlus, MonadTrans, MonadCatch, MonadMask, MonadThrow)

instance Algebra sig m => Algebra (Throw e :+: sig) (ThrowC e m) where
  alg hdl sig ctx = case sig of
    L (Throw e) -> ThrowC (throwError e)
    R other     -> ThrowC (alg (runThrowC . hdl) (R other) ctx)
  {-# INLINE alg #-}
