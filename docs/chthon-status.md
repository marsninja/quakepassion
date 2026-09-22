# Q1 Chthon encounter

The `monster_boss` entity now loads the original boss model and waits for its
map activation. A dedicated graph walker runs rise, attack, shock and death
phases. Two traveling lava balls are emitted during each attack cycle using the
original projectile model. Ordinary weapon damage does not reduce boss health.

The `event_lightning` node connects to the two authored electrode doors. It
rejects misaligned or moving electrodes, holds an accepted discharge for one
second, then returns both movers. An aligned lowered pair removes one boss
health point. Normal difficulty requires three strikes. The final shock and death
phases fire the boss output once and award one kill. An active beam is drawn
between the electrodes. Boss phase/time and lightning duration survive saves.

The original map uses `target="lightning"` as an electrode marker without a
matching target entity. Missing target recipients are now harmless no-ops;
existing recipients with unimplemented behavior remain guarded. This corrects
previously frozen electrodes without adding a map-name exception. Reference:
[original boss behavior](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/boss.qc).

Three unit regressions cover activation, weapon immunity, lava-ball timing,
alignment, duplicate discharge requests, three strikes, one death output and
saved shocks. The native `scripts/chthon_smoke.jac` passes the original `e1m7`
model/door/event sequence with save restoration after every strike. The separate
render harness captures the original model in its arena; that image was inspected.

This does not establish complete encounter fidelity. Remaining details include
original sounds and lava splash effects, yaw rate, damage randomness, wide actor
collision/hit bounds, and a player-driven fight through the authored buttons.
The native harness drives target requests and does not claim an uninterrupted
human boss fight. Easy difficulty and the final Shub-Niggurath encounter remain
outside this implemented increment.
