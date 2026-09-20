"""Native damage, paused exposure, death lockout and keyboard restart."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from scripts.swim_support { swim_points }
import from vendor.raylib {
    obj AutomationEvent {
        has frame: u32,
            kind: u32,
            p0: i32,
            p1: i32,
            p2: i32,
            p3: i32;
    }  def PlayAutomationEvent(event: AutomationEvent) -> None;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2", "q3"] {
        name = "e1m2" if game == "q1" else ("base1" if game == "q2" else "q3dm12");
        world = World();
        level = load_level(world, game_directory(game), name, game);
        points = swim_points(level);
        assert len(points) == 1;
        player = Player(pos=points[0], health=4, air_remaining=0.001);
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
        app.menu.opened = True;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert player.health == 4 and player.air_remaining == 0.001;
        app.menu.opened = False;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert player.health == 0;
        before = player.pos;
        for i in range(3) {
            app.step();
        }
        assert player.pos.sub(before).length() == 0.0;
        renderer.screenshot("qp_health_" + game + "_dead.png");
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(2), p0=i32(257), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        assert app.step();
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(1), p0=i32(257), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        assert app.player is not player and app.player.health == 100;
        assert app.level.name == name and app.walking and not app.menu.opened;
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_health_" + game + "_restarted.png");
        print("HEALTH RENDER PASS", game, "pause death restart");
        app.quake.close();
    }
    renderer.close();
}
