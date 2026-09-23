"""Hull-accurate playtesting of a compiled blueprint.

The agent stands on column corners: a 32-unit hull centered on a corner covers
one quarter of each of the four columns around it, so a corner is standable
only when all four are open, clear of cover and closed doors, share a floor
within one step, and leave headroom. Moves climb at most one step and may drop
from ledges; teleport pads jump to their destinations. A token-carrying flood
re-proves the mission against real geometry, collecting a room's tokens when
its stage is reached, and breadth-first routes over the same moves give
physics bots waypoints a real hull can follow.
"""
import from .blueprint { Blueprint, DoorSpec }
import from .layout { Site, rooms_of, CELL }
import from .mission { Expedition, beats_of }

glob STEP_UP: int = 18;
glob HEADROOM: int = 60;
glob LAVA: int = 8;
glob NOWHERE: int = -1000000;

obj Walkway {
    has bp: Blueprint,
        strict: bool = False,
        door_at: dict[int, int] = {},
        jumps: dict[int, list[int]] = {},
        forced: dict[int, int] = {},
        stage_of: dict[int, int] = {},
        exits: list[int] = [];

    def door_open(door: DoorSpec, tokens: list[str]) -> bool {
        if door.kind == "key" {
            for key in door.keys {
                if key not in tokens {
                    return False;
                }
            }
            return True;
        }
        if door.kind in ["remote", "guardian"] {
            return door.keys[0] in tokens;
        }
        if door.kind == "shortcut" {
            return ("open:" + str(door.link)) in tokens;
        }
        if door.kind == "lockdown" {
            # Lockdown doors rest open and always reopen on a timer.
            return True;
        }
        # Secrets open by shooting a panel; strict bots never assume them.
        return not self.strict;
    }

    def column_clear(i: int, tokens: list[str]) -> bool {
        bp = self.bp;
        if not bp.open(i) {
            return False;
        }
        if bp.liquid[i] == LAVA and bp.surface[i] > bp.floor[i] {
            return False;
        }
        if i in self.door_at
            and not self.door_open(bp.doors[self.door_at[i]], tokens) {
            return False;
        }
        return True;
    }

    # Standing height of the hull on a corner, or NOWHERE if it cannot stand.
    def stand(v: int, tokens: list[str]) -> int {
        bp = self.bp;
        x = v % bp.width;
        y = v // bp.width;
        if x < 1 or y < 1 {
            return NOWHERE;
        }
        low = 1000000;
        high = -1000000;
        roof = 1000000;
        for cell in [
            bp.index(x - 1, y - 1),
            bp.index(x, y - 1),
            bp.index(x - 1, y),
            bp.index(x, y)
        ] {
            if not self.column_clear(cell, tokens) {
                return NOWHERE;
            }
            low = min(low, bp.floor[cell]);
            high = max(high, bp.floor[cell]);
            roof = min(roof, bp.ceiling[cell]);
        }
        if high - low > STEP_UP or roof - high < HEADROOM {
            return NOWHERE;
        }
        return high;
    }

    # A falling hull passes a corner whose columns are all open and no higher
    # than the ledge it leaves.
    def open_above(v: int, height: int, tokens: list[str]) -> bool {
        bp = self.bp;
        x = v % bp.width;
        y = v // bp.width;
        for cell in [
            bp.index(x - 1, y - 1),
            bp.index(x, y - 1),
            bp.index(x - 1, y),
            bp.index(x, y)
        ] {
            if not self.column_clear(cell, tokens) {
                return False;
            }
            if bp.floor[cell] > height or bp.ceiling[cell] - height < HEADROOM {
                return False;
            }
        }
        return True;
    }

    def moves(v: int, tokens: list[str]) -> list[int] {
        bp = self.bp;
        here = self.stand(v, tokens);
        result: list[int] = [];
        if here == NOWHERE {
            return result;
        }
        # A hull overlapping a teleporter's volume is always teleported.
        if v in self.forced {
            return [self.forced[v]];
        }
        x = v % bp.width;
        y = v // bp.width;
        for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
            nx = x + delta[0];
            ny = y + delta[1];
            if nx < 1 or ny < 1 or nx >= bp.width or ny >= bp.height {
                continue;
            }
            w = bp.index(nx, ny);
            there = self.stand(w, tokens);
            if there != NOWHERE and there - here <= STEP_UP {
                result.append(w);
                continue;
            }
            # Ledges: step across one corner that straddles a drop.
            fx = nx + delta[0];
            fy = ny + delta[1];
            if there == NOWHERE
                and 1 <= fx < bp.width
                and 1 <= fy < bp.height
                and self.open_above(w, here, tokens) {
                beyond = bp.index(fx, fy);
                landing = self.stand(beyond, tokens);
                if landing != NOWHERE and landing < here - STEP_UP {
                    result.append(beyond);
                }
            }
        }
        for w in self.jumps.get(v, []) {
            result.append(w);
        }
        return result;
    }

    # A standable corner of a column, if it has one.
    def corner(column: int, tokens: list[str]) -> int {
        bp = self.bp;
        x = column % bp.width;
        y = column // bp.width;
        for offset in [[0, 0], [1, 0], [0, 1], [1, 1]] {
            if x + offset[0] >= bp.width or y + offset[1] >= bp.height {
                continue;
            }
            v = bp.index(x + offset[0], y + offset[1]);
            if self.stand(v, tokens) != NOWHERE {
                return v;
            }
        }
        return bp.index(x, y);
    }

    # Corners whose hull overlaps a column while resting at its floor height:
    # standing there presses a plate or picks up an item on that column.
    def touching(column: int, tokens: list[str]) -> list[int] {
        bp = self.bp;
        x = column % bp.width;
        y = column // bp.width;
        result: list[int] = [];
        for dy in [0, 1] {
            for dx in [0, 1] {
                if x + dx >= bp.width or y + dy >= bp.height {
                    continue;
                }
                v = bp.index(x + dx, y + dy);
                if self.stand(v, tokens) == bp.floor[column] {
                    result.append(v);
                }
            }
        }
        return result;
    }

    # Corners within a small radius of a column, for goals like stages or exits.
    def near(column: int) -> list[int] {
        bp = self.bp;
        x = column % bp.width;
        y = column // bp.width;
        result: list[int] = [];
        for dy in range(-1, 3) {
            for dx in range(-1, 3) {
                if 1 <= x + dx < bp.width and 1 <= y + dy < bp.height {
                    result.append(bp.index(x + dx, y + dy));
                }
            }
        }
        return result;
    }
}

def column_of(bp: Blueprint, x: float, y: float) -> int {
    cx = int(x / 32.0);
    cy = int(y / 32.0);
    if cx < 0 or cy < 0 or cx >= bp.width or cy >= bp.height {
        return -1;
    }
    return bp.index(cx, cy);
}

# The corner nearest a world point (corners sit on multiples of 32 units).
def vertex_of(bp: Blueprint, x: float, y: float) -> int {
    vx = int(x / 32.0 + 0.5);
    vy = int(y / 32.0 + 0.5);
    return bp.index(max(1, min(bp.width - 1, vx)), max(1, min(bp.height - 1, vy)));
}

def walkway(bp: Blueprint, site: Site, strict: bool = False) -> Walkway {
    way = Walkway(bp=bp, strict=strict);
    for index in range(len(bp.doors)) {
        for cell in bp.doors[index].cells {
            way.door_at[cell] = index;
        }
    }
    destinations: dict[str, int] = {};
    for mark in bp.marks {
        if mark.kind == "info_notnull" and "targetname" in mark.fields {
            destinations[mark.fields["targetname"]] = vertex_of(bp, mark.x, mark.y);
        }
    }
    for volume in bp.volumes {
        cx = (volume.low[0] + volume.high[0]) * 0.5;
        cy = (volume.low[1] + volume.high[1]) * 0.5;
        if volume.kind == "teleport" and volume.target in destinations {
            arrival = destinations[volume.target];
            way.jumps.setdefault(vertex_of(bp, cx, cy), []).append(arrival);
            # Every corner whose 32-unit hull overlaps the trigger is forced.
            for vy in range(
                int(volume.low[1] / 32.0) - 1, int(volume.high[1] / 32.0) + 3
            ) {
                for vx in range(
                    int(volume.low[0] / 32.0) - 1, int(volume.high[0] / 32.0) + 3
                ) {
                    px = float(vx) * 32.0;
                    py = float(vy) * 32.0;
                    # Hull half-width plus a margin: touching the trigger counts.
                    if px + 24.0 > volume.low[0]
                        and px - 24.0 < volume.high[0]
                        and py + 24.0 > volume.low[1]
                        and py - 24.0 < volume.high[1]
                        and 1 <= vx < bp.width
                        and 1 <= vy < bp.height {
                        way.forced[bp.index(vx, vy)] = arrival;
                    }
                }
            }
        }
        if volume.kind == "exit" {
            way.exits.append(column_of(bp, cx, cy));
        }
    }
    for room in rooms_of(site) {
        interior = bp.interiors[room.beat];
        lx = interior.stage % interior.width;
        ly = interior.stage // interior.width;
        way.stage_of[room.beat] = bp.index(
            CELL * room.x + 1 + lx, CELL * room.y + 1 + ly
        );
    }
    return way;
}

obj Proof {
    has reached_exit: bool = False,
        tokens: list[str] = [],
        rooms: list[int] = [],
        rounds: int = 0,
        columns: int = 0;
}

def reached_any(seen: list[bool], corners: list[int]) -> bool {
    for v in corners {
        if seen[v] {
            return True;
        }
    }
    return False;
}

# Flood, collect tokens at reached stages, repeat until nothing new opens.
def progress(
    plan: Expedition, bp: Blueprint, site: Site, start_x: float, start_y: float
) -> Proof {
    way = walkway(bp, site);
    beats = beats_of(plan);
    result = Proof();
    start = way.corner(column_of(bp, start_x, start_y), []);
    if way.stand(start, []) == NOWHERE {
        return result;
    }
    for round in range(32) {
        result.rounds = round + 1;
        seen = [False for _ in range(bp.width * bp.height)];
        seen[start] = True;
        queue = [start];
        cursor = 0;
        while cursor < len(queue) {
            v = queue[cursor];
            cursor += 1;
            for w in way.moves(v, result.tokens) {
                if not seen[w] {
                    seen[w] = True;
                    queue.append(w);
                }
            }
        }
        result.columns = len(queue);
        gained = False;
        for beat in beats {
            stage = way.stage_of.get(beat.id, -1);
            if stage >= 0 and reached_any(seen, way.touching(stage, result.tokens)) {
                if beat.id not in result.rooms {
                    result.rooms.append(beat.id);
                }
                for token in beat.grants {
                    if token not in result.tokens {
                        result.tokens.append(token);
                        gained = True;
                    }
                }
            }
        }
        for column in way.exits {
            if column >= 0 and reached_any(seen, way.near(column)) {
                result.reached_exit = True;
            }
        }
        if not gained {
            break;
        }
    }
    return result;
}

# Shortest corner route from a corner to a corner of the goal column, whose
# hull then overlaps the goal (a plate, a pickup); nearby corners otherwise.
def route_between(way: Walkway, start: int, goal: int, tokens: list[str]) -> list[int] {
    exact = route_to(way, start, way.touching(goal, tokens), tokens);
    if exact {
        return exact;
    }
    return route_to(way, start, way.near(goal), tokens);
}

def route_to(
    way: Walkway, start: int, goals: list[int], tokens: list[str]
) -> list[int] {
    parent: dict[int, int] = {start: -1};
    queue = [start];
    cursor = 0;
    found = -1;
    while cursor < len(queue) {
        v = queue[cursor];
        cursor += 1;
        if v in goals and way.stand(v, tokens) != NOWHERE {
            found = v;
            break;
        }
        for w in way.moves(v, tokens) {
            if w not in parent {
                parent[w] = v;
                queue.append(w);
            }
        }
    }
    if found < 0 {
        return [];
    }
    result: list[int] = [];
    cursor = found;
    while cursor >= 0 {
        result.insert(0, cursor);
        cursor = parent[cursor];
    }
    return result;
}
