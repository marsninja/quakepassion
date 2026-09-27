"""Q2 accelerated moves (g_func.c Think_AccelMove) for plats and doors."""
import from engine.world.mover_ramp { MoverRamp, q2_mover_ramp, ramp_step, ramp_rest }
import from engine.world.doors { Door, HasDoor }
import from tests.door_support { DoorFixture }
import from engine.core.savegame { snapshot, restore }
import from engine.world.world { Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.math.vec3 { Vec3 }

test "Q2 plats always ramp; doors only with authored accel or decel" {
    plat = q2_mover_ramp("func_plat", {}, 200.0);
    assert plat is not None and plat.accel == 5.0 and plat.decel == 5.0;
    authored = q2_mover_ramp("func_plat", {"accel": "250", "decel": "30"}, 150.0);
    assert authored is not None and authored.accel == 25.0 and authored.decel == 3.0;
    assert q2_mover_ramp("func_door", {}, 100.0) is None;
    assert q2_mover_ramp("func_door", {"accel": "100"}, 100.0) is None;
    door = q2_mover_ramp("func_door", {"accel": "20"}, 100.0);
    assert door is not None and door.accel == 2.0 and door.decel == 10.0;
    assert q2_mover_ramp("func_train", {"accel": "20"}, 100.0) is None;
}

test "a ramped move follows Think_AccelMove frame by frame at 120 Hz" {
    ramp = MoverRamp(accel=5.0, decel=5.0);
    # 120 units at 200 a second: still for a frame, then 5, 10, 15, 20, 20,
    # 20, 15, 10 and 5 units a frame.
    expected = [0.0, 5.0, 15.0, 30.0, 50.0, 70.0, 90.0, 105.0, 115.0, 120.0];
    moved = 0.0;
    for frame in range(10) {
        for tick in range(12) {
            moved += ramp_step(ramp, 1, 120.0 - moved, 200.0, 1.0 / 120.0);
        }
        assert abs(moved - expected[frame]) < 0.0001;
    }
    # A reversal starts again from rest.
    back = ramp_step(ramp, -1, 120.0, 200.0, 0.05);
    assert back == 0.0 and ramp.heading == -1;
    ramp_rest(ramp);
    assert ramp.heading == 0 and ramp.current_speed == 0.0;
}

test "a short ramped move and a slow one finish exactly" {
    short = MoverRamp(accel=5.0, decel=5.0);
    moved = 0.0;
    for tick in range(60) {
        moved += ramp_step(short, 1, 10.0 - moved, 200.0, 1.0 / 120.0);
    }
    assert abs(moved - 10.0) < 0.0001;
    # 64 units at 64 a second: 5 then 6.4 a frame, landing 1.4 short of ten
    # full frames (1.2 s in all).
    slow = MoverRamp(accel=5.0, decel=5.0);
    moved = 0.0;
    for tick in range(143) {
        moved += ramp_step(slow, 1, 64.0 - moved, 64.0, 1.0 / 120.0);
    }
    assert moved < 64.0 and moved > 62.5;
    moved += ramp_step(slow, 1, 64.0 - moved, 64.0, 1.0 / 120.0);
    assert abs(moved - 64.0) < 0.0001;
}

test "Q2 plats in the level ramp; Q1 plats keep their constant speed" {
    for game in ["q1", "q2"] {
        fixture = DoorFixture();
        fixture.setup(game, {"classname": "func_plat", "height": "64", "speed": "64", "targetname": "lift"});
        platform = [fixture.world->:HasDoor:->][?:Door][0];
        assert (platform.ramp is not None) == (game == "q2");
    }
}

test "a ramped move saves mid-flight and resumes the same way" {
    f = DoorFixture();
    f.setup("q2", {"classname": "func_plat", "height": "64", "speed": "64", "targetname": "lift"});
    plat = [f.world->:HasDoor:->][?:Door][0];
    plat.activation.pending = 1;
    for i in range(30) {
        f.tick(Vec3(x=500.0), 1.0 / 120.0);
    }
    level = Level(bsp=f.bsp, collision=f.collision, name="ramp");
    player = Player();
    combat = CombatState();
    saved = snapshot(f.world, level, player, combat);
    for i in range(24) {
        f.tick(Vec3(x=500.0), 1.0 / 120.0);
    }
    later = plat.position;
    restore(f.world, level, player, combat, saved);
    ramp = plat.ramp;
    assert ramp is not None and ramp.heading == -1 and ramp.current_speed > 0.0;
    for i in range(24) {
        f.tick(Vec3(x=500.0), 1.0 / 120.0);
    }
    assert abs(plat.position - later) < 0.000001;
    # Older saves without the ramp columns still load, starting from rest.
    lines = [line for line in saved.splitlines()];
    for i in range(len(lines)) {
        if lines[i].startswith("D ") {
            words = lines[i].split();
            lines[i] = " ".join(words[:len(words) - 6]);
        }
    }
    restore(f.world, level, player, combat, "\n".join(lines) + "\n");
    assert ramp.heading == 0;
}
