"""Original-map powerups: spawning, models, rendering, collection and effects."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.powerups { PowerupTick, UseItem, powerup_left, owned_items }
import from engine.world.models { UsesModel, ModelResource }
import from games.items { populate_pickups }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def special(kind: str) -> bool {
    return kind == "powerup"
        or kind.startswith("powerup_")
        or kind.startswith("holdable_")
        or kind in ["power_screen", "power_shield", "adrenaline", "bandolier", "pack"];
}

def view_point(level: Level, item: Pickup) -> list[Vec3] {
    for offset in [
        Vec3(x=80.0, z=60.0),
        Vec3(x=-80.0, z=60.0),
        Vec3(y=80.0, z=60.0),
        Vec3(y=-80.0, z=60.0),
        Vec3(z=80.0)
    ] {
        position = item.pos.add(offset);
        origin = position.sub(Vec3(z=level.collision.eye_height));
        query = level.collision.trace(origin, item.pos.add(Vec3(z=16.0)));
        if not query.start_solid and query.fraction > 0.99 {
            return [position];
        }
    }
    return [];
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    cases: list[tuple[str, str, int]] = [
        ("q1", "e1m1", 2),
        ("q2", "base3", 3),
        ("q3", "q3dm11", 3),
        ("q3", "q3dm19", 2)
    ];
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        populate_pickups(world, level, game_directory(game));
        pickups = [
            pickup
            for pickup in [world->:HasPickup:->][?:Pickup]
            if special(pickup.rule.kind)
        ];
        assert len(pickups) >= scenario[2];
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        shots = 0;
        for item in pickups {
            resources = [item.visual->:UsesModel:->][?:ModelResource];
            assert resources and resources[0].name in scene.resources;
            if game == "q3" and item.rule.kind == "powerup" {
                assert len(resources) == 2;
                assert item.visual.spin > 0.0 and item.visual.bob == 4.0;
                # Q3 powerups first appear 30-60 seconds into the match.
                assert not item.active and item.remaining >= 30.0;
                item.active = True;
                item.visual.visible = True;
            }
            if game == "q1" {
                assert item.visual.spin == 100.0;
            }
            spot = view_point(level, item);
            if not spot or shots >= 2 {
                continue;
            }
            eye = spot[0];
            direction = item.pos.add(Vec3(z=12.0)).sub(eye);
            yaw = math.atan2(direction.y, direction.x);
            pitch = math.atan2(
                direction.z, math.sqrt(direction.x * direction.x + direction.y * direction.y)
            );
            for frame in range(3) {
                renderer.begin_frame(eye, yaw, pitch);
                drawing.draw(level, level.visible(world, eye, False), eye);
                scene.draw(world, eye, float(frame) * 0.25);
                renderer.end_scene();
                renderer.end_frame();
            }
            renderer.screenshot(
                "qp_powerup_" + game + "_" + name + "_" + str(shots) + ".png"
            );
            shots += 1;
        }
        assert shots > 0;
        player = spawn_player(level);
        collected = 0;
        sounds: list[str] = [];
        for item in pickups {
            item.active = True;
            result = world spawn PickupTick(
                player=player,
                start=item.pos,
                finish=item.pos,
                dt=0.01,
                selected_only=True,
                targets=[item]
            );
            collected += result.collected;
            sounds.extend(result.sounds);
        }
        assert collected > 0 and sounds;
        if game == "q1" {
            # The e1m1 Pentagram is deathmatch-only (spawnflags 1792).
            assert powerup_left(player, "quad") > 0.0;
            assert powerup_left(player, "suit") > 0.0;
        } elif game == "q2" {
            stored = owned_items(player.inventory, "q2");
            assert "powerup_quad" in stored;
            player spawn UseItem(game="q2", kind="powerup_quad");
            assert powerup_left(player, "quad") == 30.0;
        } else {
            assert powerup_left(player, "quad") > 0.0;
        }
        tick = player spawn PowerupTick(game=game, dt=40.0);
        assert tick.expired;
        print("POWERUPS PASS", game, name, len(pickups), "special items", shots, "captures");
        scene.close();
        drawing.close();
    }
    renderer.close();
}
