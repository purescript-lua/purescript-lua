module Test.Hspec.Hedgehog.Extended
  ( module H
  , prop
  , test
  , xtest
  ) where

import Hedgehog (PropertyT)
import Test.Hspec (SpecWith, it, xit)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)
import Test.Hspec.Hedgehog qualified as H

test ∷ String → PropertyT IO () → SpecWith ()
test title =
  modifyMaxShrinks (const 0)
    . modifyMaxSuccess (const 1)
    . it title
    . hedgehog

{- | Like 'test', but runs the property over the given number of generated
inputs: 'test' pins @maxSuccess@ at 1, which is fine for example-based
checks but too weak for pass\/pipeline contract invariants.
-}
prop ∷ Int → String → PropertyT IO () → SpecWith ()
prop maxSuccess title =
  modifyMaxSuccess (const maxSuccess) . it title . hedgehog

xtest ∷ String → PropertyT IO () → SpecWith ()
xtest title = xit title . hedgehog
