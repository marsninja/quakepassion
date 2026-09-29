import from engine.physics.collision { HullCell, HullFront, HullBack, CollisionMap }
import from engine.physics.movement { slide, step_slide, MovePlayer, movement_profile }
import from engine.math.vec3 { Vec3 }
import from engine.world.world { Player }

def halfspace(normal: Vec3, distance: float) -> HullCell {
    cell = HullCell(normal=normal, distance=distance);
    empty = HullCell(contents=-1);
    solid = HullCell(contents=-2);
    cell +>:HullFront:+> empty;
    cell +>:HullBack:+> solid;
    return cell;
}

def floor_map() -> CollisionMap {
    return CollisionMap(hulls=[halfspace(Vec3(z=1.0), 24.0)], offsets=[Vec3()]);
}

test "sweep stops at a plane without tunneling" {
    collision = floor_map();
    hit = collision.trace(Vec3(z=100.0), Vec3(z=-1000.0));
    assert hit.fraction > 0.0 and hit.fraction < 1.0;
    assert abs(hit.end.z - 24.03125) < 0.0001;
    assert hit.normal.z == 1.0;
    assert not hit.start_solid;
    assert collision.trace(Vec3(z=25.0), Vec3(x=100.0, z=25.0)).fraction == 1.0;
}

test "solid starts reject motion and translated hulls collide" {
    collision = floor_map();
    assert collision.trace(Vec3(), Vec3(z=100.0)).start_solid;
    collision.offsets[0] = Vec3(z=10.0);
    hit = collision.trace(Vec3(z=100.0), Vec3());
    assert abs(hit.end.z - 34.03125) < 0.0001;
}

test "sliding preserves tangent motion and corners stop both axes" {
    collision = CollisionMap(
        hulls=[halfspace(Vec3(x=1.0), 0.0), halfspace(Vec3(y=1.0), 0.0)],
        offsets=[Vec3(), Vec3()]
    );
    moved = slide(collision, Vec3(x=10.0, y=10.0), Vec3(x=-200.0, y=100.0), 0.1);
    assert moved.pos.x > 0.0 and moved.pos.x < 0.04;
    assert moved.pos.y > 19.0;
    corner = slide(collision, Vec3(x=10.0, y=10.0), Vec3(x=-200.0, y=-200.0), 0.1);
    assert corner.pos.x >= 0.0 and corner.pos.y >= 0.0;
    assert corner.velocity.length() < 0.001;
}

test "gravity lands the player and jump clears the floor" {
    collision = floor_map();
    player = Player(pos=Vec3(z=100.0));
    for i in range(240) {
        player spawn MovePlayer(collision=collision);
    }
    assert abs(player.pos.z - 46.03125) < 0.001;
    assert player.grounded;
    player spawn MovePlayer(collision=collision, jump=True);
    assert player.pos.z > 46.1 and player.velocity.z > 0.0;
    for i in range(240) {
        player spawn MovePlayer(collision=collision);
    }
    assert player.grounded and abs(player.pos.z - 46.03125) < 0.001;
}

test "standing player steps onto an eighteen unit ledge" {
    floor = halfspace(Vec3(z=1.0), 24.0);
    ledge = HullCell(normal=Vec3(x=-1.0), distance=-10.0);
    empty = HullCell(contents=-1);
    top = halfspace(Vec3(z=1.0), 40.0);
    ledge +>:HullFront:+> empty;
    ledge +>:HullBack:+> top;
    collision = CollisionMap(hulls=[floor, ledge], offsets=[Vec3(), Vec3()]);
    moved = step_slide(collision, Vec3(z=24.03125), Vec3(x=200.0), 0.1, True);
    assert moved.pos.x > 19.0;
    assert abs(moved.pos.z - 40.03125) < 0.001;
}

test "contact at the starting plane is blocked but not embedded" {
    hit = floor_map().trace(Vec3(z=24.0), Vec3(z=0.0));
    assert not hit.start_solid;
    assert hit.fraction == 0.0 and hit.normal.z == 1.0;
}

test "high ledges and low ceilings prevent stepping" {
    floor = halfspace(Vec3(z=1.0), 24.0);
    ledge = HullCell(normal=Vec3(x=-1.0), distance=-10.0);
    empty = HullCell(contents=-1);
    top = halfspace(Vec3(z=1.0), 44.0);
    ledge +>:HullFront:+> empty;
    ledge +>:HullBack:+> top;
    collision = CollisionMap(hulls=[floor, ledge], offsets=[Vec3(), Vec3()]);
    moved = step_slide(collision, Vec3(z=24.03125), Vec3(x=200.0), 0.1, True);
    assert moved.pos.x < 10.0;
    top.distance = 40.0;
    collision.hulls.append(halfspace(Vec3(z=-1.0), -35.0));
    collision.offsets.append(Vec3());
    moved = step_slide(collision, Vec3(z=24.03125), Vec3(x=200.0), 0.1, True);
    assert moved.pos.x < 10.0;
}

test "walkable slopes ground the player while steep slopes do not" {
    gentle = CollisionMap(hulls=[halfspace(Vec3(x=0.6, z=0.8), 0.0)], offsets=[Vec3()]);
    player = Player(pos=Vec3(z=22.04));
    player spawn MovePlayer(collision=gentle);
    assert player.grounded;
    steep = CollisionMap(hulls=[halfspace(Vec3(x=0.8, z=0.6), 0.0)], offsets=[Vec3()]);
    player = Player(pos=Vec3(z=22.04));
    player spawn MovePlayer(collision=steep);
    assert not player.grounded;
}

"""A 35 degree ramp rising along +x (walkable: normal z 0.82), topped by a
flat floor at z 40 when `crest` is set."""
def ramp_map(crest: bool) -> CollisionMap {
    ramp = HullCell(normal=Vec3(x=-0.573576, z=0.819152), distance=0.0);
    ramp +>:HullFront:+> HullCell(contents=-1);
    if crest {
        ramp +>:HullBack:+> halfspace(Vec3(z=1.0), 40.0);
    } else {
        ramp +>:HullBack:+> HullCell(contents=-2);
    }
    return CollisionMap(hulls=[ramp], offsets=[Vec3()]);
}

test "walking up and down a ramp stays on the ground at full speed" {
    for heading in [1.0, -1.0] {
        for game in ["q1", "q2", "q3"] {
            collision = ramp_map(False);
            player = Player(pos=Vec3(z=22.04));
            for i in range(240) {
                player spawn MovePlayer(collision=collision, wish=Vec3(x=heading), profile=movement_profile(game));
                assert player.grounded;
            }
            start = player.pos.x;
            player spawn MovePlayer(collision=collision, wish=Vec3(x=heading), profile=movement_profile(game));
            assert abs(abs(player.pos.x - start) - 320.0 / 120.0) < 0.01;
        }
    }
}

test "a jump still leaves a ramp" {
    collision = ramp_map(False);
    player = Player(pos=Vec3(z=22.04));
    player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), jump=True, profile=movement_profile("q1"));
    player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=movement_profile("q1"));
    assert not player.grounded and player.velocity.z > 0.0;
}

test "Q1 and Q2 walk over a ramp's crest while Q3 kicks off it" {
    for game in ["q1", "q2", "q3"] {
        collision = ramp_map(True);
        player = Player(pos=Vec3(x=-40.0, z=-28.0 + 22.04));
        airborne = 0;
        for i in range(120) {
            player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=movement_profile(game));
            if not player.grounded {
                airborne += 1;
            }
        }
        assert player.pos.x > 200.0 and abs(player.pos.z - 62.03125) < 0.001;
        assert (airborne > 0) == (game == "q3");
    }
}

test "cyclic collision graphs report invalid geometry" {
    cycle = HullCell(normal=Vec3(z=1.0));
    empty = HullCell(contents=-1);
    cycle +>:HullFront:+> cycle;
    cycle +>:HullBack:+> empty;
    collision = CollisionMap(hulls=[cycle], offsets=[Vec3()]);
    failed = False;
    try {
        collision.trace(Vec3(z=10.0), Vec3(z=20.0));
    } except ValueError {
        failed = True;
    }
    assert failed;
}

"""A Q1-style clip hull, top down: open above z=60, a slab from 50 to 60
(split at 55 into two solid leaves when `split`), open from 0 to 50 and
solid below the floor at 0."""
def slab_map(split: bool) -> CollisionMap {
    top = HullCell(normal=Vec3(z=1.0), distance=60.0);
    slab = HullCell(normal=Vec3(z=1.0), distance=50.0);
    ground = halfspace(Vec3(z=1.0), 0.0);
    top +>:HullFront:+> HullCell(contents=-1);
    top +>:HullBack:+> slab;
    if split {
        halves = HullCell(normal=Vec3(z=1.0), distance=55.0);
        halves +>:HullFront:+> HullCell(contents=-2);
        halves +>:HullBack:+> HullCell(contents=-2);
        slab +>:HullFront:+> halves;
    } else {
        slab +>:HullFront:+> HullCell(contents=-2);
    }
    slab +>:HullBack:+> ground;
    return CollisionMap(hulls=[top], offsets=[Vec3()]);
}

test "an escaping trace leaves the solid it starts in as SV_RecursiveHullCheck does" {
    collision = slab_map(False);
    # Normally a start in solid is where the trace ends.
    stuck = collision.trace(Vec3(z=55.0), Vec3(z=-45.0));
    assert stuck.start_solid and stuck.fraction == 0.0;
    # Escaping, it runs on out of the slab and stops on the floor below.
    out = collision.trace(Vec3(z=55.0), Vec3(z=-45.0), escape=True);
    assert out.start_solid and not out.all_solid;
    assert abs(out.end.z - 0.03125) < 0.0001 and out.normal.z == 1.0;
    # Out of the slab with nothing below: no floor, fraction 1.
    open = collision.trace(Vec3(z=55.0), Vec3(z=20.0), escape=True);
    assert open.start_solid and not open.all_solid and open.fraction == 1.0;
    # Never out of it: all solid.
    buried = collision.trace(Vec3(z=58.0), Vec3(z=52.0), escape=True);
    assert buried.all_solid and buried.fraction == 1.0;
    # From open space an escaping trace is an ordinary one.
    above = collision.trace(Vec3(z=100.0), Vec3(z=0.0), escape=True);
    assert not above.start_solid and abs(above.end.z - 60.03125) < 0.0001;
    # Solid meeting solid before any open space gives up all solid, even
    # though open space lies beyond ("never got out of the solid area").
    halves = slab_map(True).trace(Vec3(z=57.0), Vec3(z=-43.0), escape=True);
    assert halves.all_solid and halves.fraction == 1.0;
}

test "an escaping trace leaves a brush it starts in" {
    collision = CollisionMap();
    for bounds in [(50.0, 60.0), (-64.0, 0.0)] {
        collision.add_brush(
            [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
            [1000.0, 1000.0, 1000.0, 1000.0, bounds[1], -bounds[0]],
            Vec3(),
            Vec3(),
            Vec3()
        );
    }
    collision.models = [0, 0];
    collision.reindex();
    out = collision.trace(Vec3(z=55.0), Vec3(z=-45.0), escape=True, point=True);
    assert out.start_solid and not out.all_solid and abs(out.end.z) < 0.0001;
    buried = collision.trace(Vec3(z=58.0), Vec3(z=52.0), escape=True, point=True);
    assert buried.all_solid;
}
