"""Prefabs drawn from Quake II's waste1, the Waste Processing plant: a yard
under the sky over pits of sludge, a conveyor gallery dumping into a
sludge trench, a settling hall of tanks under a walk, the key in a lab
over the tanks up a lift. Raised in waste1's own palette.

- `SludgeYard`: the start. A yard under the sky, pits of sludge sunk in it,
  walks between; ways on from three sides.
- `DumpGallery`: a gallery raised along a trench of sludge, chutes from
  its edge, a stair down at its far end to the trench's walk.
- `SettlingHall`: a hall of settling tanks in a grid, a walk raised over
  them up a stair; ways on from the floor and the walk (a hub).
- `WasteLab`: the key in a lab up a lift over a tank; taking it opens the
  closets.
- `Waste1Exit`: the end. A door (a key's, as a gate), an outflow channel
  bridged, the way out beyond it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob WASTE1: str = "q2:waste1";

"""waste1's foes: gunners and soldiers, iron maidens and berserkers, hovers,
a tank deeper in."""
def waste1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_soldier", "monster_gunner", "monster_chick"], ["monster_tank"] if heavy else ["monster_hover", "monster_berserk"], danger * 0.3 if heavy else danger * 0.6));
}

"""The start: a yard under the sky, pits of sludge sunk in it."""
node SludgeYard(Prefab) {
    has tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sludge yard";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(18, 22);
        self.low = -4;
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
        for px in [7, 15] {
            for py in [3, middle + 3] {
                build.pool(px, py, -3, px + 5, py + 5, 0, 3);
            }
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(13 + index % 2 * 8) + 0.5, float(middle) + (0.5 if index < 2 else 6.5), 0, waste1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 8, "monster_hover", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A gallery raised along a trench of sludge, chutes from its edge, a stair
down at its far end to the trench's walk."""
node DumpGallery(Prefab) {
    has gallery: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dump gallery";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(4, 6);
        self.tall = self.gallery + 9;
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 3), floor=self.gallery);
        self.leaves = [Port(face=0, along=3.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        gy = self.wide - 5;
        build.solid(1, gy, 0, self.long - 1, self.wide - 1, g);
        # The trench of sludge along the hall's middle, its walk along the
        # south wall.
        build.pool(1, 5, -3, self.long - 1, gy, 0, 3, False, False);
        for x in [4, self.long // 2, self.long - 6] {
            stair(build, x, 7, -3, 3, 3, 2);
        }
        for x in range(5, self.long - 6, 6) {
            build.solid(x, gy - 1, g - 2, x + 2, gy, g);
        }
        # The stair down from the gallery's far end to the walk.
        sx = self.long - 4;
        for step in range(g) {
            y = gy - 1 - step;
            build.solid(sx, y, 0, self.long - 1, y + 1, g - step - 1);
        }
        build.solid(sx, 5, -3, self.long - 1, gy, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(self.wide) - 2.5, g, waste1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 2.5, 0, waste1_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall of settling tanks in a grid, a walk raised over them up a stair."""
node SettlingHall(Prefab) {
    has walk: int = 6,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Settling hall";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(6, 7);
        self.tall = self.walk + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.walk),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        for x in range(7, self.long - 6, 6) {
            for y0 in [3, middle + 3] {
                build.solid(x, y0, 0, x + 4, y0 + 5, 4);
            }
        }
        build.solid(4 + self.walk, middle - 1, self.walk - 1, self.long - 1, middle + 2, self.walk);
        stair(build, 4, middle - 1, 0, 0, self.walk, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 6) + 0.5, 2.0 if index % 2 == 0 else float(self.wide) - 2.0, 0, waste1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 0.5, self.walk, waste1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a lab up a lift over a tank; taking it opens the closets."""
node WasteLab(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        lab: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Waste lab (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.lab = dice.between(6, 7);
        self.tall = self.lab + 8;
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
        build.level(room, self.lab);
        build.doorway(room, self.enter);
        lx = self.long - 6;
        build.solid(lx, 1, self.lab - 1, self.long - 1, side, self.lab);
        lift(build, lx - 3, cy - 1, lx, cy + 2, 0, self.lab);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, lx, y, self.lab);
        }
        build.pool(5, 3, -3, lx - 4, 7, 0, 3);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.lab, side, 0, [2, lx - 4], [waste1_foe(dice, self.danger, True), waste1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.lab, waste1_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, an outflow channel bridged, the way out beyond it."""
node Waste1Exit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Outflow" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
        self.low = -4;
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
        cx = wall + 5;
        build.pool(cx, 1, -3, cx + 5, self.wide - 1, 0, 3);
        stair(build, cx + 2, self.wide - 3, -3, 0, 3, 2);
        build.solid(cx, middle - 2, -1, cx + 5, middle + 2, 0);
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, waste1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, 0, waste1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste1's stretches: [name, role]."""
glob WASTE1_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["gallery", "flow"],
         ["settling", "hub"],
         ["settling", "flow"],
         ["lab", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of waste1's stretches by its name."""
def make_waste1(name: str, key: str) -> Prefab {
    if name == "yard" {
        return SludgeYard();
    }
    if name == "gallery" {
        return DumpGallery();
    }
    if name == "settling" {
        return SettlingHall();
    }
    if name == "lab" {
        return WasteLab(key=key if key else "key_silver");
    }
    return Waste1Exit(key=key);
}
