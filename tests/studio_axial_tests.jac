import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.linear { Linear, linear_turn, linear_size }
import from editor.geometry.axial { linear_about, linear_along, world_ways, point_sized }

def close(a: Vec3, b: Vec3) -> bool {
    return a.sub(b).length() < 0.0001;
}

def same(a: Linear, b: Linear) -> bool {
    return close(a.x, b.x) and close(a.y, b.y) and close(a.z, b.z);
}

test "a turn about one of the world's axes is the turn in the plane of the other two" {
    assert same(linear_about(Vec3(z=1.0), 90.0), linear_turn(0, 1, 90.0));
    assert same(linear_about(Vec3(x=1.0), 30.0), linear_turn(1, 2, 30.0));
    assert same(linear_about(Vec3(y=1.0), -45.0), linear_turn(2, 0, -45.0));
    assert linear_about(Vec3(z=1.0), 0.0).idle();
}

test "a turn about a slanted way leaves that way where it is and keeps sizes" {
    way = Vec3(x=1.0, y=1.0, z=1.0).normalized();
    turned = linear_about(way, 120.0);
    assert close(turned.carry(way), way);
    # A third of a turn about the long diagonal takes x to y, y to z and z to x.
    assert close(turned.carry(Vec3(x=1.0)), Vec3(y=1.0)) and close(turned.carry(Vec3(y=1.0)), Vec3(z=1.0));
    assert abs(turned.volume() - 1.0) < 0.0001;
}

test "a change of size along the world's ways is the plain one, and along slanted ways leaves what is square to them" {
    world = [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)];
    assert world_ways(world) and same(linear_along(world, Vec3(x=2.0, y=0.5, z=1.0)), linear_size(Vec3(x=2.0, y=0.5, z=1.0)));
    slant = math.sqrt(0.5);
    slanted = [Vec3(x=slant, y=slant), Vec3(x=-slant, y=slant), Vec3(z=1.0)];
    assert not world_ways(slanted);
    grown = linear_along(slanted, Vec3(x=3.0, y=1.0, z=1.0));
    assert close(grown.carry(slanted[0]), slanted[0].scale(3.0)) and close(grown.carry(slanted[1]), slanted[1]);
    assert close(grown.carry(Vec3(z=5.0)), Vec3(z=5.0)) and abs(grown.volume() - 3.0) < 0.0001;
    assert linear_along(slanted, Vec3(x=1.0, y=1.0, z=1.0)).idle() and linear_along([], Vec3(x=2.0, y=2.0, z=2.0)).idle();
    assert close(point_sized(Vec3(x=10.0, y=10.0), Vec3(), slanted, Vec3(x=2.0, y=1.0, z=1.0)), Vec3(x=20.0, y=20.0));
    assert close(point_sized(Vec3(x=11.0, y=10.0, z=4.0), Vec3(x=1.0, z=4.0), slanted, Vec3(x=2.0, y=1.0, z=1.0)), Vec3(x=21.0, y=20.0, z=4.0));
}
