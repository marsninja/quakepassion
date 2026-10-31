"""Shapes the stretches of e1m2 and its neighbours share (drawn in a
prefab's own cells through its `Raising`): slabs over arcades, stashes
behind secret doors, closets that open on a cue, spike traps in a wall,
steps up out of water, and the cue-wired key.

Each takes the cue that sets it off (or answers the cue it is), so a
stretch's set-piece is a small graph of `Cue`s joined by `Fires`."""
import from ..prefab { Raising, Cue, Fires }
import from ..space { Space }
import from ..random { Stream }
import from .common { key_item, apart }

"""A slab: a floor a lift thick, its top at lift `z`, over the cells
x0..x1, y0..y1 (a gallery, a catwalk, a bridge with air under it)."""
def slab(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int) {
    build.solid(x0, y0, z - 1, x1, y1, z);
}

"""Every cell of the box x0..x1, y0..y1 kept clear of railings on lift `z`
(a stair's top, an edge meant to be dropped from)."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(space, x, y, z);
        }
    }
}

"""Columns a cell square under the edge of a slab, from lift `z0` to
`z1`, every `every` cells along the cell line `line` (y, or x when
`along_y`) from `start` to `finish`: the arcade that holds a gallery up."""
def arcade(build: Raising, line: int, start: int, finish: int, z0: int, z1: int, every: int, along_y: bool) {
    for at in range(start, finish, every) {
        if along_y {
            build.solid(line, at, z0, line + 1, at + 1, z1);
        } else {
            build.solid(at, line, z0, at + 1, line + 1, z1);
        }
    }
}

"""A stash: a closet two cells square behind a stretch of wall that opens
when shot, beyond the room's air ending at the cell line `line` (x, or y
when the way `direction` goes is across y), the door's two cells from
`along`, on lift `z`. `direction` (0 +x ... 3 -y) is the way from the room
into the wall. A secret is found in the closet, and `reward` lies there.
Four cells of solid must stand beyond `line`. Answers the secret's cue."""
def stash(build: Raising, line: int, along: int, z: int, direction: int, reward: str) -> Cue {
    if direction == 0 {
        door = [line, along, line + 2, along + 2];
        closet = [line + 2, along, line + 4, along + 2];
    } elif direction == 2 {
        door = [line - 2, along, line, along + 2];
        closet = [line - 4, along, line - 2, along + 2];
    } elif direction == 1 {
        door = [along, line, along + 2, line + 2];
        closet = [along, line + 2, along + 2, line + 4];
    } else {
        door = [along, line - 2, along + 2, line];
        closet = [along, line - 4, along + 2, line - 2];
    }
    build.room(closet[0], closet[1], z, closet[2], closet[3], z + 4);
    build.secret_door(float(door[0]), float(door[1]), float(z), float(door[2]), float(door[3]), float(z + 4), direction);
    found = build.secret(float(closet[0]), float(closet[1]), float(z), float(closet[2]), float(closet[3]), float(z + 3));
    build.supply(float(closet[0]) + 1.0, float(closet[1]) + 1.0, z, reward);
    return found;
}

"""Closets three cells wide and deep beyond a room's wall (its air ending
at the cell line `line`, the way `direction` goes from the room into the
wall: 0 +x ... 3 -y), one at each of `starts` along it, on lift `z`, a door
across each that rises when `cue` fires; what stands in each (of `kinds`,
in turn) wakes with it and comes out. Four cells beyond `line` are taken."""
def closets(build: Raising, cue: Cue, line: int, starts: list[int], z: int, direction: int, kinds: list[str]) {
    woken = build.waiting();
    cue +>:Fires:+> woken;
    for (index, at) in enumerate(starts) {
        if direction == 1 {
            room = build.room(at, line + 1, z, at + 3, line + 4, z + 7);
            build.widen(room, at, line, z, at + 3, line + 1, z + 6);
            door = build.opened(float(at), float(line), float(z), float(at + 3), float(line + 1), float(z + 6));
            spot = [float(at) + 1.5, float(line) + 2.5];
            facing = 270.0;
        } elif direction == 3 {
            room = build.room(at, line - 4, z, at + 3, line - 1, z + 7);
            build.widen(room, at, line - 1, z, at + 3, line, z + 6);
            door = build.opened(float(at), float(line - 1), float(z), float(at + 3), float(line), float(z + 6));
            spot = [float(at) + 1.5, float(line) - 2.5];
            facing = 90.0;
        } elif direction == 0 {
            room = build.room(line + 1, at, z, line + 4, at + 3, z + 7);
            build.widen(room, line, at, z, line + 1, at + 3, z + 6);
            door = build.opened(float(line), float(at), float(z), float(line + 1), float(at + 3), float(z + 6));
            spot = [float(line) + 2.5, float(at) + 1.5];
            facing = 180.0;
        } else {
            room = build.room(line - 4, at, z, line - 1, at + 3, z + 7);
            build.widen(room, line - 1, at, z, line, at + 3, z + 6);
            door = build.opened(float(line - 1), float(at), float(z), float(line), float(at + 3), float(z + 6));
            spot = [float(line) - 2.5, float(at) + 1.5];
            facing = 0.0;
        }
        cue +>:Fires:+> door;
        build.foe(spot[0], spot[1], z, kinds[index % len(kinds)], facing, waits=woken);
    }
}

"""Spike shooters set in a wall: its face the cell line `line` (y, or x
when `along_y`), one every `every` cells from `start` to `finish`, `high`
lifts up, each shooting the way `direction` goes (out of the wall) each
time `cue` fires."""
def spike_wall(build: Raising, cue: Cue, line: int, start: int, finish: int, high: float, every: int, along_y: bool, direction: int) {
    inset = 0.2 if direction in [0, 1] else -0.2;
    for at in range(start, finish, every) {
        if along_y {
            shooter = build.spikes(float(line) + inset, float(at) + 0.5, high, direction);
        } else {
            shooter = build.spikes(float(at) + 0.5, float(line) + inset, high, direction);
        }
        cue +>:Fires:+> shooter;
    }
}

"""A key lying on a floor as a cue: taking it fires what it is wired to."""
def key_cue(build: Raising, key: str, x: float, y: float, z: int) -> Cue {
    fields = {"classname": key_item(key), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    return build.cue([fields], "key");
}

"""A door across the cells of the box (lifts z0..z1) that rises as a body
comes up to it: Quake's plain door, opened by a touch and shut again."""
def plain_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
    build.rising_door(x0, y0, z0, x1, y1, z1, {});
}

"""A ramp of rock or a flight of steps three lifts thick (open under its
higher steps): `steps` lifts climbed from lift `z` at the cell (x, y), a
lift a cell the way `direction` goes (0 +x ... 3 -y), `width` cells
across (+y, or +x when it climbs across y)."""
def ramp(build: Raising, x: int, y: int, z: int, direction: int, steps: int, width: int) {
    for step in range(steps) {
        top = z + step + 1;
        low = max(z, top - 3);
        if direction == 0 {
            build.solid(x + step, y, low, x + step + 1, y + width, top);
        } elif direction == 2 {
            build.solid(x - step, y, low, x - step + 1, y + width, top);
        } elif direction == 1 {
            build.solid(x, y + step, low, x + width, y + step + 1, top);
        } else {
            build.solid(x, y - step, low, x + width, y - step + 1, top);
        }
    }
}

"""Water in every cell of the box (lifts z0..z1): a flooded tunnel, a
niche under water."""
def flood(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) {
    for z in range(z0, z1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                build.liquid(x, y, z, 2);
            }
        }
    }
}

"""The cells round the border of the box x0..x1, y0..y1 kept clear of
railings on lift `z` (an island's or a stepping stone's edge, climbed onto
out of the water or jumped to)."""
def keep_ring(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        build.keep(space, x, y0, z);
        build.keep(space, x, y1 - 1, z);
    }
    for y in range(y0, y1) {
        build.keep(space, x0, y, z);
        build.keep(space, x1 - 1, y, z);
    }
}

"""Low rocks against the walls of a floor (the box x0..x1, y0..y1 on lift
`z`): `count` lumps a cell or two across and `high` lifts high (low enough
to be jumped onto, so none walls a body in), each touching the box's edge,
clear of `clear` ([x0, y0, x1, y1] each, grown by each rock placed)."""
def low_rocks(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, high: int, clear: list[list[int]]) {
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 8 {
        tries += 1;
        wide = dice.between(1, 2);
        deep = dice.between(1, 2);
        side = dice.below(4);
        if side == 0 {
            x = x0;
            y = dice.between(y0, max(y0, y1 - deep));
        } elif side == 1 {
            x = x1 - wide;
            y = dice.between(y0, max(y0, y1 - deep));
        } elif side == 2 {
            x = dice.between(x0, max(x0, x1 - wide));
            y = y0;
        } else {
            x = dice.between(x0, max(x0, x1 - wide));
            y = y1 - deep;
        }
        box = [x, y, x + wide, y + deep];
        if not apart(box, clear) {
            continue;
        }
        build.solid(x, y, z, x + wide, y + deep, z + high);
        clear.append(box);
        placed += 1;
    }
}

"""A sump: a well of water `wide` cells square from the cell (x, y) down
from the bottom of a pool at lift `top` to lift `bottom`, swum down into
and up out of (the deep water of a lake or a cistern)."""
def sump(build: Raising, x: int, y: int, bottom: int, top: int, wide: int) {
    build.room(x, y, bottom, x + wide, y + wide, top);
    flood(build, x, y, bottom, x + wide, y + wide, top);
}
