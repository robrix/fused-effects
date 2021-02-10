{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

-- | Provides an 'InterpretC' carrier capable of interpreting an arbitrary effect using a passed-in higher order function to interpret that effect. This is suitable for prototyping new effects quickly.

module Control.Carrier.Interpret
( -- * Interpret carrier
  runInterpret
, runInterpretState
, InterpretC(InterpretC)
, Reifies
, Interpreter
  -- * Re-exports
, Algebra
, Has
, run
) where

import Control.Algebra
import Control.Applicative (Alternative)
import Control.Carrier.State.Strict
import Control.Monad (MonadPlus)
import Control.Monad.Catch (MonadCatch, MonadMask, MonadThrow)
import Control.Monad.IO.Unlift (MonadUnliftIO)
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Data.Functor.Const (Const(..))
import Data.Kind (Type)
import Unsafe.Coerce (unsafeCoerce)

-- | An @Interpreter@ is a function that interprets effects described by @sig@ into the carrier monad @m@.
newtype Interpreter sig m = Interpreter
  { runInterpreter :: forall ctx n s x . Functor ctx => Handler ctx n (InterpretC s sig m) -> sig n x -> ctx () -> InterpretC s sig m (ctx x) }


class Reifies s a | s -> a where
  reflect :: Const a s


data Skolem

-- | @Magic@ captures the GHC implementation detail of how single method type classes are implemented.
newtype Magic a r = Magic (Reifies Skolem a => Const r Skolem)

-- For more information on this technique, see the @reflection@ library. We use the formulation described in https://github.com/ekmett/reflection/issues/31 for better inlining.
--
-- Essentially we can view @k@ as internally a function of type @Reifies s a -> Tagged s r@, whch we can again view as just @a -> Tagged s r@ through @unsafeCoerce@. After this coercion, we just apply the function to @a@.
reify :: a -> (forall s . Reifies s a => Const r s) -> r
reify a k = unsafeCoerce (Magic k) a


-- | Interpret an effect using a higher-order function.
--
-- Note that due to the higher-rank type, you have to use either '$' or explicit application when applying this interpreter. That is, you will need to write @runInterpret f (runInterpret g myPrgram)@ or @runInterpret f $ runInterpret g $ myProgram@. If you try and write @runInterpret f . runInterpret g@, you will unfortunately get a rather scary type error!
--
-- @since 1.0.0.0
runInterpret
  :: (forall ctx n x . Functor ctx => Handler ctx n m -> eff n x -> ctx () -> m (ctx x))
  -> (forall s . Reifies s (Interpreter eff m) => InterpretC s eff m a)
  -> m a
runInterpret f m = reify (Interpreter (\ hdl sig -> InterpretC . f (runInterpretC . hdl) sig)) (go m) where
  go :: InterpretC s eff m x -> Const (m x) s
  go (InterpretC m) = Const m
{-# INLINE runInterpret #-}

-- | Interpret an effect using a higher-order function with some state variable.
--
-- @since 1.0.0.0
runInterpretState
  :: (forall ctx n x . Functor ctx => Handler ctx n (StateC s m) -> eff n x -> s -> ctx () -> m (s, ctx x))
  -> s
  -> (forall t . Reifies t (Interpreter eff (StateC s m)) => InterpretC t eff (StateC s m) a)
  -> m (s, a)
runInterpretState handler state m
  = runState state
  $ runInterpret (\ hdl sig ctx -> StateC (flip (handler hdl sig) ctx)) m
{-# INLINE runInterpretState #-}

-- | @since 1.0.0.0
newtype InterpretC s (sig :: (Type -> Type) -> (Type -> Type)) m a = InterpretC { runInterpretC :: m a }
  deriving (Alternative, Applicative, Functor, Monad, Fail.MonadFail, MonadFix, MonadIO, MonadPlus, MonadCatch, MonadMask, MonadThrow, MonadUnliftIO)

instance MonadTrans (InterpretC s sig) where
  lift = InterpretC
  {-# INLINE lift #-}

instance (Reifies s (Interpreter eff m), Algebra sig m) => Algebra (eff :+: sig) (InterpretC s eff m) where
  alg hdl = \case
    L eff   -> runInterpreter (getConst (reflect @s)) hdl eff
    R other -> InterpretC . alg (runInterpretC . hdl) other
  {-# INLINE alg #-}
