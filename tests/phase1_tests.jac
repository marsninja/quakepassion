"""Phase 1 tests: math, clock, and — the one that matters — the world graph
and VisPass flood, exercised with zero graphics."""

import from engine.math.vec3 { Vec3, forward_from }
import from engine.math.aabb { AABB }
import from engine.core.clock { Clock }
import from engine.world.world {
    World, Area, Portal, In, Player, Entity, Surface,
    ThinkPass, VisPass, portal_visible,
    area_containing, area_of, move_to_area
}


def make_area(name: str, x0: float, x1: float) -> Area {
    return Area(
        name=name,
        bounds=AABB(mins=Vec3(x=x0, y=0.0, z=0.0), maxs=Vec3(x=x1, y=256.0, z=128.0))
    );
}


def door_rect(x: float) -> AABB {
    return AABB(mins=Vec3(x=x - 6.0, y=96.0, z=0.0), maxs=Vec3(x=x + 6.0, y=160.0, z=96.0));
}


test "vec3 math behaves" {
    v = Vec3(x=3.0, y=4.0, z=0.0);
    assert v.length() == 5.0;
    assert v.normalized().length() > 0.999;
    assert v.dot(Vec3(x=1.0)) == 3.0;
    c = Vec3(x=1.0).cross(Vec3(y=1.0));
    assert c.z == 1.0;
    assert Vec3(x=1.0).lerp(Vec3(x=3.0), 0.5).x == 2.0;
}


test "forward vector is z-up quake style" {
    f = forward_from(0.0, 0.0);
    assert abs(f.x - 1.0) < 0.0001;
    up = forward_from(0.0, 1.5707963);
    assert abs(up.z - 1.0) < 0.0001;
}


test "aabb containment" {
    bb = AABB(mins=Vec3(), maxs=Vec3(x=10.0, y=10.0, z=10.0));
    assert bb.contains(Vec3(x=5.0, y=5.0, z=5.0));
    assert not bb.contains(Vec3(x=11.0, y=5.0, z=5.0));
    assert bb.center().x == 5.0;
    assert bb.size().y == 10.0;
}


test "clock accumulates fixed ticks" {
    c = Clock(tick_rate=0.05);
    assert c.advance(0.12) == 2;
    assert abs(c.accumulator - 0.02) < 0.000001;
    assert c.advance(0.04) == 1;
    # spiral-of-death guard: a huge frame is capped and the debt dropped
    c2 = Clock(tick_rate=0.05, max_ticks_per_frame=5);
    assert c2.advance(10.0) == 5;
    assert c2.accumulator == 0.0;
}


test "vis flood crosses facing portals only" {
    w = World();
    a = make_area("a", 0.0, 256.0);
    b = make_area("b", 256.0, 512.0);
    c = make_area("c", 512.0, 768.0);
    w ++> a;
    w ++> b;
    w ++> c;
    a <+: Portal(rect=door_rect(256.0)) :+> b;
    b <+: Portal(rect=door_rect(512.0)) :+> c;

    eye = Vec3(x=64.0, y=128.0, z=56.0);

    # facing +x toward the chain: the flood reaches every room
    toward = a spawn VisPass(eye=eye, facing=Vec3(x=1.0));
    assert len(toward.visible) == 3;

    # facing -x away from the chain: only the room we stand in
    away = a spawn VisPass(eye=eye, facing=Vec3(x=-1.0));
    assert len(away.visible) == 1;
    assert away.visible[0] is a;

    # standing in the middle room facing back toward a: a and b visible, c not
    mid_eye = Vec3(x=300.0, y=128.0, z=56.0);
    back = b spawn VisPass(eye=mid_eye, facing=Vec3(x=-1.0));
    assert len(back.visible) == 2;
}


test "portal right next to the eye is always visible" {
    rect = door_rect(256.0);
    eye_in_door = Vec3(x=256.0, y=128.0, z=48.0);
    assert portal_visible(eye_in_door, Vec3(x=-1.0), rect);
}


test "area containment lookup finds the right room" {
    w = World();
    a = make_area("a", 0.0, 256.0);
    b = make_area("b", 256.0, 512.0);
    w ++> a;
    w ++> b;
    found = area_containing(w, Vec3(x=300.0, y=10.0, z=10.0));
    assert found is b;
    assert area_containing(w, Vec3(x=9999.0, y=0.0, z=0.0)) is None;
}


test "in edge rewires as the player moves" {
    w = World();
    a = make_area("a", 0.0, 256.0);
    b = make_area("b", 256.0, 512.0);
    w ++> a;
    w ++> b;
    p = Player(pos=Vec3(x=64.0, y=128.0, z=56.0));
    p +>: In :+> a;
    assert area_of(p) is a;

    move_to_area(p, b);
    assert area_of(p) is b;
    # exactly one In edge survives the rewire
    assert len([edge p ->:In:->]) == 1;
}


test "think pass reaches every entity in the world" {
    w = World();
    a = make_area("a", 0.0, 256.0);
    b = make_area("b", 256.0, 512.0);
    w ++> a;
    w ++> b;
    p = Player();
    e1 = Entity();
    e2 = Entity();
    p +>: In :+> a;
    e1 +>: In :+> a;
    e2 +>: In :+> b;

    tp = w spawn ThinkPass(dt=0.05);
    assert tp.entities_visited == 3;
}
