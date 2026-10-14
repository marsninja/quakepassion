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
import from .bot_routes { NavMesh, HasNavMesh, BotRoute, AvoidReach, plan_route, build_navmesh, UNREACHED }
import from .bot_travel { FollowRoute, TravelResult, yaw_of, gap_distance }
import from .pickups { Pickup, HasPickup }
import from .inventory { quantity }
import from .bot_trace { BotTrace, trace_text, trace_number }
import from .combat { Opponent, HasOpponent, CombatState, owns_weapon, has_ammo_for, selected_weapon, Projectile, HasProjectile }
import from .weapons { WeaponRule }
import from .exits { LevelExit, HasExit }
import from .objectives { Objective, mover_objectives, exit_objectives, objective_mover, mover_blocked, objective_item_box }
import from .bot_routes { predict_mover }
import from ..nav.compile { compile_navigation }
import from ..formats.aas { TFL_DEFAULT, TRAVEL_JUMP, area_mover_model }
import from ..input.input { Intent }
import from ..math.vec3 { Vec3, forward_from, right_from }

glob AUTO_THINK: float = 0.1,
    # How fast the bot turns its view, radians a second.
    AUTO_TURN: float = 9.0,
    # How far it looks for enemies.
    AUTO_SIGHT: float = 2048.0;

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
        # What it is doing to get by a mover, and what it gave up on (by
        # where it was, until when).
        objective: Objective | None = None,
        # Objectives set aside for one in their way, the latest last.
        waiting: list[Objective] = [],
        given_up: list[tuple[Vec3, float]] = [],
        exit_goal: Vec3 | None = None,
        # The areas it has stood in, and when it last chose where to roam.
        visited: set[int] = set(),
        roam_chosen: float = -100.0,
        # A dodge under way: which way, until when.
        dodge_way: Vec3 = Vec3(),
        dodge_until: float = 0.0,
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
        # Progress: where it was when it last got nearer its goal, and when.
        best_distance: float = 1.0e9,
        progress_time: float = 0.0,
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
        jump_due: bool = False,
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
        area = mesh.locate(origin);
        if area > 0 {
            return (area, origin);
        }
        for reach in [12.0, 24.0, 36.0] {
            for k in range(8) {
                angle = float(k) * math.pi / 4.0;
                spot = origin.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach));
                found = mesh.locate(spot);
                if found > 0 {
                    return (found, spot);
                }
            }
        }
        return (0, origin);
    }

    """Close `area` to routing for a while, for the mover `model` (0: none)
    that makes it no way through."""
    def close_area(area: int, model: int) {
        mesh = self.mesh;
        if mesh is None or area <= 0 {
            return;
        }
        mesh.enable_area(area, False);
        self.closed[area] = (model, self.clock + 30.0);
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
            if self.clock > until or (model > 0 and not mover_blocked(world, model, player)) {
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
        mesh = self.mesh;
        if mesh is None {
            return None;
        }
        for reach in [16.0, 32.0, 48.0, 64.0, 96.0, 128.0] {
            for k in range(16) {
                angle = float(k) * math.pi / 8.0;
                spot = origin.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach));
                for drop in [0.0, 16.0, 32.0, 48.0, -16.0] {
                    area = mesh.aas.area_at(spot.sub(Vec3(z=drop)));
                    if area > 0 and mesh.aas.areas[area].reach_count > 0 {
                        return spot;
                    }
                }
            }
        }
        return None;
    }

    """The middle of the nearest area within a few hundred units that has a
    way to the goal, or None."""
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
        forward = forward_from(player.yaw, 0.0);
        right = right_from(player.yaw);
        intent.move = Vec3(x=aim.dot(right), y=aim.dot(forward));
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
                "at": "[" + str(int(origin.x)) + ", " + str(int(origin.y)) + ", " + str(int(origin.z)) + "]",
                "area": str(area),
                "goal": trace_text(self.goal_name)
            });
            self.trace.dump("blocked", self.clock);
        }
    }

    """Which way to step to keep out of a burst: from a grenade lying or
    landing within its reach, or across the line of a rocket that will pass
    close. None when nothing threatens."""
    def dodge(world: World, origin: Vec3) -> Vec3 | None {
        best: Vec3 | None = None;
        worst = 1.0e9;
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
                # A grenade: away from where it is, while within its reach.
                if distance < reach + 48.0 and distance < worst {
                    worst = distance;
                    away = Vec3(x=rel.x, y=rel.y);
                    best = away.normalized() if away.length() > 0.001 else Vec3(x=1.0);
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
        level = self.level;
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
            if level is not None {
                left_room = level.collision.trace(origin, origin.add(across.scale(64.0))).fraction;
                right_room = level.collision.trace(origin, origin.sub(across.scale(64.0))).fraction;
                if right_room > left_room {
                    across = across.scale(-1.0);
                }
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
        self.exit_goal = None;
        self.exit_area = 0;
        self.exit_name = "";
        self.visited = set();
        self.roam_chosen = -100.0;
        self.closed = {};
        self.lost_since = -1.0;
        self.leap = 0;
        self.best_distance = 1.0e9;
        self.progress_time = self.clock;
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
        # A monster whose wounds close after each hit (its pain puts its
        # health back) falls only to a shot that does `needed` at once.
        if needed > 0 and rule.damage * max(1, rule.pellets) + rule.splash < needed {
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
        rate = float(rule.damage * max(1, rule.pellets) + rule.splash) / max(0.05, rule.interval);
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
            # One it holds nothing to hurt with (only the axe, out of reach;
            # nothing that does enough at once to a zombie) is not fought:
            # it keeps on its way, dodging what comes at it.
            if autoplay_standoff(self.player, self.state, body) < 0.0 {
                continue;
            }
            nearest = distance;
            best = body;
        }
        return best;
    }

    """The level's way out the route finds soonest: an exit's trigger."""
    def choose_exit() {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return;
        }
        here_area = self.bot.area_near(self.origin)[0];
        best_time = UNREACHED;
        for portal in [self.world->:HasExit:->][?:LevelExit] {
            if not portal.volume.bounds {
                continue;
            }
            box = portal.volume.bounds[0];
            goal = box.mins.add(box.maxs).scale(0.5);
            area = mesh.locate(goal);
            if area == 0 or here_area == 0 {
                continue;
            }
            times = mesh.times_to(area, TFL_DEFAULT);
            cost = times[here_area] if here_area < len(times) else UNREACHED;
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
        for reach in [0.0, 16.0, 32.0, 48.0, 64.0] {
            for k in range(8 if reach > 0.0 else 1) {
                angle = float(k) * math.pi / 4.0;
                spot = point.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach));
                for drop in [0.0, 16.0, 32.0, 48.0, 64.0, 80.0] {
                    area = mesh.aas.area_at(spot.sub(Vec3(z=drop)));
                    if area > 0 and mesh.aas.areas[area].reach_count > 0 {
                        return (area, spot);
                    }
                }
            }
        }
        # Nothing near its height (it is over a mover compiled elsewhere,
        # a floor lowered as a lift): the area under it, however far.
        under = mesh.locate(point);
        return (under, point);
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
        busy = [bot.objective.mover] if bot.objective is not None else [];
        busy.extend([held.mover for held in bot.waiting]);
        for (model, area) in movers {
            if model in busy {
                # Being seen to further down the stack (not by the objective
                # under way, which may be done from on the mover), and not yet
                # open: no way through it meanwhile. Never the area it is in.
                current = bot.objective;
                its_own = current is not None and (current.mover == model or current.stand == area);
                here_area = bot.area_near(self.origin)[0];
                if not its_own and area > 0 and area != here_area and area not in mesh.disabled
                    and mover_blocked(self.world, model, self.player) {
                    bot.close_area(area, model);
                    bot.route.abandon();
                    print("AUTOPLAY mover", model, "is still shut: area", area, "closed");
                }
                continue;
            }
            if area in bot.rest_areas {
                leader = objective_mover(self.world, model);
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
                for choice in mover_objectives(self.world, model, self.player)
                if not any([held.point.sub(choice.point).length() < 8.0 for held in pending])
            ];
            # Before working to open it: is there another way on without it?
            # A player goes round a door that opens elsewhere when the way
            # round is there, rather than hunting for what opens it.
            if choices and area > 0 and area not in mesh.disabled and not self.near_work(choices, model) and self.way_round(area) {
                bot.close_area(area, model);
                bot.route.abandon();
                print("AUTOPLAY mover", model, "needs work; going round it");
                bot.trace.event("go_round", bot.clock, {"mover": str(model), "area": str(area)});
                return False;
            }
            if choices and self.take_objective(choices) {
                return True;
            }
            # In the way with nothing to be done about it now: route round it.
            if area > 0 and area not in mesh.disabled and mover_blocked(self.world, model, self.player) {
                bot.close_area(area, model);
                bot.route.abandon();
                print("AUTOPLAY mover", model, "is shut: area", area, "closed");
                return False;
            }
        }
        return False;
    }

    """Whether one of `choices` (what opens mover `model`) is reached with no
    other shut mover opened first: every area of a mover that is shut is
    closed for the asking. A door whose opener is behind other doors is
    deep work."""
    def near_work(choices: list[Objective], model: int) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        here_area = bot.area_near(self.origin)[0];
        if here_area <= 0 {
            return True;
        }
        shut: dict[int, bool] = {};
        closed: list[int] = [];
        for a in range(1, len(mesh.aas.areas)) {
            other = area_mover_model(mesh.aas.areas[a].contents);
            if other <= 0 or other == model or a in mesh.disabled {
                continue;
            }
            if other not in shut {
                shut[other] = mover_blocked(self.world, other, self.player);
            }
            if shut[other] {
                mesh.enable_area(a, False);
                closed.append(a);
            }
        }
        found = False;
        for choice in choices {
            box = choice.box;
            spots: list[int] = [];
            if box is not None {
                spots = [a for a in mesh.aas.box_areas(box.mins, box.maxs, 32) if mesh.aas.areas[a].reach_count > 0];
            } else {
                spots = [self.stand_area(choice.point)[0]];
            }
            for spot in spots {
                if spot <= 0 {
                    continue;
                }
                if spot == here_area {
                    found = True;
                    break;
                }
                times = mesh.times_to(spot, TFL_DEFAULT);
                if here_area < len(times) and times[here_area] < UNREACHED {
                    found = True;
                    break;
                }
            }
            if found {
                break;
            }
        }
        for a in closed {
            mesh.enable_area(a, True);
        }
        return found;
    }

    """Whether the bot's goal can still be reached with `area` closed (from
where it stands): another way on than through it."""
    def way_round(area: int) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None or bot.goal_area <= 0 {
            return False;
        }
        here_area = bot.area_near(self.origin)[0];
        if here_area <= 0 or here_area == area or bot.goal_area == area {
            return False;
        }
        was_open = mesh.enable_area(area, False);
        times = mesh.times_to(bot.goal_area, TFL_DEFAULT);
        reachable = here_area < len(times) and times[here_area] < UNREACHED;
        if was_open {
            mesh.enable_area(area, True);
        }
        return reachable;
    }

    """Take up the objective, of `choices`, the route reaches soonest and that
    was not given up on lately. Whether one was."""
    def take_objective(choices: list[Objective], within: int = UNREACHED) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        here_area = self.bot.area_near(self.origin)[0];
        best: Objective | None = None;
        best_time = UNREACHED;
        notes: list[str] = [];
        for choice in choices {
            passed_over = False;
            for (spot, until) in bot.given_up {
                if until > bot.clock and spot.sub(choice.point).length() < 8.0 {
                    passed_over = True;
                }
            }
            where = "[" + str(int(choice.point.x)) + ", " + str(int(choice.point.y)) + ", " + str(int(choice.point.z)) + "]";
            label = "{\"kind\": " + trace_text(choice.kind) + ", \"why\": " + trace_text(choice.why) + ", \"at\": " + where;
            # Only worth having, near where it died on this map: not again.
            if choice.why in ["ammo", "health", "supply"] and bot.deaths_map == self.level.name {
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
            # A volume no area reaches into is not done from beside it.
            if not spots and box is None {
                spots.append(self.stand_area(choice.point));
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
            "at": "[" + str(int(best.point.x)) + ", " + str(int(best.point.y)) + ", " + str(int(best.point.z)) + "]",
            "route": str(best_time),
            "from_area": str(here_area),
            "stack": trace_text(bot.chain()),
            "choices": "[" + ", ".join(notes[0:16]) + "]"
        });
        best.started = bot.clock;
        # As long as the way there should take, twice over, and twenty seconds
        # to do it in.
        best.allowed = float(best_time) * 0.02 + 20.0;
        best.nearest = 1.0e9;
        best.nearer_at = bot.clock;
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

    """Ammunition when out of it, health when hurt, as an objective set on
    top of what it is doing (not with an enemy in sight). Whether one was."""
    def resupply() -> bool {
        # Out of ammunition it goes for some even with an enemy in sight:
        # standing to fight with the axe loses.
        if self.take_objective(self.ammo_nearby(), 1500) {
            return True;
        }
        if self.bot.enemy is not None {
            return False;
        }
        # Before pressing or touching what opens the way (it may let monsters
        # out), it tops up sooner.
        current = self.bot.objective;
        wary = current is not None and current.kind in ["press", "touch", "shoot"];
        if self.player.health < (75 if wary else 60) and self.take_objective(self.health_nearby(), 1500) {
            return True;
        }
        # Something worth a short way round, but not on top of an objective
        # (a key, a button): those come first.
        if self.bot.objective is not None {
            return False;
        }
        return self.take_objective(self.on_the_way(), 300);
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
    when short, armor or health when hurt (worth at least 25, close by)."""
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
        # No way to the exit for a while: what was given up and closed is
        # tried again (the key behind a door it set aside).
        mesh = bot.mesh;

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

    can engage with Engage entry {
        bot = self.bot;
        enemy = self.spot_enemy();
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
            if gap < objective.nearest - 32.0 {
                objective.nearest = gap;
                objective.nearer_at = bot.clock;
            }
        }
        if objective is None or objective.done(self.player)
            or bot.clock - objective.nearer_at > max(25.0, objective.allowed * 0.5)
            or bot.clock - objective.started > max(180.0, objective.allowed * 3.0) {
            if objective is not None {
                finished = objective.done(self.player);
                why_end = "done" if finished else (
                    "no nearer for " + str(int(bot.clock - objective.nearer_at)) + " s (nearest " + str(int(objective.nearest)) + ")"
                    if bot.clock - objective.nearer_at > max(25.0, objective.allowed * 0.5)
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
            if objective is not None and objective.done(self.player) {
                print("AUTOPLAY objective done:", objective.kind, "for", objective.why);
            } elif objective is not None {
                print("AUTOPLAY objective given up:", objective.kind, "for", objective.why);
                # Supplies are passed over for longer: there are others.
                spare = objective.why in ["ammo", "health", "supply"];
                bot.given_up.append((objective.point, bot.clock + (240.0 if spare else 60.0)));
            }
            # Back to what it set aside, or on to the exit.
            bot.objective = bot.waiting.pop() if bot.waiting else None;
            resumed = bot.objective;
            if resumed is not None {
                resumed.started = bot.clock;
                # Set aside is not stuck: its progress is counted afresh.
                resumed.nearest = 1.0e9;
                resumed.nearer_at = bot.clock;
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
        if objective.why not in ["ammo", "health", "supply"] and self.resupply() {
            return;
        }
        if objective.kind == "kill" {
            bot.enemy = objective.body;
        } else {
            enemy = self.spot_enemy();
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
            passed_over = False;
            for (spot, until) in bot.given_up {
                if until > bot.clock and spot.sub(item.pos).length() < 8.0 {
                    passed_over = True;
                }
            }
            if passed_over {
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
        bot.goal = best;
        bot.goal_area = best_area;
        bot.goal_name = best_name;
        bot.route.abandon();
        bot.roam_chosen = bot.clock;
        bot.roam_nearest = 1.0e9;
        bot.roam_nearer_at = bot.clock;
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
                bot.given_up.append((goal, bot.clock + 240.0));
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
        bot.best_distance = 1.0e9;
        bot.progress_time = bot.clock;
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
            "at": "[" + str(int(origin.x)) + ", " + str(int(origin.y)) + ", " + str(int(origin.z)) + "]",
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
                self.trace.event("route", self.clock, {
                    "goal": trace_text(self.goal_name),
                    "from_area": str(self.area_near(origin)[0]),
                    "to_area": str(self.goal_area),
                    "legs": str(len(planned.points)),
                    "kinds": trace_text(" ".join(kinds[0:24]))
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
                    forward = forward_from(player.yaw, 0.0);
                    right = right_from(player.yaw);
                    intent.move = Vec3(x=heading.dot(right), y=heading.dot(forward));
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
                    forward = forward_from(player.yaw, 0.0);
                    right = right_from(player.yaw);
                    intent.move = Vec3(x=heading.dot(right), y=heading.dot(forward));
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
                forward = forward_from(player.yaw, 0.0);
                right = right_from(player.yaw);
                intent.move = Vec3(x=flat.dot(right), y=flat.dot(forward));
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
            share = travel.result.speed_scale();
            if travel.launch is not None {
                # The jump the route wants from here: off at a run.
                launch = travel.launch;
                heading = Vec3(x=launch.x, y=launch.y);
                share = 1.0;
                intent.jump = True;
            }
            if travel.result.jump or self.jump_due {
                intent.jump = True;
                self.jump_due = False;
            }
            intent.crouch = travel.result.crouch;
            if self.clock < self.detour_until {
                heading = self.detour;
                share = 1.0;
            }
            flat = Vec3(x=heading.x, y=heading.y);
            if flat.length() > 0.001 and share > 0.0 {
                flat = flat.normalized();
                forward = forward_from(player.yaw, 0.0);
                right = right_from(player.yaw);
                intent.move = Vec3(x=flat.dot(right) * share, y=flat.dot(forward) * share);
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
    # In a fight with an enemy near, stand and sidestep rather than run on:
    # back and forth across its line, turning about at walls and ledges.
    foe = self.enemy;
    if foe is not None and foe.health > 0 {
        toward = foe.pos.sub(player.pos);
        flat_toward = Vec3(x=toward.x, y=toward.y);
        reach = flat_toward.length();
        # Fighting, it stands its ground; on its way, only an enemy close by
        # stops it (one it is fleeing for ammunition does not).
        fighting = self.mind.current == "engage" or (reach < 350.0 and self.objective_why() != "ammo");
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
            if reach < standoff {
                behind = ahead.scale(-1.0);
                drop = gap_distance(level.collision, origin, behind);
                clear = level.collision.trace(origin, origin.add(behind.scale(40.0)));
                if (drop <= 0.0 or drop > 64.0) and clear.fraction >= 1.0 {
                    wish = behind.scale(0.9).add(side.scale(0.45));
                }
            }
            # Badly hurt with it close: back away, still firing, unless a
            # ledge is behind.
            if player.health < 35 and reach < 400.0 {
                behind = ahead.scale(-1.0);
                drop = gap_distance(level.collision, origin, behind);
                clear = level.collision.trace(origin, origin.add(behind.scale(40.0)));
                if (drop <= 0.0 or drop > 64.0) and clear.fraction >= 1.0 {
                    wish = behind.add(side.scale(0.5));
                }
            }
            wish = Vec3(x=wish.x, y=wish.y).normalized();
            forward = forward_from(player.yaw, 0.0);
            right = right_from(player.yaw);
            intent.move = Vec3(x=wish.dot(right), y=wish.dot(forward));
            intent.jump = False;
        }
    }
    # The view: on the enemy when there is one, else where the travel looks
    # or along the way.
    want_yaw = player.yaw;
    want_pitch = 0.0;
    enemy = self.enemy;
    objective = self.objective;
    shoot_at: Vec3 | None = None;
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
        if slot > 0 and slot != state.weapon {
            intent.weapon = slot;
        }
        yaw_gap = abs(autoplay_turn(player.yaw, want_yaw));
        pitch_gap = abs(want_pitch - player.pitch);
        # Only with a weapon that reaches it: not the axe from across a room.
        intent.fire = slot > 0 and yaw_gap < 0.12 and pitch_gap < 0.15;
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
        forward = forward_from(player.yaw, 0.0);
        right = right_from(player.yaw);
        intent.move = Vec3(x=dodge.dot(right), y=dodge.dot(forward), z=intent.move.z);
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
            forward = forward_from(player.yaw, 0.0);
            right = right_from(player.yaw);
            intent.move = Vec3(x=closing.dot(right), y=closing.dot(forward), z=intent.move.z);
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
