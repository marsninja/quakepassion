import from engine.math.vec3 { Vec3 }
import from editor.model.marks { MARK_STYLES, mark_lines, picks_middle, handle_tips, drag_along, drag_kept, locked_axes }

def close(a: Vec3, b: Vec3) -> bool {
    return a.sub(b).length() < 0.0001;
}

test "a mark is a cross, a box or a diamond about its point" {
    at = Vec3(x=10.0, y=20.0, z=30.0);
    cross = mark_lines(at, 2.0);
    assert len(cross) == 3 and close(cross[0][0], Vec3(x=8.0, y=20.0, z=30.0)) and close(cross[2][1], Vec3(x=10.0, y=20.0, z=32.0));
    box = mark_lines(at, 2.0, "box");
    assert len(box) == 12;
    diamond = mark_lines(at, 2.0, "diamond");
    assert len(diamond) == 12;
    for style in MARK_STYLES {
        for pair in mark_lines(at, 2.0, style) {
            # Every line begins and ends on the mark, and has some length.
            assert pair[0].sub(at).length() <= 2.0 * 1.8 and pair[1].sub(pair[0]).length() > 1.0;
        }
    }
    # A box's edges are each as long as it is wide; a diamond's corners are on the axes.
    assert abs(box[0][1].sub(box[0][0]).length() - 4.0) < 0.0001;
    assert abs(diamond[0][0].sub(at).length() - 2.0) < 0.0001;
    assert len(mark_lines(at, 2.0, "star")) == 3;
}

test "the handles stand along the axes from the middle of what is picked" {
    points = [Vec3(), Vec3(x=4.0), Vec3(x=4.0, y=8.0), Vec3(z=100.0)];
    assert close(picks_middle(points, [0, 1, 2]), Vec3(x=8.0 / 3.0, y=8.0 / 3.0));
    assert close(picks_middle(points, []), Vec3()) and close(picks_middle(points, [9, -1]), Vec3());
    tips = handle_tips(Vec3(x=1.0, y=2.0, z=3.0), 5.0);
    assert close(tips[0], Vec3(x=6.0, y=2.0, z=3.0)) and close(tips[1], Vec3(x=1.0, y=7.0, z=3.0)) and close(tips[2], Vec3(x=1.0, y=2.0, z=8.0));
}

test "a handle takes a drag along its axis, and a locked axis takes none" {
    moved = Vec3(x=3.0, y=-4.0, z=5.0);
    assert close(drag_along(moved, 0), Vec3(x=3.0)) and close(drag_along(moved, 2), Vec3(z=5.0)) and close(drag_along(moved, -1), moved);
    assert close(drag_kept(moved, ""), moved) and close(drag_kept(moved, "y"), Vec3(x=3.0, z=5.0));
    assert close(drag_kept(moved, "XZ"), Vec3(y=-4.0)) and close(drag_kept(moved, "xyz"), Vec3());
    assert locked_axes("zx") == "xz" and locked_axes("Y") == "y" and locked_axes("off") == "" and locked_axes("") == "" and locked_axes("xx") == "x";
}

import from editor.model.marks { tints_carried, tint_word, word_tint }

test "points keep their colours through a tool, and new points take the nearest" {
    before = [Vec3(), Vec3(x=10.0), Vec3(y=10.0)];
    tints = [0xff0000, 0x00ff00, -1];
    # Moved but not remade: the tool that moves points does not ask.
    assert tints_carried(before, tints, before) == tints;
    # A point added beside the second, and the list shuffled.
    after = [Vec3(), Vec3(x=10.0), Vec3(y=10.0), Vec3(x=9.0, y=1.0)];
    assert tints_carried(before, tints, after) == [0xff0000, 0x00ff00, -1, 0x00ff00];
    assert tints_carried(before, tints, [Vec3(y=10.0), Vec3()]) == [-1, 0xff0000];
    assert tints_carried(before, [], after) == [] and tints_carried([], tints, after) == [];
}

test "a colour is six letters of sixteen" {
    assert tint_word(0xff8800) == "ff8800" and tint_word(0) == "000000" and tint_word(-1) == "none";
    assert word_tint("ff8800") == 0xff8800 and word_tint("#0A0b0C") == 0x0a0b0c;
    assert word_tint("none") == -1 and word_tint("ff88") == -1 and word_tint("gg0000") == -1;
}

import from editor.model.mesh { Mesh }
import from editor.model.document { ModelDoc, Reshape }
import from editor.model.marks { face_light }
import from editor.model.skin { skin_filled, skin_dab, skin_colour }

"""Two triangles that make a square, flat on the ground."""
def sheet -> Mesh {
    return Mesh(
        points=[Vec3(), Vec3(x=32.0), Vec3(x=32.0, y=32.0), Vec3(y=32.0)], corners=[0, 1, 2, 0, 2, 3],
        uvs=[0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
    );
}

test "a part's points keep their colours through undo, tools and the rig's file" {
    doc = ModelDoc(name="sheet");
    doc.add_part("flat", sheet(), []);
    part = doc.parts()[0];
    assert part.tints == [] and not doc.tint_points([], 0xff0000, "Colour") and not doc.tint_points([9], 0xff0000, "Colour");
    assert doc.tint_points([0, 1], 0xff0000, "Colour") and part.tints == [0xff0000, 0xff0000, -1, -1];
    assert doc.tint_points([1], 0x00ff00, "Colour") and part.tints == [0xff0000, 0x00ff00, -1, -1];
    assert not doc.tint_points([1], 0x00ff00, "Colour");
    assert doc.undo() and part.tints == [0xff0000, 0xff0000, -1, -1];
    assert doc.redo() and part.tints == [0xff0000, 0x00ff00, -1, -1];
    # Moved: the same points, so the same colours.
    assert doc.reshape(Reshape(kind="move", picks=[0], vector=Vec3(z=4.0)), "Lift");
    assert part.tints == [0xff0000, 0x00ff00, -1, -1];
    # Cut in two: the points there were keep theirs, and each new one takes its nearest's.
    assert doc.reshape(Reshape(kind="subdivide", faces=[0, 1], count=2), "Cut");
    count = len(doc.mesh(part).points);
    assert count > 4 and len(part.tints) == count and part.tints[:4] == [0xff0000, 0x00ff00, -1, -1];
    # Written with the bones and read back.
    text = doc.rig_text();
    assert "colours 0 ff0000 00ff00 none none" in text;
    kept = list(part.tints);
    part.tints = [];
    doc.read_rig(text);
    assert part.tints == kept;
    # Colours for other points than it has are not taken.
    part.tints = [];
    doc.read_rig("colours 0 ff0000 00ff00\n");
    assert part.tints == [];
    # None of them coloured: the part has no colours.
    assert doc.tint_points(list(range(count)), -1, "Clear") is False;
    part.tints = kept;
    assert doc.tint_points(list(range(count)), -1, "Clear") and part.tints == [];
}

test "a face is brightest turned to the light and never dark" {
    assert face_light(Vec3(z=1.0)) > face_light(Vec3(x=1.0)) and face_light(Vec3(x=1.0)) > face_light(Vec3(z=-1.0));
    assert abs(face_light(Vec3(z=-1.0)) - 0.35) < 0.0001 and face_light(Vec3(z=1.0)) <= 1.0;
}

test "a brush lays its colour in a pattern, and a colour is taken up from the skin" {
    skin = skin_filled(16, 16, [0, 0, 0]);
    whole = skin_dab(skin_filled(16, 16, [0, 0, 0]), 0.5, 0.5, 6.0, [255, 0, 0]);
    checked = skin_dab(skin, 0.5, 0.5, 6.0, [255, 0, 0], False, 1.0, "checks", 2);
    assert checked > 0 and checked < whole;
    # Squares of two: (8, 8) is covered, the square beside it is not.
    assert skin_colour(skin, 8.5 / 16.0, 8.5 / 16.0) == [255, 0, 0] and skin_colour(skin, 10.5 / 16.0, 8.5 / 16.0) == [0, 0, 0];
    # Off the picture's edge: the texel at the edge.
    assert skin_colour(skin, 2.0, 2.0) == [0, 0, 0] and skin_colour(skin, -1.0, 0.5) == [0, 0, 0];
}
