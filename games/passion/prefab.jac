"""Prefabs: pieces of level, each drawn from a stretch of an original level
and made again by code, at its scale and with its flow (its doors, buttons,
lifts and bridges), varied by a seed.

A prefab is a node. It has a box in cells of its own (x along the way
through it, y across, z up in lifts), a way in on its -x face, and the ways
out it offers. Prefabs stand in a chain (`Next`), and two walkers go along
it:

- `Lay` has each prefab choose its sizes and what it holds, then places it:
  mirrored or not, turned so its way in meets the way out of the one before
  it across a short passage, and kept clear of every prefab and passage
  already laid. A prefab that does not fit takes another of the ways out
  of the one before it.
- `Raise` has each prefab carve itself into the massing (the level's grid
  of cells) and put down its entities, and joins it to the one before it
  by a passage with a double door.

A prefab draws itself in its own cells; `Raising` turns them into the
world's, so the same drawing serves every way a prefab lies."""
import math;
import os;
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side }
import from .random { Stream }
import from .massing { Massing, CELL, LIFT }
import from .space { Space }
import from .kits { kit_of }
import from .dress { plain_box }
import from .cast { Casting, origin_text, TELEPORT_MATERIAL, BUTTON_MATERIAL }
import from engine.level.budget { foe_stats }

glob Q2_FOES: list[str] = [
         "monster_soldier_light", "monster_soldier", "monster_soldier_ss", "monster_infantry", "monster_gunner",
         "monster_berserk", "monster_gladiator", "monster_tank", "monster_tank_commander", "monster_parasite",
         "monster_flyer", "monster_hover", "monster_floater", "monster_brain", "monster_mutant", "monster_chick",
         "monster_medic", "monster_flipper", "monster_supertank", "monster_boss2", "monster_jorg", "monster_makron"
     ],
     PORT_WIDE: int = 4,
     PORT_HIGH: int = 8,
     PREFAB_MARGIN: int = 3,
     # Lifts of rock left over a level for its ceilings to rise into.
     VAULT_ROOM: int = 34,
     # Foes this much alive (bosses) stay wherever the pace falls.
     PACE_BOSS: float = 1500.0;

"""A way into or out of a prefab: the face of its box it opens in (0 +x,
1 +y, 2 -x, 3 -y, in the prefab's own cells), the middle of the opening
along that face, the floor it is at (in lifts), how wide (cells) and high
(lifts) it opens, and what the door through it wants: nothing (it opens to
a touch), a key (`key_silver`, `key_gold`), or a targetname of the
prefab's own that fires it. `number` is its place among a prefab's ports."""
obj Port {
    has face: int = 0,
        along: float = 0.0,
        floor: int = 0,
        wide: int = 4,
        high: int = 8,
        gate: str = "",
        number: int = 0,
        # For a derived stretch, the numbers of its ways a body reaches from
        # this one inside it: a way out must be one the way in reaches.
        groups: list[int] = [],
        # Where the passage leaves it, in the prefab's own cells, when not at
        # the middle of its face (a door inside a derived stretch's box).
        point: list[float] = [];
}

"""A piece of level. Its box runs 0..long along x, 0..wide across y and
low..high in lifts; it lies mirrored across y (or not), turned by quarter
turns, and moved by an offset in the world's cells."""
node Prefab {
    has title: str = "",
        source: str = "",
        number: int = 0,
        long: int = 8,
        wide: int = 8,
        low: int = 0,
        high: int = 8,
        enter: Port = Port(face=2),
        leaves: list[Port] = [],
        leave: Port | None = None,
        mirror: bool = False,
        turn: int = 0,
        ox: int = 0,
        oy: int = 0,
        oz: int = 0,
        # Cells of passage between this prefab and the one before it, and how
        # many lifts the passage climbs (down when below 0), a lift a cell.
        gap: int = 0,
        rise: int = 0,
        # The way out of the prefab before it that the passage leaves by,
        # what the passage's door wants (a key) beyond what that way says,
        # and the ways out of this prefab the prefabs after it leave by.
        via: Port | None = None,
        locked: str = "",
        taken: list[Port] = [],
        taken_index: list[int] = [],
        # How hard its fights are, from 0 (a run's first level) to 1.
        danger: float = 0.0,
        # The district whose materials it is raised in (the kit of the
        # original it was drawn from).
        district: int = 0,
        # The cells its air takes, in its own cells ([x, y, z] each): when
        # given, it is laid clear of what is laid by them, not by its box.
        cells: list[list[int]] = [],
        # When given, the ways in it may be laid by (each tried in turn) and
        # every way it has: the ways out are the rest.
        ways_in: list[Port] = [],
        ways: list[Port] = [],
        # The passage from the prefab before, when laid by cells: its boxes
        # in the world's cells ([x0, y0, x1, y1] each, a leg a box), its
        # floor and height, and where the door across its first leg stands
        # ([along, lo, hi] in the world's cells, the leg along x when
        # `route_x`).
        route: list[list[int]] = [],
        route_floor: int = 0,
        route_high: int = 8,
        route_door: list[float] = [],
        route_x: bool = True,
        # The ways back it leads to stretches it was reached through.
        loops: list[Loop] = [],
        # Its part in the level's rhythm of fights (`Pace`): "rest", "steady"
        # or "fight".
        pace: str = "steady";
}

edge Next: Prefab --> Prefab {}

"""A way back from a stretch into one it was reached through (`older`):
a passage from a way out of its own the level left free (`mine`) to one
of `older`'s (`theirs`), with a door opened from its own side, as the
originals' later rooms open back onto earlier ones."""
obj Loop {
    has older: Prefab | None = None,
        mine: Port | None = None,
        theirs: Port | None = None;
}

"""A loop's passage where its stretches now lie, a leg at a time: [x, y,
direction, length, floor at its start, floor at its end, landing] (x, y
where its middle line starts, in the world's cells; a leg climbing or
falling a lift a cell after `landing` cells level). Straight, or bent
twice (a jog across), when the ways face each other; bent once when they
face across. Empty when no such passage joins them."""
def loop_path(later: Prefab, loop: Loop) -> list[list[float]] {
    older = loop.older;
    mine = loop.mine;
    theirs = loop.theirs;
    if older is None or mine is None or theirs is None {
        return [];
    }
    a = port_middle(later, mine);
    s = prefab_point(later, a[0], a[1]);
    b = port_middle(older, theirs);
    t = prefab_point(older, b[0], b[1]);
    out = prefab_direction(later, mine.face);
    back = (prefab_direction(older, theirs.face) + 2) % 4;
    step = prefab_step(out);
    last = prefab_step(back);
    dx = t[0] - s[0];
    dy = t[1] - s[1];
    turns: list[list[float]] = [];
    if out == back {
        along = dx * float(step[0]) + dy * float(step[1]);
        offset = dy if out % 2 == 0 else dx;
        if along < 8.0 {
            return [];
        }
        if abs(offset) < 0.5 {
            turns = [[float(out), along]];
        } elif abs(offset) < 4.0 {
            return [];
        } else {
            side = (1 if offset > 0.0 else 3) if out % 2 == 0 else (0 if offset > 0.0 else 2);
            first = float(math.floor(along * 0.5));
            turns = [[float(out), first], [float(side), abs(offset)], [float(out), along - first]];
        }
    } elif out % 2 != back % 2 {
        first = dx * float(step[0]) + dy * float(step[1]);
        second = dx * float(last[0]) + dy * float(last[1]);
        if first < 5.0 or second < 5.0 {
            return [];
        }
        turns = [[float(out), first], [float(back), second]];
    } else {
        return [];
    }
    low = float(later.oz + mine.floor);
    high = float(older.oz + theirs.floor);
    rise = high - low;
    climb = 0;
    for index in range(len(turns)) {
        if turns[index][1] > turns[climb][1] {
            climb = index;
        }
    }
    landing = 3.0 if climb == 0 else 1.0;
    if turns[climb][1] < abs(rise) + landing + 2.0 or abs(rise) > 16.0 {
        return [];
    }
    legs: list[list[float]] = [];
    x = s[0];
    y = s[1];
    floor = low;
    for index in range(len(turns)) {
        direction = int(turns[index][0]);
        length = turns[index][1];
        ends = high if index == climb else floor;
        legs.append([x, y, float(direction), length, floor, ends, landing if index == climb else 0.0]);
        move = prefab_step(direction);
        x += float(move[0]) * length;
        y += float(move[1]) * length;
        floor = ends;
    }
    return legs;
}

"""The boxes a loop's passage takes, its walls and a door's room in them
([x0, y0, x1, y1, z0, z1] each, z in lifts), a leg each; empty when no
passage joins its ways."""
def loop_boxes(later: Prefab, loop: Loop) -> list[list[int]] {
    found: list[list[int]] = [];
    legs = loop_path(later, loop);
    for (index, leg) in enumerate(legs) {
        move = prefab_step(int(leg[2]));
        # Past its end by half the passage's width, round the corner (not
        # the last, which ends at the way in).
        reach = leg[3] + (0.0 if index == len(legs) - 1 else 2.0);
        ex = leg[0] + float(move[0]) * reach;
        ey = leg[1] + float(move[1]) * reach;
        across = 5.0;
        x0 = min(leg[0], ex) - (across if move[0] == 0 else 0.0);
        x1 = max(leg[0], ex) + (across if move[0] == 0 else 0.0);
        y0 = min(leg[1], ey) - (across if move[1] == 0 else 0.0);
        y1 = max(leg[1], ey) + (across if move[1] == 0 else 0.0);
        found.append([int(math.floor(x0)), int(math.floor(y0)), int(math.ceil(x1)), int(math.ceil(y1)), int(min(leg[4], leg[5])) - 1, int(max(leg[4], leg[5])) + 10]);
    }
    return found;
}

"""Something in a level that fires or is fired, as the originals' own
triggers are: a touch, a button, a door, foes lying in wait, a train, a
relay. `items` are the fields of the entities it stands for (shared with
the casting, so naming them names the entities). A cue `Fires` the cues it
sets off; `Wire` gives each its names once all are laid down."""
node Cue {
    has items: list[dict[str, str]] = [],
        word: str = "cue";
}

edge Fires: Cue --> Cue {}

"""Names a cue's targets: walked from a cue that fires others, its entities
target a name of its own and every cue it fires answers to that name (or,
when it answers to another already, or is fired by more than one cue and
so answers to a name of its own, a relay of that name fires it)."""
walker Wire {
    has build: Raising,
        name: str = "";

    can wire with Cue entry {
        if not self.name {
            fired = [here->:Fires:->][?:Cue];
            if not fired {
                return;
            }
            self.name = self.build.cue_name(here.word);
            for item in here.items {
                item["target"] = self.name;
            }
            visit fired;
            return;
        }
        answered = [item.get("targetname", "") for item in here.items if item.get("targetname", "")];
        # Fired from more than one cue, it answers to a name of its own, each
        # firer's reaching it by a relay, so no firer fires what another's
        # name fires besides it.
        firers = [here<-:Fires:<-][?:Cue];
        if not answered and len(firers) > 1 {
            solo_name = self.build.cue_name(here.word);
            for item in here.items {
                item["targetname"] = solo_name;
            }
            answered = [solo_name];
        }
        if not answered {
            for item in here.items {
                item["targetname"] = self.name;
            }
        } elif self.name not in answered {
            self.build.casting.put({"classname": "trigger_relay", "targetname": self.name, "target": answered[0], "origin": "0 0 0"});
        }
    }
}

"""A point of a prefab's own cells (x, y) in the world's, by how the prefab
lies."""
def prefab_point(prefab: Prefab, x: float, y: float) -> list[float] {
    ly = float(prefab.wide) - y if prefab.mirror else y;
    turn = prefab.turn % 4;
    rx = x;
    ry = ly;
    if turn == 1 {
        rx = -ly;
        ry = x;
    } elif turn == 2 {
        rx = -x;
        ry = -ly;
    } elif turn == 3 {
        rx = ly;
        ry = -x;
    }
    return [rx + float(prefab.ox), ry + float(prefab.oy)];
}

"""The world's direction (0 +x, 1 +y, 2 -x, 3 -y) of a prefab's own."""
def prefab_direction(prefab: Prefab, face: int) -> int {
    mirrored = face;
    if prefab.mirror and face % 2 == 1 {
        mirrored = 4 - face;
    }
    return (mirrored + prefab.turn) % 4;
}

"""The step a direction takes, in cells."""
def prefab_step(direction: int) -> list[int] {
    if direction == 0 {
        return [1, 0];
    }
    if direction == 1 {
        return [0, 1];
    }
    if direction == 2 {
        return [-1, 0];
    }
    return [0, -1];
}

"""The middle of a port's opening, in a prefab's own cells."""
def port_middle(prefab: Prefab, port: Port) -> list[float] {
    if port.point {
        return [port.point[0], port.point[1]];
    }
    if port.face == 0 {
        return [float(prefab.long), float(port.along)];
    }
    if port.face == 1 {
        return [float(port.along), float(prefab.wide)];
    }
    if port.face == 2 {
        return [0.0, float(port.along)];
    }
    return [float(port.along), 0.0];
}

"""A prefab's box in the world's cells, [x0, y0, x1, y1, z0, z1] (z in
lifts)."""
def prefab_box(prefab: Prefab) -> list[int] {
    a = prefab_point(prefab, 0.0, 0.0);
    b = prefab_point(prefab, float(prefab.long), float(prefab.wide));
    return [
        int(round(min(a[0], b[0]))), int(round(min(a[1], b[1]))), int(round(max(a[0], b[0]))), int(round(max(a[1], b[1]))),
        prefab.oz + prefab.low, prefab.oz + prefab.high
    ];
}

"""Whether two boxes [x0, y0, x1, y1, z0, z1] overlap, `margin` cells apart
at least across (a box's own walls, floor and roof are inside it, so one
over another may touch)."""
def boxes_meet(a: list[int], b: list[int], margin: int) -> bool {
    across = a[0] < b[2] + margin and b[0] < a[2] + margin and a[1] < b[3] + margin and b[1] < a[3] + margin;
    if len(a) < 6 or len(b) < 6 {
        return across;
    }
    return across and a[4] < b[5] and b[4] < a[5];
}

"""The prefabs a prefab is reached through, the nearest first."""
def prefab_ancestors(prefab: Prefab) -> list[Prefab] {
    found: list[Prefab] = [];
    here = prefab;
    while True {
        before = [here<-:Next:<-][?:Prefab];
        if not before {
            return found;
        }
        here = before[0];
        found.append(here);
    }
    return found;
}

"""How many cells of box `a` stand over or under box `b` (each
[x0, y0, x1, y1, z0, z1], z in lifts) a storey or so apart (the lower's
roof under the higher's floor, eight lifts between at most), so a body in
one may see, hear or drop into the other."""
def stacked_cells(a: list[int], b: list[int]) -> int {
    across = max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]));
    if across == 0 {
        return 0;
    }
    gap = max(a[4] - b[5], b[4] - a[5]);
    return across if 0 <= gap and gap <= 8 else 0;
}

"""How long a wall box `a` shares with box `b` where they stand side by
side, four cells apart at most, their storeys overlapping eight lifts or
more (room for a shortcut between): the cells along it, short of their
corners; 0 when they do not."""
def beside_span(a: list[int], b: list[int]) -> int {
    rise = min(a[5], b[5]) - max(a[4], b[4]);
    if rise < 8 {
        return 0;
    }
    best = 0;
    gap = max(b[0] - a[2], a[0] - b[2]);
    if 0 <= gap and gap <= 4 {
        best = max(best, min(a[3], b[3]) - max(a[1], b[1]) - 6);
    }
    gap = max(b[1] - a[3], a[1] - b[3]);
    if 0 <= gap and gap <= 4 {
        best = max(best, min(a[2], b[2]) - max(a[0], b[0]) - 6);
    }
    return max(0, best);
}

"""The passage from a way out to the next way in: its box in the world's
cells [x0, y0, x1, y1], taking in the walls beside it."""
def passage_box(start: list[float], direction: int, gap: int, wide: int = PORT_WIDE, floor: int = -100000, high: int = 8, rise: int = 0) -> list[int] {
    x = int(round(start[0]));
    y = int(round(start[1]));
    half = wide // 2 + 3;
    z0 = floor + min(0, rise) - 1;
    z1 = floor + max(0, rise) + high + 1;
    if floor == -100000 {
        z0 = -100000;
        z1 = 100000;
    }
    if direction == 0 {
        return [x, y - half, x + gap, y + half, z0, z1];
    }
    if direction == 2 {
        return [x - gap, y - half, x, y + half, z0, z1];
    }
    if direction == 1 {
        return [x - half, y, x + half, y + gap, z0, z1];
    }
    return [x - half, y - gap, x + half, y, z0, z1];
}

"""Lays a chain of prefabs: each chooses itself (its own ability) and asks
to be placed."""
walker Lay {
    has dice: Stream,
        laid: list[Prefab] = [],
        taken: list[list[int]] = [],
        # The world's cells laid prefabs and passages take, a wall's cell
        # round each (for prefabs laid by their cells).
        filled: set[int] = set(),
        fits: bool = True,
        notes: list[str] = [];

    """A world cell's key in `filled`."""
    def cell_key(x: int, y: int, z: int) -> int {
        return ((z + 4096) * 8192 + (y + 4096)) * 8192 + (x + 4096);
    }

    """The world's cells a prefab's air takes, where it now lies."""
    def world_cells(prefab: Prefab) -> list[list[int]] {
        found: list[list[int]] = [];
        for cell in prefab.cells {
            at = prefab_point(prefab, float(cell[0]) + 0.5, float(cell[1]) + 0.5);
            found.append([int(math.floor(at[0])), int(math.floor(at[1])), cell[2] + prefab.oz]);
        }
        return found;
    }

    """The world's cells of the passage from a way out: `gap` cells on from
    `start` (its middle) the way `direction` goes, `wide` across and
    `high` up from `floor`."""
    def passage_cells(start: list[float], direction: int, gap: int, wide: int, high: int, floor: int) -> list[list[int]] {
        found: list[list[int]] = [];
        step = prefab_step(direction);
        across = float(wide) * 0.5;
        for along in range(gap) {
            for side in range(wide) {
                offset = float(side) - across + 0.5;
                x = start[0] + float(step[0]) * (float(along) + 0.5) + (offset if step[0] == 0 else 0.0);
                y = start[1] + float(step[1]) * (float(along) + 0.5) + (offset if step[1] == 0 else 0.0);
                for z in range(floor, floor + high) {
                    found.append([int(math.floor(x)), int(math.floor(y)), z]);
                }
            }
        }
        return found;
    }

    """Whether none of `cells` is taken."""
    def clear_of(cells: list[list[int]]) -> bool {
        for cell in cells {
            if self.cell_key(cell[0], cell[1], cell[2]) in self.filled {
                return False;
            }
        }
        return True;
    }

    """Take `cells` and a wall's cell round each."""
    def fill(cells: list[list[int]]) {
        for cell in cells {
            for dz in [-1, 0, 1] {
                for dy in [-1, 0, 1] {
                    for dx in [-1, 0, 1] {
                        self.filled.add(self.cell_key(cell[0] + dx, cell[1] + dy, cell[2] + dz));
                    }
                }
            }
        }
    }

    can go with Prefab entry {
        visit [here->:Next:->];
    }

    """The prefab a prefab is laid after (the one before it in the tree)."""
    def parent_of(prefab: Prefab) -> Prefab {
        found = [prefab<-:Next:<-][?:Prefab];
        return found[0] if found else self.laid[-1];
    }

    """Note that a prefab is reached from `last` by its way out `index`."""
    def take(last: Prefab, index: int, prefab: Prefab) {
        port = last.leaves[index];
        last.leave = port;
        last.taken.append(port);
        last.taken_index.append(index);
        prefab.via = port;
    }

    """The dice a prefab chooses itself by."""
    def dice_for(prefab: Prefab) -> Stream {
        return self.dice.child("prefab", prefab.number);
    }

    """The legs of a passage from `start` the way `direction` goes: `first`
    cells on, then (when `bend` is 1 or -1) a quarter turn that way and
    `second` cells more. Answers the legs' boxes in the world's cells, where
    the passage ends, the way it then goes, and where its door stands."""
    def route_of(start: list[float], direction: int, first: int, bend: int, second: int, wide: int) -> list[list[float]] {
        step = prefab_step(direction);
        half = float(wide) * 0.5;
        boxes: list[list[float]] = [];
        along_x = direction % 2 == 0;
        reach = float(first) + (float(wide) if bend != 0 else 0.0);
        ends = [start[0] + float(step[0]) * reach, start[1] + float(step[1]) * reach];
        if along_x {
            boxes.append([min(start[0], ends[0]), start[1] - half, max(start[0], ends[0]), start[1] + half]);
        } else {
            boxes.append([start[0] - half, min(start[1], ends[1]), start[0] + half, max(start[1], ends[1])]);
        }
        door = [(start[0] if along_x else start[1]) + float(step[0] + step[1]) * float(first) * 0.5];
        finish = [start[0] + float(step[0]) * float(first), start[1] + float(step[1]) * float(first)];
        heading = direction;
        if bend != 0 {
            heading = (direction + bend + 4) % 4;
            turn = prefab_step(heading);
            corner = [start[0] + float(step[0]) * (float(first) + half), start[1] + float(step[1]) * (float(first) + half)];
            begin = [corner[0] + float(turn[0]) * half, corner[1] + float(turn[1]) * half];
            finish = [begin[0] + float(turn[0]) * float(second), begin[1] + float(turn[1]) * float(second)];
            if heading % 2 == 0 {
                boxes.append([min(begin[0], finish[0]), corner[1] - half, max(begin[0], finish[0]), corner[1] + half]);
            } else {
                boxes.append([corner[0] - half, min(begin[1], finish[1]), corner[0] + half, max(begin[1], finish[1])]);
            }
        }
        boxes.append([finish[0], finish[1], float(heading), door[0]]);
        return boxes;
    }

    """Place a prefab laid by its cells after the last laid: by any of its
    ways in, mirrored either way, through a passage straight or bent once,
    short or long, its air and the passage clear of every cell laid."""
    def place_by_cells(prefab: Prefab, dice: Stream) -> bool {
        last = self.parent_of(prefab);
        entries = [prefab.ways_in[number] for number in dice.order(len(prefab.ways_in))] if prefab.ways_in else [prefab.enter];
        shapes: list[list[int]] = [[dice.between(3, 5), 0, 0]];
        for first in [4, 8, 16, 32] {
            for bend in [1, -1] {
                for second in [6, 12, 24, 48, 72] {
                    shapes.append([first, bend, second]);
                }
            }
        }
        for first in [8, 16, 24, 32, 48, 64, 96] {
            shapes.append([first, 0, 0]);
        }
        for way_in in entries {
            prefab.enter = way_in;
            if prefab.ways_in {
                # A way out the way in reaches (for a derived stretch, what a
                # body walks to inside it).
                prefab.leaves = [way for way in prefab.ways if way.number != way_in.number and (not way_in.groups or way.number in way_in.groups)];
                if prefab.ways and not prefab.leaves {
                    continue;
                }
            }
            for index in dice.order(len(last.leaves)) {
                if index in last.taken_index {
                    continue;
                }
                port = last.leaves[index];
                direction = prefab_direction(last, port.face);
                middle = port_middle(last, port);
                start = prefab_point(last, middle[0], middle[1]);
                wide = max(port.wide, way_in.wide);
                high = max(port.high, way_in.high);
                floor = last.oz + port.floor;
                for shape in shapes {
                    legs = self.route_of(start, direction, shape[0], shape[1], shape[2], wide);
                    tail = legs[-1];
                    heading = int(tail[2]);
                    walk: list[list[int]] = [];
                    boxes: list[list[int]] = [];
                    for leg in legs[:-1] {
                        box = [int(math.floor(leg[0] + 0.01)), int(math.floor(leg[1] + 0.01)), int(math.ceil(leg[2] - 0.01)), int(math.ceil(leg[3] - 0.01))];
                        boxes.append(box);
                        for y in range(box[1], box[3]) {
                            for x in range(box[0], box[2]) {
                                for z in range(floor, floor + high) {
                                    walk.append([x, y, z]);
                                }
                            }
                        }
                    }
                    if not self.clear_of(walk) {
                        continue;
                    }
                    for mirrored in [prefab.mirror, not prefab.mirror] {
                        prefab.mirror = mirrored;
                        face = prefab.enter.face;
                        if prefab.mirror and face % 2 == 1 {
                            face = 4 - face;
                        }
                        prefab.turn = ((heading + 2 - face) % 4 + 4) % 4;
                        prefab.ox = 0;
                        prefab.oy = 0;
                        inside = port_middle(prefab, prefab.enter);
                        inward = prefab_point(prefab, inside[0], inside[1]);
                        prefab.ox = int(round(tail[0] - inward[0]));
                        prefab.oy = int(round(tail[1] - inward[1]));
                        prefab.oz = floor - prefab.enter.floor;
                        mine = self.world_cells(prefab);
                        if not self.clear_of(mine) {
                            continue;
                        }
                        self.take(last, index, prefab);
                        prefab.gap = shape[0];
                        prefab.route = boxes;
                        prefab.route_floor = floor;
                        prefab.route_high = high;
                        prefab.route_x = direction % 2 == 0;
                        lead = boxes[0];
                        prefab.route_door = [tail[3], float(lead[1] if prefab.route_x else lead[0]), float(lead[3] if prefab.route_x else lead[2])];
                        self.laid.append(prefab);
                        self.taken.append(prefab_box(prefab));
                        self.fill(walk);
                        self.fill(mine);
                        return True;
                    }
                }
            }
        }
        return False;
    }

    """Place a prefab that has chosen itself: the first where it stands,
    each after it beyond a way out of the one before, clear of all laid."""
    def place(prefab: Prefab) {
        if not self.fits {
            return;
        }
        dice = self.dice_for(prefab).derive("place");
        # Tried alone (QP_PREFAB_SOLO), a stretch lies as it is drawn.
        solo = os.getenv("QP_PREFAB_SOLO", "") != "";
        prefab.mirror = False if solo else dice.chance(0.5);
        if self.laid and prefab.cells {
            if not self.place_by_cells(prefab, dice) {
                self.notes.append(prefab.title + " found no room after " + self.parent_of(prefab).title);
                self.fits = False;
            }
            return;
        }
        if not self.laid {
            prefab.turn = 0 if solo else dice.below(4);
            self.laid.append(prefab);
            self.taken.append(prefab_box(prefab));
            if prefab.cells {
                self.fill(self.world_cells(prefab));
            }
            return;
        }
        last = self.parent_of(prefab);
        # Tried alone, a stretch takes the first way out free, so it lies as
        # drawn behind the testbed's start (or the way out
        # QP_PREFAB_SOLO_LEAVE numbers, to try each).
        order = list(range(len(last.leaves))) if solo else dice.order(len(last.leaves));
        first_leave = int(os.getenv("QP_PREFAB_SOLO_LEAVE", "0"));
        if solo and last.source != "testbed" and 0 < first_leave < len(order) {
            order = [first_leave] + [index for index in order if index != first_leave];
        }
        parent_box = prefab_box(last);
        # The passage straight, or climbing or falling a lift a cell (a
        # landing a cell long at each end).
        shapes: list[list[int]] = [[dice.between(3, 5), 0]];
        for rise in [dice.between(4, 8), -dice.between(4, 8), dice.between(9, 12), -dice.between(9, 12), dice.between(13, 18), -dice.between(13, 18)] {
            shapes.append([abs(rise) + 2 + dice.below(2), rise]);
        }
        shapes = [shapes[0]] + [shapes[1 + number] for number in dice.order(len(shapes) - 1)];
        # Of the ways it fits, the one standing most over or under what is
        # laid (as the originals' stretches wind over and under each other);
        # the first that fits when none does.
        best: list[int] = [];
        best_stack = -1;
        ancestors = prefab_ancestors(prefab);
        for index in order {
            if index in last.taken_index {
                continue;
            }
            port = last.leaves[index];
            direction = prefab_direction(last, port.face);
            middle = port_middle(last, port);
            start = prefab_point(last, middle[0], middle[1]);
            step = prefab_step(direction);
            for shape in shapes {
                gap = shape[0];
                rise = shape[1];
                # Turned so its way in faces back the way the passage comes.
                face = prefab.enter.face;
                if prefab.mirror and face % 2 == 1 {
                    face = 4 - face;
                }
                prefab.turn = ((direction + 2 - face) % 4 + 4) % 4;
                prefab.ox = 0;
                prefab.oy = 0;
                inside = port_middle(prefab, prefab.enter);
                inward = prefab_point(prefab, inside[0], inside[1]);
                prefab.ox = int(round(start[0] + float(step[0] * gap) - inward[0]));
                prefab.oy = int(round(start[1] + float(step[1] * gap) - inward[1]));
                prefab.oz = last.oz + port.floor + rise - prefab.enter.floor;
                prefab.gap = gap;
                prefab.rise = rise;
                box = prefab_box(prefab);
                wide = max(port.wide, prefab.enter.wide);
                passage = passage_box(start, direction, gap, wide, last.oz + port.floor, max(port.high, prefab.enter.high), rise);
                clear = True;
                for other in self.taken {
                    # The box before it stands across the passage, a wall apart.
                    margin = 0 if other == parent_box else 1;
                    if boxes_meet(box, other, margin) {
                        clear = False;
                    }
                    if other != parent_box and boxes_meet(passage, other, 0) {
                        clear = False;
                    }
                }
                if clear {
                    # Over a stretch it is reached through counts thrice (a
                    # hatch may drop back into it), and beside one (a
                    # shortcut may lead back into it).
                    stack = 0;
                    for other in self.laid {
                        if other != last {
                            under = prefab_box(other);
                            over = stacked_cells(box, under);
                            if other in ancestors {
                                if box[4] >= under[5] - 1 {
                                    over *= 3;
                                }
                                over += 6 * beside_span(box, under);
                            }
                            stack += over;
                        }
                    }
                    if stack > best_stack {
                        best_stack = stack;
                        best = [index, gap, rise, prefab.turn, prefab.ox, prefab.oy, prefab.oz];
                    }
                }
            }
        }
        if best {
            prefab.turn = best[3];
            prefab.ox = best[4];
            prefab.oy = best[5];
            prefab.oz = best[6];
            prefab.gap = best[1];
            prefab.rise = best[2];
            port = last.leaves[best[0]];
            middle = port_middle(last, port);
            start = prefab_point(last, middle[0], middle[1]);
            wide = max(port.wide, prefab.enter.wide);
            self.take(last, best[0], prefab);
            self.laid.append(prefab);
            self.taken.append(passage_box(start, prefab_direction(last, port.face), best[1], wide, last.oz + port.floor, max(port.high, prefab.enter.high), best[2]));
            self.taken.append(prefab_box(prefab));
            return;
        }
        self.notes.append(prefab.title + " found no room after " + last.title);
        self.fits = False;
    }

    """Lay ways back once all are placed: from a way out a stretch left
    free to a free way out of one it was reached through (not the one just
    before it), by a passage clear of all laid; `most` of them, the latest
    stretches first."""
    def close_loops(chain: list[Prefab], most: int) {
        if not self.fits or os.getenv("QP_PREFAB_SOLO", "") != "" {
            return;
        }
        made = 0;
        for later in reversed(chain) {
            if made >= most or later.cells {
                break;
            }
            found = False;
            for older in prefab_ancestors(later)[1:] {
                if found {
                    break;
                }
                for mine_index in self.dice.order(len(later.leaves)) {
                    mine = later.leaves[mine_index];
                    if found or mine_index in later.taken_index or mine.gate {
                        continue;
                    }
                    for theirs_index in self.dice.order(len(older.leaves)) {
                        theirs = older.leaves[theirs_index];
                        # Onto the floor its way in stands on, so a body that
                        # comes to the door from that side came in walking
                        # (never stranded on a ledge it reached one way).
                        if theirs_index in older.taken_index or theirs.gate or theirs.floor != older.enter.floor {
                            continue;
                        }
                        loop = Loop(older=older, mine=mine, theirs=theirs);
                        boxes = loop_boxes(later, loop);
                        if not boxes {
                            continue;
                        }
                        clear = True;
                        for box in boxes {
                            for other in self.taken {
                                if boxes_meet(box, other, 0) {
                                    clear = False;
                                }
                            }
                        }
                        if not clear {
                            continue;
                        }
                        later.taken.append(mine);
                        later.taken_index.append(mine_index);
                        older.taken.append(theirs);
                        older.taken_index.append(theirs_index);
                        later.loops.append(loop);
                        self.taken.extend(boxes);
                        self.notes.append("loop from " + later.title + " back to " + older.title);
                        made += 1;
                        found = True;
                        break;
                    }
                }
            }
        }
    }
}

"""A door that slides or rises into rock: where the rock goes, so the door
opens into solid and not out of the world (the shell is a cell thick). The
rock stops short of any air."""
obj RockWant {
    has low: Vec3,
        high: Vec3;
}

"""What the prefabs raise: the massing, its spaces, the entities, and the
prefab being raised now (whose cells `Raising` reads)."""
obj Raising {
    has mass: Massing,
        dice: Stream,
        district: int = 0,
        spaces: list[Space] = [],
        casting: Casting = Casting(),
        rocks: list[RockWant] = [],
        # Boxes whose solid cells are all made rock (round a mover of a
        # derived stretch, whose walls are a cell thick).
        fills: list[RockWant] = [],
        # Liquid cells by the world's cell index: 2 water, 3 slime, 4 lava.
        wet: dict[int, int] = {},
        here: Prefab | None = None,
        notes: list[str] = [],
        # Every cue laid down, wired once all are (`wire_cues`).
        cues: list[Cue] = [],
        cue_count: int = 0,
        # The foes each stretch stood about in the open (no cue wakes them,
        # none fires on their death), by its number: what `thin` may take.
        loose_foes: dict[int, list[dict[str, str]]] = {};

    """Raise `prefab` next: its cells are read from now on."""
    def begin(prefab: Prefab) -> Stream {
        self.here = prefab;
        self.district = prefab.district;
        return self.dice.child("rise", prefab.number);
    }

    def:priv lying -> Prefab {
        prefab = self.here;
        if prefab is None {
            raise ValueError("No prefab is being raised");
        }
        return prefab;
    }

    """A box of the prefab's cells in the world's, [x0, y0, z0, x1, y1, z1]
    (x and y in cells, z in lifts)."""
    def cells(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> list[float] {
        prefab = self.lying();
        a = prefab_point(prefab, x0, y0);
        b = prefab_point(prefab, x1, y1);
        return [min(a[0], b[0]), min(a[1], b[1]), z0 + float(prefab.oz), max(a[0], b[0]), max(a[1], b[1]), z1 + float(prefab.oz)];
    }

    """A point of the prefab's cells (z in lifts) in world units."""
    def units(x: float, y: float, z: float) -> Vec3 {
        prefab = self.lying();
        at = prefab_point(prefab, x, y);
        return Vec3(x=at[0] * CELL, y=at[1] * CELL, z=(z + float(prefab.oz)) * LIFT);
    }

    """A box of the prefab's cells in world units, [low, high]."""
    def box_units(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> list[Vec3] {
        found = self.cells(x0, y0, z0, x1, y1, z1);
        return [Vec3(x=found[0] * CELL, y=found[1] * CELL, z=found[2] * LIFT), Vec3(x=found[3] * CELL, y=found[4] * CELL, z=found[5] * LIFT)];
    }

    """A heading of the prefab's own (degrees from its +x) as the world's."""
    def heading(angle: float) -> int {
        prefab = self.lying();
        turned = -angle if prefab.mirror else angle;
        return int(round(turned + 90.0 * float(prefab.turn))) % 360;
    }

    """The world's heading of one of the prefab's directions (0 +x, 1 +y,
    2 -x, 3 -y)."""
    def facing(direction: int) -> int {
        return prefab_direction(self.lying(), direction) * 90;
    }

    def:priv carve_cells(found: list[float], owner: int) {
        self.mass.carve(
            int(round(found[0])), int(round(found[1])), int(round(found[2])),
            int(round(found[3])), int(round(found[4])), int(round(found[5])), owner
        );
    }

    """A room (or passage) of air: the prefab's cells x0..x1, y0..y1, z0..z1,
    taking the materials of its district's variant. Answers its space."""
    def room(
        x0: int, y0: int, z0: int, x1: int, y1: int, z1: int,
        role: str = "room", variant: int = 0, sky: bool = False, flood: int = 0, deadly: bool = False
    ) -> Space {
        found = self.cells(float(x0), float(y0), float(z0), float(x1), float(y1), float(z1));
        space = Space(
            id=len(self.spaces),
            role=role,
            district=self.district,
            x=int(round(found[0])),
            y=int(round(found[1])),
            z=int(round(found[2])),
            w=int(round(found[3] - found[0])),
            d=int(round(found[4] - found[1])),
            h=int(round(found[5] - found[2])),
            sky=sky,
            variant=variant,
            flood=flood,
            deadly=deadly,
            levels=[int(round(found[2]))]
        );
        self.spaces.append(space);
        self.carve_cells(found, space.id);
        return space;
    }

    """A space over a box of the prefab's cells whose air is carved a cell at
    a time (`widen`), taking a district's materials."""
    def space(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, district: int) -> Space {
        found = self.cells(float(x0), float(y0), float(z0), float(x1), float(y1), float(z1));
        space = Space(
            id=len(self.spaces),
            district=district,
            x=int(round(found[0])),
            y=int(round(found[1])),
            z=int(round(found[2])),
            w=int(round(found[3] - found[0])),
            d=int(round(found[4] - found[1])),
            h=int(round(found[5] - found[2])),
            levels=[int(round(found[2]))]
        );
        self.spaces.append(space);
        return space;
    }

    """A cell of the prefab's that liquid fills (2 water, 3 slime, 4 lava)."""
    def liquid(x: int, y: int, z: int, code: int) {
        found = self.cells(float(x) + 0.5, float(y) + 0.5, float(z), float(x) + 0.5, float(y) + 0.5, float(z));
        cx = int(math.floor(found[0]));
        cy = int(math.floor(found[1]));
        cz = int(round(found[2]));
        if self.mass.inside(cx, cy, cz) {
            self.wet[(cz * self.mass.ny + cy) * self.mass.nx + cx] = code;
        }
    }

    """More air for a space."""
    def widen(space: Space, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) {
        self.carve_cells(self.cells(float(x0), float(y0), float(z0), float(x1), float(y1), float(z1)), space.id);
    }

    """Solid again: a ledge, a pillar, a step, an island."""
    def solid(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) {
        self.carve_cells(self.cells(float(x0), float(y0), float(z0), float(x1), float(y1), float(z1)), -1);
    }

    """Air where a mover of its own stands in a wall (a secret door, a panel
    that breaks), so the world's rock does not stand there too and it opens
    onto a way through: the box of the prefab's cells carved into the space
    of the air beside it (none when no air is beside it)."""
    def hollow(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
        found = self.cells(x0, y0, z0, x1, y1, z1);
        box = [int(round(value)) for value in found];
        owner = 0;
        for z in range(box[2], box[5]) {
            for y in range(box[1] - 1, box[4] + 1) {
                for x in range(box[0] - 1, box[3] + 1) {
                    if owner == 0 and self.mass.at(x, y, z) > 0 {
                        owner = self.mass.at(x, y, z);
                    }
                }
            }
        }
        if owner > 0 {
            self.mass.carve(box[0], box[1], box[2], box[3], box[4], box[5], owner - 1);
        }
    }

    """A floor level a space's lamps light (in the prefab's lifts)."""
    def level(space: Space, z: int) {
        lift = z + self.lying().oz;
        if lift not in space.levels {
            space.levels.append(lift);
        }
    }

    """A cell a space keeps clear of railings (a bridge's end, a stair's
    top), in the prefab's cells."""
    def keep(space: Space, x: int, y: int, z: int) {
        found = self.cells(float(x) + 0.5, float(y) + 0.5, float(z), float(x) + 0.5, float(y) + 0.5, float(z));
        space.kept.append([int(math.floor(found[0])), int(math.floor(found[1])), int(round(found[2]))]);
    }

    """The opening a port makes through the prefab's wall, as the air of
    `space`, and the cell inside it kept clear, so nothing stands in the way
    through."""
    def doorway(space: Space, port: Port) {
        prefab = self.lying();
        low = int(round(port.along - float(port.wide) * 0.5));
        high = low + port.wide;
        # Never through its own roof (that air would stand outside its walls).
        top = min(port.floor + port.high, prefab.high - 1);
        if port.face == 0 {
            self.widen(space, prefab.long - 2, low, port.floor, prefab.long, high, top);
        } elif port.face == 2 {
            self.widen(space, 0, low, port.floor, 2, high, top);
        } elif port.face == 1 {
            self.widen(space, low, prefab.wide - 2, port.floor, high, prefab.wide, top);
        } else {
            self.widen(space, low, 0, port.floor, high, 2, top);
        }
        for along in range(low, high) {
            if port.face == 0 {
                self.keep(space, prefab.long - 2, along, port.floor);
            } elif port.face == 2 {
                self.keep(space, 1, along, port.floor);
            } elif port.face == 1 {
                self.keep(space, along, prefab.wide - 2, port.floor);
            } else {
                self.keep(space, along, 1, port.floor);
            }
        }
    }

    """A name of the prefab's own, for targets."""
    def name(word: str) -> str {
        return "pf" + str(self.lying().number) + "_" + word;
    }

    """A point entity standing on a floor (the prefab's cells, z in lifts)."""
    def put_at(fields: dict[str, str], x: float, y: float, z: int) {
        at = self.units(x, y, float(z));
        fields["origin"] = origin_text(at.x, at.y, at.z + 24.0);
        self.casting.put(fields);
    }

    """A brush entity of one box (the prefab's cells, z in lifts)."""
    def put_box(fields: dict[str, str], x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, material: str) {
        corners = self.box_units(x0, y0, z0, x1, y1, z1);
        self.casting.put_brushed(fields, [plain_box(corners[0], corners[1], material, kit_of(self.district).scale)]);
    }

    """Where the player begins, facing a heading of the prefab's own."""
    def start(x: float, y: float, z: int, angle: float) {
        at = self.units(x, y, float(z));
        self.casting.start = [at.x, at.y, at.z + 24.0];
        self.casting.put({"classname": "info_player_start", "origin": origin_text(at.x, at.y, at.z + 24.0), "angle": str(self.heading(angle))});
    }

    """A foe standing on a floor, of one of `kinds`, facing a heading; its
    death fires `target` when one is given. Quake II's are told by their
    names, the rest are Quake's. One that `waits` on a cue lies in wait
    until it fires: Quake's wakes and comes for the player, Quake II's is
    not there until then (TRIGGER_SPAWN). One given a `patrol` (points of
    the prefab's cells on its floor) walks them round while idle."""
    def foe(x: float, y: float, z: int, kind: str, angle: float, target: str = "", waits: Cue | None = None, patrol: list[list[float]] | None = None) {
        game = "q2" if kind in Q2_FOES else "q1";
        fields = {"classname": kind, "angle": str(self.heading(angle)), "asset_game": game};
        if target {
            fields["target"] = target;
        }
        if waits is not None {
            waits.items.append(fields);
            if game == "q2" {
                fields["spawnflags"] = "2";
            }
        }
        if patrol is not None and patrol and not target {
            fields["target"] = self.path(patrol, z, True);
        }
        self.put_at(fields, x, y, z);
        self.casting.monsters += 1;
        prefab = self.here;
        if prefab is not None and not target and waits is None {
            self.loose_foes.setdefault(prefab.number, []).append(fields);
        }
    }

    """Take foes out of a stretch's loose ones, all but `share` of them (at
    random, rounded up when any are left at all), bosses staying whatever the
    share. Foes that a cue wakes stay: an ambush is a fight of its own."""
    def thin(prefab: Prefab, share: float, dice: Stream) {
        loose = self.loose_foes.get(prefab.number, []);
        common = [fields for fields in loose if foe_stats(fields.get("asset_game", "q1"), fields.get("classname", ""))[0] < PACE_BOSS];
        kept = int(math.ceil(float(len(common)) * share));
        order = dice.order(len(common));
        for index in order[kept:] {
            common[index]["thinned"] = "1";
            self.casting.monsters -= 1;
        }
        self.casting.items = [item for item in self.casting.items if "thinned" not in item.fields];
    }

    """A chain of path_corners through `points` (the prefab's cells) on lift
    `z`, round again to the first when `loop`. Answers the first's name."""
    def path(points: list[list[float]], z: int, loop: bool, pause: float = 0.0) -> str {
        names = [self.name("path" + str(len(self.casting.items) + index)) for index in range(len(points))];
        for index in range(len(points)) {
            fields = {"classname": "path_corner", "targetname": names[index]};
            if index + 1 < len(points) {
                fields["target"] = names[index + 1];
            } elif loop {
                fields["target"] = names[0];
            }
            if pause > 0.0 {
                fields["wait"] = str(pause);
            }
            at = self.units(points[index][0], points[index][1], float(z));
            fields["origin"] = origin_text(at.x, at.y, at.z + 24.0);
            self.casting.put(fields);
        }
        return names[0];
    }

    """A cue of the entities `items`, wired once all are laid down."""
    def cue(items: list[dict[str, str]], word: str) -> Cue {
        made = Cue(items=items, word=word);
        self.cues.append(made);
        return made;
    }

    """A name for what a cue fires."""
    def cue_name(word: str) -> str {
        self.cue_count += 1;
        return word + str(self.cue_count);
    }

    """Name every cue's targets (`Wire`), once all are laid down."""
    def wire_cues {
        for made in self.cues {
            made spawn Wire(build=self);
        }
    }

    """A touch of the prefab's cells box: fires its cue when a body walks
    into it (once, or again and again); `message` is shown to who touches
    it (a hint, a warning)."""
    def touch(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, once: bool = True, message: str = "") -> Cue {
        fields = {"classname": "trigger_once" if once else "trigger_multiple"};
        if message {
            fields["message"] = message;
        }
        if not once {
            fields["wait"] = "4";
        }
        self.put_box(fields, x0, y0, z0, x1, y1, z1, "trigger");
        return self.cue([fields], "touch");
    }

    """A secret: a box of the prefab's cells that counts as found when
    touched (and fires its cue)."""
    def secret(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> Cue {
        fields = {"classname": "trigger_secret"};
        self.put_box(fields, x0, y0, z0, x1, y1, z1, "trigger");
        return self.cue([fields], "secret");
    }

    """Foes to lie in wait: a cue for `foe(..., waits=)`, fired to let them
    loose."""
    def waiting -> Cue {
        return self.cue([], "foes");
    }

    """A button on a wall (as `button`) as a cue: pushed (or shot), it fires
    what it is wired to."""
    def push(x: float, y: float, z: float, direction: int, shot: bool = False) -> Cue {
        return self.cue([self.button(x, y, z, direction, "", shot)], "button");
    }

    """A door (as `rising_door`) that opens only when its cue fires."""
    def opened(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> Cue {
        fields = {"wait": "-1"};
        self.rising_door(x0, y0, z0, x1, y1, z1, fields);
        return self.cue([fields], "door");
    }

    """A floor that sinks when its cue fires: a block of the prefab's cells
    x0..x1, y0..y1 filling a shaft from lift `top` down `drop` lifts, that
    goes down the shaft to its foot and stays (Quake's func_door moving
    down), carrying whoever stands on it; rock under the shaft to sink into."""
    def sinking(x0: float, y0: float, x1: float, y1: float, top: int, drop: int) -> Cue {
        fields = {"classname": "func_door", "angle": "-2", "speed": "60", "wait": "-1", "lip": "0"};
        self.put_box(fields, x0, y0, float(top - drop), x1, y1, float(top), kit_of(self.district).step);
        corners = self.box_units(x0, y0, float(top - 2 * drop), x1, y1, float(top - drop));
        self.rocks.append(RockWant(low=corners[0], high=corners[1]));
        self.casting.doors += 1;
        return self.cue([fields], "floor");
    }

    """A bridge (as `bridge`) drawn out when its cue fires."""
    def drawn(x0: float, y0: float, x1: float, y1: float, top: int, sink: int) -> Cue {
        return self.cue([self.bridge(x0, y0, x1, y1, top, sink, "")], "bridge");
    }

    """A relay: fired, it fires what it is wired to `delay` seconds on."""
    def delay(seconds: float) -> Cue {
        fields = {"classname": "trigger_relay", "delay": str(seconds), "origin": "0 0 0"};
        self.casting.put(fields);
        return self.cue([fields], "relay");
    }

    """A counter: fired `count` times (each by its own cue), it fires what
    it is wired to; `message` counts down to who fires it."""
    def tally(count: int, message: str) -> Cue {
        fields = {"classname": "trigger_counter", "count": str(count), "origin": "0 0 0"};
        if message {
            fields["message"] = message;
        }
        self.casting.put(fields);
        return self.cue([fields], "counter");
    }

    """A point entity of `game`'s at the prefab's cell point (x, y), `z`
    lifts up (not stood on a floor: in a wall, in the air)."""
    def put_point(fields: dict[str, str], x: float, y: float, z: float, game: str) {
        at = self.units(x, y, z);
        fields["origin"] = origin_text(at.x, at.y, at.z);
        fields["asset_game"] = game;
        self.casting.put(fields);
    }

    """Quake II's breakable: a box of the prefab's cells drawn in the
    district's wall that breaks apart when shot enough (`health`), firing
    its cue's targets as it goes (a panel over a stash, a grate)."""
    def breakable(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, health: int) -> Cue {
        self.hollow(x0, y0, z0, x1, y1, z1);
        fields = {"classname": "func_explosive", "health": str(health), "asset_game": "q2"};
        self.put_box(fields, x0, y0, z0, x1, y1, z1, kit_of(self.district).wall);
        return self.cue([fields], "breakable");
    }

    """Quake's spike shooter set in a wall at (x, y), `z` lifts up, firing
    the way `direction` goes (0 +x ... 3 -y) each time its cue fires."""
    def spikes(x: float, y: float, z: float, direction: int) -> Cue {
        fields = {"classname": "trap_spikeshooter", "angle": str(self.facing(direction))};
        self.put_point(fields, x, y, z, "q1");
        return self.cue([fields], "spikes");
    }

    """Quake II's explosion at (x, y), `z` lifts up, when its cue fires: a
    show, harmless (`damage` 0) unless told otherwise."""
    def explosion(x: float, y: float, z: float, damage: int = 0) -> Cue {
        fields = {"classname": "target_explosion", "dmg": str(damage)};
        self.put_point(fields, x, y, z, "q2");
        return self.cue([fields], "blast");
    }

    """Quake II's sparks from (x, y), `z` lifts up, out the way `direction`
    goes, when its cue fires (a broken pipe, a shorting panel)."""
    def sparks(x: float, y: float, z: float, direction: int) -> Cue {
        fields = {"classname": "target_splash", "angle": str(self.facing(direction)), "count": "12", "sounds": "1"};
        self.put_point(fields, x, y, z, "q2");
        return self.cue([fields], "sparks");
    }

    """Quake II's timer: fires what it is wired to every `seconds` (a
    little more or less), from the start."""
    def timer(seconds: float) -> Cue {
        fields = {"classname": "func_timer", "wait": str(seconds), "random": str(seconds * 0.3), "spawnflags": "1", "origin": "0 0 0", "asset_game": "q2"};
        self.casting.put(fields);
        return self.cue([fields], "timer");
    }

    """Quake II's help computer: when its cue fires, the objective reads
    `message` (the main one when `primary`)."""
    def objective(message: str, primary: bool = True) -> Cue {
        fields = {"classname": "target_help", "message": message, "spawnflags": "1" if primary else "0", "origin": "0 0 0", "asset_game": "q2"};
        self.casting.put(fields);
        return self.cue([fields], "help");
    }

    """A foe brought in when its cue fires: it stands sealed in a closet of
    the prefab's cells (x0..x0+3, y0..y0+3, z0..z0+6, in rock where no one
    goes) on a teleporter that wakes with the cue and sends it to (tx, ty)
    on lift `tz`, facing a heading of the prefab's own (Quake's teleported
    ambush)."""
    def summon(x0: int, y0: int, z0: int, kind: str, tx: float, ty: float, tz: int, angle: float) -> Cue {
        self.room(x0, y0, z0, x0 + 3, y0 + 3, z0 + 6);
        arrive = self.name("summon" + str(len(self.casting.items)));
        fields = {"classname": "trigger_teleport", "target": arrive};
        self.put_box(fields, float(x0), float(y0), float(z0), float(x0 + 3), float(y0 + 3), float(z0 + 4), "trigger");
        landing = self.units(tx, ty, float(tz));
        self.casting.put({"classname": "info_teleport_destination", "targetname": arrive, "origin": origin_text(landing.x, landing.y, landing.z + 32.0), "angle": str(self.heading(angle))});
        self.foe(float(x0) + 1.5, float(y0) + 1.5, z0, kind, angle);
        made = Cue(items=[fields], word="summon");
        self.cues.append(made);
        return made;
    }

    """Steps that rise out of a floor when their cue fires: `count` blocks
    of the prefab's cells, each a cell along the way `direction` goes
    (0 +x ... 3 -y) from (x, y), `width` cells across, flush with the floor
    on lift `z` until fired, then risen a lift more each than the last (a
    stair up to lift z + count): drawn out as bridges are, so a proof reads
    its steps as there once fired."""
    def rising_steps(x: int, y: int, z: int, direction: int, count: int, width: int) -> Cue {
        items: list[dict[str, str]] = [];
        kit = kit_of(self.district);
        for step in range(count) {
            at_x = x + step if direction == 0 else (x - step if direction == 2 else x);
            at_y = y + step if direction == 1 else (y - step if direction == 3 else y);
            x1 = at_x + (1 if direction % 2 == 0 else width);
            y1 = at_y + (width if direction % 2 == 0 else 1);
            rise = step + 1;
            # Quake's START_OPEN door placed where it stands risen: it waits
            # sunk its own height under the floor, in rock, and shuts up
            # into its step when fired (each on its own, DONT_LINK).
            fields = {"classname": "func_door", "angle": "-2", "speed": "40", "wait": "-1", "lip": "0", "spawnflags": "5"};
            self.put_box(fields, float(at_x), float(at_y), float(z), float(x1), float(y1), float(z + rise), kit.step);
            sunk = self.box_units(float(at_x), float(at_y), float(z - rise), float(x1), float(y1), float(z));
            self.rocks.append(RockWant(low=sunk[0], high=sunk[1]));
            items.append(fields);
            self.casting.doors += 1;
        }
        return self.cue(items, "steps");
    }

    """A train: a platform of the prefab's cells `size` [across x, across y,
    lifts thick] riding from point to point of `stops` ([x, y, z] in the
    prefab's cells, each where the platform's low corner comes to) and round
    again, waiting `pause` seconds at each. It runs from the start, or (when
    `fired`) from when its cue fires."""
    def train(size: list[float], stops: list[list[float]], speed: float, pause: float, fired: bool = False) -> Cue {
        names = [self.name("stop" + str(len(self.casting.items) + index)) for index in range(len(stops))];
        for index in range(len(stops)) {
            stop = stops[index];
            low = self.box_units(stop[0], stop[1], stop[2], stop[0] + size[0], stop[1] + size[1], stop[2] + size[2])[0];
            self.casting.put({"classname": "path_corner", "targetname": names[index], "target": names[(index + 1) % len(stops)], "wait": str(pause), "origin": origin_text(low.x, low.y, low.z)});
        }
        fields = {"classname": "func_train", "target": names[0], "speed": str(speed), "dmg": "0"};
        first = stops[0];
        self.put_box(fields, first[0], first[1], first[2], first[0] + size[0], first[1] + size[1], first[2] + size[2], kit_of(self.district).step);
        return self.cue([fields] if fired else [], "train");
    }

    """A pickup lying on a floor, of `game`'s."""
    def supply(x: float, y: float, z: int, kind: str, game: str = "q1") {
        self.put_at({"classname": kind, "asset_game": game}, x, y, z);
    }

    """A door in the prefab's cells that rises when touched or fired, with
    rock over it to rise into."""
    def rising_door(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, fields: dict[str, str]) {
        fields["classname"] = "func_door";
        fields["angle"] = "-1";
        if "speed" not in fields {
            fields["speed"] = "120";
        }
        if "lip" not in fields {
            fields["lip"] = "8";
        }
        self.put_box(fields, x0, y0, z0, x1, y1, z1, kit_of(self.district).door);
        # Rock in every solid cell over it, as high as it rises and a body's
        # height more, so nothing stands on it opened.
        self.rock_round(x0, y0, z1, x1, y1, z1 + (z1 - z0) + 5.0);
        self.casting.doors += 1;
    }

    """A button on a wall: its face at the prefab's cell line `x` (or `y`)
    facing `direction` (0 +x ... 3 -y, the way out of the wall), its middle
    at (x, y) and `z` lifts up, pushed back into the wall when touched (or
    shot, when `shot`)."""
    def button(x: float, y: float, z: float, direction: int, target: str, shot: bool = False) -> dict[str, str] {
        depth = 0.25;
        half = 0.4;
        tall = 1.4;
        x0 = x - half;
        x1 = x + half;
        y0 = y - half;
        y1 = y + half;
        if direction == 0 {
            x0 = x;
            x1 = x + depth;
        } elif direction == 2 {
            x0 = x - depth;
            x1 = x;
        } elif direction == 1 {
            y0 = y;
            y1 = y + depth;
        } else {
            y0 = y - depth;
            y1 = y;
        }
        fields = {"classname": "func_button", "angle": str(self.facing((direction + 2) % 4)), "wait": "-1", "lip": "4"};
        if target {
            fields["target"] = target;
        }
        if shot {
            fields["health"] = "1";
        }
        self.put_box(fields, x0, y0, z, x1, y1, z + tall, BUTTON_MATERIAL);
        return fields;
    }

    """A bridge drawn out across a gap when fired: Quake's START_OPEN
    func_door, its deck the prefab's cells x0..x1, y0..y1 with its top at
    lift `top`, a block `sink` lifts deep. Until it is fired it lies sunk
    under the floor of the pit below (`sink` takes in the pit and a lift
    more), in rock, where nothing can stand on it."""
    def bridge(x0: float, y0: float, x1: float, y1: float, top: int, sink: int, target: str) -> dict[str, str] {
        fields = {"classname": "func_door", "spawnflags": "1", "angle": "-2", "speed": "80", "wait": "-1", "lip": "8"};
        if target {
            fields["targetname"] = target;
        }
        self.put_box(fields, x0, y0, float(top - sink), x1, y1, float(top), kit_of(self.district).step);
        travel = float(sink) - 0.5;
        corners = self.box_units(x0, y0, float(top - sink) - travel, x1, y1, float(top) - travel);
        self.rocks.append(RockWant(low=corners[0], high=corners[1]));
        return fields;
    }

    """A relay: firing `name` fires `target` too."""
    def relay(x: float, y: float, z: int, name: str, target: str) {
        self.put_at({"classname": "trigger_relay", "targetname": name, "target": target}, x, y, z);
    }

    """A counter: fired `count` times, it fires `target`."""
    def counter(x: float, y: float, z: int, name: str, count: int, target: str, message: str) {
        self.put_at({"classname": "trigger_counter", "targetname": name, "count": str(count), "target": target, "message": message}, x, y, z);
    }

    """A pool of liquid in the prefab's cells x0..x1, y0..y1, z0..z1, carved
    as a room of its own (a deadly one glows): the liquid (`code` 2 water, 3
    slime, 4 lava) fills it to a lift below its rim, so a swimmer jumps out
    as from the originals' pools (`brim` fills it to the top). `both` puts
    steps along its far side too, for a pool split across by a walkway.
    Answers its space."""
    def pool(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, code: int, brim: bool = False, steps: bool = True, both: bool = False) -> Space {
        space = self.room(x0, y0, z0, x1, y1, z1, deadly=code >= 3);
        for z in range(z0, z1 if brim else z1 - 1) {
            for y in range(y0, y1) {
                for x in range(x0, x1) {
                    self.liquid(x, y, z, code);
                }
            }
        }
        # Steps up out of it along its near side, a lift a cell, so nothing
        # that falls in is kept there (unless `steps` says it need not be).
        depth = z1 - z0;
        if steps and depth > 1 {
            span = y1 - y0;
            wide = min(2, x1 - x0);
            if span >= depth {
                for step in range(depth) {
                    self.solid(x0, y0 + step, z0, x0 + wide, y0 + step + 1, z0 + step + 1);
                    if both {
                        self.solid(x0, y1 - step - 1, z0, x0 + wide, y1 - step, z0 + step + 1);
                    }
                }
            } elif x1 - x0 >= depth {
                for step in range(depth) {
                    self.solid(x0 + step, y0, z0, x0 + step + 1, y0 + min(2, span), z0 + step + 1);
                }
            }
        }
        return space;
    }

    """A teleporter: a pad on the floor at the prefab's cell point (x, y),
    lift `z`, that sends a body touching it to (tx, ty) on lift `tz`,
    facing a heading of the prefab's own."""
    def teleporter(x: float, y: float, z: int, tx: float, ty: float, tz: int, angle: float) {
        name = self.name("tele" + str(len(self.casting.items)));
        at = self.units(x, y, float(z));
        self.casting.put_brushed(
            {"classname": "func_wall", "_passion": "teleporter"},
            [plain_box(Vec3(x=at.x - 24.0, y=at.y - 24.0, z=at.z), Vec3(x=at.x + 24.0, y=at.y + 24.0, z=at.z + 4.0), TELEPORT_MATERIAL, 1.0)]
        );
        self.casting.put_brushed(
            {"classname": "trigger_teleport", "target": name},
            [plain_box(Vec3(x=at.x - 20.0, y=at.y - 20.0, z=at.z + 4.0), Vec3(x=at.x + 20.0, y=at.y + 20.0, z=at.z + 68.0), "trigger", 1.0)]
        );
        arrive = self.units(tx, ty, float(tz));
        self.casting.put({"classname": "info_teleport_destination", "targetname": name, "origin": origin_text(arrive.x, arrive.y, arrive.z + 32.0), "angle": str(self.heading(angle))});
        self.casting.put({"classname": "light", "origin": origin_text(at.x, at.y, at.z + 64.0), "light": "180", "_color": "180 200 255"});
    }

    """A jump pad on the floor at the prefab's cell point (x, y), lift `z`,
    that throws a body over to (tx, ty) on lift `tz` (Quake III's
    trigger_push at its target)."""
    def jump_pad(x: float, y: float, z: int, tx: float, ty: float, tz: int) {
        name = self.name("pad" + str(len(self.casting.items)));
        at = self.units(x, y, float(z));
        self.casting.put_brushed(
            {"classname": "func_wall", "_passion": "jumppad"},
            [plain_box(Vec3(x=at.x - 24.0, y=at.y - 24.0, z=at.z), Vec3(x=at.x + 24.0, y=at.y + 24.0, z=at.z + 4.0), BUTTON_MATERIAL, 1.0)]
        );
        self.casting.put_brushed(
            {"classname": "trigger_push", "target": name},
            [plain_box(Vec3(x=at.x - 24.0, y=at.y - 24.0, z=at.z + 4.0), Vec3(x=at.x + 24.0, y=at.y + 24.0, z=at.z + 40.0), "trigger", 1.0)]
        );
        arrive = self.units(tx, ty, float(tz));
        self.casting.put({"classname": "info_notnull", "targetname": name, "origin": origin_text(arrive.x, arrive.y, max(at.z, arrive.z) + 96.0)});
    }

    """A secret door: a box of the prefab's cells drawn as the wall, that
    opens (back, then aside) when shot, with rock round it to open into.
    `direction` (0 +x ... 3 -y) is the way it slides back into the wall."""
    def secret_door(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) {
        self.hollow(x0, y0, z0, x1, y1, z1);
        kit = kit_of(self.district);
        self.put_box({"classname": "func_door_secret", "angle": str(self.facing(direction)), "sounds": "1"}, x0, y0, z0, x1, y1, z1, kit.wall);
        reach = max(x1 - x0, y1 - y0) + 1.0;
        self.rock_round(x0 - reach, y0 - reach, z0, x1 + reach, y1 + reach, z1 + 1.0);
    }

    """The way out: a pad of the slipgate's light on a floor, the box that
    ends the level over it, and a lamp."""
    def way_out(x: float, y: float, z: int) {
        low = self.units(x - 1.0, y - 1.0, float(z));
        high = self.units(x + 1.0, y + 1.0, float(z));
        a = Vec3(x=min(low.x, high.x), y=min(low.y, high.y), z=low.z);
        b = Vec3(x=max(low.x, high.x), y=max(low.y, high.y), z=low.z + 8.0);
        self.casting.put_brushed({"classname": "func_wall", "_passion": "exit"}, [plain_box(a, b, TELEPORT_MATERIAL, 1.0)]);
        self.casting.put({"classname": "light", "origin": origin_text((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, a.z + 56.0), "light": "300", "_color": "200 220 255"});
        self.casting.exit_low = [a.x, a.y, a.z + 2.0];
        self.casting.exit_high = [b.x, b.y, a.z + 96.0];
    }

    """The passage from the way out of `before` into the way in of `after`:
    as wide as both doorways taken together, with a double door halfway
    along whose halves slide apart into its walls. The door wants what the
    way out's port says (a key, or its targetname fired)."""
    def join(before: Prefab, after: Prefab) {
        port = after.via;
        if port is None {
            port = before.leave;
        }
        if port is None {
            return;
        }
        gate = after.locked if after.locked else port.gate;
        if after.route {
            self.join_route(gate, after);
            return;
        }
        enter = after.enter;
        direction = prefab_direction(before, port.face);
        step = prefab_step(direction);
        middle = port_middle(before, port);
        start = prefab_point(before, middle[0], middle[1]);
        inner = port_middle(after, enter);
        finish = prefab_point(after, inner[0], inner[1]);
        floor = before.oz + port.floor;
        high = max(port.high, enter.high);
        along_x = direction % 2 == 0;
        near_mid = start[1] if along_x else start[0];
        far_mid = finish[1] if along_x else finish[0];
        lo = int(math.floor(min(near_mid - float(port.wide) * 0.5, far_mid - float(enter.wide) * 0.5) + 0.01));
        hi = int(math.ceil(max(near_mid + float(port.wide) * 0.5, far_mid + float(enter.wide) * 0.5) - 0.01));
        near_at = int(round(start[0] if along_x else start[1]));
        far_at = int(round(finish[0] if along_x else finish[1]));
        a0 = min(near_at, far_at);
        a1 = max(near_at, far_at);
        rise = after.rise;
        x0 = a0 if along_x else lo;
        x1 = a1 if along_x else hi;
        y0 = lo if along_x else a0;
        y1 = hi if along_x else a1;
        space = Space(id=len(self.spaces), role="corridor", district=self.district, x=x0, y=y0, z=floor + min(0, rise), w=x1 - x0, d=y1 - y0, h=high + abs(rise), levels=[floor, floor + rise]);
        self.spaces.append(space);
        # A cell of passage at a time: a landing, then a lift a cell up (or
        # down) to the far landing.
        climb = 1 if rise > 0 else -1;
        for at in range(a0, a1) {
            k = at - near_at if step[0] + step[1] > 0 else near_at - 1 - at;
            lift = floor + climb * min(abs(rise), max(0, k - 1));
            if along_x {
                self.mass.carve(at, lo, lift, at + 1, hi, lift + high, space.id);
            } else {
                self.mass.carve(lo, at, lift, hi, at + 1, lift + high, space.id);
            }
        }
        # The door on the first landing (halfway along a level passage).
        door_at = float(near_at) + float(step[0] + step[1]) * (1.0 if rise != 0 else float(a1 - a0) * 0.5);
        self.passage_door(gate, along_x, door_at, float(lo), float(hi), floor, high);
    }

    """A way back (`Loop`) from `later`: its passage a leg at a time, each
    leg a corridor climbing or falling a lift a cell where it must, and a
    door two cells in from `later`'s way out, opened by walking up to it
    from that side (so it never lets a body round what bars `later`)."""
    def loop_passage(later: Prefab, loop: Loop) {
        legs = loop_path(later, loop);
        mine = loop.mine;
        theirs = loop.theirs;
        if not legs or mine is None or theirs is None {
            return;
        }
        wide = mine.wide;
        half = float(wide) * 0.5;
        high = max(mine.high, theirs.high);
        self.district = later.district;
        for (index, leg) in enumerate(legs) {
            direction = int(leg[2]);
            move = prefab_step(direction);
            length = int(round(leg[3])) + (0 if index == len(legs) - 1 else wide // 2);
            rise = int(round(leg[5] - leg[4]));
            landing = int(leg[6]);
            climb = 1 if rise > 0 else -1;
            space = Space(id=len(self.spaces), role="corridor", district=later.district, x=0, y=0, z=int(min(leg[4], leg[5])), w=1, d=1, h=high + abs(rise), levels=[int(leg[4]), int(leg[5])]);
            self.spaces.append(space);
            lows: list[int] = [];
            highs: list[int] = [];
            for k in range(length) {
                floor = int(leg[4]) + climb * min(abs(rise), max(0, k - landing)) if rise != 0 else int(leg[4]);
                along = leg[0] + float(move[0]) * float(k) if move[0] != 0 else leg[1] + float(move[1]) * float(k);
                a0 = int(math.floor(min(along, along + float(move[0] + move[1])) + 0.01));
                if move[0] != 0 {
                    c0 = int(math.floor(leg[1] - half + 0.01));
                    self.mass.carve(a0, c0, floor, a0 + 1, c0 + wide, floor + high, space.id);
                    lows = [min(lows[0], a0), min(lows[1], c0)] if lows else [a0, c0];
                    highs = [max(highs[0], a0 + 1), max(highs[1], c0 + wide)] if highs else [a0 + 1, c0 + wide];
                } else {
                    c0 = int(math.floor(leg[0] - half + 0.01));
                    self.mass.carve(c0, a0, floor, c0 + wide, a0 + 1, floor + high, space.id);
                    lows = [min(lows[0], c0), min(lows[1], a0)] if lows else [c0, a0];
                    highs = [max(highs[0], c0 + wide), max(highs[1], a0 + 1)] if highs else [c0 + wide, a0 + 1];
                }
            }
            if lows {
                space.x = lows[0];
                space.y = lows[1];
                space.w = highs[0] - lows[0];
                space.d = highs[1] - lows[1];
            }
        }
        # The door across the first leg, and the touch before it.
        first = legs[0];
        move = prefab_step(int(first[2]));
        along_x = move[0] != 0;
        start = first[0] if along_x else first[1];
        sign = float(move[0] + move[1]);
        middle = first[1] if along_x else first[0];
        floor = int(first[4]);
        gate = self.cue_name("loop");
        self.passage_door(gate, along_x, start + sign * 2.0, middle - half, middle + half, floor, high);
        t0 = min(start, start + sign * 1.5);
        t1 = max(start, start + sign * 1.5);
        low = Vec3(x=t0 * CELL, y=(middle - half) * CELL, z=float(floor) * LIFT) if along_x else Vec3(x=(middle - half) * CELL, y=t0 * CELL, z=float(floor) * LIFT);
        top = Vec3(x=t1 * CELL, y=(middle + half) * CELL, z=float(floor + high) * LIFT) if along_x else Vec3(x=(middle + half) * CELL, y=t1 * CELL, z=float(floor + high) * LIFT);
        self.casting.put_brushed({"classname": "trigger_once", "target": gate}, [plain_box(low, top, "trigger", 1.0)]);
        older = loop.older;
        self.notes.append("loop from " + later.title + " back into " + (older.title if older is not None else "?") + " over " + str(len(legs)) + " legs");
    }

    """A passage laid as a route (`Lay.place_by_cells`): each leg a corridor,
    and the double door across the first leg."""
    def join_route(gate: str, after: Prefab) {
        for box in after.route {
            space = Space(id=len(self.spaces), role="corridor", district=self.district, x=box[0], y=box[1], z=after.route_floor, w=box[2] - box[0], d=box[3] - box[1], h=after.route_high, levels=[after.route_floor]);
            self.spaces.append(space);
            self.mass.carve(box[0], box[1], after.route_floor, box[2], box[3], after.route_floor + after.route_high, space.id);
        }
        self.passage_door(gate, after.route_x, after.route_door[0], after.route_door[1], after.route_door[2], after.route_floor, after.route_high);
    }

    """A double door across a passage: a slab a half cell thick at `mid`
    along it (x when `along_x`), from `lo` to `hi` across, split at its
    middle, each half sliding into its own wall; it wants `gate` (a key, a
    targetname, or nothing)."""
    def passage_door(gate: str, along_x: bool, mid: float, lo: float, hi: float, floor: int, high: int) {
        kit = kit_of(self.district);
        fields = {"classname": "func_door", "speed": "140", "wait": "3", "lip": "8"};
        # Passion's doors say the keys they want outright.
        if gate.startswith("key_") {
            fields["key"] = gate;
        } elif gate {
            fields["targetname"] = gate;
            fields["wait"] = "-1";
        }
        split = (lo + hi) * 0.5;
        for side in [1, -1] {
            across_lo = split if side > 0 else lo;
            across_hi = hi if side > 0 else split;
            span = (across_hi - across_lo) * float(side) * CELL;
            if along_x {
                low = Vec3(x=(mid - 0.25) * CELL, y=across_lo * CELL, z=float(floor) * LIFT);
                top = Vec3(x=(mid + 0.25) * CELL, y=across_hi * CELL, z=float(floor + high) * LIFT);
                heading = 90 if side > 0 else 270;
                shift = Vec3(y=span);
            } else {
                low = Vec3(x=across_lo * CELL, y=(mid - 0.25) * CELL, z=float(floor) * LIFT);
                top = Vec3(x=across_hi * CELL, y=(mid + 0.25) * CELL, z=float(floor + high) * LIFT);
                heading = 0 if side > 0 else 180;
                shift = Vec3(x=span);
            }
            half = dict(fields);
            half["angle"] = str(heading);
            self.casting.put_brushed(half, [plain_box(low, top, kit.door, kit.scale)]);
            self.rocks.append(RockWant(low=low.add(shift), high=top.add(shift)));
            self.casting.doors += 1;
        }
    }

    """Ways between stretches that their passages do not make, as the
    originals' stretches meet: a hatch in a stretch's floor that drops a
    body into one it was reached through, under it (a way back the branch
    did not come by), and barred windows between stretches side by side
    (a look into what is ahead, or down into what is behind)."""
    def weave(chain: list[Prefab], hatching: bool = True) {
        taken = self.entity_boxes();
        hatches = 0;
        for prefab in chain {
            if hatches >= 3 or not hatching {
                break;
            }
            for older in prefab_ancestors(prefab) {
                if self.hatch(prefab, older, taken) {
                    hatches += 1;
                    break;
                }
            }
        }
        windows = 0;
        for index in range(len(chain)) {
            for other in chain[index + 1:] {
                if windows < 4 and self.window(chain[index], other, taken) {
                    windows += 1;
                }
            }
        }
        shortcuts = 0;
        for prefab in chain {
            if shortcuts >= 3 {
                break;
            }
            for older in prefab_ancestors(prefab)[1:] {
                if os.getenv("QP_WEAVE_DEBUG", "") {
                    self.notes.append("beside " + prefab.title + " / " + older.title + " span " + str(beside_span(prefab_box(prefab), prefab_box(older))) + " boxes " + str(prefab_box(prefab)) + " " + str(prefab_box(older)));
                }
                if self.shortcut(prefab, older, taken) {
                    shortcuts += 1;
                    break;
                }
            }
        }
        self.notes.append("woven: " + str(hatches) + " hatches, " + str(windows) + " windows, " + str(shortcuts) + " shortcuts");
    }

    """Ceilings of the stretches' big rooms risen into the rock over them, as
the originals' great halls stand far taller than their floors are wide: each
room's air under a flat ceiling of its own, raised flat, in steps inward or
round a lantern in its middle (by the stretch's dice, some left as they
were). Only where rock stands all the way up and on every side, so it opens
into nothing; never over a mover's or a thing's reach."""
    def vault(chain: list[Prefab], dice: Stream) {
        boxes = self.entity_boxes();
        for prefab in chain {
            self.vault_stretch(prefab, boxes, dice.child("stretch", prefab.number));
        }
    }

    def:priv vault_stretch(prefab: Prefab, boxes: list[list[float]], dice: Stream) {
        if dice.chance(0.2) {
            return;
        }
        box = prefab_box(prefab);
        mass = self.mass;
        tall = 1.5 if prefab.source.startswith("q3:") else 1.0;
        by_id = {space.id: space for space in self.spaces};
        for z in range(prefab.oz + prefab.low, prefab.oz + prefab.high + 1) {
            under: dict[int, bool] = {};
            for y in range(box[1], box[3]) {
                for x in range(box[0], box[2]) {
                    owner = mass.at(x, y, z);
                    if owner > 0 and mass.at(x, y, z + 1) == 0 {
                        space = by_id.get(owner - 1, None);
                        if space is not None and not space.sky and space.role not in ["corridor", "window"] {
                            under[y * mass.nx + x] = True;
                        }
                    }
                }
            }
            while under {
                first = next(iter(under));
                del under[first];
                patch = [first];
                reached = 0;
                while reached < len(patch) {
                    cell = patch[reached];
                    reached += 1;
                    for step in [1, -1, mass.nx, -mass.nx] {
                        if under.get(cell + step, False) {
                            del under[cell + step];
                            patch.append(cell + step);
                        }
                    }
                }
                if len(patch) >= 40 {
                    self.vault_patch(patch, z, boxes, dice.child("patch", z * 4096 + patch[0]), tall);
                }
            }
        }
    }

    """How many lifts of rock stand over a cell at (x, y) above lift z, it and
    its eight neighbours, up to `most`."""
    def:priv rock_over(x: int, y: int, z: int, most: int) -> int {
        mass = self.mass;
        for up in range(1, most + 1) {
            for dy in [-1, 0, 1] {
                for dx in [-1, 0, 1] {
                    if not mass.inside(x + dx, y + dy, z + up) or mass.at(x + dx, y + dy, z + up) != 0 {
                        return up - 1;
                    }
                }
            }
        }
        return most;
    }

    def:priv vault_patch(patch: list[int], z: int, boxes: list[list[float]], dice: Stream, tall: float) {
        mass = self.mass;
        xs = [cell % mass.nx for cell in patch];
        ys = [cell // mass.nx for cell in patch];
        if max(xs) - min(xs) < 5 or max(ys) - min(ys) < 5 {
            return;
        }
        wanted = min(30, int(float(dice.between(6, 20)) * tall));
        room: dict[int, int] = {};
        for cell in patch {
            x = cell % mass.nx;
            y = cell // mass.nx;
            blocked = False;
            for box in boxes {
                if box[0] <= float(x) + 1.0 and float(x) <= box[3] and box[1] <= float(y) + 1.0 and float(y) <= box[4] and box[5] >= float(z) and box[2] <= float(z + wanted + 2) {
                    blocked = True;
                    break;
                }
            }
            room[cell] = 0 if blocked else self.rock_over(x, y, z, wanted + 2) - 2;
        }
        # As high as half the room may rise, the columns too low left out.
        rise = wanted;
        while rise >= 5 and len([cell for cell in patch if room[cell] >= rise]) * 2 < len(patch) {
            rise -= 3;
        }
        if rise < 5 {
            return;
        }
        open_cells = {cell: True for cell in patch if room[cell] >= rise};
        # How far in from the risen part's edge each column stands.
        inset: dict[int, int] = {};
        layer = list(open_cells.keys());
        depth = 0;
        while layer {
            edge_cells = [cell for cell in layer if not all([cell + a * mass.nx + b in open_cells and cell + a * mass.nx + b not in inset for a in [-1, 0, 1] for b in [-1, 0, 1]])];
            if not edge_cells {
                edge_cells = layer;
            }
            for cell in edge_cells {
                inset[cell] = depth;
            }
            layer = [cell for cell in layer if cell not in inset];
            depth += 1;
        }
        shape = dice.below(3);
        third = max(2, rise // 3);
        tops: dict[int, int] = {};
        for cell in inset {
            reach = inset[cell];
            if shape == 0 {
                tops[cell] = rise;
            } elif shape == 1 {
                tops[cell] = min(rise, third * (reach // 2 + 1));
            } else {
                tops[cell] = rise if reach >= 3 else third;
            }
        }
        by_id = {space.id: space for space in self.spaces};
        for cell in tops {
            x = cell % mass.nx;
            y = cell // mass.nx;
            owner = mass.at(x, y, z);
            mass.carve(x, y, z + 1, x + 1, y + 1, z + 1 + tops[cell], owner - 1);
            space = by_id.get(owner - 1, None);
            if space is not None {
                space.h = max(space.h, z + 1 + tops[cell] - space.z);
            }
        }
    }

    """The boxes the entities take, in the world's cells (z in lifts):
    [x0, y0, z0, x1, y1, z1] each, a point entity a cell round its origin."""
    def entity_boxes -> list[list[float]] {
        found: list[list[float]] = [];
        for item in self.casting.items {
            for brush in item.brushes {
                xs = [side.plane.dist for side in brush if side.plane.normal.x > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.x < -0.5];
                ys = [side.plane.dist for side in brush if side.plane.normal.y > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.y < -0.5];
                zs = [side.plane.dist for side in brush if side.plane.normal.z > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.z < -0.5];
                if xs and ys and zs {
                    box = [min(xs) / CELL, min(ys) / CELL, min(zs) / LIFT, max(xs) / CELL, max(ys) / CELL, max(zs) / LIFT];
                    # A mover takes all it may move through: as far again
                    # as it is big any way, and a lift its whole fall.
                    kind = item.fields.get("classname", "");
                    if kind.startswith("func_") and kind not in ["func_wall", "func_illusionary"] {
                        span = [box[3] - box[0], box[4] - box[1], box[5] - box[2]];
                        fall = float(item.fields.get("height", "0") or "0") / LIFT if kind == "func_plat" else 0.0;
                        box = [box[0] - span[0], box[1] - span[1], box[2] - span[2] - fall - (span[2] + 8.0 if kind == "func_plat" else 0.0), box[3] + span[0], box[4] + span[1], box[5] + span[2]];
                    }
                    found.append(box);
                }
            }
            words = item.fields.get("origin", "").split();
            if len(words) == 3 and not item.brushes {
                x = float(words[0]) / CELL;
                y = float(words[1]) / CELL;
                z = float(words[2]) / LIFT;
                found.append([x - 1.0, y - 1.0, z - 3.0, x + 1.0, y + 1.0, z + 3.0]);
            }
        }
        return found;
    }

    """Whether a box of the world's cells is clear of every entity's."""
    def clear_of_entities(box: list[float], taken: list[list[float]]) -> bool {
        for other in taken {
            if box[0] < other[3] and other[0] < box[3] and box[1] < other[4] and other[1] < box[4] and box[2] < other[5] and other[2] < box[5] {
                return False;
            }
        }
        return True;
    }

    """Whether the cells x..x+2, y..y+2 and the ring round them are all
    level floor on lift z, room to stand over them, none in liquid."""
    def level_floor(x: int, y: int, z: int) -> bool {
        mass = self.mass;
        for cy in range(y - 1, y + 3) {
            for cx in range(x - 1, x + 3) {
                if not mass.standing(cx, cy, z) or mass.headroom(cx, cy, z) < 5 {
                    return False;
                }
                if self.wet.get((z * mass.ny + cy) * mass.nx + cx, 0) != 0 {
                    return False;
                }
            }
        }
        return True;
    }

    """A hatch two cells square in `upper`'s floor, over `lower` (a stretch
    it was reached through), dropping a body four to twenty-two lifts onto
    level floor of `lower`'s, clear of every entity; the rims kept free of
    railings and props. Whether one was cut."""
    def hatch(upper: Prefab, lower: Prefab, taken: list[list[float]]) -> bool {
        a = prefab_box(upper);
        b = prefab_box(lower);
        mass = self.mass;
        # It lands on a floor one of `lower`'s ways stands on (its main
        # floors, walked from), never a pit or a ledge of its own.
        floors = [lower.oz + port.floor for port in [lower.enter] + lower.taken];
        for x in range(max(a[0], b[0]) + 3, min(a[2], b[2]) - 4) {
            for y in range(max(a[1], b[1]) + 3, min(a[3], b[3]) - 4) {
                for top in range(max(a[4], b[4]) + 1, a[5] - 4) {
                    if not self.level_floor(x, y, top) {
                        continue;
                    }
                    # Solid under the floor, then the lower's air down to its
                    # own floor.
                    under = top - 1;
                    while under > 0 and not mass.air(x, y, under) {
                        under -= 1;
                    }
                    if under <= b[4] or under == top - 1 {
                        continue;
                    }
                    bottom = under;
                    while bottom > 0 and mass.air(x, y, bottom - 1) {
                        bottom -= 1;
                    }
                    drop = top - bottom;
                    if drop < 4 or drop > 22 or bottom < b[4] or bottom not in floors or not self.level_floor(x, y, bottom) {
                        continue;
                    }
                    owner = mass.at(x, y, bottom);
                    landing = self.spaces[owner - 1] if 0 < owner and owner <= len(self.spaces) else None;
                    if landing is None or landing.deadly {
                        continue;
                    }
                    if not self.clear_of_entities([float(x - 1), float(y - 1), float(bottom), float(x + 3), float(y + 3), float(top + 6)], taken) {
                        continue;
                    }
                    rim = mass.at(x, y, top);
                    for cy in range(y, y + 2) {
                        for cx in range(x, x + 2) {
                            mass.carve(cx, cy, under, cx + 1, cy + 1, top, owner - 1);
                            if 0 < rim and rim <= len(self.spaces) {
                                self.spaces[rim - 1].kept.append([cx, cy, top]);
                            }
                            landing.kept.append([cx, cy, bottom]);
                        }
                    }
                    self.notes.append("hatch from " + upper.title + " down " + str(drop) + " lifts into " + lower.title);
                    return True;
                }
            }
        }
        return False;
    }

    """A barred window two cells wide and three lifts high through the
    walls between `one` and `other` where they stand side by side (four
    cells apart at most), its sill two lifts over a floor of one of them
    and the other's air beyond, every cell between solid. Whether one was
    cut."""
    def window(one: Prefab, other: Prefab, taken: list[list[float]]) -> bool {
        mass = self.mass;
        for pair in [[one, other], [other, one]] {
            a = prefab_box(pair[0]);
            b = prefab_box(pair[1]);
            for along_x in [True, False] {
                near = a[2] if along_x else a[3];
                far = b[0] if along_x else b[1];
                if far < near or far - near > 4 {
                    continue;
                }
                lo = max(a[1], b[1]) + 3 if along_x else max(a[0], b[0]) + 3;
                hi = min(a[3], b[3]) - 5 if along_x else min(a[2], b[2]) - 5;
                for across in range(lo, hi) {
                    for floor in range(max(a[4], b[4]) + 1, min(a[5], b[5]) - 6) {
                        inside = near - 2;
                        beyond = far + 1;
                        sill = floor + 2;
                        ok = True;
                        for side in range(across, across + 2) {
                            x = inside if along_x else side;
                            y = side if along_x else inside;
                            if not mass.standing(x, y, floor) {
                                ok = False;
                            }
                            for z in range(sill, sill + 3) {
                                far_x = beyond if along_x else side;
                                far_y = side if along_x else beyond;
                                if not mass.air(x, y, z) or not mass.air(far_x, far_y, z) {
                                    ok = False;
                                }
                                for step in range(inside + 1, beyond) {
                                    wx = step if along_x else side;
                                    wy = side if along_x else step;
                                    if mass.air(wx, wy, z) {
                                        ok = False;
                                    }
                                }
                            }
                        }
                        if not ok {
                            continue;
                        }
                        x0 = inside + 1 if along_x else across;
                        x1 = beyond if along_x else across + 2;
                        y0 = across if along_x else inside + 1;
                        y1 = across + 2 if along_x else beyond;
                        if not self.clear_of_entities([float(x0 - 1), float(y0 - 1), float(sill), float(x1 + 1), float(y1 + 1), float(sill + 3)], taken) {
                            continue;
                        }
                        space = Space(id=len(self.spaces), role="window", kind="window_x" if along_x else "window_y", district=pair[0].district, x=x0, y=y0, z=sill, w=x1 - x0, d=y1 - y0, h=3, levels=[sill]);
                        self.spaces.append(space);
                        mass.carve(x0, y0, sill, x1, y1, sill + 3, space.id);
                        self.notes.append("window from " + pair[0].title + " into " + pair[1].title);
                        return True;
                    }
                }
            }
        }
        return False;
    }

    """A way back from `later` into `older` (a stretch it was reached
    through) where the two stand side by side, four cells apart at most: a
    passage four cells wide and six lifts high through the walls between,
    level with a floor of each, and a door across it opened by walking up
    to it from `later`'s side, so it is a way back and never a way round
    what bars the way to `later`. Whether one was cut."""
    def shortcut(later: Prefab, older: Prefab, taken: list[list[float]]) -> bool {
        mass = self.mass;
        wide = 4;
        high = 6;
        for pair in [[later, older], [older, later]] {
            a = prefab_box(pair[0]);
            b = prefab_box(pair[1]);
            for along_x in [True, False] {
                near = a[2] if along_x else a[3];
                far = b[0] if along_x else b[1];
                if far < near or far - near > 4 {
                    continue;
                }
                lo = max(a[1], b[1]) + 3 if along_x else max(a[0], b[0]) + 3;
                hi = min(a[3], b[3]) - 3 - wide if along_x else min(a[2], b[2]) - 3 - wide;
                inside = near - 2;
                beyond = far + 1;
                for across in range(lo, hi + 1) {
                    for floor in range(max(a[4], b[4]) + 1, min(a[5], b[5]) - high - 1) {
                        ok = True;
                        for side in range(across - 1, across + wide + 1) {
                            # Floor to walk up to the passage on both sides,
                            # dry, two cells deep.
                            if across <= side and side < across + wide {
                                for at in [inside - 1, inside, beyond, beyond + 1] {
                                    x = at if along_x else side;
                                    y = side if along_x else at;
                                    if not mass.standing(x, y, floor) or mass.headroom(x, y, floor) < high or self.wet.get((floor * mass.ny + y) * mass.nx + x, 0) != 0 {
                                        ok = False;
                                    }
                                }
                            }
                            # The walls between solid, and the cells beside
                            # the passage too, for the door's halves.
                            for step in range(inside + 1, beyond) {
                                wx = step if along_x else side;
                                wy = side if along_x else step;
                                for z in range(floor, floor + high) {
                                    if mass.air(wx, wy, z) {
                                        ok = False;
                                    }
                                }
                            }
                            if not ok {
                                break;
                            }
                        }
                        if not ok {
                            continue;
                        }
                        x0 = inside + 1 if along_x else across;
                        x1 = beyond if along_x else across + wide;
                        y0 = across if along_x else inside + 1;
                        y1 = across + wide if along_x else beyond;
                        if not self.clear_of_entities([float(x0 - 2), float(y0 - 2), float(floor), float(x1 + 2), float(y1 + 2), float(floor + high)], taken) {
                            continue;
                        }
                        self.district = later.district;
                        space = Space(id=len(self.spaces), role="corridor", district=later.district, x=x0, y=y0, z=floor, w=x1 - x0, d=y1 - y0, h=high, levels=[floor]);
                        self.spaces.append(space);
                        mass.carve(x0, y0, floor, x1, y1, floor + high, space.id);
                        for side in range(across, across + wide) {
                            for at in [inside, beyond] {
                                x = at if along_x else side;
                                y = side if along_x else at;
                                owner = mass.at(x, y, floor);
                                if 0 < owner and owner <= len(self.spaces) {
                                    self.spaces[owner - 1].kept.append([x, y, floor]);
                                }
                            }
                        }
                        # The door halfway through; the touch that opens it
                        # on `later`'s side of it.
                        gate = self.cue_name("shortcut");
                        mid = float(inside + 1 + beyond) * 0.5;
                        self.passage_door(gate, along_x, mid, float(across), float(across + wide), floor, high);
                        near_side = pair[0] == later;
                        t0 = float(inside + 1) if near_side else mid + 0.5;
                        t1 = mid - 0.5 if near_side else float(beyond);
                        low = Vec3(x=t0 * CELL, y=float(across) * CELL, z=float(floor) * LIFT) if along_x else Vec3(x=float(across) * CELL, y=t0 * CELL, z=float(floor) * LIFT);
                        top = Vec3(x=t1 * CELL, y=float(across + wide) * CELL, z=float(floor + high) * LIFT) if along_x else Vec3(x=float(across + wide) * CELL, y=t1 * CELL, z=float(floor + high) * LIFT);
                        self.casting.put_brushed({"classname": "trigger_once", "target": gate}, [plain_box(low, top, "trigger", 1.0)]);
                        taken.append([float(x0 - 1), float(y0 - 1), float(floor), float(x1 + 1), float(y1 + 1), float(floor + high)]);
                        self.notes.append("shortcut from " + later.title + " back into " + older.title);
                        return True;
                    }
                }
            }
        }
        return False;
    }

    """The liquid cells as brushes the world keeps: runs of one liquid
    merged into boxes (along x, then y, then up), each side's contents said
    outright (lava 8, slime 16, water 32)."""
    def settle_liquids {
        mass = self.mass;
        taken: set[int] = set();
        materials = {2: "q1:e1m2/*04water1", 3: "q1:e1m1/*slime0", 4: "q1:e3m2/*lava1"};
        contents = {2: 32, 3: 16, 4: 8};
        for index in sorted(self.wet.keys()) {
            if index in taken {
                continue;
            }
            code = self.wet[index];
            x = index % mass.nx;
            y = (index // mass.nx) % mass.ny;
            z = index // (mass.nx * mass.ny);
            x1 = x + 1;
            while x1 < mass.nx and self.wet.get((z * mass.ny + y) * mass.nx + x1, 0) == code and ((z * mass.ny + y) * mass.nx + x1) not in taken {
                x1 += 1;
            }
            y1 = y + 1;
            growing = True;
            while growing and y1 < mass.ny {
                for cx in range(x, x1) {
                    other = (z * mass.ny + y1) * mass.nx + cx;
                    if self.wet.get(other, 0) != code or other in taken {
                        growing = False;
                    }
                }
                if growing {
                    y1 += 1;
                }
            }
            z1 = z + 1;
            growing = True;
            while growing and z1 < mass.nz {
                for cy in range(y, y1) {
                    for cx in range(x, x1) {
                        other = (z1 * mass.ny + cy) * mass.nx + cx;
                        if self.wet.get(other, 0) != code or other in taken {
                            growing = False;
                        }
                    }
                }
                if growing {
                    z1 += 1;
                }
            }
            for cz in range(z, z1) {
                for cy in range(y, y1) {
                    for cx in range(x, x1) {
                        taken.add((cz * mass.ny + cy) * mass.nx + cx);
                    }
                }
            }
            box = plain_box(
                Vec3(x=float(x) * CELL, y=float(y) * CELL, z=float(z) * LIFT),
                Vec3(x=float(x1) * CELL, y=float(y1) * CELL, z=float(z1) * LIFT),
                materials.get(code, materials[2]),
                1.0
            );
            for side in box {
                side.contents = contents.get(code, 32);
            }
            self.casting.solids.append(box);
        }
    }

    """Rock in every solid cell of a box of the prefab's cells (z in lifts),
    for a mover to move into."""
    def rock_round(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
        corners = self.box_units(x0, y0, z0, x1, y1, z1);
        self.fills.append(RockWant(low=corners[0], high=corners[1]));
    }

    """The rock doors open into, each box cut short of any air (its cells
    taken whole), as caulk the world keeps; and the solid cells of each
    `fills` box, in runs along x."""
    def settle_rocks {
        solid: set[int] = set();
        mass = self.mass;
        for want in self.fills {
            x0 = max(0, int(math.floor(want.low.x / CELL + 0.001)));
            y0 = max(0, int(math.floor(want.low.y / CELL + 0.001)));
            z0 = max(0, int(math.floor(want.low.z / LIFT + 0.001)));
            x1 = min(mass.nx, int(math.ceil(want.high.x / CELL - 0.001)));
            y1 = min(mass.ny, int(math.ceil(want.high.y / CELL - 0.001)));
            z1 = min(mass.nz, int(math.ceil(want.high.z / LIFT - 0.001)));
            for cz in range(z0, z1) {
                for cy in range(y0, y1) {
                    for cx in range(x0, x1) {
                        if not mass.air(cx, cy, cz) {
                            solid.add((cz * mass.ny + cy) * mass.nx + cx);
                        }
                    }
                }
            }
        }
        for index in sorted(solid) {
            x = index % mass.nx;
            if x > 0 and (index - 1) in solid {
                continue;
            }
            run = x + 1;
            while run < mass.nx and (index + run - x) in solid {
                run += 1;
            }
            y = (index // mass.nx) % mass.ny;
            z = index // (mass.nx * mass.ny);
            self.casting.solids.append(
                plain_box(Vec3(x=float(x) * CELL, y=float(y) * CELL, z=float(z) * LIFT), Vec3(x=float(run) * CELL, y=float(y + 1) * CELL, z=float(z + 1) * LIFT), "caulk", 1.0)
            );
        }
        for want in self.rocks {
            x0 = int(math.floor(want.low.x / CELL + 0.001));
            y0 = int(math.floor(want.low.y / CELL + 0.001));
            z0 = int(math.floor(want.low.z / LIFT + 0.001));
            x1 = int(math.ceil(want.high.x / CELL - 0.001));
            y1 = int(math.ceil(want.high.y / CELL - 0.001));
            z1 = int(math.ceil(want.high.z / LIFT - 0.001));
            clear = True;
            for cz in range(z0, z1) {
                for cy in range(y0, y1) {
                    for cx in range(x0, x1) {
                        if self.mass.air(cx, cy, cz) {
                            clear = False;
                        }
                    }
                }
            }
            if clear {
                self.casting.solids.append(plain_box(want.low, want.high, "caulk", 1.0));
            } else {
                self.notes.append("rock at " + origin_text(want.low.x, want.low.y, want.low.z) + " meets air");
            }
        }
    }
}

"""The rhythm of a level's fights, as the originals have it: long quiet ways
with a stray or two, and foes bunched where it matters. Walks the level from
its start and gives each stretch its part, a rest after a fight more often
than not, a fight where a key lies or the way out does, and takes the stray
foes out of it to suit (fewer in the first levels of a run)."""
walker Pace {
    has build: Raising,
        dice: Stream,
        depth: int = 1,
        last: str = "rest";

    can go with Prefab entry {
        ahead = [here->:Next:->][?:Prefab];
        roll = self.dice.child("pace", here.number);
        before = [here<-:Next:<-][?:Prefab];
        here.pace = "rest";
        if before {
            if not ahead {
                here.pace = "fight" if roll.chance(0.7) else "steady";
            } elif self.last == "fight" {
                here.pace = "rest" if roll.chance(0.65) else "steady";
            } else {
                here.pace = ["rest", "steady", "fight"][roll.weighted([0.25, 0.3, 0.45])];
            }
        }
        self.last = here.pace;
        early = min(1.0, 0.75 + 0.05 * float(self.depth - 1));
        share = {"rest": 0.1, "steady": 0.5 * early, "fight": early}[here.pace];
        self.build.thin(here, share, roll);
        visit [here->:Next:->];
    }
}

"""Raises a laid chain: each prefab carves itself (its own ability), then
the passage from the one before it is cut."""
walker Raise {
    has build: Raising;

    can go with Prefab entry {
        before = [here<-:Next:<-][?:Prefab];
        if before {
            self.build.join(before[0], here);
        }
        visit [here->:Next:->];
    }
}
