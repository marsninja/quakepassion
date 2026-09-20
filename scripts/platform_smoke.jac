"""Desktop platform ride and Escape pause checks on Q1/Q2 asset maps."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor }
import from engine.physics.collision { Sweep }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2"] {
        name = "e1m1" if game == "q1" else "base3";
        world = World();
        level = load_level(world, game_directory(game), name, game);
        platforms = [
            mover
            for mover in [world->:HasDoor:->][?:Door]
            if mover.enabled and mover.kind == "platform" and mover.position == 0.0
        ];
        found = False;
        origin = Vec3();
        chosen = 0;
        for i in range(len(platforms)) {
            platform = platforms[i];
            for x in [0.5, 0.25, 0.75] {
                for y in [0.5, 0.25, 0.75] {
                    candidate = Vec3(
                        x=platform.bounds.mins.x + platform.bounds.size().x * x,
                        y=platform.bounds.mins.y + platform.bounds.size().y * y,
                        z=platform.bounds.maxs.z + platform.rest.z + 24.03125
                    );
                    if level.collision.trace(candidate, candidate).start_solid {
                        continue;
                    }
                    for index in platform.hulls {
                        local = candidate.sub(level.collision.offsets[index]);
                        probe = level.collision.hulls[index] spawn Sweep(
                            start=local, finish=local.add(Vec3(z=-0.25))
                        );
                        if not probe.result.start_solid
                            and probe.result.fraction < 1.0
                            and probe.result.normal.z >= 0.7 {
                            origin = candidate;
                            chosen = i;
                            found = True;
                            break;
                        }
                    }
                    if found {
                        break;
                    }
                }
                if found {
                    break;
                }
            }
            if found {
                break;
            }
        }
        assert found;
        platform = platforms[chosen];
        player = Player(pos=origin.add(Vec3(z=level.collision.eye_height)), pitch=-0.5);
        app = App(
            world=world,
            player=player,
            renderer=renderer,
            clock=Clock(),
            level=level,
            overlay=False,
            culling=False,
            walking=True
        );
        app.quake.upload(level);
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_platform_" + game + "_bottom.png");
        before = player.pos.z;
        app.menu.opened = True;
        app.physics_clock.accumulator = 0.05;
        app.skip_time = True;
        assert app.step();
        assert player.pos.z == before and platform.position == 0.0;
        app.menu.opened = False;
        platform.requested = True;
        for i in range(600) {
            app.physics_clock.accumulator = app.physics_clock.tick_rate;
            app.skip_time = True;
            assert app.step();
            if platform.position == 1.0 {
                break;
            }
        }
        assert platform.position == 1.0;
        assert abs(player.pos.z - before - platform.travel.z) < 0.1;
        assert not level.collision.trace(
            player.pos.sub(Vec3(z=level.collision.eye_height)),
            player.pos.sub(Vec3(z=level.collision.eye_height))
        ).start_solid;
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_platform_" + game + "_top.png");
        print("PLATFORM RENDER PASS", game, name, "rise", player.pos.z - before);
        app.quake.close();
    }
    renderer.close();
}
