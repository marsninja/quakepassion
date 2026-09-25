# Shared buttons and relay activation

Translating touch buttons (`func_button`) now use the same mover simulation and
render/collision transforms as doors. Physical contact starts the press; reaching
the pressed endpoint emits the target signal. The button waits, then returns.
Named Q1/Q3 buttons remain touchable; named Q2 buttons require use. Fly mode does not press buttons; Escape pauses
motion and dispatch.

`Signal` nodes and `Targets` edges connect map entities. `Fire` walks relay
chains, deduplicating visits so cycles terminate and diamond-shaped fan-outs do
not activate the same recipient twice. Door group members resolve to their
leader's signal. A recipient without a use is skipped and the rest of the chain
still fires, as SUB_UseTargets/G_UseTargets do (see [level flow](level-flow-status.md)).

Supported relays are immediate, unflagged `trigger_relay`/`target_relay` entities.
Shootable buttons accept direct weapon damage and unobstructed explosion damage.
They accumulate damage until their authored health is depleted, then use the
same press/target/return sequence. Damage is disabled while pressed or pressing
and resumes during return. Partial health and pending shot activation survive
save/load. Q2 buttons default to a three-second wait.

Shootable ordinary doors, killtarget, button teams, sounds, texture-state
animation, and remaining conditional map scripting are still incomplete. Doors emit output at the open endpoint; exact per-game use-target
ordering is not claimed. Shared lifts and trains have separate status documents.

## Validation

The full suite passed 82 tests after signal integration, including cycle/diamond
dispatch, button contact/endpoint emission, disabled targets and a map-defined
button → relay → named-door chain. Asset-backed validation exercises 26 buttons:
14 Q1, 11 Q2, and one Q3 (`q3dm7`), plus the existing 19 touch triggers.

Use the local compiler fix described in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md):

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-lighting-validation/jac
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

## Damage and spawn-rule regression coverage

`tests/shoot_button_tests.jac` covers damage thresholds, contact rejection,
endpoint-only output, repeated use, saved partial damage and queued activation,
and explosion occlusion. `tests/spawn_filter_tests.jac` covers the normal-campaign
and local-arena entity selection that must happen before target links are built.
The native campaign harness checks Q2 `base1` starts without a free secret and
awards its authored `t91` secret only after model 13 is damaged and presses.

Sources: [Q2 buttons](https://github.com/id-Software/Quake-2/blob/master/game/g_func.c)
and [Q3 buttons](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_mover.c).

The expanded full suite passes 237 tests, and all four native campaign markers
(startup filtering, shootable secret, hub persistence, Q1 key route) pass.
