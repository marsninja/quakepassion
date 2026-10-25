"""Solving a level graph: the plan a player follows from where they stand,
with what they hold, to the way out.

The proof's own search (`prove.jac`), begun at the player's place and
holding: the cheapest way over the graph's moves to the way out, a token
taken where its opener is done from. The plan is a chain of steps, each a
node: a `MoveStep` for each move taken, and a `DoStep` where the way needs a
token taken (press, touch, shoot, pick up, kill: at its opener's point).
The breadcrumb trail lays its motes along the plan's first steps; the player
(`engine/world/plan_player.jac`) walks the whole chain.

A plan is made again whenever what it stood on changes: the player is
somewhere it did not lead, a token came or went (a door shut again), or a
step failed. A failed step is *banned* (that move from that place, that
token from that place), so the next plan goes another way: what the level
showed the graph had wrong, kept for the rest of the level."""
import from ..math.vec3 { Vec3 }
import from .graph { LevelGraph, Place, Move, Opener, graph_places, graph_openers, opener_places }
import from .prove { Search, search_of }

# What taking a token costs the plan over the way's length: a token is
# taken only when no way round it is that much shorter, so a plan leads
# past a secret's button to what the level needs. A move the graph is
# only sure might work (a hard jump) costs three times its length, and a
# place a body dies in (lava, slime) is gone into only when nothing else
# will do (a player already in the slime, wading out).
glob SOLVE_TOKEN_COST: float = 4000.0,
     SOLVE_MAYBE_SCALE: float = 3.0,
     SOLVE_DEADLY_COST: float = 20000.0,
     SOLVE_SEARCH: int = 400000;

"""One step of a plan, from place `area`."""
node Step {
    has area: int;
}

"""A move to place `to`: its kind (botlib's travel types), the mover it
rides, where it is taken from and arrives, its time (hundredths of a
second), and whether the graph is sure of it."""
node MoveStep(Step) {
    has to: int,
        kind: int,
        model: int = 0,
        start: Vec3 = Vec3(),
        finish: Vec3 = Vec3(),
        time: int = 0,
        must: bool = True;
}

"""A token taken where the player stands: its opener's kind (press, touch,
shoot, pickup, kill), the token, the opener's point, and what stands there
(a key's or a monster's classname)."""
node DoStep(Step) {
    has kind: str,
        token: str,
        point: Vec3 = Vec3(),
        what: str = "";
}

"""A plan: from `area` holding `held`, whether it reaches the way out
(else it only leads to the nearest token to be had), and why there is
none when there is none."""
node Plan {
    has area: int,
        held: int,
        found: bool = False,
        to_exit: bool = False,
        reason: str = "";

    """Its steps in order."""
    def steps -> list[Step] {
        found: list[Step] = [];
        step = [self->:First:->][?:Step];
        while step {
            found.append(step[0]);
            step = [step[0]->:Then:->][?:Step];
        }
        return found;
    }
}

edge First: Plan --> Step {}
edge Then: Step --> Step {}

"""The steps a player found do not work, kept for the rest of a level or
until a time (`now` is the level's clock as the plan is made): moves
(`area:to:kind`) and tokens taken from a place (`area:token`)."""
obj Bans {
    has moves: dict[str, float] = {},
        takes: dict[str, float] = {},
        now: float = 0.0;

    def move_banned(area: int, move: Move) -> bool {
        return self.moves.get(str(area) + ":" + str(move.to) + ":" + str(move.kind), -1.0) > self.now;
    }

    def take_banned(area: int, token: str) -> bool {
        return self.takes.get(str(area) + ":" + token, -1.0) > self.now;
    }

    def ban_move(step: MoveStep, until: float = 1.0e18) {
        self.moves[str(step.area) + ":" + str(step.to) + ":" + str(step.kind)] = until;
    }

    def ban_take(step: DoStep, until: float = 1.0e18) {
        self.takes[str(step.area) + ":" + step.token] = until;
    }
}

"""A level graph made ready to solve: the search's view, its places by
area, and what each place gives with the bans taken off."""
obj Solver {
    has atlas: LevelGraph,
        view: Search | None = None,
        span: int = 1,
        by_area: dict[int, Place] = {},
        # Falls (found by running a body off a ledge) are moves only a graph
        # proof takes: no router follows them.
        falls: bool = True;

    def prepare {
        if self.view is not None {
            return;
        }
        view = search_of(self.atlas);
        self.view = view;
        self.span = 1 << len(view.tokens);
        for place in graph_places(self.atlas) {
            self.by_area[place.area] = place;
        }
    }

    """What being in `area` holding `held` gives, without the tokens banned
    there."""
    def gives(area: int, held: int, bans: Bans) -> int {
        view = self.view;
        if view is None {
            return 0;
        }
        mask = view.give(area, held);
        if bans.takes {
            for index in range(len(view.tokens)) {
                if mask & (1 << index) and bans.take_banned(area, view.tokens[index]) {
                    mask &= ~(1 << index);
                }
            }
        }
        return mask;
    }

    """The plan from `area` holding `held`, the player at `origin`; a way
    out in `passed_over` does not count (one back to a level already
    played)."""
    def solve(area: int, held: int, origin: Vec3, bans: Bans = Bans(), passed_over: set[int] = set()) -> Plan {
        self.prepare();
        plan = Plan(area=area, held=held);
        view = self.view;
        if view is None or area <= 0 or area >= view.count or not view.live[area] {
            plan.reason = "standing in no place of the graph";
            return plan;
        }
        if not view.exits {
            plan.reason = "the graph has no way out";
            return plan;
        }
        span = self.span;
        # The search begins holding what this place gives too.
        begun = held | self.gives(area, held, bans);
        first = area * span + begun;
        cost: dict[int, float] = {first: 0.0};
        came: dict[int, list[int]] = {};
        heap: list[list[float]] = [[0.0, float(first)]];
        done: dict[int, bool] = {};
        goal = -1;
        nearest_gain = -1;
        popped = 0;
        while heap and popped < SOLVE_SEARCH {
            top = solve_heap_pop(heap);
            state = int(top[1]);
            if state in done {
                continue;
            }
            done[state] = True;
            popped += 1;
            at = state // span;
            mask = state % span;
            if at not in passed_over and view.out_with(at, mask) {
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
                if step[1] & mask != step[1] {
                    continue;
                }
                move = view.ways[at][index];
                if (move.fall and not self.falls) or (bans.moves and bans.move_banned(at, move)) {
                    continue;
                }
                to_place = self.by_area.get(step[0], None);
                length = 16.0;
                if from_place is not None and to_place is not None {
                    length = max(16.0, to_place.center.sub(from_place.center).length());
                }
                length = length if move.must else length * SOLVE_MAYBE_SCALE;
                if view.deadly[step[0]] {
                    length += SOLVE_DEADLY_COST;
                }
                after_mask = mask | self.gives(step[0], mask, bans);
                after = step[0] * span + after_mask;
                total = top[0] + length + (SOLVE_TOKEN_COST if after_mask != mask else 0.0);
                if after not in done and total < cost.get(after, 1.0e18) {
                    cost[after] = total;
                    came[after] = [state, at, index];
                    solve_heap_push(heap, [total, float(after)]);
                }
            }
        }
        plan.to_exit = goal >= 0;
        if goal < 0 {
            goal = nearest_gain;
        }
        if goal < 0 {
            plan.reason = "no way out from place " + str(area) + " holding [" + self.held_words(held) + "]";
            return plan;
        }
        # The states back to the start, and the tokens the way's steps want
        # (and the way out, when it wants one): only those are taken. A token
        # taken on the way and wanted by nothing (a button seen in passing)
        # is no step.
        states = [goal];
        while states[0] in came {
            states.insert(0, came[states[0]][0]);
        }
        wanted = (view.exit_bit | view.exit_wants[goal // span]) if plan.to_exit else 0;
        for at in range(1, len(states)) {
            link = came[states[at]];
            wanted |= view.maybe[link[1]][link[2]][1];
        }
        if not plan.to_exit {
            wanted |= (goal % span) & ~held;
        }
        last: Step | None = None;
        last_point = origin;
        gained = self.gives(area, held, bans) & ~held & wanted;
        for step in self.takes(gained, area, last_point) {
            last = solve_link(plan, last, step);
            last_point = step.point;
        }
        for at in range(1, len(states)) {
            link = came[states[at]];
            move = view.ways[link[1]][link[2]];
            last = solve_link(
                plan,
                last,
                MoveStep(
                    area=link[1],
                    to=move.to,
                    kind=move.kind,
                    model=move.model,
                    start=move.start,
                    finish=move.finish,
                    time=move.time,
                    must=move.must
                )
            );
            last_point = move.finish;
            gained = (states[at] % span) & ~(states[at - 1] % span) & wanted;
            for step in self.takes(gained, move.to, last_point) {
                last = solve_link(plan, last, step);
                last_point = step.point;
            }
        }
        plan.found = True;
        return plan;
    }

    """The steps that take each token of `gained` in `area`: each its
    opener done from there nearest `near`."""
    def takes(gained: int, area: int, near: Vec3) -> list[DoStep] {
        view = self.view;
        found: list[DoStep] = [];
        if view is None or gained == 0 {
            return found;
        }
        for index in range(len(view.tokens)) {
            if gained & (1 << index) == 0 {
                continue;
            }
            best: Opener | None = None;
            nearest = 1.0e18;
            for opener in graph_openers(self.atlas) {
                if opener.token != view.tokens[index] or area not in [place.area for place in opener_places(opener)] {
                    continue;
                }
                distance = opener.point.sub(near).length();
                if distance < nearest {
                    nearest = distance;
                    best = opener;
                }
            }
            if best is not None {
                found.append(DoStep(area=area, kind=best.kind, token=best.token, point=best.point, what=best.what));
            }
        }
        return found;
    }

    """The bit of `token`, 0 when the graph has none."""
    def token_bit(token: str) -> int {
        self.prepare();
        view = self.view;
        if view is None or token not in view.tokens {
            return 0;
        }
        return 1 << view.tokens.index(token);
    }

    """A holding in words: its tokens' names."""
    def held_words(held: int) -> str {
        view = self.view;
        if view is None {
            return "";
        }
        return ", ".join([view.tokens[index] for index in range(len(view.tokens)) if held & (1 << index)]);
    }
}

"""Put `step` after `last` in `plan` (first when there is none)."""
def solve_link(plan: Plan, last: Step | None, step: Step) -> Step {
    if last is None {
        plan +>:First:+> step;
    } else {
        last +>:Then:+> step;
    }
    return step;
}

"""Push onto a binary heap of [cost, state] (cheapest first)."""
def solve_heap_push(heap: list[list[float]], item: list[float]) {
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
def solve_heap_pop(heap: list[list[float]]) -> list[float] {
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
