"""The studio: QuakePassion's editing mode.

`edit` (F8) turns the running game into a document. The level's entities
become a Scene (document/scene.jac), shown in a tree and an inspector built
from the interface toolkit (ui/), and in the level itself as boxes that can be
picked. Play rebuilds the world from the document and hands the window back
to the game; Stop returns to the document as it was left.

Everything the studio does is a console command (`ed_*`), which is what its
buttons, menus and keys run. The `ui_*` commands script the pointer and the
keyboard, so a config file can drive the interface for validation."""
import math;
import os;
import from engine.core.workbench { Workbench, SceneView }
import from engine.core.app { App }
import from engine.console.shell { Shell, quote_command_word }
import from engine.formats.bsp { Model }
import from engine.math.vec3 { Vec3 }
import from engine.input.input { _capture, _release, mouse_captured }
import from engine.world.world { move_to_area }
import from engine.render.renderer { Color, Vector3, DrawCubeWires, DrawLine3D }
import from games.levels { override_path }
import from vendor.raylib {
    def rlDisableDepthTest -> None;  def rlEnableDepthTest -> None;  def rlDrawRenderBatchActive -> None;
}
import from .ui.canvas { ScreenCanvas, Rect, Ink, ink }
import from .ui.input { UiSource, UiStep, script_click, script_drag }
import from .ui.widget { Widget, Stage }
import from .ui.widgets {
    Box,
    Label,
    Header,
    Spacer,
    PushButton,
    TextField,
    Scroll,
    Splitter,
    TreeView,
    TreeRow,
    MenuBar,
    MenuItem,
    ViewArea
}
import from .document.scene { Scene, Item, scene_of }
import from .camera { EditCamera, ray_enters_box }

"""The studio's commands: name, usage, description."""
glob STUDIO_COMMANDS: list[tuple[str, str, str]] = [
    ("edit", "edit", "enter or leave the studio"),
    ("ed_play", "ed_play [here]", "play the document from its start, or from the camera"),
    ("ed_stop", "ed_stop", "stop playing and return to the document"),
    ("ed_select", "ed_select [serial|class:<name>] [add]", "select an entity, a class, or nothing"),
    ("ed_fold", "ed_fold <class>", "open or close a class in the scene list"),
    ("ed_filter", "ed_filter <text>", "show only matching entities in the scene list"),
    ("ed_focus", "ed_focus [serial]", "look at the selection, or at an entity"),
    ("ed_set", "ed_set <key> <value>", "set a field on the selection"),
    ("ed_unset", "ed_unset <key>", "remove a field from the selection"),
    ("ed_add", "ed_add", "add the inspector's new key and value to the selection"),
    ("ed_new", "ed_new [classname]", "add an entity in front of the camera"),
    ("ed_delete", "ed_delete", "delete the selection"),
    ("ed_duplicate", "ed_duplicate", "copy the selection"),
    ("ed_move", "ed_move <dx> <dy> <dz>", "move the selection"),
    ("ed_undo", "ed_undo", "undo the last edit"),
    ("ed_redo", "ed_redo", "redo the edit last undone"),
    ("ed_save", "ed_save", "save the document's entities for this map"),
    ("ed_revert", "ed_revert", "discard every edit and return to the map as shipped"),
    ("ed_cam", "ed_cam <x> <y> <z> [yaw pitch]", "place the camera (angles in degrees)"),
    ("ed_dump", "ed_dump [label]", "print the document's state (after `STEP label`)"),
    ("ed_exec", "ed_exec <file>", "run a file of console commands"),
    ("ui_move", "ui_move <x> <y>", "script: move the pointer"),
    ("ui_click", "ui_click <x> <y> [button]", "script: click"),
    ("ui_double", "ui_double <x> <y>", "script: double click"),
    ("ui_drag", "ui_drag <x0> <y0> <x1> <y1> [button] [frames]", "script: drag"),
    ("ui_wheel", "ui_wheel <amount>", "script: turn the wheel"),
    ("ui_key", "ui_key <name>", "script: press a key"),
    ("ui_type", "ui_type <text>", "script: type text"),
    ("ui_mod", "ui_mod <shift|ctrl|alt> <0|1>", "script: hold or let go a modifier"),
    ("ui_idle", "ui_idle <frames>", "script: let frames pass"),
    ("ui_sync", "ui_sync", "script: wait until the scripted input has played")
];

"""An entity as the level view draws and picks it: its box and colour."""
obj Shape {
    has item: Item,
        low: Vec3,
        high: Vec3,
        tone: Ink;

    def center -> Vec3 {
        return self.low.add(self.high).scale(0.5);
    }
}

"""The colour a class of entity is drawn in."""
def class_tone(classname: str) -> Ink {
    if classname.startswith("monster_") or classname.startswith("misc_explobox") {
        return ink(0xe5484d);
    }
    if classname.startswith("light") {
        return ink(0xf5d90a);
    }
    if classname.startswith("info_player") {
        return ink(0x4cc38a);
    }
    if classname.startswith("trigger_") {
        return ink(0xb36bff);
    }
    if classname.startswith("func_") {
        return ink(0xff7a18);
    }
    if classname.startswith("item_")
        or classname.startswith("weapon_")
        or classname.startswith("ammo_")
        or classname.startswith("key_")
        or classname.startswith("holdable_") {
        return ink(0x4aa3ff);
    }
    if classname.startswith("path_") or classname.startswith("target_") or classname.startswith("info_") {
        return ink(0x38d6d6);
    }
    return ink(0xa39b90);
}

"""An entity's box in the world: a brush entity's is its model's bounds; a
point entity's is sized by what it is. None for the world and for entities
that are nowhere."""
def item_shape(item: Item, models: list[Model]) -> Shape | None {
    classname = item.classname();
    at = item.origin();
    index = item.model();
    if index > 0 and index < len(models) {
        shift = at if at is not None else Vec3();
        return Shape(
            item=item,
            low=models[index].mins.add(shift),
            high=models[index].maxs.add(shift),
            tone=class_tone(classname)
        );
    }
    if at is None or classname == "worldspawn" {
        return None;
    }
    low = Vec3(x=-8.0, y=-8.0, z=-8.0);
    high = Vec3(x=8.0, y=8.0, z=8.0);
    if classname.startswith("monster_") or classname.startswith("info_player") {
        low = Vec3(x=-16.0, y=-16.0, z=-24.0);
        high = Vec3(x=16.0, y=16.0, z=32.0);
    } elif classname.startswith("light") {
        low = Vec3(x=-4.0, y=-4.0, z=-4.0);
        high = Vec3(x=4.0, y=4.0, z=4.0);
    }
    return Shape(item=item, low=at.add(low), high=at.add(high), tone=class_tone(classname));
}

"""The studio's widgets, kept by name so its code can reach them."""
obj StudioUi {
    has menu: MenuBar,
        tree: TreeView,
        search: TextField,
        view: ViewArea,
        form: Box,
        new_class: TextField,
        play: PushButton,
        stop: PushButton,
        save: PushButton,
        undo: PushButton,
        redo: PushButton,
        title: Label,
        hint: Label,
        summary: Label,
        place: Label,
        new_key: TextField | None = None,
        new_value: TextField | None = None;
}

obj Studio(Workbench) {
    has app: App | None = None,
        canvas: ScreenCanvas = ScreenCanvas(),
        stage: Stage | None = None,
        ui: StudioUi | None = None,
        source: UiSource = UiSource(),
        # Frames since the scripted input last had a step to play.
        quiet: int = 0,
        scene: Scene | None = None,
        scenes: dict[str, Scene] = {},
        camera: EditCamera = EditCamera(),
        # A play session started from the document, to return from.
        playing: bool = False,
        restore_mouse: bool = False,
        looking: bool = False,
        panning: bool = False,
        # Dragging the selection in the level: where on its plane the drag
        # began, the height of that plane, and how far it has gone.
        moving: bool = False,
        moved: bool = False,
        move_from: Vec3 = Vec3(),
        move_by: Vec3 = Vec3(),
        press_x: int = 0,
        press_y: int = 0,
        grid: float = 8.0,
        hover: Item | None = None,
        shapes: list[Shape] = [],
        opened: dict[str, bool] = {},
        filter: str = "",
        seen_revision: int = -1,
        seen_picks: int = -1,
        seen_filter: str = "",
        seen_folds: int = 0,
        folds: int = 0,
        note: str = "";

    def declare(shell: Shell) {
        for (name, usage, description) in STUDIO_COMMANDS {
            shell.command(name, "studio", usage, description);
        }
    }

    """Say something: in the console, and in the status bar."""
    def say(message: str) {
        self.note = message;
        app = self.app;
        if app is not None {
            app.shell.print(message);
        }
    }

    # ------------------------------------------------------------------
    # Entering, leaving, playing

    """Take the window: the current level becomes the document."""
    def enter(reset_camera: bool = True) {
        app = self.app;
        if app is None or not app.level.active {
            return;
        }
        self.active = True;
        self.playing = False;
        self.restore_mouse = mouse_captured();
        _release();
        app.controls.release_all();
        level = app.level;
        key = level.bsp.game + "/" + level.name;
        found = self.scenes.get(key);
        if found is None {
            found = scene_of(level.bsp.game, level.name, level.source_entities);
            self.scenes[key] = found;
        }
        self.scene = found;
        self.seen_revision = -1;
        self.seen_picks = -1;
        if self.stage is None {
            self.build();
        }
        if reset_camera {
            player = app.player;
            self.camera.eye = Vec3(
                x=player.pos.x, y=player.pos.y, z=player.pos.z + level.collision.eye_height
            );
            self.camera.yaw = player.yaw;
            self.camera.pitch = player.pitch;
        }
    }

    """Hand the window back to the game as it stands."""
    def leave {
        app = self.app;
        self.active = False;
        self.looking = False;
        stage = self.stage;
        if stage is not None {
            stage.dismiss();
            stage.focus_on(None);
        }
        if app is not None and (self.restore_mouse or app.walking) {
            _capture();
        }
    }

    """Rebuild the world from the document and play it."""
    def play(here: bool) {
        app = self.app;
        scene = self.scene;
        if app is None or scene is None {
            return;
        }
        if scene.game != "passion" {
            app.staged_entities[scene.game + "/" + scene.name] = scene.text();
        }
        self.leave();
        before = app.level;
        app.load_destination(scene.game, scene.name);
        if app.level is before {
            # The document does not load: the host has said why.
            app.menu.opened = False;
            self.enter(reset_camera=False);
            self.say(app.menu.message);
            return;
        }
        self.playing = True;
        if here {
            player = app.player;
            level = app.level;
            player.pos = Vec3(
                x=self.camera.eye.x,
                y=self.camera.eye.y,
                z=self.camera.eye.z - level.collision.eye_height
            );
            player.yaw = self.camera.yaw;
            player.pitch = self.camera.pitch;
            player.velocity = Vec3();
            move_to_area(player, level.areas[level.locate(player.pos)]);
        }
        _capture();
        app.show_notice("Playing from the studio - F8 returns to it");
    }

    """Return from a play session: the world is rebuilt as the document has
    it, and the camera is where it was left."""
    def stop {
        app = self.app;
        scene = self.scene;
        if app is None or scene is None {
            return;
        }
        app.load_destination(scene.game, scene.name);
        self.enter(reset_camera=False);
    }

    """Write the document's entities where the level loader looks for them."""
    def save {
        scene = self.scene;
        if scene is None {
            return;
        }
        if scene.game == "passion" {
            self.say("Generated expeditions cannot be saved yet");
            return;
        }
        path = override_path(scene.game, scene.name);
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as file {
            file.write(scene.text());
        }
        scene.dirty = False;
        self.say("Saved " + path);
    }

    """Forget every edit, saved or not, and reload the map as shipped."""
    def revert {
        app = self.app;
        scene = self.scene;
        if app is None or scene is None {
            return;
        }
        path = override_path(scene.game, scene.name);
        if os.path.isfile(path) {
            os.remove(path);
        }
        key = scene.game + "/" + scene.name;
        app.staged_entities[key] = "";
        self.scenes.pop(key, None);
        app.load_destination(scene.game, scene.name);
        app.staged_entities.pop(key, None);
        self.enter(reset_camera=False);
        self.say("Reverted " + scene.name + " to the map as shipped");
    }

    # ------------------------------------------------------------------
    # The interface

    def build {
        self.canvas.open(os.getenv("QP_UI_FONT", ""));
        stage = Stage(canvas=self.canvas);
        top = Box();
        menu = MenuBar(
            titles=["File", "Edit", "View", "Play"],
            menus=[
                [
                    MenuItem(text="Save entities", command="ed_save", keys="Ctrl+S"),
                    MenuItem(text="Revert to the shipped map", command="ed_revert"),
                    MenuItem(rule=True),
                    MenuItem(text="Leave the studio", command="edit", keys="F8"),
                    MenuItem(text="Quit", command="quit")
                ],
                [
                    MenuItem(text="Undo", command="ed_undo", keys="Ctrl+Z"),
                    MenuItem(text="Redo", command="ed_redo", keys="Ctrl+Y"),
                    MenuItem(rule=True),
                    MenuItem(text="Duplicate", command="ed_duplicate", keys="Ctrl+D"),
                    MenuItem(text="Delete", command="ed_delete", keys="Del"),
                    MenuItem(rule=True),
                    MenuItem(text="Select nothing", command="ed_select", keys="Esc")
                ],
                [
                    MenuItem(text="Look at the selection", command="ed_focus", keys="F"),
                    MenuItem(text="Console", command="toggleconsole", keys="`")
                ],
                [
                    MenuItem(text="Play", command="ed_play", keys="F5"),
                    MenuItem(text="Play from here", command="ed_play here", keys="F6")
                ]
            ]
        );
        top.adopt(menu);

        tools = Box(across=True, pad=4, gap=4, fill="panel");
        top.adopt(tools);
        play = PushButton(
            text="Play", glyph="play", command="ed_play", bold=True, hint="Play the level from its start (F5)"
        );
        tools.adopt(play);
        tools.adopt(
            PushButton(text="From here", glyph="play", command="ed_play here", hint="Play from where the camera is (F6)")
        );
        stop = PushButton(text="Stop", glyph="stop", command="ed_stop", enabled=False, hint="Stop playing (F8)");
        tools.adopt(stop);
        tools.adopt(Spacer(size=10));
        undo = PushButton(text="Undo", command="ed_undo", hint="Undo the last edit (Ctrl+Z)");
        tools.adopt(undo);
        redo = PushButton(text="Redo", command="ed_redo", hint="Redo the edit last undone (Ctrl+Y)");
        tools.adopt(redo);
        tools.adopt(Spacer(size=10));
        new_class = TextField(
            ghost="classname", command="ed_new", size=170, hint="Type a classname and press Enter to add an entity"
        );
        tools.adopt(new_class);
        tools.adopt(PushButton(text="Add entity", command="ed_new", hint="Add an entity in front of the camera"));
        tools.adopt(Spacer(grow=1));
        title = Label(text="", tone="dim");
        tools.adopt(title);
        tools.adopt(Spacer(size=6));
        save = PushButton(text="Save", command="ed_save", hint="Save this map's entities (Ctrl+S)");
        tools.adopt(save);

        body = Box(across=True, grow=1);
        top.adopt(body);
        left = Box(size=280, fill="panel");
        body.adopt(left);
        left.adopt(Header(text="Scene"));
        search_row = Box(pad=4);
        left.adopt(search_row);
        search = TextField(
            ghost="Filter by class or name", command="ed_filter", live=True, hint="Show only matching entities"
        );
        search_row.adopt(search);
        tree = TreeView(
            pick="ed_select",
            toggle="ed_fold",
            open_command="ed_focus",
            grow=1,
            hint="Click selects (Ctrl adds), double click looks at it"
        );
        left.adopt(tree);
        body.adopt(Splitter(target=left, low=160, high=600));
        view = ViewArea(
            grow=1, hint="Right drag + WASD/QE: fly | wheel: dolly | middle drag: pan | click: select | F: look at selection"
        );
        body.adopt(view);
        right = Box(size=320, fill="panel");
        body.adopt(Splitter(target=right, after=True, low=220, high=640));
        body.adopt(right);
        right.adopt(Header(text="Inspector"));
        scroller = Scroll(grow=1);
        right.adopt(scroller);
        form = Box(pad=6, gap=4);
        scroller.adopt(form);

        status = Box(across=True, pad=4, gap=16, fill="header");
        top.adopt(status);
        hint = Label(text="", tone="dim", grow=1, small=True);
        status.adopt(hint);
        summary = Label(text="", tone="text", small=True);
        status.adopt(summary);
        place = Label(text="", tone="dim", small=True);
        status.adopt(place);

        stage.open(top);
        self.stage = stage;
        self.ui = StudioUi(
            menu=menu,
            tree=tree,
            search=search,
            view=view,
            form=form,
            new_class=new_class,
            play=play,
            stop=stop,
            save=save,
            undo=undo,
            redo=redo,
            title=title,
            hint=hint,
            summary=summary,
            place=place
        );
    }

    """Bring the panels in line with the document when it has changed."""
    def refresh {
        scene = self.scene;
        ui = self.ui;
        app = self.app;
        if scene is None or ui is None or app is None {
            return;
        }
        changed = scene.revision != self.seen_revision;
        picked = scene.picks != self.seen_picks;
        listed = changed or picked or self.filter != self.seen_filter or self.folds != self.seen_folds;
        if changed {
            self.shapes = [];
            for item in scene.items() {
                shape = item_shape(item, app.level.bsp.models);
                if shape is not None {
                    self.shapes.append(shape);
                }
            }
        }
        if picked {
            # A selection made in the level opens its class in the list.
            for item in scene.selection() {
                self.opened[item.classname()] = True;
            }
        }
        if listed {
            self.list_scene(scene, ui, reveal=picked);
        }
        if changed or picked {
            self.fill_form(scene, ui);
        }
        self.seen_revision = scene.revision;
        self.seen_picks = scene.picks;
        self.seen_filter = self.filter;
        self.seen_folds = self.folds;

        journal = scene.journal;
        ui.undo.enabled = bool(journal.done);
        ui.redo.enabled = bool(journal.undone);
        ui.undo.hint = "Undo " + journal.done[-1].label + " (Ctrl+Z)" if journal.done else "Nothing to undo";
        ui.redo.hint = "Redo " + journal.undone[-1].label + " (Ctrl+Y)" if journal.undone else "Nothing to redo";
        ui.save.lit = scene.dirty;
        ui.title.text = scene.game.upper() + "  " + scene.name + ("  (edited)" if scene.dirty else "");
        chosen = scene.selection();
        if len(chosen) == 1 {
            ui.summary.text = chosen[0].title() + "  #" + str(chosen[0].serial);
        } elif chosen {
            ui.summary.text = str(len(chosen)) + " entities selected";
        } else {
            ui.summary.text = str(len(scene.items())) + " entities";
        }
        eye = self.camera.eye;
        ui.place.text = str(int(eye.x)) + " " + str(int(eye.y)) + " " + str(int(eye.z));
    }

    """Fill the scene list: a row per class, and under an open class a row
    per entity."""
    def list_scene(scene: Scene, ui: StudioUi, reveal: bool) {
        wanted = self.filter.lower();
        classes: dict[str, list[Item]] = {};
        for item in scene.items() {
            name = item.classname();
            if wanted
                and wanted not in name.lower()
                and wanted not in item.fields.get("targetname", "").lower()
                and wanted not in item.fields.get("target", "").lower() {
                continue;
            }
            if name not in classes {
                classes[name] = [];
            }
            classes[name].append(item);
        }
        names = sorted(classes.keys());
        if "worldspawn" in names {
            names.remove("worldspawn");
            names = ["worldspawn"] + names;
        }
        rows: list[TreeRow] = [];
        first_picked = -1;
        for name in names {
            members = classes[name];
            shown = self.opened.get(name, False) or bool(wanted);
            rows.append(
                TreeRow(key="class:" + name, text=name, branch=True, opened=shown, note=str(len(members)))
            );
            if not shown {
                continue;
            }
            for item in members {
                words = item.fields.get("targetname", "");
                if not words {
                    words = item.fields.get("origin", "");
                }
                if not words {
                    words = item.fields.get("model", name);
                }
                picked = scene.is_selected(item);
                if picked and first_picked < 0 {
                    first_picked = len(rows);
                }
                rows.append(
                    TreeRow(key=str(item.serial), text=words, depth=1, picked=picked, note="#" + str(item.serial))
                );
            }
        }
        ui.tree.rows = rows;
        if reveal and first_picked >= 0 {
            ui.tree.reveal(first_picked);
        }
    }

    """Fill the inspector with the selection's fields."""
    def fill_form(scene: Scene, ui: StudioUi) {
        stage = self.stage;
        form = ui.form;
        if stage is not None {
            held = stage.focus;
            if held is not None and held.parent() is not None and held is not ui.search and held is not ui.new_class
                and held is not ui.view {
                stage.focus_on(None);
            }
        }
        for row in form.kids() {
            row.clear();
        }
        form.clear();
        ui.new_key = None;
        ui.new_value = None;
        chosen = scene.selection();
        if not chosen {
            form.adopt(Label(text="Nothing is selected.", tone="dim"));
            form.adopt(Label(text="Click an entity in the level or the list.", tone="faint", small=True));
            return;
        }
        heading = chosen[0].title() if len(chosen) == 1 else str(len(chosen)) + " entities";
        form.adopt(Label(text=heading, tone="accent"));
        # The class first, then the fields in the order the map has them.
        keys: list[str] = ["classname"];
        for item in chosen {
            for key in item.fields.keys() {
                if key not in keys {
                    keys.append(key);
                }
            }
        }
        for key in keys {
            first = chosen[0].fields.get(key, "");
            same = True;
            for item in chosen {
                if item.fields.get(key, "") != first or key not in item.fields {
                    same = False;
                }
            }
            row = Box(across=True, gap=4);
            form.adopt(row);
            row.adopt(Label(text=key, tone="dim", size=104));
            row.adopt(
                TextField(
                    value=first if same else "",
                    ghost="" if same else "(mixed)",
                    command="ed_set " + quote_command_word(key),
                    grow=1,
                    hint="Enter sets " + key + " on the selection; Escape cancels"
                )
            );
            row.adopt(
                PushButton(text="x", command="ed_unset " + quote_command_word(key), size=22, hint="Remove " + key)
            );
        }
        adder = Box(across=True, gap=4);
        form.adopt(adder);
        new_key = TextField(ghost="new key", size=104, hint="The name of a field to add");
        adder.adopt(new_key);
        new_value = TextField(ghost="value", grow=1, command="ed_add", hint="Enter adds the field");
        adder.adopt(new_value);
        adder.adopt(PushButton(text="+", command="ed_add", size=22, hint="Add the field"));
        ui.new_key = new_key;
        ui.new_value = new_value;
        form.adopt(Spacer(size=6));
        actions = Box(across=True, gap=4);
        form.adopt(actions);
        actions.adopt(PushButton(text="Look at", command="ed_focus", grow=1, hint="Move the camera to the selection (F)"));
        actions.adopt(PushButton(text="Duplicate", command="ed_duplicate", grow=1, hint="Copy the selection (Ctrl+D)"));
        actions.adopt(PushButton(text="Delete", command="ed_delete", grow=1, hint="Delete the selection (Del)"));
    }

    # ------------------------------------------------------------------
    # The frame

    def frame(dt: float, keys: list[str], text: str, shift: bool, ctrl: bool, alt: bool) {
        app = self.app;
        stage = self.stage;
        ui = self.ui;
        if app is None or stage is None or ui is None {
            return;
        }
        if self.source.pending() > 0 {
            self.quiet = 0;
        } else {
            self.quiet += 1;
        }
        input = self.source.read(dt, keys, text, shift, ctrl, alt);
        stage.frame(input, app.renderer.width, app.renderer.height, dt);
        ui.menu.track(stage);
        ui.tree.track(stage);
        self.camera.fov = app.renderer.fov;
        self.steer(dt);
        self.shortcuts(stage.loose_keys, input.shift, input.ctrl);
        # Ahead of anything already waiting, so a script's next line sees
        # what its click did.
        asked = stage.take_commands();
        if asked {
            app.shell.insert_text("\n".join(asked));
        }
        self.refresh();
        hint = stage.hint();
        ui.hint.text = hint if hint else self.note;
        ui.stop.enabled = self.playing;
    }

    """The camera and the pointer in the level view."""
    def steer(dt: float) {
        app = self.app;
        stage = self.stage;
        ui = self.ui;
        scene = self.scene;
        if app is None or stage is None or ui is None or scene is None {
            return;
        }
        input = stage.input;
        for event in ui.view.take() {
            if event.kind == "press" and event.button == 1 {
                self.looking = True;
            } elif event.kind == "press" and event.button == 2 {
                self.panning = True;
            } elif event.kind == "press" and event.button == 0 {
                # A press on something selected starts moving the selection.
                self.moved = False;
                under = self.pick(event.x, event.y);
                if under is not None and scene.is_selected(under) and not (event.ctrl or event.shift) {
                    grabbed = self.shape_of(under);
                    if grabbed is not None {
                        self.moving = True;
                        self.move_by = Vec3();
                        self.move_from = grabbed.center();
                        self.press_x = event.x;
                        self.press_y = event.y;
                    }
                }
            } elif event.kind == "release" {
                if event.button == 1 {
                    self.looking = False;
                }
                if event.button == 2 {
                    self.panning = False;
                }
                if event.button == 0 and self.moving {
                    self.moving = False;
                    shift = self.move_by;
                    self.move_by = Vec3();
                    # A press that travelled is a drag, whether or not it got
                    # as far as a grid step: its end is not a click.
                    self.moved = abs(event.x - self.press_x) + abs(event.y - self.press_y) > 3;
                    if shift.length() > 0.0 {
                        stage.emit(
                            "ed_move " + str(int(shift.x)) + " " + str(int(shift.y)) + " " + str(int(shift.z))
                        );
                    }
                }
            } elif event.kind == "drag" and self.moving {
                self.drag_selection(event.x, event.y, event.shift, event.ctrl);
            } elif event.kind == "drag" {
                if self.looking {
                    self.camera.turn(-float(event.dx) * 0.005, -float(event.dy) * 0.005);
                } elif self.panning {
                    scale = 1.0 if not event.shift else 4.0;
                    self.camera.eye = self.camera.eye.sub(self.camera.right().scale(float(event.dx) * scale)).add(
                        self.camera.up().scale(float(event.dy) * scale)
                    );
                }
            } elif event.kind == "wheel" {
                self.camera.fly(event.wheel * (256.0 if event.shift else 64.0), 0.0, 0.0);
            } elif event.kind == "click" and event.button == 0 {
                if self.moved {
                    # The end of a drag is not a click.
                    self.moved = False;
                    continue;
                }
                found = self.pick(event.x, event.y);
                words = "ed_select";
                if found is not None {
                    words += " " + str(found.serial);
                }
                if event.ctrl or event.shift {
                    words += " add" if found is not None else "";
                    if found is None {
                        continue;
                    }
                }
                stage.emit(words);
            }
        }
        if stage.held is not ui.view {
            self.looking = False;
            self.panning = False;
            self.moving = False;
        }
        if self.looking and not self.source.scripted {
            speed = app.host.flyspeed.number * (4.0 if input.shift else 1.0) * dt;
            keyboard = app.keyboard;
            ahead = (1.0 if keyboard.is_down("w") else 0.0) - (1.0 if keyboard.is_down("s") else 0.0);
            side = (1.0 if keyboard.is_down("d") else 0.0) - (1.0 if keyboard.is_down("a") else 0.0);
            rise = (1.0 if keyboard.is_down("e") else 0.0) - (1.0 if keyboard.is_down("q") else 0.0);
            self.camera.fly(ahead * speed, side * speed, rise * speed);
        }
        self.hover = None;
        if stage.hover is ui.view and not self.looking and not self.panning and not self.moving {
            self.hover = self.pick(input.x, input.y);
        }
    }

    """The keys no field took."""
    def shortcuts(keys: list[str], shift: bool, ctrl: bool) {
        stage = self.stage;
        if stage is None {
            return;
        }
        for key in keys {
            if key == "F8" {
                stage.emit("edit");
            } elif key == "F5" {
                stage.emit("ed_play");
            } elif key == "F6" {
                stage.emit("ed_play here");
            } elif key == "ESCAPE" {
                if len(stage.layers()) > 1 {
                    stage.dismiss();
                } else {
                    stage.emit("ed_select");
                }
            } elif ctrl and key == "z" {
                stage.emit("ed_redo" if shift else "ed_undo");
            } elif ctrl and key == "y" {
                stage.emit("ed_redo");
            } elif ctrl and key == "s" {
                stage.emit("ed_save");
            } elif ctrl and key == "d" {
                stage.emit("ed_duplicate");
            } elif self.looking {
                # Flying: the letter keys move the camera.
                continue;
            } elif key == "DEL" or key == "BACKSPACE" {
                stage.emit("ed_delete");
            } elif key == "f" {
                stage.emit("ed_focus");
            } elif key in ["LEFTARROW", "RIGHTARROW", "UPARROW", "DOWNARROW", "PGUP", "PGDN"] {
                step = 64 if shift else 16;
                moves = {
                    "LEFTARROW": "0 " + str(step) + " 0",
                    "RIGHTARROW": "0 " + str(-step) + " 0",
                    "UPARROW": str(step) + " 0 0",
                    "DOWNARROW": str(-step) + " 0 0",
                    "PGUP": "0 0 " + str(step),
                    "PGDN": "0 0 " + str(-step)
                };
                stage.emit("ed_move " + moves[key]);
            }
        }
    }

    def shape_of(item: Item) -> Shape | None {
        for shape in self.shapes {
            if shape.item is item {
                return shape;
            }
        }
        return None;
    }

    """Where the line of sight through a point of the view meets the plane
    that faces the camera through `anchor`."""
    def on_view_plane(x: int, y: int, anchor: Vec3) -> Vec3 {
        eye = self.camera.eye;
        ahead = self.camera.forward();
        along = self.camera.ray(self.view_area(), x, y);
        closing = along.dot(ahead);
        if closing < 0.001 {
            return anchor;
        }
        return eye.add(along.scale(anchor.sub(eye).dot(ahead) / closing));
    }

    """Follow the pointer with the selection, as seen: it moves in the plane
    that faces the camera, so looking down drags it across the floor and
    looking level drags it sideways and up. Shift keeps the move to the axis
    it has gone furthest along; moves snap to the grid unless Ctrl is held."""
    def drag_selection(x: int, y: int, one_axis: bool, free: bool) {
        start = self.on_view_plane(self.press_x, self.press_y, self.move_from);
        now = self.on_view_plane(x, y, self.move_from);
        shift = now.sub(start);
        if one_axis {
            if abs(shift.x) >= abs(shift.y) and abs(shift.x) >= abs(shift.z) {
                shift = Vec3(x=shift.x);
            } elif abs(shift.y) >= abs(shift.z) {
                shift = Vec3(y=shift.y);
            } else {
                shift = Vec3(z=shift.z);
            }
        }
        step = 1.0 if free else self.grid;
        self.move_by = Vec3(
            x=float(round(shift.x / step)) * step,
            y=float(round(shift.y / step)) * step,
            z=float(round(shift.z / step)) * step
        );
    }

    """The level view's rectangle on screen."""
    def view_area -> Rect {
        ui = self.ui;
        return ui.view.area if ui is not None else Rect();
    }

    """The entity under a point of the level view: the nearest whose box the
    line of sight enters before it meets a wall."""
    def pick(x: int, y: int) -> Item | None {
        app = self.app;
        if app is None {
            return None;
        }
        eye = self.camera.eye;
        along = self.camera.ray(self.view_area(), x, y);
        tried: list[Item] = [];
        for attempt in range(6) {
            best: Shape | None = None;
            reach = 1000000.0;
            for shape in self.shapes {
                if shape.item in tried {
                    continue;
                }
                enters = ray_enters_box(eye, along, shape.low, shape.high);
                # A box the camera is inside is not something to click on.
                if enters > 0.0 and enters < reach {
                    reach = enters;
                    best = shape;
                }
            }
            if best is None {
                return None;
            }
            trace = app.level.collision.trace_point(eye, eye.add(along.scale(reach)));
            # A camera inside a wall sees through it, so nothing is hidden.
            if trace.start_solid or trace.fraction >= 1.0 or reach * (1.0 - trace.fraction) < 8.0 {
                return best.item;
            }
            tried.append(best.item);
        }
        return None;
    }

    # ------------------------------------------------------------------
    # Drawing

    def views -> list[SceneView] {
        area = self.view_area();
        if area.w <= 0 or area.h <= 0 {
            return [];
        }
        return [
            SceneView(
                x=area.x,
                y=area.y,
                width=area.w,
                height=area.h,
                eye=self.camera.eye,
                yaw=self.camera.yaw,
                pitch=self.camera.pitch,
                everything=True
            )
        ];
    }

    def draw_scene(view: SceneView) {
        scene = self.scene;
        if scene is None {
            return;
        }
        chosen: list[Shape] = [];
        for shape in self.shapes {
            if scene.is_selected(shape.item) {
                chosen.append(shape);
            } else {
                wire_box(shape.low, shape.high, shape.tone.faded(200));
            }
        }
        # The selection, what it targets and what is pointed at show through
        # the walls.
        rlDrawRenderBatchActive();
        rlDisableDepthTest();
        for shape in chosen {
            if self.moving {
                # Where the drag would leave it, over where it is.
                wire_box(shape.low.add(self.move_by), shape.high.add(self.move_by), ink(0xff7a18));
            }
            wire_box(shape.low, shape.high, ink(0xffffff));
            target = shape.item.fields.get("target", "");
            name = shape.item.fields.get("targetname", "");
            for other in self.shapes {
                if other.item is shape.item {
                    continue;
                }
                if target and other.item.fields.get("targetname", "") == target {
                    wire_line(shape.center(), other.center(), ink(0x4cc38a));
                    wire_box(other.low, other.high, ink(0x4cc38a));
                }
                if name and other.item.fields.get("target", "") == name {
                    wire_line(other.center(), shape.center(), ink(0xf5d90a));
                    wire_box(other.low, other.high, ink(0xf5d90a));
                }
            }
        }
        hovered = self.hover;
        if hovered is not None and not scene.is_selected(hovered) {
            for shape in self.shapes {
                if shape.item is hovered {
                    wire_box(shape.low, shape.high, shape.tone);
                }
            }
        }
        rlDrawRenderBatchActive();
        rlEnableDepthTest();
    }

    def draw(width: int, height: int) {
        stage = self.stage;
        scene = self.scene;
        if stage is None or scene is None {
            return;
        }
        stage.paint();
        # Names over the selection and over what the pointer is on.
        area = self.view_area();
        canvas = self.canvas;
        canvas.clip(area);
        for shape in self.shapes {
            picked = scene.is_selected(shape.item);
            if not picked and shape.item is not self.hover {
                continue;
            }
            top = Vec3(x=shape.center().x, y=shape.center().y, z=shape.high.z);
            at = self.camera.project(area, top);
            if at is None {
                continue;
            }
            words = shape.item.title();
            wide = canvas.text_width(words, canvas.theme.small) + 8;
            tag = Rect(x=at[0] - wide // 2, y=at[1] - 20, w=wide, h=16);
            canvas.fill(tag, canvas.theme.header.faded(210));
            canvas.label(
                words, tag, canvas.theme.text if picked else canvas.theme.dim, 0, 0, canvas.theme.small
            );
        }
        canvas.unclip();
    }

    # ------------------------------------------------------------------
    # Commands

    def command(args: list[str]) {
        app = self.app;
        if app is None or not args {
            return;
        }
        name = args[0];
        if name == "edit" {
            if self.active {
                self.leave();
            } elif self.playing {
                self.stop();
            } else {
                self.enter();
            }
            return;
        }
        if name == "ed_stop" {
            if self.playing {
                self.stop();
            }
            return;
        }
        if name == "ed_exec" {
            if len(args) > 1 and os.path.isfile(args[1]) {
                with open(args[1], "r") as file {
                    app.shell.insert_text(file.read());
                }
            } else {
                self.say("ed_exec: no such file");
            }
            return;
        }
        if name.startswith("ui_") {
            self.script(args);
            return;
        }
        scene = self.scene;
        if not self.active or scene is None {
            self.say(name + ": the studio is not open (edit opens it)");
            return;
        }
        if name == "ed_play" {
            self.play(len(args) > 1 and args[1] == "here");
        } elif name == "ed_select" {
            self.select(scene, args);
        } elif name == "ed_fold" {
            if len(args) > 1 {
                group = args[1][6:] if args[1].startswith("class:") else args[1];
                self.opened[group] = not self.opened.get(group, False);
                self.folds += 1;
            }
        } elif name == "ed_filter" {
            self.filter = args[1] if len(args) > 1 else "";
        } elif name == "ed_focus" {
            self.focus(scene, args);
        } elif name == "ed_set" {
            if len(args) > 2 {
                reason = scene.refuses(args[1], args[2]);
                if reason {
                    self.say(reason);
                    # The inspector shows what the document still has.
                    self.seen_revision = -1;
                } else {
                    scene.set_field(args[1], args[2]);
                }
            }
        } elif name == "ed_unset" {
            if len(args) > 1 and not scene.unset_field(args[1]) {
                self.say("Cannot remove " + args[1]);
            }
        } elif name == "ed_add" {
            ui = self.ui;
            if ui is not None {
                new_key = ui.new_key;
                new_value = ui.new_value;
                if new_key is not None and new_value is not None and new_key.text_now().strip() {
                    reason = scene.refuses(new_key.text_now().strip(), new_value.text_now());
                    if reason {
                        self.say(reason);
                    } else {
                        scene.set_field(new_key.text_now().strip(), new_value.text_now());
                    }
                }
            }
        } elif name == "ed_new" {
            self.create(scene, args);
        } elif name == "ed_delete" {
            if not scene.remove_selection() {
                self.say("Nothing to delete");
            }
        } elif name == "ed_duplicate" {
            if not scene.clone_selection(Vec3(x=32.0)) {
                self.say("Nothing to duplicate (brush entities cannot be copied)");
            }
        } elif name == "ed_move" {
            if len(args) > 3 {
                scene.shift_selection(Vec3(x=float(args[1]), y=float(args[2]), z=float(args[3])));
            }
        } elif name == "ed_undo" {
            label = scene.undo();
            self.say("Undid " + label if label else "Nothing to undo");
        } elif name == "ed_redo" {
            label = scene.redo();
            self.say("Redid " + label if label else "Nothing to redo");
        } elif name == "ed_save" {
            self.save();
        } elif name == "ed_revert" {
            self.revert();
        } elif name == "ed_cam" {
            if len(args) > 3 {
                self.camera.eye = Vec3(x=float(args[1]), y=float(args[2]), z=float(args[3]));
            }
            if len(args) > 5 {
                self.camera.yaw = math.radians(float(args[4]));
                self.camera.pitch = math.radians(float(args[5]));
            }
        } elif name == "ed_dump" {
            if len(args) > 1 {
                print("STEP " + args[1]);
            }
            self.dump(scene);
        }
    }

    def select(scene: Scene, args: list[str]) {
        add = len(args) > 2 and args[2] == "add";
        if len(args) < 2 {
            scene.select(None);
            return;
        }
        if args[1].startswith("class:") {
            wanted = args[1][6:];
            if not add {
                scene.clear_selection();
            }
            for item in scene.items() {
                if item.classname() == wanted and not scene.is_selected(item) {
                    scene.select(item, add=True);
                }
            }
            return;
        }
        if args[1].isdigit() {
            found = scene.find(int(args[1]));
            if found is not None {
                scene.select(found, add=add);
                return;
            }
        }
        self.say("ed_select: no entity " + args[1]);
    }

    """Look at an entity, or at the whole selection."""
    def focus(scene: Scene, args: list[str]) {
        wanted: list[Item] = scene.selection();
        if len(args) > 1 and args[1].isdigit() {
            found = scene.find(int(args[1]));
            if found is not None {
                wanted = [found];
                if not scene.is_selected(found) {
                    scene.select(found);
                }
            }
        }
        low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
        high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
        seen = 0;
        for shape in self.shapes {
            if shape.item in wanted {
                low = Vec3(x=min(low.x, shape.low.x), y=min(low.y, shape.low.y), z=min(low.z, shape.low.z));
                high = Vec3(x=max(high.x, shape.high.x), y=max(high.y, shape.high.y), z=max(high.z, shape.high.z));
                seen += 1;
            }
        }
        if seen == 0 {
            self.say("Nothing to look at");
            return;
        }
        self.camera.frame(low.add(high).scale(0.5), high.sub(low).length() * 0.5);
    }

    """Add an entity where the camera looks: against the wall ahead, or a
    little way in front."""
    def create(scene: Scene, args: list[str]) {
        app = self.app;
        ui = self.ui;
        if app is None or ui is None {
            return;
        }
        classname = args[1].strip() if len(args) > 1 else ui.new_class.text_now().strip();
        if not classname {
            self.say("Type a classname first");
            return;
        }
        eye = self.camera.eye;
        ahead = self.camera.forward();
        trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(192.0)));
        at = eye.add(ahead.scale(max(32.0, 192.0 * trace.fraction - 24.0)));
        scene.create(classname, Vec3(x=float(round(at.x)), y=float(round(at.y)), z=float(round(at.z))));
        self.say("Added " + classname);
    }

    def dump(scene: Scene) {
        eye = self.camera.eye;
        lines = [
            "studio: "
                + scene.game
                + "/"
                + scene.name
                + " entities="
                + str(len(scene.items()))
                + " dirty="
                + ("1" if scene.dirty else "0")
                + " undo="
                + str(len(scene.journal.done))
                + " redo="
                + str(len(scene.journal.undone)),
            "studio: camera " + str(int(eye.x)) + " " + str(int(eye.y)) + " " + str(int(eye.z)),
            "studio: view " + str(self.view_area().x) + " " + str(self.view_area().y) + " "
                + str(self.view_area().w) + " " + str(self.view_area().h)
        ];
        for item in scene.selection() {
            pairs = " ".join([key + "=" + value for (key, value) in item.fields.items()]);
            lines.append("studio: selected #" + str(item.serial) + " " + pairs);
        }
        app = self.app;
        for line in lines {
            print(line);
            if app is not None {
                app.shell.print(line);
            }
        }
    }

    """The ui_* commands: queue scripted input."""
    def script(args: list[str]) {
        app = self.app;
        if app is None {
            return;
        }
        name = args[0];
        numbers: list[int] = [];
        for word in args[1:] {
            if word.lstrip("-").isdigit() {
                numbers.append(int(word));
            }
        }
        if name == "ui_sync" {
            # Hold the rest of the script until the scripted input has played
            # and a few frames have drawn what it did.
            if self.active and (self.source.pending() > 0 or self.quiet < 3) {
                app.shell.insert_text("wait\nui_sync");
            }
            return;
        }
        if name == "ui_move" and len(numbers) >= 2 {
            self.source.script(UiStep(kind="move", x=numbers[0], y=numbers[1]));
        } elif name == "ui_click" and len(numbers) >= 2 {
            script_click(self.source, numbers[0], numbers[1], numbers[2] if len(numbers) > 2 else 0);
        } elif name == "ui_double" and len(numbers) >= 2 {
            script_click(self.source, numbers[0], numbers[1], 0, True);
        } elif name == "ui_drag" and len(numbers) >= 4 {
            script_drag(
                self.source,
                numbers[0],
                numbers[1],
                numbers[2],
                numbers[3],
                numbers[4] if len(numbers) > 4 else 0,
                numbers[5] if len(numbers) > 5 else 6
            );
        } elif name == "ui_wheel" and len(args) > 1 {
            self.source.script(UiStep(kind="wheel", amount=float(args[1])));
        } elif name == "ui_key" and len(args) > 1 {
            self.source.script(UiStep(kind="key", words=args[1]));
        } elif name == "ui_type" and len(args) > 1 {
            self.source.script(UiStep(kind="type", words=" ".join(args[1:])));
        } elif name == "ui_mod" and len(args) > 2 {
            self.source.script(UiStep(kind=args[1], button=1 if args[2] != "0" else 0));
        } elif name == "ui_idle" {
            for _ in range(numbers[0] if numbers else 1) {
                self.source.script(UiStep(kind="idle"));
            }
        }
        self.quiet = 0;
    }
}

def:priv wire_color(color: Ink) -> Color {
    return Color(r=u8(color.r), g=u8(color.g), b=u8(color.b), a=u8(color.a));
}

"""A box's twelve edges, in the level."""
def wire_box(low: Vec3, high: Vec3, color: Ink) {
    DrawCubeWires(
        Vector3(x=f32((low.x + high.x) * 0.5), y=f32((low.y + high.y) * 0.5), z=f32((low.z + high.z) * 0.5)),
        f32(high.x - low.x),
        f32(high.y - low.y),
        f32(high.z - low.z),
        wire_color(color)
    );
}

def wire_line(start: Vec3, finish: Vec3, color: Ink) {
    DrawLine3D(
        Vector3(x=f32(start.x), y=f32(start.y), z=f32(start.z)),
        Vector3(x=f32(finish.x), y=f32(finish.y), z=f32(finish.z)),
        wire_color(color)
    );
}

"""Give an App its studio."""
def attach_studio(app: App) -> Studio {
    studio = Studio(app=app);
    app.workbench = studio;
    return studio;
}
