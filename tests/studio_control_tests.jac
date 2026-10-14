import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { box_sides }
import from editor.document.scene { Scene }
import from editor.tools.control {
    Desk,
    Request,
    Filed,
    FindRequest,
    Survey,
    json_text,
    json_number,
    numbers_from,
    request_name,
    request_script,
    eased,
    turn_between,
    look_angles
}

test "words and numbers are written as JSON" {
    assert json_text("plain") == "\"plain\"";
    assert json_text("say \"hi\"\\ok\n\ttab") == "\"say \\\"hi\\\"\\\\ok\\n\\ttab\"";
    assert json_text("\u0001") == "\"\\u0001\"";
    assert json_number(64.0) == "64" and json_number(-16.0) == "-16" and json_number(0.125) == "0.125";
    # A corner a turn left a hair off a whole number is written whole.
    assert json_number(-991.99999999) == "-992";
}

test "a request's file is named by its number alone" {
    assert request_name("0001762-42.cmd") == "0001762-42";
    assert request_name(".0001.part") == "" and request_name("a b.cmd") == "" and request_name("x.json") == "";
}

test "a request runs between a step that begins it and one that answers it, each line echoed" {
    script = request_script("7", ["ed_box_at 0 0 0 64 64 64", "", "// a remark", "wait", "ed_query made"]);
    assert script.split("\n") == [
        "ed_control begin 7",
        "ed_control line 7 0",
        "ed_box_at 0 0 0 64 64 64",
        "wait",
        "ed_control line 7 4",
        "ed_query made",
        "ed_control end 7"
    ];
}

test "numbers are read from the words, or not at all" {
    found = numbers_from(["ed_fly", "1", "-2.5", "3"], 1, 3);
    assert found is not None and found == [1.0, -2.5, 3.0];
    assert numbers_from(["ed_fly", "1", "x", "3"], 1, 3) is None and numbers_from(["ed_fly", "1"], 1, 3) is None;
}

test "a flight eases in and out and turns the short way round" {
    assert eased(0.0) == 0.0 and eased(1.0) == 1.0 and eased(0.5) == 0.5 and eased(2.0) == 1.0;
    assert turn_between(350.0, 10.0) == 20.0 and turn_between(10.0, 350.0) == -20.0 and turn_between(0.0, 90.0) == 90.0;
    angles = look_angles(Vec3(), Vec3(x=0.0, y=100.0, z=-100.0));
    assert abs(angles[0] - 90.0) < 0.001 and abs(angles[1] + 45.0) < 0.001;
}

test "the desk finds a request by its number" {
    desk = Desk();
    desk +>:Filed:+> Request(seq="1");
    desk +>:Filed:+> Request(seq="2", lines=["ed_note two"]);
    finder = FindRequest(seq="2");
    desk spawn finder;
    assert finder.found is not None and finder.found.lines == ["ed_note two"];
    missing = FindRequest(seq="3");
    desk spawn missing;
    assert missing.found is None;
}

test "a survey writes a scene's entities and brushes, or those of some numbers" {
    scene = Scene(game="passion", name="studio:survey");
    scene.add_solid(scene.world(), box_sides(Vec3(z=-16.0), Vec3(x=64.0, y=32.0), "floor"));
    door = scene.create("func_door", None);
    made = scene.create_solid(box_sides(Vec3(x=128.0), Vec3(x=144.0, y=64.0, z=128.0), "q1:e1m7/*lava1"), door);
    assert made is not None;
    everything = Survey();
    scene spawn everything;
    assert len(everything.entities) == 2 and len(everything.brushes) == 2;
    assert "\"classname\":\"func_door\"" in everything.entities[1];
    assert "\"low\":[128,0,0],\"high\":[144,64,128]" in everything.brushes[1];
    assert "\"owner\":" + str(door.serial) in everything.brushes[1] and "q1:e1m7/*lava1" in everything.brushes[1];
    # By material, and by number.
    lava = Survey(entities_wanted=False, material="lava");
    scene spawn lava;
    assert len(lava.entities) == 0 and len(lava.brushes) == 1;
    picked = Survey(serials=[made.serial]);
    scene spawn picked;
    assert len(picked.entities) == 0 and len(picked.brushes) == 1;
}
