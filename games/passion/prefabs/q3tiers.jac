"""Moves Quake III's arenas are built of, shared by the arena modules from
q3dm9 to q3dm16 and drawn in a prefab's own cells through its `Raising`:
decks over air, hurting pits, the key taken as a cue, edges kept clear of
railings where a pad throws a body over them or a body drops off."""
import math;
import from ..prefab { Raising, Cue, Fires }
import from ..space { Space }
import from .common { key_item }

"""Keep every cell of the box x0..x1, y0..y1 on lift `z` clear of
railings (a pad's landing edge, a drop's lip, a bridge's ends)."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A deck a lift thick with its floor at lift `z` over the cells x0..x1,
y0..y1: a gallery, a bridge, a catwalk, air left under it."""
def deck(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int) {
    build.solid(x0, y0, z - 1, x1, y1, z);
}

"""Quake III's hurting volume (a trigger_hurt): a box of the prefab's cells
that wounds whoever stands in it, `damage` a second (the floor of a pit,
a pool of lava)."""
def hurt(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int = 5) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage), "spawnflags": "16"}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""The key (`key_gold` or `key_silver`) lying on a floor, as a cue that
fires when it is taken."""
def key_taken(build: Raising, key: str, x: float, y: float, z: int) -> Cue {
    fields = {"classname": key_item(key), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    return build.cue([fields], "key");
}

"""A pit's fall: over its floor (the box x0..x1, y0..y1 from lift `z`),
in halves along its length as Quake III's pits are cut, the floor hurts
and a touch warns who lands there and, a moment on, lets loose `wakes`
(foes lying in wait over the pit)."""
def pit_fall(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, message: str, wakes: Cue) {
    late = build.delay(1.0);
    late +>:Fires:+> wakes;
    parts: list[list[int]] = [[x0, y0, x1, y1]];
    if x1 - x0 >= 6 and x1 - x0 >= y1 - y0 {
        half = (x0 + x1) // 2;
        parts = [[x0, y0, half, y1], [half, y0, x1, y1]];
    } elif y1 - y0 >= 6 {
        half = (y0 + y1) // 2;
        parts = [[x0, y0, x1, half], [x0, half, x1, y1]];
    }
    for part in parts {
        hurt(build, float(part[0]), float(part[1]), float(z), float(part[2]), float(part[3]), float(z + 2));
        landed = build.touch(float(part[0]), float(part[1]), float(z), float(part[2]), float(part[3]), float(z + 4), True, message);
        landed +>:Fires:+> late;
    }
}

"""A jump pad on the floor at the prefab's cell point (x, y), lift `z`,
that lands a body at (lx, ly) on lift `lz`. Quake III's pads aim the top
of the arc at their target, 96 units over the higher floor, and the body
falls on past it; the target is set short of the landing by as much."""
def pad_to(build: Raising, x: float, y: float, z: int, lx: float, ly: float, lz: int) {
    top = float(max(z, lz)) * 16.0 + 96.0;
    rise = top - (float(z) * 16.0 + 22.0);
    fall = max(1.0, top + 3.0 - (float(lz) * 16.0 + 24.0));
    share = 1.0 / (1.0 + math.sqrt(fall / 400.0) / math.sqrt(rise / 400.0));
    build.jump_pad(x, y, z, x + (lx - x) * share, y + (ly - y) * share, lz);
}

"""Closets beyond a room's wall (the cell line y = `side`, the closets
beyond it), one at each of `xs` on lift `floor`, a foe of `foes` (in turn)
in each, behind doors that open when `opens` fires: what waits there
meets the player on the way back (a key's ambush, as the cue graph)."""
def closets(build: Raising, opens: Cue, side: int, floor: int, xs: list[int], foes: list[str]) {
    for (index, at) in enumerate(xs) {
        closet = build.room(at, side + 1, floor, at + 3, side + 4, floor + 7);
        build.widen(closet, at, side, floor, at + 3, side + 1, floor + 6);
        opens +>:Fires:+> build.opened(float(at), float(side), float(floor), float(at + 3), float(side + 1), float(floor + 6));
        build.foe(float(at) + 1.5, float(side) + 2.5, floor, foes[index % len(foes)], 270.0);
    }
}

"""A touch over the box x0..x1, y0..y1 from lift `z` (`high` lifts tall)
that lets loose what lies in wait, `after` seconds on: answers the cue of
the foes to wait on it."""
def wake_on(build: Raising, x0: float, y0: float, x1: float, y1: float, z: float, after: float = 0.5, high: float = 6.0) -> Cue {
    touched = build.touch(x0, y0, z, x1, y1, z + high);
    late = build.delay(after);
    foes = build.waiting();
    touched +>:Fires:+> late;
    late +>:Fires:+> foes;
    return foes;
}
