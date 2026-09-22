"""Deterministic mission graph, independent of assets and runtime geometry."""
edge Contains: Expedition --> Chamber {}
edge Passage: Chamber --> Chamber {}
node Expedition {
    has seed: int, version: int = 1, key_rooms: list[int] = [];
}
node Chamber {
    has index: int, x: int, y: int, theme: int = 0,
        shape: int = 0, role: str = "encounter", distance: int = -1;
}
obj RandomStream {
    has state: int;
    def choose(limit: int) -> int {
        if limit <= 0 { raise ValueError("Empty random choice"); }
        self.state = (self.state * 48271) % 2147483647;
        return self.state % limit;
    }
}
walker Explore {
    has visited: list[int] = [], blocked: int = -1;
    can reach with Chamber entry {
        if here.index == self.blocked or here.index in self.visited { return; }
        self.visited.append(here.index);
        visit [here->:Passage:->];
    }
}

def seed_from(name: str) -> int {
    if not name.startswith("v1-") { raise ValueError("Expected expedition v1-SEED"); }
    seed = int(name[3:]);
    if seed < 1 or seed > 2147483646 or name != "v1-" + str(seed) {
        raise ValueError("Seed must be 1..2147483646");
    }
    return seed;
}

def adjacent(a: Chamber, b: Chamber) -> bool {
    return abs(a.x - b.x) + abs(a.y - b.y) == 1;
}

def link(a: Chamber, b: Chamber) {
    a +>:Passage:+> b;
    b +>:Passage:+> a;
}

def make_plan(seed: int) -> Expedition {
    seed_from("v1-" + str(seed));
    plan = Expedition(seed=seed);
    layout = RandomStream(state=seed);
    decoration = RandomStream(state=(seed + 104729) % 2147483646 + 1);
    rooms: list[Chamber] = [];
    zone = decoration.choose(3);
    for index in range(20) {
        room = Chamber(index=index, x=index % 5, y=index // 5,
            theme=(index % 5 // 2 + zone) % 3, shape=decoration.choose(3));
        plan +>:Contains:+> room;
        rooms.append(room);
    }
    rooms[0].role = "arrival";
    rooms[0].distance = 0;
    rooms[19].role = "extraction";
    reached = [0];
    while len(reached) < 19 {
        sources: list[int] = [];
        destinations: list[int] = [];
        for a in reached {
            for b in range(19) {
                if b not in reached and adjacent(rooms[a], rooms[b]) {
                    sources.append(a); destinations.append(b);
                }
            }
        }
        selected = layout.choose(len(sources));
        a = sources[selected]; b = destinations[selected];
        link(rooms[a], rooms[b]);
        rooms[b].distance = rooms[a].distance + 1;
        reached.append(b);
    }
    # A leaf extraction chamber ensures every route crosses the objective gate.
    parent = 14 if layout.choose(2) == 0 else 18;
    link(rooms[parent], rooms[19]);
    loops = 0;
    for a in range(19) {
        for b in range(a + 1, 19) {
            if adjacent(rooms[a], rooms[b]) and rooms[b] not in [rooms[a]->:Passage:->]
                and (layout.choose(3) == 0 or loops < 2) {
                link(rooms[a], rooms[b]); loops += 1;
            }
        }
    }
    for room in rooms {
        room.distance = len(route(plan, 0, room.index)) - 1;
    }
    for key in range(2) {
        best = 1;
        best_score = -1;
        for index in range(1, 19) {
            score = rooms[index].distance;
            if key == 1 { score = min(score, len(route(plan, plan.key_rooms[0], index)) - 1); }
            if index not in plan.key_rooms and score > best_score {
                best = index; best_score = score;
            }
        }
        plan.key_rooms.append(best);
        rooms[best].role = "objective";
    }
    for room in rooms {
        if room.role == "encounter" and room.index != 7 and len([room->:Passage:->]) == 1 { room.role = "secret"; }
        elif room.role == "encounter" and room.index % 4 == 0 { room.role = "recovery"; }
    }
    caches = [room for room in rooms if room.role == "secret"];
    for room in rooms {
        if len(caches) >= 2 { break; }
        if room.role == "encounter" and room.index != 7 and room.distance >= 3 {
            room.role = "secret"; caches.append(room);
        }
    }
    validate_plan(plan);
    return plan;
}

def validate_plan(plan: Expedition) {
    rooms = [plan->:Contains:->][?:Chamber];
    assert len(rooms) == 20;
    walk = rooms[0] spawn Explore();
    assert len(walk.visited) == 20, "Disconnected expedition";
    before_gate = rooms[0] spawn Explore(blocked=19);
    assert len(before_gate.visited) == 19;
    assert len([rooms[19]->:Passage:->]) == 1;
    assert len(plan.key_rooms) == 2 and plan.key_rooms[0] != plan.key_rooms[1];
    for key in plan.key_rooms { assert key in before_gate.visited; }
    for room in rooms {
        for other in [room->:Passage:->][?:Chamber] {
            assert adjacent(room, other);
            assert room in [other->:Passage:->];
        }
    }
}

def route(plan: Expedition, first: int, last: int) -> list[int] {
    rooms = [plan->:Contains:->][?:Chamber];
    parents: dict[int, int] = {first: -1};
    queue = [first];
    cursor = 0;
    while cursor < len(queue) and last not in parents {
        current = queue[cursor]; cursor += 1;
        for neighbor in [rooms[current]->:Passage:->][?:Chamber] {
            if neighbor.index not in parents {
                parents[neighbor.index] = current; queue.append(neighbor.index);
            }
        }
    }
    if last not in parents { raise ValueError("No mission route"); }
    result: list[int] = [];
    cursor = last;
    while cursor >= 0 { result = [cursor] + result; cursor = parents[cursor]; }
    return result;
}
