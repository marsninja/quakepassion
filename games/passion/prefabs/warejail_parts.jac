"""Set-pieces the Quake II warehouse and prison stretches share (ware1,
ware2, jail1..jail5, security), drawn in a prefab's own cells through its
`Raising` and wired through the `Cue` / `Fires` graph: a shutter across a
way out opened from elsewhere, the key as a cue, crates riding a belt, a
panel sparking on a timer, guards brought in by a cue, a stash behind a
panel that breaks."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }
import from .common { key_item }

"""A pair of shutters across the doorway `port` makes in the prefab's wall
(the wall's own cell, the port's width and height, split at its middle),
shut until their cue fires: Quake II's "This door is opened elsewhere"."""
def shutter(build: Raising, prefab: Prefab, port: Port) -> Cue {
    low = port.along - float(port.wide) * 0.5;
    high = low + float(port.wide);
    split = port.along;
    z0 = float(port.floor);
    z1 = float(port.floor + port.high);
    items: list[dict[str, str]] = [];
    for half in [[low, split], [split, high]] {
        fields = {"wait": "-1"};
        if port.face == 0 {
            build.rising_door(float(prefab.long - 1), half[0], z0, float(prefab.long), half[1], z1, fields);
        } elif port.face == 2 {
            build.rising_door(0.0, half[0], z0, 1.0, half[1], z1, fields);
        } elif port.face == 1 {
            build.rising_door(half[0], float(prefab.wide - 1), z0, half[1], float(prefab.wide), z1, fields);
        } else {
            build.rising_door(half[0], 0.0, z0, half[1], 1.0, z1, fields);
        }
        items.append(fields);
    }
    return build.cue(items, "door");
}

"""The cells just inside the doorway `port` makes, as a box of the
prefab's cells [x0, y0, x1, y1] (two cells deep)."""
def inside_port(prefab: Prefab, port: Port) -> list[float] {
    low = port.along - float(port.wide) * 0.5;
    high = low + float(port.wide);
    if port.face == 0 {
        return [float(prefab.long - 4), low, float(prefab.long - 2), high];
    }
    if port.face == 2 {
        return [2.0, low, 4.0, high];
    }
    if port.face == 1 {
        return [low, float(prefab.wide - 4), high, float(prefab.wide - 2)];
    }
    return [low, 2.0, high, 4.0];
}

"""The cells just outside the doorway `port` makes, in the passage beyond
the prefab's face, as a box [x0, y0, x1, y1] (two cells deep)."""
def outside_port(prefab: Prefab, port: Port) -> list[float] {
    low = port.along - float(port.wide) * 0.5;
    high = low + float(port.wide);
    if port.face == 0 {
        return [float(prefab.long), low, float(prefab.long + 2), high];
    }
    if port.face == 2 {
        return [-2.0, low, 0.0, high];
    }
    if port.face == 1 {
        return [low, float(prefab.wide), high, float(prefab.wide + 2)];
    }
    return [low, -2.0, high, 0.0];
}

"""Shutters across the ways out `ports` that open as a body comes up to
them from either side (a touch just inside each and one just outside,
Quake II's doors fired by a trigger_multiple), each pair now and then
(`chance`)."""
def auto_shutters(build: Raising, dice: Stream, prefab: Prefab, ports: list[Port], chance: float) {
    for port in ports {
        if not dice.chance(chance) {
            continue;
        }
        box = inside_port(prefab, port);
        near = build.touch(box[0], box[1], float(port.floor), box[2], box[3], float(port.floor + 6), False);
        doors = shutter(build, prefab, port);
        near +>:Fires:+> doors;
        # And one just outside, in the passage, so a body coming back the
        # other way is not shut out.
        beyond = outside_port(prefab, port);
        build.touch(beyond[0], beyond[1], float(port.floor), beyond[2], beyond[3], float(port.floor + 6), False) +>:Fires:+> doors;
    }
}

"""The key (`key_silver`, `key_gold`) lying on a floor as a cue: taking it
fires what it is wired to (Quake II's power cube, its pass)."""
def key_cue(build: Raising, key: str, x: float, y: float, z: int) -> Cue {
    fields = {"classname": key_item(key), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    return build.cue([fields], "key");
}

"""Crates riding a conveyor belt: `count` crates two cells square and
`high` lifts tall riding to and fro along the belt's top on lift `z`,
each over its own length of it, from (x0, y) to (x1, y) when `along_x`,
else from (y, x0) to (y, x1) (the belt two cells wide from `y`). Answers
the trains' cues (they run from the start)."""
def belt_crates(build: Raising, dice: Stream, x0: int, x1: int, y: int, z: int, count: int, along_x: bool = True, high: int = 2) -> list[Cue] {
    found: list[Cue] = [];
    length = max(4, (x1 - x0) // max(1, count));
    for index in range(count) {
        a = x0 + index * length;
        b = min(x1, a + length) - 2;
        if b <= a {
            continue;
        }
        if along_x {
            stops = [[float(a), float(y), float(z)], [float(b), float(y), float(z)]];
        } else {
            stops = [[float(y), float(a), float(z)], [float(y), float(b), float(z)]];
        }
        if index % 2 == 1 {
            stops = [stops[1], stops[0]];
        }
        found.append(build.train([2.0, 2.0, float(high)], stops, float(dice.between(50, 80)), float(dice.between(1, 3))));
    }
    return found;
}

"""A broken panel at (x, y), `z` lifts up, sparking out the way
`direction` goes (0 +x ... 3 -y) every `every` seconds or so."""
def sparking(build: Raising, x: float, y: float, z: float, direction: int, every: float) {
    build.timer(every) +>:Fires:+> build.sparks(x, y, z, direction);
}

"""Guards brought in when `cue` fires (Quake II's TRIGGER_SPAWN, Quake's
waking): one of `kinds` (in turn) at each spot [x, y] on lift `z`, facing
`angle`. Answers the cue they wait on."""
def guards(build: Raising, cue: Cue, spots: list[list[float]], z: int, kinds: list[str], angle: float) -> Cue {
    waiting = build.waiting();
    cue +>:Fires:+> waiting;
    for (index, spot) in enumerate(spots) {
        build.foe(spot[0], spot[1], z, kinds[index % len(kinds)], angle, waits=waiting);
    }
    return waiting;
}

"""Charges going off one after another when `cue` fires: an explosion at
each of `spots` [x, y, z] (z in lifts), `gap` seconds apart."""
def charges(build: Raising, cue: Cue, spots: list[list[float]], gap: float) {
    for (index, spot) in enumerate(spots) {
        late = build.delay(0.1 + gap * float(index));
        cue +>:Fires:+> late;
        late +>:Fires:+> build.explosion(spot[0], spot[1], spot[2]);
    }
}

"""A stash: a closet of the prefab's cells x0..x1, y0..y1 on lift `z`
(carved out of what is solid there), behind a panel in its face toward
the room (the cell line beyond the closet the way `face` goes, 0 +x ...
3 -y) that breaks when shot; inside, a secret and `item` of `game`'s."""
def stash(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, face: int, item: str, game: str) {
    build.room(x0, y0, z, x1, y1, z + 4);
    if face == 0 {
        build.breakable(float(x1), float(y0), float(z), float(x1 + 1), float(y1), float(z + 4), 20);
    } elif face == 2 {
        build.breakable(float(x0 - 1), float(y0), float(z), float(x0), float(y1), float(z + 4), 20);
    } elif face == 1 {
        build.breakable(float(x0), float(y1), float(z), float(x1), float(y1 + 1), float(z + 4), 20);
    } else {
        build.breakable(float(x0), float(y0 - 1), float(z), float(x1), float(y0), float(z + 4), 20);
    }
    build.secret(float(x0), float(y0), float(z), float(x1), float(y1), float(z + 3));
    build.supply(float(x0 + x1) * 0.5, float(y0 + y1) * 0.5, z, item, game);
}

"""A flight of stairs as cells kept clear of railings at its top: the
cells (x, y) .. along the way `direction` goes from (x, y), `width`
across, on lift `z` (the floor the flight lands on)."""
def keep_row(build: Raising, space: Space, x: int, y: int, z: int, direction: int, width: int) {
    for across in range(width) {
        if direction % 2 == 0 {
            build.keep(space, x, y + across, z);
        } else {
            build.keep(space, x + across, y, z);
        }
    }
}

"""Whether a way out of `ports` stands at `face` on lift `floor`, near
`along` (within `reach` cells)."""
def port_near(ports: list[Port], face: int, floor: int, along: float, reach: float) -> bool {
    for port in ports {
        if port.face == face and port.floor == floor and abs(port.along - along) <= reach {
            return True;
        }
    }
    return False;
}

"""A lift called down: a plat over the cells x0..x1, y0..y1 drawn at lift
`top`, where it waits (Quake's func_plat with a targetname) until its cue
fires; then it comes down to `bottom` and rides as any plat."""
def called_lift(build: Raising, x0: int, y0: int, x1: int, y1: int, bottom: int, top: int) -> Cue {
    fields = {"classname": "func_plat", "height": str((top - bottom) * 16), "speed": "200"};
    build.put_box(fields, float(x0), float(y0), float(top) - 0.5, float(x1), float(y1), float(top), kit_of(build.district).step);
    return build.cue([fields], "plat");
}

"""Closets along a wall that open when `cue` fires: each three cells wide
at `xs` (x0 each), carved from the cell line y = `line` the way `out`
goes (+1 or -1) three cells deep on lift `z`, its door in the wall's
cell, a foe of `kinds` (in turn) inside facing the room (`angle`)."""
def closets(build: Raising, cue: Cue, xs: list[int], line: int, out: int, z: int, kinds: list[str], angle: float) {
    for (index, x) in enumerate(xs) {
        if out > 0 {
            build.room(x, line + 1, z, x + 3, line + 4, z + 7);
            door = build.opened(float(x), float(line), float(z), float(x + 3), float(line + 1), float(z + 6));
            build.foe(float(x) + 1.5, float(line) + 2.5, z, kinds[index % len(kinds)], angle);
        } else {
            build.room(x, line - 3, z, x + 3, line, z + 7);
            door = build.opened(float(x), float(line), float(z), float(x + 3), float(line + 1), float(z + 6));
            build.foe(float(x) + 1.5, float(line) - 1.5, z, kinds[index % len(kinds)], angle);
        }
        cue +>:Fires:+> door;
    }
}

"""An end's way in for Quake II: a hall from the near wall to the cell
line `wall`, its way in cut, and a pair of doors through `wall` into the
room beyond (from `wall` to the far wall, lifts `low` to `tall`), the
door `panels` panels two cells wide each (a loading bay's big door when
four), all wanting `key` when one is given (a gate). Answers the room
beyond."""
def gate_pair(build: Raising, dice: Stream, enter: Port, long: int, wide: int, wall: int, low: int, tall: int, key: str, panels: int = 2) -> Space {
    middle = wide // 2;
    hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
    room = build.room(wall + 1, 1, low, long - 1, wide - 1, tall, variant=dice.below(3));
    if low < 0 {
        build.level(room, 0);
    }
    build.doorway(hall, enter);
    half = panels;
    build.widen(room, wall, middle - half, 0, wall + 1, middle + half, 8);
    if key {
        # The panels side by side, touching, so they open as one (a key
        # taken once).
        for panel in range(panels) {
            y = middle - half + panel * 2;
            build.rising_door(float(wall), float(y), 0.0, float(wall + 1), float(y + 2), 8.0, {"key": key, "wait": "-1"});
        }
    }
    return room;
}

"""A button on a post: a pillar a cell square at (x, y) from lift `z`
three lifts high, the button on its face toward `direction` (0 +x ... 3
-y), pushed (or shot) as a cue."""
def post_button(build: Raising, x: int, y: int, z: int, direction: int, shot: bool = False) -> Cue {
    build.solid(x, y, z, x + 1, y + 1, z + 3);
    if direction == 0 {
        return build.push(float(x + 1), float(y) + 0.5, float(z) + 1.0, 0, shot);
    }
    if direction == 2 {
        return build.push(float(x), float(y) + 0.5, float(z) + 1.0, 2, shot);
    }
    if direction == 1 {
        return build.push(float(x) + 0.5, float(y + 1), float(z) + 1.0, 1, shot);
    }
    return build.push(float(x) + 0.5, float(y), float(z) + 1.0, 3, shot);
}

"""A crane's crate riding to and fro high over a floor: a train two cells
square and two lifts high from (x, a) to (x, b) on lift `z` (from (a, x)
to (b, x) when `along_x`), out of a body's reach."""
def crane(build: Raising, x: int, a: int, b: int, z: int, along_x: bool = False) -> Cue {
    if along_x {
        stops = [[float(a), float(x), float(z)], [float(b), float(x), float(z)]];
    } else {
        stops = [[float(x), float(a), float(z)], [float(x), float(b), float(z)]];
    }
    return build.train([2.0, 2.0, 2.0], stops, 50.0, 3.0);
}

"""Quake II's laser: a beam from (x, y), `z` lifts up, out the way
`direction` goes (0 +x ... 3 -y) to the first wall, hurting whoever
crosses it; on from the start when `on`, and toggled each time its cue
fires (a security grid a button shuts off)."""
def laser(build: Raising, x: float, y: float, z: float, direction: int, on: bool = True, damage: int = 4) -> Cue {
    fields = {"classname": "target_laser", "angle": str(build.facing(direction)), "spawnflags": "3" if on else "2", "dmg": str(damage)};
    build.put_point(fields, x, y, z, "q2");
    return build.cue([fields], "laser");
}

"""A grid of lasers across a hall: beams from the wall at the cell line
y = `y` (pointing +y, or -y when `back`) at each x of `xs`, at each
height of `heights` (lifts over lift `z`). Answers their cues."""
def laser_grid(build: Raising, xs: list[float], y: float, z: int, heights: list[float], back: bool = False) -> list[Cue] {
    found: list[Cue] = [];
    for x in xs {
        for height in heights {
            found.append(laser(build, x, y, float(z) + height, 3 if back else 1));
        }
    }
    return found;
}

"""Quake II's bars: a wall of the prefab's cells (a cell's bars, a
grate) there from the start and gone, or back, each time its cue fires
(func_wall TOGGLE and START_ON)."""
def bars(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> Cue {
    fields = {"classname": "func_wall", "spawnflags": "6", "asset_game": "q2"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, kit_of(build.district).door);
    return build.cue([fields], "bars");
}

"""A leaking pipe at (x, y), `z` lifts up, dripping water every `every`
seconds or so (a timer and Quake II's splash, falling)."""
def drip(build: Raising, x: float, y: float, z: float, every: float) {
    fields = {"classname": "target_splash", "angle": "-2", "count": "6", "sounds": "2"};
    build.put_point(fields, x, y, z, "q2");
    build.timer(every) +>:Fires:+> build.cue([fields], "drip");
}
