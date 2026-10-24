"""Transforms of an essence that keep what it is but blur where it came
from: the whole of it mirrored and turned, and the things a player must get
to (keys, plates, switches) moved to other places reached before what they
open. Each works on a copy of the essence's graph; a token moved is kept
only if the graph still proves clean with it there."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.level.graph { LevelGraph, Place, Move, Gate, Opener, Thing, DoneFrom, graph_text, graph_from_text, graph_places, graph_gates, graph_openers, graph_things, opener_places }
import from engine.level.prove { prove, prove_level }
import from .random { Stream }

"""A copy of a graph (its text read back)."""
def copy_graph(atlas: LevelGraph) -> LevelGraph {
    copied = graph_from_text(graph_text(atlas));
    if copied is None {
        raise ValueError("The essence could not be copied");
    }
    return copied;
}

"""A point turned a quarter `turns` times about the origin, after being
mirrored across x when `mirror`."""
def turned(point: Vec3, mirror: bool, turns: int) -> Vec3 {
    x = -point.x if mirror else point.x;
    y = point.y;
    for count in range(turns % 4) {
        swap = x;
        x = -y;
        y = swap;
    }
    return Vec3(x=x, y=y, z=point.z);
}

"""A box turned as `turned` turns its points."""
def turned_box(box: AABB, mirror: bool, turns: int) -> AABB {
    a = turned(box.mins, mirror, turns);
    b = turned(box.maxs, mirror, turns);
    return AABB(mins=Vec3(x=min(a.x, b.x), y=min(a.y, b.y), z=box.mins.z), maxs=Vec3(x=max(a.x, b.x), y=max(a.y, b.y), z=box.maxs.z));
}

"""A facing (degrees) turned as `turned` turns points."""
def turned_yaw(yaw: float, mirror: bool, turns: int) -> float {
    facing = 180.0 - yaw if mirror else yaw;
    return (facing + 90.0 * float(turns % 4)) % 360.0;
}

"""Mirror and turn a graph in place: its places, moves, gates, openers,
things and the start's facing."""
def turn_graph(atlas: LevelGraph, mirror: bool, turns: int) {
    if not mirror and turns % 4 == 0 {
        return;
    }
    for place in graph_places(atlas) {
        place.box = turned_box(place.box, mirror, turns);
        place.center = turned(place.center, mirror, turns);
        for move in [edge place->:Move:->] {
            move.start = turned(move.start, mirror, turns);
            move.finish = turned(move.finish, mirror, turns);
        }
    }
    for gate in graph_gates(atlas) {
        gate.box = turned_box(gate.box, mirror, turns);
    }
    for opener in graph_openers(atlas) {
        opener.point = turned(opener.point, mirror, turns);
    }
    for thing in graph_things(atlas) {
        thing.point = turned(thing.point, mirror, turns);
        thing.yaw = turned_yaw(thing.yaw, mirror, turns);
    }
    atlas.start_yaw = turned_yaw(atlas.start_yaw, mirror, turns);
    atlas.notes.append("turned " + str(turns % 4) + (" mirrored" if mirror else ""));
}

"""Move the things a player must get to: each key, plate or switch (an
opener done where it stands, not one shot from afar) to another place of
the same stage or an earlier one (reached with no more than the place it
stood in), on firm dry floor. A move that breaks the proof is undone."""
def move_tokens(atlas: LevelGraph, dice: Stream, most: int = 3) -> int {
    moved = 0;
    tried = 0;
    places = graph_places(atlas);
    # Keys first, then plates and switches; a few at most (each move is
    # proven).
    movable = [opener for opener in graph_openers(atlas) if opener.kind == "pickup" and opener.token.startswith("key")]
        + [opener for opener in graph_openers(atlas) if opener.kind in ["press", "touch"] and opener.token != "exit"];
    for opener in movable {
        if tried >= most {
            break;
        }
        tried += 1;
        now = opener_places(opener);
        if not now {
            continue;
        }
        stage = now[0].stage;
        if stage < 0 {
            continue;
        }
        choices = [
            place
            for place in places
            if place.stage >= 0 and place.stage & stage == place.stage and not place.deadly and place.liquid == 0 and place.mover == 0
                and not place.resting and place.box.maxs.x - place.box.mins.x >= 32.0 and place.box.maxs.y - place.box.mins.y >= 32.0
                and place not in now
        ];
        if not choices {
            continue;
        }
        pick = choices[dice.below(len(choices))];
        was = opener.point;
        for place in now {
            opener del --> place;
        }
        opener.point = Vec3(x=pick.center.x, y=pick.center.y, z=pick.floor + 24.0);
        opener +>:DoneFrom:+> pick;
        checked = prove(atlas);
        if checked.finishes and checked.softlocks == 0 {
            moved += 1;
            continue;
        }
        opener del --> pick;
        opener.point = was;
        for place in now {
            opener +>:DoneFrom:+> place;
        }
    }
    atlas.notes.append("tokens moved " + str(moved));
    return moved;
}

"""An essence transformed for a level: a copy turned and mirrored by the
dice, its tokens moved when `move` asks, its stages found again."""
def transform_essence(atlas: LevelGraph, dice: Stream, turn: bool = True, move: bool = True) -> LevelGraph {
    copied = copy_graph(atlas);
    if turn {
        turn_graph(copied, dice.chance(0.5), dice.below(4));
    }
    if move {
        move_tokens(copied, dice.derive("tokens"));
    }
    prove_level(copied, False);
    return copied;
}
