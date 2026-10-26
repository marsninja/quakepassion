"""Prefabs drawn from Quake II's ware1, the Warehouse: a yard between rows
of crates, a hall with a conveyor raised down its length, a bay crossed
high up by a crane's gantry, the key (Quake II's power cube there) in a
vault of shelves. Raised in ware1's own palette.

- `CrateYard`: the start. A yard, rows of crates across it with lanes
  between; ways on from the yard's sides and far end.
- `ConveyorHall`: a hall, a conveyor raised down its middle up ramps at
  both ends, crates on it; ways on from the floor and the conveyor's end.
- `CraneBay`: a tall bay, a gantry across it high up reached by a stair up
  one wall; ways on from the floor and both ends of the gantry (a hub).
- `ShelfVault`: the key at the end of a vault of shelves, a lift up to the
  top shelf where it lies; taking it opens the closets.
- `WarehouseExit`: the end. A door (a key's, as a gate), a loading bay,
  the way out on its dock."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }
import from .bunk1 { crates }

glob WARE1: str = "q2:ware1";

"""ware1's foes: soldiers and gunners, berserkers growing with the danger."""
def ware1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_soldier_ss", "monster_soldier_light", "monster_infantry"], ["monster_gladiator"] if heavy else ["monster_gunner", "monster_berserk"], danger));
}

"""The start: a yard, rows of crates across it with lanes between."""
node CrateYard(Prefab) {
    has tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crate yard";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(16, 20);
        self.low = -1;
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
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        # Rows of crates across the yard, a lane through each row at a
        # different place.
        for (index, x) in enumerate(range(7, self.long - 7, 5)) {
            gap = 3 + dice.below(self.wide - 9);
            for y in range(1, self.wide - 1, 2) {
                if y + 2 <= gap or y >= gap + 4 {
                    build.solid(x, y, 0, x + 2, min(y + 2, self.wide - 1), dice.between(2, 4));
                }
            }
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(10 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, ware1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, ware1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall, a conveyor raised down its middle up ramps at both ends, crates
on it."""
node ConveyorHall(Prefab) {
    has belt: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Conveyor hall";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.belt = dice.between(3, 5);
        self.tall = self.belt + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.belt), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.belt);
        # The conveyor: four cells wide down the middle, a ramp up at its
        # near end, running to the far wall.
        bx = 4 + self.belt;
        build.solid(bx, middle - 2, 0, self.long - 1, middle + 2, self.belt);
        stair(build, 4, middle - 2, 0, 0, self.belt, 4);
        crates(build, dice, [[bx + 4, middle - 2], [bx + 10, middle]], self.belt);
        for x in range(bx + 2, self.long - 2, 5) {
            build.solid(x, middle - 3, 0, x + 1, middle - 2, self.belt + 1);
            build.solid(x, middle + 2, 0, x + 1, middle + 3, self.belt + 1);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx + 3 + index * 5) + 0.5, 3.5 if index % 2 == 0 else float(self.wide) - 3.5, 0, ware1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, self.belt, ware1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(bx) + 1.5, float(middle) + 0.5, self.belt, "ammo_bullets", "q2");
    }
}

"""A tall bay, a gantry across it high up reached by a stair up one wall."""
node CraneBay(Prefab) {
    has gantry: int = 10,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crane bay";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.gantry = dice.between(9, 11);
        self.tall = self.gantry + 10;
        self.low = -1;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=1, along=cx, floor=self.gantry),
            Port(face=0, along=5.0, floor=0),
            Port(face=3, along=cx, floor=self.gantry),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        middle = self.wide // 2;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, self.gantry);
        # The gantry: north to south across the bay's middle, a walk from
        # its south end along to the east wall, where a stair climbs up the
        # wall from its north end to the walk.
        build.solid(cx - 2, 1, self.gantry - 1, cx + 2, self.wide - 1, self.gantry);
        build.solid(cx + 2, 1, self.gantry - 1, self.long - 1, 4, self.gantry);
        for step in range(self.gantry) {
            y = self.wide - 2 - step;
            build.solid(self.long - 4, y, max(0, step - 2), self.long - 1, y + 1, step + 1);
        }
        build.solid(self.long - 4, 1, self.gantry - 1, self.long - 1, self.wide - 1 - self.gantry, self.gantry);
        for x in range(cx - 2, cx + 2) {
            build.keep(bay, x, 4, self.gantry);
        }
        crates(build, dice, [[5, 4], [5, self.wide - 6], [cx - 6, middle - 1]], 0);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, ware1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(middle) + 0.5, self.gantry, ware1_foe(dice, self.danger, True), 90.0);
        build.supply(float(cx) + 0.5, 2.5, self.gantry, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key at the end of a vault of shelves, a lift up to the top shelf
where it lies; taking it opens the closets."""
node ShelfVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        shelf: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shelf vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.shelf = dice.between(5, 7);
        self.tall = self.shelf + 7;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, self.shelf);
        build.doorway(vault, self.enter);
        # Shelves: rows along the room, the top shelf at the far end the lift
        # rises beside.
        for y in [3, side - 4] {
            build.solid(5, y, 0, self.long - 7, y + 1, self.shelf - 2);
        }
        sx = self.long - 5;
        build.solid(sx, 1, self.shelf - 1, self.long - 1, side, self.shelf);
        build.put_box({"classname": "func_plat", "height": str(self.shelf * 16), "speed": "200"}, float(sx - 3), float(cy - 1), float(self.shelf) - 0.5, float(sx), float(cy + 2), float(self.shelf), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(vault, sx, y, self.shelf);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.shelf, side, 0, [2, sx - 6], [ware1_foe(dice, self.danger, True), ware1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.shelf, ware1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a loading bay, the way out on its dock."""
node WarehouseExit(Prefab) {
    has key: str = "",
        dock: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Warehouse exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.dock = dice.between(3, 4);
        self.tall = dice.between(15, 17);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        dx = self.long - 6;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, 2, 0, 0, self.dock, 3);
        crates(build, dice, [[wall + 4, 3], [wall + 7, self.wide - 5]], 0);
        build.way_out(float(self.long) - 3.0, float(middle), self.dock);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, ware1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 3.5, float(middle) + 3.5, 0, ware1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""ware1's stretches: [name, role]."""
glob WARE1_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["conveyor", "flow"],
         ["crane", "hub"],
         ["crane", "flow"],
         ["shelves", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of ware1's stretches by its name."""
def make_ware1(name: str, key: str) -> Prefab {
    if name == "yard" {
        return CrateYard();
    }
    if name == "conveyor" {
        return ConveyorHall();
    }
    if name == "crane" {
        return CraneBay();
    }
    if name == "shelves" {
        return ShelfVault(key=key if key else "key_silver");
    }
    return WarehouseExit(key=key);
}
