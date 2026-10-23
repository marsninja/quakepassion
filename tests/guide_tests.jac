import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.level.graph { LevelGraph }
import from engine.level.guide { Guide, HasGuide, guide_level, guide_crumbs }
import from tests.level_graph_support { row_graph, place_of, side_place, add_gate, add_opener }

# The switch the door at 4 wants, pressed from 2.
glob GUIDE_SWITCH: Vec3 = Vec3(x=256.0, y=40.0, z=40.0);

"""A row of six: the door at 4 opened by a switch at 2; a secret off 3
whose button is shot from anywhere from 1 to 3."""
def switched_row -> LevelGraph {
    atlas = row_graph(6);
    add_gate(atlas, 7, ["open:7"], [place_of(atlas, 4)]);
    add_opener(atlas, "press", "open:7", [place_of(atlas, 2)], "button", GUIDE_SWITCH);
    secret = side_place(atlas, 9, place_of(atlas, 3));
    add_gate(atlas, 8, ["open:8"], [secret]);
    add_opener(atlas, "shoot", "open:8", [place_of(atlas, 1), place_of(atlas, 2), place_of(atlas, 3)], "button");
    return atlas;
}

"""A guide over `atlas`, its plan made from the middle of `area`, holding
the tokens named."""
def guide_from(atlas: LevelGraph, area: int, tokens: list[str]) -> Guide {
    guide = Guide(atlas=atlas);
    guide.prepare();
    view = guide.view;
    assert view is not None;
    held = 0;
    for token in tokens {
        held |= 1 << view.tokens.index(token);
    }
    guide.plan(place_of(atlas, area).center, area, held);
    return guide;
}

test "the trail leads to the switch the way out needs, not a button seen in passing" {
    guide = guide_from(switched_row(), 1, []);
    goal = guide.goal;
    assert goal is not None;
    assert guide.goal_kind == "press";
    assert goal.sub(GUIDE_SWITCH).length() < 0.01;
    assert guide.trail[-1].sub(GUIDE_SWITCH).length() < 0.01;
}

test "with the switch pressed the trail leads to the way out" {
    atlas = switched_row();
    guide = guide_from(atlas, 2, ["open:7"]);
    goal = guide.goal;
    assert goal is not None;
    assert guide.goal_kind == "exit";
    assert goal.sub(place_of(atlas, 6).center).length() < 0.01;
}

test "a door shut again sends the trail back to its switch" {
    # Past the switch, by the door, holding nothing: the door has shut.
    guide = guide_from(switched_row(), 3, []);
    assert guide.goal_kind == "press";
}

test "motes are laid every 40 units from a little past the player" {
    origin = Vec3(z=24.0);
    crumbs = guide_crumbs([origin, Vec3(x=500.0, z=24.0)], origin);
    assert len(crumbs) == 12;
    assert crumbs[0].x == 48.0 and crumbs[1].x == 88.0;
    assert crumbs[0].z == 12.0;
}

test "a level gets one guide, and an arena or a level with no graph none" {
    world = World();
    atlas = switched_row();
    guide_level(world, atlas);
    guide_level(world, atlas);
    assert len([world->:HasGuide:->][?:Guide]) == 1;
    guide_level(world, None);
    assert len([world->:HasGuide:->][?:Guide]) == 0;
    arena = row_graph(3);
    arena.arena = True;
    guide_level(world, arena);
    assert len([world->:HasGuide:->][?:Guide]) == 0;
}
