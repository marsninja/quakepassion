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

The boss now plays boss.qc frame by frame at 10 Hz: `boss_rise` with out1 and
sight1, `boss_missile` turning 20 degrees a frame toward the player
(`boss_face`/`ChangeYaw`, `yaw_speed` 20) and throwing a lava ball on attack9 and
attack20 from `makevectors(vectoangles(...))` offsets (leading the player's ground
speed above Normal, 100 to 120 damage, throw.wav), `boss_idle` while the player
is dead, the shock families with pain.wav, and death with death.wav, out1 and a
lava splash before `boss_death10` counts it and fires its targets. `boss_awake`
sets health by skill (one strike on Easy) and the boss has its 256-unit box.
`lightning_use` plays misc/power.wav, ignores only uses made as a bolt starts,
and `lightning_fire` emits a `q1_lightning3` beam every tenth of a second, its far
end 100 units short. The lava splash uses the explosion event kind
`q1_lavasplash`, whose look belongs to the particle work.

The native harness drives target requests and does not claim an uninterrupted
human boss fight. The final Shub-Niggurath encounter remains outside this
increment.
