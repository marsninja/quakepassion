import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }

"""Two boxes side by side that share the edge at x 64, and a third apart."""
def neighbours -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=64.0), Vec3(x=128.0, y=64.0, z=64.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=256.0), Vec3(x=320.0, y=64.0, z=64.0), "wall"));
    return scene;
}

test "a shared corner moved with the lock takes its neighbour's with it, as one step" {
    scene = neighbours();
    first = scene.solids()[0];
    second = scene.solids()[1];
    third = scene.solids()[2];
    corner = Vec3(x=64.0, y=64.0, z=64.0);
    assert scene.move_corners_shared(first, [corner], Vec3(z=32.0)) == 2;
    assert first.bounds()[1].z == 96.0 and second.bounds()[1].z == 96.0 and third.bounds()[1].z == 64.0;
    # One step: undone, both are as they were.
    assert scene.undo();
    assert first.bounds()[1].z == 64.0 and second.bounds()[1].z == 64.0;
    # A corner only the one brush has moves that brush alone.
    assert scene.move_corners_shared(first, [Vec3(y=64.0, z=64.0)], Vec3(z=16.0)) == 1;
    assert first.bounds()[1].z == 80.0 and second.bounds()[1].z == 64.0;
}

test "a shared move that would flatten a brush, or that starts where the brush has no corner, moves nothing" {
    scene = neighbours();
    first = scene.solids()[0];
    second = scene.solids()[1];
    assert scene.move_corners_shared(first, [Vec3(x=1.0, y=2.0, z=3.0)], Vec3(z=32.0)) == 0;
    assert scene.move_corners_shared(first, [Vec3(x=64.0, y=64.0, z=64.0)], Vec3()) == 0;
    # The neighbour's whole end wall pushed through its far side: neither brush changes.
    wall = [Vec3(x=64.0), Vec3(x=64.0, y=64.0), Vec3(x=64.0, z=64.0), Vec3(x=64.0, y=64.0, z=64.0)];
    assert scene.move_corners_shared(first, wall, Vec3(x=64.0)) == 0;
    assert first.bounds()[1].x == 64.0 and second.bounds()[0].x == 64.0;
    assert not scene.undo();
}
