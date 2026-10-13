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
import from .combat { Opponent, HasOpponent, CombatState, owns_weapon, has_ammo_for, selected_weapon }
import from .weapons { WeaponRule }
import from .exits { LevelExit, HasExit }
import from .objectives { Objective, mover_objectives, exit_objectives }
import from .bot_routes { predict_mover }
import from ..nav.compile { compile_navigation }
import from ..formats.aas { TFL_DEFAULT, area_mover_model }
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
    for mode in [seek, engage, unstick, activate] {
        mind +>:HasAutoMode:+> mode;
    }
    seek +>:Shifts:+> engage;
    seek +>:Shifts:+> unstick;
    seek +>:Shifts:+> activate;
    engage +>:Shifts:+> seek;
    engage +>:Shifts:+> unstick;
    unstick +>:Shifts:+> seek;
    activate +>:Shifts:+> seek;
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
        given_up: list[tuple[Vec3, float]] = [],
        exit_goal: Vec3 | None = None,
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
        travel: TravelResult = TravelResult(),
        jump_due: bool = False,
        status: str = "",
        log_wait: float = 0.0,
        compile_seconds: float = 0.0,
        # QP_AUTOPLAY_SHOTS=<seconds>: a screenshot that often, to see the
        # bot play afterwards (into QP_AUTOPLAY_SHOT_DIR, relative).
        shot_every: float = 0.0,
        shot_wait: float = 0.0,
        shot_dir: str = ".jac/shots",
        fired: bool = False,
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
        self.given_up = [];
        self.exit_goal = None;
        self.best_distance = 1.0e9;
        self.progress_time = self.clock;
        self.stuck_count = 0;
        self.mind.current = "seek_exit";
        meshes = [world->:HasNavMesh:->][?:NavMesh];
        if meshes {
            self.mesh = meshes[0];
            self.status = "navigation from the map's AAS";
        } else {
            started = time.time();
            build = compile_navigation(world, level);
            self.compile_seconds = time.time() - started;
            self.mesh = build_navmesh(world, build.aas, level.bsp);
            self.status = "navigation compiled in " + str(round(self.compile_seconds, 1)) + " s: " + build.summary();
        }
        print("AUTOPLAY", level.bsp.game, level.name, self.status);
    }
}

"""The best weapon held for an enemy `distance` away: the most damage a
second, without splash up close or in water where it would hurt."""
def autoplay_weapon(player: Player, state: CombatState, distance: float, wet: bool) -> int {
    best = 0;
    best_rate = -1.0;
    for rule in state.rules {
        if not owns_weapon(player, rule) or not has_ammo_for(player, rule) or rule.hand_thrown {
            continue;
        }
        if (rule.splash > 0 or rule.radius > 0.0) and distance < 160.0 {
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
        here_area = mesh.locate(self.origin);
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
        area = mesh.locate(self.origin);
        if area == 0 {
            return 0;
        }
        standing = area_mover_model(mesh.aas.areas[area].contents);
        if standing > 0 {
            return standing;
        }
        return predict_mover(mesh, area, self.origin, bot.exit_area, TFL_DEFAULT, 400, 100000);
    }

    """Take up the objective, of `choices`, the route reaches soonest and that
    was not given up on lately. Whether one was."""
    def take_objective(choices: list[Objective]) -> bool {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return False;
        }
        here_area = mesh.locate(self.origin);
        best: Objective | None = None;
        best_time = UNREACHED;
        for choice in choices {
            passed_over = False;
            for (spot, until) in bot.given_up {
                if until > bot.clock and spot.sub(choice.point).length() < 8.0 {
                    passed_over = True;
                }
            }
            if passed_over {
                continue;
            }
            stand = self.stand_area(choice.point);
            if stand[0] == 0 {
                continue;
            }
            cost = 1;
            if stand[0] != here_area and here_area > 0 {
                times = mesh.times_to(stand[0], TFL_DEFAULT);
                cost = times[here_area] if here_area < len(times) else UNREACHED;
            }
            if cost < best_time {
                best_time = cost;
                best = choice;
            }
        }
        if best is None {
            return False;
        }
        best.started = bot.clock;
        signal = best.signal;
        best.fired = signal.fired if signal is not None else 0;
        bot.objective = best;
        bot.route.abandon();
        print("AUTOPLAY objective", best.kind, "at", int(best.point.x), int(best.point.y), int(best.point.z), "for", best.why);
        return True;
    }

    """Health on the map within about fifteen seconds' travel."""
    def health_nearby() -> list[Objective] {
        found: list[Objective] = [];
        for item in [self.world->:HasPickup:->][?:Pickup] {
            if item.active and item.rule.kind == "health" and item.pos.sub(self.origin).length() < 1500.0 {
                found.append(Objective(kind="pickup", point=item.pos, why="health", item=item));
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
        bot.goal = bot.exit_goal;
        bot.goal_area = bot.exit_area;
        bot.goal_name = bot.exit_name;
        model = self.blocking_mover();
        if model > 0 and self.take_objective(mover_objectives(self.world, model, self.player)) {
            visit self.shift(here, "activate");
            return;
        }
        if enemy is None and self.player.health < 60 and self.take_objective(self.health_nearby()) {
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
        }
    }

    can activate with Activate entry {
        bot = self.bot;
        objective = bot.objective;
        if objective is None or objective.done(self.player) {
            if objective is not None {
                print("AUTOPLAY objective done:", objective.kind, "for", objective.why);
            }
            bot.objective = None;
            bot.route.abandon();
            visit self.shift(here, "seek_exit");
            return;
        }
        if bot.clock - objective.started > 25.0 {
            print("AUTOPLAY objective given up:", objective.kind, "for", objective.why);
            bot.given_up.append((objective.point, bot.clock + 60.0));
            bot.objective = None;
            bot.route.abandon();
            visit self.shift(here, "seek_exit");
            return;
        }
        if objective.kind == "kill" {
            bot.enemy = objective.body;
        } else {
            enemy = self.spot_enemy();
            bot.enemy = enemy;
        }
        stand = self.stand_area(objective.point);
        if bot.goal is None or bot.goal.sub(objective.point).length() > 1.0 {
            bot.route.abandon();
        }
        bot.goal = objective.point;
        bot.goal_area = stand[0];
        bot.goal_name = objective.kind + " for " + objective.why;
    }

    can unstick with Unstick entry {
        bot = self.bot;
        # Forget the route and the passages that failed it for a while.
        bot.route.abandon();
        bot.replan_wait = 0.0;
        bot.stuck_count = 0;
        bot.best_distance = 1.0e9;
        bot.progress_time = bot.clock;
        bot.jump_due = True;
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
    if player.health <= 0 {
        # Fire brings the dead back (respawn, or the level restarted).
        self.route.abandon();
        self.goal = None;
        self.objective = None;
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
        self.mind spawn AutoThink(
            bot=self, world=world, level=level, player=player, origin=origin, eye_height=eye_height
        );
    }
    mesh = self.mesh;
    goal = self.goal;
    intent = Intent();
    if mesh is not None {
        mesh.advance_tables();
    }
    if mesh is not None and goal is not None {
        # Progress: nearer the goal along the route's next waypoint.
        distance = goal.sub(origin).length();
        if self.route.points {
            distance = self.route.points[0].sub(origin).length() + float(len(self.route.points)) * 64.0;
        }
        if distance < self.best_distance - 8.0 {
            self.best_distance = distance;
            self.progress_time = self.clock;
        } elif self.clock - self.progress_time > 3.0 {
            self.stuck_count += 1;
            self.progress_time = self.clock;
            print("AUTOPLAY stuck at", int(origin.x), int(origin.y), int(origin.z), "area", mesh.locate(origin), "legs", len(self.route.points));
        }
        self.replan_wait -= dt;
        if not self.route.points and self.replan_wait <= 0.0 {
            planned = plan_route(
                mesh, origin, goal, limit=64, flags=TFL_DEFAULT, goal_area=self.goal_area, avoid=self.avoid, now=self.clock
            );
            self.replan_wait = 0.05 if planned.pending else (0.3 if planned.found else 1.0);
            if planned.found {
                self.route = planned;
            }
        }
        if self.route.points {
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
            flat = Vec3(x=heading.x, y=heading.y);
            if flat.length() > 0.001 and share > 0.0 {
                flat = flat.normalized();
                forward = forward_from(player.yaw, 0.0);
                right = right_from(player.yaw);
                intent.move = Vec3(x=flat.dot(right) * share, y=flat.dot(forward) * share);
                if player.water_depth >= 2 {
                    intent.move.z = heading.normalized().z * share;
                }
            }
        }
    }
    # In a fight with an enemy near, stand and sidestep rather than run on:
    # back and forth across its line, turning about at walls and ledges.
    foe = self.enemy;
    if foe is not None and foe.health > 0 and self.mind.current == "engage" {
        toward = foe.pos.sub(player.pos);
        flat_toward = Vec3(x=toward.x, y=toward.y);
        reach = flat_toward.length();
        if reach < 700.0 and reach > 1.0 {
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
            if reach < 160.0 {
                wish = wish.sub(ahead.scale(0.7));
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
        slot = autoplay_weapon(player, state, distance, player.water_depth >= 2);
        if slot > 0 and slot != state.weapon {
            intent.weapon = slot;
        }
        yaw_gap = abs(autoplay_turn(player.yaw, want_yaw));
        pitch_gap = abs(want_pitch - player.pitch);
        intent.fire = yaw_gap < 0.12 and pitch_gap < 0.15;
        self.fired = intent.fire;
    } elif self.travel.view_set {
        want_yaw = math.radians(self.travel.yaw);
        want_pitch = -math.radians(self.travel.pitch);
    } else {
        heading = self.travel.direction;
        if Vec3(x=heading.x, y=heading.y).length() > 0.1 {
            want_yaw = math.atan2(heading.y, heading.x);
        }
    }
    limit = AUTO_TURN * max(dt, 0.001);
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
    self.log_wait -= dt;
    if self.log_wait <= 0.0 {
        self.log_wait = 2.0;
        print(
            "AUTOPLAY", level.name, "t", round(self.clock, 1), "at", int(origin.x), int(origin.y), int(origin.z), "hp",
            player.health, "mode", self.mind.current, "goal", self.goal_name, "legs", len(self.route.points),
            "objective", objective.kind if objective is not None else "-",
            "enemy", (enemy.rule.model.split("/")[-1] + " " + str(int(enemy.pos.sub(player.pos).length())) + " hp " + str(enemy.health)) if enemy is not None else "no",
            "fire", self.fired, "weapon", state.weapon, "next", self.next_leg()
        );
    }
    return intent;
}
