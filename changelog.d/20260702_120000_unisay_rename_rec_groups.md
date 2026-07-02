### Fixed

- `renameShadowedNames` no longer miscompiles local recursive groups. The
  member list of every local `RecursiveGroup` came out reversed, undoing the
  initialization order computed by the laziness transform, so an eager member
  (such as the `name = Lazy_name(0)` forcing binding of a runtime-lazy group)
  could run before the member it reads was assigned and crash with an
  "attempt to call a nil value" at runtime. Additionally, when a group member
  shadowed an outer binder, self- and forward references inside the group kept
  the old name and silently rebound to the outer binder, severing the
  recursion. Member RHSs are now renamed in the complete group scope and the
  member order is preserved (#133).
