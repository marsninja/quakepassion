# Passion runs

Passion is the fourth game mode of the shared engine (`games/passion/`). A
run is a seed. Each of its levels takes an **essence** (the level graph of
one of the original levels of Quake, Quake II and Quake III) and makes a new
level of brushes for it, which is played only once its own level graph
proves that it can be finished.

## Run

With the build in the README and all three games under one asset directory
(`~/quake-assets` by default; `QP_ASSETS` names another parent):

```sh
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH=vendor ./qp
QP_GAME=passion QP_MAP=trace-e1m1 DYLD_LIBRARY_PATH=vendor ./qp
```

- `QP_SEED` is the run's seed (default 1). Its first level is `v4-42`, the
  levels after it `v4-42-2`, `v4-42-3` and on; `QP_MAP` names any of them.
- `trace-<map>` makes a level from one original's essence named outright
  (`trace-e1m1`, `trace-base1`, `trace-q3dm6`), and leads on into a run of
  its own seed.
- Reaching a level's way out shows its tally; the next level is made then,
  its progress on the tally, and Enter goes on to it. Health, armour,
  weapons and ammunition carry on; keys do not. A death begins the level
  again with what the player came in with.
- Essences are read from the player's own game files the first time they
  are wanted (5-80 seconds each) and kept under `QP_CONFIG_DIR` (else the
  home folder) in `.quakepassion-essences/`; nothing of the games goes in
  the repository. `scripts/level_proof.jac` with `QP_PROOF_CORPUS=1` reads
  them all ahead of time.

## The level graph (`engine/level/`)

One graph of what a level lets a player do, read off any level the engine
loads: an original, a studio scene, a generated level. The bots route by it
and Passion generates from it.

| Layer | What it holds | Read from |
| --- | --- | --- |
| Places | the navigation's areas, each with its floor, the air over it, sky, liquid | `engine/nav/compile.jac`, sounded against the level |
| Moves | ways between places (walked, dropped, jumped, swum, lifted, teleported), each *must* or *may* | the compiled navigation; jumps run through the player's own movement; falls run off every ledge |
| Gates | movers that bar places (and ways that pass through them) until their tokens are held | the level's doors, lifts and secret doors |
| Openers | what gives a token: press, touch, shoot, pick up a key, kill | the level's activation graph, as the player bot plans from it (`engine/world/objectives.jac`) |
| Things | monsters and supplies, each in its place | the level's entities |
| Stages | the tokens each place takes to get to | the proof |

- **Proof** (`prove.jac`): a player's state is a place and the tokens held.
  The search takes every state the *may* moves reach from the start and
  asks of each whether the way out is reached from it over *must* moves,
  tokens taken where their openers are done, gates passed only with what
  they want. A level **finishes** when the start's state does; a
  **softlock** is a state that does not, outside a death place. Each token
  is left out in turn: those the level cannot be finished without are the
  ones it **requires**. An arena (no way out of its own) proves when no
  state strands a player from the start.
- **Budget** (`budget.jac`): a ledger of health, armour and ammunition
  walked along the proven route with each game's own weapons, monsters and
  supplies: supplies on the way or a short detour in sight taken, each
  monster fought when the route first comes where it stands or sees it, with
  the best weapon that can kill it. It is an estimate of the fights, not a
  simulation of them.
- **Pruning**: an essence that finishes but strands a player in a pit or a
  pocket has those places taken out (when no opener, start, way out or
  death needs them), and is proven again.
- **Routes** (`routes.jac`): the graph as the AAS arrays the router reads.
  The player bot routes by it; Quake III's bots bring their map's shipped
  AAS file in as a graph; the studio reads and proves its scenes' graphs.

`scripts/level_proof.jac` reads and proves original levels and says why one
does not prove (where its traps are, how a player gets there, what bars the
way out, which tokens are wanted and who gives them).

## Making a level (`generate.jac`)

1. **Essence** (`essence.jac`): the run's seed orders every original, and a
   level takes the first in its order from its depth that proves clean;
   from the third level on, the hardest (lowest health its budget leaves)
   of the next three.
2. **Candidates**, up to four, the first that proves clean kept:
   - laid out anew (`embed.jac`): the essence split into pieces (its
     progression's stages, or sections across it), each turned and set down
     as close as it fits, joined by passages routed over and under what
     stands between them; or one piece swapped for a piece of another
     essence already read;
   - transformed in full (`transform.jac`): mirrored and turned, its keys,
     plates and switches moved to other places still reached before what
     they open (each move kept only if the essence still proves);
   - turned only;
   - as the essence lies.
3. **Sculpture** (`sculpt.jac`): the essence's places laid on Passion's
   massing (cells 32 units across, 16 up), a ground for each floor of each
   column a body covers, the essence's moves the ways between them; stairs
   too steep for the grid eased; ledges kept open where the essence drops
   off them; rooms and passages read off how far each ground lies from the
   floor's edge; ceilings by each room's size, sky where the essence was
   open to it; pits of liquid under gaps it jumps across; lift shafts and
   floors that lower; then the massing carved and dressed (`dress.jac`:
   trim, pilasters on any wall, lamps, railings) in two or three districts
   (`kits.jac`) shared out along the progression.
4. **Cast** (`cast.jac`): doors where the essence's barred a doorway (keyed
   as they were, fired by their openers, secret ones opened by a shot), rock
   over each so it opens into stone; lifts in their shafts; a key, a plate
   or a shootable button where each opener was done from; teleporters where
   the essence's carried a body; the way out (caged behind a door when the
   essence fired its way out by a chain; an arena's on its highest ground,
   opened by a counter of its foes' deaths); and the population cast afresh
   stage by stage, foes from the roster of all three games as strong in all
   as the essence's were there, and the health, armour, ammunition and
   weapons it had there, each in its district's game's own kind.
5. **Build and proof**: the map items compiled by the studio's compiler, the
   made level opened in a world of its own with its things spawned, its own
   graph read and proven. A candidate that does not prove is passed over
   with a line on why (and how its graph differs from the essence's:
   `verify.jac`). The kept level is lit by the studio's light bake.

`scripts/passion_forge.jac` makes levels as the game makes them and says how
each candidate went; `QP_PASSION_UNPROVEN=1` lets the game play the last
candidate when none proves (to look at what the proof found).

## Prefabs (`prefab.jac`, `prefabs/`, `assemble.jac`)

A second engine, side by side with the essences: a run named `pf-<seed>`
(the Passion page's "Prefabs" choice, or `QP_MAP=pf-42`) assembles each
level from prefabs. A prefab is a stretch of an original level made again
by code, at its scale and with its flow (its doors, buttons, lifts and
bridges), and varied by the seed: its sizes, heights, which way it lies,
what stands on its floors.

- A prefab is a node (`Prefab`) with a box of its own cells, a way in on
  its -x face and the ways out it offers (`Port`). Prefabs stand in a chain
  (`Next`). The `Lay` walker has each choose itself (its own `choose`
  ability) and places it, mirrored and turned so its way in meets a way
  out of the one before across a short passage, clear of all laid. The
  `Raise` walker has each carve itself into the massing and put down its
  entities (its own `rise` ability, through `Raising`), and cuts the
  passage from the one before, with a double door that slides into its
  walls.
- The level is then dressed, compiled, proven and lit as an essence's is.
  The pilot plays its best candidate even when none proves (the forge log
  says so).
- A `pfh-<seed>` run takes the hand-made library (`prefabs/library.jac`):
  a module per original of all three games (Quake's 31, Quake II's 39,
  Quake III's 26), each about five stretches drawn after that original's
  flow, each playing a part: `start`, `flow`, `hub`, `keyroom`, `end` or
  `gate` (an end behind a key's door). A level is a tree of them: a start,
  a flow or two, a hub; from the hub a branch to a key room, and the hub's
  way on locked by that key, so the key is fetched and the branch walked
  back; from level 2 a second hub and the gold key; then the end. Any
  original's stretch may follow any other's.
- Quake III's arenas hold no foes of their own, so each arena's stretches
  take Quake's and Quake II's; the arenas share their entry, pad tower,
  atrium, vault and portal (`prefabs/q3arena.jac`, made for each arena
  in its own palette) and each adds a stretch of its own (a chasm of
  bridges, a tower climbed by a spiral stair, platforms thrown between by
  jump pads, ledges over a void with teleporters back up...).
- Supplies follow the foes (`provision`): health at every second foe and
  every Quake II one, ammunition at every third in its foe's game, and at
  the start Quake's super shotgun, nailgun and grenade launcher and Quake
  II's super shotgun, machinegun and grenade launcher, so either game's
  ammunition feeds a gun.
- Trying stretches: `QP_PREFAB_SOLO=<original>:<name>:<role>` makes one
  stretch alone between plain rooms (`QP_PREFAB_SOLO_LEAVE=n` takes its
  n-th way out); `QP_PREFAB_FOCUS=<original>` takes that original's
  stretches first in every level.
- Jump pads sit three cells back from the edge they throw a body over and
  `keep` that edge, since the dressing rails any drop of four lifts.

## Districts (`kits.jac`)

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

A level never takes the district read from its own essence's level.

## The arsenal

A Passion level holds every weapon of the three games (`passion_arsenal`
in `games/weapons.jac`), each by its own game's rules; number keys choose
by role (`PASSION_ROLES`), ammunition is shared by kind, armour is the one
value every game's pickups share, and the start kit is the melee weapon and
first gun of the game the level's things come from most.

## Limitations

- Static guarantees cover moving through the level, gates and their
  openers; they assume every foe can be killed (the budget estimates what
  it costs), and model doors that start open as no gate.
- Quake III's jump pads are not compiled into the navigation yet: an arena's
  places reached only by a pad are left out of its essence.
- Re-embedding and splicing join pieces by plain passages; the candidates
  they make prove less often than the others.
- The next level is made when the way out is reached (reading an essence or
  proving a level are long steps), not while the last is played.
