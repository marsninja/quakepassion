# Original-game weapon integration

Q1, Q2 and Q3 now use game-specific weapon descriptions with a single shared
combat simulation. Passion retains its previous two-weapon rules while original
game work takes priority.

Implemented:

- Owned weapon inventory, original starting loadouts, weapon/ammo pickups and
  per-game capacities. Keys **1–9**, and **0** for Q2's BFG, select owned weapons
  with ammo; the mouse wheel and `/` cycle them (see
  [player-feedback-status.md](player-feedback-status.md) for switching,
  autoswitch, knockback, explosions and trails).
- Pellet spread with a saved random stream; damage aggregates before armor and
  death callbacks. Rails penetrate opponents but stop at world geometry.
- Traveling bolts, nails, rockets, plasma and BFG projectiles, swept impact
  detection, grenade gravity/bounce/fuses, splash visibility, self-damage and
  each game's knockback. Active projectiles live in the world graph and survive saves.
- Shot and blast damage to Q2 destructible brushes and shot activation of Q1
  secret doors. Opponent deaths use the shared target/kill-credit path.
- Weapon names and current ammo in the HUD; archive-backed weapon sounds are
  decoded at level load, avoiding asset reads on the firing path.
- Q2 trigger-spawn pickups and Q3 targeted pickup activation; Q3 item categories
  have distinct respawn delays, with authored `wait` overrides. Hidden targeted
  items cannot appear from their respawn timer before first activation.

The native asset/simulation harness (`scripts/weapon_smoke.jac`) passes for
8 Q1, 11 Q2 and 9 Q3 configured weapons and 45 unique weapon/ammo model assets.
`scripts/weapon_audio_smoke.jac` decodes and plays all 28 firing sounds. Focused
regressions check ownership, capped pickup acceptance, armor aggregation, rail
penetration, thin-wall projectile sweeps, splash occlusion, death credit,
grenade bounce/fuse and deterministic save restoration.

These are functional arsenal foundations, **not full weapon fidelity**. Remaining
work includes BFG immunity rules, exact original recoil/animation, exact
game-specific muzzle offsets and spread sequences, remaining projectile
materials, impact marks, dropped weapons,
powerups, and bot use of the arsenal. Original MDL/MD2/MD3 models now cover nails,
bolts, grenades and rockets. Q2 BFG flight/explosion effects use the original
animated SP2/PCX assets; Q3 plasma uses its additive rotating sprite and the Q3
BFG flies as `models/weaphits/bfg.md3`. Q3 model materials still report partial support for several animated
shader stages. Team-linked pickups, Q2 no-touch items, floor placement/riding
movers, and Q3 randomized respawn timing also remain open.

Weapon parameters are adapted from the original
[Q1 weapon logic](https://github.com/id-Software/Quake/blob/master/QW/progs/weapons.qc),
[Q2 weapon logic](https://github.com/id-Software/Quake-2/blob/master/game/p_weapon.c),
[Q3 weapon logic](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_weapon.c)
and [Q3 missile logic](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_missile.c).
Item activation follows
[Q2 items](https://github.com/id-Software/Quake-2/blob/master/game/g_items.c) and
[Q3 items](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_items.c).

## Integrated checkpoint

The complete local suite passes **212 tests** with the documented source compiler.
The native viewer builds, and Q1 `e1m1`, Q2 `base1` and Q3 `q3dm1` graphical
checks pass textured frames, camera movement and exact PVS/all-visible image
agreement. Native combat checks use the real starting weapons, verify deaths
and snapshots, and complete a ten-frag Q3 respawn loop. This is controlled
acceptance, not a full campaign playthrough.

A local M5 gameplay sample with models and audio enabled measured median frames
of 3.87 ms (Q1), 8.26 ms (Q2), 6.99 ms (Q3) and 4.20 ms (Passion). Q1/Q2/Q3 p95
frames were 5.69/9.51/8.53 ms. A regression-test process was running concurrently;
these are indicative samples, not an isolated performance comparison or a claim
that every map meets a frame-time budget.


## Q2 BFG energy phases

The Q2 BFG now has 10 Hz piercing laser tendrils, a 200-point core impact and
short-radius blast, followed by a delayed 500-point energy effect with square-root
falloff. The delayed effect requires visibility from both the orb and shooter.
Projectile phase, timers and random state survive snapshots; kill callbacks still
run once. Dedicated tests cover tendril cadence/penetration/occlusion, distinct
core and burst damage, restored pending effects, and shooter-side occlusion.
The native original-map combat harness verifies the complete phase sequence and
cleanup in Q2 `base1` alongside the Q1/Q3 combat checks. Implementation follows
[Q2 projectile logic](https://github.com/id-Software/Quake-2/blob/master/game/g_weapon.c).

The sprite path validates SP2 frame tables and pivots, decodes PCX palette-index
transparency without changing model-skin alpha, and renders depth-tested camera
billboards with ordered blending. Sprite textures load with the level and are
released on switches. Captured Q2 `base1` flight and explosion frames confirm
original sprite art replaces the debug boxes. Cosmetic animation age and effect
selection are saved alongside projectile state.


## Hand grenades and empty-weapon selection

Q2 hand grenades are selected with **G** once grenade ammunition is owned. The
fixed-step state machine handles priming, cooking, release, throw delay, fuse-
dependent launch speed and in-hand detonation. Weapon switching cannot cancel a
live grenade. The held-explosion latch prevents repeated detonation until release.
Cooldowns, spread state and live-grenade timers carry across campaign transitions
and snapshots. Empty weapons fall back through the game rules to an owned,
usable weapon; Q1 avoids choosing lightning underwater.

Four focused tests cover early release, single ammo consumption, held detonation,
menu/simulation pause, restored throw fuse/speed and empty-weapon fallback. Native
arsenal and audio acceptance now cover **28 weapons**. The original-map campaign
smoke additionally carries a cooking grenade from Q2 `base1` to `base2`, saves,
reloads and revisits the hub while preserving its state. That harness uses an
explicit test save path instead of changing HOME or overwriting the user's save.
Pin/cooking sound loops, exact first-person animation timing, dropped live grenades on death,
and exact weapon-raise/lower timing remain open.

Original first-person gun models and basic firing/idle/raise poses are now
integrated for all 28 weapons. See [viewweapon status](viewweapons-status.md)
for asset validation and the remaining animation/presentation gaps.

## Original projectile rendering

The shared effect scene loads Q1 nails, grenades and rockets; Q2 blaster bolts,
both grenade models and rockets; and Q3 grenades, rockets and plasma. Models
follow projectile pitch/yaw, with grenade roll driven by simulation age. The
ordinary actor renderer retains its existing yaw-only path. Asset loading and
texture ownership stay outside the firing path, with cleanup on level changes.

Q3 rocket flare surfaces use their authored additive blending and two-sided
rendering. Model `animMap` stages retain their image sequence and frequency,
including the grenade's red/green overlay. This follows the original
[Q3 shader parser](https://github.com/id-Software/Quake-III-Arena/blob/master/code/renderer/tr_shader.c).
Other unsupported model shader operations still report partial support rather
than silently claiming fidelity. Q3 BFG autosprite/deformation stages, projectile
smoke trails and impact marks remain unfinished.

`scripts/projectile_scene_smoke.jac` loads and draws all 12 configured effects
and verifies animated grenade stages and additive rocket flare setup. Focused
tests cover orthonormal pitch/roll transforms, inverse transforms, cull parsing,
animation frame boundaries and line-delimited animation image lists.

The native gallery passes for all 12 effects, including resource cleanup; the
main application builds successfully. The weapon/orientation/material focused
run passed 20 tests, followed by seven material/orientation checks after animated
stages were added. A subsequent M5 gameplay sample measured median/p95 frames of
3.25/5.03 ms (Q1), 6.04/8.35 ms (Q2), 5.18/7.04 ms (Q3) and 3.79/5.12 ms
(Passion). These fixed-scene samples do not establish performance for every map
or heavy projectile combat.

After the hand-grenade and campaign-carry changes, the full local suite passes
**221 tests**. Native arsenal checks pass for all 28 configured weapons, and
native campaign acceptance passes the live-grenade carry/save scenario.
