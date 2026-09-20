"""Held-Control crouching through the normal app input and physics loop."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }
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

def frame(app: App) {
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.skip_time = True;
    assert app.step();
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q2", "q3"] {
        name = "base1" if game == "q2" else "q3dm1";
        world = World();
        level = load_level(world, game_directory(game), name, game);
        player = spawn_player(level);
        app = App(
            world=world,
            player=player,
            level=level,
            renderer=renderer,
            clock=Clock(),
            walking=True,
            overlay=False,
            culling=False
        );
        app.quake.upload(level);
        for i in range(120) {
            frame(app);
        }
        assert player.grounded;
        eye = player.pos.z;
        origin = player.pos.sub(Vec3(z=level.collision.eye_height));
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_crouch_" + game + "_standing.png");
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(2), p0=i32(341), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        app.menu.opened = True;
        frame(app);
        assert not player.crouched and player.pos.z == eye;
        app.menu.opened = False;
        frame(app);
        assert player.crouched;
        assert abs(player.pos.sub(Vec3(z=level.collision.eye_height)).z - origin.z)
            < 0.1;
        assert abs(eye - player.pos.z - (24.0 if game == "q2" else 14.0)) < 0.1;
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_crouch_" + game + "_ducked.png");
        PlayAutomationEvent(
            AutomationEvent(
                frame=u32(0), kind=u32(1), p0=i32(341), p1=i32(0), p2=i32(0), p3=i32(0)
            )
        );
        frame(app);
        assert not player.crouched and abs(player.pos.z - eye) < 0.1;
        print("CROUCH RENDER PASS", game, name);
        app.quake.close();
    }
    renderer.close();
}
