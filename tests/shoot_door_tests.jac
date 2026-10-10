import from engine.world.doors { Door, DoorMember, HasDoor, load_doors }
import from engine.world.trains { ShootMover, BlastMover }
import from engine.world.signals { Signal, Targets }
import from engine.world.world { Player, World }
import from engine.world.combat { CombatState }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture, pair_fixture }

test "campaign shot doors wait for damage and fire targets at the start of travel" {
    for game in ["q1", "q2"] {
        f = DoorFixture();
        f.setup(game, {"health": "20"});
        door = [f.world->:HasDoor:->][?:Door][0];
        sink = Signal();
        door.activation +>:Targets:+> sink;
        assert not door.automatic;
        f.tick(Vec3(x=60.0, z=24.0), 1.0);
        assert door.position == 0.0;
        f.world spawn ShootMover(model=1, amount=19);
        assert door.health == 1 and door.activation.pending == 0;
        f.world spawn ShootMover(model=1, amount=1);
        f.tick(Vec3(x=500.0), 0.05);
        assert door.state == "opening" and sink.pending == 1;
        f.world spawn ShootMover(model=1, amount=100);
        assert door.activation.pending == 0;
        f.tick(Vec3(x=500.0), 2.0);
        assert door.state == "open" and sink.pending == 1;
        f.tick(Vec3(x=500.0), 0.2);
        assert door.state == "closing" and door.health == 20;
        f.world spawn ShootMover(model=1, amount=20);
        f.tick(Vec3(x=500.0), 0.05);
        assert door.state == "open" and sink.pending == 2;
    }
}

test "linked campaign doors accept either brush and preserve per-part damage" {
    for game in ["q1", "q2"] {
        f = pair_fixture(game);
        f.world = World();
        for entity in f.bsp.entities {
            entity.fields["health"] = "20";
        }
        load_doors(f.world, f.bsp, f.collision);
        door = [f.world->:HasDoor:->][?:Door][0];
        member = [door->:DoorMember:->][?:Door][0];
        f.world spawn ShootMover(model=2, amount=8);
        assert (door.health if game == "q1" else member.health) == 12;
        assert (member.health if game == "q1" else door.health) == 20;
        level = Level(bsp=f.bsp, collision=f.collision, name="pair");
        player = Player();
        state = CombatState();
        data = snapshot(f.world, level, player, state);
        f.world spawn ShootMover(model=2, amount=12);
        assert door.activation.pending == 1;
        restore(f.world, level, player, state, data);
        assert door.activation.pending == 0;
        assert (door.health if game == "q1" else member.health) == 12;
        f.world spawn ShootMover(model=2, amount=12);
        f.tick(Vec3(x=500.0), 4.0);
        assert door.position == 1.0 and member.position == 1.0;
        assert door.health == 20 and member.health == 20;
    }
}

test "explosions activate campaign doors but cannot shoot ordinary proximity doors" {
    for health in [0, 20] {
        f = DoorFixture();
        f.setup("q2", {"health": str(health)});
        f.world spawn BlastMover(
            origin=Vec3(x=80.0, z=48.0),
            amount=100,
            radius=128.0,
            game="q2",
            collision=f.collision,
            player=Player()
        );
        door = [f.world->:HasDoor:->][?:Door][0];
        assert door.activation.pending == (1 if health > 0 else 0);
    }
}


test "a Q3 door at rest opens for any damage, and only at rest" {
    # Think_SpawnNewDoorTrigger makes a door that opens by its own field
    # shootable too; G_Damage uses a mover resting at its first position.
    f = DoorFixture();
    f.setup("q3");
    door = [f.world->:HasDoor:->][?:Door][0];
    assert door.automatic and door.max_health == 1;
    f.world spawn ShootMover(model=1, amount=1);
    assert door.activation.pending == 1;
    f.tick(Vec3(x=500.0), 0.05);
    assert door.state == "opening";
    f.world spawn ShootMover(model=1, amount=50);
    assert door.activation.pending == 0;
    f.tick(Vec3(x=500.0), 2.0);
    f.tick(Vec3(x=500.0), 0.2);
    assert door.state == "closing";
    f.world spawn ShootMover(model=1, amount=50);
    assert door.activation.pending == 0;
    f.tick(Vec3(x=500.0), 2.0);
    assert door.state == "closed";
    f.world spawn ShootMover(model=1, amount=1);
    assert door.activation.pending == 1;
    # A targeted door is left to its target; one given health is shot only.
    named = DoorFixture();
    named.setup("q3", {"targetname": "far"});
    held = [named.world->:HasDoor:->][?:Door][0];
    named.world spawn ShootMover(model=1, amount=100);
    assert held.max_health == 0 and held.activation.pending == 0;
    shot = DoorFixture();
    shot.setup("q3", {"health": "50"});
    target = [shot.world->:HasDoor:->][?:Door][0];
    assert not target.automatic;
    shot.tick(Vec3(x=60.0, z=24.0), 0.05);
    assert target.state == "closed";
    shot.world spawn ShootMover(model=1, amount=1);
    assert target.activation.pending == 1;
}

test "Q3 splash reaches a door by the nearest point of its box" {
    # 107 units from the door's side but 140 from its middle: inside a
    # 120-unit blast only by G_RadiusDamage's measure, and for less than one
    # point of damage, which G_Damage does not ask a mover about.
    for game in ["q2", "q3"] {
        f = DoorFixture();
        f.setup(game, {"health": "1"});
        f.world spawn BlastMover(
            origin=Vec3(y=140.0, z=48.0),
            amount=5,
            radius=120.0,
            game=game,
            collision=f.collision,
            player=Player()
        );
        door = [f.world->:HasDoor:->][?:Door][0];
        assert door.activation.pending == (1 if game == "q3" else 0);
    }
}
