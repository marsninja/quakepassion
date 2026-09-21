# Combat prototype progress

The shared engine now has finite hitscan weapon queries against level geometry and
living opponents. `Aim` and `CombatTick` walkers operate on the world/opponent
graph; the existing `Damage` and inventory walkers apply health, armor and ammo.

## Implemented locally

- Mouse button 1 fires while mouse capture is active; the capture warmup prevents
  the click that captures the mouse from immediately firing.
- Keys 1/2 select an unlimited basic shot or a stronger shell-consuming shot.
  Both have simulation-time cooldowns, a crosshair, hit feedback and kill counts.
- Q1 soldiers and Q2 soldier/infantry variants bind original MDL/MD2 resources.
  Opponents turn, pursue in line of sight, collide with world geometry and fire.
  Animation uses the model's run frames. This is intentionally a small shared
  prototype behavior, not original game AI or weapon fidelity.
- Q3 has up to three box-shaped training bots, three-second respawn, a ten-frag
  win threshold and Enter to rematch. Bots avoid the initial player spawn.
- Menus suspend simulation; death blocks firing and Enter reloads the level.
- Archive-backed shooting, pain and pickup sounds use native raylib audio.
- F5/F9 save/load and persistent menu settings are drafted, including entity,
  inventory, mover, trigger and signal state. Restores build a replacement world
  before replacing the current one. Native file replacement and save restoration
  now pass with the combined upstream fixes; settings reload is blocked by
  [native splitlines](native-splitlines-blocker.md).

## Validation and limits

The full regression run passes 148 collected tests (118.86 seconds).
Four combat fixtures cover nearest targets, world occlusion, health/death,
weapon cooldowns/ammo, bounds and arena respawn. Two save fixtures cover round
trip state and rejection of mismatched/incomplete snapshots.

Before persistence was added, `scripts/combat_smoke.jac` built and passed on Q1
`e1m1`, Q2 `base1` and Q3 `q3dm1`; original soldier models and the Q3 training bots
were inspected in captures. The expanded harness now also exercises sound and
save I/O. It reaches Q1 save replacement and exposes
[native-os-replace-blocker.md](native-os-replace-blocker.md).

The latest combined-compiler run passes the full combat harness on all three
games, including audio resource loading/play calls, save I/O and Q3 respawn.
The new `scripts/persistence_smoke.jac` passes actual App quicksave/quickload,
cross-game restoration and malformed-save rejection on all three games. Combat
captures were inspected for Q1/Q2 original models and Q3 training bots. Settings
reload exposes native `splitlines()` adding an extra empty line; see the blocker
above. The normal input loop, match completion/rematch, settings and subjective
audio checks still need acceptance. Bots currently
pursue only with line of sight; navigation around obstacles, actor separation,
original Q3 player models, full animation state machines, projectiles, campaign
keys/objectives/hub state and endings remain. This is progress toward the agreed
playable prototype, not a claim that the prototype is complete.
