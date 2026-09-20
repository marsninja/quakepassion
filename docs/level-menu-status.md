# Escape level menu

Run `./qp`, then press **Escape** to open the menu. Escape again resumes the
current level. Choose a game tab, select a map with the mouse or Up/Down, and
click **Render selected level** or press Enter. Mouse-wheel scrolling reaches
long lists. **Quit** exits the application; the window close button also works.

The menu lists archive contents from `~/quake-assets/id1`, `baseq2`, and `baseq3`.
`QP_ASSETS` overrides only the initial `QP_GAME` directory. Duplicate names are
collapsed; Q1 BSP brush models without player starts are filtered out. Supplied
assets provide 38 Q1 levels, 47 Q2 levels, and 36 Q3 levels.

Movement and simulation pause while the menu is open. The cursor is released
for menu use and restored to its prior capture state on resume. Loading creates
a new world graph, player, and GPU resources before replacing the current level.
Failures leave the current level intact and display an error in the menu.
The first frame after loading excludes loading time from movement integration.

## Validation

The native regression checks pass with the released Jac 0.37.21 compiler.
All 44 unit tests passed on the first run with Jac 0.37.21, including catalogue deduplication
and distinguishing Q1 levels from brush models. Repeated full-suite runs currently
hit a [Jac compiler crash](validation-tooling-status.md).
The menu's native graphical test feeds raylib keyboard,
mouse, and wheel events through the same `App.step()` loop used by the viewer:

- Escape opens/closes the menu, restoring captured mouse state.
- Movement input does not move the player while the menu is open.
- Scrolling clamps at both list boundaries; mouse/keyboard selection works.
- Q1 e1m1 -> start -> Q2 base1 -> Q3 q3dm1 -> Q1 e1m1 loads in one process.
- A missing-map load preserves the current Q3 level and reports the failure.
- Quit ends the loop and the window and GPU resources close normally.

```sh
jac run scripts/validate_menu.jac
```

An active desktop and all three games' original assets are required. Screenshots
and logs are saved under `.jac/screenshots/menu/`. The menu and post-switch views
were visually inspected on macOS arm64. Loading and archive scanning are
synchronous; the fixed layout matches the viewer's 1280x720 window.

## Compiler fixes included in Jac 0.37.21

These upstream fixes ship in Jac 0.37.21. Fresh setup is documented in README.

- [Jac #9327](https://github.com/jaseci-labs/jac/pull/9327): `sorted()` supports
  iterable inputs, including the catalogue's set of map names.
- [Jac #9336](https://github.com/jaseci-labs/jac/pull/9336): scalar C results are
  no longer reinterpreted as unrelated same-width structs. The old compiler
  converted `GetMouseX()`'s i32 result into a `Color` pointer, breaking `int()`.

The engine retains both original idioms instead of working around the compiler.
The asset-free sorting reproduction remains in `scripts/repros/native_sorted_set.jac`;
scalar/struct JIT and standalone regressions are included in upstream PR #9336.
