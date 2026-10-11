import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from editor.model.mesh { mesh_volume, open_edges }
import from editor.model.files { model_of, doc_from_model }
import from editor.model.document { ModelDoc }
import from editor.assets.playback {
    frame_after,
    edges_between,
    facing_edges,
    box_corners,
    box_mesh,
    box_round,
    sequence_range,
    share_stepped,
    SEQUENCES
}

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

test "frames play on through a range, round again or to its end" {
    assert [frame_after(frame, 0, -1, 4) for frame in range(4)] == [1, 2, 3, 0];
    assert frame_after(3, 0, -1, 4, False) == 3 and frame_after(2, 0, -1, 4, False) == 3;
    # From the second to the fourth of six.
    assert [frame_after(frame, 1, 3, 6) for frame in [1, 2, 3]] == [2, 3, 1] and frame_after(3, 1, 3, 6, False) == 3;
    # A frame outside the range comes in at its start; a range that is not one is the whole model.
    assert frame_after(5, 1, 3, 6) == 1 and frame_after(0, 1, 3, 6) == 1;
    assert frame_after(2, 4, 1, 6) == 3 and frame_after(5, 4, 1, 6) == 0 and frame_after(5, 9, 12, 6) == 0;
    assert frame_after(0, 0, 0, 1) == 0 and frame_after(3, 0, -1, 0) == 0;
}

test "the frame between two frames lies part of the way from one to the other" {
    first = [[Vec3(), Vec3(x=8.0)], [Vec3(x=8.0), Vec3(x=8.0, z=8.0)]];
    second = [[Vec3(z=4.0), Vec3(x=8.0, z=4.0)], [Vec3(x=8.0, z=4.0), Vec3(x=16.0, z=8.0)]];
    half = edges_between(first, second, 0.5);
    assert near(half[0][0], Vec3(z=2.0)) and near(half[1][1], Vec3(x=12.0, z=8.0)) and near(first[0][0], Vec3());
    assert edges_between(first, second, 0.0) is first and near(edges_between(first, second, 7.0)[0][0], Vec3(z=4.0));
    # Frames that do not have the same edges are not mixed.
    assert edges_between(first, second[:1], 0.5) is first;
}

test "a box is a closed mesh, and from outside only the faces toward the eye are seen" {
    low = Vec3(x=-8.0, y=-4.0, z=0.0);
    high = Vec3(x=8.0, y=4.0, z=16.0);
    box = box_mesh(low, high);
    assert len(box.points) == 8 and box.triangles() == 12 and open_edges(box) == 0;
    assert abs(mesh_volume(box) - 16.0 * 8.0 * 16.0) < 0.01 and near(box_corners(low, high)[6], high) and near(box.points[0], low);
    # As a model in the games' own winding: from far along x, the face toward the eye and no other.
    doc = ModelDoc(name="box");
    doc.add_part("box", box);
    model = model_of(doc);
    everything = facing_edges(model, 0, Vec3(x=500.0, y=300.0, z=400.0));
    toward = facing_edges(model, 0, Vec3(x=500.0, y=0.0, z=8.0));
    # Three faces show from a corner: nine of the cube's twelve edges and a diagonal each.
    assert len(toward) == 5 and len(everything) == 12;
    for pair in toward {
        assert pair[0].x == 8.0 and pair[1].x == 8.0;
    }
    # From inside, no face is toward the eye.
    assert facing_edges(model, 0, Vec3(z=8.0)) == [];
    assert facing_edges(AnimatedModel(surfaces=[AnimatedSurface(name="bare")]), 0, Vec3()) == [];
}

test "a body's sequences are read from its table for its legs and its torso" {
    # Sarge's table as far as it matters: the whole body's, the torso's from 90, the legs' from 153.
    rows: list[list[float]] = [];
    for (first, count) in [(0, 30), (29, 1), (30, 30), (59, 1), (60, 30), (89, 1)] {
        rows.append([float(first), float(count), 0.0, 20.0]);
    }
    for (first, count, looping, rate) in [
        (90, 40, 0, 15), (130, 6, 0, 15), (136, 6, 0, 15), (142, 5, 0, 20), (147, 4, 0, 20), (151, 1, 0, 15), (152, 1, 0, 15)
    ] {
        rows.append([float(first), float(count), float(looping), float(rate)]);
    }
    for (first, count, looping, rate) in [
        (153, 8, 8, 20), (161, 12, 12, 20), (173, 9, 9, 18), (182, 10, 10, 20), (192, 10, 10, 15), (202, 8, 0, 15),
        (210, 1, 0, 15), (211, 8, 0, 15), (219, 1, 0, 15), (220, 10, 10, 15), (230, 10, 10, 15), (240, 7, 7, 15)
    ] {
        rows.append([float(first), float(count), float(looping), float(rate)]);
    }
    assert len(rows) == 25 and len(SEQUENCES) == 25 and SEQUENCES[6] == "gesture" and SEQUENCES[15] == "run";
    # The torso plays its own from where the table has them, once.
    assert sequence_range(rows, SEQUENCES.index("attack"), False) == [130.0, 135.0, 15.0, 0.0];
    # The legs' file leaves the torso's sixty-three frames out, and running goes round.
    assert sequence_range(rows, SEQUENCES.index("run"), True) == [110.0, 118.0, 18.0, 1.0];
    assert sequence_range(rows, SEQUENCES.index("walkcr"), True) == [90.0, 97.0, 20.0, 1.0];
    # Both play the deaths; neither plays the other's, and a short table plays nothing.
    assert sequence_range(rows, 0, True) == [0.0, 29.0, 20.0, 0.0] and sequence_range(rows, 0, False) == [0.0, 29.0, 20.0, 0.0];
    assert sequence_range(rows, SEQUENCES.index("run"), False) is None and sequence_range(rows, SEQUENCES.index("attack"), True) is None;
    assert sequence_range(rows[:20], 0, True) is None and sequence_range(rows, 25, True) is None;
}

test "a set number of frames between two frames, and the box round some points" {
    # Three between: quarters.
    assert [share_stepped(share, 3) for share in [0.0, 0.2, 0.3, 0.6, 0.8, 1.0]] == [0.0, 0.0, 0.25, 0.5, 0.75, 1.0];
    assert share_stepped(0.37, 0) == 0.37 and share_stepped(0.6, 1) == 0.5 and share_stepped(3.0, 1) == 1.0;
    around = box_round([Vec3(x=4.0, y=-2.0, z=1.0), Vec3(x=-8.0, y=6.0, z=3.0), Vec3(x=1.0, z=-5.0)]);
    assert near(around[0], Vec3(x=-8.0, y=-2.0, z=-5.0)) and near(around[1], Vec3(x=4.0, y=6.0, z=3.0));
    assert near(box_round([])[1], Vec3());
}
