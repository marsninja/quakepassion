"""Prefabs drawn from Quake II's mine2, the Borehole: workings sunk deep, a
borehole wound down into round its walls, a channel of lava with
walkways over it and a pump house, the key at the bottom of a flooded
sump. Raised in mine2's own palette.

- `BoreheadLanding`: the start. A cavern, rock ledges along its walls, a
  stair down into its lower half; ways on from both.
- `BoreholeDescent`: a borehole entered at its top, a stair winding down
  round its walls to water at its bottom; ways on at the foot.
- `LavaChannel`: a cavern, a channel of lava down its middle, walkways
  across, a pump house on a ledge up a stair; ways on from the floor and
  the ledge (a hub).
- `FloodedSump`: the key on the floor of a flooded sump; taking it opens
  the closets round it.
- `Mine2Exit`: the end. A door (a key's, as a gate), a ramp down to the way
  out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, stalactites, key_ambush, gate_into, spiral }
import from .e2m2 { spiral_landing }

glob MINE2: str = "q2:mine2";

"""mine2's foes: gunners and soldiers, berserkers, gladiators deeper in."""
def mine2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_gunner"] if heavy else ["monster_soldier_ss", "monster_soldier_ss", "monster_gunner"], ["monster_gladiator"] if heavy else ["monster_berserk"], danger * 0.6 if heavy else danger * 0.8));
}

"""The start: a cavern, rock ledges along its walls, a stair down into its
lower half."""
node BoreheadLanding(Prefab) {
    has drop: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Borehead landing";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.drop = dice.between(4, 6);
        self.tall = dice.between(13, 15);
        self.low = -self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.drop), Port(face=1, along=6.0, floor=0), Port(face=3, along=float(self.long - 4), floor=-self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.drop;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 0);
        hx = 11;
        build.solid(1, 1, low, hx, self.wide - 1, 0);
        stair(build, hx + self.drop - 1, middle - 2, low, 2, self.drop, 4);
        clear = [[hx - 1, middle - 3, hx + self.drop + 1, middle + 3], [self.long - 6, middle - 3, self.long, middle + 3], [self.long - 7, 0, self.long, 4]];
        boulders(build, dice, hx, 1, self.long - 1, self.wide - 1, low, dice.between(4, 7), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(5, 8));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(hx + self.drop + 3 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), low, mine2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, low, Q2_HEALTH, "q2");
    }
}

"""A borehole entered at its top, a stair winding down round its walls to
water at its bottom."""
node BoreholeDescent(Prefab) {
    has steps: int = 28,
        tall: int = 36;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Borehole descent";
        self.source = MINE2;
        self.district = level_district(MINE2);
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
        self.low = -4;
        self.high = self.tall + 1;
        top = spiral_landing(self.long, self.wide, self.steps, 5);
        self.enter = Port(face=2, along=top[1], floor=self.steps);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hole = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hole, self.steps // 2);
        build.level(hole, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        build.pool(5, 5, -3, self.long - 5, self.wide - 5, 0, 2);
        build.doorway(hole, self.enter);
        for port in self.taken {
            build.doorway(hole, port);
        }
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 0, mine2_foe(dice, self.danger, True), 180.0);
        build.foe(2.5, 2.5, 1, mine2_foe(dice, self.danger), 0.0);
        build.foe(float(self.long // 2) + 0.5, 2.5, 6, mine2_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A cavern, a channel of lava down its middle, walkways across, a pump
house on a ledge up a stair."""
node LavaChannel(Prefab) {
    has ledge: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava channel";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.ledge = dice.between(6, 7);
        self.tall = self.ledge + 11;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 5), floor=self.ledge),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=1, along=6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.ledge);
        build.pool(4, middle - 2, -3, self.long - 4, middle + 2, 0, 4, False, False);
        for x in [8, self.long // 2, self.long - 10] {
            build.solid(x, middle - 2, -3, x + 3, middle + 2, 0);
        }
        # The pump house: a ledge in the north-east corner, a stair up its
        # face, a block of machinery on it.
        lx = self.long - 9;
        ly = self.wide - 7;
        build.solid(lx, ly, 0, self.long - 1, self.wide - 1, self.ledge);
        stair(build, lx - self.ledge, ly, 0, 0, self.ledge, 3);
        build.solid(self.long - 4, self.wide - 4, self.ledge, self.long - 2, self.wide - 2, self.ledge + 3);
        for y in range(ly, ly + 3) {
            build.keep(cave, lx, y, self.ledge);
        }
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 9));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 5) + 0.5, float(middle) + (5.5 if index % 2 == 0 else -5.5), 0, mine2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.0, float(ly) + 1.5, self.ledge, mine2_foe(dice, self.danger, True), 180.0);
        build.supply(float(lx) + 1.5, float(self.wide) - 2.5, self.ledge, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on the floor of a flooded sump; taking it opens the closets
round it."""
node FloodedSump(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded sump (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 7);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
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
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(cave, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -self.deep, x1, side - 2, 0, 2);
        stair(build, x1 - self.deep, side - 4, -self.deep, 0, self.deep, 2);
        key_ambush(build, self.key, float(x1) - 4.5, float(cy) + 0.5, -self.deep, side, 0, [2, self.long - 5], [mine2_foe(dice, self.danger, True), mine2_foe(dice, self.danger)]);
        build.foe(float(x0 + 3) + 0.5, float(cy) + 2.5, -self.deep + 1, "monster_flipper", 0.0);
        build.foe(float(self.long) - 2.5, 2.0, 0, mine2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a ramp down to the way out."""
node Mine2Exit(Prefab) {
    has key: str = "",
        deep: int = 4,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Borehole exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(3, 5);
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
        stair(build, wall + 3 + self.deep, 2, low, 2, self.deep, self.wide - 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mine2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, low, mine2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine2's stretches: [name, role]."""
glob MINE2_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["descent", "flow"],
         ["channel", "hub"],
         ["channel", "flow"],
         ["sump", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine2's stretches by its name."""
def make_mine2(name: str, key: str) -> Prefab {
    if name == "landing" {
        return BoreheadLanding();
    }
    if name == "descent" {
        return BoreholeDescent();
    }
    if name == "channel" {
        return LavaChannel();
    }
    if name == "sump" {
        return FloodedSump(key=key if key else "key_silver");
    }
    return Mine2Exit(key=key);
}
