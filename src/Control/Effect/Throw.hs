{-# LANGUAGE DeriveFunctor, DeriveGeneric, FlexibleContexts, KindSignatures #-}
module Control.Effect.Throw
( -- * Throw effect
  Throw(..)
, throwError
  -- * Re-exports
, Has
) where

import {-# SOURCE #-} Control.Carrier
import GHC.Generics (Generic1)

data Throw e (m :: * -> *) k
  = Throw e
  deriving (Functor, Generic1)

instance HFunctor (Throw e)
instance Effect   (Throw e)


-- | Throw an error, escaping the current computation up to the nearest 'Control.Effect.Catch.catchError' (if any).
throwError :: Has (Throw e) sig m => e -> m a
throwError = send . Throw