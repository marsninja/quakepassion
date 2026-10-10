import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush {
    Plane3,
    Side,
    Mapping,
    plane_through,
    plane_winding,
    clip_winding,
    brush_windings,
    box_sides,
    windings_bounds,
    brush_holds,
    ray_enters_brush,
    winding_area,
    brush_volume,
    classic_axes,
    classic_mapping
}

def close(a: float, b: float) -> bool {
    return abs(a - b) < 0.001;
}

test "three clockwise points make the plane facing the viewer" {
    # A floor's top face as a map writes it, seen from above.
    plane = plane_through(Vec3(x=0.0, y=0.0, z=64.0), Vec3(x=0.0, y=64.0, z=64.0), Vec3(x=64.0, y=0.0, z=64.0));
    assert plane is not None and close(plane.normal.z, 1.0) and close(plane.dist, 64.0);
    assert plane_through(Vec3(), Vec3(x=1.0), Vec3(x=2.0)) is None;
    assert close(plane.side(Vec3(z=70.0)), 6.0) and close(plane.side(Vec3(z=60.0)), -4.0);
    assert close(plane.moved(Vec3(z=16.0)).dist, 80.0) and close(plane.flipped().normal.z, -1.0);
}

test "a box brush has six rectangular faces winding clockwise from outside" {
    sides = box_sides(Vec3(x=-32.0, y=-16.0, z=0.0), Vec3(x=32.0, y=16.0, z=64.0), "wall");
    windings = brush_windings(sides);
    assert len(windings) == 6;
    areas = [winding_area(winding) for winding in windings];
    assert close(areas[0], 32.0 * 64.0) and close(areas[2], 64.0 * 64.0) and close(areas[4], 64.0 * 32.0);
    for i in range(6) {
        winding = windings[i];
        assert len(winding) == 4;
        # Every corner is on the face's plane and the winding faces along it.
        for point in winding {
            assert close(sides[i].plane.side(point), 0.0);
        }
        facing = winding[2].sub(winding[0]).cross(winding[1].sub(winding[0])).normalized();
        assert close(facing.dot(sides[i].plane.normal), 1.0);
    }
    bounds = windings_bounds(windings);
    assert bounds is not None and close(bounds[0].x, -32.0) and close(bounds[1].z, 64.0);
    assert close(brush_volume(sides), 64.0 * 32.0 * 64.0);
}

test "a plane cuts a corner off a box and the cut face is a triangle" {
    sides = box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0));
    normal = Vec3(x=1.0, y=1.0, z=1.0).normalized();
    # Through the three corners next to (64, 64, 64).
    sides.append(Side(plane=Plane3(normal=normal, dist=normal.dot(Vec3(x=64.0, y=64.0, z=0.0)))));
    windings = brush_windings(sides);
    assert len(windings[6]) == 3;
    assert close(winding_area(windings[6]), math.sqrt(3.0) / 4.0 * (64.0 * math.sqrt(2.0)) ** 2);
    # The three faces at the corner each lost half.
    assert len(windings[0]) == 3 and close(winding_area(windings[0]), 2048.0);
    assert len(windings[1]) == 4;
    assert close(brush_volume(sides), 64.0 ** 3 - 64.0 ** 3 / 6.0);
    assert not brush_holds(sides, Vec3(x=60.0, y=60.0, z=60.0)) and brush_holds(sides, Vec3(x=8.0, y=8.0, z=8.0));
}

test "a side the others cut away has no outline, and a plane that misses changes nothing" {
    sides = box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0));
    sides.append(Side(plane=Plane3(normal=Vec3(x=1.0), dist=200.0)));
    windings = brush_windings(sides);
    assert len(windings[6]) == 0;
    assert close(brush_volume(sides), 64.0 ** 3);
    whole = plane_winding(Plane3(normal=Vec3(z=1.0), dist=8.0));
    assert len(whole) == 4 and close(whole[0].z, 8.0);
    assert len(clip_winding(whole, Plane3(normal=Vec3(x=1.0), dist=0.0))) == 4;
    assert len(clip_winding(whole, Plane3(normal=Vec3(z=1.0), dist=0.0))) == 0;
}

test "a ray enters a brush by the side facing it" {
    sides = box_sides(Vec3(x=100.0, y=-10.0, z=-10.0), Vec3(x=120.0, y=10.0, z=10.0));
    hit = ray_enters_brush(sides, Vec3(), Vec3(x=1.0));
    assert close(hit[0], 100.0) and hit[1] == 1;
    assert ray_enters_brush(sides, Vec3(), Vec3(x=-1.0))[1] == -1;
    assert ray_enters_brush(sides, Vec3(y=50.0), Vec3(x=1.0))[1] == -1;
    above = ray_enters_brush(sides, Vec3(x=110.0, z=100.0), Vec3(z=-1.0));
    assert close(above[0], 90.0) and hit[1] != above[1] and above[1] == 4;
}

test "the classic mapping projects along the nearest axis and turns with its rotation" {
    floor = classic_axes(Vec3(z=1.0));
    assert close(floor[0].x, 1.0) and close(floor[1].y, -1.0);
    wall = classic_axes(Vec3(x=-0.9, y=0.1, z=0.2).normalized());
    assert close(wall[0].y, 1.0) and close(wall[1].z, -1.0);
    plain = classic_mapping(Vec3(z=1.0), 16.0, 8.0, 0.0, 2.0, 0.5);
    texel = plain.texel(Vec3(x=64.0, y=32.0, z=5.0));
    assert close(texel[0], 64.0 / 2.0 + 16.0) and close(texel[1], -32.0 / 0.5 + 8.0);
    turned = classic_mapping(Vec3(z=1.0), 0.0, 0.0, 90.0, 1.0, 1.0);
    assert close(turned.s_axis.y, 1.0) and close(turned.t_axis.x, 1.0) and close(turned.rotation, 90.0);
    assert close(classic_mapping(Vec3(z=1.0), 0.0, 0.0, 0.0, 0.0, 0.0).s_scale, 1.0);
}
