"""Real-asset pickup spawning, rendering and collection across all three games."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from games.items { populate_pickups }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        world = World();
        level = load_level(world, game_directory(game), name, game);
        count = populate_pickups(world, level, game_directory(game));
        assert count > 0;
        player = spawn_player(level);
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        pickups = [world->:HasPickup:->][?:Pickup];
        item = pickups[0];
        eye = player.pos;
        found = False;
        for candidate in pickups {
            if candidate.rule.kind != "health" {
                continue;
            }
            for offset in [
                Vec3(x=90.0, z=70.0),
                Vec3(x=-90.0, z=70.0),
                Vec3(y=90.0, z=70.0),
                Vec3(y=-90.0, z=70.0)
            ] {
                position = candidate.pos.add(offset);
                origin = position.sub(Vec3(z=level.collision.eye_height));
                target = candidate.pos.add(Vec3(z=24.0));
                query = level.collision.trace(origin, target);
                if not query.start_solid and query.fraction > 0.99 {
                    item = candidate;
                    eye = position;
                    found = True;
                    break;
                }
            }
            if found {
                break;
            }
        }
        assert found;
        direction = item.pos.add(Vec3(z=12.0)).sub(eye);
        yaw = math.atan2(direction.y, direction.x);
        pitch = math.atan2(
            direction.z,
            math.sqrt(direction.x * direction.x + direction.y * direction.y)
        );
        for i in range(3) {
            renderer.begin_frame(eye, yaw, pitch);
            drawing.draw(level, level.visible(world, eye, False), eye);
            scene.draw(world, eye);
            renderer.end_scene();
            renderer.end_frame();
        }
        renderer.screenshot("qp_pickup_" + game + ".png");
        player.health = 1;
        result = world spawn PickupTick(
            player=player, start=item.pos, finish=item.pos, dt=0.01
        );
        assert result.collected > 0 and not item.active and not item.visual.visible;
        print(
            "PICKUPS PASS", game, count, "items", len(scene.resources), "shared models"
        );
        scene.close();
        drawing.close();
    }
    renderer.close();
}
