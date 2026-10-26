"""Prefabs drawn from e2m5, the Wizard's Manse: a manse of stone and metal,
its court and fountain, a grand stair down under a walkway, a sanctum of
terraces climbing one over another, the gold key at the top of a winding
stair, a way out down from a balcony. Raised in e2m5's own palette.

- `ManseCourt`: the start. A court under the sky, a fountain in it, a
  porch up a stair across its far end; ways on from the porch and court.
- `GrandStair`: a stair down the whole width of a hall to a floor far
  below, a walkway on along the wall over it; ways on below and above.
- `SanctumTerraces`: a sanctum climbing in two terraces up its far end,
  stairs between them; ways on from the floor and each terrace (a hub).
- `GoldSpire`: a stair winding up round a spire's walls to a landing, the
  key on it; taking it opens the closets at the foot.
- `ManseExit`: the end. A door (a key's, as a gate) out onto a balcony, a
  stair down from it to the slipgate below."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, spiral }
import from .e2m2 { spiral_landing }

glob E2M5: str = "q1:e2m5";

"""e2m5's foes: ogres and scrags, hell knights and fiends deeper in."""
def e2m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_ogre", "monster_wizard"], ["monster_demon1"] if heavy else ["monster_hell_knight"], danger));
}

"""The start: a court, a fountain in it, a porch up a stair."""
node ManseCourt(Prefab) {
    has porch: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Manse court";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(16, 20);
        self.porch = dice.between(4, 5);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.porch), Port(face=1, along=float(self.long - 5), floor=self.porch), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.porch);
        px = self.long - 10;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.porch);
        stair(build, px - self.porch, middle - 3, 0, 0, self.porch, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(court, px, y, self.porch);
        }
        # Columns along the porch's front.
        for y in range(3, self.wide - 3, 4) {
            if abs(y - middle) > 3 {
                build.solid(px, y, self.porch, px + 1, y + 1, self.tall - 4);
            }
        }
        # The fountain, a column in its middle.
        build.pool(8, middle - 3, -3, 14, middle + 3, 0, 2);
        build.solid(11, middle, -3, 12, middle + 1, 4);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(px) + 3.5, 3.5 + float(index) * 5.0, self.porch, e2m5_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(px) - 6.5, 3.5 + float(index) * (float(self.wide) - 7.0), 0, e2m5_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, self.porch, "item_health");
    }
}

"""A stair down the whole width of a hall to a floor far below, a walkway
on along the wall over it."""
node GrandStair(Prefab) {
    has deep: int = 9,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grand stair";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(9, 10);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2) - 1.0;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=3, along=float(self.long - 4), floor=-self.deep), Port(face=0, along=float(self.wide - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        walk_y = self.wide - 5;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The landing in, and the stair down from it across the width.
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        stair(build, 5 + self.deep, 1, low, 2, self.deep, walk_y - 1);
        # The walkway along the north wall, a slab over the floor below,
        # piers under it.
        build.solid(6, walk_y, -1, self.long - 1, self.wide - 1, 0);
        for x in range(8 + self.deep, self.long - 2, 5) {
            build.solid(x, walk_y, low, x + 1, walk_y + 1, -1);
        }
        for x in range(6, self.long - 1) {
            if x % 6 != 0 {
                build.keep(hall, x, walk_y, 0);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 4) + 0.5, 3.5 + float(index % 2) * 3.0, low, e2m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 4.5, low + 6, "monster_wizard", 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide) - 2.5, 0, e2m5_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, low, "item_health");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A sanctum climbing in two terraces up its far end, stairs between them;
ways on from the floor and each terrace."""
node SanctumTerraces(Prefab) {
    has first: int = 5,
        second: int = 10,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sanctum terraces";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.first = dice.between(5, 6);
        self.second = self.first + 5;
        self.tall = self.second + dice.between(10, 12);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.second),
            Port(face=1, along=float(self.long - 10), floor=self.first),
            Port(face=3, along=float(self.long // 2 - 4), floor=0),
            Port(face=1, along=6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.first);
        build.level(hall, self.second);
        t1 = self.long - 13;
        t2 = self.long - 7;
        build.solid(t1, 1, 0, self.long - 1, self.wide - 1, self.first);
        build.solid(t2, 1, 0, self.long - 1, self.wide - 1, self.second);
        stair(build, t1 - self.first, middle - 2, 0, 0, self.first, 4);
        stair(build, t2 - 5, 2, self.first, 0, 5, 3);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, t1, y, self.first);
        }
        for y in range(2, 5) {
            build.keep(hall, t2, y, self.second);
        }
        clear = [[0, middle - 3, 5, middle + 3], [t1 - self.first - 1, middle - 3, t1, middle + 3]];
        pillars(build, 5, 4, t1 - 2, 5, 0, self.tall, 5, clear);
        pillars(build, 5, self.wide - 5, t1 - 2, self.wide - 4, 0, self.tall, 5, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, e2m5_foe(dice, self.danger), 0.0);
        }
        build.foe(float(t1) + 3.5, float(self.wide) - 3.5, self.first, e2m5_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.second, e2m5_foe(dice, self.danger, True), 180.0);
        build.foe(float(t1) - 4.5, float(middle) + 0.5, self.second + 2, "monster_wizard", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.second, "item_health");
        build.supply(float(t1) + 2.5, 2.5, self.first, "item_shells");
    }
}

"""A stair winding up round a spire's walls to a landing, the key on it;
taking it opens the closets at the foot."""
node GoldSpire(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 15,
        steps: int = 12,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold spire (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(14, 16);
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        fits: list[int] = [];
        for steps in range(10, 18) {
            landing = spiral_landing(self.long, self.hall_wide, steps, 4);
            if landing and landing[0] != 2.0 and landing[0] != 1.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
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
        spire = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(spire, self.steps);
        build.doorway(spire, self.enter);
        landing = spiral(build, 1, 1, self.long - 1, side, 0, self.steps, 3, 4);
        top = landing[2];
        key_ambush(build, self.key, float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.steps, side, 0, [4, self.long - 7], [e2m5_foe(dice, self.danger, True), e2m5_foe(dice, self.danger)]);
        build.foe(float(self.long // 2) + 0.5, float(side // 2) + 0.5, 0, e2m5_foe(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(side // 2) + 0.5, self.steps - 2, "monster_wizard", 180.0);
        build.supply(2.5, float(side) - 4.5, 0, "item_health");
    }
}

"""The end: a door out onto a balcony, a stair down from it to the
slipgate below."""
node ManseExit(Prefab) {
    has key: str = "",
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Manse exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(11, 13);
        self.low = -7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = self.long - 15;
        hall = build.room(1, 1, 0, wall, self.wide - 1, self.tall, variant=dice.below(3));
        below = build.room(wall + 1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(below, 0);
        build.doorway(hall, self.enter);
        build.widen(below, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The balcony past the door, and the stair down off its south side.
        build.solid(wall + 1, 1, -6, wall + 5, self.wide - 1, 0);
        stair(build, wall + 10, 1, -6, 2, 6, 3);
        for y in range(1, 4) {
            build.keep(below, wall + 4, y, 0);
        }
        build.way_out(float(self.long) - 3.0, float(middle), -6);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 5.5, float(self.wide) - 3.5, -6, e2m5_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, -1, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m5's stretches: [name, role]."""
glob E2M5_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["stair", "flow"],
         ["terraces", "hub"],
         ["terraces", "flow"],
         ["spire", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m5's stretches by its name."""
def make_e2m5(name: str, key: str) -> Prefab {
    if name == "court" {
        return ManseCourt();
    }
    if name == "stair" {
        return GrandStair();
    }
    if name == "terraces" {
        return SanctumTerraces();
    }
    if name == "spire" {
        return GoldSpire(key=key if key else "key_gold");
    }
    return ManseExit(key=key);
}
