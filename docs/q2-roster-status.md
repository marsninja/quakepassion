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
| `monster_soldier_light` / `monster_soldier` / `monster_soldier_ss` | 20 / 30 / 40 | walk | blaster bolt / 12-pellet shotgun / 4-11 round machine-gun burst; duck and crouch-fire (`attack3`) |
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
- **Pain**: soldiers and the chick recover in 0.5 s, berserkers 0.4, gladiators
  0.6 and infantry 1.0, with a 3 s cooldown. Monsters with several pain
  sequences (`pain_variants`: the gunner, flyer, floater, hover, mutant, brain,
  medic, flipper, tanks, Supertank, Hornet, Jorg and Makron) choose by damage
  (`pain_variant_damage`) or at random, as their originals do.

## Validation

- `tests/q2_roster_tests.jac`: berserker windups and damage, gladiator locked aim
  and saves, rail occlusion and safe zone, cleaver escape, sound cues.
- `tests/q2_roster_expansion_tests.jac`: gunner bursts, grenades and pain by
  damage, flyer, mutant, parasite drain, brain pull/push, tank and Supertank
  choices, Hornet volley and Jorg spawning Makron, Makron sweep and rail,
  hostile BFG, flipper, static bodies.
- `tests/chick_tests.jac`, `tests/q2_attack_tests.jac` (soldier/infantry bursts,
  muzzles and flashes), `tests/infantry_melee_tests.jac`,
  `tests/enemy_pain_tests.jac`, `tests/dodge_tests.jac`, `tests/turret_tests.jac`,
  `tests/monster_skin_tests.jac` (bloodied skin below half health).
- Native: `scripts/roster_smoke.jac` checks every Q1/Q2 class's frames, sounds
  and missiles against the archives; `scripts/q2_attack_smoke.jac`,
  `scripts/turret_smoke.jac`, and the render captures
  `scripts/chick_render_smoke.jac`, `scripts/berserker_render_smoke.jac`,
  `scripts/gladiator_render_smoke.jac`, `scripts/infantry_render_smoke.jac`,
  `scripts/pain_render_smoke.jac`.

## Limitations

- Each monster plays one death sequence: the authored `death_frames` or the
  model's first contiguous `death` family (`games/opponents.jac`). The
  originals' random choices among death animations are not made.
- The soldiers, infantry, berserker, gladiator and chick play one pain sequence;
  the originals choose by damage or at random (for example `berserk_pain`).
- Pain frames carry no movement steps, and there are no airborne pain reactions.
- Light and shotgun soldiers always fire `attack1` (and `attack3` when
  dodging); `soldier_attack` picks `attack1` or `attack2` half the time each.
- `misc_actor` and `target_actor` are not driven (no shipped map pairs them).

References: [Q2 game source](https://github.com/id-Software/Quake-2/tree/master/game)
(`m_*.c`, `g_monster.c`, `g_turret.c`, `m_flash.c`).
