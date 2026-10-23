"""The level graph: one graph of what a level lets a player do, read off any
level the engine loads (an original, a studio scene, a generated level),
the graph the bots route and plan by and the one Passion generates from.

Its layers, each joined to the next by edges:

- **places**: where a body stands, the navigation's areas, each with its
  floor and what the level had over it (air, sky, liquid), joined by
  `Move`s: walked, dropped, jumped, swum, lifted, teleported, pushed. A move
  is *must* when it surely works (jumps are run through the engine's own
  player movement to see that they land) or only *may* when it might happen
  (a fall or a jump off any ledge, wherever it lands);
- **gates**: the movers that bar places until something opens them, each
  wanting tokens (`open:<model>`, or keys), and the **openers** that give
  them (press, touch, shoot, pick up, kill), each done from places;
- **things**: monsters and supplies, each standing in a place;
- **stages**: each place's progression stage, the tokens it takes to get
  there (`prove.jac` finds them).

It is kept on disk as lines of text (`write_graph`, `read_graph`) so an
original read once is not read again."""
import os;
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

glob GRAPH_VERSION: int = 1;

"""Where a body stands: a navigation area. `floor` is the floor's height,
`roof` how much air the level had over it, `surface` its liquid's top."""
node Place {
    has area: int,
        box: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        center: Vec3 = Vec3(),
        floor: float = 0.0,
        # 0 none, 1 water, 2 slime, 3 lava.
        liquid: int = 0,
        surface: float = 0.0,
        roof: float = 0.0,
        sky: bool = False,
        # A body here dies (lava, slime, a hurting volume): no softlock.
        deadly: bool = False,
        # The mover whose doorway it is, 0 for none; found with the movers
        # at rest (a bridge drawn out), not posed for travel.
        mover: int = 0,
        resting: bool = False,
        # The area's flags and contents as botlib keeps them.
        flags: int = 0,
        contents: int = 0,
        way_out: bool = False,
        start: bool = False,
        # Its progression stage: the tokens it takes to get there (a mask
        # over the graph's tokens), -1 unreached.
        stage: int = -1;
}

"""A way from one place to another: how it is taken (botlib's travel
types), the mover it rides, and whether it is sure or only possible."""
edge Move: Place --> Place {
    has kind: int,
        to: int = 0,
        must: bool = True,
        model: int = 0,
        # Where it is taken from and arrives, and how long it takes (a
        # hundredth of a second each): what a router follows.
        start: Vec3 = Vec3(),
        finish: Vec3 = Vec3(),
        time: int = 0,
        # Found by running a body off a ledge (no router follows those).
        fall: bool = False;
}

"""A mover that bars places (or a lift its ride) until its tokens are held:
`open:<model>`, or every key it wants. `box` is where it stands shut."""
node Gate {
    has model: int,
        kind: str = "door",
        needs: list[str] = [],
        box: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        # How far a lift travels from its top.
        travel: float = 0.0;
}

edge Bars: Gate --> Place {}

"""Something a player does that gives a token: press, touch, shoot, pick
up (a key), kill; at `point`, done from the places it is `DoneFrom`."""
node Opener {
    has kind: str,
        token: str,
        point: Vec3 = Vec3(),
        # A key's classname, a monster's: what stands there.
        what: str = "";
}

edge DoneFrom: Opener --> Place {}

"""A monster or a supply: its classname, the game it is from, where it
stands, its spawnflags and facing."""
node Thing {
    has classname: str,
        game: str = "q1",
        point: Vec3 = Vec3(),
        spawnflags: int = 0,
        yaw: float = 0.0;
}

edge StandsIn: Thing --> Place {}

"""The graph's root: the level it was read off and how."""
node LevelGraph {
    has name: str = "",
        game: str = "q1",
        start_yaw: float = 0.0,
        # An arena: no way out of its own (Quake III's).
        arena: bool = False,
        notes: list[str] = [];
}

edge Holds: LevelGraph --> Place {}
edge Guards: LevelGraph --> Gate {}
edge Offers: LevelGraph --> Opener {}
edge Contains: LevelGraph --> Thing {}

"""The places of a graph."""
def graph_places(atlas: LevelGraph) -> list[Place] {
    return [atlas->:Holds:->][?:Place];
}

"""The places of a graph by area."""
def places_by_area(atlas: LevelGraph) -> dict[int, Place] {
    found: dict[int, Place] = {};
    for place in graph_places(atlas) {
        found[place.area] = place;
    }
    return found;
}

def graph_gates(atlas: LevelGraph) -> list[Gate] {
    return [atlas->:Guards:->][?:Gate];
}

def graph_openers(atlas: LevelGraph) -> list[Opener] {
    return [atlas->:Offers:->][?:Opener];
}

def graph_things(atlas: LevelGraph) -> list[Thing] {
    return [atlas->:Contains:->][?:Thing];
}

"""The tokens of a graph, in a fixed order: what openers give, then what
gates want that nothing gives."""
def graph_tokens(atlas: LevelGraph) -> list[str] {
    tokens: list[str] = [];
    for opener in graph_openers(atlas) {
        if opener.token not in tokens {
            tokens.append(opener.token);
        }
    }
    for gate in graph_gates(atlas) {
        for need in gate.needs {
            if need not in tokens {
                tokens.append(need);
            }
        }
    }
    return tokens;
}

"""The places a thing stands in, an opener is done from, a gate bars."""
def thing_place(thing: Thing) -> Place | None {
    found = [thing->:StandsIn:->][?:Place];
    return found[0] if found else None;
}

def opener_places(opener: Opener) -> list[Place] {
    return [opener->:DoneFrom:->][?:Place];
}

def barred_places(gate: Gate) -> list[Place] {
    return [gate->:Bars:->][?:Place];
}

def:priv graph_number(value: float) -> str {
    return str(round(value, 2));
}

def:priv graph_box(box: AABB) -> str {
    return " ".join([graph_number(value) for value in [box.mins.x, box.mins.y, box.mins.z, box.maxs.x, box.maxs.y, box.maxs.z]]);
}

def:priv graph_flag(value: bool) -> str {
    return "1" if value else "0";
}

"""A graph as lines of text."""
def graph_text(atlas: LevelGraph) -> str {
    lines: list[str] = [
        "LEVELGRAPH " + str(GRAPH_VERSION) + " " + atlas.game + " " + atlas.name + " " + graph_number(atlas.start_yaw) + " "
            + graph_flag(atlas.arena)
    ];
    for note in atlas.notes {
        lines.append("N " + note.replace("\n", " "));
    }
    places = graph_places(atlas);
    for place in places {
        lines.append(
            "P " + str(place.area) + " " + graph_box(place.box) + " " + graph_number(place.floor) + " " + str(place.liquid) + " "
                + graph_number(place.surface) + " " + graph_number(place.roof) + " " + graph_flag(place.sky) + " "
                + graph_flag(place.deadly) + " " + str(place.mover) + " " + graph_flag(place.resting) + " "
                + graph_flag(place.way_out) + " " + graph_flag(place.start) + " " + str(place.stage) + " " + str(place.flags) + " "
                + str(place.contents)
        );
    }
    for place in places {
        for move in [edge place->:Move:->] {
            lines.append(
                "M " + str(place.area) + " " + str(move.to) + " " + str(move.kind) + " " + graph_flag(move.must) + " " + str(move.model) + " "
                    + " ".join([graph_number(value) for value in [move.start.x, move.start.y, move.start.z, move.finish.x, move.finish.y, move.finish.z]])
                    + " " + str(move.time) + " " + graph_flag(move.fall)
            );
        }
    }
    for gate in graph_gates(atlas) {
        lines.append(
            "G " + str(gate.model) + " " + gate.kind + " " + (",".join(gate.needs) if gate.needs else "-") + " " + graph_box(gate.box) + " "
                + graph_number(gate.travel) + " " + (",".join([str(place.area) for place in barred_places(gate)]) or "-")
        );
    }
    for opener in graph_openers(atlas) {
        lines.append(
            "O " + opener.kind + " " + opener.token + " " + graph_number(opener.point.x) + " " + graph_number(opener.point.y) + " "
                + graph_number(opener.point.z) + " " + (opener.what or "-") + " "
                + (",".join([str(place.area) for place in opener_places(opener)]) or "-")
        );
    }
    for thing in graph_things(atlas) {
        at = thing_place(thing);
        lines.append(
            "T " + thing.classname + " " + thing.game + " " + graph_number(thing.point.x) + " " + graph_number(thing.point.y) + " "
                + graph_number(thing.point.z) + " " + str(thing.spawnflags) + " " + graph_number(thing.yaw) + " "
                + (str(at.area) if at is not None else "-1")
        );
    }
    return "\n".join(lines) + "\n";
}

def:priv graph_read_box(words: list[str], at: int) -> AABB {
    return AABB(
        mins=Vec3(x=float(words[at]), y=float(words[at + 1]), z=float(words[at + 2])),
        maxs=Vec3(x=float(words[at + 3]), y=float(words[at + 4]), z=float(words[at + 5]))
    );
}

def:priv graph_areas(word: str) -> list[int] {
    return [] if word == "-" else [int(part) for part in word.split(",")];
}

"""A graph from its lines of text; None when they are not one, or of
another version."""
def graph_from_text(text: str) -> LevelGraph | None {
    lines = text.split("\n");
    if not lines or not lines[0].startswith("LEVELGRAPH ") {
        return None;
    }
    head = lines[0].split(" ");
    if len(head) < 6 or int(head[1]) != GRAPH_VERSION {
        return None;
    }
    atlas = LevelGraph(game=head[2], name=head[3], start_yaw=float(head[4]), arena=head[5] == "1");
    by_area: dict[int, Place] = {};
    for line in lines[1:] {
        if not line {
            continue;
        }
        if line.startswith("N ") {
            atlas.notes.append(line[2:]);
            continue;
        }
        words = line.split(" ");
        tag = words[0];
        if tag == "P" {
            place = Place(
                area=int(words[1]),
                box=graph_read_box(words, 2),
                floor=float(words[8]),
                liquid=int(words[9]),
                surface=float(words[10]),
                roof=float(words[11]),
                sky=words[12] == "1",
                deadly=words[13] == "1",
                mover=int(words[14]),
                resting=words[15] == "1",
                way_out=words[16] == "1",
                start=words[17] == "1",
                stage=int(words[18]),
                flags=int(words[19]),
                contents=int(words[20])
            );
            place.center = place.box.mins.add(place.box.maxs).scale(0.5);
            by_area[place.area] = place;
            atlas +>:Holds:+> place;
        } elif tag == "M" {
            source = by_area.get(int(words[1]), None);
            target = by_area.get(int(words[2]), None);
            if source is not None and target is not None {
                source +>:Move(
                    kind=int(words[3]),
                    to=target.area,
                    must=words[4] == "1",
                    model=int(words[5]),
                    start=Vec3(x=float(words[6]), y=float(words[7]), z=float(words[8])),
                    finish=Vec3(x=float(words[9]), y=float(words[10]), z=float(words[11])),
                    time=int(words[12]),
                    fall=words[13] == "1"
                ):+> target;
            }
        } elif tag == "G" {
            gate = Gate(model=int(words[1]), kind=words[2], needs=[] if words[3] == "-" else words[3].split(","), box=graph_read_box(words, 4), travel=float(words[10]));
            atlas +>:Guards:+> gate;
            for area in graph_areas(words[11]) {
                if area in by_area {
                    gate +>:Bars:+> by_area[area];
                }
            }
        } elif tag == "O" {
            opener = Opener(kind=words[1], token=words[2], point=Vec3(x=float(words[3]), y=float(words[4]), z=float(words[5])), what="" if words[6] == "-" else words[6]);
            atlas +>:Offers:+> opener;
            for area in graph_areas(words[7]) {
                if area in by_area {
                    opener +>:DoneFrom:+> by_area[area];
                }
            }
        } elif tag == "T" {
            thing = Thing(classname=words[1], game=words[2], point=Vec3(x=float(words[3]), y=float(words[4]), z=float(words[5])), spawnflags=int(words[6]), yaw=float(words[7]));
            atlas +>:Contains:+> thing;
            area = int(words[8]);
            if area in by_area {
                thing +>:StandsIn:+> by_area[area];
            }
        }
    }
    return atlas;
}

"""Keep a graph on disk."""
def write_graph(atlas: LevelGraph, path: str) {
    folder = os.path.dirname(path);
    if folder and not os.path.isdir(folder) {
        os.makedirs(folder);
    }
    with open(path + ".part", "w") as handle {
        handle.write(graph_text(atlas));
    }
    os.replace(path + ".part", path);
}

"""A graph kept on disk, or None."""
def read_graph(path: str) -> LevelGraph | None {
    if not os.path.exists(path) {
        return None;
    }
    with open(path) as handle {
        return graph_from_text(handle.read());
    }
}
