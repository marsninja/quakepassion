"""Render benchmark: frame time and per-stage render cost on original maps.

Each map in QP_BENCH_MAPS is loaded as the menu loads it. The player stands
at the start in god mode while the view turns a full circle over QP_BENCH_FRAMES
frames (default 600), so every direction is drawn. For each map it prints the
median and 95th percentile frame time, the frame rate at the median, and the
median cost of each render stage (App.render_times). Run it on a quiet
machine and compare runs made back to back. With QP_BENCH_SHOTS=1 it also
saves four views per map, a quarter turn apart, as bench_<map>_<n>.png in the
working directory, for comparing renderers by eye; QP_BENCH_DT fixes each
frame's time step (e.g. 0.01), so renderers of different speeds show the same
moment of every animation in each view. With QP_BENCH_COMBAT=1 the view fills
with combat effects while it turns (combat_effects): explosions, rail and
lightning trails, impact sprays, wall marks and missiles, so the effects stage
carries a fight's load.

    jac build scripts/render_benchmark.jac --native -o .jac/render-benchmark
    DYLD_LIBRARY_PATH=vendor .jac/render-benchmark
"""
import os;
import math;
import time;
import from engine.core.app { App, RenderTimes }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.arena { match_of }
import from engine.world.combat { Projectile, HasProjectile }
import from engine.world.particles {
    explode,
    rail_trail,
    beam_trail,
    impact_spray,
    impact_mark
}
import from engine.math.vec3 { Vec3, forward_from, right_from }

glob BENCH_DEFAULT: str = "q1:e1m1,q1:e4m7,q2:base1,q2:bunk1,q2:train,q3:q3dm1,q3:q3dm7,q3:q3dm11,q3:q3dm12,q3:q3tourney2";

"""The median of `values`."""
def median_of(values: list[float]) -> float {
    ordered = sorted(values);
    return ordered[len(ordered) // 2] if ordered else 0.0;
}

"""Frame `i` of a steady fight in view: where the view meets a wall, sprays
every frame, a mark every other (Q3), an explosion every sixth, a rail or
lightning trail every third to tenth and a missile every eighth, all capped
by the world's own effect budgets."""
def combat_effects(app: App, game: str, i: int) {
    world = app.world;
    eye = app.player.pos;
    ahead = forward_from(app.player.yaw, 0.0);
    side = right_from(app.player.yaw);
    hit = app.level.collision.trace_point(eye, eye.add(ahead.scale(2048.0)));
    if hit.fraction >= 1.0 or hit.start_solid {
        return;
    }
    point = hit.end;
    normal = hit.normal;
    muzzle = eye.add(side.scale(8.0)).sub(Vec3(z=10.0));
    impact_spray(world, point, normal, blood=i % 2 == 0);
    if game == "q3" and i % 2 == 0 {
        shaders = ["gfx/damage/bullet_mrk", "gfx/damage/burn_med_mrk", "gfx/damage/hole_lg_mrk", "gfx/damage/plasma_mrk"];
        pick = (i // 2) % 4;
        impact_mark(world, shaders[pick], point, normal, [8.0, 32.0, 12.0, 16.0][pick], alpha_fade=pick == 3);
    }
    if i % 6 == 0 {
        kinds = {
            "q1": ["q1_explosion"],
            "q2": ["q2_explosion", "q2_grenade_explosion"],
            "q3": ["q3_rocket_explosion", "q3_grenade_explosion", "q3_plasma_explosion", "q3_bfg_explosion"]
        }.get(game, ["blast"]);
        explode(world, point.add(normal.scale(16.0)), kinds[(i // 6) % len(kinds)]);
    }
    if game == "q1" and i % 3 == 0 {
        beam_trail(world, muzzle, point, "player_lightning");
    }
    if game == "q2" and i % 10 == 0 {
        rail_trail(world, muzzle, point, "q2_rail");
    }
    if game == "q3" {
        if i % 10 == 0 {
            rail_trail(world, muzzle, point, "q3_rail");
        }
        if i % 3 == 0 {
            beam_trail(world, muzzle, point, "lightning");
        }
    }
    if i % 8 == 0 {
        effect = {"q1": "q1_rocket", "q2": "q2_bfg", "q3": "q3_plasma"}.get(game, "");
        world +>:HasProjectile:+> Projectile(
            pos=eye.add(ahead.scale(48.0)),
            velocity=ahead.scale(600.0),
            damage=0,
            effect=effect,
            remaining=3.0
        );
    }
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    frames = int(os.getenv("QP_BENCH_FRAMES", "600"));
    shots = os.getenv("QP_BENCH_SHOTS", "") != "";
    combat = os.getenv("QP_BENCH_COMBAT", "") != "";
    specs = os.getenv("QP_BENCH_MAPS", BENCH_DEFAULT).split(",");
    opened: list[str] = [];
    for spec in specs {
        game = spec.split(":")[0];
        name = spec.split(":")[1];
        app.smoke = True;
        app.load_destination(game, name);
        if game not in opened {
            app.audio.close();
            app.audio.open(game, game_directory(game));
            opened.append(game);
        }
        app.audio.volume = 0.0;
        app.smoke = False;
        app.walking = True;
        app.fixed_dt = float(os.getenv("QP_BENCH_DT", "0"));
        app.player.god_mode = True;
        # Q3: no warmup, so the scoreboard does not cover the view.
        contest = match_of(app.world);
        if contest is not None {
            contest.warmup = 0.0;
        }
        start_yaw = app.player.yaw;
        for i in range(60) {
            app.step();
        }
        times: list[float] = [];
        stages: dict[str, list[float]] = {
            "visible": [], "portal": [], "world": [], "models": [],
            "effects": [], "weapon": [], "hud": [], "present": []
        };
        for i in range(frames) {
            app.player.yaw = start_yaw + 2.0 * math.pi * float(i) / float(frames);
            app.player.pitch = 0.0;
            if combat {
                combat_effects(app, game, i);
            }
            started = time.time();
            app.step();
            times.append((time.time() - started) * 1000.0);
            if shots and i % (frames // 4) == 0 {
                renderer.screenshot("bench_" + name + "_" + str(i // (frames // 4)) + ".png");
            }
            r = app.render_times;
            stages["visible"].append(r.visible);
            stages["portal"].append(r.portal);
            stages["world"].append(r.world);
            stages["models"].append(r.models);
            stages["effects"].append(r.effects);
            stages["weapon"].append(r.weapon);
            stages["hud"].append(r.hud);
            stages["present"].append(r.present);
        }
        ordered = sorted(times);
        median = ordered[len(ordered) // 2];
        p95 = ordered[(len(ordered) * 95) // 100];
        parts = [key + "=" + str(round(median_of(values), 2)) for (key, values) in stages.items()];
        print(
            "BENCH", game + ":" + name,
            "fps", round(1000.0 / max(median, 0.001), 1),
            "median_ms", round(median, 2),
            "p95_ms", round(p95, 2),
            "|", " ".join(parts)
        );
    }
    renderer.close();
}
