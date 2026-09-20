# Campaign and local arena completion plan

The first completion target is a playable Q1/Q2 campaign and local Q3 arena
prototype with a smaller combat roster, as clarified by the user.
Network multiplayer and original-mod compatibility are deferred. The project is
still a gameplay prototype, not a completed implementation of those games.

## Validated foundations

- Shared activation graph, moving buttons, proximity/touch doors and cycle-safe
  relay dispatch.
- Translating platforms with transactional collision and player carrying.
- Teleporters, directional/apex jump pads, liquid queries/swimming, Q2/Q3 crouching
  with matching collision hulls and standing clearance.
- Initial Q1/Q2 campaign exit loading, named Q2 arrivals and failed-load rollback.
- Shared actor health/armor, inventory slots, liquid damage, death and restart.
- MDL/MD2/MD3 model adapters, vertex interpolation, PCX skins and a common model
  renderer; graph-based visual components and shared model resource references.
- Health, armor and shell pickups instantiated in normal play across all three
  games, with shared contact/collection and initial Q3 respawn behavior.

The regression suite passes 133 tests. Native checks cover 14 campaign exits,
Q2/Q3 crouching, death/restart, pickup rendering and collection in all three games,
and all installed model files.
See [campaign status](campaign-gameplay-status.md), [model status](models-status.md),
[buttons](buttons-status.md), [platforms](platforms-status.md),
[traversal](traversal-status.md) and [swimming](swimming-status.md) for evidence
and limits.

## Remaining implementation and acceptance criteria

1. Bind characters to shared model resources; choose animations and compose Q3
   player/weapon attachment tags. Item binding is implemented for the initial roster.
2. Remaining pickups, weapons, hits/projectiles, enemy behaviors and local arena opponents.
   Validate acquisition, combat, kills, deaths, respawn and arena scoring.
3. Campaign keys, objectives, rune/boss progression, Q2 hub state and intermissions.
   Complete representative multi-map routes. Full original campaign branches,
   endings and complete weapon/enemy rosters follow the playable prototype.
4. Save/load and persistent settings; verify restart and cross-map state restoration.
5. Original audio/effects, remaining mover/trigger behaviors, model lighting and
   material passes. Q3 armor's environment, alpha and scrolling additive stages
   now render; other shader directives still need implementation and validation.

Every stage needs focused fixtures and representative native asset checks.
Graphical changes also need desktop captures. No stage is complete merely because
its loaders compile. Compiler defects must be reduced and reported, not bypassed.

Builds currently use the local `qp-cache-sections` compiler described in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md).

The model screenshot-comparison extension remains blocked by
[missing native Path.read_bytes](native-path-read-bytes-blocker.md). Independent
gameplay development continues without bypassing that defect. PR #9323 is no
longer the intended resolution; the native stdlib fix needs separate discussion.
