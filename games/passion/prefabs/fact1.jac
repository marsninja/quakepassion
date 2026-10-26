"""Prefabs drawn from Quake II's fact1, the Receiving Center: a factory's
docks over channels of slime, conveyors climbing one over another, a
processing floor of vats under a catwalk ring, the key in a shipping
office up a lift. Raised in fact1's own palette.

- `ReceivingDock`: the start. A dock, a channel of slime across it bridged
  twice, the factory's doors beyond; ways on from the far side.
- `SorterBelts`: two conveyors raised along a hall, the second over the
  first, ramps up each at opposite ends; ways on from the floor and the
  upper belt's end.
- `ProcessingFloor`: a floor of slime vats, a catwalk ring over it ridden
  up to by a lift; ways on from the floor and the catwalk (a hub).
- `ShippingOffice`: the key in an office up a lift over a store of crates;
  taking it opens the closets.
- `Fact1Exit`: the end. A door (a key's, as a gate), a loading bay, the way
  out on its dock."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }
import from .bunk1 { crates }

glob FACT1: str = "q2:fact1";

"""fact1's foes: soldiers and gunners, berserkers and hovers, a gladiator
deeper in."""
def fact1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_soldier_ss", "monster_gunner", "monster_soldier"], ["monster_gladiator"] if heavy else ["monster_hover", "monster_parasite"], danger * 0.5 if heavy else danger * 0.7));
}

"""The start: a dock, a channel of slime across it bridged twice."""
node ReceivingDock(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Receiving dock";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(15, 17);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        dock = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        cx = 11;
        build.pool(cx, 1, -3, cx + 5, self.wide - 1, 0, 3, False, True);
        stair(build, cx + 2, self.wide - 3, -3, 0, 3, 2);
        for y in [4, self.wide - 7] {
            build.solid(cx, y, -1, cx + 5, y + 3, 0);
            for along in range(y, y + 3) {
                build.keep(dock, cx - 1, along, 0);
                build.keep(dock, cx + 5, along, 0);
            }
        }
        crates(build, dice, [[4, 3], [4, self.wide - 5], [cx + 8, middle - 1]], 0);
        build.doorway(dock, self.enter);
        for port in self.taken {
            build.doorway(dock, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx + 7 + index % 2 * 4) + 0.5, 3.5 + float(index) * 4.0, 0, fact1_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""Two conveyors raised along a hall, the second over the first, ramps up
each at opposite ends."""
node SorterBelts(Prefab) {
    has first: int = 4,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sorter belts";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.first = dice.between(3, 4);
        self.tall = 2 * self.first + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=2 * self.first), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        f = self.first;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, f);
        build.level(hall, 2 * f);
        # The first belt down the middle, a ramp up its near end; the second
        # along the north wall over it, a ramp up from the first's far end.
        build.solid(4 + f, middle - 2, 0, self.long - 6, middle + 1, f);
        stair(build, 4, middle - 2, 0, 0, f, 3);
        build.solid(4, self.wide - 4, 2 * f - 1, self.long - 1, self.wide - 1, 2 * f);
        stair(build, self.long - 6, middle - 2, f, 1, f, 3);
        build.solid(self.long - 6, middle - 2 + f, f, self.long - 3, self.wide - 4, 2 * f);
        for x in range(self.long - 6, self.long - 3) {
            build.keep(hall, x, self.wide - 5, 2 * f);
        }
        crates(build, dice, [[8 + f, middle - 2], [14 + f, middle - 1]], f);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, 2.5, 0, fact1_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) - 0.5, f, fact1_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 4.0, float(self.wide) - 2.5, 2 * f, fact1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 2 * f, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A floor of slime vats, a catwalk ring over it ridden up to by a lift."""
node ProcessingFloor(Prefab) {
    has walk: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Processing floor";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(7, 8);
        self.tall = self.walk + 10;
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        floor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(floor, self.walk);
        for vx in range(7, self.long - 8, 7) {
            for vy in [5, self.wide - 10] {
                build.pool(vx, vy, -2, vx + 5, vy + 5, 0, 3);
            }
        }
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(1, 4, under, 4, self.wide - 4, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        lift(build, 4, middle - 1, 7, middle + 2, 0, self.walk);
        for y in range(middle - 2, middle + 3) {
            build.keep(floor, 3, y, self.walk);
        }
        build.doorway(floor, self.enter);
        for port in self.taken {
            build.doorway(floor, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 5) + 0.5, float(middle) + 0.5, 0, fact1_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 5) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, self.walk, fact1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, 6.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an office up a lift over a store of crates; taking it opens
the closets."""
node ShippingOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shipping office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(6, 7);
        self.tall = self.office + 8;
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
        store = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(store, self.office);
        build.doorway(store, self.enter);
        ox = self.long - 6;
        build.solid(ox, 1, self.office - 1, self.long - 1, side, self.office);
        lift(build, ox - 3, cy - 1, ox, cy + 2, 0, self.office);
        for y in range(cy - 2, cy + 3) {
            build.keep(store, ox, y, self.office);
        }
        crates(build, dice, [[5, 2], [5, side - 3], [9, 4], [ox - 5, side - 4]], 0);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.office, side, 0, [2, ox - 3], [fact1_foe(dice, self.danger, True), fact1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.office, fact1_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(cy) + 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a loading bay, the way out on its dock."""
node Fact1Exit(Prefab) {
    has key: str = "",
        dock: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Receiving exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
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
        dx = self.long - 6;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, middle - 2, 0, 0, self.dock, 4);
        build.way_out(float(self.long) - 3.0, float(middle), self.dock);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, fact1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 4.0, 2.5, 0, fact1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact1's stretches: [name, role]."""
glob FACT1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["belts", "flow"],
         ["processing", "hub"],
         ["processing", "flow"],
         ["office", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact1's stretches by its name."""
def make_fact1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return ReceivingDock();
    }
    if name == "belts" {
        return SorterBelts();
    }
    if name == "processing" {
        return ProcessingFloor();
    }
    if name == "office" {
        return ShippingOffice(key=key if key else "key_silver");
    }
    return Fact1Exit(key=key);
}
