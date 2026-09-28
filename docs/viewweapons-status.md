# First-person weapons

The shared viewweapon renderer uses the original Q1 MDL and Q2 MD2 view assets,
and Q3 MD3 weapon models positioned through their hand-model `tag_weapon`.
Optional Q3 barrel models attach through `tag_barrel`. All assets load with the
level; no archive access occurs when selecting or firing a weapon. Failed level
loads dispose the newly prepared resources and preserve the previous scene.

The view follows camera pitch/yaw, samples map illumination with minimum ambient
light, and compresses projection depth for the weapon pass. World projection is
restored before HUD rendering. Death hides the gun. Cosmetic firing/idle frames
and the weapon switch use simulation time, so menu pause freezes them.
Q2 cooked grenades have explicit priming/holding/throw poses. None of this changes
weapon damage, cooldowns or ammunition.

A weapon change shows the old weapon lowering, then the new one rising, over
the same lower and raise times that hold fire (`swap_weapon` records what was
put away): Q2 plays each weapon's `Weapon_Generic` deactivate frames
(`FRAME_IDLE_LAST + 1` to `FRAME_DEACTIVATE_LAST`) then its activate frames
(0 to `FRAME_ACTIVATE_LAST`) at 10 a second, the hand grenade changing at once
as `Weapon_Grenade` does; Q3 plays the hand model's frames 6-10 and 11-14 at
20 a second (`CG_MapTorsoToWeaponFrame` following `TORSO_DROP` and
`TORSO_RAISE`); Q1 changes at once. `scripts/weapon_switch_smoke.jac` captures
a Q2 blaster-to-shotgun and a Q3 machine gun-to-shotgun change mid-lower,
mid-raise and ready (inspected).

Firing and idle frames follow each game's own rules (`ViewWeaponRule`,
`GunAnimation` in `engine/world/weapons.jac`, tables in `games/viewweapons.jac`),
stepped ten a second of simulation time. Q1 plays player.qc's weaponframes: the
axe swings 1-4 or 5-8 (W_Attack's four swings), shotguns and launchers 1-6, the
nailguns cycle 1-8 and the thunderbolt 1-4 while the trigger holds and drop to
frame 0 when it is let go (player_run); Q1 draws each frame as it is. Q2 follows
Weapon_Generic: a shot shows FRAME_FIRE_FIRST + 1 (the fire function steps past
the frame it fired on), the machinegun alternates 5 and 4, the chaingun spins up
6-21, cycles 15-21 and winds down through 31 (or jumps from 14 to idle when let go
early), the hyperblaster turns 6-11 and winds down, and the idle frames loop with
the per-weapon pause_frames holding fifteen steps in sixteen (Weapon_Grenade's
own 16-48 idle included); frames blend over each 100 ms as the client lerps them.
Q3's hand frames blend too, and the gun rides the blended tag_weapon.

The gun is placed by each game's view rule (`engine/render/view_sway.jac`): Q1
V_CalcRefdef lifts it with the bob, pushes it forward 0.4 of the bob and 2 units
up (viewsize 100), turned with the aim and the damage kick's pitch but not the
strafe roll or punch; Q2 draws it at the bobbing, kicking view with
SV_CalcGunOffset's bob angles and a fifth of the last server frame's turn as lag;
Q3 CG_CalculateWeaponPosition adds the bob angles, a quarter more of the landing
dip and the idle drift. The old generic sway and recoil nudge are gone.

A Q2 shot also kicks the view for the server frame it is fired in (the fire
functions' kick_origin and random kick_angles): the blaster, shotguns, launchers,
hyperblaster and BFG push it 2 units back along the aim, the railgun 3, and the
machinegun and chaingun shake it 0.35 units and 0.7 degrees; the gun, drawn at
the view, moves with it. Q3 muzzle flashes, barrel spin and powerup shells are
drawn; several weapon shader effects remain open. Q3 arm meshes are not drawn separately: the
hand MD3 supplies the original attachment animation. Passion is unchanged.

The native gallery (`scripts/viewweapon_smoke.jac`) loads and renders 8 Q1,
11 Q2 and 9 Q3 weapons and captures idle/firing poses. Q1 shotgun, Q2 blaster,
Q3 machinegun and gauntlet captures have been visually inspected. Frame sampling
regressions cover attack/idle boundaries, repeated sampling, range bounds and
cooked-grenade release.

Asset/frame references: the original Q1 weapon selection, Q2 `Weapon_Generic`
and item view-model entries, and Q3 `CG_AddViewWeapon` / hand-frame mapping:

- https://github.com/id-Software/Quake/blob/master/QW/progs/weapons.qc
- https://github.com/id-Software/Quake-2/blob/master/game/p_weapon.c
- https://github.com/id-Software/Quake-2/blob/master/game/g_items.c
- https://github.com/id-Software/Quake-III-Arena/blob/master/code/cgame/cg_weapons.c

Sixteen focused viewweapon, hand-grenade and weapon tests pass with the documented
source compiler. The native main application builds. The gameplay harness also
loads Q1 `e1m1`, Q2 `base1`, Q3 `q3dm1` and Passion in sequence; the three original
map captures show the starting gun correctly over the world. During concurrent
compiler/test activity, sampled median frames were 3.65 ms, 7.57 ms and 6.96 ms
for Q1/Q2/Q3 respectively. These are smoke/performance samples, not exhaustive
combat or campaign acceptance.
