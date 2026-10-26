"""Prefabs drawn from Quake II's lab, the Research Lab: a lab where the
Strogg breed, specimen tanks lining a corridor, an atrium of two floors
round a well, the key in a cloning vault behind a door its button opens.
Raised in lab's own palette.

- `LabEntrance`: the start. A decontamination hall, airlock doors across
  its far end; ways on beyond.
- `SpecimenRow`: a corridor lined with specimen tanks in alcoves, a
  gallery over one side up a stair; ways on from both.
- `LabAtrium`: an atrium of two floors round a well, the upper floor up
  stairs at both ends; ways on from both floors (a hub).
- `CloningVault`: the key in a vault of cloning pods behind a door its
  button opens; taking it opens the closets.
- `LabExit`: the end. A door (a key's, as a gate), a lift down to the
  way out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob LAB: str = "q2:lab";

"""lab's foes: parasites and iron maidens, medics and brains deeper in."""
def lab_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_chick", "monster_brain"] if heavy else ["monster_parasite", "monster_parasite", "monster_chick"], ["monster_medic"] if heavy else ["monster_brain"], danger * 0.4 if heavy else danger * 0.5));
}

"""The start: a decontamination hall, airlock doors across its far end."""
node LabEntrance(Prefab) {
    has tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lab entrance";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(11, 13);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        a = self.long - 11;
        b = self.long - 6;
        hall = build.room(1, 1, 0, a, self.wide - 1, self.tall, variant=dice.below(3));
        lock = build.room(a + 1, middle - 3, 0, b, middle + 3, 8, variant=dice.below(3));
        beyond = build.room(b + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for x in [a, b] {
            build.widen(lock, x, middle - 2, 0, x + 1, middle + 2, 7);
            build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 7.0, {"wait": "-1"});
        }
        for x in range(4, a - 2, 4) {
            build.solid(x, 1, 0, x + 1, 3, self.tall);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 1, self.tall);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(a) - 3.5, 3.5 + float(index) * 4.0, 0, lab_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, lab_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A corridor lined with specimen tanks in alcoves, a gallery over one side
up a stair."""
node SpecimenRow(Prefab) {
    has gallery: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Specimen row";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(5, 6);
        self.tall = self.gallery + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 1.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 1.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        row = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(row, self.gallery);
        gy = self.wide - 5;
        build.solid(4 + self.gallery, gy, self.gallery - 1, self.long - 1, self.wide - 1, self.gallery);
        stair(build, 4, gy, 0, 0, self.gallery, 3);
        # Specimen tanks: alcoves along the south wall, a tank in each.
        for x in range(4, self.long - 6, 4) {
            build.solid(x, 1, 0, x + 1, 4, self.tall);
            build.solid(x + 1, 1, 0, x + 3, 3, 1);
            build.solid(x + 1, 1, 4, x + 3, 3, 5);
        }
        build.doorway(row, self.enter);
        for port in self.taken {
            build.doorway(row, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 5) + 0.5, float(middle) + 0.5, 0, lab_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, self.gallery, lab_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 5.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 3.0, self.gallery, "ammo_cells", "q2");
    }
}

"""An atrium of two floors round a well, the upper floor up stairs at both
ends."""
node LabAtrium(Prefab) {
    has upper: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lab atrium";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.upper = dice.between(7, 8);
        self.tall = self.upper + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=4.0, floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        atrium = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(atrium, self.upper);
        # The upper floor: a slab over all but the well in the middle.
        under = self.upper - 1;
        build.solid(1, 1, under, self.long - 1, self.wide - 1, self.upper);
        build.widen(atrium, cx - 6, cy - 4, under, cx + 6, cy + 4, self.upper);
        # A stair up through the floor at each end, the floor cut away over
        # all its steps but the top.
        build.widen(atrium, 3, cy - 2, under, 2 + self.upper, cy + 2, self.upper);
        stair(build, 3, cy - 2, 0, 0, self.upper, 4);
        build.widen(atrium, self.long - 2 - self.upper, cy - 2, under, self.long - 3, cy + 2, self.upper);
        stair(build, self.long - 4, cy - 2, 0, 2, self.upper, 4);
        for y in range(cy - 2, cy + 2) {
            build.keep(atrium, 2 + self.upper, y, self.upper);
            build.keep(atrium, self.long - 3 - self.upper, y, self.upper);
        }
        build.doorway(atrium, self.enter);
        for port in self.taken {
            build.doorway(atrium, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 4 + index * 3) + 0.5, float(cy) + 0.5, 0, lab_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0, self.upper, lab_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(cx) + 4.0, 3.0, self.upper, Q2_ARMOR, "q2");
        build.supply(float(cx) - 4.0, float(cy) + 2.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a vault of cloning pods behind a door its button opens;
taking it opens the closets."""
node CloningVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cloning vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = LAB;
        self.district = level_district(LAB);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(room, self.enter);
        vx = self.long - 8;
        build.solid(vx, 1, 0, vx + 1, side, self.tall);
        door = build.name("clones");
        build.widen(room, vx, cy - 2, 0, vx + 1, cy + 2, 7);
        build.rising_door(float(vx), float(cy - 2), 0.0, float(vx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(vx), float(cy) - 4.0, 1.3, 2, door);
        for y in [2, side - 4] {
            for x in range(vx + 2, self.long - 2, 3) {
                build.solid(x, y, 0, x + 2, y + 2, 5);
            }
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [3, vx - 5], [lab_foe(dice, self.danger, True), lab_foe(dice, self.danger)]);
        build.foe(float(vx) - 3.5, float(side) - 3.0, 0, lab_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a lift down to the way out."""
node LabExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lab exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(10, 12);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        wall = 8;
        gate_into(build, dice, self.enter, self.long, self.wide, wall, low, self.tall, self.key);
        build.solid(wall + 1, 1, low, wall + 4, self.wide - 1, 0);
        stair(build, wall + 3 + self.deep, middle - 2, low, 2, self.deep, 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, lab_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, low, lab_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""lab's stretches: [name, role]."""
glob LAB_STRETCHES: list[list[str]] = [
         ["entrance", "start"],
         ["specimens", "flow"],
         ["atrium", "hub"],
         ["atrium", "flow"],
         ["clones", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of lab's stretches by its name."""
def make_lab(name: str, key: str) -> Prefab {
    if name == "entrance" {
        return LabEntrance();
    }
    if name == "specimens" {
        return SpecimenRow();
    }
    if name == "atrium" {
        return LabAtrium();
    }
    if name == "clones" {
        return CloningVault(key=key if key else "key_silver");
    }
    return LabExit(key=key);
}
