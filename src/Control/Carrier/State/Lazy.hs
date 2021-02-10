{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{- | A carrier for the 'State' effect that refrains from evaluating its state until necessary. This is less efficient than "Control.Carrier.State.Strict" but allows some cyclic computations to terminate that would loop infinitely in a strict state carrier.

Note that the parameter order in 'runState', 'evalState', and 'execState' is reversed compared the equivalent functions provided by @transformers@. This is an intentional decision made to enable the composition of effect handlers with '.' without invoking 'flip'.

@since 1.0.0.0
-}

module Control.Carrier.State.Lazy
( -- * Lazy state carrier
  runState
, evalState
, execState
, StateC(..)
  -- * State effect
, module Control.Effect.State
) where

import Control.Algebra
import Control.Applicative (Alternative(..))
import Control.Effect.State
import Control.Monad (MonadPlus)
import Control.Monad.Catch
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.State.Lazy (StateT(..))
import Data.Tuple (swap)

-- | Run a lazy 'State' effect, yielding the result value and the final state. More programs terminate with lazy state than strict state, but injudicious use of lazy state may lead to thunk buildup.
--
-- @
-- 'runState' s ('pure' a) = 'pure' (s, a)
-- @
-- @
-- 'runState' s 'get' = 'pure' (s, s)
-- @
-- @
-- 'runState' s ('put' t) = 'pure' (t, ())
-- @
--
-- @since 1.0.0.0
runState :: s -> StateC s m a -> m (s, a)
runState s (StateC runStateC) = runStateC s
{-# INLINE[3] runState #-}

toStateT :: Monad m => StateC s m a -> StateT s m a
toStateT (StateC m) = StateT (fmap (fmap swap) m)

fromStateT :: Monad m => StateT s m a -> StateC s m a
fromStateT (StateT m) = StateC (fmap (fmap swap) m)

-- | Run a lazy 'State' effect, yielding the result value and discarding the final state.
--
-- @
-- 'evalState' s m = 'fmap' 'snd' ('runState' s m)
-- @
--
-- @since 1.0.0.0
evalState :: forall s m a . Functor m => s -> StateC s m a -> m a
evalState s = fmap snd . runState s
{-# INLINE[3] evalState #-}

-- | Run a lazy 'State' effect, yielding the final state and discarding the return value.
--
-- @
-- 'execState' s m = 'fmap' 'fst' ('runState' s m)
-- @
--
-- @since 1.0.0.0
execState :: forall s m a . Functor m => s -> StateC s m a -> m s
execState s = fmap fst . runState s
{-# INLINE[3] execState #-}

-- | @since 1.0.0.0
newtype StateC s m a = StateC (s -> m (s, a))

instance Functor m => Functor (StateC s m) where
  fmap f m = StateC $ \ s -> (\ ~(s', a) -> (s', f a)) <$> runState s m
  {-# INLINE fmap #-}

instance Monad m => Applicative (StateC s m) where
  pure a = StateC $ \ s -> pure (s, a)
  {-# INLINE pure #-}

  StateC mf <*> StateC mx = StateC $ \ s -> do
    ~(s',  f) <- mf s
    ~(s'', x) <- mx s'
    pure (s'', f x)
  {-# INLINE (<*>) #-}

  m *> k = m >>= const k
  {-# INLINE (*>) #-}

instance Monad m => Monad (StateC s m) where
  m >>= k = StateC $ \ s -> do
    ~(s', a) <- runState s m
    runState s' (k a)
  {-# INLINE (>>=) #-}

instance (Alternative m, Monad m) => Alternative (StateC s m) where
  empty = StateC (const empty)
  {-# INLINE empty #-}

  StateC l <|> StateC r = StateC (\ s -> l s <|> r s)
  {-# INLINE (<|>) #-}

instance Fail.MonadFail m => Fail.MonadFail (StateC s m) where
  fail s = StateC (const (Fail.fail s))
  {-# INLINE fail #-}

instance MonadFix m => MonadFix (StateC s m) where
  mfix f = StateC (\ s -> mfix (runState s . f . snd))
  {-# INLINE mfix #-}

instance MonadIO m => MonadIO (StateC s m) where
  liftIO io = StateC (\ s -> (,) s <$> liftIO io)
  {-# INLINE liftIO #-}

instance (Alternative m, Monad m) => MonadPlus (StateC s m)

instance MonadTrans (StateC s) where
  lift m = StateC (\ s -> (,) s <$> m)
  {-# INLINE lift #-}

instance Algebra sig m => Algebra (State s :+: sig) (StateC s m) where
  alg hdl sig ctx = StateC $ \ s -> case sig of
    L Get     -> pure (s, s <$ ctx)
    L (Put s) -> pure (s, ctx)
    R other   -> thread (uncurry runState ~<~ hdl) other (s, ctx)
  {-# INLINE alg #-}

instance MonadThrow m => MonadThrow (StateC s m) where
  throwM = fromStateT . throwM
  {-# INLINE throwM #-}

instance MonadCatch m => MonadCatch (StateC s m) where
  catch m f = fromStateT (catch (toStateT m) (toStateT . f))
  {-# INLINE catch #-}

instance MonadMask m => MonadMask (StateC s m) where
  mask f = fromStateT (mask (\restore -> toStateT (f (fromStateT . restore . toStateT))))
  {-# INLINE mask #-}

  uninterruptibleMask f = fromStateT (uninterruptibleMask (\restore -> toStateT (f (fromStateT . restore . toStateT))))
  {-# INLINE uninterruptibleMask #-}

  generalBracket acquire release inner = fromStateT (generalBracket acquire' release' inner')
    where
      acquire' = toStateT acquire
      release' = fmap (fmap toStateT) release
      inner' = fmap toStateT inner
  {-# INLINE generalBracket #-}
