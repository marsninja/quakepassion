import from engine.world.arena_navigation {
    ArenaNavigationTick,
    ArenaContactIndex,
    prepare_arena_links
}
import from engine.world.powerups { powerup_left }
import from engine.world.inventory { quantity }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.world { World }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.traversal { Traversal, Destination, HasTraversal, ArrivesAt }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from tests.traversal_tests { traversal_box }

test "arena bots seek needed health and use the shared pickup rules" {
    world = World();
    bot = Opponent(arena=True, health=20, max_health=100, pos=Vec3(x=100.0, z=22.0));
    item = Pickup(pos=Vec3(x=100.0), rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world +>:HasOpponent:+> bot;
    world +>:HasPickup:+> item;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    assert bot.arena_goal is not None;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert bot.health == 45 and not item.active;
}

test "campaign monsters do not acquire arena item goals" {
    world = World();
    enemy = Opponent(health=20);
    world +>:HasOpponent:+> enemy;
    world +>:HasPickup:+> Pickup(pos=Vec3(), rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert enemy.arena_goal is None and enemy.health == 20;
}

test "arena bots follow directed teleport goals and retain shared cooldowns" {
    world = World();
    portal = Traversal(volume=traversal_box(), kind="teleport", nav_entry=Vec3(), nav_exit=Vec3(x=900.0));
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=900.0));
    world +>:HasTraversal:+> portal;
    bot = Opponent(arena=True, pos=Vec3(x=-20.0, z=22.0), last_seen=Vec3(x=1000.0, z=22.0));
    world +>:HasOpponent:+> bot;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    assert bot.arena_goal is not None and bot.arena_goal.x == 0.0;
    bot.pos = Vec3(x=20.0, z=22.0);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert bot.pos.x == 900.0 and bot.teleport_cooldown > 0.0;
    assert bot.arena_goal is None;
}

test "arena bots prize powerups over a fight and hold one holdable" {
    world = World();
    bot = Opponent(
        arena=True, pursuing=True, pos=Vec3(x=100.0, z=22.0), last_seen=Vec3(x=-800.0, z=22.0)
    );
    quad = Pickup(
        pos=Vec3(x=400.0),
        rule=PickupRule(kind="powerup", amount=1, capacity=1, model="", powerup="quad", duration=30.0)
    );
    world +>:HasOpponent:+> bot;
    world +>:HasPickup:+> quad;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    assert bot.arena_goal is not None and bot.arena_goal.x == 400.0;
    bot.pos = Vec3(x=400.0, z=22.0);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert not quad.active and powerup_left(bot, "quad") == 30.0;
    kit = Pickup(pos=Vec3(x=400.0), rule=PickupRule(kind="holdable_medkit", amount=1, capacity=1, model=""));
    world +>:HasPickup:+> kit;
    world spawn ArenaNavigationTick(
        collision=CollisionMap(), dt=0.01, contacts=True, index=ArenaContactIndex()
    );
    assert not kit.active and quantity(bot.inventory, "holdable_medkit") == 1;
    bot.arena_goal_wait = 0.0;
    world +>:HasPickup:+> Pickup(
        pos=Vec3(x=500.0), rule=PickupRule(kind="holdable_teleporter", amount=1, capacity=1, model="")
    );
    bot.pursuing = False;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, index=ArenaContactIndex());
    assert bot.arena_goal is None or bot.arena_goal.x != 500.0;
}
