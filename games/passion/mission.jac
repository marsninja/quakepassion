"""Cyclic mission grammar: objectives, locks, valves and loops before any space.

The expedition begins as start -> sections -> gate -> goal. Every section is a
cycle pattern (after Dormans' cyclic dungeon generation) whose arcs are later
expanded into chains or nested cycles. Links carry the tokens they need, and
beats grant tokens, so one state-space search proves each mission completable
and free of softlocks regardless of which patterns were combined.
"""
import from .random { Stream }

node Expedition {
    has seed: int,
        version: int = 2,
        archetype: str = "keys",
        briefing: str = "",
        niche: list[int] = [],
        descriptors: list[float] = [],
        quality: float = 0.0,
        candidate: int = 0,
        objectives: list[str] = [],
        route: list[int] = [],
        sections: int = 1,
        verticality: float = 0.5,
        density: float = 0.5,
        loopiness: float = 0.5,
        districts: list[int] = [];
}

node Beat {
    has id: int,
        kind: str = "room",
        size: int = 1,
        section: int = 0,
        district: int = 0,
        grants: list[str] = [],
        optional: bool = False,
        order: int = -1,
        depth: int = -1,
        tension: float = 0.0,
        encounter: str = "",
        pattern: str = "";
}

edge Holds: Expedition --> Beat {}

# mode: open | valve (one-way head->tail) | locked | shortcut | secret | window | gate
edge Link: Beat --> Beat {
    has id: int = 0,
        mode: str = "open",
        needs: list[str] = [],
        chain: int = 0,
        danger: float = 0.0,
        tail: int = 0,
        head: int = 0;
}

walker Reach {
    has tokens: list[str] = [],
        visited: list[int] = [];

    can reach with Beat entry {
        if here.id in self.visited {
            return;
        }
        self.visited.append(here.id);
        links = [edge here->:Link:->];
        heads = [here->:Link:->][?:Beat];
        for index in range(len(links)) {
            if passable(links[index], self.tokens) {
                visit [heads[index]];
            }
        }
        back_links = [edge here<-:Link:<-];
        tails = [here<-:Link:<-][?:Beat];
        for index in range(len(back_links)) {
            link = back_links[index];
            if link.mode not in ["valve", "window"] and passable(link, self.tokens) {
                visit [tails[index]];
            }
        }
    }
}

def passable(link: Link, tokens: list[str]) -> bool {
    if link.mode == "window" {
        return False;
    }
    for token in link.needs {
        if token not in tokens {
            return False;
        }
    }
    return True;
}

obj Grammar {
    has plan: Expedition,
        stream: Stream,
        beats: list[Beat] = [],
        links: int = 0,
        keys: list[str] = [],
        nesting: int = 2,
        switches: int = 0;

    def beat(kind: str, size: int = 1, section: int = 0) -> Beat {
        made = Beat(id=len(self.beats), kind=kind, size=size, section=section);
        self.plan +>:Holds:+> made;
        self.beats.append(made);
        return made;
    }

    def link(
        tail: Beat,
        head: Beat,
        mode: str = "open",
        needs: list[str] = [],
        chain: int = 0,
        danger: float = 0.0
    ) -> Link {
        self.links += 1;
        tail +>:Link(
            id=self.links,
            mode=mode,
            needs=needs,
            chain=chain,
            danger=danger,
            tail=tail.id,
            head=head.id
        ):+> head;
        return [edge tail->:Link:->][-1];
    }

    def take_key -> str {
        if not self.keys {
            return "";
        }
        return self.keys.pop(0);
    }

    def objective(kind: str, section: int, archetype_token: str) -> Beat {
        room = self.beat(kind, 2 if kind != "guardian" else 3, section);
        if archetype_token {
            room.grants.append(archetype_token);
        }
        return room;
    }
}

def links_of(plan: Expedition) -> list[Link] {
    result: list[Link] = [];
    for beat in beats_of(plan) {
        result.extend([edge beat->:Link:->]);
    }
    return result;
}

def beats_of(plan: Expedition) -> list[Beat] {
    found = [plan->:Holds:->][?:Beat];
    by_id: dict[int, Beat] = {};
    for beat in found {
        by_id[beat.id] = beat;
    }
    return [by_id[index] for index in range(len(found))];
}

def neighbors_of(beat: Beat) -> list[Beat] {
    result: list[Beat] = [];
    for other in [beat->:Link:->][?:Beat] + [beat<-:Link:<-][?:Beat] {
        if other not in result {
            result.append(other);
        }
    }
    return result;
}

# ---------------------------------------------------------------------------
# Section patterns. Each connects entry e to exit x and may host an objective.
# Arcs are Links with chain > 0; they expand into rooms or nested cycles later.
# ---------------------------------------------------------------------------

def pattern_alternatives(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    short = g.stream.between(1, 2);
    long = short + g.stream.between(1, 3);
    if host {
        goal = g.objective(host, x.section, token);
        g.link(e, goal, chain=short, danger=0.9);
        g.link(goal, x, chain=1);
        g.link(e, x, chain=long, danger=0.3);
    } else {
        g.link(e, x, chain=short, danger=0.9);
        g.link(e, x, chain=long, danger=0.3);
    }
    e.pattern = "alternatives";
}

def pattern_lock_key(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    key = g.take_key();
    if not key {
        pattern_alternatives(g, e, x, host, token);
        return;
    }
    landing = g.beat("junction", 1, x.section);
    vault = g.beat("key", 2, x.section);
    vault.grants.append(key);
    if host {
        goal = g.objective(host, x.section, token);
        g.link(landing, goal, "locked", [key]);
        g.link(goal, x, chain=1);
    } else {
        g.link(landing, x, "locked", [key]);
    }
    g.link(e, landing, chain=g.stream.between(1, 2));
    g.link(e, vault, chain=g.stream.between(1, 3), danger=0.7);
    # The key route returns over a ledge beside the lock it opens.
    g.link(vault, landing, "valve", chain=g.stream.between(0, 1));
    e.pattern = "lock_key";
}

def pattern_far_key(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    key = g.take_key();
    if not key {
        pattern_shortcut(g, e, x, host, token);
        return;
    }
    vault = g.beat("key", 2, x.section);
    vault.grants.append(key);
    g.link(e, vault, chain=g.stream.between(2, 4), danger=0.6);
    g.link(vault, e, "valve", chain=g.stream.between(0, 1));
    if host {
        goal = g.objective(host, x.section, token);
        g.link(e, goal, "locked", [key]);
        g.link(goal, x, chain=1);
    } else {
        g.link(e, x, "locked", [key], chain=0);
    }
    e.pattern = "far_key";
}

def pattern_shortcut(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    target = x;
    if host {
        target = g.objective(host, x.section, token);
        g.link(target, x, chain=1);
    }
    g.link(e, target, chain=g.stream.between(2, 4), danger=0.5);
    back = g.link(e, target, "shortcut");
    back.needs = ["open:" + str(back.id)];
    target.grants.append("open:" + str(back.id));
    e.pattern = "shortcut";
}

def pattern_hidden(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    target = x;
    if host {
        target = g.objective(host, x.section, token);
        g.link(target, x, chain=1);
    }
    g.link(e, target, chain=g.stream.between(2, 4), danger=0.5);
    g.link(e, target, "secret");
    e.pattern = "hidden";
}

def pattern_foreshadow(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    target = x;
    if host {
        target = g.objective(host, x.section, token);
        g.link(target, x, chain=1);
    }
    g.link(e, target, chain=g.stream.between(2, 4), danger=0.6);
    g.link(e, target, "window");
    e.pattern = "foreshadow";
}

def pattern_switch(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    g.switches += 1;
    toggle = "switch:" + str(g.switches);
    station = g.beat("switch", 2, x.section);
    station.grants.append(toggle);
    g.link(e, station, chain=g.stream.between(1, 3), danger=0.6);
    g.link(station, e, "valve", chain=g.stream.between(0, 1));
    if host {
        goal = g.objective(host, x.section, token);
        g.link(e, goal, "locked", [toggle]);
        g.link(goal, x, chain=1);
    } else {
        g.link(e, x, "locked", [toggle]);
    }
    e.pattern = "switch";
}

def pattern_gambit(g: Grammar, e: Beat, x: Beat, host: str, token: str) {
    reward = g.beat("arena", 3, x.section);
    reward.optional = True;
    if host {
        goal = g.objective(host, x.section, token);
        g.link(e, goal, chain=g.stream.between(1, 3));
        g.link(goal, x, chain=1);
    } else {
        g.link(e, x, chain=g.stream.between(1, 3));
    }
    g.link(e, reward, chain=g.stream.between(0, 1), danger=1.0);
    g.link(reward, x, chain=g.stream.between(0, 1));
    e.pattern = "gambit";
}

glob PATTERNS: list[str] = [
         "alternatives",
         "lock_key",
         "far_key",
         "shortcut",
         "hidden",
         "foreshadow",
         "switch",
         "gambit"
     ];

def apply_pattern(g: Grammar, name: str, e: Beat, x: Beat, host: str, token: str) {
    if name == "alternatives" {
        pattern_alternatives(g, e, x, host, token);
    } elif name == "lock_key" {
        pattern_lock_key(g, e, x, host, token);
    } elif name == "far_key" {
        pattern_far_key(g, e, x, host, token);
    } elif name == "shortcut" {
        pattern_shortcut(g, e, x, host, token);
    } elif name == "hidden" {
        pattern_hidden(g, e, x, host, token);
    } elif name == "foreshadow" {
        pattern_foreshadow(g, e, x, host, token);
    } elif name == "switch" {
        pattern_switch(g, e, x, host, token);
    } else {
        pattern_gambit(g, e, x, host, token);
    }
}

# Nested cycles replace long arcs. Only token-free patterns nest, so nesting
# never introduces a lock whose key sits outside the enclosing section.
def expand_arc(g: Grammar, link: Link, tail: Beat, head: Beat, loopiness: float) {
    count = link.chain;
    mode = link.mode;
    needs = list(link.needs);
    danger = link.danger;
    del link;
    section = max(tail.section, head.section) if mode != "valve" else tail.section;
    if count >= 4 and g.nesting > 0 and g.stream.chance(loopiness) {
        g.nesting -= 1;
        opening = g.beat("junction", 1, section);
        closing = g.beat("hub" if g.stream.chance(0.5) else "junction", 2, section);
        choice = g.stream.below(3);
        if choice == 0 {
            g.link(opening, closing, chain=1, danger=0.9);
            g.link(opening, closing, chain=count - 3, danger=0.3);
            opening.pattern = "alternatives";
        } elif choice == 1 {
            g.link(opening, closing, chain=count - 2, danger=0.5);
            back = g.link(opening, closing, "shortcut");
            back.needs = ["open:" + str(back.id)];
            closing.grants.append("open:" + str(back.id));
            opening.pattern = "shortcut";
        } else {
            g.link(opening, closing, chain=count - 2, danger=0.5);
            g.link(opening, closing, "secret");
            opening.pattern = "hidden";
        }
        g.link(tail, opening, danger=danger);
        g.link(closing, head, mode, needs, 0, danger);
        return;
    }
    previous = tail;
    for index in range(count) {
        kind = "room";
        roll = g.stream.unit();
        if roll < 0.12 {
            kind = "recovery";
        } elif roll < 0.3 {
            kind = "arena";
        } elif roll < 0.4 {
            kind = "hub";
        }
        size = 3
            if kind in ["arena", "hub"]
            else (0 if kind == "recovery" else 1 + g.stream.below(2));
        room = g.beat(kind, size, section);
        g.link(previous, room, danger=danger);
        previous = room;
    }
    g.link(previous, head, mode, needs, 0, danger);
}

def pending_arcs(g: Grammar) -> list[Link] {
    return [
        link
        for link in links_of(g.plan)
        if link.chain > 0
    ];
}

def endpoints(g: Grammar, link: Link) -> list[Beat] {
    return [g.beats[link.tail], g.beats[link.head]];
}

glob KEY_TYPES: list[str] = [
         "key_silver",
         "key_gold",
         "key_blue_key",
         "key_red_key"
     ];

def objective_tokens(archetype: str, count: int) -> list[str] {
    tokens: list[str] = [];
    for index in range(count) {
        if archetype == "keys" {
            tokens.append(KEY_TYPES[index]);
        } elif archetype == "relays" {
            tokens.append("relay:" + str(index + 1));
        } elif archetype == "guardian" {
            tokens.append("guardian:" + str(index + 1));
        } else {
            tokens.append(
                KEY_TYPES[index] if index % 2 == 0 else "guardian:" + str(index + 1)
            );
        }
    }
    return tokens;
}

def objective_kind(token: str) -> str {
    if token.startswith("key_") {
        return "key";
    }
    if token.startswith("relay:") {
        return "switch";
    }
    return "guardian";
}

# Descriptor targets steer the grammar; the selector then measures the result.
def build_mission(
    seed: int,
    stream: Stream,
    archetype: str,
    objectives: int,
    sections: int,
    rooms: int,
    loopiness: float
) -> Expedition {
    plan = Expedition(
        seed=seed, archetype=archetype, sections=sections, loopiness=loopiness
    );
    tokens = objective_tokens(archetype, objectives);
    plan.objectives = tokens;
    used_keys = [
        token
        for token in tokens
        if token.startswith("key_")
    ];
    g = Grammar(
        plan=plan,
        stream=stream,
        keys=[
            key
            for key in KEY_TYPES
            if key not in used_keys
        ],
        nesting=1 + int(loopiness * 2.5)
    );
    start = g.beat("start", 1, 0);
    opening = start;
    hosts: list[int] = [];
    # Spread objectives over sections, latest objective in the last section.
    for index in range(len(tokens)) {
        hosts.append(min(sections - 1, (index * sections) // max(1, len(tokens))));
    }
    if tokens {
        hosts[-1] = sections - 1;
    }
    for section in range(sections) {
        closing = g.beat("hub" if section < sections - 1 else "junction", 2, section);
        hosted = [
            index
            for index in range(len(tokens))
            if hosts[index] == section
        ];
        weights: list[float] = [];
        for name in PATTERNS {
            weight = 1.0;
            if name in ["lock_key", "far_key", "switch"] {
                weight = 0.6 + loopiness;
            } elif name == "alternatives" {
                weight = 0.5 + loopiness;
            } elif name == "gambit" {
                weight = 0.3 + loopiness * 0.5;
            } elif name in ["shortcut", "hidden"] {
                weight = 0.8;
            } elif name == "foreshadow" {
                weight = 0.6;
            }
            if name == "switch" and archetype == "relays" {
                weight = 0.2;
            }
            weights.append(weight);
        }
        name = PATTERNS[g.stream.weighted(weights)];
        host = objective_kind(tokens[hosted[0]]) if hosted else "";
        apply_pattern(
            g, name, opening, closing, host, tokens[hosted[0]] if hosted else ""
        );
        # A second objective in one section hangs off the exit as a side branch.
        for extra in hosted[1:] {
            side = g.objective(objective_kind(tokens[extra]), section, tokens[extra]);
            g.link(closing, side, chain=g.stream.between(1, 2), danger=0.8);
        }
        opening = closing;
    }
    goal = g.beat("goal", 1, sections - 1);
    g.link(opening, goal, "gate", list(tokens));
    # Spend the remaining room budget on arc lengths, then expand every arc.
    arcs = pending_arcs(g);
    remaining = rooms - len(g.beats) - sum([arc.chain for arc in arcs]);
    while remaining > 0 and arcs {
        arc = arcs[g.stream.below(len(arcs))];
        if arc.mode == "valve" and arc.chain >= 2 {
            remaining -= 1;
            continue;
        }
        arc.chain += 1;
        remaining -= 1;
    }
    guard = 0;
    arcs = pending_arcs(g);
    while arcs and guard < 200 {
        guard += 1;
        arc = arcs[0];
        ends = endpoints(g, arc);
        expand_arc(g, arc, ends[0], ends[1], loopiness);
        arcs = pending_arcs(g);
    }
    decorate(g, loopiness);
    annotate(plan);
    validate_mission(plan);
    return plan;
}

# Optional side content: secret caches, dead-end rewards and vistas.
def:priv decorate(g: Grammar, loopiness: float) {
    candidates = [
        beat
        for beat in g.beats
        if beat.kind in ["room", "junction", "hub", "arena", "recovery"]
    ];
    secrets = 1 + g.stream.below(3);
    for index in range(secrets) {
        if not candidates {
            break;
        }
        parent = candidates[g.stream.below(len(candidates))];
        cache = g.beat("cache", 0, parent.section);
        cache.optional = True;
        cache.grants.append("secret:" + str(index + 1));
        g.link(parent, cache, "secret");
    }
    sides = g.stream.between(0, 2 + int((1.0 - loopiness) * 2.0));
    for index in range(sides) {
        parent = candidates[g.stream.below(len(candidates))];
        side = g.beat(
            "recovery" if g.stream.chance(0.5) else "vista", 1, parent.section
        );
        side.optional = True;
        g.link(parent, side);
    }
}

# Progression order approximates the intended first-visit sequence: flood what
# is open, collect every token found, repeat. Tension then follows that order.
def annotate(plan: Expedition) {
    all_beats = beats_of(plan);
    start = all_beats[0];
    tokens: list[str] = [];
    order = 0;
    route: list[int] = [];
    for round in range(64) {
        reach = start spawn Reach(tokens=tokens);
        # Breadth order within the round: distances from the start over open links.
        distances = distances_from(plan, start.id, tokens);
        fresh = [
            beat
            for beat in all_beats
            if beat.id in reach.visited and beat.order < 0
        ];
        fresh = by_distance(fresh, distances);
        for beat in fresh {
            beat.order = order;
            beat.depth = distances[beat.id];
            order += 1;
            if not beat.optional {
                route.append(beat.id);
            }
        }
        gained = False;
        for beat in all_beats {
            if beat.id in reach.visited {
                for token in beat.grants {
                    if token not in tokens {
                        tokens.append(token);
                        gained = True;
                    }
                }
            }
        }
        if not gained {
            break;
        }
    }
    plan.route = route;
    total = max(1, order - 1);
    for beat in all_beats {
        t = float(max(0, beat.order)) / float(total);
        # Rising action with three swells; the finale sits at the top.
        swell = 0.5 + 0.5 * math_sin(t * 3.0 * 6.2831853 - 1.5707963);
        tension = 0.25 + 0.45 * t + 0.25 * swell;
        if beat.kind in ["arena", "guardian"] {
            tension += 0.25;
        } elif beat.kind in ["recovery", "vista", "start"] {
            tension = 0.1;
        } elif beat.kind == "cache" {
            tension = 0.35;
        } elif beat.kind in ["key", "switch"] {
            tension += 0.15;
        } elif beat.kind == "goal" {
            tension = 0.0;
        }
        beat.tension = max(0.0, min(1.0, tension));
    }
}

def by_distance(items: list[Beat], distances: dict[int, int]) -> list[Beat] {
    result: list[Beat] = [];
    for beat in items {
        position = len(result);
        while position > 0
            and distances[result[position - 1].id] > distances[beat.id] {
            position -= 1;
        }
        result.insert(position, beat);
    }
    return result;
}

def math_sin(value: float) -> float {
    # Range-reduced Taylor series keeps this module free of float libm variance.
    two_pi = 6.283185307179586;
    x = value - two_pi * float(int(value / two_pi));
    if x > 3.141592653589793 {
        x -= two_pi;
    }
    if x < -3.141592653589793 {
        x += two_pi;
    }
    term = x;
    total = x;
    for n in range(1, 9) {
        term = -term * x * x / float((2 * n) * (2 * n + 1));
        total += term;
    }
    return total;
}

def distances_from(plan: Expedition, first: int, tokens: list[str]) -> dict[int, int] {
    all_beats = beats_of(plan);
    result: dict[int, int] = {first: 0};
    queue = [first];
    cursor = 0;
    while cursor < len(queue) {
        current = all_beats[queue[cursor]];
        cursor += 1;
        for step in moves(current, tokens) {
            if step not in result {
                result[step] = result[current.id] + 1;
                queue.append(step);
            }
        }
    }
    return result;
}

def moves(beat: Beat, tokens: list[str]) -> list[int] {
    result: list[int] = [];
    for link in [edge beat->:Link:->] {
        if passable(link, tokens) {
            result.append(link.head);
        }
    }
    for link in [edge beat<-:Link:<-] {
        if link.mode not in ["valve", "window"] and passable(link, tokens) {
            result.append(link.tail);
        }
    }
    return result;
}

def grant_mask(universe: list[str], mask: int, beat: Beat) -> int {
    for token in beat.grants {
        mask = mask | (1 << universe.index(token));
    }
    return mask;
}

# Exhaustive (beat, token-set) search: the goal must be reachable, and no
# reachable state may lose the ability to reach it (no softlocks).
def validate_mission(plan: Expedition) {
    all_beats = beats_of(plan);
    universe: list[str] = [];
    for beat in all_beats {
        for token in beat.grants {
            if token not in universe {
                universe.append(token);
            }
        }
    }
    for link in links_of(plan) {
        for token in link.needs {
            assert token in universe , "Mission needs an ungranted token: " + token;
        }
    }
    assert len(universe) <= 16 , "Mission token space too large";
    goal = [
        beat
        for beat in all_beats
        if beat.kind == "goal"
    ];
    assert len(goal) == 1 , "Mission needs exactly one goal";
    states: dict[int, int] = {};
    order: list[int] = [];
    edges_from: list[list[int]] = [];
    width = 1 << len(universe);

    first = grant_mask(universe, 0, all_beats[0]);
    states[first] = 0;
    order.append(first);
    edges_from.append([]);
    cursor = 0;
    while cursor < len(order) {
        state = order[cursor];
        beat = all_beats[state // width];
        mask = state % width;
        held = [
            universe[bit]
            for bit in range(len(universe))
            if mask & (1 << bit)
        ];
        for step in moves(beat, held) {
            nxt = step * width + grant_mask(universe, mask, all_beats[step]);
            if nxt not in states {
                states[nxt] = len(order);
                order.append(nxt);
                edges_from.append([]);
            }
            edges_from[cursor].append(states[nxt]);
        }
        cursor += 1;
        assert len(order) < 200000 , "Mission state space exploded";
    }
    # Reverse search from every goal state.
    incoming: list[list[int]] = [[] for _ in order];
    for index in range(len(order)) {
        for other in edges_from[index] {
            incoming[other].append(index);
        }
    }
    good: list[bool] = [False for _ in order];
    queue: list[int] = [];
    for index in range(len(order)) {
        if order[index] // width == goal[0].id {
            good[index] = True;
            queue.append(index);
        }
    }
    assert queue , "Mission goal is unreachable";
    cursor = 0;
    while cursor < len(queue) {
        for other in incoming[queue[cursor]] {
            if not good[other] {
                good[other] = True;
                queue.append(other);
            }
        }
        cursor += 1;
    }
    visited_beats: list[bool] = [False for _ in all_beats];
    for index in range(len(order)) {
        assert good[index] , "Mission softlock at beat " + str(order[index] // width);
        visited_beats[order[index] // width] = True;
    }
    for beat in all_beats {
        assert visited_beats[beat.id] , "Mission beat unreachable: " + str(beat.id);
    }
}
