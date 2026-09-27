"""Stepping onto (and off) a platform eases the view up the step, as each
game's client does, instead of jumping the eye there in one tick."""
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.world { Player }
import from engine.render.view_feedback { ViewFeedback }
import from engine.physics.collision { HullCell, HullFront, HullBack, CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

def halfspace(normal: Vec3, distance: float) -> HullCell {
    cell = HullCell(normal=normal, distance=distance);
    empty = HullCell(contents=-1);
    solid = HullCell(contents=-2);
    cell +>:HullFront:+> empty;
    cell +>:HullBack:+> solid;
    return cell;
}

test "a move reports the height of the step it climbed" {
    floor = halfspace(Vec3(z=1.0), 24.0);
    ledge = HullCell(normal=Vec3(x=-1.0), distance=-10.0);
    empty = HullCell(contents=-1);
    top = halfspace(Vec3(z=1.0), 32.0);
    ledge +>:HullFront:+> empty;
    ledge +>:HullBack:+> top;
    collision = CollisionMap(hulls=[floor, ledge], offsets=[Vec3(), Vec3()]);
    player = Player(pos=Vec3(x=-20.0, z=24.03125 + collision.eye_height));
    player spawn MovePlayer(collision=collision, game="q1");
    steps: list[float] = [];
    for tick in range(60) {
        moved = player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), game="q1");
        if moved.stepped > 0.0 {
            steps.append(moved.stepped);
        }
    }
    assert player.pos.x > 20.0;
    assert len(steps) == 1 and abs(steps[0] - 8.0) < 0.001;
}

test "walking onto a Q1 plat eases the eye up its lip and the ride" {
    fixture = DoorFixture();
    fixture.setup("q1", {"classname": "func_plat", "height": "64", "speed": "64"});
    # A floor eight units below the lowered plat's top (plats.qc's lip).
    fixture.collision.add_brush(
        [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ],
        [512.0, 512.0, 512.0, 512.0, 24.0, 64.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    fixture.collision.models.append(0);
    fixture.collision.reindex();
    platform = [fixture.world->:HasDoor:->][?:Door][0];
    eye_height = fixture.collision.eye_height;
    player = Player(pos=Vec3(x=-48.0, z=48.03125 + eye_height));
    view = ViewFeedback();
    view.reset("q1");
    dt = 1.0 / 120.0;
    body_jump = 0.0;
    eye_rise = 0.0;
    lag = 0.0;
    eye = player.pos.z - view.climb(player.pos.z, True, 0.0);
    for tick in range(480) {
        before = player.pos.z;
        fixture.world spawn DoorTick(
            bsp=fixture.bsp,
            collision=fixture.collision,
            player_origin=player.pos.sub(Vec3(z=eye_height)),
            player=player,
            dt=dt
        );
        view.ride(player.pos.z - before);
        moved = player spawn MovePlayer(
            collision=fixture.collision,
            wish=Vec3(x=1.0) if player.pos.x < 0.0 else Vec3(),
            steady=True,
            game="q1",
            dt=dt
        );
        view.step(moved.stepped);
        view.advance(dt);
        seen = player.pos.z - view.climb(player.pos.z, player.grounded, dt);
        body_jump = max(body_jump, player.pos.z - before);
        eye_rise = max(eye_rise, seen - eye);
        if platform.state == "opening" {
            lag = max(lag, player.pos.z - seen);
        }
        eye = seen;
    }
    # The body (walking a steady stride to the centre and stopping there)
    # pops up the eight-unit lip in one tick, then rides 64 units.
    assert body_jump > 7.9;
    assert platform.state == "open";
    assert abs(player.pos.z - (48.03125 + 8.0 + 64.0 + eye_height)) < 0.001;
    # V_CalcRefdef: the eye eases up the lip at 80 units a second, rides the
    # plat with it and has caught up once the plat stops.
    assert eye_rise <= (80.0 + 64.0) * dt + 0.00001;
    assert lag < 8.0;
    assert eye == player.pos.z;
}

test "Q1 keeps the eye at most 12 units behind and drops it with the body" {
    view = ViewFeedback();
    view.reset("q1");
    assert view.climb(100.0, True, 0.05) == 0.0;
    assert abs(view.climb(108.0, True, 0.05) - 4.0) < 0.00001;
    assert view.climb(108.0, True, 0.05) == 0.0;
    # An 18-unit step (off the top of a lift still rising) starts 12 behind.
    assert abs(view.climb(126.0, True, 0.01) - 12.0) < 0.00001;
    assert view.climb(126.0, False, 0.01) == 0.0;
    view.climb(140.0, True, 0.01);
    assert view.climb(100.0, True, 0.01) == 0.0;
    view.reset("q1");
    assert view.climb(300.0, True, 0.01) == 0.0;
}

test "a Q1 lift carries the eye rigidly, keeping the ease for a step off it" {
    view = ViewFeedback();
    view.reset("q1");
    z = 0.0;
    view.climb(z, True, 0.0);
    for frame in range(120) {
        z += 1.25;
        view.ride(1.25);
        assert abs(view.climb(z, True, 1.0 / 120.0)) < 0.00001;
    }
    # Stepping 17 units onto the landing before the lift arrives: the eye
    # moves 5 at once and eases the other 12.
    z += 17.0;
    assert abs(view.climb(z, True, 0.0) - 12.0) < 0.00001;
    q3 = ViewFeedback();
    q3.reset("q3");
    q3.ride(40.0);
    assert q3.climb(40.0, True, 0.0) == 0.0;
}

test "Q2 eases 8 to 20 unit steps over 100 ms; Q3 rounds and stacks over 200" {
    q2 = ViewFeedback();
    q2.reset("q2");
    q2.step(8.0);
    assert abs(q2.climb(0.0, True, 0.0) - 8.0) < 0.00001;
    q2.advance(0.05);
    assert abs(q2.climb(0.0, True, 0.05) - 4.0) < 0.00001;
    q2.advance(0.05);
    assert q2.climb(0.0, True, 0.05) == 0.0;
    q2.step(7.0);
    q2.step(20.0);
    assert q2.climb(0.0, True, 0.0) == 0.0;
    q3 = ViewFeedback();
    q3.reset("q3");
    q3.step(1.5);
    assert q3.climb(0.0, True, 0.0) == 0.0;
    q3.step(9.0);
    assert abs(q3.climb(0.0, True, 0.0) - 8.0) < 0.00001;
    q3.advance(0.1);
    assert abs(q3.climb(0.0, True, 0.1) - 4.0) < 0.00001;
    # CG_StepEvent adds what is left of the last step, up to 32.
    q3.step(5.0);
    assert abs(q3.climb(0.0, True, 0.0) - 8.0) < 0.00001;
    q3.step(18.0);
    q3.step(18.0);
    q3.step(18.0);
    assert abs(q3.climb(0.0, True, 0.0) - 32.0) < 0.00001;
    q3.advance(0.2);
    assert q3.climb(0.0, True, 0.2) == 0.0;
}
