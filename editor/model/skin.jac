"""A model's skin: where each point of a part lies on its picture, and the
picture itself. A point's place is two numbers from 0 to 1, across and down
the picture; the tools here move, stretch, turn and flip the places of the
picked points, lay a part flat onto its skin by looking along an axis, and
paint the picture, on the skin or through the model."""
import math;
import struct;
import from engine.math.vec3 { Vec3 }
import from .mesh { Mesh, ray_meets }
import from .pattern { pattern_covers }

"""The box round the places of some points: [u low, v low, u high, v high]
(all of them when none are named; a square of nothing when there are none)."""
def places_box(uvs: list[float], picks: list[int]) -> list[float] {
    chosen = picks if len(picks) > 0 else list(range(len(uvs) // 2));
    box = [1000000.0, 1000000.0, -1000000.0, -1000000.0];
    for at in chosen {
        if at >= 0 and at * 2 + 1 < len(uvs) {
            box[0] = min(box[0], uvs[at * 2]);
            box[1] = min(box[1], uvs[at * 2 + 1]);
            box[2] = max(box[2], uvs[at * 2]);
            box[3] = max(box[3], uvs[at * 2 + 1]);
        }
    }
    return box if box[0] <= box[2] else [0.0, 0.0, 0.0, 0.0];
}

"""The places of some points moved across and down."""
def places_moved(uvs: list[float], picks: list[int], across: float, down: float) -> list[float] {
    made = list(uvs);
    for at in (picks if len(picks) > 0 else list(range(len(uvs) // 2))) {
        if at >= 0 and at * 2 + 1 < len(made) {
            made[at * 2] += across;
            made[at * 2 + 1] += down;
        }
    }
    return made;
}

"""The places of some points stretched about the middle of their box."""
def places_scaled(uvs: list[float], picks: list[int], across: float, down: float) -> list[float] {
    made = list(uvs);
    box = places_box(uvs, picks);
    middle_u = (box[0] + box[2]) * 0.5;
    middle_v = (box[1] + box[3]) * 0.5;
    for at in (picks if len(picks) > 0 else list(range(len(uvs) // 2))) {
        if at >= 0 and at * 2 + 1 < len(made) {
            made[at * 2] = middle_u + (made[at * 2] - middle_u) * across;
            made[at * 2 + 1] = middle_v + (made[at * 2 + 1] - middle_v) * down;
        }
    }
    return made;
}

"""The places of some points turned about the middle of their box."""
def places_turned(uvs: list[float], picks: list[int], degrees: float) -> list[float] {
    made = list(uvs);
    box = places_box(uvs, picks);
    middle_u = (box[0] + box[2]) * 0.5;
    middle_v = (box[1] + box[3]) * 0.5;
    cosine = math.cos(math.radians(degrees));
    sine = math.sin(math.radians(degrees));
    for at in (picks if len(picks) > 0 else list(range(len(uvs) // 2))) {
        if at >= 0 and at * 2 + 1 < len(made) {
            du = made[at * 2] - middle_u;
            dv = made[at * 2 + 1] - middle_v;
            made[at * 2] = middle_u + du * cosine - dv * sine;
            made[at * 2 + 1] = middle_v + du * sine + dv * cosine;
        }
    }
    return made;
}

"""The places of some points mirrored within their box: across (`"u"`) or
down (`"v"`)."""
def places_flipped(uvs: list[float], picks: list[int], way: str) -> list[float] {
    made = list(uvs);
    box = places_box(uvs, picks);
    for at in (picks if len(picks) > 0 else list(range(len(uvs) // 2))) {
        if at >= 0 and at * 2 + 1 < len(made) {
            if way == "u" {
                made[at * 2] = box[0] + box[2] - made[at * 2];
            } elif way == "v" {
                made[at * 2 + 1] = box[1] + box[3] - made[at * 2 + 1];
            }
        }
    }
    return made;
}

"""The picked points laid flat on the skin by looking along an axis (0 x,
1 y, 2 z): what is seen from there fills a rectangle of the skin, [u low,
v low, u high, v high], the right way up."""
def places_projected(mesh: Mesh, picks: list[int], axis: int, onto: list[float] = [0.0, 0.0, 1.0, 1.0]) -> list[float] {
    made = list(mesh.uvs) if len(mesh.uvs) == len(mesh.points) * 2 else [0.0 for index in range(len(mesh.points) * 2)];
    chosen = picks if len(picks) > 0 else list(range(len(mesh.points)));
    flat: list[tuple[float, float]] = [];
    for at in chosen {
        point = mesh.points[at];
        # Across the view and up it, seen from the far end of the axis.
        if axis == 0 {
            flat.append((point.y, point.z));
        } elif axis == 1 {
            flat.append((point.x, point.z));
        } else {
            flat.append((point.x, point.y));
        }
    }
    if len(flat) == 0 {
        return made;
    }
    low_a = flat[0][0];
    high_a = flat[0][0];
    low_b = flat[0][1];
    high_b = flat[0][1];
    for spot in flat {
        low_a = min(low_a, spot[0]);
        high_a = max(high_a, spot[0]);
        low_b = min(low_b, spot[1]);
        high_b = max(high_b, spot[1]);
    }
    wide = max(0.0001, high_a - low_a);
    tall = max(0.0001, high_b - low_b);
    for (index, at) in enumerate(chosen) {
        made[at * 2] = onto[0] + (flat[index][0] - low_a) / wide * (onto[2] - onto[0]);
        # Up the view is up the picture: its rows run down.
        made[at * 2 + 1] = onto[3] - (flat[index][1] - low_b) / tall * (onto[3] - onto[1]);
    }
    return made;
}

"""A picture to paint on: four numbers a texel, red, green, blue and how
solid, row by row from the top."""
obj Skin {
    has width: int = 64,
        height: int = 64,
        texels: bytearray = bytearray();

    """The colour at a texel: [red, green, blue, solid]."""
    def at(x: int, y: int) -> list[int] {
        if x < 0 or y < 0 or x >= self.width or y >= self.height {
            return [0, 0, 0, 0];
        }
        base = (y * self.width + x) * 4;
        return [int(self.texels[base]), int(self.texels[base + 1]), int(self.texels[base + 2]), int(self.texels[base + 3])];
    }
}

"""A skin of one colour."""
def skin_filled(width: int, height: int, color: list[int]) -> Skin {
    made = Skin(width=max(1, width), height=max(1, height));
    made.texels = bytearray(made.width * made.height * 4);
    for index in range(made.width * made.height) {
        made.texels[index * 4] = color[0];
        made.texels[index * 4 + 1] = color[1];
        made.texels[index * 4 + 2] = color[2];
        made.texels[index * 4 + 3] = color[3] if len(color) > 3 else 255;
    }
    return made;
}

"""Paint a dab on a skin at a place on it: a disc of so many texels, solid
to its edge, or with `soft` strongest at its middle and fading to nothing
(an airbrush). `strength` from 0 to 1 is how much of the colour is laid,
and a `pattern` lays it only on the texels that pattern covers.
Answers how many texels it touched."""
def skin_dab(
    skin: Skin, u: float, v: float, radius: float, color: list[int], soft: bool = False, strength: float = 1.0,
    pattern: str = "solid", grain: int = 4
) -> int {
    middle_x = u * float(skin.width);
    middle_y = v * float(skin.height);
    reach = max(0.5, radius);
    touched = 0;
    for y in range(max(0, int(middle_y - reach)), min(skin.height, int(middle_y + reach) + 1)) {
        for x in range(max(0, int(middle_x - reach)), min(skin.width, int(middle_x + reach) + 1)) {
            away = math.sqrt((float(x) + 0.5 - middle_x) * (float(x) + 0.5 - middle_x) + (float(y) + 0.5 - middle_y) * (float(y) + 0.5 - middle_y));
            if away > reach or not pattern_covers(pattern, x, y, grain) {
                continue;
            }
            share = strength * (1.0 - away / reach if soft else 1.0);
            base = (y * skin.width + x) * 4;
            for k in range(3) {
                skin.texels[base + k] = int(round(float(skin.texels[base + k]) * (1.0 - share) + float(color[k]) * share));
            }
            skin.texels[base + 3] = 255;
            touched += 1;
        }
    }
    return touched;
}

"""The colour at a place on a skin: [red, green, blue], for taking up a
colour that is already painted there."""
def skin_colour(skin: Skin, u: float, v: float) -> list[int] {
    found = skin.at(
        max(0, min(skin.width - 1, int(u * float(skin.width)))), max(0, min(skin.height - 1, int(v * float(skin.height))))
    );
    return [found[0], found[1], found[2]];
}

"""Where on its skin a line of sight meets a mesh: [u, v], or none when it
misses or the mesh has no skin laid on it. For painting through the model."""
def place_under(mesh: Mesh, start: Vec3, along: Vec3) -> list[float] | None {
    if len(mesh.uvs) != len(mesh.points) * 2 {
        return None;
    }
    best = -1;
    nearest = 1000000000.0;
    for index in range(mesh.triangles()) {
        spots = mesh.triangle(index);
        reach = ray_meets(start, along, spots[0], spots[1], spots[2]);
        if reach > 0.0 and reach < nearest and mesh.normal(index).dot(along) < 0.0 {
            nearest = reach;
            best = index;
        }
    }
    if best < 0 {
        return None;
    }
    # How much of each corner the place is: by the areas it cuts the triangle into.
    hit = start.add(along.scale(nearest));
    corners = [mesh.corners[best * 3], mesh.corners[best * 3 + 1], mesh.corners[best * 3 + 2]];
    spots = mesh.triangle(best);
    whole = spots[1].sub(spots[0]).cross(spots[2].sub(spots[0])).length();
    if whole < 0.0000001 {
        return None;
    }
    first = spots[1].sub(hit).cross(spots[2].sub(hit)).length() / whole;
    second = spots[2].sub(hit).cross(spots[0].sub(hit)).length() / whole;
    third = max(0.0, 1.0 - first - second);
    return [
        mesh.uvs[corners[0] * 2] * first + mesh.uvs[corners[1] * 2] * second + mesh.uvs[corners[2] * 2] * third,
        mesh.uvs[corners[0] * 2 + 1] * first + mesh.uvs[corners[1] * 2 + 1] * second + mesh.uvs[corners[2] * 2 + 1] * third
    ];
}

"""The skin as a TGA file: uncompressed, 32 bits a texel, top row first."""
def skin_tga(skin: Skin) -> bytes {
    out = bytearray();
    # No name, no palette, a true-colour picture; its origin at the top left.
    out.extend(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, skin.width, skin.height, 32, 0x28));
    for index in range(skin.width * skin.height) {
        base = index * 4;
        out.extend(bytes([skin.texels[base + 2], skin.texels[base + 1], skin.texels[base], skin.texels[base + 3]]));
    }
    return bytes(out);
}

"""A skin from an uncompressed TGA of 24 or 32 bits, or none."""
def tga_skin(data: bytes) -> Skin | None {
    if len(data) < 18 or data[2] != 2 or data[16] not in [24, 32] {
        return None;
    }
    width = int(struct.unpack("<H", data[12:14])[0]);
    height = int(struct.unpack("<H", data[14:16])[0]);
    step = int(data[16]) // 8;
    start = 18 + int(data[0]);
    if width < 1 or height < 1 or len(data) < start + width * height * step {
        return None;
    }
    made = Skin(width=width, height=height);
    made.texels = bytearray(width * height * 4);
    top_first = int(data[17]) & 0x20 != 0;
    for y in range(height) {
        row = y if top_first else height - 1 - y;
        for x in range(width) {
            source = start + (row * width + x) * step;
            base = (y * width + x) * 4;
            made.texels[base] = data[source + 2];
            made.texels[base + 1] = data[source + 1];
            made.texels[base + 2] = data[source];
            made.texels[base + 3] = data[source + 3] if step == 4 else 255;
        }
    }
    return made;
}
