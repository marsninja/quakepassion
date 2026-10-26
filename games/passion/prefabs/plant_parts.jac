"""Set-pieces Quake II's plant and base levels share (power1, power2, cool1,
waste1..3, biggun, hangar1), drawn through a prefab's `Raising` and wired
through its `Cue` / `Fires` graph: charges going off one after another,
panels that spark now and then, stashes behind panels that break when
shot, hurting volumes in liquid, doors in a way out that a cue opens,
squads that appear when a cue fires."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }

"""The way in (unless the prefab is where a level begins, which nothing
leads into) and every way out taken, cut through the walls as the air of
`space`."""
def open_ways(build: Raising, space: Space, prefab: Prefab) {
    if prefab.via is not None {
        build.doorway(space, prefab.enter);
    }
    for port in prefab.taken {
        build.doorway(space, port);
    }
}

"""Whether one of the prefab's ways out was taken: the port at `index` of
its `leaves`."""
def taken_way(prefab: Prefab, index: int) -> bool {
    return index in prefab.taken_index;
}

"""Charges going off one after another when `cue` fires: one at each of
`points` ([x, y, z], the prefab's cells, z in lifts), `gap` seconds after
the last (Quake II's chained target_explosions, each on a relay's delay)."""
def charges(build: Raising, cue: Cue, points: list[list[float]], gap: float = 0.3) {
    for (index, point) in enumerate(points) {
        late = build.delay(gap * float(index + 1));
        cue +>:Fires:+> late;
        late +>:Fires:+> build.explosion(point[0], point[1], point[2]);
    }
}

"""A broken panel that sparks every `seconds` or so (a func_timer firing a
target_splash), at (x, y), `z` lifts up, spraying the way `direction`
goes."""
def sparking(build: Raising, seconds: float, x: float, y: float, z: float, direction: int) {
    build.timer(seconds) +>:Fires:+> build.sparks(x, y, z, direction);
}

"""Distant fighting: a timer every `seconds` setting off a run of charges
at `points` (the original's timed explosion chains outside the walls)."""
def shelling(build: Raising, seconds: float, points: list[list[float]]) {
    clock = build.timer(seconds);
    charges(build, clock, points, 0.35);
}

"""A hurting volume over a box of the prefab's cells (Quake II's
trigger_hurt, as round its slime and its machines' fans): `damage` a
second to whoever is in it."""
def hurting(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage)}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""A stash in a wall: a closet two cells wide and two deep beyond the wall
line `line` (a line of y; of x when `along_y`), `at` to `at` + 2 along the
wall on lift `z`. The room lies on the side `out` says (+1: at `line` and
beyond; -1: short of it), the closet on the other, its mouth a panel that
breaks when shot. Reaching it counts as a secret. The cells it takes must
be rock."""
def stash(build: Raising, line: int, at: int, z: int, along_y: bool, out: int, item: str) {
    near = line - 1 if out > 0 else line;
    lo = line - 3 if out > 0 else line;
    hi = line if out > 0 else line + 3;
    inner_lo = lo if out > 0 else lo + 1;
    inner_hi = hi - 1 if out > 0 else hi;
    if along_y {
        build.room(lo, at, z, hi, at + 2, z + 4);
        build.breakable(float(near), float(at), float(z), float(near + 1), float(at + 2), float(z + 4), 15);
        build.secret(float(inner_lo), float(at), float(z), float(inner_hi), float(at + 2), float(z + 3));
        build.supply(float(inner_lo + inner_hi) * 0.5, float(at) + 1.0, z, item, "q2");
    } else {
        build.room(at, lo, z, at + 2, hi, z + 4);
        build.breakable(float(at), float(near), float(z), float(at + 2), float(near + 1), float(z + 4), 15);
        build.secret(float(at), float(inner_lo), float(z), float(at + 2), float(inner_hi), float(z + 3));
        build.supply(float(at) + 1.0, float(inner_lo + inner_hi) * 0.5, z, item, "q2");
    }
}

"""Crates stacked against a wall that break apart when shot (Quake II's
func_explosive boxes): a pile of `count` crates two cells square from the
cell (x, y) on lift `z`, the way `direction` goes along the wall, every
other one a lift taller."""
def crate_pile(build: Raising, x: int, y: int, z: int, direction: int, count: int) {
    for index in range(count) {
        cx = x + (index * 2 if direction == 0 else (-index * 2 if direction == 2 else 0));
        cy = y + (index * 2 if direction == 1 else (-index * 2 if direction == 3 else 0));
        high = 2 + index % 2;
        build.breakable(float(cx), float(cy), float(z), float(cx + 2), float(cy + 2), float(z + high), 10);
    }
}

"""A door in a way out the prefab took that rises only when `cue` fires:
across the opening in its wall (port on its face), as tall as the port."""
def port_door(build: Raising, prefab: Prefab, port: Port, cue: Cue) {
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    fields = {"wait": "-1"};
    top = float(port.floor + port.high);
    if port.face == 0 {
        build.rising_door(float(prefab.long - 1), low, float(port.floor), float(prefab.long), high, top, fields);
    } elif port.face == 1 {
        build.rising_door(low, float(prefab.wide - 1), float(port.floor), high, float(prefab.wide), top, fields);
    } elif port.face == 3 {
        build.rising_door(low, 0.0, float(port.floor), high, 1.0, top, fields);
    } else {
        build.rising_door(0.0, low, float(port.floor), 1.0, high, top, fields);
    }
    cue +>:Fires:+> build.cue([fields], "door");
}

"""Foes that appear when `cue` fires (Quake II's TRIGGER_SPAWN), one of
`kinds` (in turn) at each of `spots` ([x, y, z], z in lifts), facing
`angle`."""
def squad(build: Raising, cue: Cue, spots: list[list[float]], kinds: list[str], angle: float) {
    crew = build.waiting();
    cue +>:Fires:+> crew;
    for (index, spot) in enumerate(spots) {
        build.foe(spot[0], spot[1], int(spot[2]), kinds[index % len(kinds)], angle, waits=crew);
    }
}

"""Keep a run of cells along x (y0 = y1 - 1) or y clear of railings: the
cells x0..x1, y0..y1 on lift `z`."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for y in range(y0, y1) {
        for x in range(x0, x1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A plat over the cells x0..x1, y0..y1 that waits at lift `bottom` and
rides up to `top` when stood on, its foot and head kept clear of
railings."""
def plat(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, bottom: int, top: int) {
    build.put_box({"classname": "func_plat", "height": str((top - bottom) * 16), "speed": "200"}, float(x0), float(y0), float(top) - 0.5, float(x1), float(y1), float(top), kit_of(build.district).step);
    keep_box(build, space, x0 - 1, y0 - 1, x1 + 1, y1 + 1, top);
    keep_box(build, space, x0 - 1, y0 - 1, x1 + 1, y1 + 1, bottom);
}

"""Quake II's laser: a beam from (x, y), `z` lifts up, to (tx, ty, tz)
(the prefab's cells, z in lifts), burning whoever crosses it; on from the
start when `on`, and switched over each time its cue fires. A laser's cue
must fire nothing (its `target` is where it aims)."""
def laser(build: Raising, x: float, y: float, z: float, tx: float, ty: float, tz: float, on: bool = True) -> Cue {
    aim = build.name("aim" + str(len(build.casting.items)));
    build.put_point({"classname": "info_notnull", "targetname": aim}, tx, ty, tz, "q2");
    fields = {"classname": "target_laser", "target": aim, "spawnflags": "1" if on else "0", "dmg": "8"};
    build.put_point(fields, x, y, z, "q2");
    return build.cue([fields], "laser");
}

"""Quake II's earthquake at (x, y), `z` lifts up: when its cue fires, the
ground shakes for `seconds`."""
def quake(build: Raising, x: float, y: float, z: float, seconds: int) -> Cue {
    fields = {"classname": "target_earthquake", "count": str(seconds), "speed": "150"};
    build.put_point(fields, x, y, z, "q2");
    return build.cue([fields], "quake");
}

"""A door across the gap x0..x1 (the cell line `x0`, a cell thick) from
`y0` to `y1`, lifts 0 to 8, in two leaves that rise apart, each wanting
`key` (Quake II's paired security doors)."""
def key_doors(build: Raising, x0: float, y0: float, y1: float, key: str) {
    half = (y0 + y1) * 0.5;
    build.rising_door(x0, y0, 0.0, x0 + 1.0, half, 8.0, {"key": key, "wait": "-1"});
    build.rising_door(x0, half, 0.0, x0 + 1.0, y1, 8.0, {"key": key, "wait": "-1"});
}
