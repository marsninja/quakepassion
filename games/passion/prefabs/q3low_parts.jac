"""Shapes the reworked early arenas of Quake III (q3dm0 to q3dm8) share,
drawn in a prefab's own cells through its `Raising`: floors that float
over others (balconies, bridges, galleries round a hall), jump pads with
the edge they throw a body over kept free of railings, lava with its hurt,
hints that speak again a little later (q3dm0's voice), and sliding doors."""
import math;
import from ..prefab { Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }

"""A floor that floats: the cells x0..x1, y0..y1 made solid `thick` lifts
under lift `z`, so a body stands on it at `z` and the air under it stays
(a balcony, a bridge, a catwalk, a gallery's deck)."""
def slab(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, thick: int = 1) {
    build.solid(x0, y0, z - thick, x1, y1, z);
}

"""Every cell of the box x0..x1, y0..y1 on lift `z` kept free of railings
(an edge to drop from, a pad's landing, a bridge's end)."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for y in range(y0, y1) {
        for x in range(x0, x1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A hurt: a box of the prefab's cells that wounds whoever is in it
`damage` points at a time (lava's burn, the void's fall)."""
def hurt(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage)}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""Lava in the cells x0..x1, y0..y1 from lift z0 to a lift under z1, and
its hurt inside it; the steps up out of it along its near side (`pool`'s)
when `steps`. Answers its space."""
def lava(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, damage: int = 20, steps: bool = True) -> Space {
    space = build.pool(x0, y0, z0, x1, y1, z1, 4, False, steps);
    hurt(build, float(x0), float(y0), float(z0), float(x1), float(y1), float(z1) - 1.0, damage);
    return space;
}

"""A hint: a touch of the box that shows `first` once, `later` again
`seconds` on, and `last` (when given) as long again after that (the
arena's voice, each a relay of its own). Answers the touch's cue, to wire
more to it."""
def hint(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, first: str, later: str, seconds: float, last: str = "") -> Cue {
    seen = build.touch(x0, y0, z0, x1, y1, z1, True, first);
    then = build.delay(seconds);
    then.items[0]["message"] = later;
    seen +>:Fires:+> then;
    if last {
        after = build.delay(seconds);
        after.items[0]["message"] = last;
        then +>:Fires:+> after;
    }
    return seen;
}

"""Foes lying in wait, let loose `seconds` after `cue` fires (a relay
between). Answers the cue to give them (`foe(..., waits=)`)."""
def wake_later(build: Raising, cue: Cue, seconds: float) -> Cue {
    late = build.delay(seconds);
    cue +>:Fires:+> late;
    foes = build.waiting();
    late +>:Fires:+> foes;
    return foes;
}

"""A jump pad on lift `z` at (x, y) throwing a body to (tx, ty) on lift
`tz`, and the cells of the box kx0..kx1, ky0..ky1 on lift `tz` (the edge
it throws a body over, where it lands) kept free of railings."""
def pad(build: Raising, space: Space, x: float, y: float, z: int, tx: float, ty: float, tz: int, kx0: int, ky0: int, kx1: int, ky1: int) {
    build.jump_pad(x, y, z, tx, ty, tz);
    keep_box(build, space, kx0, ky0, kx1, ky1, tz);
}

"""A stair whose steps float (each `thick` lifts deep), so the floor runs on
under its higher steps: `steps` lifts from lift `z` at the cell (x, y), a
lift a cell the way `direction` goes (0 +x, 1 +y, 2 -x, 3 -y), `width`
cells across (+y or +x of (x, y))."""
def flying_stair(build: Raising, x: int, y: int, z: int, direction: int, steps: int, width: int, thick: int = 2) {
    for step in range(steps) {
        top = z + step + 1;
        low = max(z, top - thick);
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

"""A pair of doors across the cell line x (from x to x + 1), from y0 to
y1, lifts z0 to z1, that slide apart into the walls beside them when a
body comes near (or when their cue fires, when `fired`): q3dm0's sliding
gates. Answers their cue."""
def sliding_pair(build: Raising, x: int, y0: int, y1: int, z0: int, z1: int, fired: bool = False) -> Cue {
    kit = kit_of(build.district);
    split = (y0 + y1) // 2;
    items: list[dict[str, str]] = [];
    for side in [0, 1] {
        lo = y0 if side == 0 else split;
        hi = split if side == 0 else y1;
        fields = {"classname": "func_door", "angle": str(build.facing(3 if side == 0 else 1)), "speed": "160", "wait": "3", "lip": "4"};
        if fired {
            fields["wait"] = "-1";
        }
        build.put_box(fields, float(x), float(lo), float(z0), float(x + 1), float(hi), float(z1), kit.door);
        reach = hi - lo;
        if side == 0 {
            build.rock_round(float(x), float(lo - reach), float(z0), float(x + 1), float(lo), float(z1));
        } else {
            build.rock_round(float(x), float(hi), float(z0), float(x + 1), float(hi + reach), float(z1));
        }
        build.casting.doors += 1;
        items.append(fields);
    }
    return build.cue(items if fired else [], "doors");
}

"""Pillars a cell square from lift z0 to z1 at each of `spots` ([x, y]
each)."""
def columns(build: Raising, spots: list[list[int]], z0: int, z1: int) {
    for spot in spots {
        build.solid(spot[0], spot[1], z0, spot[0] + 1, spot[1] + 1, z1);
    }
}

"""A floating floor over the cells x0..x1, y0..y1 on lift `z` but for the
box `hole` ([x0, y0, x1, y1], where a stair comes up through it): the
pieces round the hole, each a slab."""
def slab_except(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, hole: list[int]) {
    if not hole or hole[2] <= x0 or x1 <= hole[0] or hole[3] <= y0 or y1 <= hole[1] {
        slab(build, x0, y0, x1, y1, z);
        return;
    }
    hx0 = max(x0, hole[0]);
    hy0 = max(y0, hole[1]);
    hx1 = min(x1, hole[2]);
    hy1 = min(y1, hole[3]);
    if x0 < hx0 {
        slab(build, x0, y0, hx0, y1, z);
    }
    if hx1 < x1 {
        slab(build, hx1, y0, x1, y1, z);
    }
    if y0 < hy0 {
        slab(build, hx0, y0, hx1, hy0, z);
    }
    if hy1 < y1 {
        slab(build, hx0, hy1, hx1, y1, z);
    }
}

"""The cells round the edge of the box x0..x1, y0..y1 (its outermost ring
of cells) on lift `z` kept free of railings: a floor's whole rim to drop
from, as the arenas leave their ledges open."""
def keep_frame(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        build.keep(space, x, y0, z);
        build.keep(space, x, y1 - 1, z);
    }
    for y in range(y0 + 1, y1 - 1) {
        build.keep(space, x0, y, z);
        build.keep(space, x1 - 1, y, z);
    }
}

"""Lava from cell line x0 to x1 (y0..y1 across), lifts z0..z1, crossed by
stepping stones along the lane lane0..lane1: a cell of lava, two of stone,
a cell of lava... (so every gap is a cell, to jump), each reach of lava a
pool of its own with its hurt. Answers where the stones stand ([x, ...])."""
def lava_stones(build: Raising, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, lane0: int, lane1: int, damage: int = 30) -> list[int] {
    stones: list[int] = [];
    x = x0;
    while x < x1 {
        if (x - x0) % 3 == 0 or x + 1 >= x1 {
            lava(build, x, y0, z0, x + 1, y1, z1, damage, False);
            x += 1;
        } else {
            stones.append(x);
            if y0 < lane0 {
                lava(build, x, y0, z0, x + 2, lane0, z1, damage, False);
            }
            if lane1 < y1 {
                lava(build, x, lane1, z0, x + 2, y1, z1, damage, False);
            }
            x += 2;
        }
    }
    return stones;
}

"""A jump pad on lift `z` at (x, y) that comes down at (lx, ly) on lift
`lz`: the point it aims at (the top of its arc, 96 units over the higher
of the two floors, which the body passes and goes on beyond) set short of
the landing by the arc's rise and fall, so a long throw over a chasm lands
where it is meant to and not past it. The box kx0..kx1, ky0..ky1 on lift
`lz` (the edge it comes in over) is kept free of railings."""
def pad_to(build: Raising, space: Space, x: float, y: float, z: int, lx: float, ly: float, lz: int, kx0: int, ky0: int, kx1: int, ky1: int) {
    top = float(max(z, lz)) * 16.0 + 96.0;
    rise = math.sqrt(top - float(z) * 16.0);
    fall = math.sqrt(top - float(lz) * 16.0);
    share = rise / (rise + fall);
    build.jump_pad(x, y, z, x + (lx - x) * share, y + (ly - y) * share, lz);
    keep_box(build, space, kx0, ky0, kx1, ky1, lz);
}
