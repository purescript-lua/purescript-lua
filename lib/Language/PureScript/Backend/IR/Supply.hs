{- | A deterministic supply of fresh names for IR pipeline passes.

The counter starts at 0 on every 'runSupply' and advances in traversal
order, so the minted names are reproducible across runs — they end up
verbatim in generated Lua (and thus in golden files), where any
non-determinism would show up as spurious churn.

Only passes that mint names appearing in the /output/ may draw from the
shared supply — 'Language.PureScript.Backend.IR.FlattenDeepBinds'
('$kontN'\/'$tmpN' helpers) and the freshening primitives of
'Language.PureScript.Backend.IR.Types' ('freshenBinders',
'substituteCopyM', 'substituteMoveM') used by the optimizer and magic-do.
Counters that are internal to a pass — the node-ID counter of
'Language.PureScript.Backend.IR.DCE', the digit-suffix renaming of
'Language.PureScript.Backend.IR.Uniquify.uniquifyNames' — must stay
internal: routing them through the shared supply would shift the
numbering of every name minted downstream.
-}
module Language.PureScript.Backend.IR.Supply
  ( SupplyM
  , runSupply
  , freshName
  ) where

import Language.PureScript.Backend.IR.Names (Name (..))

newtype SupplyM a = SupplyM (State Natural a)
  deriving newtype (Functor, Applicative, Monad)

-- | Run a supplied computation, starting the counter at 0.
runSupply ∷ SupplyM a → a
runSupply (SupplyM st) = evalState st 0

-- | Mint a fresh name: the prefix followed by the next counter value.
freshName ∷ Text → SupplyM Name
freshName prefix = SupplyM $ state \n → (Name (prefix <> show n), n + 1)
