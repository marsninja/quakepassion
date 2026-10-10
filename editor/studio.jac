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
import from engine.formats.bsp { Model, Bsp, MapEntity, Texture }
import from engine.math.vec3 { Vec3, forward_from, right_from }
import from engine.input.input { _capture, _release, mouse_captured }
import from engine.world.world { move_to_area }
import from engine.render.renderer { Color, Vector3, DrawCubeWires, DrawLine3D }
import from games.levels { override_path }
import from vendor.raylib {
    def rlDisableDepthTest -> None;  def rlEnableDepthTest -> None;  def rlDrawRenderBatchActive -> None;
}
import from .ui.canvas { ScreenCanvas, Rect, Ink, ink }
import from .ui.input { UiSource, UiStep, script_click, script_drag }
import from .ui.widget { Widget, Stage, UiEvent }
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
    Tabs,
    MenuBar,
    MenuItem,
    ViewArea,
    Gallery,
    Tile,
    GraphView,
    GraphNode,
    GraphLink,
    Dropdown,
    Swatch,
    Check,
    Picture
}
import from .assets.explorer { AssetIndex, AssetLook }
import from .formats.archive { write_pak, write_zip, file_kind }
import from .classes.registry { ClassInfo, FieldInfo, class_info, class_names, class_family, field_of, flag_set }
import from .geometry.shapes { shape_brushes, SHAPE_KINDS }
import from .compile.light { bake_light }
import from .compile.leak { find_leak, LeakReport }
import from .formats.bspmap { bsp_items }
import from .document.generate { duplicates, image_brushes, with_images, DUPLICATOR_KEYS }
import from .document.scene {
    Scene,
    Item,
    Solid,
    FaceEdit,
    FacePick,
    Finding,
    read_vector,
    scene_of,
    scene_map,
    scene_from_map
}
import from .geometry.csg { brush_corners, brush_edges }
import from .camera { EditCamera, ray_enters_box, axis_camera }
import from .compile.live { compile_scene, LiveLevel, Materials, SwatchMaterials, swatch_texture }
import from .assets.materials { ArchiveMaterials, small_picture }
import from engine.core.menu { game_directory }
import from .formats.map { read_map, write_map, MapItem, MapFile }
import from .geometry.brush { brush_windings, windings_bounds, Side }
import from .geometry.brush { box_sides, cylinder_sides, wedge_sides, ray_enters_brush, Plane3 }

"""The studio's commands: name, usage, description."""
glob STUDIO_COMMANDS: list[tuple[str, str, str]] = [
    ("edit", "edit", "enter or leave the studio"),
    ("ed_play", "ed_play [here]", "play the document from its start, or from the camera"),
    ("ed_stop", "ed_stop", "stop playing and return to the document"),
    (
        "ed_select",
        "ed_select [serial|solid:<n>|class:<name>|material:<name>|all|brushes|entities|invert] [add]",
        "select an entity, a brush, a class, everything of a kind, the rest, or nothing"
    ),
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
    ("ed_scene", "ed_scene [name]", "start a new scene of brushes"),
    ("ed_open", "ed_open <file.map>", "open a map file as a scene"),
    ("ed_save_as", "ed_save_as <file.map>", "save the scene to another file"),
    ("ed_box", "ed_box [width depth height]", "add a box brush where the camera looks"),
    ("ed_cylinder", "ed_cylinder [width depth height sides]", "add an upright prism of that many sides"),
    ("ed_wedge", "ed_wedge [width depth height]", "add a ramp rising toward +y"),
    ("ed_clip", "ed_clip <x|y|z> <coordinate> [back|front|both]", "cut the selected brushes along a plane"),
    ("ed_rotate", "ed_rotate [degrees] [x|y|z]", "turn the selection about its middle (90 about z without words)"),
    ("ed_mirror", "ed_mirror <x|y|z>", "mirror the selection along an axis through its middle"),
    ("ed_resize", "ed_resize <fx> [fy fz]", "stretch the selection about its middle by a factor along each axis"),
    ("ed_carve", "ed_carve", "cut the selected brushes out of every other brush they reach"),
    ("ed_intersect", "ed_intersect", "replace the selected brushes with what they all share"),
    ("ed_hollow", "ed_hollow [thickness]", "turn the selected brushes into shells of walls (16 thick)"),
    ("ed_merge", "ed_merge", "join the selected brushes into one, when together they are convex"),
    ("ed_mode", "ed_mode <brush|face|corner>", "what a click in the level picks, and which handles a brush shows"),
    ("ed_face", "ed_face <brush> <side> [add]", "select a face of a brush"),
    (
        "ed_tex",
        "ed_tex <shift|shiftto|scale|turn|turnto|fit|flat|reset> [a] [b]",
        "change how the material lies on the selected faces, or on every side of the selected brushes"
    ),
    ("ed_pickmat", "ed_pickmat [brush side]", "take the material of a face as the one new brushes and faces get"),
    ("ed_boxselect", "ed_boxselect <view> <x0> <y0> <x1> <y1> [add]", "select what lies in a rectangle of a view"),
    ("ed_corner", "ed_corner <dx> <dy> <dz> <x> <y> <z> [...]", "move the corners of the selected brush at those points"),
    ("ed_display", "ed_display <wire|textured> [3d|axis|all]", "draw views as edges or textured (the axis views without a word)"),
    ("ed_check", "ed_check [number]", "list what is wrong with the document, or select the thing a finding is about"),
    ("ed_shelf", "ed_shelf <group>", "show a group's materials in the materials tab"),
    ("ed_material", "ed_material <name> [side]", "set the material of the selected brushes, and of new ones"),
    ("ed_push", "ed_push <side> <distance>", "move one side of the selected brush along its normal"),
    ("ed_tie", "ed_tie [classname]", "hand the selected brushes to a new entity, or back to the world"),
    ("ed_matfilter", "ed_matfilter <text>", "show only matching materials in the materials list"),
    (
        "ed_layout",
        "ed_layout <1|4|logic|assets>",
        "one level view, four (3D, top, front and side), the logic graph, or the asset explorer"
    ),
    ("ed_asset", "ed_asset <dir:game:folder|file:game:name>", "open or close a folder of the explorer, or show a file"),
    ("ed_extract", "ed_extract [folder]", "write the file the explorer shows to disk"),
    (
        "ed_pack",
        "ed_pack <folder|scene> <out.pak|out.pk3>",
        "pack a folder's files, or the scene with the textures it uses, into an archive"
    ),
    ("ed_copy", "ed_copy", "copy the selection (as map text)"),
    ("ed_cut", "ed_cut", "copy the selection and delete it"),
    ("ed_paste", "ed_paste [here]", "paste what was copied: beside where it was, or where the camera looks"),
    ("ed_group", "ed_group [name]", "hold the selected brushes together as a group"),
    (
        "ed_prefab",
        "ed_prefab <save|add|link|unlink> [name]",
        "keep the selection as a prefab, add a copy of one, place a linked one, or turn linked ones into copies"
    ),
    ("ed_import", "ed_import <file.map> [group]", "add a map file's entities and brushes to the scene"),
    ("ed_library", "ed_library [row]", "list the saved scenes and prefabs, or open the one a row names"),
    (
        "ed_shape",
        "ed_shape <cone|pyramid|ball|dome|stairs|spiral|arch|pipe> [w d h] [count] [thickness]",
        "add a shape built of brushes where the camera looks"
    ),
    ("ed_class", "ed_class <classname>", "add an entity of a class, or make the selected brushes one"),
    ("ed_classfilter", "ed_classfilter <text>", "show only matching classes in the class list"),
    ("ed_flag", "ed_flag <bit> <0|1>", "clear or set one of the selection's spawnflags (bit 0 is the value 1)"),
    ("ed_bump", "ed_bump <key> <amount>", "add to a number field of the selection"),
    ("ed_light", "ed_light <on|off>", "light scenes from their own lights, or leave them flat"),
    ("ed_convert", "ed_convert", "turn the level being looked at into a scene of its own brushes"),
    ("ed_leak", "ed_leak [clear]", "look for a way from the entities out to the void, and draw it"),
    (
        "ed_dup",
        "ed_dup <copies> <dx> <dy> <dz> [turn] | mirror <x|y|z> | off | apply",
        "make the selected group build copies of itself, stop it, or make the copies real"
    ),
    ("ed_link", "ed_link <from> <to>", "make one entity fire another"),
    ("ed_unlink", "ed_unlink <from> [to]", "stop an entity firing another, or anything"),
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

"""A brush as the level view draws and picks it: its outlines and the box
around them."""
obj SolidLook {
    has solid: Solid,
        outlines: list[list[Vec3]],
        low: Vec3,
        high: Vec3;

    def center -> Vec3 {
        return self.low.add(self.high).scale(0.5);
    }
}

"""What is under a point of the level view: an entity or a brush (and which
of its sides), and how far away."""
obj Aim {
    has item: Item | None = None,
        solid: Solid | None = None,
        side: int = -1,
        reach: float = -1.0;
}

"""One view of the level: the part of the window it shows through, and the
camera it looks with. The first is the free 3D camera; the others look along
an axis."""
obj Port {
    has view: ViewArea,
        camera: EditCamera,
        title: str = "3D";
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
        materials: TreeView,
        gallery: Gallery,
        checks: TreeView,
        library: TreeView,
        classes: TreeView,
        assets: TreeView,
        asset_box: Box,
        asset_form: Box,
        logic: GraphView,
        prefab_name: TextField,
        modes: list[PushButton],
        center: Box,
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
        # The free 3D camera, the level views, and the one the pointer is in:
        # `camera` is that view's, which the pointer's code looks through.
        main: EditCamera = EditCamera(),
        camera: EditCamera = EditCamera(),
        ports: list[Port] = [],
        port_now: int = 0,
        layout: int = 1,
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
        # Scenes of brushes: where their materials come from, what the scene
        # last compiled to, and the document's geometry count it was built at.
        materials: Materials = SwatchMaterials(),
        # The same, when the games' archives are at hand, for listing them.
        archive: ArchiveMaterials | None = None,
        material_filter: str = "",
        materials_shown: int = -1,
        materials_changed: int = 0,
        live: LiveLevel | None = None,
        built_geometry: int = -1,
        looks: list[SolidLook] = [],
        hover_solid: Solid | None = None,
        material: str = "blockout",
        # Dragging a side of the selected brush by its handle.
        resizing: bool = False,
        resize_side: int = -1,
        resize_by: float = 0.0,
        grid: float = 8.0,
        # What a click picks: "brush" (and entities), "face" or "corner".
        mode: str = "brush",
        hover_side: int = -1,
        # Views drawn as edges: the axis views, the 3D view.
        wire_axis: bool = False,
        wire_main: bool = False,
        bare_now: bool = False,
        # A rectangle dragged out over a view, to select what is in it.
        boxing: bool = False,
        box_port: int = 0,
        # How far a dragged corner or edge has gone.
        corner_by: Vec3 = Vec3(),
        # The group the materials tab shows, and pictures still to load.
        shelf: str = "",
        thumbs: list[str] = [],
        findings: list[Finding] = [],
        # The logic graph in place of the level views.
        logic_shown: bool = False,
        logic_seen: int = -1,
        # What was last copied, as map text.
        clip: str = "",
        # Scenes lit from their own lights, and how many samples the last was.
        lit: bool = True,
        lit_samples: int = 0,
        # The asset explorer in place of the level views: the games' files,
        # which folders are open, and the file being shown.
        assets_shown: bool = False,
        asset_index: AssetIndex | None = None,
        asset_now: AssetLook | None = None,
        assets_listed: int = -1,
        # The way out the leak finder last found.
        leak: list[Vec3] = [],
        class_filter: str = "",
        classes_seen: str = "",
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
            self.main.eye = Vec3(
                x=player.pos.x, y=player.pos.y, z=player.pos.z + level.collision.eye_height
            );
            self.main.yaw = player.yaw;
            self.main.pitch = player.pitch;
            for port in self.ports[1:] {
                port.camera.eye = self.main.eye;
            }
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

    """Load a level on the studio's behalf. Commands still waiting (the rest
    of a script) are held back until it is loaded: a load that changes game
    runs that game's configuration, and with it everything waiting. False
    when the level did not load; the host has said why."""
    def load(game: str, name: str, quiet: bool = False) -> bool {
        app = self.app;
        if app is None {
            return False;
        }
        waiting = app.shell.pending;
        app.shell.pending = "";
        before = app.level;
        app.quiet_load = quiet;
        app.load_destination(game, name);
        app.quiet_load = False;
        app.shell.add_text(waiting);
        if app.level is before {
            app.menu.opened = False;
            self.say(app.menu.message);
            return False;
        }
        return True;
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
        if not self.load(scene.game, scene.name) {
            # The document does not load: back to it.
            self.enter(reset_camera=False);
            return;
        }
        self.playing = True;
        if here {
            player = app.player;
            level = app.level;
            player.pos = Vec3(
                x=self.main.eye.x,
                y=self.main.eye.y,
                z=self.main.eye.z - level.collision.eye_height
            );
            player.yaw = self.main.yaw;
            player.pitch = self.main.pitch;
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
        self.load(scene.game, scene.name);
        self.enter(reset_camera=False);
    }

    """Write the document's entities where the level loader looks for them."""
    def save {
        scene = self.scene;
        if scene is None {
            return;
        }
        if self.is_built_scene() {
            self.save_scene();
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
        self.load(scene.game, scene.name);
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
            titles=["File", "Edit", "View", "Brush", "Play"],
            menus=[
                [
                    MenuItem(text="Save", command="ed_save", keys="Ctrl+S"),
                    MenuItem(text="New scene", command="ed_scene"),
                    MenuItem(text="Turn this level into brushes", command="ed_convert"),
                    MenuItem(text="Revert to the shipped map", command="ed_revert"),
                    MenuItem(rule=True),
                    MenuItem(text="Leave the studio", command="edit", keys="F8"),
                    MenuItem(text="Quit", command="quit")
                ],
                [
                    MenuItem(text="Undo", command="ed_undo", keys="Ctrl+Z"),
                    MenuItem(text="Redo", command="ed_redo", keys="Ctrl+Y"),
                    MenuItem(rule=True),
                    MenuItem(text="Cut", command="ed_cut", keys="Ctrl+X"),
                    MenuItem(text="Copy", command="ed_copy", keys="Ctrl+C"),
                    MenuItem(text="Paste where the camera looks", command="ed_paste here", keys="Ctrl+V"),
                    MenuItem(text="Paste beside the original", command="ed_paste"),
                    MenuItem(text="Duplicate", command="ed_duplicate", keys="Ctrl+D"),
                    MenuItem(text="Delete", command="ed_delete", keys="Del"),
                    MenuItem(rule=True),
                    MenuItem(text="Select all", command="ed_select all", keys="Ctrl+A"),
                    MenuItem(text="Select the rest", command="ed_select invert", keys="Ctrl+I"),
                    MenuItem(text="Select nothing", command="ed_select", keys="Esc"),
                    MenuItem(rule=True),
                    MenuItem(text="Pick brushes and entities", command="ed_mode brush", keys="1"),
                    MenuItem(text="Pick faces", command="ed_mode face", keys="2"),
                    MenuItem(text="Move corners and edges", command="ed_mode corner", keys="3"),
                    MenuItem(rule=True),
                    MenuItem(text="Check the map", command="ed_check"),
                    MenuItem(text="Look for a leak", command="ed_leak")
                ],
                [
                    MenuItem(text="One view", command="ed_layout 1"),
                    MenuItem(text="Four views", command="ed_layout 4"),
                    MenuItem(text="Logic graph", command="ed_layout logic", keys="L"),
                    MenuItem(text="Asset explorer", command="ed_layout assets"),
                    MenuItem(rule=True),
                    MenuItem(text="Axis views as edges", command="ed_display wire axis"),
                    MenuItem(text="Axis views textured", command="ed_display textured axis"),
                    MenuItem(text="3D view as edges", command="ed_display wire 3d"),
                    MenuItem(text="3D view textured", command="ed_display textured 3d"),
                    MenuItem(rule=True),
                    MenuItem(text="Light from the scene's lights", command="ed_light on"),
                    MenuItem(text="Flat light", command="ed_light off"),
                    MenuItem(rule=True),
                    MenuItem(text="Look at the selection", command="ed_focus", keys="F"),
                    MenuItem(text="Console", command="toggleconsole", keys="`")
                ],
                [
                    MenuItem(text="Box", command="ed_box", keys="B"),
                    MenuItem(text="Cylinder", command="ed_cylinder"),
                    MenuItem(text="Wedge", command="ed_wedge"),
                    MenuItem(text="Cone", command="ed_shape cone"),
                    MenuItem(text="Pyramid", command="ed_shape pyramid"),
                    MenuItem(text="Ball", command="ed_shape ball"),
                    MenuItem(text="Dome", command="ed_shape dome"),
                    MenuItem(text="Stairs", command="ed_shape stairs"),
                    MenuItem(text="Spiral stairs", command="ed_shape spiral"),
                    MenuItem(text="Arch", command="ed_shape arch"),
                    MenuItem(text="Pipe", command="ed_shape pipe"),
                    MenuItem(rule=True),
                    MenuItem(text="Turn a quarter", command="ed_rotate 90", keys="R"),
                    MenuItem(text="Tip a quarter about x", command="ed_rotate 90 x"),
                    MenuItem(text="Tip a quarter about y", command="ed_rotate 90 y"),
                    MenuItem(text="Mirror along x", command="ed_mirror x"),
                    MenuItem(text="Mirror along y", command="ed_mirror y"),
                    MenuItem(text="Mirror along z", command="ed_mirror z"),
                    MenuItem(rule=True),
                    MenuItem(text="Carve out of the others", command="ed_carve"),
                    MenuItem(text="Keep what they share", command="ed_intersect"),
                    MenuItem(text="Hollow", command="ed_hollow"),
                    MenuItem(text="Merge", command="ed_merge"),
                    MenuItem(rule=True),
                    MenuItem(text="Group", command="ed_group", keys="Ctrl+G"),
                    MenuItem(text="Four in a row", command="ed_dup 3 64 0 0"),
                    MenuItem(text="Four round the middle", command="ed_dup 3 0 0 0 90"),
                    MenuItem(text="Mirror image along x", command="ed_dup mirror x"),
                    MenuItem(text="Make the copies real", command="ed_dup apply"),
                    MenuItem(text="Hand to the world", command="ed_tie")
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
        tools.adopt(Spacer(size=10));
        tools.adopt(PushButton(text="Box", command="ed_box", hint="Add a box brush where the camera looks (B)"));
        tools.adopt(Spacer(size=10));
        modes: list[PushButton] = [];
        for (word, named, told) in [
            ("brush", "Brushes", "A click picks a brush or an entity; a brush shows its sides' handles (1)"),
            ("face", "Faces", "A click picks one face of a brush (2)"),
            ("corner", "Corners", "A brush shows its corners and edges, to drag (3)")
        ] {
            chooser = PushButton(text=named, command="ed_mode " + word, hint=told);
            tools.adopt(chooser);
            modes.append(chooser);
        }
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
        side = Tabs(titles=["Scene", "Materials", "Checks", "Library", "Classes"], grow=1);
        left.adopt(side);
        scene_page = Box();
        side.adopt(scene_page);
        search_row = Box(pad=4);
        scene_page.adopt(search_row);
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
        scene_page.adopt(tree);
        material_page = Box();
        side.adopt(material_page);
        material_row = Box(pad=4);
        material_page.adopt(material_row);
        material_row.adopt(
            TextField(
                ghost="Filter materials", command="ed_matfilter", live=True, hint="Show only matching materials"
            )
        );
        material_tree = TreeView(
            pick="ed_shelf", toggle="ed_fold", size=150, hint="Click a group to see its materials below"
        );
        material_page.adopt(material_tree);
        gallery = Gallery(
            pick="ed_material",
            grow=1,
            hint="Click a material to give it to the selected faces or brushes, and to new brushes"
        );
        material_page.adopt(gallery);
        check_page = Box();
        side.adopt(check_page);
        check_row = Box(pad=4);
        check_page.adopt(check_row);
        check_row.adopt(
            PushButton(text="Check the map", command="ed_check", hint="Look for what would stop the map playing")
        );
        checks = TreeView(pick="ed_check", grow=1, hint="Click a finding to select what it is about");
        check_page.adopt(checks);
        library_page = Box();
        side.adopt(library_page);
        prefab_row = Box(across=True, pad=4, gap=4);
        library_page.adopt(prefab_row);
        prefab_name = TextField(
            ghost="Save the selection as a prefab", command="ed_prefab save", grow=1,
            hint="Type a name and press Enter to keep the selection as a prefab"
        );
        prefab_row.adopt(prefab_name);
        prefab_row.adopt(PushButton(text="List", command="ed_library", hint="Read the scenes and prefabs folders again"));
        library = TreeView(
            pick="ed_library",
            toggle="ed_fold",
            grow=1,
            hint="Click a scene to open it, or a prefab to add a copy where the camera looks"
        );
        library_page.adopt(library);
        class_page = Box();
        side.adopt(class_page);
        class_row = Box(pad=4);
        class_page.adopt(class_row);
        class_row.adopt(
            TextField(ghost="Filter classes", command="ed_classfilter", live=True, hint="Show only matching classes")
        );
        class_list = TreeView(
            pick="ed_class",
            toggle="ed_fold",
            grow=1,
            hint="Click a class to add one where the camera looks; a brush class takes the selected brushes"
        );
        class_page.adopt(class_list);
        sheet = GraphView(
            pick="ed_select",
            open_command="ed_focus",
            link="ed_link",
            grow=1,
            empty="Nothing here fires anything yet. Drag from one entity's box to another's to link them.",
            hint="Click: select | drag from a box to another: make it fire that | drag the sheet: slide | double click: look at"
        );
        asset_box = Box(across=True, grow=1, gap=3);
        asset_tree = TreeView(
            pick="ed_asset",
            toggle="ed_asset",
            grow=1,
            hint="Click a folder to open it, a file to see it"
        );
        asset_box.adopt(asset_tree);
        asset_side = Box(size=340, fill="panel");
        asset_box.adopt(asset_side);
        asset_side.adopt(Header(text="File"));
        asset_form = Box(pad=6, gap=4, grow=1);
        asset_side.adopt(asset_form);
        body.adopt(Splitter(target=left, low=160, high=600));
        home = game_directory("passion");
        if os.path.isdir(home) {
            found = ArchiveMaterials(directory=home);
            self.archive = found;
            self.materials = found;
        }
        view = ViewArea(
            grow=1, hint="Right drag + WASD/QE: fly | wheel: dolly | middle drag: pan | click: select | F: look at selection"
        );
        center = Box(grow=1, gap=3);
        body.adopt(center);
        center.adopt(view);
        self.camera = self.main;
        self.ports = [Port(view=view, camera=self.main, title="3D")];
        for (kind, named) in [("top", "Top  x/y"), ("front", "Front  x/z"), ("side", "Side  y/z")] {
            self.ports.append(
                Port(
                    view=ViewArea(
                        grow=1,
                        hint="Right or middle drag: slide | wheel: zoom | click: select | drag a selection to move it"
                    ),
                    camera=axis_camera(kind),
                    title=named
                )
            );
        }
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
            place=place,
            materials=material_tree,
            gallery=gallery,
            checks=checks,
            library=library,
            classes=class_list,
            assets=asset_tree,
            asset_box=asset_box,
            asset_form=asset_form,
            logic=sheet,
            prefab_name=prefab_name,
            modes=modes,
            center=center
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
            built = self.is_built_scene();
            for item in scene.items() {
                owned = scene.solids_of(item);
                # A scene's brush entities are their brushes; a shipped
                # map's are the map's models.
                shape = self.owned_shape(item, owned)
                    if owned
                    else item_shape(item, [] if built else app.level.bsp.models);
                if shape is not None {
                    self.shapes.append(shape);
                }
            }
            self.outline_solids(scene);
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
        if self.logic_shown and (changed or picked or self.logic_seen != scene.revision) {
            self.fill_graph(scene, ui);
            self.logic_seen = scene.revision;
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
        picks = scene.faces();
        brushes = scene.selected_solids();
        if picks {
            ui.summary.text = str(len(picks)) + (" face selected" if len(picks) == 1 else " faces selected");
        } elif len(chosen) == 1 and not brushes {
            ui.summary.text = chosen[0].title() + "  #" + str(chosen[0].serial);
        } elif chosen or brushes {
            ui.summary.text = (
                (str(len(chosen)) + (" entity " if len(chosen) == 1 else " entities ") if chosen else "")
                    + (str(len(brushes)) + (" brush " if len(brushes) == 1 else " brushes ") if brushes else "")
                    + "selected"
            );
        } else {
            ui.summary.text = str(len(scene.items())) + " entities";
        }
        for (index, word) in enumerate(["brush", "face", "corner"]) {
            ui.modes[index].lit = self.mode == word;
        }
        eye = self.main.eye;
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
        self.list_solids(scene, rows, wanted);
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
                and not isinstance(held, ViewArea) {
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
        if scene.faces() {
            self.fill_face_form(scene, ui);
            return;
        }
        if not chosen and scene.selected_solids() {
            self.fill_solid_form(scene, ui);
            return;
        }
        if not chosen {
            form.adopt(Label(text="Nothing is selected.", tone="dim"));
            form.adopt(Label(text="Click an entity or a brush in the level or the list.", tone="faint", small=True));
            return;
        }
        heading = chosen[0].title() if len(chosen) == 1 else str(len(chosen)) + " entities";
        form.adopt(Label(text=heading, tone="accent"));
        self.fill_fields(scene, ui, chosen);
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
        self.fill_class(scene, ui, chosen);
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
        self.main.fov = app.renderer.fov;
        self.steer(dt);
        self.shortcuts(stage.loose_keys, input.shift, input.ctrl);
        # Ahead of anything already waiting, so a script's next line sees
        # what its click did.
        asked = stage.take_commands();
        if asked {
            app.shell.insert_text("\n".join(asked));
        }
        self.refresh();
        if self.materials_shown != self.materials_changed {
            self.list_materials(ui);
            self.materials_shown = self.materials_changed;
        }
        ui.materials.track(stage);
        ui.gallery.track(stage);
        ui.checks.track(stage);
        ui.library.track(stage);
        ui.classes.track(stage);
        ui.assets.track(stage);
        if self.assets_shown and self.assets_listed != self.folds {
            self.list_assets(ui);
            self.assets_listed = self.folds;
        }
        # A list opened by a dropdown follows the pointer too.
        for layer in stage.layers() {
            layer.track(stage);
        }
        signature = scene_game(self.scene) + "|" + self.class_filter + "|" + str(self.folds);
        if signature != self.classes_seen {
            self.list_classes(ui);
            self.classes_seen = signature;
        }
        if len(ui.library.rows) == 0 {
            self.list_library(ui);
        }
        ui.logic.track(stage);
        self.load_thumbs();
        self.keep_built();
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
        happened: list[tuple[int, UiEvent]] = [];
        for (index, port) in enumerate(self.ports) {
            for taken in port.view.take() {
                happened.append((index, taken));
            }
        }
        for (index, event) in happened {
            # The pointer's code looks through the view the event was in.
            self.watch(index);
            if event.kind == "press" and event.button == 1 {
                self.looking = True;
            } elif event.kind == "press" and event.button == 2 {
                self.panning = True;
            } elif event.kind == "press" and event.button == 0 {
                # A press on a side handle resizes; one on something selected
                # starts moving the selection.
                self.moved = False;
                self.press_x = event.x;
                self.press_y = event.y;
                if self.grab_handle(scene, event.x, event.y) {
                    continue;
                }
                under = self.aim(event.x, event.y);
                grabbed: Vec3 | None = None;
                if not (event.ctrl or event.shift) {
                    under_item = under.item;
                    under_solid = under.solid;
                    if under_solid is not None and scene.is_solid_selected(under_solid) {
                        seen = self.look_of(under_solid);
                        grabbed = seen.center() if seen is not None else None;
                    } elif under_item is not None and scene.is_selected(under_item) {
                        boxed = self.shape_of(under_item);
                        grabbed = boxed.center() if boxed is not None else None;
                    }
                }
                if grabbed is not None and self.mode != "face" {
                    self.moving = True;
                    self.move_by = Vec3();
                    self.move_from = grabbed;
                } elif self.mode == "brush" and not event.alt {
                    # A press on nothing selected may become a rectangle.
                    self.boxing = True;
                    self.box_port = index;
                }
            } elif event.kind == "release" {
                if event.button == 1 {
                    self.looking = False;
                }
                if event.button == 2 {
                    self.panning = False;
                }
                if event.button == 0 and self.boxing {
                    self.boxing = False;
                    if abs(event.x - self.press_x) + abs(event.y - self.press_y) > 6 {
                        self.moved = True;
                        stage.emit(
                            "ed_boxselect " + str(self.box_port) + " " + str(self.press_x) + " " + str(self.press_y)
                                + " " + str(event.x) + " " + str(event.y)
                                + (" add" if event.ctrl or event.shift else "")
                        );
                    }
                }
                if event.button == 0 and self.resizing {
                    self.resizing = False;
                    self.moved = abs(event.x - self.press_x) + abs(event.y - self.press_y) > 3;
                    if self.mode == "corner" {
                        gone = self.corner_by;
                        if gone.length() > 0.0 {
                            words = "ed_corner " + str(int(gone.x)) + " " + str(int(gone.y)) + " " + str(int(gone.z));
                            for spot in self.grip_spots(scene, self.resize_side) {
                                words += " " + str(round(spot.x, 2)) + " " + str(round(spot.y, 2)) + " "
                                    + str(round(spot.z, 2));
                            }
                            stage.emit(words);
                        }
                        self.corner_by = Vec3();
                    } elif self.resize_by != 0.0 {
                        stage.emit("ed_push " + str(self.resize_side) + " " + str(int(self.resize_by)));
                    }
                    self.resize_by = 0.0;
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
            } elif event.kind == "drag" and self.resizing {
                self.drag_handle(scene, event.x, event.y, event.ctrl);
            } elif event.kind == "drag" and self.moving {
                self.drag_selection(event.x, event.y, event.shift, event.ctrl);
            } elif event.kind == "drag" {
                if self.camera.span > 0.0 {
                    # An axis view slides under either button.
                    if self.looking or self.panning {
                        self.camera.pan(self.view_area(), event.dx, event.dy);
                    }
                } elif self.looking {
                    self.camera.turn(-float(event.dx) * 0.005, -float(event.dy) * 0.005);
                } elif self.panning {
                    scale = 1.0 if not event.shift else 4.0;
                    self.camera.eye = self.camera.eye.sub(self.camera.right().scale(float(event.dx) * scale)).add(
                        self.camera.up().scale(float(event.dy) * scale)
                    );
                }
            } elif event.kind == "wheel" {
                if self.camera.span > 0.0 {
                    self.camera.zoom(0.85 ** event.wheel);
                } else {
                    self.camera.fly(event.wheel * (256.0 if event.shift else 64.0), 0.0, 0.0);
                }
            } elif event.kind == "click" and event.button == 0 {
                if self.moved {
                    # The end of a drag is not a click.
                    self.moved = False;
                    continue;
                }
                found = self.aim(event.x, event.y);
                found_item = found.item;
                found_solid = found.solid;
                if event.alt {
                    # The eyedropper: the material under the pointer.
                    if found_solid is not None {
                        stage.emit("ed_pickmat " + str(found_solid.serial) + " " + str(found.side));
                    }
                    continue;
                }
                if self.mode == "face" {
                    if found_solid is not None {
                        stage.emit(
                            "ed_face " + str(found_solid.serial) + " " + str(found.side)
                                + (" add" if event.ctrl or event.shift else "")
                        );
                    } elif not (event.ctrl or event.shift) {
                        stage.emit("ed_select");
                    }
                    continue;
                }
                words = "ed_select";
                if found_solid is not None {
                    words += " solid:" + str(found_solid.serial);
                } elif found_item is not None {
                    words += " " + str(found_item.serial);
                }
                if event.ctrl or event.shift {
                    if found_item is None and found_solid is None {
                        continue;
                    }
                    words += " add";
                }
                stage.emit(words);
            }
        }
        held_view = False;
        over_view = False;
        for (index, port) in enumerate(self.ports) {
            if stage.held is port.view {
                held_view = True;
            }
            if stage.hover is port.view {
                over_view = True;
                if stage.held is None {
                    self.watch(index);
                }
            }
        }
        if not held_view {
            self.looking = False;
            self.panning = False;
            self.moving = False;
            self.resizing = False;
            self.boxing = False;
        }
        if self.looking and self.camera.span <= 0.0 and not self.source.scripted {
            speed = app.host.flyspeed.number * (4.0 if input.shift else 1.0) * dt;
            keyboard = app.keyboard;
            ahead = (1.0 if keyboard.is_down("w") else 0.0) - (1.0 if keyboard.is_down("s") else 0.0);
            side = (1.0 if keyboard.is_down("d") else 0.0) - (1.0 if keyboard.is_down("a") else 0.0);
            rise = (1.0 if keyboard.is_down("e") else 0.0) - (1.0 if keyboard.is_down("q") else 0.0);
            self.camera.fly(ahead * speed, side * speed, rise * speed);
        }
        self.hover = None;
        self.hover_solid = None;
        self.hover_side = -1;
        if over_view and not self.looking and not self.panning and not self.moving and not self.resizing
            and not self.boxing {
            pointed = self.aim(input.x, input.y);
            self.hover = pointed.item;
            self.hover_solid = pointed.solid;
            self.hover_side = pointed.side;
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
            } elif ctrl and key == "c" {
                stage.emit("ed_copy");
            } elif ctrl and key == "x" {
                stage.emit("ed_cut");
            } elif ctrl and key == "v" {
                stage.emit("ed_paste" if shift else "ed_paste here");
            } elif ctrl and key == "g" {
                stage.emit("ed_group");
            } elif ctrl and key == "a" {
                stage.emit("ed_select all");
            } elif ctrl and key == "i" {
                stage.emit("ed_select invert");
            } elif self.looking {
                # Flying: the letter keys move the camera.
                continue;
            } elif key == "DEL" or key == "BACKSPACE" {
                stage.emit("ed_delete");
            } elif key == "f" {
                stage.emit("ed_focus");
            } elif key == "b" {
                stage.emit("ed_box");
            } elif key == "r" {
                stage.emit("ed_rotate 90");
            } elif key == "l" {
                stage.emit("ed_layout " + (str(self.layout) if self.logic_shown else "logic"));
            } elif key == "1" {
                stage.emit("ed_mode brush");
            } elif key == "2" {
                stage.emit("ed_mode face");
            } elif key == "3" {
                stage.emit("ed_mode corner");
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
        line = self.camera.sight(self.view_area(), x, y);
        ahead = self.camera.forward();
        closing = line[1].dot(ahead);
        if closing < 0.001 {
            return anchor;
        }
        return line[0].add(line[1].scale(anchor.sub(line[0]).dot(ahead) / closing));
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

    """The rectangle of the level view the pointer's code is looking
    through."""
    def view_area -> Rect {
        if self.port_now < len(self.ports) {
            return self.ports[self.port_now].view.area;
        }
        return Rect();
    }

    """Look through one of the level views."""
    def watch(index: int) {
        if index >= 0 and index < len(self.ports) {
            self.port_now = index;
            self.camera = self.ports[index].camera;
        }
    }

    """The level views showing: the first alone, or all four."""
    def showing -> int {
        if self.logic_shown or self.assets_shown {
            return 0;
        }
        return len(self.ports) if self.layout == 4 else min(1, len(self.ports));
    }

    """Lay the level views out: one, or four in a square."""
    def arrange_views(count: int) {
        ui = self.ui;
        stage = self.stage;
        if ui is None or len(self.ports) < 4 {
            return;
        }
        if stage is not None {
            stage.focus_on(None);
        }
        for row in ui.center.kids() {
            row.clear();
        }
        ui.center.clear();
        self.layout = 4 if count == 4 else 1;
        self.watch(0);
        if self.logic_shown {
            ui.center.adopt(ui.logic);
            self.logic_seen = -1;
            return;
        }
        if self.assets_shown {
            ui.center.adopt(ui.asset_box);
            self.assets_listed = -1;
            return;
        }
        if self.layout == 1 {
            ui.center.adopt(self.ports[0].view);
            return;
        }
        upper = Box(across=True, grow=1, gap=3);
        lower = Box(across=True, grow=1, gap=3);
        ui.center.adopt(upper);
        ui.center.adopt(lower);
        upper.adopt(self.ports[0].view);
        upper.adopt(self.ports[1].view);
        lower.adopt(self.ports[2].view);
        lower.adopt(self.ports[3].view);
    }

    """The entity under a point of the level view: the nearest whose box the
    line of sight enters before it meets a wall."""
    def pick(x: int, y: int) -> Item | None {
        app = self.app;
        if app is None {
            return None;
        }
        line = self.camera.sight(self.view_area(), x, y);
        eye = line[0];
        along = line[1];
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
        seen: list[SceneView] = [];
        built = self.is_built_scene();
        for (index, port) in enumerate(self.ports[:self.showing()]) {
            area = port.view.area;
            if area.w <= 0 or area.h <= 0 {
                continue;
            }
            edges = self.wire_main if index == 0 else self.wire_axis;
            seen.append(
                SceneView(
                    x=area.x,
                    y=area.y,
                    width=area.w,
                    height=area.h,
                    eye=port.camera.eye,
                    yaw=port.camera.yaw,
                    pitch=port.camera.pitch,
                    span=port.camera.span,
                    everything=True,
                    # A scene's own brushes are drawn by their outlines; a
                    # shipped map has only its triangles to show.
                    wire=edges and not built,
                    bare=edges and built
                )
            );
        }
        return seen;
    }

    """The grid behind an axis view: lines far down its line of sight, so
    the level covers them. They are 16 units apart when that reads, else 64,
    256 or 1024, and every fourth is brighter."""
    def draw_grid(view: SceneView) {
        ahead = forward_from(view.yaw, view.pitch);
        across = right_from(view.yaw);
        up = across.cross(ahead);
        tall = view.span * 0.5;
        wide = tall * float(max(1, view.width)) / float(max(1, view.height));
        step = 16.0;
        while view.span / step > 40.0 {
            step *= 4.0;
        }
        back = view.eye.add(ahead.scale(30000.0));
        faint = ink(0x2a2723);
        strong = ink(0x3d3832);
        middle_x = view.eye.dot(across);
        middle_y = view.eye.dot(up);
        base = back.sub(across.scale(middle_x)).sub(up.scale(middle_y));
        first = int(math.floor((middle_x - wide) / step));
        last = int(math.ceil((middle_x + wide) / step));
        for i in range(first, last + 1) {
            at = float(i) * step;
            wire_line(
                base.add(across.scale(at)).add(up.scale(middle_y - tall)),
                base.add(across.scale(at)).add(up.scale(middle_y + tall)),
                strong if i % 4 == 0 else faint
            );
        }
        first = int(math.floor((middle_y - tall) / step));
        last = int(math.ceil((middle_y + tall) / step));
        for i in range(first, last + 1) {
            at = float(i) * step;
            wire_line(
                base.add(up.scale(at)).add(across.scale(middle_x - wide)),
                base.add(up.scale(at)).add(across.scale(middle_x + wide)),
                strong if i % 4 == 0 else faint
            );
        }
    }

    def draw_scene(view: SceneView) {
        scene = self.scene;
        if scene is None {
            return;
        }
        if view.span > 0.0 {
            self.draw_grid(view);
        }
        self.bare_now = view.bare;
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
        # The way out of a level that leaks.
        for i in range(1, len(self.leak)) {
            wire_line(self.leak[i - 1], self.leak[i], ink(0xe5484d));
        }
        rlDrawRenderBatchActive();
        rlEnableDepthTest();
        self.draw_solids(scene);
    }

    def draw(width: int, height: int) {
        stage = self.stage;
        scene = self.scene;
        if stage is None or scene is None {
            return;
        }
        stage.paint();
        # Over each level view, through its own camera.
        watched = self.port_now;
        for index in range(self.showing()) {
            self.watch(index);
            self.draw_over_view(scene, self.ports[index].title if self.layout == 4 else "");
        }
        self.watch(watched);
        self.canvas.unclip();
    }

    """Names over the selection and over what the pointer is on, the selected
    brush's handles, and the view's title."""
    def draw_over_view(scene: Scene, title: str) {
        area = self.view_area();
        canvas = self.canvas;
        canvas.clip(area);
        if title {
            canvas.text(title, area.x + 8, area.y + 6, canvas.theme.dim, canvas.theme.small);
        }
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
        self.draw_handles(scene, area);
        stage = self.stage;
        if self.boxing and stage is not None and self.port_now == self.box_port {
            x0 = min(self.press_x, stage.input.x);
            y0 = min(self.press_y, stage.input.y);
            band = Rect(x=x0, y=y0, w=abs(stage.input.x - self.press_x), h=abs(stage.input.y - self.press_y));
            if band.w + band.h > 6 {
                canvas.fill(band, canvas.theme.accent.faded(40));
                canvas.outline(band, canvas.theme.accent);
            }
        }
    }

    # ------------------------------------------------------------------
    # Scenes and brushes (impl/studio.scenes.impl.jac)

    def build_level(game: str, name: str) -> Bsp | None;
    """Whether the document is a scene of its own brushes rather than a
    shipped map's entities."""
    def is_built_scene -> bool;
    """Start a scene: a floor and a player start."""
    def new_scene(name: str);
    def open_map(path: str);
    """Load a scene's level and edit it."""
    def show_scene(scene: Scene);
    def scene_path(name: str) -> str;
    def save_scene(path: str = "");
    """Rebuild the level when the document's brushes have changed."""
    def keep_built;
    """Bring the brushes' outlines in line with the document."""
    def outline_solids(scene: Scene);
    """The shape of an entity made of brushes: the box around them."""
    def owned_shape(item: Item, solids: list[Solid]) -> Shape | None;
    def look_of(solid: Solid) -> SolidLook | None;
    """Fill the materials list: the games' groups, and under an open group
    its materials."""
    def list_materials(ui: StudioUi);
    """The entity or brush under a point of the level view."""
    def aim(x: int, y: int) -> Aim;
    def draw_solids(scene: Scene);
    """Where the selected brush's side handles are (when one brush alone is
    selected): each side's index and the middle of its outline."""
    def handles(scene: Scene) -> list[tuple[int, Vec3]];
    def draw_handles(scene: Scene, area: Rect);
    """Start dragging a side handle under the pointer."""
    def grab_handle(scene: Scene, x: int, y: int) -> bool;
    def drag_handle(scene: Scene, x: int, y: int, free: bool);
    """Add a brush of a shape ("box", "cylinder" or "wedge") where the
    camera looks, resting on what is beneath it."""
    def add_shape(scene: Scene, args: list[str], shape: str);
    def list_solids(scene: Scene, rows: list[TreeRow], wanted: str);
    def fill_solid_form(scene: Scene, ui: StudioUi);
    """Run a scene or brush command. False when it is not one."""
    def scene_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Faces, corners, wider selections and brush tools (impl/studio.tools.impl.jac)

    """Run a face, corner, selection or brush-tool command. False when it is
    not one."""
    def tool_command(scene: Scene, args: list[str]) -> bool;
    """The wider selections of ed_select. False when the word is not one."""
    def select_wide(scene: Scene, args: list[str]) -> bool;
    def fill_face_form(scene: Scene, ui: StudioUi);
    """The corners a handle of the selected brush stands for in corner mode:
    one for a corner, two for an edge."""
    def grip_spots(scene: Scene, index: int) -> list[Vec3];
    """Select what lies in a rectangle of a view."""
    def select_in_box(scene: Scene, port: int, area: Rect, add: bool);
    def draw_faces(scene: Scene);
    """The size in texels of every material the selection's sides have."""
    def material_sizes(scene: Scene) -> dict[str, list[int]];
    """Show a group's materials in the gallery."""
    def fill_gallery(ui: StudioUi);
    """Load a few of the pictures the gallery is waiting for."""
    def load_thumbs;
    def check(scene: Scene, args: list[str]);

    # ------------------------------------------------------------------
    # The clipboard, prefabs, the library and the logic graph (impl/studio.library.impl.jac)

    """Run a clipboard, prefab, library or logic command. False when it is
    not one."""
    def library_command(scene: Scene, args: list[str]) -> bool;
    def prefab_path(name: str) -> str;
    """A map file's entities and brushes, or none (and why is said)."""
    def read_fragment(path: str) -> list[MapItem] | None;
    """Add a map's contents so they rest where the camera looks."""
    def place_fragment(scene: Scene, found: list[MapItem], label: str, group: str = "") -> bool;
    """The scene with every linked prefab put in as its entities and
    brushes: what is built and played."""
    def expanded(scene: Scene) -> Scene;
    def list_library(ui: StudioUi);
    def fill_graph(scene: Scene, ui: StudioUi);

    # ------------------------------------------------------------------
    # Entity classes, typed fields and shapes (impl/studio.classes.impl.jac)

    """Run a class, option or shape command. False when it is not one."""
    def class_command(scene: Scene, args: list[str]) -> bool;
    """The inspector's rows for the fields the selection has, each edited
    by its kind."""
    def fill_fields(scene: Scene, ui: StudioUi, chosen: list[Item]);
    """Under the fields: what the class is, its options as boxes to tick,
    and the fields it knows that the selection does not have yet."""
    def fill_class(scene: Scene, ui: StudioUi, chosen: list[Item]);
    def list_classes(ui: StudioUi);

    # ------------------------------------------------------------------
    # Converting levels, the leak finder and duplicators (impl/studio.build.impl.jac)

    """Run a convert, leak or duplicator command. False when it is not one."""
    def build_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # The asset explorer and archive packing (impl/studio.assets.impl.jac)

    """Run an explorer or packing command. False when it is not one."""
    def asset_command(scene: Scene, args: list[str]) -> bool;
    def list_assets(ui: StudioUi);
    """Fill the explorer's side with the file being shown."""
    def show_asset(ui: StudioUi);

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
        if name == "ed_scene" {
            self.new_scene(args[1] if len(args) > 1 else "untitled");
            return;
        }
        if name == "ed_open" {
            if len(args) > 1 {
                self.open_map(args[1]);
            } else {
                self.say("ed_open <file.map>");
            }
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
                self.materials_changed += 1;
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
                self.main.eye = Vec3(x=float(args[1]), y=float(args[2]), z=float(args[3]));
            }
            if len(args) > 5 {
                self.main.yaw = math.radians(float(args[4]));
                self.main.pitch = math.radians(float(args[5]));
            }
        } elif name == "ed_layout" {
            self.logic_shown = len(args) > 1 and args[1] == "logic";
            self.assets_shown = len(args) > 1 and args[1] == "assets";
            if self.logic_shown or self.assets_shown {
                self.arrange_views(self.layout);
            } else {
                self.arrange_views(4 if len(args) > 1 and args[1] == "4" else 1);
            }
        } elif name == "ed_dump" {
            if len(args) > 1 {
                print("STEP " + args[1]);
            }
            self.dump(scene);
        } elif not self.scene_command(scene, args) and not self.tool_command(scene, args)
            and not self.library_command(scene, args) and not self.class_command(scene, args)
            and not self.build_command(scene, args) {
            self.asset_command(scene, args);
        }
    }

    def select(scene: Scene, args: list[str]) {
        add = len(args) > 2 and args[2] == "add";
        if len(args) < 2 {
            scene.select(None);
            return;
        }
        if self.select_wide(scene, args) {
            return;
        }
        if args[1].startswith("solid:") and args[1][6:].isdigit() {
            brush = scene.find_solid(int(args[1][6:]));
            if brush is not None {
                scene.select_solid(brush, add=add);
            } else {
                self.say("ed_select: no brush " + args[1][6:]);
            }
            return;
        }
        if args[1] == "class:brushes" {
            if not add {
                scene.clear_selection();
            }
            for brush in scene.solids() {
                if not scene.is_solid_selected(brush) {
                    scene.select_solid(brush, add=True);
                }
            }
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
        for look in self.looks {
            if scene.is_solid_selected(look.solid) {
                low = Vec3(x=min(low.x, look.low.x), y=min(low.y, look.low.y), z=min(low.z, look.low.z));
                high = Vec3(x=max(high.x, look.high.x), y=max(high.y, look.high.y), z=max(high.z, look.high.z));
                seen += 1;
            }
        }
        if seen == 0 {
            self.say("Nothing to look at");
            return;
        }
        for port in self.ports {
            port.camera.frame(low.add(high).scale(0.5), high.sub(low).length() * 0.5);
        }
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
        eye = self.main.eye;
        ahead = self.main.forward();
        trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(192.0)));
        at = eye.add(ahead.scale(max(32.0, 192.0 * trace.fraction - 24.0)));
        scene.create(classname, Vec3(x=float(round(at.x)), y=float(round(at.y)), z=float(round(at.z))));
        self.say("Added " + classname);
    }

    def dump(scene: Scene) {
        eye = self.main.eye;
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
                + str(self.view_area().w) + " " + str(self.view_area().h) + " of " + str(self.showing())
        ];
        for item in scene.selection() {
            pairs = " ".join([key + "=" + value for (key, value) in item.fields.items()]);
            owned = len(scene.solids_of(item));
            lines.append(
                "studio: selected #" + str(item.serial) + " " + pairs + (" owns=" + str(owned) if owned else "")
            );
        }
        if scene.solids() {
            lines.append(
                "studio: brushes=" + str(len(scene.solids())) + " geometry=" + str(scene.geometry) + " built="
                    + str(self.built_geometry)
            );
        }
        for brush in scene.selected_solids() {
            box = brush.bounds();
            holder = scene.owner_of(brush);
            if box is not None {
                lines.append(
                    "studio: brush #" + str(brush.serial) + " low=" + str(int(round(box[0].x))) + ","
                        + str(int(round(box[0].y))) + "," + str(int(round(box[0].z))) + " high="
                        + str(int(round(box[1].x))) + "," + str(int(round(box[1].y))) + ","
                        + str(int(round(box[1].z))) + " sides=" + str(len(brush.sides)) + " material="
                        + brush.sides[0].material + " owner="
                        + (holder.classname() if holder is not None else "")
                );
            }
        }
        for face in scene.faces() {
            side = face.solid.sides[face.side];
            lay = side.mapping;
            lines.append(
                "studio: face #" + str(face.solid.serial) + "/" + str(face.side) + " material=" + side.material
                    + " shift=" + str(round(lay.s_shift, 2)) + "," + str(round(lay.t_shift, 2)) + " scale="
                    + str(round(lay.s_scale, 3)) + "," + str(round(lay.t_scale, 3)) + " turn="
                    + str(round(lay.rotation, 1))
            );
        }
        placed = scene.logic_nodes();
        arrows = 0;
        for node in placed {
            arrows += len(scene.fires(node.item));
        }
        lines.append(
            "studio: logic nodes=" + str(len(placed)) + " links=" + str(arrows) + " shown="
                + ("1" if self.logic_shown else "0") + " leak=" + str(len(self.leak))
        );
        seen_asset = self.asset_now;
        if seen_asset is not None {
            lines.append(
                "studio: asset " + seen_asset.game + ":" + seen_asset.name + " kind=" + seen_asset.kind + " size="
                    + str(seen_asset.size) + " note=" + seen_asset.note.replace(" ", "") + " lines="
                    + str(len(seen_asset.lines)) + " material=" + seen_asset.material
            );
        }
        lines.append(
            "studio: mode=" + self.mode + " material=" + self.material + " wire="
                + ("1" if self.wire_axis else "0") + ("1" if self.wire_main else "0") + " lit="
                + str(self.lit_samples if self.lit else 0)
        );
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

"""The game whose classes a document may hold ("" before there is one)."""
def scene_game(scene: Scene | None) -> str {
    return scene.game if scene is not None else "";
}

"""Give an App its studio."""
def attach_studio(app: App) -> Studio {
    studio = Studio(app=app);
    app.workbench = studio;
    return studio;
}
