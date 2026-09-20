import from engine.formats.brush_collision { build_brush_collision }
import from engine.physics.movement { MovePlayer }
import from engine.world.traversal {
    Traversal,
    Destination,
    HasTraversal,
    ArrivesAt,
    TraversalTick,
    load_traversal
}
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { MapEntity }
import from tests.trigger_support { trigger_fixture }


def traversal_box() -> CollisionMap {
    volume = CollisionMap();
    volume.add_brush(
        [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ],
        [8.0, 8.0, 8.0, 8.0, 8.0, 8.0],
        Vec3(),
        Vec3(),
        Vec3()
    );
    return volume;
}

test "teleport swept contact updates pose and velocity without chaining old contacts" {
    world = World();
    first = Traversal(volume=traversal_box(), kind="teleport");
    second = Traversal(volume=traversal_box(), kind="teleport");
    first +>:ArrivesAt:+> Destination(origin=Vec3(x=100.0), yaw=1.5707963267948966);
    second +>:ArrivesAt:+> Destination(origin=Vec3(x=200.0));
    world +>:HasTraversal:+> first;
    world +>:HasTraversal:+> second;
    player = Player(pos=Vec3(x=20.0, z=22.0), grounded=True);
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(x=-20.0), dt=0.01
    );
    assert player.pos.x == 100.0 and player.pos.z == 22.0;
    assert abs(player.velocity.y - 300.0) < 0.00001 and not player.grounded;
    assert first.activations == 1 and second.activations == 0;
}

test "blocked teleport exits preserve the complete player state" {
    world = World();
    trigger = Traversal(volume=traversal_box(), kind="teleport");
    trigger +>:ArrivesAt:+> Destination(origin=Vec3());
    world +>:HasTraversal:+> trigger;
    player = Player(pos=Vec3(z=22.0), velocity=Vec3(x=5.0), grounded=True);
    world spawn TraversalTick(
        player=player, collision=traversal_box(), start=Vec3(), dt=0.01
    );
    assert player.pos.z == 22.0 and player.velocity.x == 5.0 and player.grounded;
    assert trigger.activations == 0 and player.teleport_cooldown == 0.0;
}

test "pause fly mode and teleport cooldown suppress travel" {
    world = World();
    trigger = Traversal(volume=traversal_box(), kind="teleport");
    trigger +>:ArrivesAt:+> Destination(origin=Vec3(x=100.0));
    world +>:HasTraversal:+> trigger;
    player = Player(pos=Vec3(z=22.0), teleport_cooldown=0.2);
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.0
    );
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.1, touching=False
    );
    assert player.teleport_cooldown == 0.2;
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.1
    );
    assert trigger.activations == 0;
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.11
    );
    assert trigger.activations == 1;
}

test "one shot push changes velocity once and never relocates the player" {
    world = World();
    trigger = Traversal(
        volume=traversal_box(), kind="push", velocity=Vec3(z=400.0), once=True
    );
    world +>:HasTraversal:+> trigger;
    player = Player(pos=Vec3(z=22.0), grounded=True);
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.01
    );
    assert player.pos.z == 22.0 and player.velocity.z == 400.0 and not player.grounded;
    player.velocity.z = 300.0;
    world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(), dt=0.01
    );
    assert player.velocity.z == 300.0 and trigger.activations == 1;
    assert trigger.velocity.z == 400.0;
}

test "Q3 pad launch reaches its authored apex under shared gravity" {
    fixture = trigger_fixture("q3");
    fixture.bsp.entities[1].fields = {
        "classname": "trigger_push",
        "model": "*2",
        "origin": "200 0 0",
        "target": "apex"
    };
    fixture.bsp.models[2].mins = Vec3(x=-8.0, y=-8.0, z=-8.0);
    fixture.bsp.models[2].maxs = Vec3(x=8.0, y=8.0, z=8.0);
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "target_position",
                "targetname": "apex",
                "origin": "400 0 100"
            }
        )
    );
    load_traversal(fixture.world, fixture.bsp);
    pads = [fixture.world->:HasTraversal:->][?:Traversal];
    assert len(pads) == 1;
    velocity = pads[0].velocity;
    time = velocity.z / 800.0;
    assert abs(velocity.x * time - 200.0) < 0.00001;
    assert abs(velocity.z * time - 400.0 * time * time - 100.0) < 0.00001;
}

test "invalid or ambiguous destinations and spectator teleporters stay disabled" {
    for mode in ["missing", "ambiguous", "spectator"] {
        fixture = trigger_fixture("q3");
        fixture.bsp.entities[1].fields = {
            "classname": "trigger_teleport",
            "model": "*2",
            "target": "exit",
            "spawnflags": "1" if mode == "spectator" else "0"
        };
        if mode != "missing" {
            fixture.bsp.entities.append(
                MapEntity(fields={"classname": "target_position", "targetname": "exit"})
            );
        }
        if mode == "ambiguous" {
            fixture.bsp.entities.append(
                MapEntity(fields={"classname": "target_position", "targetname": "exit"})
            );
        }
        load_traversal(fixture.world, fixture.bsp);
        assert len([fixture.world->:HasTraversal:->][?:Traversal]) == 0;
    }
}


test "Q2 point pads use an expanded touch volume and clear velocity at the destination" {
    fixture = trigger_fixture("q2");
    fixture.bsp.entities = [
        MapEntity(
            fields={
                "classname": "misc_teleporter",
                "origin": "200 0 0",
                "target": "exit"
            }
        ),
        MapEntity(
            fields={
                "classname": "misc_teleporter_dest",
                "origin": "500 0 0",
                "targetname": "exit",
                "angle": "90"
            }
        )
    ];
    load_traversal(fixture.world, fixture.bsp);
    pads = [fixture.world->:HasTraversal:->][?:Traversal];
    assert len(pads) == 1;
    player = Player(pos=Vec3(x=220.0, z=32.0), velocity=Vec3(x=200.0), grounded=True);
    fixture.world spawn TraversalTick(
        player=player, collision=CollisionMap(), start=Vec3(x=220.0, z=10.0), dt=0.01
    );
    assert player.pos.x == 500.0 and player.pos.z == 32.0;
    assert player.velocity.length() == 0.0 and not player.grounded;
    assert abs(player.yaw - 1.5707963267948966) < 0.00001;
    assert player.teleport_hold == 0.16;
}


test "Q2 destination disc supports the arriving standing player" {
    fixture = trigger_fixture("q2");
    fixture.bsp.entities = [
        MapEntity(fields={"classname": "misc_teleporter_dest", "origin": "500 0 0"})
    ];
    collision = build_brush_collision(fixture.bsp);
    origin = Vec3(x=500.0, z=10.0);
    assert not collision.trace(origin, origin).start_solid;
    ground = collision.trace(origin, origin.add(Vec3(z=-4.0)));
    assert ground.fraction < 1.0 and ground.normal.z == 1.0;
}


test "Q2 arrival hold pauses movement before releasing normal physics" {
    player = Player(pos=Vec3(z=100.0), teleport_hold=0.16);
    for i in range(4) {
        player spawn MovePlayer(
            collision=CollisionMap(), wish=Vec3(x=1.0), jump=True, dt=0.04
        );
    }
    assert player.pos.z == 100.0 and player.velocity.length() == 0.0;
    for i in range(2) {
        player spawn MovePlayer(collision=CollisionMap(), dt=0.04);
    }
    assert player.pos.z < 100.0;
}
