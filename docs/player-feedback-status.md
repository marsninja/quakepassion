# Player feedback: weapons, damage and the view

How the player's own weapons, hits, falls and movement feel in each game. Each
rule cites the original function it follows. Particles, trails, beams, impact
marks and dynamic lights are in [combat feedback](combat-feedback-status.md);
the first-person weapon in [first-person weapons](viewweapons-status.md);
movement rules in [player movement](player-movement-status.md).

## Knockback and rocket jumps

`knock_back` (`engine/world/combat.jac`) applies each game's push before armor
and protection:

- Q1 `T_Damage`: only walking bodies (the player) are pushed, by
  `dir * damage * 8` away from the inflictor.
- Q2 `T_Damage`: anything that moves is pushed by `500 * knockback / mass`; a
  player hurting himself uses 1600 (the rocket-jump hack). Monster masses come
  from the `m_*.c` spawn functions; dead monsters are not pushed. Weapons carry
  their `kick` (shotgun 8, super shotgun 12, machinegun/chaingun 2, railgun
  250, blasters 1); rockets and the BFG push only through their blast.
- Q3 `G_Damage`: players and bots are pushed by `1000 * min(damage, 200) / 200`
  and skid without ground friction for 2 ms a point (`PMF_TIME_KNOCKBACK`).
  Splash measures from the nearest point of the box and pushes the centre of
  mass 24 units higher (`G_RadiusDamage`); self-damage is halved after the push.

All three halve an attacker's own splash, bots and monsters included.
`scripts/rocket_jump_probe.jac` jumps and fires at the feet on the same tick on
e1m1, base1 and q3dm1 and prints the apexes (2026-09-24, before the per-game
movement profiles: about 247, 233 and 272 units, against 45 for a plain jump).

## Falling and landing

`CrashLand` (`engine/world/vitals.jac`) takes the landing speed that
`MovePlayer` reports: Q1 `PlayerPostThink` (over 300 plays `land.wav`, over 650
hurts 5 with `land2.wav`, `h2ojump.wav` into water); Q2 `P_FallingDamage`
(delta = v²/10000 cut by water depth, (delta-30)/2 damage past 30,
fall1/fall2/land1 sounds, a pitch dip); Q3 `PM_CrashLand` (5 past 40, 10 past
60, doubled ducked; `land1.wav` and an eye dip).

## Explosions

Missile bursts, exploding barrels, Q2 viper bombs and `target_explosion`
create an `Explosion` node (`engine/world/particles.jac`) with its sound,
light and particles, drawn by `engine/render/effects.jac`:

- Q1 `BecomeExplosion`: `progs/s_explod.spr` (`engine/formats/q1/sprite.jac`)
  at 10 Hz, `r_exp3.wav`, a 350-unit light.
- Q2 `CL_ParseTEnt`: the `r_explode` model, full bright, changing skin and
  fading after its tenth frame as `CL_AddExplosions` does; rocket bursts start
  on frame 0 or 15, grenades on 30; `rocklx1a`/`grenlx1a.wav`.
- Q3 `CG_MissileHitWall`: the rocket, grenade and BFG animmap sprites
  cross-fade frame to frame while growing from 30 to 72 units; plasma uses
  plasmaboom.

The player's railgun leaves Q2's blue particle spiral around a grey core, or
Q3's `railCore` quad (`cg_oldRail`, the default); the Q1 Thunderbolt draws
`bolt2.mdl` every 30 units, the Q3 lightning gun `CG_LightningBolt`'s beam. The
Q3 BFG flies as `models/weaphits/bfg.md3`.

## Weapon handling

- Weapon keys refuse weapons the player lacks or cannot fire (Q1 "no weapon." /
  "not enough ammo.", Q2 "No shells for Shotgun.", Q3 silently). The mouse
  wheel and `/` cycle to the next owned weapon with ammo.
- Changing weapons holds fire while the old weapon lowers and the new one
  rises: instant in Q1, each weapon's deactivate/activate frames in Q2, 200 +
  250 ms in Q3.
- Pickups switch: Q1 always in single player, Q2 the first time a weapon is
  picked up, Q3 on any weapon but the machinegun. Q3 weapon pickups top the
  ammo up to the pickup's count (or one shot) and are always taken.
- Out of ammo: Q2 and Q3 click (`noammo.wav`) and change to the best weapon
  with ammo, as Q1 does on the next attack.
- Q2 chaingun: one shot a 10 Hz frame for five frames, two for five, then
  three, with the spin-up and wind-down sounds. Q2 BFG: flash and sound on the
  trigger, the orb 0.8 s later if the cells are still there. Q2 machinegun
  climbs 1.5 degrees a shot up to nine. Q1 and Q2 weapons punch the view, and a
  Q2 shot kicks the view back for the server frame it is fired in.
- Q1 Thunderbolt under water discharges every cell as `T_RadiusDamage` 35 per
  cell, the shooter taking half.
- Q3: machinegun spread is circular (0.0244), shotgun 0.085; grenades leave
  0.2 upward at 700 and bounce at 65%; rockets live 15 s, plasma and BFG 10 s;
  the gauntlet fires only on contact within 46 units; the lightning gun sounds
  `lg_fire` once and then hums; `hit.wav` plays when a shot lands; LOW AMMO
  WARNING / OUT OF AMMO follow `CG_CheckAmmo`.
- Q2 energy weapons (blasters, BFG) meet jacket armor's 0, combat armor's 0.3
  and body armor's 0.6 energy protection. Q2 health pickups stop at
  max_health except the stimpack and mega health.

## View

`ViewFeedback` (`engine/render/view_feedback.jac`) turns hits into the
originals' flashes and kicks: Q1 `V_ParseDamage` (red or armor-tinted cshift,
pitch/roll kick), Q2 `P_DamageFeedback` (damage blend and kick by health) and
Q3 `CG_DamageFeedback` with the `viewBloodBlend` blob toward the hit. Liquids
tint the view when the eye is under (Q1 `V_SetContentsColor`, Q2
`SV_CalcBlend`), pickups flash gold (Q1 `V_BonusFlash_f`, Q2 `bonus_alpha`),
and the dead view drops and rolls (Q1 80 degrees; Q2/Q3 40, looking toward the
killer).

Moving sways the view per game (`engine/render/view_sway.jac`):

- Q1 `V_CalcBob` (`cl_bob` 0.02 over a 0.6 s cycle, held between -7 and 4)
  lifts the eye and gun and pushes the gun forward; `V_CalcRoll` rolls up to 2
  degrees at 200 units a second strafing.
- Q2 `SV_CalcViewOffset` and `SV_CalcGunOffset`: bobtime steps by bobmove
  each 100 ms server frame on the ground; bob_up/pitch/roll, run_pitch 0.002
  and run_roll 0.005; crouching bobs six times as hard; the fall kick lowers
  the eye; the gun lags a turn. Lerped between server frames as the client
  does.
- Q3 `CG_OffsetFirstPersonView` on `PM_Footsteps`' bobCycle, only on the
  ground while trying to move (landing starts it over), and
  `CG_CalculateWeaponPosition`'s gun bob, landing drop and idle drift.

`ViewFeedback.place` composes the eye from the body as drawn between ticks,
the step and crouch ease (see [player movement](player-movement-status.md);
Q1 eases the body's height net of what movers carried it), the landing dip,
kicks, punch and sway.

## Drawing between physics ticks

Frames draw every body between its last two 120 Hz ticks
(`engine/math/interpolation.jac`, `Clock.alpha` in `engine/core/clock.jac`).
At each tick `CaptureMotion` (`engine/world/motion.jac`) records every entity
in an occupied area and every projectile, and the renderer keeps each moving
brush group's placement; a frame draws the eye, models, projectiles, sprites
and movers that far between (Q1 `CL_RelinkEntities`, Q2
`CL_AddPacketEntities`, Q3 `CG_InterpolateEntityPosition`). View angles are the
latest input. A body that moved more than 100 units on an axis in one tick is
drawn where it is (Q1's teleport rule); noclip flight, teleports, respawns and
the intermission camera settle the player's pose.

## Voice, gibs and prints

`VoiceTick` (`engine/world/vitals.jac`) voices Q1 and Q2 bodies: jump,
landing, water entry/exit and submerging, surfacing gasps, drowning,
lava/slime burns, pain (by health in Q2) and death. Q3 plays the water events;
its model sounds belong to the Q3 player model. A killing blow more than 40
past zero (Q3: 40 or more) gibs the player: Q1 `GibPlayer` plays `gib` or
`udeath` (`teledth1` for a telefrag), Q2 `player_die` `misc/udeath`, Q3
`EV_GIB_PLAYER` `gibsplt1`, with no death cry.

Printed lines go where the games put them: Q1/Q2 pickup and weapon prints at
the top left in the game's character sheet, centre prints a third of the way
down. Q1 pickups print "You got the Rocket Launcher", "You receive 25 health",
"You got armor"; Q2 shows the pickup icon and name on the status bar; Q3 shows
the icon and name above the lower left. Q3 frags add the standing ("You
fragged X / 1st place with 3"), and bot-versus-bot obituaries print at the top
left.

## Validation

- `tests/player_feedback_tests.jac`: knockback per game, own rocket blasts,
  jump-before-friction and jump release, `PMF_TIME_LAND`, landing speeds and
  fall thresholds, autoswitch/refusal/cycling, chaingun spin-up, BFG delay,
  machinegun climb, Q1 discharge, trails, explosions per game, Q3 top-up, Q2
  health cap, gibbing, voice cues and view blends.
- `tests/view_sway_tests.jac` (bob, roll, gun lag, Q2 shot kick, dead and
  intermission views), `tests/render_interpolation_tests.jac`,
  `tests/step_view_tests.jac`.
- `scripts/player_feedback_smoke.jac` renders each game's rocket and grenade
  explosions, the Q1/Q3 lightning beam, Q2/Q3 rail trails, the damage flash,
  the underwater tint, pickup feedback and the dead view.
- `scripts/rocket_jump_probe.jac` prints the rocket jump apexes.

## Limitations

- Q1 backpacks (grunt, enforcer and ogre drops) are picked up, but
  `BackpackTouch`'s "You get ..." print is not shown.
- The player's own body is not thrown as gibs.
