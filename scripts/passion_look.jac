"""Look at a level the way a player first sees it: screenshots from the
places with the widest views, for comparing generated expeditions with the
original games' levels by eye.

    jac build scripts/passion_look.jac --native -o .jac/qp-look
    QP_LOOK_GAME=passion QP_LOOK_MAP=v3-42 DYLD_LIBRARY_PATH=vendor .jac/qp-look
    QP_LOOK_GAME=q1 QP_LOOK_MAP=e1m1 DYLD_LIBRARY_PATH=vendor .jac/qp-look

The real game loads the level (QP_LOOK_GAME, QP_LOOK_MAP) and the yardstick
samples where a player can stand; QP_LOOK_SHOTS views (default 8) are taken
from the standing places with the longest sightlines, at least 640 units
apart, each looking along its longest line of sight, saved as
<prefix>_<n>.png in the working directory (QP_LOOK_PREFIX, default
look_<game>_<map>)."""
import os;
import math;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }
import from games.passion.yardstick { traverse, mover_hulls, Footing, STAND_Z, EYE_RISE, area_path, level_start, level_exit }
import from games.passion.generate { survey_of }

def capture_view(app: App, renderer: Renderer, name: str) {
    for frame in range(3) {
        app.render_frame();
    }
    renderer.screenshot(name);
}

with entry {
    game = os.environ.get("QP_LOOK_GAME", "passion");
    level_name = os.environ.get("QP_LOOK_MAP", "v3-42");
    shots = int(os.environ.get("QP_LOOK_SHOTS", "8"));
    prefix = os.environ.get("QP_LOOK_PREFIX", "look_" + game + "_" + level_name.replace("-", "_"));
    print("LOOK game=" + game + " map=" + level_name);
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.host.overlay.assign("0");
    began = time.perf_counter();
    app.load_destination(game, level_name);
    print("LOOK load seconds=" + str(round(time.perf_counter() - began, 2)));
    if app.menu.opened {
        print("LOOK load failed: " + app.menu.message);
    }
    level = app.level;
    collision = level.collision;
    walk = traverse(level.bsp, collision, 32.0);
    exclude = mover_hulls(collision, level.bsp);
    # Each standing place's longest line of sight at eye height.
    scored: list[list[float]] = [];
    stride = max(1, len(walk.places) // 2500);
    for index in range(0, len(walk.places), stride) {
        place = walk.places[index];
        eye = Vec3(x=place.x, y=place.y, z=place.z + EYE_RISE);
        best = 0.0;
        best_angle = 0.0;
        total = 0.0;
        for turn in range(16) {
            angle = float(turn) * math.pi / 8.0;
            far = Vec3(x=eye.x + 4096.0 * math.cos(angle), y=eye.y + 4096.0 * math.sin(angle), z=eye.z);
            look = collision.trace_point(eye, far, exclude);
            reach = look.end.sub(eye).length();
            total += reach;
            if reach > best {
                best = reach;
                best_angle = angle;
            }
        }
        scored.append([total / 16.0 + 0.25 * best, float(index), best_angle]);
    }
    chosen: list[list[float]] = [];
    while len(chosen) < shots and scored {
        pick = -1;
        for (at, item) in enumerate(scored) {
            place = walk.places[int(item[1])];
            clear = True;
            for taken in chosen {
                other = walk.places[int(taken[1])];
                if Vec3(x=place.x - other.x, y=place.y - other.y, z=(place.z - other.z) * 2.0).length() < 640.0 {
                    clear = False;
                }
            }
            if clear and (pick < 0 or item[0] > scored[pick][0]) {
                pick = at;
            }
        }
        if pick < 0 {
            break;
        }
        chosen.append(scored[pick]);
        scored.pop(pick);
    }
    if os.environ.get("QP_LOOK_ROUTE", "") {
        # A walk from the start to the way out: frames along the shortest
        # route, each looking ahead along it.
        start = level_start(level.bsp);
        finish = level_exit(level.bsp);
        record = survey_of(app.world);
        if record is not None and record.casting is not None and record.casting.exit_low {
            low = record.casting.exit_low;
            high = record.casting.exit_high;
            finish = Vec3(x=(low[0] + high[0]) * 0.5, y=(low[1] + high[1]) * 0.5, z=low[2] + 24.0);
        }
        if start is None or finish is None {
            print("LOOK route: no start or no way out");
            return;
        }
        first = walk.nearest(start);
        last = walk.nearest(finish, 256.0);
        if first < 0 or last < 0 {
            print("LOOK route: start or way out has nowhere to stand");
            return;
        }
        path = area_path(walk.areas, walk.places[first].area, walk.places[last].area);
        print("LOOK route areas=" + str(len(path)));
        middles: dict[int, Footing] = {};
        for place in walk.places {
            area = walk.areas[place.area];
            if place.area not in middles {
                middles[place.area] = place;
                continue;
            }
            kept = middles[place.area];
            if abs(place.x - area.x) + abs(place.y - area.y) < abs(kept.x - area.x) + abs(kept.y - area.y) {
                middles[place.area] = place;
            }
        }
        frames = max(1, shots);
        for number in range(frames) {
            at = (len(path) - 1) * number // max(1, frames - 1) if frames > 1 else 0;
            ahead = min(len(path) - 1, at + 3);
            here_place = middles[path[at]];
            there = walk.areas[path[ahead]];
            app.player.pos = Vec3(x=here_place.x, y=here_place.y, z=here_place.z + collision.eye_height);
            if ahead != at {
                app.player.yaw = math.atan2(there.y - here_place.y, there.x - here_place.x);
            }
            app.player.pitch = max(-0.5, min(0.5, math.atan2(there.z - here_place.z, max(64.0, Vec3(x=there.x - here_place.x, y=there.y - here_place.y).length()))));
            name = prefix + "_route_" + str(number) + ".png";
            capture_view(app, renderer, name);
            print("LOOK route " + str(number) + " area " + str(at) + "/" + str(len(path)) + " at " + str(int(here_place.x)) + " " + str(int(here_place.y)) + " " + str(int(here_place.z)) + " file=" + name);
        }
        return;
    }
    for (number, item) in enumerate(chosen) {
        place = walk.places[int(item[1])];
        app.player.pos = Vec3(x=place.x, y=place.y, z=place.z - STAND_Z + collision.eye_height + 24.0);
        app.player.yaw = item[2];
        app.player.pitch = -0.08;
        name = prefix + "_" + str(number) + ".png";
        capture_view(app, renderer, name);
        print(
            "LOOK view " + str(number) + " at " + str(int(place.x)) + " " + str(int(place.y)) + " " + str(int(place.z))
                + " yaw=" + str(int(math.degrees(item[2]))) + " score=" + str(int(item[0])) + " file=" + name
        );
    }
    print("LOOK places=" + str(len(walk.places)) + " views=" + str(len(chosen)));
}
