"""The model editor's marks and handles, with nothing drawn: the lines a
mark on a point is made of, in each of the ways it may be drawn; where the
three handles of what is picked stand; and what is left of a drag when the
model's axes are locked or one handle is pulled."""

import from engine.math.vec3 { Vec3 }

"""The ways a mark may be drawn."""
glob MARK_STYLES: list[str] = ["cross", "box", "diamond"];

"""The lines of a mark at a point, reaching so far from it: a cross along
the three axes, the edges of a box about it, or of a diamond with a corner
on each axis. A style that is none of them is a cross."""
def mark_lines(at: Vec3, reach: float, style: str = "cross") -> list[list[Vec3]] {
    lines: list[list[Vec3]] = [];
    if style == "box" {
        signs = [-1.0, 1.0];
        for a in signs {
            for b in signs {
                lines.append([at.add(Vec3(x=-reach, y=a * reach, z=b * reach)), at.add(Vec3(x=reach, y=a * reach, z=b * reach))]);
                lines.append([at.add(Vec3(x=a * reach, y=-reach, z=b * reach)), at.add(Vec3(x=a * reach, y=reach, z=b * reach))]);
                lines.append([at.add(Vec3(x=a * reach, y=b * reach, z=-reach)), at.add(Vec3(x=a * reach, y=b * reach, z=reach))]);
            }
        }
        return lines;
    }
    tips = [Vec3(x=reach), Vec3(y=reach), Vec3(z=reach)];
    if style == "diamond" {
        # Each corner to the four that are not across from it.
        for first in range(3) {
            for second in range(first + 1, 3) {
                for a in [-1.0, 1.0] {
                    for b in [-1.0, 1.0] {
                        lines.append([at.add(tips[first].scale(a)), at.add(tips[second].scale(b))]);
                    }
                }
            }
        }
        return lines;
    }
    for tip in tips {
        lines.append([at.sub(tip), at.add(tip)]);
    }
    return lines;
}

"""The middle of the picked points (the origin when none is picked)."""
def picks_middle(points: list[Vec3], picks: list[int]) -> Vec3 {
    total = Vec3();
    count = 0;
    for index in picks {
        if index >= 0 and index < len(points) {
            total = total.add(points[index]);
            count += 1;
        }
    }
    return total.scale(1.0 / float(count)) if count > 0 else Vec3();
}

"""Where the three handles stand: so far from the middle along x, y and z."""
def handle_tips(middle: Vec3, reach: float) -> list[Vec3] {
    return [middle.add(Vec3(x=reach)), middle.add(Vec3(y=reach)), middle.add(Vec3(z=reach))];
}

"""A drag as one handle takes it: only what of it runs along that handle's
axis (0 x, 1 y, 2 z; any other axis leaves it whole)."""
def drag_along(moved: Vec3, axis: int) -> Vec3 {
    if axis == 0 {
        return Vec3(x=moved.x);
    }
    if axis == 1 {
        return Vec3(y=moved.y);
    }
    if axis == 2 {
        return Vec3(z=moved.z);
    }
    return moved;
}

"""A drag with some axes locked: `locked` names them ("x", "yz", ...), and
nothing moves along a locked axis."""
def drag_kept(moved: Vec3, locked: str) -> Vec3 {
    held = locked.lower();
    return Vec3(x=0.0 if "x" in held else moved.x, y=0.0 if "y" in held else moved.y, z=0.0 if "z" in held else moved.z);
}

"""The axes a word locks, in order and each once: "zx" is "xz", and a word
of anything else ("off", "none") locks nothing."""
def locked_axes(word: str) -> str {
    said = word.lower();
    for letter in said {
        if letter not in "xyz" {
            return "";
        }
    }
    return "".join([axis for axis in ["x", "y", "z"] if axis in said]);
}

"""The colours a part's points carry once a tool has remade them: a point
that is where it was keeps its own, and one the tool made, or moved up the
list, takes the colour of the nearest point there was. `tints` has one
colour a point (below zero for a point with none), or nothing when the part
has no colours, and then it still has none."""
def tints_carried(before: list[Vec3], tints: list[int], after: list[Vec3]) -> list[int] {
    if len(tints) == 0 or len(before) == 0 {
        return [];
    }
    carried: list[int] = [];
    for (index, point) in enumerate(after) {
        if index < len(before) and index < len(tints) and before[index].sub(point).length() < 0.0001 {
            carried.append(tints[index]);
            continue;
        }
        nearest = -1;
        least = 0.0;
        for (other, was) in enumerate(before) {
            away = was.sub(point).length();
            if other < len(tints) and (nearest < 0 or away < least) {
                nearest = other;
                least = away;
            }
        }
        carried.append(tints[nearest] if nearest >= 0 else -1);
    }
    return carried;
}

"""A colour as six letters of sixteen ("ff8800"), or "none" below zero."""
def tint_word(tint: int) -> str {
    if tint < 0 {
        return "none";
    }
    digits = "0123456789abcdef";
    word = "";
    for place in range(6) {
        word = digits[(tint >> (4 * place)) & 15] + word;
    }
    return word;
}

"""The colour such a word names (with or without a # before it): below zero
when it names none."""
def word_tint(word: str) -> int {
    letters = word.strip().lower().lstrip("#");
    if len(letters) != 6 {
        return -1;
    }
    value = 0;
    for letter in letters {
        at = "0123456789abcdef".find(letter);
        if at < 0 {
            return -1;
        }
        value = value * 16 + at;
    }
    return value;
}

"""How bright a face is drawn when the model is drawn solid: lit from above
and a little to one side, and never dark, so that a face turned away from
the light can still be made out. From 0.35 to 1."""
def face_light(normal: Vec3) -> float {
    toward = Vec3(x=0.38, y=0.28, z=0.88);
    return 0.35 + 0.65 * max(0.0, normal.dot(toward) / toward.length());
}
