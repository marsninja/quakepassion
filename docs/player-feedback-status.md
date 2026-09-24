# Player feedback: weapons, damage and movement

How the player's own weapons, hits and movement feel in each game. Each rule
cites the original function it follows.

## Knockback and rocket jumps

`knock_back` (engine/world/combat.jac) applies each game's push before armor
and protection:

- Q1 `T_Damage`: only the player (the one walking body) is pushed, by
  `dir * damage * 8`, away from the inflictor. Monsters are not pushed.
- Q2 `T_Damage`: anything that moves is pushed by `500 * knockback / mass`; a
  player hurting himself uses 1600 (the rocket-jump hack). Monster masses come
  from the `m_*.c` spawn functions; dead monsters are not pushed. Weapons carry
  their `kick` (shotgun 8, super shotgun 12, machinegun/chaingun 2, railgun
  250, blasters 1); rockets and the BFG push only through their blast.
- Q3 `G_Damage`: players and bots are pushed by `1000 * min(damage, 200) / 200`
  and ground friction is held off for 2 ms a point (`PMF_TIME_KNOCKBACK`).
  Splash measures from the nearest point of the box and pushes the centre of
  mass 24 units higher (`G_RadiusDamage`); self-damage is halved after the push.

All three halve an attacker's own splash, bots and monsters included.
`scripts/rocket_jump_probe.jac` jumps and fires a rocket at the feet on the same
tick on e1m1, base1 and q3dm1: apexes of about 247, 233 and 272 units, against
45 for a plain jump.

## Movement

- Q2 and Q3 check the jump before ground friction (`PM_CheckJump` before
  `PM_Friction`), so a jump on landing keeps its speed; Q1 rubs friction off
  first. A jump needs the button released after the last one (Q1
  `FL_JUMPRELEASED`, Q2/Q3 `PMF_JUMP_HELD`); holding it jumps again on landing
  once released and pressed. Q2 adds 270 to an upward velocity.
- Q2/Q3 `PM_StepSlideMove` also steps up while falling, catching ledges.
- Water jumps: waist deep, facing a wall that is solid at the waist and open
  above, the swimmer springs out (Q1 `CheckWaterJump` 225 up and pushed at the
  wall until clear of the water, Q2 `PM_CheckSpecialMovement` 350 up and 50
  forward, Q3 `PM_CheckWaterJump` 350 up and 200 along the view).
- Falling (`CrashLand`, engine/world/vitals.jac): Q1 `PlayerPostThink` (over
  300 plays land.wav, over 650 hurts 5 with land2.wav, h2ojump.wav into water);
  Q2 `P_FallingDamage` (delta = v²/10000 cut by water depth, (delta-30)/2
  damage past 30, fall1/fall2/land1 sounds, a pitch dip); Q3 `PM_CrashLand`
  (5 past 40, 10 past 60, doubled ducked; land1.wav and an eye dip).

## Explosions, trails and lights

Missile bursts, exploding barrels, Q2 viper bombs and `target_explosion` create
an `Explosion` node (engine/world/particles.jac) with its sound, dynamic light
and a burst of fire particles:

- Q1 `BecomeExplosion`: `progs/s_explod.spr` (a new SPR reader,
  engine/formats/q1/sprite.jac) at 10 Hz, r_exp3.wav, a 350-unit light.
- Q2 `CL_ParseTEnt`: the `r_explode` model, full bright, changing skin and
  fading after its tenth frame as `CL_AddExplosions` does; rocket bursts start
  on frame 0 or 15, grenades on 30; rocklx1a/grenlx1a.wav.
- Q3 `CG_MissileHitWall`: the rocket, grenade and BFG animmap sprites cross-fade
  frame to frame while growing from 30 to 72 units; plasma uses plasmaboom;
  rocklx1a/plasmx1a.wav.

The player's railgun leaves a Q2 blue particle spiral around a grey core or a
Q3 railCore ribbon with a spiral of railDisc rings (the default red/magenta
player colours); the Q1 Thunderbolt draws `bolt2.mdl` segments every 30 units
(the shambler `bolt.mdl`); the Q3 lightning gun a scrolling lightning3 ribbon.
Q2 blaster bolts, rockets, plasma and BFG orbs carry a light in flight. The Q3
BFG flies as `models/weaphits/bfg.md3`.

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
- Out of ammo: Q2 and Q3 click (noammo.wav) and change to the best weapon with
  ammo, as Q1 does on the next attack.
- Q2 chaingun: one shot a 10 Hz frame for five frames, two for five, then three,
  with the spin-up and wind-down sounds. Q2 BFG: flash and sound on the
  trigger, the orb 0.8 s later if the cells are still there. Q2 machinegun
  climbs 1.5 degrees a shot up to nine. Q1 and Q2 weapons punch the view.
- Q1 Thunderbolt under water discharges every cell as `T_RadiusDamage` 35 per
  cell, the shooter taking half.
- Q3: machinegun spread is circular (0.0244), shotgun 0.085; grenades leave
  0.2 upward at 700 and bounce at 65%; rockets live 15 s, plasma and BFG 10 s;
  the gauntlet only fires on contact within 46 units; the lightning gun sounds
  lg_fire once and then hums; hit.wav plays when a shot lands; LOW AMMO WARNING
  / OUT OF AMMO follow `CG_CheckAmmo`.
- Q2 energy weapons (blasters, BFG) meet jacket armor's 0, combat armor's 0.3
  and body armor's 0.6 energy protection. Q2 health pickups stop at
  max_health except the stimpack and mega health.

## View and sound feedback

`ViewFeedback` (engine/render/view_feedback.jac) turns hits into the originals'
flashes and kicks: Q1 `V_ParseDamage` (red or armor-tinted cshift, pitch/roll
kick), Q2 `P_DamageFeedback` (damage blend and kick by health) and Q3
`CG_DamageFeedback` with the `viewBloodBlend` blob toward the hit. Liquids tint
the view when the eye is under (Q1 `V_SetContentsColor`, Q2 `SV_CalcBlend`),
pickups flash gold (Q1 `V_BonusFlash_f`, Q2 bonus_alpha), and the dead view
drops and rolls (Q1 80 degrees; Q2/Q3 40 degrees, looking toward the killer).

`VoiceTick` voices Q1 and Q2 bodies: jump, landing, water entry/exit and
submerging, surfacing gasps, drowning, lava/slime burns, pain (by health in
Q2) and death. It keeps its own last health, so liquid damage is voiced too.
Q3 plays the water events; its model sounds belong to the Q3 player model.

Printed lines go where the games put them: Q1/Q2 pickup and weapon prints at
the top left in the game's character sheet, centre prints a third of the way
down. Q1 pickups print "You got the Rocket Launcher", "You receive 25 health",
"You got armor"; Q2 shows the pickup icon and name on the status bar (and the
selected item's icon); Q3 shows the icon and name above the lower left. Q3 frags
add the standing ("You fragged X / 1st place with 3") and bot-versus-bot
obituaries print at the top left.

## Validation

- `tests/player_feedback_tests.jac`: knockback per game, own rocket blasts,
  jump-before-friction and jump release, landing speeds and fall thresholds,
  autoswitch/refusal/cycling, chaingun spin-up timing, BFG delay, machinegun
  climb, Q1 discharge, player trails, explosions per game, Q3 top-up, Q2
  health cap, voice cues and view blends.
- `scripts/player_feedback_smoke.jac` renders each game's rocket and grenade
  explosions, the Q1/Q3 lightning beam, Q2/Q3 rail trails, the damage flash,
  the underwater tint, pickup feedback and the dead view.
- `scripts/rocket_jump_probe.jac` prints the rocket jump apexes above.

Not done: Q3 scorch/bullet marks and ricochet sounds, the Q2/Q3 view weapon
lowering during a switch (the view weapon only shows its raise), Q2 PMF_TIME_LAND
after hard landings, Q1 backpack pickups and gib sounds for the player.
