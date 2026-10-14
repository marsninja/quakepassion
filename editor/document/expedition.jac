"""A Passion expedition as the studio speaks of it: its mission's beats and
links and its spaces said in a line each, which space a place in the world
is in, and a level's world brushes handed to a group for every room, so that
a generated level opens as rooms that can be picked, locked and kept."""

import from engine.math.vec3 { Vec3 }
import from games.passion.mission { Expedition, Beat, Link, beats_of, links_of }
import from games.passion.spaces { Space }
import from games.passion.massing { CELL, LIFT }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side, brush_windings }

"""The room a place in the world is in: the space whose box (grown by a
cell, for its walls) holds it, rooms before corridors. -1 for a place in
none (the rock between)."""
def space_at(spaces: list[Space], x: float, y: float, z: float) -> int {
    cx = int(x // CELL);
    cy = int(y // CELL);
    cz = int(z // LIFT);
    found = -1;
    for space in spaces {
        if space.x - 1 <= cx < space.x + space.w + 1 and space.y - 1 <= cy < space.y + space.d + 1
            and space.z - 1 <= cz < space.z + space.h + 1 {
            if space.role != "corridor" {
                return space.id;
            }
            if found < 0 {
                found = space.id;
            }
        }
    }
    return found;
}

"""Where a space's middle is, on its lowest floor."""
def space_middle(space: Space) -> Vec3 {
    return Vec3(x=space.middle_x() * CELL, y=space.middle_y() * CELL, z=float(space.z) * LIFT);
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

"""What a space is called as a group."""
def space_name(space: Space) -> str {
    if space.role == "corridor" {
        return "way " + str(space.id);
    }
    return "room " + str(space.id) + " " + space.role + " " + space.kind;
}

"""A level's entities with the world's brushes handed out: a group for each
space that has any, named for it; the world keeps whatever lies in none.
The other entities are as they were."""
def space_groups(found: list[MapItem], spaces: list[Space]) -> list[MapItem] {
    held: dict[int, list[list[Side]]] = {};
    made: list[MapItem] = [];
    for item in found {
        if item.fields.get("classname", "") != "worldspawn" {
            made.append(item);
            continue;
        }
        kept: list[list[Side]] = [];
        for sides in item.brushes {
            at = brush_middle(sides);
            which = space_at(spaces, at.x, at.y, at.z);
            if which < 0 {
                kept.append(sides);
                continue;
            }
            if which not in held {
                held[which] = [];
            }
            held[which].append(sides);
        }
        made.append(MapItem(fields=dict(item.fields), brushes=kept, patches=item.patches));
    }
    for space in spaces {
        if space.id in held {
            made.append(MapItem(fields={"classname": "func_group", "_group_name": space_name(space)}, brushes=held[space.id]));
        }
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

"""A space in a line."""
def space_words(space: Space) -> str {
    return "space " + str(space.id) + " " + space.role + " " + space.kind + " beat=" + str(space.beat) + " at="
        + str(space.x) + "," + str(space.y) + "," + str(space.z) + " size=" + str(space.w) + "x" + str(space.d) + "x"
        + str(space.h) + " levels=" + ",".join([str(level) for level in space.levels]) + " district=" + str(space.district)
        + " order=" + str(space.order);
}
