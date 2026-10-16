"""Brushwork: an arranged, dressed expedition as map items, the brushes and
entities a map file holds and the studio and the level compiler read.

The massing's shell becomes the world's structural brushes, each side
dressed by the kit of the space it faces: floor on top, ceiling beneath,
wall on the sides, sky over an open court. The dressing's boxes join them,
and its lamps become light entities."""
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side }
import from .massing { Massing, CellBox, CELL, LIFT, shell_steps }
import from .spaces { Space }
import from .kits { Kit, kit_of, kit_surfaces, kit_water, kit_liquid }
import from .dress { Dressing, Lamp3, box_brush }

"""The structural brushes: the shell's boxes with the materials of the
space each faces."""
def shell_brushes(mass: Massing, spaces: dict[int, Space]) -> list[list[Side]] {
    found: list[list[Side]] = [];
    for label in shell_brush_steps(mass, spaces, found) {
        continue;
    }
    return found;
}

"""`shell_brushes` a step at a time, into `found`."""
def shell_brush_steps(mass: Massing, spaces: dict[int, Space], found: list[list[Side]]) -> Iterator[str] {
    boxes: list[CellBox] = [];
    yield from shell_steps(mass, boxes);
    for (number, box) in enumerate(boxes) {
        if number % 96 == 95 {
            yield "brushes";
        }
        space = spaces.get(box.owner, None);
        if space is None {
            continue;
        }
        kit = kit_of(space.district);
        looks = kit_surfaces(kit, space.variant);
        ceiling = looks[2];
        glowing: list[int] = [];
        if space.sky and box.z0 >= space.z + space.h {
            # Open sky lights the court beneath it, as Quake II's does.
            ceiling = kit.sky;
            glowing = [5];
        }
        wall = looks[0];
        floor = looks[1];
        materials = [wall, wall, wall, wall, floor, ceiling];
        # A side with no air across it faces only solid or the void outside:
        # never seen, so never drawn.
        for side in range(6) {
            if not side_sees_air(mass, box, side) {
                materials[side] = "caulk";
            }
        }
        found.append(box_brush(box.low(), box.high(), materials, kit.scale, [side for side in glowing if materials[side] != "caulk"]));
    }
}

"""Whether any cell across one side of a box (0 +x, 1 -x, 2 +y, 3 -y, 4 +z,
5 -z) is air."""
def side_sees_air(mass: Massing, box: CellBox, side: int) -> bool {
    x0 = box.x0;
    x1 = box.x1;
    y0 = box.y0;
    y1 = box.y1;
    z0 = box.z0;
    z1 = box.z1;
    if side == 0 {
        x0 = box.x1;
        x1 = box.x1 + 1;
    } elif side == 1 {
        x0 = box.x0 - 1;
        x1 = box.x0;
    } elif side == 2 {
        y0 = box.y1;
        y1 = box.y1 + 1;
    } elif side == 3 {
        y0 = box.y0 - 1;
        y1 = box.y0;
    } elif side == 4 {
        z0 = box.z1;
        z1 = box.z1 + 1;
    } else {
        z0 = box.z0 - 1;
        z1 = box.z0;
    }
    for z in range(z0, z1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                if mass.air(x, y, z) {
                    return True;
                }
            }
        }
    }
    return False;
}

"""A light entity for a lamp."""
def lamp_item(lamp: Lamp3) -> MapItem {
    return MapItem(
        fields={
            "classname": "light",
            "origin": str(int(lamp.x)) + " " + str(int(lamp.y)) + " " + str(int(lamp.z)),
            "light": str(lamp.level),
            "_color": lamp.color
        }
    );
}

"""The map items of an expedition: the world (structure and dressing),
then the lamps, then `extra` entities (the population)."""
def map_items(mass: Massing, spaces: list[Space], dressing: Dressing, extra: list[MapItem], message: str = "") -> list[MapItem] {
    items: list[MapItem] = [];
    for label in map_item_steps(mass, spaces, dressing, extra, message, items) {
        continue;
    }
    return items;
}

"""`map_items` a step at a time, into `items`."""
def map_item_steps(mass: Massing, spaces: list[Space], dressing: Dressing, extra: list[MapItem], message: str, items: list[MapItem]) -> Iterator[str] {
    by_id: dict[int, Space] = {};
    for space in spaces {
        by_id[space.id] = space;
    }
    world = MapItem(
        fields={"classname": "worldspawn", "message": message, "_minlight": "8", "_bounce": "1", "generator": "passion-v4"}
    );
    for item in extra {
        if item.fields.get("classname", "") == "info_player_start" {
            world.fields["_passion_kit"] = item.fields.get("_passion_kit", "");
        }
    }
    shell: list[list[Side]] = [];
    yield from shell_brush_steps(mass, by_id, shell);
    world.brushes = shell;
    for space in spaces {
        if space.flood <= 0 {
            continue;
        }
        # The liquid fills the room's lowest floor across its whole box;
        # inside the solid it is nothing.
        kit = kit_of(space.district);
        material = kit_liquid(kit, space.deadly, space.liquid);
        low = Vec3(x=float(space.x) * CELL, y=float(space.y) * CELL, z=float(space.z) * LIFT);
        high = Vec3(x=float(space.x + space.w) * CELL, y=float(space.y + space.d) * CELL, z=float(space.z + space.flood) * LIFT - 4.0);
        liquid = box_brush(low, high, [material, material, material, material, material, material], 1.0);
        # Said outright in each side's contents (lava 8, slime 16, water 32),
        # not left to the material's name.
        lowered = material.lower();
        contents = 8 if "lava" in lowered else (16 if "slime" in lowered else 32);
        for side in liquid {
            side.contents = contents;
        }
        world.brushes.append(liquid);
    }
    for brush in dressing.brushes {
        world.brushes.append(brush);
    }
    items.append(world);
    for lamp in dressing.lamps {
        items.append(lamp_item(lamp));
    }
    for item in extra {
        items.append(item);
    }
    yield "items";
}

"""Where to stand a player in a space: on its stage, facing the room's
middle (an `info_player_start`)."""
def start_item(space: Space) -> MapItem {
    x = (float(space.stage[0]) + 0.5) * CELL;
    y = (float(space.stage[1]) + 0.5) * CELL;
    z = float(space.stage[2]) * LIFT + 24.0;
    return MapItem(fields={"classname": "info_player_start", "origin": str(int(x)) + " " + str(int(y)) + " " + str(int(z)), "angle": "90"});
}
