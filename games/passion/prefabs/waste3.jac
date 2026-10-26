"""Prefabs drawn from Quake II's waste3, the Waste Storage depot: drum
stacks in a yard, a lift shaft to a storage loft, a cavern of tanks
standing in toxic pools under a ring walk, the key behind a hazard door.
Raised in waste3's own palette.

- `DrumYard`: the start. A yard of drums stacked in rows, lanes between;
  ways on beyond.
- `LoftShaft`: a shaft, a lift up to a loft across its far end and a walk
  on from it; the floor's way on below.
- `TankCavern`: a cavern of tanks standing in toxic pools, a ring walk
  round it up a stair; ways on from the floor and the walk (a hub).
- `HazardStore`: the key behind a hazard door its button opens, over a
  pool of slime crossed on a walk; taking it opens the closets.
- `Waste3Exit`: the end. A door (a key's, as a gate), a ramp up, the way
  out on a loading deck."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }
import from .bunk1 { crates }

glob WASTE3: str = "q2:waste3";

"""waste3's foes: soldiers and gunners, floaters and berserkers, a tank
deeper in."""
def waste3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_soldier", "monster_soldier", "monster_gunner"], ["monster_tank"] if heavy else ["monster_floater"], danger * 0.3 if heavy else danger * 0.6));
}

"""The start: a yard of drums stacked in rows, lanes between."""
node DrumYard(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drum yard";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(15, 17);
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
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for x in range(6, self.long - 6, 5) {
            spots: list[list[int]] = [];
            for y in range(2, self.wide - 3, 4) {
                if abs(y - middle) > 3 {
                    spots.append([x, y]);
                }
            }
            crates(build, dice, spots, 0);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 4) + 0.5, float(middle) + (0.5 if index % 2 == 0 else -1.5), 0, waste3_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A shaft, a lift up to a loft across its far end and a walk on from it;
the floor's way on below."""
node LoftShaft(Prefab) {
    has loft: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Loft shaft";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.loft = dice.between(8, 10);
        self.tall = self.loft + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.loft), Port(face=1, along=float(self.long - 3), floor=self.loft), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.loft);
        lx = self.long - 6;
        build.solid(lx, 1, self.loft - 1, self.long - 1, self.wide - 1, self.loft);
        lift(build, lx - 3, middle - 1, lx, middle + 2, 0, self.loft);
        for y in range(middle - 2, middle + 3) {
            build.keep(shaft, lx, y, self.loft);
        }
        crates(build, dice, [[3, 2], [3, self.wide - 4], [lx + 2, 2]], 0);
        crates(build, dice, [[lx + 2, self.wide - 4]], self.loft);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, waste3_foe(dice, self.danger), 90.0);
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, self.loft, waste3_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 6, "monster_floater", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.loft, Q2_HEALTH, "q2");
    }
}

"""A cavern of tanks standing in toxic pools, a ring walk round it up a
stair."""
node TankCavern(Prefab) {
    has walk: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tank cavern";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(6, 7);
        self.tall = self.walk + 11;
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
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.walk);
        for x in range(7, self.long - 9, 8) {
            for y0 in [6, middle + 2] {
                build.pool(x, y0, -2, x + 6, y0 + 5, 0, 3);
                build.solid(x + 2, y0 + 1, -2, x + 5, y0 + 4, 7);
            }
        }
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        stair(build, 4, 4, 0, 0, self.walk, 2);
        for x in range(2 + self.walk, 4 + self.walk) {
            build.keep(cave, x, 3, self.walk);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 6) + 0.5, float(middle) + 0.5, 0, waste3_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long // 2) + 0.5, 2.5, self.walk, waste3_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, float(self.wide) - 6.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key behind a hazard door its button opens, over a pool of slime
crossed on a walk; taking it opens the closets."""
node HazardStore(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hazard store (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(11, 13);
        self.low = -4;
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
        hx = self.long - 7;
        build.pool(5, 2, -3, hx - 1, side - 1, 0, 3, False, True, True);
        build.solid(5, cy - 1, -3, hx - 1, cy + 2, 0);
        build.solid(hx, 1, 0, hx + 1, side, self.tall);
        door = build.name("hazard");
        build.widen(room, hx, cy - 2, 0, hx + 1, cy + 2, 7);
        build.rising_door(float(hx), float(cy - 2), 0.0, float(hx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(hx), float(cy) + 3.5, 1.3, 2, door);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [1, hx + 2], [waste3_foe(dice, self.danger, True), waste3_foe(dice, self.danger)]);
        build.foe(float(hx) - 2.5, float(cy) - 3.5, 0, waste3_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a ramp up, the way out on a loading deck."""
node Waste3Exit(Prefab) {
    has key: str = "",
        deck: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Storage exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.deck = dice.between(3, 4);
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
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.deck);
        stair(build, dx - self.deck, 2, 0, 0, self.deck, 3);
        crates(build, dice, [[wall + 4, middle + 2], [dx + 2, self.wide - 4]], 0);
        build.way_out(float(self.long) - 3.0, float(middle), self.deck);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, waste3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 4.5, float(self.wide) - 3.0, 0, waste3_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste3's stretches: [name, role]."""
glob WASTE3_STRETCHES: list[list[str]] = [
         ["drums", "start"],
         ["loft", "flow"],
         ["tanks", "hub"],
         ["tanks", "flow"],
         ["hazard", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of waste3's stretches by its name."""
def make_waste3(name: str, key: str) -> Prefab {
    if name == "drums" {
        return DrumYard();
    }
    if name == "loft" {
        return LoftShaft();
    }
    if name == "tanks" {
        return TankCavern();
    }
    if name == "hazard" {
        return HazardStore(key=key if key else "key_silver");
    }
    return Waste3Exit(key=key);
}
