"""Dressing: the detail that makes carved space read as architecture.

Read off the massing once everything is carved, so it fits whatever the
archetypes and corridors made:

- baseboards where floor meets wall, and a cornice where wall meets ceiling,
  each run merged along its wall;
- pilasters ribbing the walls at a steady rhythm, on plinths, where the
  wall stands whole from floor to ceiling, and on every other one a lamp;
- lamps in the ceiling of low wide rooms, and along corridors;
- railings along the edges of balconies, bridges and stairs over a drop;
- frames round the doorways corridors open in a space's walls.

Everything is boxes of brush sides with the kit's materials, and lamps as
points with a level and a colour (light entities, which the bake reads)."""
import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, Plane3, classic_mapping }
import from .random { Stream }
import from .massing { Massing, CELL, LIFT }
import from .spaces { Space, Doorway, OPEN_HIGH }
import from .kits { Kit, kit_of }

glob TRIM_DEPTH: float = 6.0,
     TRIM_HIGH: float = 16.0,
     RAIL_HIGH: float = 32.0,
     RAIL_DEPTH: float = 8.0,
     PILASTER_WIDE: float = 24.0,
     PILASTER_DEEP: float = 12.0,
     GLOW_VALUE: int = 300,
     WAINSCOT_HIGH: float = 64.0;

"""A lamp: where it is, how bright (a light entity's `light`) and its colour."""
obj Lamp3 {
    has x: float,
        y: float,
        z: float,
        level: int = 200,
        color: str = "255 255 255";
}

"""What the dressing made."""
obj Dressing {
    has brushes: list[list[Side]] = [],
        lamps: list[Lamp3] = [],
        # How many lamps each space was given.
        lit: dict[int, int] = {};

    def add_lamp(space: Space, lamp: Lamp3) {
        self.lamps.append(lamp);
        self.lit[space.id] = self.lit.get(space.id, 0) + 1;
    }
}

"""A box brush with a material for each side (+x, -x, +y, -y, +z, -z),
mapped to the world at `scale`; sides in `glowing` give light."""
def box_brush(low: Vec3, high: Vec3, materials: list[str], scale: float, glowing: list[int] = []) -> list[Side] {
    faces = [
        (Vec3(x=1.0), high.x),
        (Vec3(x=-1.0), -low.x),
        (Vec3(y=1.0), high.y),
        (Vec3(y=-1.0), -low.y),
        (Vec3(z=1.0), high.z),
        (Vec3(z=-1.0), -low.z)
    ];
    sides: list[Side] = [];
    for (index, face) in enumerate(faces) {
        normal = face[0];
        side = Side(
            plane=Plane3(normal=normal, dist=face[1]),
            material=materials[index],
            mapping=classic_mapping(normal, 0.0, 0.0, 0.0, scale, scale)
        );
        if index in glowing {
            side.flags = 1;
            side.value = GLOW_VALUE;
        }
        sides.append(side);
    }
    return sides;
}

"""A box all of one material."""
def plain_box(low: Vec3, high: Vec3, material: str, scale: float) -> list[Side] {
    return box_brush(low, high, [material, material, material, material, material, material], scale);
}

"""The step of a horizontal direction (0 +x, 1 -x, 2 +y, 3 -y)."""
def direction_step(direction: int) -> list[int] {
    if direction == 0 {
        return [1, 0];
    }
    if direction == 1 {
        return [-1, 0];
    }
    if direction == 2 {
        return [0, 1];
    }
    return [0, -1];
}

"""A strip along the wall on side `direction` of a run of cells: from cell
`start` to `finish` (inclusive) along the wall, at heights `low`..`high`,
standing `depth` out from the wall. `line` is the cell coordinate across
the wall (x for walls facing x, y for walls facing y)."""
def wall_strip(direction: int, line: int, start: int, finish: int, low: float, high: float, depth: float) -> list[Vec3] {
    if direction == 0 {
        face = float(line + 1) * CELL;
        return [Vec3(x=face - depth, y=float(start) * CELL, z=low), Vec3(x=face, y=float(finish + 1) * CELL, z=high)];
    }
    if direction == 1 {
        face = float(line) * CELL;
        return [Vec3(x=face, y=float(start) * CELL, z=low), Vec3(x=face + depth, y=float(finish + 1) * CELL, z=high)];
    }
    if direction == 2 {
        face = float(line + 1) * CELL;
        return [Vec3(x=float(start) * CELL, y=face - depth, z=low), Vec3(x=float(finish + 1) * CELL, y=face, z=high)];
    }
    face = float(line) * CELL;
    return [Vec3(x=float(start) * CELL, y=face, z=low), Vec3(x=float(finish + 1) * CELL, y=face + depth, z=high)];
}

"""The cell at (`line`, `along`) for a wall facing `direction`: walls facing
x run along y, walls facing y along x."""
def run_cell(direction: int, line: int, along: int) -> list[int] {
    if direction < 2 {
        return [line, along];
    }
    return [along, line];
}

"""Dress the massing."""
def dress(mass: Massing, spaces: list[Space], dice: Stream) -> Dressing {
    made = Dressing();
    by_id: dict[int, Space] = {};
    for space in spaces {
        by_id[space.id] = space;
    }
    edge_trims(mass, by_id, made);
    pilasters(mass, by_id, made, dice);
    ceiling_lamps(mass, by_id, made, dice);
    dark_rooms(mass, by_id, made);
    railings(mass, by_id, made);
    return made;
}

def:priv owner_space(by_id: dict[int, Space], owner: int) -> Space | None {
    if owner <= 0 or (owner - 1) not in by_id {
        return None;
    }
    return by_id[owner - 1];
}

"""Whether a wall stands at a cell: solid there and for six lifts above (or,
for a cornice, below), so a stair's riser or a ledge is not taken for one."""
def wall_stands(mass: Massing, x: int, y: int, z: int, down: bool) -> bool {
    for lift in range(6) {
        if mass.air(x, y, z - lift if down else z + lift) {
            return False;
        }
    }
    return True;
}

"""Whether the space whose air a cell is (by owner number) is a room high
enough for a cornice."""
def tall_room(by_id: dict[int, Space], owner: int) -> bool {
    space = owner_space(by_id, owner);
    return space is not None and space.role != "corridor" and space.h >= 12;
}

"""Baseboards and cornices: runs of cells along a wall, at a floor (solid
below) or under a ceiling (solid above)."""
def edge_trims(mass: Massing, by_id: dict[int, Space], made: Dressing) {
    for direction in range(4) {
        step = direction_step(direction);
        lines = mass.nx if direction < 2 else mass.ny;
        length = mass.ny if direction < 2 else mass.nx;
        for z in range(mass.nz) {
            for line in range(lines) {
                for top in [False, True] {
                    run_start = -1;
                    run_owner = 0;
                    for along in range(length + 1) {
                        owner = 0;
                        if along < length {
                            cell = run_cell(direction, line, along);
                            cx = cell[0];
                            cy = cell[1];
                            here = mass.at(cx, cy, z);
                            if here > 0 and wall_stands(mass, cx + step[0], cy + step[1], z, top) and (not top or tall_room(by_id, here)) {
                                if (not top and not mass.air(cx, cy, z - 1)) or (top and not mass.air(cx, cy, z + 1)) {
                                    owner = here;
                                }
                            }
                        }
                        if owner != run_owner {
                            if run_owner > 0 and run_start >= 0 {
                                space = owner_space(by_id, run_owner);
                                if space is not None {
                                    kit = kit_of(space.district);
                                    if top {
                                        low = float(z + 1) * LIFT - TRIM_HIGH;
                                        high = float(z + 1) * LIFT;
                                    } else {
                                        low = float(z) * LIFT;
                                        high = float(z) * LIFT + TRIM_HIGH;
                                    }
                                    corners = wall_strip(direction, line, run_start, along - 1, low, high, TRIM_DEPTH);
                                    made.brushes.append(plain_box(corners[0], corners[1], kit.trim, kit.scale));
                                    start_cell = run_cell(direction, line, run_start);
                                    if not top and space.role != "corridor" and mass.headroom(start_cell[0], start_cell[1], z) >= 8 {
                                        # A lower band of the wall in the kit's second
                                        # material, and a rail along its top.
                                        band = wall_strip(direction, line, run_start, along - 1, low, low + WAINSCOT_HIGH, 3.0);
                                        made.brushes.append(plain_box(band[0], band[1], kit.lower, kit.scale));
                                        rail = wall_strip(direction, line, run_start, along - 1, low + WAINSCOT_HIGH, low + WAINSCOT_HIGH + 8.0, TRIM_DEPTH);
                                        made.brushes.append(plain_box(rail[0], rail[1], kit.trim, kit.scale));
                                    }
                                }
                            }
                            run_owner = owner;
                            run_start = along;
                        }
                    }
                }
            }
        }
    }
}

"""Pilasters along the walls of rooms (not corridors) where the wall
stands whole from floor to ceiling, every few cells, with a lamp on every
other one."""
def pilasters(mass: Massing, by_id: dict[int, Space], made: Dressing, dice: Stream) {
    for space in by_id.values() {
        if space.role == "corridor" or space.kind in ["shaft", "vault"] {
            continue;
        }
        kit = kit_of(space.district);
        owner = space.id + 1;
        gap = 4 if space.w * space.d > 120 else 3;
        lamp_every = 2;
        for direction in range(4) {
            step = direction_step(direction);
            # The walls of this space facing `direction`: the cells along
            # the box's side, at each floor level.
            if direction == 0 {
                line = space.x + space.w - 1;
            } elif direction == 1 {
                line = space.x;
            } elif direction == 2 {
                line = space.y + space.d - 1;
            } else {
                line = space.y;
            }
            first = space.y if direction < 2 else space.x;
            last = (space.y + space.d if direction < 2 else space.x + space.w) - 1;
            for z in range(space.z, space.z + space.h) {
                count = 0;
                placed = 0;
                for along in range(first + 1, last) {
                    cell = run_cell(direction, line, along);
                    cx = cell[0];
                    cy = cell[1];
                    if mass.at(cx, cy, z) != owner or mass.air(cx, cy, z - 1) {
                        count = 0;
                        continue;
                    }
                    rise = mass.headroom(cx, cy, z);
                    if rise < OPEN_HIGH + 1 {
                        count = 0;
                        continue;
                    }
                    # The wall must stand whole beside the cell, and the
                    # cells either side be floor at this height too.
                    whole = True;
                    for up in range(rise) {
                        if mass.air(cx + step[0], cy + step[1], z + up) {
                            whole = False;
                        }
                    }
                    for side in [-1, 1] {
                        near = run_cell(direction, line, along + side);
                        if not mass.standing(near[0], near[1], z) or mass.at(near[0], near[1], z) != owner {
                            whole = False;
                        }
                    }
                    if not whole {
                        count = 0;
                        continue;
                    }
                    count += 1;
                    if count % gap != 2 {
                        continue;
                    }
                    low = float(z) * LIFT;
                    high = float(z + rise) * LIFT;
                    middle = (float(along) + 0.5) * CELL;
                    half = PILASTER_WIDE * 0.5;
                    shaft = pilaster_box(direction, line, middle - half, middle + half, low, high, PILASTER_DEEP);
                    made.brushes.append(plain_box(shaft[0], shaft[1], kit.support, kit.scale));
                    plinth = pilaster_box(direction, line, middle - half - 4.0, middle + half + 4.0, low, low + 24.0, PILASTER_DEEP + 4.0);
                    made.brushes.append(plain_box(plinth[0], plinth[1], kit.trim, kit.scale));
                    capital = pilaster_box(direction, line, middle - half - 4.0, middle + half + 4.0, high - 16.0, high, PILASTER_DEEP + 4.0);
                    made.brushes.append(plain_box(capital[0], capital[1], kit.trim, kit.scale));
                    placed += 1;
                    if placed % lamp_every == 1 {
                        height = low + min(112.0, max(80.0, (high - low) * 0.45));
                        add_wall_lamp(made, kit, direction, line, middle, height, PILASTER_DEEP, space);
                    }
                }
            }
        }
    }
}

"""The box of a pilaster (or anything standing out from a wall) on side
`direction` of the cells at `line`, from `start` to `finish` along the
wall, `low` to `high` up, `depth` out from the wall."""
def pilaster_box(direction: int, line: int, start: float, finish: float, low: float, high: float, depth: float) -> list[Vec3] {
    if direction == 0 {
        face = float(line + 1) * CELL;
        return [Vec3(x=face - depth, y=start, z=low), Vec3(x=face, y=finish, z=high)];
    }
    if direction == 1 {
        face = float(line) * CELL;
        return [Vec3(x=face, y=start, z=low), Vec3(x=face + depth, y=finish, z=high)];
    }
    if direction == 2 {
        face = float(line + 1) * CELL;
        return [Vec3(x=start, y=face - depth, z=low), Vec3(x=finish, y=face, z=high)];
    }
    face = float(line) * CELL;
    return [Vec3(x=start, y=face, z=low), Vec3(x=finish, y=face + depth, z=high)];
}

"""The side of a box that faces into the room from a wall on `direction`."""
def facing_side(direction: int) -> int {
    if direction == 0 {
        return 1;
    }
    if direction == 1 {
        return 0;
    }
    if direction == 2 {
        return 3;
    }
    return 2;
}

"""A lamp on a wall (or on a pilaster standing `depth` out from it): a
small glowing fixture and a light in front of it."""
def add_wall_lamp(made: Dressing, kit: Kit, direction: int, line: int, middle: float, height: float, depth: float, space: Space) {
    fixture = pilaster_box(direction, line, middle - 8.0, middle + 8.0, height - 8.0, height + 8.0, depth + 4.0);
    glow = facing_side(direction);
    made.brushes.append(
        box_brush(
            fixture[0],
            fixture[1],
            [kit.trim, kit.trim, kit.trim, kit.trim, kit.trim, kit.trim][:glow] + [kit.light]
                + [kit.trim, kit.trim, kit.trim, kit.trim, kit.trim, kit.trim][glow + 1:],
            kit.scale,
            [glow]
        )
    );
    out = depth + 28.0;
    step = direction_step(direction);
    if direction < 2 {
        face = float(line + 1) * CELL if direction == 0 else float(line) * CELL;
        x = face - float(step[0]) * out;
        y = middle;
    } else {
        face = float(line + 1) * CELL if direction == 2 else float(line) * CELL;
        x = middle;
        y = face - float(step[1]) * out;
    }
    made.add_lamp(space, Lamp3(x=x, y=y, z=height, level=lamp_strength(kit, space), color=kit.lamp_color));
}

"""How bright a space's lamps burn: the kit's level, dimmer where tension
runs high."""
def lamp_strength(kit: Kit, space: Space) -> int {
    return int(float(kit.lamp_level) * (1.1 - 0.35 * max(0.0, min(1.0, space.tension))));
}

"""Lamps hung under the ceiling of rooms whose ceiling is in reach, in a
grid; and along corridors."""
def ceiling_lamps(mass: Massing, by_id: dict[int, Space], made: Dressing, dice: Stream) {
    for space in by_id.values() {
        kit = kit_of(space.district);
        owner = space.id + 1;
        corridor = space.role == "corridor";
        if not corridor and made.lit.get(space.id, 0) > 0 {
            continue;
        }
        gap = 4 if corridor else 5;
        for cz in range(space.z, space.z + space.h) {
            for cy in range(space.y, space.y + space.d) {
                for cx in range(space.x, space.x + space.w) {
                    if mass.at(cx, cy, cz) != owner or mass.air(cx, cy, cz + 1) or not mass.air(cx, cy, cz - 1) {
                        continue;
                    }
                    # A ceiling cell: lamp it on the grid, when the floor
                    # below is near enough to light.
                    if (cx % gap) != (gap // 2) or (cy % gap) != (gap // 2) {
                        continue;
                    }
                    if corridor and not (mass.air(cx + 1, cy, cz) and mass.air(cx, cy + 1, cz)) {
                        continue;
                    }
                    floor = cz;
                    while floor > 0 and mass.air(cx, cy, floor - 1) {
                        floor -= 1;
                    }
                    reach = cz + 1 - floor;
                    if reach > 18 or space.sky {
                        continue;
                    }
                    top = float(cz + 1) * LIFT;
                    x = float(cx) * CELL + (CELL if corridor else CELL * 0.5);
                    y = float(cy) * CELL + (CELL if corridor else CELL * 0.5);
                    panel_low = Vec3(x=x - 12.0, y=y - 12.0, z=top - 6.0);
                    panel_high = Vec3(x=x + 12.0, y=y + 12.0, z=top);
                    made.brushes.append(
                        box_brush(panel_low, panel_high, [kit.trim, kit.trim, kit.trim, kit.trim, kit.trim, kit.light], kit.scale, [5])
                    );
                    made.add_lamp(space, Lamp3(x=x, y=y, z=top - 28.0, level=int(float(lamp_strength(kit, space)) * (0.8 if corridor else 1.0)), color=kit.lamp_color));
                }
            }
        }
    }
}

"""A lamp hung over each floor level of a room nothing else lit (a shaft,
a vault): over its stage, and at the middle of each upper level."""
def dark_rooms(mass: Massing, by_id: dict[int, Space], made: Dressing) {
    for space in by_id.values() {
        if space.role == "corridor" or made.lit.get(space.id, 0) > 0 {
            continue;
        }
        kit = kit_of(space.district);
        for level in space.levels {
            x = space.middle_x() * CELL;
            y = space.middle_y() * CELL;
            if space.stage and level == space.levels[0] {
                x = (float(space.stage[0]) + 0.5) * CELL;
                y = (float(space.stage[1]) + 0.5) * CELL;
            }
            made.add_lamp(space, Lamp3(x=x, y=y, z=float(level) * LIFT + 96.0, level=lamp_strength(kit, space), color=kit.lamp_color));
        }
    }
}

"""Railings along floor edges of rooms that drop three lifts or more."""
def railings(mass: Massing, by_id: dict[int, Space], made: Dressing) {
    for direction in range(4) {
        step = direction_step(direction);
        lines = mass.nx if direction < 2 else mass.ny;
        length = mass.ny if direction < 2 else mass.nx;
        for z in range(1, mass.nz) {
            for line in range(lines) {
                run_start = -1;
                run_owner = 0;
                for along in range(length + 1) {
                    owner = 0;
                    if along < length {
                        cell = run_cell(direction, line, along);
                        cx = cell[0];
                        cy = cell[1];
                        here = mass.at(cx, cy, z);
                        space = owner_space(by_id, here);
                        if space is not None and space.role != "corridor" and mass.standing(cx, cy, z) {
                            nx_ = cx + step[0];
                            ny_ = cy + step[1];
                            if mass.air(nx_, ny_, z) and mass.air(nx_, ny_, z - 1) and mass.air(nx_, ny_, z - 2)
                                and mass.air(nx_, ny_, z - 3) and mass.headroom(cx, cy, z) >= 4 {
                                owner = here;
                            }
                        }
                    }
                    if owner != run_owner {
                        if run_owner > 0 and run_start >= 0 {
                            space = owner_space(by_id, run_owner);
                            if space is not None {
                                kit = kit_of(space.district);
                                corners = wall_strip(
                                    direction,
                                    line,
                                    run_start,
                                    along - 1,
                                    float(z) * LIFT,
                                    float(z) * LIFT + RAIL_HIGH,
                                    RAIL_DEPTH
                                );
                                made.brushes.append(plain_box(corners[0], corners[1], kit.trim, kit.scale));
                            }
                        }
                        run_owner = owner;
                        run_start = along;
                    }
                }
            }
        }
    }
}

"""Frames round a doorway in a space's wall: two jambs and a lintel standing
out into the room."""
def frame_doorway(made: Dressing, space: Space, door: Doorway, high: int) {
    kit = kit_of(space.district);
    if door.side == 0 {
        line = space.x + space.w - 1;
        start = float(space.y + door.along) * CELL;
    } elif door.side == 1 {
        line = space.x;
        start = float(space.y + door.along) * CELL;
    } elif door.side == 2 {
        line = space.y + space.d - 1;
        start = float(space.x + door.along) * CELL;
    } else {
        line = space.y;
        start = float(space.x + door.along) * CELL;
    }
    finish = start + float(door.span) * CELL;
    low = float(door.level) * LIFT;
    top = low + float(high) * LIFT;
    for (a, b) in [(start - 16.0, start), (finish, finish + 16.0)] {
        jamb = pilaster_box(door.side, line, a, b, low, top + 16.0, 10.0);
        made.brushes.append(plain_box(jamb[0], jamb[1], kit.support, kit.scale));
    }
    lintel = pilaster_box(door.side, line, start, finish, top, top + 16.0, 10.0);
    made.brushes.append(plain_box(lintel[0], lintel[1], kit.trim, kit.scale));
}
