"""Prefabs drawn from Quake II's city3, the Upper Palace: the palace's upper
halls, a gate at the head of a long stair, a stairway climbing in flights
between landings, a rotunda ringed by a gallery round a sunken floor,
the key in the royal chamber on a dais. Raised in city3's own palette.

- `UpperGate`: the start. A hall, a stair up its far end to a gallery and a
  gate through the wall there; ways on above and below.
- `PalaceStairs`: a stairway climbing in three flights between landings
  along a tall hall's walls; the way on from the top.
- `Rotunda`: a round-walled hall, its floor sunk in the middle, a gallery
  round it up stairs; ways on from the floor, the pit and the gallery (a
  hub).
- `RoyalChamber`: the key on a dais in the royal chamber behind a door its
  button opens; taking it opens the closets.
- `City3Exit`: the end. A door (a key's, as a gate), a balcony over the
  city, the way out at its end; a stair back up for whoever falls."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, gate_into, lift }

glob CITY3: str = "q2:city3";

"""city3's foes: soldiers and gunners, iron maidens and floaters, tank
commanders deeper in."""
def city3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_chick"] if heavy else ["monster_soldier_ss", "monster_soldier", "monster_chick"], ["monster_tank_commander"] if heavy else ["monster_floater"], danger * 0.3 if heavy else danger * 0.5));
}

"""The start: a hall, a stair up its far end to a gallery and a gate."""
node UpperGate(Prefab) {
    has gallery: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Upper gate";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.gallery = dice.between(5, 7);
        self.tall = self.gallery + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.gallery), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        gx = self.long - 5;
        build.solid(gx, 1, 0, self.long - 1, self.wide - 1, self.gallery);
        stair(build, gx - self.gallery, middle - 3, 0, 0, self.gallery, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(hall, gx, y, self.gallery);
        }
        clear = [[0, middle - 3, 5, middle + 3], [6, 0, 11, 4], [6, self.wide - 4, 11, self.wide], [gx - self.gallery - 1, middle - 4, gx, middle + 4]];
        pillars(build, 4, 4, gx - 1, 5, 0, self.tall, 4, clear);
        pillars(build, 4, self.wide - 5, gx - 1, self.wide - 4, 0, self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(gx) - 9.5 + float(index % 2) * 2.0, 2.5 + float(index) * 4.0, 0, city3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.gallery, city3_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_HEALTH, "q2");
    }
}

"""A stairway climbing in three flights between landings along a tall
hall's walls."""
node PalaceStairs(Prefab) {
    has flight: int = 4,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace stairs";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.flight = dice.between(4, 5);
        self.tall = 3 * self.flight + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=2, along=float(self.wide - 3), floor=3 * self.flight), Port(face=1, along=4.0, floor=3 * self.flight)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.flight;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [f, 2 * f, 3 * f] {
            build.level(hall, z);
        }
        # Flight one east along the south wall to a landing in the south-east
        # corner; flight two north up the east wall to a landing in the
        # north-east; flight three west along the north wall to the top
        # landing in the north-west.
        stair(build, 4, 1, 0, 0, f, 3);
        build.solid(4 + f, 1, 0, self.long - 1, 4, f);
        stair(build, self.long - 4, 4, f, 1, f, 3);
        build.solid(self.long - 4, 4 + f, 0, self.long - 1, self.wide - 1, 2 * f);
        stair(build, self.long - 5, self.wide - 4, 2 * f, 2, f, 3);
        build.solid(1, self.wide - 4, 0, self.long - 4 - f, self.wide - 1, 3 * f);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(self.long) - 3.0, 2.5, f, city3_foe(dice, self.danger), 90.0);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, 2 * f, city3_foe(dice, self.danger), 180.0);
        build.foe(3.0, float(self.wide) - 3.0, 3 * f, city3_foe(dice, self.danger, True), 0.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 6, "monster_floater", 0.0);
        build.supply(3.0, float(self.wide) - 2.5, 3 * f, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, "ammo_bullets", "q2");
    }
}

"""A round-walled hall, its floor sunk in the middle, a gallery round it up
stairs."""
node Rotunda(Prefab) {
    has sunk: int = 3,
        gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rotunda";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.sunk = dice.between(3, 4);
        self.gallery = dice.between(8, 9);
        self.tall = self.gallery + 11;
        self.low = -self.sunk - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        low = -self.sunk;
        rotunda = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(rotunda, low);
        build.level(rotunda, self.gallery);
        # The corners filled in to round the walls.
        for corner in [[1, 1], [self.long - 4, 1], [1, self.wide - 4], [self.long - 4, self.wide - 4]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 3, corner[1] + 3, self.tall);
        }
        build.widen(rotunda, cx - 6, cy - 6, low, cx + 6, cy + 6, 0);
        stair(build, cx - 6 + self.sunk - 1, cy - 2, low, 2, self.sunk, 4);
        stair(build, cx + 6 - self.sunk, cy - 2, low, 0, self.sunk, 4);
        under = self.gallery - 1;
        build.solid(4, 1, under, self.long - 4, 5, self.gallery);
        build.solid(4, self.wide - 5, under, self.long - 4, self.wide - 1, self.gallery);
        build.solid(self.long - 5, 4, under, self.long - 1, self.wide - 4, self.gallery);
        stair(build, 4, 5, 0, 0, self.gallery, 2);
        stair(build, 4, self.wide - 7, 0, 0, self.gallery, 2);
        build.doorway(rotunda, self.enter);
        for port in self.taken {
            build.doorway(rotunda, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 4 + index * 3) + 0.5, float(cy) + 3.5, low, city3_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, 3.0, self.gallery, city3_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(float(cx) + 0.5, float(cy) - 4.0, low, Q2_HEALTH, "q2");
    }
}

"""The key on a dais in the royal chamber behind a door its button opens;
taking it opens the closets."""
node RoyalChamber(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Royal chamber (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(12, 14);
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
        rx = self.long - 8;
        build.solid(rx, 1, 0, rx + 1, side, self.tall);
        door = build.name("royal");
        build.widen(room, rx, cy - 2, 0, rx + 1, cy + 2, 8);
        build.rising_door(float(rx), float(cy - 2), 0.0, float(rx + 1), float(cy + 2), 8.0, {"targetname": door, "wait": "-1"});
        build.button(float(rx), float(cy) + 4.0, 1.3, 2, door);
        build.solid(self.long - 4, cy - 2, 0, self.long - 1, cy + 3, 2);
        stair(build, self.long - 6, cy - 1, 0, 0, 2, 3);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 2, side, 0, [3, rx - 5], [city3_foe(dice, self.danger, True), city3_foe(dice, self.danger)]);
        build.foe(float(rx) - 3.5, 2.5, 0, city3_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a balcony over the city, the way out at its end."""
node City3Exit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace balcony" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 20);
        self.low = -9;
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, -8, self.tall, self.key, True);
        build.solid(wall + 1, 1, -8, self.long - 1, middle + 3, 0);
        # Posts along the balcony's edge, clear of the stair's top.
        for x in range(wall + 11, self.long - 1, 2) {
            build.solid(x, middle + 2, 0, x + 1, middle + 3, 2);
        }
        stair(build, wall + 2, middle + 3, -8, 0, 8, 3);
        # A lift at the far end back up, for whoever falls in past the stair.
        lift(build, self.long - 4, middle + 3, self.long - 1, middle + 6, -8, 0);
        build.way_out(float(self.long) - 3.0, float(middle) - 2.0, 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, city3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 6.5, 3.0, 0, city3_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.5, 3, "monster_floater", 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""city3's stretches: [name, role]."""
glob CITY3_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["stairs", "flow"],
         ["rotunda", "hub"],
         ["rotunda", "flow"],
         ["royal", "keyroom"],
         ["balcony", "end"],
         ["balcony", "gate"]
     ];

"""One of city3's stretches by its name."""
def make_city3(name: str, key: str) -> Prefab {
    if name == "gate" {
        return UpperGate();
    }
    if name == "stairs" {
        return PalaceStairs();
    }
    if name == "rotunda" {
        return Rotunda();
    }
    if name == "royal" {
        return RoyalChamber(key=key if key else "key_silver");
    }
    return City3Exit(key=key);
}
