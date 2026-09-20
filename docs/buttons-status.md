# Shared buttons and relay activation

Translating touch buttons (`func_button`) now use the same mover simulation and
render/collision transforms as doors. Physical contact starts the press; reaching
the pressed endpoint emits the target signal. The button waits, then returns.
Named buttons remain touchable. Fly mode does not press buttons; Escape pauses
motion and dispatch.

`Signal` nodes and `Targets` edges connect map entities. `Fire` walks relay
chains, deduplicating visits so cycles terminate and diamond-shaped fan-outs do
not activate the same recipient twice. Door group members resolve to their
leader's signal. A missing or unsupported recipient disables the entire source
chain, rather than executing a partial map script.

Supported relays are immediate, unflagged `trigger_relay`/`target_relay` entities.
Shootable buttons, delayed/randomized/conditional relay behavior, killtarget,
button teams, sounds, texture-state animation, and general map scripting are not
implemented. Doors emit output at the open endpoint; exact per-game use-target
ordering is not claimed. Lifts and gameplay remain separate roadmap stages.

## Validation

The full suite passed 82 tests after signal integration, including cycle/diamond
dispatch, button contact/endpoint emission, disabled targets and a map-defined
button → relay → named-door chain. Asset-backed validation exercises 26 buttons:
14 Q1, 11 Q2, and one Q3 (`q3dm7`), plus the existing 19 touch triggers.

Use the local compiler fix described in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md):

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac
export JAC_COMPILER_LIB=off
jac test
jac build scripts/validate_buttons.jac --native -o .jac/qp-button-check
QP_GAME=q1 .jac/qp-button-check
QP_GAME=q2 .jac/qp-button-check
QP_GAME=q3 .jac/qp-button-check
jac build scripts/door_smoke.jac --native -o .jac/qp-buttons-smoke
QP_BUTTON_TEST=1 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-buttons-smoke
```

Desktop validation now passes for Q1 `e1m1`, Q2 `base1`, and Q3 `q3dm7`.
The harness checks physical contact, Escape pause, movement and endpoint dispatch;
closed/pressed captures were inspected for all three games. Captures are local
artifacts in `.jac/screenshots/buttons/` (game assets are not committed).
