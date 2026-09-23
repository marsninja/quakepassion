import from tests.door_support { DoorFixture }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.rotators { Rotator, HasRotator, RotatorTick, load_rotators }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.formats.bsp { Bsp, Face, Model, MapEntity }
import from engine.physics.collision { CollisionMap, hull_sweep }
import from engine.math.orientation { quake_basis }
import from engine.math.vec3 { Vec3 }

def slab(collision: CollisionMap) {
    collision.add_brush(
        [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(z=1.0), Vec3(z=-1.0)],
        [8.0, 8.0, 32.0, 32.0, 96.0, 0.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    collision.models = [1];
}

def mover_bsp(fields: dict[str, str]) -> Bsp {
    return Bsp(
        game="q3",
        models=[
            Model(head=0, first_face=0, face_count=0),
            Model(head=0, first_face=0, face_count=1, mins=Vec3(z=-128.0))
        ],
        faces=[Face(vertices=[Vec3(x=-8.0, y=-32.0), Vec3(x=8.0, y=32.0, z=96.0)])],
        entities=[MapEntity(fields=fields)]
    );
}

test "Quake angles follow AngleVectors conventions" {
    yaw = quake_basis(Vec3(y=90.0)).apply(Vec3(x=1.0));
    assert abs(yaw.y - 1.0) < 0.0001 and abs(yaw.x) < 0.0001;
    down = quake_basis(Vec3(x=90.0)).apply(Vec3(x=1.0));
    assert abs(down.z + 1.0) < 0.0001;
    roll = quake_basis(Vec3(z=90.0)).apply(Vec3(y=1.0));
    assert abs(roll.z - 1.0) < 0.0001;
    turn = quake_basis(Vec3(x=20.0, y=35.0, z=-15.0));
    back = turn.inverse(turn.apply(Vec3(x=3.0, y=-4.0, z=5.0)));
    assert back.sub(Vec3(x=3.0, y=-4.0, z=5.0)).length() < 0.0001;
}

test "turned hulls collide in their rotated frame and turn hit normals back" {
    collision = CollisionMap();
    slab(collision);
    assert collision.trace(Vec3(y=40.0, z=24.0), Vec3(y=40.0, z=24.0)).start_solid;
    assert not collision.trace(Vec3(x=40.0, z=24.0), Vec3(x=40.0, z=24.0)).start_solid;
    collision.allow_rotation(0);
    collision.reindex();
    collision.set_turn(0, quake_basis(Vec3(y=90.0)));
    assert not collision.trace(Vec3(y=40.0, z=24.0), Vec3(y=40.0, z=24.0)).start_solid;
    assert collision.trace(Vec3(x=40.0, z=24.0), Vec3(x=40.0, z=24.0)).start_solid;
    hit = collision.trace(Vec3(y=100.0, z=24.0), Vec3(y=-100.0, z=24.0));
    assert hit.fraction < 1.0 and hit.normal.y > 0.99;
    direct = hull_sweep(
        collision.hulls[0], Vec3(y=100.0, z=24.0), Vec3(y=-100.0, z=24.0), Vec3(), 0.0, False, None
    );
    assert direct.fraction < 1.0 and direct.normal.y > 0.99;
    collision.set_turn(0, None);
    assert collision.trace(Vec3(y=40.0, z=24.0), Vec3(y=40.0, z=24.0)).start_solid;
}

test "Q2 rotating doors swing open about their origin and close again" {
    fixture = DoorFixture();
    fixture.setup("q2", {"classname": "func_door_rotating", "speed": "180", "wait": "0.1"});
    doors = [fixture.world->:HasDoor:->][?:Door];
    assert len(doors) == 1 and doors[0].rotation.y == 90.0;
    door = doors[0];
    for i in range(12) {
        fixture.tick(Vec3(x=60.0, z=24.0));
    }
    assert door.state == "open" and door.position == 1.0;
    face = fixture.bsp.faces[0];
    assert face.turn is not None and face.motion.length() == 0.0;
    assert fixture.collision.trace(Vec3(x=40.0, z=24.0), Vec3(x=40.0, z=24.0)).start_solid;
    assert not fixture.collision.trace(Vec3(y=40.0, z=24.0), Vec3(y=40.0, z=24.0)).start_solid;
    for i in range(20) {
        fixture.tick(Vec3(x=500.0));
    }
    assert door.state == "closed" and door.position == 0.0;
    assert fixture.collision.trace(Vec3(y=40.0, z=24.0), Vec3(y=40.0, z=24.0)).start_solid;
}

test "reverse and axis flags pick the swing and start-open doors begin swung" {
    fixture = DoorFixture();
    fixture.setup("q2", {"classname": "func_door_rotating", "spawnflags": "66", "distance": "45"});
    door = [fixture.world->:HasDoor:->][?:Door][0];
    assert door.rotation.z == -45.0 and door.rotation.y == 0.0;
    opened = DoorFixture();
    opened.setup("q2", {"classname": "func_door_rotating", "spawnflags": "1"});
    swung = [opened.world->:HasDoor:->][?:Door][0];
    assert swung.rest_angles.y == 90.0 and swung.rotation.y == -90.0;
    assert opened.bsp.faces[0].turn is not None;
}

test "blocked movers crush what stops them and crushers keep pushing" {
    fixture = DoorFixture();
    fixture.setup("q2", {"dmg": "7"});
    door = [fixture.world->:HasDoor:->][?:Door][0];
    player = Player(health=100, pos=Vec3(x=60.0, z=46.0));
    for i in range(25) {
        fixture.world spawn DoorTick(
            bsp=fixture.bsp,
            collision=fixture.collision,
            player_origin=Vec3(),
            dt=0.05,
            player=player
        );
    }
    assert door.state == "open";
    # A targeted door closes on its own schedule even with someone underneath.
    player.pos = Vec3(z=46.0);
    door.automatic = False;
    door.state = "closing";
    for i in range(30) {
        if door.state != "closing" {
            break;
        }
        fixture.world spawn DoorTick(
            bsp=fixture.bsp,
            collision=fixture.collision,
            player_origin=Vec3(),
            dt=0.05,
            player=player
        );
    }
    assert player.health == 93 and door.state == "opening" and door.position > 0.0;
    crusher = DoorFixture();
    crusher.setup("q2", {"spawnflags": "4", "wait": "-1"});
    block = [crusher.world->:HasDoor:->][?:Door][0];
    assert block.crusher and block.damage == 2;
}

test "Q3 bobbing and spinning movers follow their sine and rate and carry riders" {
    world = World();
    bsp = mover_bsp(
        {"classname": "func_bobbing", "model": "*1", "height": "32", "speed": "4"}
    );
    collision = CollisionMap();
    slab(collision);
    load_rotators(world, bsp, collision);
    movers = [world->:HasRotator:->][?:Rotator];
    assert len(movers) == 1 and movers[0].kind == "bob";
    rider = Player(pos=Vec3(z=120.0 + 22.0));
    for i in range(20) {
        world spawn RotatorTick(bsp=bsp, collision=collision, dt=0.05, player=rider);
    }
    assert abs(bsp.faces[0].motion.z - 32.0) < 0.01;
    assert abs(rider.pos.z - (142.0 + 32.0)) < 0.5;
    spin_world = World();
    spin = mover_bsp({"classname": "func_rotating", "model": "*1", "speed": "90"});
    spin_collision = CollisionMap();
    slab(spin_collision);
    load_rotators(spin_world, spin, spin_collision);
    for i in range(20) {
        spin_world spawn RotatorTick(bsp=spin, collision=spin_collision, dt=0.05);
    }
    turned = spin.faces[0].turn;
    assert turned is not None;
    assert abs(turned.apply(Vec3(x=1.0)).y - 1.0) < 0.001;
    assert spin_collision.trace(Vec3(x=40.0, z=24.0), Vec3(x=40.0, z=24.0)).start_solid;
}

test "pendulums swing on their gravity period and mover clocks survive saves" {
    world = World();
    bsp = mover_bsp({"classname": "func_pendulum", "model": "*1", "speed": "30"});
    collision = CollisionMap();
    slab(collision);
    load_rotators(world, bsp, collision);
    swing = [world->:HasRotator:->][?:Rotator][0];
    assert swing.kind == "pendulum" and abs(swing.period - 4.3531) < 0.01;
    quarter = swing.period / 4.0;
    world spawn RotatorTick(bsp=bsp, collision=collision, dt=quarter);
    peak = bsp.faces[0].turn;
    assert peak is not None and abs(peak.apply(Vec3(y=1.0)).z - 0.5) < 0.01;
    level = Level(bsp=bsp, collision=collision);
    level.name = "test";
    data = snapshot(world, level, Player(), CombatState());
    world spawn RotatorTick(bsp=bsp, collision=collision, dt=1.0);
    restore(world, level, Player(), CombatState(), data);
    assert abs(swing.clock - quarter) < 0.0001;
}
