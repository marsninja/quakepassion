# Scope and remaining work

The target is the original Quake and Quake II single-player campaigns and the
Quake III Arena single-player ladder, each played by its own rules inside the
one engine, plus the generated Passion mode. Network multiplayer, mods, other
Q3 game types, an editor, and entity classes no campaign map uses (Q2's
`misc_actor`) are out of scope.

## Where things stand

- **Quake**: all 32 campaign maps (start, four episodes, end) load, link their
  exits and play through. All sixteen v101qc monster classes are driven,
  including Chthon and Shub-Niggurath; runes, episode gates, secrets,
  intermissions and the finale text follow the QuakeC.
  See [q1-roster-status.md](q1-roster-status.md) and [level-flow-status.md](level-flow-status.md).
- **Quake II**: all 39 campaign maps across the units, with hub returns and
  remembered levels, the help computer carried across levels, cinematics and
  music, and the full base-game roster through Jorg and Makron.
  See [q2-roster-status.md](q2-roster-status.md).
- **Quake III Arena**: the `arenas.txt` ladder as free-for-all matches against
  botlib bots (AAS routing, travel types, fuzzy weights, the ai_dmnet.c nodes,
  chat), with scoring, awards, the podium and ladder progress.
  See [arena-match-status.md](arena-match-status.md) and [bot-tactics-status.md](bot-tactics-status.md).
- **Shared engine**: per-game movement profiles, the shared pusher for every
  mover, per-game weapons, items and powerups, per-game renderers (status bars,
  light styles, skies, liquids, Q3 shaders, fog, particles, marks, dynamic
  lights, lightmap-lit models), render interpolation over the 120 Hz
  simulation, the console, cvars and bindings, and saves.

`scripts/campaign_walkthrough.jac` and `scripts/arena_ladder_walkthrough.jac`
exercise every campaign exit and every ladder arena through the real game loop.
They are scripted runs, not human playthroughs; see
[validation-tooling-status.md](validation-tooling-status.md).

## Open issues

- **Jac**: every compiler and runtime fix the pinned compiler carries has
  merged upstream and shipped in jac 0.37.25, among them the two runtime
  fixes (jac #9634, #9639) behind the intermittent native SIGBUS/SIGSEGV in
  Q3 arenas with bots. One known jac defect has no upstream fix yet (an abort
  under the `nogc` memory mode, which QuakePassion does not use). See
  [jac-native-fixes.md](jac-native-fixes.md).

## Remaining fidelity gaps

Each is verified against the code; the linked doc has the detail.

Monsters ([monster-behaviour-status.md](monster-behaviour-status.md), [navigation-status.md](navigation-status.md), [q1-roster-status.md](q1-roster-status.md), [q2-roster-status.md](q2-roster-status.md)):
- Steering is five fixed headings plus bounded ground detours, not
  `SV_StepDirection`/`SV_NewChaseDir`; fliers and swimmers only steer.
- Monsters do not plan through elevators or trains, press switches, or use
  jump/swim links, and are not solid to each other.
- One death sequence per monster; several monsters have one pain sequence; pain
  frames carry no movement.
- Light and shotgun Q2 soldiers never use `attack2`.

Movers, triggers and levels ([doors-status.md](doors-status.md), [map-mechanics-status.md](map-mechanics-status.md), [level-flow-status.md](level-flow-status.md), [traversal-status.md](traversal-status.md)):
- Closed Q2/Q3 area portals do not cull rendering, sounds are not PHS-limited,
  and a relay-toggled portal's state is not saved.
- Q3 RoQ cinematics are not played.

Weapons, items and feedback ([weapons-status.md](weapons-status.md), [combat-feedback-status.md](combat-feedback-status.md), [player-feedback-status.md](player-feedback-status.md)):
- The Q3 railgun draws its core only, not the raildisc rings.
- The player's own body is not thrown as gibs.

Rendering ([rendering-status.md](rendering-status.md), [presentation-status.md](presentation-status.md), [models-status.md](models-status.md)):
- Q3 flares are not drawn; `deformVertexes` applies to world surfaces only, and
  model shaders with unsupported stage features fall back to the plain skin.
- Patches tessellate at a fixed 8 steps; the lightmap atlas is a fixed 2048².
- No player shadows; repeated models are not instanced.

Q3 bots and arenas ([bot-tactics-status.md](bot-tactics-status.md), [arena-match-status.md](arena-match-status.md)):
- Free-for-all only, with no time limit.
- Not modelled: `BotWantsToCamp`, `BotReplyChat`, `BotAddToAvoidReach`,
  `BotAIPredictObstacles`/`BotAIBlocked`.
- Dropped items are not kept in saves.

Passion's own limits are in [passion.md](passion.md).

## Validation limits

- CI builds the viewer and runs the unit suites on Linux; graphical and
  asset-backed checks run by hand on macOS.
- Movement and monster timing follow the original source function by function;
  there is no demo or frame-exact comparison against the original executables.
