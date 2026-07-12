### Fixed

- A name declared as a `foreign import` but missing from the table its FFI
  file returns is now a compile-time error naming the module and the missing
  names, instead of compiling to a field read that surfaces at runtime as a
  `nil`. The check runs on the DCE-pruned name list, so only names the
  emitted code would actually read are required; undeclared extra exports
  are still dropped silently (#249).
