import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }
import from engine.level.graph { LevelGraph, Place, Move, graph_text, graph_from_text, graph_places, graph_gates, graph_openers, graph_things, opener_places }
import from engine.level.prove { prove, prove_level, prune_traps }
import from engine.level.solve { Solver, MoveStep }
import from engine.level.budget { budget_route, start_kit }
import from games.passion.transform { copy_graph, turned, turn_graph, move_tokens }
import from games.passion.random { stream_for }
import from tests.level_graph_support { row_graph, place_of, side_place, fall_to, add_gate, add_opener, add_thing }

"""A row of six with a gold key at 2 for the door at 4, a secret at 3's
side opened by a button shot from 1 to 3, and a soldier at 5."""
def keyed_row -> LevelGraph {
    atlas = row_graph(6);
    add_opener(atlas, "pickup", "key_gold", [place_of(atlas, 2)], "key_gold");
    add_gate(atlas, 7, ["key_gold"], [place_of(atlas, 4)]);
    secret = side_place(atlas, 9, place_of(atlas, 3));
    add_gate(atlas, 8, ["open:8"], [secret]);
    add_opener(atlas, "shoot", "open:8", [place_of(atlas, 1), place_of(atlas, 2), place_of(atlas, 3)], "button");
    add_thing(atlas, "monster_army", place_of(atlas, 5));
    return atlas;
}

test "a level graph read back from its text is the same graph" {
    atlas = keyed_row();
    text = graph_text(atlas);
    again = graph_from_text(text);
    assert again is not None;
    assert graph_text(again) == text;
    assert len(graph_places(again)) == 7 and len(graph_gates(again)) == 2;
    assert len(graph_openers(again)) == 2 and len(graph_things(again)) == 1;
    assert sorted([len(opener_places(opener)) for opener in graph_openers(again)]) == [1, 3];
}

test "a row walked end to end finishes by the shortest sure route" {
    proof = prove(row_graph(5));
    assert proof.finishes and proof.softlocks == 0;
    assert proof.route == [1, 2, 3, 4, 5];
}

test "a search run a state at a time makes the plan one run whole does" {
    atlas = row_graph(6);
    solver = Solver(atlas=atlas);
    start = place_of(atlas, 1);
    whole = solver.solve(1, 0, start.center);
    job = solver.begin(1, 0, start.center);
    runs = 0;
    while not job.run(1) {
        runs += 1;
    }
    assert runs > 1;
    assert whole.found and job.plan.found;
    routes = [[step.to for step in plan.steps() if isinstance(step, MoveStep)] for plan in [whole, job.plan]];
    assert routes[0] == routes[1];
    assert len(routes[0]) > 0;
}

test "a pit fallen into is a softlock, and pruning takes it out" {
    atlas = row_graph(4);
    pit = side_place(atlas, 9, place_of(atlas, 2));
    # The pit is entered only by a drop and left by nothing.
    pit del --> place_of(atlas, 2);
    place_of(atlas, 2) del --> pit;
    fall_to(place_of(atlas, 2), pit);
    proof = prove(atlas);
    assert proof.finishes and proof.softlocks > 0;
    assert prune_traps(atlas) == 1;
    assert 9 not in [place.area for place in graph_places(atlas)];
    again = prove(atlas);
    assert again.finishes and again.softlocks == 0;
}

test "a key before its door is required, a secret's button is not" {
    proof = prove_level(keyed_row());
    assert proof.finishes and proof.softlocks == 0;
    assert proof.required == ["key_gold"];
    assert "open:8" in proof.tokens;
}

test "a key behind its own door leaves the level unfinished" {
    atlas = row_graph(6);
    add_opener(atlas, "pickup", "key_gold", [place_of(atlas, 5)], "key_gold");
    add_gate(atlas, 7, ["key_gold"], [place_of(atlas, 4)]);
    assert not prove(atlas).finishes;
}

test "an arena proves when nothing strands a player, and not with a pit" {
    atlas = row_graph(3);
    atlas.arena = True;
    place_of(atlas, 3).way_out = False;
    proof = prove(atlas);
    assert proof.finishes and proof.softlocks == 0;
    pit = side_place(atlas, 9, place_of(atlas, 3));
    pit del --> place_of(atlas, 3);
    assert prove(atlas).softlocks > 0;
}

test "the budget fights what the route meets and pays for more foes" {
    one = row_graph(6);
    add_thing(one, "monster_knight", place_of(one, 3));
    many = row_graph(6);
    for area in range(2, 6) {
        for count in range(3) {
            add_thing(many, "monster_knight", place_of(many, area));
        }
    }
    route = [1, 2, 3, 4, 5, 6];
    light = budget_route(one, route, CollisionMap(), start_kit("q1"));
    heavy = budget_route(many, route, CollisionMap(), start_kit("q1"));
    assert light.fights == 1 and heavy.fights == 12;
    assert heavy.lowest < light.lowest and light.lowest <= 100.0;
    # Out of shells, the rest are fought with the axe.
    assert heavy.melee > 0 and light.melee == 0;
}

test "the budget takes supplies on the way" {
    atlas = row_graph(6);
    for count in range(4) {
        add_thing(atlas, "monster_knight", place_of(atlas, 2));
    }
    add_thing(atlas, "item_health", place_of(atlas, 5));
    ledger = budget_route(atlas, [1, 2, 3, 4, 5, 6], CollisionMap(), start_kit("q1"));
    assert ledger.health > ledger.lowest;
}

test "a turned or mirrored essence turns its points and still proves" {
    turned_once = turned(Vec3(x=1.0), False, 1);
    assert turned_once.x == 0.0 and turned_once.y == 1.0;
    mirrored = turned(Vec3(x=1.0, y=2.0), True, 0);
    assert mirrored.x == -1.0 and mirrored.y == 2.0;
    atlas = keyed_row();
    copied = copy_graph(atlas);
    turn_graph(copied, True, 3);
    assert place_of(atlas, 2).center.x == 256.0;
    assert place_of(copied, 2).center.x != 256.0 or place_of(copied, 2).center.y != 0.0;
    proof = prove(copied);
    assert proof.finishes and proof.softlocks == 0;
    assert len(graph_places(copied)) == len(graph_places(atlas));
}

test "a moved key still comes before its door, or stays where it was" {
    moves = 0;
    for seed in range(1, 21) {
        atlas = row_graph(6);
        key = add_opener(atlas, "pickup", "key_gold", [place_of(atlas, 2)], "key_gold");
        add_gate(atlas, 7, ["key_gold"], [place_of(atlas, 4)]);
        prove_level(atlas, False);
        moved = move_tokens(atlas, stream_for(seed, "tokens"));
        areas = [place.area for place in opener_places(key)];
        assert len(areas) == 1;
        # Places past the door (4 and on) would strand the key: a move
        # there is undone.
        assert areas[0] in ([1, 3] if moved == 1 else [2]);
        proof = prove(atlas);
        assert proof.finishes and proof.softlocks == 0;
        moves += moved;
    }
    assert moves > 0;
}
