{-# LANGUAGE DeriveFunctor, ExistentialQuantification, RankNTypes, StandaloneDeriving #-}
module Control.Effect.Intercept where

import Control.Effect.Carrier

data Intercept eff m k
  = forall a . Intercept (m a) (forall n x . eff n (n x) -> m a) (a -> k)

deriving instance Functor (Intercept eff m)

instance HFunctor (Intercept eff) where
  hmap f (Intercept m h k) = Intercept (f m) (f . h) k
