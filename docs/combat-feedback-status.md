# Combat feedback

What a fight looks and sounds like beyond the weapons themselves: hit
particles, impact sounds and marks, monster attack cues and muzzle flashes,
model lighting and dynamic lights, and particle trails and beams. All of it is
cosmetic: it never consumes gameplay random numbers or changes damage, and it
is not saved. Monster attack sequences and pain are described per monster in
[q1-roster-status.md](q1-roster-status.md) and
[q2-roster-status.md](q2-roster-status.md).

## Hits

Every hitscan wall impact and actor hit emits its game's particles at the real
pellet endpoint and wall normal: Q1 `TE_GUNSHOT` and `SpawnBlood`
(`R_RunParticleEffect`), Q2 `TE_GUNSHOT` and `TE_BLOOD` (`CL_ParticleEffect`),
and a short spray of sparks in Q3 and Passion. Particles draw on their own
`rand()` stream.

Shots that strike the world play each game's impact sound once, from where
they struck (`ImpactSound` nodes), chosen by a roll derived from the impact
point:

- Q1 (`CL_ParseTEnt`): nails and super nails `tink1` four times in five, else
  `ric1`-`ric3`; the enforcer's laser `enfstop`; Scrag and Hell Knight spikes
  their `hit` sounds. `TE_GUNSHOT` is silent.
- Q2: bullets (`TE_GUNSHOT`: machine gun, chaingun, monster guns)
  `world/ric1`-`ric3` three times in sixteen; shotgun pellets (`TE_SHOTGUN`)
  silent; blaster bolts `lashit`.
- Q3 (`CG_MissileHitWall`): the machine gun always ricochets, the lightning gun
  plays its `lg_hit` sounds, the shotgun is silent.

Sky (Q2/Q3 `SURF_SKY`) and Q3 `SURF_NOIMPACT` sides take no sparks, sound or
mark, and missiles striking them vanish without exploding (`G_MissileImpact`,
`rocket_touch`).

## Q3 impact marks

Q3 leaves `CG_ImpactMark` marks (`ImpactMark` nodes, `engine/world/particles.jac`):
`bullet_mrk` for the machine gun (radius 8) and shotgun (4), `hole_lg_mrk` for
the lightning gun (12), `burn_med_mrk` for rockets and grenades (64) and the BFG
(32), and `plasma_mrk` for the plasma gun (16) and railgun (24, in the rail
colour). Each is a square on the struck plane at a random turn. Bullet, burn
and hole marks darken what is behind them (`GL_ZERO GL_ONE_MINUS_SRC_COLOR`)
and fade their colour; energy marks blend by alpha, their glow dying over three
seconds. Marks last 10 s, fading over the last one. A grenade bursting at rest
marks the floor under it. Marks go only on world brushes, as Q3 marks only the
world model; `SURF_NOMARKS` sides take none.

Each mark is cut to the world faces it covers as `R_MarkFragments` cuts it: the
square's edge planes, projected 20 units along the shot with planes 32 beyond
and 20 before, clip every face of the leaves the box reaches (the `BoxSurfaces`
walker walks the BSP graph as `R_BoxSurfaces_r`). Planar faces within 60
degrees of the shot and patch triangles take marks; `SURF_NOIMPACT`,
`SURF_NOMARKS`, fog faces and triangle soups do not. A mark stops at an edge,
wraps into a corner, and is not left with nothing behind it. The pieces are
drawn as polygons (`ScenePolygons`, `RE_AddPolyToScene`); the pool holds 256
polygons (`MAX_MARK_POLYS`) and the oldest marks give way.

## Monster attacks

- **Cues.** Attack, sight, pain, death and idle sounds play through positional
  graph speakers. Attack cues fire at their authored times on the attack clock,
  bounded by timeline crossings (including floating-point frame boundaries),
  and a restored attack does not replay earlier cues.
- **Poses.** Attack and pain poses advance at 10 Hz; pain holds its last pose
  and derives from the remaining recovery timer, so a restored reaction resumes
  mid-pose. Death holds the last frame.
- **Muzzles.** Shots leave per-attack muzzles (`AttackProfile.muzzles`:
  forward, right and up from the origin, one per shot of a sequence, or one per
  gun of a `volley`). Q2 monsters use `m_flash.c monster_flash_offset` through
  `G_ProjectSource` (the soldier's by attack; the gunner's, tank's and Makron's
  sweeps by frame; the Hornet's and Jorg's twin guns and the Hornet's four
  rocket tubes as volleys). Q1 monsters use their QuakeC launch origins. Aim
  runs from the muzzle, and a wall between the origin and the muzzle stops the
  shot there, as `fire_lead`'s origin trace does.
- **Flashes.** Each shot lights a 0.1 s dynamic light at the muzzle in its
  weapon's colour (Q2 `CL_ParseMuzzleFlash2`: yellow guns and blasters, orange
  rockets and grenades, blue rails, green BFG; Q1 `EF_MUZZLEFLASH` on the grunt,
  enforcer, ogre, Scrag, shambler and vore). Beam attacks (shambler lightning,
  parasite drain) keep their beam origins.

## Model lighting and dynamic lights

Q1 and Q2 models are lit from the lightmaps below them (`R_LightPoint`): a
`TraceLightPoint` walker runs `RecursiveLightPoint` 2048 units down the BSP
graph to the first surface whose lightmap holds the point, summed over its
light styles (the world's `LightStyles` values; Q1 `d_lightstylevalue` is
22/256 a letter). Traces are cached by point.

- **Q1** follows `R_AliasSetupLighting`: ambient and shade light from that
  level, dynamic lights adding their radius less their distance, ambient held
  to 128 and the pair to 192, never below `LIGHT_MIN` 5 (the view model at
  least 24), shaded from `lightvec` (-1, 0, 0). Palette fullbright texels
  (224-255) stay unlit. Brush pickups (health, ammo boxes) carry their own
  lightmaps baked into their skins, as `R_DrawBrushModel` lights them.
- **Q2** takes the coloured light (dynamic lights adding `(intensity -
  distance) / 256` of their colour), `RF_MINLIGHT` on the view weapon,
  `RF_GLOW`'s pulse on every item, and `shadedots` by yaw in sixteenths of a
  turn (a closed form of `anorm_dots.h`). MDL and MD2 frames carry their
  `anorms.h` normals.
- **Q3** models sample the light grid at their origin, dynamic lights adding
  directed light as `R_SetupEntityLighting` does.

Dynamic lights follow each client (`engine/world/light_effects.jac`). Q1's are
white: `EF_MUZZLEFLASH` 200 + rand&31 with minlight 32, `EF_ROCKET` 200 on
missile.mdl and lavaball.mdl, the enforcer laser's and the quad's and
pentagram's `EF_DIMLIGHT`, `TE_EXPLOSION` 350 shrinking 300 a second. Q2's are
coloured: muzzle flashes by weapon, `EF_ROCKET`, `EF_BLASTER` and
`EF_HYPERBLASTER` yellow, `EF_BFG`'s `bfg_lightramp`, explosions 350 times their
alpha. Q3's are the weapon flash colour at 300 + rand&31, the rocket's 200 and
explosions' 300. The eight nearest the viewer are kept. Q1/Q2 world surfaces
add them as `R_AddDynamicLights` does: the light's radius less its distance
from the surface's plane, falling off with the octagonal texel distance across
the face (`engine/render/world_mesh.jac`), cut below the minimum light (Q1
`minlight`, Q2 `DLIGHT_CUTOFF` 64), on either side of a surface.

## Particles, trails and beams

Particles are spawned once and never touched again on the CPU
(`engine/world/particle_field.jac`): their motion and colour follow in closed
form from the originals' per-frame rules, evaluated on the GPU from a ring of
spawn records (`engine/render/particles.jac`). Q1 kinds (`pt_fire`,
`pt_explode`, `pt_explode2`, `pt_blob`, `pt_blob2`, `pt_grav`, `pt_slowgrav`,
`pt_static`) integrate `R_DrawParticles`' steps with their colour ramps and
draw as the software renderer did; Q2 particles are `CL_AddParticles`'
`org + vel t + accel t^2` with fading alpha, drawn as ref_gl's round dots.
Particles pass through surfaces, as the originals' do: neither
`R_DrawParticles` nor `CL_AddParticles` traces them.

- **Trails** run from where each missile or gib was to where it is now
  (`EmitTrails`): Q1 `R_RocketTrail` by model flags (rocket and lavaball fire,
  grenade smoke, gib blood, zombie gibs, Scrag and Hell Knight tracers, the
  vore's trail); Q2 `CL_RocketTrail`, `CL_BlasterTrail` (the blaster only; the
  hyperblaster's `EF_HYPERBLASTER` bolts are lit but trailless) and
  `CL_DiminishingTrail` (grenades, gibs); Q3 smoke puffs every 50 ms
  (`CG_RocketTrail`, `CG_GrenadeTrail`) and gib blood (`CG_BloodTrail`).
- **Bursts**: `R_ParticleExplosion` and `CL_ExplosionParticles`,
  `R_BlobExplosion` (the spawn), `R_LavaSplash` (Chthon), `R_TeleportSplash` and
  `CL_TeleportParticles`, and wall strikes `TE_SPIKE`, `TE_SUPERSPIKE`,
  `TE_WIZSPIKE`, `TE_KNIGHTSPIKE` and `TE_BLASTER`. The flying Q2 BFG ball
  carries `CL_BfgParticles`; Q2 teleporter pads (`misc_teleporter`) show their
  dmspot model and `CL_TeleporterParticles` each client frame. The Q2 railgun
  is `CL_RailTrail`'s particles.
- **Beams**: Q1 lightning is bolt models every 30 units (the player's
  bolt2.mdl, the shambler's bolt.mdl, Chthon's bolt3.mdl), lit where they lie;
  Q2 `target_laser` and the BFG's lasers are `R_DrawBeam`'s six-sided tubes in
  one of their four palette colours each frame; the parasite's drain and the
  medic's cable are `CL_AddBeams`' segment models; Q3's lightning gun is
  `lightningBoltNew` on four crossed quads (`RB_SurfaceLightningBolt`) and its
  rail the `railCore` quad of the default `cg_oldRail`.

## Validation

- Tests: `tests/feedback_tests.jac` (wall feedback keeps damage events and
  random state, pain and death poses, turning), `tests/impact_tests.jac`,
  `tests/model_lighting_tests.jac` (light point trace, Q1/Q2 shading, normals,
  fullbrights, baked pickups, Q3 grid dynamic lights),
  `tests/particle_field_tests.jac` (particles and dynamic lights),
  `tests/lightfx_render_tests.jac`, `tests/effect_quads_tests.jac`,
  `tests/enemy_sound_tests.jac` and `tests/q2_attack_tests.jac` (cue timing,
  muzzles and flashes), `tests/enemy_pain_tests.jac`.
- Native: `scripts/feedback_render_smoke.jac` (Q1 shotgun impacts and blood),
  `scripts/impact_marks_smoke.jac` (every Q3 hitscan and missile weapon at a
  q3dm1 wall: sparks, marks, and marks four seconds later),
  `scripts/muzzle_flash_smoke.jac` (an e1m1 grunt and a base1 soldier before and
  during a flash), `scripts/pain_render_smoke.jac`,
  `scripts/attack_timing_smoke.jac` and `scripts/q2_attack_smoke.jac` (attack
  frames against the original models), and `scripts/effects_gallery.jac` (one
  posed frame per game with every effect kind, for comparison by eye).
