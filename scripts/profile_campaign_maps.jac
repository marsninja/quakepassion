"""Campaign map frame and per-system timing on original assets.

Loads each map in `QP_PROFILE_MAPS` (default: the heavy Q1/Q2 maps plus
reference maps) through the real App, with god mode and the player idle at
the start. For each map it measures the real game loop (`App.step`, render
included, frame dt from the renderer so a slow frame owes more ticks, as in
play), the time to draw the view alone, and the per-tick cost of the main
simulation walkers spawned on their own at the 120 Hz physics step. It does this twice: with the level as
loaded ("idle") and after waking every monster within 1500 units, which
then hunts and fights the player ("awake").

    jac build scripts/profile_campaign_maps.jac --native -o .jac/profile-campaign
    QP_PROFILE_MAPS="q1:e4m7,q2:train" DYLD_LIBRARY_PATH=vendor .jac/profile-campaign

Nothing is saved. Run it with no other heavy work on the machine when
comparing numbers, and compare runs made back to back."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player, ThinkPass }
import from engine.world.combat { CombatTick, Opponent, HasOpponent }
import from engine.world.doors { DoorTick, Door, HasDoor }
import from engine.world.trains { TrainTick, Train, HasTrain }
import from engine.world.rotators { RotatorTick, Rotator, HasRotator }
import from engine.world.targets { TargetTick }
import from engine.world.triggers { MonsterJumpTick }
import from engine.world.traversal { TeleportMonsters }
import from engine.world.patrols { PatrolTick }
import from engine.math.vec3 { Vec3 }
import from vendor.raylib { def GetTime -> f64;  }

glob PROFILE_DEFAULT_MAPS: str = "q1:e4m7,q1:e1m3,q1:e2m6,q2:bunk1,q2:train,q2:ware1,q2:ware2,q2:jail4,q2:boss1,q2:base1";

def:priv percentile(values: list[float], fraction: float) -> float {
    ordered = sorted(values);
    return ordered[min(len(ordered) - 1, int(fraction * float(len(ordered))))];
}

"""Median and p90 of `frames` App.step frames, in milliseconds."""
def:priv profile_frames(app: App, frames: int) -> list[float] {
    times: list[float] = [];
    for i in range(frames) {
        start = float(GetTime());
        app.step();
        times.append((float(GetTime()) - start) * 1000.0);
    }
    return [percentile(times, 0.5), percentile(times, 0.9)];
}

"""Median milliseconds of drawing the current view, with no simulation."""
def:priv profile_render(app: App, frames: int) -> float {
    times: list[float] = [];
    for i in range(frames) {
        start = float(GetTime());
        app.render_frame();
        times.append((float(GetTime()) - start) * 1000.0);
    }
    return percentile(times, 0.5);
}

"""Per-tick milliseconds of each simulation walker, spawned alone."""
def:priv profile_systems(app: App, ticks: int) -> list[str] {
    world = app.world;
    level = app.level;
    player = app.player;
    dt = app.physics_clock.tick_rate;
    costs: list[str] = [];
    for name in [
        "TrainTick",
        "DoorTick",
        "RotatorTick",
        "CombatTick",
        "MonsterJumpTick",
        "TargetTick",
        "TeleportMonsters",
        "PatrolTick",
        "ThinkPass"
    ] {
        if name == "MonsterJumpTick" and level.bsp.game == "q3" {
            continue;
        }
        start = float(GetTime());
        for i in range(ticks) {
            if name == "TrainTick" {
                world spawn TrainTick(bsp=level.bsp, collision=level.collision, dt=dt, player=player);
            } elif name == "DoorTick" {
                world spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=player.pos.sub(Vec3(z=level.collision.eye_height)),
                    dt=dt,
                    touching=True,
                    player=player
                );
            } elif name == "RotatorTick" {
                world spawn RotatorTick(bsp=level.bsp, collision=level.collision, dt=dt, player=player);
            } elif name == "CombatTick" {
                world spawn CombatTick(player=player, collision=level.collision, state=app.combat, dt=dt);
            } elif name == "MonsterJumpTick" {
                world spawn MonsterJumpTick();
            } elif name == "TargetTick" {
                world spawn TargetTick(player=player, collision=level.collision, state=app.combat, dt=dt);
            } elif name == "TeleportMonsters" {
                world spawn TeleportMonsters(
                    collision=level.collision,
                    dt=dt,
                    player=player,
                    player_height=level.collision.eye_height,
                    tally=app.combat
                );
            } elif name == "PatrolTick" {
                world spawn PatrolTick(dt=dt);
            } else {
                world spawn ThinkPass(dt=app.clock.tick_rate);
            }
        }
        cost = (float(GetTime()) - start) * 1000.0 / float(ticks);
        costs.append(name + "=" + str(round(cost, 3)));
    }
    return costs;
}

def:priv roster(world: World) -> str {
    monsters = [enemy for enemy in [world->:HasOpponent:->][?:Opponent]];
    live = [enemy for enemy in monsters if enemy.health > 0 and not enemy.dormant];
    alert = [enemy for enemy in live if enemy.alert > 0.0];
    return "monsters " + str(len(live)) + "/" + str(len(monsters))
        + " alert " + str(len(alert))
        + " doors " + str(len([world->:HasDoor:->][?:Door]))
        + " trains " + str(len([world->:HasTrain:->][?:Train]))
        + " rotators " + str(len([world->:HasRotator:->][?:Rotator]));
}

with entry {
    frames = int(os.getenv("QP_PROFILE_FRAMES", "120"));
    ticks = int(os.getenv("QP_PROFILE_TICKS", "60"));
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        save_path=".jac/profile-campaign-save.txt",
        smoke=True,
        overlay=False
    );
    for spec in os.getenv("QP_PROFILE_MAPS", PROFILE_DEFAULT_MAPS).split(",") {
        parts = spec.strip().split(":");
        game = parts[0];
        name = parts[1];
        app.smoke = True;
        app.load_destination(game, name);
        if not app.level.active or app.menu.opened {
            print("PROFILE FAIL", game, name, app.menu.message);
            app.menu.opened = False;
            continue;
        }
        if not app.audio.ready {
            app.audio.open(game, game_directory(game));
        }
        app.audio.volume = 0.0;
        app.smoke = False;
        app.walking = True;
        app.player.god_mode = True;
        app.skip_time = True;
        for mode in ["idle", "awake"] {
            if mode == "awake" {
                # A firefight: every monster in reach hunts the player.
                for enemy in [app.world->:HasOpponent:->][?:Opponent] {
                    if enemy.health > 0
                        and not enemy.dormant
                        and enemy.pos.sub(app.player.pos).length() < 1500.0 {
                        enemy.alert = 8.0;
                        enemy.last_seen = app.player.pos.add(Vec3());
                        enemy.last_seen_height = app.level.collision.eye_height;
                    }
                }
            }
            for i in range(30) {
                app.step();
            }
            summary = roster(app.world);
            stats = profile_frames(app, frames);
            drawing = profile_render(app, 30);
            systems = profile_systems(app, ticks);
            print(
                "PROFILE",
                game + ":" + name,
                mode,
                "frame_ms median",
                round(stats[0], 2),
                "p90",
                round(stats[1], 2),
                "render",
                round(drawing, 2),
                "|",
                summary
            );
            print("PROFILE", game + ":" + name, mode, "tick_ms", " ".join(systems));
        }
    }
    app.audio.close();
    app.models.close();
    app.effects.close();
    app.viewweapon.close();
    app.quake.close();
    renderer.close();
}
