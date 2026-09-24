"""Native timing of Q3 bot bodies: every bot drawn every frame (culling off),
against the same frames without models, and the combat tick with the bots
thinking. Runs unchanged on older trees for comparison."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatTick }
import from engine.world.bot_tactics { BotTactics }
import from vendor.raylib { def GetTime -> f64;  }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    for name in ["q3dm7", "q3dm6"] {
        app.load_destination("q3", name);
        assert not app.menu.opened , app.menu.message;
        app.culling = False;
        bots = len([bot for bot in [app.world->:HasOpponent:->][?:Opponent] if bot.arena]);
        app.player.health = 100000;
        app.player.god_mode = True;
        # Let the bots spread out and fight so their bodies animate.
        for i in range(240) {
            app.world spawn CombatTick(player=app.player, collision=app.level.collision, state=app.combat, dt=1.0 / 120.0, arena_live=True);
            app.world spawn BotTactics(player=app.player, collision=app.level.collision, state=app.combat, rules=app.combat.rules, dt=1.0 / 120.0);
        }
        resources = app.models.resources;
        results: dict[str, float] = {};
        for mode in ["full", "without_models", "full_repeat"] {
            app.models.resources = {} if mode == "without_models" else resources;
            for i in range(30) {
                app.render_frame();
            }
            start = float(GetTime());
            for i in range(180) {
                app.render_frame();
            }
            results[mode] = (float(GetTime()) - start) * 1000.0 / 180.0;
            print("PERF", name, mode, "ms/frame", results[mode]);
        }
        full = min(results["full"], results["full_repeat"]);
        print("PERF", name, "bots", bots, "model ms/frame", full - results["without_models"],
            "per bot", (full - results["without_models"]) / float(max(1, bots)));
        start = float(GetTime());
        for i in range(240) {
            app.world spawn CombatTick(player=app.player, collision=app.level.collision, state=app.combat, dt=1.0 / 120.0, arena_live=True);
            app.world spawn BotTactics(player=app.player, collision=app.level.collision, state=app.combat, rules=app.combat.rules, dt=1.0 / 120.0);
        }
        print("PERF", name, "combat+tactics ms/tick", (float(GetTime()) - start) * 1000.0 / 240.0);
    }
    app.models.close();
    app.quake.close();
    renderer.close();
}
