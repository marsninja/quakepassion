"""Map-wide bot navigation over the original AAS data. Every AAS area is a
NavArea node and every reachability a Passage node between two areas
(NavArea -Exits-> Passage -Enters-> NavArea), so routing is graph traversal:
a TravelTimes walker relaxes travel times outward from a goal area, as botlib's
routing cache does, and bots descend those times one passage at a time.

Like botlib's routing caches, each table is for one goal and one set of travel
flags (be_aas.h TFL_*): which travel types a route may use and which area
contents it may enter. Bots route with TFL_DEFAULT, adding rocket jumps when
they can and want to (ai_dmq3.c BotCanAndWantsToRocketJump) and lava and slime
when they are in it (BotInLavaOrSlime)."""
import math;
import from .world { World }
import from ..formats.aas {
    Aas,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_LADDER,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_WATERJUMP,
    TRAVEL_TELEPORT,
    TRAVEL_ELEVATOR,
    TRAVEL_ROCKETJUMP,
    TRAVEL_BFGJUMP,
    TRAVEL_JUMPPAD,
    TRAVEL_FUNCBOB,
    TFL_DEFAULT,
    travel_flag_for_type,
    area_contents_travel_flags,
    AREA_DISABLED,
    AREA_GROUNDED
}
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

glob UNREACHED: int = 1000000000;

node NavArea {
    has index: int,
        center: Vec3;
}

"""One AAS reachability. `flags` are the travel flags it needs: its travel
type's and those of the contents of the area it enters. A mover passage
(elevator or bobbing platform) keeps the mover's BSP `model`; a bobbing
platform also its `axis` and the axis positions of the platform's centre at
this passage's `near` and `far` ends (be_ai_move.c BotFuncBobStartEnd)."""
node Passage {
    has kind: int,
        start: Vec3,
        finish: Vec3,
        time: int,
        source: int,
        target: int,
        cost: int = 0,
        flags: int = 0,
        model: int = 0,
        axis: int = 2,
        near: float = 0.0,
        far: float = 0.0;
}

edge Exits: NavArea --> Passage {}
edge Enters: Passage --> NavArea {}

"""A travel table under construction: the times so far and the areas whose
entering passages still need relaxing (the next round's frontier)."""
obj TravelJob {
    has goal: int,
        times: list[int],
        flags: int = TFL_DEFAULT,
        key: int = 0,
        frontier: list[NavArea] = [],
        queued: set[int] = set();
}

# Passage relaxations spent per navigation tick on tables built in the
# background (a full table on the ladder's arenas is some 15-25 thousand).
glob TABLE_BUDGET: int = 1500;

node NavMesh {
    has aas: Aas,
        areas: list[NavArea] = [],
        tables: dict[int, list[int]] = {},
        recent: list[int] = [],
        jobs: list[TravelJob] = [],
        profiles: list[int] = [],
        mover_bounds: dict[int, AABB] = {};

    """The cache key of a goal's table for a set of travel flags: the goal
    area and the index of the flag set among those seen so far."""
    def table_key(goal: int, flags: int) -> int {
        if flags not in self.profiles {
            self.profiles.append(flags);
        }
        return goal * 64 + self.profiles.index(flags);
    }

    """Travel times (hundredths of a second) from every area to `goal` with
    the travel `flags`, cached for the most recently used goals; built now if
    not cached."""
    def times_to(goal: int, flags: int = TFL_DEFAULT) -> list[int] {
        key = self.table_key(goal, flags);
        if key in self.tables {
            return self.tables[key];
        }
        job = self.job_for(goal, flags);
        while job.frontier {
            self.relax(job, UNREACHED);
        }
        return self.finish(job);
    }

    """The travel table to `goal` with `flags` if it is built; otherwise None,
    with the table queued to be built a budget at a time by advance_tables
    (botlib builds its routing caches on demand; here the work is spread over
    ticks instead of stalling one)."""
    def times_ready(goal: int, flags: int = TFL_DEFAULT) -> list[int] | None {
        key = self.table_key(goal, flags);
        if key in self.tables {
            return self.tables[key];
        }
        self.job_for(goal, flags);
        return None;
    }

    """The best table ready for routing to `goal` with `flags`: its own, or
    while that is being built the TFL_DEFAULT one, whose routes every bot can
    take (a bot waiting on its rocket-jump table routes without them)."""
    def times_for(goal: int, flags: int = TFL_DEFAULT) -> list[int] | None {
        ready = self.times_ready(goal, flags);
        if ready is None and flags != TFL_DEFAULT {
            key = self.table_key(goal, TFL_DEFAULT);
            if key in self.tables {
                return self.tables[key];
            }
        }
        return ready;
    }

    """Spend up to `budget` passage relaxations on queued tables."""
    def advance_tables(budget: int = TABLE_BUDGET) {
        spent = 0;
        while self.jobs and spent < budget {
            job = self.jobs[0];
            spent += self.relax(job, budget - spent);
            if not job.frontier {
                self.finish(job);
            }
        }
    }

    def job_for(goal: int, flags: int = TFL_DEFAULT) -> TravelJob {
        key = self.table_key(goal, flags);
        for queued in self.jobs {
            if queued.key == key {
                return queued;
            }
        }
        times = [UNREACHED for area in self.areas];
        times[goal] = 0;
        job = TravelJob(goal=goal, times=times, flags=flags, key=key, frontier=[self.areas[goal]]);
        self.jobs.append(job);
        return job;
    }

    """One pass of the relaxation over the head of the job's frontier,
    stopping near `budget` relaxations; returns how many it made."""
    def relax(job: TravelJob, budget: int) -> int {
        count = min(len(job.frontier), max(1, budget // 2));
        chunk = job.frontier[0:count];
        job.frontier = job.frontier[count:];
        for area in chunk {
            job.queued.discard(area.index);
        }
        relax = self spawn TravelTimes(
            times=job.times, areas=self.areas, chunk=chunk, queued=job.queued, allowed=job.flags
        );
        job.frontier.extend(relax.reached);
        return relax.relaxed;
    }

    def finish(job: TravelJob) -> list[int] {
        if job in self.jobs {
            self.jobs.remove(job);
        }
        self.tables[job.key] = job.times;
        self.recent.append(job.key);
        if len(self.recent) > 512 {
            oldest = self.recent.pop(0);
            if oldest in self.tables {
                self.tables.pop(oldest);
            }
        }
        return job.times;
    }

    """The area holding an origin. AAS space is expanded by the player box, so
    points nearer the floor than a standing origin (items rest 15 units up) are
    probed a little higher; airborne bots are probed lower, as
    BotReachabilityArea traces down to the ground. An origin standing exactly
    on the floor lies on the plane where the grounded area begins (q3dm10's
    spawn spots do), which the tree sends to the solid below: a quarter unit
    higher finds the ground area."""
    def locate(origin: Vec3) -> int {
        fallback = 0;
        drops = [0.0, -0.25, -10.0, -24.0];
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

"""Backward relaxation, a frontier at a time: from each area in `chunk`,
look at the passages entering it; a passage that shortens its source area's
time puts that area on the next frontier (`reached`)."""
walker TravelTimes {
    has times: list[int],
        areas: list[NavArea],
        chunk: list[NavArea],
        queued: set[int],
        allowed: int = TFL_DEFAULT,
        reached: list[NavArea] = [],
        relaxed: int = 0;

    can start with NavMesh entry {
        visit self.chunk;
    }

    can settle with NavArea entry {
        visit [here<-:Enters:<-];
    }

    can relax with Passage entry {
        self.relaxed += 1;
        # AAS_UpdateAreaRoutingCache: "if there is used an undesired travel
        # type" or the next area's contents are not allowed.
        if here.flags & ~self.allowed {
            return;
        }
        candidate = self.times[here.target] + here.cost;
        if candidate < self.times[here.source] {
            self.times[here.source] = candidate;
            if here.source not in self.queued {
                self.queued.add(here.source);
                self.reached.append(self.areas[here.source]);
            }
        }
    }
}

"""A bobbing platform's two ends along its axis from be_aas_reach.c's
packing: `face >> 16` the spawnflags (1 bobs along x, 2 along y, else z) and
`packed` the platform centre's axis position at the passage's start (high 16
bits) and end (low 16 bits), each a signed 16-bit value."""
def bob_ends(face: int, packed: int) -> tuple[int, float, float] {
    spawnflags = face >> 16;
    axis = 0 if spawnflags & 1 else (1 if spawnflags & 2 else 2);
    near = (packed >> 16) & 65535;
    far = packed & 65535;
    if near > 32767 {
        near -= 65536;
    }
    if far > 32767 {
        far -= 65536;
    }
    return (axis, float(near), float(far));
}

"""The navigation graph for a map's AAS. `bsp` supplies the bounds of the
movers that elevator and bobbing-platform passages ride
(AAS_BSPModelMinsMaxsOrigin)."""
def build_navmesh(world: World, aas: Aas, bsp: Bsp | None = None) -> NavMesh {
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
            if reach.area == 0 or aas.areas[reach.area].flags & AREA_DISABLED != 0 {
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
                    + run_time(reach.finish, aas.areas[reach.area].center),
                flags=travel_flag_for_type(reach.kind)
                    | area_contents_travel_flags(aas.areas[reach.area].contents)
            );
            if reach.kind in [TRAVEL_ELEVATOR, TRAVEL_FUNCBOB] {
                passage.model = reach.face_num & 65535;
                if reach.kind == TRAVEL_FUNCBOB {
                    ends = bob_ends(reach.face_num, reach.edge_num);
                    passage.axis = ends[0];
                    passage.near = ends[1];
                    passage.far = ends[2];
                }
                if bsp is not None and passage.model < len(bsp.models) {
                    record = bsp.models[passage.model];
                    mesh.mover_bounds[passage.model] = AABB(mins=record.mins, maxs=record.maxs);
                }
            }
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
reaching each one, the AAS area whose entry completes it (0 when only
reaching the point itself counts, as for a jump's takeoff), and the passage a
waypoint travels when that takes more than heading for it (rocket jumps,
ladders, elevators and bobbing platforms; be_ai_move.c BotTravel_*)."""
obj BotRoute {
    has points: list[Vec3] = [],
        launches: list[Vec3] = [],
        areas: list[int] = [],
        passages: list[Passage | None] = [],
        found: bool = False,
        pending: bool = False,
        leg_started: float = -1.0,
        jumped: bool = False;

    def add(point: Vec3, area: int, launch: Vec3 = Vec3(), passage: Passage | None = None) {
        self.points.append(point);
        self.areas.append(area);
        self.launches.append(launch);
        self.passages.append(passage);
    }

    """Done with the first waypoint at `clock`: the next leg starts now."""
    def advance(clock: float) {
        self.points.pop(0);
        self.areas.pop(0);
        if self.launches {
            self.launches.pop(0);
        }
        if self.passages {
            self.passages.pop(0);
        }
        self.leg_started = clock;
        self.jumped = False;
    }
}

"""Plan from a bot origin to a goal point (in `goal_area` when the goal
knows its area, as an item floating over a jump pad does) with the travel
`flags`: descend
the goal's travel times one passage at a time, up to `limit` passages, then
finish at the goal itself. Like botlib, a passage is done once the bot stands
in its target area; jumps, ledges, pads and teleporters first need their
takeoff point, and the passages that need more than a heading (rocket jumps,
ladders and movers) carry their passage for the bot's travel to follow."""
def plan_route(
    mesh: NavMesh, origin: Vec3, goal: Vec3, limit: int = 32, flags: int = TFL_DEFAULT, goal_area: int = 0
) -> BotRoute {
    route = BotRoute();
    here_area = mesh.locate(origin);
    if goal_area == 0 {
        goal_area = mesh.locate(goal);
    }
    if here_area == 0 or goal_area == 0 {
        return route;
    }
    ready = mesh.times_for(goal_area, flags);
    if ready is None {
        # The goal's travel table is still being built: ask again shortly.
        route.pending = True;
        return route;
    }
    times: list[int] = ready;
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
            if times[passage.target] >= UNREACHED or passage.flags & ~flags {
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
            route.add(best.start, best.target, passage=best);
            route.found = True;
            return route;
        }
        if best.kind in [TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_LADDER, TRAVEL_ELEVATOR, TRAVEL_FUNCBOB] {
            route.add(best.finish, best.target, passage=best);
        } else {
            if best.kind in [TRAVEL_BARRIERJUMP, TRAVEL_JUMP, TRAVEL_WATERJUMP] {
                route.add(best.start, 0, jump_launch(best.start, best.finish), best);
            } elif best.kind == TRAVEL_WALKOFFLEDGE {
                route.add(best.start, 0, passage=best);
            }
            route.add(best.finish, best.target, passage=best);
        }
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

"""be_aas_route.c AAS_AreaTravelTimeToGoalArea from a point in `area`:
hundredths of a second to the goal area with the travel `flags` (1 within
it), or 0 when it cannot be reached or its table is still being built."""
def area_travel_time(mesh: NavMesh, area: int, origin: Vec3, goal_area: int, flags: int = TFL_DEFAULT) -> int {
    if area == 0 {
        return 0;
    }
    return exits_travel_time(mesh, area, [mesh.areas[area]->:Exits:->][?:Passage], origin, goal_area, flags);
}

"""area_travel_time with the passages out of `area` already gathered (a
goal choice rates many items from one spot)."""
def exits_travel_time(
    mesh: NavMesh, area: int, exits: list[Passage], origin: Vec3, goal_area: int, flags: int = TFL_DEFAULT
) -> int {
    if area == 0 or goal_area == 0 {
        return 0;
    }
    if area == goal_area {
        return 1;
    }
    times = mesh.times_for(goal_area, flags);
    if times is None or times[area] >= UNREACHED {
        return 0;
    }
    # The table runs from the area's centre; the bot starts at its origin.
    best = UNREACHED;
    for passage in exits {
        if times[passage.target] >= UNREACHED or passage.flags & ~flags {
            continue;
        }
        cost = run_time(origin, passage.start)
            + passage.time
            + run_time(passage.finish, mesh.areas[passage.target].center)
            + times[passage.target];
        best = min(best, cost);
    }
    return max(1, best if best < UNREACHED else times[area]);
}

"""Whether the AAS connects two points with the travel `flags`, from cached
travel times. A goal whose table is still being built counts as unreachable
until it is."""
def reachable(mesh: NavMesh, origin: Vec3, goal: Vec3, flags: int = TFL_DEFAULT) -> bool {
    here_area = mesh.locate(origin);
    goal_area = mesh.locate(goal);
    if here_area == 0 or goal_area == 0 {
        return False;
    }
    if here_area == goal_area {
        return True;
    }
    times = mesh.times_for(goal_area, flags);
    return times is not None and times[here_area] < UNREACHED;
}
