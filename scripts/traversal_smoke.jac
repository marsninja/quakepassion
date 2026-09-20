"""Exercise traversal through the application's fixed-step walking loop."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.traversal { Traversal, HasTraversal }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    for scenario in range(5) {
        game = "q1" if scenario == 0 else ("q2" if scenario == 1 else "q3");
        name = "e1m2"
            if scenario == 0
            else (
                "jail1" if scenario == 1 else ("q3dm6" if scenario == 2 else "q3dm7")
            );
        kind = "teleport" if scenario == 0 or scenario == 3 else "push";
        if scenario == 4 {
            game = "q2";
            name = "base3";
            kind = "teleport";
        }
        world = World();
        level = load_level(world, game_directory(game), name, game);
        triggers = [
            trigger
            for trigger in [world->:HasTraversal:->][?:Traversal]
            if trigger.kind == kind
        ];
        assert len(triggers) > 0;
        candidates: list[Vec3] = [];
        for bounds in triggers[0].volume.bounds {
            for x in [0.5, 0.25, 0.75] {
                for y in [0.5, 0.25, 0.75] {
                    for z in [0.5, 0.25, 0.75, 0.9, 0.99] {
                        candidates.append(
                            bounds.mins.add(
                                Vec3(
                                    x=bounds.size().x * x,
                                    y=bounds.size().y * y,
                                    z=bounds.size().z * z
                                )
                            )
                        );
                    }
                }
            }
        }
        if game == "q1" {
            for model in level.bsp.models {
                size = model.maxs.sub(model.mins);
                for x in [0.1, 0.3, 0.5, 0.7, 0.9] {
                    for y in [0.1, 0.3, 0.5, 0.7, 0.9] {
                        for z in [0.1, 0.3, 0.5, 0.7, 0.9] {
                            candidates.append(
                                model.mins.add(
                                    Vec3(x=size.x * x, y=size.y * y, z=size.z * z)
                                )
                            );
                        }
                    }
                }
            }
        }
        origin = Vec3();
        found = False;
        for candidate in candidates {
            if triggers[0].volume.trace(candidate, candidate).start_solid
                and not level.collision.trace(candidate, candidate).start_solid {
                origin = candidate;
                found = True;
                break;
            }
        }
        assert found;
        player = Player(pos=origin.add(Vec3(z=level.collision.eye_height)));
        app = App(
            world=world,
            player=player,
            renderer=renderer,
            clock=Clock(),
            level=level,
            walking=True,
            overlay=False,
            culling=False
        );
        app.quake.upload(level);
        for i in range(3) {
            app.render_frame();
        }
        prefix = "qp_traversal_" + game + "_" + kind;
        renderer.screenshot(prefix + "_before.png");
        app.menu.opened = True;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert triggers[0].activations == 0;
        app.menu.opened = False;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert triggers[0].activations == 1;
        if kind == "teleport" {
            assert player.pos.sub(
                origin.add(Vec3(z=level.collision.eye_height))
            ).length()
                > 32.0;
        } else {
            assert player.velocity.sub(triggers[0].velocity).length() < 0.0001;
            for i in range(30) {
                app.physics_clock.accumulator = app.physics_clock.tick_rate;
                app.skip_time = True;
                assert app.step();
            }
            assert player.pos.sub(
                origin.add(Vec3(z=level.collision.eye_height))
            ).length()
                > 16.0;
        }
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot(prefix + "_after.png");
        print("TRAVERSAL RENDER PASS", game, name, kind);
        app.quake.close();
    }
    renderer.close();
}
