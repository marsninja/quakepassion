import from editor.assets.needs { sound_file, model_file, needed_files, missing_files, held_names }

test "a sound field names a file by its game's rules" {
    assert sound_file("q1", "ambience/fire1.wav") == "sound/ambience/fire1.wav";
    assert sound_file("q2", "world/amb10.wav") == "sound/world/amb10.wav";
    assert sound_file("q2", "sound/world/amb10.wav") == "sound/world/amb10.wav";
    assert sound_file("q3", "sound/world/fire1.wav") == "sound/world/fire1.wav";
    assert sound_file("q3", "music/fla22k_03") == "music/fla22k_03.wav";
    # A player's own sound, and nothing at all, name no file.
    assert sound_file("q3", "*falling1.wav") == "" and sound_file("q1", "  ") == "";
    assert sound_file("q1", "doors\\drclos4.wav") == "sound/doors/drclos4.wav";
}

test "a model field names a file unless it is one of the level's own" {
    assert model_file("models/mapobjects/lamps/bot_lamp.md3") == "models/mapobjects/lamps/bot_lamp.md3";
    assert model_file("progs/flame.mdl") == "progs/flame.mdl";
    assert model_file("*12") == "" and model_file("") == "" and model_file("torch") == "";
}

test "an entity's fields say which files it needs, and which a game does not hold" {
    speaker = {"classname": "target_speaker", "noise": "sound/world/fire1.wav", "origin": "0 0 0"};
    assert needed_files("q3", speaker) == [("noise", "sound/world/fire1.wav")];
    world = {"classname": "worldspawn", "music": "music/intro.wav music/loop.wav", "message": "A place"};
    assert needed_files("q3", world) == [("music", "music/intro.wav"), ("music", "music/loop.wav")];
    # Quake's worldspawn has no music file; a door's model is the level's own.
    assert needed_files("q1", world) == [] and needed_files("q1", {"classname": "func_door", "model": "*4"}) == [];
    lamp = {"classname": "misc_model", "model": "models/lamp.md3", "model2": "models/glow.md3", "noise": "hum"};
    needs = needed_files("q3", lamp);
    assert needs == [("model", "models/lamp.md3"), ("model2", "models/glow.md3"), ("noise", "hum.wav")];
    held = held_names(["models/LAMP.md3", "hum.wav", "maps/q3dm1.bsp"]);
    assert missing_files(needs, held) == [("model2", "models/glow.md3")];
    assert missing_files(needs, held_names([])) == needs and missing_files([], held) == [];
}
