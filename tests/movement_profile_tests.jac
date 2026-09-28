import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { MovePlayer, SetStance, MovementProfile, movement_profile }
import from engine.formats.bsp { Bsp, Model, Brush, Plane }
import from engine.formats.brush_collision { build_brush_collision }
import from engine.world.liquids { load_liquids }
import from engine.world.level { Level }
import from engine.world.world { Player }
import from engine.math.vec3 { Vec3 }

glob MP_TICK: float = 1.0 / 120.0;

"""A standing player's box (the hulls here are expanded by it)."""
def mp_mins() -> Vec3 {
    return Vec3(x=-16.0, y=-16.0, z=-24.0);
}

def mp_maxs() -> Vec3 {
    return Vec3(x=16.0, y=16.0, z=32.0);
}

"""A floor whose top is z 0, running out to x = `reach`."""
def mp_floor(reach: float = 4000.0) -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-4000.0, y=-4000.0, z=-64.0),
        Vec3(x=reach, y=4000.0, z=0.0),
        Vec3(),
        mp_mins(),
        mp_maxs()
    );
    collision.reindex();
    return collision;
}

"""A player standing on the floor at `x` (eye 22 above the origin)."""
def mp_standing(x: float = 0.0, velocity: Vec3 = Vec3()) -> Player {
    return Player(pos=Vec3(x=x, z=24.03125 + 22.0), velocity=velocity, grounded=True);
}

test "each game rubs its own ground friction off a slide" {
    for row in [("q1", 290.0), ("q2", 285.0), ("q3", 285.0)] {
        player = mp_standing(velocity=Vec3(x=300.0));
        player spawn MovePlayer(collision=mp_floor(), profile=movement_profile(row[0]));
        assert player.grounded and abs(player.velocity.x - row[1]) < 0.01;
    }
}

test "Q1 doubles its friction over a drop-off ahead" {
    collision = mp_floor(20.0);
    player = mp_standing(10.0, Vec3(x=300.0));
    player spawn MovePlayer(collision=collision, profile=movement_profile("q1"));
    assert abs(player.velocity.x - 280.0) < 0.01;
    # Heading back over the floor the friction is normal again.
    player = mp_standing(10.0, Vec3(x=-300.0));
    player spawn MovePlayer(collision=collision, profile=movement_profile("q1"));
    assert abs(player.velocity.x + 290.0) < 0.01;
}

test "Q1 air control steers at full strength toward a 30 unit wish" {
    for row in [("q1", 320.0 * 10.0 / 120.0), ("q2", 320.0 / 120.0), ("q3", 320.0 / 120.0)] {
        player = Player(pos=Vec3(z=1000.0), velocity=Vec3(x=320.0));
        player spawn MovePlayer(
            collision=CollisionMap(), wish=Vec3(y=1.0), profile=movement_profile(row[0])
        );
        assert abs(player.velocity.y - row[1]) < 0.001;
        assert abs(player.velocity.x - 320.0) < 0.001;
    }
    # Turning the wish with the flight path gains speed past the run speed.
    player = Player(pos=Vec3(z=100000.0), velocity=Vec3(x=320.0));
    for i in range(120) {
        heading = Vec3(x=player.velocity.x, y=player.velocity.y).normalized();
        player spawn MovePlayer(
            collision=CollisionMap(),
            wish=Vec3(x=-heading.y, y=heading.x),
            profile=movement_profile("q1")
        );
    }
    assert Vec3(x=player.velocity.x, y=player.velocity.y).length() > 420.0;
}

test "each game's run and crouch speeds" {
    for row in [("q1", 320.0, 320.0), ("q2", 300.0, 100.0), ("q3", 320.0, 80.0)] {
        rules = movement_profile(row[0]);
        collision = mp_floor();
        collision.eye_height = rules.stand_eye_height;
        player = Player(pos=Vec3(z=24.03125 + rules.stand_eye_height), grounded=True);
        player spawn SetStance(collision=collision, profile=rules, crouch=False, dt=MP_TICK);
        assert player.walk_speed == row[1];
        for i in range(240) {
            player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=rules);
        }
        assert player.grounded and abs(player.velocity.x - row[1]) < 0.01;
        for i in range(240) {
            player spawn SetStance(collision=collision, profile=rules, crouch=True, dt=MP_TICK);
            player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=rules);
        }
        assert player.crouched == (row[0] != "q1");
        assert abs(player.velocity.x - row[2]) < 0.01;
    }
    # In the air a Q2 crouch still caps the wish; Q3 PM_AirMove does not.
    for row in [("q2", 100.0 / 120.0), ("q3", 320.0 / 120.0)] {
        player = Player(pos=Vec3(z=1000.0), crouched=True);
        player spawn MovePlayer(
            collision=CollisionMap(), wish=Vec3(x=1.0), profile=movement_profile(row[0])
        );
        assert abs(player.velocity.x - row[1]) < 0.001;
    }
}

test "Q3 wading slows the walk by the water's depth" {
    for row in [("q1", 320.0), ("q2", 320.0), ("q3", 320.0 * (1.0 - 0.5 / 3.0))] {
        player = mp_standing();
        for i in range(360) {
            player spawn MovePlayer(
                collision=mp_floor(),
                wish=Vec3(x=1.0),
                water_depth=1,
                profile=movement_profile(row[0])
            );
        }
        assert abs(player.velocity.x - row[1]) < 0.01;
    }
}

test "each game swims at its own speed and sinks at its own drift" {
    for row in [("q1", 224.0, 42.0), ("q2", 150.0, 30.0), ("q3", 160.0, 60.0)] {
        rules = movement_profile(row[0]);
        swimmer = Player(pos=Vec3(z=1000.0), walk_speed=rules.max_speed);
        for i in range(360) {
            swimmer spawn MovePlayer(
                collision=CollisionMap(), water_depth=3, swim_wish=Vec3(x=1.0), profile=rules
            );
        }
        assert abs(swimmer.velocity.length() - row[1]) < 0.01;
        sinker = Player(pos=Vec3(z=1000.0), walk_speed=rules.max_speed);
        for i in range(600) {
            sinker spawn MovePlayer(collision=CollisionMap(), water_depth=3, profile=rules);
        }
        assert abs(sinker.velocity.z + row[2]) < 0.01;
    }
}

test "Q1 and Q2 swimmers jump up out of the depths while Q3 ones do not" {
    for game in ["q1", "q2", "q3"] {
        swimmer = Player(pos=Vec3(z=1000.0), liquid_kind=1);
        swimmer spawn MovePlayer(
            collision=CollisionMap(), water_depth=3, jump=True, profile=movement_profile(game)
        );
        assert (swimmer.velocity.z > 90.0) == (game != "q3");
    }
    # Q2 PM_CheckJump waits for the button's release; lava lifts at 50.
    held = Player(pos=Vec3(z=1000.0), liquid_kind=1, jump_held=True);
    held spawn MovePlayer(
        collision=CollisionMap(), water_depth=3, jump=True, profile=movement_profile("q2")
    );
    assert held.velocity.z < 0.0;
    lava = Player(pos=Vec3(z=1000.0), liquid_kind=3);
    lava spawn MovePlayer(
        collision=CollisionMap(), water_depth=3, jump=True, profile=movement_profile("q1")
    );
    assert lava.velocity.z > 45.0 and lava.velocity.z < 50.0;
}

"""A floor, and a ladder face at x 32 rising to `top` in front of a ledge
whose floor is at `top`."""
def mp_ladder(top: float) -> CollisionMap {
    collision = mp_floor();
    collision.add_box(
        Vec3(x=32.0, y=-4000.0, z=-64.0),
        Vec3(x=4000.0, y=4000.0, z=top),
        Vec3(),
        mp_mins(),
        mp_maxs()
    );
    collision.hulls[-1].climbable = True;
    collision.reindex();
    return collision;
}

test "Q2 ladders climb looking up or down while pressing forward" {
    rules = movement_profile("q2");
    collision = mp_ladder(4000.0);
    player = Player(pos=Vec3(x=15.9, z=24.03125 + 22.0), pitch=0.5, walk_speed=300.0);
    climbed = False;
    for i in range(120) {
        moved = player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=rules);
        climbed = climbed or moved.climbing;
    }
    # Ground friction and the 200 limit keep the climb just under 200.
    assert climbed and player.velocity.z > 150.0 and player.velocity.z < 210.0;
    assert player.pos.z > 24.0 + 22.0 + 150.0;
    # Letting go, the climber hangs on without gravity.
    for i in range(60) {
        player spawn MovePlayer(collision=collision, profile=rules);
    }
    height = player.pos.z;
    for i in range(60) {
        player spawn MovePlayer(collision=collision, profile=rules);
    }
    assert player.velocity.z == 0.0 and abs(player.pos.z - height) < 0.001;
    # Crouch (upmove down) and looking down climb down.
    player spawn MovePlayer(collision=collision, upmove=-1.0, profile=rules);
    assert player.velocity.z < 0.0;
    player.pitch = -0.5;
    for i in range(60) {
        player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=rules);
    }
    assert player.velocity.z < -150.0 and player.velocity.z > -210.0;
    # Q1 and Q3 have no ladders: the same wall is only a wall.
    for game in ["q1", "q3"] {
        strider = Player(pos=Vec3(x=15.9, z=24.03125 + 22.0), pitch=0.5, grounded=True);
        for i in range(60) {
            strider spawn MovePlayer(
                collision=collision, wish=Vec3(x=1.0), profile=movement_profile(game)
            );
        }
        assert strider.grounded and abs(strider.pos.z - 46.03125) < 0.001;
    }
}

test "Q2 climbs off the top of a ladder onto its ledge" {
    rules = movement_profile("q2");
    collision = mp_ladder(100.0);
    player = Player(pos=Vec3(x=15.9, z=24.03125 + 22.0), pitch=0.5, walk_speed=300.0);
    for i in range(480) {
        player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), profile=rules);
    }
    assert player.grounded and player.pos.x > 48.0;
    assert abs(player.pos.z - (124.03125 + 22.0)) < 0.001;
}

test "Q2 currents carry swimmers and waders, and conveyors walkers" {
    swimmer = Player(pos=Vec3(z=1000.0), walk_speed=300.0);
    for i in range(360) {
        swimmer spawn MovePlayer(
            collision=CollisionMap(),
            water_depth=3,
            current=Vec3(x=1.0),
            profile=movement_profile("q2")
        );
    }
    assert swimmer.velocity.x > 140.0 and swimmer.velocity.x < 150.0;
    still = Player(pos=Vec3(z=1000.0));
    still spawn MovePlayer(
        collision=CollisionMap(), water_depth=3, current=Vec3(x=1.0), profile=movement_profile("q3")
    );
    assert still.velocity.x == 0.0;
    # A wader standing on the bottom feels half the current.
    wader = mp_standing();
    wader.walk_speed = 300.0;
    for i in range(240) {
        wader spawn MovePlayer(
            collision=mp_floor(), water_depth=1, current=Vec3(y=-1.0), profile=movement_profile("q2")
        );
    }
    assert wader.grounded and abs(wader.velocity.y + 200.0) < 0.01;
    belt = mp_floor();
    belt.hulls[0].conveyor = Vec3(y=1.0);
    rider = mp_standing();
    rider.walk_speed = 300.0;
    for i in range(240) {
        rider spawn MovePlayer(collision=belt, profile=movement_profile("q2"));
    }
    assert abs(rider.velocity.y - 100.0) < 0.01;
}

test "Q1 rubs speed off a wall the view faces" {
    collision = mp_floor();
    collision.add_box(
        Vec3(x=32.0, y=-4000.0, z=-64.0),
        Vec3(x=64.0, y=4000.0, z=4000.0),
        Vec3(),
        mp_mins(),
        mp_maxs()
    );
    collision.reindex();
    along: dict[str, float] = {};
    for game in ["q1", "q2"] {
        player = mp_standing(15.0, Vec3(x=200.0, y=200.0));
        player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0, y=1.0).normalized(), profile=movement_profile(game));
        along[game] = player.velocity.y;
    }
    assert along["q2"] > 190.0 and along["q1"] < along["q2"] * 0.6;
}

test "Q3 knockback skids without friction; Q1 and Q2 rub it off" {
    for row in [("q3", True), ("q2", False), ("q1", False)] {
        player = mp_standing(velocity=Vec3(x=300.0));
        player.knockback_time = 0.1;
        player spawn MovePlayer(collision=mp_floor(), profile=movement_profile(row[0]));
        assert (player.velocity.x > 299.0) == row[1];
    }
}

"""A Q2/Q3 map with one brush of `contents` spanning x -10..10."""
def mp_brush_map(game: str, contents: int) -> Bsp {
    bsp = Bsp(game=game, models=[Model(head=-1, first_face=0, face_count=0, brushes=[0])]);
    for n in [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)] {
        bsp.planes.append(Plane(normal=n, distance=10.0));
    }
    bsp.brushes = [Brush(planes=[0, 1, 2, 3, 4, 5], contents=contents)];
    return bsp;
}

test "Q2 brush contents mark ladders and conveyors for traces" {
    # CONTENTS_PLAYERCLIP | MONSTERCLIP | DETAIL | LADDER, as most Q2 ladders are.
    ladder = build_brush_collision(mp_brush_map("q2", 0x28030000));
    hit = ladder.trace(Vec3(x=-40.0), Vec3(x=0.0));
    assert hit.fraction < 1.0 and hit.climbable and hit.conveyor is None;
    # Q3 reads the same bits differently: no ladder.
    plain = build_brush_collision(mp_brush_map("q3", 0x20000001));
    assert not plain.trace(Vec3(x=-40.0), Vec3(x=0.0)).climbable;
    # A window with CONTENTS_CURRENT_DOWN (city3) carries a downward conveyor.
    window = build_brush_collision(mp_brush_map("q2", 0x18800002));
    belt = window.trace(Vec3(z=80.0), Vec3(z=0.0)).conveyor;
    assert belt is not None and belt.z == -1.0 and belt.x == 0.0;
}

test "Q2 water currents reach the immersion at the feet" {
    # CONTENTS_WATER | CURRENT_90 | DETAIL | TRANSLUCENT, as in cool1.
    level = Level(active=True, bsp=mp_brush_map("q2", 0x18080020));
    level.liquids = load_liquids(level.bsp);
    state = level.immersion(Vec3(z=45.0));
    assert state.depth >= 1 and state.kind == 1;
    assert state.current.y == 1.0 and state.current.x == 0.0 and state.current.z == 0.0;
    dry = level.immersion(Vec3(z=200.0));
    assert dry.depth == 0 and dry.current.length() == 0.0;
    arena = Level(active=True, bsp=mp_brush_map("q3", 0x80020));
    arena.liquids = load_liquids(arena.bsp);
    wet = arena.immersion(Vec3(z=45.0));
    assert wet.depth >= 1 and wet.current.length() == 0.0;
}

test "monsters keep the shared walk" {
    rules = movement_profile("");
    assert rules.max_speed == 320.0 and rules.friction == 6.0;
    assert rules.air_accelerate == 1.0 and rules.swim_accelerate == 4.0;
    assert not rules.climbs_ladders and not rules.can_duck;
    strider = mp_standing();
    for i in range(240) {
        strider spawn MovePlayer(collision=mp_floor(), wish=Vec3(x=1.0), profile=MovementProfile());
    }
    assert abs(strider.velocity.x - 320.0) < 0.01;
}
