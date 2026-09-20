"""Desktop swimming checks using held Space input through the app loop."""
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
        player = Player(pos=points[0]);
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
        renderer.screenshot("qp_swim_" + game + "_before.png");
        before = player.pos.z;
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(2), p0=i32(32), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        app.menu.opened = True;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert player.pos.z == before;
        app.menu.opened = False;
        for i in range(30) {
            app.physics_clock.accumulator = app.physics_clock.tick_rate;
            app.skip_time = True;
            assert app.step();
        }
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(1), p0=i32(32), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        assert player.pos.z > before;
        assert player.water_depth == level.immersion(player.pos).depth;
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_swim_" + game + "_after.png");
        print("SWIM RENDER PASS", game, name, "rise", player.pos.z - before);
        app.quake.close();
    }
    renderer.close();
}
