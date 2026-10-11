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
- **G** changes those handles (`ed_gizmo <move|turn|size|next>`, Brush
  menu), for any selection, a lone brush included:
  - *Rings that turn.* Each ring that faces the view has a knob; taking the
    knob round the ring turns the selection about that ring's axis. The
    axis views show the one ring that faces them, the 3D view all three.
    A turn snaps to 15 degrees (`ed_anglesnap <degrees>`, kept between
    sessions); Ctrl turns by single degrees.
  - *Boxes that size.* A box on each axis stretches the selection along it,
    and a fourth stretches all three at once; a pull as long as the arm
    doubles it. Sizes go in quarters, or freely with Ctrl.
  - While a handle is held the views show the selection as it would be
    left, and say by how much.
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
  scrolling, splitters, tabs, menus and hints, through a recording canvas
  and scripted input.
- `tests/studio_document_tests.jac`: entity lumps round-trip; selection;
  every edit and its undo; any run of edits undone in full restores the
  document.
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
  a brush.
- `tests/studio_select_tests.jac`: sets kept, picked, replaced and dropped;
  a deleted member leaving a set and coming back with undo; sets written
  with the map and read from it; the steps to owner, brushes and
  neighbours; brushes by number; the swap and its undo; what a build is
  made from under each of a group's switches.
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
  `scripts/studio/convert_session.cfg` turns Quake II's base1 (1,750
  brushes) and Quake III's q3dm1 (987) into scenes, saves them as maps and
  reopens them. It tries a generated expedition too and says when the
  expedition itself does not load.

## What remains

Milestones 1 (the shell) and 2 (blockout) of #73 are done, and most of 3
(views and texturing), 4 (brush tools) and 5 (logic and reuse), with parts
of 6, 7 and 9. The checklist in #73 says item by item what exists.

- Left over in what is built: the handles work along the world's axes only
  (not a brush's own, nor the view's), and there is no single handle that
  shears; face-to-face
  tools (tag, glue, wrap a texture round a corner) are not built; a shipped
  map takes new brushes only once it is turned into a scene; Quake III's
  `brushDef` sides open without their texture alignment, and a level's
  patches are left behind by `ed_convert` (a map file's `patchDef2` patches
  do open, as patches of the scene); a patch mirrored keeps its control points' order, so its
  curve faces the same way round; a linked prefab stands as its file has it (it
  does not turn); the logic graph neither reorders nor shows signals as
  they fire in play; a scene too large for the light budget stays flat.
- Not yet built: a solid-colour display mode; the bake proper (partition,
  visibility, bounced light, bot navigation); patches written back as
  `patchDef2`, and texture coordinates per control point; the rest of the
  asset studio (models textured and assembled, sounds played, shader and
  texture authoring); the
  model editor; the Passion tools; user walkers.
- Within the shell: entity previews are boxes rather than the entity's
  model, and generated (Passion) levels can be edited but not saved as
  they are (`ed_convert` is meant to turn one into a scene, but expeditions
  do not load in the test environment at present: #76).
