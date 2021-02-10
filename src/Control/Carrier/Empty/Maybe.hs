{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{- | A carrier for an 'Empty' effect, indicating failure with a 'Nothing' value. Users that need access to an error message should use the 'Control.Effect.Fail.Fail' effect.

Note that 'Empty' effects can, when they are the last effect in a stack, be interpreted directly to a 'Maybe' without a call to 'runEmpty'.

@since 1.0.0.0
-}

module Control.Carrier.Empty.Maybe
( -- * Empty carrier
  runEmpty
, evalEmpty
, execEmpty
, EmptyC(..)
  -- * Empty effect
, module Control.Effect.Empty
) where

import Control.Algebra
import Control.Effect.Empty
import Control.Monad.Catch
import Control.Monad.Fail as Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.Maybe
import Data.Functor (void)
import Data.Maybe (isJust)

-- | Run an 'Empty' effect, returning 'Nothing' for empty computations, or 'Just' the result otherwise.
--
-- @
-- 'runEmpty' 'empty' = 'pure' 'Nothing'
-- @
-- @
-- 'runEmpty' ('pure' a) = 'pure' ('Just' a)
-- @
--
-- @since 1.0.0.0
runEmpty :: EmptyC m a -> m (Maybe a)
runEmpty (EmptyC m) = runMaybeT m
{-# INLINE runEmpty #-}

-- | Run an 'Empty' effect, discarding its result.
--
-- This is convenient for using 'empty' to signal early returns without needing to know whether control exited normally or not.
--
-- @
-- 'evalEmpty' = 'void' '.' 'runEmpty'
-- @
--
-- @since 1.1.0.0
evalEmpty :: Functor m => EmptyC m a -> m ()
evalEmpty = void . runEmpty
{-# INLINE evalEmpty #-}

-- | Run an 'Empty' effect, replacing its result with a 'Bool' indicating whether control exited normally.
--
-- This is convenient for using 'empty' to signal early returns when all you need to know is whether control exited normally or not, and not what value it exited with.
--
-- @
-- 'execEmpty' = 'fmap' 'isJust' '.' 'runEmpty'
-- @
-- @
-- 'execEmpty' ('pure' a) = 'pure' 'True'
-- @
-- @
-- 'execEmpty' 'empty' = 'pure' 'False'
-- @
--
-- @since 1.1.0.0
execEmpty :: Functor m => EmptyC m a -> m Bool
execEmpty = fmap isJust . runEmpty
{-# INLINE execEmpty #-}

-- | @since 1.0.0.0
newtype EmptyC m a = EmptyC (MaybeT m a)
  deriving (Algebra (Empty :+: sig), Applicative, Functor, Monad, MonadFix, MonadIO, MonadTrans, MonadThrow, MonadMask, MonadCatch)

-- | 'EmptyC' passes 'Fail.MonadFail' operations along to the underlying monad @m@, rather than interpreting it as a synonym for 'empty' à la 'MaybeT'.
instance Fail.MonadFail m => Fail.MonadFail (EmptyC m) where
  fail = lift . Fail.fail
  {-# INLINE fail #-}
