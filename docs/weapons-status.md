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
work includes Q2 hand-grenade cooking, BFG secondary lasers/explosion phases,
chaingun spin-up, original recoil/animation/viewmodels, water/lightning discharge,
exact game-specific muzzle offsets and spread sequences, projectile models and
impact/trail effects, weapon switching/autoselection timing, dropped weapons,
powerups, and bot use of the arsenal. Projectiles currently render as small
markers. Q3 model materials still report partial support for several animated
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
