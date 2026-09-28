# Authored activation and timing

The shared activation graph now supports Q1/Q2 delayed outputs, Q3 `target_delay`,
Q2/Q3 `trigger_always`, and Q2/Q3 `func_timer`. Delayed contact triggers, buttons,
doors, key gates and counters retain their normal activation rules.

Q1/Q2 delayed outputs queue independent uses. Q3 delay entities replace their
pending timer when used again. Timer intervals support bounded variance through
an entity-local random stream; save/load restores that stream, queued delays,
activator inventory, running state and remaining interval. Event collection and
emission are separate phases, so newly queued events do not lose time based on
entity registration order. Timers emit at most once per simulation tick.

The implementation follows the original [Q2 target dispatch](https://github.com/id-Software/Quake-2/blob/master/game/g_utils.c),
[Q2 timers](https://github.com/id-Software/Quake-2/blob/master/game/g_func.c),
[Q3 delay entities](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_target.c),
and [Q3 startup triggers and timers](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_trigger.c).
It preserves scheduling behavior, not the original engines' global random sequence.

Named monsters in the supported combat roster are no longer discarded. Q2's
triggered-spawn flag instead creates a dormant, hidden opponent: activation starts
its spawn countdown, then enables combat and rendering. Dormant opponents cannot
be hit or carried by trains. Snapshots preserve dormancy and the countdown.
Q2 `deathtarget` overrides the outgoing death target. The underlying reference is
[Q2 monster activation](https://github.com/id-Software/Quake-2/blob/master/game/g_monster.c).

## Validation

- Focused signal/trigger tests cover queueing, timer reset, one-shot delivery,
  registration-order independence, activator inventory, persistence, startup
  timing, periodic toggling and repeatable variance.
- `scripts/validate_events.jac` exercises original Q1 `e1m2`/`e2m6`, Q2
  `base1`/`fact2`/`ware2`, and Q3 `q3dm7`/`q3dm17`. It checks exact snapshot
  round-trips after advancing the event scheduler. Recipients without a use are
  skipped rather than disabling their chain; `scripts/chain_audit.jac` reports them.
- Save format 3 includes these states together with train movers. No version-3
  snapshot was released before this branch; version-2 saves remain incompatible.

## Remaining original behavior

`killtarget`, unrestricted monster-spawner classes, monster path patrols,
monster-on-monster spawn telefrags, timer-linked sound/effect entities, and
remaining combat rosters are still open. Named-monster support applies to the
existing roster, not every original enemy. Campaign playthrough acceptance and
full Q3 match behavior remain separate milestones.

## Damage volumes and progress

Shared `trigger_hurt` volumes now damage players and active opponents, including
local arena bots. Q1 uses its one-second contact interval; Q2/Q3 support startup
disabling, remote toggles, slow damage and armor bypass. God mode remains the
player's explicit override. Hazard cooldown and activation state survive saves.
Original-map probes pass for 26 volumes in Q1 `end`, Q2 `fact2`/`power2`, and
Q3 `q3dm17`/`q3dm12`. These checks validate contact damage and snapshots, not
sound or complete environmental damage behavior for every monster.

Q1 `trigger_secret` and Q2 `target_secret`/`target_goal` use a shared progress node.
Each counts once, forwards its targets, and updates the campaign HUD. Progress
and consumed objective signals are persisted together. Asset validation confirms
Q1 `e1m1` contact discovery (six total secrets), and Q2 `base1` activation (three
secrets and one goal), including save restoration.

## Q1 secret doors

Q1 secret doors now build their opening and return paths with the same mover
nodes, collision sweeps, rider handling and snapshot records as trains. They
support two-stage travel, corner pauses, open-once behavior, named activation,
shoot activation and first-left/first-down directions. The weapon trace identifies
the brush that was actually hit before requesting activation. Original-map route
and snapshot checks pass for 17 doors in `e1m1`, `e1m2`, `e2m1` and `e4m1`.

The reference is the original [Q1 secret-door state sequence](https://github.com/id-Software/Quake/blob/master/qw-qc/doors.qc).
Mover sound sequencing, Q2's secret-door variant, and `killtarget` effects remain
open; this is not a claim that all authored door behavior is complete.

## Sound emitters and Q2 brush state

Q2/Q3 `target_speaker` emitters now participate in activation chains. Native
archive-backed streams handle one-shot requests, looping toggles, menu pause,
volume, distance attenuation and stereo pan. Loop state and queued requests are
saved. Streams retain their source bytes until unloaded; map changes release
streams and archive handles. Native audio acceptance passes for Q2 `base1`
(84 emitters, 79 decoded streams) and Q3 `q3dm7` (20 emitters/streams), including
pause, toggle and cleanup. These are playback/resource checks, not a listening
review of original-engine acoustics.

Speakers now follow each game's `SP_target_speaker`. Q2 loops always play at
volume 1 with the looping falloff, one-shots keep their `volume` and
`attenuation` (-1 is heard everywhere), and sexed `*` sounds play at the
speaker in the male voice. Q3 ignores those keys; its global (4) and
activator (8) speakers play at full volume. A Q3 speaker with a `random` of a
tenth or more also sounds by itself every `wait` seconds, give or take
`random` (`CG_Speaker`, which tests `s.clientNum`, so `wait` alone does
nothing), over its loop if it has one. Every positioned sound falls off as its
game mixes it (`sound_falloff`): Q1 `SND_Spatialize` (attenuation/1000 a
unit), Q2 `S_SpatializeOrigin` (full within 80 units, then 0.0005 per
attenuation, 0.001 for ATTN_STATIC, 0.003 for loops) and Q3 (full within 80,
then 0.0008). Q2 and Q3 missiles carry their flight sounds (rockets, blaster
bolts, BFG, hand grenades, plasma), and the Q2 player's own looping sound
follows `G_SetClientSound`: frying in slime or lava, the railgun and BFG hums,
the hyperblaster firing, the chaingun spinning and a cooking grenade. Q1
teleporters hum (`ambience/hum1.wav` at the trigger's centre unless SILENT),
`ambient_thunder` rumbles, and Q2 teleporter pads loop `world/amb10.wav`. The
original occlusion model (PVS-limited sounds) remains open.

Q2 toggle walls now change visibility and collision together. Destructible
brushes accept shots or authored activation, disappear from world traces and
rendering, emit their targets, and can apply blast damage and chain reactions.
Shared opponent-death handling preserves target activation and kill credit for
weapon and environmental damage. Save restoration reconstructs brush collision
and visibility from the authored baseline. Original-map state checks pass for
18 brushes in `base1`, `base2`, `fact1` and `ware1`. Animated brush textures,
explosion/debris effects and complete spawn-overlap behavior remain open.

The brush rules follow [Q2's wall and explosive entities](https://github.com/id-Software/Quake-2/blob/master/game/g_misc.c).
The native streaming ABI is from [raylib 6.0](https://github.com/raysan5/raylib/blob/6.0/src/raylib.h).

## Q1 platform collision bounds correction

Q1 submodel collision bounds now include the original runtime's one-unit
expansion before player-hull expansion. Previously the broad-phase filter could
skip a real collision in that outer unit. In `e1m1`, the player sank into lifts
7 and 22, causing ground probes to report a solid start and preventing walking;
lift 7 also stalled just below its upper endpoint. This is an engine bounds bug,
not a Jac compiler defect.

The regression fails with the old bounds and passes after the correction. It
compares indexed versus exhaustive collision on all six faces of a translated
Q1 hull. Twenty-three collision/platform/train tests pass. The native
`scripts/platform_walk_smoke.jac` verifies full rises and subsequent walking on
both `e1m1` lifts and Q2 `base3` lift 41.

The source behavior is `Mod_LoadSubmodels` in
[Quake's model loader](https://github.com/id-Software/Quake/blob/master/WinQuake/model.c).
