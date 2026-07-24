{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Optimizer.Spec where

import Language.PureScript.Backend.Lua.Limits (LuaLimits (..), lua51Limits)
import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.Optimizer
  ( collapseTailLiteralApplication
  , foldCallThroughScopeCall
  , foldFieldProjectionThroughScopeCall
  , foldNotEqual
  , optimizeStatement
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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

    it "declines when the callee isn't a no-arg immediately-invoked function" do
      let original ∷ Lua.Exp =
            Lua.varField (Lua.varName [name|notACall|]) [name|eqCharImpl|]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

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
        rewriteExpWithRule (foldFieldProjectionThroughScopeCall lua51Limits) original

  describe "foldCallThroughScopeCall" do
    it "folds a trailing call into a plain-return scope call" do
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [ Lua.local1 [name|v|] (Lua.varName [name|g|])
                  , Lua.return (Lua.varName [name|f|])
                  ]
              )
              [Lua.varName [name|b|]]
          expected ∷ Lua.Exp =
            Lua.scope
              [ Lua.local1 [name|v|] (Lua.varName [name|g|])
              , Lua.return
                  (Lua.functionCall (Lua.varName [name|f|]) [Lua.varName [name|b|]])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "folds a zero-argument run into both branches of a tail if" do
      -- The thunk-selection shape: `(function() if c then return f else
      -- return g end end)()()` picks an effect and immediately runs it.
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [ Lua.ifThenElse
                      (Lua.varName [name|c|])
                      [Lua.return (Lua.varName [name|f|])]
                      [Lua.return (Lua.varName [name|g|])]
                  ]
              )
              []
          expected ∷ Lua.Exp =
            Lua.scope
              [ Lua.ifThenElse
                  (Lua.varName [name|c|])
                  [Lua.return (Lua.functionCall (Lua.varName [name|f|]) [])]
                  [Lua.return (Lua.functionCall (Lua.varName [name|g|]) [])]
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "re-folds when the returned expression is itself a scope call" do
      let original ∷ Lua.Exp =
            Lua.functionCall
              (Lua.scope [Lua.return (Lua.scope [Lua.return (Lua.varName [name|f|])])])
              [Lua.varName [name|b|]]
          expected ∷ Lua.Exp =
            Lua.scope
              [ Lua.return
                  ( Lua.scope
                      [ Lua.return
                          ( Lua.functionCall
                              (Lua.varName [name|f|])
                              [Lua.varName [name|b|]]
                          )
                      ]
                  )
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "declines when a leading statement contains an early return" do
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [ Lua.ifThenElse
                      (Lua.varName [name|c|])
                      [Lua.return (Lua.varName [name|f|])]
                      []
                  , Lua.return (Lua.varName [name|g|])
                  ]
              )
              []
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "declines on a fall-off path (tail if without an else)" do
      -- Falling off the end yields nil, which the original code then
      -- calls (an error); a partial fold would return nil instead.
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [ Lua.ifThenElse
                      (Lua.varName [name|c|])
                      [Lua.return (Lua.varName [name|f|])]
                      []
                  ]
              )
              []
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "declines on a multi-valued tail return" do
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [Lua.returnN (Lua.varName [name|f|] :| [Lua.varName [name|g|]])]
              )
              []
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "declines when an argument name collides with a body local" do
      -- Moved inside, `x` would resolve to the callee's local, not the
      -- enclosing scope's binding.
      let original ∷ Lua.Exp =
            Lua.functionCall
              ( Lua.scope
                  [ Lua.local1 [name|x|] (Lua.Integer 1)
                  , Lua.return (Lua.varName [name|f|])
                  ]
              )
              [Lua.varName [name|x|]]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "declines non-atomic arguments on a branching tail" do
      -- Branch pushing duplicates the arguments into every return site;
      -- only names and literals keep that duplication trivial.
      let scopeCall ∷ Lua.Exp =
            Lua.scope
              [ Lua.ifThenElse
                  (Lua.varName [name|c|])
                  [Lua.return (Lua.varName [name|f|])]
                  [Lua.return (Lua.varName [name|g|])]
              ]
          nonAtomic ∷ Lua.Exp =
            Lua.functionCall
              scopeCall
              [Lua.functionCall (Lua.varName [name|h|]) []]
          atomic ∷ Lua.Exp =
            Lua.functionCall scopeCall [Lua.varName [name|b|]]
          pushed ∷ Lua.Exp =
            Lua.scope
              [ Lua.ifThenElse
                  (Lua.varName [name|c|])
                  [ Lua.return
                      ( Lua.functionCall
                          (Lua.varName [name|f|])
                          [Lua.varName [name|b|]]
                      )
                  ]
                  [ Lua.return
                      ( Lua.functionCall
                          (Lua.varName [name|g|])
                          [Lua.varName [name|b|]]
                      )
                  ]
              ]
      assertEqual (toString $ pShow nonAtomic) nonAtomic $
        rewriteExpWithRule foldCallThroughScopeCall nonAtomic
      assertEqual (toString $ pShow atomic) pushed $
        rewriteExpWithRule foldCallThroughScopeCall atomic

    it "declines varargs among the arguments" do
      let original ∷ Lua.Exp =
            Lua.functionCall
              (Lua.scope [Lua.return (Lua.varName [name|f|])])
              [Lua.Vararg]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule foldCallThroughScopeCall original

    it "composes with the tail-literal collapse into a zero-closure tail" do
      -- The end-to-end #230-family result: `return (function() if c then
      -- return f else return g end end)()()` in a function tail loses
      -- both the closure and the extra calls.
      let worker ∷ [Lua.Statement] → Lua.Statement
          worker body =
            Lua.local1
              [name|w|]
              (Lua.functionDef [Lua.ParamNamed [name|n|]] body)
          original =
            worker
              [ Lua.return
                  ( Lua.functionCall
                      ( Lua.scope
                          [ Lua.ifThenElse
                              (Lua.varName [name|c|])
                              [Lua.return (Lua.varName [name|f|])]
                              [Lua.return (Lua.varName [name|g|])]
                          ]
                      )
                      []
                  )
              ]
          expected =
            worker
              [ Lua.ifThenElse
                  (Lua.varName [name|c|])
                  [Lua.return (Lua.functionCall (Lua.varName [name|f|]) [])]
                  [Lua.return (Lua.functionCall (Lua.varName [name|g|]) [])]
              ]
      assertEqual (toString $ pShow original) expected $
        optimizeStatement lua51Limits original

  describe "collapseTailLiteralApplication" do
    it "splices a tail scope call into the enclosing function body" do
      -- The residual magic-do shape from issue #230: an effectful
      -- uncurried definition runs its do-chunk through a tail IIFE.
      let original ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.return
                  ( Lua.scope
                      [ Lua.local1 [name|c|] (Lua.varName [name|a|])
                      , Lua.return (Lua.varName [name|c|])
                      ]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.local1 [name|c|] (Lua.varName [name|a|])
              , Lua.return (Lua.varName [name|c|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "re-collapses a tail exposed by its own merge, without a traversal" do
      -- The bare rule (no bottom-up driver) must flatten both levels:
      -- 'foldCallThroughScopeCall' builds nested tails at depths the
      -- driver has already passed, so the rule cannot rely on it.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.scope
                      [ Lua.local1 [name|a|] (Lua.Integer 1)
                      , Lua.return
                          (Lua.scope [Lua.return (Lua.varName [name|a|])])
                      ]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.local1 [name|a|] (Lua.Integer 1)
              , Lua.return (Lua.varName [name|a|])
              ]
      assertEqual (toString $ pShow original) expected $
        collapseTailLiteralApplication lua51Limits original

    it "splices nested tail scope calls bottom-up in one pass" do
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.scope
                      [ Lua.local1 [name|a|] (Lua.Integer 1)
                      , Lua.return
                          ( Lua.scope
                              [ Lua.local1 [name|b|] (Lua.Integer 2)
                              , Lua.return (Lua.varName [name|b|])
                              ]
                          )
                      ]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.local1 [name|a|] (Lua.Integer 1)
              , Lua.local1 [name|b|] (Lua.Integer 2)
              , Lua.return (Lua.varName [name|b|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "splices past a leading early return" do
      -- An early return among the leading statements exits the parent on
      -- its own path either way; only the final statement is replaced.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.ifThenElse
                  (Lua.Boolean True)
                  [Lua.return (Lua.Integer 1)]
                  []
              , Lua.return (Lua.scope [Lua.return (Lua.Integer 2)])
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.ifThenElse
                  (Lua.Boolean True)
                  [Lua.return (Lua.Integer 1)]
                  []
              , Lua.return (Lua.Integer 2)
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "splices a body that falls off the end (zero return values)" do
      -- Both before and after, the parent returns no values.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.local1 [name|a|] (Lua.Integer 1)
              , Lua.return
                  (Lua.scope [Lua.CallStatement (Lua.ann (Lua.error "eff"))])
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.local1 [name|a|] (Lua.Integer 1)
              , Lua.CallStatement (Lua.ann (Lua.error "eff"))
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "splices an applied literal, binding its parameters as locals" do
      -- The beta-redex 'foldCallThroughScopeCall' leaves behind (#295):
      -- the parameter binding becomes a simultaneous `local`.
      let original ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|b|]]
              [ Lua.return
                  ( Lua.functionCall
                      ( Lua.functionDef
                          [Lua.ParamNamed [name|x|]]
                          [Lua.return (Lua.varName [name|x|])]
                      )
                      [Lua.varName [name|b|]]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|b|]]
              [ Lua.local1 [name|x|] (Lua.varName [name|b|])
              , Lua.return (Lua.varName [name|x|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "binds parameters missing an argument to nil, as the call did" do
      -- One `local x, y = 1` nil-fills y exactly as Lua's call
      -- adjustment did.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.functionCall
                      ( Lua.functionDef
                          [Lua.ParamNamed [name|x|], Lua.ParamNamed [name|y|]]
                          [Lua.return (Lua.varName [name|y|])]
                      )
                      [Lua.Integer 1]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.localN ([name|x|] :| [[name|y|]]) (Lua.Integer 1)
              , Lua.return (Lua.varName [name|y|])
              ]
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "re-collapses through a parameterized merge, without a traversal" do
      -- The bare rule must flatten both levels when the outer merge
      -- exposes another applied literal in tail position.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.functionCall
                      ( Lua.functionDef
                          [Lua.ParamNamed [name|x|]]
                          [ Lua.return
                              ( Lua.functionCall
                                  ( Lua.functionDef
                                      [Lua.ParamNamed [name|y|]]
                                      [Lua.return (Lua.varName [name|x|])]
                                  )
                                  [Lua.Integer 2]
                              )
                          ]
                      )
                      [Lua.Integer 1]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.local1 [name|x|] (Lua.Integer 1)
              , Lua.local1 [name|y|] (Lua.Integer 2)
              , Lua.return (Lua.varName [name|x|])
              ]
      assertEqual (toString $ pShow original) expected $
        collapseTailLiteralApplication lua51Limits original

    it "declines a nullary literal applied to arguments" do
      -- There is no `local` binding zero names, and dropping the
      -- arguments would drop their effects.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.functionCall
                      (Lua.functionDef [] [Lua.return (Lua.Integer 1)])
                      [Lua.Integer 2]
                  )
              ]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "declines vararg and unused parameters" do
      -- Neither `...` nor an unnamed parameter can be bound by a `local`.
      let decline ∷ Lua.Param → IO ()
          decline param = do
            let original ∷ Lua.Exp =
                  Lua.functionDef
                    []
                    [ Lua.return
                        ( Lua.functionCall
                            ( Lua.functionDef
                                [param]
                                [Lua.return (Lua.Integer 1)]
                            )
                            [Lua.Integer 2]
                        )
                    ]
            assertEqual (toString $ pShow original) original $
              rewriteExpWithRule
                (collapseTailLiteralApplication lua51Limits)
                original
      decline Lua.ParamVararg
      decline Lua.ParamUnused

    it "declines a duplicate parameter name" do
      -- `local x, x = 1, 2` does bind the last occurrence, like the
      -- call did, but the shape never comes out of lowering — declining
      -- is simpler than reasoning about it.
      let original ∷ Lua.Exp =
            Lua.functionDef
              []
              [ Lua.return
                  ( Lua.functionCall
                      ( Lua.functionDef
                          [Lua.ParamNamed [name|x|], Lua.ParamNamed [name|x|]]
                          [Lua.return (Lua.varName [name|x|])]
                      )
                      [Lua.Integer 1, Lua.Integer 2]
                  )
              ]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "counts bound parameters against the local budget" do
      -- With maxLocals = 22 the working ceiling is 2: one parameter,
      -- one leading local and the bound parameter (3 slots) must not
      -- merge into one activation; one more slot of headroom admits the
      -- same splice.
      let tinyLimits = lua51Limits {maxLocals = 22}
          roomyLimits = lua51Limits {maxLocals = 23}
          original ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.return
                  ( Lua.functionCall
                      ( Lua.functionDef
                          [Lua.ParamNamed [name|c|]]
                          [Lua.return (Lua.varName [name|c|])]
                      )
                      [Lua.varName [name|b|]]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.local1 [name|c|] (Lua.varName [name|b|])
              , Lua.return (Lua.varName [name|c|])
              ]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (collapseTailLiteralApplication tinyLimits) original
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication roomyLimits) original

    it "declines when the merged body exceeds the local budget" do
      -- With maxLocals = 22 the working ceiling is 2: one parameter plus
      -- two merged locals (3 slots) must not be spliced into one
      -- activation; one more slot of headroom admits the same splice.
      let tinyLimits = lua51Limits {maxLocals = 22}
          roomyLimits = lua51Limits {maxLocals = 23}
          original ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.return
                  ( Lua.scope
                      [ Lua.local1 [name|c|] (Lua.Integer 2)
                      , Lua.return (Lua.varName [name|c|])
                      ]
                  )
              ]
          expected ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamNamed [name|a|]]
              [ Lua.local1 [name|b|] (Lua.Integer 1)
              , Lua.local1 [name|c|] (Lua.Integer 2)
              , Lua.return (Lua.varName [name|c|])
              ]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (collapseTailLiteralApplication tinyLimits) original
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication roomyLimits) original

    it "declines when the spliced statements use varargs in their scope" do
      -- A no-parameter function cannot legally mention `...`; on such
      -- (only ever hand-written) input the splice would rebind `...` to
      -- the parent's varargs instead of failing to load.
      let original ∷ Lua.Exp =
            Lua.functionDef
              [Lua.ParamVararg]
              [Lua.return (Lua.scope [Lua.Return [Lua.ann Lua.Vararg]])]
      assertEqual (toString $ pShow original) original $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

    it "splices past varargs owned by a nested function literal" do
      let inner ∷ [Lua.Statement] =
            [ Lua.local1
                [name|f|]
                ( Lua.functionDef
                    [Lua.ParamVararg]
                    [Lua.Return [Lua.ann Lua.Vararg]]
                )
            , Lua.return
                (Lua.functionCall (Lua.varName [name|f|]) [Lua.Integer 1])
            ]
          original ∷ Lua.Exp =
            Lua.functionDef [] [Lua.return (Lua.scope inner)]
          expected ∷ Lua.Exp = Lua.functionDef [] inner
      assertEqual (toString $ pShow original) expected $
        rewriteExpWithRule (collapseTailLiteralApplication lua51Limits) original

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
