"""Native Q1/Q2 model lighting cost: render frames of one map's fixed view
with models lit from the lightmaps and unlit (no light point source), in
alternating blocks, and print each stage's mean render time. No settings or
save writes.

QP_GAME / QP_MAP pick the map (default q1 e1m1); QP_PROFILE_BLOCKS the number
of lit/unlit block pairs (default 4) of QP_PROFILE_FRAMES frames each
(default 240); QP_PROFILE_HOLD=lit|unlit renders that mode for
QP_PROFILE_SECONDS (default 20) first, for a sampling profiler to attach."""
import os;
import from engine.core.app { App, RenderTimes }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from vendor.raylib { def GetTime -> f64;  }

"""Summed stage times over a block of frames."""
obj StageTotals {
    has frames: int = 0,
        total: float = 0.0,
        visible: float = 0.0,
        portal: float = 0.0,
        world: float = 0.0,
        models: float = 0.0,
        effects: float = 0.0,
        weapon: float = 0.0,
        present: float = 0.0;

    def add(times: RenderTimes, frame: float) {
        self.frames += 1;
        self.total += frame;
        self.visible += times.visible;
        self.portal += times.portal;
        self.world += times.world;
        self.models += times.models;
        self.effects += times.effects;
        self.weapon += times.weapon;
        self.present += times.present;
    }

    def print_summary(label: str) {
        n = float(max(1, self.frames));
        print(
            "PERF", label, "frame", round(self.total / n, 3), "models", round(self.models / n, 3),
            "world", round(self.world / n, 3), "effects", round(self.effects / n, 3), "weapon",
            round(self.weapon / n, 3), "visible", round(self.visible / n, 3), "portal",
            round(self.portal / n, 3), "present", round(self.present / n, 3)
        );
    }
}

def render_block(app: App, frames: int) -> StageTotals {
    totals = StageTotals();
    for i in range(frames) {
        start = float(GetTime());
        app.render_frame();
        totals.add(app.render_times, (float(GetTime()) - start) * 1000.0);
    }
    return totals;
}

with entry {
    game = os.environ.get("QP_GAME", "q1");
    level = os.environ.get("QP_MAP", "e1m1" if game == "q1" else "base1");
    blocks = int(os.environ.get("QP_PROFILE_BLOCKS", "4"));
    frames = int(os.environ.get("QP_PROFILE_FRAMES", "240"));
    hold = os.environ.get("QP_PROFILE_HOLD", "");
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    app.host.overlay.assign("0");
    app.load_destination(game, level);
    assert not app.menu.opened , app.menu.message;
    if not app.audio.ready {
        app.audio.open(game, game_directory(game));
    }
    app.audio.volume.assign("0");
    lighting = app.level.lighting;
    source = lighting.point;
    render_block(app, 60);
    if hold {
        lighting.point = source if hold == "lit" else None;
        seconds = float(os.environ.get("QP_PROFILE_SECONDS", "20"));
        start = float(GetTime());
        held = StageTotals();
        while float(GetTime()) - start < seconds {
            held.add(app.render_times, 0.0);
            app.render_frame();
        }
        held.print_summary("hold-" + hold);
    }
    lit = StageTotals();
    unlit = StageTotals();
    for block in range(blocks) {
        lighting.point = source;
        block_lit = render_block(app, frames);
        lighting.point = None;
        block_unlit = render_block(app, frames);
        block_lit.print_summary("lit");
        block_unlit.print_summary("unlit");
        for (into, part) in [(lit, block_lit), (unlit, block_unlit)] {
            into.frames += part.frames;
            into.total += part.total;
            into.visible += part.visible;
            into.portal += part.portal;
            into.world += part.world;
            into.models += part.models;
            into.effects += part.effects;
            into.weapon += part.weapon;
            into.present += part.present;
        }
    }
    lighting.point = source;
    lit.print_summary(game + " " + level + " lit mean");
    unlit.print_summary(game + " " + level + " unlit mean");
    app.audio.close();
    app.models.close();
    app.effects.close();
    app.viewweapon.close();
    app.quake.close();
    renderer.close();
}
