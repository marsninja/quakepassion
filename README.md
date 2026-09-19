# QuakePassion

A heartfelt attempt to build a beautiful 3D engine in pure [Jac](https://github.com/jaseci-labs/jaseci) and raylib — one engine that delivers a Quake-like experience capable of loading the assets of all three Quake games (Quake, Quake II, and Quake III Arena) and making them playable.

## The Idea

QuakePassion is not a source port. It is a single, coherent engine with its own architecture, its own physics, and its own internal file formats. Because of that, it will naturally *feel* different from each of the original games — and that's by design. What it promises instead is compatibility where it matters: it will load all the relevant original asset formats (maps, models, textures, sounds) so that everything from Quake 1, 2, and 3 is playable inside one unified world.

Most importantly, this project is a showcase for Jac's **Object-Spatial Programming** paradigm. Everywhere it makes sense — the scene graph, entities, game logic, the structure of the engine itself — computation moves to data through walkers, nodes, and edges rather than the other way around.

## Why

Quake (and games in general) is the thing that got me into programming. This project celebrates that passion, and my admiration for the true GOAT, John Carmack, the man... the coder... the ninja who invented 3D games as we know it.

## Getting Started

The native level viewer renders maps from Quake, Quake II, and Quake III Arena.
It is validated on macOS arm64 using the local Jac 0.37.19 binary with newer
compiler sources staged privately under `.jac/compiler`.

Place your original game archives in these directories (assets are not included):

- `~/quake-assets/id1`: Quake PAK files.
- `~/quake-assets/baseq2`: Quake II PAK files.
- `~/quake-assets/baseq3`: Quake III PK3 files.

The current checkout already has its compiler and raylib staged. Build and run:

```bash
JAC_COMPILER_LIB=off jac build main.jac --native -o qp
./qp                                # Quake: e1m1
QP_GAME=q2 ./qp                     # Quake II: base1
QP_GAME=q3 ./qp                     # Quake III: q3dm1
QP_GAME=q3 QP_MAP=q3dm7 ./qp         # another map, without maps/ or .bsp
QP_GAME=q2 QP_ASSETS=/path/to/baseq2 ./qp
QP_GRAYBOX=1 ./qp                   # original two-room development scene
```

For a fresh checkout, stage the compiler and raylib before building. The tested
compiler source is ZIP-support PR #9322, commit
`fb6940ddd52a76ea75790dda10736ef09926f0fd`, with the two additional upstream fixes:

```bash
# /path/to/jac-checkout must contain the source revision above.
python3 scripts/prepare_compiler.py --source /path/to/jac-checkout \
    --patch patches/jac-native-bytearray-extend.patch \
    --patch patches/jac-native-aggregate-bytes.patch
./scripts/stage_raylib.sh
JAC_COMPILER_LIB=off jac clean --cache --force
JAC_COMPILER_LIB=off jac build main.jac --native -o qp
```

Setup leaves the installed binary and reference submodule unchanged. Move an
existing `.jac/compiler` aside before replacing it. Do not reapply patches to a
source revision that already includes them. `JAC_COMPILER_LIB=off` selects the
source parser compatible with these compiler sources. The legacy no-argument
compiler setup only supplies the earlier Q1 fixes and is insufficient here.
The first build can take a few minutes.

Raylib setup builds pinned 6.0 sources with JPG/TGA support, which its prebuilt
libraries lack. It requires a C compiler and `make`; Linux also needs the desktop
OpenGL/X11 development dependencies. Linux has not been validated. Compiler setup
uses matching bundled typeshed stubs when absent from the source checkout; if
versions differ, fetch that checkout's stubs with `zig build fetch-typeshed`.

Controls: **WASD** moves, **Space/Shift** moves vertically, **Tab** or a click
captures the mouse, and arrow keys also turn. **C** toggles PVS culling, **F3**
toggles the overlay, and **Escape** exits. Movement is free flight through walls.

## Status and validation

All three formats use Jac nodes, edges, and walkers for BSP spatial queries and
visible-face collection. Q1 includes palette textures, baked lighting, fullbright
texels, and static sky. Q2 adds WAL textures, RGB lightmaps, and environment skyboxes.
Q3 includes PK3 archives, indexed meshes, curved patches, baked lighting, and static
shader texture selection with alpha tests, additive blending, and two-sided surfaces.

```bash
JAC_COMPILER_LIB=off jac test -j0
python3 scripts/validate_quake.py --game q1
python3 scripts/validate_quake.py --game q2
python3 scripts/validate_quake.py --game q3
```

All 38 unit tests pass. Graphical validation requires an active desktop and original assets. Twelve maps
passed: six Q1, three Q2, and three Q3. Each check captures two positions and a
camera turn, rejects blank images, and compares culling on/off at both positions.
All 24 pairs matched exactly in the latest run. Captures and logs are ignored
under `.jac/screenshots/<game>/<map>/`. `QP_SMOKE=1` runs one capture sequence.
These checks establish representative rendering and culling consistency, not
pixel parity with the original games.

This is a static level viewer. Collision, gameplay, character/item models, and
moving doors/lifts remain future work. Animated materials and full Q3 multipass
shaders, fog, skyboxes, and vertex deformation are not implemented.

See [Q1 results](docs/quake1-rendering-status.md) and
[Q2/Q3 results, compiler fixes, and limitations](docs/quake2-quake3-rendering-status.md).
