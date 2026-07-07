module Language.PureScript.Backend.Lua.Traversal where

import Language.PureScript.Backend.Lua.Types
import Prelude hiding (local)

everywhereExp
  ∷ (Exp → Exp) → (Statement → Statement) → Exp → Exp
everywhereExp f g = runIdentity . everywhereExpM (pure . f) (pure . g)

everywhereStat
  ∷ (Statement → Statement) → (Exp → Exp) → Statement → Statement
everywhereStat f g = runIdentity . everywhereStatM (pure . f) (pure . g)

everywhereInChunkM
  ∷ Monad m
  ⇒ (Exp → m Exp)
  → (Statement → m Statement)
  → (Chunk → m Chunk)
everywhereInChunkM f g = traverse (everywhereStatM g f)

{- | Bottom-up rewriting. Rebuilt nodes keep the annotations of the originals:
a rewrite that returns its argument unchanged is comment-preserving.
-}
everywhereExpM
  ∷ ∀ m
   . Monad m
  ⇒ (Exp → m Exp)
  → (Statement → m Statement)
  → (Exp → m Exp)
everywhereExpM f g = goe
 where
  goe ∷ Exp → m Exp
  goe = \case
    Var (c, v) → f . Var . (c,) =<< goVar v
    Function params body →
      f . Function params =<< traverse (traverse gos) body
    TableCtor rows →
      f . TableCtor =<< forM rows \(c, row) → (c,) <$> goRow row
    UnOp op e →
      f . UnOp op =<< goAnn e
    BinOp op e1 e2 →
      f =<< BinOp op <$> goAnn e1 <*> goAnn e2
    FunctionCall fn args →
      f =<< FunctionCall <$> goAnn fn <*> traverse goAnn args
    MethodCall obj n args →
      f =<< MethodCall <$> goAnn obj <*> pure n <*> traverse goAnn args
    Paren e → f . Paren =<< goAnn e
    other → f other

  goAnn ∷ Annotated Comments ExpF → m (Annotated Comments ExpF)
  goAnn = traverse goe

  goVar ∷ VarF Comments → m (VarF Comments)
  goVar = \case
    VarName n → pure (VarName n)
    VarIndex e1 e2 → VarIndex <$> goAnn e1 <*> goAnn e2
    VarField e n → (`VarField` n) <$> goAnn e

  goRow ∷ TableRowF Comments → m (TableRowF Comments)
  goRow = \case
    TableRowKV k v → TableRowKV <$> goAnn k <*> goAnn v
    TableRowNV n e → TableRowNV n <$> goAnn e
    TableRowV e → TableRowV <$> goAnn e

  gos ∷ Statement → m Statement
  gos = everywhereStatM g f

{- | Bottom-up rewriting. Rebuilt nodes keep the annotations of the originals:
a rewrite that returns its argument unchanged is comment-preserving.
-}
everywhereStatM
  ∷ ∀ m
   . Monad m
  ⇒ (Statement → m Statement)
  → (Exp → m Exp)
  → (Statement → m Statement)
everywhereStatM f g = go
 where
  goe ∷ Exp → m Exp
  goe = everywhereExpM g f

  goAnn ∷ Annotated Comments ExpF → m (Annotated Comments ExpF)
  goAnn = traverse goe

  goVar ∷ Annotated Comments VarF → m (Annotated Comments VarF)
  goVar (c, v) =
    (c,) <$> case v of
      VarName n → pure (VarName n)
      VarIndex e1 e2 → VarIndex <$> goAnn e1 <*> goAnn e2
      VarField e n → (`VarField` n) <$> goAnn e

  goBlock ∷ [Annotated Comments StatementF] → m [Annotated Comments StatementF]
  goBlock = traverse (traverse go)

  go ∷ Statement → m Statement
  go = \case
    Assign vars vals →
      f =<< Assign <$> traverse goVar vars <*> traverse goAnn vals
    Local names vals → f . Local names =<< traverse goAnn vals
    IfThenElse p tb eb →
      f =<< IfThenElse <$> goAnn p <*> goBlock tb <*> goBlock eb
    Return es → f . Return =<< traverse goAnn es
    CallStatement e → f . CallStatement =<< goAnn e
    Do body → f . Do =<< goBlock body
    While p body → f =<< While <$> goAnn p <*> goBlock body
    Repeat body p → f =<< Repeat <$> goBlock body <*> goAnn p
    ForNum n start limit step body →
      f
        =<< ForNum n
          <$> goAnn start
          <*> goAnn limit
          <*> traverse goAnn step
          <*> goBlock body
    ForIn names es body →
      f =<< ForIn names <$> traverse goAnn es <*> goBlock body
    LocalFunction n params body →
      f . LocalFunction n params =<< goBlock body
    Break → f Break
