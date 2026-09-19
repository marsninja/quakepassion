# QuakePassion

A heartfelt attempt to build a beautiful 3D engine in pure [Jac](https://github.com/jaseci-labs/jaseci) and raylib — one engine that delivers a Quake-like experience capable of loading the assets of all three Quake games (Quake, Quake II, and Quake III Arena) and making them playable.

## The Idea

QuakePassion is not a source port. It is a single, coherent engine with its own architecture, its own physics, and its own internal file formats. Because of that, it will naturally *feel* different from each of the original games — and that's by design. What it promises instead is compatibility where it matters: it will load all the relevant original asset formats (maps, models, textures, sounds) so that everything from Quake 1, 2, and 3 is playable inside one unified world.

Most importantly, this project is a showcase for Jac's **Object-Spatial Programming** paradigm. Everywhere it makes sense — the scene graph, entities, game logic, the structure of the engine itself — computation moves to data through walkers, nodes, and edges rather than the other way around.

## Why

Quake (and games in general) is the thing that got me into programming. This project celebrates that passion, and my admiration for the true GOAT, John Carmack, the man... the coder... the ninja who invented 3D games as we know it.

## Getting Started

The Quake 1 viewer runs with the local `jac` binary (validated with 0.37.19 on
macOS arm64). That release needs the checked-in compiler fixes; both fixes have
been merged upstream. Setup copies the installed compiler into `.jac/compiler`
and patches the private copy selected by `jac.toml`.

Put your original Quake PAK files in `~/quake-assets/id1` (`PAK0.PAK` and
`PAK1.PAK`, or lowercase names), then run:

```bash
python3 scripts/prepare_compiler.py
./scripts/stage_raylib.sh            # only if vendor/ has no raylib library
jac build main.jac --native -o qp
./qp                                # e1m1, at the player start
```

The first compiler setup/build can take a few minutes. The global Jac binary
and the reference submodule are not modified by setup. If upgrading an older private compiler, move `.jac/compiler`
aside before rerunning setup; the script deliberately refuses to overwrite it.

```bash
QP_MAP=start ./qp                    # another map, without maps/ or .bsp
QP_ASSETS=/path/to/id1 ./qp           # another directory of Quake 1 PAKs
QP_GRAYBOX=1 ./qp                    # original two-room development scene
```

Controls: **WASD** moves, **Space/Shift** moves vertically, **Tab** or a click
captures the mouse, and arrow keys also turn. **C** toggles PVS culling, **F3**
toggles the overlay, and **Escape** exits. Movement is free flight through walls.

## Status and validation

The first Quake 1 BSP29 viewer renders original geometry, palette textures,
baked lightmaps, fullbright texels, static brush entities, and a static sky
composite. BSP splits/leaves form a Jac graph; walkers locate the camera and
collect visible faces from the map's PVS. Invisible trigger volumes are excluded.

```bash
jac test -j 0
python3 scripts/validate_quake.py     # requires a graphical display and assets
```

The graphical check visits two positions and turns the camera in six maps. It
checks nonblank images and compares PVS-on/off pixels, allowing at most 16 edge
pixels out of 921,600. Screenshots and logs are saved under `.jac/screenshots`.
`QP_SMOKE=1 ./qp` runs one map's deterministic screenshot sequence and exits.

This is a level viewer: collision, monsters/items/weapons, moving doors/lifts,
animated textures/lightstyles/water/sky, and Quake II/III rendering remain later
work. The original assets stay outside the repository.

See [rendering results and limitations](docs/quake1-rendering-status.md) and the
[original OSP compiler fix](docs/jac-native-visit-blocker.md).
