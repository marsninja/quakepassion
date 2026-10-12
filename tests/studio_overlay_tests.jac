import from editor.document.overlays { brush_kind, kind_tint }

test "a brush is known for what it is for by its entity and its materials" {
    # A volume of a trigger entity, whatever it is textured with.
    assert brush_kind("trigger_once", ["q1:e1m1/tech04_1"]) == "trigger" and brush_kind("trigger_multiple", []) == "trigger";
    # The games' own names for what is not seen.
    assert brush_kind("worldspawn", ["q3:textures/common/clip", "q3:textures/common/clip"]) == "clip";
    assert brush_kind("worldspawn", ["q2:e1u1/clip"]) == "clip" and brush_kind("func_group", ["clip_monster"]) == "clip";
    assert brush_kind("worldspawn", ["q3:textures/common/hint"]) == "hint" and brush_kind("worldspawn", ["q3:textures/common/caulk"]) == "hint";
    assert brush_kind("worldspawn", ["q1:e1m1/trigger"]) == "trigger" and brush_kind("worldspawn", ["common/playerclip"]) == "clip";
    # A brush with any side that is seen is a brush like any other; so is a door, and a word inside a name.
    assert brush_kind("worldspawn", ["q3:textures/common/caulk", "q3:textures/base_wall/concrete"]) == "";
    assert brush_kind("func_door", ["q1:e1m1/door02_1"]) == "" and brush_kind("worldspawn", ["q1:e1m1/eclipse"]) == "";
    assert brush_kind("worldspawn", []) == "" and brush_kind("worldspawn", ["blockout"]) == "";
    # Each kind has a colour of its own; the rest have none.
    tints = [kind_tint("trigger"), kind_tint("clip"), kind_tint("hint")];
    assert len(set(tints)) == 3 and min(tints) > 0 and kind_tint("") == -1 and kind_tint("wall") == -1;
}
