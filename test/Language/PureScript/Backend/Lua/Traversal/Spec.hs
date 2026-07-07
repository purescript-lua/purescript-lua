module Language.PureScript.Backend.Lua.Traversal.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.Lua.Gen qualified as Gen
import Language.PureScript.Backend.Lua.Traversal
  ( everywhereExp
  , everywhereStat
  )
import Test.Hspec (Spec, describe)
import Test.Hspec.Hedgehog.Extended (prop)
import Prelude hiding (exp)

{- | The traversals rebuild every node by hand, threading each 'Annotated'
slot's comments through. A rebuild that dropped a @(c,)@ pair would
silently discard FFI comments from the output, and nothing else checks
that: the rewrite rules all promise "a rewrite that returns its argument
unchanged is comment-preserving" on top of exactly this contract.
-}
spec ∷ Spec
spec = describe "Lua AST traversal" do
  prop 300 "everywhereStat identity identity ≡ identity" do
    s ← forAll Gen.statement
    everywhereStat identity identity s === s

  prop 300 "everywhereExp identity identity ≡ identity" do
    e ← forAll Gen.exp
    everywhereExp identity identity e === e
