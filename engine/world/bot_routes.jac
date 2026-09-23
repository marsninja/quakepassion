"""Map-wide bot navigation over the original AAS data. Every AAS area is a
NavArea node and every reachability a Passage node between two areas
(NavArea -Exits-> Passage -Enters-> NavArea), so routing is graph traversal:
a TravelTimes walker relaxes travel times outward from a goal area, as botlib's
routing cache does, and bots descend those times one passage at a time."""
import math;
import from .world { World }
import from ..formats.aas {
    Aas,
    TRAVEL_WALK,
    TRAVEL_CROUCH,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_SWIM,
    TRAVEL_WATERJUMP,
    TRAVEL_TELEPORT,
    TRAVEL_JUMPPAD,
    AREA_DISABLED,
    AREA_GROUNDED
}
import from ..math.vec3 { Vec3 }

glob UNREACHED: int = 1000000000;

node NavArea {
    has index: int,
        center: Vec3;
}

node Passage {
    has kind: int,
        start: Vec3,
        finish: Vec3,
        time: int,
        source: int,
        target: int,
        cost: int = 0;
}

edge Exits: NavArea --> Passage {}
edge Enters: Passage --> NavArea {}

node NavMesh {
    has aas: Aas,
        areas: list[NavArea] = [],
        tables: dict[int, list[int]] = {},
        recent: list[int] = [];

    """Travel times (hundredths of a second) from every area to `goal`, cached
    for the most recently used goals."""
    def times_to(goal: int) -> list[int] {
        if goal in self.tables {
            return self.tables[goal];
        }
        times = [UNREACHED for area in self.areas];
        times[goal] = 0;
        relax = self.areas[goal] spawn TravelTimes(times=times);
        times = relax.times;
        self.tables[goal] = times;
        self.recent.append(goal);
        if len(self.recent) > 256 {
            oldest = self.recent.pop(0);
            if oldest in self.tables {
                self.tables.pop(oldest);
            }
        }
        return times;
    }

    """The area holding an origin. AAS space is expanded by the player box, so
    points nearer the floor than a standing origin (items rest 15 units up) are
    probed a little higher; airborne bots are probed lower, as
    BotReachabilityArea traces down to the ground."""
    def locate(origin: Vec3) -> int {
        fallback = 0;
        drops = [0.0, -10.0, -24.0];
        for step in range(1, 65) {
            drops.append(float(step) * 16.0);
        }
        for drop in drops {
            area = self.aas.area_at(origin.sub(Vec3(z=drop)));
            if area <= 0 or self.aas.areas[area].flags & AREA_DISABLED != 0 {
                continue;
            }
            # Prefer a grounded area with ways out over the air above it.
            if self.aas.areas[area].flags & AREA_GROUNDED != 0
                and self.aas.areas[area].reach_count > 0 {
                return area;
            }
            if fallback == 0 {
                fallback = area;
            }
        }
        return fallback;
    }
}

edge HasNavMesh: World --> NavMesh {}

"""Hundredths of a second to run a distance at the bots' 320 units/s."""
def run_time(a: Vec3, b: Vec3) -> int {
    return int(a.sub(b).length() / 3.2);
}

"""Travel the bots can execute: the TFL_DEFAULT set without ladders, elevators
and bobbing platforms, and never rocket jumps."""
def bot_travel(kind: int) -> bool {
    return kind in [
        TRAVEL_WALK,
        TRAVEL_CROUCH,
        TRAVEL_BARRIERJUMP,
        TRAVEL_JUMP,
        TRAVEL_WALKOFFLEDGE,
        TRAVEL_SWIM,
        TRAVEL_WATERJUMP,
        TRAVEL_TELEPORT,
        TRAVEL_JUMPPAD
    ];
}

"""Backward relaxation: from an area, look at the passages entering it; a
passage that shortens its source area's time sends the walker on to that area."""
walker TravelTimes {
    has times: list[int];

    can settle with NavArea entry {
        visit [here<-:Enters:<-];
    }

    can relax with Passage entry {
        candidate = self.times[here.target] + here.cost;
        if candidate < self.times[here.source] {
            self.times[here.source] = candidate;
            visit [here<-:Exits:<-];
        }
    }
}

def build_navmesh(world: World, aas: Aas) -> NavMesh {
    mesh = NavMesh(aas=aas);
    for i in range(len(aas.areas)) {
        mesh.areas.append(NavArea(index=i, center=aas.areas[i].center));
    }
    for i in range(len(aas.areas)) {
        area = aas.areas[i];
        if i == 0 or area.flags & AREA_DISABLED != 0 {
            continue;
        }
        for r in range(area.first_reach, area.first_reach + area.reach_count) {
            reach = aas.reaches[r];
            if not bot_travel(reach.kind)
                or reach.area == 0
                or aas.areas[reach.area].flags & AREA_DISABLED != 0 {
                continue;
            }
            passage = Passage(
                kind=reach.kind,
                start=reach.start,
                finish=reach.finish,
                time=reach.time,
                source=i,
                target=reach.area,
                cost=run_time(area.center, reach.start)
                    + reach.time
                    + run_time(reach.finish, aas.areas[reach.area].center)
            );
            mesh.areas[i] +>:Exits:+> passage;
            passage +>:Enters:+> mesh.areas[reach.area];
        }
    }
    world +>:HasNavMesh:+> mesh;
    return mesh;
}

"""The launch for a jump passage: Q3's 270 units/s jump, with the horizontal
speed that lands on the far point, capped at run speed."""
def jump_launch(start: Vec3, finish: Vec3) -> Vec3 {
    delta = finish.sub(start);
    discriminant = max(0.0, 270.0 * 270.0 - 1600.0 * delta.z);
    duration = (270.0 + math.sqrt(discriminant)) / 800.0;
    horizontal = Vec3(x=delta.x, y=delta.y).scale(1.0 / max(0.05, duration));
    if horizontal.length() > 320.0 {
        horizontal = horizontal.normalized().scale(320.0);
    }
    return horizontal.add(Vec3(z=270.0));
}

"""A planned path: waypoints at bot-origin height, the launch to apply on
reaching each one, and the AAS area whose entry completes it (0 when only
reaching the point itself counts, as for a jump's takeoff)."""
obj BotRoute {
    has points: list[Vec3] = [],
        launches: list[Vec3] = [],
        areas: list[int] = [],
        found: bool = False;

    def add(point: Vec3, area: int, launch: Vec3 = Vec3()) {
        self.points.append(point);
        self.areas.append(area);
        self.launches.append(launch);
    }
}

"""Plan from a bot origin to a goal point: descend the goal's travel times one
passage at a time, up to `limit` passages, then finish at the goal itself.
Like botlib, a passage is done once the bot stands in its target area; jumps,
ledges, pads and teleporters first need their takeoff point."""
def plan_route(mesh: NavMesh, origin: Vec3, goal: Vec3, limit: int = 32) -> BotRoute {
    route = BotRoute();
    here_area = mesh.locate(origin);
    goal_area = mesh.locate(goal);
    if here_area == 0 or goal_area == 0 {
        return route;
    }
    times = mesh.times_to(goal_area);
    if times[here_area] >= UNREACHED {
        return route;
    }
    area = here_area;
    position = origin;
    steps = 0;
    while area != goal_area and steps < limit {
        best: Passage | None = None;
        best_cost = UNREACHED;
        for passage in [mesh.areas[area]->:Exits:->][?:Passage] {
            if times[passage.target] >= UNREACHED {
                continue;
            }
            cost = run_time(position, passage.start)
                + passage.time
                + run_time(passage.finish, mesh.areas[passage.target].center)
                + times[passage.target];
            if cost < best_cost {
                best_cost = cost;
                best = passage;
            }
        }
        if best is None {
            return route;
        }
        if best.kind in [TRAVEL_TELEPORT, TRAVEL_JUMPPAD] {
            # The trigger carries the bot on; planning resumes where it lands.
            route.add(best.start, best.target);
            route.found = True;
            return route;
        }
        if best.kind in [TRAVEL_BARRIERJUMP, TRAVEL_JUMP, TRAVEL_WATERJUMP] {
            route.add(best.start, 0, jump_launch(best.start, best.finish));
        } elif best.kind == TRAVEL_WALKOFFLEDGE {
            route.add(best.start, 0);
        }
        route.add(best.finish, best.target);
        position = best.finish;
        area = best.target;
        steps += 1;
    }
    if area == goal_area {
        route.add(goal, 0);
    }
    route.found = True;
    return route;
}

"""Whether the AAS connects two points, from cached travel times."""
def reachable(mesh: NavMesh, origin: Vec3, goal: Vec3) -> bool {
    here_area = mesh.locate(origin);
    goal_area = mesh.locate(goal);
    if here_area == 0 or goal_area == 0 {
        return False;
    }
    return here_area == goal_area or mesh.times_to(goal_area)[here_area] < UNREACHED;
}
