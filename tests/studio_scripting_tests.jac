import from editor.document.scripting {
    ASK_KINDS, json_word, scene_json, launcher_text, asked_words, read_asked, script_walkers, script_classes, said_faults,
    starter_script, library_text
}

test "the library kept in the studio is the library in the repository" {
    source = "";
    with open("editor/userland/qp.jac", "r") as file {
        source = file.read();
    }
    # scripts/embed_script_library.jac writes one from the other.
    assert library_text() == source;
    assert "node Thing" in source and "edge Fires" in source and "def write_asked" in source;
}

test "a level is written for a script as JSON, whatever its fields hold" {
    assert json_word("a \"door\"\nback\\slash") == "\"a \\\"door\\\"\\nback\\\\slash\"";
    said = scene_json(
        "yard", "passion", "run", ["one", "two words"], 3,
        [(1, {"classname": "worldspawn", "message": "The \"yard\""}), (3, {"target": "gate", "classname": "func_button"})]
    );
    assert said.startswith("{\"name\": \"yard\", \"game\": \"passion\", \"event\": \"run\", \"words\": [\"one\", \"two words\"], \"on\": 3,");
    assert "{\"number\": 1, \"fields\": {\"classname\": \"worldspawn\", \"message\": \"The \\\"yard\\\"\"}}" in said;
    assert "{\"number\": 3, \"fields\": {\"classname\": \"func_button\", \"target\": \"gate\"}}" in said and said.endswith("]}\n");
}

test "the lines that start a walker import it and set it down" {
    said = launcher_text("doors", "StayOpen", "in.json", "out.txt");
    assert "import from doors { StayOpen }" in said and "thing spawn StayOpen();" in said and "level spawn StayOpen();" in said;
    assert "read_level(\"in.json\")" in said and "write_asked(\"out.txt\")" in said;
}

test "what a script asked is read back, and nothing of a kind the studio does not know" {
    assert asked_words("set 3 \"wait\" \"-1\"") == ["set", "3", "wait", "-1"];
    assert asked_words("say \"two words, a \\\"quote\\\" and a\\nline\"") == ["say", "two words, a \"quote\" and a\nline"];
    asked = read_asked(
        "set 3 \"wait\" \"-1\"\nsay \"hello there\"\nfire \"gate\"\npick 4\nadd \"light\" \"0 0 64\" \"light\" \"300\"\n"
            + "quit\ndelete 3\nset 3 \"wait\"\n\nexec \"rm\"\n"
    );
    assert [words[0] for words in asked] == ["set", "say", "fire", "pick", "add"];
    assert asked[4] == ["add", "light", "0 0 64", "light", "300"] and ASK_KINDS == ["set", "fire", "pick", "say", "add"];
}

test "a script's walkers and the classes it declares are found in its words" {
    source = "import from qp { Thing, Level }\n\n\"\"\"Spikes that rise\"\"\"\nnode trap_spikes(Thing) {\n    has dmg: int = 20,\n        note: str = \"sharp\";\n}\n\n"
        + "node Helper {\n    has count: int = 0;\n}\n\nwalker Raise {\n    can go with Thing entry {}\n}\n\nwalker Census{\n}\n";
    assert script_walkers(source) == ["Raise", "Census"];
    assert script_classes(source) == ["trap_spikes|point|passion|Spikes that rise|dmg:n:20:,note:t:sharp:|"];
    assert script_walkers(starter_script("Look")) == ["Look"] and script_classes(starter_script("Look")) == [];
}

test "what the compiler and a running script say is wrong is read by line" {
    checked = "  Checking doors.jac...\n✖ Error: error[E1036]: Generic type \"dict\" requires explicit type arguments\n"
        + "  --> /home/me/project/scripts/doors.jac:74:11\n   72 | something\n";
    assert said_faults(checked, "doors.jac") == [(74, "Generic type \"dict\" requires explicit type arguments")];
    ran = "✖ Error: name 'Holds' is not defined\n   17 | walker Census {\n  at count() /home/me/project/scripts/doors.jac:19\n  ... [internal runtime calls]\n";
    assert said_faults(ran, "doors.jac") == [(19, "name 'Holds' is not defined")];
    assert said_faults("all good\n", "doors.jac") == [] and said_faults("✖ Error: no such file", "doors.jac") == [(0, "no such file")];
}
