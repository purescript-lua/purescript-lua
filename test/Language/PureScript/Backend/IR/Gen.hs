module Language.PureScript.Backend.IR.Gen where

import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Hedgehog (MonadGen)
import Hedgehog.Corpus qualified as Corpus
import Hedgehog.Gen.Extended qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Names qualified as IR
import Language.PureScript.Backend.IR.Types (noAnn)
import Language.PureScript.Backend.IR.Types qualified as IR
import Language.PureScript.Names (ModuleName, moduleNameFromString)
import Prelude hiding (exp)

exp ∷ ∀ m. MonadGen m ⇒ m IR.Exp
exp =
  Gen.recursiveFrequency
    [(1, nonRecursiveExp)]
    [
      ( 7
      , Gen.subterm2 exp exp IR.application
      )
    ,
      ( 3
      , Gen.subterm3 exp exp exp IR.ifThenElse
      )
    ,
      ( 1
      , Gen.subtermM exp \e →
          IR.arrayIndex e <$> Gen.integral (Range.linear 0 9)
      )
    ,
      ( 1
      , Gen.subtermM exp \e → IR.objectProp e <$> genPropName
      )
    ,
      ( 2
      , IR.literalArray <$> Gen.list (Range.linear 1 10) exp
      )
    ,
      ( 2
      , IR.literalObject <$> Gen.list (Range.linear 1 10) ((,) <$> genPropName <*> exp)
      )
    ,
      ( 1
      , Gen.subtermM exp \e →
          IR.objectUpdate e
            <$> Gen.nonEmpty (Range.linear 1 10) ((,) <$> genPropName <*> exp)
      )
    ,
      ( 5
      , Gen.subtermM exp \e → (`IR.abstraction` e) <$> parameter
      )
    ,
      ( 6
      , Gen.subtermM exp \e →
          (`IR.lets` e) <$> Gen.nonEmpty (Range.linear 1 5) binding
      )
    ]

{- | A generation-time scope: each local name in scope mapped to the number of
enclosing binders for it. Lets 'scopedExp' emit only references that resolve
to a binder (a valid De Bruijn index for that name).
-}
type Scope = Map IR.Name Natural

{- | Generate a closed, well-scoped expression: every local reference has an
index below the number of enclosing binders of that name. Restricted to
λ / application / if / object / reference / scalar, which is enough to
exercise beta reduction and name shadowing (the surface of issues #37 and
#56) while keeping well-scopedness easy to guarantee by construction. 'Let'
is intentionally left out; its sequential scoping is covered by the
hand-written specs.
-}
scopedExp ∷ ∀ m. MonadGen m ⇒ m IR.Exp
scopedExp =
  -- Cap the size hard: beta reduction duplicates substituted arguments, so an
  -- unbounded term can blow the optimizer up exponentially in memory. Small
  -- terms are plenty to surface scoping bugs (issues #37 / #56 both shrink to
  -- a handful of binders).
  Gen.scale (min 8) (scopedExpIn mempty)

scopedExpIn ∷ ∀ m. MonadGen m ⇒ Scope → m IR.Exp
scopedExpIn scope =
  Gen.recursiveFrequency
    ((4, scalarExp) : [(5, scopedRef) | not (null inScope)])
    [ (6, IR.application <$> scopedExpIn scope <*> scopedExpIn scope)
    ,
      ( 3
      , IR.ifThenElse
          <$> scopedExpIn scope
          <*> scopedExpIn scope
          <*> scopedExpIn scope
      )
    , (5, genAbs)
    , (4, genRedex)
    ,
      ( 2
      , IR.literalObject
          <$> Gen.list
            (Range.linear 1 4)
            ((,) <$> genPropName <*> scopedExpIn scope)
      )
    ]
 where
  inScope = [(nm, count) | (nm, count) ← Map.toList scope, count > 0]
  scopedRef = do
    (nm, count) ← Gen.element inScope
    index ← Gen.integral (Range.linear 0 (fromIntegral count - 1))
    pure (IR.refLocal nm index)
  genAbs = do
    (param, body) ← genBinderBody
    pure (IR.abstraction param body)
  -- An immediately-applied λ: a beta redex. Generating these directly (rather
  -- than hoping an application's head happens to be a λ) is what makes the
  -- well-scopedness property actually exercise beta reduction, including the
  -- shadowing case behind issue #56.
  genRedex = do
    (param, body) ← genBinderBody
    arg ← scopedExpIn scope
    pure (IR.application (IR.abstraction param body) arg)
  genBinderBody = do
    param ← parameter
    let scope' = case param of
          IR.ParamNamed _ nm → Map.insertWith (+) nm 1 scope
          IR.ParamUnused _ → scope
    body ← scopedExpIn scope'
    pure (param, body)

binding ∷ MonadGen m ⇒ m IR.Binding
binding = Gen.frequency [(8, standaloneBinding), (2, recursiveBinding)]

namedExp ∷ MonadGen m ⇒ m (IR.Ann, IR.Name, IR.Exp)
namedExp = (noAnn,,) <$> name <*> exp

recursiveBinding ∷ MonadGen m ⇒ m IR.Binding
recursiveBinding =
  IR.RecursiveGroup <$> Gen.nonEmpty (Range.linear 1 5) namedExp

standaloneBinding ∷ MonadGen m ⇒ m IR.Binding
standaloneBinding = IR.Standalone <$> namedExp

nonRecursiveExp ∷ MonadGen m ⇒ m IR.Exp
nonRecursiveExp =
  Gen.frequency
    [ (5, literalNonRecursiveExp)
    , (1, exception)
    , (1, ctor)
    , (3, IR.ref <$> qualified name <*> pure 0)
    ]

exception ∷ MonadGen m ⇒ m IR.Exp
exception = IR.exception <$> Gen.text (Range.linear 0 10) Gen.unicode

ctor ∷ MonadGen m ⇒ m IR.Exp
ctor =
  IR.ctor
    <$> Gen.enumBounded
    <*> moduleName
    <*> tyName
    <*> ctorName
    <*> Gen.list (Range.linear 0 10) fieldName

literalNonRecursiveExp ∷ MonadGen m ⇒ m IR.Exp
literalNonRecursiveExp =
  Gen.frequency
    [ (5, scalarExp)
    , (1, pure $ IR.literalArray [])
    , (1, pure $ IR.literalObject [])
    ]

scalarExp ∷ MonadGen m ⇒ m IR.Exp
scalarExp =
  Gen.choice
    [ IR.literalInt <$> Gen.integral (Range.exponential 0 1000)
    , IR.literalString <$> Gen.text (Range.linear 0 10) Gen.unicode
    , IR.literalBool <$> Gen.bool
    , IR.literalChar <$> Gen.unicode
    , IR.literalFloat
        <$> Gen.double
          (Range.exponentialFloat 0 1000000000000000000)
    ]

parameter ∷ MonadGen m ⇒ m (IR.Parameter IR.Ann)
parameter =
  Gen.frequency
    [ (1, pure (IR.ParamUnused noAnn))
    , (9, IR.ParamNamed noAnn <$> name)
    ]

qualified ∷ MonadGen m ⇒ m a → m (IR.Qualified a)
qualified q =
  Gen.frequency
    [ (8, IR.Local <$> q)
    , (2, IR.Imported <$> moduleName <*> q)
    ]

refLocal ∷ MonadGen m ⇒ m IR.Exp
refLocal = flip IR.refLocal 0 <$> name

moduleName ∷ MonadGen m ⇒ m ModuleName
moduleName = moduleNameFromString <$> Gen.element Corpus.colours

name ∷ MonadGen m ⇒ m IR.Name
name = IR.Name <$> Gen.element ["x", "y", "z", "i", "j", "k", "l"]

tyName ∷ MonadGen m ⇒ m IR.TyName
tyName = IR.TyName . Text.toTitle <$> Gen.element Corpus.waters

ctorName ∷ MonadGen m ⇒ m IR.CtorName
ctorName = IR.CtorName . Text.toTitle <$> Gen.element Corpus.colours

genPropName ∷ MonadGen m ⇒ m IR.PropName
genPropName = IR.PropName <$> Gen.element Corpus.metasyntactic

fieldName ∷ MonadGen m ⇒ m IR.FieldName
fieldName = IR.FieldName <$> Gen.element Corpus.metasyntactic
