"""Ride every way up or down a Passion expedition's stacked rooms have, in
the real game, and say whether it carries the player.

    jac build scripts/passion_connectors.jac --native -o .jac/qp-connectors
    QP_GAME=passion QP_SEEDS="15 84" DYLD_LIBRARY_PATH=vendor .jac/qp-connectors

For each connector of each seed (QP_SEEDS, default 15) the player is set
down where a body would use it and the game steps on, with god mode on:

- a lift: on its platform at the bottom, standing still; it must carry
  the player up to the upper floor;
- a jump pad: on the pad; it must throw the player up the column and set
  them down on the upper floor beside the hole;
- a drop: over the hole on the upper floor; the player must land on the
  lower floor;
- water: at the bottom of the flooded shaft, swimming up (jump held); the
  player must come out at the upper floor.

A line `CONNECTOR seed=... <kind> PASS|FAIL <why>` for each, and a total."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.input.input { Intent }
import from engine.math.vec3 { Vec3 }
import from games.passion.generate { survey_of, Survey, level_name }
import from games.passion.arrange { estate_corridors }
import from games.passion.massing { CELL, LIFT }

def:priv tick(app: App, jump: bool) {
    app.scripted = Intent(move=Vec3(z=1.0 if jump else 0.0), jump=jump);
    app.skip_time = True;
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.step();
}

"""Set the player's feet at a point, at rest (the body's origin stands 24
units over its feet)."""
def:priv stand_at(app: App, x: float, y: float, z: float) {
    app.player.pos = Vec3(x=x, y=y, z=z + 24.0 + app.level.collision.eye_height);
    app.player.velocity = Vec3();
}

def:priv feet(app: App) -> Vec3 {
    return app.player.pos.sub(Vec3(z=app.level.collision.eye_height + 24.0));
}

"""Ride one connector; the reason it failed, or ""."""
def:priv ride(app: App, kind: str, column: list[int], low: int, high: int, landing: list[int]) -> str {
    middle_x = (float(column[0]) + 1.0) * CELL;
    middle_y = (float(column[1]) + 1.0) * CELL;
    low_z = float(low) * LIFT;
    high_z = float(high) * LIFT;
    frames = 0;
    best = -100000.0;
    if kind == "lift" {
        stand_at(app, middle_x, middle_y, low_z + 2.0);
        while frames < 900 {
            tick(app, False);
            frames += 1;
            best = max(best, feet(app).z);
            if feet(app).z >= high_z - 4.0 {
                return "";
            }
        }
        return "rose only to " + str(int(best)) + " of " + str(int(high_z));
    }
    if kind == "jumppad" {
        stand_at(app, middle_x, middle_y, low_z + 6.0);
        while frames < 600 {
            tick(app, False);
            frames += 1;
            at = feet(app);
            best = max(best, at.z);
            if frames > 30 and app.player.grounded and abs(at.z - high_z) < 8.0 {
                return "";
            }
        }
        return "rose to " + str(int(best)) + " of " + str(int(high_z)) + ", ended at " + str(int(feet(app).x)) + "," + str(int(feet(app).y)) + "," + str(int(feet(app).z));
    }
    if kind == "drop" {
        stand_at(app, middle_x, middle_y, high_z + 24.0);
        while frames < 600 {
            tick(app, False);
            frames += 1;
            if app.player.grounded and abs(feet(app).z - low_z) < 8.0 {
                return "";
            }
        }
        return "came to rest at " + str(int(feet(app).z)) + ", not " + str(int(low_z));
    }
    if kind == "water" {
        stand_at(app, middle_x, middle_y, low_z + 2.0);
        while frames < 1500 {
            tick(app, True);
            frames += 1;
            best = max(best, feet(app).z);
            if feet(app).z >= high_z - 24.0 {
                return "";
            }
        }
        return "swam only to " + str(int(best)) + " of " + str(int(high_z));
    }
    return "unknown connector " + kind;
}

with entry {
    seeds = (os.environ.get("QP_SEEDS", "15")).split();
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.host.overlay.assign("0");
    passed = 0;
    failed = 0;
    for word in seeds {
        app.load_destination("passion", level_name(int(word), 1));
        if app.menu.opened {
            print("CONNECTOR seed=" + word + " FAIL load: " + app.menu.message);
            failed += 1;
            continue;
        }
        app.player.god_mode = True;
        found = survey_of(app.world);
        if found is None {
            continue;
        }
        record: Survey = found;
        estate = record.estate;
        if estate is None {
            continue;
        }
        for corridor in estate_corridors(estate) {
            if not corridor.connector or len(corridor.column) != 2 {
                continue;
            }
            # Let a lift come to rest at the bottom first.
            for frame in range(240) {
                tick(app, False);
            }
            why = ride(app, corridor.connector, corridor.column, corridor.low, corridor.high, corridor.landing);
            if why {
                failed += 1;
                print("CONNECTOR seed=" + word + " " + corridor.connector + " at " + str(corridor.column) + " FAIL " + why);
            } else {
                passed += 1;
                print("CONNECTOR seed=" + word + " " + corridor.connector + " at " + str(corridor.column) + " PASS");
            }
        }
    }
    print("CONNECTOR " + str(passed) + " passed, " + str(failed) + " failed");
}
