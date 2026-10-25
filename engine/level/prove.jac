"""Proving a level graph: that the level can be finished, whatever geometry
carries the graph.

A player's state is a place and the tokens held (keys taken, gates opened);
tokens only grow. The proof searches every state the *may* moves reach from
the start, and asks of each whether the way out is reached from it over
*must* moves, taking tokens where their openers are done and passing gates
only with all they need. The level finishes when the start's state does;
a softlock is a state that does not, outside a death place (the level
begins again from a death). An arena has no way out of its own: there, the
way out is the start's own places, so no state may strand a player from the
rest of the arena.

Each token is then left out in turn: the ones the level cannot be finished
without are the ones it requires. Each place's stage is the smallest
holding of tokens it is first reached with: the level's progression."""
import from ..formats.aas { TRAVEL_ELEVATOR }
import from .graph { LevelGraph, Place, Move, Gate, Opener, Bars, Holds, graph_places, graph_gates, graph_openers, graph_tokens, opener_places, barred_places }

"""What a proof found."""
obj Proof {
    has finishes: bool = False,
        # States the possible moves reach, and those with no sure way on.
        states: int = 0,
        softlocks: int = 0,
        traps: list[str] = [],
        tokens: list[str] = [],
        required: list[str] = [],
        # The sure route from the start to the way out: areas in order, and
        # the holding at each.
        route: list[int] = [],
        holdings: list[int] = [],
        notes: list[str] = [];
}

"""The search's view of a graph: per area, the sure and possible steps
([to, tokens wanted]) and the moves they are (`ways`, beside `maybe`), what
being there gives, the death places, the starts and the ways out."""
obj Search {
    has count: int = 0,
        tokens: list[str] = [],
        sure: list[list[list[int]]] = [],
        maybe: list[list[list[int]]] = [],
        ways: list[list[Move]] = [],
        gives: list[int] = [],
        # Per area, the tokens it gives only once others are held (a
        # counter's door, opened by the last of its buttons): [bit, needs].
        gives_if: list[list[list[int]]] = [],
        deadly: list[bool] = [],
        live: list[bool] = [],
        starts: list[int] = [],
        exits: list[int] = [],
        exit_bit: int = 0,
        # Per area, the tokens its way out takes beyond being there.
        exit_wants: list[int] = [];

    """What being in `area` holding `held` gives: its tokens, and those
    whose needs its own tokens and `held` complete."""
    def give(area: int, held: int) -> int {
        got = self.gives[area];
        for round_index in range(2) {
            for pair in self.gives_if[area] {
                if pair[1] & (held | got) == pair[1] {
                    got |= pair[0];
                }
            }
        }
        return got;
    }

    """Whether `area` holding `held` is out: a way out, with the way out's
    token when the level has one and what this way out takes."""
    def out_with(area: int, held: int) -> bool {
        return area in self.exits and (self.exit_bit == 0 or held & self.exit_bit != 0) and held & self.exit_wants[area] == self.exit_wants[area];
    }
}

"""The search's view of a graph, with some tokens left out (nothing gives
them)."""
def search_of(atlas: LevelGraph, leave_out: list[str] = []) -> Search {
    view = Search();
    places = graph_places(atlas);
    count = max([place.area for place in places] + [0]) + 1;
    view.count = count;
    tokens = graph_tokens(atlas);
    view.tokens = tokens;
    view.gives = [0 for _ in range(count)];
    view.deadly = [False for _ in range(count)];
    view.live = [False for _ in range(count)];
    needs = [0 for _ in range(count)];
    lifts: dict[int, int] = {};
    view.gives_if = [[] for _ in range(count)];
    for opener in graph_openers(atlas) {
        if opener.token in leave_out {
            continue;
        }
        bit = 1 << tokens.index(opener.token);
        prior = 0;
        for need in opener.needs {
            if need in tokens {
                prior |= 1 << tokens.index(need);
            }
        }
        for place in opener_places(opener) {
            if prior {
                view.gives_if[place.area].append([bit, prior]);
            } else {
                view.gives[place.area] |= bit;
            }
        }
    }
    for gate in graph_gates(atlas) {
        mask = 0;
        for need in gate.needs {
            mask |= 1 << tokens.index(need);
        }
        lifts[gate.model] = mask;
        for place in barred_places(gate) {
            needs[place.area] |= mask;
        }
    }
    view.exit_bit = (1 << tokens.index("exit")) if "exit" in tokens else 0;
    view.exit_wants = [0 for _ in range(count)];
    view.sure = [[] for _ in range(count)];
    view.maybe = [[] for _ in range(count)];
    view.ways = [[] for _ in range(count)];
    for place in places {
        view.live[place.area] = True;
        view.deadly[place.area] = place.deadly;
        if place.start {
            view.starts.append(place.area);
        }
        if place.way_out {
            view.exits.append(place.area);
            for need in place.exit_needs {
                if need in tokens {
                    view.exit_wants[place.area] |= 1 << tokens.index(need);
                }
            }
        }
        for move in [edge place->:Move:->] {
            if move.to <= 0 or move.to >= count {
                continue;
            }
            wanted = (lifts.get(move.model, 0) if move.kind == TRAVEL_ELEVATOR else 0) | needs[move.to] | lifts.get(move.gate, 0);
            view.maybe[place.area].append([move.to, wanted]);
            view.ways[place.area].append(move);
            if move.must {
                view.sure[place.area].append([move.to, wanted]);
            }
        }
    }
    if atlas.arena {
        view.exits = list(view.starts);
    }
    return view;
}

"""How many tokens a holding has."""
def bits_of(mask: int) -> int {
    count = 0;
    while mask > 0 {
        count += mask & 1;
        mask = mask >> 1;
    }
    return count;
}

"""Prove a graph (with some tokens left out)."""
def prove(atlas: LevelGraph, leave_out: list[str] = []) -> Proof {
    proof = Proof();
    view = search_of(atlas, leave_out);
    proof.tokens = view.tokens;
    if not view.starts {
        proof.notes.append("no start");
        return proof;
    }
    if not view.exits {
        proof.notes.append("no way out");
        return proof;
    }
    span = 1 << len(view.tokens);
    start = view.starts[0];
    first = start * span + view.give(start, 0);
    seen = reach_states(view, first, span);
    proof.states = len(seen);
    good = good_states(view, seen, span);
    proof.finishes = first in good;
    for state in seen.keys() {
        area = state // span;
        if state in good or view.deadly[area] {
            continue;
        }
        proof.softlocks += 1;
        if len(proof.traps) < 8 {
            held = state % span;
            proof.traps.append(str(area) + " holding [" + ", ".join([view.tokens[index] for index in range(len(view.tokens)) if held & (1 << index)]) + "]");
        }
    }
    if proof.finishes {
        sure_route(view, first, span, proof);
    }
    return proof;
}

"""Every state the possible moves reach from `first`."""
def reach_states(view: Search, first: int, span: int) -> dict[int, bool] {
    seen: dict[int, bool] = {first: True};
    todo = [first];
    while todo {
        state = todo.pop();
        area = state // span;
        held = state % span;
        for step in view.maybe[area] {
            if step[1] & held != step[1] {
                continue;
            }
            after = step[0] * span + (held | view.give(step[0], held));
            if after not in seen {
                seen[after] = True;
                todo.append(after);
            }
        }
    }
    return seen;
}

"""The states (of those seen) from which the way out is reached over sure
moves. Larger holdings first: a sure move into a place that gives more
leads to a holding already settled."""
def good_states(view: Search, seen: dict[int, bool], span: int) -> dict[int, bool] {
    masks: list[int] = [];
    for state in seen.keys() {
        held = state % span;
        if held in masks {
            continue;
        }
        at = len(masks);
        while at > 0 and bits_of(masks[at - 1]) < bits_of(held) {
            at -= 1;
        }
        masks.insert(at, held);
    }
    good: dict[int, bool] = {};
    for held in masks {
        frontier: list[int] = [];
        for area in range(view.count) {
            if not view.live[area] {
                continue;
            }
            if view.out_with(area, held) {
                frontier.append(area);
                continue;
            }
            for step in view.sure[area] {
                gained = held | view.give(step[0], held);
                if step[1] & held == step[1] and gained != held and (step[0] * span + gained) in good {
                    frontier.append(area);
                    break;
                }
            }
        }
        reached: dict[int, bool] = {};
        for area in frontier {
            reached[area] = True;
        }
        backward: list[list[int]] = [[] for _ in range(view.count)];
        for area in range(view.count) {
            for step in view.sure[area] {
                if step[1] & held == step[1] and view.give(step[0], held) | held == held {
                    backward[step[0]].append(area);
                }
            }
        }
        while frontier {
            area = frontier.pop();
            for before in backward[area] {
                if before not in reached {
                    reached[before] = True;
                    frontier.append(before);
                }
            }
        }
        for area in reached.keys() {
            good[area * span + held] = True;
        }
    }
    return good;
}

"""The shortest sure route from the start to the way out, tokens gathered
on the way (breadth first over states)."""
def sure_route(view: Search, first: int, span: int, proof: Proof) {
    came: dict[int, int] = {first: -1};
    todo = [first];
    at = 0;
    goal = -1;
    while at < len(todo) {
        state = todo[at];
        at += 1;
        area = state // span;
        mask = state % span;
        if view.out_with(area, mask) {
            goal = state;
            break;
        }
        for step in view.sure[area] {
            if step[1] & mask != step[1] {
                continue;
            }
            after = step[0] * span + (mask | view.give(step[0], mask));
            if after not in came {
                came[after] = state;
                todo.append(after);
            }
        }
    }
    while goal >= 0 {
        proof.route.insert(0, goal // span);
        proof.holdings.insert(0, goal % span);
        goal = came[goal];
    }
}

"""A few lines on why a proof failed: where the states that strand a
player are (and what kind of place), and the ways the search found barred
from what the start reaches."""
def explain_proof(atlas: LevelGraph, proof: Proof) -> list[str] {
    lines: list[str] = [];
    by_area: dict[int, Place] = {};
    for place in graph_places(atlas) {
        by_area[place.area] = place;
    }
    # The first trap: what it reaches for sure, and the possible-only moves
    # out of that (what the level would need to be sure of).
    if proof.traps {
        view = search_of(atlas);
        span = 1 << len(view.tokens);
        words = proof.traps[0].split(" ");
        trap_area = int(words[0]);
        held = 0;
        inner = proof.traps[0][proof.traps[0].index("[") + 1:proof.traps[0].index("]")];
        for name in inner.split(", ") {
            if name in view.tokens {
                held |= 1 << view.tokens.index(name);
            }
        }
        closure: dict[int, bool] = {trap_area * span + held: True};
        todo = [trap_area * span + held];
        while todo {
            state = todo.pop();
            area = state // span;
            have = state % span;
            for step in view.sure[area] {
                if step[1] & have == step[1] {
                    after = step[0] * span + (have | view.give(step[0], have));
                    if after not in closure {
                        closure[after] = True;
                        todo.append(after);
                    }
                }
            }
        }
        inside = set([state // span for state in closure.keys()]);
        lines.append("first trap reaches " + str(len(inside)) + " places for sure");
        entered = 0;
        for place in graph_places(atlas) {
            if place.area in inside {
                continue;
            }
            for move in [edge place->:Move:->] {
                if move.to in inside and entered < 4 {
                    entered += 1;
                    lines.append(
                        "  entered by " + str(place.area) + " -> " + str(move.to) + " kind " + str(move.kind) + (" sure" if move.must else " possible")
                            + " at " + str(int(move.start.x)) + "," + str(int(move.start.y)) + "," + str(int(move.start.z)) + " to "
                            + str(int(move.finish.x)) + "," + str(int(move.finish.y)) + "," + str(int(move.finish.z))
                    );
                }
            }
        }
        shown = 0;
        for area in inside {
            place = by_area.get(area, None);
            if place is None {
                continue;
            }
            for move in [edge place->:Move:->] {
                if move.to not in inside and shown < 5 {
                    shown += 1;
                    barring = "";
                    target = by_area.get(move.to, None);
                    if target is not None {
                        for gate in [target<-:Bars:<-][?:Gate] {
                            barring += " barred by " + gate.kind + " " + str(gate.model) + " wanting " + ",".join(gate.needs) + " moving "
                                + str(int(gate.motion.x)) + "," + str(int(gate.motion.y)) + "," + str(int(gate.motion.z)) + " box z "
                                + str(int(gate.box.mins.z)) + ".." + str(int(gate.box.maxs.z));
                        }
                    }
                    lines.append(
                        "  left by " + str(area) + " -> " + str(move.to) + " kind " + str(move.kind) + (" sure" if move.must else " possible")
                            + " at " + str(int(move.start.x)) + "," + str(int(move.start.y)) + "," + str(int(move.start.z)) + " to "
                            + str(int(move.finish.x)) + "," + str(int(move.finish.y)) + "," + str(int(move.finish.z)) + barring
                    );
                }
            }
        }
    }
    for trap in proof.traps[:3] {
        area = int(trap.split(" ")[0]);
        place = by_area.get(area, None);
        if place is None {
            continue;
        }
        lines.append(
            "trap at " + str(int(place.center.x)) + "," + str(int(place.center.y)) + "," + str(int(place.floor)) + " liquid "
                + str(place.liquid) + " " + trap + " moves "
                + " ".join([str(move.to) + ":" + str(move.kind) + ("" if move.must else "?") for move in [edge place->:Move:->]])
        );
    }
    if not proof.finishes {
        view = search_of(atlas);
        if view.starts {
            span = 1 << len(view.tokens);
            start = view.starts[0];
            seen = reach_states(view, start * span + view.give(start, 0), span);
            areas = set([state // span for state in seen.keys()]);
            lines.append("from the start " + str(len(areas)) + " of " + str(len(by_area)) + " places reached; ways out at " + str(view.exits[:4]));
            # The edge of what the start reaches for sure (tokens taken on
            # the way): the possible moves that leave it.
            sure_seen: dict[int, bool] = {start * span + view.give(start, 0): True};
            todo = [start * span + view.give(start, 0)];
            while todo {
                state = todo.pop();
                area = state // span;
                held = state % span;
                for step in view.sure[area] {
                    if step[1] & held == step[1] {
                        after = step[0] * span + (held | view.give(step[0], held));
                        if after not in sure_seen {
                            sure_seen[after] = True;
                            todo.append(after);
                        }
                    }
                }
            }
            sure_areas = set([state // span for state in sure_seen.keys()]);
            leaving = 0;
            for area in sure_areas {
                place = by_area.get(area, None);
                if place is None {
                    continue;
                }
                for move in [edge place->:Move:->] {
                    if move.to not in sure_areas and leaving < 6 {
                        leaving += 1;
                        lines.append(
                            "sure region (" + str(len(sure_areas)) + " places) left only by " + str(area) + " -> " + str(move.to) + " kind "
                                + str(move.kind) + (" sure" if move.must else " possible") + " from " + str(int(move.start.x)) + ","
                                + str(int(move.start.y)) + "," + str(int(move.start.z)) + " to " + str(int(move.finish.x)) + ","
                                + str(int(move.finish.y)) + "," + str(int(move.finish.z))
                        );
                    }
                }
            }
            wanted: list[str] = [];
            for state in seen.keys() {
                area = state // span;
                held = state % span;
                for step in view.maybe[area] {
                    if step[1] & held != step[1] {
                        for index in range(len(view.tokens)) {
                            if step[1] & ~held & (1 << index) and view.tokens[index] not in wanted {
                                wanted.append(view.tokens[index]);
                            }
                        }
                    }
                }
            }
            for token in wanted[:6] {
                where: list[str] = [];
                for opener in graph_openers(atlas) {
                    if opener.token == token {
                        done = [place.area for place in opener_places(opener)];
                        where.append(opener.kind + " at " + str(int(opener.point.x)) + "," + str(int(opener.point.y)) + "," + str(int(opener.point.z)) + " from " + str(done[:4]) + " reached " + str(len([area for area in done if area in areas])));
                    }
                }
                lines.append("wanted " + token + ": " + ("; ".join(where) if where else "nothing gives it"));
            }
        }
    }
    return lines;
}

"""Prove a graph in full: the proof, the tokens it requires (each left out
in turn; a proof a token, so only when `required`), and each place's stage
written onto it."""
def prove_level(atlas: LevelGraph, required: bool = True) -> Proof {
    proof = prove(atlas);
    if proof.finishes and required {
        for token in proof.tokens {
            if not prove(atlas, [token]).finishes {
                proof.required.append(token);
            }
        }
    }
    mark_stages(atlas);
    return proof;
}

"""Each place's stage: the smallest holding (fewest tokens) any reachable
state has it with; -1 where nothing reaches."""
def mark_stages(atlas: LevelGraph) {
    view = search_of(atlas);
    if not view.starts {
        return;
    }
    span = 1 << len(view.tokens);
    start = view.starts[0];
    seen = reach_states(view, start * span + view.give(start, 0), span);
    best: dict[int, int] = {};
    for state in seen.keys() {
        area = state // span;
        held = state % span;
        if area not in best or bits_of(held) < bits_of(best[area]) {
            best[area] = held;
        }
    }
    for place in graph_places(atlas) {
        place.stage = best.get(place.area, -1);
    }
}

"""Prune a graph that finishes but strands a player somewhere: the places
no reachable state can ever leave for the way out (pits, pockets, ledges
fallen to), when nothing needs them (no opener is done there, it is not the
start nor a way out, and no body dies there) are taken out, with the ways
into them; again until the graph proves clean or nothing more goes.
Answers how many places went. A level made from the graph has none of
them: no pocket to fall into."""
def prune_traps(atlas: LevelGraph, rounds: int = 4) -> int {
    removed = 0;
    for round_index in range(rounds) {
        proof = prove(atlas);
        if not proof.finishes or proof.softlocks == 0 {
            break;
        }
        view = search_of(atlas);
        span = 1 << len(view.tokens);
        start = view.starts[0];
        first = start * span + view.give(start, 0);
        seen = reach_states(view, first, span);
        good = good_states(view, seen, span);
        alive: dict[int, bool] = {};
        reached: dict[int, bool] = {};
        for state in seen.keys() {
            area = state // span;
            reached[area] = True;
            if state in good {
                alive[area] = True;
            }
        }
        dead: dict[int, bool] = {};
        for area in reached.keys() {
            if area in alive or view.deadly[area] or view.gives[area] != 0 or view.gives_if[area] or area in view.starts or area in view.exits {
                continue;
            }
            dead[area] = True;
        }
        if not dead {
            break;
        }
        for place in graph_places(atlas) {
            if place.area in dead {
                atlas del->:Holds:-> place;
                continue;
            }
            for target in [place->:Move:->][?:Place] {
                if target.area in dead {
                    place del->:Move:-> target;
                }
            }
        }
        removed += len(dead);
    }
    if removed {
        atlas.notes.append("pruned " + str(removed) + " places no one gets out of");
    }
    return removed;
}