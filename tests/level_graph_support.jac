"""Small level graphs built by hand for the level graph's tests: places in a
row along x, 128 units apart, joined by walks; gates, openers and things
added where a test wants them."""
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.formats.aas { TRAVEL_WALK, TRAVEL_WALKOFFLEDGE }
import from engine.level.graph { LevelGraph, Place, Move, Gate, Opener, Thing, Holds, Guards, Bars, Offers, DoneFrom, Contains, StandsIn }

"""A place at `area`, its middle at x = 128 * area (a body's middle 24 over
its floor)."""
def row_place(area: int) -> Place {
    x = float(area) * 128.0;
    return Place(
        area=area,
        box=AABB(mins=Vec3(x=x - 48.0, y=-48.0, z=20.0), maxs=Vec3(x=x + 48.0, y=48.0, z=32.0)),
        center=Vec3(x=x, z=24.0),
        floor=0.0
    );
}

"""A graph of `count` places in a row (areas 1 to `count`), each walked to
from the next and back; the first the start, the last the way out."""
def row_graph(count: int) -> LevelGraph {
    atlas = LevelGraph(name="row", game="q1");
    places: list[Place] = [];
    for area in range(1, count + 1) {
        place = row_place(area);
        atlas +>:Holds:+> place;
        places.append(place);
    }
    places[0].start = True;
    places[-1].way_out = True;
    for index in range(len(places) - 1) {
        walk_both(places[index], places[index + 1]);
    }
    return atlas;
}

"""The place of `area` in a graph."""
def place_of(atlas: LevelGraph, area: int) -> Place {
    for place in [atlas->:Holds:->][?:Place] {
        if place.area == area {
            return place;
        }
    }
    raise ValueError("No place " + str(area));
}

"""A walk from one place to another (sure unless `must` is False)."""
def walk_to(a: Place, b: Place, must: bool = True) {
    a +>:Move(kind=TRAVEL_WALK, to=b.area, must=must, start=a.center, finish=b.center):+> b;
}

def walk_both(a: Place, b: Place) {
    walk_to(a, b);
    walk_to(b, a);
}

"""A drop off a ledge that may happen (one way)."""
def fall_to(a: Place, b: Place) {
    a +>:Move(kind=TRAVEL_WALKOFFLEDGE, to=b.area, must=False, start=a.center, finish=b.center, fall=True):+> b;
}

"""A place off the row, joined to `beside` by walks both ways."""
def side_place(atlas: LevelGraph, area: int, beside: Place) -> Place {
    place = Place(
        area=area,
        box=AABB(mins=Vec3(x=beside.center.x - 48.0, y=80.0, z=20.0), maxs=Vec3(x=beside.center.x + 48.0, y=176.0, z=32.0)),
        center=Vec3(x=beside.center.x, y=128.0, z=24.0),
        floor=0.0
    );
    atlas +>:Holds:+> place;
    walk_both(beside, place);
    return place;
}

"""A door of `model` barring `barred`, wanting `needs`."""
def add_gate(atlas: LevelGraph, model: int, needs: list[str], barred: list[Place]) -> Gate {
    gate = Gate(model=model, kind="door", needs=needs, box=barred[0].box);
    atlas +>:Guards:+> gate;
    for place in barred {
        gate +>:Bars:+> place;
    }
    return gate;
}

"""An opener giving `token`, done from `places`, standing at the first's
middle (or `point`)."""
def add_opener(atlas: LevelGraph, kind: str, token: str, places: list[Place], what: str = "", point: Vec3 | None = None) -> Opener {
    at = point if point is not None else places[0].center;
    opener = Opener(kind=kind, token=token, point=at, what=what);
    atlas +>:Offers:+> opener;
    for place in places {
        opener +>:DoneFrom:+> place;
    }
    return opener;
}

"""A monster or a supply standing in a place."""
def add_thing(atlas: LevelGraph, classname: str, place: Place, game: str = "q1", spawnflags: int = 0) -> Thing {
    thing = Thing(classname=classname, game=game, point=place.center, spawnflags=spawnflags);
    atlas +>:Contains:+> thing;
    thing +>:StandsIn:+> place;
    return thing;
}
