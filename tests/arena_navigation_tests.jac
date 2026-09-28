import from engine.formats.aas { TRAVEL_WALK }
import from engine.formats.botconfig { ItemInfo }
import from engine.world.bot_routes { build_navmesh }
import from engine.world.bot_goals { BotItems, HasBotItems, LevelItem, HasLevelItem }
import from tests.bot_travel_tests { strip_aas }
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

test "arena bots pick up items they touch with the shared pickup rules" {
    world = World();
    bot = Opponent(arena=True, health=20, max_health=100, pos=Vec3(x=100.0, z=22.0));
    item = Pickup(pos=Vec3(x=100.0), rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world +>:HasOpponent:+> bot;
    world +>:HasPickup:+> item;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert bot.health == 45 and not item.active;
}

test "campaign monsters do not take arena items" {
    world = World();
    enemy = Opponent(health=20);
    world +>:HasOpponent:+> enemy;
    world +>:HasPickup:+> Pickup(pos=Vec3(), rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert enemy.health == 20;
}

test "arena bots teleport and keep the shared cooldowns" {
    world = World();
    portal = Traversal(volume=traversal_box(), kind="teleport", nav_entry=Vec3(), nav_exit=Vec3(x=900.0));
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=900.0));
    world +>:HasTraversal:+> portal;
    bot = Opponent(arena=True, pos=Vec3(x=-20.0, z=22.0), last_seen=Vec3(x=1000.0, z=22.0));
    world +>:HasOpponent:+> bot;
    bot.arena_goal = Vec3(x=1000.0, z=22.0);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    bot.pos = Vec3(x=20.0, z=22.0);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert bot.pos.x == 900.0 and bot.teleport_cooldown > 0.0;
    assert bot.arena_goal is None;
}

test "arena bots take powerups and hold one holdable" {
    world = World();
    bot = Opponent(arena=True, pos=Vec3(x=400.0, z=22.0));
    quad = Pickup(
        pos=Vec3(x=400.0),
        rule=PickupRule(kind="powerup", amount=1, capacity=1, model="", powerup="quad", duration=30.0)
    );
    world +>:HasOpponent:+> bot;
    world +>:HasPickup:+> quad;
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01);
    world spawn ArenaNavigationTick(collision=CollisionMap(), dt=0.01, contacts=True);
    assert not quad.active and powerup_left(bot, "quad") == 30.0;
    kit = Pickup(pos=Vec3(x=400.0), rule=PickupRule(kind="holdable_medkit", amount=1, capacity=1, model=""));
    world +>:HasPickup:+> kit;
    world spawn ArenaNavigationTick(
        collision=CollisionMap(), dt=0.01, contacts=True, index=ArenaContactIndex()
    );
    assert not kit.active and quantity(bot.inventory, "holdable_medkit") == 1;
}

test "an item floating over the void is a goal at the jump pad that throws bots through it" {
    world = World();
    walks = [(1, 2, TRAVEL_WALK), (2, 1, TRAVEL_WALK)];
    mesh = build_navmesh(world, strip_aas(2, walks));
    items = BotItems(infos=[
        ItemInfo(classname="item_armor_shard", mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0)),
        ItemInfo(classname="item_health", mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0))
    ]);
    world +>:HasBotItems:+> items;
    collision = CollisionMap();
    collision.add_box(Vec3(x=0.0, y=-100.0, z=-64.0), Vec3(x=200.0, y=100.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    # A pad at x=64 throwing straight up at 600 units a second.
    volume = CollisionMap();
    volume.add_box(Vec3(x=56.0, y=-8.0, z=0.0), Vec3(x=72.0, y=8.0, z=16.0), Vec3(), Vec3(), Vec3());
    volume.reindex();
    pad = Traversal(volume=volume, kind="push", velocity=Vec3(z=600.0));
    world +>:HasTraversal:+> pad;
    shard = Pickup(pos=Vec3(x=64.0, z=150.0), rule=PickupRule(kind="armor", amount=5, capacity=200, model="", classname="item_armor_shard"));
    stray = Pickup(pos=Vec3(x=150.0, z=500.0), rule=PickupRule(kind="health", amount=25, capacity=100, model="", classname="item_health"));
    ground = Pickup(pos=Vec3(x=150.0, z=15.0), rule=PickupRule(kind="health", amount=25, capacity=100, model="", classname="item_health"));
    for item in [shard, stray, ground] {
        world +>:HasPickup:+> item;
    }
    prepare_arena_links(world, collision);
    assert pad.nav_entry is not None;
    known = [items->:HasLevelItem:->][?:LevelItem];
    # The shard floats in the pad's throw; the stray one no pad reaches is
    # no goal; the one on the floor is a goal where it lies.
    assert len(known) == 2;
    floating = [item for item in known if item.pickup is shard][0];
    resting = [item for item in known if item.pickup is ground][0];
    assert floating.goal_area == mesh.locate(Vec3(x=64.0)) and resting.goal_area == 2;
}
