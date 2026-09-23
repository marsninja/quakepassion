"""Native crowded-enemy benchmark. All original-map actors are alerted; attacks are held to isolate movement and navigation. No saves or settings are written."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatTick, HasOpponent, Opponent }
import from vendor.raylib { def GetTime -> f64; }
with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    for game in ["q1", "q2", "q3"] {
      for mode in ["routes", "no_route_search"] {
        app.load_destination(game, "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1"));
        assert not app.menu.opened, app.menu.message;
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        app.player.health = 100000;
        for enemy in enemies {
            enemy.alert = 100.0;
            enemy.last_seen = app.player.pos;
            enemy.last_seen_height = app.level.collision.eye_height;
            enemy.attack_wait = 100.0;
        }
        times: list[float] = [];
        for i in range(600) {
            if mode == "no_route_search" { app.combat.route_credit = -100.0; }
            start = float(GetTime());
            app.world spawn CombatTick(player=app.player, collision=app.level.collision, state=app.combat, dt=1.0 / 120.0);
            times.append((float(GetTime()) - start) * 1000.0);
        }
        ordered = sorted(times);
        total = 0.0;
        for value in times { total += value; }
        print("ENEMY_PERF", game, mode, "enemies", len(enemies), "mean", total / 600.0, "median", ordered[300], "p95", ordered[570], "max", ordered[599]);
    }
    }
    app.models.close();
    app.effects.close();
    app.viewweapon.close();
    app.quake.close();
    renderer.close();
}
