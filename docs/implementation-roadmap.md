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
  the current world. Save format 8 rejects older snapshots explicitly.
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
The full suite passes 251 tests; native campaign acceptance passes these changes.
See [spawn rules](spawn-rules-status.md) and [buttons](buttons-status.md).

Q1/Q2 shootable door groups now receive direct and radius damage, retain partial
damage across saves, and dispatch targets at the start of opening. See
[door updates](doors-status.md#campaign-damage-activation-update).

Released-toolchain CI remains blocked on the newer compiler features/fixes.
PR #35's v0.37.21 Linux build first rejects the union-typed BSP edge endpoints
in `engine/world/level.jac`; local native acceptance uses the documented patched
source compiler. v0.37.21 is still the latest release checked on September 22.

### Rune and mover-state progression

Q1 rune inventory, completed-episode gates and the final hub gate now follow
the authored progression rules, with original assets and native save/load checks.
See [rune acceptance and remaining limits](runes-status.md). Start-open doors
and Q1/Q2 toggle doors now share the translating-mover implementation; native
acceptance covers 24 groups across six original maps. This still does not complete
the boss encounters, endings, full combat rosters or local-arena milestones.

The first boss increment adds [Chthon's electrode encounter](chthon-status.md):
activation, original model/attack phases, hostile lava balls, aligned lightning
strikes, saved encounter state and delayed death output. Native original-map
acceptance passes; full encounter fidelity and player-driven playthrough remain
open, as does the final boss.

Latest regression checkpoint: **251 tests pass** with the documented local
source compiler. The combined native viewer builds and completes graphical smoke
runs for Q1 `e1m1`, Q2 `base1`, and Q3 `q3dm1`. Native rune and Chthon harnesses
pass the controlled authored-map scenarios described above. Save format 8 is the
current layout; older snapshots are rejected.

Fresh screenshots have zero PVS/all-visible pixel differences at spawn and after
movement in all three sampled maps. The PNG comparison ran through Jac's server
codespace: its temporary caller could not lower a cross-module `Path` argument
(`Cannot assign Path to parameter path of type Path`). This is not a native
validator acceptance claim; the game executables producing the images were native.

### Combat continuation (current checkpoint)

The latest combat work is tracked in [combat feedback](combat-feedback-status.md):
pellet impacts, blood, pain/death poses, weapon bob/recoil, Q1 attack timelines,
Q2 held gun bursts and infantry melee, and Q1 ogre sweep/smash/grenade sequences.
The current snapshot version is **11**. Earlier validation counts and snapshot
versions above describe historical checkpoints.

The expanded scope remains open. The largest remaining tasks are the unsupported
Q1/Q2 enemy rosters and final encounters, authored campaign traversal coverage,
global navigation and local Q3 weapon/item tactics, plus original audiovisual
feedback and released-toolchain acceptance. Existing automated scenarios do not
establish uninterrupted completion of the original campaigns.


### Q2 roster continuation

Berserkers and gladiators now join the shared campaign combat system, including
alternate melee damage profiles, locked-aim railgun windup and trails, and
positional attack cues. See [Q2 roster status](q2-roster-status.md) for behavior,
validation, and remaining limits. Current snapshot format: **12**.

The [Q2 rocket enemy](chick-status.md) adds authored rocket/slash cycles,
conditional refires, explicit locomotion poses and signed recovery movement.
Snapshot format is now **13**. Full original campaigns and local-arena acceptance
remain open; prior prototype validation is not a completion claim.

Q1's [Hell Knight](hell-knight-status.md) now has its canonical spike volley and
close-range slice in the shared combat engine. Snapshot format is **14**.
Its remaining attack repertoire and the broader campaign/arena milestones remain
open.

Supported Q2 enemies now have explicit pain sequences, per-enemy recovery timing,
and save-resumed poses; see [combat feedback](combat-feedback-status.md).
The latest regression checkpoint is **293 passing tests**, with native asset and
pain-render checks. Snapshot format remains **14**.

The next navigation increment adds collision-checked ground detours shared by
campaign enemies and arena bots. See [ground navigation](navigation-status.md)
for search limits, validation, and remaining global traversal work.

Enemies now participate in automatic door activation, door obstruction checks,
and platform carrying; see [enemy movers](enemy-movers-status.md). This retains
key/remote activation restrictions and supports Q2's `NOMONSTER` flag.

[Actor body isolation](actor-body-status.md) separates enemy movement and hit
bounds from player crouching, including platform/train carrying and attack-step
movement. Original per-monster hull dimensions and duck behavior remain open.

### Remaining-scope milestones (September 2026)

The remaining original-game scope is being completed in stacked milestones:
powerups and item presentation, Q3 ladder matches, map mechanics, monster
behavior and difficulty, Q3 bot tactics and navigation, presentation (HUDs,
light styles, effects), and full playthrough validation.

[Powerups, holdables and item presentation](powerups-status.md): all original
powerups and Q3 holdables as graph effects, per-item original pickup sounds,
item spin/bob and Q3 ring models. Snapshot format 18.

[Q3 arena matches and the ladder](arena-match-status.md): `arenas.txt` rosters
and frag limits, bots fighting every competitor, frag credit, respawns at the
furthest spawn, the announcer and scoreboard, and ladder progression. Snapshot
format 19.

[Map mechanics](map-mechanics-status.md): rotating doors and periodic movers,
crush damage, complete trigger chains (named, shootable, directional,
killtargets, messages), traps, Q2 targets and cross-level flags, spawners,
barrels, fixtures and ambience. Snapshot format 20.

[Monster behaviour](monster-behaviour-status.md): skill selection, original
awareness and hearing, idle path-corner patrols and Q2 combat points,
infighting by the Q1/Q2 rules, and gibbing into the original models with
shootable Q2/Q3 corpses. Snapshot format 21.

[Q3 bot tactics](bot-tactics-status.md): map-wide routing over the maps' own AAS
data, botlib characters and weapon weights, original weapon choice, aim, view
turning, reaction and fire throttle, combat movement, real weapon fire, and the
Excellent, Impressive, Humiliation and Perfect awards.
