# Teleporters and launch triggers

Traversal uses `Traversal` nodes connected to `Destination` nodes by `ArrivesAt`
edges. `TraversalTick` runs after walking and touch activation in the fixed-step
simulation. It shares the existing expanded brush-volume collision queries.
Escape pauses traversal; fly mode does not activate it.

Implemented:

- Q1 ordinary `trigger_teleport` → `info_teleport_destination` and Q3 ordinary
  `trigger_teleport` → destination markers. Position, view direction and exit
  velocity change together; grounded state is cleared.
- Solid-world destination checks reject the entire teleport. A short player
  cooldown prevents immediate bounce loops, and a teleport stops processing
  the old movement segment against additional traversal triggers that tick.
- Q2 `misc_teleporter` point pads and `misc_teleporter_dest` exits, including
  solid pad bases, expanded player contact, a 10-unit exit offset, cleared
  velocity and a 0.16-second arrival hold. Pad models/effects remain unrendered.
- Q1/Q2 directional `trigger_push`, including one-shot pushes.
- Q3 `trigger_push` velocity calculated from the brush model's authored center
  and its target apex, using the same 800-unit gravity as walking.
- Arriving telefrags whoever the arriving body overlaps (Q1 `spawn_tdeath`, Q2
  `KillBox`, Q3 `G_KillBox`), through armor and invulnerability. The kill counts
  for the player. Q3 telefrags only players and bots, and bots teleporting onto
  the player telefrag them too.
- All BSP adapters retain model bounds. Trigger-volume extraction is shared
  with the existing door/button activation system.

This remains partial traversal support. Named
or scripted teleport activation, randomized destination selection,
teleport effects/sounds, Q1/Q3 post-teleport input lock timing and
crouching are not implemented. Initial liquid movement is described in
[swimming status](swimming-status.md). Missing/ambiguous targets and unsupported flags
are not activated. The collision-safe exit rejection and 0.2-second teleport
cooldown are intentional interim behavior, not exact original-game parity.

## Validation

The full suite passes 95 tests. Focused fixtures cover swept contacts, atomic
blocked exits, no same-tick teleport chains, cooldown/pause/fly behavior,
one-shot pushes, independent launch velocity state, target validation and the
Q3 ballistic apex calculation. Q2 fixtures additionally cover destination
placement/orientation, cleared velocity, supporting pad collision, and arrival
hold expiry before normal physics resumes.

Native asset checks pass 28 Q1, 13 Q2 and 32 Q3 traversal contacts across the
sampled maps. These check loaded brush contacts, safe destination placement and
launch velocities; they do not prove every jump lands at its original-game
endpoint under the current shared movement approximation.

Use the local compiler in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md):

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac
export JAC_COMPILER_LIB=off
jac test
jac build scripts/validate_traversal.jac --native -o .jac/qp-traversal-check
QP_GAME=q1 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-traversal-check
QP_GAME=q2 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-traversal-check
QP_GAME=q3 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-traversal-check
jac build scripts/traversal_smoke.jac --native -o .jac/qp-traversal-smoke
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-traversal-smoke
```

Behavior references: id Software's [Q1 triggers](https://github.com/id-Software/Quake/blob/master/qw-qc/triggers.qc),
[Q2 triggers](https://github.com/id-Software/Quake-2/blob/master/game/g_trigger.c),
[Q3 triggers](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_trigger.c)
and [Q3 teleport placement](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_misc.c).

Desktop app checks pass for Q1 `e1m2` teleporting, Q2 `jail1` pushing,
Q3 `q3dm6` launching and Q3 `q3dm7` teleporting. All four check Escape pause
before activation through the app's walking loop. Launch checks additionally
advance 30 physics ticks and verify displacement. Destination/in-flight captures
were inspected; local screenshots and logs are in `.jac/screenshots/traversal/`.
These validate traversal and continued rendering, not landing parity or material
completeness (existing Q3 shader and sky limitations remain).

Q2 point-pad follow-up: the five-scenario desktop harness additionally passes
`base3` teleporting through the app's walking loop, with Escape pause before
activation. Its destination capture was inspected. The four earlier desktop
scenarios still pass. The runnable `qp` binary has been rebuilt with this support.
