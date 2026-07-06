### Changed

- A field projection off a foreign module with a header no longer keeps the
  whole exports table behind an IIFE call: the Lua optimizer moves the
  projection into the call body, where the existing table-constructor fold
  picks out the single export. The rule declines when a leading statement of
  the called function contains a body-level early return (#159).
