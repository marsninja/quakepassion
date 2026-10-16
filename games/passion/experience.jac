"""The experience a level stages: approaches, encounters, firing positions
and rewards connected to the rooms and passages that realise the mission.

These are generation-time nodes. The cast records what it actually placed
on them; the critic visits them instead of inferring pacing from room size.
"""
import math;
import from .arrange { Estate, Encloses, Corridor, estate_spaces }
import from .spaces { Space, Doorway }
import from .massing { Massing, CELL, LIFT }
import from editor.geometry.brush { Side }

glob QUIET_ROLES: list[str] = ["start", "recovery", "vista", "cache", "goal"];

node Experience {
    has expects_returns: bool = False;
}

node Encounter {
    has room: int,
        order: int,
        pattern: str,
        quiet: bool = False,
        optional: bool = False,
        approach: list[float] = [],
        foes: int = 0,
        enemy_health: int = 0,
        threat: float = 0.0,
        health_before: float = 100.0,
        health_ready: float = 100.0,
        health_after: float = 100.0,
        health_added: float = 0.0,
        ammo_needed: int = 0,
        ammo_ready: int = 0,
        weapon: str = "",
        issues: list[str] = [];
}

node CombatPosition {
    has point: list[float],
        role: str,
        foe: str,
        sees_entry: bool = False,
        cover: int = 0;
}

node Reward {
    has point: list[float],
        kind: str,
        source: str,
        amount: int,
        before_fight: bool = True;
}

edge Stages: Experience --> Encounter {}
edge InRoom: Encounter --> Space {}
edge HoldsPosition: Encounter --> CombatPosition {}
edge Supplies: Encounter --> Reward {}
edge Crossfire: CombatPosition --> CombatPosition {}

def encounters(experience: Experience) -> list[Encounter] {
    found = [experience->:Stages:->][?:Encounter];
    return sorted(found, key=lambda (e: Encounter) { (e.order, e.room); });
}

def stage_point(space: Space) -> list[float] {
    return [
        (float(space.stage[0]) + 0.5) * CELL,
        (float(space.stage[1]) + 0.5) * CELL,
        float(space.stage[2]) * LIFT + 24.0
    ];
}

"""The floor inside a doorway, two cells back from the threshold."""
def approach_point(space: Space, door: Doorway) -> list[float] {
    x = float(space.x) + float(space.w) * 0.5;
    y = float(space.y) + float(space.d) * 0.5;
    if door.side < 2 {
        x = float(space.x + space.w - 2 if door.side == 0 else space.x + 1) + 0.5;
        y = float(space.y + door.along) + float(door.span) * 0.5;
    } else {
        y = float(space.y + space.d - 2 if door.side == 2 else space.y + 1) + 0.5;
        x = float(space.x + door.along) + float(door.span) * 0.5;
    }
    return [x * CELL, y * CELL, float(door.level) * LIFT + 24.0];
}

"""Sight through structural geometry, sampled every eight world units.
Points are hull origins; eye height is added here. Exact dressing boxes
also block sight, including rails thinner than the structural samples.
"""
def clear_sight(
    mass: Massing, a: list[float], b: list[float], details: list[list[float]] = []
) -> bool {
    dx = b[0] - a[0];
    dy = b[1] - a[1];
    dz = b[2] - a[2];
    steps = max(1, int(math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / 8.0)));
    for index in range(steps + 1) {
        t = float(index) / float(steps);
        if not mass.air(
            int(math.floor((a[0] + dx * t) / CELL)),
            int(math.floor((a[1] + dy * t) / CELL)),
            int(math.floor((a[2] + dz * t + 22.0) / LIFT))
        ) {
            return False;
        }
    }
    for box in details {
        low = 0.0;
        high = 1.0;
        for axis in range(3) {
            origin = a[axis] + (22.0 if axis == 2 else 0.0);
            delta = b[axis] - a[axis];
            if abs(delta) < 0.00001 {
                if origin < box[axis] or origin > box[axis + 3] {
                    high = -1.0;
                    break;
                }
            } else {
                one = (box[axis] - origin) / delta;
                two = (box[axis + 3] - origin) / delta;
                low = max(low, min(one, two));
                high = min(high, max(one, two));
            }
        }
        if low <= high {
            return False;
        }
    }
    return True;
}

"""Exact boxes for the dressing's axis-aligned solid brushes. Liquids do
not block a shot. Keeping these separate from the coarse massing preserves
the thin rails and pilasters that matter to collision and visibility."""
def detail_boxes(brushes: list[list[Side]]) -> list[list[float]] {
    found: list[list[float]] = [];
    for brush in brushes {
        if not brush or brush[0].contents in [8, 16, 32] {
            continue;
        }
        box = [-1000000.0, -1000000.0, -1000000.0, 1000000.0, 1000000.0, 1000000.0];
        for side in brush {
            normal = side.plane.normal;
            for (axis, component) in enumerate([normal.x, normal.y, normal.z]) {
                if component > 0.99 {
                    box[axis + 3] = min(box[axis + 3], side.plane.dist);
                } elif component < -0.99 {
                    box[axis] = max(box[axis], -side.plane.dist);
                }
            }
        }
        found.append(box);
    }
    return found;
}

def body_clear(point: list[float], details: list[list[float]]) -> bool {
    low = [point[0] - 16.0, point[1] - 16.0, point[2] - 24.0];
    high = [point[0] + 16.0, point[1] + 16.0, point[2] + 32.0];
    return not any(
        [
            all(
                [
                    low[axis] < box[axis + 3] - 0.1 and high[axis] > box[axis] + 0.1
                    for axis in range(3)
                ]
            ) for box in details
        ]
    );
}

def settle_approach(
    space: Space, point: list[float], mass: Massing, details: list[list[float]]
) -> list[float] {
    cx = int(math.floor(point[0] / CELL));
    cy = int(math.floor(point[1] / CELL));
    cz = int(round((point[2] - 24.0) / LIFT));
    best = stage_point(space);
    score = 1000000.0;
    for dz in [-1, 0, 1] {
        for dy in range(-3, 4) {
            for dx in range(-3, 4) {
                x = cx + dx;
                y = cy + dy;
                z = cz + dz;
                if mass.at(x, y, z) != space.id + 1
                    or not mass.standing(x, y, z)
                    or mass.headroom(x, y, z) < 5 {
                    continue;
                }
                candidate = [
                    (float(x) + 0.5) * CELL,
                    (float(y) + 0.5) * CELL,
                    float(z) * LIFT + 24.0
                ];
                distance = abs(candidate[0] - point[0])
                    + abs(candidate[1] - point[1])
                    + abs(candidate[2] - point[2]);
                if distance < score and body_clear(candidate, details) {
                    score = distance;
                    best = candidate;
                }
            }
        }
    }
    return best;
}

"""Nearby structural cover at standing eye height, rather than a nearby
wall at foot height or an unsupported decorative prop."""
def cover_at(mass: Massing, point: list[float]) -> int {
    cx = int(math.floor(point[0] / CELL));
    cy = int(math.floor(point[1] / CELL));
    cz = int(math.floor((point[2] + 22.0) / LIFT));
    count = 0;
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        if any(
            [
                not mass.air(cx + dx * distance, cy + dy * distance, cz)
                for distance in [1, 2, 3]
            ]
        ) {
            count += 1;
        }
    }
    return count;
}

walker ComposeEncounters {
    has experience: Experience = Experience(),
        rooms: dict[int, Space] = {},
        mass: Massing | None = None,
        details: list[list[float]] = [];

    can begin with Estate entry {
        for space in estate_spaces(here) {
            self.rooms[space.id] = space;
        }
        visit [->:Encloses:->];
    }

    can compose with Space entry {
        if here.role in ["corridor", "window"] or not here.stage {
            return;
        }
        quiet = here.role in QUIET_ROLES;
        pattern = "quiet"
            if quiet
            else (
                "guardian"
                    if here.role == "guardian"
                    else (
                        "teach"
                            if here.order < 4
                            else (
                                "overwatch"
                                    if here.kind
                                        in [
                                            "atrium",
                                            "overlook",
                                            "terraces",
                                            "towerhub"
                                        ]
                                    else ["crossfire", "pressure", "ambush"][
                                        here.order % 3
                                    ]
                            )
                    )
            );
        if here.encounter and not quiet {
            pattern = here.encounter;
            if pattern not in ["teach", "guardian"]
                and here.kind in ["atrium", "overlook", "terraces", "towerhub"] {
                pattern = "overwatch";
            }
        }
        approach = stage_point(here);
        earliest = 1000000;
        for corridor in [edge here<-:Corridor:<-] + [edge here->:Corridor:->] {
            other_id = corridor.tail if corridor.head == here.id else corridor.head;
            if other_id not in self.rooms or corridor.window {
                continue;
            }
            other = self.rooms[other_id];
            door = corridor.in_door if corridor.head == here.id else corridor.out_door;
            if other.order < here.order
                and other.order < earliest
                and door is not None
                and door.floored {
                approach = approach_point(here, door);
                earliest = other.order;
            }
        }
        mass = self.mass;
        if mass is not None {
            approach = settle_approach(here, approach, mass, self.details);
        }
        made = Encounter(
            room=here.id,
            order=here.order,
            pattern=pattern,
            quiet=quiet,
            optional=here.optional,
            approach=approach
        );
        self.experience +>:Stages:+> made;
        made +>:InRoom:+> here;
    }
}

"""Connect two ranged positions only when their lanes converge on the
approach from substantially different directions."""
def link_crossfire(encounter: Encounter, position: CombatPosition) {
    if not position.sees_entry or position.role != "ranged" {
        return;
    }
    ax = position.point[0] - encounter.approach[0];
    ay = position.point[1] - encounter.approach[1];
    for other in [encounter->:HoldsPosition:->][?:CombatPosition] {
        if other is position or not other.sees_entry or other.role != "ranged" {
            continue;
        }
        bx = other.point[0] - encounter.approach[0];
        other_y = other.point[1] - encounter.approach[1];
        scale = math.sqrt((ax * ax + ay * ay) * (bx * bx + other_y * other_y));
        if scale > 0.0 and (ax * bx + ay * other_y) / scale < 0.5 {
            position +>:Crossfire:+> other;
        }
    }
}

walker ReviewExperience {
    has rooms: int = 0,
        fights: int = 0,
        planned_fights: int = 0,
        positions: int = 0,
        quiet: int = 0,
        quiet_violations: int = 0,
        weapons: int = 0,
        discoveries: set[str] = set(),
        return_routes: int = 0,
        shortcuts: int = 0,
        ammo: set[str] = set(),
        patterns: set[str] = set(),
        supplied: int = 0,
        covered: int = 0,
        lanes: int = 0,
        ranged: int = 0,
        crossfires: int = 0,
        useful_optional: int = 0,
        optional: int = 0,
        low: float = 100.0;

    can begin with Experience entry {
        visit [->:Stages:->];
    }

    can review with Encounter entry {
        self.rooms += 1;
        for room in [here->:InRoom:->][?:Space] {
            for corridor in [edge room->:Corridor:->] {
                if not corridor.certified or corridor.window { continue; }
                if corridor.mode == "shortcut" {
                    self.shortcuts += 1;
                    self.return_routes += 1;
                } elif corridor.mode == "valve" {
                    # A key-room drop back into a familiar hub is also a
                    # return. A one-way descent into a new room is not.
                    for destination in [room->:Corridor:->][?:Space] {
                        if destination.id == corridor.head and destination.order < room.order
                            and not destination.optional { self.return_routes += 1; }
                    }
                }
            }
        }
        if here.quiet {
            self.quiet += 1;
            if here.foes > 0 {
                self.quiet_violations += 1;
            }
        } else {
            self.planned_fights += 1;
        }
        rewards = [here->:Supplies:->][?:Reward];
        if here.optional {
            self.optional += 1;
            if any(
                [
                    reward.kind.startswith("weapon_")
                        or reward.kind in ["armor", "powerup"] for reward in rewards
                ]
            ) {
                self.useful_optional += 1;
            }
        }
        if here.foes > 0 {
            self.fights += 1;
            self.patterns.add(here.pattern);
            if not here.quiet
                and here.ammo_ready >= here.ammo_needed
                and here.health_after >= 25.0
                and not here.issues {
                self.supplied += 1;
            }
            self.low = min(self.low, here.health_after);
        }
        visit [->:HoldsPosition:->];
        visit [->:Supplies:->];
    }

    can position with CombatPosition entry {
        self.positions += 1;
        if here.cover > 0 {
            self.covered += 1;
        }
        if here.role == "ranged" {
            self.ranged += 1;
            if here.sees_entry {
                self.lanes += 1;
            }
        }
        self.crossfires += len([edge here->:Crossfire:->]);
    }

    can reward with Reward entry {
        if here.kind.startswith("weapon_") {
            self.weapons += 1;
            self.discoveries.add(here.source + ":" + here.kind);
        } elif here.kind
            in [
                "shells",
                "nails",
                "bullets",
                "rockets",
                "cells",
                "slugs",
                "grenades",
                "lightning",
                "bfg"
            ] {
            self.ammo.add(here.kind);
        }
    }
}

def experience_measures(experience: Experience) -> dict[str, float] {
    review = experience spawn ReviewExperience();
    return {
        "play_quiet": float(review.quiet) / float(max(1, review.rooms)),
        "play_quiet_violations": float(review.quiet_violations),
        "play_weapons": float(len(review.discoveries)),
        "play_return_routes": float(review.return_routes),
        "play_shortcuts": float(review.shortcuts),
        "play_returns_wanted": 1.0 if experience.expects_returns else 0.0,
        "play_ammo_types": float(len(review.ammo)),
        "play_patterns": float(len(review.patterns)),
        "play_fight_coverage": float(review.fights)
            / float(max(1, review.planned_fights)),
        "play_cover": float(review.covered) / float(max(1, review.positions)),
        "play_supplied": float(review.supplied) / float(max(1, review.fights)),
        "play_firing_lanes": float(review.lanes) / float(max(1, review.ranged)),
        "play_crossfires": float(review.crossfires),
        "play_optional_rewards": float(review.useful_optional)
            / float(max(1, review.optional)),
        "play_health_low": review.low
    };
}
