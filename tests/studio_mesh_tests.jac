import math;
import from engine.math.vec3 { Vec3 }
import from editor.model.mesh {
    Mesh,
    mesh_volume,
    open_edges,
    mesh_faults,
    points_of_faces,
    faces_of_points,
    faces_toward,
    mesh_moved,
    mesh_turned,
    mesh_scaled,
    mesh_mirrored,
    mesh_flipped,
    mesh_subdivided,
    mesh_extruded,
    mesh_welded
}
import from editor.model.primitives { primitive_mesh, PRIMITIVE_KINDS }
import from editor.model.wavefront { mesh_obj, obj_mesh }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A box 64 wide, 32 deep and 16 tall on the origin: eight points, twelve
triangles, facing outward."""
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

test "a mesh knows what it holds, where it is open and what is wrong with it" {
    box = crate();
    assert box.triangles() == 12 and about(mesh_volume(box), 64.0 * 32.0 * 16.0) and open_edges(box) == 0;
    assert mesh_faults(box) == [];
    low_high = box.bounds();
    assert low_high[0].x == 0.0 and low_high[1].x == 64.0 and low_high[1].z == 16.0;
    assert about(box.normal(0).z, -1.0) and about(box.normal(2).z, 1.0);
    # With its lid off it has four open sides; turned inside out it holds less than nothing.
    lidless = Mesh(points=list(box.points), corners=box.corners[:6] + box.corners[12:], uvs=list(box.uvs));
    assert open_edges(lidless) == 4;
    assert about(mesh_volume(mesh_flipped(box, list(range(12)))), -64.0 * 32.0 * 16.0);
    assert open_edges(mesh_flipped(box, [0])) > 0;
    broken = Mesh(points=[Vec3(), Vec3(x=1.0), Vec3(y=1.0), Vec3(z=5.0)], corners=[0, 1, 2, 0, 1, 1, 0, 1, 9], uvs=[0.0, 0.0]);
    faults = mesh_faults(broken);
    assert len(faults) == 4 and "corner at no point" in faults[0] and "no area" in faults[1];
    assert "used by no triangle" in faults[2] and "skin" in faults[3];
}

test "points and triangles are picked by each other, and by the way they face" {
    box = crate();
    assert points_of_faces(box, [2, 3]) == [4, 5, 6, 7] and points_of_faces(box, [99]) == [];
    assert faces_of_points(box, [4, 5, 6, 7]) == [2, 3] and faces_of_points(box, [0, 1]) == [];
    # Looking down, the top is what faces the eye and the bottom what faces away.
    assert faces_toward(box, Vec3(z=-1.0)) == [2, 3] and faces_toward(box, Vec3(z=-1.0), False) == [0, 1];
    assert len(faces_toward(box, Vec3(x=1.0, z=-1.0).normalized())) == 4;
}

test "picked points move, turn, stretch and mirror, and the mesh given is left alone" {
    box = crate();
    lifted = mesh_moved(box, [4, 5, 6, 7], Vec3(z=16.0));
    assert about(mesh_volume(lifted), 64.0 * 32.0 * 32.0) and box.points[4].z == 16.0 and lifted.points[4].z == 32.0;
    turned = mesh_turned(box, list(range(8)), Vec3(), 2, 90.0);
    # A quarter turn about the vertical: +x goes to +y.
    assert about(turned.points[1].x, 0.0) and about(turned.points[1].y, 64.0) and about(mesh_volume(turned), 32768.0);
    tipped = mesh_turned(box, list(range(8)), Vec3(), 0, 90.0);
    assert about(tipped.points[3].y, 0.0) and about(tipped.points[3].z, 32.0);
    grown = mesh_scaled(box, list(range(8)), Vec3(), Vec3(x=2.0, y=1.0, z=0.5));
    assert about(grown.bounds()[1].x, 128.0) and about(grown.bounds()[1].z, 8.0) and about(mesh_volume(grown), 32768.0);
    across = mesh_mirrored(box, 0, 0.0);
    assert about(across.bounds()[0].x, -64.0) and about(across.bounds()[1].x, 0.0);
    # Mirrored, it still faces outward.
    assert about(mesh_volume(across), 32768.0) and open_edges(across) == 0;
}

test "triangles are cut in two, three and four, keeping what the mesh holds" {
    box = crate();
    for parts in [2, 3, 4] {
        cut = mesh_subdivided(box, list(range(12)), parts);
        assert cut.triangles() == 12 * parts , str(parts);
        assert about(mesh_volume(cut), 32768.0, 0.5) and mesh_faults(cut) == [] , str(parts);
        assert len(cut.uvs) == len(cut.points) * 2;
    }
    # Every side cut once: a point for each of the box's eighteen edges.
    assert len(mesh_subdivided(box, list(range(12)), 4).points) == 8 + 18;
    assert open_edges(mesh_subdivided(box, list(range(12)), 4)) == 0 and open_edges(mesh_subdivided(box, list(range(12)), 3)) == 0;
    # Only the top cut: the rest is as it was.
    top = mesh_subdivided(box, [2, 3], 3);
    assert top.triangles() == 16 and top.corners[:6] == box.corners[:6];
    assert mesh_subdivided(box, [0], 5).triangles() == 12;
}

test "triangles are pushed out with walls behind them, with or without what was there" {
    box = crate();
    raised = mesh_extruded(box, [2, 3], 8.0);
    # The top goes up eight on four walls: it holds eight more of its floor, and is still closed.
    assert raised.triangles() == 12 + 8 and len(raised.points) == 12;
    assert about(mesh_volume(raised), 64.0 * 32.0 * 24.0, 0.5) and open_edges(raised) == 0 and mesh_faults(raised) == [];
    assert about(raised.bounds()[1].z, 24.0);
    # With bulkheads the old top stays where it was, inside.
    walled = mesh_extruded(box, [2, 3], 8.0, True);
    assert walled.triangles() == 12 + 8 + 2 and about(walled.bounds()[1].z, 24.0);
    # Nothing chosen, or faces that cancel out, push nothing.
    assert mesh_extruded(box, [], 8.0).triangles() == 12 and mesh_extruded(box, [0, 1, 2, 3], 8.0).triangles() == 12;
}

test "every primitive is closed, faces outward and fills its box" {
    low = Vec3(x=-32.0, y=-32.0, z=0.0);
    high = Vec3(x=32.0, y=32.0, z=64.0);
    for kind in PRIMITIVE_KINDS {
        # A ring is as thick as its box is tall: it lies in a flatter one.
        tall = 16.0 if kind == "torus" else 64.0;
        made = primitive_mesh(kind, low, Vec3(x=32.0, y=32.0, z=tall), 12, 8);
        assert made.triangles() > 0 and mesh_faults(made) == [] , kind;
        assert len(made.uvs) == len(made.points) * 2 , kind;
        box = made.bounds();
        assert about(box[0].x, -32.0, 0.01) and about(box[1].x, 32.0, 0.01) , kind;
        if kind == "fan" {
            # One sheet: open all round, facing up.
            assert open_edges(made) == 12 and about(made.normal(0).z, 1.0) , kind;
            continue;
        }
        assert open_edges(made) == 0 and mesh_volume(made) > 0.0 , kind;
        assert about(box[0].z, 0.0, 0.01) and about(box[1].z, tall, 0.01) , kind;
    }
    # A cylinder of many sides holds nearly what a round one would; a cone a third of it.
    drum = primitive_mesh("cylinder", low, high, 48);
    assert about(mesh_volume(drum), math.pi * 32.0 * 32.0 * 64.0, 700.0);
    assert about(mesh_volume(primitive_mesh("cone", low, high, 48)) * 3.0, mesh_volume(drum), 1.0);
    assert about(mesh_volume(primitive_mesh("bicone", low, high, 48)) * 3.0, mesh_volume(drum), 1.0);
    assert primitive_mesh("cube", low, high).triangles() == 0;
    assert primitive_mesh("cone", low, high, 2).triangles() == 6;
    # A ring too thin for its own thickness is not made.
    assert primitive_mesh("torus", low, Vec3(x=32.0, y=32.0, z=128.0)).triangles() == 0;
}

test "a mesh written as OBJ text reads back the same, and other programs' files are read" {
    box = crate();
    text = mesh_obj(box, "crate");
    assert text.startswith("# Written by the QuakePassion studio.\no crate\nv 0 0 0\nv 64 0 0\n");
    # Up is y there: the point at (64, 32, 16) is written as 64 16 -32.
    assert "v 64 16 -32\n" in text and "vt 1 0\n" in text and "f 1/1 3/3 2/2\n" in text;
    again = obj_mesh(text);
    assert again.triangles() == 12 and len(again.points) == 8 and again.corners == box.corners;
    for index in range(8) {
        assert about(again.points[index].sub(box.points[index]).length(), 0.0);
        assert about(again.uvs[index * 2], box.uvs[index * 2]) and about(again.uvs[index * 2 + 1], box.uvs[index * 2 + 1]);
    }
    assert about(mesh_volume(again), 32768.0);
    bare = Mesh(points=list(box.points), corners=list(box.corners));
    assert "vt " not in mesh_obj(bare) and "f 1 3 2\n" in mesh_obj(bare) and obj_mesh(mesh_obj(bare)).uvs == [];
    # A square face with normals, corners counted back from the end, and a line of nonsense.
    other = "# a quad\nv 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nvn 0 0 1\nnonsense here now\nf -4//1 -3//1 -2//1 -1//1\nf 1 2 9\n";
    quad = obj_mesh(other);
    assert quad.triangles() == 2 and len(quad.points) == 4 and quad.corners == [0, 1, 2, 0, 2, 3];
    assert mesh_faults(quad) == [] and about(quad.normal(0).y, -1.0);
    # One point at two places on the skin becomes two points.
    seam = obj_mesh("v 0 0 0\nv 1 0 0\nv 0 1 0\nv 1 1 0\nvt 0 0\nvt 1 0\nvt 0.5 1\nf 1/1 2/2 3/3\nf 2/1 4/2 3/3\n");
    assert seam.triangles() == 2 and len(seam.points) == 5 and len(seam.uvs) == 10;
    # Welded, points in one place are one again, and what nothing uses is gone.
    assert len(mesh_welded(seam).points) == 4 and mesh_welded(seam).triangles() == 2;
    spare = Mesh(points=list(box.points) + [Vec3(z=99.0)], corners=list(box.corners), uvs=list(box.uvs) + [0.0, 0.0]);
    assert len(mesh_welded(spare).points) == 8 and len(mesh_welded(spare).uvs) == 16;
}
