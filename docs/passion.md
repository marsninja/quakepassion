# Passion expeditions

Passion is the fourth game mode of the shared engine (`games/passion/`). It
generates seeded expeditions, real levels of brushes in three dimensions,
from the original Quake, Quake II and Quake III assets, and measures them
against the original games' own levels. The generator version is `v3`
(`generate.jac` `VERSION`).

## Run

With the build in the README and all three games under one asset directory
(`~/quake-assets` by default; `QP_ASSETS` names another parent):

```sh
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH=vendor ./qp
```

- `QP_SEED` picks the seed (default 1); `QP_MAP=v3-42` is the equivalent
  level name. Seeds run from 1 to 2147483646, and names with another version
  prefix are rejected (`seed_from`), so saves from an older generator do not
  load.
- `QP_LIGHT_CACHE` sets the baked-lighting cache directory (default
  `~/.cache/quakepassion/lighting`); an empty value bakes every time. A file
  is named by the hash of the expedition's map and the bake's settings.
- The Escape menu lists twelve fresh seeds when Passion is selected. The HUD
  briefing names the districts the route crosses and the objectives (for
  example "Gothic Ruin > Strogg Works | Recover 1 key, reach extraction").
- A seed takes 2-7 s to generate (a few candidates are built and the best
  kept), and its light 6-12 s to bake the first time it is played.

## The yardstick and the corpus

`yardstick.jac` measures any level, an original or a generated one, the same
way. Places a player can stand are sampled on a 32-unit grid over the
world's walkable faces (nudged round crowded cells, lifted onto slopes) and
joined by the moves the engine allows between neighbours: walking (the
engine's own stepping slide), jumping up a ledge, dropping off one, and
teleporters. Places gather into areas (the places of a 128-unit bin that walk
to each other), nodes of a graph whose edges are the moves between areas;
walkers flood it. Doors are measured open; platforms stay where they rest.

Beside the traversal it measures the level's shape (extent, floor levels,
floor over floor, height range, headroom, sightlines, distance to the
nearest wall), detail (faces for the floor they serve, trim, textures),
light (lamps for the floor, their spacing, the lightmaps' levels) and
population (monsters and items for the floor), and how much of the level the
start reaches and by what route to the exit.

`scripts/passion_corpus.jac` measured 115 original levels (38 Quake, 47 Quake
II, 30 Quake III) and how each uses its textures. `corpus.jac` keeps only the
measures' quartiles: over Quake and Quake II's single-player levels
(`CORPUS_SP`) and per game. For example, id's single-player levels have a
median of six floor levels, 40% of their floor over other floor, 240 units
of headroom, 176-unit sightlines, a lamp per 110 units, and lightmaps whose
quartiles are 1, 35 and 109.

## Pipeline (`generate.jac`)

A seed picks a niche (how much the expedition loops, how vertical it is, how
densely it is fought over, how big it is) and an objective archetype (keys,
relays, guardians or a mix). Up to four candidates are built in full; each is
turned down if it cannot be laid out, needs too many teleporters, or if a
room's stage cannot be walked to; the critic scores the rest and the best is
kept.

1. **Mission** (`mission.jac`, unchanged from v2): beats and links, a cyclic
   grammar after Dormans whose links carry tokens; an exhaustive search over
   (beat, tokens) proves the goal reachable and no state a softlock.
2. **Spaces** (`spaces.jac`): each beat becomes a box in a voxel massing
   (`massing.jac`, cells 32 units across and 16 up) and takes an archetype by
   its role: a hall (dais, pillar rows), an atrium (a balcony round its walls
   and stairs up to it), a shaft (stairs winding up its walls, open in the
   middle), a chasm (a pit crossed by a bridge, stairs from the pit up to a
   ledge), an open court (an arcade round it, sky over it), terraces, a stair
   hall, a vault (a dais for its prize), an arena (a sunken pit and steps
   down) or a crypt (a grid of squat pillars). Doorways (`Doorway`) are found
   from the carved cells: two cells of floor deep, headroom for a doorway, at
   each floor level the stage can be walked to; ledges high in the walls for
   one-way drops.
3. **Arrangement** (`arrange.jac`): spaces are placed in progression order
   beside one they link to, higher or lower (the expedition drifts deeper or
   higher as it goes), a corridor's width apart, or wall to wall with a
   doorway straight through (steps in its thickness for up to two lifts).
   Links are routed as corridors by A* over blocks two cells square and six
   lifts high: they climb by stairs, turn on the flat, keep a wall's thickness
   from everything else (free runs per column make each test four reads), and
   pass over and under other spaces. Half are widened to three cells where
   the rock allows. A one-way link ends at a ledge when one can be had. A link
   no corridor can carry becomes a pair of teleporters (a candidate needing
   more than two, or than a quarter of its links where that is more, is
   turned down).
   Rooms facing each other across a short gap get barred windows, the
   mission's own window links first.
4. **Pits**: a chasm's pit floods, deep with its district's lava or slime
   where nothing needs the floor (no doorway opens there and the objective is
   on the bridge), else a lift of water.
5. **Dressing** (`dress.jac`): a lower band of the wall in the kit's second
   material, baseboards on walls six lifts high or more, cornices in tall
   rooms, pilasters on plinths every three cells where the wall stands whole,
   railings on edges over a drop (never on or beside stairs, never where they
   leave a walk under two cells), frames round doorways, bars across windows.
   Lamps: on every other pilaster, under ceilings where no wall lamp went,
   along corridors every third block, hung over big rooms' floors, over the
   middle of courts (whose sky glows), over lava and slime, and over any room
   still unlit.
6. **Cast** (`cast.jac`): the start; each objective on its room's stage (a
   key; a plate set in the floor with a trigger over it for a switch; a
   guardian whose death fires its gate); doors for what each link needs (one
   for all its keys, one per token something else opens, a shootable wall for
   a secret, a trigger beyond a shortcut); teleporters; foes from a roster of
   all three games weighted toward each district's game, by a threat budget
   from tension, size and density; health, shells and armour by what the
   fights cost.
7. **Critic** (`critic.jac`): the yardstick's measures taken quickly from the
   massing, lamps and cast, each scored by how many corpus spreads it lies
   from the corpus median.
8. **Brushwork** (`brushwork.jac`): the massing's shell (the solid touching
   air, diagonals included, so the world is sealed) merged into boxes that
   hold only cells of one space exposed alike on every side, so a side faces
   air all over or is caulked; each dressed by the kit of the space it faces.
   Dressing boxes, liquids (their contents said on every side), lamps and the
   cast join them as map items.
9. **Build**: the map items become a studio scene, compiled by
   `editor/compile/live.jac` with buried faces cut away
   (`editor/compile/cull.jac`) and lit by the studio's light bake at 32-unit
   luxels (bounce, a light grid for models), kept on disk once baked.

## Districts (`kits.jac`)

Each district is one original level's palette, read off how that level uses
its textures (the corpus lists, for every texture of every level, the area it
covers on floors, walls and ceilings and on narrow trim): its floor, wall,
ceiling, trim, supports, lower band, panels, light, door, step, sky and
liquid, and other walls, floors and ceilings rooms may take for a variant.

| District | Read from |
| --- | --- |
| Slipgate Base | Quake e1m1 |
| Stone Keep | Quake e1m2 |
| Runic Halls | Quake e3m2 |
| Tech Complex | Quake e4m1 |
| Strogg Outpost | Quake II base1 |
| Deep Mines | Quake II mine1 |
| Strogg Works | Quake II fact1 |
| Gothic Ruin | Quake III q3dm1 |
| Arena Works | Quake III q3dm17 |

Materials are named as the studio names them (`q1:e1m1/tech08_1`,
`q2:e1u1/metal2_1`, `q3:textures/...`) and load from the player's own game
files; nothing of the games is copied into the repository.

## In the studio

`ed_exp open <seed>` generates an expedition and opens it as a document of
brushes, a group a room and a group a corridor, with the way out as a
trigger; `ed_exp mission`, `rooms`, `ways` and `measures` say its beats and
links, spaces, corridors and how it measures against the corpus, and
`ed_exp show` draws the ways over the level.

## Validation

```sh
jac test tests/passion_tests.jac
jac build scripts/passion_map.jac --native -o .jac/qp-passion-map
QP_SEEDS="1 2 3 4 5 6 7 8 9 10 11 12" .jac/qp-passion-map
jac build scripts/passion_play.jac --native -o .jac/qp-play
QP_GAME=passion QP_SEEDS="1 2 3" DYLD_LIBRARY_PATH=vendor .jac/qp-play
jac build scripts/passion_look.jac --native -o .jac/qp-look
QP_GAME=passion QP_LOOK_GAME=passion QP_LOOK_MAP=v3-5 QP_LOOK_ROUTE=1 DYLD_LIBRARY_PATH=vendor .jac/qp-look
jac build scripts/passion_corpus.jac --native -o .jac/qp-corpus
QP_CORPUS_GAMES=passion .jac/qp-corpus
```

- `tests/passion_tests.jac`: the massing's shell seals all air; every
  archetype gives a stage and doorways and every floor level can be walked
  to; arrangements are deterministic and corridors join their doorways;
  names parse strictly; a survey keeps its promises (start, exit, a door for
  each lock, a fair score); the light cache round-trips; a compiled
  expedition is walked from its start to its exit by the yardstick over its
  real collision.
- `scripts/passion_map.jac`: how each seed's survey went, why candidates
  were turned down, teleporters and windows (seeds 1-12: 0-2 teleporters,
  2-7 s).
- `scripts/passion_play.jac`: each seed's logic played in the game (keys,
  switches, guardians, locked doors, the way out). Seeds 1-30 pass.
- `scripts/passion_look.jac`: photographs from the widest views a player can
  reach, along the route from start to exit, or from given places; the same
  for the original levels, to compare by eye.
- `scripts/passion_corpus.jac` with `QP_CORPUS_GAMES=passion`: generated
  expeditions measured like the originals.

Jac compiler defects found while building Passion are recorded in
[jac native fixes](jac-native-fixes.md).

## Limitations

- Rooms are boxes and their structure axis-aligned: no slopes, arches or
  round rooms yet, and walls are a cell thick.
- The yardstick does not swim or ride lifts, so a level's reach and routes
  are measured as far as walking, jumping, dropping and teleporters go.
- Generated levels are still more detailed in small faces and trim than the
  originals (cut faces round pilasters, plinths and stair risers), and use
  fewer textures.
- Passion has no weapon table of its own (`weapon_rules("passion")` is
  empty): the player has the engine's two basic weapon slots, and the supply
  of health and shells balances against them.
- The director's damage model is a heuristic, not a combat simulation.
- The level is one cluster (no visibility culling); generated expeditions
  draw well within the frame budget, but a bake by planes could cut them.
