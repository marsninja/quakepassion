"""Prefabs drawn from Quake II's jail4, the Torture Chambers: chambers sunk
far below the prison, a well wound down into round its walls, a ring of
cells round a flooded pit, the key on a rack in a chamber off a gallery.
Raised in jail4's own palette.

- `TortureEntry`: the start. A hall, a broad stair down its far half into
  a lower chamber; ways on from both.
- `TortureWell`: a well entered at its top, a stair winding down round its
  walls past cages hung in it to its floor; ways on at the bottom.
- `ChamberRing`: a flooded pit in a hall's middle, chambers open off a
  walk round it, a stair down into the water; ways on round the walk (a
  hub).
- `RackChamber`: the key on a rack in a chamber up a stair at a gallery's
  end; taking it opens the cells below.
- `TortureExit`: the end. A door (a key's, as a gate), a stair down, the
  way out at its foot."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, spiral }
import from .e2m2 { spiral_landing }

glob JAIL4: str = "q2:jail4";

"""jail4's foes: soldiers and gunners, a tank deeper in."""
def jail4_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gunner"] if heavy else ["monster_soldier_light", "monster_soldier", "monster_soldier_ss"], ["monster_tank"] if heavy else ["monster_gunner"], danger * 0.5 if heavy else danger));
}

"""The start: a hall, a broad stair down its far half into a lower
chamber."""
node TortureEntry(Prefab) {
    has deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture entry";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(5, 7);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=1, along=5.0, floor=0), Port(face=3, along=float(self.long - 4), floor=-self.deep)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        sx = 10;
        build.solid(1, 1, low, sx, self.wide - 1, 0);
        stair(build, sx + self.deep - 1, 3, low, 2, self.deep, self.wide - 6);
        for x in range(sx + self.deep + 2, self.long - 3, 4) {
            build.solid(x, 2, low, x + 1, 3, low + 6);
            build.solid(x, self.wide - 3, low, x + 1, self.wide - 2, low + 6);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(sx + self.deep + 3 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), low, jail4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, low, Q2_HEALTH, "q2");
    }
}

"""A well entered at its top, a stair winding down round its walls past
cages hung in it."""
node TortureWell(Prefab) {
    has steps: int = 28,
        tall: int = 36;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture well";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        fits: list[int] = [];
        for steps in range(20, 34) {
            landing = spiral_landing(self.long, self.wide, steps, 5);
            if landing and landing[0] == 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top = spiral_landing(self.long, self.wide, self.steps, 5);
        self.enter = Port(face=2, along=top[1], floor=self.steps);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        well = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(well, self.steps // 2);
        build.level(well, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        # Cages hung in the well's middle, on chains from the roof.
        cx = self.long // 2;
        cy = self.wide // 2;
        for (index, z) in enumerate([self.steps // 3, 2 * self.steps // 3]) {
            x = cx - 2 + index * 2;
            build.solid(x, cy - 1, z, x + 2, cy + 1, z + 1);
            build.solid(x, cy - 1, z + 3, x + 2, cy + 1, z + 4);
            build.solid(x, cy - 1, z + 4, x + 1, cy, self.tall);
        }
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        build.foe(float(self.long) - 2.5, float(cy) + 0.5, 0, jail4_foe(dice, self.danger, True), 180.0);
        build.foe(2.5, 2.5, 1, jail4_foe(dice, self.danger), 0.0);
        build.foe(float(cx) + 0.5, 2.5, 6, jail4_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A flooded pit in a hall's middle, chambers open off a walk round it."""
node ChamberRing(Prefab) {
    has deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chamber ring";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.deep = dice.between(5, 7);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=float(self.wide - 8), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(8, 8, -self.deep, self.long - 8, self.wide - 8, 0, 2, False, True, True);
        stair(build, self.long - 8 - self.deep, 8, -self.deep, 0, self.deep, 2);
        # Chambers: walls out from the hall's walls every few cells, open
        # bays between them round the walk.
        for x in range(4, self.long - 4, 5) {
            if abs(x - cx) > 3 {
                build.solid(x, 1, 0, x + 1, 5, self.tall);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 1, self.tall);
            }
        }
        for y in range(4, self.wide - 4, 5) {
            if abs(y - cy) > 3 and abs(y - (self.wide - 8)) > 3 {
                build.solid(1, y, 0, 5, y + 1, self.tall);
                build.solid(self.long - 5, y, 0, self.long - 1, y + 1, self.tall);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 5)) {
            build.foe(float(6 + index * 5) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, jail4_foe(dice, self.danger, index == 0), 90.0);
        }
        build.supply(float(cx) + 0.5, 6.0, 0, Q2_ARMOR, "q2");
        build.supply(6.0, float(cy) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on a rack in a chamber up a stair at a gallery's end; taking it
opens the cells below."""
node RackChamber(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        gallery: int = 5,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rack chamber (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.gallery = dice.between(5, 6);
        self.tall = self.gallery + 8;
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
        build.level(room, self.gallery);
        build.doorway(room, self.enter);
        gx = self.long - 7;
        build.solid(gx, 1, 0, self.long - 1, side, self.gallery);
        stair(build, gx - self.gallery, cy - 2, 0, 0, self.gallery, 4);
        for y in range(cy - 2, cy + 2) {
            build.keep(room, gx, y, self.gallery);
        }
        build.solid(self.long - 4, cy - 1, self.gallery, self.long - 2, cy + 2, self.gallery + 1);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.gallery + 1, side, 0, [2, 7, gx - 4], [jail4_foe(dice, self.danger, True), jail4_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 3.0, self.gallery, jail4_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a stair down, the way out at its foot."""
node TortureExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(24, 26);
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
        build.solid(wall + 1, 1, low, wall + 3, self.wide - 1, 0);
        stair(build, wall + 2 + self.deep, middle - 2, low, 2, self.deep, 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, jail4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, low, jail4_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail4's stretches: [name, role]."""
glob JAIL4_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["well", "flow"],
         ["ring", "hub"],
         ["ring", "flow"],
         ["rack", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail4's stretches by its name."""
def make_jail4(name: str, key: str) -> Prefab {
    if name == "entry" {
        return TortureEntry();
    }
    if name == "well" {
        return TortureWell();
    }
    if name == "ring" {
        return ChamberRing();
    }
    if name == "rack" {
        return RackChamber(key=key if key else "key_silver");
    }
    return TortureExit(key=key);
}
