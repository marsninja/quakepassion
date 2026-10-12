import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh, mesh_found }

test "a point and a triangle are found by number, and said" {
    # Two triangles of a square in the floor, sharing a diagonal.
    square = Mesh(
        points=[Vec3(), Vec3(x=8.0), Vec3(x=8.0, y=8.0), Vec3(y=8.0), Vec3(x=1.5, y=2.25, z=3.0)],
        corners=[0, 1, 2, 0, 2, 3]
    );
    assert mesh_found(square, False, 0) == "point 0 at=0,0,0 triangles=0,1";
    assert mesh_found(square, False, 1) == "point 1 at=8,0,0 triangles=0";
    # A point no triangle uses, with a place that is not whole.
    assert mesh_found(square, False, 4) == "point 4 at=1.5,2.25,3 triangles=";
    assert mesh_found(square, True, 1) == "triangle 1 points=0,2,3 area=32 facing=0,0,1";
    assert mesh_found(square, True, 2) == "" and mesh_found(square, False, 5) == "" and mesh_found(square, True, -1) == "";
}
