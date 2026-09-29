"""Movers push what they carry or meet in each body's own box (SV_PushMove,
SV_Push, G_MoverPush), and items settle as their game spawns them."""
import math;
import from tests.door_support { DoorFixture }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.rotators { Rotator, HasRotator, RotatorTick, load_rotators }
import from engine.world.turrets { Turret, HasTurret, TurretTick }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.pickups { Pickup, PickupRule, HasPickup, item_view, drop_to_floor }
import from engine.core.savegame { snapshot, restore }
import from engine.formats.bsp { Bsp, Face, Model, MapEntity }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def lift_fixture(game: str) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(
        game, {"classname": "func_plat", "height": "64", "speed": "64"}
    );
    return fixture;
}

def lift(fixture: DoorFixture, dt: float) {
    fixture.world spawn DoorTick(
        bsp=fixture.bsp,
        collision=fixture.collision,
        player_origin=Vec3(x=1000.0),
        dt=dt
    );
}

def item(pos: Vec3) -> Pickup {
    return Pickup(
        rule=PickupRule(kind="shells", amount=20, capacity=100, model=""), pos=pos
    );
}

def floor_map(top: float) -> CollisionMap {
    collision = CollisionMap();
    collision.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [1000.0, 1000.0, 1000.0, 1000.0, top, 64.0 - top],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    collision.models = [0];
    collision.reindex();
    return collision;
}

test "a lift carries a big monster in its own box and stops for one too tall" {
    for tall in [False, True] {
        fixture = lift_fixture("q2");
        plat = [fixture.world->:HasDoor:->][?:Door][0];
        # The lowered plat's top is at 32; a ceiling above the raised plat
        # leaves room for a 56-unit player box but not an 88-unit tank.
        fixture.add_ceiling(170.0);
        rule = OpponentRule(width=32.0, hull_bottom=-16.0, hull_top=72.0 if tall else 40.0);
        tank = Opponent(
            rule=rule,
            own_hull=True,
            health=100,
            eye_height=22.0,
            pos=Vec3(z=32.03125 + 16.0 + 22.0)
        );
        fixture.world +>:HasOpponent:+> tank;
        before = tank.pos.z;
        for i in range(8) {
            lift(fixture, 0.25);
        }
        if tall {
            # Blocked on the way up, it came back down with the tank.
            assert plat.position < 1.0 and plat.state != "open";
            assert tank.pos.z - before < 64.0;
        } else {
            assert plat.position == 1.0 and plat.state == "open";
            assert abs(tank.pos.z - before - 64.0) < 0.001;
        }
    }
}

test "items settle as each game spawns them" {
    collision = floor_map(0.0);
    # Q1 PlaceItem: up 6, then droptofloor puts the box's low corner down.
    q1 = item(Vec3(z=40.0));
    assert drop_to_floor(q1, item_view(collision, "q1"), "q1", False).kept;
    assert abs(q1.pos.z) < 0.05;
    # Nothing within 256 below: the item fell out of the level.
    high = item(Vec3(z=400.0));
    assert not drop_to_floor(high, item_view(collision, "q1"), "q1", False).kept;
    # Armor and weapons reach from '-16 -16 0', keys and artifacts from
    # '-16 -16 -24': each lands with its own box's bottom on the floor.
    armor = item(Vec3(z=40.0));
    armor.rule.mins = Vec3(x=-16.0, y=-16.0);
    assert drop_to_floor(armor, item_view(collision, "q1"), "q1", False).kept;
    assert abs(armor.pos.z) < 0.05;
    key = item(Vec3(z=40.0));
    key.rule.mins = Vec3(x=-16.0, y=-16.0, z=-24.0);
    assert drop_to_floor(key, item_view(collision, "q1"), "q1", False).kept;
    assert abs(key.pos.z - 24.0) < 0.05;
    # Against a wall, only the item's own box decides whether it fits.
    walled = floor_map(0.0);
    walled.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [100.0, -20.0, 1000.0, 1000.0, 200.0, 0.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    walled.models.append(0);
    walled.reindex();
    beside = item(Vec3(x=0.0, z=40.0));
    beside.rule.mins = Vec3(x=-16.0, y=-16.0);
    assert drop_to_floor(beside, item_view(walled, "q1"), "q1", False).kept;
    # Q2 droptofloor: the 15-unit box, 128 down, or left hanging to fall.
    q2 = item(Vec3(z=40.0));
    landing = drop_to_floor(q2, item_view(collision, "q2"), "q2", False);
    assert landing.kept and not landing.falls and abs(q2.pos.z - 15.0) < 0.05;
    hanging = item(Vec3(z=400.0));
    landing = drop_to_floor(hanging, item_view(collision, "q2"), "q2", False);
    assert landing.kept and landing.falls and abs(hanging.pos.z - 272.0) < 0.05;
    buried = item(Vec3(z=-20.0));
    assert not drop_to_floor(buried, item_view(collision, "q2"), "q2", False).kept;
    # Q3 FinishSpawningItem: 4096 down unless suspended.
    q3 = item(Vec3(z=400.0));
    assert drop_to_floor(q3, item_view(collision, "q3"), "q3", False).kept;
    assert abs(q3.pos.z - 15.0) < 0.05;
    floating = item(Vec3(z=400.0));
    assert drop_to_floor(floating, item_view(collision, "q3"), "q3", True).kept;
    assert floating.pos.z == 400.0;
}

test "items ride lifts and Q2 doors clear an item in their way" {
    for game in ["q1", "q2", "q3"] {
        fixture = lift_fixture(game);
        plat = [fixture.world->:HasDoor:->][?:Door][0];
        # Resting on the lowered plat's top at 32.
        box = item(Vec3(x=-16.0, y=-16.0, z=32.03125) if game == "q1" else Vec3(z=47.03125));
        fixture.world +>:HasPickup:+> box;
        before = box.pos.z;
        plat.state = "opening";
        for i in range(8) {
            if plat.state != "open" {
                lift(fixture, 0.25);
            }
        }
        assert plat.state == "open" and abs(box.pos.z - before - 64.0) < 0.001;
    }
    for game in ["q1", "q2"] {
        fixture = DoorFixture();
        fixture.setup(game);
        fixture.add_floor();
        door = [fixture.world->:HasDoor:->][?:Door][0];
        door.automatic = False;
        door.state = "opening";
        for i in range(25) {
            fixture.tick(Vec3(x=500.0));
        }
        # An item on the floor where the door comes down.
        shells = item(Vec3(z=15.03125) if game == "q2" else Vec3(x=-16.0, y=-16.0, z=0.03125));
        fixture.world +>:HasPickup:+> shells;
        # Items entering the world at runtime move its item serial on.
        fixture.world.item_serial += 1;
        door.state = "closing";
        for i in range(40) {
            fixture.tick(Vec3(x=500.0));
        }
        if game == "q2" {
            # door_blocked: BecomeExplosion1, and the door closes after all.
            assert not [fixture.world->:HasPickup:->] and door.state == "closed";
        } else {
            # Q1 items (SOLID_TRIGGER) never hold up a door.
            assert [fixture.world->:HasPickup:->] and door.state == "closed";
        }
    }
}

test "a rider on a Q3 rotating mover is carried round and turns with it" {
    world = World();
    bsp = Bsp(
        game="q3",
        models=[
            Model(head=0, first_face=0, face_count=0),
            Model(head=0, first_face=0, face_count=1, mins=Vec3(z=-128.0))
        ],
        faces=[Face(vertices=[Vec3(x=-64.0, y=-64.0), Vec3(x=64.0, y=64.0, z=16.0)])],
        entities=[MapEntity(fields={"classname": "func_rotating", "model": "*1", "speed": "90"})]
    );
    collision = CollisionMap();
    collision.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [64.0, 64.0, 64.0, 64.0, 16.0, 0.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    collision.models = [1];
    load_rotators(world, bsp, collision);
    rider = Player(pos=Vec3(x=40.0, z=16.03125 + 24.0 + 22.0), yaw=0.0);
    world spawn RotatorTick(bsp=bsp, collision=collision, dt=0.5, player=rider);
    # A quarter of 90 degrees a second times half a second, about the origin.
    assert abs(math.degrees(rider.yaw) - 45.0) < 0.01;
    assert abs(rider.pos.x - 40.0 * math.cos(math.radians(45.0))) < 0.01;
    assert abs(rider.pos.y - 40.0 * math.sin(math.radians(45.0))) < 0.01;
}

def turret_map() -> CollisionMap {
    collision = CollisionMap();
    # The breach's barrel: 80 long from its pivot at (0, 0, 100).
    collision.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [80.0, 0.0, 8.0, 8.0, 8.0, 8.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3(z=100.0)
    );
    collision.models = [1];
    collision.allow_rotation(0);
    collision.reindex();
    return collision;
}

test "a turning turret pushes what it swings into and crushes what it cannot" {
    collision = turret_map();
    world = World();
    breach = Turret(pivot=Vec3(z=100.0), hulls=[0], origins=[Vec3(z=100.0)], aim_yaw=90.0);
    world +>:HasTurret:+> breach;
    bsp = Bsp(game="q2");
    # Just beside the barrel's tip, in the way of its swing to the left.
    player = Player(health=100, pos=Vec3(x=60.0, y=26.0, z=100.0));
    world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    assert breach.yaw == 5.0 and player.pos.y > 26.0 and player.health == 100;
    # Pinned against a wall, it stops the turret and takes turret_blocked's dmg.
    collision.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [200.0, 200.0, 200.0, -44.0, 300.0, 0.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    collision.models.append(0);
    collision.reindex();
    player.pos = Vec3(x=60.0, y=26.0, z=100.0);
    breach.yaw = 0.0;
    world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    assert breach.yaw == 0.0 and player.health == 90;
}

test "a turret's aim and its driver's targeting survive a save" {
    collision = turret_map();
    world = World();
    breach = Turret(pivot=Vec3(z=100.0), hulls=[0], origins=[Vec3(z=100.0)]);
    breach.pitch = -12.0;
    breach.yaw = 33.0;
    breach.aim_pitch = -20.0;
    breach.aim_yaw = 80.0;
    world +>:HasTurret:+> breach;
    level = Level(collision=collision);
    level.name = "gun";
    level.bsp.game = "q2";
    saved = snapshot(world, level, Player(), CombatState());
    breach.pitch = 0.0;
    breach.yaw = 0.0;
    breach.aim_pitch = 0.0;
    breach.aim_yaw = 0.0;
    restore(world, level, Player(), CombatState(), saved);
    assert breach.pitch == -12.0 and breach.yaw == 33.0;
    assert breach.aim_pitch == -20.0 and breach.aim_yaw == 80.0;
    assert collision.turns[0] is not None;
}
