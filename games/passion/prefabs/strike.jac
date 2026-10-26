"""Prefabs drawn from Quake II's strike, the Strike Base by the sea: a
beach under the sky by deep water, a sea wall walked along over the
waves, a harbor of piers over deep water round a boat house, the key in
the boat house's loft. Raised in strike's own palette.

- `BeachHead`: the start. A beach under the sky, the deep sea along one
  side, steps up out of it, dunes of rock; ways on along the beach.
- `SeaWall`: a sea wall under the sky, its top walked over the water on
  one side and a yard on the other, stairs down off it.
- `Harbor`: deep water filling a harbor, piers out over it from the
  quays, steps up out of the water; ways on round the quays (a hub).
- `BoatHouse`: the key in a boat house's loft up a stair over a slip of
  water; taking it opens the closets.
- `StrikeExit`: the end. A door (a key's, as a gate), a jetty, the way out
  at its end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, gate_into }

glob STRIKE: str = "q2:strike";

"""strike's foes: elite soldiers and flyers, infantry and gunners."""
def strike_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_soldier_ss", "monster_gunner"] if heavy else ["monster_soldier_ss", "monster_soldier", "monster_flyer"], ["monster_infantry"] if heavy else ["monster_soldier_ss"], danger * 0.6));
}

"""The start: a beach, the deep sea along one side, steps up out of it."""
node BeachHead(Prefab) {
    has tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Beach head";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(18, 22);
        self.low = -6;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=5.0, floor=0);
        self.leaves = [Port(face=0, along=5.0, floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        beach = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        sy = 11;
        build.pool(1, sy, -5, self.long - 1, self.wide - 1, 0, 2, False, False);
        for x in [4, self.long // 2, self.long - 6] {
            stair(build, x, sy + 4, -5, 3, 5, 2);
        }
        clear = [[0, 2, 6, 9], [self.long - 7, 0, self.long, 4], [self.long - 5, 2, self.long, 9]];
        boulders(build, dice, 1, 1, self.long - 1, sy, 0, dice.between(4, 7), clear);
        build.doorway(beach, self.enter);
        for port in self.taken {
            build.doorway(beach, port);
        }
        build.start(2.5, 5.5, 0, 0.0);
        build.supply(2.5, 3.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(10 + index * 4) + 0.5, 3.5 + float(index % 2) * 4.0, 0, strike_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 10) + 0.5, float(self.wide) - 4.0, -4, "monster_flipper", 0.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A sea wall, its top walked over the water on one side and a yard on the
other, stairs down off it."""
node SeaWall(Prefab) {
    has wall: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sea wall";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.wall = dice.between(4, 6);
        self.tall = dice.between(16, 20);
        self.low = -6;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.wall);
        self.leaves = [Port(face=0, along=middle, floor=self.wall), Port(face=0, along=3.0, floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        shore = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(shore, self.wall);
        # The wall along the middle, the sea north of it, the yard south.
        build.solid(1, middle - 2, 0, self.long - 1, middle + 2, self.wall);
        build.pool(1, middle + 2, -5, self.long - 1, self.wide - 1, 0, 2, False, False);
        for x in [3, self.long - 7 - self.wall] {
            stair(build, x, middle + 2, -5, 0, 5 + self.wall, 2);
        }
        for x in [5, self.long - 8] {
            stair(build, x, middle - 2 - self.wall, 0, 1, self.wall, 2);
        }
        for x in range(3, self.long - 3, 3) {
            build.solid(x, middle + 1, self.wall, x + 1, middle + 2, self.wall + 2);
        }
        build.doorway(shore, self.enter);
        for port in self.taken {
            build.doorway(shore, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(middle) + 0.5, self.wall, strike_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, strike_foe(dice, self.danger), 90.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.0, -4, "monster_flipper", 0.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""Deep water filling a harbor, piers out over it from the quays, steps up
out of the water."""
node Harbor(Prefab) {
    has tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Harbor";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(16, 20);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=float(self.wide - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        harbor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.pool(5, 5, -6, self.long - 5, self.wide - 5, 0, 2, False, True, True);
        stair(build, self.long - 11, 5, -6, 0, 6, 2);
        stair(build, self.long - 11, self.wide - 7, -6, 0, 6, 2);
        # Piers: out from the west and east quays, a gap of water between
        # their ends to jump.
        build.solid(5, cy - 1, -1, cx - 1, cy + 1, 0);
        build.solid(cx + 1, cy - 1, -1, self.long - 5, cy + 1, 0);
        for x in range(7, self.long - 6, 4) {
            build.solid(x, cy - 2, -6, x + 1, cy - 1, -1);
            build.solid(x, cy + 1, -6, x + 1, cy + 2, -1);
        }
        build.doorway(harbor, self.enter);
        for port in self.taken {
            build.doorway(harbor, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.0 if index % 2 == 0 else float(self.long) - 3.0, 4.5 + float(index) * 5.0, 0, strike_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 4.5, float(cy) + 0.5, 0, strike_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx - 3 + index * 6) + 0.5, float(cy) + 5.0, -5, "monster_flipper", 0.0);
        }
        build.supply(float(cx) - 3.0, float(cy) + 0.5, 0, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a boat house's loft up a stair over a slip of water; taking
it opens the closets."""
node BoatHouse(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        loft: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Boat house (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.loft = dice.between(5, 7);
        self.tall = self.loft + 8;
        self.low = -5;
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
        house = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(house, self.loft);
        build.doorway(house, self.enter);
        build.pool(5, cy - 3, -4, self.long - 1, cy + 3, 0, 2, False, True, True);
        stair(build, self.long - 5, cy - 3, -4, 0, 4, 2);
        lx = self.long - 6;
        build.solid(lx, cy + 3, self.loft - 1, self.long - 1, side, self.loft);
        stair(build, lx - self.loft, side - 3, 0, 0, self.loft, 3);
        key_ambush(build, self.key, float(self.long) - 3.0, float(side) - 3.0, self.loft, side, 0, [2, lx - 4], [strike_foe(dice, self.danger, True), strike_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, float(cy) + 5.0, self.loft, strike_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a jetty, the way out at its end."""
node StrikeExit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Jetty" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 20);
        self.low = -6;
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        x0 = wall + 3;
        build.pool(x0, 1, -5, self.long - 1, self.wide - 1, 0, 2, False, True, True);
        build.solid(x0, middle - 1, -5, self.long - 4, middle + 1, 0);
        build.solid(self.long - 5, middle - 3, -5, self.long - 1, middle + 3, 0);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, strike_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 4.0, 3.0, -4, "monster_flipper", 0.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""strike's stretches: [name, role]."""
glob STRIKE_STRETCHES: list[list[str]] = [
         ["beach", "start"],
         ["seawall", "flow"],
         ["harbor", "hub"],
         ["harbor", "flow"],
         ["boathouse", "keyroom"],
         ["jetty", "end"],
         ["jetty", "gate"]
     ];

"""One of strike's stretches by its name."""
def make_strike(name: str, key: str) -> Prefab {
    if name == "beach" {
        return BeachHead();
    }
    if name == "seawall" {
        return SeaWall();
    }
    if name == "harbor" {
        return Harbor();
    }
    if name == "boathouse" {
        return BoatHouse(key=key if key else "key_silver");
    }
    return StrikeExit(key=key);
}
