import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.brush { box_sides }
import from editor.ui.canvas { TraceCanvas }
import from editor.ui.input { UiSource, script_click, script_drag }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets { Box, TreeView, TreeRow, ViewArea }
import from editor.ui.order { moved_before }

"""Run frames until the scripted steps are played, plus one to settle."""
def play(stage: Stage, source: UiSource) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
    }
    stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
}

test "a row carried onto another row of its list asks for the drop, with both" {
    top = Box(across=True);
    rows = TreeView(pick="choose", drag="tree", drop="put", size=200);
    rows.rows = [
        TreeRow(key="heading", text="Heading", branch=True), TreeRow(key="door", text="A door", depth=1),
        TreeRow(key="solid:3", text="A brush", depth=1), TreeRow(key="bin", text="A bin", depth=1, fixed=True)
    ];
    plain = TreeView(pick="other", drag="thing", size=200);
    plain.rows = [TreeRow(key="one", text="One"), TreeRow(key="two", text="Two")];
    view = ViewArea(grow=1);
    top.adopt(rows);
    top.adopt(plain);
    top.adopt(view);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    source = UiSource();
    play(stage, source);
    # The brush's row (the third, twenty high each) carried up onto the door's.
    script_drag(source, 60, 50, 60, 30);
    play(stage, source);
    assert stage.take_commands() == ["choose \"solid:3\"", "put \"door\" \"tree solid:3\""];
    # Onto the heading; and let go under the last row, on none.
    script_drag(source, 60, 50, 60, 10);
    play(stage, source);
    assert stage.take_commands()[-1] == "put \"heading\" \"tree solid:3\"";
    script_drag(source, 60, 50, 60, 300);
    play(stage, source);
    assert stage.take_commands()[-1] == "put \"\" \"tree solid:3\"";
    # A click carries nothing; and neither does a row that stays where it is.
    script_click(source, 60, 50);
    play(stage, source);
    assert stage.take_commands() == ["choose \"solid:3\""];
    script_drag(source, 60, 70, 60, 30);
    play(stage, source);
    assert stage.take_commands() == ["choose \"bin\""];
    # From another list: let go on a row here it is asked for as what it is.
    script_drag(source, 260, 10, 60, 30);
    play(stage, source);
    assert stage.take_commands() == ["other \"one\"", "put \"door\" \"thing one\""];
    # A list that takes no drops says nothing of one, from itself or from elsewhere.
    script_drag(source, 260, 10, 260, 30);
    play(stage, source);
    assert stage.take_commands() == ["other \"one\""];
    script_drag(source, 60, 50, 260, 30);
    play(stage, source);
    assert stage.take_commands() == ["choose \"solid:3\""];
    # Into a view it is dropped as before.
    script_drag(source, 60, 50, 600, 300);
    play(stage, source);
    drops = [event for event in view.take() if event.kind == "drop"];
    assert len(drops) == 1 and drops[0].text == "tree solid:3";
}

test "selected brushes are handed to an entity that is already there, as one step" {
    scene = Scene(game="q1", name="studio:test");
    world = scene.world();
    first = scene.add_solid(world, box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    second = scene.add_solid(world, box_sides(Vec3(x=128.0), Vec3(x=192.0, y=64.0, z=64.0), "wall"));
    door = scene.add_item({"classname": "func_door"});
    third = scene.add_solid(door, box_sides(Vec3(y=128.0), Vec3(x=64.0, y=192.0, z=64.0), "wood"));
    scene.relink();
    scene.select_solid(first);
    scene.select_solid(second, add=True);
    assert scene.hand_selection(door) == 2;
    assert scene.owner_of(first) is door and scene.owner_of(second) is door and len(scene.solids_of(door)) == 3;
    assert len(scene.solids_of(world)) == 0;
    # What it holds already is not handed again; and with nothing to hand there is no step.
    scene.select_solid(third, add=True);
    assert scene.hand_selection(door) == 0;
    # Back to the world, the door's own with them; then undone, a step at a time.
    assert scene.hand_selection(world) == 3 and len(scene.solids_of(door)) == 0;
    assert scene.undo() == "Hand to worldspawn" and len(scene.solids_of(door)) == 3;
    assert scene.undo() == "Hand to func_door" and scene.owner_of(first) is world and scene.owner_of(third) is door;
    assert scene.redo() == "Hand to func_door" and scene.owner_of(second) is door;
}

test "a name is moved to stand before another, or to the end" {
    names = ["light", "item_health", "monster_ogre"];
    assert moved_before(names, "monster_ogre", "light") == ["monster_ogre", "light", "item_health"];
    assert moved_before(names, "light", "monster_ogre") == ["item_health", "light", "monster_ogre"];
    assert moved_before(names, "light") == ["item_health", "monster_ogre", "light"];
    assert moved_before(names, "light", "nothing") == ["item_health", "monster_ogre", "light"];
    assert moved_before(names, "light", "light") == names and names == ["light", "item_health", "monster_ogre"];
    assert moved_before(names, "func_door", "item_health") == ["light", "func_door", "item_health", "monster_ogre"];
    assert moved_before([], "light") == ["light"];
}
