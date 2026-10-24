"""The breadcrumb trail: where a player goes next, read off the level's
graph.

From the place the player stands in and the tokens held now (keys carried,
gates open), the cheapest way over the graph's moves to the way out, tokens
taken where their openers are done: the proof's own search, begun where the
player is. Its first leg, up to the first token it takes (a key, a switch, a
plate, a foe whose death opens something) or else to the way out, is laid
as a trail along the moves' ends, and a wave of motes runs along it
toward that goal, in the goal's colour, each time the player asks (the
`guide` command, bound to G): the plan is made afresh then, from where the
player stands with what is held."""
import from ..math.vec3 { Vec3 }
import from ..world.world { World, Player }
import from ..world.objectives { mover_blocked }
import from ..world.inventory { quantity }
import from ..world.particle_field { Particle, particle_field, PARTICLE_GLOW }
import from .graph { LevelGraph, Place, Move, Opener, graph_places, graph_openers, opener_places }
import from .prove { Search, search_of }

# How often where the player is, and what is held, is looked at (the plan
# is made again when either has changed); how long a wave's fountain at the
# goal lasts; the spacing of the motes and how far along the trail they are
# laid; the grid places are found by.
glob GUIDE_LOOK_EVERY: float = 0.25,
     GUIDE_WAVE_TIME: float = 1.2,
     GUIDE_SPACING: float = 40.0,
     GUIDE_REACH: float = 1600.0,
     GUIDE_CELL: float = 256.0,
     GUIDE_SEARCH: int = 200000,
     # What taking a token costs the plan over the way's length: a token is
     # taken only when no way round it is that much shorter, so a trail
     # leads past a secret's button to what the level needs.
     GUIDE_TOKEN_COST: float = 4000.0;

# The goal's colours (0xRRGGBB): the way out, a foe to kill, a switch, plate
# or other thing to do, and keys by the colour in their names.
glob GUIDE_EXIT_COLOR: int = 0x50FF80,
     GUIDE_KILL_COLOR: int = 0xFF5040,
     GUIDE_DO_COLOR: int = 0xFFA040,
     GUIDE_KEY_COLORS: dict[str, int] = {"gold": 0xFFD040, "silver": 0xD8E4FF, "blue": 0x4A8CFF, "red": 0xFF4A4A, "green": 0x50E050};

"""A level's breadcrumb trail: its graph and the search's view of it, the
places by grid cell, and the trail as last planned."""
node Guide {
    has atlas: LevelGraph,
        view: Search | None = None,
        span: int = 1,
        cells: dict[tuple[int, int], list[Place]] = {},
        by_area: dict[int, Place] = {},
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

    """The search's view and the grid of places, made on first use."""
    def prepare {
        if self.view is not None {
            return;
        }
        view = search_of(self.atlas);
        self.view = view;
        self.span = 1 << len(view.tokens);
        for place in graph_places(self.atlas) {
            self.by_area[place.area] = place;
            for cx in range(int(place.box.mins.x // GUIDE_CELL), int(place.box.maxs.x // GUIDE_CELL) + 1) {
                for cy in range(int(place.box.mins.y // GUIDE_CELL), int(place.box.maxs.y // GUIDE_CELL) + 1) {
                    self.cells.setdefault((cx, cy), []).append(place);
                }
            }
        }
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

    """The tokens held now, as the search's mask: keys carried, gates the
    player would pass (open, or opening for what is carried)."""
    def held_now(world: World, player: Player) -> int {
        view = self.view;
        if view is None {
            return 0;
        }
        mask = 0;
        for index in range(len(view.tokens)) {
            token = view.tokens[index];
            held = False;
            if token.startswith("key") {
                held = quantity(player.inventory, token) > 0;
            } elif token.startswith("open:") {
                held = not mover_blocked(world, int(token[5:]), player);
            }
            if held {
                mask |= 1 << index;
            }
        }
        return mask;
    }

    """Plan the trail from `origin` in `area` holding `held`."""
    def plan(origin: Vec3, area: int, held: int) {
        view = self.view;
        if view is None {
            return;
        }
        span = self.span;
        self.trail = [];
        # The search begins holding what this place gives too; a token of
        # those the way wants is done right here.
        begun = held | view.gives[area];
        first = area * span + begun;
        cost: dict[int, float] = {first: 0.0};
        came: dict[int, list[int]] = {};
        heap: list[list[float]] = [[0.0, float(first)]];
        done: dict[int, bool] = {};
        goal = -1;
        nearest_gain = -1;
        popped = 0;
        while heap and popped < GUIDE_SEARCH {
            top = guide_heap_pop(heap);
            state = int(top[1]);
            if state in done {
                continue;
            }
            done[state] = True;
            popped += 1;
            at = state // span;
            mask = state % span;
            if at in view.exits and (view.exit_bit == 0 or mask & view.exit_bit != 0) {
                goal = state;
                break;
            }
            if mask != begun and nearest_gain < 0 {
                nearest_gain = state;
            }
            from_place = self.by_area.get(at, None);
            steps = view.maybe[at];
            for index in range(len(steps)) {
                step = steps[index];
                if step[1] & mask != step[1] or view.deadly[step[0]] {
                    continue;
                }
                move = view.ways[at][index];
                to_place = self.by_area.get(step[0], None);
                length = 16.0;
                if from_place is not None and to_place is not None {
                    length = max(16.0, to_place.center.sub(from_place.center).length());
                }
                # Ways the level may not let every player take (a hard jump)
                # cost more than sure ones.
                length = length if move.must else length * 3.0;
                after_mask = mask | view.gives[step[0]];
                after = step[0] * span + after_mask;
                total = top[0] + length + (GUIDE_TOKEN_COST if after_mask != mask else 0.0);
                if after not in done and total < cost.get(after, 1.0e18) {
                    cost[after] = total;
                    came[after] = [state, at, index];
                    guide_heap_push(heap, [total, float(after)]);
                }
            }
        }
        if goal < 0 {
            goal = nearest_gain;
        }
        if goal < 0 {
            return;
        }
        # The states back to the start; the tokens the way's steps want (and
        # the way out, when it wants one); then forward to the first state
        # that takes one of those (or all the way, to the way out). A token
        # taken on the way and wanted by nothing (a button seen in passing)
        # is no goal.
        states = [goal];
        while states[0] in came {
            states.insert(0, came[states[0]][0]);
        }
        wanted = view.exit_bit if goal // span in view.exits else 0;
        for at in range(1, len(states)) {
            link = came[states[at]];
            wanted |= view.maybe[link[1]][link[2]][1];
        }
        if goal // span not in view.exits {
            wanted |= (goal % span) & ~held;
        }
        here = view.gives[area] & ~held & wanted;
        if here != 0 {
            opener = self.token_opener(here, area, origin);
            if opener is not None {
                self.aim(opener.point, opener.kind, opener.what, guide_color(opener.kind, opener.what));
                self.trail = [origin, opener.point];
            }
            return;
        }
        cut = len(states) - 1;
        for at in range(1, len(states)) {
            if (states[at] % span) & ~(states[at - 1] % span) & wanted != 0 {
                cut = at;
                break;
            }
        }
        points = [origin];
        for at in range(1, cut + 1) {
            link = came[states[at]];
            move = view.ways[link[1]][link[2]];
            points.append(move.start);
            points.append(move.finish);
        }
        end = states[cut];
        gained = (end % span) & ~(states[cut - 1] % span) & wanted if cut > 0 else 0;
        if gained != 0 {
            opener = self.token_opener(gained, end // span, points[-1]);
            if opener is not None {
                self.aim(opener.point, opener.kind, opener.what, guide_color(opener.kind, opener.what));
                points.append(opener.point);
            }
        } else {
            place = self.by_area.get(end // span, None);
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

    """The opener of a token in `gained` done from `area` (the nearest to
    `near` when several are), or None."""
    def token_opener(gained: int, area: int, near: Vec3) -> Opener | None {
        view = self.view;
        if view is None {
            return None;
        }
        best: Opener | None = None;
        nearest = 1.0e18;
        for opener in graph_openers(self.atlas) {
            if opener.token not in view.tokens or gained & (1 << view.tokens.index(opener.token)) == 0 {
                continue;
            }
            if area not in [place.area for place in opener_places(opener)] {
                continue;
            }
            distance = opener.point.sub(near).length();
            if distance < nearest {
                nearest = distance;
                best = opener;
            }
        }
        return best;
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

"""Push onto a binary heap of [cost, state] (cheapest first)."""
def guide_heap_push(heap: list[list[float]], item: list[float]) {
    heap.append(item);
    at = len(heap) - 1;
    while at > 0 {
        parent = (at - 1) // 2;
        if heap[parent][0] <= heap[at][0] {
            break;
        }
        swap = heap[parent];
        heap[parent] = heap[at];
        heap[at] = swap;
        at = parent;
    }
}

"""Pop the cheapest of a binary heap of [cost, state]."""
def guide_heap_pop(heap: list[list[float]]) -> list[float] {
    top = heap[0];
    last = heap.pop();
    if heap {
        heap[0] = last;
        at = 0;
        while True {
            left = at * 2 + 1;
            right = left + 1;
            least = at;
            if left < len(heap) and heap[left][0] < heap[least][0] {
                least = left;
            }
            if right < len(heap) and heap[right][0] < heap[least][0] {
                least = right;
            }
            if least == at {
                break;
            }
            swap = heap[least];
            heap[least] = heap[at];
            heap[at] = swap;
            at = least;
        }
    }
    return top;
}
