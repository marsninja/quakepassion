"""Works the Quake II stretches of the hangars, the labs, the command
centre, the strike, the space port, the cities and the boss levels share,
drawn in a prefab's own cells through its `Raising`: decks over floors,
panels that spark, charges going off one after another, stashes behind
panels that break, squads that appear when a cue fires, and doors over
the ways out that a cue opens.

Each wiring goes through the `Cue` / `Fires` graph, as the stretches'
own do."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { kit_of }

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
