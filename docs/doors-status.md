# Shared moving-door milestone

Ordinary proximity-activated `func_door` brushes now open, hold, and close in
Q1, Q2 and Q3. Approach in walk or fly mode; Escape pauses simulation. Suggested
maps are Q1 `e1m1`, Q2 `base2`, and Q3 `q3dm2`.

## Shared behavior

`Door` nodes are connected by `DoorLink` edges: touching brushes in Q1 and named
teams in Q2/Q3. `AssembleDoors` traverses those relationships and attaches each
supported group's leader to the world. `DoorMember` edges retain its parts.
`DoorTick` advances the whole group at the player's 120 Hz physics rate.

Members finish together using the longest authored travel time. Before applying
any movement, every member sweeps the standing player's origin in its moving
collision frame. A blocked opening stops; a blocked closing reverses. A blocked
member prevents all members from moving that tick. This deliberately avoids
crushing or pushing the player; riding movers is not implemented.

Rendering and collision use the same absolute translation. Original vertices
and hull planes remain unchanged, preventing accumulated drift. Planar face
culling accounts for motion; collision-tree bounds include the entire supported
travel, so an opened door is still found outside its original bounds.

Authored direction, speed, lip and wait are read once at load. Negative wait
keeps the door open. Q1/Q2 defaults are speed 100 and wait 3; Q3 defaults are
speed 400 and wait 2. The shared proximity volume extends 60 units horizontally
and 8 vertically, then includes standing-player extents; this is an approximation
of the games' differing trigger rules. Travel is derived from visible model
bounds. See the original [Q1 doors](https://github.com/id-Software/Quake/blob/master/qw-qc/doors.qc),
[Q2 movers](https://github.com/id-Software/Quake-2/blob/master/game/g_func.c), and
[Q3 movers](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_mover.c).

## Deliberate limits

Named doors can now receive direct brush-touch activation; see the
[touch-trigger milestone](triggers-status.md). Shootable, keyed, start-open, toggle,
crusher, secret, and rotating doors remain static. General target/killtarget
dispatch, acceleration/deceleration, sounds and
damage are not implemented. A group with an unsupported member stays entirely
static, including teams containing another mover class. Lifts, trains and buttons
are still static. This is a traversal milestone, not original-game behavior parity.

## Build and validate

Use the local compiler containing [upstream PR #9347](https://github.com/jaseci-labs/jac/pull/9347)
until a compiler with that fix is available:

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-layout-cache/jac
export JAC_COMPILER_LIB=off
jac build main.jac --native -o qp
QP_GAME=q3 QP_MAP=q3dm2 QP_WALK=1 ./qp

jac test
jac build scripts/validate_doors.jac --native -o .jac/qp-door-check
QP_GAME=q1 .jac/qp-door-check
QP_GAME=q2 .jac/qp-door-check
QP_GAME=q3 .jac/qp-door-check
jac build scripts/door_smoke.jac --native -o .jac/qp-door-smoke
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-door-smoke
```

On Linux, use `LD_LIBRARY_PATH` for the last command. The graphical harness needs
an active desktop and original assets; its `qp_door_*` screenshots are ignored.

Eight door unit tests cover timing, repeated cycles, transformed collision,
negative wait, zero-time pause, blocking, group synchronization, and restricted
activation. Real-map validation covers 17 groups across 14 maps (5 Q1, 3 Q2, 9 Q3
groups). Maps without eligible doors explicitly report zero; each game's run
requires at least one tested group. Q3's previous dm1/dm7/tourney2 sample was not
sufficient coverage for proximity doors.

The native graphical harness verifies player-sized traces blocked before opening
and clear afterward in `e1m1`, `base2`, and `q3dm2`; it also exercises App-driven
door ticks and menu pause/resume. Closed/open captures for all three games were
visually inspected. The complete unit suite passes 78 tests.

The existing graphical menu harness also passes settings, walking, grounding,
pause, map switching and quit checks. Native movement checks pass on the original
12-map sample, including all 96 Q3 solid-patch probes. Captures from this run are
saved under `.jac/screenshots/doors/`.

## Campaign damage activation update

Q1/Q2 `func_door` brushes with health now accept weapon and explosion damage.
Q1 linked brushes share the leader's damage threshold; Q2 team members retain
individual thresholds. Depleting a threshold activates the entire group and
resets its health. Proximity does not activate these doors. Damage is accepted
again during return travel. Buttons retain their separate contact and endpoint
activation rules.

Campaign doors dispatch targets when opening starts, matching the original
mover implementations. Save format 6 includes partial damage for every linked
part and rejects earlier snapshots. Unit coverage exercises thresholds, ignored
shots during opening, returning-door reversal, linked parts, explosions and
save restoration. `scripts/shoot_door_smoke.jac` exercises eligible authored
health doors in the installed campaign maps and checks render/collision motion.

The older limits above describe the initial milestone: translating platforms,
trains, buttons, Q1 keys and Q1 two-stage secret doors have since been implemented.
Start-open/toggle/rotating/crushing ordinary doors, unsupported target chains,
Q3 shot doors and exact original timing/sounds still need work. An unsupported
member or target chain continues to keep its group static.

Validation: the full suite passes **240 tests**. The original-map audit passes
13 groups across 10 maps (Q1: seven groups, including the four-part `e4m2` door;
Q2: six groups, including the paired `city3` door). This audit ran through Jac's
server execution path because its archive-inventory decoding uses an
[unsupported native error-policy argument](native-decode-errors-blocker.md).
The native viewer builds successfully with the documented source compiler.

## Start-open and toggle update

Start-open doors now initialize every linked face and hull at the far endpoint
and traverse the reversed authored path. Q1/Q2 toggle doors wait at both endpoints
and reverse smoothly when activated while moving. Proximity activation is
throttled to one request per second; that timer is saved. Q1 DONT_LINK brushes
remain independent. Q3 start-open behavior has synthetic coverage; its original
maps in the installed inventory did not contain these flags.

Four tests cover initial transforms, linked members, intermediate save restoration,
toggle reversal/endpoint waits and contact debounce. Native
`scripts/mover_flags_smoke.jac` passes 24 original groups across six campaign maps:
19 start-open groups and five toggle groups. Crusher and rotating doors remain
unsupported. Save format 8 rejects older layouts explicitly.
