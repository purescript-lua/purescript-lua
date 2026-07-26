-- Record surgery (Record.Unsafe) over statically-known and unknown
-- records, and the identity foreign (Unsafe.Coerce.unsafeCoerce).
module Golden.RecordSurgery.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)
import Effect.Ref as Ref
import Record.Unsafe (unsafeDelete, unsafeGet, unsafeHas, unsafeSet)
import Unsafe.Coerce (unsafeCoerce)

-- Surgery on manifest record literals.
inserted :: { a :: Int, b :: Int }
inserted = unsafeSet "b" 2 { a: 1 }

replaced :: { a :: Int }
replaced = unsafeSet "a" 3 { a: 1 }

deleted :: { b :: Int }
deleted = unsafeDelete "a" { a: 1, b: 2 }

got :: Int
got = unsafeGet "a" { a: 42 }

present :: Boolean
present = unsafeHas "a" { a: 1 }

absent :: Boolean
absent = unsafeHas "z" { a: 1 }

coerced :: Int
coerced = unsafeCoerce 7

main :: Effect Unit
main = do
  ref <- Ref.new { k: 9, n: 1 }
  dyn <- Ref.read ref
  logShow (inserted.a + inserted.b)
  logShow replaced.a
  logShow deleted.b
  logShow got
  logShow present
  logShow absent
  -- A record the optimizer cannot see through: get reads the field
  -- directly, while the copying surgeries stay foreign calls.
  logShow (unsafeGet "k" (unsafeSet "k" (unsafeGet "k" dyn + 1) dyn) :: Int)
  logShow (unsafeHas "k" (unsafeDelete "k" dyn))
  logShow coerced
