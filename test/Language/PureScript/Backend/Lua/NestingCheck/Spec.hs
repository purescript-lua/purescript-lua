{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.NestingCheck.Spec where

import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.NestingCheck
  ( exceedsNestingLimit
  , maxChunkDepth
  , nestingLimit
  )
import Language.PureScript.Backend.Lua.Types (Chunk)
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

spec ∷ Spec
spec = describe "NestingCheck" do
  it "passes an empty chunk" do
    maxChunkDepth [] `shouldBe` 0
    exceedsNestingLimit [] `shouldBe` Nothing

  it "passes a shallow chunk" do
    exceedsNestingLimit (nestedArgs 10) `shouldBe` Nothing

  it "flags a chunk that nests beyond the limit" do
    let depth = nestingLimit + 50
    exceedsNestingLimit (nestedArgs depth) `shouldSatisfy` \case
      Just d → d >= depth
      Nothing → False

  it "measures nested function-call arguments as one level each" do
    maxChunkDepth (nestedArgs 30) `shouldBe` 30

  it "does not count the iterative spine of a curried call" do
    -- @f()()()…()@ is parsed iteratively, so its depth stays tiny regardless of
    -- how many calls are chained — mirroring Lua's parser.
    maxChunkDepth (curriedCalls 250) `shouldSatisfy` (<= 2)
    exceedsNestingLimit (curriedCalls 250) `shouldBe` Nothing

--------------------------------------------------------------------------------
-- Builders --------------------------------------------------------------------

-- | @return f(f(…f(nil)…))@ with @n@ nested argument positions.
nestedArgs ∷ Int → Chunk
nestedArgs n =
  [ Lua.return
      (foldr (\_ e → Lua.functionCall (Lua.varName [name|f|]) [e]) Lua.Nil [1 .. n])
  ]

-- | @return f()()…()@ with @n@ chained (curried) calls, each with no arguments.
curriedCalls ∷ Int → Chunk
curriedCalls n =
  [ Lua.return
      (foldl' (\acc _ → Lua.functionCall acc []) (Lua.varName [name|f|]) [1 .. n])
  ]
