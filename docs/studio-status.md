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
editor/camera.jac            the free camera: rays through the view, points onto it
editor/studio.jac            the workbench: panels, picking, play and stop, the ed_* commands
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
- **Every action is a console command** (`ed_select`, `ed_set`, `ed_new`,
  `ed_play`, ...; `cmdlist ed_` lists them), which is what buttons, menus and
  keys run. `ui_move`, `ui_click`, `ui_drag`, `ui_key`, `ui_type` and
  `ui_sync` script the pointer and keyboard one step a frame, and `ed_exec
  <file>` runs a file of commands, so a script drives the interface exactly
  as a hand does.
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
- `scripts/ui_gallery.jac`: every widget in one window without the engine,
  with a scripted session saved to a screenshot.
- `scripts/studio_smoke.jac`: drives the real studio in `qp` through a
  scripted session and checks the document and the saved overrides.

## What remains

Milestone 1 of #73 (the shell) is what this page describes. Not yet built:
brushes and the document's own geometry, `.map` import and export, transform
gizmos, multiple views and display modes, texturing, the entity class
registry behind typed inspector fields, the logic graph panel, prefabs, the
bake, patches and duplicators, the asset studio, the model editor, terrain,
the Passion tools and user walkers. Within the shell: entity previews are
boxes rather than the entity's model, generated (Passion) levels can be
edited but not saved, and a brush entity cannot be duplicated because two
entities cannot share a map model.
