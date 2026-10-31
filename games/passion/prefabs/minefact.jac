"""Shapes and set-pieces Quake II's mines and factory share in their
prefabs (mintro, mine1 to mine4, fact1 to fact3), drawn in a prefab's own
cells through its `Raising`: floor slabs over open floor, hurting volumes,
timed sparks, stashes behind panels that break, presses and carts.

Each wiring goes through the prefab's `Cue` / `Fires` graph."""
import from ..prefab { Raising, Cue, Fires, Port }
import from ..space { Space }
import from ..kits { kit_of }
import from ..cast { origin_text }

"""A floor slab `thick` lifts thick, its top at lift `z` over the cells
x0..x1, y0..y1: a gallery, a catwalk, a bridge over open floor."""
def slab(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, thick: int = 1) {
    build.solid(x0, y0, z - thick, x1, y1, z);
}

"""Quake II's hurting volume over a box of the prefab's cells (z in lifts):
`damage` a tick to whatever stands in it (lava's heat, a crusher's foot,
a live cable). Answers its cue (firing it turns a toggled hurt on or off)."""
def hurt(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) -> Cue {
    fields = {"classname": "trigger_hurt", "dmg": str(damage)};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, "trigger");
    return build.cue([fields], "hurt");
}

"""A pool of lava or slime (`code` 4 or 3) in the cells x0..x1, y0..y1,
from lift z0 to z1, with a hurting volume over its liquid as Quake II's
pits have. Answers the pool's space."""
def burning(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, code: int, damage: int = 20) -> Space {
    space = build.pool(x0, y0, z0, x1, y1, z1, code, False, False);
    hurt(build, float(x0), float(y0), float(z0), float(x1), float(y1), float(z1 - 1), damage);
    return space;
}

"""A broken pipe or panel at (x, y), `z` lifts up, that sparks the way
`direction` goes (0 +x ... 3 -y) every `seconds` or so: Quake II's
func_timer firing a target_splash. Answers the timer's cue."""
def sparking(build: Raising, x: float, y: float, z: float, direction: int, seconds: float) -> Cue {
    clock = build.timer(seconds);
    clock +>:Fires:+> build.sparks(x, y, z, direction);
    return clock;
}

"""A stash: a closet of the prefab's cells x..x+2, y..y+2 from lift `z`
(cut into solid the caller drew), behind a panel a cell thick on its face
`face` (0 +x ... 3 -y) that breaks when shot; inside, the secret's touch
(when `hidden`) and `item`. The panel's cell is carved too, so it breaks
open on air. Answers the panel's cue (what its breaking fires)."""
def stash(build: Raising, x: int, y: int, z: int, face: int, item: str, game: str = "q2", hidden: bool = True) -> Cue {
    closet = build.room(x, y, z, x + 2, y + 2, z + 4);
    px0 = x;
    py0 = y;
    px1 = x + 2;
    py1 = y + 2;
    if face == 0 {
        px0 = x + 2;
        px1 = x + 3;
    } elif face == 2 {
        px0 = x - 1;
        px1 = x;
    } elif face == 1 {
        py0 = y + 2;
        py1 = y + 3;
    } else {
        py0 = y - 1;
        py1 = y;
    }
    build.widen(closet, px0, py0, z, px1, py1, z + 4);
    panel = build.breakable(float(px0), float(py0), float(z), float(px1), float(py1), float(z + 4), 20);
    if hidden {
        build.secret(float(x), float(y), float(z), float(x + 2), float(y + 2), float(z + 3));
    }
    build.supply(float(x) + 1.0, float(y) + 1.0, z, item, game);
    return panel;
}

"""Charges that go off one after another when `cue` fires: an explosion at
each of `points` ([x, y, z] in the prefab's cells, z in lifts), `step`
seconds apart, each through a relay of its own."""
def charges(build: Raising, cue: Cue, points: list[list[float]], step: float) {
    for (index, point) in enumerate(points) {
        late = build.delay(step * float(index));
        cue +>:Fires:+> late;
        late +>:Fires:+> build.explosion(point[0], point[1], point[2]);
    }
}

"""A press: a block of the prefab's cells `size` [x, y, lifts] that rides
up and down between lift `low` and lift `high` at (x, y), pausing at each
(Quake II's stamping and drilling machines, a func_train between two
stops). Answers its train's cue."""
def press(build: Raising, x: float, y: float, size: list[float], low: float, high: float, speed: float, pause: float) -> Cue {
    return build.train(size, [[x, y, high], [x, y, low]], speed, pause);
}

"""A cart: a platform three cells square riding back and forth between
`stops` ([x, y, z] each, the low corner, z in lifts) along rails (a mine's
ore cart, a factory's carrier), waiting `pause` seconds at each. Answers
its train's cue."""
def cart(build: Raising, stops: list[list[float]], speed: float, pause: float) -> Cue {
    return build.train([3.0, 3.0, 1.0], stops, speed, pause);
}

"""Quake II's timer that waits to be fired: firing it starts it, firing it
again stops it (a run of charges set off and later stopped). It fires
what it is wired to every `seconds` or so while it runs."""
def timer_off(build: Raising, seconds: float) -> Cue {
    fields = {"classname": "func_timer", "wait": str(seconds), "random": str(seconds * 0.3), "spawnflags": "0", "origin": "0 0 0", "asset_game": "q2"};
    build.casting.put(fields);
    return build.cue([fields], "timer");
}

"""A door across the opening of a way (`port`) of a prefab `long` by
`wide` cells, that rises when `cue` fires and stays open (a way on
opened by a counter, a switch, a valve)."""
def port_door(build: Raising, long: int, wide: int, port: Port, cue: Cue) {
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    top = float(port.floor + port.high);
    fields = {"wait": "-1"};
    cue +>:Fires:+> build.cue([fields], "door");
    if port.face == 0 {
        build.rising_door(float(long - 1), low, float(port.floor), float(long), high, top, fields);
    } elif port.face == 1 {
        build.rising_door(low, float(wide - 1), float(port.floor), high, float(wide), top, fields);
    } elif port.face == 2 {
        build.rising_door(0.0, low, float(port.floor), 1.0, high, top, fields);
    } else {
        build.rising_door(low, 0.0, float(port.floor), high, 1.0, top, fields);
    }
}

"""A door drawn shut across a doorway's niche (a way that goes nowhere: a
start's way in, a sealed exit), as a wall the door's material shows on,
in a port's opening of a prefab `long` by `wide` cells."""
def sealed(build: Raising, long: int, wide: int, port: Port, material: str) {
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    top = float(port.floor + port.high);
    fields = {"classname": "func_wall"};
    if port.face == 0 {
        build.put_box(fields, float(long) - 1.25, low, float(port.floor), float(long) - 1.0, high, top, material);
    } elif port.face == 1 {
        build.put_box(fields, low, float(wide) - 1.25, float(port.floor), high, float(wide) - 1.0, top, material);
    } elif port.face == 2 {
        build.put_box(fields, 1.0, low, float(port.floor), 1.25, high, top, material);
    } else {
        build.put_box(fields, low, 1.0, float(port.floor), high, 1.25, top, material);
    }
}

"""A crusher: a block of the prefab's cells `size` [x, y, lifts] slamming
down from lift `high` to lift `low` at (x, y) and up again, pausing at
each, hurting `damage` whatever it is stopped by (Quake II's stamping
presses, func_train with dmg). Answers its train's cue."""
def crusher(build: Raising, x: float, y: float, size: list[float], low: float, high: float, speed: float, pause: float, damage: int) -> Cue {
    stops = [[x, y, high], [x, y, low]];
    names = [build.name("crush" + str(len(build.casting.items) + index)) for index in range(2)];
    for index in range(2) {
        stop = stops[index];
        corner = build.box_units(stop[0], stop[1], stop[2], stop[0] + size[0], stop[1] + size[1], stop[2] + size[2])[0];
        build.casting.put({"classname": "path_corner", "targetname": names[index], "target": names[(index + 1) % 2], "wait": str(pause), "origin": origin_text(corner.x, corner.y, corner.z)});
    }
    fields = {"classname": "func_train", "target": names[0], "speed": str(speed), "dmg": str(damage)};
    build.put_box(fields, x, y, high, x + size[0], y + size[1], high + size[2], kit_of(build.district).step);
    return build.cue([], "train");
}

"""Quake II's earthquake: when its cue fires, the ground shakes for
`seconds` (a cave-in, a blast deep in the rock)."""
def quake(build: Raising, x: float, y: float, z: float, seconds: int) -> Cue {
    fields = {"classname": "target_earthquake", "count": str(seconds), "speed": "200"};
    build.put_point(fields, x, y, z, "q2");
    return build.cue([fields], "quake");
}
