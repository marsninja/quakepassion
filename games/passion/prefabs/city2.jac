"""Prefabs drawn from Quake II's city2, the Lower Palace: a palace of door
after door, a gate up steps from a court, a colonnade of bays along a
long hall, a throne hall on a dais under balconies, the key in the
treasury behind a door its button opens. Raised in city2's own palette.

- `PalaceGate`: the start. A court, a gate up broad steps into the palace;
  ways on beyond the gate and round the court.
- `Colonnade`: a long hall, bays between columns down both sides, doors at
  both ends of its middle.
- `PalaceThrone`: a throne on a dais under balconies on three walls, stairs
  up to them at the near corners; ways on from the floor and the balconies
  (a hub).
- `Treasury`: the key in a treasury behind a door its button opens; taking
  it opens the closets.
- `City2Exit`: the end. A door (a key's, as a gate), an antechamber, the way
  out through a second door."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, gate_into }

glob CITY2: str = "q2:city2";

"""city2's foes: elite soldiers and berserkers, floaters and brains, tank
commanders deeper in."""
def city2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_brain"] if heavy else ["monster_soldier_ss", "monster_berserk", "monster_floater"], ["monster_tank_commander"] if heavy else ["monster_brain"], danger * 0.3 if heavy else danger * 0.5));
}

"""The start: a court, a gate up broad steps into the palace."""
node PalaceGate(Prefab) {
    has steps: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace gate";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.steps = dice.between(3, 4);
        self.tall = dice.between(18, 22);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.steps), Port(face=1, along=6.0, floor=0), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.steps);
        gx = self.long - 6;
        build.solid(gx, 1, 0, self.long - 1, self.wide - 1, 14);
        build.widen(court, gx, middle - 2, self.steps, self.long - 1, middle + 2, self.steps + 8);
        stair(build, gx - self.steps, middle - 5, 0, 0, self.steps, 10);
        for y in range(middle - 4, middle + 4) {
            build.keep(court, gx - 1, y, self.steps);
        }
        for y in range(2, self.wide - 2, 3) {
            if abs(y - middle) > 5 {
                build.solid(gx - 1, y, 0, gx, y + 1, 12);
            }
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(gx) - 8.5 + float(index % 2) * 2.0, 3.5 + float(index) * 4.0, 0, city2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, self.steps, city2_foe(dice, self.danger, True), 180.0);
        build.supply(float(gx) - 4.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A long hall, bays between columns down both sides, doors at both ends of
its middle."""
node Colonnade(Prefab) {
    has tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Colonnade";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(14, 16);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        clear = [[0, middle - 3, 5, middle + 3], [self.long // 2 - 3, 0, self.long // 2 + 3, self.wide], [self.long - 5, middle - 3, self.long, middle + 3]];
        pillars(build, 4, 4, self.long - 4, 5, 0, self.tall, 3, clear);
        pillars(build, 4, self.wide - 5, self.long - 4, self.wide - 4, 0, self.tall, 3, clear);
        for x in [6, self.long - 7] {
            build.solid(x, 5, 0, x + 1, middle - 2, self.tall);
            build.solid(x, middle + 2, 0, x + 1, self.wide - 5, self.tall);
            build.solid(x, middle - 2, 8, x + 1, middle + 2, self.tall);
            build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 8.0, {"wait": "-1"});
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 4) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, city2_foe(dice, self.danger, index == 0), 90.0);
        }
        build.supply(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A throne on a dais under balconies on three walls, stairs up to them at
the near corners."""
node PalaceThrone(Prefab) {
    has dais: int = 3,
        balcony: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace throne";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.dais = dice.between(3, 4);
        self.balcony = dice.between(8, 9);
        self.tall = self.balcony + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=self.balcony),
            Port(face=3, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.dais);
        build.level(hall, self.balcony);
        dx = self.long - 12;
        build.solid(dx, cy - 4, 0, self.long - 5, cy + 4, self.dais);
        stair(build, dx - self.dais, cy - 2, 0, 0, self.dais, 4);
        build.solid(self.long - 7, cy - 1, self.dais, self.long - 6, cy + 1, self.dais + 4);
        under = self.balcony - 1;
        bx = 4 + self.balcony;
        build.solid(bx, 1, under, self.long - 1, 5, self.balcony);
        build.solid(bx, self.wide - 5, under, self.long - 1, self.wide - 1, self.balcony);
        build.solid(self.long - 5, 5, under, self.long - 1, self.wide - 5, self.balcony);
        stair(build, 4, 1, 0, 0, self.balcony, 3);
        stair(build, 4, self.wide - 4, 0, 0, self.balcony, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(dx - 6 + index * 3) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, city2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 8.5, float(cy) + 2.5, self.dais, city2_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, 3.0, self.balcony, city2_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, self.balcony, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a treasury behind a door its button opens; taking it opens
the closets."""
node Treasury(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Treasury (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY2;
        self.district = level_district(CITY2);
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
        tx = self.long - 7;
        build.solid(tx, 1, 0, tx + 1, side, self.tall);
        door = build.name("treasury");
        build.widen(room, tx, cy - 2, 0, tx + 1, cy + 2, 7);
        build.rising_door(float(tx), float(cy - 2), 0.0, float(tx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(tx), float(cy) - 4.0, 1.3, 2, door);
        build.solid(self.long - 4, cy - 1, 0, self.long - 2, cy + 2, 2);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 2, side, 0, [3, tx - 5], [city2_foe(dice, self.danger, True), city2_foe(dice, self.danger)]);
        build.foe(float(tx) - 3.5, float(side) - 3.0, 0, city2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, an antechamber, the way out through a second door."""
node City2Exit(Prefab) {
    has key: str = "",
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace antechamber" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(12, 14);
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
        ix = self.long - 7;
        build.solid(ix, 1, 0, ix + 1, middle - 2, self.tall);
        build.solid(ix, middle + 2, 0, ix + 1, self.wide - 1, self.tall);
        build.solid(ix, middle - 2, 8, ix + 1, middle + 2, self.tall);
        build.rising_door(float(ix), float(middle - 2), 0.0, float(ix + 1), float(middle + 2), 8.0, {"wait": "-1"});
        pillars(build, wall + 3, 3, ix - 1, self.wide - 3, 0, self.tall, 4, [[0, middle - 3, self.long, middle + 3]]);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, city2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(ix) - 2.5, float(middle) + 3.0, 0, city2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""city2's stretches: [name, role]."""
glob CITY2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["colonnade", "flow"],
         ["throne", "hub"],
         ["throne", "flow"],
         ["treasury", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of city2's stretches by its name."""
def make_city2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PalaceGate();
    }
    if name == "colonnade" {
        return Colonnade();
    }
    if name == "throne" {
        return PalaceThrone();
    }
    if name == "treasury" {
        return Treasury(key=key if key else "key_silver");
    }
    return City2Exit(key=key);
}
