import from engine.world.arena_navigation { ArenaContactIndex, ArenaNavigationTick }
import from engine.world.world { World }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.traversal { Traversal, Destination, ArrivesAt, HasTraversal }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "arena contacts do not sweep pickups through a teleport jump" {
    world = World();
    volume = CollisionMap();
    volume.add_box(Vec3(x=-8.0, y=-8.0, z=-8.0), Vec3(x=8.0, y=8.0, z=8.0), Vec3(), Vec3(), Vec3());
    portal = Traversal(volume=volume, kind="teleport");
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=900.0));
    world +>:HasTraversal:+> portal;
    rule = PickupRule(kind="health", amount=25, capacity=100, model="");
    middle = Pickup(pos=Vec3(x=400.0), rule=rule);
    arrival = Pickup(pos=Vec3(x=900.0), rule=rule);
    world +>:HasPickup:+> middle;
    world +>:HasPickup:+> arrival;
    bot = Opponent(arena=True, health=20, pos=Vec3(x=20.0, z=22.0), arena_origin=Vec3(x=-20.0));
    world +>:HasOpponent:+> bot;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert bot.pos.x == 900.0 and bot.health == 45;
    assert middle.active and not arrival.active;
}

test "contact index follows world replacement and live item availability" {
    world = World();
    item = Pickup(pos=Vec3(x=-1.0), rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world +>:HasPickup:+> item;
    index = ArenaContactIndex();
    index.prepare(world);
    assert item in index.near_items(Vec3(x=1.0), Vec3(x=2.0));
    item.active = False;
    assert not index.near_items(Vec3(), Vec3())[0].active;
    index.prepare(World());
    assert not index.near_items(Vec3(), Vec3());
}
