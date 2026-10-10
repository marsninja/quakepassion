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
- **Monster movement** (Quake and Quake II): each 0.1 s frame a monster takes
  one `SV_movestep` of that frame's distance or none, chasing by
  `SV_StepDirection` and `SV_NewChaseDir`, solid to other monsters and the
  player; fliers and swimmers move by the `FL_FLY` / `FL_SWIM` rules. The
  originals' monsters plan no routes: they do not take lifts or trains on
  purpose, press switches or use jump links, and neither do these.
  See [navigation-status.md](navigation-status.md).
- **Quake III Arena**: the `arenas.txt` ladder as free-for-all matches against
  botlib bots (AAS routing, travel types, fuzzy weights, the ai_dmnet.c nodes,
  chat), with scoring, awards, the podium, ladder progress and the RoQ films.
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
- Fliers and swimmers take no steps from their attack frames, and bodies
  that already overlap do not block each other.
- Q2 monsters collide with player clip brushes, not monster clip brushes.

Weapons, items and feedback ([weapons-status.md](weapons-status.md), [combat-feedback-status.md](combat-feedback-status.md), [player-feedback-status.md](player-feedback-status.md)):
- A Q3 player killed in a `CONTENTS_NODROP` void still gibs; Q2 `AI_BRUTAL`
  and lava burning a Q2 body are not modelled.

Rendering ([rendering-status.md](rendering-status.md), [presentation-status.md](presentation-status.md), [models-status.md](models-status.md)):
- Q3 patches are not thinned with distance (`r_lodCurveError`).
- Repeated models are not instanced.

Q3 bots and arenas ([bot-tactics-status.md](bot-tactics-status.md), [arena-match-status.md](arena-match-status.md)):
- The single-player ladder's game type only (no tournament queue, team modes
  or CTF).

Passion's own limits are in [passion.md](passion.md).

## Validation limits

- CI builds the viewer and runs the unit suites on Linux; graphical and
  asset-backed checks run by hand on macOS.
- Movement and monster timing follow the original source function by function;
  there is no demo or frame-exact comparison against the original executables.
