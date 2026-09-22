# Authored spawn rules

Q1/Q2 campaign loading now filters every entity for normal difficulty before
building collision, movers, triggers, items, opponents, objectives or target
links. Previously only enemies checked the difficulty flags. Surviving runtime
records have global mode/difficulty bits removed so those bits cannot be mistaken
for unsupported entity-specific behavior. Original archive data remains intact.

The visible failure was Q2 `base1`: a `trigger_always` with spawnflags 1792
(excluded from all three campaign skill groups) targeted secret `t91`. It ran
at startup and awarded a secret without exploration. It is now excluded. The
legitimate `func_button` model 13 has health 1 and must instead be shot.

Local Q3 free-for-all loading applies `notfree`, base-game `notq3a`, and authored
`gametype` restrictions. Q3 class-specific spawnflags are preserved. These are
rules for the currently supported normal campaigns and local free-for-all;
selectable campaign difficulty and other match modes remain future work.

Save format 6 rejects previous snapshots because entity filtering changes
positional records and shootable buttons add persistent health state.

Sources:

- [Q1 entity spawning](https://github.com/id-Software/Quake/blob/master/WinQuake/pr_edict.c)
- [Q2 entity spawning](https://github.com/id-Software/Quake-2/blob/master/game/g_spawn.c)
- [Q3 entity spawning](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_spawn.c)

Validation: all 237 unit tests pass with the documented source compiler. The
native campaign harness passes startup exclusion, actual model-13 damage and
endpoint secret activation, Q2 hub/save/load, and Q1 key/exit progression.
