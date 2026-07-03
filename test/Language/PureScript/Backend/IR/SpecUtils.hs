-- | Helpers shared by the IR pass specs.
module Language.PureScript.Backend.IR.SpecUtils
  ( applyPassToExpression
  , emptyUberModule
  ) where

import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names (Name (Name))
import Language.PureScript.Backend.IR.Types (Exp)

{- | Run a whole-module pass over a single expression by wrapping it as the
sole @main@ export of an otherwise empty 'UberModule' and unwrapping the
result. The first argument names the caller in the error message.
-}
applyPassToExpression
  ∷ HasCallStack ⇒ Text → (UberModule → UberModule) → Exp → Exp
applyPassToExpression caller runPass e =
  case uberModuleExports
    (runPass emptyUberModule {uberModuleExports = [(Name "main", e)]}) of
    [(Name "main", e')] → e'
    res → error $ caller <> ": unexpected result: " <> show res

emptyUberModule ∷ UberModule
emptyUberModule =
  UberModule
    { uberModuleForeigns = []
    , uberModuleBindings = []
    , uberModuleExports = []
    }
