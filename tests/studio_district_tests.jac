import os;
import tempfile;
import from games.passion.materials {
    DISTRICTS,
    SLOTS,
    SLOT_NAMES,
    DISTRICT_NAMES,
    DISTRICT_TEXTURES,
    DistrictTable,
    district_table,
    material_word,
    material_spec,
    table_text,
    table_from,
    districts_path,
    kept_table,
    district_names,
    material
}

test "a slot's material is one word, as the studio names materials" {
    assert material_word(["q1", "e1m2", "stone1_3"]) == "q1:e1m2/stone1_3";
    assert material_word(["q2", "", "e1u1/floor3_1"]) == "q2:e1u1/floor3_1";
    assert material_word(["q3", "", "textures/base_wall/concrete"]) == "q3:textures/base_wall/concrete";
    assert material_spec("q1:e1m2/stone1_3") == ["q1", "e1m2", "stone1_3"];
    assert material_spec("q2:e1u1/floor3_1") == ["q2", "", "e1u1/floor3_1"];
    assert material_spec("q3:textures/base_wall/concrete") == ["q3", "", "textures/base_wall/concrete"];
    # A Quake texture needs its map; a word with no game, or another's, names nothing.
    assert material_spec("q1:stone1_3") is None and material_spec("stone1_3") is None and material_spec("q4:x/y") is None;
    assert material_spec("q2:") is None and material_word(["q1"]) == "";
    for district in DISTRICT_TEXTURES {
        for spec in district {
            assert material_spec(material_word(spec)) == spec;
        }
    }
}

test "the table is text, and a text changes only what it speaks of" {
    table = district_table();
    assert len(table.names) == DISTRICTS and len(table.slots) == DISTRICTS and len(table.slots[0]) == SLOTS and len(SLOT_NAMES) == SLOTS;
    text = table_text(table);
    assert "district 0 Stone Keep" in text and "0 floor q1:e1m2/stone1_3" in text and "5 accent q3:textures/base_wall/bluemetal2" in text;
    same = table_from(text);
    assert same.names == table.names and same.slots == table.slots;
    # Two facts: a name and a slot. The rest is as it was, and the built-in table is not touched.
    changed = table_from("district 1 The Yard\n1 wall q2:e1u1/metal3_2\n");
    assert changed.names[1] == "The Yard" and changed.names[0] == "Stone Keep";
    assert changed.slots[1][1] == ["q2", "", "e1u1/metal3_2"] and changed.slots[1][0] == table.slots[1][0];
    assert district_table().slots[1][1] == ["q1", "e1m1", "tech04_1"] and DISTRICT_NAMES[1] == "Slipgate Base";
    # On top of a table already changed.
    again = table_from("1 floor q3:textures/base_floor/diamond2c\n", changed);
    assert again.slots[1][0] == ["q3", "", "textures/base_floor/diamond2c"] and again.slots[1][1] == ["q2", "", "e1u1/metal3_2"];
    assert changed.slots[1][0] == table.slots[1][0];
    # Lines that say nothing a table can hold.
    odd = table_from("// a note\n9 floor q2:a/b\n0 roof q2:a/b\n0 floor stone\ndistrict 9 Nowhere\nfloor\n\n0 floor\n");
    assert odd.names == table.names and odd.slots == table.slots;
    # The numbers levels are made with do not move.
    assert material(0, 0) == 0 and material(1, 1) == 6 and material(5, 4) == 29 and material(6, 0) == 0;
}

test "the table levels are made with is the built-in one with the kept file's changes" {
    folder = tempfile.mkdtemp(prefix="qp-districts-");
    path = folder + "/districts.txt";
    before = os.environ.get("QP_DISTRICTS", "");
    os.environ["QP_DISTRICTS"] = path;
    try {
        assert districts_path() == path;
        # No file: the built-in table.
        assert kept_table().slots == district_table().slots and district_names() == DISTRICT_NAMES;
        with open(path, "w") as file {
            file.write("district 2 Engine Deck\n2 trim q2:e1u1/box3_1\n");
        }
        kept = kept_table();
        assert kept.names[2] == "Engine Deck" and kept.slots[2][3] == ["q2", "", "e1u1/box3_1"] and kept.slots[2][0] == DISTRICT_TEXTURES[2][0];
        assert district_names()[2] == "Engine Deck";
        # The whole table written and read is itself.
        with open(path, "w") as file {
            file.write(table_text(kept));
        }
        assert kept_table().slots == kept.slots and kept_table().names == kept.names;
    } finally {
        if before {
            os.environ["QP_DISTRICTS"] = before;
        } else {
            os.environ.pop("QP_DISTRICTS", None);
        }
    }
}
