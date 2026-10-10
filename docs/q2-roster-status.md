# Quake 2 monster roster

Every monster class in the original Q2 campaign spawns and fights, including
the fliers, swimmers, tanks and the three bosses (Supertank, Hornet and
Jorg/Makron). Each is an `OpponentRule` in `games/enemies.jac`
(`enemy_rule("q2", kind)`) built into an `Opponent` node by
`games/opponents.jac` and driven by the shared `CombatTick` walker in
`engine/world/combat.jac`. Frame lists, event times, damage, muzzles
(`m_flash.c monster_flash_offset`) and sounds come from each `m_*.c` file.

Shared behaviour (noticing, attack chances, dodging, medics, infighting, gibs,
drops, the player trail) is in
[monster-behaviour-status.md](monster-behaviour-status.md); movement, bodies and
movers are in [navigation-status.md](navigation-status.md).

## Roster

| Class | Health | Movement | Attacks |
| --- | ---: | --- | --- |
| `monster_soldier_light` / `monster_soldier` / `monster_soldier_ss` | 20 / 30 / 40 | walk | blaster bolt / 12-pellet shotgun (`attack1` or `attack2`) / 4-11 round machine-gun burst (`attack4`); duck and crouch-fire (`attack3`); run-and-shoot on sighting (`attack6`) |
| `monster_infantry` | 100 | walk | gun burst; `attak2` punch (5-9, knockback) |
| `monster_berserk` | 240 | walk | spike (15-20) or club (5-10) |
| `monster_gladiator` | 400 | walk | two cleaver strikes; rail with aim locked at windup |
| `monster_chick` (Iron Maiden) | 175 | walk | rocket (50 + 50 splash); slash (10-15); both repeat their active section |
| `monster_gunner` | 175 | walk | chaingun burst; grenades beyond 80 units; grenade while ducking on Hard |
| `monster_mutant` | 300 | walk | claws; leap |
| `monster_parasite` | 175 | walk | drain beam |
| `monster_brain` | 300 | walk | claws; tentacle pull; 100-cell power screen |
| `monster_medic` | 300 | walk | blaster; cable revives a corpse |
| `monster_tank` / `monster_tank_commander` | 750 / 1000 | walk | blaster, machine-gun sweep, rockets, chosen by range |
| `monster_supertank` | 1500 | walk | chaingun (repeats), rockets preferred at range; explodes |
| `monster_flyer` | 50 | fly | blade slash loop; twin blasters |
| `monster_floater` | 200 | fly | wham, zap, blaster |
| `monster_hover` (Icarus) | 240 | fly | blaster |
| `monster_flipper` | 50 | swim | bite |
| `monster_boss2` (Hornet) | 2000 | fly | twin machine guns; four rockets at once; explodes |
| `monster_jorg` | 3000 | walk | twin chainguns; BFG; explodes, then Makron |
| `monster_makron` | 3000 | walk | BFG, hyperblaster sweep, locked-aim rail |
| `misc_insane` | 100 | walk / crawl / none | harmless (`AI_GOOD_GUY`); crucified with spawnflag 8 |
| `turret_driver` | 100 | none | mans a `turret_breach` (`engine/world/turrets.jac`) |
| `monster_commander_body`, `monster_boss3_stand` | 1 | none | decorations |

`misc_explobox` barrels use the same rules (10 health, 150 blast).

Details that follow the originals:

- **Soldiers** (`m_soldier.c`, `soldier_attacks` in `games/enemies.jac`):
  - Light and shotgun soldiers attack with `attack1` (attak101-112, shot on
    attak103) or `attack2` (attak201-218, shot on attak205 from the higher
    muzzle, flash 1), half the time each (`soldier_attack`).
  - Each has a refire frame. With the enemy alive it goes back to the frame
    before the shot (attak102, attak204) when the enemy is within 80 units
    (`RANGE_MELEE`) or, on Nightmare, half the time. A blaster soldier tests
    this on attak106/attak208 and otherwise skips to attak110/attak216
    (`soldier_attack1_refire1`). A shotgun soldier cocks its gun first
    (`soldier_cock`, `infantry/infatck3.wav` on attak108/attak213), tests on
    attak109/attak215 and otherwise plays on (`soldier_attack1_refire2`).
    With the enemy dead the frames play straight through.
  - Above Easy, a soldier that first sights its enemy 500 units or more away
    runs at it half the time through runs01-14, striding each frame's
    `ai_charge` distance and firing on runs04 from flash 7
    (`soldier_sight`, `soldier_move_attack6`). On Nightmare it runs on from
    runs03 while the enemy is still that far (`soldier_attack6_refire`).
  - The machine gunner holds its fire frame for the burst in every sequence,
    so its crouched `attack3` fires one burst on attak303 and does not loop.
  - These are `AttackProfile` refire fields (`repeat_near`, `repeat_skill`,
    `repeat_from`, `repeat_unseen`, `repeat_skip`) on the one repeat
    mechanism the chick and gunner use, and a `"sight"` `trigger`.
- **Jorg and Makron** (`m_boss31.c`, `m_boss32.c`): Jorg's rule names
  `monster_makron` as its `successor`. The Makron is built dormant at load and
  takes over Jorg's targets. When Jorg's death animation ends it bursts apart
  (`BossExplode`), and 0.8 s later the Makron is thrown toward the player at
  400 units a second plus 200 up (`MakronToss`, `MakronSpawn`).
- **Hostile BFG** (Jorg, Makron): the orb lasers targets in reach and bursts at
  impact.
- **Gladiator** (`m_gladiator.c`): aim locks when the windup begins, so dodging
  decides whether the rail hits. The rail stops at world geometry. It closes
  through its rail safe zone (112 units) to reach melee. Locked aim is saved.
- **Chick** (`m_chick.c`): the rocket leaves at 1.3 s, 500 units a second. The
  rocket and slash sequences repeat their active section on a range, sight and
  random check without replaying the windup. Recovery steps may be negative
  (backwards) and still check collision and support.
- **Pain** (`pains` on each rule; the mechanism is in
  [monster-behaviour-status.md](monster-behaviour-status.md)). Every monster
  waits 3 s between pains (`pain_debounce_time`) and strides its frames'
  `ai_move` distances, scaled by the model scale.
  - At random: soldiers (`pain1`-`pain3`, 0.33/0.33/0.34), infantry, medic and
    flipper (even odds), brain, mutant and flyer (thirds), floater (`pain1`
    one time in three).
  - By damage: chick and gunner (up to 10, up to 25, more), tank (up to 30, up
    to 60, more), Supertank (10, 25), Hornet (light under 30, else heavy),
    Jorg (50, 100, then `pain3` three times in ten), Makron (40, 110, then
    `pain6` about two times in three up to 150 and nothing above), berserker
    (`pain1` under 20, either from there up), hover (`pain3` or `pain2` up to
    25, else `pain1`).
  - Jorg shrugs off one hit in 200 more while it winds up either attack
    and one in 20000 while its chainguns fire (`pain_shrugs` on the attack).
  - The tank ignores 10 damage or less and shrugs off four hits in five up to
    30; the Supertank and Makron one in five up to 25; Jorg six in ten up to
    40. On Hard and above the tank feels no pain while firing its blaster or
    rockets, nor the Supertank its rockets.
  - Sounds: soldiers, berserker, gladiator, chick, gunner and tank cry before
    the Nightmare test, so they cry on Nightmare too. The others' sounds
    belong to the sequence drawn (infantry `infpain1` with `pain1`, the
    Supertank `btkpain3` with `pain2`) and are silent there. The Hornet has no
    Nightmare test and flinches regardless.
  - Thrown upward faster than 100 units a second, a soldier takes `pain4` and
    a gladiator its `painup` frames instead, and changes to them if thrown
    while already flinching. The soldier picks `pain4` before the Nightmare
    test. No other `m_*.c` has this test.
  - A ducked monster's pain function is not called (`T_Damage`).
  - An insane marine cries with the player's voice for its health
    (`pain25`, `pain50`, `pain75` or `pain100`, either of two) before its
    Nightmare test, and dies with one of the player's four death cries.
    Crucified, it struggles through cross16-30 with one of eight screams
    (`insane_scream`) and is left hanging as it is when killed.
- **Death** (`deaths` on each rule):
  - Soldiers fall on `death3` for a head shot, a hit within 4 units of the
    eye (origin plus viewheight 25), and otherwise on `death1`, `death2`,
    `death4`, `death5` or `death6` at even odds (`soldier_die`). A hit's point
    is a bullet's end, a missile's origin or a blast's centre; of a shotgun's
    pellets the last to land.
  - Infantry take one of three (`death2` with the other death sound), the
    chick one of two with its own sound, brain and mutant one of two; the
    berserker `death1` for a killing hit of 50 or more, else `death2`; the
    hover either death sound.
  - Death frames stride their `ai_move` distances (a soldier's `death1` falls
    back 42 units).
  - Frames make their sounds as they are entered (`events` on the
    sequence): the tank's footstep in `pain3` and its thud on death128,
    Jorg's steps through `pain3`, the Makron's `makron_popup` and
    `makron_taunt` in `pain6` and its steps, `makron_hit` and
    `makron_brainsplorch` as it dies.
  - A corpse keeps its box until the sequence ends and is then left the box
    its `*_dead` sets: -16 -16 -24 to 16 16 -8 for most, 0 to 16 high for the
    chick, -16 to 0 for the tank, and the full-width boxes of the Supertank,
    Hornet and Makron.

## Validation

- `tests/monster_sequence_tests.jac`: every pain and death table against the
  `mmove_t` frame counts and distances, each `*_pain` and `*_die` branch,
  sounds and Nightmare, airborne pain, strides, corpse boxes, saves.
- `tests/q2_roster_tests.jac`: berserker windups and damage, gladiator locked aim
  and saves, rail occlusion and safe zone, cleaver escape, sound cues.
- `tests/q2_roster_expansion_tests.jac`: gunner bursts, grenades and pain by
  damage, flyer, mutant, parasite drain, brain pull/push, tank and Supertank
  choices, Hornet volley and Jorg spawning Makron, Makron sweep and rail,
  hostile BFG, flipper, static bodies.
- `tests/chick_tests.jac`, `tests/q2_attack_tests.jac` (the soldier's attack
  tables, its choice of `attack1` or `attack2`, each refire branch, the
  run-and-shoot and its strides, soldier/infantry bursts, muzzles and
  flashes), `tests/infantry_melee_tests.jac`,
  `tests/enemy_pain_tests.jac`, `tests/dodge_tests.jac`, `tests/turret_tests.jac`,
  `tests/monster_skin_tests.jac` (bloodied skin below half health).
- Native: `scripts/roster_smoke.jac` checks every Q1/Q2 class's frames, sounds
  and missiles against the archives; `scripts/q2_attack_smoke.jac`,
  `scripts/turret_smoke.jac`, and the render captures
  `scripts/chick_render_smoke.jac`, `scripts/berserker_render_smoke.jac`,
  `scripts/gladiator_render_smoke.jac`, `scripts/infantry_render_smoke.jac`,
  `scripts/pain_render_smoke.jac` (an infantry mid-pain, then an infantry
  and a head-shot soldier mid-death and at rest, each restored from a save).

## Limitations

- A dying soldier on `death1` and a dying infantry on `death2` do not fire
  their guns (`soldier_fire6`/`soldier_fire7`, `InfantryMachineGun`).
- The Makron leaves no torso as it dies (`makron_torso`).
- The insane marines' cries carry as far as any other sound; the original
  plays them at `ATTN_IDLE`. A standing marine that has lain down by itself
  (`insane_checkdown`) is not modelled, so only marines spawned crawling take
  the crawling pain and death.
- `soldier_sight` always plays `solsght1.wav`, not `solsrch1.wav` half the time.
  The infantry's gun cock (`infantry_cock_gun` on attak104) and the smack of
  a punch that lands are not played.
- Attack strides head at the target; Q2 `ai_charge` walks along the monster's
  own facing while it turns.
- `misc_actor` is not implemented; no campaign map has one (see
  [map mechanics](map-mechanics-status.md#limitations)).

References: [Q2 game source](https://github.com/id-Software/Quake-2/tree/master/game)
(`m_*.c`, `g_monster.c`, `g_turret.c`, `m_flash.c`).
