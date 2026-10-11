import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh, mesh_cut, mesh_volume, open_edges, mesh_faults }
import from editor.model.document { ModelDoc, Reshape }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A box 64 by 32 by 16 with a corner on the origin."""
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

test "triangles are cut along a plane, with one new point where two of them share a side" {
    box = crate();
    assert box.triangles() == 12 and len(box.points) == 8 and about(mesh_volume(box), 32768.0);
    cut = mesh_cut(box, list(range(12)), Vec3(x=20.0), Vec3(x=1.0));
    # The plane crosses the four long sides and the four faces' diagonals: eight new points, all on it.
    fresh = cut.points[8:];
    assert len(fresh) == 8 and len([point for point in fresh if about(point.x, 20.0)]) == 8;
    # The two end faces are left; each of the eight triangles it passes through becomes three.
    assert cut.triangles() == 4 + 8 * 3 and open_edges(cut) == 0 and mesh_faults(cut) == [];
    assert about(mesh_volume(cut), 32768.0) and box.triangles() == 12;
    # Their places on the skin lie between those of the ends of the sides they cut.
    if len(cut.uvs) > 0 {
        assert len(cut.uvs) == len(cut.points) * 2;
    }
    # A plane that misses, or only touches a face, cuts nothing; nor does a plane with no way across.
    assert mesh_cut(box, list(range(12)), Vec3(x=80.0), Vec3(x=1.0)).triangles() == 12;
    assert mesh_cut(box, list(range(12)), Vec3(x=64.0), Vec3(x=1.0)).triangles() == 12;
    assert mesh_cut(box, list(range(12)), Vec3(x=20.0), Vec3()).triangles() == 12;
    # Only the chosen triangles are cut: the rest keep their corners.
    some = mesh_cut(box, [0, 1], Vec3(x=20.0), Vec3(x=1.0));
    assert some.triangles() > 12 and some.triangles() < cut.triangles() and some.corners[-3:] != [];
}

test "a plane through a corner cuts a triangle in two" {
    flat = Mesh(points=[Vec3(), Vec3(x=8.0), Vec3(x=4.0, y=8.0)], corners=[0, 1, 2], uvs=[0.0, 0.0, 1.0, 0.0, 0.5, 1.0]);
    halves = mesh_cut(flat, [0], Vec3(x=4.0), Vec3(x=1.0));
    assert halves.triangles() == 2 and len(halves.points) == 4 and about(halves.points[3].x, 4.0) and about(halves.points[3].y, 0.0);
    assert about(halves.uvs[6], 0.5) and about(halves.uvs[7], 0.0);
    # Both halves face the way the whole did.
    assert halves.normal(0).z > 0.9 and halves.normal(1).z > 0.9 and flat.normal(0).z > 0.9;
    # Off the corner it is three.
    thirds = mesh_cut(flat, [0], Vec3(x=2.0), Vec3(x=1.0));
    assert thirds.triangles() == 3 and len(thirds.points) == 5;
    assert thirds.normal(0).z > 0.9 and thirds.normal(1).z > 0.9 and thirds.normal(2).z > 0.9;
}

test "a cut falls on every pose alike, measured at the frame in hand, and is undone whole" {
    doc = ModelDoc(name="crate");
    doc.add_part("box", crate());
    assert doc.copy_frame(0, "wide") == 1;
    doc.frame = 1;
    part = doc.parts()[0];
    # The second frame twice as long: the cut is measured there, a third of the way along.
    assert doc.reshape(Reshape(kind="scale", picks=list(range(8)), pivot=Vec3(), vector=Vec3(x=2.0, y=1.0, z=1.0), only=1), "Stretch");
    assert doc.reshape(Reshape(kind="cut", faces=list(range(12)), pivot=Vec3(x=40.0), vector=Vec3(x=1.0)), "Cut triangles");
    assert doc.mesh(part, 1).triangles() == 28 and doc.mesh(part, 0).triangles() == 28 and doc.faults() == [];
    wide = doc.mesh(part, 1).points[8:];
    short = doc.mesh(part, 0).points[8:];
    assert len([point for point in wide if about(point.x, 40.0)]) == 8 and len([point for point in short if about(point.x, 20.0)]) == 8;
    assert about(mesh_volume(doc.mesh(part, 0)), 32768.0) and about(mesh_volume(doc.mesh(part, 1)), 65536.0);
    assert doc.undo() == "Cut triangles" and doc.mesh(part, 0).triangles() == 12 and doc.redo() == "Cut triangles";
    # A plane that passes through nothing changes nothing.
    assert not doc.reshape(Reshape(kind="cut", faces=list(range(28)), pivot=Vec3(x=500.0), vector=Vec3(x=1.0)), "Cut triangles");
}

test "a tag is turned where it stands, at one frame or at all" {
    doc = ModelDoc(name="crate");
    doc.add_part("box", crate());
    assert doc.copy_frame(0, "second") == 1;
    hook = doc.add_tag("tag_hook", Vec3(x=4.0, y=5.0, z=6.0));
    assert hook is not None;
    doc.frame = 1;
    assert doc.turn_tag("tag_hook", 2, 90.0);
    # About the upright: what pointed along x points along y; the upright itself stays.
    assert about(hook.axes[1][0].y, 1.0) and about(hook.axes[1][0].x, 0.0) and about(hook.axes[1][1].x, -1.0) and about(hook.axes[1][2].z, 1.0);
    assert about(hook.axes[0][0].x, 1.0) and about(hook.origins[1].x, 4.0);
    # At every frame, about x: the upright tips toward... y goes to z.
    assert doc.turn_tag("tag_hook", 0, 90.0, True);
    assert about(hook.axes[0][1].z, 1.0) and about(hook.axes[0][2].y, -1.0) and about(hook.axes[1][0].z, 1.0);
    # Each axis is still a unit long and they still stand square to one another.
    for frame in range(2) {
        for k in range(3) {
            assert about(hook.axes[frame][k].length(), 1.0) and about(hook.axes[frame][k].dot(hook.axes[frame][(k + 1) % 3]), 0.0);
        }
    }
    assert not doc.turn_tag("tag_none", 2, 90.0) and not doc.turn_tag("tag_hook", 5, 90.0) and not doc.turn_tag("tag_hook", 2, 360.0);
}
