"""The diff between an essence and the level made for it: each sure move of
the essence, taken between the places of the made level that stand where
its two places stood, must still be surely taken there (within a few sure
moves). The moves that are not are what the sculpture lost; a level that
loses none plays as its essence does."""
import from engine.math.vec3 { Vec3 }
import from engine.formats.aas { TRAVEL_TELEPORT, TRAVEL_ELEVATOR }
import from engine.level.graph { LevelGraph, Place, Move, graph_places }
import from .sculpt { Sculpting }

"""The made level's place a point (in the made level's coordinates)
stands in: the nearest whose box holds it across, at about its height."""
def place_at(places: list[Place], point: Vec3) -> Place | None {
    best: Place | None = None;
    nearest = 1.0e9;
    for place in places {
        box = place.box;
        if point.x < box.mins.x - 16.0 or point.x > box.maxs.x + 16.0 or point.y < box.mins.y - 16.0 or point.y > box.maxs.y + 16.0 {
            continue;
        }
        gap = abs(place.center.z - point.z) + 0.25 * (abs(place.center.x - point.x) + abs(place.center.y - point.y));
        if gap < nearest and abs(place.center.z - point.z) < 40.0 {
            nearest = gap;
            best = place;
        }
    }
    return best;
}

"""Whether `target` is reached from `source` over sure moves (gates aside)
within `depth` moves."""
def surely_near(by_area: dict[int, Place], source: Place, target: Place, depth: int) -> bool {
    frontier = [source];
    seen: dict[int, bool] = {source.area: True};
    for count in range(depth) {
        after: list[Place] = [];
        for place in frontier {
            for move in [edge place->:Move:->] {
                if not move.must or move.to in seen {
                    continue;
                }
                if move.to == target.area {
                    return True;
                }
                seen[move.to] = True;
                other = by_area.get(move.to, None);
                if other is not None {
                    after.append(other);
                }
            }
        }
        frontier = after;
    }
    return False;
}

"""The essence's sure moves the made level loses, as lines (at most
`limit`): where each was in the essence and in the level, and its kind."""
def lost_moves(essence: LevelGraph, level: LevelGraph, made: Sculpting, limit: int = 12) -> list[str] {
    places = graph_places(level);
    by_area: dict[int, Place] = {};
    for place in places {
        by_area[place.area] = place;
    }
    lost: list[str] = [];
    checked = 0;
    missing = 0;
    for place in graph_places(essence) {
        for move in [edge place->:Move:->] {
            if not move.must or move.fall or move.kind in [TRAVEL_TELEPORT, TRAVEL_ELEVATOR] {
                continue;
            }
            a = made.moved(move.start.x, move.start.y, move.start.z);
            b = made.moved(move.finish.x, move.finish.y, move.finish.z);
            here = place_at(places, Vec3(x=a[0], y=a[1], z=a[2]));
            there = place_at(places, Vec3(x=b[0], y=b[1], z=b[2]));
            checked += 1;
            if here is None or there is None or here is there {
                continue;
            }
            if not surely_near(by_area, here, there, 6) {
                missing += 1;
                if len(lost) < limit {
                    lost.append(
                        "lost kind " + str(move.kind) + " essence " + str(int(move.start.x)) + "," + str(int(move.start.y)) + "," + str(int(move.start.z))
                            + " -> " + str(int(move.finish.x)) + "," + str(int(move.finish.y)) + "," + str(int(move.finish.z)) + " level "
                            + str(int(a[0])) + "," + str(int(a[1])) + "," + str(int(a[2])) + " places " + str(here.area) + " -> " + str(there.area)
                    );
                }
            }
        }
    }
    lost.insert(0, "diff: " + str(missing) + " of " + str(checked) + " sure moves lost");
    return lost;
}
