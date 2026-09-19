# QuakePassion

A heartfelt attempt to build a beautiful 3D engine in pure [Jac](https://github.com/jaseci-labs/jaseci) and raylib — one engine that delivers a Quake-like experience capable of loading the assets of all three Quake games (Quake, Quake II, and Quake III Arena) and making them playable.

## The Idea

QuakePassion is not a source port. It is a single, coherent engine with its own architecture, its own physics, and its own internal file formats. Because of that, it will naturally *feel* different from each of the original games — and that's by design. What it promises instead is compatibility where it matters: it will load all the relevant original asset formats (maps, models, textures, sounds) so that everything from Quake 1, 2, and 3 is playable inside one unified world.

Most importantly, this project is a showcase for Jac's **Object-Spatial Programming** paradigm. Everywhere it makes sense — the scene graph, entities, game logic, the structure of the engine itself — computation moves to data through walkers, nodes, and edges rather than the other way around.

## Why

Quake (and games in general) is the thing that got me into programming. This project celebrates that passion, and my admiration for the true GOAT, John Carmack, the man... the coder... the ninja who invented 3D games as we know it.

## Getting Started

The engine runs with the installed `jac` binary (tested with Jac 0.37.19 on macOS arm64). This release needs a small native OSP compiler fix: the setup below copies the binary's compiler sources into `.jac/compiler` and applies the checked-in patch. `jac.toml` selects that private copy; the installed binary and other projects are unchanged. The `jaseci` submodule remains a source reference.

```bash
jac --version
python3 scripts/prepare_compiler.py  # one-time compiler fix for Jac 0.37.19
jac test                         # math, world graph, and PAK reader tests
./scripts/stage_raylib.sh         # only if vendor/ has no raylib shared library
jac run main.jac                 # fly the graybox arena
```

The first run after compiler setup can take a few minutes while Jac compiles and caches its patched sources. Later runs use the cache.

Controls: WASD + mouse to fly, Space/Shift for up/down, Tab to capture/release the mouse, C to toggle portal culling, and F3 for the debug overlay. `QP_SMOKE=1 jac run main.jac` runs the short screenshot sequence and exits; it still requires a graphical display.

`./scripts/refresh.sh` updates the reference submodule to upstream main. It does not update the installed `jac` binary.

## Status

Phase 1 implements a two-room graybox fly-through. Phase 2 has a PAK archive reader; original Quake BSP maps are not loaded yet.

The graybox arena builds and runs with the local compiler patch. Its automated smoke run captures both rooms, facing-away culling, and culling disabled. All 19 tests pass. See [the compiler fix and minimal repro](docs/jac-native-visit-blocker.md); the engine's OSP traversal is unchanged.
