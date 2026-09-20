import from engine.physics.collision { HullCell, HullFront, HullBack, CollisionMap }
import from engine.physics.movement { slide, step_slide, MovePlayer }
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
