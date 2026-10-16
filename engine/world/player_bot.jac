"""The player bot: the player's own body played by the engine, through the
same `Intent` a keyboard and mouse make (issue #88).

It routes over the level's navigation (the map's AAS, or one compiled from
the level by `engine/nav/compile.jac`), follows the route with the Q3 bots'
own travel (`FollowRoute`), and turns what that asks for into a frame's
command: a heading as forward and sideways shares of the run, a turn of the
view, a jump, a duck. It fights what it sees with the best weapon it holds.

What it is doing is a mode: a node under the bot's mind, entered by the
`AutoThink` walker ten times a second, as the Q3 bots' `ai_dmnet.c` states
are. Modes hand over to one another along `Shifts` edges."""
import math;
import time;
import from .world { World, Player }
import from .level { Level }
import from .bot_routes { NavMesh, HasNavMesh, BotRoute, AvoidReach, plan_route, build_navmesh, predict_mover, area_travel_time, UNREACHED }
import from .bot_travel { FollowRoute, TravelResult, gap_distance, soonest_out, compass, BODY_REACH_BELOW, BODY_REACH_ABOVE }
import from .pickups { Pickup, HasPickup }
import from .inventory { quantity }
import from .bot_trace { BotTrace, trace_text, trace_number, trace_point }
import from .combat { Opponent, HasOpponent, CombatState, owns_weapon, has_ammo_for, weapon_rule, Projectile, HasProjectile }
import from .exits { LevelExit, HasExit }
import from .doors { Door, HasDoor, door_starts_open }
import from .trains { Train, HasTrain, TrackPoint, TrackNext }
import from .signals { Signal, HasSignal, Targets }
import from .objectives { Objective, mover_objectives, exit_objectives, objective_mover, mover_area_blocked, objective_item_box }
import from ..nav.compile { compile_navigation }
import from ..formats.aas { TFL_DEFAULT, TRAVEL_JUMP, TRAVEL_ELEVATOR, area_mover_model }
import from ..input.input { Intent }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..math.aabb { AABB }

glob AUTO_THINK: float = 0.1,
    # How fast the bot turns its view, radians a second.
    AUTO_TURN: float = 9.0,
    # How far it looks for enemies.
    AUTO_SIGHT: float = 2048.0,
    # What objectives fetch supplies (as against opening the way) are for.
    AUTO_SUPPLIES: list[str] = ["ammo", "health", "supply"],
    # How long something given up is passed over: supplies (there are
    # others) and the rest.
    AUTO_PASS_SUPPLY: float = 240.0,
    AUTO_PASS_OTHER: float = 60.0,
    # Seconds a fight may go on with no harm done and no nearer before the
    # enemy is given up and the bot goes back to its way.
    AUTO_FIGHT_STALL: float = 12.0;

"""Something the bot can be doing."""
node AutoMode {
    has name: str;
}

"""Making for the level's way out."""
node SeekExit(AutoMode) {}

"""Fighting what it sees, still on its way."""
node Engage(AutoMode) {}

"""Free of where it was stuck: a new route from where it is."""
node Unstick(AutoMode) {}

"""With no exit to make for (an arena, or a level whose way on is not
known yet): after what is worth having, else where it has not been."""
node Roam(AutoMode) {}

"""Doing what lets it by: pressing a button, standing in a trigger,
shooting a switch, fetching a key (`engine/world/objectives.jac`)."""
node Activate(AutoMode) {}

edge Shifts: AutoMode --> AutoMode {}

"""The bot's modes, and the one it is in."""
node AutoMind {
    has current: str = "seek_exit";
}

edge HasAutoMode: AutoMind --> AutoMode {}

def build_auto_mind() -> AutoMind {
    mind = AutoMind();
    seek = SeekExit(name="seek_exit");
    engage = Engage(name="engage");
    unstick = Unstick(name="unstick");
    activate = Activate(name="activate");
    roam = Roam(name="roam");
    for mode in [seek, engage, unstick, activate, roam] {
        mind +>:HasAutoMode:+> mode;
    }
    seek +>:Shifts:+> engage;
    seek +>:Shifts:+> unstick;
    seek +>:Shifts:+> activate;
    engage +>:Shifts:+> seek;
    engage +>:Shifts:+> unstick;
    unstick +>:Shifts:+> seek;
    activate +>:Shifts:+> seek;
    seek +>:Shifts:+> roam;
    roam +>:Shifts:+> seek;
    roam +>:Shifts:+> engage;
    roam +>:Shifts:+> activate;
    activate +>:Shifts:+> engage;
    engage +>:Shifts:+> activate;
    return mind;
}

"""The player bot's state across frames."""
node PlayerBot {
    has mind: AutoMind = build_auto_mind(),
        level: Level | None = None,
        mesh: NavMesh | None = None,
        route: BotRoute = BotRoute(),
        avoid: AvoidReach = AvoidReach(),
        goal: Vec3 | None = None,
        goal_area: int = 0,
        goal_name: str = "",
        enemy: Opponent | None = None,
        # What it is doing (to get by a mover, to fetch a supply).
        objective: Objective | None = None,
        # Objectives set aside for one in their way, the latest last.
        waiting: list[Objective] = [],
        # What it gave up on, by where it was, and until when.
        given_up: list[tuple[Vec3, float]] = [],
        # Monsters given up killing, and until when (they move about).
        given_up_bodies: list[tuple[Opponent, float]] = [],
        # The fight under way: with whom, its health and distance last think,
        # the nearest it has been, and when the fight last got anywhere.
        fight_with: Opponent | None = None,
        fight_health: int = 0,
        fight_nearest: float = 0.0,
        fight_moved_at: float = 0.0,
        exit_goal: Vec3 | None = None,
        # The areas it has stood in, and when it last chose where to roam.
        visited: set[int] = set(),
        roam_chosen: float = -100.0,
        # A dodge under way: which way, until when.
        dodge_way: Vec3 = Vec3(),
        dodge_until: float = 0.0,
        # How long it has held still on a moving lift.
        ride_held: float = 0.0,
        # Its health last think, and when it last took a hit.
        last_health: int = 0,
        hurt_at: float = -100.0,
        # Since when it has stood waiting for a lift.
        waiting_since: float = -1.0,
        # area_near's answer this frame, and where it was asked from.
        near_frame: int = -1,
        near_origin: Vec3 = Vec3(),
        near_found: tuple[int, Vec3] = (0, Vec3()),
        # Whether it is getting out of a train's way, and what that train
        # sweeps.
        escaping: bool = False,
        swept: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        # The direction the view settles on while travelling (100: none yet).
        view_yaw: float = 100.0,
        roam_nearest: float = 1.0e9,
        roam_nearer_at: float = 0.0,
        # Areas compiled with their mover where the level starts it (a floor
        # that drops): usable only while it is still there.
        rest_areas: set[int] = set(),
        exit_area: int = 0,
        exit_name: str = "",
        clock: float = 0.0,
        think_wait: float = 0.0,
        replan_wait: float = 0.0,
        frames: int = 0,
        stuck_count: int = 0,
        # A sidestep round what it is caught on (BotAIBlocked): which way,
        # until when, and how many in a row without getting on.
        detour: Vec3 = Vec3(),
        detour_until: float = 0.0,
        detours: int = 0,
        reopened: float = -100.0,
        # Areas closed to routing: by area, the mover that shut it and until
        # when (a closing lapses; doors open).
        closed: dict[int, tuple[int, float]] = {},
        # How long it has been trying to move and not moving.
        blocked_time: float = 0.0,
        moving_time: float = 0.0,
        # Since when no route to the goal has been found from here.
        lost_since: float = -1.0,
        travel: TravelResult = TravelResult(),
        # A gap jump under way: 1 backing up to the run-up, 2 running at the
        # edge, 3 in the air; when it began.
        leap: int = 0,
        leap_started: float = 0.0,
        status: str = "",
        log_wait: float = 0.0,
        compile_seconds: float = 0.0,
        # QP_AUTOPLAY_SHOTS=<seconds>: a screenshot that often, to see the
        # bot play afterwards (into QP_AUTOPLAY_SHOT_DIR, relative).
        shot_every: float = 0.0,
        shot_wait: float = 0.0,
        shot_dir: str = ".jac/shots",
        fired: bool = False,
        trace: BotTrace = BotTrace(),
        # Where it has died on this map (kept across restarts of the level):
        # what is only worth having is not fetched near there again.
        deaths_map: str = "",
        death_spots: list[Vec3] = [],
        dead_seen: bool = False,
        menu_notice: str = "",
        # Which way it sidesteps in a fight (1 right, -1 left), and when it
        # turns about.
        strafe: float = 1.0,
        strafe_wait: float = 0.0;

    """The name of a screenshot due now, or "" (QP_AUTOPLAY_SHOTS)."""
    def shot_name(dt: float) -> str {
        if self.shot_every <= 0.0 {
            return "";
        }
        self.shot_wait -= dt;
        if self.shot_wait > 0.0 {
            return "";
        }
        self.shot_wait = self.shot_every;
        level = self.level;
        name = level.name if level is not None else "level";
        stamp = str(int(self.clock * 10.0));
        return self.shot_dir + "/" + name + "_" + "0" * max(0, 5 - len(stamp)) + stamp + ".png";
    }

    """The objectives under way, the current one first, each with why:
    "pickup for mover 39 needs key_silver < ..." ("-" when none)."""
    def chain -> str {
        current = self.objective;
        if current is None {
            return "-";
        }
        held = [current] + list(reversed(self.waiting));
        return " < ".join([step.kind + " (" + step.why + ")" for step in held]);
    }

    """Why the objective under way is being done, or ""."""
    def objective_why -> str {
        objective = self.objective;
        return objective.why if objective is not None else "";
    }

    """The route's next waypoint and the passage it is on, for the log."""
    def next_leg -> str {
        route = self.route;
        if not route.points {
            return "-";
        }
        point = route.points[0];
        passage = route.passages[0] if route.passages else None;
        kind = passage.kind if passage is not None else 0;
        return str(int(point.x)) + "," + str(int(point.y)) + "," + str(int(point.z)) + "/" + str(kind);
    }

    """The area the bot is in: the one at its origin, else (stood closer to
    a wall than the compiled floor reaches) the one a few units beside it,
    as botlib's BotReachabilityArea probes round a bot. With the point that
    area was found at."""
    def area_near(origin: Vec3) -> tuple[int, Vec3] {
        mesh = self.mesh;
        if mesh is None {
            return (0, origin);
        }
        # Asked often in a frame from the same place: found once a frame.
        if self.near_frame == self.frames and self.near_origin.sub(origin).length() < 0.01 {
            return self.near_found;
        }
        found = (0, origin);
        area = mesh.locate(origin);
        if area > 0 {
            found = (area, origin);
        } else {
            for reach in [12.0, 24.0, 36.0] {
                for k in range(8) {
                    angle = float(k) * math.pi / 4.0;
                    spot = origin.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach));
                    beside = mesh.locate(spot);
                    if beside > 0 and found[0] == 0 {
                        found = (beside, spot);
                    }
                }
            }
        }
        self.near_frame = self.frames;
        self.near_origin = origin;
        self.near_found = found;
        return found;
    }

    """The first area with ways out found round `point`: out to each of
    `reaches` in `ways` directions (just the point for a reach of 0), each
    looked for that far below it in turn by `drops`; (0, point) when none."""
    def area_round(point: Vec3, reaches: list[float], ways: int, drops: list[float]) -> tuple[int, Vec3] {
        mesh = self.mesh;
        if mesh is None {
            return (0, point);
        }
        for reach in reaches {
            for k in range(ways if reach > 0.0 else 1) {
                angle = float(k) * 2.0 * math.pi / float(ways);
                spot = point.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach));
                for drop in drops {
                    area = mesh.aas.area_at(spot.sub(Vec3(z=drop)));
                    if area > 0 and mesh.aas.areas[area].reach_count > 0 {
                        return (area, spot);
                    }
                }
            }
        }
        return (0, point);
    }

    """The areas of the mover with BSP `model` (all of them: a mover spans
    several)."""
    def mover_areas(model: int) -> list[int] {
        mesh = self.mesh;
        if mesh is None {
            return [];
        }
        return [a for a in range(1, len(mesh.aas.areas)) if area_mover_model(mesh.aas.areas[a].contents) == model];
    }

    """Close every area of the mover `model` for a while."""
    def close_mover(model: int) {
        for area in self.mover_areas(model) {
            self.close_area(area, model);
        }
    }

    """The lift, plat or door the bot stands on while it is still going up
    or down, or None."""
    def rising_under(world: World, level: Level, origin: Vec3) -> Door | None {
        below = level.collision.trace(origin, origin.sub(Vec3(z=2.0)));
        if below.fraction >= 1.0 or below.model <= 0 {
            return None;
        }
        leader = objective_mover(world, below.model);
        if leader is None or leader.state not in ["opening", "closing"] or abs(leader.travel.z) < 24.0 {
            return None;
        }
        return leader;
    }

    """The way out of the path of a train that pins what it meets (e1m3's
    log down its corridor), when the bot is in what it sweeps on the leg it
    is on, or is about to set off on (what fires it has fired and waits out
    a delay); None when out of the way, or riding it."""
    def train_way_out(world: World, level: Level, origin: Vec3) -> Vec3 | None {
        soon: list[Signal] = [];
        for signal in [world->:HasSignal:->][?:Signal] {
            if signal.queued {
                soon.extend([fired for fired in [signal->:Targets:->][?:Signal]]);
            }
        }
        for train in [world->:HasTrain:->][?:Train] {
            if train.damage < 10 or train.kind == "secret" or train.activation.killed {
                continue;
            }
            start = train.motion;
            finish = train.motion;
            heading = train.destination;
            if train.running and heading is not None {
                finish = heading.origin.sub(train.anchor);
            } elif not train.running and any([train.activation is fired for fired in soon]) {
                following = [train.current->:TrackNext:->][?:TrackPoint];
                if following {
                    finish = following[0].origin.sub(train.anchor);
                }
            }
            travel = finish.sub(start);
            if travel.length() < 1.0 {
                continue;
            }
            lo = Vec3(x=min(start.x, finish.x), y=min(start.y, finish.y), z=min(start.z, finish.z))
                .add(train.bounds.mins).sub(BODY_REACH_BELOW);
            hi = Vec3(x=max(start.x, finish.x), y=max(start.y, finish.y), z=max(start.z, finish.z))
                .add(train.bounds.maxs).add(BODY_REACH_ABOVE);
            if origin.x < lo.x or origin.x > hi.x or origin.y < lo.y or origin.y > hi.y or origin.z < lo.z or origin.z > hi.z {
                continue;
            }
            self.swept = AABB(mins=lo, maxs=hi);
            below = level.collision.trace(origin, origin.sub(Vec3(z=2.0)));
            if below.fraction < 1.0 and below.model == train.model {
                continue;
            }
            # Only where it is coming: behind it (under a crusher on its
            # way up) is passed through.
            heading_way = travel.normalized();
            middle = train.bounds.center().add(train.motion);
            size = train.bounds.maxs.sub(train.bounds.mins);
            reach = (abs(size.x * heading_way.x) + abs(size.y * heading_way.y) + abs(size.z * heading_way.z)) * 0.5 + 24.0;
            if origin.sub(middle).dot(heading_way) < -reach {
                continue;
            }
            # Sideways either way, or on ahead of it: the soonest out of
            # the swept box by a clear way, else the clearest.
            along = Vec3(x=travel.x, y=travel.y);
            ways = compass(4);
            if along.length() > 1.0 {
                along = along.normalized();
                ways = [Vec3(x=-along.y, y=along.x), Vec3(x=along.y, y=-along.x), along];
            }
            return soonest_out(level.collision, origin, lo, hi, ways, 400.0);
        }
        return None;
    }

    """Whether what is at `point` was given up lately and is still passed
    over."""
    def passed_over(point: Vec3) -> bool {
        for (spot, until) in self.given_up {
            if until > self.clock and spot.sub(point).length() < 8.0 {
                return True;
            }
        }
        return False;
    }

    """Whether a monster is given up fighting, for now."""
    def passed_body(body: Opponent) -> bool {
        for (quarry, until) in self.given_up_bodies {
            if until > self.clock and quarry is body {
                return True;
            }
        }
        return False;
    }

    """Close `area` to routing for a while, for the mover `model` (0: none)
    that makes it no way through."""
    def close_area(area: int, model: int, hold: float = 30.0) {
        mesh = self.mesh;
        if mesh is None or area <= 0 {
            return;
        }
        mesh.enable_area(area, False);
        self.closed[area] = (model, self.clock + hold);
    }

    """Open again the closed areas whose closing has lapsed or whose mover
    no longer stands in the way; and all of them, with what was given up,
    after five seconds with no way on. Whether any was opened."""
    def reopen_areas(world: World, player: Player) -> bool {
        mesh = self.mesh;
        if mesh is None {
            return False;
        }
        opened = False;
        for area in list(self.closed.keys()) {
            (model, until) = self.closed[area];
            # A plat's top closed while the plat was down (model negated):
            # open again once it is up.
            raised = False;
            if model < 0 {
                plat = objective_mover(world, -model);
                raised = plat is None or plat.position >= 0.99;
            }
            if self.clock > until or raised or (model > 0 and not mover_area_blocked(world, model, player, area in self.rest_areas)) {
                mesh.enable_area(area, True);
                self.closed.pop(area);
                opened = True;
            }
        }
        if self.lost_since >= 0.0 and self.clock - self.lost_since > 5.0 {
            self.given_up = [];
            for area in list(mesh.disabled) {
                mesh.enable_area(area, True);
            }
            self.closed = {};
            self.lost_since = -1.0;
            opened = True;
            print("AUTOPLAY no way on: trying again what was closed and given up");
        }
        if opened {
            self.route.abandon();
        }
        return opened;
    }

    """The nearest point to `origin` that lies in an area with ways out, at
    about its height (out of a button's recess, off a ledge no area covers),
    or None."""
    def nearest_area_point(origin: Vec3) -> Vec3 | None {
        found = self.area_round(origin, [16.0, 32.0, 48.0, 64.0, 96.0, 128.0], 16, [0.0, 16.0, 32.0, 48.0, -16.0]);
        return found[1] if found[0] > 0 else None;
    }

    """The middle of the nearest area with a way to the goal, looked for out
    to 384, then 768, then 1536 units; or None."""
    def way_on(origin: Vec3) -> Vec3 | None {
        mesh = self.mesh;
        if mesh is None or self.goal_area <= 0 {
            return None;
        }
        times = mesh.times_to(self.goal_area, TFL_DEFAULT);
        here_area = self.area_near(origin)[0];
        best: Vec3 | None = None;
        best_distance = 1.0e9;
        for size in [384.0, 768.0, 1536.0] {
            reach = Vec3(x=size, y=size, z=size * 0.5);
            for area in mesh.aas.box_areas(origin.sub(reach), origin.add(reach), 512) {
                if area == here_area or area >= len(times) or times[area] >= UNREACHED {
                    continue;
                }
                center = mesh.aas.areas[area].center;
                distance = center.sub(origin).length();
                if distance < best_distance {
                    best_distance = distance;
                    best = center;
                }
            }
            if best is not None {
                return best;
            }
        }
        # Nowhere near has a way on: what was closed may be open now (a door
        # opened since); open it all again, at most every ten seconds.
        if mesh.disabled and self.clock - self.reopened > 10.0 {
            self.reopened = self.clock;
            for area in list(mesh.disabled) {
                mesh.enable_area(area, True);
            }
            self.lost_since = -1.0;
            print("AUTOPLAY lost: closed areas opened again");
        }
        return best;
    }

    """A running jump over a gap (the route's next passage): back up along
    the jump's line to a run-up, run through the takeoff and jump at the
    edge, keep on in the air, and plan again from wherever it lands. The
    command for this frame, or None when no jump is under way."""
    def leap_over(level: Level, player: Player, origin: Vec3) -> Intent | None {
        route = self.route;
        passage = route.passages[0] if route.passages else None;
        if passage is None or passage.kind != TRAVEL_JUMP {
            self.leap = 0;
            return None;
        }
        line = Vec3(x=passage.finish.x - passage.start.x, y=passage.finish.y - passage.start.y);
        if line.length() < 1.0 {
            return None;
        }
        line = line.normalized();
        if self.leap == 0 {
            self.leap = 1;
            self.leap_started = self.clock;
        }
        if self.clock - self.leap_started > 6.0 {
            # It is not working out: let the route be chosen again.
            self.leap = 0;
            route.abandon();
            return None;
        }
        aim = line;
        if self.leap == 1 {
            # As far back as the floor allows, up to 128 units.
            back = level.collision.trace(passage.start, passage.start.sub(line.scale(128.0)));
            room = max(0.0, back.fraction * 128.0 - 8.0);
            run_up = passage.start.sub(line.scale(room));
            gap = Vec3(x=run_up.x - origin.x, y=run_up.y - origin.y);
            if gap.length() > 12.0 {
                aim = gap.normalized();
            } else {
                self.leap = 2;
            }
        }
        intent = Intent();
        along = Vec3(x=origin.x - passage.start.x, y=origin.y - passage.start.y).dot(line);
        if self.leap == 2 and along >= -12.0 and player.grounded {
            intent.jump = True;
            self.leap = 3;
        }
        if self.leap == 3 and player.grounded and along > 24.0 {
            # Down again: the route goes on from here.
            self.leap = 0;
            route.abandon();
        }
        intent.move = autoplay_move(player.yaw, aim);
        self.travel = TravelResult(direction=aim, speed=400.0);
        return intent;
    }

    """Stuck is trying to move and not moving: on the ground, asking for a
    run and going nowhere, not waiting on a lift or a door. Caught so for
    half a second it steps aside, the clearer way (BotAIBlocked); three
    times without getting on, it keeps off that way a while and plans
    again."""
    def check_blocked(level: Level, player: Player, origin: Vec3, intent: Intent, dt: float) {
        asked = Vec3(x=intent.move.x, y=intent.move.y).length();
        speed = Vec3(x=player.velocity.x, y=player.velocity.y).length();
        foe = self.enemy;
        fighting = foe is not None and foe.health > 0 and foe.pos.sub(player.pos).length() < 400.0;
        trying = asked > 0.5 and player.grounded and not self.travel.waiting and self.route.points and not fighting;
        if trying and speed < 30.0 {
            self.blocked_time += dt;
            self.moving_time = 0.0;
        } else {
            self.blocked_time = max(0.0, self.blocked_time - dt);
            if speed > 100.0 {
                self.moving_time += dt;
                if self.moving_time > 1.0 {
                    self.detours = 0;
                }
            }
        }
        if self.blocked_time < 0.5 or self.clock < self.detour_until or not self.route.points {
            return;
        }
        self.blocked_time = 0.0;
        ahead = self.route.points[0].sub(origin);
        flat = Vec3(x=ahead.x, y=ahead.y);
        if flat.length() > 0.001 {
            flat = flat.normalized();
            left = Vec3(x=-flat.y, y=flat.x);
            to_left = level.collision.trace(origin, origin.add(left.scale(48.0))).fraction;
            to_right = level.collision.trace(origin, origin.sub(left.scale(48.0))).fraction;
            side = left if to_left >= to_right else left.scale(-1.0);
            self.detour = side.add(flat.scale(0.4)).normalized();
            self.detour_until = self.clock + 0.5;
        }
        self.detours += 1;
        if self.detours >= 3 {
            passage = self.route.passages[0] if self.route.passages else None;
            if passage is not None {
                for k in range(6) {
                    self.avoid.add(passage, self.clock);
                }
            }
            self.route.abandon();
            self.detours = 0;
            self.stuck_count += 1;
            mesh = self.mesh;
            area = self.area_near(origin)[0] if mesh is not None else 0;
            print("AUTOPLAY blocked at", int(origin.x), int(origin.y), int(origin.z), "area", area, ": way avoided");
            self.trace.event("blocked", self.clock, {
                "at": trace_point(origin),
                "area": str(area),
                "goal": trace_text(self.goal_name)
            });
            self.trace.dump("blocked", self.clock);
        }
    }

    """Which way to step to keep out of harm: away from a grenade lying or
    landing within its reach, across the line of a rocket that will pass
    close, or off the line of a monster coming at it fast (a fiend's leap,
    a charge). None when nothing threatens."""
    def dodge(world: World, origin: Vec3) -> Vec3 | None {
        best: Vec3 | None = None;
        worst = 1.0e9;
        level = self.level;
        if level is None {
            return None;
        }
        for missile in [world->:HasProjectile:->][?:Projectile] {
            reach = max(missile.radius, 120.0 if missile.splash > 0 else 0.0);
            if reach <= 0.0 {
                continue;
            }
            rel = origin.sub(missile.pos);
            distance = rel.length();
            if distance > 320.0 {
                continue;
            }
            speed = missile.velocity.length();
            if missile.gravity or speed < 50.0 {
                # A grenade, while within its reach: of eight ways, the one
                # that ends farthest from it for the room there is (straight
                # away can be into a corner).
                if distance < reach + 48.0 and distance < worst {
                    worst = distance;
                    best_end = -1.0;
                    for way in compass(8) {
                        room = level.collision.trace(origin, origin.add(way.scale(96.0))).fraction * 96.0;
                        end = origin.add(way.scale(room)).sub(missile.pos);
                        far = Vec3(x=end.x, y=end.y).length();
                        if far > best_end {
                            best_end = far;
                            best = way;
                        }
                    }
                }
                continue;
            }
            # A rocket: where it passes nearest the bot in the next moment.
            ahead = missile.velocity.scale(1.0 / speed);
            along = rel.dot(ahead);
            if along < 0.0 or along / speed > 0.8 {
                continue;
            }
            miss = rel.sub(ahead.scale(along));
            if miss.length() < reach and along < worst {
                worst = along;
                side = Vec3(x=miss.x, y=miss.y);
                best = side.normalized() if side.length() > 0.001 else Vec3(x=-ahead.y, y=ahead.x).normalized();
            }
        }
        # A monster coming at it fast (a fiend's leap, a charge) is a missile
        # too: off its line, to the roomier side.
        for body in [world->:HasOpponent:->][?:Opponent] {
            if body.health <= 0 or body.dormant {
                continue;
            }
            rel = origin.sub(body.pos.sub(Vec3(z=body.eye_height)));
            flat_rel = Vec3(x=rel.x, y=rel.y);
            distance = flat_rel.length();
            run = Vec3(x=body.velocity.x, y=body.velocity.y);
            if distance > 350.0 or distance < 1.0 or run.length() < 250.0 {
                continue;
            }
            closing = run.dot(flat_rel.scale(1.0 / distance));
            if closing < 200.0 or distance >= worst {
                continue;
            }
            worst = distance;
            across = Vec3(x=-run.y, y=run.x).normalized();
            left_room = level.collision.trace(origin, origin.add(across.scale(64.0))).fraction;
            right_room = level.collision.trace(origin, origin.sub(across.scale(64.0))).fraction;
            if right_room > left_room {
                across = across.scale(-1.0);
            }
            best = across;
        }
        return best;
    }

    """The direction to look while travelling: toward the farthest of the
    route's next waypoints within 220 units that the eye can see, or None."""
    def look_ahead(level: Level, eye: Vec3, origin: Vec3) -> Vec3 | None {
        best: Vec3 | None = None;
        for point in self.route.points[0:6] {
            flat = Vec3(x=point.x - origin.x, y=point.y - origin.y);
            if flat.length() > 220.0 {
                break;
            }
            sight = level.collision.trace_point(eye, point.add(Vec3(z=16.0)));
            if sight.fraction < 0.98 {
                break;
            }
            if flat.length() > 24.0 {
                best = flat.normalized();
            }
        }
        return best;
    }

    """One frame of play: the command the player's body gets."""
    def drive(world: World, level: Level, player: Player, state: CombatState, dt: float) -> Intent;

    """Ready the bot for the level now loaded: its navigation, compiled when
    the map has none."""
    def begin_level(world: World, level: Level) {
        self.level = level;
        self.route = BotRoute();
        self.avoid = AvoidReach();
        self.goal = None;
        self.goal_area = 0;
        self.goal_name = "";
        self.enemy = None;
        self.objective = None;
        self.waiting = [];
        self.given_up = [];
        self.given_up_bodies = [];
        self.exit_goal = None;
        self.exit_area = 0;
        self.exit_name = "";
        self.visited = set();
        self.roam_chosen = -100.0;
        self.closed = {};
        self.lost_since = -1.0;
        self.leap = 0;
        self.stuck_count = 0;
        self.mind.current = "seek_exit";
        self.rest_areas = set();
        meshes = [world->:HasNavMesh:->][?:NavMesh];
        if meshes {
            self.mesh = meshes[0];
            self.status = "navigation from the map's AAS";
        } else {
            started = time.time();
            build = compile_navigation(world, level);
            self.compile_seconds = time.time() - started;
            self.mesh = build_navmesh(world, build.aas, level.bsp);
            self.rest_areas = set(build.rest_areas);
            self.status = "navigation compiled in " + str(round(self.compile_seconds, 1)) + " s: " + build.summary();
        }
        print("AUTOPLAY", level.bsp.game, level.name, self.status);
        mesh = self.mesh;
        self.trace.event("level", self.clock, {
            "map": trace_text(level.bsp.game + ":" + level.name),
            "navigation": trace_text(self.status),
            "areas": str(len(mesh.aas.areas) - 1 if mesh is not None else 0)
        });
    }
}

"""The best weapon held for an enemy `distance` away: the most damage a
second, without splash up close or in water where it would hurt."""
def autoplay_weapon(player: Player, state: CombatState, distance: float, wet: bool, needed: int = 0) -> int {
    best = 0;
    best_rate = -1.0;
    for rule in state.rules {
        if not owns_weapon(player, rule) or not has_ammo_for(player, rule) or rule.hand_thrown {
            continue;
        }
        # Pellets spread: the share that lands on a body (about 20 units
        # either side of the aim) at this distance. Fewer than a third is
        # ammunition thrown away.
        landing = 1.0;
        if rule.pellets > 1 and rule.spread > 0.0 {
            landing = min(1.0, 20.0 / max(1.0, distance * rule.spread));
        }
        if landing < 0.35 {
            continue;
        }
        # A monster whose wounds close after each hit (its pain puts its
        # health back) falls only to a shot that does `needed` at once.
        if needed > 0 and float(rule.damage * max(1, rule.pellets)) * landing + float(rule.splash) < float(needed) {
            continue;
        }
        # Its own blast: splash only beyond 200 units, and grenades, which
        # bounce back, beyond 350.
        if (rule.splash > 0 or rule.radius > 0.0) and distance < 200.0 {
            continue;
        }
        if rule.gravity and distance < 350.0 {
            continue;
        }
        if wet and (rule.avoid_underwater or rule.beam_damage > 0) {
            continue;
        }
        if rule.reach < distance {
            continue;
        }
        rate = (float(rule.damage * max(1, rule.pellets)) * landing + float(rule.splash)) / max(0.05, rule.interval);
        if rate > best_rate {
            best_rate = rate;
            best = rule.slot;
        }
    }
    return best;
}

"""What one shot must do to put `body` down: its health back after each
pain (OpponentRule.pain_health_reset, Q1's zombie), else nothing."""
def autoplay_needed(body: Opponent) -> int {
    return body.rule.pain_health_reset;
}

"""A flat world direction `way` as the move asked for with the view at
`yaw`: across and along it, scaled by `share`, with `rise` up or down."""
def autoplay_move(yaw: float, way: Vec3, share: float = 1.0, rise: float = 0.0) -> Vec3 {
    return Vec3(x=way.dot(right_from(yaw)) * share, y=way.dot(forward_from(yaw, 0.0)) * share, z=rise);
}

"""The way to back off from an enemy `ahead` (flat unit): straight back,
back to either side, or sideways, whichever has the most room within 96
units and no drop past a stair's depth; None when boxed in."""
def autoplay_retreat(level: Level, origin: Vec3, ahead: Vec3) -> Vec3 | None {
    back = ahead.scale(-1.0);
    left = Vec3(x=-ahead.y, y=ahead.x);
    best: Vec3 | None = None;
    best_room = 24.0;
    # Past it on a slant, last of all: boxed in, a player circles it.
    past_left = left.add(ahead.scale(0.6)).normalized();
    past_right = left.scale(-1.0).add(ahead.scale(0.6)).normalized();
    for way in [back, back.add(left).normalized(), back.sub(left).normalized(), left, left.scale(-1.0), past_left, past_right] {
        drop = gap_distance(level.collision, origin, way);
        if drop > 0.0 and drop <= 64.0 {
            continue;
        }
        room = level.collision.trace(origin, origin.add(way.scale(96.0))).fraction * 96.0;
        # Straight back is worth a little more than the same room aside, and
        # going past it a good deal less.
        if way is back {
            room += 8.0;
        }
        if way is past_left or way is past_right {
            room -= 40.0;
        }
        if room > best_room {
            best_room = room;
            best = way;
        }
    }
    return best;
}

"""What one hit must do to knock `body` down for a while when only a blow
big enough at once puts it down for good (Q1's zombie flinches from 9 and
falls from a second hit while it does), else 0."""
def autoplay_knock(body: Opponent) -> int {
    if body.rule.pain_health_reset <= 0 {
        return 0;
    }
    return max(1, body.rule.pain_threshold);
}

"""Whether a weapon held could hurt `body` from `distance` (in reach, with
ammunition, enough at once where that is what it takes)."""
def autoplay_can_hurt(player: Player, state: CombatState, body: Opponent, distance: float) -> bool {
    return autoplay_weapon(player, state, distance, player.water_depth >= 2, autoplay_needed(body)) > 0;
}

"""The nearest distance, of a few, from which a weapon held could hurt
`body` (a grenade launcher only from far off); -1 when none could."""
def autoplay_standoff(player: Player, state: CombatState, body: Opponent) -> float {
    for distance in [64.0, 220.0, 380.0, 520.0] {
        if autoplay_can_hurt(player, state, body, distance) {
            return distance;
        }
    }
    return -1.0;
}

"""The shortest turn from angle `a` to `b`, radians."""
def autoplay_turn(a: float, b: float) -> float {
    gap = (b - a) % (2.0 * math.pi);
    if gap > math.pi {
        gap -= 2.0 * math.pi;
    }
    return gap;
}

"""One think of the bot: it walks into the bot's mind, then into the mode
it is in, which decides the goal and the enemy."""
walker AutoThink {
    has bot: PlayerBot,
        world: World,
        level: Level,
        player: Player,
        state: CombatState,
        origin: Vec3,
        eye_height: float,
        switches: int = 0;

    can start with AutoMind entry {
        for mode in [here->:HasAutoMode:->][?:AutoMode] {
            if mode.name == here.current {
                visit [mode];
            }
        }
    }

    """Hand over to the mode `name` along the mind's edges: the modes to
    visit to run it this think too."""
    def shift(current: AutoMode, name: str) -> list[AutoMode] {
        if current.name != name {
            self.bot.trace.event("mode", self.bot.clock, {"from": trace_text(current.name), "to": trace_text(name)});
        }
        self.bot.mind.current = name;
        self.switches += 1;
        if self.switches >= 4 {
            return [];
        }
        return [mode for mode in [current->:Shifts:->][?:AutoMode] if mode.name == name];
    }

    """The nearest living enemy in sight, or None."""
    def spot_enemy() -> Opponent | None {
        eye = self.player.pos;
        best: Opponent | None = None;
        nearest = AUTO_SIGHT;
        for body in [self.world->:HasOpponent:->][?:Opponent] {
            rule = body.rule;
            if body.health <= 0 or body.dormant or rule.decoration or rule.inert or rule.good_guy {
                continue;
            }
            target = body.pos.sub(Vec3(z=body.eye_height * 0.5));
            distance = target.sub(eye).length();
            if distance >= nearest {
                continue;
            }
            line = self.level.collision.trace_point(eye, target);
            if line.fraction < 0.97 {
                continue;
            }
            # One given up fighting (no harm done to it, and no nearer, for a
            # while) is passed by, unless it is hurting the bot now.
            attacked = self.bot.clock - self.bot.hurt_at < 2.0 and distance < 200.0;
            if not attacked and self.bot.passed_body(body) {
                continue;
            }
            # One it holds nothing to hurt with (only the axe, out of reach;
            # nothing that does enough at once to a zombie) is not fought:
            # it keeps on its way, dodging what comes at it.
            standoff = autoplay_standoff(self.player, self.state, body);
            knock = autoplay_knock(body);
            # One put down for good only by a blow big enough at once (Q1's
            # zombie), lying down: left there, and walked past.
            if knock > 0 and body.pain_down {
                continue;
            }
            # Nothing held to put it down from here (none at all, or a
            # zombie at the grenade launcher's elbow): standing to fight is
            # only being hit. A zombie near is knocked down to get by; else
            # it keeps on its way, and turns on it again with room to.
            if standoff < 0.0 or (distance < standoff and not autoplay_can_hurt(self.player, self.state, body, distance)) {
                # The one it is already on is kept a little farther (no
                # dithering at the edge).
                limit = 450.0 if body is self.bot.enemy else 350.0;
                # Only one in the way is knocked down: close, or by the way
                # on. The rest are gone round, and the ammunition kept.
                # Hitting it while it waits on a lift, or at all of late,
                # is in the way too.
                in_way = distance < 150.0 or self.by_the_way(body.pos, 96.0)
                    or self.bot.travel.waiting or self.bot.clock - self.bot.hurt_at < 2.0;
                if knock <= 0 or distance > limit or not in_way
                    or autoplay_weapon(self.player, self.state, distance, self.player.water_depth >= 2, knock) <= 0 {
                    continue;
                }
            }
            nearest = distance;
            best = body;
        }
        return best;
    }

    """Where `target` can be shot from: up to eight areas within 900 units
    of it, the nearest first, with a clear line from eye height to it."""
    def shooting_spots(target: Vec3) -> list[tuple[int, Vec3]] {
        mesh = self.bot.mesh;
        found: list[tuple[int, Vec3]] = [];
        if mesh is None {
            return found;
        }
        near: list[tuple[float, int]] = [];
        for a in range(1, len(mesh.aas.areas)) {
            info = mesh.aas.areas[a];
            if info.reach_count == 0 or a in mesh.disabled {
                continue;
            }
            gap = info.center.sub(target).length();
            if gap < 900.0 {
                near.append((gap, a));
            }
        }
        near.sort();
        for (gap, a) in near[0:48] {
            eye = mesh.aas.areas[a].center.add(Vec3(z=self.eye_height));
            if self.level.collision.trace_point(eye, target).fraction > 0.97 {
                found.append((a, mesh.aas.areas[a].center));
                if len(found) >= 8 {
                    break;
                }
            }
        }
        return found;
    }

    """Whether `point` is within `room` units (across the floor) of the next
    few waypoints of the route."""
    def by_the_way(point: Vec3, room: float) -> bool {
        for waypoint in self.bot.route.points[0:6] {
            if Vec3(x=waypoint.x - point.x, y=waypoint.y - point.y).length() < room and abs(waypoint.z - point.z) < 96.0 {
                return True;
            }
        }
        return False;
    }

    """The level's way out the route finds soonest: an exit's trigger."""
    def choose_exit() {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return;
        }
        here_area = self.bot.area_near(self.origin)[0];
        self.nearest_exit(here_area);
        if bot.exit_goal is not None {
            return;
        }
        # None to be had with the doors it has found shut closed off: one
        # beyond such a door is still the way out, and the door is then seen
        # to on the way (what opens it, its key), as any door in the way is.
        shut = [area for (area, held) in bot.closed.items() if held[0] != 0 and area in mesh.disabled];
        if not shut {
            return;
        }
        for area in shut {
            mesh.enable_area(area, True);
        }
        self.nearest_exit(here_area);
        for area in shut {
            mesh.enable_area(area, False);
        }
    }

    """The nearest way out the bot can get to from `here_area` as the areas
    stand open, as its exit goal (left as it was when none)."""
    def nearest_exit(here_area: int) {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return;
        }
        best_time = UNREACHED;
        for portal in [self.world->:HasExit:->][?:LevelExit] {
            if not portal.volume.bounds {
                continue;
            }
            box = portal.volume.bounds[0];
            goal = box.mins.add(box.maxs).scale(0.5);
            if here_area == 0 {
                continue;
            }
            # The area at its middle, or (a tall volume's middle floats over
            # the floor, in no area) the one reaching into it soonest got to,
            # as with an item's box.
            area = 0;
            cost = UNREACHED;
            candidates = [mesh.locate(goal)];
            candidates.extend(mesh.aas.box_areas(box.mins, box.maxs, 16));
            for candidate in candidates {
                if candidate <= 0 or mesh.aas.areas[candidate].reach_count == 0 or candidate in mesh.disabled {
                    continue;
                }
                times = mesh.times_to(candidate, TFL_DEFAULT);
                took = times[here_area] if here_area < len(times) else UNREACHED;
                if took < cost {
                    cost = took;
                    area = candidate;
                }
            }
            if area == 0 {
                continue;
            }
            if cost < best_time {
                best_time = cost;
                bot.exit_goal = goal;
                bot.exit_area = area;
                bot.exit_name = "exit to " + portal.destination;
            }
        }
    }

    """Where an objective is done from: an area at its point, or beside it
    (a button sits in a wall, an item just over the floor)."""
    def stand_area(point: Vec3) -> tuple[int, Vec3] {
        mesh = self.bot.mesh;
        if mesh is None {
            return (0, point);
        }
        # A standing origin within reach of the point's own height: not the
        # floor of a pit below a button on a walkway.
        found = self.bot.area_round(point, [0.0, 16.0, 32.0, 48.0, 64.0], 8, [0.0, 16.0, 32.0, 48.0, 64.0, 80.0]);
        if found[0] > 0 {
            return found;
        }
        # Nothing near its height (it is over a mover compiled elsewhere,
        # a floor lowered as a lift): the area under it, however far.
        return (mesh.locate(point), point);
    }

    """The mover the route to the goal runs into first (or that the bot
    stands in), by BSP model; 0 when none."""
    def blocking_mover() -> int {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None or bot.exit_area == 0 {
            return 0;
        }
        area = self.bot.area_near(self.origin)[0];
        if area == 0 {
            return 0;
        }
        standing = area_mover_model(mesh.aas.areas[area].contents);
        if standing > 0 {
            return standing;
        }
        return predict_mover(mesh, area, self.origin, bot.exit_area, TFL_DEFAULT, 400, 100000);
    }

    """The movers the bot stands in and its route runs through, in order:
    each mover's BSP model with the first area of it on the way."""
    def route_movers() -> list[tuple[int, int]] {
        bot = self.bot;
        mesh = bot.mesh;
        found: list[tuple[int, int]] = [];
        if mesh is None {
            return found;
        }
        seen: list[int] = [];
        for area in [self.bot.area_near(self.origin)[0]] + bot.route.areas {
            if area <= 0 or area >= len(mesh.aas.areas) {
                continue;
            }
            model = area_mover_model(mesh.aas.areas[area].contents);
            if model > 0 and model not in seen {
                seen.append(model);
                found.append((model, area));
            }
        }
        return found;
    }

    """Look over the movers on the way: an area compiled with its mover at
    rest whose mover has moved away is closed to routing (and the route
    dropped); a mover that needs something done gives an objective.
    Whether one was taken up."""
    def check_movers() -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        movers = self.route_movers();
        if not bot.route.points {
            model = self.blocking_mover();
            if model > 0 {
                movers.append((model, 0));
            }
        }
        # Areas the route rides a lift into: the lift's own travel waits for
        # it there.
        lifted_into: set[int] = set();
        for k in range(min(len(bot.route.areas), len(bot.route.passages))) {
            passage = bot.route.passages[k];
            if passage is not None and passage.kind == TRAVEL_ELEVATOR {
                lifted_into.add(bot.route.areas[k]);
            }
        }
        here_now = bot.area_near(self.origin)[0];
        busy = self.opened_with(bot.objective.mover) if bot.objective is not None else [];
        # The next leg rides a door that only moves when something sets it
        # going (e1m3's rising block): what sets it going comes first.
        if bot.route.passages {
            first = bot.route.passages[0];
            if first is not None and first.kind == TRAVEL_ELEVATOR and first.model not in busy {
                lift = objective_mover(self.world, first.model);
                if lift is not None and lift.kind == "door" and not lift.automatic and lift.state not in ["opening", "closing"] {
                    starters = mover_objectives(self.world, first.model, self.player, door_starts_open(lift));
                    if starters and self.take_objective(starters) {
                        print("AUTOPLAY lift", first.model, "is set going elsewhere");
                        return True;
                    }
                    # Nothing left to set it going (a button that stays in, a
                    # trigger spent), or nothing of it within reach: no ride
                    # there; another way.
                    ride_to = bot.route.areas[0] if bot.route.areas else 0;
                    if ride_to > 0 and ride_to != here_now {
                        bot.close_area(ride_to, 0, 120.0);
                        bot.route.abandon();
                        print("AUTOPLAY lift", first.model, "cannot be set going from here: area", ride_to, "closed");
                        return False;
                    }
                }
            }
        }
        busy.extend([held.mover for held in bot.waiting]);
        for (model, area) in movers {
            resting = area in bot.rest_areas;
            # A plat's top is walked onto from beside it only while the plat
            # is up there: down, it is a shaft. Check that transient state
            # only when boarding now: a distant plat can be beyond this
            # route slice's elevator leg and must not disconnect the map.
            plat = objective_mover(self.world, model);
            if plat is not None and plat.kind == "platform" and plat.state != "locked" and not resting
                and area not in lifted_into and area != here_now and area > 0 and area not in mesh.disabled
                and bot.route.areas and bot.route.areas[0] == area
                and plat.position < 0.99 {
                bot.close_area(area, -model);
                bot.route.abandon();
                print("AUTOPLAY plat", model, "is not up: area", area, "closed");
                return False;
            }
            if model in busy {
                # Being seen to further down the stack (not by the objective
                # under way, which may be done from on the mover), and not yet
                # open: no way through it meanwhile. Never the area it is in.
                # Its own mover stays open to it only where it is done from
                # on the mover; else it is not opened by going through it.
                current = bot.objective;
                its_own = current is not None and current.stand > 0
                    and (current.stand == area or area_mover_model(mesh.aas.areas[current.stand].contents) == model);
                if not its_own and area > 0 and area != here_now and area not in mesh.disabled
                    and mover_area_blocked(self.world, model, self.player, resting) {
                    bot.close_area(area, model);
                    bot.route.abandon();
                    print("AUTOPLAY mover", model, "is still shut: area", area, "closed");
                }
                continue;
            }
            # Walked on where it rests: gone once it has moved. A door that
            # starts open is walked on where it closes to (a bridge drawn
            # out), which is work to do while it rests.
            leader = objective_mover(self.world, model) if resting else None;
            if resting and not (leader is not None and door_starts_open(leader)) {
                if leader is not None and leader.position > 0.01 and area not in mesh.disabled {
                    bot.close_area(area, model);
                    bot.route.abandon();
                    print("AUTOPLAY mover", model, "has moved: area", area, "closed");
                    return False;
                }
                continue;
            }
            # What it is already about (or set aside) does not count: a
            # door opened by picking up the key behind it is in the way.
            pending = [bot.objective] if bot.objective is not None else [];
            pending.extend(bot.waiting);
            choices = [
                choice
                for choice in mover_objectives(self.world, model, self.player, resting)
                if not any([held.point.sub(choice.point).length() < 8.0 for held in pending])
            ];
            # Before working to open it: is there another way on without it?
            # A player goes round a door that opens elsewhere when the way
            # round is there, rather than hunting for what opens it.
            if choices and area > 0 and area not in mesh.disabled and self.way_round_mover(model) {
                bot.close_mover(model);
                bot.route.abandon();
                print("AUTOPLAY mover", model, "needs work; going round it");
                bot.trace.event("go_round", bot.clock, {"mover": str(model), "area": str(area)});
                return False;
            }
            if choices and self.take_objective(choices) {
                return True;
            }
            # In the way with nothing to be done about it now: route round it.
            if area > 0 and area not in mesh.disabled and mover_area_blocked(self.world, model, self.player, resting) {
                bot.close_area(area, model);
                bot.route.abandon();
                print("AUTOPLAY mover", model, "is shut: area", area, "closed");
                return False;
            }
        }
        return False;
    }

    """Whether the bot's goal can be reached with the mover `model` closed
    and every other mover that is no way through now closed too: a way on
    round it that needs nothing done first."""
    def way_round_mover(model: int) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None or bot.goal_area <= 0 {
            return False;
        }
        here_area = bot.area_near(self.origin)[0];
        its_areas = bot.mover_areas(model);
        if here_area <= 0 or bot.goal_area in its_areas {
            return False;
        }
        closing = [a for a in its_areas if a != here_area and a not in mesh.disabled];
        closing.extend([a for a in self.shut_areas(here_area) if a != bot.goal_area and a not in its_areas]);
        for a in closing {
            mesh.enable_area(a, False);
        }
        times = mesh.times_to(bot.goal_area, TFL_DEFAULT);
        reachable = here_area < len(times) and times[here_area] < UNREACHED;
        for a in closing {
            mesh.enable_area(a, True);
        }
        return reachable;
    }

    """The BSP models of the mover `model` and every mover set going with
    it (the same targetname; none for 0)."""
    def opened_with(model: int) -> list[int] {
        if model <= 0 {
            return [];
        }
        leader = objective_mover(self.world, model);
        if leader is None {
            return [model];
        }
        found = [model];
        name = leader.activation.name;
        if not name {
            return found;
        }
        for other in [self.world->:HasDoor:->][?:Door] {
            if other.activation.name == name and other.model not in found {
                found.append(other.model);
            }
        }
        return found;
    }

    """Take up the objective, of `choices`, the route reaches soonest and that
    was not given up on lately. Whether one was."""
    def take_objective(choices: list[Objective], within: int = UNREACHED, open_only: bool = False) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        here_area = self.bot.area_near(self.origin)[0];
        # What can be had with every shut door left shut first: supplies
        # only so (not seen through bars), anything else then by a way
        # through doors still to open when there is no other.
        gated = self.shut_areas(here_area);
        for a in gated {
            mesh.enable_area(a, False);
        }
        taken = self.take_best(choices, within, here_area);
        for a in gated {
            mesh.enable_area(a, True);
        }
        if taken or open_only {
            return taken;
        }
        return self.take_best(choices, within, here_area);
    }

    """Every area of a mover that is no way through now (but `keep`), open
    to routing."""
    def shut_areas(keep: int) -> list[int] {
        bot = self.bot;
        mesh = bot.mesh;
        found: list[int] = [];
        if mesh is None {
            return found;
        }
        blocked: dict[tuple[int, bool], bool] = {};
        for a in range(1, len(mesh.aas.areas)) {
            model = area_mover_model(mesh.aas.areas[a].contents);
            if model <= 0 or a == keep or a in mesh.disabled {
                continue;
            }
            key = (model, a in bot.rest_areas);
            if key not in blocked {
                blocked[key] = mover_area_blocked(self.world, model, self.player, key[1]);
            }
            if blocked[key] {
                found.append(a);
            }
        }
        return found;
    }

    """take_objective's choosing, with the routing as it stands."""
    def take_best(choices: list[Objective], within: int, here_area: int) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        # Nowhere to measure from (riding a lift, in the air): chosen once
        # it is somewhere, not by guesswork.
        if mesh is None or here_area <= 0 {
            return False;
        }
        best: Objective | None = None;
        best_time = UNREACHED;
        notes: list[str] = [];
        for choice in choices {
            passed_over = bot.passed_over(choice.point);
            for (quarry, until) in bot.given_up_bodies {
                if until > bot.clock and choice.body is quarry {
                    passed_over = True;
                }
            }
            where = trace_point(choice.point);
            label = "{\"kind\": " + trace_text(choice.kind) + ", \"why\": " + trace_text(choice.why) + ", \"at\": " + where;
            # Only worth having, near where it died on this map: not again.
            if choice.why in AUTO_SUPPLIES and bot.deaths_map == self.level.name {
                for spot in bot.death_spots {
                    if spot.sub(choice.point).length() < 300.0 {
                        passed_over = True;
                    }
                }
            }
            if passed_over {
                notes.append(label + ", \"result\": \"given up lately, or near a death\"}");
                continue;
            }
            cheapest = UNREACHED;
            # Where it is done from: an area within its volume, the soonest
            # reached; else the area at (or by) its point.
            spots: list[tuple[int, Vec3]] = [];
            box = choice.box;
            if box is not None {
                for area in mesh.aas.box_areas(box.mins, box.maxs, 64) {
                    if mesh.aas.areas[area].reach_count == 0 or area in mesh.disabled {
                        continue;
                    }
                    center = mesh.aas.areas[area].center;
                    inside = Vec3(
                        x=max(box.mins.x, min(box.maxs.x, center.x)),
                        y=max(box.mins.y, min(box.maxs.y, center.y)),
                        z=center.z
                    );
                    spots.append((area, inside));
                }
            }
            # A monster to kill, or a switch, a door or a target to shoot
            # (e1m1's planet on its pillar), is shot from where it can be
            # seen (through bars, across a pit), not walked up to.
            prey = choice.body;
            if choice.kind == "kill" and prey is not None {
                spots = self.shooting_spots(prey.pos.sub(Vec3(z=prey.eye_height * 0.5)));
            } elif choice.kind == "shoot" {
                spots = self.shooting_spots(choice.aim);
            }
            # A volume no area reaches into is not done from beside it.
            if not spots and box is None {
                spots.append(self.stand_area(choice.point));
            }
            # Not reached through the mover it is to open (a plate behind
            # the bars it lifts is for the far side).
            # Nor through the others it opens with it (twin bars on one
            # signal).
            through: list[int] = [];
            for model in self.opened_with(choice.mover) {
                shut_open = mover_area_blocked(self.world, model, self.player, False);
                shut_rest = mover_area_blocked(self.world, model, self.player, True);
                through.extend([
                    a
                    for a in bot.mover_areas(model)
                    if a != here_area and a not in mesh.disabled and (shut_rest if a in bot.rest_areas else shut_open)
                ]);
            }
            for a in through {
                mesh.enable_area(a, False);
            }
            for (area, spot) in spots {
                if area == 0 {
                    continue;
                }
                cost = 1;
                if area != here_area and here_area > 0 {
                    times = mesh.times_to(area, TFL_DEFAULT);
                    cost = times[here_area] if here_area < len(times) else UNREACHED;
                }
                cheapest = min(cheapest, cost);
                if cost < best_time and cost <= within {
                    best_time = cost;
                    best = choice;
                    choice.stand = area;
                    choice.stand_point = spot;
                }
            }
            for a in through {
                mesh.enable_area(a, True);
            }
            if not spots {
                notes.append(label + ", \"result\": \"no area reaches it\"}");
            } elif cheapest >= UNREACHED {
                notes.append(label + ", \"result\": \"no route to it\"}");
            } else {
                over = " (over the " + str(within) + " limit)" if cheapest > within else "";
                notes.append(label + ", \"result\": " + trace_text("route " + str(cheapest) + over) + "}");
            }
        }
        if best is None {
            return False;
        }
        bot.trace.event("choose", bot.clock, {
            "chose": trace_text(best.kind + " for " + best.why),
            "at": trace_point(best.point),
            "route": str(best_time),
            "from_area": str(here_area),
            "stack": trace_text(bot.chain()),
            "choices": "[" + ", ".join(notes[0:16]) + "]"
        });
        best.started = bot.clock;
        # As long as the way there should take, twice over, and twenty seconds
        # to do it in.
        best.allowed = float(best_time) * 0.02 + 20.0;
        best.reset_progress(bot.clock);
        signal = best.signal;
        best.fired = signal.fired if signal is not None else 0;
        current = bot.objective;
        if current is not None {
            bot.waiting.append(current);
        }
        bot.objective = best;
        bot.route.abandon();
        print("AUTOPLAY objective", best.kind, "at", int(best.point.x), int(best.point.y), int(best.point.z), "for", best.why);
        return True;
    }

    """Ammunition on the map for the weapons held, within reach: wanted when
    no weapon held has fifteen shots left."""
    def ammo_nearby() -> list[Objective] {
        found: list[Objective] = [];
        wanted: list[str] = [];
        shots = 0;
        for rule in self.state.rules {
            if owns_weapon(self.player, rule) and rule.ammo {
                wanted.append(rule.ammo);
                shots = max(shots, quantity(self.player.inventory, rule.ammo) // max(1, rule.cost));
            }
        }
        # Running low, not only out: a fight empties a shotgun fast.
        if shots >= 15 {
            return found;
        }
        for item in [self.world->:HasPickup:->][?:Pickup] {
            if item.active and (item.rule.kind in wanted or item.rule.ammo in wanted or item.rule.kind == "backpack")
                and item.pos.sub(self.origin).length() < 2000.0 {
                found.append(Objective(kind="pickup", point=item.pos, why="ammo", item=item, box=objective_item_box(item)));
            }
        }
        return found;
    }

    """Supplies as an objective set on top of what it is doing: health first
    when badly hurt, then ammunition when no weapon held has fifteen shots
    left (enemy in sight or not), then, with no enemy in sight, health when
    hurt and anything worth a short way round. Whether one was taken."""
    def resupply() -> bool {
        # Badly hurt, health first, enemy or not: one more hit on the way to
        # ammunition is the end.
        if self.player.health < 40 and self.take_objective(self.health_nearby(), 1500, True) {
            return True;
        }
        # Short of ammunition it goes for some even with an enemy in sight:
        # standing to fight with the axe loses.
        if self.take_objective(self.ammo_nearby(), 1500, True) {
            return True;
        }
        if self.bot.enemy is not None {
            return False;
        }
        # Before pressing or touching what opens the way (it may let monsters
        # out), it tops up sooner.
        current = self.bot.objective;
        wary = current is not None and current.kind in ["press", "touch", "shoot"];
        if self.player.health < (75 if wary else 60) and self.take_objective(self.health_nearby(), 1500, True) {
            return True;
        }
        # Something worth a short way round, but not on top of an objective
        # (a key, a button): those come first.
        if self.bot.objective is not None {
            return False;
        }
        return self.take_objective(self.on_the_way(), 300, True);
    }

    """Whether it holds a weapon with ammunition (beyond the axe and the
    blaster, which need none)."""
    def armed() -> bool {
        for rule in self.state.rules {
            if rule.ammo and owns_weapon(self.player, rule) and has_ammo_for(self.player, rule) {
                return True;
            }
        }
        return False;
    }

    """Items worth a short way off the route: a weapon it lacks, ammunition
    when short, armor or health when hurt (worth at least 50, within 500
    units)."""
    def on_the_way() -> list[Objective] {
        found: list[Objective] = [];
        for item in [self.world->:HasPickup:->][?:Pickup] {
            if not item.active or item.untouchable or item.pos.sub(self.origin).length() > 500.0 {
                continue;
            }
            if self.item_worth(item) >= 50.0 {
                found.append(Objective(kind="pickup", point=item.pos, why="supply", item=item, box=objective_item_box(item)));
            }
        }
        return found;
    }

    """Health on the map within about fifteen seconds' travel."""
    def health_nearby() -> list[Objective] {
        found: list[Objective] = [];
        for item in [self.world->:HasPickup:->][?:Pickup] {
            if item.active and item.rule.kind == "health" and item.pos.sub(self.origin).length() < 1500.0 {
                found.append(Objective(kind="pickup", point=item.pos, why="health", item=item, box=objective_item_box(item)));
            }
        }
        return found;
    }

    can seek_exit with SeekExit entry {
        bot = self.bot;
        enemy = self.spot_enemy();
        bot.enemy = enemy;
        if bot.exit_goal is None {
            self.choose_exit();
        }
        if bot.exit_goal is None and bot.objective is None {
            # No exit to walk into (Quake II's target_changelevel): what
            # fires one, found the way a door's opener is.
            chained: list[Objective] = [];
            for portal in [self.world->:HasExit:->][?:LevelExit] {
                chained.extend(exit_objectives(self.world, portal));
            }
            if self.take_objective(chained) {
                visit self.shift(here, "activate");
                return;
            }
        }
        if bot.exit_goal is None {
            visit self.shift(here, "roam");
            return;
        }
        bot.goal = bot.exit_goal;
        bot.goal_area = bot.exit_area;
        bot.goal_name = bot.exit_name;
        if self.check_movers() {
            visit self.shift(here, "activate");
            return;
        }
        if enemy is None and self.resupply() {
            visit self.shift(here, "activate");
            return;
        }
        if enemy is not None {
            visit self.shift(here, "engage");
        } elif bot.stuck_count > 0 {
            visit self.shift(here, "unstick");
        }
    }

    """Keep count of the fight with `enemy`: it is getting somewhere while
    the enemy is hurt or the bot gets nearer it. One that has got nowhere
    for a while (out of reach of all it holds, or shot at to no effect) is
    given up for a time, and None is answered: the bot goes on its way."""
    def keep_fight(enemy: Opponent | None) -> Opponent | None {
        bot = self.bot;
        if enemy is None {
            bot.fight_with = None;
            return None;
        }
        distance = enemy.pos.sub(self.player.pos).length();
        if enemy is not bot.fight_with {
            bot.fight_with = enemy;
            bot.fight_health = enemy.health;
            bot.fight_nearest = distance;
            bot.fight_moved_at = bot.clock;
            return enemy;
        }
        # A hurt is counted think by think, so a zombie whose health comes
        # back after each pain is still seen being hit.
        if enemy.health < bot.fight_health or distance < bot.fight_nearest - 32.0 {
            bot.fight_moved_at = bot.clock;
            bot.fight_nearest = min(bot.fight_nearest, distance);
        }
        bot.fight_health = enemy.health;
        if bot.clock - bot.fight_moved_at < AUTO_FIGHT_STALL {
            return enemy;
        }
        print("AUTOPLAY fight given up:", enemy.rule.model, "no harm done and no nearer for", int(bot.clock - bot.fight_moved_at), "s");
        bot.trace.event("fight_given_up", bot.clock, {"enemy": trace_text(enemy.rule.model), "distance": trace_number(distance)});
        bot.given_up_bodies.append((enemy, bot.clock + AUTO_PASS_OTHER));
        bot.fight_with = None;
        return None;
    }

    can engage with Engage entry {
        bot = self.bot;
        enemy = self.keep_fight(self.spot_enemy());
        bot.enemy = enemy;
        if enemy is None {
            visit self.shift(here, "seek_exit");
            return;
        }
        # Nothing to shoot with: get some rather than stand and fight.
        if not self.armed() and self.resupply() {
            visit self.shift(here, "activate");
        }
    }

    can activate with Activate entry {
        bot = self.bot;
        objective = bot.objective;
        # Given up only when it stops getting nearer for a while (or after a
        # long time all told), not while it is on its way.
        if objective is not None {
            gap = objective.stand_point.sub(self.origin).length() if objective.stand > 0 else objective.point.sub(self.origin).length();
            area = bot.area_near(self.origin)[0];
            mesh = bot.mesh;
            travel = 0;
            if mesh is not None {
                goal = objective.stand if objective.stand > 0 else mesh.locate(objective.point);
                travel = area_travel_time(mesh, area, self.origin, goal);
            }
            objective.note_progress(gap, area, travel, bot.clock);
        }
        finished = objective is not None and objective.done(self.player);
        stalled = objective is not None and bot.clock - objective.nearer_at > max(25.0, objective.allowed * 0.5);
        overdue = objective is not None and bot.clock - objective.started > max(180.0, objective.allowed * 3.0);
        if objective is None or finished or stalled or overdue {
            if objective is not None {
                why_end = "done" if finished else (
                    "no nearer for " + str(int(bot.clock - objective.nearer_at)) + " s (nearest " + str(int(objective.nearest)) + ")"
                    if stalled
                    else "over its time (" + str(int(bot.clock - objective.started)) + " s)"
                );
                bot.trace.event("objective_end", bot.clock, {
                    "objective": trace_text(objective.kind + " for " + objective.why),
                    "result": trace_text(why_end),
                    "seconds": trace_number(bot.clock - objective.started)
                });
                if not finished {
                    bot.trace.dump("gave up " + objective.kind + " for " + objective.why, bot.clock);
                }
            }
            if objective is not None and finished {
                print("AUTOPLAY objective done:", objective.kind, "for", objective.why);
            } elif objective is not None {
                print("AUTOPLAY objective given up:", objective.kind, "for", objective.why);
                # Supplies are passed over for longer: there are others.
                spare = objective.why in AUTO_SUPPLIES;
                bot.given_up.append((objective.point, bot.clock + (AUTO_PASS_SUPPLY if spare else AUTO_PASS_OTHER)));
                quarry = objective.body;
                if objective.kind == "kill" and quarry is not None {
                    bot.given_up_bodies.append((quarry, bot.clock + AUTO_PASS_OTHER));
                }
            }
            # Back to what it set aside, or on to the exit.
            bot.objective = bot.waiting.pop() if bot.waiting else None;
            resumed = bot.objective;
            if resumed is not None {
                resumed.started = bot.clock;
                # Set aside is not stuck: its progress is counted afresh.
                resumed.reset_progress(bot.clock);
            }
            bot.route.abandon();
            if resumed is None {
                visit self.shift(here, "seek_exit");
            }
            return;
        }
        # A mover in the way of this objective comes first, then supplies.
        if self.check_movers() {
            return;
        }
        if objective.why not in AUTO_SUPPLIES and self.resupply() {
            return;
        }
        if objective.kind == "kill" {
            bot.enemy = objective.body;
        } else {
            enemy = self.keep_fight(self.spot_enemy());
            bot.enemy = enemy;
        }
        # A button is walked into (its middle); a trigger stood in, at the
        # point chosen inside it; anything else gone to.
        target = objective.stand_point if objective.kind == "touch" and objective.stand > 0 else objective.point;
        if bot.goal is None or bot.goal.sub(target).length() > 1.0 {
            bot.route.abandon();
        }
        bot.goal = target;
        bot.goal_area = objective.stand if objective.stand > 0 else self.stand_area(objective.point)[0];
        bot.goal_name = objective.kind + " for " + objective.why;
    }

    """What an item is worth to the bot now, from what it gives: a weapon it
    lacks, ammunition for one it holds, health and armor by how far short
    it is, powerups always. 0 when nothing."""
    def item_worth(item: Pickup) -> float {
        rule = item.rule;
        player = self.player;
        if rule.kind.startswith("weapon_") {
            for weapon in self.state.rules {
                if "weapon_" + weapon.key == rule.kind {
                    return 30.0 if owns_weapon(player, weapon) else 100.0;
                }
            }
            return 0.0;
        }
        if rule.kind == "health" {
            return max(0.0, float(100 - player.health)) * (2.0 if rule.max_health_bonus > 0 else 1.0);
        }
        if rule.kind == "armor" {
            return max(0.0, float(150 - player.armor)) * 0.4;
        }
        if rule.kind in ["powerup", "backpack"] {
            return 60.0;
        }
        for weapon in self.state.rules {
            if weapon.ammo == rule.kind and owns_weapon(player, weapon) {
                held = quantity(player.inventory, weapon.ammo);
                return 25.0 if held < max(1, weapon.capacity) // 2 else 5.0;
            }
        }
        return 0.0;
    }

    """Where to roam: the item worth the most for the time it takes to get
    there, else the nearest place not stood in yet that the route reaches."""
    def roam_goal() -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        here_area = self.bot.area_near(self.origin)[0];
        if here_area == 0 {
            return False;
        }
        best: Vec3 | None = None;
        best_area = 0;
        best_score = 0.0;
        best_name = "";
        for item in [self.world->:HasPickup:->][?:Pickup] {
            if not item.active or item.untouchable {
                continue;
            }
            worth = self.item_worth(item);
            if worth <= 0.0 {
                continue;
            }
            if bot.passed_over(item.pos) {
                continue;
            }
            # Only where the player's box can touch it: an area reaching into
            # its pickup box (not the floor under one on a ledge).
            area = 0;
            reach_box = objective_item_box(item);
            for candidate in mesh.aas.box_areas(reach_box.mins, reach_box.maxs, 16) {
                if mesh.aas.areas[candidate].reach_count > 0 and candidate not in mesh.disabled {
                    area = candidate;
                    break;
                }
            }
            if area == 0 {
                continue;
            }
            times = mesh.times_to(area, TFL_DEFAULT);
            cost = times[here_area] if here_area < len(times) else UNREACHED;
            if cost >= UNREACHED {
                continue;
            }
            score = worth / (float(cost) * 0.01 + 1.0);
            if score > best_score {
                best_score = score;
                best = item.pos;
                best_area = area;
                best_name = "item " + item.rule.kind;
            }
        }
        if best is None {
            # Explore: the nearest unvisited area among a few close ones.
            nearest: list[tuple[float, int]] = [];
            for area in range(1, len(mesh.aas.areas)) {
                if area in bot.visited or mesh.aas.areas[area].reach_count == 0 {
                    continue;
                }
                nearest.append((mesh.aas.areas[area].center.sub(self.origin).length(), area));
            }
            nearest = sorted(nearest)[0:12];
            for (distance, area) in nearest {
                times = mesh.times_to(area, TFL_DEFAULT);
                if here_area < len(times) and times[here_area] < UNREACHED {
                    best = mesh.aas.areas[area].center;
                    best_area = area;
                    best_name = "explore";
                    break;
                }
            }
        }
        if best is None {
            return False;
        }
        # Chosen again, the same goal keeps its count of how long it has got
        # no nearer: else one it cannot reach is never given up.
        previous = bot.goal;
        same = previous is not None and previous.sub(best).length() < 1.0;
        bot.goal = best;
        bot.goal_area = best_area;
        bot.goal_name = best_name;
        bot.roam_chosen = bot.clock;
        if not same {
            bot.route.abandon();
            bot.roam_nearest = 1.0e9;
            bot.roam_nearer_at = bot.clock;
        }
        return True;
    }

    can roam with Roam entry {
        bot = self.bot;
        enemy = self.spot_enemy();
        bot.enemy = enemy;
        if enemy is not None {
            visit self.shift(here, "engage");
            return;
        }
        if self.resupply() {
            visit self.shift(here, "activate");
            return;
        }
        # A door in the way that something else opens: that first, or a way
        # round it, rather than walking into it again and again.
        if self.check_movers() {
            visit self.shift(here, "activate");
            return;
        }
        # A way out may have come to be (an exit's chain fired).
        if bot.clock - bot.roam_chosen > 8.0 or bot.goal is None or bot.goal_area == 0 {
            self.choose_exit();
            if bot.exit_goal is not None {
                visit self.shift(here, "seek_exit");
                return;
            }
            self.roam_goal();
        }
        mesh = bot.mesh;
        goal = bot.goal;
        if goal is not None {
            # Not getting nearer for fifteen seconds: set it aside and choose
            # again (an item it cannot after all reach).
            gap = goal.sub(self.origin).length();
            if gap < bot.roam_nearest - 32.0 {
                bot.roam_nearest = gap;
                bot.roam_nearer_at = bot.clock;
            } elif bot.clock - bot.roam_nearer_at > 15.0 {
                bot.given_up.append((goal, bot.clock + AUTO_PASS_SUPPLY));
                bot.trace.event("roam_given_up", bot.clock, {"goal": trace_text(bot.goal_name), "nearest": str(int(bot.roam_nearest))});
                print("AUTOPLAY roam given up:", bot.goal_name);
                self.roam_goal();
                return;
            }
        }
        if mesh is not None and bot.goal is not None and self.bot.area_near(self.origin)[0] == bot.goal_area {
            # Arrived: choose again.
            self.roam_goal();
        }
    }

    can unstick with Unstick entry {
        bot = self.bot;
        # Forget the route and the passages that failed it for a while.
        bot.route.abandon();
        bot.replan_wait = 0.0;
        bot.stuck_count = 0;
        visit self.shift(here, "seek_exit");
    }
}

impl PlayerBot.drive(world: World, level: Level, player: Player, state: CombatState, dt: float) -> Intent {
    self.clock += dt;
    self.frames += 1;
    if level is not self.level {
        self.begin_level(world, level);
    }
    eye_height = level.collision.eye_height;
    origin = player.pos.sub(Vec3(z=eye_height));
    if player.health < self.last_health {
        self.hurt_at = self.clock;
    }
    self.last_health = player.health;
    if player.health <= 0 and not self.dead_seen {
        self.dead_seen = True;
        if self.deaths_map != level.name {
            self.deaths_map = level.name;
            self.death_spots = [];
        }
        self.death_spots.append(origin);
        killer = player.killer;
        slayer = "";
        if killer is not None and isinstance(killer, Opponent) {
            slayer = killer.rule.model.split("/")[-1];
        }
        self.trace.event("death", self.clock, {
            "map": trace_text(level.name),
            "means": trace_text(player.death_means),
            "killer": trace_text(slayer),
            "at": trace_point(origin),
            "water": str(player.water_depth),
            "stack": trace_text(self.chain()),
            "goal": trace_text(self.goal_name)
        });
        self.trace.dump("death", self.clock);
        print("AUTOPLAY died:", player.death_means, slayer);
    }
    if player.health > 0 {
        self.dead_seen = False;
    }
    if player.health <= 0 {
        # Fire brings the dead back (respawn, or the level restarted).
        self.route.abandon();
        self.goal = None;
        self.objective = None;
        self.waiting = [];
        self.log_wait -= dt;
        if self.log_wait <= 0.0 {
            self.log_wait = 2.0;
            print("AUTOPLAY", level.name, "t", round(self.clock, 1), "dead, health", player.health);
        }
        return Intent(fire=self.frames % 30 == 0);
    }
    self.think_wait -= dt;
    if self.think_wait <= 0.0 {
        self.think_wait += AUTO_THINK;
        if self.mesh is not None {
            standing = self.area_near(origin)[0];
            if standing > 0 {
                self.visited.add(standing);
            }
        }
        self.reopen_areas(world, player);
        self.mind spawn AutoThink(
            bot=self, world=world, level=level, player=player, state=state, origin=origin, eye_height=eye_height
        );
    }
    mesh = self.mesh;
    goal = self.goal;
    intent = Intent();
    if mesh is not None {
        mesh.advance_tables();
    }
    if mesh is not None and goal is not None {
        self.replan_wait -= dt;
        if not self.route.points and self.replan_wait <= 0.0 {
            # From the area it is effectively in (beside a wall, the one by it).
            anchor = self.area_near(origin)[1];
            planned = plan_route(
                mesh, anchor, goal, limit=64, flags=TFL_DEFAULT, goal_area=self.goal_area, avoid=self.avoid, now=self.clock
            );
            self.replan_wait = 0.05 if planned.pending else (0.3 if planned.found else 1.0);
            if planned.found {
                self.route = planned;
                self.lost_since = -1.0;
                kinds = [str(passage.kind) for passage in planned.passages if passage is not None];
                movers = [
                    str(a) + ":" + str(area_mover_model(mesh.aas.areas[a].contents)) + ("r" if a in self.rest_areas else "")
                    for a in planned.areas
                    if a > 0 and a < len(mesh.aas.areas) and area_mover_model(mesh.aas.areas[a].contents) > 0
                ];
                self.trace.event("route", self.clock, {
                    "goal": trace_text(self.goal_name),
                    "from_area": str(self.area_near(origin)[0]),
                    "to_area": str(self.goal_area),
                    "legs": str(len(planned.points)),
                    "kinds": trace_text(" ".join(kinds[0:24])),
                    "movers": trace_text(" ".join(movers))
                });
            } elif not planned.pending and self.lost_since < 0.0 {
                self.lost_since = self.clock;
                here = self.area_near(origin)[0];
                reason = "standing in no area" if here == 0 else (
                    "goal in no area" if self.goal_area == 0 else (
                        "goal area closed" if self.goal_area in mesh.disabled
                        else "no way between them (" + str(len(mesh.disabled)) + " areas closed)"
                    )
                );
                print("AUTOPLAY no route from area", here, "to area", self.goal_area, "for", self.goal_name, ":", reason);
                self.trace.event("no_route", self.clock, {
                    "goal": trace_text(self.goal_name),
                    "from_area": str(here),
                    "to_area": str(self.goal_area),
                    "reason": trace_text(reason)
                });
            }
        }
        lost = self.lost_since >= 0.0 and self.clock - self.lost_since > 2.0;
        if not self.route.points and lost {
            # No way on from this area (fallen into a pit, a pool): make for
            # the nearest area near by that has one.
            way_on = self.way_on(origin);
            if way_on is not None {
                heading3 = way_on.sub(origin);
                heading = Vec3(x=heading3.x, y=heading3.y);
                if heading.length() > 0.001 {
                    heading = heading.normalized();
                    intent.move = autoplay_move(player.yaw, heading);
                    if player.water_depth >= 2 {
                        intent.move.z = 1.0 if heading3.z > 0.0 else -1.0;
                    }
                    self.travel = TravelResult(direction=heading, speed=400.0);
                    intent.jump = player.water_depth < 2 and self.blocked_time > 0.5;
                }
            }
        } elif not self.route.points and self.area_near(origin)[0] == 0 {
            # In no area: walk (jumping when stuck) to the nearest that is.
            way_out = self.nearest_area_point(origin);
            if way_out is not None {
                heading = Vec3(x=way_out.x - origin.x, y=way_out.y - origin.y);
                if heading.length() > 0.001 {
                    heading = heading.normalized();
                    intent.move = autoplay_move(player.yaw, heading);
                    self.travel = TravelResult(direction=heading, speed=400.0);
                    intent.jump = self.blocked_time > 0.5;
                }
            }
        }
        leaping = self.leap_over(level, player, origin) if self.route.points else None;
        if leaping is not None {
            intent = leaping;
        } elif self.route.points and player.grounded and mesh.locate(origin) == 0 {
            # Out of every area by a wall: the Q3 travel would call this in
            # solid and stop; head straight for the next waypoint instead,
            # back into the areas.
            ahead = self.route.points[0].sub(origin);
            flat = Vec3(x=ahead.x, y=ahead.y);
            if flat.length() < 16.0 {
                self.route.advance(self.clock);
            } else {
                flat = flat.normalized();
                intent.move = autoplay_move(player.yaw, flat);
                self.travel = TravelResult(direction=flat, speed=400.0);
            }
        } elif self.route.points {
            travel = player spawn FollowRoute(
                mesh=mesh,
                collision=level.collision,
                route=self.route,
                eye_height=eye_height,
                clock=self.clock,
                view_yaw=math.degrees(player.yaw) % 360.0,
                view_pitch=-math.degrees(player.pitch),
                dt=dt,
                avoid=self.avoid,
                ducked=player.crouched
            );
            self.travel = travel.result;
            heading = travel.result.direction;
            # Waiting for a lift that does not come (held up, or turned back
            # by something under it): after ten seconds that ride is given
            # up for a minute and another way found.
            # (Not while the lift is on its way: that is the ride.)
            if travel.result.waiting and self.rising_under(world, level, origin) is None {
                if self.waiting_since < 0.0 {
                    self.waiting_since = self.clock;
                } elif self.clock - self.waiting_since > 10.0 and self.route.areas {
                    ride_to = self.route.areas[0];
                    self.waiting_since = -1.0;
                    if ride_to > 0 {
                        self.close_area(ride_to, 0, 60.0);
                        self.route.abandon();
                        print("AUTOPLAY lift does not come: area", ride_to, "closed");
                    }
                }
            } else {
                self.waiting_since = -1.0;
            }
            share = travel.result.speed_scale();
            if travel.launch is not None {
                # The jump the route wants from here: off at a run.
                launch = travel.launch;
                heading = Vec3(x=launch.x, y=launch.y);
                share = 1.0;
                intent.jump = True;
            }
            if travel.result.jump {
                intent.jump = True;
            }
            intent.crouch = travel.result.crouch;
            if self.clock < self.detour_until {
                heading = self.detour;
                share = 1.0;
            }
            flat = Vec3(x=heading.x, y=heading.y);
            if flat.length() > 0.001 and share > 0.0 {
                flat = flat.normalized();
                intent.move = autoplay_move(player.yaw, flat, share);
                if player.water_depth >= 2 {
                    intent.move.z = heading.normalized().z * share;
                }
                # In water at all, a waypoint well below or above is swum to
                # straight down or up: floating at the surface it was never
                # dived for.
                if player.water_depth >= 1 and self.route.points {
                    rise = self.route.points[0].z - origin.z;
                    if rise < -24.0 {
                        intent.move.z = -1.0;
                    } elif rise > 24.0 and player.water_depth >= 2 {
                        intent.move.z = 1.0;
                    }
                }
            }
        }
    }
    # On a lift still going up or down: held still on it until it stops.
    # Stepping off part way (the route has it at the top once it is near)
    # drops it back down the shaft. Not for long: a mover held up by
    # something goes back and forth.
    riding = self.rising_under(world, level, origin) if player.grounded else None;
    if riding is not None and self.ride_held < 6.0 {
        self.ride_held += dt;
        # To its middle meanwhile: near an edge the shaft's lip catches the
        # body and turns the lift back.
        centre = riding.bounds.center().add(riding.rest).add(riding.travel.scale(riding.position));
        to_centre = Vec3(x=centre.x - origin.x, y=centre.y - origin.y);
        intent.move = Vec3();
        if to_centre.length() > 12.0 {
            way = to_centre.normalized();
            share = min(1.0, to_centre.length() / 64.0);
            intent.move = autoplay_move(player.yaw, way, share);
        }
        intent.jump = False;
    } elif player.grounded {
        self.ride_held = 0.0;
    }
    # In a fight with an enemy near, stand and sidestep rather than run on:
    # back and forth across its line, turning about at walls and ledges.
    foe = self.enemy;
    if foe is not None and foe.health > 0 {
        toward = foe.pos.sub(player.pos);
        flat_toward = Vec3(x=toward.x, y=toward.y);
        reach = flat_toward.length();
        # Fighting, it stands its ground; on its way, only an enemy close by
        # stops it (one it is fleeing for ammunition does not, unless it is
        # within arm's reach).
        fighting = self.mind.current == "engage" or reach < 120.0 or (reach < 350.0 and self.objective_why() != "ammo");
        if fighting and reach < 700.0 and reach > 1.0 {
            ahead = flat_toward.scale(1.0 / reach);
            side = Vec3(x=-ahead.y, y=ahead.x).scale(self.strafe);
            self.strafe_wait -= dt;
            sweep = level.collision.trace(origin, origin.add(side.scale(40.0)));
            gap = gap_distance(level.collision, origin, side);
            if self.strafe_wait <= 0.0 or sweep.fraction < 1.0 or (gap > 0.0 and gap < 64.0) {
                self.strafe = -self.strafe;
                self.strafe_wait = 0.8 + float(self.frames % 7) * 0.1;
                side = side.scale(-1.0);
            }
            wish = side;
            # Out of reach of claws, chainsaws and swords: back off to about
            # two hundred units, or as far as its weapon needs (a grenade
            # launcher against a zombie), unless a ledge is behind.
            standoff = max(220.0, autoplay_standoff(player, state, foe) + 20.0);
            wet = player.water_depth >= 2;
            needed = autoplay_needed(foe);
            # Holding nothing that hurts it from farther than arm's length (an
            # axe, a gauntlet): in to swing, not off out of its own reach.
            if autoplay_can_hurt(player, state, foe, 64.0) and not autoplay_can_hurt(player, state, foe, 220.0) {
                standoff = 40.0;
            }
            # Knocking a zombie down rather than blowing it apart: near
            # enough to hit, not off at the grenade launcher's distance.
            if autoplay_knock(foe) > 0 and autoplay_weapon(player, state, reach, wet, needed) <= 0 {
                standoff = 220.0;
                needed = autoplay_knock(foe);
            }
            # Out of reach of all it holds: in closer, still sidestepping.
            if reach > standoff and autoplay_weapon(player, state, reach, wet, needed) <= 0 {
                wish = ahead.scale(0.9).add(side.scale(0.45));
            }
            # Backing off (too close, or badly hurt with it near): the way
            # away from it with the most room and no drop, still firing.
            if reach < standoff or (player.health < 35 and reach < 400.0) {
                away = autoplay_retreat(level, origin, ahead);
                if away is not None {
                    wish = away;
                }
            }
            wish = Vec3(x=wish.x, y=wish.y).normalized();
            intent.move = autoplay_move(player.yaw, wish);
            intent.jump = False;
        }
    }
    # In the path of a train that pins what it meets: out of it, first.
    escape = self.train_way_out(world, level, origin);
    if escape is not None {
        if not self.escaping {
            self.escaping = True;
            # Routes keep out of what it sweeps for a few seconds, or the
            # way on pulls the bot straight back in.
            mesh = self.mesh;
            if mesh is not None {
                here_now = self.area_near(origin)[0];
                for a in mesh.aas.box_areas(self.swept.mins, self.swept.maxs, 256) {
                    if a != here_now and a not in mesh.disabled {
                        self.close_area(a, 0, 4.0);
                    }
                }
                self.route.abandon();
            }
            print("AUTOPLAY out of a train's way");
            self.trace.event("train_escape", self.clock, {"at": trace_point(origin)});
        }
        intent.move = autoplay_move(player.yaw, escape);
        intent.jump = False;
    } else {
        self.escaping = False;
    }
    # The view: on the enemy when there is one, else where the travel looks
    # or along the way.
    want_yaw = player.yaw;
    want_pitch = 0.0;
    enemy = self.enemy;
    objective = self.objective;
    shoot_at: Vec3 | None = None;
    self.fired = False;
    if objective is not None and objective.kind == "shoot" {
        line = level.collision.trace_point(player.pos, objective.aim);
        if line.fraction > 0.97 or objective.aim.sub(line.end).length() < 24.0 {
            shoot_at = objective.aim;
        }
    }
    if shoot_at is not None and (enemy is None or enemy.health <= 0) {
        aim = shoot_at.sub(player.pos);
        want_yaw = math.atan2(aim.y, aim.x);
        want_pitch = math.atan2(aim.z, math.sqrt(aim.x * aim.x + aim.y * aim.y));
        intent.fire = abs(autoplay_turn(player.yaw, want_yaw)) < 0.06 and abs(want_pitch - player.pitch) < 0.08;
        self.fired = intent.fire;
    } elif enemy is not None and enemy.health > 0 {
        target = enemy.pos.sub(Vec3(z=enemy.eye_height * 0.5));
        aim = target.sub(player.pos);
        want_yaw = math.atan2(aim.y, aim.x);
        want_pitch = math.atan2(aim.z, math.sqrt(aim.x * aim.x + aim.y * aim.y));
        distance = aim.length();
        slot = autoplay_weapon(player, state, distance, player.water_depth >= 2, autoplay_needed(enemy));
        # Nothing to put it down for good from here: knocked down instead.
        if slot <= 0 and autoplay_knock(enemy) > 0 {
            slot = autoplay_weapon(player, state, distance, player.water_depth >= 2, autoplay_knock(enemy));
        }
        if slot > 0 and slot != state.weapon {
            intent.weapon = slot;
        }
        yaw_gap = abs(autoplay_turn(player.yaw, want_yaw));
        pitch_gap = abs(want_pitch - player.pitch);
        # Only with a weapon that reaches it, and only once that is the one
        # in hand: an axe or a gauntlet swung from across a room hits
        # nothing, while the gun asked for is still being taken up.
        held = weapon_rule(state, state.weapon);
        in_hand = held is not None and held.reach >= distance;
        intent.fire = slot > 0 and in_hand and yaw_gap < 0.12 and pitch_gap < 0.15;
        self.fired = intent.fire;
    } elif self.travel.view_set {
        want_yaw = math.radians(self.travel.yaw);
        want_pitch = -math.radians(self.travel.pitch);
    } else {
        # Where it is headed, not where its feet go this moment: the farthest
        # waypoint ahead still in sight, up to a couple of hundred units off
        # (the feet still take every waypoint).
        heading = self.travel.direction;
        look = self.look_ahead(level, player.pos, origin);
        if look is not None {
            heading = look;
        }
        if Vec3(x=heading.x, y=heading.y).length() > 0.1 {
            aim_yaw = math.atan2(heading.y, heading.x);
            # Small changes are let be.
            if abs(autoplay_turn(self.view_yaw, aim_yaw)) > 0.25 or self.view_yaw > 99.0 {
                self.view_yaw = aim_yaw;
            }
            want_yaw = self.view_yaw;
        }
    }
    calm = (enemy is None or enemy.health <= 0) and shoot_at is None and not self.travel.view_set;
    limit = (AUTO_TURN * 0.35 if calm else AUTO_TURN) * max(dt, 0.001);
    intent.look_yaw = max(-limit, min(limit, autoplay_turn(player.yaw, want_yaw)));
    intent.look_pitch = max(-limit, min(limit, want_pitch - player.pitch));
    # A turned view leaves the move pointing where the body faced: keep the
    # heading in the world, measured against the view after the turn.
    if intent.move.length() > 0.0 and abs(intent.look_yaw) > 0.0 {
        turned = player.yaw + intent.look_yaw;
        world_move = forward_from(player.yaw, 0.0).scale(intent.move.y).add(right_from(player.yaw).scale(intent.move.x));
        intent.move = Vec3(
            x=world_move.dot(right_from(turned)), y=world_move.dot(forward_from(turned, 0.0)), z=intent.move.z
        );
    }
    # Grenades and rockets: out of the way of one that will burst near
    # (Q3's BotCheckForGrenades keeps clear of each live grenade).
    # Once chosen, a way out is kept for half a second: choosing afresh each
    # frame turned it back and forth in place.
    dodge: Vec3 | None = None;
    if self.clock < self.dodge_until {
        dodge = self.dodge_way;
    } else {
        dodge = self.dodge(world, origin);
        if dodge is not None {
            self.dodge_way = dodge;
            self.dodge_until = self.clock + 0.5;
        }
    }
    if dodge is not None {
        intent.move = autoplay_move(player.yaw, dodge, 1.0, intent.move.z);
        self.travel = TravelResult(direction=dodge, speed=400.0);
    }
    # The last step of an objective: a button is pressed and an item taken
    # by touching it, which the route's end (an area's middle, a waypoint
    # "reached" a few units off) may leave short of. Close to it with the
    # route done, walk straight into it.
    task = self.objective;
    if task is not None and task.kind in ["press", "pickup", "touch"] and len(self.route.points) <= 1 {
        target = task.stand_point if task.kind == "touch" and task.stand > 0 else task.point;
        closing = Vec3(x=target.x - origin.x, y=target.y - origin.y);
        if closing.length() < 160.0 and closing.length() > 2.0 and abs(target.z - origin.z) < 96.0 {
            closing = closing.normalized();
            intent.move = autoplay_move(player.yaw, closing, 1.0, intent.move.z);
            self.travel = TravelResult(direction=closing, speed=400.0);
        }
    }
    # Out of breath under water (Quake's twelve seconds of air): up for air
    # before going on, whatever the route says.
    if player.water_depth >= 3 and player.air_remaining < 5.0 {
        intent.move = Vec3(x=intent.move.x * 0.3, y=intent.move.y * 0.3, z=1.0);
        intent.jump = True;
    }
    self.check_blocked(level, player, origin, intent, dt);
    if self.trace.on() {
        foe = self.enemy;
        passage = self.route.passages[0] if self.route.passages else None;
        self.trace.sample(self.clock, dt, "{\"t\": " + trace_number(self.clock) + ", \"at\": [" + str(int(origin.x)) + ", "
            + str(int(origin.y)) + ", " + str(int(origin.z)) + "], \"vel\": [" + str(int(player.velocity.x)) + ", "
            + str(int(player.velocity.y)) + ", " + str(int(player.velocity.z)) + "], \"move\": [" + trace_number(intent.move.x)
            + ", " + trace_number(intent.move.y) + ", " + trace_number(intent.move.z) + "], \"jump\": "
            + ("true" if intent.jump else "false") + ", \"fire\": " + ("true" if intent.fire else "false") + ", \"hp\": "
            + str(player.health) + ", \"area\": " + str(self.area_near(origin)[0]) + ", \"mode\": "
            + trace_text(self.mind.current) + ", \"leg\": " + str(passage.kind if passage is not None else 0)
            + ", \"waiting\": " + ("true" if self.travel.waiting else "false") + ", \"enemy\": "
            + (str(int(foe.pos.sub(player.pos).length())) if foe is not None and foe.health > 0 else "null")
            + ", \"water\": " + str(player.water_depth) + "}");
    }
    self.log_wait -= dt;
    if self.log_wait <= 0.0 {
        self.log_wait = 2.0;
        print(
            "AUTOPLAY", level.name, "t", round(self.clock, 1), "at", int(origin.x), int(origin.y), int(origin.z), "hp",
            player.health, "mode", self.mind.current, "goal", self.goal_name, "legs", len(self.route.points),
            "objective", self.chain(),
            "enemy", (enemy.rule.model.split("/")[-1] + " " + str(int(enemy.pos.sub(player.pos).length())) + " hp " + str(enemy.health)) if enemy is not None else "no",
            "fire", self.fired, "weapon", state.weapon, "next", self.next_leg()
        );
    }
    return intent;
}
