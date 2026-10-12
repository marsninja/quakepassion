import from editor.document.playtest { objectives, is_key_class, is_exit_class }

test "a level's objectives are its keys, then what opens the way, then the way out" {
    held = [
        {"classname": "worldspawn"},
        {"classname": "trigger_changelevel", "map": "next"},
        {"classname": "func_button", "target": "gate"},
        {"classname": "item_key1"},
        {"classname": "trigger_once", "target": "bridge", "targetname": "pad"},
        {"classname": "trigger_once"},
        {"classname": "trigger_relay", "target": "gate"},
        {"classname": "key_gold"},
        {"classname": "monster_ogre"}
    ];
    found = objectives(held);
    assert [index for (index, called) in found] == [3, 7, 2, 4, 1];
    assert found[0][1] == "the key item_key1" and found[2][1] == "func_button, which fires gate";
    assert found[3][1] == "trigger_once pad, which fires bridge" and found[4][1] == "the way out (trigger_changelevel)";
    assert objectives([]) == [] and objectives([{"classname": "light"}]) == [];
}

test "keys and ways out are known by their classes" {
    assert is_key_class("key_blue_key") and is_key_class("item_key2") and not is_key_class("item_health");
    assert is_exit_class("trigger_changelevel") and is_exit_class("target_changelevel") and not is_exit_class("trigger_once");
}
