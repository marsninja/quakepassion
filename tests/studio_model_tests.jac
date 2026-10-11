import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh, mesh_volume, open_edges }
import from editor.model.primitives { primitive_mesh }
import from editor.model.document { ModelDoc, Part, Pose, Tag, Reshape, HasPose, HasTag }
import from editor.model.files { doc_from_model, model_of, write_md3, md3_limits, write_md2, md2_limits, turned_about }
import from engine.formats.q2.model { parse_md2 }
import from engine.formats.q3.model { parse_md3 }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A box 64 by 32 by 16 on the origin."""
def crate -> Mesh {
    made = Mesh();
    for z in [0.0, 16.0] {
        for (x, y) in [(0.0, 0.0), (64.0, 0.0), (64.0, 32.0), (0.0, 32.0)] {
            made.points.append(Vec3(x=x, y=y, z=z));
            made.uvs.append(x / 64.0);
            made.uvs.append(y / 32.0);
        }
    }
    made.corners = [
        0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7
    ];
    return made;
}

"""A model of one crate with three frames, the lid a little higher in each."""
def lifting -> ModelDoc {
    doc = ModelDoc(name="crate");
    doc.add_part("box", crate(), ["skins/crate"]);
    assert doc.copy_frame(0, "half") == 1 and doc.copy_frame(1, "open") == 2;
    for frame in [1, 2] {
        doc.frame = frame;
        doc.pick_faces([2, 3]);
        assert doc.reshape(Reshape(kind="move", picks=doc.parts()[0].picked_points, vector=Vec3(z=8.0 * float(frame)), only=frame), "Lift");
    }
    doc.frame = 0;
    doc.pick_points([]);
    return doc;
}

test "a model is parts with a pose a frame, and frames are copied, named and dropped" {
    doc = lifting();
    assert len(doc.parts()) == 1 and doc.frames() == 3 and doc.frame_name(1) == "half" and doc.frame_name(2) == "open";
    part = doc.parts()[0];
    assert part.skins == ["skins/crate"] and len(doc.poses(part)) == 3;
    # The lid stands higher at each frame; the first is as it was made.
    assert about(mesh_volume(doc.mesh(part, 0)), 32768.0) and about(mesh_volume(doc.mesh(part, 1)), 49152.0);
    assert about(mesh_volume(doc.mesh(part, 2)), 65536.0) and about(doc.bounds(2)[1].z, 32.0) and about(doc.bounds(0)[1].z, 16.0);
    assert doc.name_frame(1, "ajar") and doc.frame_name(1) == "ajar" and not doc.name_frame(9, "x");
    assert doc.drop_frame(1) and doc.frames() == 2 and doc.frame_name(1) == "open";
    assert about(mesh_volume(doc.mesh(part, 1)), 65536.0);
    assert doc.drop_frame(0) and not doc.drop_frame(0) and doc.frames() == 1 and doc.frame_name(0) == "open";
    assert doc.copy_frame(5) == -1;
}

test "a tool that changes the triangles is carried to every pose alike" {
    doc = lifting();
    part = doc.parts()[0];
    doc.pick_faces([2, 3]);
    assert doc.reshape(Reshape(kind="extrude", faces=[2, 3], amount=8.0), "Extrude");
    assert len(part.corners) // 3 == 20;
    for frame in range(3) {
        mesh = doc.mesh(part, frame);
        # Twelve points at every frame, closed, and eight taller than it was.
        assert len(mesh.points) == 12 and open_edges(mesh) == 0 , str(frame);
        assert about(mesh_volume(mesh), 64.0 * 32.0 * (16.0 + 8.0 * float(frame) + 8.0), 0.5) , str(frame);
    }
    assert doc.reshape(Reshape(kind="subdivide", faces=list(range(20)), count=2), "Cut in two");
    assert len(part.corners) // 3 == 40;
    counts = [len(doc.mesh(part, frame).points) for frame in range(3)];
    assert counts[0] == counts[1] and counts[1] == counts[2];
    for frame in range(3) {
        # The same cut at every frame: nothing is left with no area.
        assert doc.faults() == [] and open_edges(doc.mesh(part, frame)) == 0 , str(frame);
    }
    assert doc.reshape(Reshape(kind="flip", faces=list(range(40))), "Turn round");
    assert mesh_volume(doc.mesh(part, 0)) < 0.0 and mesh_volume(doc.mesh(part, 2)) < 0.0;
    # A tool that changes nothing leaves no step.
    steps = len(doc.done);
    assert not doc.reshape(Reshape(kind="move", picks=[], vector=Vec3(z=5.0)), "Move") and len(doc.done) == steps;
}

test "edits are undone and redone whole, a part at a time" {
    doc = lifting();
    part = doc.parts()[0];
    before = doc.mesh(part, 2);
    doc.pick_faces([2, 3]);
    assert doc.reshape(Reshape(kind="extrude", faces=[2, 3], amount=8.0), "Extrude");
    assert doc.reshape(Reshape(kind="turn", picks=list(range(12)), pivot=Vec3(), axis=2, amount=90.0), "Turn");
    assert about(doc.bounds(0)[0].x, -32.0) and doc.dirty;
    assert doc.undo() == "Turn" and about(doc.bounds(0)[0].x, 0.0) and len(part.corners) // 3 == 20;
    assert doc.undo() == "Extrude" and len(part.corners) // 3 == 12 and part.picked_faces == [2, 3];
    again = doc.mesh(part, 2);
    assert len(again.points) == 8 and again.corners == before.corners;
    for index in range(8) {
        assert about(again.points[index].sub(before.points[index]).length(), 0.0);
    }
    # The two lifts that made the frames are steps too.
    assert doc.undo() == "Lift" and doc.undo() == "Lift" and doc.undo() == "";
    assert doc.redo() == "Lift" and doc.redo() == "Lift" and doc.redo() == "Extrude" and doc.redo() == "Turn" and doc.redo() == "";
    assert len(part.corners) // 3 == 20 and about(doc.bounds(0)[0].x, -32.0);
    # A new edit forgets what was undone.
    doc.undo();
    assert doc.reshape(Reshape(kind="scale", picks=list(range(12)), pivot=Vec3(), vector=Vec3(x=2.0, y=1.0, z=1.0)), "Stretch");
    assert doc.redo() == "";
}

test "points and triangles are picked by number and by the way they face" {
    doc = lifting();
    part = doc.parts()[0];
    assert doc.pick_points([0, 1, 99, 1]) == 2 and part.picked_points == [0, 1];
    assert doc.pick_points([5], True) == 3 and doc.pick_points([]) == 0;
    assert doc.pick_faces([2, 3]) == 2 and part.picked_points == [4, 5, 6, 7];
    middle = doc.picked_middle();
    assert about(middle.x, 32.0) and about(middle.y, 16.0) and about(middle.z, 16.0);
    doc.frame = 2;
    assert about(doc.picked_middle().z, 32.0);
    # From above, the top; from above, what faces away.
    assert doc.pick_facing(Vec3(z=-1.0)) == 2 and part.picked_faces == [2, 3];
    assert doc.pick_facing(Vec3(z=-1.0), False) == 2 and part.picked_faces == [0, 1];
    doc.pick_faces([]);
    assert about(doc.picked_middle().x, 32.0);
}

test "a model of several parts is checked, and its parts given the same frames" {
    doc = lifting();
    low = Vec3(x=0.0, y=0.0, z=40.0);
    knob = doc.add_part("knob", primitive_mesh("sphere", low, Vec3(x=16.0, y=16.0, z=56.0), 8));
    assert len(doc.parts()) == 2 and doc.part() is knob and len(doc.poses(knob)) == 3;
    # A part added later has the model's frames, by name.
    assert [pose.name for pose in doc.poses(knob)] == ["frame 0", "half", "open"] and doc.faults() == [];
    assert about(doc.bounds(0)[1].z, 56.0);
    # A frame too many on one part, and a triangle with a corner nowhere.
    knob +>:HasPose(index=3):+> Pose(name="stray", points=list(doc.poses(knob)[0].points));
    knob.corners.extend([0, 1, 999]);
    faults = doc.faults();
    assert len(faults) == 2 and "corner at no point" in faults[0] and "knob has 4 frames, the model 3" in faults[1];
    assert doc.match_frames() == 1 and len(doc.poses(knob)) == 3 and doc.match_frames() == 0;
    knob.corners = knob.corners[:-3];
    assert doc.faults() == [];
    # An edit goes to the part in hand, and its undo to that part.
    doc.part_now = 0;
    assert doc.reshape(Reshape(kind="mirror", axis=0, amount=0.0), "Mirror") and about(doc.bounds(0)[0].x, -64.0);
    assert about(doc.mesh(knob, 0).bounds()[0].x, 0.0);
    assert doc.undo() == "Mirror" and about(doc.bounds(0)[0].x, 0.0);
    empty = ModelDoc();
    assert empty.frames() == 0 and empty.part() is None and empty.faults() == [] and not empty.reshape(Reshape(kind="flip"), "x");
}

test "a model written as MD3 is read by the engine as it was, and comes back as a graph" {
    doc = lifting();
    knob = doc.add_part("knob", primitive_mesh("sphere", Vec3(x=0.0, y=0.0, z=40.0), Vec3(x=16.0, y=16.0, z=56.0), 8));
    hook = Tag(name="tag_hook");
    for frame in range(3) {
        hook.origins.append(Vec3(x=32.0, y=16.0, z=16.0 + 8.0 * float(frame)));
        hook.axes.append([Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]);
    }
    doc +>:HasTag:+> hook;
    assert md3_limits(doc) == [];
    data = write_md3(doc);
    assert len(data) > 108 and data[:4] == b"IDP3";
    read = parse_md3(data);
    assert len(read.surfaces) == 2 and read.surfaces[0].name == "box" and read.surfaces[1].name == "knob";
    assert read.surfaces[0].skins == ["skins/crate"] and len(read.surfaces[0].frames) == 3;
    # The file winds its triangles the other way round from the editor.
    assert turned_about([0, 1, 2, 3, 4, 5]) == [0, 2, 1, 3, 5, 4];
    assert read.surfaces[0].frames[1].name == "half" and read.surfaces[0].indices == turned_about(doc.parts()[0].corners);
    assert len(read.tags) == 3 and read.tags[2].tags[0].name == "tag_hook" and about(read.tags[2].tags[0].origin.z, 32.0);
    # Places to a sixty-fourth of a unit; the lid's corner at the last frame.
    top = read.surfaces[0].frames[2].vertices[6];
    assert about(top.x, 64.0, 0.02) and about(top.y, 32.0, 0.02) and about(top.z, 32.0, 0.02);
    # The way a point faces survives to within the two bytes it is kept in.
    normal = read.surfaces[1].frames[0].normals[len(read.surfaces[1].frames[0].normals) - 2];
    assert about(normal.z, 1.0, 0.05);
    again = doc_from_model(read, "crate");
    assert len(again.parts()) == 2 and again.frames() == 3 and again.frame_name(2) == "open" and not again.dirty;
    assert again.parts()[0].corners == doc.parts()[0].corners and len(again.tags()) == 1;
    assert about(mesh_volume(again.mesh(again.parts()[0], 2)), 65536.0, 1.0) and again.faults() == [];
    # What the viewer draws is the same model.
    shown = model_of(again);
    assert len(shown.surfaces) == 2 and len(shown.surfaces[0].uv) == len(shown.surfaces[0].indices) * 2;
    assert len(shown.tags) == 3 and shown.tags[1].tags[0].name == "tag_hook";
    # A model too wide for the file's numbers is not written.
    wide = ModelDoc(name="wide");
    wide.add_part("slab", crate());
    wide.reshape(Reshape(kind="scale", picks=list(range(8)), pivot=Vec3(), vector=Vec3(x=10.0, y=1.0, z=1.0)), "Stretch");
    assert len(md3_limits(wide)) == 1 and "511" in md3_limits(wide)[0] and write_md3(wide) == b"";
    assert len(md3_limits(ModelDoc())) == 1;
}

test "a model written as MD2 is one mesh the engine reads, to within what its bytes can say" {
    doc = lifting();
    doc.add_part("knob", primitive_mesh("sphere", Vec3(x=0.0, y=0.0, z=40.0), Vec3(x=16.0, y=16.0, z=56.0), 8), ["skins/knob"]);
    assert md2_limits(doc) == [];
    data = write_md2(doc, 128, 64);
    assert len(data) > 68 and data[:4] == b"IDP2";
    read = parse_md2(data);
    assert len(read.surfaces) == 1 and read.surfaces[0].skins == ["skins/crate", "skins/knob"];
    surface = read.surfaces[0];
    box_part = doc.parts()[0];
    knob = doc.parts()[1];
    # Both parts' triangles, the second's points numbered after the first's.
    assert len(surface.indices) == len(box_part.corners) + len(knob.corners) and len(surface.frames) == 3;
    assert surface.indices[:36] == turned_about(box_part.corners) and surface.indices[36] == 8 + turned_about(knob.corners)[0];
    assert surface.frames[2].name == "open" and len(surface.frames[0].vertices) == 8 + len(doc.poses(knob)[0].points);
    for frame in range(3) {
        for (index, point) in enumerate(doc.poses(box_part)[frame].points) {
            # A byte an axis across the frame's box: within a 255th of it.
            assert about(surface.frames[frame].vertices[index].sub(point).length(), 0.0, 0.3) , str(frame) + " " + str(index);
        }
    }
    # A place on the skin comes back to within a texel.
    first = turned_about(box_part.corners)[1];
    assert about(surface.uv[2], box_part.uvs[first * 2], 1.0 / 128.0) and about(surface.uv[3], box_part.uvs[first * 2 + 1], 1.0 / 64.0);
    # And as a graph again it is one part that holds what the two did.
    again = doc_from_model(read, "crate");
    assert len(again.parts()) == 1 and again.frames() == 3 and again.faults() == [];
    held = mesh_volume(doc.mesh(box_part, 0)) + mesh_volume(doc.mesh(knob, 0));
    assert about(mesh_volume(again.mesh(again.parts()[0], 0)), held, held * 0.02);
    assert len(md2_limits(ModelDoc())) == 2 and write_md2(ModelDoc()) == b"";
}
