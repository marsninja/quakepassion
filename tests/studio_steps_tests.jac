import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, scene_map }
import from editor.geometry.brush { box_sides }
import from editor.formats.map { write_map }
import from editor.compile.steps {
    recipe_steps,
    step_line,
    number_after,
    place_of_line,
    places_named,
    text_mark
}

"""A floor and a door of two brushes, with a player start between them."""
def room -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 -64 24"});
    door = scene.add_item({"classname": "func_door", "angle": "-1"});
    scene.add_solid(door, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=16.0, y=64.0, z=96.0), "wall"));
    scene.add_solid(door, box_sides(Vec3(x=16.0, y=0.0, z=0.0), Vec3(x=32.0, y=64.0, z=96.0), "wall"));
    return scene;
}

test "a recipe is its commands apart at semicolons, and a step's line takes the map" {
    assert recipe_steps("ed_build full; ed_bake 128 ;; ed_play") == ["ed_build full", "ed_bake 128", "ed_play"];
    assert recipe_steps("  ") == [];
    line = step_line("qbsp -leak %map% %dir%/%name%.bsp", "/tmp/maps/hall.build.map");
    assert line == "qbsp -leak /tmp/maps/hall.build.map /tmp/maps/hall.build.bsp";
    assert step_line("echo %name%", "hall.map") == "echo hall";
    assert step_line("qbsp %map%", "/tmp/my maps/hall.map") == "qbsp \"/tmp/my maps/hall.map\"";
}

test "a compiler's words are read for the entities and brushes they name" {
    assert number_after("entity 4, brush 12: duplicate plane", "entity") == 4;
    assert number_after("entity 4, brush 12: duplicate plane", "brush") == 12;
    assert number_after("brush #7 of entity (3)", "entity") == 3;
    assert number_after("no number after entity here", "entity") == -1;
    # The first mention has no number; the second does.
    assert number_after("entity leak: entity 9 reached", "entity") == 9;
    said = "--- qbsp ---\nEntity 2, Brush 1: mirrored plane\nWARNING: Entity 1 (info_player_start) is in solid\n\n3 brushes\n";
    places = places_named(said);
    assert len(places) == 2;
    assert places[0].entity == 2 and places[0].brush == 1 and places[0].words == "Entity 2, Brush 1: mirrored plane";
    assert places[1].entity == 1 and places[1].brush == -1;
}

test "a line of the map's text is the entity and brush it lies in" {
    scene = room();
    text = write_map(scene_map(scene), "valve", False, True, False);
    lines = text.split("\n");
    # The second brush of the door: find its comment and a line under it.
    marked = -1;
    for (index, line) in enumerate(lines) {
        if line.startswith("// brush 1") {
            marked = index;
        }
    }
    assert marked > 0;
    spot = place_of_line(text, marked + 3);
    assert spot is not None and spot.entity == 2 and spot.brush == 1;
    first = place_of_line(text, 3);
    assert first is not None and first.entity == 0;
    assert place_of_line(text, len(lines) + 40) is None;
    places = places_named("hall.map:" + str(marked + 3) + ": brush has too few planes\nline 3: odd\nline 0: nothing", text);
    assert len(places) == 2 and places[0].entity == 2 and places[0].brush == 1 and places[1].entity == 0;
    # Without the map's text a line number says nothing.
    assert len(places_named("line 3: odd")) == 0;
    assert scene.select_numbered(places[0].entity, places[0].brush) and len(scene.selected_solids()) == 1;
}

test "a text's mark is the same for the same text and no other" {
    scene = room();
    text = write_map(scene_map(scene));
    assert text_mark(text) == text_mark(write_map(scene_map(scene)));
    scene.select_solid(scene.solids()[0]);
    assert scene.shift_selection(Vec3(x=16.0));
    moved = write_map(scene_map(scene));
    assert text_mark(moved) != text_mark(text);
    assert scene.undo() == "Move" and text_mark(write_map(scene_map(scene))) == text_mark(text);
    assert text_mark("") == "7-11-0" and text_mark("ab") != text_mark("ba");
}
