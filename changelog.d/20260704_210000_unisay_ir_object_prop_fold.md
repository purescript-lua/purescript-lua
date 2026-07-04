### Changed

- Record-literal projections are now folded in the IR optimizer
  (`reduceObjectProp`): `{ foo: 1, bar: 2 }.foo` reduces to `1`, and a
  projection through a record update takes the patched value or reaches into
  the updated record. Running inside the optimize+dce fixpoint lets the folded
  value feed inlining, beta reduction, and dead-code elimination, so dictionary
  records that only existed to be projected disappear from the generated Lua
  along with the wrapper functions around their members. The Lua-AST rule
  `reduceTableDefinitionAccessor` still handles constructors that only
  materialize during lowering, such as projections out of foreign modules
  (#153).
