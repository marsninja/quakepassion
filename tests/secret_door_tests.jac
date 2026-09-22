import from engine.world.secret_doors { load_secret_doors }
import from engine.world.trains { Train, HasTrain, TrainTick, ShootMover }
import from engine.world.doors { connect_targets }
import from engine.world.signals { Signal, Targets }
import from engine.world.world { Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

def secret_fixture(flags: int = 0, named: bool = False) -> DoorFixture {
    f = DoorFixture();
    f.setup(
        "q1",
        {
            "classname": "func_door_secret",
            "angle": "0",
            "wait": "5",
            "spawnflags": str(flags),
            "targetname": "remote" if named else ""
        }
    );
    f.bsp.models[1].mins = Vec3(x=-8.0, y=-32.0, z=0.0);
    f.bsp.models[1].maxs = Vec3(x=8.0, y=32.0, z=96.0);
    load_secret_doors(f.world, f.bsp, f.collision);
    connect_targets(f.world, f.bsp);
    return f;
}

test "secret doors shoot open in two stages close and rearm" {
    f = secret_fixture();
    door = [f.world->:HasTrain:->][?:Train][0];
    sink = Signal();
    door.activation +>:Targets:+> sink;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.1);
    assert door.motion.length() == 0.0 and not door.running;
    f.world spawn ShootMover(model=1);
    for i in range(128) {
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.01);
    }
    assert abs(door.motion.y + 64.0) < 0.001
        and door.motion.x == 0.0
        and sink.pending == 1;
    for i in range(170) {
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.01);
    }
    assert abs(door.motion.y + 64.0) < 0.001 and abs(door.motion.x - 16.0) < 0.001;
    level = Level(bsp=f.bsp, collision=f.collision, name="fixture");
    data = snapshot(f.world, level, Player(), CombatState());
    for i in range(900) {
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.01);
    }
    assert not door.running and not door.started and door.motion.length() < 0.001;
    assert f.collision.offsets[0].length() < 0.001
        and f.bsp.faces[0].motion.length() < 0.001;
    f.world spawn ShootMover(model=1);
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.01);
    assert door.running and sink.pending == 2;
    restore(f.world, level, Player(), CombatState(), data);
    assert abs(door.motion.x - 16.0) < 0.001 and door.running;
}

test "named secret doors require remote activation unless always shoot is set" {
    for flags in [0, 16] {
        f = secret_fixture(flags, True);
        door = [f.world->:HasTrain:->][?:Train][0];
        f.world spawn ShootMover(model=1);
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.1);
        assert door.running == (flags == 16);
        door.activation.pending = 1;
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.1);
        assert door.running;
    }
}

test "open once and first down secret door flags preserve route shape" {
    f = secret_fixture(5);
    door = [f.world->:HasTrain:->][?:Train][0];
    door.activation.pending = 1;
    for i in range(1200) {
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.01);
    }
    assert not door.running and door.started;
    assert abs(door.motion.z + 96.0) < 0.001 and abs(door.motion.x - 16.0) < 0.001;
    f.world spawn ShootMover(model=1);
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.1);
    assert not door.running;
}
