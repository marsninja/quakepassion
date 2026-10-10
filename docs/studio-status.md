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
  out (16 units, then 64, 256, ...), every fourth line brighter.
- **Scene** (left): the map's entities by class. A click selects, a click on
  a class selects all of it, a double click looks at the entity, and the
  filter narrows the list by class, `targetname` or `target`.
- **Inspector** (right): the selection's fields. Enter sets a field on every
  selected entity, `x` removes it, and the last row adds one.
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
- The inspector shows a brush's material (`ed_material <name>`), size and
  owner, and hands the selected brushes to a new entity (`ed_tie
  func_door`) or back to the world.
- The Materials tab lists the games' textures by where they live: a Quake
  map (`q1:e1m1/tech04_1`), a Quake II folder (`q2:e1u1/metal3_2`), a Quake
  III folder (`q3:textures/base_wall/concrete`). A click gives a material to
  the selected brushes and to new ones. Any other name is a swatch: a colour
  from the name with a line every 64 units and a fainter one every 16.
- Every edit that changes the brushes rebuilds the level at once, so the
  level view is what Play runs. Save writes the scene as a Valve 220 `.map`
  under `QP_SCENES` (default `./scenes`), which other Quake editors open.

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
editor/formats/map.jac       the .map text format, classic and Valve 220
editor/compile/live.jac      a scene's brushes as a level, at once
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
  (`Shift`, `Remove`, `Clone`, `Paint`) visit both.
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
- `tests/studio_compile_tests.jac`: a compiled scene's models, faces and
  entities, and that it prepares as a level that holds the player up.
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
  saved map).

## What remains

Milestones 1 (the shell) and 2 (blockout) of #73 are what this page
describes. Left over from milestone 2: the clipper is a command (no plane
drawn in the view), there is no scaling or free rotation about other axes,
the materials list has no thumbnails, a shipped map cannot take new brushes,
and Quake III's `brushDef` and `patchDef2` blocks are skipped on open. Not
yet built: display modes (the axis views are textured, not wireframe),
texturing tools, the entity class registry behind typed inspector fields, the logic graph panel, prefabs, the
bake, patches and duplicators, the asset studio, the model editor, terrain,
the Passion tools and user walkers. Within the shell: entity previews are
boxes rather than the entity's model, generated (Passion) levels can be
edited but not saved, and a brush entity cannot be duplicated because two
entities cannot share a map model.
