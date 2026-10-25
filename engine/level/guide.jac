"""The breadcrumb trail: where a player goes next, read off the level's
graph.

From the place the player stands in and the tokens held now (keys carried,
gates open), the solver's plan (`solve.jac`) to the way out. Its first leg, up to the first token it takes (a key, a switch, a
plate, a foe whose death opens something) or else to the way out, is laid
as a trail along the moves' ends, and a wave of motes runs along it
toward that goal, in the goal's colour, each time the player asks (the
`guide` command, bound to G): the plan is made afresh then, from where the
player stands with what is held."""
import from ..math.vec3 { Vec3 }
import from ..world.world { World, Player }
import from ..world.objectives { mover_blocked, objective_mover }
import from ..world.doors { door_parts }
import from ..world.triggers { TouchTrigger, HasTrigger }
import from ..world.inventory { quantity }
import from ..world.particle_field { Particle, particle_field, PARTICLE_GLOW }
import from .graph { LevelGraph, Place, graph_places, graph_gates }
import from .solve { Solver, MoveStep, DoStep }

# How often where the player is, and what is held, is looked at (the plan
# is made again when either has changed); how long a wave's fountain at the
# goal lasts; the spacing of the motes and how far along the trail they are
# laid; the grid places are found by.
glob GUIDE_LOOK_EVERY: float = 0.25,
     GUIDE_WAVE_TIME: float = 1.2,
     GUIDE_SPACING: float = 40.0,
     GUIDE_REACH: float = 1600.0,
     GUIDE_CELL: float = 256.0;

# The goal's colours (0xRRGGBB): the way out, a foe to kill, a switch, plate
# or other thing to do, and keys by the colour in their names.
glob GUIDE_EXIT_COLOR: int = 0x50FF80,
     GUIDE_KILL_COLOR: int = 0xFF5040,
     GUIDE_DO_COLOR: int = 0xFFA040,
     GUIDE_KEY_COLORS: dict[str, int] = {"gold": 0xFFD040, "silver": 0xD8E4FF, "blue": 0x4A8CFF, "red": 0xFF4A4A, "green": 0x50E050};

"""A level's breadcrumb trail: its graph's solver, the places by grid
cell, and the trail as last planned."""
node Guide {
    has atlas: LevelGraph,
        solver: Solver | None = None,
        cells: dict[tuple[int, int], list[Place]] = {},
        # The gates that are bridges (doors that start open and shut to make
        # a floor), by model.
        bridges: set[int] = set(),
        # The keys carried at some time this level: a key the door it opened
        # used up (Quake's) is still had, as the graph counts it.
        carried: int = 0,
        trail: list[Vec3] = [],
        goal: Vec3 | None = None,
        goal_kind: str = "",
        goal_what: str = "",
        color: int = GUIDE_EXIT_COLOR,
        area: int = -1,
        held: int = -1,
        look_wait: float = 0.0,
        # Asked for (the `guide` command): one wave at the next step.
        asked: bool = False;

    """The graph's solver and the grid of places, made on first use."""
    def prepare -> Solver {
        solver = self.solver;
        if solver is not None {
            return solver;
        }
        made = Solver(atlas=self.atlas);
        made.prepare();
        self.solver = made;
        self.bridges = set([gate.model for gate in graph_gates(self.atlas) if gate.kind == "bridge"]);
        for place in graph_places(self.atlas) {
            for cx in range(int(place.box.mins.x // GUIDE_CELL), int(place.box.maxs.x // GUIDE_CELL) + 1) {
                for cy in range(int(place.box.mins.y // GUIDE_CELL), int(place.box.maxs.y // GUIDE_CELL) + 1) {
                    self.cells.setdefault((cx, cy), []).append(place);
                }
            }
        }
        return made;
    }

    """The place a body at `origin` stands in: the one whose box holds the
    point, or a point a little under it (in the air over a floor), else 0."""
    def place_at(origin: Vec3) -> int {
        for drop in [0.0, 8.0, 16.0, 24.0, 40.0, 64.0, 96.0, 128.0, 192.0, 256.0] {
            point = origin.sub(Vec3(z=drop));
            for place in self.cells.get((int(point.x // GUIDE_CELL), int(point.y // GUIDE_CELL)), []) {
                box = place.box;
                if box.mins.x <= point.x <= box.maxs.x and box.mins.y <= point.y <= box.maxs.y and box.mins.z - 2.0 <= point.z <= box.maxs.z + 2.0 {
                    return place.area;
                }
            }
        }
        return 0;
    }

    """The tokens held now, as the search's mask: keys carried (or carried
    before and used up on their door), gates the player would pass (open, or
    opening for what is carried), bridges drawn out (shut all the way, where
    a body walks on them)."""
    def held_now(world: World, player: Player) -> int {
        view = self.prepare().view;
        if view is None {
            return 0;
        }
        mask = 0;
        for index in range(len(view.tokens)) {
            token = view.tokens[index];
            held = False;
            if token.startswith("key") {
                held = quantity(player.inventory, token) > 0 or self.carried & (1 << index) != 0;
                if held {
                    self.carried |= 1 << index;
                }
            } elif token.startswith("hit:") {
                # One input of a counter: had once its button has been seen
                # pressed (the counter keeps the count).
                held = self.carried & (1 << index) != 0;
                if not held and token[4:].isdigit() {
                    for part in door_parts(world) {
                        if part.model == int(token[4:]) and part.kind == "button" and (part.state not in ["closed", "locked"] or part.position > 0.01) {
                            held = True;
                        }
                    }
                } elif not held {
                    # A trigger input, named by where it is: had once it has
                    # fired.
                    held = hit_trigger_fired(world, token[4:]);
                }
                if held {
                    self.carried |= 1 << index;
                }
            } elif token.startswith("open:") and int(token[5:]) in self.bridges {
                leader = objective_mover(world, int(token[5:]));
                held = leader is not None and leader.position >= 0.99;
            } elif token.startswith("open:") {
                held = not mover_blocked(world, int(token[5:]), player);
            }
            if held {
                mask |= 1 << index;
            }
        }
        return mask;
    }

    """Plan the trail from `origin` in `area` holding `held`: the solver's
    plan, up to its first token taken (or all the way to the way out)."""
    def plan(origin: Vec3, area: int, held: int) {
        solver = self.prepare();
        self.trail = [];
        made = solver.solve(area, held, origin);
        if not made.found {
            return;
        }
        points = [origin];
        aimed = False;
        last_to = area;
        for step in made.steps() {
            if isinstance(step, DoStep) {
                self.aim(step.point, step.kind, step.what, guide_color(step.kind, step.what));
                points.append(step.point);
                aimed = True;
                break;
            }
            if isinstance(step, MoveStep) {
                points.append(step.start);
                points.append(step.finish);
                last_to = step.to;
            }
        }
        if not aimed {
            place = solver.by_area.get(last_to, None);
            if place is not None {
                self.aim(place.center, "exit", "", GUIDE_EXIT_COLOR);
                points.append(place.center);
            }
        }
        self.trail = points;
    }

    """The goal from now on: a point, what is done there, its colour."""
    def aim(point: Vec3, kind: str, what: str, color: int) {
        if kind != self.goal_kind or self.goal is None or point.sub(self.goal).length() > 1.0 {
            print("GUIDE", self.atlas.name, "goal", kind, "at", int(point.x), int(point.y), int(point.z));
        }
        self.goal = point;
        self.goal_kind = kind;
        self.goal_what = what;
        self.color = color;
    }

    """What to do next, for the HUD: the goal in words and how far along
    the trail it is (32 units a metre), or "" with no plan."""
    def next_text -> str {
        if self.goal is None or not self.trail {
            return "";
        }
        kind = self.goal_kind;
        what = self.goal_what;
        doing = "Reach the way out";
        if what.startswith("key") {
            doing = "Find the " + guide_key_words(what);
        } elif kind == "press" {
            doing = "Press the button";
        } elif kind == "shoot" {
            doing = "Shoot the button";
        } elif kind == "touch" {
            doing = "Step on the plate" if self.atlas.game == "passion" else "Walk into the trigger";
        } elif kind == "kill" {
            doing = "Kill the foe that opens the way";
        } elif kind == "pickup" {
            doing = "Pick up the item";
        }
        length = 0.0;
        for index in range(1, len(self.trail)) {
            length += self.trail[index].sub(self.trail[index - 1]).length();
        }
        return doing + " (" + str(max(1, int(length / 32.0))) + " m)";
    }

    """One step of the guide: the plan made again when the player has come
    into another place or what is held has changed (for the HUD's line on
    what to do next), and when asked, one wave of motes along it."""
    def follow(world: World, player: Player, origin: Vec3, dt: float) {
        self.prepare();
        self.look_wait -= dt;
        if self.look_wait <= 0.0 or self.asked {
            self.look_wait = GUIDE_LOOK_EVERY;
            area = self.place_at(origin);
            held = self.held_now(world, player);
            # In the air, the plan stands from the last floor.
            if area > 0 and (area != self.area or held != self.held or self.asked) {
                self.area = area;
                self.held = held;
                self.plan(origin, area, held);
            }
        }
        if not self.asked {
            return;
        }
        self.asked = False;
        if not self.trail {
            return;
        }
        field = particle_field(world);
        crumbs = guide_crumbs(self.trail, origin);
        # Each mote shows at full strength for most of its life (its alpha
        # starts over one and is held to one), then fades.
        for index in range(len(crumbs)) {
            life = 1.0;
            field.add(Particle(origin=crumbs[index], velocity=Vec3(z=10.0), born=field.clock + float(index) * 0.035, life=life, kind=PARTICLE_GLOW, color=self.color, alpha=2.5, fade=-2.5 / life));
        }
        # A little fountain at the goal, over the wave's time.
        goal = self.goal;
        if goal is not None {
            for index in range(8) {
                life = 1.0;
                spot = Vec3(x=goal.x + field.crand() * 12.0, y=goal.y + field.crand() * 12.0, z=goal.z - 8.0);
                field.add(Particle(origin=spot, velocity=Vec3(x=field.crand() * 6.0, y=field.crand() * 6.0, z=40.0), born=field.clock + float(index) * GUIDE_WAVE_TIME / 8.0, life=life, kind=PARTICLE_GLOW, color=self.color, alpha=2.5, fade=-2.5 / life));
            }
        }
    }
}

edge HasGuide: World --> Guide {}

"""Whether the trigger at `where` ("x_y_z", its middle) has fired."""
def hit_trigger_fired(world: World, where: str) -> bool {
    parts = where.split("_");
    if len(parts) != 3 {
        return False;
    }
    point = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
    for trigger in [world->:HasTrigger:->][?:TouchTrigger] {
        if not trigger.volume.bounds {
            continue;
        }
        box = trigger.volume.bounds[0];
        if box.mins.add(box.maxs).scale(0.5).sub(point).length() < 8.0 {
            return trigger.activations > 0;
        }
    }
    return False;
}

"""Each step of the world, the guide (when there is one) lays its trail
if the player has asked for it."""
walker FollowGuide {
    has player: Player,
        origin: Vec3,
        dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasGuide:->];
        }
    }

    can lead with Guide entry {
        world = self.world;
        if world is not None {
            here.follow(world, self.player, self.origin, self.dt);
        }
    }
}

"""Give `world` a breadcrumb trail over `atlas`, in place of any it had (a
level with no graph, or an arena, which has no way out to lead to: none)."""
def guide_level(world: World, atlas: LevelGraph | None) {
    for old in [world->:HasGuide:->][?:Guide] {
        world del --> old;
    }
    if atlas is None or atlas.arena {
        return;
    }
    world +>:HasGuide:+> Guide(atlas=atlas);
}

"""The motes of a trail: points every GUIDE_SPACING along it from a little
past the player, as far as GUIDE_REACH, a little under the body's middle
(nearer the floor)."""
def guide_crumbs(trail: list[Vec3], origin: Vec3) -> list[Vec3] {
    crumbs: list[Vec3] = [];
    walked = 0.0;
    next_at = 48.0;
    last = origin;
    for point in trail[1:] {
        leg = point.sub(last);
        length = leg.length();
        while length > 0.001 and next_at <= walked + length and next_at <= GUIDE_REACH {
            spot = last.add(leg.scale((next_at - walked) / length));
            crumbs.append(Vec3(x=spot.x, y=spot.y, z=spot.z - 12.0));
            next_at += GUIDE_SPACING;
        }
        walked += length;
        last = point;
        if walked > GUIDE_REACH {
            break;
        }
    }
    return crumbs;
}

"""A key's name in words: "gold key" for key_gold, "blue key" for Quake
II's key_blue_key, "data cd" for key_data_cd."""
def guide_key_words(what: str) -> str {
    words = what[4:] if what.startswith("key_") else what;
    if words.endswith("_key") {
        words = words[:-4];
    }
    words = words.replace("_", " ");
    return words + " key" if words in GUIDE_KEY_COLORS else words;
}

"""The colour of a goal by what is done there."""
def guide_color(kind: str, what: str) -> int {
    if what.startswith("key") {
        for (name, color) in GUIDE_KEY_COLORS.items() {
            if name in what {
                return color;
            }
        }
        return GUIDE_KEY_COLORS["gold"];
    }
    if kind == "kill" {
        return GUIDE_KILL_COLOR;
    }
    return GUIDE_DO_COLOR;
}
