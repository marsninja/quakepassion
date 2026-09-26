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
        closed: bool = False,
        launch: Vec3 = Vec3();
}

edge RouteParent: RoutePoint --> RoutePoint {}

walker CollectRoute {
    has points: list[Vec3] = [],
        launches: list[Vec3] = [];

    can collect with RoutePoint entry {
        self.points.append(here.pos);
        self.launches.append(here.launch);
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

# A probe yields after one 12-unit movement sample. Searches never perform a
# complete multi-edge collision search in a single simulation tick.
obj WalkProbe {
    has start: Vec3,
        finish: Vec3,
        match_height: bool = True,
        pos: Vec3 = Vec3(),
        count: int = 0,
        index: int = 0,
        done: bool = False,
        reached: Vec3 | None = None;

    def advance(collision: CollisionMap) {
        if self.done { return; }
        if self.count == 0 {
            delta = self.finish.sub(self.start);
            self.count = max(1, int(math.ceil(math.sqrt(delta.x * delta.x + delta.y * delta.y) / 12.0)));
            self.pos = self.start;
            if self.count > 64 { self.done = True; return; }
        }
        wanted = self.start.lerp(self.finish, float(self.index + 1) / float(self.count));
        move = Vec3(x=wanted.x - self.pos.x, y=wanted.y - self.pos.y);
        result = step_slide(collision, self.pos, move, 1.0, True);
        self.index += 1;
        if abs(result.pos.x - wanted.x) > 0.1 or abs(result.pos.y - wanted.y) > 0.1 {
            self.done = True; return;
        }
        support = collision.trace(result.pos, result.pos.sub(Vec3(z=18.0)));
        if support.start_solid or support.fraction == 1.0 or support.normal.z < 0.7 {
            self.done = True; return;
        }
        self.pos = support.end;
        if self.index == self.count {
            self.done = True;
            if not self.match_height or abs(self.pos.z - self.finish.z) <= 18.0 {
                self.reached = self.pos;
            }
        }
    }
}

# The level owns this learned connectivity graph. Exact endpoints and hull
# stance form the cache key; different floors and clearances cannot alias.
node NavigationPoint {
    has pos: Vec3;
}
edge NavigationLink: NavigationPoint --> NavigationPoint {}
obj NavigationConnection {
    has start: Vec3,
        finish: Vec3,
        reached: Vec3 | None = None;
}
obj NavigationGraph {
    has points: dict[str, NavigationPoint] = {},
        connections: dict[str, NavigationConnection] = {},
        source: CollisionMap | None = None,
        revision: int = -1,
        hull_count: int = -1,
        dynamic_hulls: list[int] = [],
        hits: int = 0;

    def key(pos: Vec3) -> str {
        return str(pos.x) + ":" + str(pos.y) + ":" + str(pos.z);
    }
    def probe_key(probe: WalkProbe, collision: CollisionMap) -> str {
        return self.key(probe.start) + ">" + self.key(probe.finish)
            + ":" + str(probe.match_height) + ":" + str(collision.top_drop)
            + ":" + collision.body_key();
    }
    def remember(probe: WalkProbe, collision: CollisionMap) {
        # Mover bounds include their complete travel. Never cache a connection
        # touching one: its support can change every tick without invalidating
        # unrelated static navigation or scanning the whole cache.
        if self.source is None { self.refresh(collision); }
        for i in self.dynamic_hulls {
            if len(collision.bounds) != len(collision.hulls) { return; }
            bounds = collision.bounds[i];
            a = probe.start;
            b = probe.finish;
            if max(a.x, b.x) + 32.0 >= bounds.mins.x
                and min(a.x, b.x) - 32.0 <= bounds.maxs.x
                and max(a.y, b.y) + 32.0 >= bounds.mins.y
                and min(a.y, b.y) - 32.0 <= bounds.maxs.y
                and max(a.z, b.z) + 1200.0 >= bounds.mins.z
                and min(a.z, b.z) - 1200.0 <= bounds.maxs.z { return; }
        }
        # Keep level memory bounded even during long sessions.
        if len(self.connections) >= 16384 { return; }
        self.connections[self.probe_key(probe, collision)] = NavigationConnection(
            start=probe.start, finish=probe.finish, reached=probe.reached
        );
        if probe.reached is not None {
            source_key = self.key(probe.start);
            target_key = self.key(probe.reached);
            if source_key not in self.points { self.points[source_key] = NavigationPoint(pos=probe.start); }
            if target_key not in self.points { self.points[target_key] = NavigationPoint(pos=probe.reached); }
            self.points[source_key] +>:NavigationLink:+> self.points[target_key];
        }
    }
    def refresh(collision: CollisionMap) {
        if self.source is collision and self.hull_count == len(collision.hulls)
            and self.revision == collision.revision.serial { return; }
        changed: list[int] = [];
        if self.source is not collision or self.hull_count != len(collision.hulls) {
            self.dynamic_hulls = [i for i in range(len(collision.models)) if collision.models[i] > 0];
            self.connections = {};
            self.points = {};
        } else {
            for (index, serial) in collision.revision.changes.items() {
                if serial > self.revision
                    and (index >= len(collision.models) or collision.models[index] <= 0) {
                    changed.append(index);
                }
            }
            if changed {
                # Graph links are derived hints; rebuild links as connections are
                # requested again. Preserve unaffected collision results.
                self.points = {};
                retained: dict[str, NavigationConnection] = {};
                for (key, connection) in self.connections.items() {
                    valid = True;
                    for i in changed {
                        if len(collision.bounds) != len(collision.hulls) { valid = False; break; }
                        bounds = collision.bounds[i];
                        a = connection.start;
                        b = connection.finish;
                        # Bounds cover complete mover travel. A walk can climb
                        # multiple steps; include the maximum probe step rise.
                        if max(a.x, b.x) + 32.0 >= bounds.mins.x
                            and min(a.x, b.x) - 32.0 <= bounds.maxs.x
                            and max(a.y, b.y) + 32.0 >= bounds.mins.y
                            and min(a.y, b.y) - 32.0 <= bounds.maxs.y
                            and max(a.z, b.z) + 1200.0 >= bounds.mins.z
                            and min(a.z, b.z) - 1200.0 <= bounds.maxs.z {
                            valid = False; break;
                        }
                    }
                    if valid { retained[key] = connection; }
                }
                self.connections = retained;
            }
        }
        self.hull_count = len(collision.hulls);
        self.source = collision;
        self.revision = collision.revision.serial;
    }
}

# Arena jump links use the same gravity and swept hull as actor movement.
# One flight sample is charged to the global navigation budget.
obj JumpProbe {
    has start: Vec3,
        finish: Vec3,
        pos: Vec3 = Vec3(),
        velocity: Vec3 = Vec3(),
        launch: Vec3 = Vec3(),
        initialized: bool = False,
        done: bool = False,
        reached: Vec3 | None = None,
        steps: int = 0;

    def advance(collision: CollisionMap) {
        if self.done { return; }
        if not self.initialized {
            self.initialized = True;
            self.pos = self.start;
            support = collision.trace(self.finish.add(Vec3(z=48.0)), self.finish.sub(Vec3(z=128.0)));
            if support.start_solid or support.fraction == 1.0 or support.normal.z < 0.7 {
                self.done = True; return;
            }
            self.finish = support.end;
            delta = self.finish.sub(self.start);
            discriminant = 270.0 * 270.0 - 1600.0 * delta.z;
            if discriminant <= 0.0 { self.done = True; return; }
            duration = (270.0 + math.sqrt(discriminant)) / 800.0;
            horizontal = Vec3(x=delta.x, y=delta.y).scale(1.0 / duration);
            if horizontal.length() > 320.0 { self.done = True; return; }
            self.launch = horizontal.add(Vec3(z=270.0));
            self.velocity = self.launch.add(Vec3());
        }
        dt = 1.0 / 120.0;
        self.velocity.z -= 800.0 * dt;
        next_pos = self.pos.add(self.velocity.scale(dt));
        hit = collision.trace(self.pos, next_pos);
        self.steps += 1;
        if hit.start_solid { self.done = True; return; }
        if hit.fraction < 1.0 {
            self.done = True;
            delta = hit.end.sub(self.finish);
            if self.velocity.z < 0.0 and hit.normal.z >= 0.7
                and math.sqrt(delta.x * delta.x + delta.y * delta.y) < 16.0
                and abs(delta.z) < 18.0 {
                self.reached = hit.end;
            }
            return;
        }
        self.pos = next_pos;
        if self.steps >= 180 { self.done = True; }
    }
}

obj RouteSearch {
    has start: Vec3,
        finish: Vec3,
        collision: CollisionMap,
        network: NavigationGraph = NavigationGraph(),
        allow_jumps: bool = False,
        jump_probe: JumpProbe | None = None,
        pending_launch: Vec3 = Vec3(),
        budget: int = 96,
        points: list[RoutePoint] = [],
        cells: dict[str, RoutePoint] = {},
        current: RoutePoint | None = None,
        probe: WalkProbe | None = None,
        direction: int = -1,
        expanded: int = 0,
        initialized: bool = False,
        done: bool = False,
        cancelled: bool = False,
        result: list[Vec3] = [],
        launches: list[Vec3] = [];

    def complete(point: RoutePoint) {
        path = point spawn CollectRoute();
        for i in range(len(path.points) - 2, -1, -1) {
            self.result.append(path.points[i]);
            self.launches.append(path.launches[i]);
        }
        self.result.append(self.finish);
        self.launches.append(Vec3());
        self.done = True;
    }

    # One call performs at most one collision sample. Graph bookkeeping is
    # bounded by the same search expansion limit as the synchronous API.
    def advance() {
        if self.done or self.cancelled { return; }
        if not self.initialized {
            self.initialized = True;
            origin = RoutePoint(pos=self.start, estimate=self.finish.sub(self.start).length());
            self.points.append(origin);
            self.cells[str(int(round(self.start.x / 48.0))) + ":" + str(int(round(self.start.y / 48.0))) + ":" + str(int(math.floor(self.start.z / 18.0)))] = origin;
            self.current = origin;
            self.probe = WalkProbe(start=self.start, finish=self.finish);
            self.direction = -2;
        }
        if self.jump_probe is not None {
            self.jump_probe.advance(self.collision);
            if not self.jump_probe.done { return; }
            if self.probe is not None {
                self.probe.reached = self.jump_probe.reached;
                self.probe.done = True;
                if self.jump_probe.reached is not None {
                    self.pending_launch = self.jump_probe.launch;
                }
            }
            self.jump_probe = None;
        }
        if self.probe is not None {
            key = self.network.probe_key(self.probe, self.collision);
            if self.probe.done {}
            elif self.probe.index == 0 and key in self.network.connections {
                self.probe.reached = self.network.connections[key].reached;
                self.probe.done = True;
                self.network.hits += 1;
            } else {
                self.probe.advance(self.collision);
                if self.probe.done { self.network.remember(self.probe, self.collision); }
            }
            if not self.probe.done { return; }
            reached = self.probe.reached;
            if reached is None and self.allow_jumps and self.direction >= 0
                and self.pending_launch.z == 0.0 {
                self.jump_probe = JumpProbe(
                    start=self.probe.start,
                    finish=self.probe.start.add(self.probe.finish.sub(self.probe.start).scale(2.0))
                );
                # Mark the attempt so a failed flight is not retried indefinitely.
                self.pending_launch = Vec3(z=-1.0);
                return;
            }
            self.probe = None;
            if self.direction < 0 {
                if reached is not None and self.current is not None {
                    self.complete(self.current); return;
                }
                if self.direction == -2 {
                    self.current = None;
                }
            } elif reached is not None and self.current is not None {
                x = int(round(reached.x / 48.0));
                y = int(round(reached.y / 48.0));
                key = str(x) + ":" + str(y) + ":" + str(int(math.floor(reached.z / 18.0)));
                cost = self.current.cost + reached.sub(self.current.pos).length();
                point: RoutePoint | None = None;
                if key in self.cells {
                    existing = self.cells[key];
                    if cost < existing.cost - 0.001 {
                        for parent in [existing->:RouteParent:->] { existing del --> parent; }
                        existing.cost = cost;
                        existing.closed = False;
                        point = existing;
                    }
                } else {
                    point = RoutePoint(pos=reached, cost=cost);
                    self.cells[key] = point;
                    self.points.append(point);
                }
                if point is not None {
                    point.estimate = cost + self.finish.sub(reached).length();
                    if self.pending_launch.z > 0.0 {
                        # Preserve the takeoff point as an explicit path action.
                        takeoff = RoutePoint(pos=self.current.pos, launch=self.pending_launch);
                        takeoff +>:RouteParent:+> self.current;
                        point +>:RouteParent:+> takeoff;
                    } else {
                        point +>:RouteParent:+> self.current;
                    }
                }
            }
            self.pending_launch = Vec3();
            self.direction += 1;
        }
        if self.direction >= 8 { self.current = None; }
        if self.current is None {
            if self.expanded >= max(0, min(self.budget, 256)) {
                self.done = True; return;
            }
            best: RoutePoint | None = None;
            for point in self.points {
                if not point.closed and (best is None or point.estimate < best.estimate) { best = point; }
            }
            if best is None { self.done = True; return; }
            best.closed = True;
            self.current = best;
            self.expanded += 1;
            self.direction = 0;
            if self.finish.sub(best.pos).length() <= 72.0 {
                self.direction = -1;
                self.probe = WalkProbe(start=best.pos, finish=self.finish);
                return;
            }
        }
        if self.current is not None {
            dxs = [-1, -1, -1, 0, 0, 1, 1, 1];
            dys = [-1, 0, 1, -1, 1, -1, 0, 1];
            target = Vec3(
                x=(round(self.current.pos.x / 48.0) + float(dxs[self.direction])) * 48.0,
                y=(round(self.current.pos.y / 48.0) + float(dys[self.direction])) * 48.0,
                z=self.current.pos.z
            );
            self.probe = WalkProbe(start=self.current.pos, finish=target, match_height=False);
        }
    }
}

obj RouteQueue {
    has jobs: list[RouteSearch] = [],
        network: NavigationGraph = NavigationGraph(),
        cursor: int = 0,
        last_work: int = 0;

    def advance(budget: int = 12) {
        self.last_work = 0;
        self.jobs = [job for job in self.jobs if not job.done and not job.cancelled];
        for i in range(max(0, budget)) {
            if not self.jobs { break; }
            self.cursor %= len(self.jobs);
            job = self.jobs[self.cursor];
            job.advance();
            self.last_work += 1;
            if job.done or job.cancelled { self.jobs.pop(self.cursor); }
            else { self.cursor += 1; }
        }
    }
}

# Synchronous convenience for offline validation only. Live actors use RouteQueue.
def ground_route(collision: CollisionMap, start: Vec3, finish: Vec3, budget: int = 96) -> list[Vec3] {
    search = RouteSearch(start=start, finish=finish, collision=collision, budget=budget);
    while not search.done { search.advance(); }
    return search.result;
}
