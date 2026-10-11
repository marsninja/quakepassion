"""A change of the world that keeps straight lines straight and one point
where it is: what it makes of each of the three axes says all of it. A turn,
a change of size, a mirroring and a shear are each one, and so is any of
them after another. Brushes go through one side by side, each plane and the
material on it carried along; and a box handle is read here too: what
dragging one of its nine parts to a place asks of what the box is round."""

import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, Mapping }

def:priv settled(value: float) -> float {
    nearest = float(round(value));
    return nearest if abs(value - nearest) < 0.0000001 else value;
}

def:priv settled_vector(vector: Vec3) -> Vec3 {
    return Vec3(x=settled(vector.x), y=settled(vector.y), z=settled(vector.z));
}

"""The unit vector along an axis: 0 is x, 1 is y, anything else z."""
def:priv unit(axis: int) -> Vec3 {
    if axis == 0 {
        return Vec3(x=1.0);
    }
    if axis == 1 {
        return Vec3(y=1.0);
    }
    return Vec3(z=1.0);
}

"""How far a vector reaches along an axis."""
def along_axis(vector: Vec3, axis: int) -> float {
    if axis == 0 {
        return vector.x;
    }
    if axis == 1 {
        return vector.y;
    }
    return vector.z;
}

"""Where the change sends the x, y and z axes."""
obj Linear {
    has x: Vec3 = Vec3(x=1.0),
        y: Vec3 = Vec3(y=1.0),
        z: Vec3 = Vec3(z=1.0);

    """Where a vector goes."""
    def carry(vector: Vec3) -> Vec3 {
        return self.x.scale(vector.x).add(self.y.scale(vector.y)).add(self.z.scale(vector.z));
    }

    """How many times larger a volume comes out (negative when mirrored,
    nothing when the change flattens the world)."""
    def volume -> float {
        return self.x.dot(self.y.cross(self.z));
    }

    """This change and then another, as one."""
    def followed(later: Linear) -> Linear {
        return Linear(x=later.carry(self.x), y=later.carry(self.y), z=later.carry(self.z));
    }

    """What the change makes of a slope: of a plane's normal, or of an axis
    a material is measured along (not yet of unit length). None when the
    change flattens the world."""
    def slopes -> Linear | None {
        size = self.volume();
        if abs(size) < 0.000000001 {
            return None;
        }
        return Linear(
            x=self.y.cross(self.z).scale(1.0 / size),
            y=self.z.cross(self.x).scale(1.0 / size),
            z=self.x.cross(self.y).scale(1.0 / size)
        );
    }

    """The change that undoes this one."""
    def back -> Linear | None {
        rows = self.slopes();
        if rows is None {
            return None;
        }
        return Linear(
            x=Vec3(x=rows.x.x, y=rows.y.x, z=rows.z.x),
            y=Vec3(x=rows.x.y, y=rows.y.y, z=rows.z.y),
            z=Vec3(x=rows.x.z, y=rows.y.z, z=rows.z.z)
        );
    }

    """Whether it changes nothing."""
    def idle -> bool {
        return self.x.sub(Vec3(x=1.0)).length() + self.y.sub(Vec3(y=1.0)).length() + self.z.sub(Vec3(z=1.0)).length()
            < 0.0000001;
    }
}

"""A turn by degrees in the plane of two axes, the first toward the second."""
def linear_turn(first: int, second: int, degrees: float) -> Linear {
    angle = math.radians(degrees);
    made = Linear();
    toward = settled_vector(unit(first).scale(math.cos(angle)).add(unit(second).scale(math.sin(angle))));
    across = settled_vector(unit(second).scale(math.cos(angle)).sub(unit(first).scale(math.sin(angle))));
    for (axis, image) in [(first, toward), (second, across)] {
        if axis == 0 {
            made.x = image;
        } elif axis == 1 {
            made.y = image;
        } else {
            made.z = image;
        }
    }
    return made;
}

"""A change of size by a factor along each axis (a negative one mirrors)."""
def linear_size(factors: Vec3) -> Linear {
    return Linear(x=Vec3(x=factors.x), y=Vec3(y=factors.y), z=Vec3(z=factors.z));
}

"""A shear: every point slides along one axis by `amount` for each unit it
stands out along another."""
def linear_shear(along: int, across: int, amount: float) -> Linear {
    made = Linear();
    if along == across {
        return made;
    }
    leaning = unit(across).add(unit(along).scale(amount));
    if across == 0 {
        made.x = leaning;
    } elif across == 1 {
        made.y = leaning;
    } else {
        made.z = leaning;
    }
    return made;
}

"""A change as nine numbers: what it makes of x, then of y, then of z."""
def linear_text(change: Linear) -> str {
    words: list[str] = [];
    for image in [change.x, change.y, change.z] {
        for value in [image.x, image.y, image.z] {
            words.append(str(int(value)) if value == float(int(value)) else str(round(value, 9)));
        }
    }
    return " ".join(words);
}

"""The change nine numbers say, or None when they are not nine numbers."""
def linear_from(words: list[str]) -> Linear | None {
    if len(words) != 9 {
        return None;
    }
    numbers: list[float] = [];
    for word in words {
        try {
            numbers.append(float(word));
        } except ValueError {
            return None;
        }
    }
    return Linear(
        x=Vec3(x=numbers[0], y=numbers[1], z=numbers[2]),
        y=Vec3(x=numbers[3], y=numbers[4], z=numbers[5]),
        z=Vec3(x=numbers[6], y=numbers[7], z=numbers[8])
    );
}

"""Where a point goes when the world is changed about a pivot."""
def point_remapped(point: Vec3, pivot: Vec3, change: Linear) -> Vec3 {
    return pivot.add(change.carry(point.sub(pivot)));
}

"""A side carried through a change of the world about a pivot, its material
staying where it was on the face. None when the change flattens it."""
def side_remapped(side: Side, pivot: Vec3, change: Linear) -> Side | None {
    slopes = change.slopes();
    if slopes is None {
        return None;
    }
    old = side.plane;
    leaning = slopes.carry(old.normal);
    if leaning.length() < 0.000001 {
        return None;
    }
    normal = settled_vector(leaning.normalized());
    carried = point_remapped(old.normal.scale(old.dist), pivot, change);
    mapping = side.mapping;
    s_after = slopes.carry(mapping.s_axis);
    t_after = slopes.carry(mapping.t_axis);
    s_long = s_after.length();
    t_long = t_after.length();
    laid = mapping;
    if s_long > 0.000001 and t_long > 0.000001 {
        laid = Mapping(
            s_axis=settled_vector(s_after.scale(1.0 / s_long)),
            t_axis=settled_vector(t_after.scale(1.0 / t_long)),
            # What the pivot's own place on the material would otherwise slip by.
            s_shift=mapping.s_shift + (pivot.dot(mapping.s_axis) - pivot.dot(s_after)) / mapping.s_scale,
            t_shift=mapping.t_shift + (pivot.dot(mapping.t_axis) - pivot.dot(t_after)) / mapping.t_scale,
            s_scale=mapping.s_scale / s_long,
            t_scale=mapping.t_scale / t_long,
            rotation=mapping.rotation
        );
    }
    return Side(
        plane=Plane3(normal=normal, dist=settled(normal.dot(carried))),
        material=side.material,
        mapping=laid,
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""A brush's sides carried through a change; none when it flattens them."""
def sides_remapped(sides: list[Side], pivot: Vec3, change: Linear) -> list[Side] {
    made: list[Side] = [];
    for side in sides {
        moved = side_remapped(side, pivot, change);
        if moved is None {
            return [];
        }
        made.append(moved);
    }
    return made;
}

"""What a drag of a box handle asks: a change about a pivot, and then a move."""
obj BoxDrag {
    has change: Linear = Linear(),
        pivot: Vec3 = Vec3(),
        move: Vec3 = Vec3(),
        # What it is called when undone: Move, Turn, Stretch or Shear.
        label: str = "Move";

    def idle -> bool {
        return self.change.idle() and self.move.length() < 0.0000001;
    }
}

"""Where a part of a box handle is, the box seen along the axis that is
neither `across` nor `up`. The parts are numbered three to a row from the
low corner: 4 is the middle, the even ones about it the corners, the odd
ones the middles of the edges."""
def box_part(low: Vec3, high: Vec3, across: int, up: int, part: int) -> Vec3 {
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    return middle.add(unit(across).scale(float(part % 3 - 1) * along_axis(half, across))).add(
        unit(up).scale(float(part // 3 - 1) * along_axis(half, up))
    );
}

"""A factor a drag may size by: never nothing, and never the other way round."""
def:priv sound_factor(wanted: float) -> float {
    return max(0.01, wanted);
}

"""What dragging a part of a box handle to a place asks of what the box is
round.

The middle moves it. A corner turns it about the box's middle and sizes it
alike both ways, so that the corner follows the pointer (`how` "turn": turns
only, in steps of `turn_step` degrees when that is given; "size": sizes
only, each way by its own factor, the far corner staying put). The middle
of an edge, dragged along the edge, shears: the edge slides and the far edge
stays; dragged across it, sizes that way alone (`how` "shear" or "size"
says which, whichever way the drag mostly goes)."""
def box_drag(
    low: Vec3, high: Vec3, across: int, up: int, part: int, toward: Vec3, how: str = "", turn_step: float = 0.0
) -> BoxDrag {
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    wide = along_axis(half, across);
    tall = along_axis(half, up);
    column = part % 3 - 1;
    row = part // 3 - 1;
    reach = toward.sub(middle);
    # The pointer from the box's middle, in the view's own two directions.
    h = along_axis(reach, across);
    v = along_axis(reach, up);
    if column == 0 and row == 0 {
        return BoxDrag(move=unit(across).scale(h).add(unit(up).scale(v)), label="Move");
    }
    if wide < 0.0001 or tall < 0.0001 {
        return BoxDrag();
    }
    grab_h = float(column) * wide;
    grab_v = float(row) * tall;
    far = middle.sub(unit(across).scale(grab_h)).sub(unit(up).scale(grab_v));
    if column != 0 and row != 0 {
        if how == "size" {
            sized = Linear();
            wider = unit(across).scale(sound_factor((h + grab_h) / (2.0 * grab_h)));
            taller = unit(up).scale(sound_factor((v + grab_v) / (2.0 * grab_v)));
            for (axis, image) in [(across, wider), (up, taller)] {
                if axis == 0 {
                    sized.x = image;
                } elif axis == 1 {
                    sized.y = image;
                } else {
                    sized.z = image;
                }
            }
            return BoxDrag(change=sized, pivot=far, label="Stretch");
        }
        if abs(h) + abs(v) < 0.0001 {
            return BoxDrag();
        }
        degrees = math.degrees(math.atan2(v, h) - math.atan2(grab_v, grab_h));
        if turn_step > 0.0 {
            degrees = float(round(degrees / turn_step)) * turn_step;
        }
        turned = linear_turn(across, up, degrees);
        if how == "turn" {
            return BoxDrag(change=turned, pivot=middle, label="Turn");
        }
        grown = sound_factor(math.sqrt(h * h + v * v) / math.sqrt(grab_h * grab_h + grab_v * grab_v));
        both = linear_size(Vec3(x=grown, y=grown, z=grown)).followed(turned);
        return BoxDrag(change=both, pivot=middle, label="Turn" if abs(grown - 1.0) < 0.0001 else "Stretch");
    }
    # An edge's middle: `out` is the way out of the box through it, `run` the way the edge runs.
    out = across if column != 0 else up;
    run = up if column != 0 else across;
    grab = grab_h if column != 0 else grab_v;
    pushed = (h if column != 0 else v) - grab;
    slid = v if column != 0 else h;
    shears = how == "shear" or (how != "size" and abs(slid) > abs(pushed));
    if shears {
        return BoxDrag(change=linear_shear(run, out, slid / (2.0 * grab)), pivot=far, label="Shear");
    }
    one = Linear();
    image = unit(out).scale(sound_factor((pushed + 2.0 * grab) / (2.0 * grab)));
    if out == 0 {
        one.x = image;
    } elif out == 1 {
        one.y = image;
    } else {
        one.z = image;
    }
    return BoxDrag(change=one, pivot=far, label="Stretch");
}
