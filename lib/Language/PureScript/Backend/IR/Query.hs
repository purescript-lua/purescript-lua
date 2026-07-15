module Language.PureScript.Backend.IR.Query where

import Control.Lens (toListOf)
import Control.Lens.Plated (transformMOf)
import Control.Monad.Trans.Accum (add, execAccum)
import Data.Map qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( CtorName
  , ModuleName
  , Name (Name)
  , Qualified (Imported, Local)
  , TyName
  , runModuleName
  )
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (..)
  , Exp
  , RawExp (..)
  , bindingNames
  , countFreeRef
  , countFreeRefs
  , ctorId
  , listGrouping
  , paramName
  , subexpressions
  , unwindApp
  )
import Language.PureScript.Backend.IR.Types qualified as IR
import Language.PureScript.Names (runtimeLazyName)

usesRuntimeLazy ∷ UberModule → Bool
usesRuntimeLazy UberModule {uberModuleBindings, uberModuleExports} =
  getAny $
    foldMap
      (foldMap (\(_qname, e) → Any (findRuntimeLazyInExpr e)) . listGrouping)
      uberModuleBindings
      <> foldMap (Any . findRuntimeLazyInExpr . snd) uberModuleExports

-- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names
findRuntimeLazyInExpr ∷ Exp → Bool
findRuntimeLazyInExpr expr =
  countFreeRef (Local (Name runtimeLazyName)) expr > 0

usesPrimModule ∷ UberModule → Bool
usesPrimModule UberModule {uberModuleBindings, uberModuleExports} =
  getAny $
    foldMap
      (foldMap (\(_qname, e) → Any (findPrimModuleInExpr e)) . listGrouping)
      uberModuleBindings
      <> foldMap (Any . findPrimModuleInExpr . snd) uberModuleExports

findPrimModuleInExpr ∷ Exp → Bool
findPrimModuleInExpr expr =
  Map.keys (countFreeRefs expr) & any \case
    Local _name → False
    Imported moduleName _name → runModuleName moduleName == "Prim"

--------------------------------------------------------------------------------
-- Known-constructor resolution ------------------------------------------------

{- | The identity of a data constructor: its algebraic type and the
qualified name triple 'ctorId' renders into the runtime tag string.
-}
data CtorShape = CtorShape
  { ctorShapeType ∷ AlgebraicType
  , ctorShapeModule ∷ ModuleName
  , ctorShapeTyName ∷ TyName
  , ctorShapeCtor ∷ CtorName
  }
  deriving stock (Eq, Ord, Show)

-- | The runtime tag string of the constructor ('ctorId').
ctorShapeTag ∷ CtorShape → Text
ctorShapeTag CtorShape {ctorShapeModule, ctorShapeTyName, ctorShapeCtor} =
  ctorId ctorShapeModule ctorShapeTyName ctorShapeCtor

{- | Recognise a known saturated constructor value and return its shape
and field arguments. It covers every shape a constructor value takes
after uncurrying (see Note [Constructor applications are saturated] in
"Language.PureScript.Backend.IR.Types"):

  * an in-place 'Ctor' node (saturated by construction);
  * an n-ary worker call @AppN (Ref Cʷ) [a₁,…,aₙ]@ — the shape the early
    uncurry run rewrites a saturated arity-≥2 site into. 'unwindApp' does
    not flatten a multi-argument 'AppN' (Note [n-ary application]), so this
    shape is matched directly, not through the unary spine — miss it and
    the folds silently stop firing on monadic chains;
  * a curried unary spine @App (… (App (Ref C) a₁) …) aₙ@ — an arity-1
    constructor reference, or an arity-≥2 curried wrapper reference a site
    that saturates only after magicDo/flattening still carries before the
    late uncurry run.

A reference is resolved through the given environment by
'ctorFunctionShape', which reads only the constructor's declared shape —
it pastes no 'Ctor' node, so a chain that does not fold is not pessimised
into pasted constructor thunks (issue #180). The result is returned only
when the application is saturated (argument count equal to the declared
arity).
-}
resolveKnownCtorApp
  ∷ Map (Qualified Name) Exp → Exp → Maybe (CtorShape, [Exp])
resolveKnownCtorApp env = \case
  Ctor _ algTy modName tyName ctorName args →
    Just (CtorShape algTy modName tyName ctorName, args)
  AppN _ (Ref _ ctorRef) args
    | Just (shape, arity) ← ctorFunctionShape env ctorRef
    , arity == length args →
        Just (shape, toList args)
  expr
    | (Ref _ ctorRef, args@(_ : _)) ← unwindApp expr
    , Just (shape, arity) ← ctorFunctionShape env ctorRef
    , arity == length args →
        Just (shape, args)
  _ → Nothing

{- | The shape and arity of a binding that is a constructor /function/:
the manifest lambda chain 'Language.PureScript.Backend.IR.mkConstructor'
emits over a saturated 'Ctor' of references to its parameters, the n-ary
worker the uncurry split derives from it, or the curried wrapper
delegating to such a worker. Resolving reads only the declaration, never
pasting a 'Ctor' node. The visited set makes the wrapper→worker hop
terminate on arbitrary (possibly cyclic) input.
-}
ctorFunctionShape
  ∷ Map (Qualified Name) Exp → Qualified Name → Maybe (CtorShape, Int)
ctorFunctionShape env = go Set.empty
 where
  go visited ctorRef
    | ctorRef `Set.member` visited = Nothing
    | otherwise = do
        rhs ← Map.lookup ctorRef env
        let (params, body) = peelCtorParams rhs
        case body of
          Ctor _ algTy modName tyName ctorName args
            | argsAreRefsTo params args →
                Just
                  ( CtorShape algTy modName tyName ctorName
                  , length params
                  )
          AppN _ (Ref _ workerRef) wargs
            | argsAreRefsTo params (toList wargs)
            , Just (shape, arity) ← go (Set.insert ctorRef visited) workerRef
            , arity == length params →
                Just (shape, arity)
          _ → Nothing

{- | Peel leading lambda parameters (through unary 'Abs' and n-ary 'AbsN'), as
long as every one is named, returning the names in order and the body.
-}
peelCtorParams ∷ Exp → ([Name], Exp)
peelCtorParams = go []
 where
  go ∷ [Name] → Exp → ([Name], Exp)
  go acc = \case
    AbsN _ params body
      | Just names ← traverse paramName (toList params) →
          go (acc <> names) body
    e → (acc, e)

{- | Whether the expressions are exactly local references to the given names,
in order — a constructor lambda passing its parameters straight through.
-}
argsAreRefsTo ∷ [Name] → [Exp] → Bool
argsAreRefsTo names args =
  length names == length args && and (zipWith isRefTo names args)
 where
  isRefTo ∷ Name → Exp → Bool
  isRefTo name (Ref _ (Local n)) = n == name
  isRefTo _ _ = False

collectBoundNames ∷ Exp → Set Name
collectBoundNames =
  (`execAccum` Set.empty) . transformMOf subexpressions \e →
    case e of
      IR.AbsN _ann params _body →
        e <$ add (Set.fromList (mapMaybe IR.paramName (toList params)))
      IR.Let _ann groupings _body →
        e <$ add do
          Set.fromList
            [iname | grouping ← toList groupings, iname ← bindingNames grouping]
      IR.LetValues _ann params _rhs _body →
        e <$ add (Set.fromList (mapMaybe IR.paramName (toList params)))
      _ → pure e

{- | Whether some @Ref name@ is reached other than through a foldable
constructor-eliminating read — the residue that would dangle if the
binding were dropped and its reads folded to the constructor's fields.
Shared by 'propagateKnownCtorThroughLet' (the optimizer rule that folds
such a binding) and the deconstructing-site census of the CPR split
("Language.PureScript.Backend.IR.Cpr"), which pre-verifies exactly that
rule's precondition.

An out-of-range index or a mismatched algebraic type reads no existing
field, so it is not a foldable eliminating read: it counts as a
whole-value read, forcing the caller to decline (as
'reduceKnownConstructor' does). Well-typed input never indexes past the
arity nor mistypes the read; the guards keep callers sound on the
non-GUC / generated input 'optimizedExpression' also runs on. A
product-type @ReflectCtor@ read has no tag slot to fold to, so it too
counts as a whole-value read.
-}
hasWholeValueRead ∷ Name → AlgebraicType → Natural → Exp → Bool
hasWholeValueRead name algTy arity = go
 where
  go = \case
    ReflectCtor _ (Ref _ (Local n)) | n == name, SumType ← algTy → False
    DataArgumentByIndex _ readTy i (Ref _ (Local n))
      | n == name, readTy == algTy, i < arity → False
    Ref _ (Local n) | n == name → True
    other → any go (toListOf subexpressions other)
