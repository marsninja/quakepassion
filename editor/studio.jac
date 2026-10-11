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
import time;
import from engine.core.workbench { Workbench, SceneView }
import from engine.core.app { App }
import from engine.console.shell { Shell, quote_command_word }
import from engine.formats.bsp { Model, Bsp, MapEntity, Texture }
import from engine.math.vec3 { Vec3, forward_from, right_from }
import from engine.input.input { _capture, _release, mouse_captured }
import from engine.world.world { move_to_area }
import from engine.render.renderer { Color, Vector3, DrawCubeWires, DrawLine3D }
import from games.levels { override_path, override_folder }
import from games.items { pickup_rule }
import from games.enemies { enemy_rule }
import from games.fixtures { fixture_rule }
import from games.arena_character { character_rig }
import from games.viewweapons { view_weapons }
import from games.passion.materials {
    DistrictTable, district_table, kept_table, table_text, districts_path, material_word, material_spec, SLOT_NAMES,
    load_materials
}
import from engine.world.weapons { ViewWeaponRule }
import from engine.formats.animated { AnimatedModel }
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
    MenuPopup,
    ViewArea,
    Gallery,
    Tile,
    GraphView,
    GraphNode,
    GraphLink,
    Dropdown,
    Swatch,
    Check,
    Picture,
    Palette,
    PaletteEntry,
    Slider,
    Spinner,
    Radio,
    VectorField,
    ColourBars
}
import from .assets.explorer { AssetIndex, AssetLook }
import from .assets.models { ModelLook, load_model, is_model }
import from .assets.shaders {
    ShaderText, ShaderStage, ShaderFault, read_shaders, write_shaders, with_directive, shader_named, shader_faults
}
import from .formats.archive { write_pak, write_zip, file_kind }
import from .formats.sound { sound_facts, converted_sound }
import from .formats.wal { WalFacts, wal_facts, wal_with, flag_names, flag_named, quake_frames }
import from .classes.registry {
    ClassInfo, FieldInfo, class_info, class_names, class_family, field_of, flag_set, add_classes, drop_classes
}
import from .geometry.shapes { shape_brushes, caulked, SHAPE_KINDS }
import from .geometry.terrain { heights_from, heights_image, image_heights }
import from .geometry.touchup { cell_at, kin_cells, cells_outline }
import from .geometry.patch {
    patch_points, PATCH_KINDS, places_text, places_even, places_projected_from, places_slid
}
import from .model.mesh { Mesh, mesh_volume, open_edges, face_under, point_under }
import from .model.primitives { primitive_mesh, PRIMITIVE_KINDS }
import from .model.wavefront { mesh_obj, obj_mesh }
import from .model.skin {
    Skin, places_box, places_moved, places_scaled, places_turned, places_flipped, places_projected, skin_filled, skin_dab,
    place_under, skin_tga, tga_skin
}
import from .model.document { ModelDoc, Part, Reshape, Bone }
import from .model.bones { point_swung }
import from .model.assembly { body_model, held_model, clip_frames, rule_frames }
import from .model.files { doc_from_model, model_of, write_md3, md3_limits, write_md2, md2_limits }
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.q2.model { parse_md2 }
import from .geometry.extrude { profile_pieces, profile_of, sweep_brushes, PROFILE_KINDS }
import from .compile.light { bake_light }
import from .compile.bake { bake_cells, cell_sees, leaf_at, VisReport }
import from .project { Project, MANIFEST_NAME, read_project, write_project, addon_classes, file_name }
import from .compile.kept { KeptBake, keep_bake, give_bake }
import from .compile.steps { Place, recipe_steps, step_line, places_named, text_mark }
import from .compile.leak { find_leak, LeakReport }
import from .formats.bspmap { bsp_items, level_material }
import from .document.generate {
    duplicates,
    image_brushes,
    image_sets,
    with_images,
    DUPLICATOR_KEYS,
    with_holes,
    digs,
    DIGGER_KEY,
    prefab_overridden,
    with_prefabs
}
import from .document.scene {
    Scene,
    Item,
    Solid,
    FaceEdit,
    FacePick,
    Finding,
    Step,
    FieldChange,
    read_vector,
    scene_of,
    scene_map,
    scene_from_map,
    item_veil,
    item_switched,
    VIEW_KEY,
    LOCK_KEY,
    SKIP_KEY,
    TINT_KEY
}
import from .geometry.csg { brush_corners, brush_edges }
import from .geometry.mapping { spun_about, axis_vector, mapping_bad }
import from .geometry.layhandle { lay_arms, lay_dragged, swept_between }
import from .geometry.linear {
    Linear, BoxDrag, along_axis, box_part, box_drag, point_remapped, linear_shear, linear_from, linear_text
}
import from .camera { EditCamera, ray_enters_box, axis_camera }
import from engine.world.signals { Signal, Fire, HasSignal }
import from engine.world.doors { Door, HasDoor }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.combat { Opponent, HasOpponent }
import from .compile.live { compile_scene, LiveLevel, Materials, SwatchMaterials, swatch_texture }
import from .assets.materials { ArchiveMaterials, small_picture }
import from engine.core.menu { game_directory }
import from .formats.map { read_map, write_map, MapItem, MapFile }
import from .geometry.brush { brush_windings, windings_bounds, Side, Mapping }
import from .geometry.brush { box_sides, cylinder_sides, wedge_sides, ray_enters_brush, Plane3 }

"""The studio's commands: name, usage, description."""
glob STUDIO_COMMANDS: list[tuple[str, str, str]] = [
    ("edit", "edit", "enter or leave the studio"),
    ("ed_play", "ed_play [here]", "play the document from its start, or from the camera"),
    ("ed_stop", "ed_stop", "stop playing and return to the document"),
    (
        "ed_select",
        "ed_select [serial|solid:<n>|class:<name>|material:<name>|all|brushes|entities|invert|parent|child|next|prev|brush <e> [b]] [add]",
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
    ("ed_carve", "ed_carve [link]", "cut the selected brushes out of every other brush they reach; with link, the faces the cut divides stay linked"),
    ("ed_intersect", "ed_intersect", "replace the selected brushes with what they all share"),
    ("ed_hollow", "ed_hollow [thickness]", "turn the selected brushes into shells of walls (16 thick)"),
    ("ed_merge", "ed_merge", "join the selected brushes into one, when together they are convex"),
    (
        "ed_mode",
        "ed_mode <brush|face|corner|sculpt|clip|draw>",
        "what the pointer does in the level: pick brushes, pick faces, show corners, sculpt, cut along a line, draw a box"
    ),
    (
        "ed_clip_line",
        "ed_clip_line <view> <x0> <y0> <x1> <y1> [back|front|both]",
        "cut the selected brushes along a line drawn across a view"
    ),
    ("ed_box_draw", "ed_box_draw <view> <x0> <y0> <x1> <y1>", "add a box over a rectangle drawn in an axis view"),
    (
        "ed_terrain",
        "ed_terrain [cols rows cell] | export <file.pgm> | import <file.pgm> [tallest] | lift <x0> <y0> <x1> <y1> <amount> [falloff] | pattern <same|alt|other> | free",
        "add a terrain where the camera looks; write or read its heights as a grey image; lift a rectangle of it; split its cells another way; or leave it as plain brushes"
    ),
    (
        "ed_sculpt",
        "ed_sculpt <raise|lower|smooth|flatten|noise|erode|paint> [radius] [amount] [at <x> <y>]",
        "a stroke of the sculpting brush on a terrain, where the camera looks or at a point"
    ),
    ("ed_brush", "ed_brush <radius> <amount>", "the sculpting brush's width and strength"),
    ("ed_replace", "ed_replace <old> <new> [all]", "give sides of one material another, in the selection or everywhere"),
    ("ed_snap", "ed_snap [size]", "put the selection's corners and origins on the grid"),
    ("ed_align", "ed_align <x|y|z> <low|high|middle>", "line the selected brushes up along an axis"),
    (
        "ed_faces",
        "ed_faces <all|invert|extend|next|prev>",
        "spread the face pick over the whole brush, to its other faces or across the plane; or step to the next face"
    ),
    ("ed_tag", "ed_tag [clear]", "remember the picked face, to glue brushes against and take its material from; or forget it"),
    ("ed_glue", "ed_glue [face [link]]", "move the selection against the tagged face, or put the picked face in its plane (and link it to what lies there)"),
    ("ed_paintface", "ed_paintface <brush> <side>", "give one face the material in hand (Alt and a drag, in face mode)"),
    ("ed_reshape", "ed_reshape <w d h> [count] [thickness]", "build the selected shape again from other numbers, where it stands"),
    ("ed_caulk", "ed_caulk [material]", "give the faces the selected brushes cover of each other a material that is not drawn"),
    ("ed_autocaulk", "ed_autocaulk [on|off]", "whether shapes are built with their inner faces caulked"),
    (
        "ed_bake",
        "ed_bake [cell|off]",
        "cut the built level into cells that know which others they see (256 units wide unless told), or build it as one again"
    ),
    (
        "ed_project",
        "ed_project [new|open <folder>] [close] [add] [drop|start <scene>] [set <what> <value>]",
        "a project: a folder with a manifest and scenes, prefabs and textures of its own; with no word, the one open"
    ),
    ("ed_addon", "ed_addon [file] [reload|drop [file]]", "load a text file of entity classes, read it again, drop it, or list what is loaded"),
    ("ed_game", "ed_game [game] [material|build|bake] [value]", "what a scene of a game begins with, or what each game is set up with"),
    ("ed_models", "ed_models [on|off|list]", "draw entities in the 3D view as the models their game would show them as, or list those models"),
    ("ed_sound", "ed_sound info <file> | convert <file> <name> [rate] [bits] [loud]", "say what a WAV file is, or make it one channel at a game's rate and width among the project's sounds"),
    (
        "ed_wal",
        "ed_wal <file.wal|q2:name> [flag <name> on|off] [flags|contents|value <number>] [next <name>|none]",
        "a Quake II texture's own flags, contents, value and the texture that follows it: read, or changed in a copy among the project's textures"
    ),
    ("ed_frames", "ed_frames [material]", "the frames of an animated texture: a Quake + name's row, or a Quake II texture's chain"),
    (
        "ed_shader",
        "ed_shader [open <file>|take|new <name>|pick <name>|show|set <key> <value>|unset <key>|stage ...|drop|check|save]",
        "a Quake III shader script: open one (or take the one the explorer shows), change a shader's lines and stages, check it for what the game would trip on, and save it"
    ),
    ("ed_assetgame", "ed_assetgame <q1|q2|q3|none|fill>", "the game whose rules the selected entities are spawned by in a scene of no one game; fill gives every entity its class's"),
    ("ed_camps", "ed_camps", "list the spots bots camp at and roam through"),
    ("ed_touch", "ed_touch <x> <y> <amount> [variance]", "move the corner of the terrain nearest a place, and the corners that stand with it"),
    (
        "ed_plot",
        "ed_plot <x> <y> [variance] [add] | clear | variance <units> | lift <amount> | paint",
        "pick the cells of the terrain that adjoin one at about its height (outlined), and lift them or paint their tops"
    ),
    ("ed_facelink", "ed_facelink [clear]", "link the picked faces, or the selected brushes' faces that lie in one plane, so that pushing one pushes all; or take the links away"),
    ("ed_miter", "ed_miter", "cut the two selected brushes to meet in a seam where they overlap"),
    ("ed_merge", "ed_merge <x y z> <x y z>", "move a corner of the selected brush onto another of its corners"),
    (
        "ed_model",
        "ed_model [new|add <kind>] [edit] [open|save <file>] [part <n>] [frame ...] [tag ...] [skin ...] [check] [match] [box] [axes] [undo|redo] [close]",
        "the model editor: make a model from a primitive, edit the one shown in the explorer, open or save one (OBJ, MD3, MD2), and look after its parts"
    ),
    ("ed_pick", "ed_pick points|faces <numbers|all> [add] | front | back | none | mode points|faces|paint", "pick points or triangles of the model's part in hand, or say what a click in its view does"),
    (
        "ed_district",
        "ed_district [list] | <n> <floor|wall|ceiling|trim|accent> [material] | <n> name <words> | check | reset [n]",
        "the materials generated levels are built of: list each district's slots, give one another material (the one in hand), name a district, check them against the archives, or put them back"
    ),
    (
        "ed_body",
        "ed_body [character|list] [weapon|none] [legs <sequence>] [torso <sequence>]",
        "show a Quake III body put together as the game joins it: legs, torso and head by their tags, a weapon in its hand, through the frames of two sequences"
    ),
    ("ed_viewweapon", "ed_viewweapon <q1|q2|q3> [slot] [out]", "show a game's weapon as it is held in view, at rest and through a shot"),
    (
        "ed_bone",
        "ed_bone [list] | add <name> <head> <tail> [parent] | chain <name> <tail> | pick <name> | hold [weight] | release [all] | auto | weights | tint <rrggbb> | turn <x|y|z> <degrees> | move <d> | end <head|tail> <at> [all] | drop [name] | spread <first> <last> | colours [on|off] | save|load [file]",
        "the model's bones: make and joint them, give them points to carry by weight, pose with them, and spread the frames between two poses"
    ),
    (
        "ed_skin",
        "ed_skin [move|scale|turn|flip|project ...] [new <w h>|open|save <file.tga>] [colour <r g b>] [brush <radius> [soft]] [dab <u v>] [show]",
        "the model's skin: move, stretch, turn, flip or lay flat where the picked points lie on it; make, open, paint and save its picture"
    ),
    (
        "ed_mesh",
        "ed_mesh move|turn|scale|mirror|flip|subdivide|extrude ...",
        "move, turn or stretch the picked points; mirror the part; turn triangles round, cut them in 2, 3 or 4, or push them out"
    ),
    (
        "ed_sweep",
        "ed_sweep <outline|brush> [wide tall] [count] along <name> | line <points> [closed] | again",
        "carry an outline (square, round, ridge, ell, tee, channel, rail, or the selected brush's) along a path of named entities or a line of points; or sweep the sweeps again"
    ),
    ("ed_layer", "ed_layer [name|all] [hide|show|only]", "a kept set as a layer: hide or show what it holds, show it alone, or list the layers"),
    ("ed_depth", "ed_depth [top|front|side] <low> <high> | selection | off", "hold an axis view to a band of depth, measured along the axis it looks along"),
    ("ed_outside", "ed_outside [whole|grey|hide]", "how a view held to a band of depth shows what lies outside it"),
    ("ed_oblique", "ed_oblique [top|front|side] <yaw> <pitch> | off", "turn an axis view off its axis, or straighten it"),
    ("ed_mouse", "ed_mouse [look <rate>] [invert on|off] [wheel <rate>] [reverse on|off]", "how fast and which way the mouse turns the camera and the wheel moves it"),
    ("ed_assoc", "ed_assoc [ending] [command line]", "keep a program for files of an ending (%file% is the file), forget one, or list them"),
    ("ed_openwith", "ed_openwith [file]", "open a file, or the image file that is the material in hand, with the program kept for its ending"),
    ("ed_reload", "ed_reload", "read the project's image files again and build the level afresh"),
    ("ed_watch", "ed_watch [on|off]", "whether image files are read again when they change on disk"),
    ("ed_cells", "ed_cells [on|off]", "draw the cells of a bake: the one looked from, what it sees and what it does not"),
    ("ed_recipe", "ed_recipe [name] [commands]", "keep a row of commands, apart at semicolons, under a name; forget one; or list them"),
    ("ed_make", "ed_make <name>", "run a recipe's commands"),
    ("ed_run", "ed_run <command line>", "run another program over the scene written as a map (%map%), and list what it says of entities and brushes"),
    ("ed_logic", "ed_logic [kind]", "add a piece of logic (a relay, a delay, a counter ...) as the scene's game has it, or list the kinds"),
    ("ed_fav", "ed_fav <classname>", "keep a class as a favourite, or stop keeping it"),
    ("ed_bind", "ed_bind <key> <command>", "give a key (a, ctrl+k, shift+f2) an editor command of your own"),
    ("ed_unbind", "ed_unbind <key>", "give a key back what the studio gives it"),
    ("ed_binds", "ed_binds", "list the keys bound by hand"),
    ("ed_settings", "ed_settings", "list the studio's settings, each a click to change"),
    ("ed_dev", "ed_dev [on|off]", "show frame and build times and counts in the status bar"),
    ("ed_docs", "ed_docs", "list the open documents"),
    ("ed_doc", "ed_doc <name|next|prev>", "go to another open document"),
    ("ed_close", "ed_close [force]", "close this document (force, when it has edits that are not saved)"),
    ("ed_recent", "ed_recent [number]", "list the files opened and saved lately, or open one of them"),
    ("ed_log", "ed_log [lines]", "show the console's last lines"),
    ("ed_mapopts", "ed_mapopts [comments|whole] [on|off]", "how maps are written: with numbered comments, with whole coordinates only"),
    ("ed_fire", "ed_fire <targetname>", "set off what has that name, in a game played from the studio"),
    ("ed_spawn", "ed_spawn <all|easy|normal|hard|deathmatch>", "show the level as it would spawn at a skill or in a mode"),
    ("ed_refield", "ed_refield <key> <old> <new> [all]", "replace part of a field's value across the selection, or every entity"),
    ("ed_pause", "ed_pause [on|off]", "hold a game played from the studio still, or let it run"),
    ("ed_tick", "ed_tick [count]", "let a held game's time move by so many sixtieths of a second"),
    ("ed_played", "ed_played [label]", "print how a game played from the studio stands"),
    ("ed_break", "ed_break [targetname|clear]", "hold a played game still when what has that name fires; or stop doing so; or list them"),
    ("ed_trace", "ed_trace [on|off]", "name each firing in a played game as it happens"),
    ("ed_fired", "ed_fired [label]", "print what has fired in the game played from here, how often and in what order"),
    ("ed_live", "ed_live [player health <n> | player at <x y z> | signal <name> on|off]", "look at a played game's player and signals, or change them"),
    (
        "ed_build",
        "ed_build [full|quick|flat|fresh]",
        "build the level again now; how it is lit: finely, coarsely, or not at all; or fresh, forgetting what was built before"
    ),
    ("ed_group_view", "ed_group_view <shown|grey|hidden>", "how the selected groups show: whole, as outlines only, or not at all"),
    ("ed_group_lock", "ed_group_lock [on|off]", "keep clicks in the views from selecting the selected groups"),
    ("ed_group_skip", "ed_group_skip [on|off]", "leave the selected groups out of what is built and played"),
    ("ed_group_tint", "ed_group_tint <r g b|none>", "the colour of the selected groups' outlines (0 to 255 each)"),
    ("ed_groups", "ed_groups", "list the groups and their switches"),
    ("ed_zoom", "ed_zoom <in|out|units>", "zoom the axis views (so many units fit their height), or move the 3D camera"),
    ("ed_ruler", "ed_ruler [on|off]", "show the selection's size along its edges in the axis views"),
    ("ed_names", "ed_names [on|off]", "show every entity's name in the views"),
    (
        "ed_backdrop",
        "ed_backdrop <file|off> [top|front|side] [across up] [units per pixel] [alpha]",
        "lay a picture behind an axis view, to draw over"
    ),
    ("ed_marks", "ed_marks", "list the remembered views"),
    ("ed_unmark", "ed_unmark <name>", "forget a remembered view"),
    ("ed_behind", "ed_behind", "take the 3D camera behind the picked face, looking at its back"),
    ("ed_swing", "ed_swing <yaw> <pitch>", "swing the 3D camera round the selection (degrees)"),
    ("ed_face_delete", "ed_face_delete", "take the picked faces off their brushes, where the others close without them"),
    ("ed_face_flip", "ed_face_flip", "turn the picked face to face the other way, leaving what lay beyond it"),
    ("ed_cone", "ed_cone [height]", "stand a cone on each picked face"),
    ("ed_extrude", "ed_extrude [depth]", "push each picked face out into a brush of its own"),
    ("ed_walls", "ed_walls [depth] [thickness]", "stand walls round the edge of each picked face"),
    (
        "ed_sideflag",
        "ed_sideflag <contents|flags|value> <number> [set|clear|put]",
        "set, clear or replace bits on the picked faces or the selected brushes' sides"
    ),
    ("ed_detail", "ed_detail [on|off]", "mark the selected brushes as detail, or as structural again"),
    ("ed_digger", "ed_digger [on|off]", "make the selected brushes holes, cut out of the rest when the level is built"),
    ("ed_keep", "ed_keep [name]", "keep the selection as a named set (the sets, without a name)"),
    ("ed_recall", "ed_recall <name> [add]", "select a set kept before, alone or added to the selection"),
    ("ed_forget", "ed_forget <name>", "drop a kept set"),
    ("ed_swap", "ed_swap", "the two selected things change places"),
    ("ed_browse", "ed_browse [next|prev]", "look at each selected thing in turn"),
    (
        "ed_gizmo",
        "ed_gizmo <move|turn|size|box|next>",
        "which handles a selection shows: arrows, rings, boxes, or one box round it all that moves, turns, sizes and shears"
    ),
    ("ed_texhandles", "ed_texhandles [on|off]", "show handles on the one picked face for its material: a dot that slides it and two arms that stretch, swing and turn it"),
    (
        "ed_texlay",
        "ed_texlay <s axis: x y z> <t axis: x y z> <s shift> <t shift> <s scale> <t scale>",
        "lay the material on the picked faces exactly so"
    ),
    ("ed_shear", "ed_shear <x|y|z> <x|y|z> <amount>", "shear the selection: slide it along one axis by so much for each unit along another"),
    (
        "ed_linear",
        "ed_linear <nine numbers> [about <x> <y> <z>] [Turn|Stretch|Shear]",
        "carry the selection through a change of the world: what the x, y and z axes become, about a point"
    ),
    ("ed_pivot", "ed_pivot [x y z | middle | clear]", "what the selection turns and stretches about; a group keeps its own"),
    ("ed_anglesnap", "ed_anglesnap [degrees]", "what a dragged turn snaps to"),
    ("ed_inflate", "ed_inflate <units|up|down>", "push every side of the selected brushes out (or in) by a distance"),
    ("ed_texlock", "ed_texlock [on|off]", "whether materials go with the faces a move, turn or stretch carries"),
    ("ed_stats", "ed_stats [file]", "count what the document holds, or write the materials it uses to a file"),
    ("ed_step", "ed_step <next|prev>", "select the entity after, or before, the selected one"),
    ("ed_freeze", "ed_freeze [on|off]", "keep clicks in the level from changing the selection, or let them"),
    ("ed_assetfind", "ed_assetfind <text>", "list the files of every game whose names hold some text"),
    (
        "ed_patch",
        "ed_patch <sheet|arch|bevel|cylinder|cone|endcap> [w d h] | grow <u|v> | shrink <u|v> | thick <units> | fine <n> | uv [fit [n [m]] | project | point <col> <row> <s> <t> | row <n> <ds> <dt> | col <n> <ds> <dt> | all <ds> <dt> | clear]",
        "add a curved patch where the camera looks; give the selected one another curve, thickness or fineness; or say where its control points lie on its material"
    ),
    ("ed_patch_point", "ed_patch_point <patch> <point> <dx> <dy> <dz>", "move one control point of a patch"),
    ("ed_face", "ed_face <brush> <side> [add]", "select a face of a brush"),
    (
        "ed_tex",
        "ed_tex <shift|shiftto|scale|turn|turnto|fit|minfit|flat|reset|wrap|project> [a] [b]",
        "change how the material lies on the selected faces, or on every side of the selected brushes; wrap and project take it from the tagged face"
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
        "ed_layout <1|2|3|4|4b|logic|assets>",
        "one level view, four (3D, top, front and side), the logic graph, or the asset explorer"
    ),
    ("ed_palette", "ed_palette", "open the list of every studio command, to find one by typing"),
    ("ed_grid", "ed_grid <size|up|down>", "the grid moves and resizes snap to (1 to 256)"),
    ("ed_mark", "ed_mark [name]", "remember where the camera is, in the document"),
    ("ed_goto", "ed_goto <name|next>", "put the camera where it was remembered"),
    ("ed_hide", "ed_hide [others]", "put the selection, or everything else, out of sight while editing"),
    ("ed_show", "ed_show", "bring back everything hidden"),
    ("ed_drop", "ed_drop", "let the selection down onto what is beneath it"),
    ("ed_history", "ed_history [steps]", "list the edits made, or undo that many"),
    ("ed_autosave", "ed_autosave", "write the scene to its autosave file now"),
    ("ed_asset", "ed_asset <dir:game:folder|file:game:name>", "open or close a folder of the explorer, or show a file"),
    ("ed_extract", "ed_extract [folder]", "write the file the explorer shows to disk"),
    ("ed_listen", "ed_listen", "play the sound the explorer shows"),
    ("ed_frame", "ed_frame <number|next|prev|play|stop>", "the frame of the model the explorer shows"),
    ("ed_orbit", "ed_orbit <yaw> <pitch> [distance]", "turn the model view (angles in degrees)"),
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
        "ed_dup <copies> <dx> <dy> <dz> [turn] | mirror <axes> | axis <x|y|z> | grow <f> | at <name> | path <name> | materials <names> | each [on|off] | hide | show | off | apply",
        "make the selected group build copies of itself (in a row, mirrored, at named points, along a path), stop it, or make the copies real"
    ),
    ("ed_link", "ed_link <from> <to>", "make one entity fire another"),
    ("ed_unlink", "ed_unlink <from> [to]", "stop an entity firing another, or anything"),
    ("ed_exec", "ed_exec <file>", "run a file of console commands"),
    ("ui_move", "ui_move <x> <y>", "script: move the pointer"),
    ("ui_click", "ui_click <x> <y> [button]", "script: click"),
    ("ui_double", "ui_double <x> <y>", "script: double click"),
    ("ui_drag", "ui_drag <x0> <y0> <x1> <y1> [button] [frames]", "script: drag"),
    ("ui_press", "ui_press <x> <y> [button]", "script: press a button and hold it"),
    ("ui_release", "ui_release <x> <y> [button]", "script: let the held button go"),
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
        high: Vec3,
        # Its group shows it as outlines only, or keeps clicks off it, or
        # gives its outlines a colour of the group's own (-1 for none).
        dim: bool = False,
        locked: bool = False,
        tint: int = -1;

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
        model_view: ViewArea,
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
        # A line or a rectangle being drawn in a view by a tool, and whether
        # the settings file has been read.
        lining: bool = False,
        settings_read: bool = False,
        # A rectangle dragged out over a view, to select what is in it.
        boxing: bool = False,
        box_port: int = 0,
        # How far a dragged corner or edge has gone.
        corner_by: Vec3 = Vec3(),
        # Which handles a selection shows (move, turn or size), how far a
        # dragged one has turned or stretched it, and what a turn snaps to.
        gizmo: str = "move",
        # What a drag of the box handle asks so far, and whether Shift is held on it.
        box_pull: BoxDrag = BoxDrag(),
        box_said: str = "",
        held_shift: bool = False,
        # Whether a picked face shows handles for its material, and how the
        # material would lie as a drag of one stands.
        lay_shown: bool = False,
        lay_pull: Mapping | None = None,
        turn_by: float = 0.0,
        size_by: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        angle_snap: float = 15.0,
        # A pivot set by hand, and whether it is in force.
        pivot_at: Vec3 = Vec3(),
        pivot_set: bool = False,
        pivot_picks: int = -1,
        # Whether materials go with the faces a move, turn or stretch carries.
        tex_lock: bool = True,
        # A ruler along the selection in the axis views, a name on every
        # entity, and the picture laid behind an axis view.
        ruler: bool = True,
        names: bool = False,
        backdrop_seen: str = "",
        # Where the last click was and how deep it went, so another there
        # goes to what is behind; and where a tour of the selection has got to.
        click_x: int = -100,
        click_y: int = -100,
        click_port: int = -1,
        click_turn: int = 0,
        click_serial: int = -1,
        click_solid: bool = False,
        browse_turn: int = -1,
        browse_picks: int = -1,
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
        # The model the explorer shows: its frame, whether it plays, the
        # edges drawn, and the camera that goes round it.
        model_now: ModelLook | None = None,
        model_frame: int = 0,
        model_clock: float = 0.0,
        model_playing: bool = False,
        model_edges: list[list[Vec3]] = [],
        model_camera: EditCamera = EditCamera(),
        model_yaw: float = 0.6,
        model_pitch: float = -0.25,
        model_reach: float = 128.0,
        model_middle: Vec3 = Vec3(),
        # Clicks in the level leave the selection alone.
        frozen: bool = False,
        asset_filter: str = "",
        # How long the level last took to build, in milliseconds.
        build_ms: int = 0,
        # The face brushes are glued against, as its plane and what it was.
        tagged: Plane3 | None = None,
        # The tagged face itself, for its material and how it lies; and a
        # stroke of the material in hand across faces, with the last one it touched.
        tagged_side: Side | None = None,
        painting: bool = False,
        painted_solid: int = -1,
        painted_side: int = -1,
        tagged_words: str = "",
        # The sculpting brush, whether a stroke is being drawn, drags since
        # its last dab, and where on a terrain the pointer is.
        brush_radius: float = 96.0,
        brush_amount: float = 16.0,
        sculpting: bool = False,
        sculpt_drags: int = 0,
        sculpt_at: Vec3 | None = None,
        # The terrain under the pointer, by its number (-1 when none).
        sculpt_land: int = -1,
        # A build for playing takes everything; one for editing leaves out
        # what is hidden.
        play_build: bool = False,
        # Playing only what is selected; and how coarse the light is baked
        # (world units to a lightmap texel).
        play_only: bool = False,
        # How wide the cells are that a built level is cut into (none when
        # it is zero: the level is one leaf), and what the last bake did.
        vis_cell: float = 0.0,
        vis_done: VisReport = VisReport(),
        # The bake's cells drawn; recipes of commands by name; and the
        # light and cells of levels already built, by a mark of what they
        # were built of.
        cells_shown: bool = False,
        recipes: dict[str, str] = {},
        built_copies: list[KeptBake] = [],
        built_reused: bool = False,
        # The project open and its folder; the add-ons loaded (each file's
        # classes), those of them kept in the settings; and what each game
        # is set up with ("q1.material" and the like).
        project: Project | None = None,
        project_folder: str = "",
        addons: dict[str, list[str]] = {},
        user_addons: list[str] = [],
        game_setup: dict[str, str] = {},
        game_applied: str = "",
        # The program kept for each ending of file; the image files in use
        # and when each was last changed, looked at twice a second; and how
        # the mouse turns the camera and the wheel moves it.
        assoc: dict[str, str] = {},
        watching: bool = True,
        watched: dict[str, float] = {},
        watch_clock: float = 0.0,
        watch_count: int = 0,
        # How a view held to a band of depth shows what lies outside it
        # ("whole", "grey" or "hide"), and the camera of the view being drawn.
        outside: str = "grey",
        lens_now: EditCamera | None = None,
        # A played game watched: each signal's count when last looked at,
        # how often each name has fired and in what order, the names whose
        # firing holds the game, and whether each firing is named aloud.
        fired_seen: list[int] = [],
        fired_names: dict[str, int] = {},
        fire_log: list[str] = [],
        breaks: list[str] = [],
        tracing: bool = False,
        # The model being edited (none when the explorer only shows one),
        # the revision of it that is drawn, and whether its box and its axes
        # are drawn with it.
        # A plot of a terrain: the cells picked to work on, whose terrain
        # they are, and how far apart in height cells and corners may be
        # and still go together.
        # The shader script open: its file, its shaders, which is in hand,
        # what was wrong with how it was put together when read, and
        # whether it has been changed since.
        shader_file: str = "",
        shader_list: list[ShaderText] = [],
        shader_now: int = -1,
        shader_broken: list[ShaderFault] = [],
        shader_dirty: bool = False,
        plot: list[int] = [],
        plot_land: Item | None = None,
        plot_variance: float = 0.0,
        # Entities drawn as their game's models in the 3D view: whether,
        # each model's edges once read, and how many were drawn last.
        models_shown: bool = False,
        preview_models: dict[str, list[list[Vec3]]] = {},
        models_drawn: int = 0,
        model_doc: ModelDoc | None = None,
        model_seen: int = -1,
        model_box: bool = False,
        model_axes: bool = False,
        # What a click in the model's view picks ("faces" or "points"), how
        # far the pointer has gone since it was pressed there, and how far
        # the picked points are being dragged.
        # The picture being painted for the model, the colour and brush it
        # is painted with, how many dabs it has had, whether it is shown
        # under the model, and the widget that shows it.
        model_skin: Skin | None = None,
        skin_color: list[int] = [255, 122, 24],
        skin_radius: float = 4.0,
        skin_soft: bool = False,
        skin_strength: float = 1.0,
        skin_dabs: int = 0,
        skin_stale: bool = False,
        skin_shown: bool = False,
        skin_view: Picture | None = None,
        model_painting: bool = False,
        model_pick: str = "faces",
        model_travel: int = 0,
        model_drag: Vec3 = Vec3(),
        # The bone in hand, whether points show their bones' colours, and a
        # bone's end being dragged: which, from where, and how far round.
        bone_now: str = "",
        bones_tinted: bool = False,
        bone_held: str = "",
        bone_press_x: int = 0,
        bone_press_y: int = 0,
        bone_swept: float = 0.0,
        look_rate: float = 1.0,
        look_flipped: bool = False,
        wheel_rate: float = 1.0,
        wheel_flipped: bool = False,
        # The classes kept as favourites.
        favourites: list[str] = [],
        # The axis views' grid shown, with numbers along its edges; levels
        # drawn in flat tones in place of their textures; keys bound by
        # hand; and the developer's readout in the status bar.
        grid_shown: bool = True,
        solid_tones: bool = False,
        user_keys: dict[str, str] = {},
        dev_shown: bool = False,
        frame_ms: float = 0.0,
        # Whether a shape is built with the faces inside it caulked.
        autocaulk: bool = False,
        # Whether duplicators' images are in what is built.
        images_shown: bool = True,
        # Where each open document's 3D camera was left, how maps are
        # written, and where a right press began.
        doc_views: dict[str, list[float]] = {},
        map_comments: bool = True,
        map_whole: bool = False,
        right_x: int = 0,
        right_y: int = 0,
        # The skill or mode the level is shown as it would spawn for, and
        # what that hides.
        spawn_mode: str = "all",
        spawn_hidden: list[Item] = [],
        luxel: float = 16.0,
        marks_at: int = -1,
        # Seconds since the scene was last autosaved, and the revision it was at.
        autosave_clock: float = 0.0,
        autosaved: int = -1,
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
        self.read_settings();
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
    def play(here: bool, only: bool = False) {
        app = self.app;
        scene = self.scene;
        if app is None or scene is None {
            return;
        }
        if only and not (scene.selection() or scene.selected_solids()) {
            self.say("Select what to play alone");
            return;
        }
        if only and not self.is_built_scene() {
            self.say("Only a scene of brushes can be played in part");
            return;
        }
        if scene.game != "passion" {
            app.staged_entities[scene.game + "/" + scene.name] = scene.text();
        }
        self.leave();
        # What is hidden while editing is in the level that is played.
        self.play_build = True;
        self.play_only = only;
        loaded_now = self.load(scene.game, scene.name);
        self.play_build = False;
        self.play_only = False;
        if not loaded_now {
            # The document does not load: back to it.
            self.enter(reset_camera=False);
            return;
        }
        self.playing = True;
        self.holding = False;
        self.steps_owed = 0;
        # What fires is counted from the start of each game.
        self.fired_seen = [];
        self.fired_names = {};
        self.fire_log = [];
        if here or only {
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
        self.holding = False;
        self.steps_owed = 0;
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
            titles=["File", "Edit", "View", "Brush", "Play", "Window"],
            menus=[
                [
                    MenuItem(text="Save", command="ed_save", keys="Ctrl+S"),
                    MenuItem(text="New scene", command="ed_scene"),
                    MenuItem(text="Turn this level into brushes", command="ed_convert"),
                    MenuItem(text="Revert to the shipped map", command="ed_revert"),
                    MenuItem(rule=True),
                    MenuItem(text="Run a command", command="ed_palette", keys="Ctrl+P"),
                    MenuItem(text="Leave the studio", command="edit", keys="F8"),
                    MenuItem(text="Quit", command="quit")
                ],
                [
                    MenuItem(text="Undo", command="ed_undo", keys="Ctrl+Z"),
                    MenuItem(text="Redo", command="ed_redo", keys="Ctrl+Y"),
                    MenuItem(text="History", command="ed_history"),
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
                    MenuItem(text="Next entity", command="ed_step next", keys="Tab"),
                    MenuItem(text="The owner of the selected brushes", command="ed_select parent"),
                    MenuItem(text="The brushes of the selected entities", command="ed_select child"),
                    MenuItem(text="Look at each selected in turn", command="ed_browse", keys="N"),
                    MenuItem(text="Swap the two selected", command="ed_swap"),
                    MenuItem(text="Freeze the selection", command="ed_freeze"),
                    MenuItem(text="Hide the selection", command="ed_hide", keys="H"),
                    MenuItem(text="Hide everything else", command="ed_hide others", keys="Ctrl+H"),
                    MenuItem(text="Show everything", command="ed_show", keys="Shift+H"),
                    MenuItem(text="Drop to the floor", command="ed_drop", keys="End"),
                    MenuItem(rule=True),
                    MenuItem(text="Pick brushes and entities", command="ed_mode brush", keys="1"),
                    MenuItem(text="Pick faces", command="ed_mode face", keys="2"),
                    MenuItem(text="Move corners and edges", command="ed_mode corner", keys="3"),
                    MenuItem(text="Sculpt terrain", command="ed_mode sculpt", keys="4"),
                    MenuItem(text="Cut along a drawn line", command="ed_mode clip", keys="5"),
                    MenuItem(text="Draw boxes in the axis views", command="ed_mode draw", keys="6"),
                    MenuItem(rule=True),
                    MenuItem(text="Check the map", command="ed_check"),
                    MenuItem(text="Count what it holds", command="ed_stats"),
                    MenuItem(text="Look for a leak", command="ed_leak")
                ],
                [
                    MenuItem(text="One view", command="ed_layout 1"),
                    MenuItem(text="Two views", command="ed_layout 2"),
                    MenuItem(text="Three views", command="ed_layout 3"),
                    MenuItem(text="Four views", command="ed_layout 4"),
                    MenuItem(text="Four views, the axis views in a column", command="ed_layout 4b"),
                    MenuItem(rule=True),
                    MenuItem(text="Zoom in", command="ed_zoom in", keys="="),
                    MenuItem(text="Zoom out", command="ed_zoom out", keys="-"),
                    MenuItem(text="Ruler on the selection", command="ed_ruler"),
                    MenuItem(text="Names on every entity", command="ed_names"),
                    MenuItem(text="Behind the picked face", command="ed_behind"),
                    MenuItem(text="The remembered views", command="ed_marks"),
                    MenuItem(rule=True),
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
                    MenuItem(text="Look at everything", command="ed_focus all"),
                    MenuItem(text="Remember this view", command="ed_mark"),
                    MenuItem(text="Next remembered view", command="ed_goto next"),
                    MenuItem(text="Finer grid", command="ed_grid down", keys="["),
                    MenuItem(text="Coarser grid", command="ed_grid up", keys="]"),
                    MenuItem(text="Console", command="toggleconsole", keys="`"),
                    MenuItem(rule=True),
                    MenuItem(text="Hold this view to the selection's depth", command="ed_depth selection"),
                    MenuItem(text="Show every depth in this view", command="ed_depth off"),
                    MenuItem(text="Outside the depth: whole, grey or hidden", command="ed_outside"),
                    MenuItem(text="Straighten this view", command="ed_oblique off"),
                    MenuItem(text="Layers", command="ed_layer"),
                    MenuItem(text="Entities as their models", command="ed_models")
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
                    MenuItem(text="Terrain", command="ed_terrain"),
                    MenuItem(text="Curved sheet", command="ed_patch sheet"),
                    MenuItem(text="Curved arch", command="ed_patch arch"),
                    MenuItem(text="Curved corner", command="ed_patch bevel"),
                    MenuItem(text="Curved cylinder", command="ed_patch cylinder"),
                    MenuItem(text="Curved cone", command="ed_patch cone"),
                    MenuItem(rule=True),
                    MenuItem(text="Turn a quarter", command="ed_rotate 90", keys="R"),
                    MenuItem(text="Tip a quarter about x", command="ed_rotate 90 x"),
                    MenuItem(text="Tip a quarter about y", command="ed_rotate 90 y"),
                    MenuItem(text="Mirror along x", command="ed_mirror x"),
                    MenuItem(text="Mirror along y", command="ed_mirror y"),
                    MenuItem(text="Mirror along z", command="ed_mirror z"),
                    MenuItem(rule=True),
                    MenuItem(text="Handles that move", command="ed_gizmo move"),
                    MenuItem(text="Handles that turn", command="ed_gizmo turn"),
                    MenuItem(text="Handles that size", command="ed_gizmo size", keys="G"),
                    MenuItem(text="Pivot at the selection's middle", command="ed_pivot middle"),
                    MenuItem(text="No pivot", command="ed_pivot clear"),
                    MenuItem(text="Grow by a grid step", command="ed_inflate up"),
                    MenuItem(text="Shrink by a grid step", command="ed_inflate down"),
                    MenuItem(text="Materials stay with their faces", command="ed_texlock"),
                    MenuItem(rule=True),
                    MenuItem(text="Carve out of the others", command="ed_carve"),
                    MenuItem(text="Keep what they share", command="ed_intersect"),
                    MenuItem(text="Hollow", command="ed_hollow"),
                    MenuItem(text="Merge", command="ed_merge"),
                    MenuItem(rule=True),
                    MenuItem(text="Snap to the grid", command="ed_snap"),
                    MenuItem(text="The brush's next face", command="ed_faces next"),
                    MenuItem(text="The brush's face before", command="ed_faces prev"),
                    MenuItem(text="Delete the picked faces", command="ed_face_delete"),
                    MenuItem(text="Turn the picked face round", command="ed_face_flip"),
                    MenuItem(text="Cone on the picked faces", command="ed_cone"),
                    MenuItem(text="Extrude the picked faces", command="ed_extrude"),
                    MenuItem(text="Walls round the picked faces", command="ed_walls"),
                    MenuItem(text="Make detail", command="ed_detail"),
                    MenuItem(text="Make structural", command="ed_detail off"),
                    MenuItem(text="Dig: make these brushes holes", command="ed_digger"),
                    MenuItem(text="Fill in: solid again", command="ed_digger off"),
                    MenuItem(text="Tag the picked face", command="ed_tag"),
                    MenuItem(text="Glue to the tagged face", command="ed_glue"),
                    MenuItem(text="Group", command="ed_group", keys="Ctrl+G"),
                    MenuItem(text="Four in a row", command="ed_dup 3 64 0 0"),
                    MenuItem(text="Four round the middle", command="ed_dup 3 0 0 0 90"),
                    MenuItem(text="Mirror image along x", command="ed_dup mirror x"),
                    MenuItem(text="Make the copies real", command="ed_dup apply"),
                    MenuItem(text="Hand to the world", command="ed_tie"),
                    MenuItem(rule=True),
                    MenuItem(text="Fit the material, keeping its scale", command="ed_tex minfit"),
                    MenuItem(text="Wrap the tagged face's material round", command="ed_tex wrap"),
                    MenuItem(text="Lay the tagged face's material on", command="ed_tex project"),
                    MenuItem(text="Put the picked face in the tagged plane", command="ed_glue face"),
                    MenuItem(text="Forget the tagged face", command="ed_tag clear"),
                    MenuItem(rule=True),
                    MenuItem(text="Sweep the sweeps along their paths again", command="ed_sweep again"),
                    MenuItem(rule=True),
                    MenuItem(text="Link the picked faces, or the selected brushes' shared planes", command="ed_facelink"),
                    MenuItem(text="Take their links away", command="ed_facelink clear"),
                    MenuItem(text="Carve, keeping divided faces linked", command="ed_carve link"),
                    MenuItem(text="Mitre the two selected brushes", command="ed_miter"),
                    MenuItem(rule=True),
                    MenuItem(text="Spread the material over the selected patch", command="ed_patch uv fit"),
                    MenuItem(text="Lay the tagged face's material on the selected patch", command="ed_patch uv project"),
                    MenuItem(rule=True),
                    MenuItem(text="One handle that moves, turns, sizes and shears", command="ed_gizmo box"),
                    MenuItem(text="Lean a quarter along x", command="ed_shear x z 0.25"),
                    MenuItem(text="Handles on the picked face for its material", command="ed_texhandles")
                ],
                [
                    MenuItem(text="Play", command="ed_play", keys="F5"),
                    MenuItem(text="Play from here", command="ed_play here", keys="F6"),
                    MenuItem(text="Play only the selection", command="ed_play selection"),
                    MenuItem(text="Show as on easy", command="ed_spawn easy"),
                    MenuItem(text="Show as on hard", command="ed_spawn hard"),
                    MenuItem(text="Show as in deathmatch", command="ed_spawn deathmatch"),
                    MenuItem(text="Show everything that spawns", command="ed_spawn all"),
                    MenuItem(rule=True),
                    MenuItem(text="Build again now", command="ed_build"),
                    MenuItem(text="Light finely", command="ed_build full"),
                    MenuItem(text="Light coarsely (quicker)", command="ed_build quick"),
                    MenuItem(text="No light (quickest)", command="ed_build flat"),
                    MenuItem(rule=True),
                    MenuItem(text="Bake what each part can see", command="ed_bake"),
                    MenuItem(text="Build as one again", command="ed_bake off"),
                    MenuItem(text="Show the bake's cells", command="ed_cells"),
                    MenuItem(rule=True),
                    MenuItem(text="Recipes", command="ed_recipe"),
                    MenuItem(rule=True),
                    MenuItem(text="What fired in the last game", command="ed_fired"),
                    MenuItem(text="Name each firing as it happens", command="ed_trace"),
                    MenuItem(text="Firings that hold the game", command="ed_break")
                ],
                [
                    MenuItem(text="Next document", command="ed_doc next"),
                    MenuItem(text="The document before", command="ed_doc prev"),
                    MenuItem(text="Save all", command="ed_save all"),
                    MenuItem(text="Close this document", command="ed_close"),
                    MenuItem(rule=True),
                    MenuItem(text="Recent files", command="ed_recent"),
                    MenuItem(text="The console's last lines", command="ed_log"),
                    MenuItem(rule=True),
                    MenuItem(text="Settings", command="ed_settings"),
                    MenuItem(text="Keys bound by hand", command="ed_binds"),
                    MenuItem(text="Developer's readout", command="ed_dev"),
                    MenuItem(rule=True),
                    MenuItem(text="The project", command="ed_project"),
                    MenuItem(text="Add-ons", command="ed_addon"),
                    MenuItem(text="Games", command="ed_game"),
                    MenuItem(rule=True),
                    MenuItem(text="The mouse", command="ed_mouse"),
                    MenuItem(text="Programs kept for files", command="ed_assoc"),
                    MenuItem(text="Open the material's file", command="ed_openwith"),
                    MenuItem(text="Read image files again", command="ed_reload"),
                    MenuItem(rule=True),
                    MenuItem(text="Edit the model shown", command="ed_model edit"),
                    MenuItem(text="Check the model", command="ed_model check"),
                    MenuItem(text="Undo in the model", command="ed_model undo"),
                    MenuItem(rule=True),
                    MenuItem(text="The shader script's shaders", command="ed_shader"),
                    MenuItem(text="Check the shader script", command="ed_shader check"),
                    MenuItem(rule=True),
                    MenuItem(text="The model's bones", command="ed_bone"),
                    MenuItem(text="Give every point to the bone nearest it", command="ed_bone auto"),
                    MenuItem(text="Points in their bones' colours", command="ed_bone colours"),
                    MenuItem(rule=True),
                    MenuItem(text="A Quake III body, put together", command="ed_body"),
                    MenuItem(text="Quake's shotgun as held in view", command="ed_viewweapon q1 2"),
                    MenuItem(rule=True),
                    MenuItem(text="The districts' materials", command="ed_district"),
                    MenuItem(text="Check the districts' materials", command="ed_district check")
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
            ("corner", "Corners", "A brush shows its corners and edges, to drag (3)"),
            ("sculpt", "Sculpt", "A drag raises terrain; Shift lowers it and Ctrl smooths it (4)"),
            ("clip", "Clip", "A line drawn across a view cuts the selected brushes along it (5)"),
            ("draw", "Draw", "A rectangle drawn in an axis view becomes a box (6)")
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
            drag="material",
            grow=1,
            hint="Click a material to give it to the selected faces or brushes, and to new brushes; drag it onto a face"
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
            drag="library",
            grow=1,
            hint="Click a scene to open it, or a prefab to add a copy where the camera looks; drag a prefab into a view"
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
            drag="class",
            grow=1,
            hint="Click a class to add one where the camera looks, or drag it into a view; a brush class takes the selected brushes"
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
        asset_list = Box(grow=1);
        asset_box.adopt(asset_list);
        asset_search = Box(pad=4);
        asset_list.adopt(asset_search);
        asset_search.adopt(
            TextField(
                ghost="Find a file by name", command="ed_assetfind", hint="Enter lists every file whose name holds this"
            )
        );
        asset_tree = TreeView(
            pick="ed_asset",
            toggle="ed_asset",
            grow=1,
            hint="Click a folder to open it, a file to see it"
        );
        asset_list.adopt(asset_tree);
        # No fill: the model is drawn before the interface, and shows through.
        asset_side = Box(size=340);
        asset_box.adopt(asset_side);
        asset_side.adopt(Header(text="File"));
        model_view = ViewArea(grow=1, hint="Drag: turn the model | wheel: nearer or further");
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
            model_view=model_view,
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
                if item.hidden or item_veil(item) == "hidden" {
                    continue;
                }
                owned = [solid for solid in scene.solids_of(item) if not solid.hidden];
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
        for (index, word) in enumerate(["brush", "face", "corner", "sculpt", "clip", "draw"]) {
            ui.modes[index].lit = self.mode == word;
        }
        eye = self.main.eye;
        concealed = scene.hidden_count();
        ui.place.text = self.dev_words(scene) + ("frozen   " if self.frozen else "")
            + (str(concealed) + " hidden   " if concealed else "")
            + (str(self.build_ms) + " ms   " if self.build_ms > 0 else "") + "grid " + str(int(self.grid)) + "   "
            + str(int(eye.x)) + " " + str(int(eye.y)) + " " + str(int(eye.z));
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
                if name == "func_group" {
                    # A group by its own name, with its switches, and its
                    # brushes under it when it is opened.
                    self.list_group(scene, rows, item, picked);
                    continue;
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
        self.fill_group(scene, ui, chosen);
        self.fill_skill(scene, ui, chosen);
        self.fill_controls(scene, ui, chosen);
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
        # A running mean of how long a frame takes, for the developer's readout.
        self.frame_ms = self.frame_ms * 0.9 + dt * 100.0;
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
        self.turn_model(dt);
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
        signature = self.class_game() + "|" + self.class_filter + "|" + str(self.folds);
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
        self.autosave(dt, False);
        self.watch_files(dt);
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
            if event.kind == "drop" {
                # Something dragged from a side panel and let go here.
                self.dropped(scene, event.x, event.y, event.text);
                continue;
            }
            if event.kind == "press" and event.button == 1 {
                self.looking = True;
                self.right_x = event.x;
                self.right_y = event.y;
            } elif event.kind == "press" and event.button == 2 {
                self.panning = True;
            } elif event.kind == "click" and event.button == 1 {
                # A right click that did not travel, on something selected:
                # the selection's menu.
                if abs(event.x - self.right_x) + abs(event.y - self.right_y) <= 3 {
                    under_click = self.aim(event.x, event.y);
                    clicked_solid = under_click.solid;
                    clicked_item = under_click.item;
                    if (clicked_solid is not None and scene.is_solid_selected(clicked_solid))
                        or (clicked_item is not None and scene.is_selected(clicked_item)) {
                        self.selection_menu(scene, event.x, event.y);
                    }
                }
            } elif event.kind == "press" and event.button == 0 {
                # A press on a side handle resizes; one on something selected
                # starts moving the selection.
                self.moved = False;
                self.press_x = event.x;
                self.press_y = event.y;
                if self.camera.oblique() {
                    dial = self.compass_at(self.view_area());
                    if abs(event.x - dial[0]) <= dial[2] and abs(event.y - dial[1]) <= dial[2] {
                        # A press on the compass straightens the view.
                        stage.emit("ed_oblique " + self.ports[index].title.split()[0].lower() + " off");
                        self.moved = True;
                        continue;
                    }
                }
                if self.mode == "clip" or self.mode == "draw" {
                    # A line, or a rectangle, from here to where the button is let go.
                    self.lining = True;
                    self.box_port = index;
                    continue;
                }
                if self.mode == "face" and event.alt {
                    # Alt and a drag paints the material in hand across faces.
                    self.painting = True;
                    self.painted_solid = -1;
                    self.painted_side = -1;
                    continue;
                }
                if self.mode == "sculpt" and event.alt {
                    # With Alt a press picks the plot of cells there.
                    spot = self.drop_point(scene, event.x, event.y, 0.0);
                    stage.emit(
                        "ed_plot " + str(int(spot.x)) + " " + str(int(spot.y)) + (" add" if event.shift else "")
                    );
                    self.moved = True;
                    continue;
                }
                if self.mode == "sculpt" {
                    # The first dab of a stroke.
                    self.sculpting = True;
                    self.sculpt_drags = 0;
                    self.dab(scene, event.x, event.y, event.shift, event.ctrl);
                    continue;
                }
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
                if event.button == 0 and self.sculpting {
                    self.sculpting = False;
                    self.moved = True;
                }
                if event.button == 0 and self.lining {
                    self.lining = False;
                    self.moved = True;
                    if abs(event.x - self.press_x) + abs(event.y - self.press_y) > 6 {
                        ends = str(self.box_port) + " " + str(self.press_x) + " " + str(self.press_y) + " "
                            + str(event.x) + " " + str(event.y);
                        if self.mode == "clip" {
                            stage.emit(
                                "ed_clip_line " + ends + (" back" if event.shift else (" front" if event.ctrl else ""))
                            );
                        } else {
                            stage.emit("ed_box_draw " + ends);
                        }
                    }
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
                if event.button == 0 and self.painting {
                    self.painting = False;
                }
                if event.button == 0 and self.resizing and self.resize_side >= 910 {
                    # A turn or size handle let go: the drag becomes its command.
                    # A press on a handle is never a click on what lies under it.
                    self.resizing = False;
                    self.moved = True;
                    order = self.transform_words(scene);
                    self.turn_by = 0.0;
                    self.size_by = Vec3(x=1.0, y=1.0, z=1.0);
                    self.corner_by = Vec3();
                    self.box_pull = BoxDrag();
                    self.lay_pull = None;
                    if order {
                        stage.emit(order);
                    }
                }
                if event.button == 0 and self.resizing {
                    self.resizing = False;
                    self.moved = abs(event.x - self.press_x) + abs(event.y - self.press_y) > 3;
                    bent = self.patch_now(scene);
                    if self.mode == "corner" and bent is not None {
                        pulled = self.corner_by;
                        if pulled.length() > 0.0 {
                            stage.emit(
                                "ed_patch_point " + str(bent.serial) + " " + str(self.resize_side) + " "
                                    + str(int(pulled.x)) + " " + str(int(pulled.y)) + " " + str(int(pulled.z))
                            );
                        }
                        self.corner_by = Vec3();
                    } elif self.mode == "corner" {
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
            } elif event.kind == "drag" and self.painting {
                brushed = self.aim(event.x, event.y);
                brushed_solid = brushed.solid;
                if brushed_solid is not None
                    and (brushed_solid.serial != self.painted_solid or brushed.side != self.painted_side) {
                    # Each face once, as the pointer comes onto it.
                    self.painted_solid = brushed_solid.serial;
                    self.painted_side = brushed.side;
                    self.moved = True;
                    stage.emit("ed_paintface " + str(brushed_solid.serial) + " " + str(brushed.side));
                }
            } elif event.kind == "drag" and self.sculpting {
                # A dab every few moves of the pointer, so a stroke builds up evenly.
                self.sculpt_drags += 1;
                if self.sculpt_drags % 3 == 0 {
                    self.dab(scene, event.x, event.y, event.shift, event.ctrl);
                }
            } elif event.kind == "drag" and self.resizing {
                self.held_shift = event.shift;
                self.drag_handle(scene, event.x, event.y, event.ctrl);
            } elif event.kind == "drag" and self.moving {
                self.drag_selection(event.x, event.y, event.shift, event.ctrl);
            } elif event.kind == "drag" {
                if self.camera.span > 0.0 {
                    if self.looking and event.alt {
                        # With Alt an axis view is turned off its axis.
                        self.camera.turn(
                            -float(event.dx) * 0.005 * self.look_rate,
                            -float(event.dy) * 0.005 * self.look_rate * (-1.0 if self.look_flipped else 1.0)
                        );
                    } elif self.looking or self.panning {
                        # An axis view slides under either button.
                        self.camera.pan(self.view_area(), event.dx, event.dy);
                    }
                } elif self.looking and event.alt {
                    # With Alt the camera goes round what is selected.
                    self.swing(
                        scene,
                        -float(event.dx) * 0.005 * self.look_rate,
                        -float(event.dy) * 0.005 * self.look_rate * (-1.0 if self.look_flipped else 1.0)
                    );
                } elif self.looking {
                    self.camera.turn(
                        -float(event.dx) * 0.005 * self.look_rate,
                        -float(event.dy) * 0.005 * self.look_rate * (-1.0 if self.look_flipped else 1.0)
                    );
                } elif self.panning {
                    scale = 1.0 if not event.shift else 4.0;
                    self.camera.eye = self.camera.eye.sub(self.camera.right().scale(float(event.dx) * scale)).add(
                        self.camera.up().scale(float(event.dy) * scale)
                    );
                }
            } elif event.kind == "wheel" {
                turned = event.wheel * self.wheel_rate * (-1.0 if self.wheel_flipped else 1.0);
                if self.camera.span > 0.0 {
                    self.camera.zoom(0.85 ** turned);
                } else {
                    self.camera.fly(turned * (256.0 if event.shift else 64.0), 0.0, 0.0);
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
                if self.frozen and not event.alt {
                    # The selection is frozen: a click is only a click.
                    continue;
                }
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
                if self.mode == "brush" and not (event.ctrl or event.shift) {
                    # Clicked again in the same place, a click goes to what is behind.
                    deeper = self.aim_through(scene, event.x, event.y);
                    found_item = deeper.item;
                    found_solid = deeper.solid;
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
            self.sculpting = False;
            self.lining = False;
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
        self.sculpt_at = None;
        if over_view and self.mode == "sculpt" and not self.looking and not self.panning {
            self.sculpt_at = self.terrain_point(scene, input.x, input.y);
        }
    }

    """The keys no field took."""
    def shortcuts(keys: list[str], shift: bool, ctrl: bool) {
        stage = self.stage;
        if stage is None {
            return;
        }
        for key in keys {
            # A key bound by hand comes before what the studio gives it.
            chord = ("ctrl+" if ctrl else "") + ("shift+" if shift else "") + key.lower();
            if chord in self.user_keys {
                stage.emit(self.user_keys[chord]);
                continue;
            }
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
            } elif key == "g" and not ctrl {
                stage.emit("ed_gizmo next");
            } elif key == "=" or key == "+" {
                stage.emit("ed_zoom in");
            } elif key == "-" and not ctrl {
                stage.emit("ed_zoom out");
            } elif key == "n" and not ctrl {
                stage.emit("ed_browse prev" if shift else "ed_browse next");
            } elif ctrl and key == "p" {
                stage.emit("ed_palette");
            } elif ctrl and key == "h" {
                stage.emit("ed_hide others");
            } elif key == "h" {
                stage.emit("ed_show" if shift else "ed_hide");
            } elif key == "TAB" {
                stage.emit("ed_step prev" if shift else "ed_step next");
            } elif key == "END" {
                stage.emit("ed_drop");
            } elif key == "[" {
                stage.emit("ed_grid down");
            } elif key == "]" {
                stage.emit("ed_grid up");
            } elif key == "l" {
                stage.emit("ed_layout " + (str(self.layout) if self.logic_shown else "logic"));
            } elif key == "1" {
                stage.emit("ed_mode brush");
            } elif key == "2" {
                stage.emit("ed_mode face");
            } elif key == "3" {
                stage.emit("ed_mode corner");
            } elif key == "4" {
                stage.emit("ed_mode sculpt");
            } elif key == "5" {
                stage.emit("ed_mode clip");
            } elif key == "6" {
                stage.emit("ed_mode draw");
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
        # Two and three views are the first ports; both layouts of four show all.
        return min(len(self.ports), 4 if self.layout >= 4 else self.layout);
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
        self.layout = count if count in [2, 3, 4, 5] else 1;
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
        ui.center.adopt(upper);
        upper.adopt(self.ports[0].view);
        if self.layout == 2 {
            # The classic pair: the 3D view beside the plan.
            upper.adopt(self.ports[1].view);
            return;
        }
        if self.layout == 3 or self.layout == 5 {
            # The 3D view beside a column of axis views: two, or all three.
            column = Box(grow=1, gap=3);
            upper.adopt(column);
            for index in range(1, 3 if self.layout == 3 else 4) {
                column.adopt(self.ports[index].view);
            }
            return;
        }
        lower = Box(across=True, grow=1, gap=3);
        ui.center.adopt(lower);
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
                if shape.item in tried or item_veil(shape.item) != "" or item_switched(shape.item, LOCK_KEY)
                    or self.unpickable(shape.low, shape.high) {
                    # What is tried, shown as outlines only, locked, or left out of this view.
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
        shown_model = self.model_now;
        if self.assets_shown and shown_model is not None and ui_model_area(self.ui).w > 0 {
            # The explorer's model, alone in its own view.
            spot = ui_model_area(self.ui);
            seen.append(
                SceneView(
                    x=spot.x,
                    y=spot.y,
                    width=spot.w,
                    height=spot.h,
                    eye=self.model_camera.eye,
                    yaw=self.model_camera.yaw,
                    pitch=self.model_camera.pitch,
                    span=0.0,
                    everything=True,
                    bare=True
                )
            );
        }
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
        step = max(1.0, self.grid);
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
        if self.assets_shown {
            # The only view then is the explorer's model.
            for pair in self.model_edges {
                wire_line(pair[0], pair[1], ink(0xe6dfd4));
            }
            self.draw_model_marks();
            return;
        }
        self.lens_now = self.lens_of(view);
        seeing = self.lens_now;
        if view.span > 0.0 and self.grid_shown and (seeing is None or not seeing.oblique()) {
            # A view off its axis has no plane of its own to rule.
            self.draw_grid(view);
        }
        self.bare_now = view.bare;
        chosen: list[Shape] = [];
        for shape in self.shapes {
            if scene.is_selected(shape.item) {
                chosen.append(shape);
            } else {
                # Outside the band of depth this view is held to: fainter, or not there.
                veil = self.veiled(shape.low, shape.high);
                if veil < 2 {
                    wire_box(shape.low, shape.high, shape.tone.faded(200 if veil == 0 else 45));
                }
            }
        }
        # The selection, what it targets and what is pointed at show through
        # the walls.
        rlDrawRenderBatchActive();
        rlDisableDepthTest();
        if self.resizing and self.resize_side >= 910
            and (self.resize_side < 940 or (self.resize_side >= 950 and self.resize_side <= 958)) {
            self.draw_transform_preview(scene);
        }
        self.draw_paths();
        self.draw_camps();
        self.draw_entity_models(scene);
        for shape in chosen {
            if self.moving {
                # Where the drag would leave it, over where it is.
                wire_box(shape.low.add(self.move_by), shape.high.add(self.move_by), ink(0xff7a18));
            }
            wire_box(shape.low, shape.high, ink(0xffffff));
            self.draw_marks(shape);
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
                # What it removes when it fires, in red.
                doomed = shape.item.fields.get("killtarget", "");
                if doomed and other.item.fields.get("targetname", "") == doomed {
                    wire_line(shape.center(), other.center(), ink(0xe5484d));
                    wire_box(other.low, other.high, ink(0xe5484d));
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
        # Where the sculpting brush would fall, and how wide.
        ring = self.sculpt_at;
        if ring is not None {
            for i in range(24) {
                first = 2.0 * math.pi * float(i) / 24.0;
                second = 2.0 * math.pi * float(i + 1) / 24.0;
                wire_line(
                    Vec3(x=ring.x + self.brush_radius * math.cos(first), y=ring.y + self.brush_radius * math.sin(first), z=ring.z + 2.0),
                    Vec3(x=ring.x + self.brush_radius * math.cos(second), y=ring.y + self.brush_radius * math.sin(second), z=ring.z + 2.0),
                    ink(0xff7a18)
                );
            }
        }
        # The way out of a level that leaks.
        for i in range(1, len(self.leak)) {
            wire_line(self.leak[i - 1], self.leak[i], ink(0xe5484d));
        }
        self.draw_cells(scene);
        self.draw_plot(scene);
        self.draw_depth_lines(view);
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
        self.draw_skin_marks();
        # Over each level view, through its own camera: unless a menu, a
        # list or the palette is open over them.
        if len(stage.layers()) > 1 {
            self.canvas.unclip();
            return;
        }
        watched = self.port_now;
        for index in range(self.showing()) {
            self.watch(index);
            self.draw_over_view(scene, self.ports[index].title if self.layout != 1 else "");
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
        self.draw_view_extras(scene, area);
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
        if self.lining and stage is not None and self.port_now == self.box_port {
            if self.mode == "clip" {
                canvas.line(self.press_x, self.press_y, stage.input.x, stage.input.y, canvas.theme.accent);
            } else {
                drawn = Rect(
                    x=min(self.press_x, stage.input.x),
                    y=min(self.press_y, stage.input.y),
                    w=abs(stage.input.x - self.press_x),
                    h=abs(stage.input.y - self.press_y)
                );
                canvas.outline(drawn, canvas.theme.accent);
            }
        }
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
    """A prefab's entities and brushes with the prefabs it holds put in."""
    def prefab_items(name: str, trail: list[str]) -> list[MapItem] | None;
    """Change how the selected instances differ from their prefab. False
    when the command is not one of those."""
    def prefab_change(scene: Scene, args: list[str]) -> bool;
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
    """Show a frame of the explorer's model."""
    def set_frame(frame: int);
    """The model view: turned by a drag, played a frame at a time."""
    def turn_model(dt: float);

    # ------------------------------------------------------------------
    # The grid, remembered views, hiding, history and autosave (impl/studio.shell.impl.jac)

    """Run a grid, view, hiding, history or autosave command. False when it
    is not one."""
    def shell_command(scene: Scene, args: list[str]) -> bool;
    """Write the scene to its autosave file when it has changed and enough
    time has passed (or at once, when `now`)."""
    def autosave(dt: float, now: bool);
    def autosave_path(name: str) -> str;
    """What a selected entity says of itself in the level: the way it
    faces, and how far a light reaches."""
    def draw_marks(shape: Shape);
    """Where the studio's own settings are kept between sessions."""
    def settings_path -> str;
    """Write the settings: the grid, the layout, how views are drawn, the light and the brush."""
    def keep_settings;
    """Read the settings once, when the studio is first opened."""
    def read_settings;
    """A point of a view's own plane (through `anchor`) under a point of
    the screen, on the grid."""
    def view_point(port: int, x: int, y: int, anchor: Vec3) -> Vec3 | None;

    # ------------------------------------------------------------------
    # Terrain (impl/studio.terrain.impl.jac)

    """Run a terrain or sculpting command. False when it is not one."""
    def terrain_command(scene: Scene, args: list[str]) -> bool;
    """The edge of the plot picked on a terrain (impl/studio.touchup.impl.jac)."""
    def draw_plot(scene: Scene);
    """Run a touch-up, plot or top-and-bottom command. False when it is not one."""
    def touchup_command(scene: Scene, args: list[str]) -> bool;
    """The terrain a stroke goes to: the selected one, else the only one."""
    def terrain_now(scene: Scene) -> Item | None;
    """Where on a terrain the line of sight through a point of the view
    lands, or none when it lands on none."""
    def terrain_point(scene: Scene, x: int, y: int) -> Vec3 | None;
    """One dab of the sculpting brush under the pointer."""
    def dab(scene: Scene, x: int, y: int, lower: bool, smooth: bool);

    # ------------------------------------------------------------------
    # Curved patches (impl/studio.patch.impl.jac)

    """Run a patch command. False when it is not one."""
    def patch_command(scene: Scene, args: list[str]) -> bool;
    """The one selected entity, when it is a patch."""
    def patch_now(scene: Scene) -> Item | None;

    # ------------------------------------------------------------------
    # Turn and size handles, the pivot, inflating and the texture lock (impl/studio.transform.impl.jac)

    """Run one of those commands. False when it is not one."""
    def transform_command(scene: Scene, args: list[str]) -> bool;
    """The pivot in force: one set by hand, else the selected group's own."""
    def pivot_for(scene: Scene) -> Vec3 | None;
    """Where the selection turns and stretches about."""
    def turn_hub(scene: Scene) -> Vec3 | None;
    """How long a handle's arm is, for the view looked through."""
    def arm_of(middle: Vec3) -> float;
    """The turn or size handles: a knob on each ring that faces the view
    (910-912), or a box along each axis and one for all three (920-923), and
    the pivot itself (930)."""
    def transform_handles(scene: Scene) -> list[tuple[int, Vec3]];
    def draw_transform_handles(scene: Scene, area: Rect);
    def drag_transform(scene: Scene, x: int, y: int, free: bool);
    """Where a point goes under the turn or stretch being dragged."""
    def dragged_point(point: Vec3, middle: Vec3) -> Vec3;
    """The selection as the drag would leave it, drawn as edges."""
    def draw_transform_preview(scene: Scene);
    """The command a finished drag of a turn or size handle stands for."""
    def transform_words(scene: Scene) -> str;

    # ------------------------------------------------------------------
    # The box handle, and shears and other changes by number (impl/studio.linear.impl.jac)

    """Run one of those commands. False when it is not one."""
    def linear_command(scene: Scene, args: list[str]) -> bool;
    """The two axes the box handle lies along in the view looked through:
    the view's own when it looks along an axis, else x and y."""
    def box_axes -> list[int];
    """The box round everything selected: its low and high corners."""
    def box_bounds(scene: Scene) -> list[Vec3] | None;
    """The box handle's parts (950-958, three to a row from the low corner):
    its middle moves, its corners turn (with Shift, size) and the middles of
    its edges shear along the edge and size across it."""
    def box_handles(scene: Scene) -> list[tuple[int, Vec3]];
    def drag_box(scene: Scene, x: int, y: int, free: bool);
    """The command a finished drag of the box handle stands for, and what
    the drag says of itself while it goes on (in the view it is made in)."""
    def box_words -> str;
    def box_says -> str;
    def draw_box_handle(scene: Scene, area: Rect);

    # ------------------------------------------------------------------
    # Handles on a face for its material (impl/studio.layhandle.impl.jac)

    """Run one of those commands. False when it is not one."""
    def lay_command(scene: Scene, args: list[str]) -> bool;
    """The one picked face, when faces show handles for their material."""
    def lay_face(scene: Scene) -> FacePick | None;
    """Where the handles stand on a face: the middle of its outline."""
    def lay_stand(face: FacePick) -> Vec3 | None;
    """A side's material's size in texels."""
    def lay_sizes(side: Side) -> list[float];
    """The handles: the dot (960), and the ends of the arms along the
    material's first way (961) and its second (962), each a repeat long."""
    def lay_handles(scene: Scene) -> list[tuple[int, Vec3]];
    def drag_lay(scene: Scene, x: int, y: int, free: bool);
    """The command a finished drag stands for, what the drag says of itself
    meanwhile, and the handles as a line of the dump."""
    def lay_words -> str;
    def lay_says(scene: Scene) -> str;
    def lay_line(scene: Scene) -> str;
    def draw_lay_handles(scene: Scene, area: Rect);

    # ------------------------------------------------------------------
    # Keys bound by hand, the settings list, flat tones, grid numbers, readouts (impl/studio.settings.impl.jac)

    """Run one of those commands. False when it is not one."""
    def settings_command(scene: Scene, args: list[str]) -> bool;
    """What the developer's readout says, when it is shown."""
    def dev_words(scene: Scene) -> str;
    """Numbers along the edges of an axis view, at the grid's stronger lines."""
    def draw_grid_numbers(area: Rect);

    # ------------------------------------------------------------------
    # Open documents, recent files, the selection's menu, the log (impl/studio.docs.impl.jac)

    """Run one of those commands. False when it is not one."""
    def doc_command(scene: Scene, args: list[str]) -> bool;
    """The open documents' keys, in a settled order."""
    def doc_keys -> list[str];
    """Go to another open document, leaving this one's camera to come back to."""
    def show_doc(key: str) -> bool;
    """Save every open document that has been edited. Answers how many."""
    def save_all -> int;
    def recent_path -> str;
    """The files opened and saved lately, newest first."""
    def recent_files -> list[str];
    def note_recent(path: str);
    """Open the selection's menu at a point of the window."""
    def selection_menu(scene: Scene, x: int, y: int);
    """The map text a scene is written as, by the studio's own options."""
    def map_text(scene: Scene) -> str;

    # ------------------------------------------------------------------
    # Entities by skill and mode, values replaced, the logic audit (impl/studio.entities.impl.jac)

    """Run one of those commands. False when it is not one."""
    def entity_command(scene: Scene, args: list[str]) -> bool;
    """The options every class shares: which skills and modes leave it out."""
    def fill_skill(scene: Scene, ui: StudioUi, chosen: list[Item]);
    """The handles one selected entity has beside its arrows: the tip of
    the arrow it faces along (940) and the edge of a light's reach (941)."""
    def mark_handles(scene: Scene) -> list[tuple[int, Vec3]];
    def draw_mark_handles(scene: Scene, area: Rect);
    """A drag of one of those: the angle or the reach it would leave."""
    def drag_mark(scene: Scene, x: int, y: int, free: bool);
    """Lines along every path, corner to corner."""
    def draw_paths;
    """Controls to drag for what the selection has: where it is, which way
    it faces, and a light's strength and colour."""
    def fill_controls(scene: Scene, ui: StudioUi, chosen: list[Item]);

    # ------------------------------------------------------------------
    # A played game held still and stepped; how the level is built (impl/studio.play.impl.jac)

    """`ed_pause`, `ed_tick` and `ed_played`, for a game played from here."""
    def play_command(args: list[str]);
    """Run a build command. False when it is not one."""
    def build_mode_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # A played game watched (impl/studio.live.impl.jac)

    """What a signal is known by: its entity's name, else its class and target."""
    def signal_label(fields: dict[str, str]) -> str;
    """One frame of a game played from here: note what has fired."""
    def played(dt: float);
    """Run a breakpoint, trace, fired or live command. False when it is not one."""
    def live_command(args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # A bake seen, recipes, and other programs' steps (impl/studio.steps.impl.jac)

    """The cell the bake's cells are shown from (-1 when nothing is baked)."""
    def eye_cell(scene: Scene) -> int;
    """How many cells that one sees, itself among them."""
    def cells_seen(scene: Scene) -> int;
    def draw_cells(scene: Scene);
    """What a level built of this scene now would be known by."""
    def build_mark(whole: Scene) -> str;
    """List what a program said of entities and brushes as findings."""
    def show_said(scene: Scene, places: list[Place], plain: bool);
    """Run a cells, recipe or outside-step command. False when it is not one."""
    def step_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Projects, add-ons and what each game is set up with (impl/studio.project.impl.jac)

    """The game whose classes are offered: the open project's for a scene of
    brushes, else the scene's own."""
    def class_game -> str;
    """Where projects named without a path are kept."""
    def projects_folder -> str;
    def save_project;
    """A scene was saved there: one of the project's when among its scenes."""
    def project_took(path: str);
    """The recipes kept in the settings and the open project's, by name."""
    def all_recipes -> dict[str, str];
    """Read an add-on's classes (again). How many it added; -1 when it cannot be read."""
    def load_addon(path: str) -> int;
    def drop_addon(path: str);
    """Take up what a game is set up with, when a scene of it is first shown."""
    def apply_game(game: str);
    def close_project;
    def open_project(folder: str) -> bool;
    def project_words -> str;
    """Run a project, add-on or game command. False when it is not one."""
    def project_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Programs outside the studio, files that change, the mouse (impl/studio.outside.impl.jac)

    """The file something names: a path, or a `file:` material's image ("" when neither)."""
    def file_of(scene: Scene, what: str) -> str;
    """Read an image file's material again, and build with it."""
    def reread(name: str) -> bool;
    """Read again the image files that have changed since they were read."""
    def watch_files(dt: float);
    def mouse_words -> str;
    """Run a mouse, program or reload command. False when it is not one."""
    def outside_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Bands of depth and oblique views (impl/studio.depth.impl.jac)

    """The camera of the view the engine is drawing."""
    def lens_of(view: SceneView) -> EditCamera | None;
    """The axis view whose title begins so (-1 when none does)."""
    def port_named(word: str) -> int;
    """How the view being drawn shows a box: 0 as ever, 1 greyed, 2 not at all."""
    def veiled(low: Vec3, high: Vec3) -> int;
    def unpickable(low: Vec3, high: Vec3) -> bool;
    """The edges of the other views' bands of depth, across this one."""
    def draw_depth_lines(view: SceneView);
    """Where an oblique view's compass is: its middle and its radius."""
    def compass_at(area: Rect) -> list[int];
    def draw_compass(area: Rect);
    def depth_words -> list[str];
    """Run a depth or oblique-view command. False when it is not one."""
    def depth_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Sweeps: an outline carried along a path (impl/studio.sweep.impl.jac)

    """Where a path's entities stand, from the name of its first; its first
    point again at the end when the path comes back to it."""
    def path_of(scene: Scene, name: str) -> list[Vec3];
    """The brushes a sweep's fields make, with its path as it now stands."""
    def swept(scene: Scene, fields: dict[str, str], material: str) -> list[list[Side]];
    def sweep_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Sounds, texture facts and animated textures (impl/studio.sounds.impl.jac)

    """Where converted sounds are kept."""
    def sound_path(name: str) -> str;
    """A Quake II texture's bytes: a file's, or a material's from the archives."""
    def wal_bytes(source: str) -> bytes;
    """Run a sound, texture-facts or frames command. False when it is not one."""
    def sound_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Entities as their game's models (impl/studio.previews.impl.jac)

    """The model an entity's game would show it as: "game:path", or ""."""
    def entity_model_name(scene: Scene, item: Item) -> str;
    """A model's edges at its first frame, read once."""
    def preview_edges(name: str) -> list[list[Vec3]];
    def draw_entity_models(scene: Scene);
    def preview_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Shader scripts (impl/studio.shaders.impl.jac)

    """Where shader scripts named without a path are kept."""
    def shader_path(name: str) -> str;
    def shader_in_hand -> ShaderText | None;
    def shader_words -> str;
    """Run a shader command. False when it is not one."""
    def shader_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Entities' games and bots' camp spots (impl/studio.games.impl.jac)

    """The game an entity of a class is spawned by in this scene ("" when
    the scene is one game's, or the class is every game's)."""
    def game_for(scene: Scene, classname: str) -> str;
    """Entities that carry no game, or one that has no such class."""
    def game_findings(scene: Scene) -> list[Finding];
    def draw_camps;
    """Run an asset-game or camp-spot command. False when it is not one."""
    def games_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Linked faces, seams and merged corners (impl/studio.links.impl.jac)

    """Run a link, mitre or merge command (and carve or glue with a link).
    False when it is not one."""
    def links_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Things dropped in a view (impl/studio.drops.impl.jac)

    """Where in the level a point of the view is: what the line of sight
    first meets, `back` short of it, on the grid."""
    def drop_point(scene: Scene, x: int, y: int, back: float) -> Vec3;
    """Put what was dragged from a side panel where it was dropped."""
    def dropped(scene: Scene, x: int, y: int, what: str);

    # ------------------------------------------------------------------
    # The model editor (impl/studio.model.impl.jac)

    """Where models named without a path are kept."""
    def model_path(name: str) -> str;
    """Show the model being edited in the explorer's model view."""
    def show_model_doc(reframe: bool);
    """Show it again if it has changed since it was drawn."""
    def fresh_model;
    """Fill the explorer's file panel for the model being edited. False
    when that is not what the panel shows."""
    def show_model_form(ui: StudioUi) -> bool;
    """Pick the point or triangle under a place in the model's view."""
    def pick_in_model(x: int, y: int, add: bool);
    """A pointer event in the model's view: true when it was a click or a
    drag for the model being edited, not for turning the view."""
    def model_event(event: UiEvent) -> bool;
    def model_words -> str;
    """What is picked of the model, its box, its axes and its tags."""
    def draw_model_marks;
    """Run a model, pick or mesh command. False when it is not one."""
    def model_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # The Passion districts' materials (impl/studio.districts.impl.jac)

    """Run a district command. False when it is not one."""
    def district_command(scene: Scene, args: list[str]) -> bool;
    """Write the districts' table where levels read it. False when it could not be."""
    def keep_districts(table: DistrictTable) -> bool;

    # ------------------------------------------------------------------
    # Bodies and weapons in view, put together (impl/studio.figures.impl.jac)

    """Run a figure command. False when it is not one."""
    def figure_command(scene: Scene, args: list[str]) -> bool;
    """Show a model made here in the explorer's model view, from outside or
    from where the player's eye would be. False when it has no frames."""
    def show_figure(game: str, name: str, model: AnimatedModel, words: str, from_eye: bool) -> bool;

    # ------------------------------------------------------------------
    # The model's bones (impl/studio.bones.impl.jac)

    """Run a bone command. False when it is not one."""
    def bone_command(scene: Scene, args: list[str]) -> bool;
    """The bone commands work on: the one picked, or the last made."""
    def bone_in_hand -> Bone | None;
    """Where a model's bones are kept beside it."""
    def bone_rig_path -> str;
    """The bones as lines of the dump."""
    def bone_lines -> list[str];
    """A pointer event in the model's view that takes hold of a bone's end:
    dragged round its joint, the bone turns about the line of sight."""
    def bone_event(event: UiEvent) -> bool;
    def draw_bones;

    # ------------------------------------------------------------------
    # The model's skin (impl/studio.skin.impl.jac)

    def skin_words -> str;
    """Paint where a place in the model's view meets the model's skin."""
    def paint_in_model(x: int, y: int) -> bool;
    """Hand the painted picture to the canvas when it has changed."""
    def fresh_skin;
    """The part's triangles and picked points as they lie on its picture."""
    def draw_skin_marks;
    """Run a skin command. False when it is not one."""
    def skin_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Groups: their rows in the tree and their own switches (impl/studio.groups.impl.jac)

    """Run a group command. False when it is not one."""
    def group_command(scene: Scene, args: list[str]) -> bool;
    """A group's row in the scene tree, and its brushes' when it is open."""
    def list_group(scene: Scene, rows: list[TreeRow], item: Item, picked: bool);
    """The buttons for a selection that is all groups."""
    def fill_group(scene: Scene, ui: StudioUi, chosen: list[Item]);

    # ------------------------------------------------------------------
    # Zoom, the ruler, names, a backdrop, remembered views, orbit (impl/studio.views.impl.jac)

    """Run one of those commands. False when it is not one."""
    def view_command(scene: Scene, args: list[str]) -> bool;
    """The box round everything selected, or none."""
    def selection_box(scene: Scene) -> list[Vec3] | None;
    """What is drawn over a view before its labels and handles: the
    backdrop picture, the ruler, the names."""
    def draw_view_extras(scene: Scene, area: Rect);
    """Swing the 3D camera round the selection (or what it looks at)."""
    def swing(scene: Scene, yaw: float, pitch: float);

    # ------------------------------------------------------------------
    # Faces dropped, turned and built on; side flags; diggers (impl/studio.faces.impl.jac)

    """Run one of those commands. False when it is not one."""
    def face_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Clicks through, kin, sets, the tour and the swap (impl/studio.select.impl.jac)

    """Everything on the line of sight through a point of the view: what a
    click picks first, then what lies behind it, nearest first."""
    def aim_all(x: int, y: int) -> list[Aim];
    """What a click picks: what is in front, or, clicked again in the same
    place, the next thing behind."""
    def aim_through(scene: Scene, x: int, y: int) -> Aim;
    """`ed_select parent|child|next|prev|brush`. False for other words."""
    def select_more(scene: Scene, args: list[str]) -> bool;
    """Run a set, swap or tour command. False when it is not one."""
    def selection_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Materials replaced, snapping, lining up, face picks, glue, counts (impl/studio.utility.impl.jac)

    """Run one of those commands. False when it is not one."""
    def utility_command(scene: Scene, args: list[str]) -> bool;

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
        if name == "ed_pause" or name == "ed_tick" or name == "ed_played" or name == "ed_fire" {
            # These are for a game being played from here.
            self.play_command(args);
            return;
        }
        if name == "ed_break" or name == "ed_trace" or name == "ed_fired" or name == "ed_live" {
            # And these watch one, while it is played and after.
            self.live_command(args);
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
            self.play(len(args) > 1 and args[1] == "here", len(args) > 1 and args[1] == "selection");
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
                scene.shift_selection(Vec3(x=float(args[1]), y=float(args[2]), z=float(args[3])), self.tex_lock);
            }
        } elif name == "ed_undo" {
            label = scene.undo();
            self.say("Undid " + label if label else "Nothing to undo");
        } elif name == "ed_redo" {
            label = scene.redo();
            self.say("Redid " + label if label else "Nothing to redo");
        } elif name == "ed_save" {
            if len(args) > 1 and args[1] == "all" {
                count = self.save_all();
                self.say("Saved " + str(count) + " documents" if count else "Nothing open has been edited");
            } else {
                self.save();
            }
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
                wanted_layout = args[1] if len(args) > 1 else "1";
                self.arrange_views(
                    5 if wanted_layout == "4b" else (int(wanted_layout) if wanted_layout in ["2", "3", "4"] else 1)
                );
                self.keep_settings();
            }
        } elif name == "ed_dump" {
            if len(args) > 1 {
                print("STEP " + args[1]);
            }
            self.dump(scene);
        } elif not self.links_command(scene, args) and not self.prefab_change(scene, args)
            and not self.scene_command(scene, args)
            and not self.tool_command(scene, args)
            and not self.library_command(scene, args) and not self.class_command(scene, args)
            and not self.build_command(scene, args) and not self.asset_command(scene, args)
            and not self.shell_command(scene, args) and not self.touchup_command(scene, args)
            and not self.terrain_command(scene, args)
            and not self.patch_command(scene, args) and not self.transform_command(scene, args) and not self.linear_command(scene, args) and not self.lay_command(scene, args)
            and not self.selection_command(scene, args) and not self.face_command(scene, args)
            and not self.view_command(scene, args) and not self.group_command(scene, args)
            and not self.build_mode_command(scene, args) and not self.step_command(scene, args)
            and not self.project_command(scene, args) and not self.outside_command(scene, args)
            and not self.depth_command(scene, args) and not self.sweep_command(scene, args)
            and not self.model_command(scene, args) and not self.skin_command(scene, args)
            and not self.bone_command(scene, args) and not self.figure_command(scene, args)
            and not self.district_command(scene, args)
            and not self.games_command(scene, args)
            and not self.shader_command(scene, args) and not self.sound_command(scene, args)
            and not self.preview_command(scene, args)
            and not self.entity_command(scene, args)
            and not self.doc_command(scene, args) and not self.settings_command(scene, args) {
            self.utility_command(scene, args);
        }
    }

    def select(scene: Scene, args: list[str]) {
        add = len(args) > 2 and args[2] == "add";
        if len(args) < 2 {
            scene.select(None);
            return;
        }
        if self.select_wide(scene, args) or self.select_more(scene, args) {
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
        everything = len(args) > 1 and args[1] == "all";
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
            if everything or shape.item in wanted {
                low = Vec3(x=min(low.x, shape.low.x), y=min(low.y, shape.low.y), z=min(low.z, shape.low.z));
                high = Vec3(x=max(high.x, shape.high.x), y=max(high.y, shape.high.y), z=max(high.z, shape.high.z));
                seen += 1;
            }
        }
        for look in self.looks {
            if everything or scene.is_solid_selected(look.solid) {
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
        made = scene.create(classname, Vec3(x=float(round(at.x)), y=float(round(at.y)), z=float(round(at.z))));
        carried = self.game_for(scene, classname);
        if carried {
            # In a scene of no one game it is spawned by its own game's rules.
            made.fields["asset_game"] = carried;
            scene.revision += 1;
        }
        self.say("Added " + classname + (" (" + carried + "'s)" if carried else ""));
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
                + str(self.view_area().w) + " " + str(self.view_area().h) + " of " + str(self.showing()),
            "studio: views layout=" + ("4b" if self.layout == 5 else str(self.layout)) + " span="
                + str(int(self.ports[1].camera.span) if len(self.ports) > 1 else 0) + " ruler="
                + ("1" if self.ruler else "0") + " names=" + ("1" if self.names else "0") + " backdrop="
                + (scene.world().fields.get("_backdrop_at", "none").replace(" ", ",")),
            "studio: tree rows=" + str(len(self.ui.tree.rows) if self.ui is not None else 0),
            "studio: sets="
                + (
                    ",".join(
                        [each + ":" + str(len(scene.set_items(each)) + len(scene.set_solids(each)))
                            for each in scene.set_names]
                    )
                    if scene.set_names
                    else "none"
                ),
            "studio: handles=" + self.gizmo + " anglesnap=" + str(int(self.angle_snap)) + " texlock="
                + ("1" if self.tex_lock else "0") + " pivot="
                + (
                    str(int(self.pivot_at.x)) + "," + str(int(self.pivot_at.y)) + "," + str(int(self.pivot_at.z))
                    if self.pivot_set
                    else "none"
                )
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
        if self.vis_cell > 0.0 {
            done = self.vis_done;
            lines.append(
                "studio: bake cell=" + str(int(self.vis_cell)) + " cells=" + str(done.cells) + " hidden=" + str(done.hidden)
                    + " pairs=" + str(done.pairs) + " capped=" + ("1" if done.capped else "0")
            );
        }
        if self.project is not None {
            lines.append(self.project_words());
        }
        if self.cells_shown {
            lines.append(
                "studio: cells from=" + str(self.eye_cell(scene)) + " sees=" + str(self.cells_seen(scene)) + " of="
                    + str(self.vis_done.cells)
            );
        }
        if scene.solids() {
            lines.append(
                "studio: build from=" + ("copy" if self.built_reused else "new") + " copies=" + str(len(self.built_copies))
            );
        }
        built_now = self.live;
        if scene.solids() and built_now is not None {
            # How many brushes the level was built from: more than the
            # document's where copies are made, other where holes are dug.
            lines.append("studio: made brushes=" + str(built_now.brushes));
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
                    + (
                        " contents=" + str(side.contents) + " flags=" + str(side.flags) + " value=" + str(side.value)
                        if side.contents != 0 or side.flags != 0 or side.value != 0
                        else ""
                    )
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
        for item in scene.items() {
            shape_now = scene.terrain_grid(item);
            if shape_now is None {
                continue;
            }
            heights = heights_from(item.fields.get("_heights", ""), int(shape_now[0]), int(shape_now[1]));
            if heights is not None {
                lines.append(
                    "studio: terrain #" + str(item.serial) + " " + str(int(shape_now[0])) + "x" + str(int(shape_now[1]))
                        + " cell=" + str(int(shape_now[2])) + " tallest=" + str(int(max(heights))) + " raised="
                        + str(len([value for value in heights if value > 0.0]))
                );
            }
        }
        for item in scene.items() {
            control = scene.patch_control(item);
            bend = scene.patch_grid(item);
            if control is None or bend is None {
                continue;
            }
            lines.append(
                "studio: patch #" + str(item.serial) + " " + str(int(bend[0])) + "x" + str(int(bend[1])) + " top="
                    + str(int(round(max([point.z for point in control])))) + " prisms="
                    + str(len(scene.solids_of(item)))
            );
        }
        seen_model = self.model_now;
        if seen_model is not None {
            lines.append(
                "studio: model " + seen_model.game + ":" + seen_model.name + " surfaces="
                    + str(len(seen_model.model.surfaces)) + " frames=" + str(seen_model.frames) + " triangles="
                    + str(seen_model.triangles) + " frame=" + str(self.model_frame) + " edges="
                    + str(len(self.model_edges)) + " yaw=" + str(int(round(math.degrees(self.model_yaw))))
                    + " playing=" + ("1" if self.model_playing else "0")
            );
        }
        seen_asset = self.asset_now;
        if seen_asset is not None {
            lines.append(
                "studio: asset " + seen_asset.game + ":" + seen_asset.name + " kind=" + seen_asset.kind + " size="
                    + str(seen_asset.size) + " note=" + seen_asset.note.replace(" ", "") + " lines="
                    + str(len(seen_asset.lines)) + " material=" + seen_asset.material
            );
        }
        if self.models_shown {
            lines.append("studio: models shown=1 drawn=" + str(self.models_drawn));
        }
        handles_line = self.lay_line(scene);
        if handles_line {
            lines.append(handles_line);
        }
        if self.model_doc is not None {
            lines.append(self.model_words());
            lines.append(self.skin_words());
            for bone_line in self.bone_lines() {
                lines.append(bone_line);
            }
        }
        if self.shader_file {
            lines.append(self.shader_words());
        }
        if scene.link_count() > 0 {
            lines.append("studio: links=" + str(scene.link_count()));
        }
        if scene.layers_off {
            lines.append("studio: layers off=" + ",".join(sorted(scene.layers_off)));
        }
        for words in self.depth_words() {
            lines.append(words);
        }
        # The mode's line stays the last: sessions look for it there.
        lines.append(self.mouse_words());
        lines.append(
            "studio: mode=" + self.mode + " material=" + self.material + " wire="
                + ("1" if self.wire_axis else "0") + ("1" if self.wire_main else "0") + " lit="
                + str(self.lit_samples if self.lit else 0) + " grid=" + str(int(self.grid)) + " hidden="
                + str(scene.hidden_count()) + " frozen=" + ("1" if self.frozen else "0")
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
        } elif name == "ui_press" and len(numbers) >= 2 {
            # Half a drag: the button goes down and stays down.
            self.source.script(UiStep(kind="move", x=numbers[0], y=numbers[1]));
            self.source.script(
                UiStep(kind="down", x=numbers[0], y=numbers[1], button=numbers[2] if len(numbers) > 2 else 0)
            );
        } elif name == "ui_release" and len(numbers) >= 2 {
            self.source.script(UiStep(kind="move", x=numbers[0], y=numbers[1]));
            self.source.script(
                UiStep(kind="up", x=numbers[0], y=numbers[1], button=numbers[2] if len(numbers) > 2 else 0)
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

"""Where the explorer's model view is ([0, 0, 0, 0] when it is not laid out)."""
def ui_model_area(ui: StudioUi | None) -> Rect {
    if ui is None or ui.model_view.parent() is None {
        return Rect();
    }
    return ui.model_view.area;
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
