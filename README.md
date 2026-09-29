# QuakePassion

A heartfelt attempt to build a beautiful 3D engine in pure [Jac](https://github.com/jaseci-labs/jaseci) and raylib — one engine that loads the original assets of all three Quake games (Quake, Quake II, and Quake III Arena) and plays them.

## The Idea

QuakePassion is not a source port. It is a single, coherent engine with its own architecture and its own internal data model. Each game's assets load into one shared world graph, and each game's rules — movement, weapons, monsters, bots, triggers — are reproduced from the originals' behaviour, citing the original functions they follow (`PM_Friction`, `SV_Physics_Pusher`, `ai_run`, `BotAI`, ...), so each game plays like itself inside one engine.

Most importantly, this project is a showcase for Jac's **Object-Spatial Programming** paradigm. Everywhere it makes sense — the scene graph, entities, game logic, the structure of the engine itself — computation moves to data through walkers, nodes, and edges rather than the other way around.

## Why

Quake (and games in general) is the thing that got me into programming. This project celebrates that passion, and my admiration for the true GOAT, John Carmack, the man... the coder... the ninja who invented 3D games as we know it.

## What plays

- **Quake**: the full campaign, 32 maps (start, four episodes, end), with its monsters and bosses (Chthon, Shub-Niggurath), runes, secrets, intermissions and episode text.
- **Quake II**: the full campaign, 39 maps across its units, with hub returns, the help computer, cinematics, the monster roster and the final bosses.
- **Quake III Arena**: the single-player ladder from `arenas.txt`: free-for-all matches against botlib-driven bots (AAS routing, fuzzy item and weapon weights, chat), scoring, awards and the podium.
- **Passion**: a fourth mode that generates seeded expeditions from all three games' assets. See [docs/passion.md](docs/passion.md).

Save/load, per-game key bindings, the console and settings work in all modes. Network multiplayer, mods and an editor are out of scope. Known gaps are tracked per area in [docs/](docs/README.md).

## Setup

Assets are not included. Put your own archives here:

| Directory | Contents |
| --- | --- |
| `~/quake-assets/id1` | Quake `pak0.pak`, `pak1.pak` |
| `~/quake-assets/baseq2` | Quake II `pak*.pak` (plus loose `video/`, `music/` if you have them) |
| `~/quake-assets/baseq3` | Quake III `pak*.pk3` |

### Compiler

QuakePassion builds with the released [Jac 0.37.23](https://github.com/jaseci-labs/jac/releases/tag/v0.37.23)
binary, compiling with newer compiler source pinned in the `jaseci` submodule.
The pin carries upstream fixes no release has yet (see
[docs/jac-native-fixes.md](docs/jac-native-fixes.md)).

```bash
jac --version                                  # 0.37.23
export $(./scripts/stage_compiler.sh)          # inits the submodule, prints JAC_DEV_SOURCE
```

`stage_compiler.sh` initialises the submodule, fetches the typeshed stubs the
compiler needs (without them the launcher silently falls back to its bundled
compiler) and prints `JAC_DEV_SOURCE=<repo>/jaseci/jac`. The first compile
builds a native compiler kernel from that source: it is slow and memory-hungry
(about 45 minutes and 13 GB on CI) and is cached per pin afterwards. Setting
`JAC_COMPILER_LIB=off` runs the compiler interpreted instead. CI
(`.github/workflows/jac-test.yml`) follows the same steps.

### raylib and the build

```bash
./scripts/stage_raylib.sh                      # builds raylib 6.0 with JPG/TGA into vendor/
jac build main.jac --native -o qp
./qp
```

raylib's prebuilt libraries lack the JPG and TGA decoders the Q2/Q3 assets need,
so the script builds pinned sources; it needs a C compiler and `make` (Linux
also needs the X11/OpenGL development packages). If the loader cannot find
raylib, run with `DYLD_LIBRARY_PATH=vendor ./qp` (Linux: `LD_LIBRARY_PATH`).
Development and graphical validation happen on macOS; CI builds and tests on Linux.

## Running

```bash
./qp                                # Quake: e1m1
QP_GAME=q2 ./qp                     # Quake II: the intro cinematic, then base1
QP_GAME=q3 QP_MAP=q3dm7 ./qp        # a Quake III arena
QP_GAME=passion QP_SEED=42 ./qp     # a seeded Passion expedition
./qp +map e1m3 +god                 # console commands after the configuration
```

| Variable | Effect |
| --- | --- |
| `QP_GAME` | `q1` (default), `q2`, `q3` or `passion` |
| `QP_MAP` | Starting map basename (default `e1m1`, `base1`, `q3dm1`) |
| `QP_ASSETS` | Asset directory for the selected game (for Passion, the parent of all three) |
| `QP_SEED` | Passion expedition seed |
| `QP_WALK=0` | Start in free flight instead of walking |
| `QP_CONFIG_DIR` | Where settings and bindings live (default `$HOME`) |
| `QP_CAPTURE=<frame>:<file.png>` | Play normally, save one full screenshot at that frame, exit |
| `QP_SMOKE=1` | Capture a fixed set of views and exit (validation) |
| `QP_GRAYBOX=1` | The two-room development arena instead of a level |
| `QP_RENDER_LEGACY=1` | Draw models and effect cubes through the old CPU/immediate-mode path, for comparison |
| `QP_LIGHT_CACHE` | Passion's baked-lighting cache (default `~/.cache/quakepassion/lighting`) |

Validation scripts read further `QP_*` variables of their own; each documents
them in its header.

## Controls, console and settings

Each game binds keys from its own `default.cfg`. QuakePassion adds a layer on
top (`games/controls.jac`): **WASD** and the mouse wheel for weapons in Q1/Q2,
**F3** for the diagnostic overlay (`qp_overlay`), **F4** for free flight
(`noclip`), and quick save/load on **F6**/**F9** in Q3 (Q1 and Q2 bind their own).
A click captures the mouse.

- **Console**: **`** (or **Shift+Escape**). It is the originals' command
  shell (`engine/console/`): cvars, commands and aliases are nodes in a graph
  the shell searches. `bind`, `unbind`, `bindlist`, `set`, `seta`, `toggle`,
  `reset`, `cvarlist`, `cmdlist`, `alias`, `exec`, `vstr`, `map`, `god`,
  `noclip`, `give`, `impulse`, `save`, `load`, `screenshot`, `vid_restart` and
  `quit` work as in the originals; **Tab** completes names.
- **Menu**: **Escape** opens the level menu: pick a game tab and a map, or open
  **Settings** (field of view, sensitivity, volume, skill, God mode and more,
  each a cvar) or **Controls** (the game's Customize Controls: Enter then a key
  binds, Backspace clears).
- **Window**: **Alt+Enter** toggles fullscreen; the window can be resized.
- **Files**: settings (archived cvars) are written as a console script to
  `~/.quakepassion-settings.txt`, and each game's bindings to
  `~/.quakepassion-<game>-bindings.cfg`; `QP_CONFIG_DIR` moves both. Saves
  (`~/.quakepassion-save*.txt`) and Q3 ladder progress and awards stay in `$HOME`.

More detail: [menu, console and bindings](docs/menu-console-status.md).

## Architecture

```
main.jac        entry: reads QP_*, runs the settings through the shell, opens the level, runs App
engine/         the game-agnostic engine
  core/         App loop, fixed-step clocks, menu, campaign state, saves, preferences, cinematics
  console/      console, cvars and command shell
  input/        keys, bindings, move commands
  assets/       PAK/PK3 archives, asset catalog, materials
  formats/      BSP29/38/46, MDL/MD2/MD3, sprites, WAL/WAD, CIN, WAV, AAS and bot files
  physics/      hull and patch collision, per-game movement (pmove)
  world/        the world graph: areas, entities, movers, triggers, combat, monsters, bots
  render/       GPU world meshes, models, particles, HUDs, view weapons, effects
  audio/        positional sounds and music streams
games/          per-game data and rules: weapons, items, enemies, arenas, bot files, controls
  passion/      the Passion generator
scripts/        native validation harnesses and audits (validate_*, *_smoke, walkthroughs)
tests/          jac test suites (one file per area)
repros/         minimal programs for jac compiler defects
```

The world is a Jac graph (`engine/world/world.jac`). A level's BSP tree becomes
`Split` and `BspArea` (leaf) nodes joined by `Front`/`Back` edges, and walkers
query it: `Locate` finds the camera's leaf, `CollectFaces` gathers the faces of
the visible leaves, `TraceLightPoint` samples the lightmap under a model
(`engine/world/level.jac`). Entities, movers, triggers, monsters, items and
lights are nodes linked into the world, and their relationships are typed
edges: a signal's `Targets` and `Kills`, a monster's `Patrols` to its path
corners, a train's `TrackNext` route, the bots' AAS areas joined through
`Exits`/`Enters` passages, the console's `Declares` to its names. Engine systems are walkers: each 120 Hz physics tick spawns
passes such as `SignalTick`, `TrainTick` and `CombatTick` over the graph, and
frames draw bodies interpolated between their last two ticks. `engine/` holds mechanisms
shared by all three games; where the games differ, a per-game profile or table
(`MovementProfile`, `games/weapons.jac`, `games/enemies.jac`) selects the
original rule.

## Testing and validation

```bash
ls tests/*_tests.jac | xargs -P 4 -n 1 jac test          # the unit suites, one process per file
jac build scripts/campaign_walkthrough.jac --native -o .jac/walkthrough && DYLD_LIBRARY_PATH=vendor .jac/walkthrough
jac build scripts/arena_ladder_walkthrough.jac --native -o .jac/ladder && DYLD_LIBRARY_PATH=vendor .jac/ladder
jac run scripts/validate_quake.jac --game q1              # graphical checks (needs a desktop and assets)
```

One `jac test` process over the whole suite needs far more memory than one per
file, which is why CI and the command above split it. The walkthroughs play
every Q1/Q2 campaign exit and every Q3 ladder arena through the real game loop.
See [validation tooling](docs/validation-tooling-status.md) for the full set.

## Documentation

[docs/README.md](docs/README.md) indexes the status docs: what each area does,
how it is validated, and what remains.
