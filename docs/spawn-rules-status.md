# Authored spawn rules

Every map entity is filtered before the level builds collision, movers,
triggers, items, opponents, objectives or target links (`active_entities` in
`engine/world/spawns.jac`, called from `engine/world/level.jac`). The original
archive data is not changed.

- **Q1/Q2 skill.** Entities flagged for exclusion at the current skill are
  dropped: `NOT_EASY` (256) on Easy, `NOT_MEDIUM` (512) on Normal, `NOT_HARD`
  (1024) on Hard and Nightmare, as Q1 `ED_LoadFromFile` and Q2 `SpawnEntities`
  do. The skill is the `skill` cvar, set from the menu's **Skill (next level)**
  row or Q1's `trigger_setskill`, and applies from the next level load (see
  [monster-behaviour-status.md](monster-behaviour-status.md#skill)).
- **Global bits removed.** Surviving Q1 records lose bits 256-2048 and Q2
  records bits 256-4096 (the skill, `NOT_DEATHMATCH` and Q2 `NOT_COOP` flags),
  as Q2 `SpawnEntities` clears them, so they cannot be mistaken for
  class-specific spawnflags. Single-player keeps deathmatch-excluded entities.
- **Q3 free-for-all.** Entities with `notfree` or base-game `notq3a` set, or a
  `gametype` key without `ffa`, are dropped (`G_SpawnGEntityFromSpawnVars`).
  Q3 class-specific spawnflags are kept.

Example: Q2 `base1` has a `trigger_always` with spawnflags 1792 (excluded at
every skill) targeting secret `t91`. Filtered out, it cannot award the secret
at startup; the secret comes from shooting the `func_button` (model 13, health
1).

Sources: [Q1 pr_edict.c](https://github.com/id-Software/Quake/blob/master/WinQuake/pr_edict.c),
[Q2 g_spawn.c](https://github.com/id-Software/Quake-2/blob/master/game/g_spawn.c),
[Q3 g_spawn.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_spawn.c).

## Validation

`tests/spawn_filter_tests.jac`: difficulty applies to every entity and keeps
authored input unchanged, excluded startup triggers cannot award secrets, Q3
free-for-all and base-game exclusions.

## Limitations

- `spawn_filter_tests.jac` exercises Normal skill only; no test calls
  `active_entities` for the Easy or Hard sets.
- Only free-for-all is filtered for Q3; other game types (team, CTF,
  tournament) are not supported.
