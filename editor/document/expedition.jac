"""A Passion expedition as the studio speaks of it: its mission's beats and
links and its site's rooms said in a line each, which room a place in the
world is in, and a level's brushes handed to a group for every room, so that
a generated level opens as rooms that can be picked, locked and kept."""

import from engine.math.vec3 { Vec3 }
import from games.passion.mission { Expedition, Beat, Link, beats_of, links_of }
import from games.passion.layout { Site, Room, Passage, CELL, rooms_of, passages_of }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side, brush_windings }

"""A cell of the blueprint is so many units of the world each way."""
glob CELL_UNITS: float = 32.0;

"""The room a place in the world is in: the one whose share of the site
holds it. -1 for a place in no room (a corridor, the rock between)."""
def room_at(rooms: list[Room], x: float, y: float) -> int {
    across = int(x // (CELL_UNITS * float(CELL)));
    down = int(y // (CELL_UNITS * float(CELL)));
    for room in rooms {
        if room.contains(across, down) {
            return room.beat;
        }
    }
    return -1;
}

"""Where a room's middle is, on its floor."""
def room_middle(room: Room) -> Vec3 {
    return Vec3(
        x=(float(room.x) + float(room.w) / 2.0) * float(CELL) * CELL_UNITS,
        y=(float(room.y) + float(room.h) / 2.0) * float(CELL) * CELL_UNITS,
        z=float(room.z)
    );
}

"""The middle of a brush: of its corners."""
def brush_middle(sides: list[Side]) -> Vec3 {
    total = Vec3();
    count = 0;
    for outline in brush_windings(sides) {
        for corner in outline {
            total = total.add(corner);
            count += 1;
        }
    }
    return total.scale(1.0 / float(count)) if count > 0 else total;
}

"""What a room is called as a group."""
def room_name(room: Room) -> str {
    return "room " + str(room.beat) + " " + (room.kind if room.kind != "room" else room.recipe);
}

"""A level's entities with the world's brushes handed out: a group for each
room that has any, named for it, and one for the ways between; the world
keeps none. The other entities are as they were."""
def room_groups(found: list[MapItem], rooms: list[Room]) -> list[MapItem] {
    held: dict[int, list[list[Side]]] = {};
    made: list[MapItem] = [];
    for item in found {
        if item.fields.get("classname", "") != "worldspawn" {
            made.append(item);
            continue;
        }
        for sides in item.brushes {
            at = brush_middle(sides);
            which = room_at(rooms, at.x, at.y);
            if which not in held {
                held[which] = [];
            }
            held[which].append(sides);
        }
        made.append(MapItem(fields=dict(item.fields), brushes=[], patches=item.patches));
    }
    for room in rooms {
        if room.beat in held {
            made.append(MapItem(fields={"classname": "func_group", "_group_name": room_name(room)}, brushes=held[room.beat]));
        }
    }
    if -1 in held {
        made.append(MapItem(fields={"classname": "func_group", "_group_name": "ways between"}, brushes=held[-1]));
    }
    return made;
}

"""A beat of the mission in a line."""
def beat_words(beat: Beat) -> str {
    return "beat " + str(beat.id) + " " + beat.kind + " section=" + str(beat.section) + " district=" + str(beat.district)
        + " order=" + str(beat.order) + " tension=" + str(round(beat.tension, 2))
        + (" optional" if beat.optional else "") + (" grants=" + ",".join(beat.grants) if beat.grants else "")
        + (" pattern=" + beat.pattern if beat.pattern else "");
}

"""A link of the mission in a line: from which beat to which, how, and what it needs."""
def link_words(link: Link) -> str {
    return "link " + str(link.id) + " " + str(link.tail) + ">" + str(link.head) + " " + link.mode
        + (" needs=" + ",".join(link.needs) if link.needs else "");
}

"""A room of the site in a line."""
def room_words(room: Room) -> str {
    return "room " + str(room.beat) + " " + room.kind + " recipe=" + room.recipe + " at=" + str(room.x) + "," + str(room.y)
        + " size=" + str(room.w) + "x" + str(room.h) + " floor=" + str(room.z) + " ceiling=" + str(room.ceiling)
        + " district=" + str(room.district) + " order=" + str(room.order);
}
