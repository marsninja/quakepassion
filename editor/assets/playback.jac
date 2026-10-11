"""A model's frames played: which frame comes next within a range, the
frame between two frames, the edges of the triangles that face the eye, and
a box as a mesh, to keep a model's bounds as a part of it."""

import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel }
import from ..model.mesh { Mesh }

"""The frame after one when frames from `first` to `last` are played: on
round to `first` when it loops, else staying on `last`. A range that is the
wrong way round, or outside the model, is the whole model."""
def frame_after(frame: int, first: int, last: int, count: int, loops: bool = True) -> int {
    if count <= 0 {
        return 0;
    }
    low = first;
    high = last if last >= 0 else count - 1;
    if low < 0 or high >= count or low > high {
        low = 0;
        high = count - 1;
    }
    if frame < low or frame > high {
        return low;
    }
    if frame == high {
        return low if loops else high;
    }
    return frame + 1;
}

"""The edges part of the way from one frame's to the next's. The first
frame's own when the two do not have the same edges."""
def edges_between(first: list[list[Vec3]], second: list[list[Vec3]], share: float) -> list[list[Vec3]] {
    if len(first) != len(second) or share <= 0.0 {
        return first;
    }
    part = min(1.0, share);
    return [[first[index][0].lerp(second[index][0], part), first[index][1].lerp(second[index][1], part)] for index in range(len(first))];
}

"""The edges, each once, of the triangles of a model's frame that face an
eye: the games wind a triangle clockwise as seen from outside."""
def facing_edges(model: AnimatedModel, frame: int, eye: Vec3) -> list[list[Vec3]] {
    found: list[list[Vec3]] = [];
    for surface in model.surfaces {
        if len(surface.frames) == 0 {
            continue;
        }
        points = surface.frames[max(0, min(frame, len(surface.frames) - 1))].vertices;
        seen: dict[int, bool] = {};
        count = len(points);
        for t in range(len(surface.indices) // 3) {
            a = surface.indices[t * 3];
            b = surface.indices[t * 3 + 1];
            c = surface.indices[t * 3 + 2];
            if min(a, min(b, c)) < 0 or max(a, max(b, c)) >= count {
                continue;
            }
            outward = points[c].sub(points[a]).cross(points[b].sub(points[a]));
            if outward.dot(eye.sub(points[a])) <= 0.0 {
                continue;
            }
            for (near, far) in [(a, b), (b, c), (c, a)] {
                key = min(near, far) * count + max(near, far);
                if key not in seen {
                    seen[key] = True;
                    found.append([points[near], points[far]]);
                }
            }
        }
    }
    return found;
}

"""The eight corners of a box, in the order `box_mesh` has them."""
def box_corners(low: Vec3, high: Vec3) -> list[Vec3] {
    return [
        Vec3(x=low.x, y=low.y, z=low.z), Vec3(x=high.x, y=low.y, z=low.z), Vec3(x=high.x, y=high.y, z=low.z),
        Vec3(x=low.x, y=high.y, z=low.z), Vec3(x=low.x, y=low.y, z=high.z), Vec3(x=high.x, y=low.y, z=high.z),
        Vec3(x=high.x, y=high.y, z=high.z), Vec3(x=low.x, y=high.y, z=high.z)
    ];
}

"""A box as a closed mesh of twelve triangles, facing outward as the
editor's meshes do."""
def box_mesh(low: Vec3, high: Vec3) -> Mesh {
    made = Mesh(points=box_corners(low, high));
    for point in made.points {
        made.uvs.append((point.x - low.x) / max(0.001, high.x - low.x));
        made.uvs.append((point.z - low.z) / max(0.001, high.z - low.z));
    }
    made.corners = [
        0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7
    ];
    return made;
}

"""What a Quake III body's sequences are called, by their numbers in its
animation.cfg: six of the whole body, seven of the torso, twelve of the legs."""
glob SEQUENCES: list[str] = [
    "death1", "dead1", "death2", "dead2", "death3", "dead3", "gesture", "attack", "attack2", "drop", "raise", "stand",
    "stand2", "walkcr", "walk", "run", "back", "swim", "jump", "land", "jumpb", "landb", "idle", "idlecr", "turn"
];

"""How a part of a body plays a sequence of its animation.cfg, whose rows
are [first, count, looping, fps]: [first frame, last frame, frames a
second, 1 when it plays round]. The legs' file has none of the torso's own
frames, so the legs' sequences begin that many sooner. None for a sequence
the part does not play."""
def sequence_range(rows: list[list[float]], number: int, legs: bool) -> list[float] | None {
    if len(rows) < 25 or number < 0 or number >= 25 {
        return None;
    }
    if (legs and number >= 6 and number < 13) or (not legs and number >= 13) {
        return None;
    }
    first = rows[number][0];
    if number >= 13 {
        first -= rows[13][0] - rows[6][0];
    }
    count = max(1.0, abs(rows[number][1]));
    return [first, first + count - 1.0, rows[number][3] if rows[number][3] > 0.0 else 10.0, 1.0 if rows[number][2] != 0.0 else 0.0];
}

"""How far from one frame to the next is drawn, when only so many frames
are drawn between the two (none asked: wherever it has got to)."""
def share_stepped(share: float, between: int) -> float {
    if between <= 0 {
        return share;
    }
    return float(int(max(0.0, min(1.0, share)) * float(between + 1))) / float(between + 1);
}

"""The box round some points: [low, high]."""
def box_round(points: list[Vec3]) -> list[Vec3] {
    if len(points) == 0 {
        return [Vec3(), Vec3()];
    }
    low = points[0];
    high = points[0];
    for point in points {
        low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
        high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
    }
    return [low, high];
}
