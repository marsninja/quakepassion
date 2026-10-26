"""A level assembled from prefabs: a chain of them chosen by the seed, laid
out and raised (`prefab.jac`).

Two libraries:

- `derived`: the originals' own stretches (`derive.jac`), e1m1's and
  e1m2's for now, mixed: a level begins in a stretch holding an original's
  start, goes on through two or three stretches from either, and ends in a
  stretch holding an original's way out (another original's than the one
  it began in, when there is one). Its lights are the originals'.
- `handmade`: prefabs written after every original of the three games
  (`prefabs/<original>.jac`, gathered in `prefabs/library.jac`), mixed in a
  tree: a level begins at any original's start stretch and goes on through
  a flow or two to a hub. From the hub a branch of stretches leads to a key
  room and ends there; the hub's way on is locked by that key, so the key
  is fetched and the branch walked back. From level 2 a second hub and
  branch lock the way on with the gold key, and the level ends at a gate
  that wants it (else at an end, or a gate wanting the silver key). No
  stretch follows itself. It is dressed as every Passion level is, each
  stretch in its own original's materials."""
import from .random { Stream, stream_for }
import from .massing { Massing }
import from .space { Space }
import from .dress { Dressing, dress }
import from .kits { kit_of }
import from .cast { Casting }
import from .prefab { Prefab, Next, Lay, Raise, Raising, prefab_box, passage_box, prefab_direction, prefab_point, port_middle, PREFAB_MARGIN, PORT_HIGH }
import os;
import from editor.formats.map { MapItem }
import from .prefabs.library { library_stretches, make_stretch }
import from .prefabs.testbed { TestStart, TestKey, TestEnd }
import from .derive { Piece, Derived, derived_library }

glob DERIVED_SOURCES: list[str] = ["q1:e1m1", "q1:e1m2"];

glob ASSEMBLE_TRIES: int = 24;

"""A level assembled: its massing and spaces, its dressing, what it holds,
the prefabs it was made of, and notes on how it went."""
obj Assembly {
    has mass: Massing,
        spaces: list[Space],
        dressing: Dressing,
        casting: Casting,
        chain: list[Prefab] = [],
        briefing: str = "",
        notes: list[str] = [];
}

"""A stretch of the library for a role, [original, name]: one of the
focus original's when it has one (most of the time; always under
QP_PREFAB_PURE=1), and not one of `avoid` (`original:name` each) when
another will do."""
def pick_stretch(dice: Stream, role: str, focus: str, avoid: list[str]) -> list[str] {
    rows = [row for row in library_stretches() if row[2] == role];
    mine = [row for row in rows if row[0] in focus.split(",")];
    taken = dice.chance(0.85) or os.getenv("QP_PREFAB_PURE", "") == "1";
    pool = mine if mine and taken else rows;
    fresh = [row for row in pool if (row[0] + ":" + row[1]) not in avoid];
    if fresh {
        pool = fresh;
    }
    row = pool[dice.below(len(pool))];
    return [row[0], row[1]];
}

"""One stretch alone between the testbed's plain rooms, to try it
(QP_PREFAB_SOLO=original:name:role): a start before it, the way out after
it; a key room hung off a start whose way on its key unlocks; a gate after
a start whose branch holds its key."""
def solo_chain(spec: str) -> list[Prefab] {
    parts = spec.split(":");
    role = parts[2] if len(parts) > 2 else "flow";
    nodes: list[Prefab] = [];
    if role == "start" {
        opening = make_stretch(parts[0], parts[1]);
        closing = TestEnd();
        opening +>:Next:+> closing;
        nodes = [opening, closing];
    } elif role == "keyroom" {
        first = TestStart();
        room = make_stretch(parts[0], parts[1], "key_silver");
        locked = TestEnd();
        locked.locked = "key_silver";
        first +>:Next:+> room;
        first +>:Next:+> locked;
        nodes = [first, room, locked];
    } elif role == "gate" {
        first = TestStart();
        holder = TestKey();
        gate = make_stretch(parts[0], parts[1], "key_silver");
        first +>:Next:+> gate;
        first +>:Next:+> holder;
        nodes = [first, gate, holder];
    } elif role == "end" {
        first = TestStart();
        ending = make_stretch(parts[0], parts[1]);
        first +>:Next:+> ending;
        nodes = [first, ending];
    } else {
        first = TestStart();
        middle = make_stretch(parts[0], parts[1]);
        after = TestEnd();
        first +>:Next:+> middle;
        middle +>:Next:+> after;
        nodes = [first, middle, after];
    }
    for (number, prefab) in enumerate(nodes) {
        prefab.number = number;
    }
    return nodes;
}

"""The hand-made prefabs of one try as a tree joined by `Next`, its root
first: the library's stretches mixed, with a key's branch off each hub
(the module's note says how). `grand` lets it be as long as it may be; a
try that did not fit is made shorter. QP_PREFAB_FOCUS names an original
(or several, a comma between) whose stretches are taken first (to try
them)."""
def prefab_chain(dice: Stream, depth: int, grand: bool = True) -> list[Prefab] {
    solo = os.getenv("QP_PREFAB_SOLO", "");
    if solo {
        return solo_chain(solo);
    }
    danger = min(1.0, float(depth - 1) / 5.0);
    focus = os.getenv("QP_PREFAB_FOCUS", "");
    nodes: list[Prefab] = [];
    gold = grand and (depth >= 2 or dice.chance(0.35));
    last: list[str] = pick_stretch(dice, "start", focus, []);
    previous = make_stretch(last[0], last[1]);
    nodes.append(previous);
    for index in range(dice.between(1, 2) if grand else 1) {
        last = pick_stretch(dice, "flow", focus, [last[0] + ":" + last[1]]);
        made = make_stretch(last[0], last[1]);
        nodes.append(made);
        previous +>:Next:+> made;
        previous = made;
    }
    keys = ["key_silver", "key_gold"] if gold else ["key_silver"];
    for key in keys {
        row = pick_stretch(dice, "hub", focus, [last[0] + ":" + last[1]]);
        hub = make_stretch(row[0], row[1]);
        nodes.append(hub);
        previous +>:Next:+> hub;
        # The branch to the key, ending at its room.
        tip = hub;
        step = row;
        for index in range(dice.between(1, 2)) {
            step = pick_stretch(dice, "flow", focus, [step[0] + ":" + step[1]]);
            made = make_stretch(step[0], step[1]);
            nodes.append(made);
            tip +>:Next:+> made;
            tip = made;
        }
        room = pick_stretch(dice, "keyroom", focus, []);
        made = make_stretch(room[0], room[1], key);
        nodes.append(made);
        tip +>:Next:+> made;
        # The way on from the hub, locked by the key.
        previous = hub;
        last = row;
        for index in range(dice.between(1, 2)) {
            last = pick_stretch(dice, "flow", focus, [last[0] + ":" + last[1]]);
            made = make_stretch(last[0], last[1]);
            if index == 0 {
                made.locked = key;
            }
            nodes.append(made);
            previous +>:Next:+> made;
            previous = made;
        }
    }
    gated = gold or dice.chance(0.5);
    ending = pick_stretch(dice, "gate" if gated else "end", focus, []);
    made = make_stretch(ending[0], ending[1], keys[-1] if gated else "");
    nodes.append(made);
    previous +>:Next:+> made;
    for (number, prefab) in enumerate(nodes) {
        prefab.number = number;
        prefab.danger = danger;
    }
    return nodes;
}

"""A chain of the originals' stretches, joined by `Next`: one that begins
an original, two or three from the middle of either, one that ends an
original (another's than the first, when one can)."""
def derived_chain(dice: Stream, library: list[Piece]) -> list[Prefab] {
    begins = [piece for piece in library if piece.can_begin()];
    ends = [piece for piece in library if piece.can_end()];
    joins = [piece for piece in library if piece.can_join()];
    if not begins or not ends {
        raise ValueError("The originals' stretches hold no start or no way out a passage can reach");
    }
    first = begins[dice.below(len(begins))];
    others = [piece for piece in ends if piece.plan.spec != first.plan.spec];
    finals = others if others else ends;
    last = finals[dice.below(len(finals))];
    chain: list[Prefab] = [Derived(piece=first, role="start")];
    order = dice.order(len(joins));
    for index in order[:min(len(joins), dice.between(2, 3))] {
        chain.append(Derived(piece=joins[index], role="middle"));
    }
    chain.append(Derived(piece=last, role="end"));
    for (number, prefab) in enumerate(chain) {
        prefab.number = number;
        if number > 0 {
            chain[number - 1] +>:Next:+> prefab;
        }
    }
    return chain;
}

"""Supplies for a level made of hand-made prefabs, after what each stretch
put down: health where every second foe stands (every one of Quake II's)
and ammunition where every third does (in the foe's own game's kinds, for the weapons the start
gives, there for the taking once it falls), and at the start the weapons
both Quake's and Quake II's foes want, so either game's ammunition feeds
one of them."""
def provision(casting: Casting, dice: Stream) {
    health = {"q1": "item_health", "q2": "item_health_large", "q3": "item_health"};
    ammo = {"q1": ["item_shells", "item_spikes", "item_rockets"], "q2": ["ammo_shells", "ammo_bullets", "ammo_grenades"], "q3": ["ammo_shells", "ammo_bullets", "ammo_rockets"]};
    count = 0;
    extra: list[MapItem] = [];
    for item in casting.items {
        kind = item.fields.get("classname", "");
        if not kind.startswith("monster_") or "origin" not in item.fields {
            continue;
        }
        count += 1;
        game = item.fields.get("asset_game", "q1");
        # Quake II's foes hit harder for their numbers: health at every one.
        if count % 2 == 0 or game == "q2" {
            extra.append(MapItem(fields={"classname": health.get(game, "item_health"), "origin": item.fields["origin"], "asset_game": game}));
        }
        if count % 3 == 0 {
            kinds = ammo.get(game, ammo["q1"]);
            extra.append(MapItem(fields={"classname": kinds[dice.below(len(kinds))], "origin": item.fields["origin"], "asset_game": game}));
        }
    }
    if casting.start {
        at = casting.start;
        kit = [["weapon_supershotgun", "q1"], ["weapon_nailgun", "q1"], ["weapon_grenadelauncher", "q1"], ["weapon_supershotgun", "q2"], ["weapon_machinegun", "q2"], ["weapon_grenadelauncher", "q2"]];
        # At the start itself: wherever the start lies turned, there is floor.
        for arm in kit {
            extra.append(MapItem(fields={"classname": arm[0], "origin": str(int(at[0])) + " " + str(int(at[1])) + " " + str(int(at[2])), "asset_game": arm[1]}));
        }
    }
    for item in extra {
        casting.items.append(item);
    }
}

"""Move every prefab of a laid chain so the whole stands inside a massing
with `PREFAB_MARGIN` cells to spare; answers the massing's size."""
def settle_chain(chain: list[Prefab]) -> list[int] {
    lows = [1 << 30, 1 << 30, 1 << 30];
    highs = [-(1 << 30), -(1 << 30), -(1 << 30)];
    for (index, prefab) in enumerate(chain) {
        box = prefab_box(prefab);
        lows[0] = min(lows[0], box[0]);
        lows[1] = min(lows[1], box[1]);
        highs[0] = max(highs[0], box[2]);
        highs[1] = max(highs[1], box[3]);
        lows[2] = min(lows[2], prefab.oz + prefab.low);
        highs[2] = max(highs[2], prefab.oz + prefab.high);
        for box in prefab.route {
            lows[0] = min(lows[0], box[0]);
            lows[1] = min(lows[1], box[1]);
            highs[0] = max(highs[0], box[2]);
            highs[1] = max(highs[1], box[3]);
            lows[2] = min(lows[2], prefab.route_floor - 1);
            highs[2] = max(highs[2], prefab.route_floor + prefab.route_high * 2 + 1);
        }
        # The passage into it, from the prefab before it in the tree.
        port = prefab.via;
        before = [prefab<-:Next:<-][?:Prefab];
        if port is not None and before {
            parent = before[0];
            middle = port_middle(parent, port);
            passage = passage_box(prefab_point(parent, middle[0], middle[1]), prefab_direction(parent, port.face), prefab.gap, max(port.wide, prefab.enter.wide));
            lows[0] = min(lows[0], passage[0]);
            lows[1] = min(lows[1], passage[1]);
            highs[0] = max(highs[0], passage[2]);
            highs[1] = max(highs[1], passage[3]);
            lows[2] = min(lows[2], parent.oz + port.floor + min(0, prefab.rise) - 1);
            highs[2] = max(highs[2], parent.oz + port.floor + max(0, prefab.rise) + max(port.high, prefab.enter.high) * 2 + 1);
        }
    }
    for prefab in chain {
        prefab.ox += PREFAB_MARGIN - lows[0];
        prefab.oy += PREFAB_MARGIN - lows[1];
        prefab.oz += PREFAB_MARGIN - lows[2];
        shift_x = PREFAB_MARGIN - lows[0];
        shift_y = PREFAB_MARGIN - lows[1];
        prefab.route = [[box[0] + shift_x, box[1] + shift_y, box[2] + shift_x, box[3] + shift_y] for box in prefab.route];
        prefab.route_floor += PREFAB_MARGIN - lows[2];
        if prefab.route_door {
            prefab.route_door = [
                prefab.route_door[0] + float(shift_x if prefab.route_x else shift_y),
                prefab.route_door[1] + float(shift_y if prefab.route_x else shift_x),
                prefab.route_door[2] + float(shift_y if prefab.route_x else shift_x)
            ];
        }
    }
    return [highs[0] - lows[0] + 2 * PREFAB_MARGIN, highs[1] - lows[1] + 2 * PREFAB_MARGIN, highs[2] - lows[2] + 2 * PREFAB_MARGIN];
}

"""Assemble a level from prefabs for a seed and a depth: a chain laid out
(another chain tried when one does not fit), raised and dressed. None when
no try fits (`notes` says why)."""
def assemble_prefabs(seed: int, depth: int, notes: list[str], library: str = "derived") -> Assembly | None {
    dice = stream_for(seed, "prefabs");
    pieces: list[Piece] = [];
    if library == "derived" {
        pieces = derived_library(DERIVED_SOURCES, notes);
    }
    for attempt in range(ASSEMBLE_TRIES) {
        trial = dice.child("try", attempt);
        chain = derived_chain(trial.derive("chain"), pieces) if library == "derived" else prefab_chain(trial.derive("chain"), depth, attempt < ASSEMBLE_TRIES // 2);
        laid = chain[0] spawn Lay(dice=trial.derive("lay"));
        if not laid.fits or len(laid.laid) != len(chain) {
            notes.append("try " + str(attempt) + ": " + " | ".join(laid.notes));
            continue;
        }
        size = settle_chain(chain);
        mass = Massing(nx=size[0], ny=size[1], nz=size[2]);
        build = Raising(mass=mass, dice=trial.derive("rise"), casting=Casting(), district=0);
        chain[0] spawn Raise(build=build);
        build.wire_cues();
        if library != "derived" and os.getenv("QP_PREFAB_NOWEAVE", "") != "1" {
            build.weave(chain);
        }
        build.settle_liquids();
        build.settle_rocks();
        for line in build.notes {
            notes.append("try " + str(attempt) + ": " + line);
        }
        if not build.casting.start or not build.casting.exit_low {
            notes.append("try " + str(attempt) + ": no start or way out");
            continue;
        }
        dressing = dress(mass, build.spaces, trial.derive("dress")) if library != "derived" else Dressing();
        if library != "derived" {
            provision(build.casting, trial.derive("provision"));
        }
        titles = " > ".join([(prefab.source.split(":")[-1] + " " + prefab.title) if library != "derived" else prefab.title for prefab in chain]);
        for prefab in chain {
            box = prefab_box(prefab);
            notes.append(
                "try " + str(attempt) + ": " + prefab.title + " at x " + str(box[0] * 32) + ".." + str(box[2] * 32) + " y " + str(box[1] * 32) + ".."
                    + str(box[3] * 32) + " floor " + str(prefab.oz * 16) + " turn " + str(prefab.turn) + (" mirrored" if prefab.mirror else "")
            );
        }
        notes.append("try " + str(attempt) + ": " + titles + " in " + str(size[0]) + "x" + str(size[1]) + "x" + str(size[2]) + " cells");
        return Assembly(
            mass=mass,
            spaces=build.spaces,
            dressing=dressing,
            casting=build.casting,
            chain=chain,
            briefing=titles,
            notes=notes
        );
    }
    return None;
}
