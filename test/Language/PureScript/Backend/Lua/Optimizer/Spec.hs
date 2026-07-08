{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Optimizer.Spec where

import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.Optimizer
  ( foldFieldProjectionThroughScopeCall
  , foldNotEqual
  , reduceTableDefinitionAccessor
  , rewriteExpWithRule
  )
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Expectations.Pretty (assertEqual)
import Text.Pretty.Simple (pShow)

spec ∷ Spec
spec = describe "Lua AST Optimizer" do
  describe "reduceTableDefinitionAccessor" do
    it "folds a field access into an unambiguous name-value definition" do
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.table
                  [ Lua.tableRowNV [name|foo|] (Lua.Integer 1)
                  , Lua.tableRowNV [name|bar|] (Lua.Integer 2)
                  ]
              )
              [name|foo|]
      assertEqual (toString $ pShow original) (Lua.Integer 1) $
        rewriteExpWithRule reduceTableDefinitionAccessor original

    it "declines when a key-value row could shadow the accessed field" do
      -- The accessed field is present only as a string-keyed row, which the
      -- name lookup cannot see, so folding to Nil would drop the real value.
      let original ∷ Lua.Exp =
            Lua.varField
              (Lua.table [Lua.tableRowKV (Lua.String "foo") (Lua.Integer 1)])
              [name|foo|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule reduceTableDefinitionAccessor original

    it "declines on duplicate field names, where Lua keeps the last" do
      -- Lua's table constructor keeps the last assignment (2); a first-match
      -- fold would wrongly return the first (1).
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.table
                  [ Lua.tableRowNV [name|foo|] (Lua.Integer 1)
                  , Lua.tableRowNV [name|foo|] (Lua.Integer 2)
                  ]
              )
              [name|foo|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule reduceTableDefinitionAccessor original

  describe "foldFieldProjectionThroughScopeCall" do
    it "folds a field projection through a header-scope IIFE's return" do
      -- The @(function() local refEq = …; return { eqCharImpl = refEq } end)()
      -- .eqCharImpl@ shape from a foreign import with a header (issue #159).
      -- The projected field is immediately re-optimized, so
      -- 'reduceTableDefinitionAccessor' sees through the exposed table
      -- constructor and reduces it all the way to the referenced local.
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.scope
                  [ Lua.local1 [name|refEq|] (Lua.Integer 1)
                  , Lua.return
                      ( Lua.table
                          [ Lua.tableRowNV
                              [name|eqCharImpl|]
                              (Lua.varName [name|refEq|])
                          ]
                      )
                  ]
              )
              [name|eqCharImpl|]
          expected ∷ Lua.Exp =
            Lua.scope
              [ Lua.local1 [name|refEq|] (Lua.Integer 1)
              , Lua.return (Lua.varName [name|refEq|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "folds through the call even when the field can't be reduced further" do
      -- The returned value isn't an unambiguous table constructor here, so
      -- the projection only moves inside the call; it isn't reduced away.
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.scope
                  [ Lua.local1 [name|refEq|] (Lua.Integer 1)
                  , Lua.return (Lua.varName [name|refEq|])
                  ]
              )
              [name|eqCharImpl|]
          expected ∷ Lua.Exp =
            Lua.scope
              [ Lua.local1 [name|refEq|] (Lua.Integer 1)
              , Lua.return
                  (Lua.varField (Lua.varName [name|refEq|]) [name|eqCharImpl|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "declines when the callee isn't a no-arg immediately-invoked function" do
      let original ∷ Lua.Exp =
            Lua.varField (Lua.varName [name|notACall|]) [name|eqCharImpl|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "declines when a leading statement contains an early return" do
      -- Projecting only into the final return would leave the early
      -- return unprojected, changing the value on that path.
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.scope
                  [ Lua.ifThenElse
                      (Lua.Boolean True)
                      [Lua.return (Lua.varName [name|a|])]
                      []
                  , Lua.return (Lua.varName [name|b|])
                  ]
              )
              [name|foo|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "declines when a leading loop body contains a return" do
      -- A `return` at the body level of a `while` exits the call the same
      -- way a top-level early return does.
      let original ∷ Lua.Exp =
            Lua.varField
              ( Lua.scope
                  [ Lua.While
                      (Lua.ann (Lua.Boolean True))
                      [Lua.ann (Lua.return (Lua.varName [name|a|]))]
                  , Lua.return (Lua.varName [name|b|])
                  ]
              )
              [name|foo|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "folds past a leading loop without a return" do
      let scopeBody ∷ Lua.Exp → [Lua.Statement]
          scopeBody returned =
            [ Lua.While
                (Lua.ann (Lua.Boolean True))
                [Lua.ann (Lua.assignVar [name|a|] Lua.Nil)]
            , Lua.return returned
            ]
          original ∷ Lua.Exp =
            Lua.varField
              (Lua.scope (scopeBody (Lua.varName [name|b|])))
              [name|foo|]
          expected ∷ Lua.Exp =
            Lua.scope
              ( scopeBody
                  (Lua.varField (Lua.varName [name|b|]) [name|foo|])
              )
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

    it "folds past a leading local function whose body returns" do
      -- A `return` inside a nested (local) function belongs to a different
      -- activation: it does not exit this call, so the fold may proceed.
      let scopeBody ∷ Lua.Exp → [Lua.Statement]
          scopeBody returned =
            [ Lua.LocalFunction
                [name|helper|]
                []
                [Lua.ann (Lua.return Lua.Nil)]
            , Lua.return returned
            ]
          original ∷ Lua.Exp =
            Lua.varField
              (Lua.scope (scopeBody (Lua.varName [name|b|])))
              [name|foo|]
          expected ∷ Lua.Exp =
            Lua.scope
              ( scopeBody
                  (Lua.varField (Lua.varName [name|b|]) [name|foo|])
              )
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldFieldProjectionThroughScopeCall original

  describe "foldNotEqual" do
    it "rewrites not (a == b) to a ~= b" do
      let original ∷ Lua.Exp =
            Lua.logicalNot
              (Lua.equalTo (Lua.varName [name|a|]) (Lua.varName [name|b|]))
      assertEqual
        (toString $ pShow original)
        (Lua.notEqualTo (Lua.varName [name|a|]) (Lua.varName [name|b|]))
        $ rewriteExpWithRule foldNotEqual original

    it "rewrites not (a ~= b) to a == b" do
      let original ∷ Lua.Exp =
            Lua.logicalNot
              (Lua.notEqualTo (Lua.varName [name|a|]) (Lua.varName [name|b|]))
      assertEqual
        (toString $ pShow original)
        (Lua.equalTo (Lua.varName [name|a|]) (Lua.varName [name|b|]))
        $ rewriteExpWithRule foldNotEqual original
