import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh }
import from editor.model.document { ModelDoc, Part, Bone, Grip, Swing }

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

"""A square column standing on the origin: three rings of four points, at
heights 0, 16 and 32. Points 0-3 are the foot, 4-7 the middle, 8-11 the top."""
def column -> Mesh {
    made = Mesh();
    for z in [0.0, 16.0, 32.0] {
        for (x, y) in [(-4.0, -4.0), (4.0, -4.0), (4.0, 4.0), (-4.0, 4.0)] {
            made.points.append(Vec3(x=x, y=y, z=z));
            made.uvs.append((x + 4.0) / 8.0);
            made.uvs.append(z / 32.0);
        }
    }
    for ring in [0, 4] {
        for side in range(4) {
            a = ring + side;
            b = ring + (side + 1) % 4;
            made.corners += [a, b, b + 4, a, b + 4, a + 4];
        }
    }
    return made;
}

"""The column with two bones up it, jointed at the middle, each carrying the
points nearest it."""
def arm -> ModelDoc {
    doc = ModelDoc(name="arm");
    doc.add_part("column", column(), ["skins/arm"]);
    upper = doc.add_bone("upper", Vec3(), Vec3(z=16.0));
    assert upper is not None;
    fore = doc.continue_bone("upper", "fore", Vec3(z=32.0));
    assert fore is not None;
    assert doc.hold_nearest() == 12;
    return doc;
}

test "bones are added, carried on in a chain, and taken away" {
    doc = arm();
    upper = doc.bone("upper");
    fore = doc.bone("fore");
    assert upper is not None and fore is not None and len(doc.bones()) == 2 and doc.bone("hand") is None;
    assert doc.bone_parent(fore) is upper and doc.bone_parent(upper) is None and doc.bone_children(upper) == [fore];
    assert near(fore.heads[0], Vec3(z=16.0)) and near(fore.tails[0], Vec3(z=32.0)) and upper.tint != fore.tint;
    # A name taken, a name with a space, and a bone to hang from that is not there.
    assert doc.add_bone("fore", Vec3(), Vec3(z=1.0)) is None and doc.add_bone("two words", Vec3(), Vec3(z=1.0)) is None;
    assert doc.add_bone("hand", Vec3(), Vec3(z=1.0), "wrist") is None and doc.continue_bone("wrist", "hand", Vec3()) is None;
    hand = doc.continue_bone("fore", "hand", Vec3(z=40.0));
    assert hand is not None and near(hand.heads[0], Vec3(z=32.0)) and doc.bone_parent(hand) is fore;
    # An end put elsewhere leaves the points where they are.
    assert doc.set_bone_end("hand", True, Vec3(x=8.0, z=40.0)) and near(hand.tails[0], Vec3(x=8.0, z=40.0));
    assert near(doc.mesh(doc.parts()[0]).points[8], Vec3(x=-4.0, y=-4.0, z=32.0));
    assert doc.tint_bone("hand", 0x112233) and hand.tint == 0x112233 and not doc.tint_bone("wrist", 1);
    # The middle bone gone: what hung from it hangs from what it hung from.
    assert doc.drop_bone("fore") and doc.bone("fore") is None and doc.bone_parent(hand) is upper;
    assert doc.bone_children(upper) == [hand] and not doc.drop_bone("fore") and len(doc.bones()) == 2;
}

test "points are carried by the nearest bone, shared by weight, and let go" {
    doc = arm();
    part = doc.parts()[0];
    upper = doc.bone("upper");
    fore = doc.bone("fore");
    assert upper is not None and fore is not None;
    low = doc.grip(upper, part);
    high = doc.grip(fore, part);
    # The foot and the middle ring to the first bone (the joint is its end), the top to the second.
    assert low is not None and high is not None and low.points == [0, 1, 2, 3, 4, 5, 6, 7] and high.points == [8, 9, 10, 11];
    assert doc.point_shares(4) == [("upper", 1.0)] and doc.point_shares(9) == [("fore", 1.0)];
    # The middle ring half given to the second: the first keeps the other half.
    assert doc.hold_points("fore", [4, 5, 6, 7, 99], 0.5) == 4;
    assert doc.point_shares(4) == [("upper", 0.5), ("fore", 0.5)] and doc.point_shares(0) == [("upper", 1.0)];
    # A quarter more to the second leaves a quarter for the first.
    assert doc.hold_points("fore", [4], 0.75) == 1 and doc.point_shares(4) == [("upper", 0.25), ("fore", 0.75)];
    assert doc.hold_points("wrist", [4]) == 0 and doc.hold_points("fore", []) == 0;
    # Shown in its bones' colours, mixed as it is shared.
    tints = doc.point_tints(part, 0x000000);
    assert tints[0] == upper.tint and tints[8] == fore.tint and tints[5] != upper.tint and tints[5] != fore.tint;
    # Let go by one bone, then by all.
    assert doc.release_points([4], "fore") == 1 and doc.point_shares(4) == [("upper", 0.25)];
    assert doc.release_points([4, 0]) == 2 and doc.point_shares(4) == [] and doc.point_tints(part, 0x123456)[4] == 0x123456;
    assert doc.release_points([4]) == 0;
}

test "a bone turned takes what it carries by its share, and all that hangs from it whole" {
    doc = arm();
    part = doc.parts()[0];
    fore = doc.bone("fore");
    upper = doc.bone("upper");
    assert fore is not None and upper is not None;
    assert doc.hold_points("fore", [4, 5, 6, 7], 0.5) == 4;
    # The forearm a quarter round x, about the joint at the column's middle.
    assert doc.swing_bone("fore", Vec3(x=1.0), 90.0);
    points = doc.mesh(part).points;
    # The top ring goes all the way; the middle ring, carried by half, half the way; the foot stays.
    assert near(points[10], Vec3(x=4.0, y=-16.0, z=20.0)) and near(points[6], Vec3(x=4.0, y=2.0, z=18.0));
    assert near(points[2], Vec3(x=4.0, y=4.0, z=0.0));
    assert near(fore.heads[0], Vec3(z=16.0)) and near(fore.tails[0], Vec3(y=-16.0, z=16.0)) and near(upper.tails[0], Vec3(z=16.0));
    # Undone, the points and the bone are back; and done again.
    assert doc.undo() == "Turn bone" and near(doc.mesh(part).points[10], Vec3(x=4.0, y=4.0, z=32.0)) and near(fore.tails[0], Vec3(z=32.0));
    assert doc.redo() == "Turn bone" and near(doc.mesh(part).points[10], Vec3(x=4.0, y=-16.0, z=20.0)) and near(fore.tails[0], Vec3(y=-16.0, z=16.0));
    assert doc.undo() == "Turn bone";
    # The upper arm turned: the forearm goes round whole, joint and all, and a point the two
    # share between them goes all the way.
    assert doc.swing_bone("upper", Vec3(x=1.0), 90.0);
    points = doc.mesh(part).points;
    assert near(points[10], Vec3(x=4.0, y=-32.0, z=4.0)) and near(points[6], Vec3(x=4.0, y=-16.0, z=4.0));
    assert near(points[2], Vec3(x=4.0, y=0.0, z=4.0));
    assert near(fore.heads[0], Vec3(y=-16.0)) and near(fore.tails[0], Vec3(y=-32.0)) and near(upper.heads[0], Vec3());
    assert doc.undo() == "Turn bone";
    # Moved, a bone takes what hangs from it along.
    assert doc.shift_bone("upper", Vec3(x=10.0)) and near(fore.tails[0], Vec3(x=10.0, z=32.0));
    assert near(doc.mesh(part).points[10], Vec3(x=14.0, y=4.0, z=32.0)) and doc.undo() == "Move bone";
    # Nothing to turn by, no such bone, no axis.
    assert not doc.swing_bone("fore", Vec3(x=1.0), 0.0) and not doc.swing_bone("wrist", Vec3(x=1.0), 9.0);
    assert not doc.swing_bone("fore", Vec3(), 9.0) and not doc.shift_bone("fore", Vec3());
}

test "bones keep to their frames, and the frames between two poses are spread" {
    doc = arm();
    part = doc.parts()[0];
    fore = doc.bone("fore");
    assert fore is not None;
    assert doc.copy_frame(0, "half") == 1 and doc.copy_frame(1, "bent") == 2 and len(fore.heads) == 3 and len(fore.tails) == 3;
    # Bent at the last frame only.
    doc.frame = 2;
    assert doc.swing_bone("fore", Vec3(x=1.0), 90.0);
    assert near(fore.tails[2], Vec3(y=-16.0, z=16.0)) and near(fore.tails[0], Vec3(z=32.0)) and near(fore.tails[1], Vec3(z=32.0));
    assert near(doc.mesh(part, 0).points[10], Vec3(x=4.0, y=4.0, z=32.0)) and near(doc.mesh(part, 2).points[10], Vec3(x=4.0, y=-16.0, z=20.0));
    # The frame between is set half way: points and the bone's end alike.
    assert doc.spread_frames(0, 2);
    assert near(doc.mesh(part, 1).points[10], Vec3(x=4.0, y=-6.0, z=26.0)) and near(fore.tails[1], Vec3(y=-8.0, z=24.0));
    assert doc.undo() == "Spread frames" and near(doc.mesh(part, 1).points[10], Vec3(x=4.0, y=4.0, z=32.0)) and near(fore.tails[1], Vec3(z=32.0));
    assert not doc.spread_frames(0, 1) and not doc.spread_frames(0, 7);
    # A frame moved or dropped takes the bones' ends with it.
    assert doc.move_frame(2, 0) and near(fore.tails[0], Vec3(y=-16.0, z=16.0)) and near(fore.tails[2], Vec3(z=32.0));
    assert doc.drop_frame(0) and len(fore.tails) == 2 and near(fore.tails[0], Vec3(z=32.0));
}

test "the bones are kept as text and read back" {
    doc = arm();
    part = doc.parts()[0];
    assert doc.hold_points("fore", [4, 5], 0.25) == 2 and doc.tint_bone("fore", 0x4080c0);
    assert doc.copy_frame(0, "bent") == 1;
    doc.frame = 1;
    assert doc.swing_bone("fore", Vec3(x=1.0), 90.0);
    text = doc.rig_text();
    assert "bone upper - " in text and "bone fore upper " + str(0x4080c0) in text and "grip 0 4:0.25 5:0.25 8:1 9:1 10:1 11:1" in text;
    # Read into the same model with its bones taken away: they are as they were.
    assert doc.read_rig("") == 0 and len(doc.bones()) == 0;
    assert doc.read_rig(text) == 2;
    upper = doc.bone("upper");
    fore = doc.bone("fore");
    assert upper is not None and fore is not None and doc.bone_parent(fore) is upper and fore.tint == 0x4080c0;
    assert near(fore.tails[0], Vec3(z=32.0)) and near(fore.tails[1], Vec3(y=-16.0, z=16.0)) and near(fore.heads[1], Vec3(z=16.0));
    doc.frame = 0;
    assert doc.point_shares(4) == [("upper", 0.75), ("fore", 0.25)] and doc.point_shares(11) == [("fore", 1.0)];
    assert doc.rig_text() == text;
    # Lines that say nothing are passed over.
    assert doc.read_rig("// nothing\nat 0 1 2 3 4 5 6\nbone lone - x\ngrip 9 1:1\nat zero\n") == 1 and len(doc.bones()) == 1;
}
