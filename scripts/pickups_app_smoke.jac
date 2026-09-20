"""Exercise item collection and scene replacement through the native application."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(), player=Player(), renderer=renderer, clock=Clock(), overlay=False
    );
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        app.load_destination(game, name);
        assert app.level.active and app.level.bsp.game == game and not app.menu.opened;
        pickups = [app.world->:HasPickup:->][?:Pickup];
        assert pickups and app.models.resources;
        found = False;
        for item in pickups {
            if item.rule.kind != "health" {
                continue;
            }
            origin = item.pos.add(Vec3(z=24.0));
            if app.level.collision.trace(origin, origin).start_solid {
                continue;
            }
            app.player.pos = origin.add(Vec3(z=app.level.collision.eye_height));
            app.player.health = 1;
            app.menu.opened = True;
            app.skip_time = True;
            app.physics_clock.accumulator = app.physics_clock.tick_rate;
            assert app.step();
            assert app.player.health == 1 and item.active;
            app.menu.opened = False;
            app.skip_time = True;
            app.physics_clock.accumulator = app.physics_clock.tick_rate;
            assert app.step();
            assert app.player.health > 1
                and not item.active
                and not item.visual.visible;
            found = True;
            break;
        }
        assert found;
        previous = app.world;
        resources = len(app.models.resources);
        app.load_destination(game, "__missing_pickup_test__");
        assert app.world is previous and len(app.models.resources) == resources;
        assert app.menu.opened and app.menu.message;
        app.menu.opened = False;
        app.render_frame();
        print("PICKUPS APP PASS", game, "load pause collect rollback");
    }
    app.models.close();
    app.quake.close();
    renderer.close();
}
