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
    AasReach,
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
    area_mover_model,
    AREA_DISABLED,
    AREA_GROUNDED
}
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

glob UNREACHED: int = 1000000000;

# be_ai_move.c: a reachability is avoided for AVOIDREACH_TIME seconds after
# use once it has been taken more than AVOIDREACH_TRIES times.
glob AVOIDREACH_TIME: float = 6.0,
    AVOIDREACH_TRIES: int = 4;

node NavArea {
    has index: int,
        center: Vec3;
}

"""One AAS reachability. `flags` are the travel flags it needs: its travel
type's and those of the contents of the area it enters. A mover passage
(elevator or bobbing platform) keeps the mover's BSP `model`; a bobbing
platform also its `axis` and the axis positions of the platform's centre at
this passage's `near` and `far` ends (be_ai_move.c BotFuncBobStartEnd).
`mover` is the BSP model of the door or other mover whose area the passage
enters or passes through (AREACONTENTS_MOVER with its model number), 0 when
there is none."""
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
        far: float = 0.0,
        mover: int = 0;
}

edge Exits: NavArea --> Passage {}
edge Enters: Passage --> NavArea {}

# be_ai_move.h avoid spot types.
glob AVOID_ALWAYS: int = 1,
    AVOID_DONTBLOCK: int = 2;

"""be_ai_move.h bot_avoidspot_t: somewhere a bot keeps its way clear of (a
live grenade), within `radius`."""
obj AvoidSpot {
    has origin: Vec3,
        radius: float,
        kind: int = AVOID_ALWAYS;
}

"""be_ai_move.c DistanceFromLineSquared: the squared distance from `point`
to the stretch from `a` to `b` (to the nearer end beyond either)."""
def line_distance_squared(point: Vec3, a: Vec3, b: Vec3) -> float {
    along = b.sub(a);
    span = along.dot(along);
    t = point.sub(a).dot(along) / span if span > 0.000001 else 0.0;
    nearest = a.add(along.scale(max(0.0, min(1.0, t))));
    gap = point.sub(nearest);
    return gap.dot(gap);
}

"""be_ai_move.c BotAvoidSpots: the type of avoid spot a passage would take
a bot at `origin` into, 0 for none. A spot counts when the way to the
passage's start runs within its radius and toward it; for the travel types
that go straight (walk, crouch, barrier jump, ladder, swim, water jump) also
when the passage itself does; for the others the original tests the first
distance against the passage's start once more."""
def avoid_spot_type(origin: Vec3, passage: Passage, spots: list[AvoidSpot]) -> int {
    between = passage.kind not in [
        TRAVEL_WALKOFFLEDGE, TRAVEL_JUMP, TRAVEL_TELEPORT, TRAVEL_ELEVATOR, TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_JUMPPAD, TRAVEL_FUNCBOB
    ];
    kind = 0;
    for spot in spots {
        reach = spot.radius * spot.radius;
        near = line_distance_squared(spot.origin, origin, passage.start);
        from_start = spot.origin.sub(passage.start);
        from_origin = spot.origin.sub(origin);
        if near < reach and from_origin.dot(from_origin) > near {
            kind = spot.kind;
        } elif between {
            along = line_distance_squared(spot.origin, passage.start, passage.finish);
            if along < reach and from_start.dot(from_start) > along {
                kind = spot.kind;
            }
        } elif near < reach and from_start.dot(from_start) > near {
            kind = spot.kind;
        }
        if kind == AVOID_ALWAYS {
            return kind;
        }
    }
    return kind;
}

"""be_ai_move.c's avoid-reachability list of a bot's move state (avoidreach,
avoidreachtimes, avoidreachtries; MAX_AVOIDREACH is 1, so it holds a single
passage). Each passage the bot sets out on is added: the one already held
counts another try while its time is still running, and a different one only
takes the slot once that time is over. A passage tried more than
AVOIDREACH_TRIES times is passed over when the bot next chooses its way
(BotGetReachabilityToGoal), until six seconds after its last use."""
obj AvoidReach {
    has passage: Passage | None = None,
        until: float = 0.0,
        tries: int = 0;

    """BotAddToAvoidReach."""
    def add(passage: Passage, now: float) {
        if self.passage is passage {
            self.tries = self.tries + 1 if self.until > now else 1;
            self.until = now + AVOIDREACH_TIME;
        } elif self.until < now {
            self.passage = passage;
            self.until = now + AVOIDREACH_TIME;
            self.tries = 1;
        }
    }

    """Whether BotGetReachabilityToGoal passes `passage` over now."""
    def avoids(passage: Passage, now: float) -> bool {
        return self.passage is passage and self.until >= now and self.tries > AVOIDREACH_TRIES;
    }

    """BotResetAvoidReach."""
    def reset() {
        self.passage = None;
        self.until = 0.0;
        self.tries = 0;
    }

    """BotResetLastAvoidReach: the latest entry's time is over and one of
    its tries forgotten."""
    def reset_last() {
        if self.until > 0.0 {
            self.until = 0.0;
            if self.tries > 0 {
                self.tries -= 1;
            }
        }
    }
}

"""A travel table under construction: the times so far and the areas whose
entering passages still need relaxing (the next round's frontier), for the
travel `flags` and the areas `closed` to routing when it was begun."""
obj TravelJob {
    has goal: int,
        times: list[int],
        flags: int = TFL_DEFAULT,
        closed: set[int] = set(),
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
        mover_bounds: dict[int, AABB] = {},
        # Areas closed to routing for now (AREA_DISABLED set by
        # AAS_EnableRoutingArea: a shut door a bot is going to open), and
        # each set of them that tables have been built for.
        disabled: set[int] = set(),
        closures: list[list[int]] = [[]],
        closure: int = 0;

    """be_aas_route.c AAS_EnableRoutingArea: open or close an area to
    routing; returns whether it was open before. Botlib drops the routing
    caches the area is in (AAS_RemoveRoutingCacheUsingArea); here each set of
    closed areas has its own travel tables, so those of a door that shuts and
    opens are kept for the next time. Only areas with reachabilities count:
    no route runs through the others."""
    def enable_area(area: int, enable: bool) -> bool {
        was_open = area not in self.disabled;
        if area <= 0 or area >= len(self.areas) or was_open == enable {
            return was_open;
        }
        if enable {
            self.disabled.discard(area);
        } else {
            self.disabled.add(area);
        }
        closed = sorted([shut for shut in self.disabled if self.aas.areas[shut].reach_count > 0]);
        if closed not in self.closures {
            self.closures.append(closed);
        }
        self.closure = self.closures.index(closed);
        return was_open;
    }

    """Whether a route with the travel `flags` may take a passage: its travel
    type and the contents of the area it enters are allowed, and that area
    is open (be_ai_move.c BotValidTravel, and AREA_DISABLED)."""
    def allows(passage: Passage, flags: int) -> bool {
        return passage.flags & ~flags == 0 and passage.target not in self.disabled;
    }

    """The cache key of a goal's table for a set of travel flags and the
    areas now closed (or with none closed, `open_doors`): the goal area and
    the index of that pair among those seen so far."""
    def table_key(goal: int, flags: int, open_doors: bool = False) -> int {
        profile = flags * 64 + (0 if open_doors else self.closure);
        if profile not in self.profiles {
            # More profiles than a key has room for: start the cache over.
            if len(self.profiles) >= 64 {
                self.profiles = [];
                self.tables = {};
                self.recent = [];
                self.jobs = [];
            }
            self.profiles.append(profile);
        }
        return goal * 64 + self.profiles.index(profile);
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

    """A table to estimate travel times to `goal` by: the one times_for
    gives, or while tables for the areas now closed are still being built,
    the one with every area open."""
    def times_about(goal: int, flags: int = TFL_DEFAULT) -> list[int] | None {
        ready = self.times_for(goal, flags);
        if ready is None and self.closure != 0 {
            for choice in [flags, TFL_DEFAULT] {
                key = self.table_key(goal, choice, True);
                if key in self.tables {
                    return self.tables[key];
                }
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
        job = TravelJob(
            goal=goal, times=times, flags=flags, closed=set(self.disabled), key=key, frontier=[self.areas[goal]]
        );
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
            times=job.times, areas=self.areas, chunk=chunk, queued=job.queued, allowed=job.flags, closed=job.closed
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
        closed: set[int] = set(),
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
        # type", the next area is disabled or its contents are not allowed.
        if here.flags & ~self.allowed or here.target in self.closed {
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

"""The mover a reachability runs into: the first mover area among those it
passes through and the one it enters (be_aas_route.c AAS_PredictRoute's
RSE_ENTERCONTENTS test). Barrier jumps, water jumps and walks off ledges
pass through the areas along their vertical leg (AAS_InitReachabilityAreas);
the other travel types only count the area they enter."""
def passage_mover(aas: Aas, reach: AasReach) -> int {
    through: list[tuple[int, Vec3]] = [];
    if reach.kind in [TRAVEL_BARRIERJUMP, TRAVEL_WATERJUMP] {
        through = aas.trace_areas(reach.start, Vec3(x=reach.start.x, y=reach.start.y, z=reach.finish.z), 32);
    } elif reach.kind == TRAVEL_WALKOFFLEDGE {
        through = aas.trace_areas(Vec3(x=reach.finish.x, y=reach.finish.y, z=reach.start.z), reach.finish, 32);
    }
    for crossed in through {
        model = area_mover_model(aas.areas[crossed[0]].contents);
        if model > 0 {
            return model;
        }
    }
    return area_mover_model(aas.areas[reach.area].contents);
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
            passage.mover = passage_mover(aas, reach);
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

"""be_ai_move.c BotTravel_Jump's run start: up to 80 units back from the
jump's start along the line of the jump, as far as that stays in the area
the jump leaves (sampled every 10 units). The bot goes there first, so that
it runs up to the jump along its line. None when there is no room."""
def jump_run_start(mesh: NavMesh, area: int, passage: Passage) -> Vec3 | None {
    back = Vec3(x=passage.start.x - passage.finish.x, y=passage.start.y - passage.finish.y);
    if back.length() < 0.001 {
        return None;
    }
    back = back.normalized();
    room = 0.0;
    while room < 80.0 {
        probe = passage.start.add(back.scale(room + 10.0)).add(Vec3(z=2.0));
        if mesh.aas.area_at(probe) != area {
            break;
        }
        room += 10.0;
    }
    if room <= 0.0 {
        return None;
    }
    return passage.start.add(back.scale(room));
}

"""A planned path: waypoints at bot-origin height, the launch to apply on
reaching each one, the AAS area whose entry completes it (0 when only
reaching the point itself counts, as for a jump's takeoff), and the passage a
waypoint travels when that takes more than heading for it (rocket jumps,
ladders, water jumps, elevators and bobbing platforms; be_ai_move.c
BotTravel_*)."""
obj BotRoute {
    has points: list[Vec3] = [],
        launches: list[Vec3] = [],
        areas: list[int] = [],
        passages: list[Passage | None] = [],
        found: bool = False,
        pending: bool = False,
        leg_started: float = -1.0,
        jumped: bool = False,
        # Whether the leg under way has been added to the avoid list.
        noted: bool = False,
        # The gap found ahead on a walking leg (BotGapDistance) and when it
        # was last looked for.
        gap: float = 0.0,
        gap_checked: float = -1000.0,
        # Whether the bot has come to the start of the walk under way.
        begun: bool = False;

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
        self.noted = False;
        self.gap = 0.0;
        self.gap_checked = -1000.0;
        self.begun = False;
    }

    """Give the route up where the bot stands, so that its way is chosen
    again (the lists are emptied in place: the body follows the same ones)."""
    def abandon() {
        self.points.clear();
        self.areas.clear();
        self.launches.clear();
        self.passages.clear();
        self.leg_started = -1.0;
    }
}

"""The passage out of `area` that leads soonest to the goal of the travel
table `times` for a bot at `position` (be_aas_route.c
AAS_AreaReachabilityToGoalArea), or None when none does."""
def best_exit(
    mesh: NavMesh,
    area: int,
    position: Vec3,
    times: list[int],
    flags: int,
    avoid: AvoidReach | None = None,
    now: float = 0.0,
    came_from: int = 0,
    spots: list[AvoidSpot] = []
) -> Passage | None {
    best: Passage | None = None;
    best_cost = UNREACHED;
    for passage in [mesh.areas[area]->:Exits:->][?:Passage] {
        if times[passage.target] >= UNREACHED or not mesh.allows(passage, flags) {
            continue;
        }
        # "do not go back to the previous area if the goal didn't change"
        if came_from > 0 and passage.target == came_from {
            continue;
        }
        # "if the bot should not use this reachability to avoid bad spots"
        if spots and avoid_spot_type(position, passage, spots) != 0 {
            continue;
        }
        # "check if it isn't an reachability to avoid"
        if avoid is not None and avoid.avoids(passage, now) {
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
    return best;
}

"""be_aas_route.c AAS_PredictRoute stopping at a mover (RSE_ENTERCONTENTS
with AREACONTENTS_MOVER): follow the route from `origin` in `area` toward
`goal_area` for at most `max_areas` passages or `max_time` hundredths of a
second, and return the BSP model of the first mover it runs into, or 0."""
def predict_mover(
    mesh: NavMesh, area: int, origin: Vec3, goal_area: int, flags: int, max_areas: int = 100, max_time: int = 1000
) -> int {
    if area == 0 or goal_area == 0 {
        return 0;
    }
    times = mesh.times_for(goal_area, flags);
    if times is None or times[area] >= UNREACHED {
        return 0;
    }
    position = origin;
    spent = 0;
    steps = 0;
    while area != goal_area and steps < max_areas {
        passage = best_exit(mesh, area, position, times, flags);
        if passage is None {
            return 0;
        }
        if passage.mover > 0 {
            return passage.mover;
        }
        spent += run_time(position, passage.start) + passage.time;
        if spent > max_time {
            return 0;
        }
        position = passage.finish;
        area = passage.target;
        steps += 1;
    }
    return 0;
}

"""Plan from a bot origin to a goal point (in `goal_area` when the goal
knows its area, as an item floating over a jump pad does) with the travel
`flags`: descend
the goal's travel times one passage at a time, up to `limit` passages, then
finish at the goal itself. Like botlib, a passage is done once the bot stands
in its target area; jumps, ledges, pads and teleporters first need their
takeoff point, and the passages that need more than a heading (rocket jumps,
ladders, water jumps and movers) carry their passage for the bot's travel to
follow. `avoid` is the bot's avoid-reachability list at the clock `now`."""
def plan_route(
    mesh: NavMesh,
    origin: Vec3,
    goal: Vec3,
    limit: int = 32,
    flags: int = TFL_DEFAULT,
    goal_area: int = 0,
    avoid: AvoidReach | None = None,
    now: float = 0.0,
    spots: list[AvoidSpot] = []
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
    # The area just left: BotGetReachabilityToGoal never takes a passage
    # straight back into it while the goal is the same.
    came_from = 0;
    while area != goal_area and steps < limit {
        # The way out of the area the bot is in keeps clear of the passage
        # it avoids; the later ones are chosen as it gets there.
        best = best_exit(mesh, area, position, times, flags, avoid if steps == 0 else None, now, came_from, spots);
        if best is None {
            return route;
        }
        came_from = area;
        if best.kind in [TRAVEL_TELEPORT, TRAVEL_JUMPPAD] {
            # The trigger carries the bot on; planning resumes where it lands.
            # A teleporter is walked on into, past the edge of its trigger
            # where the way starts.
            aim = best.start;
            if best.kind == TRAVEL_TELEPORT {
                into = Vec3(x=best.start.x - position.x, y=best.start.y - position.y);
                if into.length() > 1.0 {
                    aim = best.start.add(into.normalized().scale(16.0));
                }
            }
            route.add(aim, best.target, passage=best);
            route.found = True;
            return route;
        }
        if best.kind in [TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_LADDER, TRAVEL_WATERJUMP, TRAVEL_ELEVATOR, TRAVEL_FUNCBOB] {
            route.add(best.finish, best.target, passage=best);
        } else {
            if best.kind == TRAVEL_JUMP {
                run_up = jump_run_start(mesh, area, best);
                if run_up is not None {
                    route.add(run_up, 0, passage=best);
                }
            }
            if best.kind in [TRAVEL_BARRIERJUMP, TRAVEL_JUMP] {
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
    times = mesh.times_about(goal_area, flags);
    if times is None or times[area] >= UNREACHED {
        return 0;
    }
    # The table runs from the area's centre; the bot starts at its origin.
    best = UNREACHED;
    for passage in exits {
        if times[passage.target] >= UNREACHED or not mesh.allows(passage, flags) {
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
