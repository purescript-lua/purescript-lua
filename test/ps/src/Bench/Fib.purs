-- Source-identical to the `fib` in Golden.Fibonacci.Test: recursion with
-- typeclass arithmetic, without the golden's stdout side effect, so a
-- benchmark driver can call it repeatedly and time it in-process.
module Bench.Fib where

import Prelude

fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)
