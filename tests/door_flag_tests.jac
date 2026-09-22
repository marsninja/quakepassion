import from engine.world.doors { Door, HasDoor, DoorMember, load_doors }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture, pair_fixture }

test "start open reverses the authored path and restores both transforms" {
    for game in ["q1", "q2", "q3"] {
        f = DoorFixture();
        f.setup(game, {"spawnflags": "1", "targetname": "remote"});
        door = [f.world->:HasDoor:->][?:Door][0];
        assert door.rest.z == 88.0 and door.travel.z == -88.0;
        assert f.bsp.faces[0].motion.z == 88.0 and f.collision.offsets[0].z == 88.0;
        assert not f.collision.trace(Vec3(z=24.0), Vec3(z=24.0)).start_solid;
        door.requested = True;
        f.tick(Vec3(x=500.0), 0.5);
        assert door.position == 0.5 and f.collision.offsets[0].z == 44.0;
        level = Level(bsp=f.bsp, collision=f.collision, name="start-open");
        player = Player();
        combat = CombatState();
        saved = snapshot(f.world, level, player, combat);
        f.tick(Vec3(x=500.0), 1.0);
        assert f.collision.offsets[0].z == 0.0;
        restore(f.world, level, player, combat, saved);
        assert door.position == 0.5 and f.collision.offsets[0].z == 44.0;
        assert f.bsp.faces[0].motion.z == 44.0;
    }
}

test "start open applies to every linked member before the first frame" {
    for game in ["q1", "q2", "q3"] {
        f = pair_fixture(game);
        f.world = World();
        for entity in f.bsp.entities {
            entity.fields["spawnflags"] = "1";
        }
        load_doors(f.world, f.bsp, f.collision);
        door = [f.world->:HasDoor:->][?:Door][0];
        member = [door->:DoorMember:->][?:Door][0];
        assert f.bsp.faces[0].motion.z == 88.0 and f.bsp.faces[1].motion.z == -88.0;
        assert f.collision.offsets[0].z == 88.0 and f.collision.offsets[1].z == -88.0;
        assert member.position == 0.0;
    }
}

test "toggle doors wait at either end and reverse mid travel without snapping" {
    for game in ["q1", "q2"] {
        f = DoorFixture();
        f.setup(game, {"spawnflags": "32", "targetname": "remote"});
        door = [f.world->:HasDoor:->][?:Door][0];
        door.requested = True;
        f.tick(Vec3(x=500.0), 0.5);
        assert door.position == 0.5;
        door.requested = True;
        f.tick(Vec3(x=500.0), 0.25);
        assert door.position == 0.25 and door.state == "closing";
        door.requested = True;
        f.tick(Vec3(x=500.0), 1.0);
        assert door.position == 1.0;
        f.tick(Vec3(x=500.0), 20.0);
        assert door.state == "open";
        door.requested = True;
        f.tick(Vec3(x=500.0), 1.0);
        assert door.state == "closed" and door.position == 0.0;
        f.tick(Vec3(x=500.0), 20.0);
        assert door.state == "closed";
    }
}

test "toggle proximity is debounced across ticks and saves" {
    f = DoorFixture();
    f.setup("q2", {"spawnflags": "32"});
    door = [f.world->:HasDoor:->][?:Door][0];
    for i in range(10) {
        f.tick(Vec3(x=60.0), 0.05);
    }
    assert door.state == "opening" and abs(door.position - 0.5) < 0.00001;
    player = Player();
    combat = CombatState();
    level = Level(bsp=f.bsp, collision=f.collision, name="toggle");
    data = snapshot(f.world, level, player, combat);
    door.contact_remaining = 0.0;
    restore(f.world, level, player, combat, data);
    f.tick(Vec3(x=60.0), 0.05);
    assert door.state == "opening";
}
