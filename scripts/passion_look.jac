"""Look at a level from given places, by eye:

    jac build scripts/passion_look.jac --native -o .jac/qp-look
    QP_LOOK_MAP=pfh-3 QP_LOOK_AT="x y z yaw pitch; ..." DYLD_LIBRARY_PATH=vendor .jac/qp-look

The real game loads the level (QP_LOOK_GAME, default passion; QP_LOOK_MAP) and
a view is saved from each place of QP_LOOK_AT (feet height, degrees), as
<prefix>_<n>.png in the working directory (QP_LOOK_PREFIX, default look).
QP_LOOK_REPORT=1 prints how the level's lightmaps spread, for Q1, Q2 and Passion
levels alike, and how far each pickup's model hangs over the floor."""
import os;
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.models { UsesModel, ModelResource }

"""The light a level's faces hold: how it spreads over the level, how much it
changes across a face and between neighbouring samples, and its lamps."""
def report_light(app: App) {
    bsp = app.level.bsp;
    if bsp.game == "q3" {
        print("LIGHT q3 lightmaps are shared pages: not read");
        return;
    }
    lamps = [entity for entity in bsp.entities if entity.fields.get("classname", "").startswith("light")];
    values: list[int] = [];
    swings: list[float] = [];
    steps: list[float] = [];
    channels = bsp.light_channels;
    for face in bsp.faces {
        if face.light_offset < 0 or face.light_width < 2 or face.light_height < 2 {
            continue;
        }
        low = 255;
        high = 0;
        total = 0.0;
        taken = 0;
        for y in range(face.light_height) {
            last = -1;
            for x in range(face.light_width) {
                at = face.light_offset + (y * face.light_width + x) * channels;
                if at + channels > len(bsp.lighting) {
                    continue;
                }
                value = max([bsp.lighting[at + channel] for channel in range(channels)]);
                values.append(value);
                low = min(low, value);
                high = max(high, value);
                if last >= 0 {
                    total += abs(float(value - last));
                    taken += 1;
                }
                last = value;
            }
        }
        if taken > 0 {
            swings.append(float(high - low));
            steps.append(total / float(taken));
        }
    }
    values.sort();
    swings.sort();
    steps.sort();
    count = max(1, len(values));
    picks = " ".join([str(share) + "%=" + str(values[count * share // 100]) for share in [5, 25, 50, 75, 95]]);
    levels: dict[str, int] = {};
    for lamp in lamps {
        word = str(int(float(lamp.fields.get("light", "300").split()[0])) // 50 * 50);
        levels[word] = levels.get(word, 0) + 1;
    }
    print("LIGHT levels " + str(levels));
    print("LIGHT " + bsp.game + " lamps " + str(len(lamps)) + " faces " + str(len(bsp.faces)) + " samples " + str(len(values)) + " " + picks);
    if swings {
        print("LIGHT swing across a face median " + str(swings[len(swings) // 2]) + " p90 " + str(swings[len(swings) * 9 // 10]) + "; step median " + str(round(steps[len(steps) // 2], 2)));
    }
}

"""How far over the floor each pickup's model hangs: its lowest point in its
first frame, less the floor straight under it, by the model's game."""
def report_items(app: App) {
    seen: dict[str, list[float]] = {};
    for item in [app.world->:HasPickup:->][?:Pickup] {
        resources = [item.visual->:UsesModel:->][?:ModelResource];
        if not resources {
            continue;
        }
        low = 1.0e9;
        high = -1.0e9;
        for surface in resources[0].model.surfaces {
            for vertex in surface.frames[0].vertices {
                low = min(low, vertex.z);
                high = max(high, vertex.z);
            }
        }
        floor = app.level.collision.trace_point(item.pos, item.pos.sub(Vec3(z=4096.0))).end.z;
        key = resources[0].name;
        if key not in seen {
            seen[key] = [item.pos.z + item.visual.offset.z - floor, low, high, 0.0];
        }
        seen[key][3] += 1.0;
    }
    for key in sorted(seen.keys()) {
        row = seen[key];
        print("ITEM " + key + " x" + str(int(row[3])) + " origin over floor " + str(round(row[0], 1)) + " model z " + str(round(row[1], 1)) + ".." + str(round(row[2], 1)) + " lowest point over floor " + str(round(row[0] + row[1], 1)));
    }
}

with entry {
    game = os.environ.get("QP_LOOK_GAME", "passion");
    map_name = os.environ.get("QP_LOOK_MAP", "pfh-1");
    prefix = os.environ.get("QP_LOOK_PREFIX", "look");
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.host.overlay.assign("0");
    app.load_destination(game, map_name);
    if app.menu.opened {
        print("LOOK load failed: " + app.menu.message);
    }
    if os.environ.get("QP_LOOK_REPORT", "") {
        report_light(app);
        report_items(app);
    }
    eye = app.level.collision.eye_height;
    for (number, view) in enumerate(os.environ.get("QP_LOOK_AT", "").split(";")) {
        words = [float(word) for word in view.split()];
        if len(words) < 4 {
            continue;
        }
        app.player.pos = Vec3(x=words[0], y=words[1], z=words[2] + eye);
        app.player.yaw = math.radians(words[3]);
        app.player.pitch = math.radians(words[4]) if len(words) > 4 else 0.0;
        for frame in range(3) {
            app.render_frame();
        }
        name = prefix + "_" + str(number) + ".png";
        renderer.screenshot(name);
        print("LOOK " + name);
    }
}
