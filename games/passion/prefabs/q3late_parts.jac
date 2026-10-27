"""Shapes the later Quake III arenas' stretches share (q3dm17 to q3dm19 and
the tourney arenas), drawn in a prefab's own cells through its `Raising`:
decks floating over a void, the void's burning floor and its teleporters
back up, jump pads that keep the edges they throw over, hurts, ambushes
woken a while after a touch, and stairs that fly free of the floor."""
import math;
import from ..random { Stream }
import from ..prefab { Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }

"""A deck: solid over the cells x0..x1, y0..y1 from `thick` lifts under lift
`z` up to it, so its top is a floor at `z` with air under it."""
def deck(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, thick: int = 2) {
    build.solid(x0, y0, z - thick, x1, y1, z);
}

"""Keep every cell of the box x0..x1, y0..y1 on lift `z` clear of railings."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A hurt: a box of the prefab's cells that wounds whoever is in it
`damage` points at a time (the void's fall, lava's burn, a charged trench)."""
def hurt(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage)}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""The floor of a void, the cells x0..x1, y0..y1 on lift `z`: it burns
whoever falls to it, and teleporters along its middle send them back up
to (tx, ty) on lift `tz`, facing `angle` (the arenas' void, made a way
back rather than a death). One every `every` cells along x."""
def void_floor(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, tx: float, ty: float, tz: int, angle: float, every: int = 10, damage: int = 8) {
    hurt(build, float(x0), float(y0), float(z), float(x1), float(y1), float(z) + 2.0, damage);
    middle = float(y0 + y1) * 0.5;
    count = max(1, (x1 - x0) // every);
    for index in range(count) {
        x = float(x0) + float(x1 - x0) * (float(index) + 0.5) / float(count);
        build.teleporter(x, middle, z, tx, ty, tz, angle);
    }
}

"""A jump pad at (x, y) on lift `z` that lands a body at (lx, ly) on lift
`lz`: its target is set where the arc tops out (96 units over the higher
floor) so that the fall from there ends at the landing. Keeps clear of
railings the cells of the takeoff's edge `lip` ([x0, y0, x1, y1] on lift
z) and of the landing's edge `land` (on lift lz), either left out when
empty."""
def throw(build: Raising, space: Space, x: float, y: float, z: int, lx: float, ly: float, lz: int, lip: list[int] | None = None, land: list[int] | None = None) {
    top = max(z, lz);
    up = math.sqrt(float((top - z) * 16 + 74));
    down = math.sqrt(float((top - lz) * 16 + 72));
    part = up / (up + down);
    build.jump_pad(x, y, z, x + (lx - x) * part, y + (ly - y) * part, lz);
    if lip is not None and lip {
        keep_box(build, space, lip[0], lip[1], lip[2], lip[3], z);
    }
    if land is not None and land {
        keep_box(build, space, land[0], land[1], land[2], land[3], lz);
    }
}

"""The void's floor, the cells x0..x1, y0..y1 on lift `z`: it burns
whoever falls to it, and jump pads on it throw them back up (as
q3dm19's pad at the foot of its void does): each of `pads` [x, y, lx,
ly, lz] from (x, y) on the floor to (lx, ly) on lift lz, the landing's
edge `keeps` ([x0, y0, x1, y1, z] each) clear of railings."""
def void_pads(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, pads: list[list[float]], keeps: list[list[int]]) {
    hurt(build, float(x0), float(y0), float(z), float(x1), float(y1), float(z) + 2.0, 8);
    for spot in pads {
        throw(build, space, spot[0], spot[1], z, spot[2], spot[3], int(spot[4]), None, None);
    }
    for box in keeps {
        keep_box(build, space, box[0], box[1], box[2], box[3], box[4]);
    }
}

"""Foes woken a while after a touch: a cue for `foe(..., waits=)` fired
`seconds` after `touched` fires (the arenas' items respawning, made foes
that come for the player when the timer runs out)."""
def wake_later(build: Raising, touched: Cue, seconds: float) -> Cue {
    late = build.delay(seconds);
    touched +>:Fires:+> late;
    woken = build.waiting();
    late +>:Fires:+> woken;
    return woken;
}

"""A stair whose steps fly free of what is under them: `steps` blocks a
cell along the way `direction` goes (0 +x ... 3 -y) from (x, y), `width`
across, each `thick` lifts thick, the first's top on lift z + 1."""
def flying_stair(build: Raising, x: int, y: int, z: int, direction: int, steps: int, width: int, thick: int = 2) {
    for step in range(steps) {
        top = z + step + 1;
        at_x = x + step if direction == 0 else (x - step if direction == 2 else x);
        at_y = y + step if direction == 1 else (y - step if direction == 3 else y);
        x1 = at_x + (1 if direction % 2 == 0 else width);
        y1 = at_y + (width if direction % 2 == 0 else 1);
        build.solid(at_x, at_y, top - thick, x1, y1, top);
    }
}

"""Columns a cell square from lift z0 to z1 at each of `spots` ([x, y])."""
def columns(build: Raising, spots: list[list[int]], z0: int, z1: int) {
    for spot in spots {
        build.solid(spot[0], spot[1], z0, spot[0] + 1, spot[1] + 1, z1);
    }
}

"""A hint shown once to whoever walks into the box, as the arenas' voice
calls out what lies ahead. Answers its cue."""
def hint(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, message: str) -> Cue {
    return build.touch(x0, y0, z0, x1, y1, z1, True, message);
}

"""A floor slab over the cells x0..x1, y0..y1, its top a floor at lift `z`
(`thick` lifts thick), but for the `holes` ([x0, y0, x1, y1] each) cut
through it as air of `space`: a stairwell, a shaft, an atrium."""
def floor_slab(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, holes: list[list[int]], thick: int = 2) {
    build.solid(x0, y0, z - thick, x1, y1, z);
    for hole in holes {
        build.widen(space, hole[0], hole[1], z - thick, hole[2], hole[3], z);
    }
}

"""A door that slides aside into the wall when touched: a slab of the
prefab's cells x0..x1, y0..y1 from lift z0 to z1, moving the way
`direction` goes (0 +x ... 3 -y) into solid beside it, and back a while
after (the original's doors that open as a body comes up to them)."""
def slide_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) {
    build.put_box({"classname": "func_door", "angle": str(build.facing(direction)), "speed": "160", "wait": "3", "lip": "4"}, x0, y0, z0, x1, y1, z1, kit_of(build.district).door);
    build.casting.doors += 1;
}
