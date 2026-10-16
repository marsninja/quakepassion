"""Rebuild the mission from realised passages, then prove its token states.

Local floor floods prevent another room or an unlocked shortcut from hiding
a broken approach. Stairs, connector landings and the actual teleporter
placements must reach those floors; every promised lock needs a cast door.
Real collision and mover execution are checked separately by play tools.
"""
import math;
import from .mission { Expedition, Beat, Link, Holds, beats_of, validate_mission }
import from .arrange { Estate, Corridor, estate_spaces, estate_corridors }
import from .spaces { Space, Doorway, socket_cells }
import from .massing { Massing, CELL, LIFT, floor_reached }
import from editor.formats.map { MapItem }

def cell_key(mass: Massing, cell: list[int]) -> int {
    return (cell[2] * mass.ny + cell[1]) * mass.nx + cell[0];
}

def returns_to_stage(mass: Massing, space: Space, cell: list[int]) -> bool {
    reached = floor_reached(mass, cell[0], cell[1], cell[2], owners=[space.id + 1]);
    return cell_key(mass, space.stage) in reached;
}

def point_cell(text: str) -> list[int] {
    words = text.split();
    return [
        int(math.floor(float(words[0]) / CELL)),
        int(math.floor(float(words[1]) / CELL)),
        int(round((float(words[2]) - 24.0) / LIFT))
    ];
}

def doorway_reached(
    mass: Massing, space: Space, door: Doorway, reached: dict[int, bool], leaving: bool
) -> bool {
    if leaving and not door.floored {
        return False;
    }
    for cell in socket_cells(space, door.side, door.along, door.span) {
        x = cell[2];
        y = cell[3];
        z = door.level;
        if not leaving {
            while z > space.z and mass.air(x, y, z) and not mass.standing(x, y, z) {
                z -= 1;
            }
        }
        if cell_key(mass, [x, y, z]) in reached {
            return True;
        }
    }
    return False;
}

def connector_reached(
    mass: Massing,
    corridor: Corridor,
    rooms: dict[int, Space],
    floors: dict[int, dict[int, bool]]
) -> bool {
    lower = corridor.lower;
    upper = corridor.head if corridor.tail == lower else corridor.tail;
    low_ok = False;
    high_ok = False;
    low_cell: list[int] = [];
    high_cell: list[int] = [];
    if len(corridor.column) != 2 or lower not in rooms or upper not in rooms {
        return False;
    }
    x = corridor.column[0];
    y = corridor.column[1];
    for dy in range(2) {
        for dx in range(2) {
            if cell_key(mass, [x + dx, y + dy, corridor.low]) in floors[lower] {
                low_ok = True;
                low_cell = [x + dx, y + dy, corridor.low];
            }
        }
    }
    if corridor.connector == "jumppad" and len(corridor.landing) == 2 {
        for dy in range(2) {
            for dx in range(2) {
                if cell_key(
                    mass,
                    [corridor.landing[0] + dx, corridor.landing[1] + dy, corridor.high]
                )
                    in floors[upper] {
                    high_ok = True;
                    high_cell = [
                        corridor.landing[0] + dx,
                        corridor.landing[1] + dy,
                        corridor.high
                    ];
                }
            }
        }
    } else {
        for dy in range(-1, 3) {
            for dx in range(-1, 3) {
                if cell_key(mass, [x + dx, y + dy, corridor.high]) in floors[upper] {
                    high_ok = True;
                    high_cell = [x + dx, y + dy, corridor.high];
                }
            }
        }
    }
    for z in range(corridor.low, corridor.high) {
        if not mass.air(x, y, z) {
            return False;
        }
    }
    return low_ok
        and high_ok
        and returns_to_stage(mass, rooms[lower], low_cell)
        and returns_to_stage(mass, rooms[upper], high_cell);
}

def teleporter_reached(
    mass: Massing,
    corridor: Corridor,
    items: list[MapItem],
    floors: dict[int, dict[int, bool]],
    rooms: dict[int, Space]
) -> bool {
    starts: set[int] = set();
    finishes: set[int] = set();
    for item in items {
        fields = item.fields;
        if fields.get("_mission_link", "") != str(corridor.link)
            or not fields.get("_portal_point", "") {
            continue;
        }
        room = int(fields["_room"]);
        if room not in floors
            or cell_key(mass, point_cell(fields["_portal_point"]))
                not in floors[room] {
            continue;
        }
        if fields.get("classname", "") == "trigger_teleport" {
            starts.add(room);
        } elif fields.get("classname", "") == "info_teleport_destination"
            and returns_to_stage(
                mass, rooms[room], point_cell(fields["_portal_point"])
            ) {
            finishes.add(room);
        }
    }
    forward = corridor.tail in starts and corridor.head in finishes;
    backward = corridor.head in starts and corridor.tail in finishes;
    return forward and (corridor.mode == "valve" or backward);
}

def locks_realised(corridor: Corridor, items: list[MapItem]) -> bool {
    for token in corridor.needs {
        found = False;
        for item in items {
            fields = item.fields;
            if fields.get("classname", "") != "func_door"
                or fields.get("_mission_link", "") != str(corridor.link) {
                continue;
            }
            if token.startswith("key_") {
                found = token in fields.get("key", "").split();
            } else {
                found = fields.get("targetname", "") == "t_" + token.replace(":", "_");
            }
            if found {
                break;
            }
        }
        if not found {
            return False;
        }
    }
    return True;
}

"""Every reachable state of the realised route must still reach its goal.
The return value is the number of physically certified mission passages."""
def validate_progression(
    plan: Expedition, estate: Estate, mass: Massing, items: list[MapItem]
) -> int {
    physical = Expedition(seed=plan.seed);
    beats: dict[int, Beat] = {};
    for beat in beats_of(plan) {
        copied = Beat(id=beat.id, kind=beat.kind, grants=list(beat.grants));
        physical +>:Holds:+> copied;
        beats[beat.id] = copied;
    }
    rooms = {
        space.id: space
        for space in estate_spaces(estate)
        if space.role not in ["corridor", "window"]
    };
    floors: dict[int, dict[int, bool]] = {};
    for space in rooms.values() {
        floors[space.id] = floor_reached(
            mass, space.stage[0], space.stage[1], space.stage[2], owners=[space.id + 1]
        );
    }
    certified = 0;
    for corridor in estate_corridors(estate) {
        if corridor.window {
            continue;
        }
        assert locks_realised(corridor, items) , "Passage "
            + str(corridor.link)
            + " did not realise its lock";
        tail = rooms[corridor.tail];
        head = rooms[corridor.head];
        good = False;
        if corridor.teleport {
            good = teleporter_reached(mass, corridor, items, floors, rooms);
        } elif corridor.connector {
            good = connector_reached(mass, corridor, rooms, floors);
        } elif corridor.out_door is not None and corridor.in_door is not None {
            good = doorway_reached(mass, tail, corridor.out_door, floors[tail.id], True)
                and doorway_reached(
                    mass, head, corridor.in_door, floors[head.id], False
                );
            if corridor.mode != "valve" {
                good = good
                    and doorway_reached(
                        mass, head, corridor.in_door, floors[head.id], True
                    );
            }
            # Overlapping two-cell blocks can each have some supported
            # floor while a wall separates their supported halves. Flood
            # the actual corridor, restricted to this one passage's owners.
            if good {
                path = floor_reached(
                    mass,
                    tail.stage[0],
                    tail.stage[1],
                    tail.stage[2],
                    owners=[tail.id + 1, head.id + 1, corridor.air + 1]
                );
                good = cell_key(mass, head.stage) in path;
                if good and corridor.mode != "valve" {
                    back = floor_reached(
                        mass,
                        head.stage[0],
                        head.stage[1],
                        head.stage[2],
                        owners=[tail.id + 1, head.id + 1, corridor.air + 1]
                    );
                    good = cell_key(mass, tail.stage) in back;
                }
            }
        }
        corridor.certified = good;
        if good {
            beats[tail.beat] +>:Link(
                id=corridor.link,
                mode=corridor.mode,
                needs=list(corridor.needs),
                tail=tail.beat,
                head=head.beat
            ):+> beats[head.beat];
            certified += 1;
        }
    }
    validate_mission(physical);
    return certified;
}
