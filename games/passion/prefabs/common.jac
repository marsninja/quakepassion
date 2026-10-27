"""Shapes the hand-made prefabs share, drawn in a prefab's own cells
through its `Raising`: stairs, pillars, a cave's boulders and stalactites,
niches in a wall. Each keeps clear of the boxes it is told to (`clear`,
[x0, y0, x1, y1] each), so a way through stays open."""
import from ..random { Stream }
import from ..prefab { Raising, Port }
import from ..space { Space }
import from ..kits { kit_of }

"""A straight stair `steps` lifts high, `width` cells wide, its first step
at the cell (x, y) on lift `z`, climbing a lift a cell the way `direction`
goes (0 +x, 1 +y, 2 -x, 3 -y); across it spreads +y (or +x) from (x, y)."""
def stair(build: Raising, x: int, y: int, z: int, direction: int, steps: int, width: int) {
    for step in range(steps) {
        top = z + step + 1;
        if direction == 0 {
            build.solid(x + step, y, z, x + step + 1, y + width, top);
        } elif direction == 2 {
            build.solid(x - step, y, z, x - step + 1, y + width, top);
        } elif direction == 1 {
            build.solid(x, y + step, z, x + width, y + step + 1, top);
        } else {
            build.solid(x, y - step, z, x + width, y - step + 1, top);
        }
    }
}

"""Whether a box [x0, y0, x1, y1] keeps a cell clear of each of `clear`."""
def apart(box: list[int], clear: list[list[int]]) -> bool {
    for other in clear {
        if box[0] < other[2] + 1 and other[0] < box[2] + 1 and box[1] < other[3] + 1 and other[1] < box[3] + 1 {
            return False;
        }
    }
    return True;
}

"""Pillars a cell square from lift z0 to z1, every `every` cells over the
box x0..x1, y0..y1, clear of `clear`."""
def pillars(build: Raising, x0: int, y0: int, x1: int, y1: int, z0: int, z1: int, every: int, clear: list[list[int]]) {
    for x in range(x0, x1, every) {
        for y in range(y0, y1, every) {
            if apart([x, y, x + 1, y + 1], clear) {
                build.solid(x, y, z0, x + 1, y + 1, z1);
            }
        }
    }
}

"""Boulders against the walls of a cave's floor (the box x0..x1, y0..y1 on
lift z): `count` lumps of rock a cell or two across and two to five lifts
high, each touching the box's edge, clear of `clear`."""
def boulders(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 8 {
        tries += 1;
        wide = dice.between(1, 2);
        deep = dice.between(1, 2);
        side = dice.below(4);
        if side == 0 {
            rock_x = x0;
            rock_y = dice.between(y0, max(y0, y1 - deep));
        } elif side == 1 {
            rock_x = x1 - wide;
            rock_y = dice.between(y0, max(y0, y1 - deep));
        } elif side == 2 {
            rock_x = dice.between(x0, max(x0, x1 - wide));
            rock_y = y0;
        } else {
            rock_x = dice.between(x0, max(x0, x1 - wide));
            rock_y = y1 - deep;
        }
        box = [rock_x, rock_y, rock_x + wide, rock_y + deep];
        if not apart(box, clear) {
            continue;
        }
        build.solid(rock_x, rock_y, z, rock_x + wide, rock_y + deep, z + dice.between(2, 5));
        placed += 1;
    }
}

"""Stalactites: `count` columns of rock hanging one to four lifts from the
ceiling at lift `top` over the box x0..x1, y0..y1."""
def stalactites(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, top: int, count: int) {
    for index in range(count) {
        x = dice.between(x0, max(x0, x1 - 1));
        y = dice.between(y0, max(y0, y1 - 1));
        build.solid(x, y, top - dice.between(1, 4), x + 1, y + 1, top);
    }
}

"""Niches in a wall: recesses two cells wide, a cell deep and `high` lifts
tall from lift `z`, every `every` cells along the wall line `line` (y,
or x when `along_y`) from `start` to `finish`, opening the way `out` (+1
or -1 across), as air of `space`. Answers each niche's middle (x, y)."""
def niches(build: Raising, space: Space, line: int, start: int, finish: int, z: int, high: int, every: int, along_y: bool, out: int) -> list[list[float]] {
    found: list[list[float]] = [];
    for at in range(start, finish - 1, every) {
        if along_y {
            build.widen(space, line, at, z, line + 1, at + 2, z + high);
            found.append([float(line) + 0.5, float(at) + 1.0]);
        } else {
            build.widen(space, at, line, z, at + 2, line + 1, z + high);
            found.append([float(at) + 1.0, float(line) + 0.5]);
        }
    }
    return found;
}

"""The key a key room holds (`key_gold` or `key_silver`) as Quake's item."""
def key_item(key: str) -> str {
    return "item_key2" if key == "key_gold" else "item_key1";
}

"""A key on a floor whose taking opens closets beyond a room's far wall
(the cell line y = `side`, the closets beyond it), one at each of `xs`
on lift `floor`, a foe of `foes` (in turn) in each: what waits there
meets the taker on the way back."""
def key_ambush(build: Raising, key: str, x: float, y: float, z: int, side: int, floor: int, xs: list[int], foes: list[str]) {
    ambush = build.name("ambush");
    build.put_at({"classname": key_item(key), "asset_game": "q1", "target": ambush}, x, y, z);
    for (index, at) in enumerate(xs) {
        closet = build.room(at, side + 1, floor, at + 3, side + 4, floor + 7);
        build.widen(closet, at, side, floor, at + 3, side + 1, floor + 6);
        build.rising_door(float(at), float(side), float(floor), float(at + 3), float(side + 1), float(floor + 6), {"targetname": ambush, "wait": "-1"});
        build.foe(float(at) + 1.5, float(side) + 2.5, floor, foes[index % len(foes)], 270.0);
    }
}

"""The cells a lap round the inside of the box x0..x1, y0..y1 takes, a
ring `width` cells wide: [x0, y0, x1, y1, face] each in turn (the face of
the box the cell stands against, 0 +x ... 3 -y), from the corner (x0, y0)
along -y's wall, then +x's, +y's and -x's."""
def ring_path(x0: int, y0: int, x1: int, y1: int, width: int) -> list[list[int]] {
    found: list[list[int]] = [];
    for x in range(x0, x1 - width) {
        found.append([x, y0, x + 1, y0 + width, 3]);
    }
    for y in range(y0, y1 - width) {
        found.append([x1 - width, y, x1, y + 1, 0]);
    }
    for x in range(x1 - 1, x0 + width - 1, -1) {
        found.append([x, y1 - width, x + 1, y1, 1]);
    }
    for y in range(y1 - 1, y0 + width - 1, -1) {
        found.append([x0, y, x0 + width, y + 1, 2]);
    }
    return found;
}

"""A stair winding up the inside walls of the box x0..x1, y0..y1 (a ring
`width` cells wide), from the corner (x0, y0) on lift `z`, `steps` lifts
high a lift a cell, each step three lifts thick so the floor runs on
under the higher turns; then a landing `landing` cells on at its top.
`start` is the cell of the lap (by ring_path) its first step takes.
Answers the cells of the landing ([x0, y0, x1, y1, face] each)."""
def spiral(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, steps: int, width: int, landing: int, start: int = 0) -> list[list[int]] {
    path = ring_path(x0, y0, x1, y1, width);
    lap = len(path);
    for step in range(steps) {
        cell = path[(start + step) % lap];
        top = z + step + 1;
        build.solid(cell[0], cell[1], max(z, top - 3), cell[2], cell[3], top);
    }
    found: list[list[int]] = [];
    top = z + steps;
    for index in range(landing) {
        cell = path[(start + steps + index) % lap];
        build.solid(cell[0], cell[1], top - 1, cell[2], cell[3], top);
        found.append(cell);
    }
    return found;
}

"""Where a stair winding round the ring of the box x0..x1, y0..y1 (`width`
cells wide) lands after `steps`: [face, along] for a landing `landing`
cells long on one face, or [] when the landing turns a corner."""
def ring_landing(x0: int, y0: int, x1: int, y1: int, width: int, steps: int, landing: int) -> list[float] {
    path = ring_path(x0, y0, x1, y1, width);
    lap = len(path);
    face = path[steps % lap][4];
    for index in range(landing) {
        if path[(steps + index) % lap][4] != face {
            return [];
        }
    }
    cell = path[(steps + landing // 2) % lap];
    along = float(cell[0]) + 0.5 if face % 2 == 1 else float(cell[1]) + 0.5;
    return [float(face), along];
}

"""An end's way in: a hall from the near wall to the cell line `wall`, its
way in (`enter`) cut, and a door through `wall` into the room beyond it
(from `wall` to the far wall, lifts `low` to `tall`), shut by `key` when
one is given (a gate). Answers the room beyond."""
def gate_into(build: Raising, dice: Stream, enter: Port, long: int, wide: int, wall: int, low: int, tall: int, key: str, sky: bool = False) -> Space {
    middle = wide // 2;
    hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
    room = build.room(wall + 1, 1, low, long - 1, wide - 1, tall, variant=dice.below(3), sky=sky);
    if low < 0 {
        build.level(room, 0);
    }
    build.doorway(hall, enter);
    build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
    if key {
        build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": key, "wait": "-1"});
    }
    return room;
}

"""A lift: a plat over the cells x0..x1, y0..y1 that waits at lift
`bottom` and rides up to `top` when stood on."""
def lift(build: Raising, x0: int, y0: int, x1: int, y1: int, bottom: int, top: int) {
    build.put_box({"classname": "func_plat", "height": str((top - bottom) * 16), "speed": "200"}, float(x0), float(y0), float(top) - 0.5, float(x1), float(y1), float(top), kit_of(build.district).step);
}
