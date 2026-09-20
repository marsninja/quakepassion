# Gameplay and rendering implementation plan

Requested scope: buttons/target chains; riding lifts; traversal mechanics;
pickups/combat/enemies/per-game rules; materials/sky/shaders/models/effects.
These are tracked separately so partial support is not presented as game parity.

1. Shared activation graph and moving buttons, with cycle-safe relay dispatch.
2. Translating platforms carrying the player, with transactional collision checks.
3. Teleporters, jump pads, liquid movement and crouching.
4. Shared damage, inventory, projectiles and AI; game-specific data and rules.
5. Asset model loading/animation and expanded material effects.

Each stage requires focused unit fixtures and representative native asset checks.
Graphical changes additionally require captures on the local desktop. Existing
movement/menu/door checks remain regressions. Compiler defects are reported with
minimal repros; no engine rewrite to conceal a language/runtime defect.

As of the start of this work, upstream #9347 remains open. Builds use the local
`qp-cache-sections` compiler described in `native-cache-section-merge-blocker.md`.

## Current checkpoint

Stage 1 has shared signal/relay nodes, target resolution, moving buttons and
focused fixtures. The full engine suite passes 100 tests. Native asset checks
pass 26 buttons (14 Q1, 11 Q2, 1 Q3) and the existing 19 touch triggers.
A local root-cause fix for the [cache-section merge defect](native-cache-section-merge-blocker.md)
unblocked validation. Stage 2 now shares mover transforms and transactional
collision checks for translating platforms and their riders. Asset checks cover
33 Q1/Q2 platform cycles and 30 carrying probes; Q3 platform semantics are covered
by unit fixtures because the supplied Q3 maps contain no `func_plat` entities.
Stage 3 now includes initial Q1/Q2/Q3 teleporters, Q1/Q2 push volumes and Q3
jump pads. Initial liquid detection and swimming now work across all three
games; see [swimming status](swimming-status.md). Crouching, water ledge jumps
and per-game traversal refinements remain. Stages 4–5 have not
started. See [traversal status](traversal-status.md).

Graphical button validation passes for all three games.
See [button status](buttons-status.md) and [platform status](platforms-status.md).

Before crouching, collision queries need a shorter player hull shared by walking,
movers, trigger contacts and teleport exit validation, plus a clearance check
before standing up. Q1's precompiled standing hull cannot simply be resized.
Swimming now uses separate point-content queries for feet/body/head, including
Q2/Q3 liquid brushes. Crouching must similarly update collision behavior, not
just the camera.
