# Q1 rune progression and hub gates

The four episode sigils load their original `progs/end1.mdl` through `end4.mdl`
assets. Collecting a sigil unions its authored rune bits into persistent inventory,
hides the pickup and fires its target chain. Duplicate bits do not accumulate.
The HUD lists collected rune numbers. Rune inventory survives ordinary map
transitions, death/restart and save/load; choosing a map starts a fresh run.

The `start` hub's `func_episodegate` brushes become visible and solid for completed
episodes. Its `func_bossgate` remains solid until all four runes are collected.
A shared graph walker updates both faces and collision hulls from inventory before
uploading a newly loaded map and after restoring a snapshot. Gate brushes are now
included in the Q1 collision loader. The rules follow the original
[items](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/items.qc)
and [gate definitions](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/misc.qc).

Three regression tests cover repeated/combined rune flags, target dispatch,
key clearing without losing runes, partial completion, and restored gate geometry.
The native `scripts/rune_smoke.jac` loads and collects each authored rune in
`e1m7`, `e2m6`, `e3m6`, and `e4m7`, then checks all five gates in `start` and
round-trips the completed inventory through a save.

These are controlled pickup/progression checks, not completed episode playthroughs.
The [Chthon encounter](chthon-status.md) now has a separate implementation and
acceptance harness. Shub-Niggurath, finale/cutscene presentation and other missing
combat/entity behavior still prevent claiming complete original campaigns. Rune-specific sound
and pickup-placement fidelity also remain presentation work.
