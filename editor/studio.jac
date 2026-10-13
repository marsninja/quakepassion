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
import from engine.console.cvar { Cvar }
import from engine.formats.bsp { Model, Bsp, MapEntity, Texture }
import from engine.math.vec3 { Vec3, forward_from, right_from }
import from engine.input.input { _capture, _release, mouse_captured }
import from engine.input.keys { Keyboard }
import from engine.world.world { move_to_area }
import from engine.render.renderer { Color, Vector3, DrawCubeWires, DrawLine3D }
import from editor.geometry.thick { WIDEST_LINE, thick_shifts, line_across, pixel_reach }
import from editor.document.readout { resident_megabytes, memory_words, flash_level, graph_places, journal_text, read_journal }
import from games.levels { override_path, override_folder }
import from games.items { pickup_rule }
import from games.enemies { enemy_rule }
import from games.fixtures { fixture_rule }
import from games.arena_character { character_rig, animation_settings }
import from games.viewweapons { view_weapons }
import from games.passion.materials {
    DistrictTable, district_table, kept_table, table_text, districts_path, material_word, material_spec, SLOT_NAMES,
    load_materials, editor_material_names
}
import from engine.world.weapons { ViewWeaponRule }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from vendor.raylib {
    def rlDisableDepthTest -> None;  def rlEnableDepthTest -> None;  def rlDrawRenderBatchActive -> None;
    # raylib's immediate batch, for the faces of the model being edited.
    def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;
    def BeginBlendMode(mode: i32) -> None;  def EndBlendMode -> None;
    def rlSetTexture(id: u32) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlTexCoord2f(
        x: f32, y: f32
    ) -> None;  def rlVertex3f(x: f32, y: f32, z: f32) -> None;  def rlColor4ub(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;
}
import from .ui.canvas { ScreenCanvas, Rect, Ink, ink, rects_outside, Theme, light_theme }
import from .ui.input { UiSource, UiStep, script_click, script_drag }
import from .ui.logview { log_reach, log_window, log_fitted }
import from .ui.order { moved_before }
import from .tools.host { ToolHost, StudioTool, PanelSpec }
import from .ui.widget { Widget, Stage, UiEvent, Child }
import from .ui.controls { Combo, TextArea, DockGrip, dock_place }
import from .ui.widgets {
    Box,
    Label,
    Header,
    Spacer,
    PushButton,
    TextField,
    Scroll,
    Splitter,
    Sash,
    TreeView,
    TreeRow,
    Tabs,
    MenuBar,
    MenuItem,
    MenuPopup,
    ViewArea,
    Floater,
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
import from .assets.needs { needed_files, missing_files, held_names, names_file, file_field, field_choices }
import from .assets.explorer { own_files, reel_next, reel_before, texture_rgba }
import from .document.shelves { shelf_name, shelf_moved, shelf_rows }
import from .assets.finding { Search, search_of, name_found, size_fits, tags_from, tags_text, tags_with, colours_used }
import from .assets.models { ModelLook, load_model, is_model }
import from .assets.entitylook { EntityLook, PreviewLook, is_sprite, class_sprite, sprite_corners, stood_at, frame_shown }
import from .assets.shaders {
    ShaderText, ShaderStage, ShaderFault, read_shaders, write_shaders, with_directive, shader_named, shader_faults
}
import from .assets.shadertext { script_shown, script_faults, shader_brief }
import from .assets.moving { warps_name }
import from .document.playtest { objectives }
import from .document.liveroll { LiveRoll, opponent_words, door_words, pickup_words }
import from .geometry.axes { world_axes, brush_axes, facing_axes, kept_to_axis }
import from .document.thumbs { sketch_edges, sketch, waveform }
import from engine.formats.wav { parse_wav_pcm }
import from .document.chords { chord_parts, bind_chord, chord_command, bound_chords }
import from .document.settingstable {
    Setting, SUBJECTS, settings_table, setting_value, setting_order, colour_parts
}
import from .ui.passage { passage_line, passage_of }
import from .formats.archive {
    write_pak, write_zip, file_kind, pak_files, zip_files, files_with, files_without, lies_in
}
import from .formats.sound { sound_facts, converted_sound }
import from .formats.wal { WalFacts, wal_facts, wal_with, flag_names, flag_named, quake_frames }
import from .classes.registry {
    ClassInfo, FieldInfo, class_info, class_names, class_family, field_of, flag_set, add_classes, drop_classes,
    names_offered
}
import from .geometry.shapes { shape_brushes, caulked, SHAPE_KINDS }
import from .geometry.terrain { heights_from, heights_image, image_heights, falloff_of }
import from .geometry.touchup { cell_at, kin_cells, cells_outline }
import from .geometry.patch {
    patch_points, PATCH_KINDS, places_text, places_even, places_projected_from, places_slid
}
import from .model.mesh { Mesh, mesh_volume, open_edges, face_under, point_under, mesh_found }
import from .model.primitives { primitive_mesh, PRIMITIVE_KINDS }
import from .model.wavefront { mesh_obj, obj_mesh }
import from .model.skin {
    Skin, places_box, places_moved, places_scaled, places_turned, places_flipped, places_projected, skin_filled, skin_dab,
    place_under, skin_tga, tga_skin, skin_colour
}
import from .model.pattern { SKIN_PATTERNS }
import from engine.render.models { ModelRenderer }
import from engine.assets.pk3 { Pk3Assets }
import from .geometry.patchpreview { lattice_edges, render_rows, collide_rows }
import from .document.duplicate { with_regenerated, regenerate }
import from .model.skinpick {
    skin_rect, skin_place, place_nearest, triangle_at, place_frame, frame_fit, place_pixel, pixel_place, place_at_pixel
}
import from .ui.skinpane { SkinPane }
import from .model.marks {
    MARK_STYLES, mark_lines, picks_middle, handle_tips, drag_along, drag_kept, locked_axes, tint_word, word_tint, face_light
}
import from .model.document { ModelDoc, Part, Reshape, Bone }
import from .model.bones { point_swung }
import from .model.assembly { body_model, held_model, clip_frames, rule_frames }
import from .assets.playback {
    frame_after,
    edges_between,
    facing_edges,
    box_corners,
    box_mesh,
    box_round,
    sequence_range,
    share_stepped,
    SEQUENCES
}
import from .model.files {
    doc_from_model,
    model_of,
    write_md3,
    md3_limits,
    write_md2,
    md2_limits,
    write_mdl,
    mdl_limits,
    palette_indices,
    grey_palette
}
import from .model.work { work_text, doc_from_work }
import from .model.gltf { write_glb, read_gltf }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.q2.model { parse_md2 }
import from .geometry.extrude { profile_pieces, profile_of, sweep_brushes, PROFILE_KINDS }
import from .compile.light { bake_light, lamp_cone, light_job, LightJob }
import from .compile.spot { Cone, cone_rim, cone_through, square_to }
import from .compile.bake {
    bake_cells,
    cell_sees,
    leaf_at,
    VisReport,
    cell_job,
    CellJob,
    BAKE_BY_PLANES,
    portal_file_text,
    portal_file_windings
}
import from .project {
    Project, MANIFEST_NAME, read_project, write_project, addon_classes, addon_folders, addon_label, file_name
}
import from .compile.kept { KeptBake, keep_bake, give_bake }
import from .compile.steps { Place, recipe_steps, step_line, places_named, text_mark }
import from .compile.navigation {
    Floor, Way, Leg, Link, floor_ways, floor_middle, nav_data, ways_count, route_time, route_legs, legs_count, NAV_STEP,
    linked_ways, swim_ways, aas_bytes
}
import from engine.world.bot_routes { NavMesh, HasNavMesh, build_navmesh }
import from engine.formats.aas {
    Aas, TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_WALKOFFLEDGE, TRAVEL_TELEPORT, TRAVEL_JUMPPAD, TRAVEL_LADDER, TRAVEL_SWIM,
    TRAVEL_ELEVATOR
}
import from .compile.leak { find_leak, LeakReport }
import from .formats.bspmap { bsp_items, level_material }
import from .document.generate {
    duplicates,
    image_brushes,
    image_sets,
    with_images,
    DUPLICATOR_KEYS,
    with_holes,
    with_makers,
    makes,
    digs,
    DIGGER_KEY,
    prefab_overridden,
    with_prefabs,
    prefab_placed,
    prefab_turns,
    with_patches
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
    write_vector,
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
import from .geometry.axial { linear_about, linear_along, world_ways, point_sized }
import from .geometry.layhandle { lay_arms, lay_dragged, swept_between }
import from .geometry.integral { faces_astray, sides_integral, sides_angled }
import from .geometry.bits { bit_names, bit_of, bits_named }
import from .geometry.snapto { loop_inside, loop_thinned, snapped_move }
import from .document.overlays { brush_kind, kind_tint }
import from .geometry.linear {
    Linear, BoxDrag, along_axis, box_part, box_drag, point_remapped, linear_shear, linear_from, linear_text
}
import from .camera { EditCamera, ray_enters_box, axis_camera, depth_cut, depth_of }
import from engine.world.signals { Signal, Fire, HasSignal }
import from engine.world.doors { Door, HasDoor }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.combat { Opponent, HasOpponent }
import from .compile.live {
    compile_scene,
    LiveLevel,
    Materials,
    SwatchMaterials,
    swatch_texture,
    level_changes,
    take_changes
}
import from engine.formats.brush_collision { refresh_world_hulls }
import from .assets.materials { ArchiveMaterials, small_picture }
import from engine.core.menu { game_directory }
import from engine.assets.content { shelf, pack_folder, folders_path, set_folders, keep_folder }
import from .formats.map { read_map, write_map, MapItem, MapFile, map_materials, map_renamed }
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
    ("ed_box_draw", "ed_box_draw <view> <x0> <y0> <x1> <y1>", "add a box over a rectangle drawn in a view: in the 3D view, on the level it stands on"),
    ("ed_tree", "ed_tree [text]", "say every row the scene tree shows, or those that hold some text"),
    (
        "ed_terrain",
        "ed_terrain [cols rows cell] | export <file.pgm> | import <file.pgm> [tallest] | lift <x0> <y0> <x1> <y1> <amount> [falloff|n%] | pattern <same|alt|other> | free",
        "add a terrain where the camera looks; write or read its heights as a grey image; lift a rectangle of it; split its cells another way; or leave it as plain brushes"
    ),
    (
        "ed_sculpt",
        "ed_sculpt <raise|lower|smooth|flatten|noise|erode|paint> [radius] [amount] [at <x> <y>]",
        "a stroke of the sculpting brush on a terrain, where the camera looks or at a point"
    ),
    ("ed_brush", "ed_brush <radius> <amount> | rect [on|off] [falloff|n%]", "the sculpting brush's width and strength; rect makes a drag in sculpt mode draw a rectangle that is lifted whole"),
    ("ed_replace", "ed_replace <old> <new> [all]", "give sides of one material another, in the selection or everywhere"),
    ("ed_snap", "ed_snap [all] [size]", "put the selection's corners and origins on the grid, or everything's (a map off the grid mended)"),
    ("ed_align", "ed_align <x|y|z> <low|high|middle> [to <set>]", "line the selected brushes up along an axis, with one another or with a kept set"),
    ("ed_prune", "ed_prune [all]", "take out the sides that make no face, and the brushes that enclose nothing"),
    (
        "ed_faces",
        "ed_faces <all|invert|extend|adjoining|beside|next|prev>",
        "spread the face pick over the whole brush, to its other faces, across the plane, to the faces that adjoin it in its plane or to those beside it; or step to the next face"
    ),
    ("ed_tag", "ed_tag [add|list|clear]", "remember the picked face, to glue brushes against and take its material from; add more faces to those remembered; say them; or forget them"),
    ("ed_glue", "ed_glue [face [link]]", "move the selection against the tagged face, or put the picked face in its plane (and link it to what lies there)"),
    ("ed_paintface", "ed_paintface <brush> <side>", "give one face the material in hand (Alt and a drag, in face mode)"),
    ("ed_reshape", "ed_reshape <w d h> [count] [thickness]", "build the selected shape again from other numbers, where it stands"),
    ("ed_caulk", "ed_caulk [material]", "give the faces the selected brushes cover of each other a material that is not drawn"),
    ("ed_autocaulk", "ed_autocaulk [on|off]", "whether shapes are built with their inner faces caulked"),
    (
        "ed_bake",
        "ed_bake [planes|cell|off]",
        "cut the built level into cells that know which others they see (256 units wide unless told), or by its brushes' own planes into leaves joined by portals, or build it as one again"
    ),
    (
        "ed_project",
        "ed_project [new|open <folder>] [close] [add] [drop|start <scene>] [set <what> <value>]",
        "a project: a folder with a manifest and scenes, prefabs and textures of its own; with no word, the one open"
    ),
    ("ed_addon", "ed_addon [file] [reload|drop [file]]", "load a text file of entity classes, read it again, drop it, or list what is loaded"),
    ("ed_game", "ed_game [game] [material|build|bake|dir] [value]", "what a scene of a game begins with and the folder its files are in, or what each game is set up with"),
    ("ed_models", "ed_models [on|off|list] | skins [on|off]", "draw entities in the 3D view as the models and sprites their game would show them as, with their skins or as edges, or list them"),
    ("ed_sound", "ed_sound info <file> | convert <file> <name> [rate] [bits] [loud]", "say what a WAV file is, or make it one channel at a game's rate and width among the project's sounds"),
    (
        "ed_wal",
        "ed_wal <file.wal|q2:name> [flag <name> on|off] [flags|contents|value <number>] [next <name>|none]",
        "a Quake II texture's own flags, contents, value and the texture that follows it: read, or changed in a copy among the project's textures"
    ),
    ("ed_frames", "ed_frames [material]", "the frames of an animated texture: a Quake + name's row, or a Quake II texture's chain"),
    (
        "ed_shader",
        "ed_shader [open <file>|take|new <name>|pick <name>|show|set <key> <value>|unset <key>|stage ...|drop|check|save|preview|text [open|close]|write <words>]",
        "a Quake III shader script: open one (or take the one the explorer shows), change a shader's lines and stages or its text in a box with the faults by line beside it, check it for what the game would trip on, and save it"
    ),
    ("ed_assetgame", "ed_assetgame <q1|q2|q3|none|fill>", "the game whose rules the selected entities are spawned by in a scene of no one game; fill gives every entity its class's"),
    ("ed_camps", "ed_camps [routes [on|off]]", "list the spots bots camp at and roam through; routes draws the ways bots take between them, or from the one thing picked to each"),
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
        "ed_model [new|add <kind>] [edit] [open|save <file>] [part <n>] [frame ...] [tag ...] [skin ...] [check] [match] [box] [axes] [marks <style>] [shade wire|solid|textured] [about model|origin|view|free] [layout 1|4] [float [close]] [undo|redo] [close]",
        "the model editor: make a model from a primitive, edit the one shown in the explorer, open or save one (OBJ, MD3, MD2), and look after its parts"
    ),
    ("ed_pick", "ed_pick points|faces <numbers|all> [add] | front | back | none | mode points|faces|paint", "pick points or triangles of the model's part in hand, or say what a click in its view does"),
    ("ed_integral", "ed_integral [grid]", "lay the picked faces (or every face of the selected brushes) through whole points again"),
    ("ed_faceangle", "ed_faceangle [degrees]", "tilt the picked faces to whole steps of heading and of slope, each about its own middle"),
    ("ed_matfind", "ed_matfind <text>", "find materials by name across every game, and show them as a shelf in the Materials tab"),
    ("ed_pickmode", "ed_pickmode <all|brushes|entities>", "what a click in a view picks: everything, brushes only, or entities only"),
    ("ed_restrict", "ed_restrict [on|off]", "keep editing to the selection: everything else is put away, and brought back when it is let go"),
    ("ed_toolpanel", "ed_toolpanel close <name>", "close a box that a tool is showing"),
    (
        "ed_playtest",
        "ed_playtest [bake]",
        "say whether the scene can be finished: what its logic can never set off, then the first key, opener or way out that cannot be reached from the start over the baked floors (bake: walk the floors as they are now)"
    ),
    (
        "ed_nav",
        "ed_nav [bake [cell] [open] | check | route <from xyz> <to xyz> | show [on|off] | write [file.aas] | clear]",
        "navigation for bots: bake the built scene's floors into the areas and ways the games' bots route over, check what can be reached, and draw the ways"
    ),
    (
        "ed_window",
        "ed_window [list] | new [outlines] | close <n|all> | <n> outlines|solid | <n> at <x> <y> [w h] | <n> cam <x y z> [yaw pitch] | <n> here",
        "floating 3D windows: further views of the level, each with a camera and a way of drawing of its own"
    ),
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
        "ed_skin [move|scale|turn|flip|project ...] [new <w h>|open|save <file.tga>|import <game>:<file> [n]] [colour <r g b>] [brush <radius> [soft]] [pattern <name> [grain]] [pick <u v>] [pickat <u v> [add]] [dab <u v>] [show]",
        "the model's skin: move, stretch, turn, flip or lay flat where the picked points lie on it; make, open, paint and save its picture"
    ),
    (
        "ed_mesh",
        "ed_mesh move|turn|scale|mirror|flip|subdivide|cut|extrude ... | lock <axes|off> | colour <rrggbb|none> | colours [on|off]",
        "move, turn or stretch the picked points; mirror the part; turn triangles round, cut them in 2, 3 or 4, or push them out; keep drags off some axes; give points colours of their own"
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
    (
        "ed_portals",
        "ed_portals [on|off] | load [file.prt] | write [file.prt] | forget",
        "draw the portals of a bake by planes, read a compiler's portal file to draw, or write the bake's"
    ),
    ("ed_recipe", "ed_recipe [name] [commands]", "keep a row of commands, apart at semicolons, under a name; forget one; or list them"),
    ("ed_make", "ed_make <name>", "run a recipe's commands"),
    ("ed_run", "ed_run <command line>", "run another program over the scene written as a map (%map%), and list what it says of entities and brushes"),
    ("ed_logic", "ed_logic [kind]", "add a piece of logic (a relay, a delay, a counter ...) as the scene's game has it, or list the kinds"),
    ("ed_fav", "ed_fav <classname>", "keep a class as a favourite, or stop keeping it"),
    ("ed_bind", "ed_bind <key> <command>", "give a key (a, ctrl+k, shift+f2) an editor command of your own"),
    ("ed_unbind", "ed_unbind <key>", "give a key back what the studio gives it"),
    ("ed_binds", "ed_binds", "list the keys bound by hand"),
    (
        "ed_settings",
        "ed_settings [box [general|display|view|map|model|files|colours|close] | vars [word]]",
        "list the studio's settings, each a click to change; open them by subject in a box; or print them as the console variables they also are"
    ),
    (
        "ed_texlink",
        "ed_texlink [<name> <folder> | drop <name>]",
        "use a folder of image files as materials where it lies, under a name: nothing is copied (kept in the open project, or in the settings)"
    ),
    (
        "ed_texlist",
        "ed_texlist [<name> [add|drop [material ...] | remove]]",
        "a list of materials kept by name and shown as a shelf of the Materials tab: add the material in hand or those named, take them off, or show the list"
    ),
    (
        "ed_colour",
        "ed_colour <accent|select|text|panel|all> <rrggbb|default>",
        "one of the studio's colours set by hand over its theme, as six digits, or given back"
    ),
    ("ed_dev", "ed_dev [on|off]", "show frame and build times and counts in the status bar"),
    ("ed_docs", "ed_docs", "list the open documents"),
    ("ed_doc", "ed_doc <name|next|prev>", "go to another open document"),
    ("ed_theme", "ed_theme [dark|light]", "the studio's colours: dark, or light for a bright room"),
    ("ed_bar", "ed_bar <tools|status> [show|hide] | tools <above|below>", "show or hide the row of tools and the status bar, and put the tools over or under the views"),
    ("ed_shapebox", "ed_shapebox [open|close|kind <kind>|set <w|d|h|count|thick> <value>|build|at <x> <y>]", "the shape dialog: choose a kind of shape and its sizes in a window, and build it"),
    ("ed_weights", "ed_weights [open|close]", "the weights dialog: the bone in hand, the weight it takes of the picked points, and what carries each of them"),
    ("ed_tab", "ed_tab <doc:game/name|model[:n]|shader[:n]|texture:game:file>", "go to an open document by its tab: a map or scene, a model being edited, a shader script or a texture"),
    ("ed_pickfile", "ed_pickfile <noise|music|model|model2>", "choose the selected entities' sound or model from the files of their game, in a list that is typed in to find one"),
    ("ed_close", "ed_close [force]", "close this document (force, when it has edits that are not saved)"),
    ("ed_documents", "ed_documents", "list the documents open: scenes, models, shader scripts and textures"),
    ("ed_texture", "ed_texture open <game:file> | close [game:file]", "open a picture as a document of its own, with a tab, or close one"),
    ("ed_recent", "ed_recent [number]", "list the files opened and saved lately, or open one of them"),
    ("ed_log", "ed_log [lines] | panel [on|off] [rows] | panel up|down [n] | panel end", "show the console's last lines; panel keeps them in sight along the foot of the views, and scrolls back through them"),
    ("ed_mapopts", "ed_mapopts [comments|whole] [on|off]", "how maps are written: with numbered comments, with whole coordinates only"),
    ("ed_overlay", "ed_overlay [triggers|unseen|portals|leaves] [on|off] | width <1..4> | overdraw [on|off]", "outline trigger volumes, or clip, hint and caulk brushes, in colours of their own, or a bake's portals or leaves; how wide the studio's lines are drawn; how many faces the renderer draws over each place; alone, count them"),
    ("ed_export", "ed_export <file.map> [valve|classic|q3]", "write the scene as a map for another tool: Valve's form, the classic one, or Quake III's brush primitives and patches"),
    ("ed_fire", "ed_fire <targetname>", "set off what has that name, in a game played from the studio"),
    ("ed_spawn", "ed_spawn <all|easy|normal|hard|deathmatch>", "show the level as it would spawn at a skill or in a mode"),
    ("ed_refield", "ed_refield <key> <old> <new> [all]", "replace part of a field's value across the selection, or every entity"),
    ("ed_pause", "ed_pause [on|off]", "hold a game played from the studio still, or let it run"),
    ("ed_tick", "ed_tick [count]", "let a held game's time move by so many sixtieths of a second"),
    ("ed_played", "ed_played [label]", "print how a game played from the studio stands"),
    ("ed_break", "ed_break [targetname|clear]", "hold a played game still when what has that name fires; or stop doing so; or list them"),
    ("ed_trace", "ed_trace [on|off] | graph [on|off]", "name each firing in a played game as it happens; or draw the scene's logic over the game, lit as it fires"),
    ("ed_fired", "ed_fired [label]", "print what has fired in the game played from here, how often and in what order"),
    (
        "ed_live",
        "ed_live [player health <n> | player at <x y z> | signal <name> on|off | opponents | doors | pickups | opponent <n> health <h>|at <x y z> | door <n> open|lock|unlock | pickup <n> at <x y z>]",
        "look at a played game's player, signals, opponents, doors and pickups, or change them"
    ),
    (
        "ed_build",
        "ed_build [full|quick|flat|fresh] | background [on|off] | cancel",
        "build the level again now; how it is lit: finely, coarsely, or not at all; or fresh, forgetting what was built before; light baked a slice a frame while the studio goes on, or that bake given up"
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
        "ed_sideflag [names] [as q2|q3] | <contents|flags> <name> [on|off] | <contents|flags|value> <number> [set|clear|put]",
        "set, clear or replace bits on the picked faces or the selected brushes' sides, by number or by the name a game has for the bit"
    ),
    ("ed_detail", "ed_detail [on|off]", "mark the selected brushes as detail, or as structural again"),
    ("ed_digger", "ed_digger [on|off]", "make the selected brushes holes, cut out of the rest when the level is built"),
    ("ed_keep", "ed_keep [name]", "keep the selection as a named set (the sets, without a name)"),
    ("ed_recall", "ed_recall <name> [add]", "select a set kept before, alone or added to the selection"),
    ("ed_forget", "ed_forget <name>", "drop a kept set"),
    ("ed_swap", "ed_swap", "the two selected things change places"),
    ("ed_uses", "ed_uses [material|file]", "what the scene uses, with what no archive holds marked; or select every brush and entity that uses one material or file"),
    ("ed_marked", "ed_marked [set|clear|take|pick|swap]", "mark the selected entity for later; then take hands it the selected brushes, pick selects it, swap changes its place with the selection's"),
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
    (
        "ed_axes",
        "ed_axes [world|local|view] | lock <x|y|z|off>",
        "what the move arrows run along: the world's axes, the selection's own or the view's; and keep a dragged selection to one of them"
    ),
    ("ed_anglesnap", "ed_anglesnap [degrees]", "what a dragged turn snaps to"),
    ("ed_inflate", "ed_inflate <units|up|down>", "push every side of the selected brushes out (or in) by a distance"),
    ("ed_texlock", "ed_texlock [on|off|axis]", "whether materials go with the faces a move, turn or stretch carries; axis: with a move, but kept to the world's axes through a turn or stretch"),
    ("ed_stats", "ed_stats [file]", "count what the document holds, or write the materials it uses to a file"),
    ("ed_step", "ed_step <next|prev>", "select the entity after, or before, the selected one"),
    ("ed_freeze", "ed_freeze [on|off]", "keep clicks in the level from changing the selection, or let them"),
    ("ed_assetfind", "ed_assetfind <words> [kind:<image|text|sound|model|map>] [game:<q1|q2|q3>] [tag:<word>]", "list the files of every game whose names hold the words, of a kind, of a game, or with a tag"),
    ("ed_assettag", "ed_assettag <word> | drop <word> | list", "hang a word on the file the explorer shows, to find it by again; or take one off; or list every tagged file"),
    ("ed_texinfo", "ed_texinfo [material]", "what there is to know of a texture: its size, its flags and contents, its frames, the colours it uses"),
    (
        "ed_patch",
        "ed_patch <sheet|arch|bevel|cylinder|cone|endcap> [w d h] | grow <u|v> | shrink <u|v> | thick <units> | fine <n> | preview [on|off|<subdivision>] | uv [fit [n [m]] | project | point <col> <row> <s> <t> | row <n> <ds> <dt> | col <n> <ds> <dt> | all <ds> <dt> | clear]",
        "add a curved patch where the camera looks; give the selected one another curve, thickness or fineness; or say where its control points lie on its material"
    ),
    ("ed_patch_point", "ed_patch_point <patch> <point> <dx> <dy> <dz>", "move one control point of a patch"),
    ("ed_shaderbox", "ed_shaderbox [open|close]", "a box with the shader in hand: its lines and its stages' lines to change, stages to add, move and drop, and its preview"),
    ("ed_shaderline", "ed_shaderline <stage|-1> <line|add> [words]", "change, add or (with no words) drop a line of the shader in hand, or of one of its stages"),
    ("ed_patchbox", "ed_patchbox [open|close]", "a box with the selected patch's material and where its control points lie on it, to drag them or set them by numbers"),
    ("ed_face", "ed_face <brush> <side> [add]", "select a face of a brush"),
    (
        "ed_tex",
        "ed_tex <shift|shiftto|scale|turn|turnto|fit|minfit|flat|reset|wrap|project> [a] [b]",
        "change how the material lies on the selected faces, or on every side of the selected brushes; wrap and project take it from the tagged face"
    ),
    ("ed_pickmat", "ed_pickmat [brush side]", "take the material of a face as the one new brushes and faces get"),
    ("ed_boxselect", "ed_boxselect <view> <x0> <y0> <x1> <y1> [add]", "select what lies in a rectangle of a view"),
    ("ed_lasso", "ed_lasso <view> <x> <y> <x> <y> ... [add]", "select what lies inside a loop drawn in a view (Alt and a drag draws one)"),
    ("ed_snapto", "ed_snapto <grid|corners|edges|faces> [reach]", "what a move ends on: where it is asked, or a corner, edge or face of another brush it comes within reach of"),
    ("ed_corner", "ed_corner <dx> <dy> <dz> <x> <y> <z> [...] | lock [on|off]", "move the corners of the selected brush at those points; with the lock on, the corners of other brushes at those points go with them"),
    ("ed_display", "ed_display <wire|textured> [3d|axis|all]", "draw views as edges or textured (the axis views without a word)"),
    ("ed_check", "ed_check [number]", "list what is wrong with the document, or select the thing a finding is about"),
    ("ed_shelf", "ed_shelf <group>", "show a group's materials in the materials tab"),
    ("ed_material", "ed_material <name> [side] | recent", "set the material of the selected brushes, and of new ones; or list those lately in hand"),
    ("ed_push", "ed_push <side> <distance>", "move one side of the selected brush along its normal"),
    ("ed_tie", "ed_tie [classname]", "hand the selected brushes to a new entity, or back to the world"),
    ("ed_matfilter", "ed_matfilter <text> [size:<WxH|N|>=N|<=N>]", "show only matching materials in the materials list, and only those of a size"),
    (
        "ed_layout",
        "ed_layout <1|2|3|4|4b|logic|assets> | save <name> | load <name> | drop <name> | list",
        "one level view, four (3D, top, front and side), the logic graph, or the asset explorer; or keep the layout as it stands under a name and bring it back"
    ),
    ("ed_help", "ed_help [command|doc]", "what the control under the pointer is for and the command it asks for (F1), or a command by name; doc opens the studio's book"),
    ("ed_flyover", "ed_flyover [on|off]", "whether a control's hint is shown beside the pointer when it rests there"),
    ("ed_rename", "ed_rename [name]", "name the selected entity (a group's own name, or the name it is fired by): typed over its row of the scene list (F2), or said"),
    ("ed_split", "ed_split [x|y] <percent> | even", "how the level views share the room: the left views' share of the width, the upper views' of the height"),
    ("ed_dock", "ed_dock <tabs|inspector> <left|right|float> | <panel> at <x> <y>", "dock a side panel on the left or the right (both on one side are stacked), or float it in a window of its own; at a point: where a panel's grip was let go"),
    ("ed_sides", "ed_sides [swap|left|right]", "which side the scene list is on: the inspector takes the other"),
    ("ed_palette", "ed_palette", "open the list of every studio command, to find one by typing"),
    ("ed_grid", "ed_grid <size|up|down>", "the grid moves and resizes snap to (1 to 256)"),
    ("ed_mark", "ed_mark [name]", "remember where the camera is, in the document"),
    ("ed_goto", "ed_goto <name|next>", "put the camera where it was remembered"),
    ("ed_hide", "ed_hide [others]", "put the selection, or everything else, out of sight while editing"),
    ("ed_show", "ed_show", "bring back everything hidden"),
    ("ed_drop", "ed_drop", "let the selection down onto what is beneath it"),
    ("ed_history", "ed_history [steps] | redo <steps> | list", "list the edits made and those undone, undo so many, or do so many again"),
    ("ed_recover", "ed_recover [<n>]", "the steps the autosaved journal of the scene in hand kept, or the state one of them left it in opened as a scene of its own"),
    ("ed_autosave", "ed_autosave [every <seconds>]", "write the scene to its autosave file now, or say how often a changed scene is (0 for never)"),
    ("ed_asset", "ed_asset <dir:game:folder|file:game:name>", "open or close a folder of the explorer, or show a file"),
    ("ed_framedrop", "ed_framedrop <row> <what>", "what a row of the model's frame list let go on another asks for: that frame put there in the order"),
    ("ed_assetdrop", "ed_assetdrop <row> <what>", "what a row of the explorer let go on the project's rows asks for: the file or folder copied into the project"),
    ("ed_extract", "ed_extract [to] | folder <game>:<folder> [to]", "write the file the explorer shows to disk, or every file under a folder of a game's archives"),
    ("ed_listen", "ed_listen", "play the sound the explorer shows"),
    ("ed_frame", "ed_frame <number|next|prev|play|stop> | fps <n> | range <first> <last>|all | smooth on|off|<frames between> | once | loop | clip <sequence|list>", "the frame of the model the explorer shows, and how its frames are played"),
    ("ed_orbit", "ed_orbit <yaw> <pitch> [distance]", "turn the model view (angles in degrees)"),
    (
        "ed_pack",
        "ed_pack <folder|scene> <out.pak|out.pk3> | list <archive> | add <archive> <file> [name inside] | drop <archive> <name, or folder/>",
        "pack a folder's files, or the scene with the textures it uses, into an archive"
    ),
    ("ed_copy", "ed_copy", "copy the selection (as map text)"),
    ("ed_cut", "ed_cut", "copy the selection and delete it"),
    ("ed_paste", "ed_paste [here]", "paste what was copied: beside where it was, or where the camera looks"),
    ("ed_group", "ed_group [name]", "hold the selected brushes together as a group"),
    (
        "ed_nest",
        "ed_nest [<group's name|#number> | out]",
        "put the selected groups in another group, which is then picked, moved, copied and deleted with them; or take them out; alone, list what is in what"
    ),
    (
        "ed_prefab",
        "ed_prefab <save|add|link|unlink> [name] | move <name> <new name> | swap|put|names|plain ... | turn <degrees> [pitch|roll] | scale <times>|<x y z>",
        "keep the selection as a prefab, add a copy of one, place a linked one, turn linked ones into copies, or change, turn and size the selected linked ones"
    ),
    ("ed_import", "ed_import <file.map> [group]", "add a map file's entities and brushes to the scene"),
    ("ed_library", "ed_library [row]", "list the saved scenes and prefabs, or open the one a row names"),
    ("ed_libfind", "ed_libfind [words]", "show only the scenes and prefabs of the Library tab whose names hold the words"),
    ("ed_treedrop", "ed_treedrop <row> <what>", "what a row of the scene list let go on another asks for: a brush handed to the entity on that row"),
    ("ed_libdrop", "ed_libdrop <row> <what>", "what a row of the Library tab let go on another asks for: a favourite put before another, or in the trash"),
    (
        "ed_shape",
        "ed_shape <cone|pyramid|ball|dome|stairs|spiral|arch|pipe|bicone|torus|xtree|cap|corner|bevel|column|landing|fan|free> [w d h] [count] [thickness]",
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
        "ed_dup <copies> <dx> <dy> <dz> [turn] | mirror <axes> | axis <x|y|z> | grow <f> | at <name> | path <name> | materials <names> | each [on|off] | hide | show | off | apply | images",
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
        title: str = "3D",
        # A floating window's: the window it is in, its number, and whether
        # it draws the level as outlines.
        window: Floater | None = None,
        number: int = 0,
        wire: bool = False;
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
        doc_strip: Box,
        top: Box,
        bar_row: Box,
        tools_row: Box,
        status_row: Box,
        model_view: ViewArea,
        frame_list: TreeView,
        logic: GraphView,
        prefab_name: TextField,
        modes: list[PushButton],
        center: Box,
        body: Box,
        left: Box,
        right: Box,
        new_key: TextField | None = None,
        new_value: TextField | None = None;
}

"""The studio as its tools see it (see editor/tools/host.jac)."""
obj StudioHost(ToolHost) {
    has studio: Studio;

    def say(message: str) {
        self.studio.say(message);
    }

    def navigation -> NavMesh | None {
        baked = self.studio.nav_mesh;
        if baked is not None {
            return baked;
        }
        app = self.studio.app;
        if app is None {
            return None;
        }
        # A shipped arena's own, when it came with one.
        meshes = [app.world->:HasNavMesh:->][?:NavMesh];
        return meshes[0] if len(meshes) > 0 else None;
    }

    def navigation_mark -> int {
        return len(self.studio.nav_floors);
    }

    def line(start: Vec3, finish: Vec3, color: Ink) {
        wire_line(start, finish, color);
    }

    def listing -> AssetIndex | None {
        stock = self.studio.archive;
        known = self.studio.asset_index;
        if known is None and stock is not None {
            known = AssetIndex(shelf=stock);
            self.studio.asset_index = known;
        }
        return known;
    }

    def picture(material: str) -> Texture | None {
        stock = self.studio.archive;
        found = stock.fetch(material) if stock is not None else None;
        if found is None {
            return None;
        }
        colours = texture_rgba(found);
        wide = found.width;
        tall = found.height;
        if len(colours) == 0 and len(found.encoded) > 0 {
            # Kept as a file's own bytes (a PNG, a JPEG, a packed TGA): read as the window reads it.
            read = self.studio.canvas.decoded(found.extension, found.encoded);
            wide = read[0][0];
            tall = read[0][1];
            colours = read[1];
        }
        if wide <= 0 or tall <= 0 or len(colours) < wide * tall * 4 {
            return None;
        }
        return Texture(name=material, width=wide, height=tall, rgba=colours);
    }

    def palette(game: str) -> bytes {
        known = self.listing();
        if known is None {
            return b"";
        }
        if game == "q1" {
            colours = known.read("q1", "gfx/palette.lmp");
            return colours if colours is not None and len(colours) == 768 else b"";
        }
        if game == "q2" {
            # The last 768 bytes of Quake II's colour map picture are its palette.
            held = known.read("q2", "pics/colormap.pcx");
            return held[len(held) - 768:] if held is not None and len(held) > 769 else b"";
        }
        return b"";
    }

    def folder(kind: str) -> str {
        if kind == "textures" {
            stock = self.studio.archive;
            return stock.files_folder() if stock is not None else "";
        }
        if kind == "scenes" {
            return os.path.dirname(self.studio.scene_path("x"));
        }
        if kind == "scripts" {
            if self.studio.project_folder {
                return self.studio.project_folder + "/scripts";
            }
            kept = os.getenv("QP_SCRIPTS", "");
            return kept if kept else os.getcwd() + "/scripts/user";
        }
        return self.studio.project_folder;
    }

    def read_file(game: str, name: str) -> bytes | None {
        known = self.listing();
        return known.read(game, name) if known is not None else None;
    }

    def file_names(game: str) -> list[str] {
        known = self.listing();
        return known.names(game) if known is not None and game in known.games() else [];
    }

    def materials_shown -> list[str] {
        panel = self.studio.ui;
        return [tile.key for tile in panel.gallery.tiles] if panel is not None else [];
    }

    def frames_of(material: str) -> list[str] {
        return self.studio.material_frames(material);
    }

    def warps(material: str) -> bool {
        return self.studio.material_warps(material);
    }

    def show_picture(material: str, width: int, height: int, rgba: bytes) {
        self.studio.canvas.keep_picture(material, width, height, rgba);
    }

    def panel(key: str, spec: PanelSpec) {
        self.studio.tool_panel_set(key, spec);
    }

    def panel_text(key: str) -> str {
        return self.studio.tool_panel_text(key);
    }

    def panel_close(key: str) {
        self.studio.tool_panel_close(key);
    }

    def playing -> bool {
        return self.studio.playing;
    }

    def fired_log -> list[str] {
        return list(self.studio.fire_log);
    }

    def files_changed {
        stock = self.studio.archive;
        if stock is not None {
            # What the project's folder of textures holds is read again.
            stock.found = {};
            stock.listed = {};
        }
        self.studio.folds += 1;
        self.studio.materials_changed += 1;
    }

    def run(words: list[str]) {
        self.studio.command(words);
    }

    def scene_now -> Scene | None {
        return self.studio.scene;
    }
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
        # How many floating windows have been opened, to number the next.
        floats_made: int = 0,
        # What a click in a view picks (all, brushes or entities), and what
        # was put away to keep editing to a selection.
        pick_kind: str = "all",
        # Materials lately taken in hand (the latest first), and those a
        # search across the games found, with what was searched for.
        recent_materials: list[str] = [],
        found_materials: list[str] = [],
        found_words: str = "",
        kept_out_items: list[Item] = [],
        kept_out_solids: list[Solid] = [],
        # Navigation baked for the scene: its floors, the ways between
        # them, the grid they are on, the engine's mesh, and whether the
        # ways are drawn.
        nav_floors: list[Floor] = [],
        nav_ways: list[Way] = [],
        nav_origin: Vec3 = Vec3(),
        nav_cell: float = 32.0,
        nav_mesh: NavMesh | None = None,
        # The baked navigation's data, handed to the bots of a game played from the scene.
        nav_aas: Aas | None = None,
        nav_shown: bool = False,
        # The tools kept in modules of their own, in the order they were added.
        tools: list[StudioTool] = [],
        tool_host: ToolHost | None = None,
        declared: bool = False,
        # The log panel along the foot of the views: whether it is open,
        # how many of the console's lines it holds, and how far back it
        # is scrolled.
        log_panel: bool = False,
        log_rows: int = 6,
        log_back: int = 0,
        # The entity marked for what is done from the mark later (-1: none).
        marked_item: int = -1,
        # Whether the model editor lists the model's frames under its view.
        frames_listed: bool = False,
        # A sprite's or a film's pictures in the explorer: whether they are
        # running, the time owed to the next, and which picture is kept.
        # The tag an Alt press took hold of in the model's view.
        tag_held: str = "",
        # The weights dialog while it is open, and what it was last filled for.
        weights_box: Floater | None = None,
        weights_for: str = "",
        # The shader script as text while its box is open: the box, the
        # words in it, what it was last filled for, words that did not
        # hold together (kept as typed), and a count of what was asked of
        # the script.
        script_box: Floater | None = None,
        script_area: TextArea | None = None,
        script_for: str = "",
        script_kept: str = "",
        shader_rev: int = 0,
        reel_playing: bool = False,
        # How many bytes of a film's sound were handed to the engine to play.
        reel_heard: int = 0,
        reel_clock: float = 0.0,
        reel_kept: str = "",
        # The tabs beside the menu bar: whether they are there (more than
        # one document is open), and what they were last filled for.
        tabs_on: bool = False,
        tabs_for: str = "",
        # The colours ("dark" or "light"); whether the row of tools and the
        # status bar are shown, and whether the tools are under the views.
        theme_name: str = "dark",
        tools_shown: bool = True,
        status_shown: bool = True,
        tools_below: bool = False,
        # What the floating windows were when the settings were last kept.
        floats_kept: str = "",
        # The shape dialog: its window while it is open, where it was left,
        # and what its fields hold.
        shape_box: Floater | None = None,
        shape_at: list[int] = [360, 120],
        shape_kind: str = "stairs",
        shape_sizes: dict[str, str] = {"w": "128", "d": "128", "h": "96", "count": "", "thick": ""},
        # Whether hints fly beside the pointer, and the field a name is
        # being typed in over a row of the scene list.
        flyovers: bool = True,
        rename_field: TextField | None = None,
        # How the level views share the room: the left views' share of the
        # width and the upper views' of the height, in hundredths; the rows
        # and the column they are laid in; whether the side panels have
        # changed sides; and layouts kept by name, as the words that set them.
        split_x: int = 50,
        split_y: int = 50,
        split_rows: list[Box] = [],
        split_column: Box | None = None,
        sides_swapped: bool = False,
        # Where each side panel is docked: left, right or float; the windows
        # the floating ones are in; and each panel's width when it is docked.
        dock_tabs: str = "left",
        dock_inspector: str = "right",
        dock_windows: dict[str, Floater] = {},
        dock_widths: dict[str, int] = {"tabs": 280, "inspector": 320},
        kept_layouts: dict[str, str] = {},
        # The part of a view its overlays are drawn in, when a floating
        # window covers the rest (the whole of it when this has no size).
        over_piece: Rect = Rect(),
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
        # Lights dragged: the level is lit where they would be left, coarsely,
        # while the drag goes on (by how much, when it was last lit so, and
        # whether the level shows such a light now).
        preview_shift: Vec3 = Vec3(),
        preview_at: float = 0.0,
        previewed: bool = False,
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
        lassoing: bool = False,
        lasso: list[int] = [],
        snap_to: str = "grid",
        show_triggers: bool = False,
        show_unseen: bool = False,
        snap_reach: float = 16.0,
        box_port: int = 0,
        # How far a dragged corner or edge has gone.
        corner_by: Vec3 = Vec3(),
        # Which handles a selection shows (move, turn or size), how far a
        # dragged one has turned or stretched it, and what a turn snaps to.
        gizmo: str = "move",
        # What the move arrows run along (world, local, view), and the one
        # of them a dragged selection is kept to (-1 for none).
        gizmo_axes: str = "world",
        axis_lock: int = -1,
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
        # Materials go with a move but keep to the world's axes through a
        # turn, a stretch or a shear (with `tex_lock`).
        tex_axis: bool = False,
        # The three ways the turn rings and size boxes go by, as last worked out.
        gizmo_ways: list[Vec3] = [],
        # A corner moved takes with it the corners of other brushes that stand at the same point.
        corner_lock: bool = False,
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
        # How the model is played and drawn: frames a second, the frames
        # played (all when the last is below zero), round again or once,
        # with frames between, with the faces turned away, every point ticked.
        model_rate: float = 10.0,
        model_first: int = 0,
        model_last: int = -1,
        model_loops: bool = True,
        model_smooth: bool = False,
        model_between: int = 0,
        bits_game: str = "q2",
        asset_tags: dict[str, list[str]] = {},
        tags_read: bool = False,
        sized_shown: int = -1,
        # Patches shown as the games make them, at the renderer's subdivision.
        # The shader box: its window and what it was last made for; and the
        # shader's preview, drawn by the engine's model renderer.
        shader_box: Floater | None = None,
        shader_box_for: str = "",
        shader_drawer: ModelRenderer | None = None,
        patch_preview: bool = False,
        # The patch's material box: its window, its picture pane, what it was
        # last made for, the material's size in texels, and a place being dragged.
        patch_box: Floater | None = None,
        patch_pane: SkinPane | None = None,
        patch_box_for: str = "",
        patch_box_size: list[float] = [64.0, 64.0],
        patch_held: int = -1,
        patch_press: list[int] = [0, 0],
        patch_drag: list[float] = [0.0, 0.0],
        patch_fineness: float = 4.0,
        preview_edges_kept: dict[str, list[list[list[Vec3]]]] = {},
        # The model's floating window: its window, its view, and its own
        # way of looking at the model (turned and drawn nearer by itself).
        model_float_box: Floater | None = None,
        model_float_pane: ViewArea | None = None,
        model_float_lens: EditCamera = EditCamera(),
        model_float_yaw: float = 2.4,
        model_float_pitch: float = -0.35,
        model_float_reach: float = 160.0,
        # The overdraw view: every face the renderer would draw from the eye,
        # added up, and how many there were in the view last drawn.
        # The journal kept for a crash: the scene it is of, the last step
        # seen, the states its latest steps left it in (each under the step's
        # name), and when one was last taken.
        journal_of: str = "",
        journal_last: Step | None = None,
        journal_kept: list[tuple[str, str]] = [],
        journal_clock: float = 0.0,
        # Light baked a slice a frame, the studio going on meanwhile: whether
        # it is, and the bake under way.
        light_background: bool = False,
        light_task: LightTask | None = None,
        overdraw: bool = False,
        overdraw_faces: int = 0,
        model_backs: bool = True,
        model_ticks: float = 0.0,
        # How the marks on the model's points are drawn; the model being
        # edited as edges, filled or with its skin; and what its view turns about.
        model_marks: str = "cross",
        model_shade: str = "wire",
        model_about: str = "model",
        # The axes picked points are not dragged along, and the handle held (-1 for none).
        model_lock: str = "",
        model_handle: int = -1,
        # The model's points shown in the colours they were given.
        points_tinted: bool = False,
        # What the skin's brush lays its colour in, and how wide its squares are.
        skin_pattern: str = "solid",
        skin_grain: int = 4,
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
        # Every tagged face: its plane and what it was called; and the first one's brush and side.
        tag_planes: list[Plane3] = [],
        tag_names: list[str] = [],
        tagged_solid: Solid | None = None,
        tagged_index: int = -1,
        # The sculpting brush, whether a stroke is being drawn, drags since
        # its last dab, and where on a terrain the pointer is.
        brush_radius: float = 96.0,
        brush_amount: float = 16.0,
        sculpting: bool = False,
        sculpt_drags: int = 0,
        sculpt_at: Vec3 | None = None,
        # The terrain under the pointer, by its number (-1 when none).
        sculpt_land: int = -1,
        # The rectangle brush: whether a drag in sculpt mode draws a
        # rectangle to lift, how far outside it the lift falls away (units,
        # or a share of its shorter side as "50%"), its two corners while it
        # is drawn and the terrain it is drawn on.
        rect_brush: bool = False,
        rect_fall: str = "",
        rect_from: Vec3 | None = None,
        rect_to: Vec3 | None = None,
        rect_land: int = -1,
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
        # The bake's portals drawn, and those read from a portal file.
        portals_shown: bool = False,
        portal_lines: list[list[Vec3]] = [],
        portal_file: str = "",
        recipes: dict[str, str] = {},
        built_copies: list[KeptBake] = [],
        built_reused: bool = False,
        # Whether the last build was brought in line in place: only the
        # faces and brushes an edit changed packed again (patch_built).
        built_patched: bool = False,
        # The project open and its folder; the add-ons loaded (each file's
        # classes), those of them kept in the settings; and what each game
        # is set up with ("q1.material" and the like).
        project: Project | None = None,
        project_folder: str = "",
        addons: dict[str, list[str]] = {},
        # What add-ons bring beside classes: each one's name by its file,
        # and its folders of image files and of prefabs by its name.
        addon_labels: dict[str, str] = {},
        addon_textures: dict[str, str] = {},
        addon_prefabs: dict[str, str] = {},
        # Folders of image files used where they lie, by a name for each,
        # and lists of materials kept by name: those of the studio's own
        # settings (a project keeps its own in its manifest).
        tex_links: dict[str, str] = {},
        tex_lists: dict[str, list[str]] = {},
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
        # The scene's logic drawn over the game as it runs: whether it is,
        # the game's own time played since it began, and when each name last fired.
        graph_over: bool = False,
        play_clock: float = 0.0,
        fired_when: dict[str, float] = {},
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
        # The other documents open: models and shader scripts not in hand,
        # and the textures open as documents (by "game:file") with the one shown.
        models_parked: list[ModelSlot] = [],
        shaders_parked: list[ShaderSlot] = [],
        textures_open: list[str] = [],
        texture_now: str = "",
        plot: list[int] = [],
        plot_land: Item | None = None,
        plot_variance: float = 0.0,
        # Entities drawn as their game's models in the 3D view: whether,
        # each model's edges once read, and how many were drawn last.
        models_shown: bool = False,
        preview_models: dict[str, list[list[Vec3]]] = {},
        models_drawn: int = 0,
        # Entities drawn with their skins (and sprites as their pictures),
        # not as edges; what was read for that, by look; and how many were
        # drawn so in the view last drawn.
        models_skinned: bool = True,
        preview_looks: dict[str, PreviewLook] = {},
        skins_drawn: int = 0,
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
        skin_view: SkinPane | None = None,
        # A drag on the skin's picture: how far the picked points' places
        # would go (a share of the picture across and down), and where it began.
        skin_drag: list[float] = [0.0, 0.0],
        skin_press: list[float] = [],
        # The Library tab's picture of a prefab, which prefab it is of, and
        # the words its rows are found by.
        library_view: Picture | None = None,
        library_previewed: str = "",
        # Boxes that tools show: each one's window and words by its name,
        # what it is to show, and those to be filled again.
        tool_boxes: dict[str, Floater] = {},
        tool_areas: dict[str, TextArea] = {},
        tool_specs: dict[str, PanelSpec] = {},
        tool_stale: list[str] = [],
        # The collision hulls a navigation bake leaves out (what moves, when doors are taken as open).
        nav_exclude: list[int] = [],
        # The scene's count of picks when its groups' groups were last picked with them.
        nest_picks: int = -1,
        library_filter: str = "",
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
        # Keys bound by hand: a keyboard of the engine's for each way Ctrl
        # and Shift are held (document/chords.jac), apart from every game's.
        key_layers: dict[str, Keyboard] = {},
        dev_shown: bool = False,
        frame_ms: float = 0.0,
        # What the program holds in memory, asked of the system once a
        # second while the readout is shown (0 until it has answered).
        memory_mb: float = 0.0,
        memory_due: float = 0.0,
        # How many pixels wide the studio's own lines are drawn in the views.
        line_width: int = 1,
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
        autosave_every: float = 30.0,
        # The settings as a table (document/settingstable.jac): what each
        # is now, the console variable that says so, a count of how often
        # they have been kept and the mark the variables were last set at;
        # the box of them by subject, and colours set by hand.
        setting_table: list[Setting] = [],
        setting_values: dict[str, str] = {},
        setting_cvars: dict[str, Cvar] = {},
        settings_rev: int = 0,
        settings_mark: str = "",
        settings_box: Floater | None = None,
        settings_subject: str = "general",
        settings_for: str = "",
        user_inks: dict[str, str] = {},
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
        self.declared = True;
        for tool in self.tools {
            for (name, usage, description) in tool.commands() {
                shell.command(name, "studio", usage, description);
            }
        }
    }

    """The studio as its tools see it."""
    def host -> ToolHost {
        known = self.tool_host;
        if known is None {
            known = StudioHost(studio=self);
            self.tool_host = known;
        }
        return known;
    }

    """Take a tool on: its commands are the studio's from now on."""
    def add_tool(tool: StudioTool) {
        self.tools.append(tool);
        app = self.app;
        if self.declared and app is not None {
            for (name, usage, description) in tool.commands() {
                app.shell.command(name, "studio", usage, description);
            }
        }
    }

    """Offer a command to the tools, first added first. False when it is none of theirs."""
    def plugin_command(scene: Scene, args: list[str]) -> bool {
        for tool in self.tools {
            if tool.command(self.host(), scene, args) {
                return True;
            }
        }
        return False;
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
        if self.nav_mesh is not None {
            # Navigation baked for the level that was is of a world that is
            # gone: its areas went with it, and are not to be asked the way.
            self.nav_mesh = None;
            self.nav_floors = [];
            self.nav_ways = [];
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
        baked = self.nav_aas;
        if baked is not None {
            # The navigation baked for the scene is the played game's: its bots route over it.
            for old_mesh in [app.world->:HasNavMesh:->][?:NavMesh] {
                app.world del->:HasNavMesh:-> old_mesh;
            }
            build_navmesh(app.world, baked, app.level.bsp);
            print("studio: bots route over the baked navigation areas=" + str(len(baked.areas) - 1));
        }
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
                    MenuItem(text="Quit", command="quit"),
                    MenuItem(rule=True),
                    MenuItem(text="Make a starter project to play in", command="ed_starter")
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
                    MenuItem(text="Look for a leak", command="ed_leak"),
                    MenuItem(rule=True),
                    MenuItem(text="Put everything on the grid", command="ed_snap all"),
                    MenuItem(text="Keep editing to the selection", command="ed_restrict"),
                    MenuItem(text="Clicks pick everything", command="ed_pickmode all"),
                    MenuItem(text="Clicks pick brushes only", command="ed_pickmode brushes"),
                    MenuItem(text="Clicks pick entities only", command="ed_pickmode entities")
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
                    MenuItem(text="The patch's material...", command="ed_patchbox open"),
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
                    MenuItem(text="Handles on the picked face for its material", command="ed_texhandles"),
                    MenuItem(rule=True),
                    MenuItem(text="Lay the picked faces through whole points", command="ed_integral"),
                    MenuItem(text="Tilt the picked faces to whole angles", command="ed_faceangle"),
                    MenuItem(rule=True),
                    MenuItem(text="Build a shape...", command="ed_shapebox open")
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
                    MenuItem(text="Show how much is drawn over each place", command="ed_overlay overdraw"),
                    MenuItem(rule=True),
                    MenuItem(text="Recipes", command="ed_recipe"),
                    MenuItem(rule=True),
                    MenuItem(text="What fired in the last game", command="ed_fired"),
                    MenuItem(text="Name each firing as it happens", command="ed_trace"),
                    MenuItem(text="The logic over the game, lit as it fires", command="ed_trace graph"),
                    MenuItem(text="Firings that hold the game", command="ed_break"),
                    MenuItem(rule=True),
                    MenuItem(text="Bake navigation for bots", command="ed_nav bake"),
                    MenuItem(text="What the baked navigation cannot reach", command="ed_nav check"),
                    MenuItem(text="Draw the baked ways", command="ed_nav show"),
                    MenuItem(text="Draw the ways bots take between camp spots", command="ed_camps routes"),
                    MenuItem(rule=True),
                    MenuItem(text="Bake by the brushes' own planes", command="ed_bake planes"),
                    MenuItem(text="Show the bake's portals", command="ed_portals"),
                    MenuItem(text="Load a portal file", command="ed_portals load"),
                    MenuItem(text="Write the bake's portal file", command="ed_portals write")
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
                    MenuItem(text="The shader in hand, stage by stage...", command="ed_shaderbox open"),
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
                    MenuItem(text="Check the districts' materials", command="ed_district check"),
                    MenuItem(rule=True),
                    MenuItem(text="Another 3D window", command="ed_window new"),
                    MenuItem(text="Another 3D window, in outlines", command="ed_window new outlines"),
                    MenuItem(text="Close the floating windows", command="ed_window close all"),
                    MenuItem(rule=True),
                    MenuItem(text="Log panel along the foot of the views", command="ed_log panel"),
                    MenuItem(rule=True),
                    MenuItem(text="Light or dark colours", command="ed_theme"),
                    MenuItem(text="Show or hide the row of tools", command="ed_bar tools"),
                    MenuItem(text="Tools over or under the views", command="ed_bar tools flip"),
                    MenuItem(text="Show or hide the status bar", command="ed_bar status"),
                    MenuItem(rule=True),
                    MenuItem(text="The picked points' weights...", command="ed_weights open"),
                    MenuItem(text="The shader script as text...", command="ed_shader text open"),
                    MenuItem(text="Play the materials that move", command="ed_animate"),
                    MenuItem(text="Settings by subject...", command="ed_settings box open"),
                    MenuItem(text="Playtest: can it be finished?", command="ed_playtest bake")
                ]
            ]
        );
        # The menu bar, and beside it in the same row the open documents' tabs.
        bar_row = Box(across=True, fill="header");
        top.adopt(bar_row);
        bar_row.adopt(menu);
        doc_strip = Box(across=True, gap=2, grow=1, fill="header");
        bar_row.adopt(doc_strip);

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
        # At the panel's foot, so that what is above it stands where it did.
        left.adopt(
            DockGrip(
                panel="tabs", text="Scene, materials, checks, library, classes",
                hint="Drag to dock this panel on the other side, or let go in the middle to float it"
            )
        );
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
            drag="tree",
            drop="ed_treedrop",
            grow=1,
            hint="Click selects (Ctrl adds), double click looks at it; drag a brush onto the entity that is to hold it, or anything into a view"
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
            drop="ed_libdrop",
            grow=1,
            hint="Click a scene to open it, or a prefab to add a copy where the camera looks; drag a prefab into a view"
        );
        library_page.adopt(library);
        # At the foot, so that the rows above stay where they were: a
        # picture of the prefab the pointer is on, and a field to find by.
        library_view = Picture(
            key="library:preview", size=132, shown=False, hint="The prefab the pointer is on, seen from above one corner"
        );
        library_page.adopt(library_view);
        self.library_view = library_view;
        find_row = Box(pad=4);
        library_page.adopt(find_row);
        find_row.adopt(
            TextField(
                ghost="Find in the library", command="ed_libfind", live=True,
                hint="Show only the scenes and prefabs whose names hold these words"
            )
        );
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
            drag="asset",
            drop="ed_assetdrop",
            carry_branches=True,
            grow=1,
            hint="Click a folder to open it, a file to see it; drag either onto Your project to copy it there"
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
            self.sync_addons();
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
        right.adopt(
            DockGrip(
                panel="inspector", text="Inspector", heading=True,
                hint="Drag to dock this panel on the other side, or let go in the middle to float it"
            )
        );
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
            doc_strip=doc_strip,
            top=top,
            bar_row=bar_row,
            tools_row=tools,
            status_row=status,
            model_view=model_view,
            frame_list=TreeView(
                pick="ed_frame",
                drag="frame",
                drop="ed_framedrop",
                size=104,
                hint="Click goes to a frame; drag one onto another to put it there in the order"
            ),
            logic=sheet,
            prefab_name=prefab_name,
            modes=modes,
            center=center,
            body=body,
            left=left,
            right=right
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
        lighting = self.light_task;
        ui.place.text = (
            "baking " + str(int(lighting.share() * 100.0)) + "%   " if lighting is not None else ""
        ) + self.dev_words(scene) + ("frozen   " if self.frozen else "")
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
                if name == "func_group" and scene.nested_in(item) is not None {
                    # Listed under the group that holds it.
                    continue;
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
        adder.adopt(PushButton(glyph="plus", command="ed_add", size=22, hint="Add the field"));
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
        if self.dev_shown {
            self.memory_due -= dt;
            if self.memory_due <= 0.0 {
                self.sample_memory();
                # The first answer is looked for sooner than the rest.
                self.memory_due = 1.0 if self.memory_mb > 0.0 else 0.25;
            }
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
        self.preview_library(ui);
        ui.classes.track(stage);
        ui.assets.track(stage);
        ui.frame_list.track(stage);
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
        self.keep_tabs(ui);
        self.keep_floats();
        self.keep_weights_box();
        self.keep_patch_box();
        self.keep_shader_box();
        self.patch_box_events();
        self.keep_script_box();
        self.keep_tool_panels();
        self.watch_settings();
        self.keep_settings_box();
        doc_now = self.scene;
        if doc_now is not None and doc_now.picks != self.nest_picks {
            # A group picked in a view or the list shows what it holds as picked.
            doc_now.pick_nested();
            self.nest_picks = doc_now.picks;
        }
        for tool in self.tools {
            tool.tick(self.host(), dt);
        }
        ui.logic.track(stage);
        self.load_thumbs();
        self.keep_built();
        self.keep_journal(dt);
        self.step_light();
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
        typed = self.rename_field;
        if typed is not None and not typed.focused {
            # The name typed over a row is done with: entered, or left as it was.
            stage.close(typed);
            self.rename_field = None;
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
                if self.mode == "sculpt" and self.rect_brush {
                    # One corner of a rectangle drawn on the terrain.
                    corner = self.terrain_point(scene, event.x, event.y);
                    if corner is not None {
                        self.rect_from = corner;
                        self.rect_to = corner;
                        self.rect_land = self.sculpt_land;
                    }
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
                } elif self.mode == "brush" {
                    # With Alt it becomes a loop drawn freehand round what is wanted.
                    self.lassoing = True;
                    self.lasso = [event.x, event.y];
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
                if event.button == 0 and self.rect_from is not None {
                    self.rect_lift(event.shift);
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
                if event.button == 0 and self.lassoing {
                    self.lassoing = False;
                    if len(self.lasso) >= 8 {
                        self.moved = True;
                        stage.emit(
                            "ed_lasso " + str(self.box_port) + " " + " ".join([str(value) for value in loop_thinned(self.lasso, 48)])
                                + (" add" if event.ctrl or event.shift else "")
                        );
                    }
                    self.lasso = [];
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
            } elif event.kind == "drag" and self.rect_from is not None {
                # The rectangle's other corner, while the pointer is over its terrain.
                other = self.terrain_point(scene, event.x, event.y);
                if other is not None and self.sculpt_land == self.rect_land {
                    self.rect_to = other;
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
            } elif event.kind == "drag" and self.lassoing {
                # A point of the loop wherever the pointer has gone a little way on.
                if abs(event.x - self.lasso[-2]) + abs(event.y - self.lasso[-1]) >= 4 {
                    self.lasso.append(event.x);
                    self.lasso.append(event.y);
                }
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
            bound_order = chord_command(self.key_layers, ("ctrl+" if ctrl else "") + ("shift+" if shift else ""), key);
            if bound_order {
                stage.emit(bound_order);
                continue;
            }
            if key == "F8" {
                stage.emit("edit");
            } elif key == "F1" {
                stage.emit("ed_help");
            } elif key == "F2" {
                stage.emit("ed_rename");
            } elif key == "F5" {
                stage.emit("ed_play");
            } elif key == "F6" {
                stage.emit("ed_play here");
            } elif key == "ESCAPE" {
                if self.over_layers(stage) > 0 {
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
        if self.axis_lock >= 0 and self.scene is not None {
            # Kept to one of the axes the handles run along.
            self.move_by = kept_to_axis(shift, self.gizmo_basis(self.scene)[self.axis_lock], 1.0 if free else self.grid);
            return;
        }
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
        # A bar lies between the rows of four views, in place of the gap.
        ui.center.gap = 0 if self.layout == 4 else 3;
        if self.layout == 1 {
            ui.center.adopt(self.ports[0].view);
            return;
        }
        # The views share the room by weight; a bar between them, where a
        # gap was, is dragged to share it out otherwise (ed_split).
        upper = Box(across=True, grow=1);
        ui.center.adopt(upper);
        upper.adopt(self.ports[0].view);
        upper.adopt(Sash(command="ed_split x", hint="Drag to make the views wider or narrower"));
        self.split_rows = [upper];
        self.split_column = None;
        if self.layout == 2 {
            # The classic pair: the 3D view beside the plan.
            upper.adopt(self.ports[1].view);
            self.apply_split();
            return;
        }
        if self.layout == 3 or self.layout == 5 {
            # The 3D view beside a column of axis views: two, or all three.
            column = Box(grow=1, gap=3);
            upper.adopt(column);
            for index in range(1, 3 if self.layout == 3 else 4) {
                column.adopt(self.ports[index].view);
            }
            self.split_column = column;
            self.apply_split();
            return;
        }
        ui.center.adopt(Sash(command="ed_split y", hint="Drag to make the views taller or shorter"));
        lower = Box(across=True, grow=1);
        ui.center.adopt(lower);
        upper.adopt(self.ports[1].view);
        lower.adopt(self.ports[2].view);
        lower.adopt(Sash(command="ed_split x", hint="Drag to make the views wider or narrower"));
        lower.adopt(self.ports[3].view);
        self.split_rows = [upper, lower];
        self.apply_split();
    }

    """Share the room among the level views by the split now set."""
    def apply_split;
    """The views' split, the side panels' sides and layouts kept by name."""
    def layouts_command(scene: Scene, args: list[str]) -> bool;
    """The open documents and which is shown, as one line: the tab strip is
    filled again when it changes."""
    def tabs_words -> str;
    def tabs_count -> int;
    def fill_doc_strip(ui: StudioUi);
    def keep_tabs(ui: StudioUi);
    """Go to an open document by its tab, or choose a field's file from the
    game's own."""
    def tabs_command(scene: Scene, args: list[str]) -> bool;
    """Put the menu bar, the tools, the views and the status bar in the
    order now set, leaving out what is hidden."""
    def place_bars;
    """The floating windows as the commands that open them again."""
    def float_settings -> list[str];
    """Keep the settings when a floating window has been moved, sized or flown."""
    def keep_floats;
    """Open the shape dialog, or fill it again from what its fields hold."""
    def show_shape_box;
    """The colours, the bars, and the shape dialog."""
    def looks_command(scene: Scene, args: list[str]) -> bool;
    """Go to the next picture of the sprite or film shown (the one before,
    going `back`). False when there is none to go to."""
    def reel_step(back: bool) -> bool;
    def play_reel(dt: float);
    def reel_command(args: list[str]) -> bool;
    """The tag nearest a point of the model's view, within reach of the pointer ("" for none)."""
    def tag_under(x: int, y: int) -> str;
    """Where a place of the model shows in its view, as "x,y" ("nowhere" when it does not)."""
    def tag_seen(at: Vec3) -> str;
    """A picture of a game's as a skin: a PCX, WAL or plain TGA, or the
    n-th skin a Quake model carries. None when it does not read."""
    def skin_from(game: str, name: str, number: int) -> Skin | None;
    """Fill the weights dialog again when what it shows has changed."""
    def keep_weights_box;
    def weights_command(scene: Scene, args: list[str]) -> bool;
    """The row of frames a material is one of (itself alone when it does
    not move), and whether it is drawn warping (impl/studio.sounds.impl.jac)."""
    def material_frames(wanted: str) -> list[str];
    def material_warps(name: str) -> bool;
    # The shader script as text (impl/studio.shadertext.impl.jac)
    """Fill the script's box again when the script has changed."""
    def keep_script_box;
    # Boxes that tools show (impl/studio.toolpanel.impl.jac)
    def tool_panel_set(key: str, spec: PanelSpec);
    def tool_panel_text(key: str) -> str;
    def tool_panel_close(key: str);
    """Open and fill the tools' boxes that have something new to show."""
    def keep_tool_panels;
    def toolpanel_command(args: list[str]) -> bool;
    def script_words -> str;
    """Open or close the script's box, or read its words as the script.
    False for every other shader command, which goes on to its own."""
    def script_command(scene: Scene, args: list[str]) -> bool;
    """What the command table says of a command: its usage and what it does."""
    def help_lines(asked: str) -> list[str];
    """Help for what the pointer is on or for a command by name, hints
    beside the pointer, and an entity named over its row."""
    def help_command(scene: Scene, args: list[str]) -> bool;
    """The layout as it stands, as the words that would set it again."""
    def layout_words -> str;
    """Put the side panels on the sides now set."""
    def place_sides;

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
            # The explorer's model, alone in its own view (in the first of
            # four, with views from above, the front and the side, when it is
            # laid out so).
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
            for (kind, quarter) in model_quarters(self.ui) {
                flat = axis_camera(kind, self.model_reach * 1.1);
                seen.append(
                    SceneView(
                        x=quarter.x,
                        y=quarter.y,
                        width=quarter.w,
                        height=quarter.h,
                        eye=self.model_middle.sub(flat.forward().scale(self.model_reach * 4.0)),
                        yaw=flat.yaw,
                        pitch=flat.pitch,
                        span=flat.span,
                        everything=True,
                        bare=True
                    )
                );
            }
            pane = self.model_float_pane;
            if pane is not None and pane.parent() is not None and pane.area.w > 0 {
                # The model's floating window, with its own way of looking at it.
                lens = self.model_float_lens;
                seen.append(
                    SceneView(
                        x=pane.area.x,
                        y=pane.area.y,
                        width=pane.area.w,
                        height=pane.area.h,
                        eye=lens.eye,
                        yaw=lens.yaw,
                        pitch=lens.pitch,
                        span=0.0,
                        everything=True,
                        bare=True,
                        over=True
                    )
                );
            }
        }
        for (index, port) in enumerate(self.ports[:self.showing()]) {
            area = port.view.area;
            if area.w <= 0 or area.h <= 0 {
                continue;
            }
            edges = self.wire_main if index == 0 else self.wire_axis;
            # A view held to a band of depth shows the level only within it
            # (unless what lies outside is to be shown whole).
            band = depth_cut(port.camera) if self.outside != "whole" else [0.0, 0.0];
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
                    bare=edges and built,
                    near=band[0],
                    far=band[1]
                )
            );
        }
        # The floating windows after, so that they are drawn over the rest.
        for floating in self.float_views(built) {
            seen.append(floating);
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
        _pen.hold(view, self.main.fov, self.line_width);
        if self.assets_shown {
            # The only view then is the explorer's model.
            drawer = self.shader_drawer;
            shown_now = self.model_now;
            if drawer is not None and shown_now is not None and shown_now.name.startswith("shader:") {
                # The shader as the game draws a model with it, moving as it moves.
                rlDrawRenderBatchActive();
                drawer.draw_immediate(Vec3(), 0.0, 0, 0, 0.0, view.eye, time.time() - _shader_clock.began);
                rlDrawRenderBatchActive();
                return;
            }
            filled = self.model_doc is not None and self.model_shade != "wire";
            if filled {
                self.draw_model_faces();
                rlDrawRenderBatchActive();
            }
            if not (filled and self.model_shade == "textured") {
                # Over faces that are filled the edges are fainter; over the skin there are none.
                for pair in self.model_edges {
                    wire_line(pair[0], pair[1], ink(0x1b1916, 120) if filled else ink(0xe6dfd4));
                }
            }
            self.draw_model_ticks();
            self.draw_model_marks();
            self.draw_model_handles();
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
        self.draw_entity_skins(scene);
        if self.overdraw and view.span <= 0.0 {
            self.overdraw_faces = self.draw_overdraw(view);
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
        self.draw_patch_preview(scene);
        for tool in self.tools {
            tool.draw_through(self.host(), scene);
        }
        self.draw_nav();
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
        if ring is not None and not self.rect_brush {
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
        self.draw_rect_brush();
        # The way out of a level that leaks.
        for i in range(1, len(self.leak)) {
            wire_line(self.leak[i - 1], self.leak[i], ink(0xe5484d));
        }
        self.draw_cells(scene);
        self.draw_portals(scene);
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
        self.draw_patch_box();
        # Over each level view, through its own camera: unless a menu, a
        # list or the palette is open over them.
        if self.over_layers(stage) > 0 {
            self.canvas.unclip();
            return;
        }
        watched = self.port_now;
        # Whatever floats over the views: their own windows, and the boxes.
        floating = [layer for layer in stage.layers() if isinstance(layer, Floater)];
        covered = [layer.area for layer in floating];
        for index in range(self.showing()) {
            self.watch(index);
            # Only where no floating window covers the view.
            for piece in rects_outside(self.view_area(), covered) {
                self.over_piece = piece;
                self.draw_over_view(scene, self.ports[index].title if self.layout != 1 else "");
            }
        }
        self.over_piece = Rect();
        for index in range(4, len(self.ports)) {
            # A floating window says its own name on its bar; and it draws
            # nothing where a window opened after it floats above it.
            self.watch(index);
            casing = self.ports[index].window;
            above: list[Rect] = [];
            reached = False;
            for layer in floating {
                if layer is casing {
                    reached = True;
                } elif reached {
                    above.append(layer.area);
                }
            }
            for piece in rects_outside(self.view_area(), above) {
                self.over_piece = piece;
                self.draw_over_view(scene, "");
            }
        }
        self.over_piece = Rect();
        self.watch(watched);
        self.canvas.unclip();
        self.draw_log_panel();
    }

    """Names over the selection and over what the pointer is on, the selected
    brush's handles, and the view's title."""
    def draw_over_view(scene: Scene, title: str) {
        area = self.view_area();
        canvas = self.canvas;
        canvas.clip(area.within(self.over_piece) if self.over_piece.w > 0 else area);
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
        self.draw_depth_knobs(area);
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
        if self.lassoing and self.port_now == self.box_port and len(self.lasso) >= 4 {
            # The loop as drawn so far, and the line that would close it.
            turns = len(self.lasso) // 2;
            for at in range(turns) {
                onward = (at + 1) % turns;
                canvas.line(
                    self.lasso[at * 2], self.lasso[at * 2 + 1], self.lasso[onward * 2], self.lasso[onward * 2 + 1],
                    canvas.theme.accent if onward != 0 else canvas.theme.accent.faded(110)
                );
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
    """Bring the level in line with the document in place, where only the
    world's brushes moved or changed shape: False when it must be built
    again."""
    def patch_built(scene: Scene) -> bool;
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
    """While only lights are dragged, light the level as they would be left,
    at most four times a second and coarsely. True while that is so."""
    def preview_light(scene: Scene) -> bool;
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
    """Sketch the prefab the pointer is on in the Library tab."""
    def preview_library(ui: StudioUi);
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
    """The commands that would set the studio as it stands: what the
    settings file holds."""
    def settings_lines -> list[str];
    # Settings by subject and as console variables (impl/studio.settingsbox.impl.jac)
    """The settings file's lines and, before them, what it does not keep."""
    def setting_lines_all -> list[str];
    """The theme, with the colours set by hand over it."""
    def apply_inks;
    """Keep the console variables saying what is so, and set the studio
    to match one that was changed from the console."""
    def watch_settings;
    """Fill the settings box again when a setting or its subject changed."""
    def keep_settings_box;
    """Run ed_colour, ed_settings box or ed_settings vars. False otherwise."""
    def settings_box_command(scene: Scene, args: list[str]) -> bool;
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
    """Lift (or lower) what the rectangle drawn on a terrain encloses, and forget it."""
    def rect_lift(lower: bool);
    def draw_rect_brush;
    """One dab of the sculpting brush under the pointer."""
    def dab(scene: Scene, x: int, y: int, lower: bool, smooth: bool);

    # ------------------------------------------------------------------
    # Curved patches (impl/studio.patch.impl.jac)

    """Run a patch command. False when it is not one."""
    def patch_command(scene: Scene, args: list[str]) -> bool;
    """The one selected entity, when it is a patch."""
    def patch_now(scene: Scene) -> Item | None;
    """A patch as the games make it, by the engine's own code: the edges of
    the triangles its renderer draws and of the lattice its collision is
    traced against (kept until the patch changes); they drawn over every
    patch; and a line of the dump saying how many."""
    def patch_preview_lines(scene: Scene, item: Item) -> list[list[list[Vec3]]];
    def draw_patch_preview(scene: Scene);
    def patch_preview_words(scene: Scene) -> str;

    # ------------------------------------------------------------------
    # The patch's material box (impl/studio.patchbox.impl.jac)

    """The selected patch's places on its material (none when no patch is)."""
    def patch_box_state(scene: Scene) -> list[float];
    """Make the box again when what it shows has changed; take its pane's
    drags; draw the places over the picture; open or close it."""
    def keep_patch_box;
    def patch_box_events;
    def draw_patch_box;
    def patch_box_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Several documents of each kind (impl/studio.docset.impl.jac)

    """Put the model in hand aside (with its skin) to take another, and take
    a parked one in hand (by its place among them, -1 the last); the same
    for shader scripts. False when there is no such one."""
    def park_model;
    def unpark_model(index: int) -> bool;
    def park_shader;
    def unpark_shader(index: int) -> bool;
    def docset_words -> str;
    """Run `ed_documents` or `ed_texture`. False when it is neither."""
    def docset_command(scene: Scene, args: list[str]) -> bool;
    """Show an open texture document in the explorer."""
    def show_texture_doc(key: str);

    # ------------------------------------------------------------------
    # The shader box and preview (impl/studio.shaderbox.impl.jac)

    """Make the shader box again when the shader in hand has changed; its
    commands (`ed_shaderbox`, `ed_shaderline`); and the shader drawn on a
    square in the explorer by the engine's model renderer ("" when it is,
    else why not)."""
    def keep_shader_box;
    def shader_box_command(scene: Scene, args: list[str]) -> bool;
    def preview_shader -> str;

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
    """The three ways the move arrows run now: the world's axes, the
    selection's own, or across, into and up the view."""
    def gizmo_basis(scene: Scene) -> list[Vec3];
    """One of the ways the rings and boxes go by (the world's when none are worked out)."""
    def gizmo_way(index: int) -> Vec3;
    """Whether materials go with their faces through a turn, a stretch or a shear."""
    def tex_turns -> bool {
        return self.tex_lock and not self.tex_axis;
    }
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
    """Take what the system last said the program holds in memory, and ask
    it again."""
    def sample_memory;
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
    the arrow it faces along (940), the edge of a light's reach (941), and
    the edge of the cone of a light that shines one way (942)."""
    def mark_handles(scene: Scene) -> list[tuple[int, Vec3]];
    """The cone a light shines in (none for one that shines every way, or
    for what is no light), and where the handle on its edge stands when
    half its angle is so many degrees."""
    def spot_of(item: Item) -> Cone | None;
    def cone_knob(middle: Vec3, cone: Cone, half: float) -> Vec3;
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
    """The scene's logic over the game as it runs: each entity that fires or
    is fired a box, lit as it fires and fading after, with lines to what it
    fires, a box that holds the game marked red."""
    def draw_over_game(width: int, height: int);
    """Every face the engine would draw from a 3D view's eye (through the
    level's PVS when culling is on), each added over what is behind it in
    one faint colour, depth ignored: where many lie over one another it
    glows. Answers how many faces were drawn."""
    def draw_overdraw(view: SceneView) -> int;
    """Take the state each new step leaves the scene in (no oftener than
    twice a second; a step in between is named with the next), for the
    journal written beside the autosave."""
    def keep_journal(dt: float);
    """Bake a slice more of the light under way (about a hundredth of a
    second's worth), and when it is all lit keep it and build again, which
    takes it."""
    def step_light;
    """Where a scene's journal is kept."""
    def journal_path(name: str) -> str;
    """Run a breakpoint, trace, fired or live command. False when it is not one."""
    def live_command(args: list[str]) -> bool;
    """Call over a played game's opponents, doors and pickups, or change
    one by its number (impl/studio.liveroll.impl.jac)."""
    def live_others(args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # A bake seen, recipes, and other programs' steps (impl/studio.steps.impl.jac)

    """The cell the bake's cells are shown from (-1 when nothing is baked)."""
    def eye_cell(scene: Scene) -> int;
    """How many cells that one sees, itself among them."""
    def cells_seen(scene: Scene) -> int;
    def draw_cells(scene: Scene);
    def draw_portals(scene: Scene);
    def portals_command(scene: Scene, args: list[str]);
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
    """Hand the add-ons' folders of image files to the archive, and list
    materials and the library again."""
    def sync_addons;
    """An add-on's line of the listing: its classes, name, and how many
    materials and prefabs it brings."""
    def addon_words(path: str) -> str;
    # Linked folders and lists of materials (impl/studio.texlinks.impl.jac)
    """The folders linked to and the lists kept: the settings' own, and
    over them the open project's."""
    def all_links -> dict[str, str];
    def all_lists -> dict[str, list[str]];
    """Run ed_texlink or ed_texlist. False when it is neither."""
    def texlink_command(scene: Scene, args: list[str]) -> bool;
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
    """Knobs on the red lines, to drag an edge of another view's band
    (970 + the view's number * 2, and one more for the far edge); a drag of
    one; the command it ends in; and the knobs drawn."""
    def depth_knobs -> list[tuple[int, Vec3]];
    def drag_depth(x: int, y: int, free: bool);
    def depth_order -> str;
    def draw_depth_knobs(area: Rect);
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
    """What an entity's game shows it as when it is spawned: a model or a
    sprite, with its skin and frame (none when its game shows nothing)."""
    def entity_look(scene: Scene, item: Item) -> EntityLook | None;
    """A look's model and pictures, read once."""
    def preview_look(look: EntityLook) -> PreviewLook;
    """Entities with their skins on, and sprites, where the level hides them as it hides anything."""
    def draw_entity_skins(scene: Scene);
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
    """Entities of a class their game does not have, and the sounds and
    models their fields name that no archive holds."""
    def need_findings(scene: Scene) -> list[Finding];
    """What the scene uses and what of it is missing; or, of one material
    or file, the brushes and entities that use it."""
    def uses_command(scene: Scene, args: list[str]) -> bool;
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
    def quake_palette -> bytes;
    def model_file_bytes(doc: ModelDoc, path: str) -> bytes;
    def model_file_doc(path: str) -> ModelDoc | None;
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
    # How the explorer's model is played and drawn (impl/studio.playback.impl.jac)

    """Run one of those commands (asked before the model's own, whose words
    they share). False when it is not one."""
    def playview_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # The model being edited in its view (impl/studio.modelview.impl.jac)

    def modelview_words -> str;
    """A mark on a point, drawn the way marks are set to be."""
    def draw_mark(at: Vec3, reach: float, color: Ink);
    """The model's faces, filled or with its skin, when it is not drawn as edges."""
    def draw_model_faces;
    """How long the handles of what is picked are, which of them is under
    the pointer (-1 for none), and they drawn."""
    def handle_reach -> float;
    def handle_under(x: int, y: int) -> int;
    def draw_model_handles;
    """A pointer event for a handle: true when it was."""
    def handle_event(event: UiEvent) -> bool;
    """Put what the view turns about where the way it turns says."""
    def frame_model_about;
    """Run one of those commands (asked before the model's own). False when it is not one."""
    def modelview_command(scene: Scene, args: list[str]) -> bool;
    """The model's floating window: its view's drags and wheel turned into
    its own way of looking, each frame."""
    def turn_model_float;
    def archive_command(scene: Scene, args: list[str]) -> bool;
    def finding_command(scene: Scene, args: list[str]) -> bool;
    def rows_command(scene: Scene, args: list[str]) -> bool;
    def prune_command(scene: Scene, args: list[str]) -> bool;
    def snapto_command(scene: Scene, args: list[str]) -> bool;
    def q3map_command(scene: Scene, args: list[str]) -> bool;
    def overlay_command(scene: Scene, args: list[str]) -> bool;
    def file_material(name: str) -> str;
    def scene_material(name: str) -> str;
    def texture_sizes(names: list[str], as_file: bool) -> dict[str, list[int]];
    def snap_delta(scene: Scene, delta: Vec3) -> Vec3;
    def select_in_loop(scene: Scene, port: int, loop: list[int], add: bool);
    def tags_path -> str;
    def read_tags;
    """The edges of a frame as they are to be drawn: all, or those of the
    triangles that face the eye."""
    def shown_edges(frame: int) -> list[list[Vec3]];
    """Play on by a frame's time, and draw every point as a tick when asked."""
    def play_model(dt: float);
    def draw_model_ticks;
    def playview_words -> str;

    # ------------------------------------------------------------------
    # Faces on whole points and whole angles (impl/studio.integral.impl.jac)

    """Run one of those commands. False when it is not one."""
    def integral_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # What clicks pick, and editing kept to the selection (impl/studio.restrict.impl.jac)

    """Run one of those commands. False when it is not one."""
    def restrict_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Navigation for bots, baked (impl/studio.nav.impl.jac)

    """Run a navigation command. False when it is not one."""
    def nav_command(scene: Scene, args: list[str]) -> bool;
    """Where the log panel lies: along the foot of the level views."""
    def log_area -> Rect;
    def log_said -> list[str];
    def draw_log_panel;
    def log_panel_words -> str;
    def logpanel_command(scene: Scene, args: list[str]) -> bool;
    """The entity a brush let go on a row of the scene list is handed to:
    the row's own when it holds brushes, the holder of the brush on that
    row, or the world for the brushes' heading."""
    def drop_taker(scene: Scene, target: str) -> Item | None;
    def treedrop_command(scene: Scene, args: list[str]) -> bool;
    """Mark an entity, and later hand the selected brushes to it, pick it,
    or change its place with the selection's."""
    def marked_command(scene: Scene, args: list[str]) -> bool;
    """The places to stand in the built scene, sampled on a grid: floor
    under the whole of a cell and room for a head over it."""
    def nav_floors_of(scene: Scene, cell: float) -> list[Floor];
    """Of the ways the floors' heights allow, those nothing stands in."""
    def nav_clear_ways(floors: list[Floor], ways: list[Way], cell: float) -> list[Way];
    """What is baked, as a line of the dump; the ways drawn in a view; and
    what cannot be reached from the first player start."""
    def nav_words -> str;
    """The ways the scene's teleporters and jump pads make: from where each
    trigger is to where it sends or throws."""
    def nav_links(scene: Scene) -> list[Link];
    """The boxes of the scene's liquids: where bots swim."""
    def nav_waters(scene: Scene) -> list[list[Vec3]];
    def draw_nav;
    def nav_findings(scene: Scene) -> list[Finding];
    """What stops a scene being finished: what its logic can never set
    off, then the first objective (a key, what opens the way, the way
    out) that cannot be reached from the start over the baked floors."""
    def playtest(scene: Scene) -> list[Finding];

    # ------------------------------------------------------------------
    # Floating 3D windows (impl/studio.windows.impl.jac)

    """Run a window command. False when it is not one."""
    def window_command(scene: Scene, args: list[str]) -> bool;
    """The views that float: those after the four that are laid out."""
    def float_ports -> list[Port];
    """How many layers are open over the views (menus, lists, the palette):
    the floating windows are not counted."""
    def over_layers(stage: Stage) -> int;
    """Open a floating window looking where the first 3D view looks, and
    close the one with a number."""
    def open_float(wire: bool) -> Port | None;
    def close_float(number: int) -> bool;
    """What the engine draws in the floating windows, and they as lines of the dump."""
    def float_views(built: bool) -> list[SceneView];
    def window_lines -> list[str];

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
    """Clicks and drags on the skin's picture: a click picks the point whose
    place is under it (or, picking faces, the triangle), Shift adds, and a
    drag from a picked point moves the picked points' places."""
    def skin_events;
    """Run a skin command. False when it is not one."""
    def skin_command(scene: Scene, args: list[str]) -> bool;

    # ------------------------------------------------------------------
    # Groups: their rows in the tree and their own switches (impl/studio.groups.impl.jac)

    """Run a group command. False when it is not one."""
    def group_command(scene: Scene, args: list[str]) -> bool;
    """A group's row in the scene tree, and its brushes' when it is open."""
    def list_group(scene: Scene, rows: list[TreeRow], item: Item, picked: bool, depth: int = 1);
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
        if scene is not None and scene.picks != self.nest_picks {
            # Whatever picked a group, what it holds is picked with it
            # before anything is done to the selection.
            scene.pick_nested();
            self.nest_picks = scene.picks;
        }
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
                # Where asked, or on to a corner, edge or face it comes within reach of.
                scene.shift_selection(
                    self.snap_delta(scene, Vec3(x=float(args[1]), y=float(args[2]), z=float(args[3]))), self.tex_lock
                );
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
        } elif name == "ed_layout" and len(args) > 1 and args[1] in ["save", "load", "drop", "list", "keep"] {
            self.layouts_command(scene, args);
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
        } elif not self.plugin_command(scene, args) and not self.weights_command(scene, args)
            and not self.looks_command(scene, args)
            and not self.tabs_command(scene, args)
            and not self.help_command(scene, args)
            and not self.layouts_command(scene, args)
            and not self.uses_command(scene, args)
            and not self.marked_command(scene, args)
            and not self.treedrop_command(scene, args)
            and not self.logpanel_command(scene, args)
            and not self.overlay_command(scene, args)
            and not self.q3map_command(scene, args)
            and not self.snapto_command(scene, args)
            and not self.prune_command(scene, args)
            and not self.rows_command(scene, args)
            and not self.finding_command(scene, args)
            and not self.archive_command(scene, args)
            and not self.modelview_command(scene, args)
            and not self.patch_box_command(scene, args)
            and not self.shader_box_command(scene, args)
            and not self.docset_command(scene, args)
            and not self.playview_command(scene, args)
            and not self.links_command(scene, args)
            and not self.prefab_change(scene, args)
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
            and not self.district_command(scene, args) and not self.window_command(scene, args)
            and not self.nav_command(scene, args) and not self.restrict_command(scene, args)
            and not self.integral_command(scene, args)
            and not self.games_command(scene, args)
            and not self.script_command(scene, args) and not self.texlink_command(scene, args)
            and not self.toolpanel_command(args)
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
                + ("axis" if self.tex_axis else ("1" if self.tex_lock else "0")) + " pivot="
                + (
                    str(int(self.pivot_at.x)) + "," + str(int(self.pivot_at.y)) + "," + str(int(self.pivot_at.z))
                    if self.pivot_set
                    else "none"
                )
                + (" axes=" + self.gizmo_axes if self.gizmo_axes != "world" else "")
                + (" lock=" + "xyz"[self.axis_lock] if self.axis_lock >= 0 else "")
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
        if self.vis_cell == BAKE_BY_PLANES {
            done = self.vis_done;
            lines.append(
                "studio: bake planes leaves=" + str(done.leaves) + " cells=" + str(done.cells) + " portals="
                    + str(done.portals) + " areas=" + str(done.areas) + " buried=" + str(done.buried) + " hidden="
                    + str(done.hidden) + " capped=" + ("1" if done.capped else "0") + " leaked=" + ("1" if done.leaked else "0")
            );
        } elif self.vis_cell > 0.0 {
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
                "studio: build from=" + ("patch" if self.built_patched else ("copy" if self.built_reused else "new")) + " copies=" + str(len(self.built_copies))
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
        if seen_model is not None and (
            self.model_rate != 10.0 or self.model_last >= 0 or self.model_smooth or not self.model_backs
            or self.model_ticks > 0.0 or not self.model_loops
        ) {
            lines.append(self.playview_words());
        }
        if self.model_marks != "cross" or self.model_shade != "wire" or self.model_about != "model" or self.model_lock
            or self.points_tinted or self.skin_pattern != "solid" or _model_split.four or self.model_float_box is not None {
            lines.append(self.modelview_words());
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
            lines.append(
                "studio: models shown=1 drawn=" + str(self.models_drawn) + " skinned=" + str(self.skins_drawn)
                    + ("" if self.models_skinned else " skins=off")
            );
        }
        for window_line in self.window_lines() {
            lines.append(window_line);
        }
        if self.nav_mesh is not None {
            lines.append(self.nav_words());
        }
        for tool in self.tools {
            for tool_line in tool.dump_lines(self.host(), scene) {
                lines.append(tool_line);
            }
        }
        if self.log_panel {
            lines.append(self.log_panel_words());
        }
        if self.split_x != 50 or self.split_y != 50 or self.sides_swapped or len(self.kept_layouts) > 0 {
            lines.append(
                "studio: split x=" + str(self.split_x) + " y=" + str(self.split_y) + " sides=" + ("swapped" if self.sides_swapped else "usual")
                    + " kept=" + ",".join(sorted(self.kept_layouts.keys()))
            );
        }
        if self.dock_tabs != "left" or self.dock_inspector != "right" {
            lines.append("studio: dock tabs=" + self.dock_tabs + " inspector=" + self.dock_inspector);
        }
        if self.theme_name != "dark" or not self.tools_shown or not self.status_shown or self.tools_below
            or self.shape_box is not None {
            lines.append(
                "studio: looks theme=" + self.theme_name + " tools=" + ("below" if self.tools_below else "above")
                    + ("" if self.tools_shown else ",hidden") + " status=" + ("shown" if self.status_shown else "hidden")
                    + " shapebox=" + (self.shape_kind if self.shape_box is not None else "shut")
            );
        }
        if self.tabs_on {
            lines.append("studio: tabs " + str(self.tabs_count()) + " " + self.tabs_words().replace(" ", "_"));
        }
        if self.rect_brush {
            lines.append("studio: rectbrush falloff=" + (self.rect_fall if self.rect_fall else "0"));
        }
        if self.marked_item >= 0 {
            lines.append("studio: marked #" + str(self.marked_item));
        }
        if self.pick_kind != "all" or len(self.kept_out_items) + len(self.kept_out_solids) > 0 {
            lines.append(
                "studio: picks=" + self.pick_kind + " put_away="
                    + str(len(self.kept_out_items) + len(self.kept_out_solids))
            );
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
        if self.script_box is not None {
            lines.append(self.script_words());
        }
        if self.settings_box is not None {
            lines.append("studio: settings box subject=" + self.settings_subject);
        }
        if len(self.all_links()) > 0 or len(self.all_lists()) > 0 {
            both_lists = self.all_lists();
            lines.append(
                "studio: materials links=" + ",".join(sorted(self.all_links().keys())) + " lists="
                    + ",".join([each + ":" + str(len(both_lists[each])) for each in sorted(both_lists.keys())])
            );
        }
        if self.library_filter or self.library_previewed {
            lines.append(
                "studio: library find=" + (self.library_filter if self.library_filter else "-") + " preview="
                    + (self.library_previewed if self.library_previewed else "-")
            );
        }
        if len(self.user_inks) > 0 {
            lines.append("studio: colours " + " ".join([each + " " + self.user_inks[each] for each in sorted(self.user_inks.keys())]));
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
        if self.snap_to != "grid" {
            lines.append("studio: snapto " + self.snap_to + " reach=" + str(int(round(self.snap_reach))));
        }
        if self.patch_preview {
            lines.append(self.patch_preview_words(scene));
        }
        if len(self.models_parked) > 0 or len(self.shaders_parked) > 0 or len(self.textures_open) > 0 {
            lines.append(self.docset_words());
        }
        if self.overdraw {
            lines.append("studio: overdraw faces=" + str(self.overdraw_faces));
        }
        if self.show_triggers or self.show_unseen or self.line_width != 1 {
            lines.append(
                "studio: overlays triggers=" + ("1" if self.show_triggers else "0") + " unseen=" + ("1" if self.show_unseen else "0")
                    + " width=" + str(self.line_width)
            );
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

"""How the studio's lines are drawn in the view being drawn now: how wide,
and what the view sees as across and up, where it looks from and how much
of the world a pixel of it covers."""
obj WirePen {
    has shifts: list[float] = [],
        eye: Vec3 = Vec3(),
        ahead: Vec3 = Vec3(x=1.0),
        right: Vec3 = Vec3(y=-1.0),
        up: Vec3 = Vec3(z=1.0),
        tall: int = 1,
        span: float = 0.0,
        fov: float = 73.74;

    def hold(view: SceneView, fov: float, width: int) {
        self.shifts = thick_shifts(width);
        self.eye = view.eye;
        self.ahead = forward_from(view.yaw, view.pitch);
        self.right = right_from(view.yaw);
        self.up = self.right.cross(self.ahead);
        self.tall = view.height;
        self.span = view.span;
        self.fov = fov;
    }
}

glob _pen: WirePen = WirePen();

"""A box's twelve edges, in the level."""
def wire_box(low: Vec3, high: Vec3, color: Ink) {
    if len(_pen.shifts) > 0 {
        # Each edge a line, so that each is as wide as lines are.
        xs = [low.x, high.x];
        ys = [low.y, high.y];
        zs = [low.z, high.z];
        for a in range(2) {
            for b in range(2) {
                wire_line(Vec3(x=low.x, y=ys[a], z=zs[b]), Vec3(x=high.x, y=ys[a], z=zs[b]), color);
                wire_line(Vec3(x=xs[a], y=low.y, z=zs[b]), Vec3(x=xs[a], y=high.y, z=zs[b]), color);
                wire_line(Vec3(x=xs[a], y=ys[b], z=low.z), Vec3(x=xs[a], y=ys[b], z=high.z), color);
            }
        }
        return;
    }
    DrawCubeWires(
        Vector3(x=f32((low.x + high.x) * 0.5), y=f32((low.y + high.y) * 0.5), z=f32((low.z + high.z) * 0.5)),
        f32(high.x - low.x),
        f32(high.y - low.y),
        f32(high.z - low.z),
        wire_color(color)
    );
}

"""A line in the level, as wide as the studio's lines are set to be: drawn
again to either side of itself, as the view sees it."""
def wire_line(start: Vec3, finish: Vec3, color: Ink) {
    tone = wire_color(color);
    DrawLine3D(
        Vector3(x=f32(start.x), y=f32(start.y), z=f32(start.z)),
        Vector3(x=f32(finish.x), y=f32(finish.y), z=f32(finish.z)),
        tone
    );
    if len(_pen.shifts) == 0 {
        return;
    }
    over = line_across(start, finish, _pen.right, _pen.up);
    here_reach = pixel_reach(start.sub(_pen.eye).dot(_pen.ahead), _pen.tall, _pen.span, _pen.fov);
    there_reach = pixel_reach(finish.sub(_pen.eye).dot(_pen.ahead), _pen.tall, _pen.span, _pen.fov);
    for shift in _pen.shifts {
        first = start.add(over.scale(shift * here_reach));
        second = finish.add(over.scale(shift * there_reach));
        DrawLine3D(
            Vector3(x=f32(first.x), y=f32(first.y), z=f32(first.z)),
            Vector3(x=f32(second.x), y=f32(second.y), z=f32(second.z)),
            tone
        );
    }
}

"""Light being baked while the studio goes on: the job, what it is the
light of (the build's mark), and what the kept bake must measure."""
obj LightTask {
    has job: LightJob | None = None,
        # The scene and the copy being baked, how wide its cells are (none
        # when it is not cut), and the cells' job once the light is done.
        scene: Scene | None = None,
        made: LiveLevel | None = None,
        cell: float = 0.0,
        cells: CellJob | None = None,
        mark: str = "",
        plane_base: int = 0,
        warned: int = 0,
        began: float = 0.0,
        # The light's samples once it is written (below zero until then).
        samples: int = -1;

    """How far the bake has got: the light, then the cells."""
    def share -> float {
        light = self.job;
        lit = light.share() if light is not None else 1.0;
        if self.cell <= 0.0 {
            return lit;
        }
        cut = self.cells;
        cells_share = cut.share() if cut is not None else 0.0;
        return (lit + cells_share) * 0.5 if light is not None else cells_share;
    }
}

"""A model being edited that is not in hand: the model, its skin's picture
and the bone that was in hand."""
obj ModelSlot {
    has doc: ModelDoc,
        skin: Skin | None = None,
        bone_now: str = "";
}

"""A shader script open but not in hand: its file, its shaders, which was in
hand, its faults as read, and whether it has been changed."""
obj ShaderSlot {
    has file: str,
        shaders: list[ShaderText] = [],
        now: int = -1,
        broken: list[ShaderFault] = [],
        dirty: bool = False;
}

"""How the explorer's model view is laid out: one view, or four."""
obj ModelSplit {
    has four: bool = False;
}

glob _model_split: ModelSplit = ModelSplit();

"""When the studio began, for a shader's preview to move by."""
obj ShaderClock {
    has began: float = 0.0;
}

glob _shader_clock: ShaderClock = ShaderClock(began=time.time());

"""Where the explorer's model view is ([0, 0, 0, 0] when it is not laid
out): the turning view's place, the first quarter when there are four."""
def ui_model_area(ui: StudioUi | None) -> Rect {
    if ui is None or ui.model_view.parent() is None {
        return Rect();
    }
    whole = ui.model_view.area;
    if _model_split.four {
        # The turning view is the first of four.
        return Rect(x=whole.x, y=whole.y, w=whole.w // 2 - 1, h=whole.h // 2 - 1);
    }
    return whole;
}

"""The other three of the model's four views: from above, the front and the
side, each its quarter of the model's view (none when there is one view)."""
def model_quarters(ui: StudioUi | None) -> list[tuple[str, Rect]] {
    if not _model_split.four or ui is None or ui.model_view.parent() is None {
        return [];
    }
    whole = ui.model_view.area;
    half_w = whole.w // 2;
    half_h = whole.h // 2;
    return [
        ("top", Rect(x=whole.x + half_w + 1, y=whole.y, w=whole.w - half_w - 1, h=half_h - 1)),
        ("front", Rect(x=whole.x, y=whole.y + half_h + 1, w=half_w - 1, h=whole.h - half_h - 1)),
        ("side", Rect(x=whole.x + half_w + 1, y=whole.y + half_h + 1, w=whole.w - half_w - 1, h=whole.h - half_h - 1))
    ];
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
