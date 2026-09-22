# First-person weapons

The shared viewweapon renderer uses the original Q1 MDL and Q2 MD2 view assets,
and Q3 MD3 weapon models positioned through their hand-model `tag_weapon`.
Optional Q3 barrel models attach through `tag_barrel`. All assets load with the
level; no archive access occurs when selecting or firing a weapon. Failed level
loads dispose the newly prepared resources and preserve the previous scene.

The view follows camera pitch/yaw, samples map illumination with minimum ambient
light, and compresses projection depth for the weapon pass. World projection is
restored before HUD rendering. Death hides the gun. Cosmetic firing/idle frames
and a short raise transition use simulation time, so menu pause freezes them.
Q2 cooked grenades have explicit priming/holding/throw poses. None of this changes
weapon damage, cooldowns or ammunition.

This is the visible-weapon foundation, not complete original animation fidelity.
Exact raise/lower timing, Q1 alternate axe swings, Q2 idle pauses and continuous
fire sequences, Q3 barrel spin, muzzle flashes, recoil, movement bob and several
weapon shader effects remain open. Q3 arm meshes are not drawn separately: the
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
