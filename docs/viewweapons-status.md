# First-person weapons

Every Q1, Q2 and Q3 weapon draws its original view model with its own firing,
idle and switch frames, placed by its game's view rule. The renderer is
`engine/render/viewweapon.jac`; frame rules are `ViewWeaponRule` and
`GunAnimation` in `engine/world/weapons.jac` with per-weapon tables in
`games/viewweapons.jac`; placement is `engine/render/view_sway.jac`. None of
this changes damage, cooldowns or ammunition.

## Models and lighting

- Q1 MDL and Q2 MD2 view models; Q3 MD3 weapons attached to the hand model's
  `tag_weapon`, with optional barrels on `tag_barrel`. Q3 arms are not drawn
  separately: the hand MD3 supplies the attachment animation.
- Q3 muzzle flashes, barrel spin and powerup shells (quad, battle suit,
  invisibility) are drawn.
- All assets load with the level; selecting or firing reads no archive. A
  failed level load disposes the new resources and keeps the previous scene.
- The gun is lit from the map (see
  [combat-feedback-status.md](combat-feedback-status.md#model-lighting-and-dynamic-lights)),
  drawn with compressed projection depth, and hidden on death. World
  projection is restored before the HUD.

## Frames

Frames step ten a second of simulation time, so menu pause freezes them.

- **Q1** plays `player.qc`'s weaponframes: the axe swings 1-4 or 5-8
  (`W_Attack`'s alternate swings), shotguns and launchers 1-6, the nailguns
  cycle 1-8 and the thunderbolt 1-4 while the trigger holds, dropping to frame 0
  on release (`player_run`). Frames are drawn unblended.
- **Q2** follows `Weapon_Generic`: a shot shows `FRAME_FIRE_FIRST + 1`; the
  machine gun alternates 5 and 4; the chaingun spins up 6-21, cycles 15-21 and
  winds down through 31 (or jumps from 14 to idle if released early); the
  hyperblaster turns 6-11 and winds down. Idle frames loop with each weapon's
  `pause_frames` holding fifteen steps in sixteen (the fidgets), including
  `Weapon_Grenade`'s 16-48 idle. The hand grenade has priming, holding and
  throw poses. Frames blend over each 100 ms as the client lerps them.
- **Q3** hand frames blend, and the gun rides the blended `tag_weapon`.

## Switching

A change shows the old weapon lowering, then the new one rising, over the same
lower and raise times that hold fire (`swap_weapon` records what was put away).
Q2 plays each weapon's deactivate frames (`FRAME_IDLE_LAST + 1` to
`FRAME_DEACTIVATE_LAST`) then its activate frames (0 to `FRAME_ACTIVATE_LAST`)
at 10 a second; the hand grenade changes at once, as `Weapon_Grenade` does.
Q3 plays the hand model's frames 6-10 and 11-14 at 20 a second
(`CG_MapTorsoToWeaponFrame`, `TORSO_DROP`, `TORSO_RAISE`). Q1 changes at once.

## Placement and kick

- **Q1** `V_CalcRefdef`: the gun lifts with the bob, is pushed forward 0.4 of
  the bob and 2 units up (viewsize 100), and turns with the aim and the damage
  kick's pitch, not the strafe roll or punch.
- **Q2**: the gun is drawn at the bobbing, kicking view with
  `SV_CalcGunOffset`'s bob angles and a fifth of the last server frame's turn as
  lag. A shot kicks the view for the server frame it is fired in (`kick_origin`,
  random `kick_angles`): the blaster, shotguns, launchers, hyperblaster and BFG
  push it 2 units back along the aim, the railgun 3; the machine gun and
  chaingun shake it 0.35 units and 0.7 degrees.
- **Q3** `CG_CalculateWeaponPosition`: the bob angles, a quarter more of the
  landing dip, and the idle drift.

## Validation

- `tests/viewweapon_tests.jac`: Q1 player.qc frames, Q2 continuous loops, fire
  frames and blending, idle fidgets, hand-grenade frames, switching per game.
- `tests/view_sway_tests.jac`: each game's bob, roll, gun placement, lag and
  the Q2 shot kick.
- `tests/item_drop_tests.jac`: powerup shaders on bodies and weapons.
- Native: `scripts/viewweapon_smoke.jac` renders all 28 weapons and captures
  idle and firing poses; `scripts/weapon_switch_smoke.jac` captures a Q2
  blaster-to-shotgun and a Q3 machine gun-to-shotgun change mid-lower,
  mid-raise and ready.

References: [Q1 weapons.qc](https://github.com/id-Software/Quake/blob/master/QW/progs/weapons.qc),
[Q2 p_weapon.c](https://github.com/id-Software/Quake-2/blob/master/game/p_weapon.c),
[Q3 cg_weapons.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/cgame/cg_weapons.c).

## Limitations

- Passion has no view models.
- Q3 model shaders' `deformVertexes` stages are parsed but applied only to
  world surfaces (`engine/render/quake.jac`), not to view or world models.
