{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
module Control.Effect.Accum.Internal
( Accum(..)
) where

import Data.Kind (Type)

-- | @since 1.1.1.1
data Accum w (m :: Type -> Type) k where
  Add  :: w -> Accum w m ()
  Look ::      Accum w m w
