import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Plane3, Mapping, classic_mapping }
import from editor.geometry.mapping { mapping_place, mapping_same }
import from editor.geometry.layhandle { lay_arms, lay_dragged, onto_plane, swept_between }

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

test "the arms lie in the face, a repeat of the material long each way" {
    up = Vec3(z=1.0);
    plain = classic_mapping(up, 0.0, 0.0, 0.0, 1.0, 1.0);
    arms = lay_arms(up, plain, 64.0, 32.0);
    assert arms is not None and near(arms[0], Vec3(x=64.0)) and near(arms[1], Vec3(y=-32.0));
    # Twice as fine along its first way: a repeat is half as long there.
    fine = lay_arms(up, classic_mapping(up, 8.0, 4.0, 0.0, 0.5, 1.0), 64.0, 64.0);
    assert fine is not None and near(fine[0], Vec3(x=32.0)) and near(fine[1], Vec3(y=-64.0));
    # On a wall facing +x the material runs along y and down.
    east = Vec3(x=1.0);
    wall = lay_arms(east, classic_mapping(east, 0.0, 0.0, 0.0, 1.0, 1.0), 64.0, 64.0);
    assert wall is not None and near(wall[0], Vec3(y=64.0)) and near(wall[1], Vec3(z=-64.0));
    # On a slope the arms lie in the slope, and are what they say: a point taken along one
    # goes a repeat along that way of the material and nowhere along the other.
    slope = Vec3(y=0.6, z=0.8);
    laid = classic_mapping(slope, 3.0, 5.0, 30.0, 1.5, 0.75);
    leaning = lay_arms(slope, laid, 128.0, 64.0);
    assert leaning is not None and about(leaning[0].dot(slope), 0.0) and about(leaning[1].dot(slope), 0.0);
    foot = Vec3(x=10.0, y=20.0, z=-15.0);
    here = mapping_place(laid, foot);
    along = mapping_place(laid, foot.add(leaning[0]));
    down = mapping_place(laid, foot.add(leaning[1]));
    assert about(along[0] - here[0], 128.0) and about(along[1] - here[1], 0.0);
    assert about(down[0] - here[0], 0.0) and about(down[1] - here[1], 64.0);
    # A material laid edge on to a face has no arms there.
    assert lay_arms(up, Mapping(s_axis=Vec3(x=1.0), t_axis=Vec3(z=1.0)), 64.0, 64.0) is None;
    assert about(swept_between(Vec3(x=1.0), Vec3(y=2.0), up), 90.0) and about(swept_between(Vec3(x=1.0), Vec3(y=-2.0), up), -90.0);
    assert near(onto_plane(Plane3(normal=up, dist=16.0), Vec3(x=3.0, y=4.0, z=99.0)), Vec3(x=3.0, y=4.0, z=16.0));
}

test "the dot slides the material, and an arm stretches and swings one way of it alone" {
    up = Vec3(z=1.0);
    floor = Plane3(normal=up, dist=0.0);
    plain = classic_mapping(up, 0.0, 0.0, 0.0, 1.0, 1.0);
    stand = Vec3(x=32.0, y=32.0);
    sizes = [64.0, 64.0];
    # The dot taken sixteen along x: what was under it is under it still.
    slid = lay_dragged(floor, plain, stand, sizes, 0, Vec3(x=48.0, y=32.0, z=7.0));
    assert slid is not None and near(slid.s_axis, plain.s_axis) and about(slid.s_scale, 1.0);
    was = mapping_place(plain, stand);
    now = mapping_place(slid, Vec3(x=48.0, y=32.0));
    assert about(was[0], now[0]) and about(was[1], now[1]);
    assert lay_dragged(floor, plain, stand, sizes, 0, stand) is None;
    # The first arm taken to twice its length: the material is twice as coarse that way, and
    # where the handles stand it has not moved.
    coarse = lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=160.0, y=32.0));
    assert coarse is not None;
    arms = lay_arms(up, coarse, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(x=128.0)) and near(arms[1], Vec3(y=-64.0));
    held = mapping_place(coarse, stand);
    assert about(held[0], was[0]) and about(held[1], was[1]);
    # Swung an eighth of the way round and no longer: that way of the material runs aslant, the
    # other as before: no longer square.
    aslant = lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=32.0 + 45.2548, y=32.0 + 45.2548));
    assert aslant is not None;
    arms = lay_arms(up, aslant, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(x=45.2548, y=45.2548), 0.01) and near(arms[1], Vec3(y=-64.0), 0.01);
    # The second arm the same, by itself.
    tall = lay_dragged(floor, plain, stand, sizes, 2, Vec3(x=32.0, y=0.0));
    assert tall is not None;
    arms = lay_arms(up, tall, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(x=64.0)) and near(arms[1], Vec3(y=-32.0));
    # Taken to where it already is, nothing changes; nor at the dot itself.
    assert lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=96.0, y=32.0)) is None;
    assert lay_dragged(floor, plain, stand, sizes, 1, stand) is None and lay_dragged(floor, plain, stand, sizes, 3, Vec3()) is None;
}

test "an arm can turn both ways together, in steps, or only stretch" {
    up = Vec3(z=1.0);
    floor = Plane3(normal=up, dist=0.0);
    plain = classic_mapping(up, 0.0, 0.0, 0.0, 1.0, 1.0);
    stand = Vec3();
    sizes = [64.0, 64.0];
    # A quarter turn: both arms go round, neither grows though the pointer is far out.
    turned = lay_dragged(floor, plain, stand, sizes, 1, Vec3(y=200.0), "turn");
    assert turned is not None;
    arms = lay_arms(up, turned, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(y=64.0)) and near(arms[1], Vec3(x=64.0));
    # About forty degrees with turns in steps of forty-five: forty-five.
    stepped = lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=76.6, y=64.3), "turn", 45.0);
    assert stepped is not None;
    arms = lay_arms(up, stepped, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(x=45.2548, y=45.2548), 0.01) and near(arms[1], Vec3(x=45.2548, y=-45.2548), 0.01);
    # In steps, an arm pulled out a little off its line stretches and does not swing.
    straight = lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=128.0, y=6.0), "", 15.0);
    assert straight is not None;
    arms = lay_arms(up, straight, 64.0, 64.0);
    assert arms is not None and about(arms[0].y, 0.0) and about(arms[0].x, 128.14, 0.01) and near(arms[1], Vec3(y=-64.0));
    # Told only to stretch, it takes how far along its own line the pointer is.
    sized = lay_dragged(floor, plain, stand, sizes, 1, Vec3(x=96.0, y=50.0), "size");
    assert sized is not None;
    arms = lay_arms(up, sized, 64.0, 64.0);
    assert arms is not None and near(arms[0], Vec3(x=96.0)) and near(arms[1], Vec3(y=-64.0));
    # On a slope the pointer is taken where it lies over the face.
    slope = Plane3(normal=Vec3(y=0.6, z=0.8), dist=0.0);
    laid = classic_mapping(slope.normal, 0.0, 0.0, 0.0, 1.0, 1.0);
    before = lay_arms(slope.normal, laid, 64.0, 64.0);
    assert before is not None;
    twice = lay_dragged(slope, laid, Vec3(), sizes, 1, before[0].scale(2.0).add(slope.normal.scale(30.0)));
    assert twice is not None;
    after = lay_arms(slope.normal, twice, 64.0, 64.0);
    assert after is not None and near(after[0], before[0].scale(2.0)) and near(after[1], before[1]);
}
