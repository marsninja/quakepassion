"""Shapes the reworked first five originals' stretches share (e1m1, e1m3,
e2m2, base1, q3dm6), drawn in a prefab's own cells through its
`Raising`: decks over a floor, stashes behind walls that open when shot,
stairs that turn back over themselves."""
import from ..prefab { Raising, Cue, Fires }
import from ..space { Space }

"""A deck: a slab a lift thick over the cells x0..x1, y0..y1 whose top is
lift `z`, air left under it (a gallery, a catwalk, a mezzanine)."""
def deck(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int) {
    build.solid(x0, y0, z - 1, x1, y1, z);
}

"""A stash: a block of rock four cells square from the cell (cx, cy) on
lift `z`, a closet two cells square in it against the side away from
`face` (0 +x ... 3 -y, the way its secret door looks out), and the door
(drawn as the wall, opened when shot) between the closet and the room;
`reward` lies in the closet, of `game`'s. Answers the secret's cue (fired
as the closet is found). `breaks` makes the door Quake II's breakable
panel instead."""
def stash(build: Raising, cx: int, cy: int, z: int, face: int, reward: str, game: str = "q1", breaks: bool = False) -> Cue {
    build.solid(cx, cy, z, cx + 4, cy + 4, z + 6);
    if face == 1 {
        closet = [cx + 1, cy, cx + 3, cy + 2];
        door = [cx + 1, cy + 2, cx + 3, cy + 4];
        slide = 3;
    } elif face == 3 {
        closet = [cx + 1, cy + 2, cx + 3, cy + 4];
        door = [cx + 1, cy, cx + 3, cy + 2];
        slide = 1;
    } elif face == 0 {
        closet = [cx, cy + 1, cx + 2, cy + 3];
        door = [cx + 2, cy + 1, cx + 4, cy + 3];
        slide = 2;
    } else {
        closet = [cx + 2, cy + 1, cx + 4, cy + 3];
        door = [cx, cy + 1, cx + 2, cy + 3];
        slide = 0;
    }
    build.room(closet[0], closet[1], z, closet[2], closet[3], z + 4);
    if breaks {
        build.breakable(float(door[0]), float(door[1]), float(z), float(door[2]), float(door[3]), float(z + 4), 20);
    } else {
        build.secret_door(float(door[0]), float(door[1]), float(z), float(door[2]), float(door[3]), float(z + 4), slide);
    }
    found = build.secret(float(closet[0]), float(closet[1]), float(z), float(closet[2]), float(closet[3]), float(z + 3));
    build.supply(float(closet[0]) + 1.0, float(closet[1]) + 1.0, z, reward, game);
    return found;
}

"""A stair of `steps` lifts that climbs along x from (x, y) on lift `z`
(the way `direction` goes, 0 +x or 2 -x), turns on a landing and climbs
back over its own foot on a deck (a stair winding over itself), `width`
cells wide, the second flight beside the first across +y (or -y when
`side` is -1). Answers the cell [x, y] beside which the top lands, and
the lift it lands on."""
def switchback(build: Raising, space: Space, x: int, y: int, z: int, direction: int, steps: int, width: int, side: int) -> list[int] {
    half = steps // 2;
    rest = steps - half;
    step_x = 1 if direction == 0 else -1;
    other_y = y + width if side > 0 else y - width;
    # The first flight, solid to its treads.
    for step in range(half) {
        at = x + step * step_x;
        build.solid(at, y, z, at + 1, y + width, z + step + 1);
    }
    # The landing, a cell past the first flight's top, across both flights.
    turn_x = x + half * step_x;
    low_y = min(y, other_y);
    build.solid(turn_x, low_y, z, turn_x + 1, low_y + 2 * width, z + half);
    # The second flight back the other way, each tread a slab with air
    # under it, over the floor beside the first flight.
    for step in range(rest) {
        at = turn_x - (step + 1) * step_x;
        build.solid(at, other_y, z + half + step, at + 1, other_y + width, z + half + step + 1);
    }
    top_x = turn_x - rest * step_x;
    for across in range(width) {
        build.keep(space, top_x, other_y + across, z + steps);
        build.keep(space, turn_x, low_y + across, z + half);
        build.keep(space, turn_x, low_y + width + across, z + half);
    }
    return [top_x - step_x, other_y, z + steps];
}
