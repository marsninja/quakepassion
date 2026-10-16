# Passion runs

Passion is the fourth game mode of the shared engine (`games/passion/`). A
run is a seed: its levels, real levels of brushes in three dimensions, are
generated one after another from the original Quake, Quake II and Quake III
assets and measured against the original games' own levels. Each level's
way out leads on to the next, made while the last is played; nothing is
saved. Every level takes one of thirty themes (below). The generator version
is `v4` (`generate.jac` `VERSION`).

## Run

With the build in the README and all three games under one asset directory
(`~/quake-assets` by default; `QP_ASSETS` names another parent):

```sh
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH=vendor ./qp
```

- `QP_SEED` is the run's seed (default 1), from 1 to 2147483646. The run's
  first level is `v4-42`, its levels after that `v4-42-2`, `v4-42-3` and on
  (`QP_MAP` names any of them). Each level is made from the run's seed and
  its depth, so a seed always plays the same run, and a deeper level is
  fought over more densely and has a room or two more. Names with another
  version prefix are refused (`run_of`).
- The Escape menu's Passion page takes a seed typed in, or rolls one, and
  starts its run.
- Reaching a level's way out shows its tally (kills, time) and Enter goes on
  to the next level. That level has been made a few milliseconds a frame
  while the last was played (`Forge`, `run.jac`), so it usually opens at
  once; if it is not ready yet the tally shows how far it has got, and it
  opens when it is.
- Health, armour, weapons and ammunition carry on from level to level;
  keys do not. A death begins the level again with what the player came in
  with, from the level kept in memory.
- The first level of a run is made when the run starts (2-7 s to lay out,
  about a second to compile, 5-8 s to light), with its progress on the
  loading screen.

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

## Themes (`themes.jac`)

Each level is made in a theme, drawn from its own seed (so a run's levels
differ, and a seed always gives the same). A theme is data, not code: a
recipe the rest of the generator reads.

- **Archetype weights**: which kinds of room it leans to (multiplying each
  beat kind's own), and its **centrepiece**: the hub, arena or goal takes
  the theme's great room, grown.
- **Connectors**: how rooms set one over another are joined, and how often
  a room is so set (below).
- **Leanings** added to the seed's niche: verticality, loopiness, density,
  rooms; the way the level **drifts** (up a spire, down a mine); the
  **mission** archetypes it sets (keys, relays, guardians).
- **Dressing**: its districts (first choice first), the foes that hold it
  (soldier, beast, undead, arcane, Strogg, Quake III, weighted three to one),
  the liquid in its pits (lava, slime, water), its light (brighter or darker
  than the district's, and its colour), how often a tall room opens to the
  sky, how often corridors are widened, and (the Slipgate Complex) how
  often a link is a teleporter on purpose.

| Theme | Centrepiece | Leans on | Joined by |
| --- | --- | --- | --- |
| Keep | court | courts, tower hubs, cross halls | stairs, lifts, drops |
| Cathedral | cross hall | overlooks, crypts, octagons | stairs, drops |
| Spire | tower hub | shafts, atriums (rises) | lifts, stairs, jump pads |
| Dungeon | crypt | mazes, cell blocks (sinks) | drops, stairs, lifts |
| Cloister | court | courts, terraces (loops) | stairs |
| Ruins | chasm | bridge spans, caves (lava, sky) | drops, stairs, jump pads, lifts |
| Necropolis | ziggurat | crypts, vaults | stairs, drops |
| Ziggurat | ziggurat | terraces, stair halls (rises) | stairs, lifts |
| Factory | catwalk | crate halls, overlooks (lava) | lifts, stairs, drops |
| Refinery | cistern | catwalks, bridge spans (slime) | lifts, stairs, water |
| Power Plant | tower hub | shafts, catwalks (relays) | lifts |
| Warehouse | crate hall | overlooks, L halls | stairs, lifts |
| Mine | shaft | caves, chasms (sinks, lava) | lifts, drops |
| Slipgate Complex | octagon | halls, vaults (teleporters) | stairs, lifts, gates |
| Waterworks | cistern | bridge spans, shafts | water, lifts |
| Detention Block | cell block | L halls, mazes (keys) | stairs, lifts |
| Hangar | arena | atriums, overlooks | jump pads, lifts |
| Laboratory | octagon | vaults, cross halls (relays) | lifts, stairs |
| Caverns | cave | chasms, cisterns | drops, stairs, water, lifts |
| Sunken Temple | cistern | crypts, octagons, ziggurats | water |
| Lava Forge | catwalk | bridge spans, chasms (lava) | stairs, lifts, drops |
| Abyss | shaft | chasms, catwalks (sinks) | drops, lifts |
| Sky Islands | bridge span | courts, octagons (sky) | jump pads, lifts |
| Gauntlet | arena | arenas (dense, linear) | stairs, lifts, drops |
| Colosseum | arena | terraces, courts (guardians) | stairs |
| Siege | court | tower hubs, terraces | stairs, lifts |
| Labyrinth | maze | L halls, crypts (loops) | stairs |
| Clockwork | tower hub | vaults, shafts (relays) | lifts |
| Twin Towers | tower hub | bridge spans, shafts | lifts, stairs, jump pads |
| Spiral Descent | shaft | tower hubs, terraces (sinks) | stairs, drops, lifts |

### Rooms over rooms

A room may be placed straight over or under the room it links to, their
boxes overlapping by nine cells or more each way and a slab of two lifts
between. The link is then joined through the slab by a column two cells
square, where both floors run round it, nothing of either room is kept
clear (stairs, stage) and the lower room is open from its floor to its
ceiling over it; when no column will do, by a corridor as before.

- **Lift**: Quake's `func_plat`, built risen to the upper floor and
  lowered to the lower when the level begins; it rises when stepped on.
- **Drop**: a hole in the upper floor (one way down).
- **Water**: the column flooded from the lower floor to just under the
  upper, walled round in the lower room but for a way in at its foot;
  swum up, dropped down.
- **Jump pad**: a pad at the foot of the column, a push straight up it and,
  in the slab, a push on the slant that sets the body down on two cells of
  floor beside the hole (a `_land` point the navigation reads).
- **Stair**: a corridor that climbs between them.

An open link takes a lift, water or a stair (both ways); a one-way link a
drop (down) or a jump pad (up); a link that needs a door, a stair. Rooms
already joined both ways may have a quicker drop or pad besides, as the
theme likes: it skips nothing. The floors' flood (`floor_reached`), the
pits' flooding and the navigation know each of them.

## Pipeline (`generate.jac`)

A seed picks a theme, a niche (how much the expedition loops, how vertical it is, how
densely it is fought over, how big it is) and an objective archetype (keys,
relays, guardians or a mix). Up to four candidates are built in full; each is
turned down if it cannot be laid out, needs too many teleporters, or if a
room's stage cannot be walked to. Candidates also need safe supply budgets
and a realised progression graph: local approaches, connectors and teleporter
placements must join their stages, and each promised lock must have a door.
The critic scores the remaining candidates and keeps the best.

1. **Mission** (`mission.jac`): beats and links, a cyclic
   grammar after Dormans whose links carry tokens; an exhaustive search over
   (beat, tokens) proves the goal reachable and no state a softlock. Plain
   beats on the main progression become recovery beats between combat runs;
   encounters are assigned as teaching fights, crossfire, pressure, ambushes
   and guardians.
2. **Spaces** (`spaces.jac`): each beat becomes a box in a voxel massing
   (`massing.jac`, cells 32 units across and 16 up) and takes an archetype by
   its role: a hall (dais, pillar rows), an atrium (a balcony round its walls
   and stairs up to it), a shaft (stairs winding up its walls, open in the
   middle), a chasm (a pit crossed by a bridge, stairs from the pit up to a
   ledge), an open court (an arcade round it, sky over it), terraces, a stair
   hall, a vault (a dais for its prize), an arena (a sunken pit and steps
   down), a crypt (a grid of squat pillars), an overlook (a mezzanine along
   one wall), a tower hub (stairs winding round a central column), a
   catwalk (walkways over a pit of lava or slime), a cistern (a pool with a
   raised walk and a bridge), a cell block (galleries over cells), a crate
   hall (stacks of crates kept off two aisles), a cave (rounded corners,
   hanging rock, uneven floor, rock pillars), a bridge span (a bridge down
   a long void), an L hall, a cross hall, an octagon, a ziggurat (a stepped
   mound) or a maze (passages two cells wide round a walk by the walls),
   weighted by the theme. Doorways (`Doorway`) are found
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
5. **Dressing** (`dress.jac`): baseboards, selective wall bands and cornices,
   ribs on the long walls of major rooms, railings, doorway headers and bars
   across windows. Recovery rooms and natural spaces keep simpler outlines.
   Broad, repeated lighting is reduced; warm recovery lights and brighter
   objective markers give spaces focal points. Key and relay gates have
   consistent lighting cues. Floor markers are only one unit high.
6. **Cast** (`cast.jac`, `experience.jac`, `supplies.jac`): objectives, doors,
   teleporters, weapon discoveries and distinct encounters. An experience
   graph links each room to its encounter, positions and rewards. Ranged
   positions need a sightline to the approach, pressure uses floor-level
   attackers, ambushes favour occlusion, and crossfire links opposing lanes.
   Placement and sight checks include thin dressing as well as the massing.
   Start, recovery, vista, cache and goal rooms receive no population.
   Nearby enemy positions also avoid sightlines into quiet rooms' stages.
   Health and ammunition use the engine's actual pickup rules. Guardians
   count toward threat and damage. Each fight budgets for arrival at 35 HP
   and locally available ammunition for the gun offered in the safe start;
   optional branches and later weapons cannot subsidise that guarantee.
   Higher weapons come with their own ammo, and optional caches offer distinct
   capabilities from the other games. The damage and accuracy forecasts remain
   heuristics.
7. **Critic and progression** (`critic.jac`, `progression.jac`): geometric
   corpus distances plus bounded targets for quiet intervals, weapon and
   ammo variety, encounter coverage and variety, cover, usable firing lanes,
   supply adequacy and useful optional rewards. Weapon variety counts distinct
   discoveries, and looping plans favour physically certified return shortcuts.
   More pickups do not produce an unlimited score. The realised corridor graph
   repeats the exhaustive
   token-state proof; locked passages that fell back to ungated teleporters
   and gates that did not fit are rejected. Local floor and connector checks
   are complemented by real collision and mover tests below.
8. **Brushwork** (`brushwork.jac`): the massing's shell (the solid touching
   air, diagonals included, so the world is sealed) merged into boxes that
   hold only cells of one space exposed alike on every side, so a side faces
   air all over or is caulked; each dressed by the kit of the space it faces.
   Dressing boxes, liquids (their contents said on every side), lamps and the
   cast join them as map items.
9. **Build**: the map items become a studio scene, compiled by
   `editor/compile/live.jac` with buried faces cut away
   (`editor/compile/cull.jac`) and lit by the studio's light bake at 32-unit
   luxels (bounce, a light grid for models).

Every stage is made a step at a time: the generator's functions are Jac
generators (`draft_steps`, `arrange_steps`, `route_steps`, `dress_steps`,
`map_item_steps`, `compile_steps`, `light_job_steps`, the light job's
`work_steps` and `finish_steps`) that pause every few milliseconds of
work, and a `Forge` steps them for as long as it is given. The game gives
it 4 ms a frame while a level is played (30 ms while a way out waits on
it); the studio steps it a few steps a frame to show it. The longest
single step is about 30 ms (a large face cut against many brushes), most
are well under 8, and a level comes out the same however it was stepped.

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

`ed_exp watch <seed> [level]` shows a level being made, in a new scene: each
candidate's rooms appear as boxes as they are placed (the start green, the
goal red, rooms with an objective amber), then shaped, with their floor
levels and stages; each corridor's search is drawn as it goes (the blocks it
goes between, and the block it has reached), and the corridors found in the
colour of their link; then the lamps and the cast. A box beside it says the
stage, the candidate and why earlier candidates were turned down, and holds
it still, steps it, paces it (a bar, or Slower and Faster) or stops it. Once
a candidate is chosen and its brushes written, the level opens as a
document, as `ed_exp open` opens one, and is compiled and lit by the
studio.

## The arsenal

A Passion level, generated or a studio scene, supports every weapon of the
three games (`passion_arsenal` in `games/weapons.jac`), each by its own
game's rules: its shots, missiles, blasts and knockback, its muzzle flash,
its sounds and its model in view come from its own game (`shot_game`,
`Projectile.game`, the per-game archives of `AssetCatalog` in the view
weapon, effects and audio).

- **Held by name**: a weapon is owned as `weapon_<game>:<key>`, so Quake's
  shotgun and Quake II's are two; a pickup in a Passion level is renamed so
  (`passion_pickup` in `games/items.jac`), and its sounds come from its
  game's archive.
- **Number keys by role**, each pressed again stepping to the next held
  weapon of the role (`change_role`): 1 the axe and the gauntlet, 2 the
  blaster and the machine guns, 3 the shotguns, 4 the nailguns and the
  chaingun, 5 the grenade launchers and the hand grenade, 6 the rocket
  launchers, 7 the lightning guns, hyperblaster and plasma gun, 8 the
  railguns, 9 the BFGs (`PASSION_ROLES`; the 9 key is bound to `weapon 9`).
  Each weapon has a number of its own (`passion_slot`: its game's slot after
  10, 20 or 40), which saves and the view use.
- **Ammunition is shared by kind**: one pool of shells, nails, bullets,
  grenades, rockets, cells, slugs, lightning and BFG charge, each gun
  spending what its own game spends, up to `PASSION_AMMO_CAPS`.
- **Armor** is the one value every game's pickups already share; each
  pickup sets how much it absorbs by its own game's rule.
- **The start**: the melee weapon and first gun of the game the level's
  start district comes from, recorded as `_passion_kit` on the generated
  worldspawn: Quake's axe and shotgun with 25
  shells, Quake II's blaster, or Quake III's gauntlet and machine gun with
  100 bullets. Studio scenes without that field retain the entity-count
  fallback (`lead_game`). A new gun is visible in the safe starting room,
  with two further discoveries during progression and additional optional
  rewards. Adding items cannot change the planned starting kit.
- **Sounds** in a Passion level are read from the game a path names
  (`q2:sound/...`), else Quake's archive, else the first game that has the
  file; monsters are heard from their own game's archive.

## Validation

```sh
jac test tests/passion_tests.jac
jac test tests/passion_experience_tests.jac
jac build scripts/passion_experience_audit.jac --native -o .jac/qp-audit
.jac/qp-audit
jac build scripts/passion_walkthrough.jac --native -o .jac/qp-walk
QP_HEADLESS=1 QP_SEEDS="4 25 84 100" QP_CONFIG_DIR=.jac/walk-config .jac/qp-walk
jac build scripts/passion_map.jac --native -o .jac/qp-passion-map
QP_SEEDS="1 2 3 4 5 6 7 8 9 10 11 12" .jac/qp-passion-map
jac build scripts/passion_play.jac --native -o .jac/qp-play
QP_GAME=passion QP_SEEDS="1 2 3" DYLD_LIBRARY_PATH=vendor .jac/qp-play
jac build scripts/passion_look.jac --native -o .jac/qp-look
QP_GAME=passion QP_LOOK_GAME=passion QP_LOOK_MAP=v4-5 QP_LOOK_ROUTE=1 DYLD_LIBRARY_PATH=vendor .jac/qp-look
jac build scripts/passion_corpus.jac --native -o .jac/qp-corpus
QP_CORPUS_GAMES=passion .jac/qp-corpus
```

- `tests/passion_tests.jac`: the massing's shell seals all air; every
  archetype gives a stage and doorways and every floor level can be walked
  to; arrangements are deterministic and corridors join their doorways;
  names parse strictly and a run's levels follow one another; a survey
  keeps its promises (start, exit, a door for each lock, a fair score), and
  a forge stepped a step at a time makes the same expedition; a compiled
  expedition is walked from its start to its exit by the yardstick over its
  real collision.
- `tests/passion_experience_tests.jac`: pickup amounts and caps, matched
  ammo for each progression weapon, starting-kit stability, experience graph
  scoring, thin dressing in sight/collision checks, route progress during
  detours, gate wiring, a deliberately broken physical corridor, and generated
  supply and pacing contracts.
- `scripts/passion_experience_audit.jac`: one naturally selected seed per
  theme, or `QP_SEEDS`; JSON results include experience measures and rejected
  candidates.
- `scripts/passion_walkthrough.jac`: the actual player bot and game loop
  from normal inventory, without god mode or warping. A pass requires level
  completion; timeout and death budgets are explicit failures. Defaults are
  600 simulation seconds and three deaths, configurable with `QP_WALK_SECONDS`
  and `QP_WALK_DEATHS`; `QP_WALK_TRACES` chooses the trace/screenshot folder.
  This is an automated acceptance tool, not a substitute for human playtests.
- `scripts/passion_connectors.jac`: every lift, drop, flooded shaft and
  jump pad of a seed ridden in the game: the player set on a lift's
  platform, a pad, over a hole or at the foot of a shaft must come out on
  the other floor.
- `scripts/passion_map.jac`: with `QP_THEME=<key>` (or `all`, each over
  `QP_SEEDS`) any theme is surveyed whatever the seed; the line says the
  theme, its connectors and the archetypes used. How each seed's survey went, why candidates
  were turned down, teleporters and windows (seeds 1-12: 0-2 teleporters,
  2-7 s).
- `scripts/passion_play.jac`: each seed's logic played in the game (keys,
  switches, guardians, locked doors, the way out); with `QP_PLAY_RUN=1` the
  way out must also lead on to the run's next level, carrying health and
  leaving keys behind, and a death there must begin it again at once.
- `scripts/passion_look.jac`: photographs from the widest views a player can
  reach, along the route from start to exit, or from given places; the same
  for the original levels, to compare by eye.
- `scripts/passion_corpus.jac` with `QP_CORPUS_GAMES=passion`: generated
  expeditions measured like the originals.

Jac compiler defects found while building Passion are recorded in
[jac native fixes](jac-native-fixes.md).

## Limitations

- Rooms are boxes and their structure axis-aligned: no slopes, arches or
  round rooms (octagons and caves are cut on the grid), and walls are a cell
  thick.
- A theme holds for a whole level; districts change by section, themes do
  not yet.
- Only rooms placed one over the other are joined straight up or down, and
  a lift is called up only by stepping onto it (or by falling to it down
  the shaft from above).
- The yardstick does not swim or ride lifts, so a level's reach and routes
  are measured as far as walking, jumping, dropping and teleporters go.
- Generated levels are still more detailed in small faces and trim than the
  originals (cut faces round pilasters, plinths and stair risers), and use
  fewer textures.
- Supply forecasts keep the safe-start gun viable independently of later
  discoveries. Damage, accuracy and expected arrival health remain conservative
  heuristics; combat difficulty still needs complete playthroughs and human
  feedback.
- Physical progression proofs use the massing and realised passage wiring;
  they do not simulate moving platforms or combat. Walkthroughs and connector
  execution cover those separately.
- The level is one cluster (no visibility culling); generated expeditions
  draw well within the frame budget, but a bake by planes could cut them.

# Human navigation review

The experience graph is also reviewed for what a person can recognise.
`wayfinding.jac` visits the room graph with `ReadRoutes`, attaching passage
cues to their rooms. It distinguishes onward passages, returns, optional
side rooms and gates. Secret walls receive no visible threshold cue. These
marks describe static relationships; they do not promise that a passage is
the player's current objective.

Within each room, a floor search samples stage-to-threshold and landing
walks, respecting thin dressing and small steps. Direct-light estimates
include occlusion. Uncovered route samples receive local light instead of
declaring a room adequately lit merely because it contains a lamp. The
audit exposes `route_samples`, `route_dark_before`, `route_dark_after`,
`route_added_lamps` and `route_missing_paths`. These are visibility proxies,
not measured rendered luminance or proof that every floor is navigable.

Portal pads and nearby arrivals are chosen together. A return pad is 64–96
units from the arrival on a clear, level walk; the player arrives outside
its trigger. Catwalks carrying portals get a wider perimeter landing before
dressing, retaining edge railings and clearance from wall trim. Pad and
arrival space is reserved before population. A candidate with
no suitable pair is rejected. Spawn and arrival facing prefer a visible,
open onward passage over a locked gate or optional branch.

Devices have distinct markings: an animated portal surface, a square exit
frame, two lift stripes and three expanding jump-pad bars. Lift stripes are
part of the moving brush model. Silver and gold gate lights and mark counts
differ. Return-route scoring includes certified one-way passages back to
earlier required rooms, as well as shortcuts; a descent into a new room is
not a return.

`scripts/passion_design_audit.jac` exports room bounds, heights, actual
passages, cues, lamps, encounters and entity positions for visual review.
Use this alongside game screenshots and human play, not just bot outcomes.
A stuck bot can expose a confusing junction without demonstrating that a
human cannot traverse it. In particular, review useful player cover rather
than equating enemy proximity to a wall with tactical cover; count quiet
beats along the route actually played rather than all optional rooms; and
tune supply surplus from observed consumption rather than treating a
conservative supply forecast as a difficulty score.

The mission briefing includes prerequisites granted on required detours,
including keys that are not themselves exit tokens. Long messages wrap to
the window width so those objectives remain visible. The native compiler
uses the backport at `9421a0850b`; the corresponding upstream fix and
regression coverage are in [jac PR #10138](https://github.com/jaseci-labs/jac/pull/10138).
