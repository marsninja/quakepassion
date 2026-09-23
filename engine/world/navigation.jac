"""Bounded ground routes using the same hull and steps as actor movement.

Routes are transient hints. Moving geometry is checked again when following them.
No point-visibility edge is assumed to be walkable.
"""
import math;
import from ..math.vec3 { Vec3 }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { step_slide }

node RoutePoint {
    has pos: Vec3,
        cost: float = 0.0,
        estimate: float = 0.0,
        closed: bool = False;
}

edge RouteParent: RoutePoint --> RoutePoint {}

walker CollectRoute {
    has points: list[Vec3] = [];

    can collect with RoutePoint entry {
        self.points.append(here.pos);
        visit [->:RouteParent:->];
    }
}

# Coordinates are hull origins, not eye positions. Sample support throughout an
# edge so a clear ray across a pit does not become a navigation connection.
def walk_edge(
    collision: CollisionMap, start: Vec3, finish: Vec3, match_height: bool = True
) -> Vec3 | None {
    delta = finish.sub(start);
    distance = math.sqrt(delta.x * delta.x + delta.y * delta.y);
    count = max(1, int(math.ceil(distance / 12.0)));
    if count > 64 {
        return None;
    }
    pos = start;
    for i in range(count) {
        wanted = start.add(delta.scale(float(i + 1) / float(count)));
        move = Vec3(x=wanted.x - pos.x, y=wanted.y - pos.y);
        result = step_slide(collision, pos, move, 1.0, True);
        if abs(result.pos.x - wanted.x) > 0.1 or abs(result.pos.y - wanted.y) > 0.1 {
            return None;
        }
        support = collision.trace(result.pos, result.pos.sub(Vec3(z=18.0)));
        if support.start_solid or support.fraction == 1.0 or support.normal.z < 0.7 {
            return None;
        }
        pos = support.end;
    }
    if match_height and abs(pos.z - finish.z) > 18.0 {
        return None;
    }
    return pos;
}

# A short-lived A* graph avoids an unbounded BSP-wide bake at startup. Only
# complete routes are returned: exhausting the budget must not send actors into
# dead ends. The grid keeps separate height layers for stacked floors.
def ground_route(
    collision: CollisionMap, start: Vec3, finish: Vec3, budget: int = 96
) -> list[Vec3] {
    if walk_edge(collision, start, finish) is not None {
        return [finish];
    }
    origin = RoutePoint(pos=start, estimate=finish.sub(start).length());
    points: list[RoutePoint] = [origin];
    cells: dict[str, RoutePoint] = {
        "0:0:" + str(int(math.floor(start.z / 18.0))): origin
    };
    for iteration in range(max(0, min(budget, 256))) {
        best: RoutePoint | None = None;
        for point in points {
            if not point.closed and (best is None or point.estimate < best.estimate) {
                best = point;
            }
        }
        if best is None {
            break;
        }
        best.closed = True;
        if finish.sub(best.pos).length() <= 72.0
            and walk_edge(collision, best.pos, finish) is not None {
            path = best spawn CollectRoute();
            result: list[Vec3] = [];
            for i in range(len(path.points) - 2, -1, -1) {
                result.append(path.points[i]);
            }
            result.append(finish);
            return result;
        }
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                if dx == 0 and dy == 0 {
                    continue;
                }
                target = best.pos.add(Vec3(x=float(dx) * 48.0, y=float(dy) * 48.0));
                reached = walk_edge(collision, best.pos, target, match_height=False);
                if reached is None {
                    continue;
                }
                x = int(round((reached.x - start.x) / 48.0));
                y = int(round((reached.y - start.y) / 48.0));
                key = str(x)
                    + ":"
                    + str(y)
                    + ":"
                    + str(int(math.floor(reached.z / 18.0)));
                cost = best.cost + reached.sub(best.pos).length();
                if key in cells {
                    point = cells[key];
                    if cost >= point.cost - 0.001 {
                        continue;
                    }
                    for parent in [point->:RouteParent:->] {
                        point del --> parent;
                    }
                    point.cost = cost;
                    point.closed = False;
                } else {
                    point = RoutePoint(pos=reached, cost=cost);
                    cells[key] = point;
                    points.append(point);
                }
                point.estimate = cost + finish.sub(reached).length();
                point +>:RouteParent:+> best;
            }
        }
    }
    return [];
}
