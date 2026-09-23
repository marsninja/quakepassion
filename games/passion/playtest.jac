"""Column-level playtesting of a compiled blueprint.

A walker-free, token-carrying flood fill re-proves the mission against the real
geometry: it climbs at most one legal step, may drop from ledges, swims but
avoids lava, honors every door's requirement, follows teleporters, and collects
a room's tokens when it reaches that room's stage. A* over the same moves gives
physics bots concrete waypoint routes.
"""
import from .blueprint { Blueprint, DoorSpec }
import from .layout { Site, rooms_of, CELL }
import from .mission { Expedition, beats_of }

glob STEP_UP: int = 18;
glob HEADROOM: int = 64;
glob LAVA: int = 8;

obj Walkway {
    has bp: Blueprint,
        door_at: dict[int, int] = {},
        jumps: dict[int, list[int]] = {},
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
        return True;
    }

    def moves(i: int, tokens: list[str]) -> list[int] {
        bp = self.bp;
        x = i % bp.width;
        y = i // bp.width;
        result: list[int] = [];
        for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
            nx = x + delta[0];
            ny = y + delta[1];
            if nx < 0 or ny < 0 or nx >= bp.width or ny >= bp.height {
                continue;
            }
            j = bp.index(nx, ny);
            if self.passable(i, j, tokens) {
                result.append(j);
            }
        }
        for j in self.jumps.get(i, []) {
            result.append(j);
        }
        return result;
    }

    def passable(i: int, j: int, tokens: list[str]) -> bool {
        bp = self.bp;
        if not bp.open(j) or bp.liquid[j] == LAVA and bp.surface[j] > bp.floor[j] {
            return False;
        }
        if bp.floor[j] - bp.floor[i] > STEP_UP {
            return False;
        }
        if min(bp.ceiling[i], bp.ceiling[j]) - max(bp.floor[i], bp.floor[j]) < HEADROOM {
            return False;
        }
        if j in self.door_at and not self.door_open(bp.doors[self.door_at[j]], tokens) {
            return False;
        }
        return True;
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

def walkway(bp: Blueprint, site: Site) -> Walkway {
    way = Walkway(bp=bp);
    for index in range(len(bp.doors)) {
        for cell in bp.doors[index].cells {
            way.door_at[cell] = index;
        }
    }
    destinations: dict[str, int] = {};
    for mark in bp.marks {
        if mark.kind == "info_notnull" and "targetname" in mark.fields {
            destinations[mark.fields["targetname"]] = column_of(bp, mark.x, mark.y);
        }
    }
    for volume in bp.volumes {
        if volume.kind == "teleport" and volume.target in destinations {
            pad = column_of(bp, (volume.low[0] + volume.high[0]) * 0.5, (volume.low[1] + volume.high[1]) * 0.5);
            way.jumps.setdefault(pad, []).append(destinations[volume.target]);
        }
        if volume.kind == "exit" {
            way.exits.append(column_of(bp, (volume.low[0] + volume.high[0]) * 0.5, (volume.low[1] + volume.high[1]) * 0.5));
        }
    }
    for room in rooms_of(site) {
        interior = bp.interiors[room.beat];
        lx = interior.stage % interior.width;
        ly = interior.stage // interior.width;
        way.stage_of[room.beat] = bp.index(CELL * room.x + 1 + lx, CELL * room.y + 1 + ly);
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

# Flood, collect tokens at reached stages, repeat until nothing new opens.
def progress(plan: Expedition, bp: Blueprint, site: Site, start_x: float, start_y: float) -> Proof {
    way = walkway(bp, site);
    beats = beats_of(plan);
    result = Proof();
    start = column_of(bp, start_x, start_y);
    if start < 0 or not bp.open(start) {
        return result;
    }
    for round in range(32) {
        result.rounds = round + 1;
        seen = [False for _ in range(bp.width * bp.height)];
        seen[start] = True;
        queue = [start];
        cursor = 0;
        while cursor < len(queue) {
            i = queue[cursor];
            cursor += 1;
            for j in way.moves(i, result.tokens) {
                if not seen[j] {
                    seen[j] = True;
                    queue.append(j);
                }
            }
        }
        result.columns = len(queue);
        gained = False;
        for beat in beats {
            stage = way.stage_of.get(beat.id, -1);
            if stage >= 0 and seen[stage] {
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
            if column >= 0 and seen[column] {
                result.reached_exit = True;
            }
        }
        if not gained {
            break;
        }
    }
    return result;
}

# Shortest column route between two world points under a token set.
def route_between(way: Walkway, start: int, goal: int, tokens: list[str]) -> list[int] {
    parent: dict[int, int] = {start: -1};
    queue = [start];
    cursor = 0;
    while cursor < len(queue) and goal not in parent {
        i = queue[cursor];
        cursor += 1;
        for j in way.moves(i, tokens) {
            if j not in parent {
                parent[j] = i;
                queue.append(j);
            }
        }
    }
    if goal not in parent {
        return [];
    }
    result: list[int] = [];
    cursor = goal;
    while cursor >= 0 {
        result.insert(0, cursor);
        cursor = parent[cursor];
    }
    return result;
}
