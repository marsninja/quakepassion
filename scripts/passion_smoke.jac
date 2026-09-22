"""Native seeded geometry, mixed source assets and objective validation."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.inventory { quantity }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.models { ModelResource, HasModelResource }
import from engine.math.vec3 { Vec3 }
import os;
import time;
import from scripts.input_events { key, click }
import from engine.input.input { _release }
import from engine.physics.movement { MovePlayer }
import from games.passion.plan { make_plan, route, Contains, Chamber }
with entry {
    assert os.getenv("QP_VALIDATE_HOME", "") == os.getenv("HOME", "missing");
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(), player=Player(), renderer=renderer, clock=Clock(), overlay=False
    );
    try {
        app.load_destination("passion", "v1-42");
        if app.menu.opened {
            print("PASSION LOAD FAILED:", app.menu.message);
        }
        assert not app.menu.opened , app.menu.message;
        assert app.level.bsp.game == "passion" and len(app.level.areas) == 20;
        assert not app.level.collision.trace(
            app.player.pos, app.player.pos
        ).start_solid;
        for source in ["q1:", "q2:", "q3:"] {
            assert [
                resource
                for resource in [app.world->:HasModelResource:->][?:ModelResource]
                if resource.name.startswith(source)
            ];
        }
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_passion.png");
        key(app, 256);
        assert app.menu.opened and app.menu.game == 3 and "v1-42" in app.menu.maps;
        renderer.screenshot("qp_passion_menu.png");
        key(app, 256);
        plan = make_plan(42);
        rooms = [plan->:Contains:->][?:Chamber];
        starting_position = app.player.pos;
        for theme in range(3) {
            room = [
                r
                for r in rooms
                if r.theme == theme and r.role != "extraction"
            ][0];
            app.player.pos = Vec3(
                x=float(room.x) * 640.0 + 320.0,
                y=float(room.y) * 640.0 + 320.0,
                z=float(room.y) * 32.0 + 46.0
            );
            app.player.yaw = 0.6;
            for frame in range(3) {
                app.render_frame();
            }
            renderer.screenshot("qp_passion_theme_" + str(theme) + ".png");
            if theme == 2 {
                app.combat.flash = 0.04;
                for frame in range(3) {
                    app.render_frame();
                }
                renderer.screenshot("qp_passion_flash.png");
                assert app.level.lighting.dynamic;
                app.combat.flash = 0.0;
                app.render_frame();
                assert not app.level.lighting.dynamic;
                if os.getenv("QP_LIGHT_BENCH", "") {
                    started = time.perf_counter();
                    for frame in range(120) {
                        app.render_frame();
                    }
                    print(
                        "PASSION LIGHTING frame ms",
                        (time.perf_counter() - started) * 1000.0 / 120.0
                    );
                }
            }
        }
        app.player.pos = Vec3(x=1600.0, y=1120.0, z=78.0);
        app.player.yaw = -1.57079632679;
        for frame in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_passion_bridge.png");
        app.player.pos = starting_position;
        current = 0;
        destinations = plan.key_rooms + [19];
        for destination in destinations {
            path = route(plan, current, destination);
            for index in path[1:] {
                room = rooms[index];
                target = Vec3(
                    x=float(room.x) * 640.0 + 320.0,
                    y=float(room.y) * 640.0 + 320.0,
                    z=float(room.y) * 32.0 + 46.0
                );
                for tick in range(600) {
                    delta = target.sub(app.player.pos);
                    if Vec3(x=delta.x, y=delta.y).length() < 8.0 {
                        break;
                    }
                    before = app.player.pos.sub(Vec3(z=app.level.collision.eye_height));
                    app.world spawn DoorTick(
                        bsp=app.level.bsp,
                        collision=app.level.collision,
                        player=app.player,
                        player_origin=before,
                        dt=1.0 / 120.0
                    );
                    app.player spawn MovePlayer(
                        collision=app.level.collision,
                        wish=Vec3(x=delta.x, y=delta.y).normalized(),
                        dt=1.0 / 120.0
                    );
                    app.world spawn PickupTick(
                        player=app.player,
                        start=before,
                        finish=app.player.pos.sub(
                            Vec3(z=app.level.collision.eye_height)
                        ),
                        dt=1.0 / 120.0
                    );
                }
                assert target.sub(app.player.pos).length() < 12.0 , "Route blocked at room "
                    + str(index);
                app.player.velocity = Vec3();
            }
            current = destination;
            print("PASSION ROUTE", destination);
        }
        door = [app.world->:HasDoor:->][?:Door][0];
        assert door.unlocked;
        assert quantity(app.player.inventory, "key_gold") == 0
            and quantity(app.player.inventory, "key_silver") == 0;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        assert app.step() and app.expedition_complete;
        for frame in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_passion_complete.png");
        app.quicksave();
        assert app.notice == "Saved - F9 to load" , app.notice;
        app.load_destination("q1", "e1m1");
        app.quickload();
        assert app.notice == "Loaded"
            and app.level.name == "v1-42"
            and app.expedition_complete;
        key(app, 257);
        assert not app.expedition_complete and app.level.name == "v1-42";
        app.load_destination("passion", "v2-42");
        assert app.menu.opened and app.level.name == "v1-42";
        key(app, 256);
        key(app, 256);
        click(app, 865, 165);
        assert app.menu.game == 3 and app.menu.maps;
        selected = app.menu.maps[app.menu.selected];
        key(app, 257);
        assert not app.menu.opened and app.level.name == selected;
        print(
            "PASSION PASS: mixed assets, objectives, completion, persistence, replay, menu seeds, rollback"
        );
    } finally {
        _release();
        app.audio.close();
        app.models.close();
        app.quake.close();
        renderer.close();
    }
}
