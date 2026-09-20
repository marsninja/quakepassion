# QuakePassion

A heartfelt attempt to build a beautiful 3D engine in pure [Jac](https://github.com/jaseci-labs/jaseci) and raylib — one engine that delivers a Quake-like experience capable of loading the assets of all three Quake games (Quake, Quake II, and Quake III Arena) and making them playable.

## The Idea

QuakePassion is not a source port. It is a single, coherent engine with its own architecture, its own physics, and its own internal file formats. Because of that, it will naturally *feel* different from each of the original games — and that's by design. What it promises instead is compatibility where it matters: it will load all the relevant original asset formats (maps, models, textures, sounds) so that everything from Quake 1, 2, and 3 is playable inside one unified world.

Most importantly, this project is a showcase for Jac's **Object-Spatial Programming** paradigm. Everywhere it makes sense — the scene graph, entities, game logic, the structure of the engine itself — computation moves to data through walkers, nodes, and edges rather than the other way around.

## Why

Quake (and games in general) is the thing that got me into programming. This project celebrates that passion, and my admiration for the true GOAT, John Carmack, the man... the coder... the ninja who invented 3D games as we know it.

## Getting Started

The native level viewer renders maps from Quake, Quake II, and Quake III Arena.
The current gameplay branch uses the local Jac launcher with the compiler source
described in [compiler setup](docs/native-cache-section-merge-blocker.md).

Place your original game archives in these directories (assets are not included):

- `~/quake-assets/id1`: Quake PAK files.
- `~/quake-assets/baseq2`: Quake II PAK files.
- `~/quake-assets/baseq3`: Quake III PK3 files.

After installing Jac and staging raylib (see below), build and run:

```bash
jac build main.jac --native -o qp
./qp                                # Quake: e1m1
QP_GAME=q2 ./qp                     # Quake II: base1
QP_GAME=q3 ./qp                     # Quake III: q3dm1
QP_GAME=q3 QP_MAP=q3dm7 ./qp         # another map, without maps/ or .bsp
QP_GAME=q2 QP_ASSETS=/path/to/baseq2 ./qp
QP_GRAYBOX=1 ./qp                   # original two-room development scene
```

For a fresh checkout, install [Jac 0.37.21](https://github.com/jaseci-labs/jac/releases/tag/v0.37.21)
for your platform, then stage raylib and build:

```bash
jac --version
./scripts/stage_raylib.sh
jac build main.jac --native -o qp
```

The current source needs the compiler fixes from Jac #9344; follow the
[patched compiler setup](docs/player-movement-status.md#compiler-requirement)
before rebuilding with the released 0.37.21 launcher.

Raylib setup builds pinned 6.0 sources with JPG/TGA support, which its prebuilt
libraries lack. It requires a C compiler and `make`; Linux also needs the desktop
OpenGL/X11 development dependencies. Graphical validation is performed on macOS.
The old `.jac/compiler` directory is no longer selected by this project and can
be removed. Compiler patches and the Python staging helper have been retired.

Controls: **WASD** moves, **Space/Shift** moves vertically, **Tab** or a click
captures the mouse, and arrow keys also turn. **C** toggles PVS culling, **F3**
toggles the overlay, and **Escape** opens/closes the level menu. Walking is the default
in all three games. **F4** toggles free flight through walls and **Space** jumps
while walking; `QP_WALK=0 ./qp` starts in fly mode. Ordinary proximity doors and supported touch-triggered doors open (including linked pairs); supported buttons and translating lifts now move, and lifts carry the player. Switching
levels returns to walking. See [movement status](docs/player-movement-status.md).

In the menu, choose **Quake**, **Quake II**, or **Quake III**, scroll or use
**Up/Down** to select a map, then click **Render selected level** or press
**Enter**. **Quit** closes the viewer; Escape resumes the current level. Movement
pauses while the menu is open, and mouse capture is restored when it closes.

The **Settings** button switches to movement mode, vertical field of view, mouse
sensitivity, inverted mouse Y, fly speed, frame limit, visibility culling, and
the diagnostic overlay. Click the arrows or use **Up/Down** and **Left/Right**.
Changes apply immediately and stay active across level switches for this session;
movement mode resets to walking on level load. **Reset defaults** restores
the original controls and uncapped rendering. Settings are not saved to disk.
Maps are discovered from your installed archives; Q1 brush-model BSPs are excluded.
`QP_ASSETS` applies to the game selected by `QP_GAME`; the other games use their
normal directories under `~/quake-assets`.

## Status and validation

All three formats use Jac nodes, edges, and walkers for BSP spatial queries and
visible-face collection. Q1 includes palette textures, baked lighting, fullbright
texels, and static sky. Q2 adds WAL textures, RGB lightmaps, and environment skyboxes.
Q3 includes PK3 archives, indexed meshes, curved patches, baked lighting, and static
shader texture selection with alpha tests, additive blending, and two-sided surfaces.

```bash
jac test -j0
jac run scripts/validate_quake.jac --game q1
jac run scripts/validate_quake.jac --game q2
jac run scripts/validate_quake.jac --game q3
jac run scripts/validate_menu.jac       # exercises real menu input and game switching
```

The validation runners are Jac scripts. `scripts/menu_smoke.jac` is the native
input-event harness built by the menu runner; `scripts/png_checks.jac` decodes
screenshots and counts changed pixels. Unit fixtures cover RGB/RGBA PNG filters,
blank-image rejection, and pixel comparison.

The expanded test suite is validated with the local compiler containing
[Jac #9347](https://github.com/jaseci-labs/jac/pull/9347) and the additional
[cache-section fix and build instructions](docs/native-cache-section-merge-blocker.md).
Graphical validation requires an active desktop and original assets. Twelve maps
passed: six Q1, three Q2, and three Q3. Each check captures two positions and a
camera turn, rejects blank images, and compares culling on/off at both positions.
All 24 pairs matched exactly in the latest run. Captures and logs are ignored
under `.jac/screenshots/<game>/<map>/`. `QP_SMOKE=1` runs one capture sequence.
These checks establish representative rendering and culling consistency, not
pixel parity with the original games.

This is a level viewer with shared walking and brush collision across Q1/Q2/Q3.
Q3 curved patches now collide using the rendered tessellation and the shared
standing-box hull queries. Initial campaign exits, health/armor, liquid damage and
health/armor/shell pickups work through shared gameplay systems. Combat, character
binding, trains and rotating/crushing movers remain future work. Animated materials and full Q3 multipass
shaders, fog, skyboxes, and vertex deformation are not implemented.

See [Q1 results](docs/quake1-rendering-status.md) and
[Q2/Q3 results, compiler fixes, and limitations](docs/quake2-quake3-rendering-status.md).

Shared moving doors: [behavior, limits and validation](docs/doors-status.md).

Shared touch triggers: [behavior, limits and validation](docs/triggers-status.md).

Buttons and activation relays: [current validation and limits](docs/buttons-status.md).

Platforms and carrying: [validation and limits](docs/platforms-status.md).

Teleporters and jump pads: [validation and limits](docs/traversal-status.md).

Swimming: Space ascends and Left Shift descends when submerged; forward follows
the view direction. See [liquid detection and swimming limits](docs/swimming-status.md).

Hold **Left Control** to crouch in Q2/Q3. Health, armor and shells are shown at the bottom
of the screen; liquid hazards and drowning can kill the player. **Enter** restarts
the level after death. Supported Q1/Q2 exits change maps and preserve player state.
See [campaign/gameplay progress and remaining scope](docs/campaign-gameplay-status.md)
and [animated model validation](docs/models-status.md).
