# Shared combat prototype

`Aim`, `CombatTick`, `Damage` and inventory walkers operate on the shared world
graph. Mouse button 1 fires; keys 1/2 choose an unlimited basic hitscan shot or a
stronger shell-consuming shot. Simulation-time cooldowns, hit feedback, kills,
health/armor, sounds and terminal banners are connected to the application loop.

Q1 soldiers and Q2 soldiers/infantry use original MDL/MD2 models. Q3 has up to
three Sarge bots assembled from lower/upper/head MD3 parts and an attached
machinegun. Skin surfaces and animation frames share the model renderer. Bots
remember the last seen position for eight seconds, sample local clear directions
around obstacles, and select idle/run/attack poses. This is shared prototype
behavior, not a reproduction of each game's original AI. It has no global route
planner or actor separation. Corpses are hidden; arena bots respawn after three
seconds. Ten kills wins the local arena; Enter starts a fresh match.

Native `scripts/combat_smoke.jac` loads, renders and shoots actual opponents in
Q1 e1m1, Q2 base1 and Q3 q3dm1. It checks saved enemy death and ten Q3 kills through
repeated respawn at a controlled firing position. `scripts/gameplay_smoke.jac`
drives raylib input through App.step for weapon selection, ammo use, pause,
death/restart and victory/rematch. Terminal values in that input-specific test
are seeded; the separate combat harness tests kill accumulation.

`scripts/validate_gameplay.jac` runs these together with campaign and persistence
checks, validates rendered captures and stores evidence under
`.jac/screenshots/gameplay`. It uses disposable save/settings directories.
Native audio resource loading and play calls are checked; this does not establish
subjective sound quality or human gameplay feel.

Validation currently requires upstream main plus
[Jac #9388](https://github.com/jaseci-labs/jac/pull/9388). Settings persistence
exposed native splitlines semantics; the engine parser was not rewritten to hide
that defect. A compiler release containing the fixes remains a delivery dependency.
