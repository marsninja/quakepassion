# Studio

The studio is QuakePassion's editing mode: the running game turned into a
document, inside the same binary. The full plan and feature list are in
issue #73; this page says what exists, how it is built and how it is checked.

## Run

```sh
./qp +edit                       # or QP_EDIT=1 ./qp, or F8 in a level
QP_GAME=q3 QP_MAP=q3dm7 ./qp +edit
```

- **Level view**: hold the right button and use W A S D (Q and E for down and
  up, Shift to go faster) to fly; the wheel dollies; the middle button pans.
  A click selects the entity under the pointer (Ctrl or Shift adds); F looks
  at the selection. The selection's `target` links are drawn to what it fires
  (green) and from what fires it (yellow).
- **Four views**: View > Four views (`ed_layout 4`) splits the level view
  into 3D, top (x/y), front (x/z) and side (y/z). The axis views slide with
  the right or middle button and zoom with the wheel; picking, dragging and
  side handles work in every view, and Look at (F) centres all of them. Each
  axis view draws a grid behind the level that coarsens as the view zooms
  out (16 units, then 64, 256, ...), every fourth line brighter. View > Axis
  views as edges (`ed_display wire [3d|axis|all]`) draws a scene's brushes
  by their outlines, and a shipped map by the edges of its triangles.
- **A rectangle selects**: a drag that starts on nothing selected draws a
  rectangle in any view and selects what lies in it (Ctrl or Shift adds).
- **A click goes through**: clicked again in the same place, a click picks
  what lies behind what it picked before, nearest first, and comes round to
  the front again. So a brush under another in the top view, or an entity
  inside a room, is two clicks away.
- **From the selection to its kin** (Edit menu): the entity that owns the
  selected brushes (`ed_select parent`), an entity's brushes
  (`ed_select child`), and the neighbour of the one selected thing in map
  order (`ed_select next`, `prev`). `ed_select brush <entity> [brush]`
  picks by number, counted from 0 as a compiler's message counts them.
- **Sets**: `ed_keep <name>` keeps the selection under a name,
  `ed_recall <name> [add]` selects it again and `ed_forget <name>` drops
  it; `ed_keep` alone lists them. A set is saved with the scene's map and
  comes back with it; what is deleted leaves it, and returns to it when the
  delete is undone.
- **N** looks at each selected thing in turn (Shift+N the other way,
  `ed_browse`), leaving the selection as it is. `ed_swap` has the two
  selected things change places. `ed_marked set` marks the selected
  entity (or the one that holds the selected brushes) for later:
  `ed_marked take` hands it the brushes selected then, `ed_marked pick`
  selects it, `ed_marked swap` has it change places with the one thing
  selected, and `ed_marked clear` forgets it.
  Ctrl+A selects everything, Ctrl+I the rest, `ed_select material:<name>`
  every brush with a side of that material.
- **Scene** (left): the map's entities by class. A click selects, a click on
  a class selects all of it, a double click looks at the entity, and the
  filter narrows the list by class, `targetname` or `target`.
- **Inspector** (right): the selection's fields. Enter sets a field on every
  selected entity, `x` removes it, and the last row adds one. Each field is
  edited by its kind: a list for one of several values, a patch of colour
  beside a colour, buttons that turn an angle (`ed_bump angle 45`), an arrow
  beside a `target` that selects what it fires. Under the fields the class
  says what it is, its spawnflags are boxes to tick (`ed_flag <bit> <0|1>`),
  and the fields it knows that the selection lacks wait to be filled in.
- **Classes** (left): the entity classes of the document's game by family,
  with a filter. A click adds one where the camera looks; a class made of
  brushes takes the selected brushes, or a new box (`ed_class <name>`).
- **Toolbar**: Play (F5) rebuilds the world from the document and plays it
  from the start; From here (F6) starts at the camera; F8 stops and returns
  to the document as it was left. Undo and redo (Ctrl+Z, Ctrl+Y), a classname
  field that adds an entity in front of the camera, and Save (Ctrl+S).
- Dragging a selected entity moves the selection as seen (in the plane that
  faces the camera), snapped to 8 units; Shift keeps to one axis and Ctrl
  moves freely. Arrow keys, PgUp and PgDn move it 16 units (64 with Shift);
  Del deletes it; Ctrl+D duplicates it.
- A selection that is not one lone brush shows three arrows from its
  middle, red, green and blue for x, y and z; dragging one moves the
  selection along that axis alone, on the grid.
- **G** changes those handles (`ed_gizmo <move|turn|size|box|next>`, Brush
  menu), for any selection, a lone brush included:
  - *Rings that turn.* Each ring that faces the view has a knob; taking the
    knob round the ring turns the selection about that ring's axis. The
    axis views show the one ring that faces them, the 3D view all three.
    A turn snaps to 15 degrees (`ed_anglesnap <degrees>`, kept between
    sessions); Ctrl turns by single degrees.
  - *Boxes that size.* A box on each axis stretches the selection along it,
    and a fourth stretches all three at once; a pull as long as the arm
    doubles it. Sizes go in quarters, or freely with Ctrl.
  - *One box round it all.* A single handle round everything selected,
    lying along the two axes of the view looked through (level, across
    the selection's middle, in the 3D view). Its middle moves the
    selection. A corner turns it about the box's middle, in steps of the
    angle snap; with Shift the corner sizes it instead, each way by its
    own factor, the far corner staying put. The middle of an edge taken
    along the edge shears: that edge slides, the far edge stays and
    everything between goes in proportion; pulled outward it sizes that
    way alone. Drags go by the grid, or freely with Ctrl.
  - While a handle is held the views show the selection as it would be
    left, and say by how much.
- **Shears and other changes by number**: `ed_shear <x|y|z> <x|y|z>
  <amount>` slides the selection along the first axis by so much for each
  unit along the second (Brush > Lean a quarter along x), and `ed_linear
  <nine numbers> [about <x> <y> <z>]` carries it through any change that
  keeps lines straight, said as what the x, y and z axes become. Brushes
  go with their materials (or leave them where they lay, with the texture
  lock off), patches by their control points, and entities by where they
  are and the way they face.
- **The pivot** is the cross the handles stand on: the selection's middle,
  put on the grid, until it is dragged somewhere else or set by
  `ed_pivot <x y z>` (`ed_pivot middle`, `ed_pivot clear`). A pivot set by
  hand lasts as long as the selection does. A group selected alone keeps
  the pivot for itself, as its `_center` field: it is saved with the group,
  moves, turns and stretches with it, and undoes. `ed_rotate`, `ed_resize`
  and `ed_mirror` go about the pivot too.
- **Playing** (Play menu): F5 plays the scene, F6 from where the camera
  is, and `ed_play selection` plays only what is selected, in a level of
  its own, from where the camera is. While a game played from the studio
  runs, `ed_pause` holds it still and `ed_tick [count]` lets its time move
  on by sixtieths of a second, so a door, a fall or a trap can be watched
  a step at a time; `ed_pause` again lets it run, and F8 returns to the
  studio. `ed_played` prints how the game stands, its doors among it, and
  `ed_fire <targetname>` sets off whatever has that name, as if something
  that targets it had gone off: a door opened or a chain started without
  walking to its trigger.
- **Handles on an entity**: one selected entity that faces a way has a
  handle at the tip of its arrow; dragged round it in the plan or the 3D
  view, it turns the entity, in steps of the angle snap. A selected light
  has a handle at the edge of its reach; pulled in or out, it sets the
  light's value. A light that shines one way also has its cone drawn and
  a handle on the cone's edge: pulled out or in, it sets `_cone`, half the
  cone's angle. Each drag is one edit. Paths are drawn corner to corner
  in every view.
- **Logic from a library**: `ed_logic` lists the pieces of logic the
  scene's game has (a relay, a delay, a counter, a trigger that fires once
  or many times, a message, a timer, a change of level) and `ed_logic
  <kind>` adds one as that game's own class, with the fields that make it
  that piece and a name, so it shows in the logic graph ready to be wired.
- **Favourites**: `ed_fav <classname>` keeps a class in a Favourites list
  at the end of the Library tab, a click from being added; the same
  command stops keeping it.
- **As it would spawn**: `ed_spawn <easy|normal|hard|deathmatch>` (Play
  menu) hides the entities that skill or mode leaves out, by the
  spawnflags every game shares (and Quake III's `notsingle` and
  `notfree`); `ed_spawn all` shows everything again. An entity's form ends
  with those four options to tick, whatever its class.
- `ed_refield <key> <old> <new> [all]` replaces part of a field's value on
  the selected entities, or on every entity: a set of doors renamed, a
  texture prefix changed, in one undoable step.
- `ed_check logic` adds a deeper look to the check: entities that wait for
  a name nothing fires, and softlocks, where the logic can leave a player
  with no way on. A walker carries "this is set off" down the graph of what
  fires what, from everything that sets itself off (a trigger walked into,
  a button, a monster that dies); what waits to be fired (a relay, a
  counter, a target, a named door, platform or train) and is fired only by
  things the walker never reaches is never set off, and is named with what
  fires it. A counter that more must fire than ever can (its count against
  the things that fire it once each) is named, and so is a Quake door
  that wants a gold or silver key the level has not got, and a Quake II
  lock (`trigger_key`) whose key is not in the level.
- What is pasted, or added from a prefab, keeps a gadget's names apart: a
  name the pasted entities give themselves and fire among themselves
  becomes a new one when the document already uses it, and what fires it
  among them follows. A button pasted without its door still opens the
  door it did, and a door pasted alone is still opened by what opened the
  first.
- **Baking what can be seen**: a built scene is one leaf, all of it drawn
  from anywhere. `ed_bake [cell]` (Play menu) cuts its plan into cells up
  to that wide (256 units unless told), each a leaf of the level's tree
  with the faces that lie in it, and gives each cell the cells it can see,
  so the engine draws only those from inside it, as it does for a shipped
  map. What can be seen is found by looking: from the points a player
  could come to in one cell (those reached, in plain sight point to point,
  from where the scene's entities stand) to such points and to the faces
  of another, with the scene's fixed brushes in the way. Cells that touch
  always see each other, and what one sees sees it back, so it errs toward
  drawing more; what no entity can reach (under the floor, outside the
  walls) is seen by nothing. `ed_bake off` builds it as one again.
  `ed_cells` (Play menu) draws the cells in every view: the one looked
  from in yellow (where the 3D camera is, or where a lone selected entity
  stands), the cells it sees in green, the rest in red.
- **Navigation for bots, baked** (`ed_nav bake [cell]`, Play menu): the
  games' bots route over areas and the ways between them, read from an
  arena's own file; a scene made here has none, so its floors are
  sampled on a grid (cells of 32 units unless told otherwise): a place
  to stand wherever there is floor under the whole of a cell and room
  for a head over it, on up to four storeys. Neighbouring places are
  joined by a way that is walked (a step of 18 or less), jumped up (a
  ledge of 44 or less) or dropped down (a fall of 256 or less), where
  nothing stands between them. The result is the engine's own
  navigation data and mesh, so its own router answers: `ed_nav route
  <from> <to>` says how long the way is, or that there is none, and
  `ed_nav check` names what cannot be reached from the first player
  start (they join the Checks tab's findings). `ed_nav show` draws the
  ways: walked green, jumped yellow, dropped red. `ed_nav clear`
  forgets it. Not there yet: the mesh is not handed to the bots of a
  game played from the scene, it is not written as an arena's file, and
  it knows floors only (no ladders, water, lifts, jump pads or
  teleporters).
- **A bake is worked out once**: a level is compiled afresh every time it
  is loaded, since a game played in it writes on it, but its light and its
  cells are kept apart under a mark of what it was built of (the scene's
  map as built, how it is lit, how wide its cells are) and given to a
  level compiled of the same thing again: after an undo, or when a game
  is played or stopped. The last six are kept; `ed_build fresh` forgets
  them. A dump's `build from=` line says whether the last build worked
  its bake out (`new`) or was given it (`copy`).
- **Recipes**: `ed_recipe <name> "<command>; <command>"` keeps a row of
  editor commands under a name (in the settings, between sessions),
  `ed_make <name>` runs them, `ed_recipe <name>` alone forgets one, and
  `ed_recipe` (Play menu, Recipes) lists them to click.
- **Other programs**: `ed_run <command line>` writes the scene as a map
  beside its own file (`<name>.build.map`, with copies and prefabs made
  real) and runs the command line over it, with `%map%` for the file,
  `%dir%` for its folder and `%name%` for its name without the ending. The
  last lines of what the program says go to the console and the whole of
  it to `<name>.build.map.log`; every line that names an entity and
  brush by number (`Entity 4, Brush 12: ...`) or a line of the map
  (`hall.map:310: ...`) is listed in the Checks tab, where a click goes to
  the brush or entity it means (when the scene has no copies or prefabs,
  so that the map's numbers are the document's). A recipe may hold such a
  step.
- **Projects**: a project is a folder with a manifest, `project.qp`, at
  its top and `scenes/`, `prefabs/` and `textures/` under it. The manifest
  is text, a line a fact (`name`, `game`, `start`, `material`, `build`,
  `bake`, a `scene` line a scene, an `addon` line an add-on, a `recipe`
  line a recipe), written in the same order every time so that two
  versions of it compare line by line; a line it does not understand is
  kept as it was. `ed_project new <folder> [name]` makes one and
  `ed_project open <folder>` opens one (a path, or a name under
  `QP_PROJECTS`, else `./projects`), showing its start scene. While one is
  open, scenes and prefabs are saved under it, its image files are the
  ones offered as materials, a scene saved among its scenes is named in
  the manifest, `ed_recipe` keeps recipes in the manifest in place of the
  settings, and the classes offered for its scenes are its game's.
  `ed_project add` saves the scene in hand into it, `ed_project drop
  <scene>` stops counting one (its file is left), `ed_project start
  <scene>` says which opens with it, `ed_project set
  name|game|material|build|bake <value>` sets what its scenes are made
  and built with, `ed_project close` closes it, and `ed_project` alone
  (Window menu, The project) says what is open.
- **Add-ons**: `ed_addon <file>` loads a text file of entity classes, each
  a line after the word `class` in the form the studio's own table has
  them (`class trap_spikes | point | passion | Spikes that rise |
  dmg:n:20:What they do | start up`; the fields and spawnflags may be left
  off). Its classes are offered in the Classes tab and the inspector like
  any other; one the studio has of its own is left as it is. `ed_addon
  reload [file]` reads add-ons again without restarting, `ed_addon drop
  <file>` takes one and its classes out, and `ed_addon` alone (Window
  menu) lists what is loaded with a count of the studio's commands,
  classes, recipes and bound keys. An add-on inside the open project is
  named in its manifest and loads with it; any other is kept in the
  settings.
- **What an add-on brings beside classes**: a line `textures <folder>`
  names a folder of image files and `prefabs <folder>` a folder of
  prefabs, each a path from the add-on's own file (nothing above it).
  They go by the add-on's name, which is its file's name without its
  ending: the images are a shelf of the Materials tab (`add-on castle`)
  and materials called `addon:castle/<file>`, the prefabs a shelf of the
  Library tab and prefabs called `addon:castle/<name>`, placed and
  linked like any other. Dropping the add-on takes them away with its
  classes; reloading reads its folders again. (`ed_pack project` does
  not yet carry an add-on's files into a pack.)
- **Folders linked to, and lists of materials**: `ed_texlink <name>
  <folder>` uses a folder of image files as materials where it lies:
  they are a shelf of the Materials tab (`link stone`) and are called
  `link:stone/<file>`, and nothing is copied. `ed_texlink drop <name>`
  lets the folder go (it is as it was) and `ed_texlink` lists the links
  with how many materials each holds. `ed_texlist <name> add [material
  ...]` puts the material in hand, or those named, on a list kept by
  name; the list is a shelf too (`list walls`), in the order things were
  put on it, of materials from anywhere: a game's, the project's, a
  link's. `drop` takes materials off, `remove` gives the list up, and
  the name alone shows it. With a project open both are kept in its
  manifest (`link`, `list`; a link's folder may be a path from the
  project's own), so the project refers to its textures and does not
  carry copies; with none, they are kept in the studio's settings.
- **What a game's scenes begin with**: `ed_game <passion|q1|q2|q3>
  <material|build|bake> [value]` sets the material new brushes are made
  of, how levels are lit and how wide a bake's cells are for scenes of
  that game, taken up when one is first shown outside a project and kept
  in the settings; `ed_game` alone lists the four with the folder each is
  read from. `ed_game <game> dir <folder>` says where a game's files are
  (`q1`, `q2`, `q3`, or a pack laid over one, such as `hipnotic`), and
  `ed_game passion dir <folder>` where the folder they are all under is;
  with no folder it is found as before (`QP_ASSETS`, else
  `~/quake-assets`). The folders are kept in `.quakepassion-folders.txt`
  beside the settings, read by the engine when it starts, so the game
  menu looks there too; what is opened next is looked for there. The
  Settings box lists them under Files, each in a field, with whether the
  folder is there.
- **Prefabs within prefabs**: a prefab may hold linked prefabs
  (`misc_prefab` entities) of its own; when a linked prefab is built, or
  unlinked into a copy, the prefabs it holds are put in too, each
  standing on its instance's place, however deep (no deeper than eight,
  and never a prefab inside itself). An instance may differ from its
  prefab: `ed_prefab swap <old> <new>` gives every side of one material
  another, `ed_prefab put <classname|name> <key> <value>` sets a field
  on its entities of that class or name, `ed_prefab names <word>` adds a
  word to every name in it (so two instances of a gadget do not fire
  each other), and `ed_prefab plain` takes those away. They are kept in
  the instance's own fields (`_swap`, `_put`, `_names`), and an
  instance's changes are made after those of the instances inside it.
  An instance is turned and sized where it stands: `ed_prefab turn
  <degrees>` turns it that much further about the upright through its
  origin (its `angle`, which the inspector's angle buttons and the
  handle at its arrow change too), `ed_prefab turn <degrees> pitch` tips
  it nose down and `turn <degrees> roll` rolls it about its length
  (kept, once it is tipped at all, as `angles`: pitch, yaw and roll as
  the games write them, and applied roll first), and `ed_prefab scale
  <times>` or
  `<x> <y> <z>` makes it that many times as large about its origin (its
  `_scale`; a negative size mirrors, nothing is refused). It is sized
  as its file lies and then turned, so `scale 2 1 1` doubles the
  prefab's own length whichever way the instance faces. Its brushes'
  materials stay on their faces, the entities inside go where their
  places are carried and face as much further round, and instances
  inside instances are each turned and sized in their own place first.
  `ed_prefab plain` takes the turn and the size away with the rest.
- **Sounds**: `ed_sound info <file>` says what a WAV file is, and
  `ed_sound convert <file> <name> [rate] [bits] [loud]` makes it what
  the games play (its channels mixed into one, at 22050 samples a second
  and 16 bits unless told otherwise, as loud as it can be without
  clipping with `loud`) and writes it under `QP_SOUNDS`, a project's
  `sounds/` or `./sounds`.
- **Texture sets**: `ed_wal <file.wal|q2:name>` says what a Quake II wall
  texture says of itself (its flags, contents and value, which a
  compiler gives every face that uses it, and the texture that follows
  it in an animation); with `flag <name> on|off`, `flags`, `contents`,
  `value <number>` or `next <name>|none` it writes a copy with those
  changed, its pictures untouched, among the project's textures.
  `ed_frames [material]` lists the frames of an animated texture: a
  Quake `+0name`'s row from its map, or a Quake II texture's chain.
- **Materials that move**: `ed_animate [on|off]` (the Window menu's last
  entry) plays them in the Materials tab. A texture that is one of a row
  shows the row's frames one after another from itself, at its game's
  pace (Quake five a second, Quake II two), and a liquid warps: Quake's
  by the star its name begins with, Quake II's by the warp flag its
  texture carries, each way across the picture pushed by a wave along
  the other, an eighth of the picture at most, as the games draw them.
  Off (as it starts), every picture is the still one again. It is a tool
  in a module of its own (`editor/tools/moving.jac`). Quake III's
  shaders are not played.
- **Shader scripts**: `ed_shader open <file>` opens a Quake III shader
  script from `QP_SHADERS`, a project's `scripts/` or `./scripts` (a
  file that is not there is a new one), and `ed_shader take` takes the
  script the asset explorer is showing, to change a copy of. A script is
  kept as its shaders, each as its own lines and its stages' lines, so
  that what is not understood is still written back. `ed_shader new
  <name>` adds a shader (a picture lit by the level's light), `ed_shader
  pick <name>` takes one in hand, `ed_shader set <key> <value>` and
  `unset <key>` change its own lines (`surfaceparm`, `cull`, `sort`,
  `deformVertexes`, sky and fog lines), and `ed_shader stage add
  [picture]`, `stage <n> set <key> <value>`, `unset <key>`, `drop` and
  `move <to>` its stages (`map`, `animMap`, `blendFunc`, `rgbGen`,
  `alphaGen`, `tcMod`, `tcGen`, `depthFunc`, `alphaFunc`); a line a
  shader may have several of (`surfaceparm`, `tcMod`) is told apart by
  its next word. `ed_shader show` prints the shader in hand as it would
  be written. `ed_shader check` lists in the Checks tab what the game
  would trip on, by line: braces that do not match, names with no
  braces, lines it does not know or that belong to a stage (or to the
  shader), words a line does not take, and stages with no picture.
  `ed_shader save` writes the script, a tab a brace. `ed_shaderbox`
  (Window menu) opens the shader in hand stage by stage: its own lines
  and each stage's lines as fields (Enter changes a line, an empty one
  drops it, the last field of each adds one), with stages added, moved
  up and dropped. `ed_shader preview` draws the shader on a square in the
  explorer's model view as the game draws a model with it: the script is
  read by the game's own shader parser over what the archives hold, its
  stages' pictures loaded, and the engine's model renderer draws them,
  blends, waves, `tcMod`s and all, moving as they move; while the box is
  open the preview is drawn again with every change.
- **The script as text**: `ed_shader text` (the Window menu's last entry)
  opens the whole script in a box of numbered lines that floats over the
  studio. Beside it are what the game would trip on, each at its own line
  (a line it does not know is said where it stands, a stage with no
  picture where the stage opens), the shader in hand in brief (its stages
  by their pictures and how they are laid on), and Check and Save.
  Ctrl+Enter or a click outside the box reads the words again as the
  script; the commands above go on working on what was read, and the box
  shows what they change. Words whose braces or names do not hold
  together are kept as typed with their faults beside them, and the
  script stands as it was until they are mended. `ed_shader write
  <words>` reads words given on the command line, their line breaks as
  `\n`. A new line begins as far in as the line it was begun from.
  Comments are not kept: the script is written from what was read.
- **Entities as their models**: `ed_models` (View menu) draws each
  pickup, monster and fixture in the 3D view as the model its own game's
  rules give it (the engine's own rules are asked: the game is the
  level's, or the entity's `asset_game` in a scene of no one game),
  standing where the entity is and turned the way it faces. Each is
  drawn as the game would spawn it: with the skin its rule names (the
  yellow armour is the green one's model with another skin) at the frame
  it starts on, hidden by walls as anything in the level is; a class the
  game shows as a sprite (Quake's bubbles) is its picture facing the
  eye, clear where the sprite is clear. What is selected has its edges
  over its skin, and `ed_models skins off` draws edges alone, in the
  entity's colour and through the walls like the other overlays.
  `ed_models list` says which model or sprite each entity has, with its
  skin and frame. Pickups that are little maps of their own (Quake's
  health and ammo boxes) keep their boxes.
- **Entities' games**: a scene of the studio's own is no one game's, and
  a pickup, a monster or a fixture in it is spawned by the rules of the
  game named in its `asset_game` field, as in a generated level (without
  one it is not spawned at all). An entity of such a class carries its
  game from the moment it is added (the open project's game when the
  class is that game's too, else the class's first); the field is a
  dropdown in the inspector; `ed_assetgame <q1|q2|q3|none>` sets it on
  the selection and `ed_assetgame fill` gives every entity that lacks one
  its class's. The check lists entities that carry no game, or a game
  that has no such class. So one scene can hold Quake's ogre beside
  Quake III's railgun.
- **Camp spots**: `info_camp` (how far a bot camps from it, how much bots
  want it, how long one stays) and `item_botroam` are classes like any
  other; a ring is drawn in the views at each camp spot's range, and
  `ed_camps` lists them. `ed_camps routes [on|off]` draws the ways bots
  take between them: a `Descend` walker is set down in the area a spot
  stands in and goes out, passage by passage, by whichever leaves the
  least time still to go on the router's own table, until it stands in
  the goal's area. With nothing picked each spot is joined to the next;
  with one thing picked (a player's start, say) the ways run from it to
  every spot. A run is drawn pink, a jump yellow and a drop red; each way
  is printed with its time and its legs by kind, and a spot there is no
  way to is said to be out of reach. The ways are walked again when a
  spot moves. They go over the navigation baked here (`ed_nav bake`), or,
  in a shipped arena, over the arena's own.
- **Fine work on a terrain**: `ed_touch <x> <y> <amount> [variance]`
  moves the corner of the terrain's grid nearest a place and the corners
  that stand with it: those joined to it along the grid within the
  variance of its height (a terrace, a floor, a ridge's top). `ed_plot
  <x> <y> [variance] [add]` picks the plot of cells that adjoin the one
  there at about its height (in sculpt mode, Alt and a press picks the
  plot under the pointer; Shift adds); the plot's edge is drawn along
  the terrain in yellow until it is cleared, to show what the next thing
  will be done to. `ed_plot lift <amount>` moves its corners, `ed_plot
  paint` gives its tops the material in hand, `ed_plot variance <units>`
  sets how far apart in height things may be and still go together, and
  `ed_plot clear` lets it go. `ed_terrain top <amount>` moves every
  height, `ed_terrain bottom <amount>` the underside of the base (the
  top staying where it is), and `ed_terrain both <amount>` the whole of
  it.
- **Linked faces**: `ed_facelink` links the picked faces that lie in one
  plane with the first of them, or, with brushes selected and no faces
  picked, every pair of their sides that lie in one plane facing the same
  way. Linked sides are kept in one plane: pushing one (a side handle, or
  `ed_push`) pushes every side tied to it, through however many links, as
  one step, and not at all if any brush would be left with nothing
  inside. Linked sides share one material too: a material given to one
  of them, by Alt and a drag or by the Faces tools, and a change of how
  it lies (a shift, a turn, a fit), goes to every side tied to it, in the
  same step. `ed_facelink clear` takes the picked faces, or every side of
  the selected brushes, out of their links. `ed_carve link` carves and
  links the faces the cut divided between the pieces it leaves, and
  `ed_glue face link` puts the picked face in the tagged plane and links
  it to what lies there. Links are edges between brushes in the document
  (a side of one to the side of another that lies in its plane); they are
  saved with the map (`_links`) and a brush that is deleted drops out of
  them until it is brought back.
- **Seams and corners**: `ed_miter` (Brush menu) cuts the two selected
  brushes, where they overlap, on the plane that halves the angle
  between them, so that they meet in a seam; `ed_merge <x y z> <x y z>`
  moves a corner of the selected brush onto another of its corners.
- **Dragging from the side panels**: a material's picture, a class or a
  prefab is dragged from its tab and let go in a view; its name follows
  the pointer while it is carried. A material lands on the face under the
  pointer and no other; a class's entity stands where the line of sight
  first meets a brush, a little toward the eye (a brush class stands on
  it); a prefab stands on what it was dropped on. The press that begins
  the drag does what a click does, as before (takes the material in
  hand, adds the entity or the prefab where the camera looks): the drop
  then puts it where it was dropped. In the toolkit a widget offers
  what was pressed (`Stage.offer`), and the stage sends a `drop` event
  to whatever is under the pointer when the button comes up.
- **Dragging within the lists**: a brush's row in the Scene tab is
  carried onto the entity that is to hold it and the brush changes hands
  as one step (with Ctrl, the whole selection): onto the row of an entity
  that holds brushes, onto a brush that entity holds, onto a class's
  heading when the class has one entity, or onto the brushes' heading for
  the world. An entity is not held by another, and is told so. A row
  carried on into a view is put where it is let go, as a class is. In the
  Library tab a favourite is carried onto another to stand before it, or
  onto the Trash row under the favourites to be forgotten (what the press
  added to the scene is taken back), or into a view to stand there. In
  the toolkit a list with `drop` set asks for that word with the row let
  go on and what was carried, also when both are rows of the one list; a
  row marked `fixed` is never carried.
- **The model editor** (the start of it): a model is edited as a graph of
  its parts (each a mesh with skins of its own), each part's poses (where
  its points stand at each frame) and its tags. `ed_model new <kind> [w d
  h] [sides]` makes one from a primitive (`sphere`, `dome`, `cone`,
  `bicone`, `cylinder`, `fan`, `torus`), `ed_model add <kind> ...` adds
  another part, `ed_model edit` takes up the model the explorer is
  showing (MDL, MD2 or MD3), and `ed_model open <file>` reads an OBJ or
  MD3 from disk. The model is drawn in the explorer's model view with a
  panel of its own (frames, undo, check, box, axes and four tools).
  `ed_pick points|faces <numbers|all> [add]`, `ed_pick front|back` (the
  triangles that face the view, or away) and `ed_pick none` choose what
  the tools work on; what is picked is drawn over the model. `ed_mesh
  move <dx dy dz>`, `turn <x|y|z> <degrees>` and `scale <f>` (or `<fx fy
  fz>`) move the picked points at the frame in hand, or at every frame
  with `all`; `ed_mesh mirror <x|y|z>`, `flip`, `subdivide <2|3|4>`,
  `cut <x|y|z> [at]` and `extrude <distance> [bulk]` change the
  triangles, and are carried to every pose alike by a walker, so that
  each frame keeps the same points in the same order. A cut is along the
  plane across an axis, where told or through the middle of what is
  picked: a triangle the plane passes through becomes three (two when it
  goes through a corner), triangles that share a side share the new
  point on it, and where each side is crossed is measured at the frame
  in hand and kept as a share of the side at every other. `ed_model frame copy [name]|drop|name <words>`
  works on the frame in hand (`ed_frame` goes from one to another).
  `ed_model frames` (the List button beside Play) lists every frame
  under the view, a row each: a click goes to that frame, a row dragged
  onto another puts its frame there in the order, and a field and two
  buttons under the list name, copy and drop the frame in hand. A frame
  and its name belong to the whole model, so every part's frames are
  named alike. `ed_pick find points|faces <number>` picks a point or a
  triangle by its number and says where the point stands and which
  triangles it is a corner of, or the triangle's points, area and
  facing. `ed_model part <n>` takes another part in hand, `ed_model check` looks
  for what is wrong (triangles with no area or a corner nowhere, unused
  points, parts with other frames than the first), `ed_model match`
  gives every part the first's frames, and `ed_model undo|redo` undo a
  part's edits whole. `ed_model save <file>` writes, by the file's ending,
  an MD3, an MD2 (the parts as one mesh, with a command list for renderers
  that want one), a Quake MDL (one mesh too, with the skin in hand inside
  it in Quake's own colours, or one grey), an OBJ (the part in hand), a
  glTF (`.glb`: every part as it stands at the frame in hand, a
  primitive each with its points, the ways they face, its places on the
  skin and its triangles, turned so that y is up) or a work file
  (`.qpm`) under `QP_MODELS`, a project's `models/` or
  `./models`, and `ed_model open <file>` reads any of them back (an MDL's
  skin becomes the skin in hand; of a glTF, a `.glb` or a `.gltf` that
  keeps its numbers inside itself, every triangle primitive as a part,
  without following where the file stands its meshes in a scene). The games' files wind triangles the
  other way round from the editor, and are turned on the way in and out;
  they keep points as bytes or sixty-fourths and know nothing of bones,
  so a model's bones go in a `.rig` file beside them. The work file is
  the model as the editor has it, as text: every pose to the last
  decimal, what is picked of each part, the tags, the bones with what
  they carry, and the frame and part in hand, so work is taken up where
  it was left.
  A click in the model's view picks the triangle under the pointer, or
  with `ed_pick mode points` (the panel's last row) the point it passes
  nearest, the nearest to the eye; Shift adds to what is picked, and Ctrl
  and a drag moves the picked points in the plane of the view, as one
  step when the button is let go. `ed_model tag add <name> [x y z]` adds
  a tag (in the middle of what is picked when no place is given),
  `ed_model tag at <name> <x y z> [all]` moves it at the frame in hand or
  at every frame, `ed_model tag turn <name> <x|y|z> <degrees> [all]`
  turns it where it stands (and with it whatever a game hangs from it),
  `ed_model tag drop <name>` drops it and `ed_model tag` lists them; a
  tag goes with its frames when they are copied, dropped or moved. `ed_model frame move <to>` puts the frame in hand elsewhere in
  the order, and `ed_model skin [add <name>|drop <number>]` keeps the
  skins the part in hand names. Not there yet: dragging tags in the
  view.
- **The model's skin**: where each point of the part in hand lies on its
  picture is changed for the picked points (all of them when none are
  picked): `ed_skin move <du dv>`, `scale <f> [fv]` and `turn <degrees>`
  about the middle of their own box, `flip u|v` within it, and `project
  x|y|z [u0 v0 u1 v1]`, which lays them flat by looking along an axis
  into a rectangle of the skin. Each is an edit of the model, undone
  with the rest. `ed_skin new <w> <h> [r g b]` makes a picture to paint
  (`ed_skin open <file.tga>` reads one), `ed_skin colour <r g b>` and
  `ed_skin brush <radius> [soft] [strength]` choose what it is painted
  with (soft is an airbrush, strongest at its middle), `ed_skin dab <u>
  <v>` paints on the skin, and with `ed_pick mode paint` the left button
  in the model's view paints through the model, where the line of sight
  meets the part's skin. `ed_skin show` puts the picture under the
  model in its panel with the part's triangles and picked points drawn
  over it, and `ed_skin save <file.tga>` writes it. `ed_skin pattern
  <solid|checks|stripes|bars|dots> [grain]` has the brush lay its colour
  only where that pattern covers, in squares, rows, columns or discs so
  many texels wide; `ed_skin pick <u> <v>` takes up the colour at a place
  on the skin, as does Alt and a click on the model while painting.
  `ed_model shade textured` draws the model with the picture as it is
  painted. On the skin view itself a click picks the point whose place
  is under the pointer (or, with Click picks triangles, the triangle that
  holds it), Shift adds, and a drag from a picked point carries the
  picked points' places with it, as one edit; what is picked there is
  what is picked in the model, and the other way round. `ed_skin pickat
  <u> <v> [add]` is such a click by numbers.
- **The model in its view**: `ed_model shade <wire|solid|textured>` draws
  the model being edited as its edges, with its faces filled and lit from
  above, or with its skin; `ed_model about <model|origin|view|free>` says
  what the view turns about: the model's middle, its origin, where the
  view looks (Shift and a drag moves that), or the eye itself. What is
  picked has three handles from its middle, one along each axis: a drag
  from a handle's tip moves the picked points along that axis alone, at
  the frame shown. `ed_mesh lock <x|y|z|xy|...|off>` keeps drags off the
  axes named (their handles are drawn faint and cannot be taken), for
  Ctrl and a drag as well. `ed_model marks <cross|box|diamond>` says how
  the marks on points and tags are drawn. `ed_model layout 4` shows the
  model in four views: the one that turns, and flat views from above,
  the front and the side (`layout 1` goes back to one; kept in the
  settings). `ed_model float` opens a floating window over the model's
  views that looks at the model from its own angle: dragged in, it turns
  that window's view alone, and the wheel draws it nearer.
- **Points' own colours**: `ed_mesh colour <rrggbb|none>` gives the
  picked points a colour (undone with the model's other edits), and
  `ed_mesh colours [on|off]` shows them: each point marked in its colour,
  and the faces between them in those colours when the model is drawn
  filled. A tool that makes points gives each the colour of the nearest
  point there was. The games' model files have no place for them, so they
  are written with the bones (`ed_bone save`), a line for each part.
- **The districts' materials** (`ed_district`, Window menu): a generated
  (Passion) level is built of six districts, each with five slots: floor,
  wall, ceiling, trim and accent. What fills them is data now: a table
  in the game (`games/passion/materials.jac`) and, in its place wherever
  it speaks, a text file kept beside the studio's other edits
  (`passion/districts.txt`, or `QP_DISTRICTS`). `ed_district` lists the
  table; `ed_district <n> <slot> [material]` gives a slot another of the
  games' textures (the material in hand when none is named), refusing
  one the archives do not hold; `ed_district <n> name <words>` names a
  district, as its briefing will; `ed_district check` looks every slot
  up and loads the materials the game's own way; `ed_district reset [n]`
  puts one district, or all, back. The numbers levels are made with do
  not move, and a slot whose material cannot be found falls back to the
  built-in one, so the file can never leave a level without a surface.
- **Bodies and weapons put together** (Window menu): `ed_body
  [character] [weapon|none] [legs <sequence>] [torso <sequence>]` shows
  a Quake III body as the game joins it, through the engine's own rig:
  the torso on the legs' `tag_torso`, the head on the torso's `tag_head`
  and a weapon in its hand on `tag_weapon`, at each frame of the legs'
  sequence and the torso's (idle, run, jump, swim, ...; stand, attack,
  gesture, ...). `ed_body list` names the bodies the archives hold.
  `ed_viewweapon <q1|q2|q3> [slot] [out]` shows a game's weapon as it is
  held in view, seen from where the player's eye is (from outside, with
  `out`), at rest and through the frames of a shot; Quake III's rides its
  hand's `tag_weapon`, with its barrel, as it does in play. Either is one
  model in the explorer's model view: its frames are stepped and played
  there, and `ed_model edit` takes it into the model editor.
- **Bones** (`ed_bone`, Window menu): a model being edited may have bones
  to pose it by. `ed_bone add <name> <head> <tail> [parent]` makes one,
  `ed_bone chain <name> <tail>` carries a chain on from the end of the
  bone in hand (`ed_bone pick <name>`, or a click on a bone's end), and
  `ed_bone drop` takes one away, what hung from it hanging from what it
  hung from. A bone carries points of a part, each by a weight from
  nothing to all: `ed_bone auto` gives every point to the bone nearest
  it, `ed_bone hold [weight]` gives the picked points to the bone in
  hand (what other bones carry of them is cut down to what is left of
  one whole), `ed_bone release [all]` lets them go, and `ed_bone
  weights` says what carries each picked point. `ed_bone turn <x|y|z>
  <degrees>` turns the bone about its joint at the frame in hand: what
  it carries goes by its share, and every bone that hangs from it goes
  round whole with what that carries. Dragging the box at a bone's end
  round its joint turns it about the line of sight, in steps of the
  angle snap (Ctrl for single degrees). `ed_bone move` moves a bone and
  what hangs from it, `ed_bone end <head|tail> <at> [all]` puts an end
  elsewhere without moving any point, and `ed_bone tint <rrggbb>` gives
  it a colour. `ed_bone spread <first> <last>` sets the frames between
  two evenly from one to the other, points and bones alike. Turns, moves
  and spreads are undone with the model's other edits. `ed_bone colours`
  shows each point in the colours of the bones that carry it, mixed by
  their shares. The model formats keep no bones, so they are written
  beside the model's file (`<file>.rig`) when it is saved and read back
  when it is opened (`ed_bone save|load [file]` does either alone). Not
  there yet: a panel for the weights, colours kept on the points
  themselves, and bones written into a format that has them.
- **A played game watched**: while a game is played from the studio, what
  fires is counted, by the name it is fired by (or its class and what it
  fires, when it has no name). `ed_fired` says how often each has fired
  and in what order, during the game and after it; back in the studio
  the logic graph marks what fired and how often. `ed_break <name>`
  holds the game still the moment that name fires (`ed_break` lists
  them, `ed_break clear` forgets them; the graph marks them `[holds]`),
  and `ed_trace on` names each firing on screen as it happens.
  `ed_trace graph` (Play menu) draws the scene's logic over the game as
  it runs: a box for each entity that fires or is fired, in the graph's
  columns, with lines to what it fires; a box lights as its name fires
  and fades over a second, keeps a darker tone once it has fired, counts
  its firings, and is outlined red when it holds the game (the engine
  hands a game played from the studio to it to draw over each frame,
  before the console). While a
  game is played, `ed_live` says where the player stands, with what
  health, and how every signal stands; `ed_live player health <n>` and
  `ed_live player at <x y z>` change the player, and `ed_live signal
  <name> on|off` switches a signal, before `ed_pause` lets the game run
  on. The rest of what lives in the game is reached by number: `ed_live
  opponents`, `ed_live doors` and `ed_live pickups` call them over (a
  walker goes out from the world to what it holds of each kind), each
  with where it is and how it stands, and `ed_live opponent <n> health
  <h>` or `at <x y z>`, `ed_live door <n> open|lock|unlock` and `ed_live
  pickup <n> at <x y z>` change one; a door asked to open opens when
  the game goes on. (The engine counts firings on its signals and calls the workbench
  each frame of a game it is not showing; nothing else of it changed.)
- **Sweeps**: `ed_sweep <outline> [wide tall] [count] along <name>`
  carries an outline along a path of entities, from the one of that
  targetname through each one's `target` (a path that comes back to its
  start is a ring), and `ed_sweep <outline> [wide tall] line <x y z> <x y
  z> ... [closed]` along a line of points. The outlines are `square`,
  `round` (of `count` sides), `ridge`, `ell`, `tee`, `channel` and `rail`,
  or `brush`: the selected brush's own outline as seen from the front, at
  its own size unless one is given. Each convex piece of the outline
  leaves a brush along each stretch of the path, and where the path
  turns the stretches are cut on the plane that halves the turn, so they
  meet without a gap or an overlap. The result is a group that keeps what
  it was swept from (`_sweep`, `_along` or `_line`): `ed_sweep again`
  (Brush menu) sweeps the selected sweeps, or all of them, along their
  paths as those now stand, as one step that can be undone.
- **Layers**: every kept set (`ed_keep <name>`) is a layer too, whatever
  owns its members: `ed_layer <name> hide|show` hides or shows what it
  holds as one, `ed_layer <name>` alone toggles it, `ed_layer <name>
  only` shows it and hides every other, `ed_layer all` shows them all
  (as `ed_show` does), and `ed_layer` (View menu, Layers) lists them with
  what each holds, to click. What two layers share stays hidden while
  either is off. A hidden layer is out of the views, of what a click
  finds and of what the views are built from, and in what is built for
  play; the layers that are off are saved with the map (`_layers_off`).
- **Bands of depth**: `ed_depth [top|front|side] <low> <high>` holds an
  axis view to a band of depth, measured along the world axis it looks
  along (z for the top view), `ed_depth <view> selection` takes the band
  from what is selected with eight units to spare, and `ed_depth <view>
  off` lets it go; with no view named it is the one last pointed at. What
  lies wholly outside a view's band is greyed there, left out and no
  longer clicked there, or drawn as ever: `ed_outside grey|hide|whole`
  (kept in the settings; with no word it steps through them). The edges
  of each band are drawn as red lines across the other axis views, each
  with a red knob: dragged, it moves that edge of the band (one step,
  `ed_depth` with the new numbers). The level itself is cut to the band
  in the view held to it (unless `ed_outside whole`): the engine draws
  only what lies between the band's edges, so a floor or a ceiling
  outside it is gone from the picture, not only from the outlines.
- **Oblique views**: Alt and a right drag turns an axis view off its
  axis, and `ed_oblique [top|front|side] <yaw> <pitch>` sets how it looks
  in degrees. A view so turned has no grid; a compass in its corner shows
  the world's three axes as it sees them, and a press on the compass, or
  `ed_oblique <view> off`, straightens it. (View menu: the selection's
  depth, every depth, what is outside, straighten.)
- **Programs outside the studio**: `ed_assoc <ending> "<command line>
  %file%"` keeps a program for files of an ending (`png`, `map`, or `*`
  for any other), `ed_assoc <ending>` alone forgets one and `ed_assoc`
  lists them; they are kept in the settings. `ed_openwith [file]` opens a
  file with the program kept for its ending and leaves it running beside
  the studio: a path, a `file:` material, or with no word the image file
  that is the material in hand (else the scene's own map).
- **Files that change**: the project's image files in use as materials are
  looked at twice a second by the clock, and one changed on disk (saved from an image
  editor) is read again, its picture in the Materials tab drawn again and
  the level built with it, at its new size if that changed. `ed_watch
  off` stops that; `ed_reload` reads them all again and builds the level
  afresh whether or not they changed.
- **The mouse**: `ed_mouse look <rate>` is how fast a right drag turns the
  3D camera (1 unless told), `ed_mouse invert on` turns it up for a drag
  down, `ed_mouse wheel <rate>` is how far a notch of the wheel moves or
  zooms a view and `ed_mouse reverse on` sends it the other way. Kept in
  the settings; `ed_mouse` alone (Window menu) says how it stands.
- **Building**: `ed_build` builds the level again now; `ed_build full`
  lights it finely (a lightmap texel to 16 units), `ed_build quick`
  coarsely (to 32, about a third of the work), and `ed_build flat` not at
  all. The choice is kept between sessions.
- **Groups** have a row of their own in the scene list, under
  `func_group`: the group's name, how many brushes it holds, and its
  brushes under it when it is opened. A group selected alone keeps
  switches of its own, in fields saved with the scene, from buttons in its
  form or by command:
  - how it shows (`ed_group_view <shown|grey|hidden>`): whole; as outlines
    only, out of the level while editing and out of a click's way; or not
    at all. What is played has it either way.
  - `ed_group_lock`: clicks and rectangles in the views pass it by; it is
    still selected from the list.
  - `ed_group_skip`: builds leave it out, when editing and when playing,
    to try part of a level alone.
  - `ed_group_tint <r g b>`: the colour of its outlines.
  `ed_groups` lists the groups with their switches.
- **A material from the tagged face**: `ed_tag` remembers a face;
  `ed_tex wrap` gives the picked faces its material carried round the edge
  they share with it, so it runs on unbroken across the corner, and
  `ed_tex project` lays it on them exactly as it lies on the tagged face.
  `ed_tex minfit` fits a material in whole repeats, as near a texel to a
  unit as that allows. In face mode, Alt and a drag paints the material in
  hand onto each face the pointer passes over (Alt and a click still takes
  a face's material). `ed_glue face` puts the picked face in the tagged
  face's plane, and `ed_tag clear` forgets the tag. The check names sides
  whose material is smeared into a line.
- **Handles on a face for its material** (`ed_texhandles`, Brush menu):
  with one face picked in face mode, a dot stands at the face's middle
  and an arm runs from it along each way the material runs, each a repeat
  of the material long (`s` and `t`). Taking the dot somewhere slides the
  material with it. Taking the end of an arm somewhere stretches the
  material that way and swings that way round, the other staying as it
  was, so the two need not stay square (a shear); swings go in steps of
  the angle snap, so an arm pulled straight out only stretches. With
  Shift an arm turns both ways together and stretches neither. Drags go
  by the grid, or freely with Ctrl, and the handles show in every view.
  `ed_texlay <s axis> <t axis> <s shift> <t shift> <s scale> <t scale>`
  lays the material on the picked faces exactly so, in numbers.
- **By a picked face** (face mode, the face's form and the Brush menu):
  `ed_extrude [depth]` pushes the face out into a brush of its own,
  `ed_cone [height]` stands a cone on it and `ed_walls [depth] [thickness]`
  stands walls round its edge; what is made is left selected.
  `ed_faces next` and `prev` step the pick round the brush's faces.
  `ed_face_delete` takes a face off where the brush's other sides close
  without it, and `ed_face_flip` turns one round to leave what lay beyond
  it, where that is closed too.
- **Side flags**: a face's form shows its contents, surface flags and value
  as the game's own tools number them, to type over;
  `ed_sideflag <contents|flags|value> <number> [set|clear|put]` changes
  bits on the picked faces or on every side of the selected brushes, and
  `ed_detail [on|off]` marks brushes as detail or structural. They are
  written with the map whenever a side has any. A bit goes by its name
  too: `ed_sideflag contents ladder`, `ed_sideflag flags slick off`.
  Quake II and Quake III give the bits different names (bit twenty-nine
  of the contents is a ladder in one and translucent in the other), so
  the names are the scene's own game's; a scene made here is of no one
  game and is read as Quake II's unless told (`ed_sideflag as q3`), and
  `q3:nodrop` says whose name is meant. `ed_sideflag names` lists the
  game's names, and `ed_sideflag` alone says what the picked faces or
  the selected brushes' sides have, by name (a bit the game has no name
  for by its number). Quake's own maps keep no such numbers.
- **Diggers**: `ed_digger` makes the selected brushes a group of holes
  (`_digger 1`). The level is built with them cut out of every brush they
  reach, and with no brush of their own; the document keeps the digger and
  what it cuts whole, so moving the digger moves the hole and
  `ed_digger off` fills it in.
- `ed_inflate <units|up|down>` pushes every side of the selected brushes
  out, or in; a brush that would be left with nothing stays as it is.
- `ed_texlock [on|off|axis]` (Brush menu) says whether materials go with
  the faces a move, turn or stretch carries, or stay where they lie in
  the world while the faces move through them. With `axis` they go with a
  move, but a turn, a stretch or a shear leaves them lying along the
  world's axes. It is kept between sessions.
- A field that would break the map is refused: an `origin` that is not three
  numbers, an empty `classname`.
- **Controls to drag** end an entity's form: its place as three numbers,
  each changed by dragging across it in grid steps (ten at a time with
  Shift); the way it faces, in steps of the angle snap; and for a light,
  its reach on a slider and its colour on red, green and blue bars. Each
  drag is one undoable edit, made when the drag ends. A brush's form ends
  with which handles it shows (Move, Turn, Size).
- **Fields that offer what to type**: an entity's class, and every field
  that names another entity (`target`, `killtarget`) or is the name it is
  fired by (`targetname`), open a list under themselves: the game's
  classes, or the names the map already uses on the other end. Typing
  narrows the list to what begins with or holds the words, the arrows walk
  it, Enter takes the lit row and a click takes the row clicked. What is
  typed need not be on the list: Enter with no row lit sets the words as
  they stand. Escape puts the list away, and again leaves the field.
- **Words of several lines**: `message` is a box three rows tall that
  wraps to its width. Enter begins a line, the arrows go up and down
  keeping how far across the cursor was, the wheel scrolls a long passage,
  and Ctrl+Enter, Tab or a click elsewhere sets it (Escape gives the
  change up). Its line breaks are written into the map as `\n`, the way
  the games read them.
- Buttons that were a character standing for a mark (`<`, `>`, `x`, `+`,
  `...`) draw the mark itself: arrows, a cross, a plus, three dots, and an
  arrow for "select what this fires".
- **Keys of your own**: `ed_bind <key> <command>` gives a key (a letter,
  or `ctrl+` and `shift+` before one) any editor command, ahead of what
  the studio gives it; `ed_unbind` gives it back and `ed_binds` lists
  them. They are held by the engine's own binding system: a keyboard of
  its key nodes for each way Ctrl and Shift are held, so a key goes by
  the name every game's `bind` knows it by (`F5`, `PGUP`, `SPACE`,
  `MOUSE3`, a letter or a digit) and one it does not know is refused.
  The studio's keyboards are its own: no game's bindings are touched,
  and they are kept in the studio's settings.
- **Settings** (Window > Settings, `ed_settings`) lists what is so, each
  line a click to change. The axis views' grid can be hidden
  (`ed_grid hide`), and when shown has the world's numbers along its
  edges. `ed_display solid` shows materials as flat tones in place of
  their textures. `ed_dev` puts frame and build times, how many brushes
  the level was built from, how many entities and light samples there
  are, and how much memory the program holds (asked of the system once a
  second, in the background) in the status bar.
- **Settings by subject**: `ed_settings box` (the Window menu's last
  entry) opens the settings in a box with a subject down its left:
  General, Display, 3D view, Map, Model, Files, Colours. Each row is a
  setting with the values it takes in a list, or a field for a number,
  and its name as a console variable beside it. Files also says where
  settings, scenes and autosaves are kept, and how often a changed scene
  is autosaved (`ed_autosave every <seconds>`, 0 for never). Colours has
  the theme and four of the studio's colours set by hand over it
  (`ed_colour <accent|select|text|panel> <rrggbb|default>`, `ed_colour
  all default` to give them up), each with a patch of what it is now.
- **Settings as console variables**: every setting in the box is also a
  variable (`studio_grid`, `studio_theme`, `studio_view_3d`, ...) that
  says what is so. Typing one with a value in the console, or in a
  config, sets the studio by the same command the box uses; a value it
  does not take is refused and the variable put back. `ed_settings vars
  [word]` prints them. They are one table
  (`editor/document/settingstable.jac`), and they are kept where they
  were: as commands in `studio.cfg`.
- **Several documents** are open at once: the level the game began in and
  every scene made or opened since. `ed_docs` lists them, `ed_doc
  <name|next|prev>` goes to another (its camera is where it was left),
  `ed_save all` saves every one that has been edited and `ed_close` closes
  the one being edited (`ed_close force` when it has unsaved edits); the
  Window menu has them. The
  Library tab ends with what is open now and with the files opened and
  saved lately (`ed_recent`), each a click away.
- **A right click on the selection** opens its menu: look at, duplicate,
  delete, copy, cut, hide, drop, and for brushes group, hollow, carve and
  the owner. A right click elsewhere is still the look or slide button.
- `ed_log [lines]` shows the console's last lines without opening it.
  `ed_log panel [on|off] [rows]` keeps them in sight instead: a panel
  along the foot of the level views (under all four when four are
  showing) that holds the last so many lines as work goes on; `ed_log
  panel up [n]`, `down [n]` and `end` scroll back through what was said
  and return to the newest. Whether it is open, and how tall, is kept
  between sessions.
- **How maps are written**: `ed_mapopts comments off` leaves out the lines
  that number entities and brushes, and `ed_mapopts whole on` writes every
  plane point in whole numbers, for tools that read nothing else. Both are
  kept between sessions.
- **Floating 3D windows** (Window > Another 3D window, `ed_window new
  [outlines]`): a further view of the level in a window of its own over
  the others, up to four of them. Each has its own camera (it starts
  where the first 3D view looks; `ed_window <n> cam <x y z> [yaw pitch]`
  and `ed_window <n> here` put it elsewhere) and its own way of drawing
  (`ed_window <n> outlines|solid`). It is flown, dollied and clicked in
  like the first view: a click selects through its camera, and handles
  are dragged in it. Its bar moves it, the corner at its bottom right
  sizes it, its cross closes it (`ed_window close <n|all>`), and it
  stays within the level views (`ed_window <n> at <x> <y> [w h]`). Its
  foot says where its camera is. A window opened later lies over one
  opened earlier, and nothing of a view is drawn over a window that
  covers it. In the toolkit it is a `Floater`, a layer of its own; the
  engine clears a view that lies over others before drawing it.
- **Long menus**: a menu with more entries than the window is tall goes
  on in further columns under its title, so every entry can be reached
  (the Brush menu, of seventy entries, is three columns on a window 720
  high; it used to run off the bottom). One that fits is as it was.
- **Layouts** (View menu, `ed_layout <1|2|3|4|4b>`): the 3D view alone;
  beside the plan; beside the plan and the front view; all four in a
  square; or the 3D view beside the three axis views in a column. The
  layout is kept between sessions.
- **Colours, bars and windows that are kept**: `ed_theme light` gives the
  studio light panels and dark words for a bright room, `ed_theme dark`
  its own again. `ed_bar tools hide` and `ed_bar status hide` take the
  row of tools and the status bar away (`show` brings them back), and
  `ed_bar tools below` puts the tools under the views. The floating 3D
  windows are opened again in the next session where they were, at the
  size they were and looking where they looked. All of it is in the
  Window menu and kept between sessions.
- **A dialog to build a shape**: Build a shape... in the Brush menu
  (`ed_shapebox`) opens a window that floats over the views with the
  kind of shape in a dropdown and its width, depth, height, count and
  thickness in fields (Tab goes from one to the next); its button builds
  the shape where the camera looks. The window is moved by its bar, and
  where it was left, whether it was open and what its fields held are
  kept between sessions.
- **A path as a whole** (`editor/tools/paths.jac`): from any corner of a
  path, `ed_path` picks every corner it leads to and is led to from (a
  train that rides it too), and `ed_path move <dx> <dy> <dz>` moves them
  all together as one step.
- **Tabs for the open documents**: with more than one document open,
  each has a tab beside the menu bar (a star when it has changes not
  saved; the one shown is lit): the maps and scenes, the model being
  edited, and the shader script. A click goes to it (`ed_tab
  <doc:game/name|model|shader>`), and the x at the end closes the one
  shown.
- **What the move arrows run along**: `ed_axes world|local|view` (alone,
  it goes to the next; it is in Settings > General and kept between
  sessions). Local is the selection's own: one brush's axes from its
  sides, so a wall turned thirty degrees is pushed along itself, or the
  way one entity faces; anything else has the world's. View is across,
  into and up the view. A move along an arrow goes in grid steps along
  that arrow. `ed_axes lock <x|y|z|off>` keeps a selection dragged by
  hand to one of those axes. The rings that turn and the boxes that size
  go by the same axes: a brush turned thirty degrees is turned about its
  own upright and stretched along its own length, and stays square. (A
  change about ways that are not the world's is carried out as the change
  itself, `ed_linear` with its nine numbers.)
- **Scripts: walkers of a project's own**: a project keeps Jac scripts in
  its `scripts/` folder (`ed_script new <file> [walker]` writes one to
  begin from, `ed_script` lists them with their walkers and what they
  are attached to). The studio is one native program and takes no new
  code in: a script is run by the `jac` toolchain in a process of its
  own (`ed_script jac <command>` says which), on the level made into a
  graph, and all it can do is ask.
  - *What a script may touch* is `qp.jac`, written beside the scripts
    (the studio carries it; `editor/userland/qp.jac` is its source): a
    `Level` that `Holds` a `Thing` for every entity, with its number,
    class and fields, and a `Fires` edge wherever one's `target` is
    another's `targetname`. A walker is set down on the thing it is
    attached to, or on the level, and walks. What it may ask is five
    things and no more: `thing.put(key, value)` to set a field,
    `thing.fire()`, `thing.pick()`, `level.say(words)` and
    `level.add(classname, origin, fields)`. The studio reads those back
    as lines and does them with its own commands, each undoable; a line
    of any other kind is not read. (A script is a program on the
    machine all the same: what keeps it from the studio is that it runs
    outside it, not that the machine is closed to it.)
  - *Run*: `ed_script run <file> <walker> [words]` sets a walker down on
    the level, which makes a command of it; `ed_script attach <file>
    <walker>` attaches one to the selected entities (a field,
    `_walker`), and `ed_script go` runs those attached to the selection
    or, with nothing selected, all of them.
  - *As behaviour*: in a game played from the studio, when an entity
    that has a walker fires, the walker is run in the background on the
    level as it stands with the event `fired`, and what it asks to fire
    or say is done when it finishes, a moment later.
  - *Edited with the compiler beside it*: `ed_script edit <file>` opens
    the script in a box of numbered lines. Saving (Ctrl+Enter, or a
    click outside the words) writes the file and asks the compiler
    (`jac check`): its faults are listed beside the words by line, or
    the walkers the script has. Nothing is restarted: the next run, and
    the next firing, use the script as saved.
  - *Classes declared in code*: a `node` of a script that derives from
    `Thing` is an entity class: its `has` fields are the class's fields
    (numbers and text told apart, with what they begin as) and the doc
    string before it is its help. They are gathered on every save into
    an add-on the studio loads, so they are in the Classes tab and the
    inspector at once.
- **An expedition as graphs, its roster, and a room's own materials**:
  `ed_exp graphs` opens a box of bars to drag: how full the expedition
  is, what it aims at on each of its four measures (loops, height,
  density, size, with what it measures beside), and every room's
  tension in the order the rooms are come to. A bar let go makes that
  part again and proves it (`ed_exp density`, `ed_exp tension <room>`,
  and `ed_exp niche <measure> <0..1>`, which surveys the seed again for
  the niche asked). `ed_exp roster <classes>|all` says which foes the
  rooms are filled from, `ed_exp budget route <threat|auto>` fills every
  room along the way the mission means to be taken, and `ed_exp slot
  <room> <floor|wall|ceiling|trim|accent> <material|auto>` gives one
  room a material of its own in place of its district's, kept when the
  expedition is made again. (Tools' boxes can hold bars: a tool gives
  each a name, a value and the command to run with the new one.)
- **A playtest of an authored scene**: `ed_playtest` (the Window menu's
  last entry) says whether a scene of brushes can be finished. It asks
  the scene's logic first (what can never be set off, a lock with no
  key), then goes down the level's objectives in the order a player
  comes to them (the keys, then the buttons and the triggers that fire
  something, then the way out) and says the first that cannot be reached
  from the player's start over the baked floors; a thing on a wall is
  come to from beside it. The floors are walked with what moves (doors,
  platforms, buttons) left out, as if every door stood open (`ed_nav
  bake [cell] open`): whether a door can be opened is the logic's to
  say, and whether what is behind it can be walked to is the floors'. What stops the level is listed in the Checks
  tab, a click from being looked at. `ed_playtest bake` walks the floors
  again as they are built now. An opened expedition has its way out as
  an entity (`trigger_changelevel`, where the generator's own exit
  volume is), so it is seen, kept in the map, and played to.
- **Passion expeditions**: `ed_exp open <seed>` runs the generator on a
  seed and opens what it made as a document of brushes, saved among the
  scenes as `expedition_<seed>.map`: its entities as they are, and the
  world's brushes handed to a group for every room (`room 7 arena`, named
  for its beat and its recipe) and one for the ways between, so a room is
  picked, hidden, locked or copied into another scene as one thing. The
  expedition's own account of itself is kept beside the document:
  `ed_exp` says its seed, archetype and sizes, `ed_exp mission` its beats
  and the links between them with what each needs, `ed_exp rooms` its
  rooms and `ed_exp ways` the ways between them, `ed_exp proof` runs the
  generator's own playtest (whether the exit is reached, in how many
  rounds, with which tokens), and `ed_exp show` draws the ways over the
  level, each in the colour of its kind (open, locked, one-way, shortcut,
  secret). It is a tool in a module of its own
  (`editor/tools/expedition.jac`); it reads the generator's graph (beats
  and links, rooms and passages) as the generator left it.
- **Parts of an expedition made again**: the tool runs the generator's
  own stages again from where something changed, proves the result with
  its playtest, and opens it in place of the document; one that cannot
  be made or proved is refused and the expedition stays as it was.
  `ed_exp again rooms` rolls the dice again for every room's inside
  except those whose group is locked in the scene list, and a locked
  room's group is kept as it was left, hand edits and all; `again
  population` rolls who and what is in the rooms; `again layout` where
  the rooms lie and the ways between them. `ed_exp fill <room>
  <recipe|any>` asks a room for one of the eleven recipes (hall, court,
  cavern, pit, arena ...), `ed_exp district <room> <n>` gives it a
  district's materials, `ed_exp tension <room> <0..1>` and `ed_exp
  budget <room> <threat|auto>` say how hard it is to be, `ed_exp density
  <0.15..1>` how full the whole is, and `ed_exp niche` prints what the
  expedition aimed at beside what it measures, what was put in it, and
  each room's tension as a bar. A room is a group of plain brushes:
  picked and copied into any scene, it is edited by hand there. (The
  generator gained three things a room may be asked: a recipe, another
  roll of its own dice, and a budget.)
- **An expedition's mission changed by hand**: the mission is the
  generator's own graph of beats and the links between them, and the tool
  changes that graph. `ed_exp link <beat> <beat> [mode] [tokens]` adds a
  link (open, valve, locked, shortcut, secret, window or gate, with the
  tokens it needs), `ed_exp unlink <link>` takes one away, `ed_exp mode
  <link> <mode> [tokens]` changes one, `ed_exp grant|ungrant <beat>
  <token>` says what a beat gives, `ed_exp beat <from beat> [kind]
  [size]` adds a beat reached from another, and `ed_exp pattern <name>
  <beat> <beat>` lays one of the generator's cycle patterns between two
  beats (alternatives, lock_key, far_key, shortcut, hidden, foreshadow,
  switch, gambit) and opens its arcs out into rooms. After every change
  the generator's proof is run on the mission (every token granted, the
  goal reached, no corner it can be played into, every beat reached) and
  what it finds is said in its own words ("Mission needs an ungranted
  token: key_blue"); a mission that is sound is laid out again, carved,
  filled and played through by the generator's playtest. A change that
  fails any of it is given up, and the expedition is as it was.
- **An expedition's layout changed by hand**: `ed_exp move <room> <dx>
  <dy>` puts a room elsewhere on the site and `ed_exp size <room> <w>
  <h>` makes it another size (both in shares of the site, five cells of
  32 units each way); `ed_exp floor <room> <height|auto>` says how high
  its floor is to be; `ed_exp reroute` rolls the routing again with the
  rooms where they are. Each lays the site out again with every room
  where it is said to be (the generator's new `relay`), routes every way
  between them afresh, solves the floors again so that every way can be
  walked, and then carves, fills and proves as before. A room laid over
  another, a size no room can be, or a way that cannot be routed is
  refused, and the site is as it was.
- **Groups in groups**: `ed_nest <group's name|#number>` puts the selected
  groups in another group, and a group's row dragged onto another group's
  row in the scene list does the same; `ed_nest out`, or its row dragged
  onto the groups' heading, takes it out again, and `ed_nest` alone lists
  what is in what. A group that holds groups is picked, moved, turned,
  copied, hidden and deleted with them (a click on it picks them all; a
  group inside can still be picked alone), its row opens to show its
  brushes and then its groups, and F2 names the group itself. A copy of
  a group and what it holds is a group of its own. In the document it is
  an edge from each group to the one that holds it, drawn from two
  fields the map keeps (`_group_id`, `_group_in`), so a walker gathers
  everything a group holds; no group can be put in itself or in one it
  holds.
- **Prefabs in folders**: a prefab's name may say folders (`ed_prefab save
  props/crate`), and the Library tab lists each folder of prefabs as a
  heading that opens and shuts, with how many it holds. `ed_prefab move
  <name> <new name>` gives one another name or folder; a prefab's row
  dragged onto a folder, onto a prefab in one, or onto Prefabs itself is
  moved there. A name never leads out of the shelf.
- **Finding in the Library, and a prefab seen before it is placed**: the
  field at the foot of the Library tab (`ed_libfind <words>`) lists only
  the scenes, prefabs and autosaves whose names hold the words, flat
  under their shelves whatever folder they are in. A prefab the pointer
  rests on is sketched above the field: its brushes' edges seen from
  above one corner, in the studio's highlight colour; it stays until the
  pointer is on another.
- **One library of everything**: below the scenes, prefabs and
  favourites, the Library tab has the scene's game's pieces of logic
  (Logic: a click adds one, as `ed_logic` does) and, for what the find
  field asks for, materials (those the Materials tab and its shelf show,
  those lately in hand and those the scene is made of), models and
  sounds from every installed game's archives (forty of each at most). A
  click on a material takes it in hand, on a model or a sound shows it in
  the explorer. Under the pointer a model is sketched as its first
  frame's edges, a sound drawn as its shape (each column its quietest to
  its loudest sample) and a material shown as its picture, where a
  prefab's sketch goes.
- **A field's file chosen from the game's own**: a field that names a
  sound or a model (`noise`, `music`, `model`, `model2`) has a `...`
  button beside it in the inspector, set or not: it opens a list of that
  game's sounds or models, as the field would name them, that is typed in
  to find one (`ed_pickfile <field>`); Enter sets it on the selection.
- **Help where the pointer is**: a control's hint is shown beside the
  pointer once it has rested there most of a second, as well as in the
  bar at the foot (`ed_flyover off` keeps it to the bar; the level views
  and the logic sheet never fly theirs). F1 (`ed_help`) opens a sheet
  with the hint of what the pointer is on and the usage and description
  of the command it asks for; `ed_help <command>` looks one up by name,
  and `ed_help doc` opens this book in the program kept for such files.
  Tab goes from one field to the next and Shift+Tab back, round those
  that are showing. F2 (`ed_rename`) puts a field over the selected
  entity's row of the scene list to type its name in (a group's own
  name, or the name it is fired by): Enter keeps it, Esc leaves it as it
  was, and `ed_rename <name>` says it outright.
- **Sharing the room among the views**: a bar lies between the level
  views where there was a gap, and is dragged to give the views on one
  side of it more of the room; `ed_split x <percent>` and `ed_split y
  <percent>` say the left views' share of the width and the upper views'
  of the height, and `ed_split even` halves it again. `ed_sides swap`
  (or `left`, `right`) has the scene list and the inspector change
  sides. `ed_layout save <name>` keeps the layout as it stands (how many
  views, the split, the sides, the log panel) and `ed_layout load <name>`
  brings it back; `ed_layout list` and `ed_layout drop <name>` list and
  forget them. All of it is kept between sessions. In the toolkit a
  `Sash` between two widgets of a box asks for its command with how far
  along the box the pointer is, and the owner shares the room out by the
  widgets' weights.
- **The ruler**: with something selected, each axis view shows how far the
  selection runs across it and up it, along its edges (`ed_ruler`).
  **Zoom**: the wheel, `=` and `-` over an axis view (twice as near or as
  far; the 3D camera moves instead), and `ed_zoom <units>` sets how many
  units fit the axis views' height. **Names** (`ed_names`) puts every
  entity's name over it, not only the selection's.
- **Remembered views**: `ed_mark [name]` keeps where the 3D camera stands,
  in the document; `ed_goto <name|next|prev>` goes back, `ed_marks` lists
  them and `ed_unmark <name>` forgets one.
- **A backdrop**: `ed_backdrop <file> [top|front|side] [across up]
  [units per pixel] [alpha]` lays a PNG, JPEG or TGA picture behind an axis
  view, to draw a level over a sketch or a map; the document remembers it
  (`ed_backdrop off` takes it away).
- **Round the selection**: Alt with the look button swings the 3D camera
  round what is selected, at the distance it stands (`ed_swing <yaw>
  <pitch>`); `ed_behind` takes it behind the picked face, looking at the
  face's back.
- **The grid** moves and resizes snap to is 8 units to begin with; `[` and
  `]` halve and double it (`ed_grid <size|up|down>`), and the axis views
  draw it.
- **Hiding**: H puts the selection out of sight while editing, Ctrl+H
  everything else, and Shift+H brings it all back (`ed_hide [others]`,
  `ed_show`). What is hidden is not drawn, picked or built into the level
  being edited, but it is saved and it is played.
- **Remembered views**: View > Remember this view (`ed_mark [name]`) keeps
  where the camera is in the document; `ed_goto <name|next>` returns to it.
  View > Look at everything frames the whole level.
- **End** lets the selection down onto what is beneath it (`ed_drop`).
- **The palette** (Ctrl+P, File > Run a command): a line to type into with
  every studio command that matches listed beneath, best first. Enter runs
  the one that is lit, or what was typed when it has words after the
  command; Tab takes the lit command's name ready for its words.
- A selected entity shows the way it faces as an arrow, a selected light
  how far it reaches as rings, and what it `killtarget`s in red.
- **History** (Edit > History, `ed_history`) lists the last edits, newest
  first; choosing one undoes it and everything after it.
  The list goes forward as well: under the edits made are those undone,
  and choosing one does it and all before it again (`ed_history redo
  <steps>`). `ed_history list` says both lists, the edits made oldest
  first.
- **Autosave**: a scene that has changed is written every half minute to
  `autosave/` beside the saved scenes, and the Library tab lists those
  files to open after a crash.

### Scenes of brushes

File > New scene (`ed_scene <name>`) starts a scene of its own geometry: a
floor and a player start. `ed_open <file.map>` opens a map file as one.

- **Box** (B, `ed_box [w d h]`) adds a box brush where the camera looks,
  resting on what is beneath it. A click selects a brush; dragging it moves
  it as seen; with one brush selected, the squares on its sides push that
  side (`ed_push <side> <distance>`).
- The Brush menu also adds a cylinder (`ed_cylinder [w d h sides]`) and a
  wedge (`ed_wedge [w d h]`), turns the selection a quarter about its middle
  (R, `ed_rotate [degrees]`; materials turn with their faces), and
  `ed_clip <x|y|z> <coordinate> [back|front|both]` cuts the selected brushes
  along a plane.
- **Shapes** (`ed_shape <cone|pyramid|ball|dome|stairs|spiral|arch|pipe> [w d
  h] [count] [thickness]`): a cone, a pyramid, a ball or a dome is one brush;
  stairs, spiral stairs, an arch and a pipe are several, held as a group.
- **More shapes**: `bicone` (two cones base to base), `torus` (a ring of
  blocks), `xtree` (thin walls crossed at the middle, as a tree is
  faked), `cap` (the half disc an arch leaves open, filled), `corner` (a
  rounded corner, in wedges) and `bevel` (one wedge of it), `column` (a
  shaft between a foot and a head) and `landing` (stairs that go up one
  side to a landing and come back up the other).
- **A fan** (`ed_shape fan <w d h> [count]`): wedges round the middle of
  its box, each a brush of its own from the middle to the rim: a round
  floor cut like a cake, each slice to raise or texture alone.
- **Every shape keeps its numbers**, one brush (a cone, a ball) as much as
  many, as a group with a
  `_shape` field: `ed_reshape <w d h> [count] [thickness]` builds it again
  from other numbers where it stands, as one undoable step, and
  `ed_shape free` leaves it as the plain brushes it is made of.
- **Caulk**: `ed_caulk [material]` gives the faces the selected brushes
  cover of each other a material that is not drawn (a step's back against
  the next step, a ring's blocks against each other); `ed_autocaulk on`
  builds every shape that way from the start.
- **Light**: a scene with `light` entities is lit from them when it is
  built: a lightmap on every face of the world, a sample every 16 units,
  shadows cast by the world's brushes, and doors lit where they stand. A
  light's `light` is its reach and `_color` its colour; moving one builds
  the level again. Where no light reaches, the world's `_minlight` (a
  quarter of full when it names none) keeps the level readable. `ed_light off` (View > Flat light) shows the flat shade
  a scene without lights has. While lights alone are dragged the level
  is lit, coarsely and a few times a second, as they would be left, and
  lit finely again where the drag ends. A light with a `target` that names an
  entity, or with a `mangle` (yaw, pitch and roll), is a spotlight: it
  lights only what lies within `_cone` degrees of the way it points (20
  when it does not say), and half lights a rim of four degrees about the
  cone's edge, as Quake II's and Quake III's light tools have it.
- More in the Brush menu: turn about x or y (`ed_rotate 90 x`), mirror
  (`ed_mirror <x|y|z>`), stretch (`ed_resize <fx> [fy fz]`), carve the
  selection out of every brush it reaches (`ed_carve`), keep what the
  selected brushes share (`ed_intersect`), hollow them into walls
  (`ed_hollow [thickness]`) and merge brushes that together are convex
  (`ed_merge`). Materials stay where they were on their faces through all of
  these.
- **Faces** (2, or the toolbar): a click picks one face of a brush, Ctrl
  adds another. The inspector then shows the face's material, shift, scale
  and angle as fields, with buttons to nudge and turn it, fit the texture
  to the face, lay it flat in the face's own plane or reset it (`ed_tex
  <shift|shiftto|scale|turn|turnto|fit|flat|reset>`). Alt+click takes the
  material under the pointer for new brushes and faces (`ed_pickmat`).
- **Corners** (3): the selected brush shows its corners and the middles of
  its edges; dragging one moves it in the plane that faces the camera and
  the brush is rebuilt round its corners (`ed_corner`). A move that would
  leave the brush flat is refused. With `ed_corner lock on` a corner that
  is moved takes with it the corners of every other brush that stand at
  the same point, as one step, so corners that are shared stay shared; if
  that would leave any of those brushes flat, none is moved.
- The inspector shows a brush's material (`ed_material <name>`), size and
  owner, and hands the selected brushes to a new entity (`ed_tie
  func_door`) or back to the world.
- The Materials tab lists the games' textures by where they live: a Quake
  map (`q1:e1m1/tech04_1`), a Quake II folder (`q2:e1u1/metal3_2`), a Quake
  III folder (`q3:textures/base_wall/concrete`), and first of all the ones
  the scene uses. A click on a group shows its textures as pictures; a click
  on a picture gives that material to the selected faces or brushes and to
  new ones. A project's own images are materials too: PNG, TGA and JPEG
  files under `QP_TEXTURES` (default `./textures`) are listed as "your
  files" and named `file:<path>`. Any other name is a swatch: a colour from
  the name with a line every 64 units and a fainter one every 16.
- The Checks tab (`ed_check`) lists what would stop the map playing or is
  likely a mistake: no player start, a target nothing is named, an origin
  that is not three numbers, a brush entity without brushes, a brush that
  encloses nothing, is thinner than a unit or has corners off the grid. A
  click on a finding selects what it is about. It also names an entity of
  a class the level's game does not have (a railgun in Quake), one of a
  class no game's levels use and no add-on names (a misspelling), and a
  sound or a model an entity's fields name that no archive of its game
  holds (`noise`, Quake III's `music`, `model` and `model2`, each found
  by its game's own rule for where such files are kept). In a scene of
  the studio's own each entity is asked of the game it carries. A shipped
  Quake III level's `misc_model`s are not asked for: the level compiler
  built them in and their files were left out. The class table lists
  every class the three games' own levels use (237 classes), with the
  fields those levels give them, so the Classes tab offers them all.
- Every edit that changes the brushes rebuilds the level at once, so the
  level view is what Play runs. Save writes the scene as a Valve 220 `.map`
  under `QP_SCENES` (default `./scenes`), which other Quake editors open.

- **Copy and paste** (Ctrl+C, Ctrl+X, Ctrl+V): the selection is copied as
  map text, which other Quake editors read and write, and pasted where the
  camera looks (`ed_paste here`) or beside the original (`ed_paste`).
  `ed_import <file.map> [group]` adds a whole map file.
- **Groups** (Ctrl+G, `ed_group [name]`): the selected brushes are held
  together as one `func_group`, which is picked, moved and duplicated as
  one and stays part of the world when the level is built.
- **Prefabs** (the Library tab): the selection is kept as a prefab by name
  (`ed_prefab save <name>`, a map file under `QP_PREFABS`, default
  `./prefabs`); a click on a prefab adds a copy where the camera looks
  (`ed_prefab add`); `ed_prefab link <name>` places a linked one, a single
  `misc_prefab` entity that is built as the file's contents wherever it
  stands, and `ed_prefab unlink` turns linked ones into copies. The tab
  also lists the saved scenes; a click opens one.
- **The logic graph** (L, View > Logic graph, `ed_layout logic`): every
  entity that fires or is fired, in columns by how far from a source it is,
  with an arrow for each `target`. A click selects, a double click looks at
  the entity, and a drag from one box to another makes the first fire the
  second (`ed_link <from> <to>`: the second gets a targetname when it has
  none). Selected entities stand in the first column, so two things picked
  in the level can be linked here. The check reports entities that set
  themselves off through what they fire.

- **Terrain** (Brush > Terrain, `ed_terrain [cols rows cell]`): a grid of
  cells where the camera looks, built as two prisms a cell over a base and
  held as a group whose heights are in its fields. In Sculpt mode (4) a drag
  over it raises it under an orange ring the width of the brush; Shift
  lowers and Ctrl smooths (`ed_sculpt <raise|lower|smooth|flatten|noise>
  [radius] [amount]`, `ed_brush <radius> <amount>`). Only the cells a stroke
  touches are built again, and each stroke undoes. `ed_terrain export
  <file.pgm>` writes the heights as a grey image and `ed_terrain import`
  reads one back. Its faces take materials like any others.
- **More for patches**: `ed_patch endcap` is half a pipe standing upright.
  The selected patch takes another curve across it or up it
  (`ed_patch grow <u|v>`, the new points carrying on as the last were
  going) and gives one up (`ed_patch shrink <u|v>`); `ed_patch thick
  <units>` changes how thick it is built and `ed_patch fine <n>` how many
  prisms a curve it is built of. Each is one undoable step.
  `ed_patch preview [on|off|<subdivision>]` draws over every patch what
  the games would make of it, worked out by the engine's own code: in
  blue the triangles Quake III's renderer tessellates it into
  (`engine/formats/q3/curve.jac`, at that `r_subdivisions`; 4 unless
  told, smaller is finer) and in magenta the lattice its collision is
  traced against (`engine/physics/patch_collide.jac`).
- **A patch's material by its control points**: `ed_patch uv` says where
  each control point of the selected patch lies on its material, in
  texels, and where its built faces have the material at its first corner
  and its last. `ed_patch uv fit [across] [up]` spreads the material over
  the patch in so many repeats (Brush > Spread the material over the
  selected patch); `ed_patch uv project` lays it as it lies on the tagged
  face, each point taking the place the face's material would have there
  (Brush > Lay the tagged face's material on the selected patch).
  `ed_patch uv point <column> <row> <s> <t>` puts one point somewhere
  else, `ed_patch uv row|col <n> <ds> <dt>` slides a row or a column of
  them and `ed_patch uv all <ds> <dt>` all of them; `ed_patch uv clear`
  forgets them, and the faces lie plainly again. The places bend between
  the control points as the surface does, are kept in the scene (`_st`)
  through every bend and move, and are let go when the patch takes
  another grid of points. Each is one undoable step. `ed_patchbox` (Brush
  > The patch's material...) opens a box with the selected patch's
  material and its control points' places drawn over it, in a grid as
  the points stand: a place is dragged there in whole texels, and fields
  take a point's place, a row's or a column's slide, or the whole
  surface's, by numbers (each is the `ed_patch uv` command it says).
- **More for terrain**: `ed_sculpt erode` wears down what stands above its
  lowest neighbour, and `ed_sculpt paint` gives the tops under the brush
  the material in hand. `ed_terrain lift <x0> <y0> <x1> <y1> <amount>
  [falloff]` raises (or lowers) every corner inside a rectangle, and
  those within the falloff of it by less the farther out they are; the
  falloff is so many units, or with a `%` after it that share of the
  rectangle's shorter side. `ed_brush rect on [falloff]` makes the brush
  a rectangle: in sculpt mode a drag draws one on the terrain (and how
  far its falloff reaches), and letting go lifts it by the brush's
  amount, or lowers it with Shift; `ed_brush rect off` is the round
  brush again. In face mode Alt and a drag paints the material in hand
  onto each top the pointer passes over.
  `ed_terrain pattern <same|alt|other>` splits the cells along the other
  diagonal, or along each in turn so ridges run either way.
  `ed_terrain free` leaves the terrain as the plain brushes it is made of.
- **Clip** (5): a line drawn across any view cuts the selected brushes
  along it, in the plane the line and the view's line of sight make; Shift
  keeps only what is behind the line and Ctrl only what is in front
  (`ed_clip_line`). **Draw** (6): a rectangle dragged in an axis view
  becomes a box on the grid, sixty-four units deep (`ed_box_draw`). In
  the 3D view the drag is taken on the level the box would stand on (the
  height of the selection's middle, or of the origin, on the grid): the
  box stands there, sixty-four high, and a drag that leaves that level
  (into the sky) makes nothing.
- **Settings** are kept between sessions beside the entity overrides
  (`studio.cfg`): the grid, one view or four, how views are drawn, the
  light and the sculpting brush.
- **Tab** steps to the next entity and Shift+Tab to the one before
  (`ed_step`); Edit > Freeze the selection (`ed_freeze`) keeps clicks in the
  level from changing it. The status bar says how long the level last took
  to build. The explorer's search field lists every file, in every game,
  whose name holds what is typed (`ed_assetfind`). The check also reports
  materials named as a game's that no archive holds, and `ed_stats <file>`
  writes the names of the materials in use.
- **Faces put right** (Brush menu): `ed_integral [grid]` lays the picked
  faces through whole points again (each face's corners are put on the
  grid and the face goes through them), or every face of the selected
  brushes when none is picked: for planes that have drifted a hair off
  whole numbers. `ed_faceangle [degrees]` tilts the picked faces to
  whole steps of heading and of slope (the angle snap, unless told),
  each about the middle of its own outline. Both leave the material as
  it lay, are one undoable step a brush, and refuse what would leave a
  brush with no inside.
- **Materials found and lately used**: `ed_matfind <text>` looks through
  every game's materials (and the project's own files) for names that
  hold the text and shows what it finds as a shelf of its own in the
  Materials tab, after the games' groups. Materials taken in hand are
  kept, the latest first, as a "recently used" shelf beside it
  (`ed_shelf recent`; `ed_material recent` lists them).
- **A folder out of an archive**: `ed_extract folder <game>:<folder> [to]`
  writes every file under a folder of a game's archives, as the
  explorer's Extract button writes one.
- **Tags dragged, weights in a dialog, skins imported** (model editor):
  with Alt, a press on a tag in the model's view takes hold of it and a
  drag moves it in the plane of the view, at the frame in hand (with
  Shift at every frame); `ed_model tag` says where each tag is seen.
  `ed_weights` opens a window with the bone in hand in a dropdown, a
  field for the weight it takes of the picked points, buttons to take
  them whole, let them go and show the bones' colours, and what carries
  each picked point. `ed_skin import <game>:<file> [n]` takes a picture
  out of a game's archives as the skin to paint on: a PCX, a WAL, a plain
  TGA, or the n-th skin a Quake model carries inside it.
- **A starter project** (`editor/tools/starter.jac`): `ed_starter [name]`
  (the last entry of the File menu) makes a project with one scene in it,
  a lit room with walls, a crate, a pillar and a player's start, saves it
  and makes it the scene the project opens on, so that Play has something
  to play the first time. A project of that name that is there already
  is left as it is.
- **Makers** (`editor/tools/makers.jac`, built in
  `editor/document/generate.jac`): a group whose brushes stay in the
  document as they are and are built as something made from them, as a
  digger's are cut out. `ed_maker hollow <thickness>` builds each as a
  shell of walls, `ed_maker walls <thickness>` as its upright walls
  alone (a room open above and below), and `ed_maker arch <count>
  [thickness]` as an arch of so many blocks spanning its box; `ed_maker
  off` builds them plain again and `ed_maker` lists the makers. Selected
  brushes that are in no group are made one. Move or size the brush and
  what is built follows; a digger cuts through a made wall as through
  any other.
- **A project packed to give away** (`editor/tools/packer.jac`):
  `ed_pack project <out.pak|out.pk3>` packs the open project's scenes
  and, of everything else, only what they use: the prefabs they link
  (and what those use), the files their materials' pictures are in
  (Quake II's WALs, Quake III's TGAs and JPEGs, the project's own image
  files), and the sounds and models their entities name. What a scene
  uses that is not found is named, and counted.
- **Pictures written as the games' own textures**
  (`editor/tools/textures.jac`): `ed_texwal <material> [name]` writes a
  material's picture as a Quake II WAL among the project's textures, and
  `ed_texwad <out.wad> <material ...|used>` writes several, or every one
  the scene uses, as a Quake WAD. Each keeps the picture at four sizes
  and in the game's own 256 colours, every texel the nearest of them. Any
  material's picture will do: a game's texture, or an image file of the
  project's (PNG, JPEG and packed TGA are read as the window reads them).
  A picture whose sides are not whole sixteens is refused, and says so.
  BMP and PCX files in the project's textures folder are materials too
  now, beside PNG, TGA and JPEG.
- **Sprites and films in the explorer**: a Quake sprite (`.spr`) and a
  Quake II sprite (`.sp2`, whose frames are PCX files) show their
  pictures, and a Quake II cinematic (`.cin`) and a Quake III film
  (`.RoQ`) show theirs as the engine's own decoders read them. The frame
  buttons and `ed_frame next|prev|play|stop|<n>` step and play them as
  they do a model's frames: a sprite's go round, a film is read forward
  at its own pace and stops at its end. A film played has its sound
  played with it, through the engine's cinematic sound channel (the one
  the games play their cinematics' sound through), and stopped with it.
- **The project's own files in the explorer**: with a project open, its
  folder is listed under Your project beside the games', read from disk
  as it is; its files are shown as any other (an image in its textures
  folder says the material it is). A file or a folder of a game's
  archives dragged onto Your project, or onto anything in it, is copied
  into the project under `files/<game>/`. A folder is opened by a click
  on it and not by the press that begins a drag.
- **What a scene uses, and what uses a thing**: `ed_uses` lists in the
  Checks tab every material on the scene's brushes with how many sides
  have it, and every sound and model its entities name with how many
  name it, each marked when no archive holds it. `ed_uses <material or
  file>`, or a click on a row of that list, selects every brush with a
  side of that material and every entity that names that file.
- **A map forced on to the grid**: `ed_snap all [size]` (Edit menu) puts
  every brush's corners and every entity's origin on the grid, as one
  undoable step, and says how many things were off it, how many it
  moved and how many it left (a brush that would have no size on that
  grid is left as it is).
- **What clicks pick**: `ed_pickmode <all|brushes|entities>` (Edit menu)
  has a click in a view pick everything, brushes only (it passes an
  entity standing in front) or entities only (it passes every brush).
- **Editing kept to the selection**: `ed_restrict` (Edit menu) puts
  everything but the selection away, so that nothing else is seen,
  clicked or built; `ed_restrict off` brings back what it put away and
  leaves alone what was hidden before.
- **Small tools**: `ed_snap [size]` puts the selection's corners and origins
  on the grid; `ed_replace <old> <new> [all]` gives sides of one material
  another; `ed_align <x|y|z> <low|high|middle>` lines the selected brushes
  up; `ed_tag` remembers a picked face and `ed_glue` moves the selection
  against it; the face inspector spreads a pick to the whole brush, to its
  other faces or across the face's plane (`ed_faces <all|invert|extend>`);
  `ed_stats` counts the document's entities, brushes, sides and materials.
- **Curved patches** (Brush > Curved sheet, arch, corner, cylinder, cone;
  `ed_patch <kind> [w d h]`): a grid of control points bends a surface, as
  Quake III's patches do, and the surface is built as thin prisms held as a
  group, so a patch draws, collides and takes materials in any game's
  scenes. With the patch selected, Corners (3) shows its control points; a
  drag moves one and the surface is built again (`ed_patch_point <patch>
  <point> <dx> <dy> <dz>`). Moved as a whole, its control points go with
  it: the larger red handle at their middle is the whole patch's, and a
  drag from it moves every point together.
- **A shipped level as brushes** (File > Turn this level into brushes,
  `ed_convert`): a Quake II or Quake III level being looked at becomes a
  scene of its own brushes, each side with the material of the face drawn
  on it and that material's lie solved from the face's texture coordinates,
  and with every entity. Quake's own format keeps no brushes, so its levels
  stay entity-only; Quake III's curved patches are not brushes and are left
  behind.
- **Copies as images** (`ed_dup <copies> <dx> <dy> <dz> [turn]`, `ed_dup
  mirror <x|y|z>`): a group that asks for copies is built with them, each an
  offset on and a turn more than the last, or its mirror image; they follow
  the group as it is edited. `ed_dup apply` makes them real brushes and
  `ed_dup off` stops them. More of what a duplicator can ask for:
  - `ed_dup grow <factor>` (or a factor an axis): each copy that much the
    size of the last. `ed_dup axis <x|y|z>`: what each copy's turn goes
    about, so a ring can stand upright.
  - `ed_dup mirror xy` (or `xyz`): every combination of the axes named, so
    one corner of a room becomes four, or eight.
  - `ed_dup at <targetname>`: an image at every entity of that name,
    facing as it does; `ed_dup path <targetname>`: one at every corner of
    a path, facing along it. With `ed_dup tile <length>` the images are
    laid along the path instead, so far apart: as many to a leg as fit,
    spaced evenly and facing along it, and at each bend one turned half
    way between the two legs, with half a tile kept clear of it on either
    side (`ed_dup tile off` goes back to the corners).
  - `ed_dup materials <names>`: the images take those materials in turn.
  - `ed_dup each` (on an entity made of brushes, a door say): each image
    is an entity of its own, with the number in its `targetname` and
    `target` counted up, so three doors open one by one.
  - `ed_dup hide` builds the level without any images, and `show` with
    them.
  - Duplicators nest: a group put in a duplicating group (`ed_nest`) is
    copied by it whole, its own images and all, so a row of posts held
    in a group that copies twice makes three rows. Each duplicator's
    images are kept on a node of their own beside it in the scene's
    graph, and a walker (`editor/document/duplicate.jac`) goes through
    the groups, those held within first, making a duplicator's images
    again only when its fields or what it copies have changed;
    `ed_dup images` lists each duplicator's images and how many the
    walker made again or kept.
- **The leak finder** (Edit > Look for a leak, `ed_leak`): floods from the
  entities through the space the world's brushes leave; when it reaches
  the void, the way it took is drawn in red in every view.

- **The asset explorer** (View > Asset explorer, `ed_layout assets`): every
  file in the installed games' archives, by game and folder. A click on a
  file shows it: a texture as its picture (Quake II's WALs, Quake III's TGA
  and JPEG images, PCX pictures), a script or config as its first lines, a
  sound as its rate and length (with a Play button while a level of its
  game is open), and a model (Quake's MDL, Quake II's MD2,
  Quake III's MD3) as its wireframe: a drag turns it, the wheel moves
  nearer, and its buttons step through its frames or play them (`ed_frame
  <number|next|prev|play|stop>`). How it plays is set beside that:
  `ed_frame fps <n>` for how many frames a second (ten unless told),
  `ed_frame range <first> <last>|all` for the frames it runs through
  (stepping on from the last comes round to the first), `ed_frame once`
  and `loop` for whether it stops at the last, and `ed_frame smooth
  on|off` to draw the frames between as it goes from one to the next
  (`ed_frame smooth <n>` draws just that many between each two). The
  `lower.md3` or `upper.md3` of one of Quake III's players plays the
  sequences of its own `animation.cfg`: `ed_frame clip list` names those
  the part plays, and `ed_frame clip <sequence>` takes that sequence's
  frames, its speed and whether it goes round from the table (the legs'
  frames counted as the legs' file has them). How
  it is drawn: `ed_model backs off` leaves out the faces turned away from
  the eye (found again as the model is turned), and `ed_model ticks
  <size>|off` marks every point. `ed_model boxpart` gives the model in
  the model editor a part named `bbox`: a box of eight points round the
  model at each of its frames, kept and saved with it; `ed_model boxpart
  picked` makes the box round the picked points or faces of the part in
  hand instead, as a part named `bbox_<part>`. Extract (`ed_extract [folder]`) writes the
  file to disk under `QP_EXTRACT` (default `./extracted`), and Use as
  material gives a texture to the selection.
- **Packing** (`ed_pack <folder> <out.pak|out.pk3>`): a folder's files as a
  PAK or a PK3 the games' own readers take. `ed_pack scene <out.pk3>` packs
  the scene's map with the texture files its materials name.
  An archive is changed in place too: `ed_pack list <archive>` says what
  it holds, `ed_pack add <archive> <file> [name inside]` puts a file in
  (in place of the file of that name, whatever its case, or after the
  rest; the archive is made if it is not there), and `ed_pack drop
  <archive> <name>` takes one out, or a whole folder when the name ends
  in `/`. The new archive is written beside the old and put in its
  place. One of an installed game's own archives is refused: copy it and
  change the copy.
- **Without a window**: with `QP_HEADLESS=1` in the environment the game
  opens its window hidden and runs as ever, so a script of editor commands
  (`./qp +ed_exec batch.cfg`, ending in `quit`) opens, converts, checks,
  builds and saves with nothing shown: what it prints and the files it
  writes are the result, and screenshots are still taken. It needs a
  desktop session for the graphics all the same. `jac run
  scripts/validate_studio.jac --hidden` runs every session this way.
- **Round a brush** (`ed_tex wrap round`): from the tagged face the
  material goes round its own brush onto the brush's picked faces, each
  taking it from the face beside it that already has it, turned about the
  edge they share: a pillar's or a column's sides in one go, both ways
  round from the tagged one, where `ed_tex wrap` reaches only the faces
  that touch it.
- **Several tagged faces**: `ed_tag add` tags the picked faces beside the
  first, `ed_tag list` says them and `ed_tag clear` forgets them all;
  `ed_glue` moves the selection against whichever tagged face's plane it
  stands nearest. The first is still the one a material is taken from.
- **Brushes that are not walls** (`ed_overlay [triggers|unseen] [on|off]`):
  the volumes that set things off (brushes of `trigger_` entities, or in
  a trigger material) are outlined in yellow in every view, and the
  brushes a player never sees in magenta (clip) and blue (hint, skip,
  caulk, nodraw), told by the last word of every side's material. A group
  with a colour of its own keeps it. `ed_overlay` alone counts each kind.
  `ed_overlay overdraw` (View menu) lays over the 3D view every face the
  engine would draw from the eye (through the level's PVS when culling
  is on), each adding a little colour where it lies whatever is in front
  of it: where many are drawn over one another it glows, which is what
  the renderer pays for there. The developer's readout has the frame's
  time beside it, and `ed_cells` what a cell sees.
  `ed_overlay width <1..4>` says how many pixels wide the studio's own
  lines are drawn in every view (outlines, arrows, paths, rings, a
  model's edges): a wide line is the line drawn again to either side of
  itself as the view sees it, so it is as wide far off as near. Kept in
  the settings, and in the Settings box under 3D view.
- **Maps for other tools** (`ed_export <file.map> [valve|classic|q3]`):
  the scene written as a map in Valve's form (the form scenes are saved
  in), the classic one, or Quake III's own. In Quake III's a brush is a
  `brushDef` with a matrix a side: how the texture runs across the face,
  in repeats of it, measured along two axes the tools take from the face's
  normal. The matrix is worked out from how the material lies and the
  texture's true size, so every texel stays where it was. A patch is
  written as a `patchDef2` (its control points and where each lies on the
  texture) in place of the prisms the scene builds it from, and materials
  are named as Quake III's tools name them (`base_wall/concrete` for
  `q3:textures/base_wall/concrete`). `ed_open` reads such a map the other
  way: each matrix becomes a lie by the size of the texture it names,
  names are found among the game's own, and a patch keeps its places on
  its material.
- **A loop round a selection**: in brush mode, Alt and a drag in any view
  draws a loop freehand; what lies inside it when the button is let go is
  selected (with Shift or Ctrl, added), where a rectangle would take what
  stands in its corners too. `ed_lasso <view> <x> <y> ...` is the same
  by command.
- **Moves that end on something** (`ed_snapto <grid|corners|edges|faces>
  [reach]`): a move of the selection, dragged or by `ed_move`, ends where
  it is asked unless a corner of what is moving comes within reach (16
  units unless told) of a corner of another brush, of a point along one
  of its edges, or of a point on one of its faces; then it ends there,
  by the least change that puts it there. Edges take corners too, and
  faces take both.
- **Faces that meet** (`ed_faces adjoining`, `ed_faces beside`): from a
  picked face the pick spreads to the faces that lie in its plane and
  share a length of edge with it or lie over it, and to those that adjoin
  them, and so on (a floor of many brushes, and not a floor across the
  room, which `ed_faces extend` would take too); or to the faces of its
  own brush that share an edge with it.
- **Sides that make no face** (`ed_prune [all]`): the check names a brush
  with a side that cuts nothing off it; `ed_prune` takes such sides out of
  the selected brushes, or of every brush, and takes out a brush that then
  encloses nothing, as one step. A brush with linked faces is left as it
  is, since its links go by the places of its sides.
- **Lined up with a set** (`ed_align <x|y|z> <low|high|middle> to <set>`):
  the selected brushes, even one, are brought to the low side, high side
  or middle of a kept set's box, where the set stands.
- **The tree in words**: `ed_tree [text]` says every row the scene tree
  shows (its depth, its key, its words and its note, and a star when it
  is selected), or those that hold some text. A group that is a
  duplicator is marked as one in the tree, with what it makes its images
  by (`posts  (duplicator: 3 copies and mirrored)`), beside the marks
  groups had (outlines, locked, not built, digs).
- **Finding**: `ed_assetfind` takes more than words: `kind:<image|text|
  sound|model|map>` for the kind of file, `game:<q1|q2|q3>` for the game,
  and `tag:<word>` for a tag, in any order beside the words every name
  must hold (`ed_assetfind metal kind:image game:q2`). A tag is a word
  hung on the file the explorer shows, to find it by again: `ed_assettag
  <word>` hangs one, `ed_assettag drop <word>` takes it off, `ed_assettag
  list` names every tagged file; they are kept in `asset_tags.txt` beside
  the studio's settings. The Materials tab's filter takes a size beside
  its words (`ed_matfilter size:64x64`, `size:64` for either side,
  `size:>=128` or `size:<=32` for the longer side): each texture of the
  shelf is read for its size. `ed_texinfo [material]` says what there is
  to know of a texture: its size, a Quake II texture's flags and contents
  by name with its value and the texture that follows it, how many
  frames it is one of, whether a script draws a Quake III one, and how
  many colours it uses and how many of its texels are clear.
- **WADs**: a WAD among a game's files (Quake's `gfx.wad`) is a folder of
  its lumps in the explorer as well as a file. A lump that is a picture
  (its size before its texels) is shown as one, the console's letters as
  the sheet they are, and Extract writes a lump out as the WAD has it.

A scene is a "passion" level: it plays by the rules generated expeditions do
and may hold any game's entities.

### Saving a shipped map's entities

Save writes the map's entities to
`$QP_OVERRIDES/<game>/<map>.ent` (default
`~/.quakepassion-overrides/`, or beside the settings when `QP_CONFIG_DIR` is
set). The level loader reads that file in place of the map's own entity lump
whenever the map loads, in or out of the studio. File > Revert to the shipped
map deletes it.

## How it is built

```
engine/core/workbench.jac    the only thing the engine knows: a mode that takes the window
editor/ui/                   the interface toolkit
editor/document/scene.jac    the document graph
editor/geometry/brush.jac    brushes: planes, outlines, clipping, mappings, rays
editor/geometry/csg.jac      brushes cut by brushes, hulls of corners
editor/geometry/mapping.jac  materials slid, scaled, turned and fitted; sides mirrored and turned
editor/geometry/linear.jac   turns, sizes and shears as one kind of change; the box handle's drags
editor/geometry/layhandle.jac  a face's material as a dot and two arms, and what a drag of each asks
editor/formats/map.jac       the .map text format, classic and Valve 220
editor/formats/bspmap.jac    a built level's brushes back as a map
editor/compile/leak.jac      the flood that finds a way out to the void
editor/document/generate.jac groups that are built with copies of themselves
editor/compile/live.jac      a scene's brushes as a level, at once
editor/compile/light.jac     lightmaps for that level from the scene's lights
editor/geometry/shapes.jac   cones, balls, stairs, arches and pipes as brushes
editor/geometry/terrain.jac  a grid of heights as prisms, sculpting, heights as images
editor/geometry/patch.jac    control points, the surface they bend, and its prisms
editor/classes/registry.jac  entity classes: fields by kind, options by name
editor/assets/materials.jac  materials from the games' archives, by name
editor/assets/explorer.jac   the archives' files by folder, and what to show of each
editor/assets/models.jac     the games' models read for looking at: edges and bounds by frame
editor/formats/archive.jac   PAK and PK3 archives written
editor/camera.jac            the free camera: rays through the view, points onto it
editor/studio.jac            the workbench: panels, picking, play and stop, the ed_* commands
editor/impl/                 the workbench's scenes and brushes
```

- **The engine side** is one interface. `App` holds a `Workbench`; while it is
  active the simulation stands still, the frame's keys go to it, and
  `App.render_bench` draws the level once for each `SceneView` it asks for
  (`Renderer.begin_view` draws into a rectangle of the window, perspective or
  orthographic) and then lets it draw over the result. `main.jac` attaches the
  studio, so `engine/` never imports `editor/`.
- **The interface is a graph** (`editor/ui/widget.jac`). Widgets are nodes
  joined by `Child` edges under a `Stage` of layers. `Arrange`, `Paint` and
  `Pick` walk the tree depth first each frame; a `Deliver` walker carries
  each event up the `Child` edges until a widget takes it. Widgets do not
  call the studio: they emit console commands.
- **The document is a graph** (`editor/document/scene.jac`). A `Scene` holds
  an `Item` per entity and points at the selected ones with `Selected` edges.
  Each edit is a walker from the scene to its selection that records what it
  changed; the journal undoes and redoes those steps.
- **Each level view is a port**: a view area and a camera. The first is the
  free 3D camera; the others are orthographic cameras along an axis
  (`EditCamera.span`). The pointer's code looks through the camera of the
  view it is in (`Studio.watch`), so picking, dragging and handles are the
  same code in every view.
- **Every action is a console command** (`ed_select`, `ed_set`, `ed_new`,
  `ed_play`, ...; `cmdlist ed_` lists them), which is what buttons, menus and
  keys run. `ui_move`, `ui_click`, `ui_drag`, `ui_key`, `ui_type` and
  `ui_sync` script the pointer and keyboard one step a frame, and `ed_exec
  <file>` runs a file of commands, so a script drives the interface exactly
  as a hand does.
- **A scene compiles to a level in memory** (`editor/compile/live.jac`).
  Every brush becomes its faces and its collision planes as drawn: no hidden
  faces are removed, the world is one leaf that sees itself, and light is a
  flat shade. `Workbench.build_level` hands the level loader that data
  afresh for each load of a `studio:` level, so Play, Stop and the rebuild
  after an edit all go through the ordinary `load_destination`.
- **Brushes are in the document graph**: an entity `Owns` its `Solid`s, the
  `Selected` edges reach items and solids alike, and the same walkers
  (`Shift`, `Remove`, `Clone`, `Paint`) visit both. A picked face is a
  `Faced` edge from the scene to its brush that carries the side's number;
  `Reface` walks those edges and the selection to change materials, `Carve`
  walks every brush of the document, and `Inspect` walks it all for the
  check.
- **Targets are edges**: an entity `Fires` what its `target` names. The
  edges are redrawn from the fields when the document changes, so what an
  entity sets off is a walk along them (`Reach`), and the logic graph's
  columns and the loops the check reports come from the same edges.
- **Play** stages the document's entity lump on the `App`
  (`staged_entities`) and reloads the level, which is how unsaved edits are
  played. The level keeps the map's entities before the skill filter
  (`Level.source_entities`); that list is what the document is made from.

## Validation

- `tests/studio_floater_tests.jac`: a floating window laying out what is
  inside it, taking the pointer only where it is, moved by its bar, sized
  by its corner, kept on the stage or within bounds, closed by its
  cross, and painting nothing inside; a rectangle with others cut out; kept within its room once there is one, and left as put before; the light colours against the dark.
- `tests/ui_tests.jac` (also): a menu too long for the window laid out in
  columns, an entry of a later column clicked.
- `tests/ui_tests.jac`: layout, picking, clicks, text editing, the tree,
  scrolling, splitters, tabs, menus and hints, and the slider, spinner,
  radio, vector field and colour bars, through a recording canvas and
  scripted input.
- `tests/studio_document_tests.jac`: entity lumps round-trip; selection;
  every edit and its undo; any run of edits undone in full restores the
  document.
- `tests/studio_bake_tests.jac`: a level cut into cells with every face in
  one; a wall across a hall hiding one side from the other, and a doorway
  letting it be seen; a level that fits one cell left as it was; a budget
  spent leaving the rest in sight; a bake kept from one build and given
  whole to a level compiled of the same thing again.
  (`tests/studio_compile_tests.jac` has
  a baked level prepared by the engine, the player's cell found in it and
  fewer faces listed from behind the wall.)
- `tests/studio_project_tests.jac`: a manifest's words with what is quoted
  kept together; a project read from its manifest and written back the
  same, its scenes in order; what a manifest does not understand kept and
  what would mislead refused; an add-on's class lines. (An add-on's
  classes joining the table, replaced when read again and leaving it are
  in `tests/studio_class_tests.jac`.)
- `tests/studio_prefab_tests.jac`: a map's box and the whole of it moved;
  an instance swapping materials, setting fields and taking names of its
  own; prefabs within a prefab standing on their instances, each changed
  as its instance says.
- `tests/studio_sound_tests.jac`: a sound written as a WAV the engine
  reads, at either width; a stereo sound mixed to one channel and played
  at the games' rates; a wall texture's facts read, changed and written
  back with its pictures untouched; a Quake animated texture's row.
- `tests/studio_shader_tests.jac`: a script read into shaders, their lines
  and their stages; written and read back the same; a directive set,
  changed among several of its kind and taken out; a broken script's
  faults said by line; what the game would trip on inside a shader.
- `tests/studio_touchup_tests.jac`: a place as the nearest corner and
  the cell it is in; corners that go together within a variance; cells
  that go together, their corners and their edge; on a scene, a corner
  moved with its kin, cells lifted, and a terrain's top and bottom moved
  apart and undone.
- `tests/studio_links_tests.jac`: planes that are one plane; linked faces
  pushed together through several links and undone together, and not
  pushed when any brush would be emptied; a side taken out of its links,
  a deleted brush dropping out and coming back; the faces a cut left in
  pieces linked, and links kept in the map; two overlapping brushes cut
  to a seam; a corner merged onto another.
- `tests/studio_mesh_tests.jac`: what a mesh holds, where it is open and
  what is wrong with it; points and triangles picked by each other and by
  the way they face; points moved, turned, stretched and mirrored;
  triangles cut in two, three and four; triangles pushed out with and
  without bulkheads; every primitive closed, facing outward and filling
  its box; OBJ text written and read back, and other programs' files
  read; a line of sight finding the triangle it meets first and the point
  it passes nearest.
- `tests/studio_model_tests.jac`: a model's parts, poses and frames; a
  tool that changes the triangles carried to every pose alike; edits
  undone and redone; picking; a model of several parts checked and its
  frames matched; MD3 and MD2 written and read back by the engine's own
  readers, and taken up again as a graph; tags added, moved a frame at a
  time and dropped, going with their frames; a frame moved in the order.
- `tests/studio_district_tests.jac`: a slot's material as one word and
  back; the table as text, a text changing only what it speaks of, lines
  that say nothing passed over; the kept file read in place of the table.
- `tests/studio_assembly_tests.jac`: points carried to where a model is
  placed; a body of legs, torso, head and weapon joined by their tags at
  each frame, a tag turning what hangs from it; a sequence's frames and
  a weapon's; a weapon riding a hand's tag with its barrel.
- `tests/studio_bones_tests.jac`, `tests/studio_rig_tests.jac`: points
  turned and moved by their shares; a grip taking, sharing and letting go
  points; the nearest bone; frames spread; colours mixed; and in a
  model, bones added, chained and dropped, points shared and released,
  a bone turned with all that hangs from it, undone and redone, bones
  kept to their frames, and the rig written as text and read back.
- `tests/studio_skin_tests.jac`: places on a skin moved, stretched,
  turned and flipped about their own box; points laid flat by looking
  along an axis; a skin filled, dabbed solid and soft, and kept as a
  TGA; painting through the model landing where the line of sight meets
  its skin.
- `tests/studio_extrude_tests.jac`: every outline's pieces within its
  square; a square along a line as a beam of the line's length; stretches
  meeting at a turn on the plane that halves it, with no gap and no
  overlap, level and climbing; a rail's three pieces along two stretches
  and a closed path as a ring; a brush's own outline swept.
- `tests/studio_steps_tests.jac`: a recipe's commands apart at semicolons
  and a step's line with the map put in; a compiler's words read for the
  entities and brushes they name; a line of the map's text placed in its
  entity and brush; a text's mark the same for the same text only.
- `tests/studio_duplicator_tests.jac`: copies that grow and turn about
  each axis; mirrors on two and three axes; images at named entities and
  along a path's corners; the material cycle; a door's images as doors
  with counted names.
- `tests/studio_entities_tests.jac`: what each skill and mode leaves out;
  the preview hiding and showing; values replaced and refused; the audit;
  pasted entities renamed apart from the document's.
- `tests/studio_faces_tests.jac`: a side dropped or turned only where the
  rest close; a cone, a prism and walls on a face; the same through the
  document with undo; side flags by brush and by face, through a map and
  back; a digger's shaft cut from what is built, the input left whole; a
  map written without comments and in whole numbers; a face's narrowest
  width and the check's finding for a sliver; the face pick stepped round
  a brush; a material fitted in whole repeats, wrapped so both faces agree
  along their shared edge, projected, painted on one face; a face glued
  into a plane; the check's finding for a smeared material.
- `tests/studio_select_tests.jac`: sets kept, picked, replaced and dropped;
  a deleted member leaving a set and coming back with undo; sets written
  with the map and read from it; the steps to owner, brushes and
  neighbours; brushes by number; the swap and its undo; what a build is
  made from under each of a group's switches.
- `tests/studio_layhandle_tests.jac`: the arms of a material on a floor, a
  wall and a slope; the dot sliding it; an arm stretching and swinging one
  way alone, turning both, going in steps, and only stretching.
- `tests/studio_linear_tests.jac`: a change as what it makes of the axes,
  one after another and undone; a box sheared keeping its volume and its
  material; turns and stretches agreeing with the ones already there; each
  part of the box handle and what a drag of it asks; a selection sheared
  with its entities and the way they face, and a patch with its points.
- `tests/studio_transform_tests.jac`: turns and stretches about a given
  pivot, the texture lock, inflating, a group's own pivot carried through a
  move, a turn and a stretch, and a patch's control points turning and
  stretching with its brushes.
- `tests/studio_camera_tests.jac`: the ray through a point of the view lands
  back on that point; framing; ray and box; the swing round a point and
  facing one point from another.
- `tests/studio_brush_tests.jac`, `tests/studio_map_tests.jac`: outlines,
  clipping, volumes, rays and mappings; maps read and written in both forms.
- `tests/studio_csg_tests.jac`: carving, hollowing, merging, hulls and
  corner moves by volume; materials kept in place through a slide, a fit, a
  mirror, a stretch and a turn about each axis.
- `tests/studio_wrapround_tests.jac`: a material sent round a box's walls
  from one, meeting without a break at each edge it crossed, onto the
  picked faces only, and undone.
- `tests/studio_overlay_tests.jac`: a brush known for a trigger volume, a
  clip or a hint brush by its entity and its materials, and a brush with
  any side that is seen left as a wall.
- `tests/studio_fanpath_tests.jac`: a fan's wedges filling the round of
  its box; where copies lie along a path a tile apart, straight, round a
  bend and up a slope; a duplicator's images with and without a tile.
- `tests/studio_primitive_tests.jac`: the two axes Quake III's tools
  measure a face's texture along; a matrix read as a lie by the texture's
  size; a lie turned, stretched, slid and leaning out of its face taken to
  a matrix and back with every texel where it was.
- `tests/studio_q3map_tests.jac`: a brush written as `brushDef` and read
  back; a map from Valve's form to Quake III's and back; a patch written
  as `patchDef2` with its places and read back; a patch read into a scene
  as prisms and written out a patch again.
- `tests/studio_snapto_tests.jac`: a point inside a loop of any shape,
  drawn either way round; a long loop thinned; a move that ends on a
  corner, an edge or a face within reach, and is left alone out of reach.
- `tests/studio_makers_tests.jac`: fields that make a group a maker; a box
  built as a shell of six slabs, as four walls and as an arch of six
  blocks; a map built with its makers' brushes made and the rest as it
  was.
- `tests/studio_texwrite_tests.jac`: a picture halved by the mean of each
  four texels; a WAL that reads back as the texture it was; a Quake WAD
  whose textures are found by name with their four sizes; sides that are
  not whole sixteens refused; the name a material's picture goes by.
- `tests/studio_paths_tests.jac`: a path as every corner reached from one
  of them, either way, and nothing that is not on it.
- `tests/studio_shelves_tests.jac`: a name with folders kept inside its
  shelf; a shelf's folders as headings, shut until opened, before its
  files; the values a sound or model field can take from a game's files.
- `tests/studio_flyover_tests.jac`: a hint beside the pointer after it
  has rested on a control, gone when it moves, never over a work surface
  and not when turned off; Tab from field to field and round, past what
  is hidden; the command a control asks for.
- `tests/studio_meshfind_tests.jac`: a point and a triangle of a mesh
  said by number: its place and its triangles, or its points, area and
  facing.
- `tests/studio_sash_tests.jac`: a bar between two views or two rows that
  asks for the share the pointer is dragged to, and the views following
  their weights.
- `tests/studio_ownfiles_tests.jac`: a folder on disk listed as its files
  by their paths from it, dotted names left out, and as folders the way
  the explorer lists a game's.
- `tests/studio_rectlift_tests.jac`: a falloff as units or as a share of
  a rectangle's shorter side; a rectangle of terrain lifted and lowered
  with one.
- `tests/studio_needs_tests.jac`: the file a sound field names by its
  game's rules and a model field's; the files an entity needs and those
  a game's list does not hold, whatever their case.
- `tests/studio_treedrop_tests.jac`: a row carried onto another row of
  its list, onto a heading and onto none, from another list, and into a
  view; a list that takes no drops; a row that is never carried; selected
  brushes handed to an entity already there as one step, undone and done
  again; a name moved before another or to the end.
- `tests/studio_camproute_tests.jac`: a way walked area by area down the
  time still to go, taking what the router said it takes and going by
  the only bridge; no legs within one area; no route off the floors or
  across a gap; a ledge as a jumped leg up and a dropped leg down.
- `tests/studio_logpanel_tests.jac`: the lines a panel of so many rows
  shows, at the newest and scrolled back, no further than the oldest;
  a long line cut to fit.
- `tests/studio_adjoin_tests.jac`: outlines in one plane that adjoin
  along an edge or over one another and not at a corner; the four faces
  beside a face of a box; a side that makes no face.
- `tests/studio_gltf_tests.jac`: JSON read into values and what is not
  JSON refused; base64; a model written as a glb and read back part for
  part; a `.gltf` with its numbers inside it, y up, read; what is not
  glTF refused.
- `tests/studio_meshcut_tests.jac`: a box's triangles cut along a plane
  (new points on the plane, shared where triangles share a side, closed
  and of the same volume), a plane through a corner, a cut that falls on
  every pose alike and is undone whole, and a tag turned at one frame and
  at all.
- `tests/studio_finding_tests.jac`: a search read from what is typed and
  answered by a file's name, kind, game and tags; a size asked exactly,
  by one side and by the longer side; tags hung, taken off and kept as
  text; a picture's colours counted.
- `tests/studio_repack_tests.jac`: a PAK's files read out, one put in
  place of another or added, one and a folder dropped, and read again by
  the engine; the same of a PK3 on disk; a WAD's lumps as files inside
  it; a file known to lie in a folder however the two are written.
- `tests/studio_instance_tests.jac`: an instance of a prefab stood on its
  origin as its file has it, turned a quarter round (brushes, entities'
  places and facings, materials still along their faces), sized by one
  number and by three, mirrored, and refused a size of nothing;
  instances inside a prefab each turned and sized in place; an instance
  tipped nose down, rolled, and tipped and then turned.
- `tests/studio_softlock_tests.jac`: a door behind a relay nothing sets
  off, and put right by a trigger that fires it (killing a thing does not
  set it off); a counter of three with two deaths to fire it; doors that
  want keys, by game.
- `tests/studio_bits_tests.jac`: each game's names for the bits of a
  side's contents and flags, and a number said by them.
- `tests/studio_modelfile_tests.jac`: a model of two parts written as a
  Quake MDL and read by the engine (points, places on the skin, the skin
  itself in the palette's colours, frames' names); a work file that gives
  back poses, picks, tags, bones and what was in hand, writes the same
  text again, and is refused when it is not one.
- `tests/studio_playback_tests.jac`: the frame after one within a range,
  round and once, and with a range that is no range; the edges of the
  faces toward an eye; a box as a mesh of twelve triangles facing out; a
  body's sequences read from its table for its legs and for its torso; a
  set number of frames between two; the box round some points.
- `tests/studio_integral_tests.jac`: a drifted face laid through whole
  points and left alone when asked again; a direction put on whole
  angles; a face tilted about its own middle.
- `tests/studio_grid_tests.jac`: what of a map is off a grid, the whole map
  forced on to it as one step, a sliver that would fall flat left alone.
- `tests/studio_navigation_tests.jac`: ways between neighbouring floors by
  their heights; floors as areas with ways out and a tree that places a
  point (stacked floors, off the grid, under the floor); and the
  engine's router over the result: round by a bridge, cut off without
  it, down a ledge and not up it, onto a low one at a cost.
- `tests/studio_compile_tests.jac`: a compiled scene's models, faces and
  entities, and that it prepares as a level that holds the player up;
  lamps, shadows and the lightmap a light gives the world.
- `tests/studio_convert_tests.jac`: a compiled scene turned back into
  brushes with its materials and their lie; a sealed room, a hole and a
  thin wall under the flood; a duplicator's images.
- `tests/studio_archive_tests.jac`: a PAK and a PK3 written and read back
  by the engine's readers; the zip checksum; names listed as folders.
- `tests/studio_terrain_tests.jac`: heights as a field, a flat terrain's
  volume, a raised corner, each kind of stroke, heights out to an image and
  back.
- `tests/studio_patch_tests.jac`: control points as a field, the surface
  through its corner points, a sheet's prisms, a lifted point, every kind.
- `tests/studio_patchskin_tests.jac`: a material laid on a plane through
  three points and their places; places as a field, spread, projected and
  slid; a patch's prisms taking the material where the control points
  say, in step with their neighbours; places kept through a bend, read
  back from the built faces, let go with the grid and forgotten.
- `tests/studio_shape_tests.jac`, `tests/studio_class_tests.jac`: each
  shape's size, volume and gaps; the class table read whole, fields by
  kind, classes by game, option bits.
- `scripts/ui_gallery.jac`: every widget in one window without the engine,
  with a scripted session saved to a screenshot.
- `jac run scripts/validate_studio.jac`: drives the real studio in `qp` by
  scripted clicks, drags, typing and shortcuts, printing the document after
  each step. `--only <session>` runs one session (`shell` is the first);
  `--jobs <n>` runs them `n` at a time, each with settings and scenes of
  its own: the forty sessions in under two minutes with eight at a time.
  The suite was thinned to those forty, the ones that walk the main
  workflows end to end, so that a change can be checked quickly; what the
  forty-two sessions taken out covered keeps its unit tests above.
  `scripts/studio/shell_session.cfg` edits e1m1's entities (15 steps, then a
  second run confirms the saved entities load);
  `scripts/studio/scene_session.cfg` builds a scene of brushes (20 steps: box,
  pick, resize by a handle, drag, material, tie to a door, undo, redo, four
  views with a pick and a drag in the top view, duplicate, wedge, cylinder,
  clip, turn, save, play, return; then a second run reopens the saved map).
  `scripts/studio/tools_session.cfg` works on faces and shapes (19 steps: pick
  a face, give it a texture from the Materials tab's pictures, fit, nudge and
  turn it from the inspector, add a second face, hollow the brush, drag an
  edge and a corner in the front view, select by a rectangle in the top view,
  carve, tip, find a broken target with the check and pick it from the list,
  save, play, return; then reopen). `scripts/studio/logic_session.cfg` wires
  and reuses (14 steps: link a button to a relay and the relay to a door by
  dragging between their boxes in the logic graph, pick from the graph, copy
  and paste the door, save it as a prefab from the Library tab, add a copy by
  a click, place and move a linked one, group two boxes, save, play, return;
  then reopen). `scripts/studio/build_session.cfg` builds and sets up (16
  steps: stairs, an arch and a cone, a light that lights the level, flat and
  lit again, a door made from the Classes tab, two options ticked, a sound
  chosen from its list, an angle typed and turned by its button, a button's
  target followed to the door, save, play, return).
  `scripts/studio/assets_session.cfg` (6 steps: a Quake II texture shown in
  the explorer, given to a brush and extracted by its buttons, a config and a
  sound shown, the scene packed with its texture as a PK3 and a folder as a
  PAK; the validator opens both archives itself).
  `scripts/studio/handy_session.cfg` (12 steps: the grid by command and by its
  keys, a brush lifted and dropped back with End, a view remembered and
  returned to, hiding with H and Shift+H and everything else with a command,
  two edits undone from the history list, a command typed into the palette and
  another found by a few letters, an autosave, a selection by field).
  `scripts/studio/terrain_session.cfg` (7 steps: a terrain made, raised by a
  command, raised further by dragging the brush over it, lowered with Shift,
  flattened, given back heights written to an image, saved, played).
  `scripts/studio/patch_session.cfg` (7 steps: an arch made, a control point
  lifted by command, another dragged in the front view, the patch moved, a
  cylinder and a cone, saved, played). `scripts/studio/draw_session.cfg` (4
  steps: a box drawn by a drag in the top view, cut in two by a line drawn
  through it, trimmed by another with Shift; then the studio opened again to
  find its settings kept). `scripts/studio/transform_session.cfg` (12 steps: a
  box turned a quarter by the knob on its ring, turned to a 45 degree snap,
  doubled by a size handle about its middle and again about a pivot at its
  corner, inflated, and grouped with a pivot of its own that goes where the
  group goes). `scripts/studio/select_session.cfg` (12 steps: two boxes
  stacked over the floor clicked through from the top view, one after another
  and round again; a brush by number; its owner and the owner's brushes; two
  sets kept, one picked again; a box and the player start swapped; a tour of
  the two; then the saved map opened again to find its sets).
  `scripts/studio/faces_session.cfg` (10 steps: a box's top picked in the top
  view; walls, a cone and a pushed-out brush stood on it; detail and a surface
  flag, found again in the saved map; a box drawn inside the first made a
  digger, so the level is built from six brushes while the document holds
  four, then filled in and dug again by undo).
  `scripts/studio/float_session.cfg` (11 steps: a floating 3D window opened,
  put somewhere and given a camera; dragged by its bar and sized by its
  corner; the wheel moving its camera and not the first view's; a click in it
  picking the box it looks at; Escape letting go of the selection; a second in
  outlines over it, closed by its cross; one sent off the edge kept within the
  views; all closed). `scripts/studio/views_session.cfg` (11 steps: two, three
  and four views and the column of axis views; the ruler on a drawn box; zoom
  by command and by key; names; two views remembered, one gone back to, one
  forgotten; a picture laid behind the plan; the camera swung a quarter round
  the box and taken under its top; then the studio opened again to find the
  layout, the ruler and the names kept). `scripts/studio/play_session.cfg` (11
  steps: a lit scene built coarsely, finely and without light; played from
  high over the floor and held still, the player hanging there until thirty
  ticks let it fall half a second, then hanging again, then let run; the
  selected box played alone, as a level of one brush).
  `scripts/studio/entities_session.cfg` (10 steps: a door, its button, a
  monster and a pickup; the level as easy and as deathmatch spawn it; an
  option ticked by command; a value replaced on every entity; the audit's
  finding; the door and button pasted with names of their own; then the scene
  played and held still, the door shut until `ed_fire` names it and twenty
  ticks pass). `scripts/studio/docs_session.cfg` (10 steps: two scenes made
  beside the shipped level, listed, switched between with the camera kept,
  saved together; one closed and opened again from the recent files; the
  console's last lines; a right click on a drawn box and Duplicate from its
  menu; the box's faces stepped through; the scene saved without comments and
  in whole numbers). `scripts/studio/dups_session.cfg` (11 steps: a post
  copied in a row, grown and mirrored on two axes into seventeen built
  brushes; hidden and shown; an image at each of two named entities, then at
  three path corners, then made real; a door with two images played as three
  doors, the second opened by firing `door2`).
  `scripts/studio/wrap_session.cfg` (6 steps: a box's top given a material,
  slid and tagged; the face beside it takes that material round the edge, the
  next takes it as it lies; fitted in whole repeats; Alt and a drag in the
  plan paints the box's top and the floor; the floor's top put in the tagged
  plane, so the floor rises to it). `scripts/studio/settings_session.cfg` (5
  steps: K bound to add a column and Shift+K a cap, pressed, listed, one
  unbound; the settings list and its line that hides the grid; flat tones and
  back; the developer's readout; then the studio opened again to find the key
  and settings kept). `scripts/studio/layouts_session.cfg` (9 steps, run twice
  over one settings folder: four views split by numbers, then by dragging the
  bar between the columns and the bar between the rows; the side panels
  swapped; that layout and a plain one kept by name, listed, the first brought
  back whole, the second dropped; the second run opens as the first was left).
  `scripts/studio/uses_session.cfg` (8 steps: three materials and two models
  listed, one of each missing; what uses a material, a model and a name
  nothing uses; a drag onto no project, which writes nothing; a project made,
  a file of Quake's dragged onto it and then a folder of 57, each found on
  disk whole; and the copy shown in the explorer from the project's own
  files). `scripts/studio/needs_session.cfg` (7 steps: e1m1 checked, lacking
  no class and no file; a railgun added to it; a sound Quake's archives do not
  hold, then one they do; in a scene of the studio's own a `misc_model` with a
  model Quake III's archives do not hold, then one they do; and a misspelt
  class). `scripts/studio/treedrop_session.cfg` (11 steps: a box's row dragged
  onto the row of a box a wall holds, back onto the brushes' heading, onto the
  wall's class heading, undone, and onto the wall's own row; the player's
  start put on the wall, which changes nothing, and carried into the view onto
  the floor; in the Library tab one favourite dragged before another, one into
  the trash, and one into the view). `scripts/studio/q3map_session.cfg` (4
  steps: a box in a Quake III texture with its top slid, stretched and turned,
  and a curved sheet, written in Quake III's form, Valve's and the classic
  one; the first two agreeing texel for texel on the turned face when worked
  out by hand; the Quake III map opened again with the texture found, the
  material where it lay and the sheet a patch still).
  `scripts/studio/stuck_session.cfg` (9 steps: a button, a relay and a door
  with nothing stuck; the door a softlock once the button is gone; a counter
  of three that two soldiers' deaths cannot make up, and a trigger that does;
  a lock without its key, and with it; a brush's sides made a ladder and slick
  by Quake II's names, a name of Quake III's refused and then taken as Quake
  III's, and the same numbers read as Quake III has them).
  `scripts/studio/nav_session.cfg` (5 steps: nothing baked for a shipped
  level; a floor with a tall box and a low one baked into 256 places to stand;
  ways across the floor, none up the tall box, a drop from it, a jump onto the
  low one, none off the level; of two things added the one on the tall box
  named as out of reach; a coarser bake; forgotten).
  `scripts/studio/bake_session.cfg` (5 steps: a hall with a wall across its
  middle opened from a map, cut into thirty cells of which some are out of
  sight of others; played from one side of the wall, 32 faces are drawn; built
  as one again and played from the same place, 42).
  `scripts/studio/steps_session.cfg` (15 steps: the hall's cells shown from
  its west room, its east and where the player start stands; a wall moved and
  the move undone, and a game played and stopped, each given the bake kept
  from before; two recipes kept, listed, run and one forgotten; a stand-in
  compiler run over the map, stopping with its own code, and its three
  complaints, by entity, by brush and by line, each gone to).
  `scripts/studio/project_session.cfg` (10 steps: a project made, two scenes
  saved into it, its start, build, bake, material and a recipe set, and its
  manifest read back word for word; an add-on's two classes loaded, an entity
  of one made with its fields and flag in the inspector, the add-on read again
  and dropped; the project asked for from the Window menu; closed, and an
  older project opened with its scene and its own add-on, its manifest
  untouched; a game's material and build kept in the settings and the next
  scene floored with it). `scripts/studio/live_session.cfg` (8 steps: a door,
  a relay that opens it and a relay that fires that one; the game played,
  nothing yet fired; the first relay set off by hand, all three counted and
  the game held because the middle one holds it; the player's health and place
  and the middle relay changed while held; fired again, the firing stopping at
  the relay switched off; the counts still there after the game, and on the
  logic graph). `scripts/studio/model_session.cfg` (13 steps: an eight-sided
  cylinder made, closed and holding what one would; its top's triangles picked
  and pushed out; a second frame with the model higher in it; every triangle
  cut in four, turned round and that undone; a ball added as a second part;
  the panel's Cut in 4 and Undo buttons clicked; saved as MD3 and OBJ; closed,
  and opened again from the MD3 with both parts and frames).
  `scripts/studio/rig_session.cfg` (10 steps: a cylinder looked down on; a
  click picking a triangle of its top and a click with Shift another; a click
  picking the point on its axis, dragged with Ctrl as one step and that
  undone; two tags, one moved at every frame and one at a copied frame only;
  the copied frame moved to the front; a tag dropped; two skins named and one
  dropped; saved as an MD3 with its frames, tag and skin).
  `scripts/studio/drop_session.cfg` (4 steps: the project's image dragged from
  the Materials tab onto one face of a box; a light dragged from the Classes
  tab onto the floor; a prefab dragged from the Library tab onto the top of
  the box). `scripts/studio/links_session.cfg` (9 steps: two boxes drawn side
  by side, their four shared planes linked; the top of one pushed and the
  other's rising with it, undone together; the links taken away; a cutter
  drawn across a box and carved with links, the two pieces tied on four planes
  and the map saying so; two walls through one corner cut to a seam; a top
  corner of a box merged onto the one beneath it).
  `scripts/studio/shader_session.cfg` (7 steps: a shader made in a new script;
  three lines of its own and a stage's `tcMod`s set, a stage added and moved
  to the front; two mistakes made and listed by the check, then mended; the
  script saved, a second shader added, and the file opened again as two; a
  script broken by hand, its five faults said by line).
  `scripts/studio/bones_session.cfg` (12 steps: two bones up a column, the
  second carrying on from the first; every point given to the nearer; two
  points shared half and half, let go and taken whole; the forearm turned
  thirty degrees and that undone; its end dragged a quarter round its joint;
  three frames with the one between two poses set half way; the model saved,
  closed and opened with its bones; a bone dropped).
  `scripts/studio/skin_session.cfg` (7 steps: a cylinder laid flat into the
  left half of its skin, stretched to half, moved, turned a quarter and
  flipped, the flip undone; a picture made and dabbed on the skin; a click on
  the model painting where it lands on the skin; the picture shown under the
  model with the triangles over it, and saved as a TGA with the two dabs in
  it). `scripts/studio/convert_session.cfg` turns Quake II's base1 (1,750
  brushes) and Quake III's q3dm1 (987) into scenes, saves them as maps and
  reopens them, and turns a generated expedition (seed 42: 1,919 brushes)
  into a scene too.

## Building quickly: tools in modules of their own

A native build recompiles only the modules that changed, but to do so it
analyses again, from source, everything a changed module imports. The
studio (`editor/studio.jac` and its impl files, some nineteen thousand
lines) imports nearly everything, so any change to it, or to a module that
imports it, costs a rebuild of three and a half to four minutes. A module
that imports little rebuilds in about a minute.

So new features are written as tools: a module under `editor/tools/` with
an `obj` that derives from `StudioTool` (`editor/tools/host.jac`), keeps
its own state, and reaches the studio only through the `ToolHost` it is
handed (say a message, the level's navigation, draw a line, a material's
picture, a game's colours and files, the project's folders, run one of the
studio's own commands, the materials the browser lists and a picture shown
there in place of one's own; more as tools need it, each added to
`ToolHost` and to `StudioHost` in `studio.jac`). The studio asks its tools
each command before its own, lets them draw in the level views, gives
them every frame as it passes (`tick`), and takes their lines of the dump
and of the settings.
`editor/tools/install.jac` lists them and `main.jac` hands them over; a
tool never imports `editor.studio`. `editor/tools/camproutes.jac` (the
ways bots take between camp spots) is the first: a change to it rebuilds
in about seventy seconds.

## What remains

Milestones 1 (the shell) and 2 (blockout) of #73 are done, and most of 3
(views and texturing), 4 (brush tools) and 5 (logic and reuse), with parts
of 6, 7 and 9. The checklist in #73 says item by item what exists.

- Left over in what is built: a shipped
  map takes new brushes only once it is turned into a scene; a level's
  patches are left behind by `ed_convert` (a map file's `patchDef2` patches
  do open, as patches of the scene); a patch mirrored keeps its control points' order, so its
  curve faces the same way round; the logic graph neither reorders nor shows signals as
  they fire in play; a scene too large for the light budget stays flat.
- Not yet built: the rest of the bake (a partition by the brushes' own
  planes with portals between its leaves, in place of cells of the plan;
  bounced light); the Passion tools; user walkers.
- Within the shell: generated (Passion) levels can be edited but not saved as
  they are; `ed_convert` turns one into a scene of brushes, and `ed_exp open
  <seed>` generates one and opens it so.
