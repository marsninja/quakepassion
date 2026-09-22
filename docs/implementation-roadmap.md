# Original campaigns and local arena

The target is complete Q1/Q2 single-player campaigns and local Q3 arena matches.
The existing smaller-roster prototype is the baseline described below; the
expanded milestones follow it. Network multiplayer, original mods, and an editor
remain outside the current target.

## Implemented prototype baseline

- One shared spatial graph, renderer, collision/movement system and application
  loop across all three game formats. Walking, crouching, swimming, jump pads,
  teleporters, buttons, translating platforms and supported doors are connected.
- Two hitscan weapons, health/armor/ammunition pickups, damage, death/restart,
  original sounds and a HUD. Q1 soldiers, Q2 soldiers/infantry, and Q3 Sarge bots
  use shared combat behavior with sight memory, local obstacle steering and
  idle/run/attack animation. Q3 body/head/weapon parts use original MD3 tags.
- Q1 silver/gold key doors, Q2 key gates, objective counters, pickup/death target
  activation, key inventory feedback and supported map exits.
- Q2 visited-map state retained across hub returns and save/load. Unit transitions
  clear keys and hub history. Map selection starts fresh; failed loads preserve
  the current world. Save format 5 rejects older snapshots explicitly.
- Escape level/settings menu, persistent settings, F5/F9 save/load, and a local
  ten-frag arena with bot respawn, victory banner and Enter rematch.

## Acceptance and delivery

`jac run scripts/validate_gameplay.jac` builds native persistence, input,
campaign and combat harnesses using a disposable HOME linked to original assets.
It checks all three games, Q1 e1m2 key collection/unlock and onward loading,
Q2 base1/base2 return state, save/load and rollback, and repeated arena kills.
The separate menu runner covers settings, game selection and quitting. Unit
fixtures cover synthetic collision, gameplay and serialization edge cases.

These are controlled automated scenarios, not uninterrupted human campaign
playthroughs. Listening to audio, judging combat feel and exploring authored maps
remain useful manual acceptance. See [campaign details](campaign-gameplay-status.md)
and [combat details](combat-prototype-status.md).

Current local validation uses the source compiler and patch set documented in
[native compiler dependencies](native-lighting-validation-blockers.md). The
released-binary check must be repeated with a release containing those fixes.
Do not substitute source-compiler results for released-binary acceptance.

## Remaining beyond the prototype

Full original campaign branches, boss/rune endings, complete enemies/weapons,
projectiles and original behavior; rotating movers, remaining crusher rules and
trigger/material directives; global bot pathfinding and actor separation;
network multiplayer, original-mod compatibility, and editing tools.

## Expanded original-game target

The current priority is now **complete Q1/Q2 single-player campaigns and local
Q3 arena gameplay**, before further Passion expansion. The implemented prototype
above is the starting point, not acceptance of the expanded scope. Network
multiplayer and original-mod compatibility remain outside this target.

Work is ordered around these remaining milestones:

1. Authored campaign traversal: trains, remaining mover/trigger types and flags,
   map-specific progression, secrets, keys, bosses, runes and endings.
2. Combat: original weapon inventories and projectile behavior, enemy rosters,
   attacks, navigation, damage rules and powerups.
3. Local Q3 matches: weapon/item rules, bot navigation and combat, match flow,
   scoring and map progression.
4. Presentation: remaining animated models/materials, effects, sound and lighting
   behavior needed by the original maps and gameplay.
5. Acceptance: campaign progression coverage, local match play, persistence,
   performance and clean-install validation with the released Jac toolchain.

The first traversal increment adds shared `func_train` movers and `path_corner`
route graphs. It includes activation, Q2 toggle/pause, corner waits, collision and
render transforms, rider carrying, blocking damage and persistence. Collision
bounds cover entire routes. Save format **3** replaces format 2 because route
signals and train state change the snapshot layout; older saves are rejected.

`jac run scripts/audit_campaigns.jac` inventories installed map entities without
loading textures. The installed assets contain 38 Q1, 47 Q2 and 36 Q3 maps with
player starts. This is an inventory, not a campaign-completion certificate.
`tests/train_tests.jac` covers synthetic mover behavior; `scripts/train_smoke.jac`
is a native fixture harness, and `scripts/validate_trains.jac` exercises original
Q1/Q2 maps. No sampled Q3 map contains a train, so Q3 train coverage is synthetic.

Train sounds, exact mover team behavior, and map-by-map human traversal remain
unvalidated. The broader milestones above remain open.

### Train validation checkpoint

- Full local regression suite: **178 passed** with the documented source compiler.

- Eight unit tests and the native mover smoke checks pass, including rider carry, blocked movement, God mode,
  activation, pause/resume, waits, route collision bounds, corner events,
  teleportation and mid-route save restoration.
- Original-map acceptance passes for 87 trains across Q1 `e1m2`, `e1m3`, `e2m6`
  and Q2 `base1`, `fact2`, `ware2`. These checks verify route movement and
  render/collision transforms and restore saved state; they do not play campaigns.
- The native viewer builds. Q1 `e1m2` and Q2 `base1` graphical acceptance pass
  textured frames, camera movement, and PVS/all-visible agreement (zero differing
  pixels).

## Current campaign expansion

See [authored event implementation and validation](authored-events-status.md) for
completed increments beyond the original prototype: delayed activation, startup
triggers, periodic timers, named/triggered opponents, authored hurt volumes,
secret and goal tracking, and Q1 two-stage secret doors. These build on the
shared graph and mover implementation. Weapon inventories, projectiles and
archive-backed firing sounds now have a [shared implementation](weapons-status.md);
original weapon fidelity, complete enemy rosters, bosses,
runes/endings, remaining brush behaviors and full campaign playthroughs remain
open; further Passion features stay deferred.

### Enemy and view-weapon increment

All 28 weapon definitions now load original first-person models. Campaign combat
adds distinct Q1 dog, knight, enforcer and ogre behavior and Q2 soldier variants,
including hostile projectiles. See [view weapons](viewweapons-status.md) and
[enemy validation and remaining work](enemies-status.md). These increments do
not complete the campaign or arena milestones above.

Campaign construction now applies authored difficulty/mode exclusions to all
entities before creating the runtime graph. Shootable buttons share weapon
impacts, explosion damage and mover output with other entities, including saved
partial damage. The Q2 base1 secret now follows its authored shot-button chain.
The full suite passes 237 tests; native campaign acceptance passes these changes.
See [spawn rules](spawn-rules-status.md) and [buttons](buttons-status.md).
