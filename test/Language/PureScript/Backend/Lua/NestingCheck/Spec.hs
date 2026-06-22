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

  -- The constructs below are not flattened by FlattenDeepBinds, so the detector
  -- is their only safety net: it must count each as one level and flag a deep
  -- enough chain. (These were previously unexercised — only call arguments and
  -- the curried spine had tests.)

  it "measures a nested operator chain as one level each" do
    maxChunkDepth (binOpChain 30) `shouldBe` 30

  it "flags an operator chain that nests beyond the limit" do
    let depth = nestingLimit + 30
    exceedsNestingLimit (binOpChain depth) `shouldSatisfy` \case
      Just d → d >= depth
      Nothing → False

  it "measures a ladder of nested if-statements as one level each" do
    maxChunkDepth (ifLadder 30) `shouldBe` 30

  it "flags an if-ladder that nests beyond the limit" do
    let depth = nestingLimit + 30
    exceedsNestingLimit (ifLadder depth) `shouldSatisfy` \case
      Just d → d >= depth
      Nothing → False

  it "measures nested table constructors as one level each" do
    maxChunkDepth (tableNest 30) `shouldBe` 30

  it "measures a chain of field accesses as one level each" do
    maxChunkDepth (fieldChain 30) `shouldBe` 30

  -- `1 + a `max` b` was flagged as able to undercount when the deeper operand
  -- is on the right. It cannot: `max` (infixl 9) binds tighter than `+`
  -- (infixl 6), so the metric is already `1 + max(left,right)`, symmetric. These
  -- guard that symmetry (and the explicit parentheses now in the source) for the
  -- binary positions — operator, index key, and if-else branch.
  it "counts the deeper operand on the right, not only the left" do
    maxChunkDepth (binOpChainRight 30) `shouldBe` 30
    maxChunkDepth (indexChainRight 30) `shouldBe` 30
    maxChunkDepth (ifLadderElse 30) `shouldBe` 30

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

-- | @return (…((nil + nil) + nil) … + nil)@, @n@ operators deep on the left.
binOpChain ∷ Int → Chunk
binOpChain n =
  [Lua.return (foldr (\_ e → Lua.binOp Lua.Add e Lua.Nil) Lua.Nil [1 .. n])]

-- | @return (nil + (nil + (… + nil)))@, @n@ operators deep on the right.
binOpChainRight ∷ Int → Chunk
binOpChainRight n =
  [Lua.return (foldr (\_ e → Lua.binOp Lua.Add Lua.Nil e) Lua.Nil [1 .. n])]

-- | @return t[t[…[t]…]]@, @n@ index accesses deep in the key (right) position.
indexChainRight ∷ Int → Chunk
indexChainRight n =
  [ Lua.return
      ( foldr
          (\_ e → Lua.varIndex (Lua.varName [name|t|]) e)
          (Lua.varName [name|t|])
          [1 .. n]
      )
  ]

-- | @if nil then else if nil then else … end end@, @n@ deep in the else branch.
ifLadderElse ∷ Int → Chunk
ifLadderElse = go
 where
  go ∷ Int → Chunk
  go k
    | k <= 0 = []
    | otherwise = [Lua.ifThenElse Lua.Nil [] (go (k - 1))]

-- | @if nil then if nil then … end end@, @n@ statements deep.
ifLadder ∷ Int → Chunk
ifLadder = go
 where
  go ∷ Int → Chunk
  go k
    | k <= 0 = []
    | otherwise = [Lua.ifThenElse Lua.Nil (go (k - 1)) []]

-- | @return { [nil] = { [nil] = … } }@, @n@ table constructors deep.
tableNest ∷ Int → Chunk
tableNest n =
  [ Lua.return
      (foldr (\_ e → Lua.table [Lua.tableRowKV Lua.Nil e]) Lua.Nil [1 .. n])
  ]

-- | @return t.f.f.….f@, @n@ field accesses deep.
fieldChain ∷ Int → Chunk
fieldChain n =
  [ Lua.return
      (foldr (\_ e → Lua.varField e [name|f|]) (Lua.varName [name|t|]) [1 .. n])
  ]
