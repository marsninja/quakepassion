import math;
import from engine.math.vec3 { Vec3 }
import from engine.assets.content { read_folders, folders_text }
import from editor.document.readout { resident_megabytes, memory_words }
import from editor.geometry.thick { thick_shifts, line_across, pixel_reach }

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.0001;
}

test "the memory a program holds is read from what ps says" {
    assert near(resident_megabytes("  204800\n"), 200.0);
    assert near(resident_megabytes("1024"), 1.0);
    assert resident_megabytes("") == 0.0 and resident_megabytes("  \n") == 0.0 and resident_megabytes("ps: no such process") == 0.0;
    assert memory_words(0.0) == "" and memory_words(199.6) == "200 MB" and memory_words(1536.0) == "1.5 GB";
}

test "a thick line is itself again to either side, half a pixel apart" {
    assert thick_shifts(1) == [] and thick_shifts(0) == [];
    assert thick_shifts(2) == [0.5, -0.5];
    assert thick_shifts(3) == [0.5, -0.5, 1.0, -1.0];
    # No wider than the widest.
    assert len(thick_shifts(40)) == 6;
}

test "the way across a line lies in the view and is square to the line" {
    right = Vec3(x=1.0);
    up = Vec3(z=1.0);
    level = line_across(Vec3(), Vec3(x=10.0), right, up);
    assert near(level.x, 0.0) and near(level.z, 1.0);
    upright = line_across(Vec3(), Vec3(z=4.0), right, up);
    assert near(abs(upright.x), 1.0) and near(upright.z, 0.0);
    slanted = line_across(Vec3(), Vec3(x=3.0, y=50.0, z=3.0), right, up);
    assert near(slanted.dot(Vec3(x=3.0, z=3.0)), 0.0) and near(slanted.length(), 1.0) and near(slanted.y, 0.0);
    # A line straight at the view.
    at_us = line_across(Vec3(), Vec3(y=9.0), right, up);
    assert near(at_us.x, 1.0);
}

test "a pixel covers the same everywhere in a flat view and more with distance in a deep one" {
    assert near(pixel_reach(500.0, 400, 800.0, 90.0), 2.0) and near(pixel_reach(5.0, 400, 800.0, 90.0), 2.0);
    assert near(pixel_reach(200.0, 400, 0.0, 90.0), 1.0) and near(pixel_reach(400.0, 400, 0.0, 90.0), 2.0);
    # Never nothing, however near.
    assert pixel_reach(0.0, 400, 0.0, 90.0) > 0.0;
}

test "the folders set for games are a line each, and a folder may have spaces" {
    held = read_folders("# where things are\nq1 /games/Quake One/id1\n\nroot   /games\nq2\nq3 \n");
    assert held == {"q1": "/games/Quake One/id1", "root": "/games"};
    assert read_folders(folders_text(held)) == held;
    assert read_folders("") == {} and read_folders(folders_text({})) == {};
}

import from editor.document.readout { flash_level, graph_places }

test "what fired flashes and fades, and a graph's boxes go in columns" {
    assert flash_level(5.0, 5.0) == 1.0 and abs(flash_level(5.5, 5.0) - 0.5) < 0.0001 and flash_level(7.0, 5.0) == 0.0;
    assert flash_level(5.0, -1.0) == 0.0 and flash_level(4.0, 5.0) == 0.0;
    laid = graph_places([[0, 0], [1, 0], [1, 1]], 100, 20, 10);
    assert laid[0] == [10, 10] and laid[1] == [120, 10] and laid[2] == [120, 40] and laid[3] == [230, 70];
    assert graph_places([], 100, 20, 10) == [[0, 0]];
}

import from editor.document.readout { journal_text, read_journal }

test "a journal keeps each step's state under its name, and reads back" {
    kept = [("Move", "{\n\"classname\" \"worldspawn\"\n}\n"), ("Set angle", "{\n\"classname\" \"worldspawn\"\n}\n{\n\"angle\" \"90\"\n}\n")];
    text = journal_text(kept);
    assert text.startswith("//@step Move\n");
    assert read_journal(text) == kept;
    assert read_journal("") == [] and read_journal("no steps here\n") == [];
    # A name with a line break in it stays on its line.
    assert read_journal(journal_text([("Two\nlines", "{\n}\n")]))[0][0] == "Two lines";
}
