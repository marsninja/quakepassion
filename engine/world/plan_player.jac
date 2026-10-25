"""The player bot: the player's own body played by the level's plan, through
the same `Intent` a keyboard and mouse make (issue #88).

The level graph's solver (`engine/level/solve.jac`) makes the plan: from the
place the bot stands in, with what it holds, every move to the way out and
every token taken on the way (a key picked up, a button pressed, a trigger
touched, a switch shot, a foe killed). The bot walks the plan's chain of
steps: an `Act` walker visits the step under way each frame, and a move is
followed with the Q3 bots' own travel (`FollowRoute`) over the graph's
moves, a token taken by going at its opener's point. What it sees it shoots
with the best weapon held, on its way.

The plan is made again when it no longer stands: the bot is somewhere the
plan did not lead, a token came or went (a door shut again), or a step took
too long. A step that took too long is banned for the rest of the level (the
graph had it wrong there) and printed, so a run of the bot is also a check
of the level's graph: `PLAY failed` for each step that did not work, `PLAY
stuck` when no plan is left, `PLAY finished` on leaving the level."""
import math;
import from .world { World, Player }
import from .level { Level }
import from .bot_routes { NavMesh, HasNavMesh, BotRoute, Passage, Exits, plan_route, build_navmesh, jump_launch, jump_run_start }
import from .bot_travel { FollowRoute, TravelResult, set_travel_gravity }
import from .bot_trace { BotTrace, trace_text, trace_point }
import from .combat { Opponent, HasOpponent, CombatState, owns_weapon, has_ammo_for, weapon_rule }
import from .exits { LevelExit, HasExit, exit_map }
import from .pickups { Pickup, HasPickup }
import from .inventory { quantity }
import from .doors { Door }
import from .objectives { objective_mover, mover_objectives, exit_objectives }
import from ..level.graph { LevelGraph }
import from ..level.guide { Guide, HasGuide }
import from ..level.routes { graph_aas }
import from ..level.solve { Solver, Plan, Step, MoveStep, DoStep, Bans }
import from ..formats.aas { TFL_DEFAULT, TRAVEL_WALK, TRAVEL_JUMP, TRAVEL_BARRIERJUMP, TRAVEL_WALKOFFLEDGE, TRAVEL_ELEVATOR, TRAVEL_TELEPORT, TRAVEL_JUMPPAD, TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_LADDER, TRAVEL_WATERJUMP, TRAVEL_FUNCBOB }
import from ..input.input { Intent }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..math.aabb { AABB }

glob PLAY_THINK: float = 0.1,  # ten thinks a second
    # How fast the bot turns its view, radians a second.
    PLAY_TURN: float = 9.0,
    # How far it looks for enemies.
    PLAY_SIGHT: float = 1500.0,
    # How long it may be somewhere the plan did not lead before it plans
    # again from there.
    PLAY_OFF_PLAN: float = 1.5,
    # How long a step may take: a move its time three times over and this
    # (a lift this much more, for the wait), a token this long once there.
    PLAY_MOVE_SLACK: float = 5.0,
    PLAY_LIFT_SLACK: float = 20.0,
    PLAY_TAKE_TIME: float = 12.0,
    # How often one plan may be begun again from the same place and holding
    # before its first step is banned (a door that shuts before it is
    # reached, again and again).
    PLAY_REPLANS: int = 6;

"""The player bot: the level's plan and where it is along it."""
node PlanPlayer {
    has level: Level | None = None,
        guide: Guide | None = None,
        solver: Solver | None = None,
        mesh: NavMesh | None = None,
        plan: Plan | None = None,
        steps: list[Step] = [],
        at: int = 0,
        bans: Bans = Bans(),
        # How often a plan was begun from each place, holding and first step.
        begun: dict[str, int] = {},
        route: BotRoute = BotRoute(),
        routed_at: int = -1,
        area: int = 0,
        held: int = -1,
        clock: float = 0.0,
        frames: int = 0,
        think_wait: float = 0.0,
        step_since: float = 0.0,
        # When each step was first set about, since it was last got past:
        # a step set about again and again (the bot drifting off the plan
        # and back) is still given only its time.
        tried: dict[str, float] = {},
        # The levels played this run (QP_AUTOPLAY_BEEN adds others): a way
        # out back to one of them is no way out, unless every one is; and
        # the places of those ways out in this level.
        been: set[str] = set(),
        back_places: set[int] = set(),
        off_since: float = -1.0,
        stuck_said: str = "",
        replan_wait: float = 0.0,
        enemy: Opponent | None = None,
        travel: TravelResult = TravelResult(),
        view_yaw: float = 100.0,
        blocked_time: float = 0.0,
        ride_held: float = 0.0,
        # A running jump under way (0 none, 1 backing up, 2 running, 3 in
        # the air) and when it began.
        leap: int = 0,
        leap_started: float = 0.0,
        dead_seen: bool = False,
        deaths: int = 0,
        failures: list[str] = [],
        log_wait: float = 0.0,
        # The menu message last printed (`App.step` prints each once).
        menu_notice: str = "",
        # Where a shoot step is shot from (a spot with a clear line), and
        # the step it was found for.
        shot_spot: Vec3 | None = None,
        shot_spot_for: str = "",
        # Asked of the game (`App.step`): the `kill` command, for a bot that
        # lives on (god mode) in a place a body dies in, with no way out.
        wants_death: bool = False,
        # QP_AUTOPLAY_SHOTS=<seconds>: a screenshot that often, into shot_dir.
        shot_every: float = 0.0,
        shot_wait: float = 0.0,
        shot_dir: str = ".jac/shots",
        trace: BotTrace = BotTrace();

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

    """A new level: its graph (the one the breadcrumb trail is laid over)
    and the router's mesh over it; the plan made at the first think."""
    def begin_level(world: World, level: Level) {
        old = self.level;
        if old is not None and old.name != level.name {
            self.been.add(old.name);
            print("PLAY finished", old.bsp.game, old.name, "to", level.name, "t", round(self.clock, 1), "deaths", self.deaths, "failures", len(self.failures));
            self.trace.event("finished", self.clock, {"map": trace_text(old.name), "failures": str(len(self.failures))});
        }
        if old is None or old.name != level.name {
            self.bans = Bans();
            self.failures = [];
            self.begun = {};
            self.tried = {};
            self.deaths = 0;
            self.clock = 0.0;
        }
        self.level = level;
        self.plan = None;
        self.steps = [];
        self.route = BotRoute();
        self.routed_at = -1;
        self.held = -1;
        self.stuck_said = "";
        set_travel_gravity(level.movement.gravity);
        guides = [world->:HasGuide:->][?:Guide];
        self.guide = guides[0] if guides else None;
        self.solver = None;
        self.mesh = None;
        guide = self.guide;
        if guide is not None {
            guide.prepare();
            self.solver = Solver(atlas=guide.atlas, falls=False);
            self.back_places = self.ways_back(world, guide);
            shipped = [world->:HasNavMesh:->][?:NavMesh];
            self.mesh = build_navmesh(world, graph_aas(guide.atlas, shipped[0].aas if shipped else None), level.bsp);
            print("PLAY level", level.bsp.game, level.name, "graph", " | ".join(guide.atlas.notes[:2]));
        } else {
            # An arena (no way out to make for) or a level with no graph: the
            # bot hunts over the level's own navigation, if it has one.
            shipped = [world->:HasNavMesh:->][?:NavMesh];
            self.mesh = shipped[0] if shipped else None;
            print("PLAY level", level.bsp.game, level.name, "no plan: an arena or no graph");
        }
        self.trace.event("level", self.clock, {"map": trace_text(level.bsp.game + ":" + level.name)});
    }

    """The area the bot stands in: the one at its origin, else one a few
    units round it (stood closer to a wall than a floor's area reaches),
    else the graph's place under it; 0 when none."""
    def area_at(origin: Vec3) -> int {
        mesh = self.mesh;
        if mesh is not None {
            area = mesh.locate(origin);
            if area > 0 {
                return area;
            }
            for reach in [12.0, 24.0, 36.0] {
                for k in range(8) {
                    angle = float(k) * math.pi / 4.0;
                    beside = mesh.locate(origin.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach)));
                    if beside > 0 {
                        return beside;
                    }
                }
            }
        }
        guide = self.guide;
        if guide is None {
            return 0;
        }
        # In the air over a floor (a jump's height at most); else, stood on
        # something that is no place of the graph (a mover's top, a ledge it
        # left out), the nearest place at or under the body: where the way on
        # starts from, the travel stepping or dropping down to it.
        under = guide.place_at(origin, 64.0);
        if under > 0 {
            return under;
        }
        solver = self.solver;
        if solver is None {
            return 0;
        }
        best = 0;
        nearest = 384.0;
        for (area, place) in solver.by_area.items() {
            if place.box.mins.z > origin.z + 24.0 {
                continue;
            }
            gap = place.center.sub(origin).length();
            if gap < nearest {
                nearest = gap;
                best = area;
            }
        }
        return best;
    }

    """The places of the ways out of this level back to levels already
    played (the places their trigger volumes meet); none when every way out
    goes back."""
    def ways_back(world: World, guide: Guide) -> set[int] {
        back: set[int] = set();
        onward = 0;
        # The graph says where each way out leads: a place whose every way
        # out leads back.
        places = list(guide.prepare().by_area.values());
        if any([place.exits for place in places]) {
            leads = set([name for place in places for name in place.exits]);
            if not [name for name in leads if name not in self.been] {
                return set();
            }
            back = set([place.area for place in places if place.way_out and place.exits and not [name for name in place.exits if name not in self.been]]);
            print("PLAY ways back", len(back), "places; ways out lead to", " ".join(sorted(leads)));
            return back;
        }
        for portal in [world->:HasExit:->][?:LevelExit] {
            going_back = False;
            try {
                going_back = exit_map(portal.destination) in self.been;
            } except ValueError {
                going_back = False;
            }
            boxes = exit_boxes(world, portal);
            print("PLAY exit to", portal.destination, "back" if going_back else "onward", len(boxes), "trigger boxes");
            if not going_back {
                onward += 1;
                continue;
            }
            for box in boxes {
                for area in guide.prepare().by_area.keys() {
                    place = guide.prepare().by_area[area];
                    if place.box.mins.x <= box.maxs.x + 16.0 and box.mins.x - 16.0 <= place.box.maxs.x and place.box.mins.y <= box.maxs.y + 16.0
                        and box.mins.y - 16.0 <= place.box.maxs.y and place.box.mins.z <= box.maxs.z + 24.0 and box.mins.z - 32.0 <= place.box.maxs.z {
                        back.add(area);
                    }
                }
            }
        }
        if onward == 0 {
            return set();
        }
        if back {
            print("PLAY ways back", len(back), "places, ways onward", onward);
        }
        return back;
    }

    """Plan from `area` holding `held`, at `origin`."""
    def replan(area: int, held: int, origin: Vec3, why: str) {
        solver = self.solver;
        level = self.level;
        if solver is None or level is None {
            return;
        }
        self.bans.now = self.clock;
        made = solver.solve(area, held, origin, self.bans, self.back_places);
        self.plan = made;
        self.steps = made.steps() if made.found else [];
        self.at = 0;
        self.route = BotRoute();
        self.routed_at = -1;
        self.begin_step();
        self.off_since = -1.0;
        self.area = area;
        self.held = held;
        if not made.found {
            said = made.reason;
            place = solver.by_area.get(area, None);
            if place is not None and place.deadly {
                # A body dies here in the game (lava, slime): the level goes
                # on from that death, as for a player.
                self.wants_death = True;
                said = said + "; in a place a body dies in: taking the death";
            }
            if said != self.stuck_said {
                self.stuck_said = said;
                print("PLAY stuck", level.bsp.game, level.name, "t", round(self.clock, 1), ":", said, "| failures:", "; ".join(self.failures[-6:]));
                self.trace.event("stuck", self.clock, {"reason": trace_text(said), "failures": trace_text("; ".join(self.failures))});
            }
            return;
        }
        self.stuck_said = "";
        # The same plan begun again and again from here as a token comes and
        # goes: its first step is not to be had (a door shut again before it
        # is reached, each time).
        key = str(area) + ":" + str(held) + ":" + (step_words(self.steps[0]) if self.steps else "-");
        if why.startswith("took") or why.startswith(" lost") {
            self.begun[key] = self.begun.get(key, 0) + 1;
        }
        if self.begun.get(key, 0) > PLAY_REPLANS and self.steps {
            self.begun[key] = 0;
            self.fail(self.steps[0], "begun " + str(PLAY_REPLANS) + " times over from place " + str(area));
            return;
        }
        print(
            "PLAY plan", level.name, "t", round(self.clock, 1), "from", area, "holding [" + solver.held_words(held) + "]", "steps", len(self.steps),
            "to the way out" if made.to_exit else "to a token", "(" + why + ") first", step_words(self.steps[0]) if self.steps else "-"
        );
        self.trace.event("plan", self.clock, {
            "from": str(area),
            "held": trace_text(solver.held_words(held)),
            "steps": str(len(self.steps)),
            "why": trace_text(why),
            "first": trace_text(step_words(self.steps[0]) if self.steps else "-")
        });
    }

    """`step` did not work: banned for the rest of the level (for a minute
    when a mover was in its way: a door that slid across it may go back),
    printed, and a plan made without it."""
    def fail(step: Step, why: str) {
        level = self.level;
        if level is None {
            return;
        }
        until = 1.0e18;
        if self.travel.blocked and self.travel.block_model > 0 {
            until = self.clock + 60.0;
            why = why + ", a mover (model " + str(self.travel.block_model) + ") in the way";
        }
        self.tried.pop(step_words(step), None);
        words = step_words(step) + ": " + why;
        self.failures.append(words);
        print("PLAY failed", level.bsp.game, level.name, "t", round(self.clock, 1), words);
        self.trace.event("failed", self.clock, {"step": trace_text(words)});
        self.trace.dump(words, self.clock);
        if isinstance(step, MoveStep) {
            self.bans.ban_move(step, until);
        } elif isinstance(step, DoStep) {
            self.bans.ban_take(step, until);
        }
        self.plan = None;
    }

    """The place the plan ends in (its way out)."""
    def final_place -> int {
        for step in reversed(self.steps) {
            if isinstance(step, MoveStep) {
                return step.to;
            }
        }
        plan = self.plan;
        return plan.area if plan is not None else 0;
    }

    """The step under way, or None (the plan done: at the way out)."""
    def current -> Step | None {
        return self.steps[self.at] if self.at < len(self.steps) else None;
    }

    """Go on along the plan from where the bot stands: past each move into
    `area`, to the step being done from it; off the plan when the plan does
    not pass there."""
    def follow_area(area: int) {
        if area <= 0 {
            return;
        }
        if isinstance(self.current(), DoStep) or (self.current() is None and area == self.final_place()) {
            # A token is taken round its point, whichever place that is; at
            # the way out, the plan is done.
            self.off_since = -1.0;
            return;
        }
        for index in range(self.at, min(len(self.steps), self.at + 24)) {
            step = self.steps[index];
            if isinstance(step, DoStep) {
                # Never past a token not yet taken.
                if step.area == area {
                    self.go_to(index);
                    self.off_since = -1.0;
                    return;
                }
                break;
            }
            if isinstance(step, MoveStep) and step.to == area {
                self.go_to(index + 1);
                self.off_since = -1.0;
                return;
            }
            if step.area == area {
                if index != self.at {
                    self.go_to(index);
                }
                self.off_since = -1.0;
                return;
            }
        }
        if self.off_since < 0.0 {
            self.off_since = self.clock;
        }
    }

    def go_to(index: int) {
        if index != self.at {
            # The steps got past are done with.
            for passed in self.steps[self.at:min(index, len(self.steps))] {
                self.tried.pop(step_words(passed), None);
            }
            self.at = index;
            self.begin_step();
        }
    }

    """The step under way is set about: its time runs from when it was
    first set about."""
    def begin_step {
        step = self.current();
        self.step_since = self.tried.setdefault(step_words(step), self.clock) if step is not None else self.clock;
    }

    """How long `step` may take."""
    def allowed(step: Step) -> float {
        if isinstance(step, MoveStep) {
            return PLAY_MOVE_SLACK + 3.0 * float(step.time) / 100.0 + (PLAY_LIFT_SLACK if step.kind == TRAVEL_ELEVATOR else 0.0);
        }
        return PLAY_TAKE_TIME;
    }

    """The route along the plan's moves from the step under way to the next
    token taken (or the way out): the travel's waypoints over the mesh's
    passages, as `plan_route` lays them. False when a move has no passage
    (the step is failed)."""
    def route_moves -> bool {
        mesh = self.mesh;
        self.route = BotRoute();
        self.routed_at = self.at;
        if mesh is None {
            return False;
        }
        for index in range(self.at, len(self.steps)) {
            step = self.steps[index];
            if not isinstance(step, MoveStep) {
                break;
            }
            best: Passage | None = None;
            nearest = 1.0e18;
            if step.area > 0 and step.area < len(mesh.areas) {
                for passage in [mesh.areas[step.area]->:Exits:->][?:Passage] {
                    if passage.target == step.to and passage.kind == step.kind {
                        gap = passage.start.sub(step.start).length();
                        if gap < nearest {
                            nearest = gap;
                            best = passage;
                        }
                    }
                }
            }
            if best is None {
                if index == self.at {
                    self.fail(step, "no such way on the router's mesh");
                    return False;
                }
                break;
            }
            if best.kind in [TRAVEL_TELEPORT, TRAVEL_JUMPPAD] {
                aim = best.start;
                self.route.add(aim, best.target, passage=best);
                break;
            }
            if best.kind in [TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_LADDER, TRAVEL_WATERJUMP, TRAVEL_ELEVATOR, TRAVEL_FUNCBOB] {
                self.route.add(best.finish, best.target, passage=best);
            } else {
                if best.kind == TRAVEL_JUMP {
                    run_up = jump_run_start(mesh, step.area, best);
                    if run_up is not None {
                        self.route.add(run_up, 0, passage=best);
                    }
                }
                if best.kind in [TRAVEL_BARRIERJUMP, TRAVEL_JUMP] {
                    self.route.add(best.start, 0, jump_launch(best.start, best.finish), best);
                } elif best.kind == TRAVEL_WALKOFFLEDGE {
                    self.route.add(best.start, 0, passage=best);
                }
                self.route.add(best.finish, best.target, passage=best);
            }
        }
        self.route.found = len(self.route.points) > 0;
        return True;
    }

    """Whether to keep the few shots left for a switch the plan shoots
    later: a shoot step ahead, and under six shots held for the weapons
    that reach."""
    def saving_shots(player: Player, state: CombatState) -> bool {
        ahead = [step for step in self.steps[self.at:] if isinstance(step, DoStep) and step.kind == "shoot"];
        if not ahead {
            return False;
        }
        shots = 0;
        for rule in state.rules {
            if rule.ammo and owns_weapon(player, rule) and rule.reach > 300.0 {
                shots += quantity(player.inventory, rule.ammo) // max(1, rule.cost);
            }
        }
        return shots < 6;
    }

    """Where `target` can be shot from: of the areas within 768 of it, the
    nearest to `origin` whose middle at eye height has a line that ends on
    what is shot (`solid`, when it is a brush) or a clear one; None when
    none near has."""
    def shooting_spot(level: Level, target: Vec3, solid: AABB | None, origin: Vec3) -> Vec3 | None {
        mesh = self.mesh;
        if mesh is None {
            return None;
        }
        near: list[tuple[float, int]] = [];
        for index in range(1, len(mesh.aas.areas)) {
            info = mesh.aas.areas[index];
            if info.reach_count == 0 or info.center.sub(target).length() > 768.0 {
                continue;
            }
            near.append((info.center.sub(origin).length(), index));
        }
        near.sort();
        eye_height = level.collision.eye_height;
        for (gap, index) in near[0:96] {
            eye = mesh.aas.areas[index].center.add(Vec3(z=eye_height));
            line = level.collision.trace_point(eye, target);
            if line.fraction > 0.97 or (solid is not None and line.model > 0 and play_inside(line.end, solid, 4.0)) {
                return mesh.aas.areas[index].center;
            }
        }
        return None;
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

    """The nearest living enemy in sight, or None."""
    def spot_enemy(world: World, level: Level, eye: Vec3) -> Opponent | None {
        best: Opponent | None = None;
        nearest = PLAY_SIGHT;
        for body in [world->:HasOpponent:->][?:Opponent] {
            rule = body.rule;
            if body.health <= 0 or body.dormant or rule.decoration or rule.inert or rule.good_guy {
                continue;
            }
            target = body.pos.sub(Vec3(z=body.eye_height * 0.5));
            distance = target.sub(eye).length();
            if distance >= nearest or level.collision.trace_point(eye, target).fraction < 0.97 {
                continue;
            }
            nearest = distance;
            best = body;
        }
        return best;
    }

    """A running jump over a gap (the route's next passage): back up along
    the jump's line to a run-up, run through the takeoff and jump at the
    edge, keep on in the air. The command for this frame, or None when no
    jump is under way."""
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
            # Not working out: the route is laid again.
            self.leap = 0;
            self.routed_at = -1;
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
            self.leap = 0;
            self.routed_at = -1;
        }
        intent.move = play_move(player.yaw, aim);
        self.travel = TravelResult(direction=aim, speed=400.0);
        return intent;
    }

    """With no plan (an arena): over the mesh after the nearest living
    opponent, the route laid again every second; `intent` takes the move."""
    def hunt(world: World, level: Level, player: Player, origin: Vec3, dt: float, intent: Intent) {
        mesh = self.mesh;
        if mesh is None {
            return;
        }
        if self.frames % 60 == 0 or not self.route.points {
            prey: Opponent | None = None;
            nearest = 1.0e18;
            for body in [world->:HasOpponent:->][?:Opponent] {
                if body.health <= 0 or body.dormant or body.rule.decoration or body.rule.inert or body.rule.good_guy {
                    continue;
                }
                gap = body.pos.sub(origin).length();
                if gap < nearest {
                    nearest = gap;
                    prey = body;
                }
            }
            if prey is not None {
                self.route = plan_route(mesh, origin, prey.pos, limit=48, flags=TFL_DEFAULT, now=self.clock);
            }
        }
        if not self.route.points {
            return;
        }
        travel = player spawn FollowRoute(
            mesh=mesh, collision=level.collision, route=self.route, eye_height=level.collision.eye_height, clock=self.clock,
            view_yaw=math.degrees(player.yaw) % 360.0, view_pitch=-math.degrees(player.pitch), dt=dt, ducked=player.crouched
        );
        self.travel = travel.result;
        flat = Vec3(x=travel.result.direction.x, y=travel.result.direction.y);
        if flat.length() > 0.001 {
            intent.move = play_move(player.yaw, flat.normalized(), travel.result.speed_scale());
        }
        intent.jump = travel.result.jump or travel.launch is not None;
    }

    def drive(world: World, level: Level, player: Player, state: CombatState, dt: float) -> Intent;
}

"""A step in words, for the log: "move 12->40 jump at 100,200,0", "press
open:5 at 64,320,40"."""
def step_words(step: Step) -> str {
    if isinstance(step, MoveStep) {
        return "move " + str(step.area) + "->" + str(step.to) + " " + travel_words(step.kind) + ("" if step.must else "?") + " at "
            + point_words(step.start) + " to " + point_words(step.finish);
    }
    if isinstance(step, DoStep) {
        return step.kind + " " + step.token + (" (" + step.what + ")" if step.what else "") + " from " + str(step.area) + " at " + point_words(step.point);
    }
    return "step";
}

def point_words(point: Vec3) -> str {
    return str(int(point.x)) + "," + str(int(point.y)) + "," + str(int(point.z));
}

"""A travel type's name."""
def travel_words(kind: int) -> str {
    names = {2: "walk", 3: "crouch", 4: "barrier-jump", 5: "jump", 6: "ladder", 7: "drop", 8: "swim", 9: "water-jump", 10: "teleport", 11: "lift", 12: "rocket-jump", 16: "ramp-jump", 18: "jump-pad", 19: "bobbing"};
    return names.get(kind, "kind " + str(kind));
}

"""A flat world direction `way` as the move asked for with the view at
`yaw`: across and along it, scaled by `share`, with `rise` up or down."""
def play_move(yaw: float, way: Vec3, share: float = 1.0, rise: float = 0.0) -> Vec3 {
    return Vec3(x=way.dot(right_from(yaw)) * share, y=way.dot(forward_from(yaw, 0.0)) * share, z=rise);
}

"""Whether a stride along `way` from `origin` would take a body over a
drop (no floor within 72 under it) or onto lava or slime."""
def play_hazard(level: Level, origin: Vec3, way: Vec3) -> bool {
    ahead = origin.add(way.scale(28.0));
    down = level.collision.trace(ahead, ahead.sub(Vec3(z=72.0)));
    if down.start_solid {
        return False;
    }
    if down.fraction >= 1.0 {
        return True;
    }
    return level.liquid_probe().kind_at(Vec3(x=ahead.x, y=ahead.y, z=down.end.z - 18.0)) >= 2;
}

"""Whether `point` is within `room` of `box`."""
def play_inside(point: Vec3, box: AABB, room: float) -> bool {
    return box.mins.x - room <= point.x <= box.maxs.x + room and box.mins.y - room <= point.y <= box.maxs.y + room
        and box.mins.z - room <= point.z <= box.maxs.z + room;
}

"""The shortest turn from angle `a` to `b`, radians."""
def play_turn(a: float, b: float) -> float {
    gap = (b - a) % (2.0 * math.pi);
    if gap > math.pi {
        gap -= 2.0 * math.pi;
    }
    return gap;
}

"""The best weapon held for something `distance` away: the most damage a
second, without splash up close or in water where it would hurt; 0 when
nothing held reaches."""
def play_weapon(player: Player, state: CombatState, distance: float, wet: bool) -> int {
    best = 0;
    best_rate = -1.0;
    for rule in state.rules {
        if not owns_weapon(player, rule) or not has_ammo_for(player, rule) or rule.hand_thrown or rule.reach < distance {
            continue;
        }
        if (rule.splash > 0 or rule.radius > 0.0) and distance < 200.0 {
            continue;
        }
        if rule.gravity and distance < 350.0 {
            continue;
        }
        if wet and (rule.avoid_underwater or rule.beam_damage > 0) {
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

"""Where an exit is touched: its trigger volume, or (fired, Quake II's) the
boxes of what fires it."""
def exit_boxes(world: World, portal: LevelExit) -> list[AABB] {
    if portal.volume.bounds {
        return [portal.volume.bounds[0]];
    }
    return [objective.box for objective in exit_objectives(world, portal) if objective.box is not None];
}

"""What a shoot step shoots: of the objectives that open its mover, the
shot one nearest the step's point, as its box and whether it is a brush (1;
0 for a trigger with health); None when there is none."""
def shot_target(world: World, player: Player, step: DoStep) -> tuple[AABB, int] | None {
    found: tuple[AABB, int] | None = None;
    nearest = 1.0e18;
    if not step.token.startswith("open:") {
        return None;
    }
    for objective in mover_objectives(world, int(step.token[5:]), player) {
        solid = objective.aim_box;
        if objective.kind != "shoot" or solid is None {
            continue;
        }
        model = 1;
        gap = objective.point.sub(step.point).length();
        if gap < nearest {
            nearest = gap;
            found = (solid, model);
        }
    }
    return found;
}

"""The nearest pickup that would give ammunition for a weapon held (its
ammunition, or a weapon of that kind carrying some), or None."""
def ammo_near(world: World, player: Player, state: CombatState, origin: Vec3) -> Vec3 | None {
    wanted: set[str] = set();
    for rule in state.rules {
        if rule.ammo and owns_weapon(player, rule) and rule.reach > 300.0 {
            wanted.add(rule.ammo);
        }
    }
    best: Vec3 | None = None;
    nearest = 1.0e18;
    for item in [world->:HasPickup:->][?:Pickup] {
        if not item.active {
            continue;
        }
        gives = item.rule.kind in wanted or (item.rule.ammo in wanted and item.rule.ammo_amount > 0);
        if not gives {
            continue;
        }
        gap = item.pos.sub(origin).length();
        if gap < nearest {
            nearest = gap;
            best = item.pos;
        }
    }
    return best;
}

"""The monster whose death a kill step wants: of those whose death fires
what opens the step's mover, the nearest; else the nearest living one to
the step's point."""
def kill_target(world: World, player: Player, step: DoStep) -> Opponent | None {
    if step.token.startswith("open:") {
        bodies = [objective.body for objective in mover_objectives(world, int(step.token[5:]), player) if objective.kind == "kill" and objective.body is not None];
        chosen: Opponent | None = None;
        closest = 1.0e18;
        for body in bodies {
            if body is not None and body.health > 0 and body.pos.sub(step.point).length() < closest {
                closest = body.pos.sub(step.point).length();
                chosen = body;
            }
        }
        if chosen is not None {
            return chosen;
        }
    }
    best: Opponent | None = None;
    nearest = 1.0e18;
    for body in [world->:HasOpponent:->][?:Opponent] {
        if body.health <= 0 or body.rule.decoration or body.rule.inert or body.rule.good_guy {
            continue;
        }
        distance = body.pos.sub(step.point).length();
        if distance < nearest {
            nearest = distance;
            best = body;
        }
    }
    return best;
}

"""This frame's doing of the step under way: a move is followed along the
route, a token taken by going at its opener. It sets the bot's travel (the
heading, a jump) and, for a step that aims (a switch shot), where to look."""
walker Act {
    has bot: PlanPlayer,
        world: World,
        level: Level,
        player: Player,
        state: CombatState,
        origin: Vec3,
        dt: float,
        intent: Intent = Intent(),
        aim: Vec3 | None = None,
        # A foe the step wants dead.
        prey: Opponent | None = None;

    can move with MoveStep entry {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return;
        }
        if bot.routed_at != bot.at or not bot.route.points {
            if not bot.route_moves() {
                return;
            }
        }
        leaping = bot.leap_over(self.level, self.player, self.origin);
        if leaping is not None {
            self.intent = leaping;
            return;
        }
        if not bot.route.points {
            return;
        }
        player = self.player;
        if player.grounded and mesh.locate(self.origin) == 0 {
            # Out of every area (closer to a wall than the floor's area
            # reaches, or on a mover compiled elsewhere): the travel would
            # call that stuck in solid and stop. Straight for the next
            # waypoint instead, back into the areas.
            ahead = Vec3(x=bot.route.points[0].x - self.origin.x, y=bot.route.points[0].y - self.origin.y);
            if ahead.length() < 16.0 {
                bot.route.advance(bot.clock);
            } else {
                self.head(ahead, 1.0);
                bot.travel = TravelResult(direction=ahead.normalized(), speed=400.0);
            }
            return;
        }
        travel = player spawn FollowRoute(
            mesh=mesh,
            collision=self.level.collision,
            route=bot.route,
            eye_height=self.level.collision.eye_height,
            clock=bot.clock,
            view_yaw=math.degrees(player.yaw) % 360.0,
            view_pitch=-math.degrees(player.pitch),
            dt=self.dt,
            ducked=player.crouched
        );
        bot.travel = travel.result;
        heading = travel.result.direction;
        share = travel.result.speed_scale();
        if travel.launch is not None {
            launch = travel.launch;
            heading = Vec3(x=launch.x, y=launch.y);
            share = 1.0;
            self.intent.jump = True;
        }
        if travel.result.jump {
            self.intent.jump = True;
        }
        self.intent.crouch = travel.result.crouch;
        if Vec3(x=heading.x, y=heading.y).length() < 0.001 and share <= 0.0 and travel.launch is None and not travel.result.waiting {
            # The travel has nothing to do (its waypoint counted reached)
            # while the move is not done: straight for the move's end.
            heading = here.finish.sub(self.origin);
            share = 1.0;
        }
        self.head(heading, share);
        # In water at all, a waypoint well below or above is swum to
        # straight down or up; a floor above the water close by is climbed
        # onto (swum up against its edge, jumping).
        if player.water_depth >= 1 and bot.route.points {
            ahead = bot.route.points[0];
            rise = ahead.z - self.origin.z;
            near = Vec3(x=ahead.x - self.origin.x, y=ahead.y - self.origin.y).length() < 64.0;
            if rise < -24.0 {
                self.intent.move.z = -1.0;
            } elif rise > 24.0 and player.water_depth >= 2 {
                self.intent.move.z = 1.0;
            } elif rise > 4.0 and near {
                self.intent.move.z = 1.0;
                self.intent.jump = True;
            }
        }
    }

    can take with DoStep entry {
        bot = self.bot;
        player = self.player;
        target = here.point;
        if here.kind == "shoot" {
            # What is shot (a button, a door, a secret door, a trigger with
            # health: the objective's box).
            aimed = shot_target(self.world, player, here);
            if aimed is not None {
                target = aimed[0].mins.add(aimed[0].maxs).scale(0.5);
            }
            # Nothing held that reaches it with ammunition: fetch some first.
            if play_weapon(player, self.state, target.sub(player.pos).length(), player.water_depth >= 2) <= 0 {
                supply = ammo_near(self.world, player, self.state, self.origin);
                if supply is not None {
                    self.chase(supply);
                }
                return;
            }
            line = self.level.collision.trace_point(player.pos, target);
            # At its middle: a line that ends on a brush model inside what is
            # shot (a button's own face), or a clear one (a trigger with
            # health, which a line passes through).
            ends_on = line.model > 0 and aimed is not None and play_inside(line.end, aimed[0], 4.0);
            if bot.frames % 120 == 0 {
                print("PLAY aim", here.token, "line ends on", line.model, "fraction", round(line.fraction, 3), "at", point_words(line.end), "aiming", point_words(target));
            }
            if ends_on or line.fraction > 0.97 or (aimed is None and line.end.sub(target).length() < 24.0) {
                self.aim = target;
                return;
            }
            # No clear line from here: to the nearest spot that has one (an
            # area's middle at eye height), found once for the step.
            words = step_words(here);
            if bot.shot_spot_for != words {
                bot.shot_spot_for = words;
                bot.shot_spot = bot.shooting_spot(self.level, target, aimed[0] if aimed is not None else None, self.origin);
            }
            spot = bot.shot_spot;
            if spot is not None and Vec3(x=spot.x - self.origin.x, y=spot.y - self.origin.y).length() > 16.0 {
                self.chase(spot);
            } else {
                self.walk_to(target, 0.5);
            }
            return;
        }
        if here.kind == "kill" {
            prey = kill_target(self.world, player, here);
            self.prey = prey;
            if prey is None {
                return;
            }
            eye = player.pos;
            spot = prey.pos.sub(Vec3(z=prey.eye_height * 0.5));
            if self.level.collision.trace_point(eye, spot).fraction < 0.97 or spot.sub(eye).length() > 900.0 {
                # Out of sight or far: after it over the mesh.
                self.chase(prey.pos);
            }
            return;
        }
        # Press, pick up, touch: straight at its point, jumping now and
        # then when it is above or does not come (a plate's trigger hung
        # over the floor, a button over a step).
        self.walk_to(target, 1.0);
        rise = target.z - self.origin.z;
        waited = bot.clock - bot.step_since;
        # Not where gravity is low (a jump there floats for seconds), unless
        # it is above.
        low_gravity = self.level.movement.gravity < 400.0;
        if player.grounded and ((rise > 48.0 and Vec3(x=target.x - self.origin.x, y=target.y - self.origin.y).length() < 96.0) or (waited > 3.0 and bot.frames % 45 == 0 and not low_gravity)) {
            self.intent.jump = True;
        }
    }

    """Over the mesh to `point` (off the plan's moves: after a foe, to a spot
    to shoot from, to ammunition), the route laid again every half second."""
    def chase(point: Vec3) {
        bot = self.bot;
        mesh = bot.mesh;
        if mesh is None {
            return;
        }
        if not bot.route.points or bot.frames % 30 == 0 {
            bot.route = plan_route(mesh, self.origin, point, limit=48, flags=TFL_DEFAULT, now=bot.clock);
            bot.routed_at = -1;
        }
        if not bot.route.points {
            self.walk_to(point, 1.0);
            return;
        }
        player = self.player;
        travel = player spawn FollowRoute(
            mesh=mesh, collision=self.level.collision, route=bot.route, eye_height=self.level.collision.eye_height,
            clock=bot.clock, view_yaw=math.degrees(player.yaw) % 360.0, view_pitch=-math.degrees(player.pitch), dt=self.dt
        );
        bot.travel = travel.result;
        self.head(travel.result.direction, travel.result.speed_scale());
        self.intent.jump = travel.result.jump or travel.launch is not None;
    }

    """Head along the flat world direction `heading` at `share` of a run."""
    def head(heading: Vec3, share: float) {
        flat = Vec3(x=heading.x, y=heading.y);
        if flat.length() > 0.001 and share > 0.0 {
            self.intent.move = play_move(self.player.yaw, flat.normalized(), share);
            if self.player.water_depth >= 2 {
                self.intent.move.z = heading.normalized().z * share;
            }
        }
    }

    """Walk straight at `point`."""
    def walk_to(point: Vec3, share: float) {
        closing = Vec3(x=point.x - self.origin.x, y=point.y - self.origin.y);
        if closing.length() > 2.0 {
            way = closing.normalized();
            self.intent.move = play_move(self.player.yaw, way, share);
            self.bot.travel = TravelResult(direction=way, speed=400.0);
            if self.player.water_depth >= 2 {
                self.intent.move.z = 1.0 if point.z > self.origin.z + 16.0 else (-1.0 if point.z < self.origin.z - 16.0 else 0.0);
            }
        }
    }
}

impl PlanPlayer.drive(world: World, level: Level, player: Player, state: CombatState, dt: float) -> Intent {
    self.clock += dt;
    self.frames += 1;
    if level is not self.level {
        self.begin_level(world, level);
    }
    origin = player.pos.sub(Vec3(z=level.collision.eye_height));
    if player.health <= 0 {
        if not self.dead_seen {
            self.dead_seen = True;
            self.deaths += 1;
            print("PLAY died", level.name, "t", round(self.clock, 1), "at", point_words(origin), player.death_means);
            self.trace.event("death", self.clock, {"at": trace_point(origin), "means": trace_text(player.death_means)});
        }
        # Fire brings the dead back (respawn, or the level begun again).
        self.plan = None;
        return Intent(fire=self.frames % 30 == 0);
    }
    self.dead_seen = False;
    # The plan, looked at ten times a second: made again when what it
    # stood on has changed, the step under way followed on from where the
    # bot is, and a step that has taken too long failed.
    self.think_wait -= dt;
    if self.think_wait <= 0.0 and self.solver is not None {
        self.think_wait += PLAY_THINK;
        guide = self.guide;
        area = self.area_at(origin);
        held = guide.held_now(world, player) if guide is not None else 0;
        if area > 0 {
            self.area = area;
        }
        self.replan_wait -= PLAY_THINK;
        if self.plan is None or not self.plan.found {
            if self.replan_wait <= 0.0 and self.area > 0 {
                self.replan_wait = 2.0;
                self.replan(self.area, held, origin, "no plan");
            }
        } elif held != self.held {
            solver = self.solver;
            self.tried = {};
            if solver is not None {
                gained = held & ~self.held;
                lost = self.held & ~held;
                self.replan(self.area, held, origin, ("took " + solver.held_words(gained) if gained else "") + (" lost " + solver.held_words(lost) if lost else ""));
            }
        } else {
            self.follow_area(area);
            step = self.current();
            if self.off_since >= 0.0 and self.clock - self.off_since > PLAY_OFF_PLAN and (player.grounded or player.water_depth >= 2) and self.area > 0 {
                self.replan(self.area, held, origin, "off the plan in place " + str(self.area));
            } elif step is not None and self.clock - self.step_since > self.allowed(step) {
                self.fail(step, "not done in " + str(round(self.allowed(step), 1)) + " s (stood at " + point_words(origin) + ")");
            } elif step is None and self.clock - self.step_since > 10.0 {
                last = self.steps[-1] if self.steps else None;
                if last is not None {
                    self.fail(last, "at the way out with no exit taken");
                } elif self.stuck_said != "way out" {
                    self.stuck_said = "way out";
                    print("PLAY stuck", level.bsp.game, level.name, "t", round(self.clock, 1), ": standing in a way out that does not take the player out");
                }
                self.step_since = self.clock;
            }
        }
    }
    if self.frames % 6 == 0 {
        self.enemy = self.spot_enemy(world, level, player.pos);
    }
    intent = Intent();
    aim: Vec3 | None = None;
    step = self.current() if self.plan is not None else None;
    mesh = self.mesh;
    if mesh is not None {
        mesh.advance_tables();
    }
    if step is not None {
        acting = step spawn Act(bot=self, world=world, level=level, player=player, state=state, origin=origin, dt=dt);
        intent = acting.intent;
        aim = acting.aim;
        prey = acting.prey;
        if prey is not None and prey.health > 0 {
            self.enemy = prey;
        }
    } elif self.solver is None and mesh is not None {
        # No plan to follow (an arena): after the nearest opponent.
        self.hunt(world, level, player, origin, dt, intent);
    } elif self.plan is not None and self.plan.found {
        # The plan done, in its way out: into the level's exit by that place
        # (onward), else onto the place itself (a car that carries a body to
        # the exit, a trigger fired by standing there) and held there.
        final = self.final_place();
        ending = self.solver;
        place = ending.by_area.get(final, None) if ending is not None else None;
        if place is not None {
            best = place.center;
            nearest = 384.0;
            touch = False;
            for portal in [world->:HasExit:->][?:LevelExit] {
                # A way back is walked into only when every way out is one
                # (a side level's).
                going_back = False;
                try {
                    going_back = bool(self.back_places) and exit_map(portal.destination) in self.been;
                } except ValueError {
                    going_back = False;
                }
                if going_back {
                    continue;
                }
                for box in exit_boxes(world, portal) {
                    middle = box.mins.add(box.maxs).scale(0.5);
                    gap = middle.sub(place.center).length();
                    if gap < nearest {
                        nearest = gap;
                        best = middle;
                        touch = True;
                    }
                }
            }
            way = Vec3(x=best.x - origin.x, y=best.y - origin.y);
            if way.length() > (2.0 if touch else 12.0) {
                intent.move = play_move(player.yaw, way.normalized(), 1.0 if touch or way.length() > 64.0 else 0.4);
                self.travel = TravelResult(direction=way.normalized(), speed=400.0);
            }
            intent.jump = touch and best.z > origin.z + 48.0 and self.frames % 40 == 0;
        }
    }
    # Walking by a drop or a pool that kills (a walkway over lava): where
    # the way would take the body over one in a stride, it slows to half and
    # makes straight for the next waypoint (no corner cut over the edge).
    walking = step is not None and isinstance(step, MoveStep) and step.kind == TRAVEL_WALK;
    heading = Vec3(x=self.travel.direction.x, y=self.travel.direction.y);
    if walking and player.grounded and player.water_depth == 0 and heading.length() > 0.1 and self.route.points
        and play_hazard(level, origin, heading.normalized()) {
        waypoint = self.route.points[0];
        straight = Vec3(x=waypoint.x - origin.x, y=waypoint.y - origin.y);
        if straight.length() > 4.0 {
            intent.move = play_move(player.yaw, straight.normalized(), 0.5);
            self.travel = TravelResult(direction=straight.normalized(), speed=200.0);
        }
    }
    # On a lift still going up or down: held still on it, at its middle,
    # until it stops (stepping off part way drops it back down the shaft).
    riding = self.rising_under(world, level, origin) if player.grounded else None;
    if riding is not None and self.ride_held < 6.0 {
        self.ride_held += dt;
        centre = riding.bounds.center().add(riding.rest).add(riding.travel.scale(riding.position));
        to_centre = Vec3(x=centre.x - origin.x, y=centre.y - origin.y);
        intent.move = Vec3();
        if to_centre.length() > 12.0 {
            intent.move = play_move(player.yaw, to_centre.normalized(), min(1.0, to_centre.length() / 64.0));
        }
        intent.jump = False;
    } elif player.grounded {
        self.ride_held = 0.0;
    }
    # Stuck on something underfoot or ahead (asking to run, going
    # nowhere): a jump.
    asked = Vec3(x=intent.move.x, y=intent.move.y).length();
    speed = Vec3(x=player.velocity.x, y=player.velocity.y).length();
    if asked > 0.5 and (player.grounded or player.water_depth >= 1) and not self.travel.waiting and speed < 30.0 {
        self.blocked_time += dt;
        if self.blocked_time > 0.6 {
            # On foot a jump (not where gravity is low: a jump there floats
            # the body for seconds, off the way); in water up out of it,
            # against the edge.
            intent.jump = player.water_depth >= 1 or level.movement.gravity >= 400.0;
            if player.water_depth >= 1 {
                intent.move.z = 1.0;
            }
            if self.blocked_time > 1.2 {
                self.blocked_time = 0.0;
            }
        }
    } else {
        self.blocked_time = 0.0;
    }
    # Out of breath under water: up for air first.
    if player.water_depth >= 3 and player.air_remaining < 5.0 {
        intent.move = Vec3(x=intent.move.x * 0.3, y=intent.move.y * 0.3, z=1.0);
        intent.jump = True;
    }
    # The view: on the enemy, else on what the step shoots, else where the
    # travel looks or along the way.
    want_yaw = player.yaw;
    want_pitch = 0.0;
    enemy = self.enemy;
    calm = True;
    if enemy is not None and enemy.health > 0 {
        calm = False;
        target = enemy.pos.sub(Vec3(z=enemy.eye_height * 0.5));
        line = target.sub(player.pos);
        want_yaw = math.atan2(line.y, line.x);
        want_pitch = math.atan2(line.z, math.sqrt(line.x * line.x + line.y * line.y));
        distance = line.length();
        slot = play_weapon(player, state, distance, player.water_depth >= 2);
        if slot > 0 and slot != state.weapon {
            intent.weapon = slot;
        }
        held_rule = weapon_rule(state, state.weapon);
        in_hand = held_rule is not None and held_rule.reach >= distance and has_ammo_for(player, held_rule);
        # Near enough on it: a body's half width at its distance.
        close = max(0.02, min(0.12, math.atan2(16.0, max(1.0, distance))));
        intent.fire = slot > 0 and in_hand and abs(play_turn(player.yaw, want_yaw)) < close and abs(want_pitch - player.pitch) < close * 1.25;
        # A switch to shoot still ahead and few shots left: kept for it
        # (unless this foe is what the plan wants dead).
        if intent.fire and step is not None and not (isinstance(step, DoStep) and step.kind == "kill") and self.saving_shots(player, state) {
            intent.fire = False;
        }
    } elif aim is not None {
        calm = False;
        line = aim.sub(player.pos);
        want_yaw = math.atan2(line.y, line.x);
        want_pitch = math.atan2(line.z, math.sqrt(line.x * line.x + line.y * line.y));
        distance = line.length();
        slot = play_weapon(player, state, distance, player.water_depth >= 2);
        if slot > 0 and slot != state.weapon {
            intent.weapon = slot;
        }
        held_rule = weapon_rule(state, state.weapon);
        in_hand = held_rule is not None and held_rule.reach >= distance and has_ammo_for(player, held_rule);
        # What is shot is small (a button): within ten units of the aim at
        # its distance, and only with a weapon that reaches it.
        close = max(0.006, min(0.06, math.atan2(10.0, max(1.0, distance))));
        intent.fire = slot > 0 and in_hand and abs(play_turn(player.yaw, want_yaw)) < close and abs(want_pitch - player.pitch) < close;
    } elif self.travel.view_set {
        want_yaw = math.radians(self.travel.yaw);
        want_pitch = -math.radians(self.travel.pitch);
    } else {
        heading = self.travel.direction;
        if Vec3(x=heading.x, y=heading.y).length() > 0.1 {
            aim_yaw = math.atan2(heading.y, heading.x);
            # Small changes are let be.
            if abs(play_turn(self.view_yaw, aim_yaw)) > 0.25 or self.view_yaw > 99.0 {
                self.view_yaw = aim_yaw;
            }
            want_yaw = self.view_yaw;
        }
    }
    limit = (PLAY_TURN * 0.35 if calm else PLAY_TURN) * max(dt, 0.001);
    intent.look_yaw = max(-limit, min(limit, play_turn(player.yaw, want_yaw)));
    intent.look_pitch = max(-limit, min(limit, want_pitch - player.pitch));
    # A turned view leaves the move pointing where the body faced: keep the
    # heading in the world, measured against the view after the turn.
    if intent.move.length() > 0.0 and abs(intent.look_yaw) > 0.0 {
        turned = player.yaw + intent.look_yaw;
        world_move = forward_from(player.yaw, 0.0).scale(intent.move.y).add(right_from(player.yaw).scale(intent.move.x));
        intent.move = Vec3(x=world_move.dot(right_from(turned)), y=world_move.dot(forward_from(turned, 0.0)), z=intent.move.z);
    }
    if self.trace.on() {
        self.trace.sample(self.clock, dt, "{\"t\": " + str(round(self.clock, 1)) + ", \"at\": " + trace_point(origin) + ", \"vel\": "
            + trace_point(player.velocity) + ", \"hp\": " + str(player.health) + ", \"area\": " + str(self.area) + ", \"step\": "
            + trace_text(step_words(step) if step is not None else "-") + ", \"move\": " + trace_text(str(round(intent.move.x, 2)) + "," + str(round(intent.move.y, 2)) + "," + str(round(intent.move.z, 2)))
            + ", \"jump\": " + ("true" if intent.jump else "false") + ", \"fire\": " + ("true" if intent.fire else "false") + ", \"legs\": " + str(len(self.route.points)) + ", \"travel\": "
            + trace_text(("blocked " if self.travel.blocked else "") + ("waiting " if self.travel.waiting else "") + ("failure " if self.travel.failure else "") + ("on-top " if self.travel.on_top else "") + "speed " + str(int(self.travel.speed)))
            + ", \"weapon\": " + str(state.weapon) + ", \"standing\": " + str(mesh.locate(origin) if mesh is not None else 0) + ", \"water\": " + str(player.water_depth) + "}");
    }
    self.log_wait -= dt;
    if self.log_wait <= 0.0 {
        self.log_wait = 2.0;
        print(
            "PLAY", level.name, "t", round(self.clock, 1), "at", point_words(origin), "hp", player.health, "area", self.area,
            "step", str(self.at + 1) + "/" + str(len(self.steps)), step_words(step) if step is not None else "-",
            "enemy", (enemy.rule.model.split("/")[-1] if enemy is not None and enemy.health > 0 else "no")
        );
    }
    return intent;
}
