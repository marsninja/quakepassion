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
- A field that would break the map is refused: an `origin` that is not three
  numbers, an empty `classname`.

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
  new ones. Any other name is a swatch: a colour from the name with a line
  every 64 units and a fainter one every 16.
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
  `ed_dup off` stops them.
- **The leak finder** (Edit > Look for a leak, `ed_leak`): floods from the
  entities through the space the world's brushes leave; when it reaches
  the void, the way it took is drawn in red in every view.

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
editor/classes/registry.jac  entity classes: fields by kind, options by name
editor/assets/materials.jac  materials from the games' archives, by name
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
- `tests/studio_camera_tests.jac`: the ray through a point of the view lands
  back on that point; framing; ray and box.
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
  `scripts/studio/convert_session.cfg` turns Quake II's base1 (1,750
  brushes) and Quake III's q3dm1 (987) into scenes, saves them as maps and
  reopens them. It tries a generated expedition too and says when the
  expedition itself does not load.

## What remains

Milestones 1 (the shell), 2 (blockout) and most of 3 and 4 (views,
texturing, brush tools) and 5 (logic and reuse) of #73 are what this page
describes. Left over from
those: the clipper is a command (no plane drawn in the view), there are no
gizmos for free rotation and scaling, face-to-face tools (tag, glue, wrap a
texture round a corner) are not built, a shipped map cannot take new
brushes, and Quake III's `brushDef` and `patchDef2` blocks are skipped on
open; a linked prefab stands as its file has it (it does not turn), and the
logic graph neither reorders nor shows signals as they fire in play. Not
yet built: a solid-colour display mode, the bake proper (partition,
visibility, bounced light, a leak finder, bot navigation), patches and duplicators, the asset studio, the model
editor, terrain, the Passion tools and user walkers. Within the shell:
entity previews are boxes rather than the entity's model, generated
(Passion) levels can be edited but not saved, and a brush entity cannot be
duplicated because two entities cannot share a map model.
