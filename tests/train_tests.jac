import from tests.door_support { DoorFixture }
import from engine.world.trains { Train, HasTrain, load_trains, TrainTick }
import from engine.world.doors { connect_targets }
import from engine.world.world { Player }
import from engine.world.signals { Signal, Targets }
import from engine.formats.bsp { MapEntity }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }

import from tests.train_support { train_fixture }

test "all train formats carry riders and synchronize render and collision transforms" {
    for game in ["q1", "q2", "q3"] {
        f = train_fixture(game);
        train = [f.world->:HasTrain:->][?:Train][0];
        player = Player(pos=Vec3(z=120.03125 + f.collision.eye_height));
        for i in range(120) {
            f.world spawn TrainTick(
                bsp=f.bsp, collision=f.collision, dt=1.0 / 120.0, player=player
            );
        }
        assert train.motion.z > 55.0 and train.motion.z <= 64.0;
        assert abs(player.pos.z - 120.03125 - f.collision.eye_height - train.motion.z)
            < 0.0001;
        assert f.bsp.faces[0].motion.z == train.motion.z
            and f.collision.offsets[0].z == train.motion.z;
    }
}

test "named trains wait for activation and toggle trains resume mid segment" {
    f = train_fixture("q2", 2, True);
    train = [f.world->:HasTrain:->][?:Train][0];
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=1.0);
    assert train.motion.z == 0.0;
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert train.motion.z == 32.0;
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert train.motion.z == 32.0 and not train.running;
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert train.motion.z == 64.0 and train.running;
}

test "train snapshots restore mid segment state and transforms" {
    f = train_fixture();
    train = [f.world->:HasTrain:->][?:Train][0];
    train.remaining = 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    level = Level(bsp=f.bsp, collision=f.collision, name="test");
    data = snapshot(f.world, level, Player(), CombatState());
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    restore(f.world, level, Player(), CombatState(), data);
    assert train.motion.z == 32.0 and train.destination is not None;
    assert f.bsp.faces[0].motion.z == 32.0 and f.collision.offsets[0].z == 32.0;
}

test "blocked trains roll back riders and transforms while damage respects god mode" {
    for protected in [False, True] {
        f = train_fixture();
        train = [f.world->:HasTrain:->][?:Train][0];
        f.collision.add_box(
            Vec3(x=-100.0, y=-100.0, z=160.0),
            Vec3(x=100.0, y=100.0, z=180.0),
            Vec3(),
            Vec3(x=-16.0, y=-16.0, z=-24.0),
            Vec3(x=16.0, y=16.0, z=32.0)
        );
        f.collision.models.append(0);
        f.collision.reindex();
        player = Player(
            pos=Vec3(z=120.03125 + f.collision.eye_height), god_mode=protected
        );
        train.remaining = 0.0;
        f.world spawn TrainTick(
            bsp=f.bsp, collision=f.collision, dt=0.5, player=player
        );
        assert train.motion.z == 0.0 and f.bsp.faces[0].motion.z == 0.0;
        assert f.collision.offsets[0].z == 0.0;
        assert player.pos.z == 120.03125 + f.collision.eye_height;
        assert player.health == (100 if protected else 0);
    }
}

test "Q2 negative corner waits stop until activated and Q1 activation does not stop motion" {
    f = train_fixture();
    train = [f.world->:HasTrain:->][?:Train][0];
    train.remaining = 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    if train.destination is not None {
        train.destination.hold_time = -1.0;
    }
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert train.motion.z == 64.0 and not train.running;
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert train.motion.z == 32.0 and train.running;
    f = train_fixture("q1", 2, True);
    train = [f.world->:HasTrain:->][?:Train][0];
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    train.activation.pending = 1;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.25);
    assert train.motion.z == 48.0 and train.running;
}

test "train route bounds retain collision after leaving the authored starting brush" {
    f = train_fixture();
    train = [f.world->:HasTrain:->][?:Train][0];
    train.remaining = 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=1.0);
    ground = f.collision.trace(Vec3(z=184.1), Vec3(z=183.0));
    assert not ground.start_solid and ground.fraction < 1.0 and ground.model == 1;
}

test "Q3 corner events fire on arrival before waits and do not repeat while waiting" {
    f = train_fixture("q3");
    train = [f.world->:HasTrain:->][?:Train][0];
    receiver = Signal();
    train.current.activation +>:Targets:+> receiver;
    train.current.hold_time = 1.0;
    train.remaining = 1.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.25);
    assert receiver.pending == 1 and train.motion.z == 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.25);
    assert receiver.pending == 1 and train.motion.z == 0.0;
    train.remaining = 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    if train.destination is not None {
        train.destination.activation +>:Targets:+> receiver;
    }
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.5);
    assert receiver.pending == 2 and train.remaining == 0.25;
}

test "Q2 teleport corners reposition without sweeping through intervening actors" {
    f = train_fixture();
    train = [f.world->:HasTrain:->][?:Train][0];
    train.remaining = 0.0;
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.25);
    if train.destination is not None {
        train.destination.teleport = True;
    }
    player = Player(pos=Vec3(z=136.03125 + f.collision.eye_height));
    f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=0.25, player=player);
    assert train.motion.z == 64.0 and train.destination is None;
    assert player.pos.z == 136.03125 + f.collision.eye_height;
}
