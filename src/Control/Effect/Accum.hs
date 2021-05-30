{- | An effect allowing writes to an accumulated quantity alongside a computed value,
and reads from the accumulator.
An 'Accum' @w@ effect keeps track of a monoidal datum of type @w@ and strictly appends to that monoidal value with the 'add' effect.
Previous writes to that value can be read with the 'look' effect.

Predefined carriers:

* "Control.Carrier.Accum.Church"
* "Control.Carrier.Accum.Strict". (A lazy carrier is not provided due to the inherent space leaks associated with lazy accumulation monads, similar to lazy writer monads.)
* "Control.Monad.Trans.Accum"

If 'Accum' @w@ is the last effect in a stack, it can be interpreted to a function @w -> (w, a)@ given some result type @a@ and the presence of a 'Monoid' instance for @w@.

-- | @since 1.1.1.1
-}

module Control.Effect.Accum
( -- * Accumulation effect
  Accum(..)
, add
, look
, looks
  -- * Re-exports
, Algebra
, Has
, run
) where

import Control.Algebra
import Control.Effect.Accum.Internal (Accum(..))


-- | Write a value to the log.
--
-- @
-- 'runAccum' w0 ('add' w '>>' m) = 'Data.Bifunctor.first' ('mappend' w) '<$>' 'runAccum' w0 m
-- 'runAccum' w0 ('add' w '>>' m) = runAccum (w0 <> w) m
-- @
--
-- @since 1.1.1.1
add :: Has (Accum w) sig m => w -> m ()
add w = send (Add w)
{-# INLINE add #-}

-- | Look up the previous accumulation
--
-- @
-- 'runAccum' w 'look' = 'return' (w, w)
-- 'runAccum' w ('look' >>= continuation) = 'runAccum' w (continuation w)
-- @
--
-- @since 1.1.1.1
look :: Has (Accum w) sig m => m w
look = send Look
{-# INLINE look #-}

-- | Look up the previous accumulation and apply a function to it.
--
-- @
-- looks f = fmap f look
-- @
--
-- @since 1.1.1.1
looks :: Has (Accum w) sig m => (w -> a) -> m a
looks f = fmap f look
{-# INLINE looks #-}
