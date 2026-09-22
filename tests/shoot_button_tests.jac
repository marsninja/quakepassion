import from engine.world.doors { Door, HasDoor, BlastButton }
import from engine.world.trains { ShootMover }
import from engine.world.signals { Signal, Targets }
import from engine.world.world { Player }
import from engine.world.combat { CombatState }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

test "shoot buttons accumulate damage and emit only at the pressed endpoint" {
    for game in ["q1", "q2", "q3"] {
        f = DoorFixture();
        f.setup(game, {"classname": "func_button", "health": "20", "wait": "0.1"});
        button = [f.world->:HasDoor:->][?:Door][0];
        destination = Signal();
        button.activation +>:Targets:+> destination;
        assert button.enabled and not button.automatic;
        f.tick(Vec3(x=24.03125, z=24.0), 1.0);
        assert button.position == 0.0;
        f.world spawn ShootMover(model=1, amount=5);
        assert button.health == 15 and button.activation.pending == 0;
        player = Player();
        state = CombatState();
        level = Level(bsp=f.bsp, collision=f.collision, name="button");
        data = snapshot(f.world, level, player, state);
        f.world spawn ShootMover(model=1, amount=15);
        assert button.activation.pending == 1 and destination.pending == 0;
        restore(f.world, level, player, state, data);
        assert button.health == 15 and button.activation.pending == 0;
        f.world spawn ShootMover(model=1, amount=15);
        f.tick(Vec3(x=500.0), 4.0);
        assert button.state == "open" and destination.pending == 1;
        f.world spawn ShootMover(model=1, amount=100);
        assert button.activation.pending == 0 and button.health == 20;
        f.tick(Vec3(x=500.0), 0.2);
        f.tick(Vec3(x=500.0), 4.0);
        assert button.state == "closed";
        f.world spawn ShootMover(model=1, amount=20);
        assert button.activation.pending == 1;
    }
}

test "a saved shot request survives until the mover consumes it" {
    f = DoorFixture();
    f.setup("q2", {"classname": "func_button", "health": "1"});
    button = [f.world->:HasDoor:->][?:Door][0];
    f.world spawn ShootMover(model=1, amount=1);
    level = Level(bsp=f.bsp, collision=f.collision, name="button");
    player = Player();
    state = CombatState();
    data = snapshot(f.world, level, player, state);
    button.activation.pending = 0;
    restore(f.world, level, player, state, data);
    assert button.activation.pending == 1;
    f.tick(Vec3(x=500.0), 4.0);
    assert button.position == 1.0;
}

test "blast damage reaches shoot buttons only through clear space" {
    for blocked in [False, True] {
        f = DoorFixture();
        f.setup("q2", {"classname": "func_button", "health": "20"});
        if blocked {
            f.collision.add_box(
                Vec3(x=39.0, y=-100.0, z=-100.0),
                Vec3(x=41.0, y=100.0, z=200.0),
                Vec3(),
                Vec3(),
                Vec3()
            );
        }
        f.collision.reindex();
        f.world spawn BlastButton(
            origin=Vec3(x=80.0, z=48.0),
            amount=100,
            radius=128.0,
            game="q2",
            collision=f.collision,
            player=Player()
        );
        button = [f.world->:HasDoor:->][?:Door][0];
        assert button.activation.pending == (0 if blocked else 1);
    }
}
