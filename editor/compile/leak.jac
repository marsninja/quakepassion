"""The leak finder: whether the inside of a level reaches the void.

A level that is to be lit and culled properly is sealed: nothing inside it
can see out. The search floods from where the entities are, a cell at a
time, stopped by brushes; if it gets past the box round every brush the
level leaks, and the way it got there is the line to follow to the hole."""
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush { Side, brush_windings, windings_bounds, ray_enters_brush, brush_holds }

"""What a search found: whether the level is sealed, the way out when it is
not, and whether the search gave up (too large to flood at this cell size)."""
obj LeakReport {
    has sealed: bool = True,
        path: list[Vec3] = [],
        cells: int = 0,
        gave_up: bool = False;
}

"""Flood from `starts` through the space the brushes leave, in cells `cell`
units across, visiting at most `budget` of them."""
def find_leak(brushes: list[list[Side]], starts: list[Vec3], cell: float = 16.0, budget: int = 300000) -> LeakReport {
    outcome = LeakReport();
    lows: list[Vec3] = [];
    highs: list[Vec3] = [];
    solid: list[list[Side]] = [];
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    high = Vec3(x=-far, y=-far, z=-far);
    for sides in brushes {
        box = windings_bounds(brush_windings(sides));
        if box is None {
            continue;
        }
        solid.append(sides);
        lows.append(box[0]);
        highs.append(box[1]);
        low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
    }
    if len(solid) == 0 or len(starts) == 0 {
        # Nothing to be inside of: everything is the void.
        outcome.sealed = len(starts) == 0;
        return outcome;
    }
    # Whether a step from one point to the next is stopped by a brush.
    queue: list[list[int]] = [];
    came: dict[str, str] = {};
    for start in starts {
        home = [int((start.x - low.x) // cell), int((start.y - low.y) // cell), int((start.z - low.z) // cell)];
        key = str(home[0]) + "," + str(home[1]) + "," + str(home[2]);
        if key not in came {
            came[key] = "";
            queue.append(home);
        }
    }
    counts = [
        int((high.x - low.x) // cell) + 1, int((high.y - low.y) // cell) + 1, int((high.z - low.z) // cell) + 1
    ];
    steps = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    at = 0;
    out_key = "";
    while at < len(queue) {
        here = queue[at];
        at += 1;
        outcome.cells += 1;
        if outcome.cells > budget {
            outcome.gave_up = True;
            return outcome;
        }
        if here[0] < -1 or here[1] < -1 or here[2] < -1 or here[0] > counts[0] or here[1] > counts[1]
            or here[2] > counts[2] {
            out_key = str(here[0]) + "," + str(here[1]) + "," + str(here[2]);
            break;
        }
        middle = Vec3(
            x=low.x + (float(here[0]) + 0.5) * cell,
            y=low.y + (float(here[1]) + 0.5) * cell,
            z=low.z + (float(here[2]) + 0.5) * cell
        );
        for step in steps {
            there = [here[0] + step[0], here[1] + step[1], here[2] + step[2]];
            key = str(there[0]) + "," + str(there[1]) + "," + str(there[2]);
            if key in came {
                continue;
            }
            direction = Vec3(x=float(step[0]), y=float(step[1]), z=float(step[2]));
            goal = middle.add(direction.scale(cell));
            stopped = False;
            for b in range(len(solid)) {
                a = lows[b];
                c = highs[b];
                if min(middle.x, goal.x) > c.x or max(middle.x, goal.x) < a.x or min(middle.y, goal.y) > c.y
                    or max(middle.y, goal.y) < a.y or min(middle.z, goal.z) > c.z or max(middle.z, goal.z) < a.z {
                    continue;
                }
                if brush_holds(solid[b], goal) {
                    stopped = True;
                    break;
                }
                entered = ray_enters_brush(solid[b], middle, direction);
                if entered[1] >= 0 and entered[0] <= cell {
                    stopped = True;
                    break;
                }
            }
            if stopped {
                continue;
            }
            came[key] = str(here[0]) + "," + str(here[1]) + "," + str(here[2]);
            queue.append(there);
        }
    }
    if not out_key {
        return outcome;
    }
    outcome.sealed = False;
    # Back from the void to where the flood began.
    walk = out_key;
    while walk {
        parts = walk.split(",");
        outcome.path.append(
            Vec3(
                x=low.x + (float(int(parts[0])) + 0.5) * cell,
                y=low.y + (float(int(parts[1])) + 0.5) * cell,
                z=low.z + (float(int(parts[2])) + 0.5) * cell
            )
        );
        walk = came.get(walk, "");
    }
    outcome.path.reverse();
    return outcome;
}
