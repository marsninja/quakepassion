import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.brush { box_sides }

"""A floor and a start: a level with nothing to go wrong in it."""
def yard(game: str = "q1") -> Scene {
    scene = Scene(game=game, name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_item({"classname": "info_player_start", "origin": "0 0 24"});
    return scene;
}

"""What the scene's softlocks say. Entities added as a loader adds them do
not count as edits, so what fires what is worked out afresh."""
def said(scene: Scene) -> list[str] {
    scene.relink();
    return [finding.words for finding in scene.softlocks()];
}

test "what is fired only by things that are never set off is never set off" {
    scene = yard();
    # A button opens a door through a relay: every link is set off in its turn.
    scene.add_item({"classname": "func_button", "origin": "64 0 32", "target": "pass"});
    scene.add_item({"classname": "trigger_relay", "origin": "64 0 64", "targetname": "pass", "target": "door1"});
    door = scene.add_item({"classname": "func_door", "origin": "96 0 32", "targetname": "door1", "target": "bell"});
    scene.add_item({"classname": "target_speaker", "origin": "96 0 64", "targetname": "bell"});
    assert said(scene) == [];
    # The world and the start set nothing off but are not waiting either; with them, six.
    assert scene.waits(door) and len(scene.woken()) == 6;
    # A second door hangs off a relay nothing fires: the relay is the audit's to name, the door a softlock.
    scene.add_item({"classname": "trigger_relay", "origin": "0 64 64", "targetname": "lost", "target": "vault"});
    vault = scene.add_item({"classname": "func_door", "origin": "0 96 32", "targetname": "vault", "target": "cheer"});
    scene.add_item({"classname": "target_speaker", "origin": "0 96 64", "targetname": "cheer"});
    scene.relink();
    found = scene.softlocks();
    assert [finding.words for finding in found] == [
        "func_door (vault) is never set off: what fires it (trigger_relay (lost)) is never set off itself",
        "target_speaker (cheer) is never set off: what fires it (func_door (vault)) is never set off itself"
    ];
    assert found[0].item is vault and not found[0].grave;
    assert [finding.words for finding in scene.audit()] == ["trigger_relay (lost) waits for lost, which nothing fires"];
    # A trigger walked into fires the relay: nothing is stuck. Killing a thing does not set it off.
    walked = scene.add_item({"classname": "trigger_once", "origin": "0 32 32", "killtarget": "lost"});
    assert len(said(scene)) == 2;
    scene.select(walked);
    assert scene.set_fields({"killtarget": None, "target": "lost"});
    assert said(scene) == [];
    # A named trigger is still walked into, and a named button still pressed; a timer that starts
    # on runs, and one that does not waits.
    assert not scene.waits(scene.add_item({"classname": "trigger_multiple", "targetname": "t9", "origin": "0 0 0"}));
    assert not scene.waits(scene.add_item({"classname": "func_button", "targetname": "t9", "origin": "0 0 0"}));
    assert not scene.waits(scene.add_item({"classname": "func_timer", "targetname": "t9", "spawnflags": "1", "origin": "0 0 0"}));
    assert scene.waits(scene.add_item({"classname": "func_timer", "targetname": "t9", "origin": "0 0 0"}));
    assert not scene.waits(scene.add_item({"classname": "func_door", "origin": "0 0 0"}));
}

test "a counter that more must fire than ever can is a softlock" {
    scene = yard();
    scene.add_item({"classname": "trigger_counter", "origin": "0 0 64", "targetname": "tally", "count": "3", "target": "gate"});
    scene.add_item({"classname": "func_door", "origin": "96 0 32", "targetname": "gate"});
    scene.add_item({"classname": "monster_ogre", "origin": "0 64 24", "target": "tally"});
    scene.add_item({"classname": "monster_knight", "origin": "0 96 24", "target": "tally"});
    assert said(scene) == ["trigger_counter (tally) counts to 3, and only 2 things ever fire it, once each"];
    # A third death makes it up.
    third = scene.add_item({"classname": "monster_dog", "origin": "0 32 24", "target": "tally"});
    assert said(scene) == [];
    # With nothing said it counts to two; a trigger that can be walked into again makes up any count.
    scene.select(third);
    assert scene.remove_selection();
    counter = [item for item in scene.items() if item.classname() == "trigger_counter"][0];
    scene.select(counter);
    assert scene.set_fields({"count": "7"}) and len(said(scene)) == 1 and "counts to 7" in said(scene)[0];
    scene.add_item({"classname": "trigger_multiple", "origin": "32 0 24", "target": "tally"});
    assert said(scene) == [];
    again = [item for item in scene.items() if item.classname() == "trigger_multiple"][0];
    scene.select(again);
    assert scene.set_fields({"wait": "-1"}) and len(said(scene)) == 1 and "only 3 things" in said(scene)[0];
}

test "a door that wants a key the level does not have is a softlock" {
    scene = yard();
    scene.add_item({"classname": "func_door", "origin": "96 0 32", "spawnflags": "8"});
    scene.add_item({"classname": "func_door", "origin": "96 64 32", "spawnflags": "17"});
    assert said(scene) == [
        "func_door wants the gold key, and the level has none (item_key2)",
        "func_door wants the silver key, and the level has none (item_key1)"
    ];
    scene.add_item({"classname": "item_key2", "origin": "0 64 24"});
    assert said(scene) == ["func_door wants the silver key, and the level has none (item_key1)"];
    scene.add_item({"classname": "item_key1", "origin": "0 96 24"});
    assert said(scene) == [];
    # The flags mean other things in the other games; Quake II asks for a key by name.
    second = yard("q2");
    second.add_item({"classname": "func_door", "origin": "96 0 32", "spawnflags": "8"});
    assert said(second) == [];
    second.add_item({"classname": "trigger_key", "origin": "64 0 32", "item": "key_data_cd", "target": "lift"});
    assert said(second) == ["trigger_key wants key_data_cd, and this level has none (unless it is carried in from another)"];
    second.add_item({"classname": "key_data_cd", "origin": "0 64 24"});
    assert said(second) == [];
}
