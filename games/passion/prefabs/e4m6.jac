"""Prefabs drawn from e4m6, the Pain Maze: mazes of narrow passages cut a
new way each time, spawn waiting in their dead ends, a hall of shallow
water crossed on stepping blocks, the key at a maze's far corner.
Raised in e4m6's own palette.

- `PainGate`: the start. A hall, shallow water across it on blocks, the
  ways on from three sides.
- `PainMaze`: a maze of three-cell passages, a new one each seed (a
  random depth-first walk over its grid); the way in on its near side, the
  ways on round the others. Small as a flow, large as a hub.
- `MazeHeart`: a small maze, the key in its far corner; taking the key
  opens the closets along its far wall.
- `MazeExit`: the end. A door (a key's, as a gate) into a hall, the
  slipgate on a dais at its far end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush }

glob E4M6: str = "q1:e4m6";

"""e4m6's foes: spawn above all, fiends and hell knights, vores deeper in."""
def e4m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_demon1"] if heavy else ["monster_tarbaby", "monster_tarbaby", "monster_demon1"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""A perfect maze over a grid of `cols` by `rows` cells, by a random walk
that goes deeper while it can and backs up when it cannot: [east, north],
where east[i][j] says the cell (i, j) opens to (i + 1, j) and north[i][j]
that it opens to (i, j + 1)."""
def maze_walk(dice: Stream, cols: int, rows: int) -> list[list[list[bool]]] {
    east: list[list[bool]] = [[False for row in range(rows)] for col in range(cols)];
    north: list[list[bool]] = [[False for row in range(rows)] for col in range(cols)];
    seen: list[list[bool]] = [[False for row in range(rows)] for col in range(cols)];
    first = dice.below(rows);
    seen[0][first] = True;
    trail: list[list[int]] = [[0, first]];
    while trail {
        cell = trail[-1];
        i = cell[0];
        j = cell[1];
        options: list[list[int]] = [];
        if i + 1 < cols and not seen[i + 1][j] {
            options.append([i + 1, j, 0]);
        }
        if i > 0 and not seen[i - 1][j] {
            options.append([i - 1, j, 2]);
        }
        if j + 1 < rows and not seen[i][j + 1] {
            options.append([i, j + 1, 1]);
        }
        if j > 0 and not seen[i][j - 1] {
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
        seen[pick[0]][pick[1]] = True;
        trail.append([pick[0], pick[1]]);
    }
    return [east, north];
}

"""Cut a maze of `cols` by `rows` cells into a space: each cell three cells
of air square, a cell of wall between it and the next unless the walk
opened them. Answers the cells with one way out of them, the dead ends
([i, j] each)."""
def cut_maze(build: Raising, dice: Stream, cols: int, rows: int, high: int) -> list[list[int]] {
    links = maze_walk(dice, cols, rows);
    east = links[0];
    north = links[1];
    for i in range(1, cols) {
        for j in range(1, rows) {
            build.solid(4 * i, 4 * j, 0, 4 * i + 1, 4 * j + 1, high);
        }
    }
    for i in range(cols) {
        for j in range(rows) {
            if i + 1 < cols and not east[i][j] {
                build.solid(4 * i + 4, 4 * j + 1, 0, 4 * i + 5, 4 * j + 4, high);
            }
            if j + 1 < rows and not north[i][j] {
                build.solid(4 * i + 1, 4 * j + 4, 0, 4 * i + 4, 4 * j + 5, high);
            }
        }
    }
    ends: list[list[int]] = [];
    for i in range(cols) {
        for j in range(rows) {
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
            if ways == 1 {
                ends.append([i, j]);
            }
        }
    }
    return ends;
}

"""The start: a hall, shallow water across it on blocks."""
node PainGate(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain gate";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(13, 15);
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 7;
        x1 = self.long - 8;
        build.pool(x0, 1, -2, x1, self.wide - 1, 0, 2, False, True, True);
        for x in range(x0 + 1, x1 - 1, 2) {
            build.solid(x, middle - 1, -2, x + 1, middle + 1, 0);
        }
        stair(build, x1 - 2, middle - 1, -2, 0, 2, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 3.5, 3.5 + float(index) * 4.0, 0, e4m6_foe(dice, self.danger), 180.0);
        }
        build.foe(float(x1) + 4.5, float(self.wide) - 3.5, 0, e4m6_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A maze of three-cell passages, a new one each seed."""
node PainMaze(Prefab) {
    has cols: int = 6,
        rows: int = 4,
        way_in: int = 1,
        tall: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain maze";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.long = 4 * self.cols + 1;
        self.wide = 4 * self.rows + 1;
        self.tall = dice.between(8, 9);
        self.low = -1;
        self.high = self.tall + 1;
        self.way_in = dice.below(self.rows);
        self.enter = Port(face=2, along=float(4 * self.way_in) + 2.5, floor=0);
        out_row = dice.below(self.rows);
        self.leaves = [
            Port(face=0, along=float(4 * out_row) + 2.5, floor=0),
            Port(face=1, along=float(4 * dice.below(self.cols)) + 2.5, floor=0),
            Port(face=3, along=float(4 * dice.below(self.cols)) + 2.5, floor=0),
            Port(face=0, along=float(4 * ((out_row + 2) % self.rows)) + 2.5, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        maze = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        ends = cut_maze(build, dice, self.cols, self.rows, self.tall);
        build.doorway(maze, self.enter);
        for port in self.taken {
            build.doorway(maze, port);
        }
        count = min(len(ends), dice.between(3, 5));
        for index in range(count) {
            end = ends[(index * 7 + 3) % len(ends)];
            if end[0] == 0 and end[1] == self.way_in {
                continue;
            }
            build.foe(float(4 * end[0]) + 2.5, float(4 * end[1]) + 2.5, 0, e4m6_foe(dice, self.danger, index == 0), 0.0);
            if index % 2 == 1 {
                build.supply(float(4 * end[0]) + 2.0, float(4 * end[1]) + 3.0, 0, "item_health");
            }
        }
        build.supply(2.5, float(4 * self.way_in) + 3.0, 0, "item_spikes");
    }
}

"""A small maze, the key in its far corner; taking it opens the closets
along its far wall."""
node MazeHeart(Prefab) {
    has key: str = "key_gold",
        cols: int = 4,
        rows: int = 3,
        hall_wide: int = 13,
        tall: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Maze heart (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.cols = dice.between(4, 5);
        self.rows = 3;
        self.long = 4 * self.cols + 1;
        self.hall_wide = 4 * self.rows + 1;
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(8, 9);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=2.5, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        maze = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        cut_maze(build, dice, self.cols, self.rows, self.tall);
        build.doorway(maze, self.enter);
        key_ambush(build, self.key, float(self.long) - 3.0, 3.0, 0, side, 0, [1, 4 * (self.cols - 2) + 1], [e4m6_foe(dice, self.danger, True), e4m6_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, float(side) - 3.0, 0, e4m6_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a hall, the slipgate on a dais at its far end."""
node MazeExit(Prefab) {
    has key: str = "",
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Maze exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M6;
        self.district = level_district(E4M6);
        self.long = dice.between(25, 27);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(11, 13);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # Baffles across the room, a gap at alternate ends.
        for (index, x) in enumerate([wall + 4, wall + 8]) {
            if index % 2 == 0 {
                build.solid(x, 1, 0, x + 1, self.wide - 5, self.tall);
            } else {
                build.solid(x, 5, 0, x + 1, self.wide - 1, self.tall);
            }
        }
        dais_x = self.long - 5;
        build.solid(dais_x, 2, 0, self.long - 1, self.wide - 2, 2);
        stair(build, dais_x - 2, middle - 2, 0, 0, 2, 4);
        build.way_out(float(self.long) - 2.5, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m6_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall + 10) + 0.5, 2.5, 0, e4m6_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m6's stretches: [name, role]."""
glob E4M6_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["maze", "flow"],
         ["labyrinth", "hub"],
         ["labyrinth", "flow"],
         ["heart", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m6's stretches by its name."""
def make_e4m6(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PainGate();
    }
    if name == "maze" {
        return PainMaze(cols=6, rows=4);
    }
    if name == "labyrinth" {
        return PainMaze(cols=7, rows=6);
    }
    if name == "heart" {
        return MazeHeart(key=key if key else "key_gold");
    }
    return MazeExit(key=key);
}
