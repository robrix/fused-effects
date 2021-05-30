{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE UndecidableInstances #-}

{- | A high-performance, strict, church-encoded carrier for 'Accum'.

This carrier issues left-associated 'mappend's, meaning that 'Monoid's such as @[]@ with poor performance for left-associated 'mappend's are ill-suited for use with this carrier. Alternatives such as 'Data.Monoid.Endo', @Seq@, or @DList@ may be preferred.

-- | @since 1.1.1.1
-}

module Control.Carrier.Accum.Church
( -- * Accum carrier
  runAccum
, execAccum
, evalAccum
, AccumC(AccumC)
  -- * Accum effect
, module Control.Effect.Accum
) where

import Control.Algebra
import Control.Applicative (Alternative(..))
import Control.Effect.Accum
import Control.Monad (MonadPlus(..))
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class

-- | Run an 'Accum' effect with a 'Monoid'al log, applying a continuation to the final log and result.
--
-- @
-- 'runAccum' k w0 ('pure' a) = k 'w0' a
-- @
-- @
-- 'runAccum' k w0 ('add' w) = k (w0 <> w) ()
-- @
-- @
-- 'runAccum' k w0 ('add' w >> 'look') = k (w0 <> w) (w0 <> w)
-- @
--
-- @since 1.1.1.1
runAccum :: (w -> a -> m b) -> w -> AccumC w m a -> m b
runAccum k w ma = runAccumC ma k w
{-# INLINE runAccum #-}

-- | Run an 'Accum' effect (typically with a 'Monoid'al log),
--   producing the final log and discarding the result value.
--
-- @
-- 'execAccum' = 'runAccum' ('const' '.' 'pure')
-- @
--
-- @since 1.1.1.1
execAccum :: Applicative m => w -> AccumC w m a -> m w
execAccum = runAccum (const . pure)
{-# INLINE execAccum #-}

-- | Run an 'Accum' effect (typically with a 'Monoid'al log),
--   producing the result value and discarding the final log.
--
-- @
-- 'evalAccum' = 'runAccum' ('const' '.' 'pure')
-- @
--
-- @since 1.1.1.1
evalAccum :: Applicative m => w -> AccumC w m a -> m a
evalAccum = runAccum $ const pure
{-# INLINE evalAccum #-}

-- | @since 1.1.1.1
newtype AccumC w m a = AccumC { runAccumC :: forall r . (w -> a -> m r) -> w -> m r }

instance Monoid w => MonadTrans (AccumC w) where
  lift ma = AccumC $ \k _ -> ma >>= k mempty
  {-# INLINE lift #-}

instance Functor (AccumC w m) where
  fmap f ma = AccumC $ \k w -> runAccumC ma (\w a -> k w $ f a) w
  {-# INLINE fmap #-}

instance Monoid w => Applicative (AccumC w m) where
  pure a = AccumC $ \k _ -> k mempty a
  {-# INLINE pure #-}

  mf <*> ma = AccumC $ \k w ->
    runAccumC mf (\w' f -> runAccumC ma (\w'' a -> k (w' <> w'') $ f a) (w <> w')) w
  {-# INLINE (<*>) #-}

instance (Alternative m, Monad m, Monoid w) => Alternative (AccumC w m) where
  empty = lift empty
  {-# INLINE empty #-}

  ma1 <|> ma2 = AccumC $ \k w -> runAccumC ma1 k w <|> runAccumC ma2 k w
  {-# INLINE (<|>) #-}

instance (Monad m, Monoid w) => Monad (AccumC w m) where
  ma >>= f = AccumC $ \k w -> runAccumC ma (\w' a -> runAccumC (f a) (\w'' -> k $ w' <> w'') (w <> w')) w
  {-# INLINE (>>=) #-}

instance (MonadPlus m, Monoid w) => MonadPlus (AccumC w m) where
  mzero = lift mzero
  {-# INLINE mzero #-}

  ma1 `mplus` ma2 = AccumC $ \k w -> runAccumC ma1 k w `mplus` runAccumC ma2 k w
  {-# INLINE mplus #-}

instance (MonadFail m, Monoid w) => MonadFail (AccumC w m) where
  fail msg = AccumC $ const $ const $ Fail.fail msg
  {-# INLINE fail #-}

instance (MonadFix m, Monoid w) => MonadFix (AccumC w m) where
  mfix ma = AccumC $ \ k w -> mfix ((\accumC -> runAccumC accumC (curry pure) w) . ma . snd) >>= uncurry k
  {-# INLINE mfix #-}

instance (MonadIO m, Monoid w) => MonadIO (AccumC w m) where
  liftIO = lift . liftIO
  {-# INLINE liftIO #-}

instance (Algebra sig m, Monoid w) => Algebra (Accum w :+: sig) (AccumC w m) where
  alg hdl sig ctx = AccumC $ \k w -> case sig of
    L accum -> case accum of
      Add w' -> k w' ctx
      Look   -> k mempty $ w <$ ctx
    R other  -> thread (uncurry (runAccum (curry pure)) ~<~ hdl) other (w, ctx) >>= uncurry k
  {-# INLINE alg #-}
