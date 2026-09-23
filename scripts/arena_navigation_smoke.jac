"""Original Q3 map travel links, including live bot trigger contacts."""
import from games.levels { open_level }
import from engine.core.menu { game_directory }
import from engine.world.world { World }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.arena_navigation { prepare_arena_links, ArenaNavigationTick }
import from engine.world.traversal { HasTraversal, Traversal }
import from engine.math.vec3 { Vec3 }

with entry {
    for name in ["q3dm6", "q3dm17"] {
        world = World();
        level = open_level(world, game_directory("q3"), name, "q3");
        prepare_arena_links(world, level.collision);
        links = 0;
        pads = 0;
        for portal in [world->:HasTraversal:->][?:Traversal] {
            if portal.nav_entry is None or portal.nav_exit is None { continue; }
            links += 1;
            if portal.kind == "push" {
                pads += 1;
                bot = Opponent(arena=True, pos=portal.nav_entry.add(Vec3(z=level.collision.eye_height)), eye_height=level.collision.eye_height, arena_origin=portal.nav_entry);
                world +>:HasOpponent:+> bot;
                world spawn ArenaNavigationTick(collision=level.collision, dt=1.0 / 120.0, contacts=True);
                assert bot.velocity.z > 0.0;
            }
        }
        assert links > 0 and pads > 0;
        print("ARENA NAV PASS", name, "links", links, "pads", pads);
    }
}
