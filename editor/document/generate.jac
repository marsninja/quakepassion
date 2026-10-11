"""Brushes that make more of themselves when the level is built.

A group is a duplicator when it says how many copies it wants: each copy
stands `_offset` on from the last and is turned `_turn` degrees more about
the vertical line through `_pivot` (the group's own middle when it names
none); `_mirror` adds the group's image across the plane through the pivot
on an axis. The copies are images: they follow the group whenever it is
edited, and exist only in what is built until they are made real."""
import math;
import from engine.math.vec3 { Vec3 }
import from ..formats.map { MapItem }
import from ..geometry.brush { Side, brush_windings, windings_bounds, side_turned }
import from ..geometry.mapping { side_stretched }
import from .scene { read_vector, side_moved }
import from ..geometry.csg { carve_sides, joined_pieces }

"""The keys that make a group a duplicator."""
glob DUPLICATOR_KEYS: list[str] = ["_copies", "_offset", "_turn", "_pivot", "_mirror"];

"""Whether an entity's fields ask for copies of its brushes."""
def duplicates(fields: dict[str, str]) -> bool {
    return fields.get("_copies", "0").strip().isdigit() and int(fields.get("_copies", "0").strip()) > 0
        or fields.get("_mirror", "") in ["x", "y", "z"];
}

"""The middle of the box round some brushes."""
def:priv brushes_middle(brushes: list[list[Side]]) -> Vec3 {
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    high = Vec3(x=-far, y=-far, z=-far);
    for sides in brushes {
        box = windings_bounds(brush_windings(sides));
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
            high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
        }
    }
    if low.x > high.x {
        return Vec3();
    }
    return low.add(high).scale(0.5);
}

"""The brushes a duplicator's images are made of: each copy's, and the
mirror image of them all. The group's own brushes are not among them."""
def image_brushes(fields: dict[str, str], brushes: list[list[Side]]) -> list[list[Side]] {
    made: list[list[Side]] = [];
    if not duplicates(fields) or len(brushes) == 0 {
        return made;
    }
    copies = int(fields.get("_copies", "0").strip()) if fields.get("_copies", "0").strip().isdigit() else 0;
    copies = min(copies, 256);
    offset = read_vector(fields.get("_offset", ""));
    step = offset if offset is not None else Vec3();
    turn = 0.0;
    try {
        turn = math.radians(float(fields.get("_turn", "0")));
    } except ValueError {
        turn = 0.0;
    }
    named = read_vector(fields.get("_pivot", ""));
    pivot = named if named is not None else brushes_middle(brushes);
    for copy in range(1, copies + 1) {
        for sides in brushes {
            image = sides;
            if turn != 0.0 {
                image = [side_turned(side, pivot, turn * float(copy)) for side in image];
            }
            if step.length() > 0.0 {
                image = [side_moved(side, step.scale(float(copy))) for side in image];
            }
            made.append(image);
        }
    }
    axis = fields.get("_mirror", "");
    if axis in ["x", "y", "z"] {
        factors = Vec3(
            x=-1.0 if axis == "x" else 1.0, y=-1.0 if axis == "y" else 1.0, z=-1.0 if axis == "z" else 1.0
        );
        for sides in brushes + list(made) {
            made.append([side_stretched(side, pivot, factors) for side in sides]);
        }
    }
    return made;
}

"""A map with every duplicator's images put in as brushes of its own
entity (the world's, for a group): what is built and played."""
def with_images(items: list[MapItem]) -> list[MapItem] {
    result: list[MapItem] = [];
    for read in items {
        if not duplicates(read.fields) or len(read.brushes) == 0 {
            result.append(read);
            continue;
        }
        result.append(MapItem(fields=read.fields, brushes=read.brushes + image_brushes(read.fields, read.brushes)));
    }
    return result;
}

"""The field that makes a group a digger: its brushes are holes, cut out of
everything else when the level is built and never built themselves."""
glob DIGGER_KEY: str = "_digger";

"""Whether an entity's fields make its brushes holes."""
def digs(fields: dict[str, str]) -> bool {
    return fields.get(DIGGER_KEY, "0").strip() == "1";
}

"""A map with its diggers' brushes cut out of every other brush, and the
diggers themselves left out. The document keeps them whole: move a digger
and the hole moves."""
def with_holes(items: list[MapItem]) -> list[MapItem] {
    cutters: list[list[Side]] = [];
    for read in items {
        if digs(read.fields) {
            for brush in read.brushes {
                cutters.append(brush);
            }
        }
    }
    if len(cutters) == 0 {
        return items;
    }
    result: list[MapItem] = [];
    for read in items {
        if digs(read.fields) {
            continue;
        }
        left: list[list[Side]] = [];
        for brush in read.brushes {
            pieces: list[list[Side]] = [brush];
            cut = False;
            for cutter in cutters {
                after: list[list[Side]] = [];
                for piece in pieces {
                    carved = carve_sides(piece, cutter);
                    if carved is None {
                        after.append(piece);
                    } else {
                        cut = True;
                        for part in carved {
                            after.append(part);
                        }
                    }
                }
                pieces = after;
            }
            for piece in (joined_pieces(pieces) if cut else pieces) {
                left.append(piece);
            }
        }
        result.append(MapItem(fields=read.fields, brushes=left));
    }
    return result;
}
