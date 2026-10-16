"""Human wayfinding, grounded in the same room/passage graph as the mission.

Threshold cues describe a passage, not a changing quest arrow. Light is
budgeted on sampled walking routes, with occlusion, instead of lamp counts.
The audit exposes this approximation separately from actual rendered light.
"""
import math;
import from .arrange { Estate, Encloses, Corridor, estate_spaces }
import from .spaces { Space }
import from .massing { Massing, CELL, LIFT }
import from .experience { approach_point, stage_point, settle_approach, clear_sight, detail_boxes, body_clear }
import from .dress { Dressing, Lamp3, box_brush, pilaster_box }
import from .kits { kit_of }
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }

node Wayfinding {
    has samples: int = 0, dark_before: int = 0, dark_after: int = 0,
        added_lamps: int = 0, missing_paths: int = 0;
}
node RouteCue {
    has room: int, destination: int, link: int, kind: str,
        point: list[float], optional: bool = False, gated: bool = False;
}
edge HasCue: Wayfinding --> RouteCue {}
edge CueInRoom: RouteCue --> Space {}

"""A portal needs a real landing before decoration and population. On a
catwalk, a two-cell ledge loses both cell centres to wall trim and railings.
Widen its perimeter by one cell so the arrival has a clear walking lane;
keep the railing on the new edge instead of removing fall protection."""
walker PreparePortalLandings {
    has mass: Massing;

    can begin with Estate entry { visit [->:Encloses:->]; }

    can prepare with Space entry {
        if here.kind != "catwalk" { return; }
        portals = [way for way in [edge here->:Corridor:->] + [edge here<-:Corridor:<-]
            if way.teleport and not way.needs];
        if not portals { return; }
        for z in here.levels {
            for y in range(here.y, here.y + here.d) {
                for x in range(here.x, here.x + here.w) {
                    inset = min(x - here.x, here.x + here.w - 1 - x,
                        y - here.y, here.y + here.d - 1 - y);
                    if inset == 2 and self.mass.at(x, y, z) == here.id + 1
                        and self.mass.headroom(x, y, z) >= 5 {
                        self.mass.fill(x, y, z - 1, x + 1, y + 1, z);
                    }
                }
            }
        }
    }
}

def route_cues(navigation: Wayfinding) -> list[RouteCue] {
    return [navigation->:HasCue:->][?:RouteCue];
}

"""Shortest bidirectional walking paths within one room. No falling down
shafts: a drop is a connector, not a substitute for finding the stairs."""
def room_paths(mass: Massing, space: Space, details: list[list[float]]) -> dict[int, int] {
    start = space.stage;
    first = (start[2] * mass.ny + start[1]) * mass.nx + start[0];
    parents: dict[int, int] = {first: -1};
    todo = [start];
    cursor = 0;
    while cursor < len(todo) {
        cell = todo[cursor];
        cursor += 1;
        previous = (cell[2] * mass.ny + cell[1]) * mass.nx + cell[0];
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            for dz in [0, 1, -1] {
                x = cell[0] + dx;
                y = cell[1] + dy;
                z = cell[2] + dz;
                key = (z * mass.ny + y) * mass.nx + x;
                if key in parents or mass.at(x, y, z) != space.id + 1
                    or not mass.standing(x, y, z) or mass.headroom(x, y, z) < 5 { continue; }
                point = [(float(x) + 0.5) * CELL, (float(y) + 0.5) * CELL, float(z) * LIFT + 24.0];
                if not body_clear(point, details) { continue; }
                parents[key] = previous;
                todo.append([x, y, z]);
            }
        }
    }
    return parents;
}

def cell_point(mass: Massing, key: int) -> list[float] {
    return [(float(key % mass.nx) + 0.5) * CELL,
        (float((key // mass.nx) % mass.ny) + 0.5) * CELL,
        float(key // (mass.nx * mass.ny)) * LIFT + 24.0];
}

"""A conservative direct-light proxy at the walking surface. A lamp in
the next room, or behind a thin railing, cannot certify this sample."""
def floor_light(mass: Massing, point: list[float], lamps: list[Lamp3], details: list[list[float]]) -> float {
    total = 0.0;
    floor = point[2] - 20.0;
    for lamp in lamps {
        dz = lamp.z - floor;
        if dz <= 0.0 { continue; }
        distance = math.sqrt((lamp.x - point[0]) ** 2 + (lamp.y - point[1]) ** 2 + dz * dz);
        if distance >= float(lamp.level) { continue; }
        # clear_sight adds 22 units to hull origins; these are actual rays.
        if clear_sight(mass, [point[0], point[1], floor - 22.0], [lamp.x, lamp.y, lamp.z - 22.0], details) {
            total += (float(lamp.level) - distance) * dz / max(1.0, distance);
        }
        if total >= 48.0 { break; }
    }
    return total;
}

walker ReadRoutes {
    has mass: Massing, dressing: Dressing, items: list[MapItem],
        navigation: Wayfinding = Wayfinding(), rooms: dict[int, Space] = {},
        details: list[list[float]] = [];

    can begin with Estate entry {
        self.details = detail_boxes(self.dressing.brushes);
        for space in estate_spaces(here) { self.rooms[space.id] = space; }
        visit [->:Encloses:->];
    }

    can read with Space entry {
        if here.role in ["corridor", "window"] or not here.stage { return; }
        points = [stage_point(here)];
        for corridor in [edge here->:Corridor:->] + [edge here<-:Corridor:<-] {
            if corridor.window or (corridor.mode == "valve" and corridor.head == here.id) { continue; }
            other_id = corridor.head if corridor.tail == here.id else corridor.tail;
            if other_id not in self.rooms { continue; }
            other = self.rooms[other_id];
            door = corridor.out_door if corridor.tail == here.id else corridor.in_door;
            point: list[float] = [];
            if corridor.teleport {
                for item in self.items {
                    fields = item.fields;
                    if fields.get("classname", "") == "trigger_teleport"
                        and fields.get("_mission_link", "") == str(corridor.link)
                        and fields.get("_room", "") == str(here.id) {
                        point = [float(v) for v in fields["_portal_point"].split()];
                    }
                }
            } elif corridor.connector and len(corridor.column) == 2 {
                z = corridor.low if here.id == corridor.lower else corridor.high;
                point = [(float(corridor.column[0]) + 1.0) * CELL,
                    (float(corridor.column[1]) + 1.0) * CELL, float(z) * LIFT + 24.0];
            } elif door is not None and door.floored {
                point = approach_point(here, door);
            }
            if not point { continue; }
            point = settle_approach(here, point, self.mass, self.details);
            kind = "optional" if other.optional else ("return" if other.order < here.order else "forward");
            if corridor.needs { kind = "gate"; }
            cue = RouteCue(room=here.id, destination=other_id, link=corridor.link, kind=kind,
                point=point, optional=other.optional, gated=bool(corridor.needs));
            self.navigation +>:HasCue:+> cue;
            cue +>:CueInRoom:+> here;
            # A secret wall stays a secret. Its hidden approach is not lit as
            # though it were the next mission exit.
            if corridor.mode == "secret" { continue; }
            points.append(point);
            if door is not None and door.floored and not corridor.connector and not corridor.teleport {
                self.mark_threshold(here, corridor, kind);
            }
        }
        for item in self.items {
            if item.fields.get("classname", "") == "info_teleport_destination"
                and item.fields.get("_room", "") == str(here.id) {
                points.append([float(v) for v in item.fields["_portal_point"].split()]);
            }
        }
        parents = room_paths(self.mass, here, self.details);
        samples: dict[int, bool] = {};
        for point in points {
            settled = settle_approach(here, point, self.mass, self.details);
            x = int(settled[0] / CELL);
            y = int(settled[1] / CELL);
            z = int(round((settled[2] - 24.0) / LIFT));
            key = (z * self.mass.ny + y) * self.mass.nx + x;
            if key not in parents {
                # A coarse cell path can miss an offset walk beside trim.
                # Still light the actual landing/threshold; keep the missing
                # path visible in the audit instead of claiming it proved.
                self.navigation.missing_paths += 1;
                if self.mass.standing(x, y, z) and body_clear(settled, self.details) { samples[key] = True; }
                continue;
            }
            step = 0;
            while key >= 0 {
                if step % 3 == 0 or parents[key] < 0 { samples[key] = True; }
                key = parents[key];
                step += 1;
            }
        }
        # Score the original lighting before adding any route lamps.
        for key in samples {
            self.navigation.samples += 1;
            if floor_light(self.mass, cell_point(self.mass, key), self.dressing.lamps, self.details) < 48.0 {
                self.navigation.dark_before += 1;
            }
        }
        for key in samples {
            point = cell_point(self.mass, key);
            if floor_light(self.mass, point, self.dressing.lamps, self.details) >= 48.0 { continue; }
            x = key % self.mass.nx;
            y = (key // self.mass.nx) % self.mass.ny;
            z = key // (self.mass.nx * self.mass.ny);
            height = min(80.0, float(self.mass.headroom(x, y, z)) * LIFT - 16.0);
            self.dressing.add_lamp(here, Lamp3(x=point[0], y=point[1], z=point[2] - 24.0 + height,
                level=210, color="255 238 210"));
            self.navigation.added_lamps += 1;
        }
        for key in samples {
            if floor_light(self.mass, cell_point(self.mass, key), self.dressing.lamps, self.details) < 48.0 {
                self.navigation.dark_after += 1;
            }
        }
    }

    def mark_threshold(space: Space, corridor: Corridor, kind: str) {
        door = corridor.out_door if corridor.tail == space.id else corridor.in_door;
        if door is None { return; }
        kit = kit_of(space.district);
        line = (space.x + space.w - 1 if door.side == 0 else space.x) if door.side < 2
            else (space.y + space.d - 1 if door.side == 2 else space.y);
        start = float((space.y if door.side < 2 else space.x) + door.along) * CELL;
        middle = start + float(door.span) * CELL * 0.5;
        top = float(door.level + 6) * LIFT;
        # One wide bar on onward passages, two small bars on a return, a
        # compact square on a side room. Marks live above the opening.
        bars = 2 if kind == "return" else 1;
        width = 8.0 if kind == "optional" else (12.0 if bars == 2 else 32.0);
        if kind == "gate" {
            bars = 2 if "key_gold" in corridor.needs else (1 if "key_silver" in corridor.needs else 3);
            width = 6.0;
        }
        for index in range(bars) {
            centre = middle + (float(index) - float(bars - 1) * 0.5) * 24.0;
            bounds = pilaster_box(door.side, line, centre - width * 0.5, centre + width * 0.5, top + 2.0, top + (14.0 if kind == "gate" else 8.0), 12.0);
            self.dressing.brushes.append(box_brush(bounds[0], bounds[1], [kit.light for _ in range(6)], kit.scale, [0, 1, 2, 3]));
        }
    }
}

"""Face a useful, visible departure on spawn/arrival. Optional detours and
locked gates do not outrank an open onward passage. No through-wall aim."""
def orient_arrivals(navigation: Wayfinding, rooms: list[Space], mass: Massing, items: list[MapItem], details: list[list[float]]) {
    by_id = {space.id: space for space in rooms};
    for item in items {
        fields = item.fields;
        kind = fields.get("classname", "");
        if kind not in ["info_player_start", "info_teleport_destination"] { continue; }
        room = int(fields.get("_room", "-1"));
        if room not in by_id { continue; }
        point = [float(v) for v in fields["origin"].split()];
        choices = [cue for cue in route_cues(navigation) if cue.room == room and not cue.optional
            and not cue.gated and str(cue.link) != fields.get("_mission_link", "")
            and clear_sight(mass, point, cue.point, details)];
        choices = sorted(choices, key=lambda (cue: RouteCue) { (cue.kind != "forward", cue.link); });
        target = choices[0].point if choices else stage_point(by_id[room]);
        if abs(target[0] - point[0]) + abs(target[1] - point[1]) < 32.0
            or not clear_sight(mass, point, target, details) { continue; }
        fields["angle"] = str(int(round(math.degrees(math.atan2(target[1] - point[1], target[0] - point[0])))) % 360);
    }
}
