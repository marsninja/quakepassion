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
  selected things change places.
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
  light's value. Each drag is one edit. Paths are drawn corner to corner
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
  a name nothing fires.
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
- **What a game's scenes begin with**: `ed_game <passion|q1|q2|q3>
  <material|build|bake> [value]` sets the material new brushes are made
  of, how levels are lit and how wide a bake's cells are for scenes of
  that game, taken up when one is first shown outside a project and kept
  in the settings; `ed_game` alone lists the four with the folder each is
  read from (those folders are still set by `QP_ASSETS` and
  `~/quake-assets`, not from the studio).
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
  (Quake's WAD files are not written, and the frames are listed, not
  played in the browser.)
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
  `ed_shader save` writes the script, a tab a brace. There is no text
  editor for it yet, and a changed shader is not shown in the renderer
  until the game loads the script.
- **Entities as their models**: `ed_models` (View menu) draws each
  pickup, monster and fixture in the 3D view as the model its own game's
  rules give it (the engine's own rules are asked: the game is the
  level's, or the entity's `asset_game` in a scene of no one game),
  standing where the entity is and turned the way it faces, in the
  entity's colour and through the walls like the other overlays;
  `ed_models list` says which model each entity has. The models are
  drawn as their edges at their first frame; pickups that are little
  maps of their own (Quake's health and ammo boxes) keep their boxes.
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
  `ed_camps` lists them.
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
  inside. `ed_facelink clear` takes the picked faces, or every side of
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
  with `all`; `ed_mesh mirror <x|y|z>`, `flip`, `subdivide <2|3|4>` and
  `extrude <distance> [bulk]` change the triangles, and are carried to
  every pose alike by a walker, so that each frame keeps the same points
  in the same order. `ed_model frame copy [name]|drop|name <words>`
  works on the frame in hand (`ed_frame` goes from one to another),
  `ed_model part <n>` takes another part in hand, `ed_model check` looks
  for what is wrong (triangles with no area or a corner nowhere, unused
  points, parts with other frames than the first), `ed_model match`
  gives every part the first's frames, and `ed_model undo|redo` undo a
  part's edits whole. `ed_model save <file>` writes an MD3, an MD2 (the
  parts as one mesh, with a command list for renderers that want one) or
  an OBJ (the part in hand) under `QP_MODELS`, a project's `models/` or
  `./models`; the games' files wind triangles the other way round from
  the editor, and are turned on the way in and out.
  A click in the model's view picks the triangle under the pointer, or
  with `ed_pick mode points` (the panel's last row) the point it passes
  nearest, the nearest to the eye; Shift adds to what is picked, and Ctrl
  and a drag moves the picked points in the plane of the view, as one
  step when the button is let go. `ed_model tag add <name> [x y z]` adds
  a tag (in the middle of what is picked when no place is given),
  `ed_model tag at <name> <x y z> [all]` moves it at the frame in hand or
  at every frame, `ed_model tag drop <name>` drops it and `ed_model tag`
  lists them; a tag goes with its frames when they are copied, dropped or
  moved. `ed_model frame move <to>` puts the frame in hand elsewhere in
  the order, and `ed_model skin [add <name>|drop <number>]` keeps the
  skins the part in hand names. Not there yet: handles drawn on the
  model, the skin view and painting, bones, MDL writing and glTF.
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
  over it, and `ed_skin save <file.tga>` writes it. Not there yet:
  picking and dragging on the skin view itself, patterns, and the
  picture drawn on the model.
- **A played game watched**: while a game is played from the studio, what
  fires is counted, by the name it is fired by (or its class and what it
  fires, when it has no name). `ed_fired` says how often each has fired
  and in what order, during the game and after it; back in the studio
  the logic graph marks what fired and how often. `ed_break <name>`
  holds the game still the moment that name fires (`ed_break` lists
  them, `ed_break clear` forgets them; the graph marks them `[holds]`),
  and `ed_trace on` names each firing on screen as it happens. While a
  game is played, `ed_live` says where the player stands, with what
  health, and how every signal stands; `ed_live player health <n>` and
  `ed_live player at <x y z>` change the player, and `ed_live signal
  <name> on|off` switches a signal, before `ed_pause` lets the game run
  on. (The engine counts firings on its signals and calls the workbench
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
  of each band are drawn as red lines across the other axis views. The
  textured picture of the level in an axis view is not cut to the band:
  it is the outlines, the entities' boxes and what a click finds that are.
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
  written with the map whenever a side has any.
- **Diggers**: `ed_digger` makes the selected brushes a group of holes
  (`_digger 1`). The level is built with them cut out of every brush they
  reach, and with no brush of their own; the document keeps the digger and
  what it cuts whole, so moving the digger moves the hole and
  `ed_digger off` fills it in.
- `ed_inflate <units|up|down>` pushes every side of the selected brushes
  out, or in; a brush that would be left with nothing stays as it is.
- `ed_texlock [on|off]` (Brush menu) says whether materials go with the
  faces a move, turn or stretch carries, or stay where they lie in the
  world while the faces move through them. It is kept between sessions.
- A field that would break the map is refused: an `origin` that is not three
  numbers, an empty `classname`.
- **Controls to drag** end an entity's form: its place as three numbers,
  each changed by dragging across it in grid steps (ten at a time with
  Shift); the way it faces, in steps of the angle snap; and for a light,
  its reach on a slider and its colour on red, green and blue bars. Each
  drag is one undoable edit, made when the drag ends. A brush's form ends
  with which handles it shows (Move, Turn, Size).
- **Keys of your own**: `ed_bind <key> <command>` gives a key (a letter,
  or `ctrl+` and `shift+` before one) any editor command, ahead of what
  the studio gives it; `ed_unbind` gives it back and `ed_binds` lists
  them. They are kept in the studio's settings, apart from every game's
  bindings.
- **Settings** (Window > Settings, `ed_settings`) lists what is so, each
  line a click to change. The axis views' grid can be hidden
  (`ed_grid hide`), and when shown has the world's numbers along its
  edges. `ed_display solid` shows materials as flat tones in place of
  their textures. `ed_dev` puts frame and build times, how many brushes
  the level was built from, and how many entities and light samples there
  are, in the status bar.
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
- **How maps are written**: `ed_mapopts comments off` leaves out the lines
  that number entities and brushes, and `ed_mapopts whole on` writes every
  plane point in whole numbers, for tools that read nothing else. Both are
  kept between sessions.
- **Layouts** (View menu, `ed_layout <1|2|3|4|4b>`): the 3D view alone;
  beside the plan; beside the plan and the front view; all four in a
  square; or the 3D view beside the three axis views in a column. The
  layout is kept between sessions.
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
- **A shape of several brushes keeps its numbers**, as a group with a
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
  a scene without lights has.
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
  leave the brush flat is refused.
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
  click on a finding selects what it is about.
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
  another grid of points. Each is one undoable step.
- **More for terrain**: `ed_sculpt erode` wears down what stands above its
  lowest neighbour, and `ed_sculpt paint` gives the tops under the brush
  the material in hand. `ed_terrain lift <x0> <y0> <x1> <y1> <amount>
  [falloff]` raises (or lowers) every corner inside a rectangle, and
  those within the falloff of it by less the farther out they are.
  `ed_terrain pattern <same|alt|other>` splits the cells along the other
  diagonal, or along each in turn so ridges run either way.
  `ed_terrain free` leaves the terrain as the plain brushes it is made of.
- **Clip** (5): a line drawn across any view cuts the selected brushes
  along it, in the plane the line and the view's line of sight make; Shift
  keeps only what is behind the line and Ctrl only what is in front
  (`ed_clip_line`). **Draw** (6): a rectangle dragged in an axis view
  becomes a box on the grid, sixty-four units deep (`ed_box_draw`).
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
  <point> <dx> <dy> <dz>`). Moved as a whole, its control points go with it.
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
    a path, facing along it.
  - `ed_dup materials <names>`: the images take those materials in turn.
  - `ed_dup each` (on an entity made of brushes, a door say): each image
    is an entity of its own, with the number in its `targetname` and
    `target` counted up, so three doors open one by one.
  - `ed_dup hide` builds the level without any images, and `show` with
    them.
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
  <number|next|prev|play|stop>`). Extract (`ed_extract [folder]`) writes the
  file to disk under `QP_EXTRACT` (default `./extracted`), and Use as
  material gives a texture to the selection.
- **Packing** (`ed_pack <folder> <out.pak|out.pk3>`): a folder's files as a
  PAK or a PK3 the games' own readers take. `ed_pack scene <out.pk3>` packs
  the scene's map with the texture files its materials name.

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
  each step. `scripts/studio/shell_session.cfg` edits e1m1's entities (15
  steps, then a second run confirms the saved entities load);
  `scripts/studio/scene_session.cfg` builds a scene of brushes (20 steps:
  box, pick, resize by a handle, drag, material, tie to a door, undo, redo,
  four views with a pick and a drag in the top view, duplicate, wedge,
  cylinder, clip, turn, save, play, return; then a second run reopens the
  saved map). `scripts/studio/tools_session.cfg` works on faces and shapes
  (19 steps: pick a face, give it a texture from the Materials tab's
  pictures, fit, nudge and turn it from the inspector, add a second face,
  hollow the brush, drag an edge and a corner in the front view, select by
  a rectangle in the top view, carve, tip, find a broken target with the
  check and pick it from the list, save, play, return; then reopen).
  `scripts/studio/logic_session.cfg` wires and reuses (14 steps: link a
  button to a relay and the relay to a door by dragging between their boxes
  in the logic graph, pick from the graph, copy and paste the door, save it
  as a prefab from the Library tab, add a copy by a click, place and move a
  linked one, group two boxes, save, play, return; then reopen).
  `scripts/studio/build_session.cfg` builds and sets up (16 steps: stairs,
  an arch and a cone, a light that lights the level, flat and lit again, a
  door made from the Classes tab, two options ticked, a sound chosen from
  its list, an angle typed and turned by its button, a button's target
  followed to the door, save, play, return).
  `scripts/studio/images_session.cfg` (9 steps: a post copied as images,
  moved, the copies made real; a yard that leaks, a ring of walls that
  still leaks through the top, and the same sealed by a roof).
  `scripts/studio/assets_session.cfg` (6 steps: a Quake II texture shown in
  the explorer, given to a brush and extracted by its buttons, a config and
  a sound shown, the scene packed with its texture as a PK3 and a folder as
  a PAK; the validator opens both archives itself).
  `scripts/studio/handy_session.cfg` (12 steps: the grid by command and
  by its keys, a brush lifted and dropped back with End, a view remembered
  and returned to, hiding with H and Shift+H and everything else with a
  command, two edits undone from the history list, a command typed into
  the palette and another found by a few letters, an autosave, a selection
  by field).
  `scripts/studio/terrain_session.cfg` (7 steps: a terrain made, raised
  by a command, raised further by dragging the brush over it, lowered with
  Shift, flattened, given back heights written to an image, saved, played).
  `scripts/studio/patch_session.cfg` (7 steps: an arch made, a control
  point lifted by command, another dragged in the front view, the patch
  moved, a cylinder and a cone, saved, played).
  `scripts/studio/tidy_session.cfg` (7 steps: a box snapped back onto the
  grid, a material replaced everywhere, two boxes lined up, one glued
  against a tagged face, a face pick spread, the counts).
  `scripts/studio/draw_session.cfg` (4 steps: a box drawn by a drag in the
  top view, cut in two by a line drawn through it, trimmed by another with
  Shift; then the studio opened again to find its settings kept).
  `scripts/studio/material_session.cfg` (3 steps: a 256 by 512 Quake III
  texture and a 4-texel image of the project's own, each fitted to a face
  at its true size, and the image picked from the Materials tab).
  `scripts/studio/transform_session.cfg` (12 steps: a box turned a quarter
  by the knob on its ring, turned to a 45 degree snap, doubled by a size
  handle about its middle and again about a pivot at its corner, inflated,
  and grouped with a pivot of its own that goes where the group goes).
  `scripts/studio/lean_session.cfg` (15 steps: the box handle round a
  drawn box; its right edge taken along itself shearing it, and the shear
  taken back by number; a corner turning it a quarter, and with Shift
  sizing it from the far corner; its top edge sizing it and shearing it
  the other way; its middle moving it; its top edge in the front view
  leaning it over; two brushes sheared as one by the handle round both;
  a shear and a quarter turn by number, and two changes refused).
  `scripts/studio/select_session.cfg` (12 steps: two boxes stacked over the
  floor clicked through from the top view, one after another and round
  again; a brush by number; its owner and the owner's brushes; two sets
  kept, one picked again; a box and the player start swapped; a tour of the
  two; then the saved map opened again to find its sets).
  `scripts/studio/faces_session.cfg` (10 steps: a box's top picked in the
  top view; walls, a cone and a pushed-out brush stood on it; detail and a
  surface flag, found again in the saved map; a box drawn inside the first
  made a digger, so the level is built from six brushes while the document
  holds four, then filled in and dug again by undo).
  `scripts/studio/views_session.cfg` (11 steps: two, three and four views
  and the column of axis views; the ruler on a drawn box; zoom by command
  and by key; names; two views remembered, one gone back to, one
  forgotten; a picture laid behind the plan; the camera swung a quarter
  round the box and taken under its top; then the studio opened again to
  find the layout, the ruler and the names kept).
  `scripts/studio/groups_session.cfg` (10 steps: a box made a group; shown
  as outlines only, so the level is built without it and a click where it
  stands takes the floor; locked, built but still passed by; unlocked and
  taken by the same click; skipped by builds; tinted, its row opened onto
  its brush; hidden; its fields found in the saved map).
  `scripts/studio/play_session.cfg` (11 steps: a lit scene built coarsely,
  finely and without light; played from high over the floor and held
  still, the player hanging there until thirty ticks let it fall half a
  second, then hanging again, then let run; the selected box played
  alone, as a level of one brush).
  `scripts/studio/entities_session.cfg` (10 steps: a door, its button, a
  monster and a pickup; the level as easy and as deathmatch spawn it; an
  option ticked by command; a value replaced on every entity; the audit's
  finding; the door and button pasted with names of their own; then the
  scene played and held still, the door shut until `ed_fire` names it and
  twenty ticks pass).
  `scripts/studio/docs_session.cfg` (10 steps: two scenes made beside the
  shipped level, listed, switched between with the camera kept, saved
  together; one closed and opened again from the recent files; the
  console's last lines; a right click on a drawn box and Duplicate from its
  menu; the box's faces stepped through; the scene saved without comments
  and in whole numbers).
  `scripts/studio/dups_session.cfg` (11 steps: a post copied in a row,
  grown and mirrored on two axes into seventeen built brushes; hidden and
  shown; an image at each of two named entities, then at three path
  corners, then made real; a door with two images played as three doors,
  the second opened by firing `door2`).
  `scripts/studio/shapes_session.cfg` (7 steps: stairs with a landing, built
  again taller and of twelve steps where they stand, undone and redone,
  caulked, then freed; a bicone, a torus, crossed walls, a cap, a corner,
  a bevel and a column; and stairs that come caulked with the setting on).
  `scripts/studio/land_session.cfg` (7 steps: a terrain lifted whole by a
  rectangle that takes it in, split along alternate diagonals, given a
  peak and worn down, its tops painted, and freed into plain brushes).
  `scripts/studio/quilt_session.cfg` (6 steps: a curved sheet grown by a
  curve across and a curve up, shrunk by one, made thicker and finer, and
  an endcap added).
  `scripts/studio/controls_session.cfg` (6 steps: a light's slider dragged
  to five hundred, its green bar to half, the third number of its place
  dragged up five grid steps, three edits in all; then a brush's handles
  chosen on the radio, the one box handle among them).
  `scripts/studio/wrap_session.cfg` (6 steps: a box's top given a material,
  slid and tagged; the face beside it takes that material round the edge,
  the next takes it as it lies; fitted in whole repeats; Alt and a drag in
  the plan paints the box's top and the floor; the floor's top put in the
  tagged plane, so the floor rises to it).
  `scripts/studio/settings_session.cfg` (5 steps: K bound to add a column
  and Shift+K a cap, pressed, listed, one unbound; the settings list and
  its line that hides the grid; flat tones and back; the developer's
  readout; then the studio opened again to find the key and settings
  kept).
  `scripts/studio/marks_session.cfg` (6 steps: the player start turned from
  facing +y to +x by the tip of its arrow; a light's reach pulled from two
  hundred units to four hundred; a handle clicked without a drag, which
  changes nothing; two path corners joined by a line; a counter from the
  logic library; a favourite class kept and added).
  `scripts/studio/bake_session.cfg` (5 steps: a hall with a wall across
  its middle opened from a map, cut into thirty cells of which some are
  out of sight of others; played from one side of the wall, 32 faces are
  drawn; built as one again and played from the same place, 42).
  `scripts/studio/steps_session.cfg` (15 steps: the hall's cells shown
  from its west room, its east and where the player start stands; a wall
  moved and the move undone, and a game played and stopped, each given
  the bake kept from before; two recipes kept, listed, run and one
  forgotten; a stand-in compiler run over the map, stopping with its own
  code, and its three complaints, by entity, by brush and by line, each
  gone to).
  `scripts/studio/project_session.cfg` (10 steps: a project made, two
  scenes saved into it, its start, build, bake, material and a recipe set,
  and its manifest read back word for word; an add-on's two classes
  loaded, an entity of one made with its fields and flag in the
  inspector, the add-on read again and dropped; the project asked for
  from the Window menu; closed, and an older project opened with its
  scene and its own add-on, its manifest untouched; a game's material
  and build kept in the settings and the next scene floored with it).
  `scripts/studio/outside_session.cfg` (8 steps: a four-texel image
  fitted to a face; a program kept for `.png` files and another
  forgotten; the material's file opened with it, a stand-in editor that
  puts an eight-texel image in its place, which the studio reads again
  unasked so that the face fits at sixteen units a texel; a right drag
  turning the camera 29 degrees, then 57 and the other way up at twice
  the rate inverted; the wheel moving the camera 64 units forward, then
  128 back).
  `scripts/studio/depth_session.cfg` (10 steps: two boxes drawn, one
  lifted; the top view held to the depths about the floor, with one brush
  outside its band, greyed and still clicked; left out instead, and a
  click where it was going to the floor beneath; the band taken from the
  selection and let go; the top view turned off its axis by command and
  the front by Alt and a right drag; the top straightened by a press on
  its compass and the front by command).
  `scripts/studio/layers_session.cfg` (7 steps: two boxes drawn, each
  kept as a layer and both as a third; one hidden, its box out of the
  views and of what they are built from, and a click where it stood
  finding the floor; the layer of both hidden and the first shown again,
  both boxes staying out of sight; the list of layers; one shown alone;
  the layers that are off written into the saved map; everything shown).
  `scripts/studio/sweep_session.cfg` (6 steps: a square beam along a
  line with one turn; three path corners added and a rail swept along
  them into six brushes; the last corner moved and the rail swept again
  to reach it, then the sweep undone; a drawn brush's outline swept round
  a closed line into a ring of four).
  `scripts/studio/live_session.cfg` (8 steps: a door, a relay that opens
  it and a relay that fires that one; the game played, nothing yet
  fired; the first relay set off by hand, all three counted and the game
  held because the middle one holds it; the player's health and place
  and the middle relay changed while held; fired again, the firing
  stopping at the relay switched off; the counts still there after the
  game, and on the logic graph).
  `scripts/studio/model_session.cfg` (13 steps: an eight-sided cylinder
  made, closed and holding what one would; its top's triangles picked and
  pushed out; a second frame with the model higher in it; every triangle
  cut in four, turned round and that undone; a ball added as a second
  part; the panel's Cut in 4 and Undo buttons clicked; saved as MD3 and
  OBJ; closed, and opened again from the MD3 with both parts and frames).
  `scripts/studio/rig_session.cfg` (10 steps: a cylinder looked down
  on; a click picking a triangle of its top and a click with Shift
  another; a click picking the point on its axis, dragged with Ctrl as
  one step and that undone; two tags, one moved at every frame and one
  at a copied frame only; the copied frame moved to the front; a tag
  dropped; two skins named and one dropped; saved as an MD3 with its
  frames, tag and skin).
  `scripts/studio/drop_session.cfg` (4 steps: the project's image
  dragged from the Materials tab onto one face of a box; a light dragged
  from the Classes tab onto the floor; a prefab dragged from the Library
  tab onto the top of the box).
  `scripts/studio/links_session.cfg` (9 steps: two boxes drawn side by
  side, their four shared planes linked; the top of one pushed and the
  other's rising with it, undone together; the links taken away; a
  cutter drawn across a box and carved with links, the two pieces tied
  on four planes and the map saying so; two walls through one corner cut
  to a seam; a top corner of a box merged onto the one beneath it).
  `scripts/studio/touch_session.cfg` (11 steps: a terrain with a
  terrace of fifteen corners, touched so that all fifteen rise; the four
  cells of the low ground picked as a plot, outlined, lifted and painted;
  a plot picked by Alt and a press in sculpt mode; the top moved up, the
  underside down with the base thicker, and the whole of it up).
  `scripts/studio/games_session.cfg` (6 steps: a health pack and an
  ogre added, each carrying Quake as its game; an armour left with none,
  found by the check, the player start not; filled; a camp spot and a
  roam spot listed; the scene played, with its pickups and its ogre
  spawned).
  `scripts/studio/shader_session.cfg` (7 steps: a shader made in a new
  script; three lines of its own and a stage's `tcMod`s set, a stage
  added and moved to the front; two mistakes made and listed by the
  check, then mended; the script saved, a second shader added, and the
  file opened again as two; a script broken by hand, its five faults
  said by line).
  `scripts/studio/sounds_session.cfg` (3 steps: a stereo sound at 44100
  made one channel at 22050 and 16 bits, and at 11025 and 8; a wall
  texture's flags, value and next frame changed in a copy whose pictures
  are the same bytes; Quake's slipgate texture found to be a row of
  seven).
  `scripts/studio/nest_session.cfg` (5 steps: a post kept as a prefab;
  two linked posts, one with a material swap, and a lintel kept together
  as a gate; the gate linked into an empty scene and built as four
  brushes; the instance given a swap and names of its own; the built map
  written out, with the gate's blockout in brass and the inner post
  still slate).
  `scripts/studio/skin_session.cfg` (7 steps: a cylinder laid flat into
  the left half of its skin, stretched to half, moved, turned a quarter
  and flipped, the flip undone; a picture made and dabbed on the skin; a
  click on the model painting where it lands on the skin; the picture
  shown under the model with the triangles over it, and saved as a TGA
  with the two dabs in it).
  `scripts/studio/preview_session.cfg` (3 steps: the models of e1m1's
  monsters and pickups listed, fifty-four of them, the soldier's and the
  armour's among them; drawn in the 3D view near the camera; turned off
  again, and the choice kept in the settings).
  `scripts/studio/lay_session.cfg` (16 steps: a sheet's material spread
  once and then twice across, slid whole, by its last row, its first
  column and one corner, each read back from the built faces; kept
  through a bend and in the saved map; taken from the tagged top of a
  box; let go when the patch grows a curve and back when that is undone;
  forgotten, and back again).
  `scripts/studio/convert_session.cfg` turns Quake II's base1 (1,750
  brushes) and Quake III's q3dm1 (987) into scenes, saves them as maps and
  reopens them. It tries a generated expedition too and says when the
  expedition itself does not load.

## What remains

Milestones 1 (the shell) and 2 (blockout) of #73 are done, and most of 3
(views and texturing), 4 (brush tools) and 5 (logic and reuse), with parts
of 6, 7 and 9. The checklist in #73 says item by item what exists.

- Left over in what is built: the handles work along the world's axes only
  (not a brush's own); a shipped
  map takes new brushes only once it is turned into a scene; Quake III's
  `brushDef` sides open without their texture alignment, and a level's
  patches are left behind by `ed_convert` (a map file's `patchDef2` patches
  do open, as patches of the scene); a patch mirrored keeps its control points' order, so its
  curve faces the same way round; a linked prefab stands as its file has it (it
  does not turn); the logic graph neither reorders nor shows signals as
  they fire in play; a scene too large for the light budget stays flat.
- Not yet built: the rest of the bake (a partition by the brushes' own
  planes with portals between its leaves, in place of cells of the plan;
  bounced light; bot navigation); patches written back as
  `patchDef2`; bones and weights in the model editor; the Passion tools;
  user walkers.
- Within the shell: generated (Passion) levels can be edited but not saved as
  they are (`ed_convert` is meant to turn one into a scene, but expeditions
  do not load in the test environment at present: #76).
