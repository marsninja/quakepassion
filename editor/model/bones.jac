"""The arithmetic of bones. A bone carries some of a part's points, each by
a weight between nothing and all: when the bone turns or moves, a point goes
that share of the way with it. Two bones may carry one point between them.
Between two frames posed by hand, the frames between are spread evenly; and
a point is shown in its bones' colours, mixed as its weights are."""

import math;
import from engine.math.vec3 { Vec3 }

"""A vector turned about a unit axis by an angle in radians."""
def:priv swung(vector: Vec3, axis: Vec3, angle: float) -> Vec3 {
    cosine = math.cos(angle);
    sine = math.sin(angle);
    return vector.scale(cosine).add(axis.cross(vector).scale(sine)).add(axis.scale(axis.dot(vector) * (1.0 - cosine)));
}

"""A point turned about the line through a pivot along an axis, by degrees."""
def point_swung(point: Vec3, pivot: Vec3, axis: Vec3, degrees: float) -> Vec3 {
    long = axis.length();
    if long < 0.000001 {
        return point;
    }
    return pivot.add(swung(point.sub(pivot), axis.scale(1.0 / long), math.radians(degrees)));
}

"""Points with those a bone carries turned about a pivot, each by its share:
a point carried wholly goes all the way round, one carried by half goes half
the way toward where that would take it."""
def points_swung(
    points: list[Vec3], held: list[int], weights: list[float], pivot: Vec3, axis: Vec3, degrees: float
) -> list[Vec3] {
    made = list(points);
    for (place, index) in enumerate(held) {
        if index < 0 or index >= len(made) {
            continue;
        }
        share = weights[place] if place < len(weights) else 1.0;
        gone = point_swung(made[index], pivot, axis, degrees).sub(made[index]);
        made[index] = made[index].add(gone.scale(share));
    }
    return made;
}

"""Points with those a bone carries moved, each by its share of the move."""
def points_carried(points: list[Vec3], held: list[int], weights: list[float], delta: Vec3) -> list[Vec3] {
    made = list(points);
    for (place, index) in enumerate(held) {
        if index < 0 or index >= len(made) {
            continue;
        }
        made[index] = made[index].add(delta.scale(weights[place] if place < len(weights) else 1.0));
    }
    return made;
}

"""What a bone carries with some points added at a weight (a point it
already carries takes the new weight): [points, weights], the points in order."""
def grip_with(held: list[int], weights: list[float], more: list[int], weight: float) -> tuple[list[int], list[float]] {
    share = max(0.0, min(1.0, weight));
    kept: dict[int, float] = {};
    for (place, index) in enumerate(held) {
        kept[index] = weights[place] if place < len(weights) else 1.0;
    }
    for index in more {
        if index >= 0 {
            kept[index] = share;
        }
    }
    order = sorted([index for index in kept.keys() if kept[index] > 0.0]);
    return (order, [kept[index] for index in order]);
}

"""What a bone carries with some points let go."""
def grip_without(held: list[int], weights: list[float], fewer: list[int]) -> tuple[list[int], list[float]] {
    order: list[int] = [];
    shares: list[float] = [];
    for (place, index) in enumerate(held) {
        if index not in fewer {
            order.append(index);
            shares.append(weights[place] if place < len(weights) else 1.0);
        }
    }
    return (order, shares);
}

"""How much of a point a bone carries (nothing when it does not)."""
def grip_share(held: list[int], weights: list[float], point: int) -> float {
    for (place, index) in enumerate(held) {
        if index == point {
            return weights[place] if place < len(weights) else 1.0;
        }
    }
    return 0.0;
}

"""The weights other bones may keep of a point once one bone takes so much of
it: as they were when all still fit in one whole, else each cut down alike."""
def shares_beside(taken: float, others: list[float]) -> list[float] {
    room = max(0.0, 1.0 - max(0.0, min(1.0, taken)));
    total = 0.0;
    for share in others {
        total += max(0.0, share);
    }
    if total <= room + 0.000001 {
        return [max(0.0, share) for share in others];
    }
    return [max(0.0, share) * room / total for share in others];
}

"""How far a point is from the stretch between a bone's two ends."""
def bone_distance(head: Vec3, tail: Vec3, point: Vec3) -> float {
    along = tail.sub(head);
    long = along.dot(along);
    if long < 0.000001 {
        return point.sub(head).length();
    }
    part = max(0.0, min(1.0, point.sub(head).dot(along) / long));
    return point.sub(head.add(along.scale(part))).length();
}

"""Which bone each point is nearest: an index into the bones for each point
(-1 when there are no bones)."""
def nearest_bones(heads: list[Vec3], tails: list[Vec3], points: list[Vec3]) -> list[int] {
    found: list[int] = [];
    for point in points {
        best = -1;
        least = 0.0;
        for index in range(min(len(heads), len(tails))) {
            away = bone_distance(heads[index], tails[index], point);
            if best < 0 or away < least - 0.000001 {
                best = index;
                least = away;
            }
        }
        found.append(best);
    }
    return found;
}

"""Frames spread between two: every frame after `first` and before `last`
has the points named (all of them when none are) set evenly on the way from
where they stand at `first` to where they stand at `last`. The frames as
they are when the two are not apart, or do not have the same points."""
def frames_spread(poses: list[list[Vec3]], first: int, last: int, only: list[int] = []) -> list[list[Vec3]] {
    made = [list(pose) for pose in poses];
    if first < 0 or last >= len(poses) or last - first < 2 or len(poses[first]) != len(poses[last]) {
        return made;
    }
    wanted = only if len(only) > 0 else list(range(len(poses[first])));
    for frame in range(first + 1, last) {
        if len(made[frame]) != len(poses[first]) {
            continue;
        }
        part = float(frame - first) / float(last - first);
        for index in wanted {
            if index >= 0 and index < len(made[frame]) {
                made[frame][index] = poses[first][index].lerp(poses[last][index], part);
            }
        }
    }
    return made;
}

"""A colour mixed from several by weights, what the weights leave of one
whole going to `plain`. Colours are 0xRRGGBB."""
def tint_mixed(tints: list[int], weights: list[float], plain: int) -> int {
    red = 0.0;
    green = 0.0;
    blue = 0.0;
    total = 0.0;
    for (place, tint) in enumerate(tints) {
        share = max(0.0, weights[place] if place < len(weights) else 0.0);
        red += float((tint >> 16) & 255) * share;
        green += float((tint >> 8) & 255) * share;
        blue += float(tint & 255) * share;
        total += share;
    }
    if total > 1.0 {
        red /= total;
        green /= total;
        blue /= total;
        total = 1.0;
    }
    rest = 1.0 - total;
    red += float((plain >> 16) & 255) * rest;
    green += float((plain >> 8) & 255) * rest;
    blue += float(plain & 255) * rest;
    return (min(255, int(round(red))) << 16) | (min(255, int(round(green))) << 8) | min(255, int(round(blue)));
}

"""Colours to tell bones apart, one after another."""
glob BONE_TINTS: list[int] = [0xffc94d, 0x5b8def, 0xe5484d, 0x4cc38a, 0xc76bff, 0xff8a3d, 0x3dd6d0, 0xf06bb0];
