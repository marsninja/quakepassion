"""Brushes that make more of themselves when the level is built.

A group is a duplicator when it says how many copies it wants: each copy
stands `_offset` on from the last, is turned `_turn` degrees more about the
line through `_pivot` along `_axis` (the vertical through the group's own
middle when it names neither), and is `_grow` times the size of the last.
`_mirror` adds its image across the planes through the pivot on one axis or
several; `_at` puts an image at every entity of a name, and `_path` at every
corner of a path. `_materials` gives the images materials in turn, and
`_each` makes each image an entity of its own with the numbers in its names
counted up. The copies are images: they follow the group whenever it is
edited, and exist only in what is built until they are made real."""
import math;
import from engine.math.vec3 { Vec3 }
import from ..formats.map { MapItem }
import from ..geometry.brush { Side, brush_windings, windings_bounds, side_turned }
import from ..geometry.mapping { side_stretched, side_spun, side_like }
import from .scene { read_vector, write_vector, side_moved, field_number }
import from ..geometry.csg { carve_sides, joined_pieces }
import from ..geometry.linear { Linear, linear_turn, linear_size, point_remapped, sides_remapped }

"""The keys that make a group a duplicator."""
glob DUPLICATOR_KEYS: list[str] = [
    "_copies", "_offset", "_turn", "_pivot", "_mirror", "_axis", "_grow", "_at", "_path", "_materials", "_each"
];

"""The axes a `_mirror` field names, in order."""
def:priv mirror_axes(fields: dict[str, str]) -> list[str] {
    named = fields.get("_mirror", "");
    return [axis for axis in ["x", "y", "z"] if axis in named] if named.strip("xyz") == "" else [];
}

"""How many copies a duplicator's fields ask for in a row."""
def:priv copies_asked(fields: dict[str, str]) -> int {
    words = fields.get("_copies", "0").strip();
    return min(256, int(words)) if words.isdigit() else 0;
}

"""Whether an entity's fields ask for copies of its brushes."""
def duplicates(fields: dict[str, str]) -> bool {
    return copies_asked(fields) > 0 or len(mirror_axes(fields)) > 0 or bool(fields.get("_at", ""))
        or bool(fields.get("_path", ""));
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

"""Brushes turned about the vertical through a pivot and then moved."""
def:priv placed(brushes: list[list[Side]], pivot: Vec3, yaw: float, delta: Vec3) -> list[list[Side]] {
    result: list[list[Side]] = [];
    for sides in brushes {
        image = sides;
        if yaw != 0.0 {
            image = [side_turned(side, pivot, yaw) for side in image];
        }
        if delta.length() > 0.0 {
            image = [side_moved(side, delta) for side in image];
        }
        result.append(image);
    }
    return result;
}

"""The entities of a name, among a map's."""
def:priv named_items(others: list[MapItem], name: str) -> list[MapItem] {
    return [other for other in others if name and other.fields.get("targetname", "") == name];
}

"""A duplicator's images, each the brushes of one copy: the copies in a
row, one at every entity `_at` names and at every corner of `_path` (found
among `others`), then the mirror images of the group and of all of those."""
def image_sets(
    fields: dict[str, str], brushes: list[list[Side]], others: list[MapItem]
) -> list[list[list[Side]]] {
    made: list[list[list[Side]]] = [];
    if not duplicates(fields) or len(brushes) == 0 {
        return made;
    }
    offset = read_vector(fields.get("_offset", ""));
    step = offset if offset is not None else Vec3();
    turn = 0.0;
    try {
        turn = math.radians(float(fields.get("_turn", "0")));
    } except ValueError {
        turn = 0.0;
    }
    about = fields.get("_axis", "z");
    axis = 0 if about == "x" else (1 if about == "y" else 2);
    grown = read_vector(fields.get("_grow", ""));
    if grown is None {
        try {
            every = float(fields.get("_grow", "1"));
            grown = Vec3(x=every, y=every, z=every);
        } except ValueError {
            grown = Vec3(x=1.0, y=1.0, z=1.0);
        }
    }
    if grown.x <= 0.0 or grown.y <= 0.0 or grown.z <= 0.0 {
        grown = Vec3(x=1.0, y=1.0, z=1.0);
    }
    growing = grown.x != 1.0 or grown.y != 1.0 or grown.z != 1.0;
    named = read_vector(fields.get("_pivot", ""));
    pivot = named if named is not None else brushes_middle(brushes);
    for copy in range(1, copies_asked(fields) + 1) {
        image_set: list[list[Side]] = [];
        for sides in brushes {
            image = sides;
            if growing {
                factors = Vec3(
                    x=math.pow(grown.x, float(copy)), y=math.pow(grown.y, float(copy)), z=math.pow(grown.z, float(copy))
                );
                image = [side_stretched(side, pivot, factors) for side in image];
            }
            if turn != 0.0 {
                image = [
                    (
                        side_turned(side, pivot, turn * float(copy))
                        if axis == 2
                        else side_spun(side, pivot, axis, turn * float(copy))
                    )
                    for side in image
                ];
            }
            if step.length() > 0.0 {
                image = [side_moved(side, step.scale(float(copy))) for side in image];
            }
            image_set.append(image);
        }
        made.append(image_set);
    }
    # One at every entity of a name, facing the way that entity does.
    for spot in named_items(others, fields.get("_at", "")) {
        at = read_vector(spot.fields.get("origin", ""));
        if at is None {
            continue;
        }
        facing = 0.0;
        try {
            facing = math.radians(float(spot.fields.get("angle", "0")));
        } except ValueError {
            facing = 0.0;
        }
        made.append(placed(brushes, pivot, facing, at.sub(pivot)));
    }
    # One at every corner of a path, facing along it.
    corners: list[Vec3] = [];
    seen: list[str] = [];
    name = fields.get("_path", "");
    while name and name not in seen and len(corners) < 64 {
        seen.append(name);
        found = named_items(others, name);
        if len(found) == 0 {
            break;
        }
        corner = read_vector(found[0].fields.get("origin", ""));
        if corner is None {
            break;
        }
        corners.append(corner);
        name = found[0].fields.get("target", "");
    }
    for index in range(len(corners)) {
        ahead = corners[index + 1].sub(corners[index])
            if index + 1 < len(corners)
            else (corners[index].sub(corners[index - 1]) if index > 0 else Vec3(x=1.0));
        made.append(placed(brushes, pivot, math.atan2(ahead.y, ahead.x), corners[index].sub(pivot)));
    }
    # Materials in turn, for the images so far.
    cycle = fields.get("_materials", "").split();
    if len(cycle) > 0 {
        for index in range(len(made)) {
            made[index] = [
                [side_like(side, cycle[index % len(cycle)]) for side in sides] for sides in made[index]
            ];
        }
    }
    # The mirror images, across one plane or several, of the group and of
    # every image made so far.
    axes = mirror_axes(fields);
    whole = [brushes] + list(made);
    for mask in range(1, 1 << len(axes)) {
        factors = Vec3(x=1.0, y=1.0, z=1.0);
        for bit in range(len(axes)) {
            if mask & (1 << bit) != 0 {
                factors = Vec3(
                    x=-1.0 if axes[bit] == "x" else factors.x,
                    y=-1.0 if axes[bit] == "y" else factors.y,
                    z=-1.0 if axes[bit] == "z" else factors.z
                );
            }
        }
        for one in whole {
            made.append([[side_stretched(side, pivot, factors) for side in sides] for sides in one]);
        }
    }
    return made;
}

"""The brushes a duplicator's images are made of, all together. The group's
own brushes are not among them."""
def image_brushes(fields: dict[str, str], brushes: list[list[Side]]) -> list[list[Side]] {
    flat: list[list[Side]] = [];
    for image_set in image_sets(fields, brushes, []) {
        for sides in image_set {
            flat.append(sides);
        }
    }
    return flat;
}

"""A name with the number at its end counted up by `more` (a name without
one counts from 1)."""
def counted_name(name: str, more: int) -> str {
    stem = name.rstrip("0123456789");
    digits = name[len(stem):];
    return stem + str((int(digits) if digits else 1) + more);
}

"""A map with every duplicator's images put in: as brushes of its own
entity (the world's, for a group), or, when it asks for `_each`, as
entities of their own with their names counted up. What is built and
played."""
def with_images(items: list[MapItem]) -> list[MapItem] {
    result: list[MapItem] = [];
    for read in items {
        if not duplicates(read.fields) or len(read.brushes) == 0 {
            result.append(read);
            continue;
        }
        sets = image_sets(read.fields, read.brushes, items);
        kind = read.fields.get("classname", "");
        if read.fields.get("_each", "0").strip() == "1" and kind != "worldspawn" and kind != "func_group" {
            result.append(read);
            for index in range(len(sets)) {
                fields: dict[str, str] = {};
                for (key, value) in read.fields.items() {
                    if key in DUPLICATOR_KEYS {
                        continue;
                    }
                    fields[key] = counted_name(value, index + 1) if key in ["targetname", "target", "killtarget"] else value;
                }
                result.append(MapItem(fields=fields, brushes=sets[index]));
            }
            continue;
        }
        flat = list(read.brushes);
        for image_set in sets {
            for sides in image_set {
                flat.append(sides);
            }
        }
        result.append(MapItem(fields=read.fields, brushes=flat));
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

# ----------------------------------------------------------------------
# Prefabs within prefabs, and instances that differ

"""The box round a map's brushes and the places of its entities: [low,
high], or none when it has neither."""
def map_box(items: list[MapItem]) -> list[Vec3] | None {
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    high = Vec3(x=-far, y=-far, z=-far);
    for item in items {
        for sides in item.brushes {
            box = windings_bounds(brush_windings(sides));
            if box is not None {
                low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
                high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
            }
        }
        stands = read_vector(item.fields.get("origin", ""));
        if stands is not None {
            low = Vec3(x=min(low.x, stands.x), y=min(low.y, stands.y), z=min(low.z, stands.z));
            high = Vec3(x=max(high.x, stands.x), y=max(high.y, stands.y), z=max(high.z, stands.z));
        }
    }
    return [low, high] if low.x <= high.x else None;
}

"""A map's entities and brushes moved."""
def map_shifted(items: list[MapItem], delta: Vec3) -> list[MapItem] {
    made: list[MapItem] = [];
    for item in items {
        fields = dict(item.fields);
        stands = read_vector(fields.get("origin", ""));
        if stands is not None {
            fields["origin"] = write_vector(stands.add(delta));
        }
        made.append(MapItem(fields=fields, brushes=placed(item.brushes, Vec3(), 0.0, delta)));
    }
    return made;
}

"""An instance of a prefab as its own fields change it. `_swap` gives
materials in pairs, each old one's sides taking the new; `_put` sets fields
on its entities, "who key value" apart at semicolons, who being a classname
or a targetname; `_names` is a word added to every name in it, so that two
instances of a gadget do not fire each other."""
def prefab_overridden(items: list[MapItem], fields: dict[str, str]) -> list[MapItem] {
    pairs = fields.get("_swap", "").split();
    puts: list[list[str]] = [];
    for part in fields.get("_put", "").split(";") {
        words = part.split();
        if len(words) >= 3 {
            puts.append([words[0], words[1], " ".join(words[2:])]);
        }
    }
    suffix = fields.get("_names", "").strip();
    if len(pairs) < 2 and len(puts) == 0 and not suffix {
        return items;
    }
    made: list[MapItem] = [];
    for item in items {
        kept = dict(item.fields);
        # By the name it had before any word was added to it.
        for put in puts {
            if kept.get("classname", "") == put[0] or kept.get("targetname", "") == put[0] {
                kept[put[1]] = put[2];
            }
        }
        if suffix {
            for key in ["targetname", "target", "killtarget"] {
                if kept.get(key, "") {
                    kept[key] = kept[key] + suffix;
                }
            }
        }
        brushes: list[list[Side]] = [];
        for sides in item.brushes {
            if len(pairs) < 2 {
                brushes.append(sides);
                continue;
            }
            dressed: list[Side] = [];
            for side in sides {
                taken = side;
                for index in range(len(pairs) // 2) {
                    if side.material == pairs[index * 2] {
                        taken = side_like(side, pairs[index * 2 + 1]);
                    }
                }
                dressed.append(taken);
            }
            brushes.append(dressed);
        }
        made.append(MapItem(fields=kept, brushes=brushes));
    }
    return made;
}

"""Prefabs within a prefab put in: each `misc_prefab` among the items gives
way to what `inner` holds for its name, standing with the middle of its
underside on the instance's origin and changed as the instance says. A
prefab `inner` does not hold is left out."""
def with_prefabs(items: list[MapItem], inner: dict[str, list[MapItem]]) -> list[MapItem] {
    made: list[MapItem] = [];
    for item in items {
        if item.fields.get("classname", "") != "misc_prefab" {
            made.append(item);
            continue;
        }
        held = inner.get(item.fields.get("prefab", ""));
        at = read_vector(item.fields.get("origin", ""));
        if held is None or at is None {
            continue;
        }
        for each in prefab_placed(held, item.fields) {
            made.append(each);
        }
    }
    return made;
}

"""How an instance of a prefab turns and sizes what it stands for: `_scale`
times as large (one number, or three for x, y and z; a negative one
mirrors), and then turned `angle` degrees about the upright. None when it
does neither, or when its size would flatten what it holds."""
def prefab_change(fields: dict[str, str]) -> Linear | None {
    factors = Vec3(x=1.0, y=1.0, z=1.0);
    numbers: list[float] = [];
    for word in fields.get("_scale", "").split() {
        try {
            numbers.append(float(word));
        } except ValueError {
            numbers = [];
            break;
        }
    }
    if len(numbers) == 1 {
        factors = Vec3(x=numbers[0], y=numbers[0], z=numbers[0]);
    } elif len(numbers) >= 3 {
        factors = Vec3(x=numbers[0], y=numbers[1], z=numbers[2]);
    }
    if abs(factors.x * factors.y * factors.z) < 0.000001 {
        return None;
    }
    change = linear_size(factors).followed(linear_turn(0, 1, prefab_yaw(fields)));
    return None if change.idle() else change;
}

"""The degrees an instance is turned about the upright (its `angle`)."""
def prefab_yaw(fields: dict[str, str]) -> float {
    try {
        turned = float(fields.get("angle", "0").strip());
    } except ValueError {
        return 0.0;
    }
    # Up and down are ways for a thing to face, not turns of what it holds.
    return turned if turned >= 0.0 else 0.0;
}

"""A map's entities and brushes carried through a change of the world about
a point, materials staying on their faces; what faces a way faces `yaw`
degrees further round. A brush the change would flatten is left out."""
def map_remapped(items: list[MapItem], pivot: Vec3, change: Linear, yaw: float = 0.0) -> list[MapItem] {
    made: list[MapItem] = [];
    for item in items {
        fields = dict(item.fields);
        stands = read_vector(fields.get("origin", ""));
        if stands is not None {
            fields["origin"] = write_vector(point_remapped(stands, pivot, change));
        }
        if yaw != 0.0 and len(item.brushes) == 0 and fields.get("classname", "") != "worldspawn" {
            try {
                faced = float(fields.get("angle", "0").strip());
            } except ValueError {
                faced = 0.0;
            }
            if faced >= 0.0 {
                fields["angle"] = field_number((faced + yaw) % 360.0);
            }
        }
        brushes: list[list[Side]] = [];
        for sides in item.brushes {
            carried = sides_remapped(sides, pivot, change);
            if len(carried) >= 4 {
                brushes.append(carried);
            }
        }
        made.append(MapItem(fields=fields, brushes=brushes));
    }
    return made;
}

"""A prefab's contents as an instance of it places them: standing with the
middle of the underside on the instance's origin, sized and turned about
that point as the instance says, and then changed as it says (materials,
fields, names). Nothing when the instance has no place or the prefab no
size."""
def prefab_placed(held: list[MapItem], fields: dict[str, str]) -> list[MapItem] {
    at = read_vector(fields.get("origin", ""));
    box = map_box(held);
    if at is None or box is None {
        return [];
    }
    middle = box[0].add(box[1]).scale(0.5);
    moved = map_shifted(held, Vec3(x=at.x - middle.x, y=at.y - middle.y, z=at.z - box[0].z));
    change = prefab_change(fields);
    if change is not None {
        moved = map_remapped(moved, at, change, prefab_yaw(fields));
    }
    return prefab_overridden(moved, fields);
}
