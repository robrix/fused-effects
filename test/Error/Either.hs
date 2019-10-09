{-# LANGUAGE ScopedTypeVariables, TypeApplications #-}
module Error.Either
( tests
) where

import Control.Carrier.Error.Either
import Control.Monad.Trans.Except
import Error
import Pure
import Test.QuickCheck.Poly
import Test.Tasty
import Test.Tasty.QuickCheck

tests :: TestTree
tests = testGroup "Error.Either"
  [ testProperty "throwError annihilation" $
    \ e k -> throwError_annihilation @C ((~=) @C @B) e (applyFun @A k)
  , testProperty "catchError substitution" $
    \ e f -> catchError_substitution @C ((~=) @C @A) e (applyFun f)
  ]

(~=) :: (Eq e, Eq a, Show e, Show a) => ErrorC e PureC a -> ErrorC e PureC a -> Property
m1 ~= m2 = run (runError m1) === run (runError m2)


instance (Arbitrary e, Arbitrary1 m, Arbitrary a) => Arbitrary (ErrorC e m a) where
  arbitrary = arbitrary1
  shrink = shrink1

instance (Arbitrary e, Arbitrary1 m) => Arbitrary1 (ErrorC e m) where
  liftArbitrary genA = ErrorC . ExceptT <$> liftArbitrary @m (liftArbitrary2 @Either (arbitrary @e) genA)
  liftShrink shrinkA = map (ErrorC . ExceptT) . liftShrink (liftShrink2 shrink shrinkA) . runError