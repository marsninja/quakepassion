"""Prefabs drawn from Quake II's ware2, the Warehouse's back end: a truck bay
with a ramp up to its loading floor, a row of offices off a corridor with
one more up a stair, storage racks walked along their tops, the key in a
foreman's office looking down on a storeroom. Raised in ware2's own
palette.

- `TruckBay`: the start. A bay, trucks parked in it, a ramp up to the
  loading floor across its far end; ways on from the floor and the bay.
- `OfficeRow`: a corridor, offices open off both sides, a hall at its far
  end and a stair up to an office across it; ways on from the hall and
  the office.
- `StorageRacks`: a storeroom of racks, planks across between their tops,
  stairs up to them; ways on from the floor and the racks' tops (a hub).
- `ForemanOffice`: the key in an office up a stair, looking down on a
  storeroom; taking it opens the closets below.
- `Ware2Exit`: the end. A door (a key's, as a gate), a freight bay, the
  way out on its lift's platform."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }
import from .bunk1 { crates }

glob WARE2: str = "q2:ware2";

"""ware2's foes: infantry and parasites, berserkers and gunners, a tank
deeper in."""
def ware2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_infantry", "monster_infantry", "monster_parasite"], ["monster_tank"] if heavy else ["monster_berserk", "monster_soldier_ss"], danger * 0.5 if heavy else danger));
}

"""The start: a bay, trucks parked in it, a ramp up to the loading floor."""
node TruckBay(Prefab) {
    has floor_at: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Truck bay";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.floor_at = dice.between(4, 5);
        self.tall = dice.between(17, 19);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.floor_at), Port(face=1, along=float(self.long - 4), floor=self.floor_at), Port(face=3, along=10.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, self.floor_at);
        fx = self.long - 8;
        build.solid(fx, 1, 0, self.long - 1, self.wide - 1, self.floor_at);
        stair(build, fx - self.floor_at, self.wide - 5, 0, 0, self.floor_at, 4);
        for y in range(self.wide - 5, self.wide - 1) {
            build.keep(bay, fx, y, self.floor_at);
        }
        # Trucks: a cab and a box each, nose to the loading floor.
        for y0 in [3, middle + 1] {
            build.solid(fx - 9, y0, 0, fx - 2, y0 + 3, 4);
            build.solid(fx - 12, y0, 0, fx - 9, y0 + 3, 3);
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(fx - 14 + index % 2 * 2) + 0.5, 2.5 + float(index) * 4.0, 0, ware2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, self.floor_at, ware2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.floor_at, Q2_HEALTH, "q2");
    }
}

"""A corridor, offices open off both sides, a stair up to an office over
its far end."""
node OfficeRow(Prefab) {
    has upper: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Office row";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.upper = dice.between(6, 7);
        self.tall = self.upper + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.upper), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        corridor = build.room(1, middle - 2, 0, self.long - 1, middle + 3, 8, variant=dice.below(3));
        # Offices: rooms off both sides, each open to the corridor.
        index = 0;
        hx = self.long - 12;
        for x in range(2, hx - 5, 6) {
            for south in [True, False] {
                y0 = 1 if south else middle + 4;
                y1 = middle - 3 if south else self.wide - 1;
                office = build.room(x, y0, 0, x + 5, y1, 7, variant=dice.below(3));
                door_y = middle - 3 if south else middle + 3;
                build.widen(office, x + 1, door_y, 0, x + 4, door_y + 1, 6);
                build.solid(x + 1, y0 + 1, 0, x + 4, y0 + 2, 2);
                if index % 2 == 0 {
                    build.foe(float(x) + 2.5, float(y0 + y1) * 0.5, 0, ware2_foe(dice, self.danger), 90.0 if south else 270.0);
                }
                index += 1;
            }
        }
        # The far end: a hall full height, a stair up its north wall to an
        # office across its far end.
        build.room(hx, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.solid(self.long - 5, 1, self.upper - 1, self.long - 1, self.wide - 1, self.upper);
        stair(build, self.long - 5 - self.upper, self.wide - 3, 0, 0, self.upper, 2);
        for y in [self.wide - 3, self.wide - 2] {
            build.keep(corridor, self.long - 5, y, self.upper);
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, self.upper, ware2_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 4.5, 3.5, 0, ware2_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 3.0, self.upper, Q2_HEALTH, "q2");
        build.supply(4.0, float(middle) + 0.5, 0, "ammo_bullets", "q2");
    }
}

"""A storeroom of racks, planks across between their tops, stairs up to
them."""
node StorageRacks(Prefab) {
    has rack: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Storage racks";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.rack = dice.between(6, 7);
        self.tall = self.rack + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.rack),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.rack),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        store = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(store, self.rack);
        # Racks along x, three cells deep, the outer two against the walls;
        # planks across their tops between them at both ends.
        rows = [1, middle - 1, self.wide - 4];
        for y0 in rows {
            build.solid(8, y0, 0, self.long - 8, y0 + 3, self.rack);
        }
        for x in [8, self.long - 11] {
            build.solid(x, 4, self.rack - 1, x + 3, self.wide - 4, self.rack);
        }
        stair(build, 8 - self.rack, 1, 0, 0, self.rack, 3);
        stair(build, self.long - 9 + self.rack, self.wide - 4, 0, 2, self.rack, 3);
        build.doorway(store, self.enter);
        for port in self.taken {
            build.doorway(store, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(10 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, ware2_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(12 + index * 6) + 0.5, float(middle) + 0.5, self.rack, ware2_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, 2.5, self.rack, Q2_ARMOR, "q2");
        build.supply(2.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an office up a stair, looking down on a storeroom; taking it
opens the closets below."""
node ForemanOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Foreman office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(5, 7);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.office);
        build.doorway(room, self.enter);
        ox = self.long - 7;
        build.solid(ox, 1, 0, self.long - 1, cy + 1, self.office);
        build.solid(ox, cy + 1, self.office, ox + 1, cy + 2, self.office + 2);
        stair(build, ox - self.office, 1, 0, 0, self.office, 2);
        crates(build, dice, [[5, cy + 2], [9, side - 4], [ox - 4, cy + 3]], 0);
        key_ambush(build, self.key, float(self.long) - 3.0, 3.0, self.office, side, 0, [2, ox - 2], [ware2_foe(dice, self.danger, True), ware2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 4.0, float(cy) - 1.0, self.office, ware2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a freight bay, the way out on its lift's platform."""
node Ware2Exit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Freight bay" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
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
        px = self.long - 8;
        build.solid(px, middle - 4, 0, self.long - 1, middle + 4, 1);
        crates(build, dice, [[wall + 3, 2], [wall + 3, self.wide - 4], [px - 4, 2]], 0);
        build.way_out(float(self.long) - 4.0, float(middle), 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, ware2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px) - 2.5, float(self.wide) - 3.0, 0, ware2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""ware2's stretches: [name, role]."""
glob WARE2_STRETCHES: list[list[str]] = [
         ["trucks", "start"],
         ["offices", "flow"],
         ["racks", "hub"],
         ["racks", "flow"],
         ["foreman", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of ware2's stretches by its name."""
def make_ware2(name: str, key: str) -> Prefab {
    if name == "trucks" {
        return TruckBay();
    }
    if name == "offices" {
        return OfficeRow();
    }
    if name == "racks" {
        return StorageRacks();
    }
    if name == "foreman" {
        return ForemanOffice(key=key if key else "key_silver");
    }
    return Ware2Exit(key=key);
}
