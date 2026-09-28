# Combat feedback and movement

The shared combat simulation emits each game's impact particles at every hitscan wall impact and actor intersection: Q1 `TE_GUNSHOT` and `SpawnBlood` (`R_RunParticleEffect`), Q2 `TE_GUNSHOT` and `TE_BLOOD` (`CL_ParticleEffect`), and a short spray of sparks in Q3 and Passion. Effects use actual pellet endpoints and wall normals, never consume weapon randomness (particles draw on their own `rand()` stream) and never alter damage events. They are cosmetic and are not saved. See "Particles, trails and beams" below.

Supported modeled opponents play one original pain/death frame family. Pain briefly interrupts movement and attacks, with a cooldown to prevent permanent stun. Death holds the last frame; restored dead opponents use that pose. Turning is rate limited, steering includes local spacing, and grounded actors check support ahead. Ranged attack animations stop forward movement; authored melee sequences can charge. First-person weapons bob and sway by each game's own view rules (see [first-person weapons](viewweapons-status.md)).

This is not yet original-game behavioral parity. Remaining work includes frame-timed attacks and each monster's authored movement distances, broader enemy rosters, path navigation and Q3 tactical/item decisions, game-specific impact textures, gibs, and varied pain/death sequences (impact marks, ricochets and monster muzzle flashes are covered below). Local spacing is steering, not full actor collision. Particles pass through surfaces, as the originals' do: neither `R_DrawParticles` (Q1) nor `CL_AddParticles` (Q2) traces them, and Q3's trails are sprites (bouncing gibs and brass are models, see `gibs.jac`).

Validation entry points: `tests/feedback_tests.jac`, existing combat tests, and native `scripts/feedback_render_smoke.jac` (requires Q1 assets in `~/quake-assets/id1` and an active display).

Validation on September 22, 2026: 255 tests passed after clearing stale Jac build cache artifacts. The native Q1 e1m1 feedback harness passed and captured visible wall spray, a blood hit on an original soldier model, and the final death pose. Validated with the local source compiler (`JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-lighting-validation/jac`, `JAC_COMPILER_LIB=off`); this does not establish parity with the released Jac compiler or original-game AI.

## Authored Q1 attack timelines

The soldier, dog, knight, and enforcer now use explicit 10 Hz attack poses and simulation-clock damage events. Dog bites occur at 0.3 s, knight strikes at 0.5/0.6/0.7 s, soldier pellets at 0.4 s, and enforcer bolts at 0.5/0.9 s. Pose lists preserve repeated frames in the enforcer sequence. Dog and knight charge distances are integrated across frame boundaries through shared stair/slide collision, with support and player-spacing checks.

Each event rechecks live range and visibility; pain/death cancel pending attacks. Soldier shots trace four spread pellets, aim behind player velocity, and emit wall feedback when they miss. Opponent randomness is separate from player weapon randomness. Save format 9 stores attack time, next event, melee selection, pain timers, and the opponent spread stream; format 8 saves are rejected.

These timings and frame names follow the original id Software [soldier](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/soldier.qc), [dog](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/dog.qc), [knight](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/knight.qc), and [enforcer](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/enforcer.qc) code. Original randomized melee damage, refire decisions, dog leaps, attack sounds, muzzle flashes, and other monsters' authored attack sequences remain unfinished. Q3 still uses the existing generic attack behavior; the subsequent Q2 work is described below.

Additional checks: `tests/attack_timing_tests.jac`, `tests/enemy_aim_tests.jac`, and `scripts/attack_timing_smoke.jac`. The native smoke checks every referenced attack frame against the supplied Q1 models.

Final attack-timeline regression run: **261 tests passed** with the local source compiler. This includes frame-boundary charge motion, blocked strikes, interruption, burst save/restore, soldier dodging, and existing gameplay regressions.

The standalone native attack smoke passed all four original model frame checks and the two-bolt timing check. `qp` was rebuilt, and native Q1 e1m1, Q2 base1, and Q3 q3dm1 smoke runs all exited successfully.

## Q2 ranged attack profiles

The three Q2 soldier variants now have distinct ranged behavior: light soldiers fire 5-damage blaster bolts after the initial windup; shotgun soldiers fire twelve 2-damage pellets; machine-gun soldiers fire held-frame bursts of 2-damage bullets. Infantry uses its longer windup and 3-damage gun burst. Horizontal and vertical spread are independent, and soldier aim jitter is applied once before the individual pellet spread.

Held bursts extend the attack timeline and hold the firing pose instead of cycling unrelated animations. Their lengths are sampled once, preserved in save format 10, and interrupted by the existing pain/death handling. End-of-burst frames resume after the hold. Save format 9 and earlier are rejected.

The source references are id Software's [Q2 soldier](https://github.com/id-Software/Quake-2/blob/master/game/m_soldier.c), [infantry](https://github.com/id-Software/Quake-2/blob/master/game/m_infantry.c), and [weapon](https://github.com/id-Software/Quake-2/blob/master/game/g_weapon.c) implementations. This covers the canonical ranged sequence, not complete Q2 AI: alternate attacks, infantry punches, dodge/duck, original muzzle attachment offsets, sounds, difficulty-dependent refires, and tactical selection remain unfinished. Native checks live in `scripts/q2_attack_smoke.jac`; regression checks live in `tests/q2_attack_tests.jac`.

Q2 ranged validation: **265 tests passed**. The standalone native smoke passed frame-name checks against all four original Q2 model/skin profiles and verified the held burst through completion.
The rebuilt viewer also completed native Q1 e1m1, Q2 base1, and Q3 q3dm1 smoke runs successfully after the Q2 ranged changes.

## Q2 infantry melee

Infantry now selects a separate close-range punch sequence: eight original `attak201`–`attak208` poses, a strike at 0.5 seconds, per-frame approach distances, 5–9 damage, and knockback. Once chosen, the attack stays melee even if the player retreats; range and cover are rechecked at the strike. A later attack can select the machine gun again. God mode prevents both punch damage and knockback.

Melee and ranged profiles use the same combat walker, collision integration, and event clock. Existing saved melee selection and random state preserve a swing in progress, so the file format remains 10. Restoring now selects the saved attack mode before validating its duration and event count. The implementation follows the infantry melee sequence in the original [Q2 infantry source](https://github.com/id-Software/Quake-2/blob/master/game/m_infantry.c).

Coverage: `tests/infantry_melee_tests.jac` and `scripts/infantry_render_smoke.jac`. Dodge/duck, alternate ranged choices, original sound feedback, difficulty behaviors, and broader navigation remain incomplete.

Infantry melee validation: 269 gameplay tests passed. The native visual harness passed and its original-model windup/strike captures were inspected. It exposed a native `list.index` equality defect, fixed locally and submitted as [upstream #9420](https://github.com/jaseci-labs/jac/pull/9420); see `docs/native-list-search-equality-blocker.md`. The playable binary has been rebuilt with that compiler fix.
A second full regression run with the patched compiler also passed all 269 tests. Native Q1, Q2, and Q3 viewer smoke runs completed successfully with the rebuilt binary.

## Q1 ogre attack sequences

Ogres and `monster_ogre_marksman` now use the original seven-pose grenade windup
(including the repeated `shoot2` pose), releasing the grenade at 0.3 seconds.
Monster grenades use 40 splash damage with an 80-unit effective damage radius,
rather than the player grenade's damage. They retain the shared bouncing flight,
200-unit upward launch velocity and 2.5-second fuse.

Close attacks choose between the original fourteen-frame chainsaw sweep and
smash. The sweep checks damage seven times from 0.4 to 1.0 seconds; the smash
checks six times from 0.5 to 1.0 seconds. Each strike rechecks range and cover.
Authored approach distances use shared collision, and damage samples three
independent random values with the original scale of four. The chosen variant
and random stream survive save/load in **format 11**; older snapshots are rejected.

The timing and damage reference is id Software's
[ogre code](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/ogre.qc).
Random smash recovery extension, swing yaw offsets, sounds, meat spray, drops,
original ogre hull dimensions and full monster navigation remain unfinished.
This is not acceptance of the complete campaign scope.

Coverage: `tests/ogre_attack_tests.jac`, original frame validation in
`scripts/attack_timing_smoke.jac`, and visual sweep/smash capture in
`scripts/ogre_render_smoke.jac`.

Native visual acceptance passed in Q1 `e1m2`, with inspected captures of the
chainsaw sweep and overhead smash. These are controlled encounter fixtures using
original assets, not a full-map playthrough. The focused combat/save suite passed
10 tests after adding alternate-attack persistence. Validation uses the documented
local compiler with the list-search equality fix.
The final regression suite passed **273 tests** with alternate attacks enabled.
The rebuilt `qp` completed native viewer smoke runs for Q1 `e1m2`, Q2 `base1`,
and Q3 `q3dm1` successfully. These establish startup/rendering acceptance,
not campaign completion or original-game behavioral parity.

## Positional enemy attack cues

The common attack clock now triggers original dog bites, knight swings,
enforcer bolt shots, and ogre grenade/chainsaw sounds through shared graph
speakers. Q2 berserker and gladiator attacks use the same mechanism; see
[Q2 roster expansion](q2-roster-status.md). Cues are bounded by authored timeline
crossings, including floating-point frame boundaries, and attack save restoration
does not replay earlier sounds. This covers attack cues; full enemy sight,
pain/death audio and environmental hit feedback remain open.

## Q2 pain recovery

Supported Q2 enemies now use explicit original pain frames and recovery lengths:
soldiers and chicks take 0.5 seconds, berserkers 0.4, gladiators 0.6, and infantry
1.0. Their pain reactions have a three-second cooldown; hits during that cooldown
still deal damage without continually restarting recovery. Pain poses advance at
10 Hz and hold the last pose instead of wrapping.

The pose derives from the remaining recovery timer, so the first simulation tick
after loading resumes the saved reaction. Snapshot format remains **14**. Paused
rendering immediately after restore is not covered by this acceptance check.

Validation: **293 tests passed**, all seven supported Q2 model profiles passed
native frame-name checks, and `scripts/pain_render_smoke.jac` passed with inspected
original-model captures before and after save restoration. Validation uses the
local source compiler with the documented list-search equality fix.

The playable `qp` was rebuilt and completed graphical startup smoke runs for
Q1 `e2m3`, Q2 `bunk1`, and Q3 `q3dm1` with exit status zero.

This implements the short pain sequences. Damage-dependent/random alternatives,
airborne reactions, nightmare suppression, authored pain movement, wounded skins,
and pain audio remain unfinished. These checks do not establish campaign parity.

## Impact marks and ricochets

Shots that strike the world play each game's impact sound once, from where they
struck (`ImpactSound` nodes, played like explosions):

- Q1 (`CL_ParseTEnt`): nails and super nails `tink1` four times in five, else
  `ric1`–`ric3`; the enforcer's laser `enfstop`, scrag and hell knight spikes
  their `hit` sounds. Q1's `TE_GUNSHOT` is silent.
- Q2: bullets (`TE_GUNSHOT`: the machine gun, chaingun and monster guns)
  `world/ric1`–`ric3` three times in sixteen; shotgun pellets (`TE_SHOTGUN`)
  are silent; blaster bolts `lashit`.
- Q3 (`CG_MissileHitWall`): the machine gun always ricochets, the lightning gun
  plays its `lg_hit` sounds, the shotgun is silent.

The choice uses a roll derived from the impact point, not gameplay random
numbers. Sparks (the existing particle spray) still show on every wall hit.

Q3 leaves `CG_ImpactMark` marks (`ImpactMark` nodes): `bullet_mrk` for the
machine gun (radius 8) and shotgun (4), `hole_lg_mrk` for the lightning gun
(12), `burn_med_mrk` for rockets and grenades (64) and the BFG (32), and
`plasma_mrk` for the plasma gun (16) and railgun (24, in the rail colour). Each
is a square on the struck plane at a random turn, drawn after the world with a
small distance-scaled lift standing in for `polygonOffset`: bullet, burn and
hole marks darken what is behind them (`GL_ZERO GL_ONE_MINUS_SRC_COLOR`) and fade
their colour, energy marks blend by alpha with their glow dying over three
seconds. Marks last 10 seconds, fading over the last one; the pool holds 128
and the oldest gives way. A grenade bursting at rest marks the floor under it.
Marks go only on world brushes (not movers, as Q3 marks only the world model).

Surfaces: brush sides keep their texture flags. Sky (Q2/Q3 `SURF_SKY`) and Q3
`SURF_NOIMPACT` sides take no sparks, sound or mark, and missiles striking them
vanish without exploding (`G_MissileImpact`, `rocket_touch`); Q3 `SURF_NOMARKS`
sides take no mark.

Each mark is cut to the world faces it covers as `R_MarkFragments` cuts it:
its square's edge planes projected 20 units along the shot, with planes 32
beyond and 20 before, clip every face of the leaves the box reaches
(`BoxSurfaces` walks the BSP graph as `R_BoxSurfaces_r`), planar faces within
60 degrees of the shot and patch triangles; SURF_NOIMPACT, SURF_NOMARKS and
fog faces and triangle soups take none. A mark near an edge stops at it, a
mark in a corner wraps onto both walls, and a mark with nothing behind it is
not left. The pieces keep the square's texture coordinates and are drawn as
polygons (`ScenePolygons`, `RE_AddPolyToScene`); the pool holds 256 polygons
(`MAX_MARK_POLYS`). Marks are not saved.

Validation: `tests/impact_tests.jac`; `scripts/impact_marks_smoke.jac` fires
every Q3 hitscan and missile weapon at a q3dm1 wall and captures the sparks
(`qp_impact_sparks.png`), the marks (`qp_impact_marks.png`) and the marks four
seconds later (`qp_impact_marks_later.png`), which were inspected.

## Monster muzzles and flashes

Monster shots leave per-attack muzzles instead of the eye: `AttackProfile.muzzles`
holds forward, right and up offsets from the origin, one per shot of a sequence
(or, for a `volley`, one per gun of one shot). Q2 monsters use
`m_flash.c monster_flash_offset` through `G_ProjectSource` (the soldier's by
attack, the gunner's, tank's and Makron's sweeps by frame, the Hornet's and
Jorg's twin guns and the Hornet's four rocket tubes as volleys); Q1 monsters use
their QuakeC launch origins (grunt `FireBullets`, `enforcer_fire`, the ogre's
origin, scrag spikes left then right, zombie throws, the vore's pod, the hell
knight's box centre). Aim runs from the muzzle, and a wall between the origin and
the muzzle stops the shot there, as `fire_lead`'s origin trace does.

Each shot lights a 0.1 s dynamic light at the muzzle in its weapon's colour (Q2
`CL_ParseMuzzleFlash2`: yellow guns and blasters, orange rockets and grenades,
blue rails, green BFG; Q1 `EF_MUZZLEFLASH` on the grunt, enforcer, ogre, scrag,
shambler and vore). This replaces the glow monsters used to carry for the whole
of an attack. Beam attacks (the shambler's lightning, parasite drain) keep their
beam origins.

Dynamic lights reach the world and models in every game (see "Model
lighting and dynamic lights" below).

Validation: the muzzle and flash tests in `tests/q2_attack_tests.jac`;
`scripts/muzzle_flash_smoke.jac` makes an e1m1 grunt and a base1 light
soldier fire and captures each before and during its flash (inspected: the
walls and floor around each light up, yellow in Q2). It also checks that
base1's areas and area portals load with a door holding its portal.

## Model lighting and dynamic lights

Q1 and Q2 models are lit from the lightmaps below them (`R_LightPoint`): a
`TraceLightPoint` walker runs `RecursiveLightPoint` 2048 units down the BSP
graph (the same `Split` nodes `Locate` walks) to the first surface whose
lightmap holds the point, and its sample is summed over the surface's light
styles, animated by the same `LightStyles` values the world uses (Q1's
`d_lightstylevalue` is now exact: 22/256 a letter). Traces are cached by
point. Q1 models then follow `R_AliasSetupLighting`: ambient and shade light
from that level, dynamic lights adding their radius less their distance to
the ambient, ambient held to 128 and the pair to 192, never below LIGHT_MIN
5 (the view model at least 24), shaded from `lightvec` (-1, 0, 0). Palette
fullbright texels (indices 224-255) stay unlit. Q2 models take the coloured
light (dynamic lights adding `(intensity - distance) / 256` of their
colour), RF_MINLIGHT on the view weapon, RF_GLOW's pulse on every item, and
`shadedots` by yaw in sixteenths of a turn (MH's closed form of
`anorm_dots.h`). MDL and MD2 frames now carry their `anorms.h` normals. Q1
brush pickups (health, ammo boxes) are drawn with their own lightmaps baked
into their skins, as `R_DrawBrushModel` lights them. Q3 models sample the
light grid at their exact origin, dynamic lights adding directed light as
`R_SetupEntityLighting` does.

Dynamic lights follow each client (`light_effects.jac`): Q1's are white
(EF_MUZZLEFLASH 200 + rand&31 with minlight 32, EF_ROCKET 200 on
missile.mdl and lavaball.mdl, the enforcer laser's EF_DIMLIGHT, the quad's
and pentagram's EF_DIMLIGHT, TE_EXPLOSION 350 shrinking 300 a second); Q2's
coloured (muzzle flashes by weapon, EF_ROCKET, EF_BLASTER and
EF_HYPERBLASTER yellow, EF_BFG's `bfg_lightramp`, explosions 350 times their
alpha); Q3's the weapon flash colour at 300 + rand&31, the rocket's 200 and
explosions' 300. The eight nearest the viewer are kept. Q1/Q2 world surfaces
add them as `R_AddDynamicLights` does: the light's radius less its distance
from the surface's plane, falling off with the distance across it, cut below
the minimum light (Q2 `DLIGHT_CUTOFF` 64), on either side of a surface.

Validation: `tests/model_lighting_tests.jac` (the light point trace, Q1 and
Q2 shading rules, vertex normals, fullbright skins, baked pickups, Q3 grid
dynamic lights) and the dynamic light cases in `tests/particle_field_tests.jac`.

## Particles, trails and beams

Particles are spawned once and never touched again on the CPU
(`particle_field.jac`): their motion and colour at any time follow in closed
form from the originals' per-frame rules, evaluated on the GPU from a ring of
spawn records (`render/particles.jac`). Q1 kinds (`pt_fire`, `pt_explode`,
`pt_explode2`, `pt_blob`, `pt_blob2`, `pt_grav`, `pt_slowgrav`,
`pt_static`) integrate `R_DrawParticles`' steps with their colour ramps and
are drawn as the software renderer drew them; Q2 particles are
`CL_AddParticles`' `org + vel t + accel t^2` with fading alpha, drawn as
ref_gl's round dots.

Trails are laid from where each missile or gib was to where it is now
(`EmitTrails`): Q1 `R_RocketTrail` by the model's flags (rocket and lavaball
fire, grenade smoke, gib blood, zombie gibs, wizard and hell knight tracers,
the vore's trail), Q2 `CL_RocketTrail`, `CL_BlasterTrail` (the blaster only:
the hyperblaster's bolts are EF_HYPERBLASTER, lit but trailless) and
`CL_DiminishingTrail` (grenades, gibs), and Q3 smoke puffs every 50 ms
(`CG_RocketTrail`, `CG_GrenadeTrail`) and gib blood (`CG_BloodTrail`).
Explosions burst as `R_ParticleExplosion` and `CL_ExplosionParticles`;
teleports as `R_TeleportSplash` and `CL_TeleportParticles`; missiles strike
walls with `TE_SPIKE`, `TE_SUPERSPIKE`, `TE_WIZSPIKE`, `TE_KNIGHTSPIKE` and
`TE_BLASTER`. The Q2 railgun is `CL_RailTrail`'s particles. Q2 teleporter
pads (`misc_teleporter`) show their dmspot model and EF_TELEPORTER sparkle.

Beams: Q1 lightning is bolt models every 30 units (the player's bolt2.mdl,
the shambler's bolt.mdl, Chthon's bolt3.mdl), lit where they lie; Q2
target_laser and the BFG's lasers are `R_DrawBeam`'s six-sided tubes in one
of their four palette colours each frame; the parasite's drain and the
medic's cable are `CL_AddBeams`' segment models; Q3's lightning gun is
`lightningBoltNew` on four crossed quads (`RB_SurfaceLightningBolt`) and its
rail the `railCore` quad of the default `cg_oldRail` (no spiral rings).

Validation: `tests/particle_field_tests.jac`, `tests/lightfx_render_tests.jac`,
`tests/feedback_tests.jac` and `tests/impact_tests.jac`.
