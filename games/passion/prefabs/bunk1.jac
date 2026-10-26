"""Prefabs drawn from Quake II's bunk1, the Ammo Depot: a depot of loading
docks and crate stacks, a warehouse climbed crate by crate to a high
way out, a hall with cargo lifts up to its mezzanine, the key in an
armory opened by a button. Raised in bunk1's own palette.

- `LoadingDock`: the start. A yard, a dock raised along its far end up
  ramps, crates about; ways on from the dock and the yard.
- `CrateStacks`: a warehouse, crates stacked in a climb from the floor to
  a high door at its far end; ways on from both.
- `CargoLifts`: a hall, a mezzanine across its far half, cargo lifts up to
  it; ways on from the floor and the mezzanine (a hub).
- `ArmoryVault`: the key in an armory behind a door a button on the wall
  opens; taking it opens the closets.
- `DepotExit`: the end. A door (a key's, as a gate), a ramp up to a dock,
  the way out on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob BUNK1: str = "q2:bunk1";

"""bunk1's foes: soldiers and berserkers, enforcers deeper in."""
def bunk1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_soldier_ss"] if heavy else ["monster_soldier", "monster_soldier_ss", "monster_soldier_light"], ["monster_gladiator"] if heavy else ["monster_berserk", "monster_infantry"], danger));
}

"""Crates: boxes of one to three lifts at the given cells ([x, y] each,
a crate two cells square)."""
def crates(build: Raising, dice: Stream, spots: list[list[int]], z: int) {
    for spot in spots {
        build.solid(spot[0], spot[1], z, spot[0] + 2, spot[1] + 2, z + dice.between(2, 3));
    }
}

"""The start: a yard, a dock raised along its far end up ramps."""
node LoadingDock(Prefab) {
    has dock: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Loading dock";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.dock = dice.between(3, 4);
        self.tall = dice.between(15, 17);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.dock), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(yard, self.dock);
        dx = self.long - 7;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, 2, 0, 0, self.dock, 3);
        stair(build, dx - self.dock, self.wide - 5, 0, 0, self.dock, 3);
        for y in [2, 3, 4, self.wide - 5, self.wide - 4, self.wide - 3] {
            build.keep(yard, dx, y, self.dock);
        }
        crates(build, dice, [[12, 3], [12, self.wide - 5], [15, middle - 1]], 0);
        crates(build, dice, [[dx + 2, 1], [dx + 2, self.wide - 3]], self.dock);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(dx) - 6.5 + float(index % 2) * 2.0, 4.5 + float(index) * 4.0, 0, bunk1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.dock, bunk1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.dock, Q2_HEALTH, "q2");
    }
}

"""A warehouse, crates stacked in a climb from the floor to a high door at
its far end."""
node CrateStacks(Prefab) {
    has top: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crate stacks";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.top = dice.between(7, 9);
        self.tall = self.top + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 4), floor=self.top), Port(face=0, along=4.0, floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        house = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(house, self.top);
        # The climb: crates two cells square along the north wall, each a
        # lift higher than the last, to a deck of crates at the far end.
        deck = self.long - 6;
        build.solid(deck, self.wide - 7, 0, self.long - 1, self.wide - 1, self.top);
        x = deck - 2;
        z = self.top - 1;
        while z > 0 and x > 3 {
            build.solid(x, self.wide - 4, 0, x + 2, self.wide - 1, z);
            x -= 2;
            z -= 1;
        }
        crates(build, dice, [[6, 3], [10, 5], [14, 2], [18, 4]], 0);
        build.doorway(house, self.enter);
        for port in self.taken {
            build.doorway(house, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + 0.5, 0, bunk1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 3.0, float(self.wide) - 4.5, self.top, bunk1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.top, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall, a mezzanine across its far half, cargo lifts up to it."""
node CargoLifts(Prefab) {
    has mezzanine: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cargo lifts";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.mezzanine = dice.between(7, 8);
        self.tall = self.mezzanine + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.mezzanine),
            Port(face=1, along=float(self.long - 5), floor=self.mezzanine),
            Port(face=3, along=8.0, floor=0),
            Port(face=1, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.mezzanine);
        mx = self.long // 2;
        build.solid(mx, 1, self.mezzanine - 1, self.long - 1, self.wide - 1, self.mezzanine);
        step = kit_of(build.district).step;
        for y0 in [3, self.wide - 7] {
            build.put_box({"classname": "func_plat", "height": str(self.mezzanine * 16), "speed": "150"}, float(mx - 4), float(y0), float(self.mezzanine) - 0.5, float(mx), float(y0 + 4), float(self.mezzanine), step);
            for y in range(y0, y0 + 4) {
                build.keep(hall, mx, y, self.mezzanine);
            }
        }
        for x in range(mx + 3, self.long - 2, 4) {
            build.solid(x, middle - 1, 0, x + 1, middle, self.mezzanine - 1);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, bunk1_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long - 4 - index * 5) + 0.5, float(middle) + 3.5, self.mezzanine, bunk1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, self.mezzanine, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""The key in an armory behind a door a button on the wall opens; taking it
opens the closets."""
node ArmoryVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Armory vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(11, 13);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The armory: the far end walled off, a door through its wall that
        # the button by it opens.
        ax = self.long - 7;
        build.solid(ax, 1, 0, ax + 1, side, self.tall);
        armory = build.name("armory");
        build.widen(hall, ax, cy - 2, 0, ax + 1, cy + 2, 7);
        build.rising_door(float(ax), float(cy - 2), 0.0, float(ax + 1), float(cy + 2), 7.0, {"targetname": armory, "wait": "-1"});
        build.button(float(ax), float(cy) + 4.5, 1.3, 2, armory);
        crates(build, dice, [[4, 2], [8, side - 3]], 0);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [3, ax - 5], [bunk1_foe(dice, self.danger, True), bunk1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, 0, bunk1_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(side) - 2.5, 0, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a ramp up to a dock, the way out on it."""
node DepotExit(Prefab) {
    has key: str = "",
        dock: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Depot exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.dock = dice.between(3, 4);
        self.tall = dice.between(13, 15);
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
        dx = self.long - 7;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, middle - 2, 0, 0, self.dock, 4);
        build.way_out(float(self.long) - 3.5, float(middle), self.dock);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, bunk1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 4.5, 2.5, 0, bunk1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""bunk1's stretches: [name, role]."""
glob BUNK1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["crates", "flow"],
         ["lifts", "hub"],
         ["lifts", "flow"],
         ["armory", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of bunk1's stretches by its name."""
def make_bunk1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return LoadingDock();
    }
    if name == "crates" {
        return CrateStacks();
    }
    if name == "lifts" {
        return CargoLifts();
    }
    if name == "armory" {
        return ArmoryVault(key=key if key else "key_silver");
    }
    return DepotExit(key=key);
}
