# Shared touch-trigger milestone

Supported `trigger_once` and `trigger_multiple` brush volumes now activate named
translating doors in Q1, Q2 and Q3. Walk mode is required for touch activation;
fly mode does not fire triggers. Escape pauses both movement and trigger timers.

## Shared behavior

`TouchTrigger` nodes connect to door-group leaders through `Activates` edges.
`TriggerTick` sweeps the standing player's previous/current position against the
actual brush volume at the fixed physics rate; crossing a thin trigger between
ticks still registers. `Activate` traverses target edges and requests door motion
on the next physics tick. Named doors do not open merely from proximity.

Trigger hulls are separate from solid-world collision. Q1 uses its authored
standing-player clip hull; Q2/Q3 use the shared expanded convex-brush queries.
Linked door members move together even when the target name is on a nonleader.
One-shot triggers disable after firing; repeat triggers honor their wait, and
negative wait also makes a trigger one-shot.

## Limits

Only direct touch-to-supported-door relationships are enabled. Delayed, random,
directional, shootable, externally enabled, and killtarget triggers are excluded.
A target fan-out containing an unsupported recipient is excluded as a whole.
General relay chains, buttons, lifts, jump pads, teleporters, messages, sounds and
original-game scripting parity remain future work. Unsupported door types retain
the limits described in the [door milestone](doors-status.md).

## Validation

Use the patched compiler documented in [the build instructions](doors-status.md#build-and-validate).

```sh
jac test
jac build scripts/validate_triggers.jac --native -o .jac/qp-trigger-check
QP_GAME=q1 .jac/qp-trigger-check
QP_GAME=q2 .jac/qp-trigger-check
QP_GAME=q3 .jac/qp-trigger-check
jac build scripts/door_smoke.jac --native -o .jac/qp-trigger-smoke
QP_TRIGGER_TEST=1 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-trigger-smoke
```

Four trigger tests cover exact brush contact, swept contact, non-solid sensor
volumes, pause, flight, cooldown, one-shot behavior and unsupported target fan-out.
The full suite passes 78 tests. Native asset checks pass 19 triggers across a
16-map sample: 12 Q1, 5 Q2 and 2 Q3 triggers. Each game must exercise at least one
trigger; empty maps cannot make the whole run pass. Existing proximity-door
checks still pass 17 groups, and movement checks pass 12 maps including 96 Q3
solid-patch probes.

The graphical harness passes Q1 `e1m1`, Q2 `ware1`, and Q3 `q3dm11`:
App-driven contact opens the door, menu pause prevents activation, and a
standing-player trace changes from blocked to clear. Closed/open captures for
all three were visually inspected and saved in `.jac/screenshots/triggers/`.
The ordinary-door graphical harness also still passes all three games.

The main native executable has been rebuilt. For example:

```sh
QP_GAME=q3 QP_MAP=q3dm11 QP_WALK=1 ./qp
```

The graphical menu regression also passes settings/reset, walking/grounding,
Escape/capture/pause, scrolling/selection, cross-game switching, load failure and
quit. This milestone was validated with the local compiler containing #9347;
no new compiler workaround was added.
