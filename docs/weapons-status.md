# Original-game weapon integration

Q1, Q2 and Q3 now use game-specific weapon descriptions with a single shared
combat simulation. Passion retains its previous two-weapon rules while original
game work takes priority.

Implemented:

- Owned weapon inventory, original starting loadouts, weapon/ammo pickups and
  per-game capacities. Keys **1–9**, and **0** for Q2's BFG, select owned weapons.
- Pellet spread with a saved random stream; damage aggregates before armor and
  death callbacks. Rails penetrate opponents but stop at world geometry.
- Traveling bolts, nails, rockets, plasma and BFG projectiles, swept impact
  detection, grenade gravity/bounce/fuses, splash visibility, self-damage and
  blast knockback. Active projectiles live in the world graph and survive saves.
- Shot and blast damage to Q2 destructible brushes and shot activation of Q1
  secret doors. Opponent deaths use the shared target/kill-credit path.
- Weapon names and current ammo in the HUD; archive-backed weapon sounds are
  decoded at level load, avoiding asset reads on the firing path.
- Q2 trigger-spawn pickups and Q3 targeted pickup activation; Q3 item categories
  have distinct respawn delays, with authored `wait` overrides. Hidden targeted
  items cannot appear from their respawn timer before first activation.

The native asset/simulation harness (`scripts/weapon_smoke.jac`) passes for
8 Q1, 10 Q2 and 9 Q3 configured weapons and 45 unique weapon/ammo model assets.
`scripts/weapon_audio_smoke.jac` decodes and plays all 27 firing sounds. Focused
regressions check ownership, capped pickup acceptance, armor aggregation, rail
penetration, thin-wall projectile sweeps, splash occlusion, death credit,
grenade bounce/fuse and deterministic save restoration.

These are functional arsenal foundations, **not full weapon fidelity**. Remaining
work includes Q2 hand-grenade cooking, BFG charge animation/timing and immunity rules,
chaingun spin-up, original recoil/animation/viewmodels, water/lightning discharge,
exact game-specific muzzle offsets and spread sequences, projectile models and
impact/trail effects, weapon switching/autoselection timing, dropped weapons,
powerups, and bot use of the arsenal. Most projectiles currently render as small
markers; Q2 BFG flight/explosion effects use the original animated SP2/PCX assets. Q3 model materials still report partial support for several animated
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
