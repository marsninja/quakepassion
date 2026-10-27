"""Works the Quake II stretches of the hangars, the labs, the command
centre, the strike, the space port, the cities and the boss levels share,
drawn in a prefab's own cells through its `Raising`: decks over floors,
panels that spark, charges going off one after another, stashes behind
panels that break, squads that appear when a cue fires, and doors over
the ways out that a cue opens.

Each wiring goes through the `Cue` / `Fires` graph, as the stretches'
own do."""
import math;
import from ..random { Stream }
import from ..prefab { Prefab, Port, Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }
import from .common { key_item }

"""A deck of floor a lift thick, its top at lift `z`, over the cells
x0..x1, y0..y1 (a gallery, a catwalk, a mezzanine): air under it stays
air, so a floor below runs on under it."""
def deck(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int) {
    build.solid(x0, y0, z - 1, x1, y1, z);
}

"""Keeps every cell of the box x0..x1, y0..y1 on lift `z` clear of
railings (where a stair lands, a catwalk meets a gallery, a drop is
walked off)."""
def keep_box(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A panel that sparks now and then: a timer firing sparks at (x, y), `z`
lifts up, out the way `direction` goes (0 +x ... 3 -y)."""
def sparking(build: Raising, x: float, y: float, z: float, direction: int, seconds: float) {
    build.timer(seconds) +>:Fires:+> build.sparks(x, y, z, direction);
}

"""Charges going off one after another when `cue` fires: a chain of
relays, each `step` seconds after the last, each setting off a blast at
its point ([x, y, z], z in lifts). Answers the chain's last relay."""
def blast_chain(build: Raising, cue: Cue, points: list[list[float]], step: float) -> Cue {
    last = cue;
    for at in points {
        late = build.delay(step);
        last +>:Fires:+> late;
        late +>:Fires:+> build.explosion(at[0], at[1], at[2]);
        last = late;
    }
    return last;
}

"""A stash in an outcrop: a block of solid four cells square at (x0, y0)
on lift `z`, `high` lifts tall, a closet two cells square in its middle
behind a panel on its face the way `direction` goes (0 +x ... 3 -y) that
breaks when shot; the closet counts as a secret and holds `item`. The
panel's cells are air under it, so the closet opens once it breaks.
Answers the panel's cue (its breaking)."""
def stash(build: Raising, x0: int, y0: int, z: int, direction: int, item: str, high: int = 7) -> Cue {
    build.solid(x0, y0, z, x0 + 4, y0 + 4, z + high);
    panel = [x0 + 3, y0 + 1, x0 + 4, y0 + 3];
    if direction == 2 {
        panel = [x0, y0 + 1, x0 + 1, y0 + 3];
    } elif direction == 1 {
        panel = [x0 + 1, y0 + 3, x0 + 3, y0 + 4];
    } elif direction == 3 {
        panel = [x0 + 1, y0, x0 + 3, y0 + 1];
    }
    closet = build.room(x0 + 1, y0 + 1, z, x0 + 3, y0 + 3, z + 4);
    build.widen(closet, panel[0], panel[1], z, panel[2], panel[3], z + 4);
    broken = build.breakable(float(panel[0]), float(panel[1]), float(z), float(panel[2]), float(panel[3]), float(z + 4), 20);
    build.secret(float(x0 + 1), float(y0 + 1), float(z), float(x0 + 3), float(y0 + 3), float(z + 3));
    build.supply(float(x0) + 2.0, float(y0) + 2.0, z, item, "q2");
    return broken;
}

"""Foes that appear when `cue` fires (Quake II's TRIGGER_SPAWN): one of
`kinds` (in turn) at each of `spots` ([x, y, z] each, z in lifts),
facing `angle`."""
def squad(build: Raising, cue: Cue, spots: list[list[float]], kinds: list[str], angle: float) {
    held = build.waiting();
    cue +>:Fires:+> held;
    for (index, at) in enumerate(spots) {
        build.foe(at[0], at[1], int(at[2]), kinds[index % len(kinds)], angle, waits=held);
    }
}

"""A door over the way out `port` of `prefab` (in its own wall, on the
port's floor) that opens only when `cue` fires; a hint at it for whoever
comes to it first (the originals' "This door is opened elsewhere")."""
def held_door(build: Raising, prefab: Prefab, port: Port, cue: Cue, hint: str = "This door is opened elsewhere") {
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    top = float(port.floor + port.high);
    floor = float(port.floor);
    fields = {"wait": "-1"};
    if port.face == 0 {
        build.rising_door(float(prefab.long - 1), low, floor, float(prefab.long), high, top, fields);
        near = [float(prefab.long - 3), low, float(prefab.long - 1), high];
    } elif port.face == 1 {
        build.rising_door(low, float(prefab.wide - 1), floor, high, float(prefab.wide), top, fields);
        near = [low, float(prefab.wide - 3), high, float(prefab.wide - 1)];
    } elif port.face == 3 {
        build.rising_door(low, 0.0, floor, high, 1.0, top, fields);
        near = [low, 1.0, high, 3.0];
    } else {
        build.rising_door(0.0, low, floor, 1.0, high, top, fields);
        near = [1.0, low, 3.0, high];
    }
    cue +>:Fires:+> build.cue([fields], "door");
    if hint {
        build.touch(near[0], near[1], floor, near[2], near[3], floor + 6.0, False, hint);
    }
}

"""A foe walking a round of `points` ([x, y] each, the prefab's cells) on
lift `z` while idle."""
def rounds(build: Raising, kind: str, points: list[list[float]], z: int) {
    build.foe(points[0][0], points[0][1], z, kind, 0.0, patrol=points);
}

"""A closet sealed in the rock under or beside a stretch (`x0`, `y0`, on
lift `z0`) whose foe is brought in to (tx, ty) on lift `tz` when `cue`
fires (`summon`), with a blast where it lands."""
def beamed(build: Raising, cue: Cue, x0: int, y0: int, z0: int, kind: str, tx: float, ty: float, tz: int, angle: float) {
    cue +>:Fires:+> build.summon(x0, y0, z0, kind, tx, ty, tz, angle);
    cue +>:Fires:+> build.sparks(tx, ty, float(tz) + 0.5, 0);
}

"""A hidden closet in an outcrop, as `stash`, but behind a stretch of the
outcrop's wall that opens back and aside when shot (a secret door).
Answers the secret's cue (its finding)."""
def hidden_closet(build: Raising, x0: int, y0: int, z: int, direction: int, item: str, high: int = 7) -> Cue {
    build.solid(x0, y0, z, x0 + 4, y0 + 4, z + high);
    panel = [x0 + 3, y0 + 1, x0 + 4, y0 + 3];
    if direction == 2 {
        panel = [x0, y0 + 1, x0 + 1, y0 + 3];
    } elif direction == 1 {
        panel = [x0 + 1, y0 + 3, x0 + 3, y0 + 4];
    } elif direction == 3 {
        panel = [x0 + 1, y0, x0 + 3, y0 + 1];
    }
    closet = build.room(x0 + 1, y0 + 1, z, x0 + 3, y0 + 3, z + 4);
    build.widen(closet, panel[0], panel[1], z, panel[2], panel[3], z + 4);
    build.secret_door(float(panel[0]), float(panel[1]), float(z), float(panel[2]), float(panel[3]), float(z + 4), (direction + 2) % 4);
    build.supply(float(x0) + 2.0, float(y0) + 2.0, z, item, "q2");
    return build.secret(float(x0 + 1), float(y0 + 1), float(z), float(x0 + 3), float(y0 + 3), float(z + 3));
}

"""Glass panes that shatter one after another when `cue` fires, `step`
seconds apart (the labs' tanks bursting in turn): each pane a breakable
box [x0, y0, z0, x1, y1, z1] of the prefab's cells (in air carved for
it), a blast at it, and the foe behind it (at `inside`'s point [x, y, z],
one of `kinds` in turn) appearing as it goes. Answers the chain's last
relay."""
def shatter_row(build: Raising, cue: Cue, panes: list[list[float]], inside: list[list[float]], kinds: list[str], angle: float, step: float, deaths: Cue | None = None) -> Cue {
    last = cue;
    for (index, pane) in enumerate(panes) {
        late = build.delay(step);
        last +>:Fires:+> late;
        late +>:Fires:+> build.breakable(pane[0], pane[1], pane[2], pane[3], pane[4], pane[5], 10);
        late +>:Fires:+> build.explosion((pane[0] + pane[3]) * 0.5, (pane[1] + pane[4]) * 0.5, pane[2] + 1.0);
        held = build.waiting();
        late +>:Fires:+> held;
        at = inside[index];
        build.foe(at[0], at[1], int(at[2]), kinds[index % len(kinds)], angle, waits=held);
        if deaths is not None {
            held +>:Fires:+> deaths;
        }
        last = late;
    }
    return last;
}

"""A security laser (Quake II's target_laser) set at (x, y), `z` lifts up,
beaming the way `direction` goes (0 +x ... 3 -y) and burning what it
crosses: when `cue` fires it comes on, and `seconds` on it goes off."""
def laser_burst(build: Raising, cue: Cue, x: float, y: float, z: float, direction: int, seconds: float) {
    fields = {"classname": "target_laser", "angle": str(build.facing(direction)), "dmg": "4"};
    build.put_point(fields, x, y, z, "q2");
    beam = build.cue([fields], "laser");
    cue +>:Fires:+> beam;
    late = build.delay(seconds);
    cue +>:Fires:+> late;
    late +>:Fires:+> beam;
}

"""A key (`key_gold` or `key_silver`) on a floor at (x, y), lift `z`, as a
cue: its taking fires what it is wired to."""
def key_taken(build: Raising, key: str, x: float, y: float, z: int) -> Cue {
    fields = {"classname": key_item(key), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    return build.cue([fields], "key");
}

"""Closets beyond a room's wall line y = `side` (the closets beyond it,
three cells square), one at each of `xs` on lift `floor`, a foe of `foes`
(in turn) in each, their doors opening when `cue` fires."""
def closets(build: Raising, cue: Cue, side: int, floor: int, xs: list[int], foes: list[str]) {
    doors: list[dict[str, str]] = [];
    for (index, at) in enumerate(xs) {
        closet = build.room(at, side + 1, floor, at + 3, side + 4, floor + 7);
        build.widen(closet, at, side, floor, at + 3, side + 1, floor + 6);
        fields = {"wait": "-1"};
        build.rising_door(float(at), float(side), float(floor), float(at + 3), float(side + 1), float(floor + 6), fields);
        doors.append(fields);
        build.foe(float(at) + 1.5, float(side) + 2.5, floor, foes[index % len(foes)], 270.0);
    }
    cue +>:Fires:+> build.cue(doors, "closets");
}

"""Shells falling in water now and then: a timer throwing up a spray of
water at (x, y), `z` lifts up (the surface)."""
def splashing(build: Raising, x: float, y: float, z: float, seconds: float) {
    fields = {"classname": "target_splash", "angle": "-1", "count": "24", "sounds": "2"};
    build.put_point(fields, x, y, z, "q2");
    build.timer(seconds) +>:Fires:+> build.cue([fields], "spray");
}

"""Barrels or crates on a floor (lift `z`) that burst when shot: `count`
of them two cells square and two or three lifts high, at points of the
box x0..x1, y0..y1 kept a cell off each of `clear` ([x0, y0, x1, y1]
each, the ones placed added to it)."""
def barrels(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 10 {
        tries += 1;
        x = dice.between(x0, max(x0, x1 - 2));
        y = dice.between(y0, max(y0, y1 - 2));
        box = [x, y, x + 2, y + 2];
        clash = False;
        for other in clear {
            if box[0] < other[2] + 1 and other[0] < box[2] + 1 and box[1] < other[3] + 1 and other[1] < box[3] + 1 {
                clash = True;
            }
        }
        if clash {
            continue;
        }
        clear.append(box);
        build.breakable(float(x), float(y), float(z), float(x + 2), float(y + 2), float(z + dice.between(2, 3)), 10);
        placed += 1;
    }
}

"""A jump pad at (x, y) on lift `z` that lands a body at (lx, ly) on lift
`lz`: the pad aims the top of its arc, so it is aimed short of the landing
by the share of the arc spent rising."""
def pad_to(build: Raising, x: float, y: float, z: int, lx: float, ly: float, lz: int) {
    top = float(max(z, lz)) * 16.0 + 96.0;
    rise = top - (float(z) * 16.0 + 22.0);
    fall = max(1.0, top + 3.0 - (float(lz) * 16.0 + 24.0));
    share = 1.0 / (1.0 + math.sqrt(fall / 400.0) / math.sqrt(rise / 400.0));
    build.jump_pad(x, y, z, x + (lx - x) * share, y + (ly - y) * share, lz);
}

"""A box of the prefab's cells that hurts whoever stands in it (`damage`
a tenth of a second): an exhaust, a vent to the vacuum, a machine's works."""
def hurting(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage), "asset_game": "q2"}, x0, y0, z0, x1, y1, z1, "trigger");
}
