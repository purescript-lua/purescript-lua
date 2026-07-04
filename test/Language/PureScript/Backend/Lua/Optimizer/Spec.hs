{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Optimizer.Spec where

import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.Optimizer
  ( reduceTableDefinitionAccessor
  , removeScopeWhenInsideEmptyFunction
  , rewriteExpWithRule
  )
import Language.PureScript.Backend.Lua.Types (ParamF (..))
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Expectations.Pretty (assertEqual)
import Text.Pretty.Simple (pShow)

spec ∷ Spec
spec = describe "Lua AST Optimizer" do
  describe "optimizes expressions" do
    it "removes scope when inside an empty function" do
      let original ∷ Lua.Exp =
            Lua.functionDef
              [ParamNamed [name|a|]]
              [ Lua.return
                  ( Lua.functionDef
                      [ParamNamed [name|b|]]
                      [Lua.return (Lua.scope [Lua.return (Lua.varName [name|c|])])]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              [ParamNamed [name|a|]]
              [ Lua.return
                  ( Lua.functionDef
                      [ParamNamed [name|b|]]
                      [Lua.return (Lua.varName [name|c|])]
                  )
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule removeScopeWhenInsideEmptyFunction original

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
