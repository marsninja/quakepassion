"""Prefabs drawn from e4m6, the Pain Maze: a fortress over flooded
cellars, its walkways and halls standing over deep water swum from well to
well, spawn swarming in its pits, four buttons in a sunken court that
together bring the way up, an unholy altar shot until it breaks and opens
the way on, the key high in a cistern up its slow lift. Raised in e4m6's
own palette.

- `PainGate`: the start. A balcony over a hall (the run begins on it), a
  stair down, a deep cistern across the hall crossed by a stone bridge, by
  stepping blocks or not at all (swum, a walkway down each side); fish in
  it; a closet behind the undercroft's wall that opens when shot (a
  secret); a spawn teleported in behind the player at the far side.
- `FloodedMaze`: the maze. A maze of three-cell passages over a second
  maze, flooded, under its floor (or an open flooded cellar of pillars):
  wells in the upper maze's dead ends drop into the water, and the drowned
  ways below join every well to every other. Some seeds split the upper maze in two, so the only way across is
  under the water. Spawn wait in the dead ends, fish below, a teleporter in
  one dead end back to the maze's mouth, a secret in a drowned dead end.
  Small as a flow, large as a hub.
- `ButtonCourt`: a sunken court (e4m6's four buttons): the way in on a
  ledge, galleries over arcades down the court's sides, the way on on a
  ledge higher still at the far end. Four buttons about the court, pressed
  together (a counter), raise a stair out of its floor to the high ledge; a
  lift back up to the near ledge; a deep pool in its middle, or none.
- `SpawnPit`: a hall over a pit, crossed by a bridge (or a bridge drawn out
  by shooting a button on the far wall); spawn wait at the pit's foot and
  leap out as the player is halfway (e4m6's pit of leaping spawn), or water
  and fish fill it; a stair up out of it; a gallery high along one wall.
- `SilverCistern`: the key room. A tall cistern, a pool at its foot, the
  key on a ledge high over the floor reached by a slow lift (e4m6's long
  lift) or by a stair winding up its walls; taking the key teleports spawn
  in, or wakes what lies under the ledge.
- `UnholyAltar`: a chapel, galleries over its aisles, the unholy altar on a
  dais at its far end. Shot again and again it breaks ("The altar has been
  defiled"), opening the way on (as a flow), or the wall before the
  slipgate (as the end: "Are you sure you want to exit?" and a hell knight
  behind); a key's door before the chapel as a gate. Shalraths wake on the
  galleries as it breaks; a secret door opens with it."""
import math;
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires, Next }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_item, ring_path, spiral }

glob E4M6: str = "q1:e4m6";

"""e4m6's foes: spawn above all, fiends and hell knights, vores deeper in."""
def e4m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_demon1"] if heavy else ["monster_tarbaby", "monster_tarbaby", "monster_demon1"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""Water (liquid 2) in every air cell of the prefab's box x0..x1, y0..y1,
z0..z1."""
def flood(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) {
    for z in range(z0, z1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                at = build.cells(float(x) + 0.5, float(y) + 0.5, float(z), float(x) + 0.5, float(y) + 0.5, float(z));
                if build.mass.air(int(math.floor(at[0])), int(math.floor(at[1])), int(round(at[2]))) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
    }
}

"""Steps up out of a pool `depth` lifts deep whose near edge is the cell
line x0: `width` cells wide from (x0, y) along +y, climbing a lift a cell
toward x0 from the pool's floor, so they keep to its side and clear of a
bridge over its middle."""
def pool_steps(build: Raising, x0: int, y: int, depth: int, width: int) {
    stair(build, x0 + depth - 1, y, -depth, 2, depth, width);
}

"""The ways out a prefab's stretches after it are reached by (not the
loops that come back into it)."""
def onward_ports(prefab: Prefab) -> list[Port] {
    found: list[Port] = [];
    for after in [prefab->:Next:->][?:Prefab] {
        if after.via is not None {
            found.append(after.via);
        }
    }
    return found;
}

"""A door across a way out of the prefab (in its wall's cell), shut until
its cue fires."""
def port_door(build: Raising, prefab: Prefab, port: Port) -> Cue {
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    top = float(port.floor + port.high);
    if port.face == 0 {
        return build.opened(float(prefab.long - 1), low, float(port.floor), float(prefab.long), high, top);
    }
    if port.face == 1 {
        return build.opened(low, float(prefab.wide - 1), float(port.floor), high, float(prefab.wide), top);
    }
    if port.face == 3 {
        return build.opened(low, 0.0, float(port.floor), high, 1.0, top);
    }
    return build.opened(0.0, low, float(port.floor), 1.0, high, top);
}

"""A secret door (as `secret_door`) that opens when its cue fires, not when
shot (Quake's func_door_secret with a targetname)."""
def fired_secret_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) -> Cue {
    kit = kit_of(build.district);
    fields = {"classname": "func_door_secret", "angle": str(build.facing(direction)), "sounds": "1"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, kit.wall);
    reach = max(x1 - x0, y1 - y0) + 1.0;
    build.rock_round(x0 - reach, y0 - reach, z0, x1 + reach, y1 + reach, z1 + 1.0);
    return build.cue([fields], "secret");
}

"""A relay that shows `message` to who set it off, `seconds` after."""
def told(build: Raising, seconds: float, message: str) -> Cue {
    relay = build.delay(seconds);
    relay.items[0]["message"] = message;
    return relay;
}

"""A perfect maze over the columns `col0`..`col1` of a grid `rows` high,
by a random walk that goes deeper while it can and backs up when it
cannot, written into `east` and `north` (east[i][j]: the cell (i, j) opens
to (i + 1, j); north[i][j]: to (i, j + 1))."""
def walk_into(dice: Stream, east: list[list[bool]], north: list[list[bool]], col0: int, col1: int, rows: int) {
    seen: dict[int, bool] = {};
    first = dice.below(rows);
    seen[col0 * 1000 + first] = True;
    trail: list[list[int]] = [[col0, first]];
    while trail {
        cell = trail[-1];
        i = cell[0];
        j = cell[1];
        options: list[list[int]] = [];
        if i + 1 < col1 and (i + 1) * 1000 + j not in seen {
            options.append([i + 1, j, 0]);
        }
        if i > col0 and (i - 1) * 1000 + j not in seen {
            options.append([i - 1, j, 2]);
        }
        if j + 1 < rows and i * 1000 + j + 1 not in seen {
            options.append([i, j + 1, 1]);
        }
        if j > 0 and i * 1000 + j - 1 not in seen {
            options.append([i, j - 1, 3]);
        }
        if not options {
            trail.pop();
            continue;
        }
        pick = options[dice.below(len(options))];
        if pick[2] == 0 {
            east[i][j] = True;
        } elif pick[2] == 2 {
            east[i - 1][j] = True;
        } elif pick[2] == 1 {
            north[i][j] = True;
        } else {
            north[i][j - 1] = True;
        }
        seen[pick[0] * 1000 + pick[1]] = True;
        trail.append([pick[0], pick[1]]);
    }
}

"""A maze of `cols` by `rows` cells, whole, or split before column `split`
(when over 0) into two mazes with no way between: [east, north]."""
def maze_links(dice: Stream, cols: int, rows: int, split: int) -> list[list[list[bool]]] {
    east: list[list[bool]] = [[False for row in range(rows)] for col in range(cols)];
    north: list[list[bool]] = [[False for row in range(rows)] for col in range(cols)];
    if split > 0 and split < cols {
        walk_into(dice.derive("west"), east, north, 0, split, rows);
        walk_into(dice.derive("east"), east, north, split, cols, rows);
    } else {
        walk_into(dice, east, north, 0, cols, rows);
    }
    return [east, north];
}

"""Open more of a maze's walls, each by `chance`, so its ways go round
in loops (a braided maze): only walls between cells that open two ways or
more already, so its dead ends stay, and none across the column line
`split` (when over 0)."""
def braid(dice: Stream, links: list[list[list[bool]]], cols: int, rows: int, chance: float, split: int) {
    east = links[0];
    north = links[1];
    for i in range(cols) {
        for j in range(rows) {
            if i + 1 < cols and not east[i][j] and i + 1 != split and maze_ways(links, cols, rows, i, j) > 1 and maze_ways(links, cols, rows, i + 1, j) > 1 and dice.chance(chance) {
                east[i][j] = True;
            }
            if j + 1 < rows and not north[i][j] and maze_ways(links, cols, rows, i, j) > 1 and maze_ways(links, cols, rows, i, j + 1) > 1 and dice.chance(chance) {
                north[i][j] = True;
            }
        }
    }
}

"""How many ways the maze cell (i, j) opens by."""
def maze_ways(links: list[list[list[bool]]], cols: int, rows: int, i: int, j: int) -> int {
    east = links[0];
    north = links[1];
    ways = 0;
    if i + 1 < cols and east[i][j] {
        ways += 1;
    }
    if i > 0 and east[i - 1][j] {
        ways += 1;
    }
    if j + 1 < rows and north[i][j] {
        ways += 1;
    }
    if j > 0 and north[i][j - 1] {
        ways += 1;
    }
    return ways;
}

"""Cut a maze's walls into lifts z0..z1 of the prefab: each cell three
cells of air square (cell (i, j) at 4i+1..4i+4, 4j+1..4j+4), a cell of
wall between it and the next unless the maze opens them, a post at each
inner corner but those `bare` names ([i, j], the corner at 4i, 4j).
Answers its dead ends ([i, j] each)."""
def cut_maze(build: Raising, links: list[list[list[bool]]], cols: int, rows: int, z0: int, z1: int, bare: list[list[int]] | None = None) -> list[list[int]] {
    east = links[0];
    north = links[1];
    for i in range(1, cols) {
        for j in range(1, rows) {
            if bare is None or [i, j] not in bare {
                build.solid(4 * i, 4 * j, z0, 4 * i + 1, 4 * j + 1, z1);
            }
        }
    }
    for i in range(cols) {
        for j in range(rows) {
            if i + 1 < cols and not east[i][j] {
                build.solid(4 * i + 4, 4 * j + 1, z0, 4 * i + 5, 4 * j + 4, z1);
            }
            if j + 1 < rows and not north[i][j] {
                build.solid(4 * i + 1, 4 * j + 4, z0, 4 * i + 4, 4 * j + 5, z1);
            }
        }
    }
    ends: list[list[int]] = [];
    for i in range(cols) {
        for j in range(rows) {
            if maze_ways(links, cols, rows, i, j) == 1 {
                ends.append([i, j]);
            }
        }
    }
    return ends;
}

"""The cells of the one opening out of a dead end (i, j) of a maze:
[x, y] each, on its floor."""
def dead_end_mouth(links: list[list[list[bool]]], cols: int, rows: int, i: int, j: int) -> list[list[int]] {
    east = links[0];
    north = links[1];
    found: list[list[int]] = [];
    for k in range(1, 4) {
        if i + 1 < cols and east[i][j] {
            found.append([4 * i + 4, 4 * j + k]);
        } elif i > 0 and east[i - 1][j] {
            found.append([4 * i, 4 * j + k]);
        } elif j + 1 < rows and north[i][j] {
            found.append([4 * i + k, 4 * j + 4]);
        } elif j > 0 and north[i][j - 1] {
            found.append([4 * i + k, 4 * j]);
        }
    }
    return found;
}

"""The start: a balcony over a hall, a stair down, a deep cistern across
the hall crossed by a bridge, stepping blocks, or swum."""
node PainGate(Prefab) {
    has perch: int = 7,
        balcony: int = 6,
        cistern: int = 10,
        far: int = 8,
        crossing: int = 0,
        stair_side: int = 0,
        secret_here: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain gate";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.perch = dice.between(7, 8);
        self.balcony = dice.between(6, 7);
        self.crossing = dice.below(3);
        self.cistern = (7 if dice.chance(0.5) else 10) if self.crossing == 1 else dice.between(8, 11);
        self.far = dice.between(7, 9);
        self.stair_side = dice.below(2);
        self.secret_here = dice.chance(0.75);
        self.wide = dice.between(18, 22);
        self.tall = self.perch + dice.between(10, 12);
        self.long = 1 + self.balcony + self.perch + 3 + self.cistern + self.far + 1;
        self.low = -11;
        self.high = self.tall + 8;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.perch);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=1 if self.stair_side == 0 else 3, along=float(1 + self.balcony // 2), floor=self.perch)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.perch);
        front = 1 + self.balcony;
        # The balcony: a slab over an undercroft, pillars along its front.
        build.solid(1, 1, self.perch - 1, front, self.wide - 1, self.perch);
        sy = 1 if self.stair_side == 0 else self.wide - 4;
        for y in range(3, self.wide - 3, 4) {
            build.solid(front - 1, y, 0, front, y + 1, self.perch - 1);
        }
        # The stair down from the balcony's front, along a side wall.
        stair(build, self.balcony + self.perch, sy, 0, 2, self.perch, 3);
        for y in range(sy, sy + 3) {
            build.keep(hall, front - 1, y, self.perch);
            build.keep(hall, front, y, self.perch);
        }
        # The cistern, deep, steps up out of it at both ends of its near side.
        x0 = front + self.perch + 2;
        x1 = x0 + self.cistern;
        lane = middle - 2;
        if self.crossing == 2 {
            build.pool(x0, 4, -9, x1, self.wide - 4, 0, 2, False, True, True);
        } elif self.crossing == 1 {
            build.pool(x0, 1, -9, x1, self.wide - 1, 0, 2, False, True, True);
        } else {
            # Under a bridge the steps out keep to the cistern's sides.
            depth = min(9, self.cistern);
            build.pool(x0, 1, -depth, x1, self.wide - 1, 0, 2, False, False);
            pool_steps(build, x0, 1, depth, 2);
            pool_steps(build, x0, self.wide - 3, depth, 2);
        }
        if self.crossing == 0 {
            build.solid(x0, lane, -1, x1, lane + 4, 0);
        } elif self.crossing == 1 {
            # Blocks two cells long, a cell of water between each.
            for x in range(x0 + 1, x1 - 1, 3) {
                build.solid(x, lane, -9, x + 2, lane + 4, 0);
                for dx in range(2) {
                    for across in range(4) {
                        build.keep(hall, x + dx, lane + across, 0);
                    }
                }
            }
        }
        if self.crossing != 2 {
            for across in range(4) {
                build.keep(hall, x0 - 1, lane + across, 0);
                build.keep(hall, x1, lane + across, 0);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The secret: a closet in a block of the undercroft, behind a stretch
        # of its wall that opens when shot.
        if self.secret_here {
            cx = 1 + self.balcony // 2 - 1;
            if self.stair_side == 0 {
                build.solid(1, self.wide - 6, 0, front - 1, self.wide - 1, self.perch - 1);
                build.room(cx, self.wide - 3, 0, cx + 2, self.wide - 1, 4);
                build.secret_door(float(cx), float(self.wide - 5), 0.0, float(cx + 2), float(self.wide - 3), 4.0, 1);
                build.secret(float(cx), float(self.wide - 3), 0.0, float(cx + 2), float(self.wide - 1), 3.0);
                build.supply(float(cx) + 1.0, float(self.wide) - 2.0, 0, "item_artifact_super_damage");
            } else {
                build.solid(1, 1, 0, front - 1, 6, self.perch - 1);
                build.room(cx, 1, 0, cx + 2, 3, 4);
                build.secret_door(float(cx), 3.0, 0.0, float(cx + 2), 5.0, 4.0, 3);
                build.secret(float(cx), 1.0, 0.0, float(cx + 2), 3.0, 3.0);
                build.supply(float(cx) + 1.0, 2.0, 0, "item_artifact_super_damage");
            }
        }
        build.start(2.5, float(middle) + 0.5, self.perch, 0.0);
        build.supply(2.5, float(middle) - 1.5, self.perch, "item_shells");
        # The hall's spawn wake as the player comes down the stair.
        foot = build.touch(float(front + self.perch - 1), float(sy), 0.0, float(front + self.perch + 1), float(sy + 3), 6.0);
        stirred = build.waiting();
        foot +>:Fires:+> stirred;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0) - 1.5, 2.5 + float(index) * 3.0 + (float(self.wide) - 12.0 if self.stair_side == 0 else 0.0), 0, e4m6_foe(dice, self.danger), 0.0, waits=stirred);
        }
        far_x = float(x1) + 2.5;
        build.foe(far_x, 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_demon1", 90.0, patrol=[[far_x, 2.5], [far_x, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, 0, e4m6_foe(dice, self.danger, True), 180.0);
        if self.danger > 0.15 or dice.chance(0.5) {
            build.foe(float(x0 + self.cistern // 2) + 0.5, 5.5, -7, "monster_fish", 90.0);
        }
        # Reaching the far side brings a spawn in behind the player.
        across = build.touch(float(x1), 1.0, 0.0, float(x1 + 2), float(self.wide - 1), 6.0);
        across +>:Fires:+> build.summon(self.long - 5, 2, self.tall + 1, "monster_tarbaby", float(x0) - 2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(float(x0) - 2.5, float(self.wide) - 2.5 if self.stair_side == 0 else 2.5, 0, "item_spikes");
    }
}

"""A maze over a flooded maze, wells between them in the upper one's dead
ends."""
node FloodedMaze(Prefab) {
    has cols: int = 6,
        rows: int = 4,
        way_in: int = 1,
        split: int = 0,
        wells: int = 3,
        cellar: bool = False,
        tall: int = 8,
        hub: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain labyrinth" if self.hub else "Flooded maze";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.cols = self.cols + dice.below(2);
        self.long = 4 * self.cols + 1;
        self.wide = 4 * self.rows + 1;
        self.tall = dice.between(8, 10);
        self.split = self.cols // 2 + dice.below(2) if dice.chance(0.45) else 0;
        self.wells = dice.between(3, 5);
        self.cellar = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 8;
        self.way_in = dice.below(self.rows);
        self.enter = Port(face=2, along=float(4 * self.way_in) + 2.5, floor=0);
        out_row = dice.below(self.rows);
        self.leaves = [
            Port(face=0, along=float(4 * out_row) + 2.5, floor=0),
            Port(face=1, along=float(4 * dice.below(self.cols)) + 2.5, floor=0),
            Port(face=3, along=float(4 * dice.below(self.cols)) + 2.5, floor=0),
            Port(face=0, along=float(4 * ((out_row + 2) % self.rows)) + 2.5, floor=0)
        ];
        if self.hub {
            self.leaves.append(Port(face=1, along=float(4 * dice.below(self.cols)) + 2.5, floor=0));
        }
        visitor.place(self);
    }

    """The maze cell a port opens into."""
    def port_cell(port: Port) -> list[int] {
        at = int(port.along) // 4;
        if port.face == 0 {
            return [self.cols - 1, at];
        }
        if port.face == 2 {
            return [0, at];
        }
        if port.face == 1 {
            return [at, self.rows - 1];
        }
        return [at, 0];
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        upper = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.room(1, 1, -9, self.long - 1, self.wide - 1, -1, variant=dice.below(3));
        above = maze_links(dice.derive("upper"), self.cols, self.rows, self.split);
        below = maze_links(dice.derive("lower"), self.cols, self.rows, 0);
        # The upper maze braided, so its ways loop; under it a drowned maze
        # braided more, or an open flooded cellar, pillars under the upper
        # maze's corners and here and there a wall.
        braid(dice.derive("braid"), above, self.cols, self.rows, 0.3, self.split);
        # Halls in the maze: blocks of two cells by two opened into one, the
        # post at their middle gone.
        halls: list[list[int]] = [];
        for index in range(2 + (1 if self.hub else 0)) {
            i = dice.below(self.cols - 1);
            j = dice.below(self.rows - 1);
            if self.split > 0 and (i + 1 == self.split) {
                continue;
            }
            above[0][i][j] = True;
            above[0][i][j + 1] = True;
            above[1][i][j] = True;
            above[1][i + 1][j] = True;
            halls.append([i + 1, j + 1]);
        }
        bare: list[list[int]] = [];
        if self.cellar {
            for i in range(self.cols) {
                for j in range(self.rows) {
                    below[0][i][j] = below[0][i][j] or not dice.chance(0.1);
                    below[1][i][j] = below[1][i][j] or not dice.chance(0.1);
                    if dice.chance(0.65) {
                        bare.append([i, j]);
                    }
                }
            }
        } else {
            braid(dice.derive("drown"), below, self.cols, self.rows, 0.5, 0);
        }
        ends = cut_maze(build, above, self.cols, self.rows, 0, self.tall, halls);
        drowned = cut_maze(build, below, self.cols, self.rows, -9, -1, bare);
        flood(build, 1, 1, -9, self.long - 1, self.wide - 1, -1);
        build.doorway(upper, self.enter);
        for port in self.taken {
            build.doorway(upper, port);
        }
        # The cells no well may take: those the ways open into.
        held: list[list[int]] = [self.port_cell(self.enter)] + [self.port_cell(port) for port in self.leaves];
        free = [end for end in ends if end not in held];
        picks: list[list[int]] = [];
        # A split maze wants a well on each side of its split.
        if self.split > 0 {
            for half in [[0, self.split], [self.split, self.cols]] {
                side = [end for end in free if half[0] <= end[0] and end[0] < half[1]];
                if side {
                    picks.append(side[dice.below(len(side))]);
                }
            }
        }
        for index in dice.order(len(free)) {
            if len(picks) >= self.wells {
                break;
            }
            if free[index] not in picks {
                picks.append(free[index]);
            }
        }
        for cell in picks {
            i = cell[0];
            j = cell[1];
            build.widen(upper, 4 * i + 1, 4 * j + 1, -1, 4 * i + 4, 4 * j + 4, 0);
            for mouth in dead_end_mouth(above, self.cols, self.rows, i, j) {
                build.keep(upper, mouth[0], mouth[1], 0);
            }
        }
        # A split with no well on a side is opened again across it.
        if self.split > 0 and len([cell for cell in picks if cell[0] < self.split]) * len([cell for cell in picks if cell[0] >= self.split]) == 0 {
            row = dice.below(self.rows);
            build.widen(upper, 4 * self.split, 4 * row + 1, 0, 4 * self.split + 1, 4 * row + 4, self.tall);
        }
        others = [end for end in free if end not in picks];
        # One dead end holds a teleporter back to the maze's mouth.
        if others and dice.chance(0.7) {
            pad = others.pop(dice.below(len(others)));
            build.teleporter(float(4 * pad[0]) + 2.5, float(4 * pad[1]) + 2.5, 0, 2.5, float(4 * self.way_in) + 2.5, 0, 0.0);
        }
        # The spawn in the dead ends wake as the player comes to the maze's
        # middle; a hell knight walks the longest run of it.
        mid_i = self.cols // 2;
        mid_j = self.rows // 2;
        roused = build.touch(float(4 * mid_i + 1), float(4 * mid_j + 1), 0.0, float(4 * mid_i + 4), float(4 * mid_j + 4), 6.0);
        stirred = build.waiting();
        roused +>:Fires:+> stirred;
        for (index, end) in enumerate(others[:dice.between(3, 5)]) {
            build.foe(float(4 * end[0]) + 2.5, float(4 * end[1]) + 2.5, 0, e4m6_foe(dice, self.danger, index == 0), float(90 * dice.below(4)), waits=stirred);
        }
        run = [0, 0, 0];
        for j in range(self.rows) {
            length = 0;
            for i in range(self.cols - 1) {
                length = length + 1 if above[0][i][j] else 0;
                if length > run[2] {
                    run = [i + 1, j, length];
                }
            }
        }
        if run[2] >= 1 {
            y = float(4 * run[1]) + 2.5;
            first_x = float(4 * (run[0] - run[2])) + 2.5;
            build.foe(first_x, y, 0, "monster_hell_knight" if self.danger > 0.4 else "monster_demon1", 0.0, patrol=[[first_x, y], [float(4 * run[0]) + 2.5, y]]);
        }
        # Fish in the drowned maze, and what lies there.
        for index in range(dice.between(1, 2) + (1 if self.hub else 0)) {
            build.foe(float(4 * dice.below(self.cols)) + 2.5, float(4 * dice.below(self.rows)) + 2.5, -8, "monster_fish", float(90 * dice.below(4)));
        }
        hiding = drowned if drowned else [[0, self.rows - 1], [self.cols - 1, 0], [self.cols - 1, self.rows - 1]];
        if hiding {
            hidden = hiding[dice.below(len(hiding))];
            build.secret(float(4 * hidden[0] + 1), float(4 * hidden[1] + 1), -9.0, float(4 * hidden[0] + 4), float(4 * hidden[1] + 4), -4.0);
            build.supply(float(4 * hidden[0]) + 2.5, float(4 * hidden[1]) + 2.5, -9, "item_artifact_super_damage" if dice.chance(0.5) else "item_armor2");
        }
        if picks {
            first = picks[0];
            build.supply(float(4 * first[0]) + 2.5, float(4 * first[1]) + 2.5, -9, "item_rockets");
        }
        build.supply(2.5, float(4 * self.way_in) + 3.0, 0, "item_spikes");
        build.supply(float(4 * mid_i) + 2.5, float(4 * mid_j) + 3.0, 0, "item_health");
        # In the labyrinth, a fiend is brought in behind the player at the
        # middle.
        if self.hub {
            roused +>:Fires:+> build.summon(1, 1, self.tall + 1, e4m6_foe(dice, self.danger, True), float(4 * mid_i) + 2.5, float(4 * mid_j) + 2.5, 0, 0.0);
        }
    }
}

"""A sunken court: a ledge in, galleries over arcades down its sides, a
ledge higher still at the far end; four buttons raise a stair to it."""
node ButtonCourt(Prefab) {
    has up: int = 8,
        top: int = 12,
        court: int = 22,
        far_ledge: int = 6,
        gallery: int = 4,
        both_galleries: bool = True,
        pool_here: bool = True,
        buttons: int = 0,
        lift_back: bool = True,
        lane: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Button court";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.up = dice.between(7, 8);
        self.top = self.up + 4;
        self.court = self.top + dice.between(9, 12);
        self.far_ledge = 6;
        self.gallery = 4;
        self.both_galleries = dice.chance(0.6);
        self.pool_here = dice.chance(0.65);
        self.buttons = dice.below(3);
        self.lift_back = dice.chance(0.6);
        self.wide = dice.between(20, 24);
        self.lane = dice.between(self.gallery + 3, self.wide - self.gallery - 7);
        self.tall = self.top + dice.between(9, 11);
        self.long = 1 + 5 + self.court + self.far_ledge + 1;
        self.low = -9;
        self.high = self.tall + 8;
        ex = self.long - 1 - self.far_ledge;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=self.up);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=self.top),
            Port(face=1, along=float(ex + 3), floor=self.top),
            Port(face=3, along=float(ex + 3), floor=self.top),
            Port(face=3, along=3.0, floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(court, self.up);
        build.level(court, self.top);
        near = 6;
        ex = self.long - 1 - self.far_ledge;
        g = self.gallery;
        # The near ledge, the far one higher still.
        build.solid(1, 1, 0, near, self.wide - 1, self.up);
        build.solid(ex, 1, 0, self.long - 1, self.wide - 1, self.top);
        # The galleries: slabs over arcades, stopping well short of the far
        # ledge (too far and too low to jump to it).
        gx1 = ex - 5;
        sides = [0, 1] if self.both_galleries else [dice.below(2)];
        for side in sides {
            y0 = 1 if side == 0 else self.wide - 1 - g;
            build.solid(near, y0, self.up - 1, gx1, y0 + g, self.up);
            inner = y0 + g - 1 if side == 0 else y0;
            for x in range(near + 3, gx1 - 1, 4) {
                build.solid(x, inner, 0, x + 1, inner + 1, self.up - 1);
            }
        }
        # The rising stair from the court floor to the far ledge, four wide.
        sx = ex - self.top;
        steps = build.rising_steps(sx, self.lane, 0, 0, self.top, 4);
        for y in range(self.lane, self.lane + 4) {
            build.keep(court, ex, y, self.top);
        }
        # Off the near ledge: a stretch of edge to drop from, and the lift
        # back up.
        lift_y = g + 2;
        drop_y = lift_y + 4;
        if self.lift_back {
            build.put_box({"classname": "func_plat", "height": str(self.up * 16), "speed": "150"}, float(near), float(lift_y), float(self.up) - 0.5, float(near + 3), float(lift_y + 3), float(self.up), kit_of(build.district).step);
            for y in range(lift_y - 1, lift_y + 4) {
                build.keep(court, near - 1, y, self.up);
                build.keep(court, near, y, 0);
            }
        } else {
            # A teleporter on the court floor back up to the near ledge.
            build.teleporter(float(near) + 1.5, float(lift_y) + 1.5, 0, 2.5, float(middle) + 0.5, self.up, 0.0);
        }
        for y in range(drop_y, drop_y + 4) {
            build.keep(court, near - 1, y, self.up);
        }
        # The pool in the court's middle, fish in it.
        px0 = near + 4;
        px1 = sx - 2;
        if self.pool_here and px1 - px0 >= 5 {
            # As deep as its steps out have room for.
            depth = min(8, max(self.wide - 2 * g - 6, px1 - px0));
            build.pool(px0, g + 3, -depth, px1, self.wide - g - 3, 0, 2, False, True, True);
            build.foe(float(px0 + px1) * 0.5, float(middle) + 0.5, 2 - depth, "monster_fish", 0.0);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # The four buttons: on the arcades' pillars, on the ledges' faces, or
        # on the court's walls under the galleries.
        spots: list[list[float]] = [];
        if self.buttons == 0 {
            for side in sides {
                for x in range(near + 3, gx1 - 1, 4) {
                    if side == 0 {
                        spots.append([float(x) + 0.5, float(g + 1), 1.0]);
                    } else {
                        spots.append([float(x) + 0.5, float(self.wide - 1 - g), 3.0]);
                    }
                }
            }
        } elif self.buttons == 1 {
            for y in [3, self.wide - 4] {
                spots.append([float(near), float(y) + 0.5, 0.0]);
            }
            for y in range(2, self.wide - 2, 3) {
                if y + 1 < self.lane - 1 or y > self.lane + 4 {
                    spots.append([float(ex), float(y) + 0.5, 2.0]);
                }
            }
        }
        if len(spots) < 4 {
            for x in range(near + 3, gx1, 3) {
                spots.append([float(x) + 0.5, 1.0, 1.0]);
                spots.append([float(x) + 0.5, float(self.wide - 1), 3.0]);
            }
        }
        count = build.tally(4, "The stair rises to the far ledge");
        for index in dice.order(len(spots))[:4] {
            spot = spots[index];
            build.push(spot[0], spot[1], 1.5, int(spot[2])) +>:Fires:+> count;
        }
        count +>:Fires:+> steps;
        build.touch(1.0, 1.0, float(self.up), float(near), float(self.wide - 1), float(self.up + 6), True, "Four buttons raise the way on");
        # Landing on the court wakes its spawn and the galleries' guards; the
        # stair's rising brings a hell knight onto the far ledge.
        landed = build.touch(float(near), float(drop_y - 1), 0.0, float(near + 3), float(drop_y + 5), 6.0);
        swarm = build.waiting();
        landed +>:Fires:+> swarm;
        for index in range(dice.between(3, 5)) {
            build.foe(float(near + 4 + index * 3) + 0.5, float(g + 2) + float(index % 2) * float(self.wide - 2 * g - 5), 0, e4m6_foe(dice, self.danger), 180.0, waits=swarm);
        }
        for side in sides {
            gy = 1.0 + float(g) * 0.5 if side == 0 else float(self.wide - 1) - float(g) * 0.5;
            build.foe(float(gx1) - 2.5, gy, self.up, e4m6_foe(dice, self.danger, True), 180.0, waits=swarm);
        }
        count +>:Fires:+> build.summon(ex + 1, 2, self.tall + 1, "monster_hell_knight", float(ex) + 3.0, float(middle) + 0.5, self.top, 180.0);
        build.foe(float(near) + 3.5, float(self.lane) + 1.5, 0, "monster_demon1" if self.danger < 0.5 else "monster_hell_knight", 0.0, patrol=[[float(near) + 3.5, float(self.lane) + 1.5], [float(sx) - 1.5, float(self.lane) + 1.5]]);
        build.supply(2.5, 2.5, self.up, "item_shells");
        build.supply(float(near) + 2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, self.top, "item_health");
        gy0 = 1.0 + float(g) * 0.5 if 0 in sides else float(self.wide - 1) - float(g) * 0.5;
        build.supply(float(gx1) - 1.5, gy0, self.up, "item_rockets");
    }
}

"""A hall over a pit, a bridge across it (or drawn out when a button is
shot), spawn at its foot or water in it; a gallery high along a wall."""
node SpawnPit(Prefab) {
    has deep: int = 9,
        near: int = 7,
        pit: int = 12,
        far: int = 8,
        drawn_bridge: bool = False,
        flooded: bool = False,
        gallery_here: bool = True,
        teleport_out: bool = False,
        hi: int = 9,
        lane: int = 7,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spawn pit";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.deep = dice.between(9, 10);
        self.near = dice.between(6, 8);
        self.pit = self.deep + dice.between(3, 5);
        self.drawn_bridge = dice.chance(0.4);
        self.flooded = dice.chance(0.35);
        self.gallery_here = dice.chance(0.7);
        self.teleport_out = dice.chance(0.4);
        self.hi = dice.between(9, 10);
        # The far floor holds the gallery's stair when there is one.
        self.far = self.hi + dice.between(2, 3) if self.gallery_here else dice.between(7, 9);
        self.wide = dice.between(17, 20);
        self.lane = dice.between(5, self.wide - 9);
        self.tall = self.hi + dice.between(9, 11);
        self.long = 1 + self.near + self.pit + self.far + 1;
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(4, self.wide - 8)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(4, self.wide - 8)), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.hi if self.gallery_here else 0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 1 + self.near;
        x1 = x0 + self.pit;
        g = 4;
        gy = self.wide - 1 - g;
        pit_y1 = gy if self.gallery_here else self.wide - 1;
        pit = build.room(x0, 1, -self.deep, x1, pit_y1, 0, variant=dice.below(3));
        build.level(pit, -self.deep);
        # The way up out of the pit to the near floor: a stair along its -y
        # wall, or a teleporter on its floor.
        if self.flooded or not self.teleport_out {
            stair(build, x0 + self.deep - 1, 1, -self.deep, 2, self.deep, 3);
            for y in range(1, 4) {
                build.keep(hall, x0 - 1, y, 0);
            }
        } else {
            build.teleporter(float(x0) + 2.5, 2.5, -self.deep, float(x0) - 2.5, 2.5, 0, 180.0);
        }
        if self.flooded {
            flood(build, x0, 1, -self.deep, x1, pit_y1, -self.deep + 5);
        }
        # The bridge across, four cells wide: there, or drawn out when the
        # button high on the far wall is shot.
        if self.drawn_bridge {
            shot = build.push(float(self.long - 1), float(self.lane) + 2.0, 9.0, 2, True);
            shot +>:Fires:+> build.drawn(float(x0), float(self.lane), float(x1), float(self.lane + 4), 0, self.deep + 1);
            build.touch(1.0, 1.0, 0.0, float(x0), float(self.wide - 1), 6.0, True, "Shoot the button across the pit");
        } else {
            build.solid(x0, self.lane, -1, x1, self.lane + 4, 0);
        }
        for across in range(4) {
            build.keep(hall, x0 - 1, self.lane + across, 0);
            build.keep(hall, x1, self.lane + across, 0);
        }
        # The gallery along the +y wall, a slab over the floors and the pit,
        # up a stair from the far floor.
        if self.gallery_here {
            build.solid(1, gy, self.hi - 1, self.long - 1, self.wide - 1, self.hi);
            build.level(hall, self.hi);
            stair(build, x1 + 1, gy - 3, 0, 0, self.hi, 3);
            for y in range(gy - 3, gy) {
                build.keep(hall, x1 + self.hi, y, self.hi);
            }
            for x in range(x1 + self.hi - 1, x1 + self.hi + 2) {
                build.keep(hall, x, gy, self.hi);
            }
            build.foe(float(x0) + 2.5, float(gy) + 2.0, self.hi, "monster_shalrath" if self.danger > 0.5 else "monster_hell_knight", 270.0);
            build.supply(3.5, float(gy) + 2.0, self.hi, "item_armor2" if dice.chance(0.3) else "item_rockets");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Halfway over, what lies at the pit's foot leaps out.
        halfway = build.touch(float(x0 + self.pit // 2 - 1), float(self.lane), 0.0, float(x0 + self.pit // 2 + 1), float(self.lane + 4), 6.0);
        leap = build.waiting();
        halfway +>:Fires:+> leap;
        if self.flooded {
            for index in range(dice.between(2, 3)) {
                build.foe(float(x0 + 3 + index * 3) + 0.5, float(pit_y1) - 2.5, -self.deep + 1, "monster_fish", 180.0);
            }
            for index in range(dice.between(2, 3)) {
                build.foe(float(x1) + 2.5, 3.5 + float(index) * 4.0, 0, e4m6_foe(dice, self.danger), 180.0, waits=leap);
            }
        } else {
            for index in range(3 + int(self.danger * 4.0) + dice.below(2)) {
                build.foe(float(x0 + 4 + (index * 3) % max(1, self.pit - 5)) + 0.5, float(pit_y1) - 2.5 - float(index % 2) * 3.0, -self.deep, "monster_tarbaby", 180.0, waits=leap);
            }
        }
        build.foe(float(x1) + 3.5, float(self.lane) + 1.5, 0, e4m6_foe(dice, self.danger, True), 180.0);
        build.foe(2.5, 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_demon1", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5 - (float(g) if self.gallery_here else 0.0)]]);
        build.supply(float(x0) + 1.5, 2.0, -self.deep, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""The key room: a tall cistern, a pool at its foot, the key on a ledge
high up reached by a slow lift or a stair winding up its walls."""
node SilverCistern(Prefab) {
    has key: str = "key_silver",
        ledge: int = 14,
        climb: int = 0,
        steps: int = 14,
        teleported: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.climb = dice.below(2);
        self.teleported = dice.chance(0.5);
        self.long = dice.between(20, 22);
        self.wide = dice.between(16, 18);
        if self.climb == 1 {
            path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
            fits: list[int] = [];
            for steps in range(12, 21) {
                if path[steps % len(path)][4] == 0 and path[(steps + 5) % len(path)][4] == 0 {
                    fits.append(steps);
                }
            }
            self.steps = fits[dice.below(len(fits))] if fits else 14;
            self.ledge = self.steps;
        } else {
            self.ledge = dice.between(13, 15);
        }
        self.tall = self.ledge + dice.between(8, 9);
        self.low = -10;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cistern = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cistern, self.ledge);
        build.doorway(cistern, self.enter);
        key_x = float(self.long) - 3.0;
        key_y = float(middle) + 0.5;
        under: list[list[float]] = [];
        if self.climb == 0 {
            # The ledge: a slab over the far end of the floor, and the slow
            # lift up to it.
            lx = self.long - 6;
            build.solid(lx, 1, self.ledge - 1, self.long - 1, self.wide - 1, self.ledge);
            build.put_box({"classname": "func_plat", "height": str(self.ledge * 16), "speed": "75"}, float(lx - 3), float(middle - 1), float(self.ledge) - 0.5, float(lx), float(middle + 2), float(self.ledge), kit_of(build.district).step);
            for y in range(middle - 2, middle + 3) {
                build.keep(cistern, lx, y, self.ledge);
                build.keep(cistern, lx - 4, y, 0);
            }
            build.pool(5, 4, -8, lx - 5, self.wide - 4, 0, 2, False, True, True);
            build.foe(float(lx) - 7.0, float(middle) + 0.5, -6, "monster_fish", 90.0);
            under = [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5], [float(lx) + 1.5, float(middle) + 3.5]];
        } else {
            # The stair winding up round the walls, its landing the ledge.
            landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
            top = landing[2];
            key_x = float(top[0] + top[2]) * 0.5;
            key_y = float(top[1] + top[3]) * 0.5;
            build.pool(6, 6, -8, self.long - 6, self.wide - 6, 0, 2, False, True, True);
            build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, -6, "monster_fish", 90.0);
            under = [[4.5, float(self.wide) - 3.5], [float(self.long) - 4.5, float(self.wide) - 3.5], [4.5, 4.5]];
        }
        key = build.cue([], "key");
        fields = {"classname": key_item(self.key), "asset_game": "q1"};
        key.items.append(fields);
        build.put_at(fields, key_x, key_y, self.ledge);
        # Taking the key brings spawn in about the floor below, or wakes what
        # lies in the shadows there.
        if self.teleported {
            for index in range(dice.between(2, 3)) {
                key +>:Fires:+> build.summon(3 + index * 4, 1, self.tall + 1, e4m6_foe(dice, self.danger, index == 0), 3.5 + float(index) * 2.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, 0.0);
            }
        } else {
            freed = build.waiting();
            key +>:Fires:+> freed;
            for (index, at) in enumerate(under) {
                build.foe(at[0], at[1], 0, e4m6_foe(dice, self.danger, index == 0), 180.0, waits=freed);
            }
        }
        build.foe(float(self.long) - 4.5, 3.5, self.ledge, e4m6_foe(dice, self.danger, True), 180.0);
        build.foe(4.5, float(self.wide) - 2.5, 0, "monster_hell_knight" if self.danger > 0.4 else "monster_demon1", 0.0, patrol=[[4.5, float(self.wide) - 2.5], [float(self.long) - 4.5, float(self.wide) - 2.5]]);
        build.supply(3.5, 3.5, 0, "item_health");
    }
}

"""A chapel, galleries over its aisles, the unholy altar on its dais; shot
till it breaks, it opens the way on (or, as the end, the slipgate)."""
node UnholyAltar(Prefab) {
    has key: str = "",
        ending: bool = False,
        gh: int = 9,
        gallery: int = 4,
        both_galleries: bool = True,
        pool_here: bool = False,
        lift_up: bool = False,
        hall: int = 0,
        nave: int = 26,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Unholy altar" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.gh = dice.between(9, 10);
        self.gallery = 4;
        self.both_galleries = dice.chance(0.6);
        self.pool_here = dice.chance(0.45);
        self.lift_up = dice.chance(0.35);
        self.hall = 9 if self.key else 0;
        self.nave = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.tall = self.gh + dice.between(10, 12);
        self.long = self.hall + self.nave + (8 if self.ending else 0);
        self.low = -9;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        if not self.ending {
            self.leaves = [
                Port(face=0, along=float(self.wide // 2), floor=2),
                Port(face=1, along=float(self.long - 5), floor=self.gh),
                Port(face=3, along=float(self.long - 5), floor=self.gh if self.both_galleries else 2)
            ];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        n0 = self.hall + 1;
        if self.key {
            hallway = build.room(1, middle - 4, 0, self.hall, middle + 4, 10, variant=dice.below(3));
            build.doorway(hallway, self.enter);
        }
        chapel_x1 = self.long - 1 - (8 if self.ending else 0);
        chapel = build.room(n0, 1, 0, chapel_x1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chapel, self.gh);
        if self.key {
            build.widen(chapel, self.hall, middle - 2, 0, n0, middle + 2, 8);
            build.rising_door(float(self.hall), float(middle - 2), 0.0, float(n0), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        } else {
            build.doorway(chapel, self.enter);
        }
        g = self.gallery;
        sides = [0, 1] if self.both_galleries else [1];
        # The galleries, slabs over the aisles, up a stair from the nave's
        # near end (or a lift).
        gx0 = n0 + self.gh;
        for side in sides {
            y0 = 1 if side == 0 else self.wide - 1 - g;
            build.solid(gx0, y0, self.gh - 1, chapel_x1, y0 + g, self.gh);
            inner = y0 + g - 1 if side == 0 else y0;
            for x in range(gx0 + 2, chapel_x1 - 2, 4) {
                build.solid(x, inner, 0, x + 1, inner + 1, self.gh - 1);
            }
            if self.lift_up {
                build.put_box({"classname": "func_plat", "height": str(self.gh * 16), "speed": "150"}, float(gx0 - 3), float(y0), float(self.gh) - 0.5, float(gx0), float(y0 + 3), float(self.gh), kit_of(build.district).step);
                for y in range(y0, y0 + 3) {
                    build.keep(chapel, gx0, y, self.gh);
                }
            } else {
                stair(build, n0, y0, 0, 0, self.gh, g);
                for y in range(y0, y0 + g) {
                    build.keep(chapel, gx0, y, self.gh);
                    build.keep(chapel, gx0 - 1, y, self.gh);
                }
            }
        }
        # The dais at the far end, two lifts up, and the altar on it.
        dais_x = chapel_x1 - 7;
        dy0 = 1 + g if 0 in sides else 1;
        build.solid(dais_x, dy0, 0, chapel_x1, self.wide - 1 - g, 1);
        build.solid(dais_x + 1, dy0, 1, chapel_x1, self.wide - 1 - g, 2);
        ax = dais_x + 3;
        build.solid(ax, middle - 1, 2, ax + 2, middle + 2, 4);
        fields = build.button(float(ax), float(middle) + 0.5, 2.3, 2, "", True);
        fields["health"] = str(30 + int(self.danger * 40.0));
        altar = build.cue([fields], "altar");
        # A pool of water across the nave, a bridge over it.
        if self.pool_here {
            px0 = gx0 + 2;
            px1 = min(dais_x - 3, px0 + 8);
            if px1 - px0 >= 5 {
                depth = min(8, px1 - px0);
                build.pool(px0, dy0 + 1, -depth, px1, self.wide - 2 - g, 0, 2, False, False);
                pool_steps(build, px0, dy0 + 1, depth, 2);
                pool_steps(build, px0, self.wide - 4 - g, depth, 2);
                build.solid(px0, middle - 2, -1, px1, middle + 2, 0);
                for across in range(-2, 2) {
                    build.keep(chapel, px0 - 1, middle + across, 0);
                    build.keep(chapel, px1, middle + across, 0);
                }
                build.foe(float(px0) + 2.5, float(middle) + 3.5, 2 - depth, "monster_fish", 0.0);
            }
        }
        build.touch(float(n0), float(middle - 3), 0.0, float(n0 + 3), float(middle + 3), 8.0, True, "An unholy altar! Shoot it repeatedly");
        defiled = told(build, 0.5, "The altar has been defiled.");
        altar +>:Fires:+> defiled;
        # The galleries' guards wake as it breaks.
        roused = build.waiting();
        defiled +>:Fires:+> roused;
        for side in sides {
            y = 1.0 + float(g) * 0.5 if side == 0 else float(self.wide - 1) - float(g) * 0.5;
            build.foe(float(chapel_x1) - 3.5, y, self.gh, "monster_shalrath" if self.danger > 0.4 else "monster_hell_knight", 180.0, waits=roused);
            build.foe(float(gx0) + 4.5, y, self.gh, e4m6_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(dais_x) - 4.5 + float(index), float(middle) + (4.5 if index % 2 == 0 else -3.5), 0, e4m6_foe(dice, self.danger), 180.0, waits=roused);
        }
        # And fiends are brought in behind the player, at the nave's foot.
        for index in range(1 + (1 if self.danger > 0.4 else 0)) {
            defiled +>:Fires:+> build.summon(n0 + 1 + index * 4, middle - 1, self.tall + 1, "monster_demon1", float(gx0) + 1.5 + float(index) * 2.0, float(middle) + 0.5, 0, 0.0);
        }
        # With one gallery, a secret door in the bare near corner opens with
        # it.
        if 0 not in sides and not self.key and dice.chance(0.8) {
            build.solid(n0, 1, 0, n0 + 3, 4, 6);
            build.room(n0, 1, 0, n0 + 2, 3, 4);
            defiled +>:Fires:+> fired_secret_door(build, float(n0 + 2), 1.0, 0.0, float(n0 + 3), 3.0, 4.0, 2);
            build.secret(float(n0), 1.0, 0.0, float(n0 + 2), 3.0, 3.0);
            build.supply(float(n0) + 1.0, 2.0, 0, "item_artifact_super_damage");
        }
        for port in self.taken {
            build.doorway(chapel, port);
        }
        # As a flow, the ways on open when the altar breaks.
        for port in onward_ports(self) {
            defiled +>:Fires:+> port_door(build, self, port);
        }
        if self.ending {
            # The sanctum behind the dais's back wall, opened as the altar
            # breaks; the slipgate in it.
            sanctum = build.room(chapel_x1 + 1, middle - 4, 2, self.long - 1, middle + 4, 12, variant=dice.below(3));
            build.widen(sanctum, chapel_x1, middle - 2, 2, chapel_x1 + 1, middle + 2, 10);
            defiled +>:Fires:+> build.opened(float(chapel_x1), float(middle - 2), 2.0, float(chapel_x1 + 1), float(middle + 2), 10.0);
            build.way_out(float(self.long) - 3.5, float(middle), 2);
            warned = build.touch(float(chapel_x1 + 1), float(middle - 4), 2.0, float(chapel_x1 + 3), float(middle + 4), 8.0, True, "Are you sure you want to exit?");
            warned +>:Fires:+> build.summon(chapel_x1 + 2, middle - 4, 13, "monster_hell_knight", float(dais_x) + 2.5, float(middle) + 0.5, 2, 0.0);
        }
        build.foe(float(n0) + 3.5, float(middle) + 3.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_demon1", 0.0, patrol=[[float(n0) + 3.5, float(middle) + 3.5], [float(dais_x) - 2.5, float(middle) + 3.5]]);
        build.supply(float(n0) + 1.5, float(middle) - 3.5, 0, "item_health");
        build.supply(float(chapel_x1) - 2.5, float(middle) + 3.5, 2, "item_rockets");
        if self.key {
            build.supply(2.5, float(middle) + 2.5, 0, "item_health");
        }
    }
}

"""e4m6's stretches: [name, role]."""
glob E4M6_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["maze", "flow"],
         ["labyrinth", "hub"],
         ["court", "flow"],
         ["court", "hub"],
         ["pit", "flow"],
         ["altar", "flow"],
         ["cistern", "keyroom"],
         ["altar_end", "end"],
         ["altar_end", "gate"]
     ];

"""One of e4m6's stretches by its name."""
def make_e4m6(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PainGate();
    }
    if name == "maze" {
        return FloodedMaze(cols=5, rows=4);
    }
    if name == "labyrinth" {
        return FloodedMaze(cols=6, rows=5, hub=True);
    }
    if name == "court" {
        return ButtonCourt();
    }
    if name == "pit" {
        return SpawnPit();
    }
    if name == "altar" {
        return UnholyAltar();
    }
    if name == "cistern" {
        return SilverCistern(key=key if key else "key_silver");
    }
    return UnholyAltar(key=key, ending=True);
}
