"""Prefabs drawn from Quake II's base3, the Comm Center: a dish on the
surface, the base sunk far below it, a hall half drowned with a catwalk
over the water, a control room round a sunken pit of consoles, the key
in a dish's control booth up a lift. Raised in base3's own palette.

- `DishYard`: the start. A yard under the sky, a comm dish on a pedestal
  in it up a stair; ways on from the yard's sides and the pedestal.
- `FloodedLevel`: a hall flooded below, a catwalk along its wall over the
  water broken in its middle, swum across and climbed out of by stairs
  either side.
- `ControlCenter`: a control room, a pit of consoles sunk in its middle,
  galleries along two walls up stairs; ways on from the floor, the pit and
  the galleries (a hub).
- `DishBooth`: the key in a control booth high on a wall, a lift up to it;
  taking it opens the closets.
- `CommExit`: the end. A door (a key's, as a gate), a lift shaft's foot,
  the way out at the bottom of a stair down."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush }

glob BASE3: str = "q2:base3";

"""base3's foes: soldiers and infantry, parasites and gunners deeper in."""
def base3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    if heavy and dice.chance(0.3 + 0.4 * danger) {
        return "monster_parasite";
    }
    return q2_foe(dice, danger, heavy);
}

"""The start: a yard, a comm dish on a pedestal up a stair."""
node DishYard(Prefab) {
    has pedestal: int = 4,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish yard";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.pedestal = dice.between(4, 5);
        self.tall = dice.between(20, 24);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0), Port(face=1, along=float(self.long // 2), floor=self.pedestal)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.pedestal);
        # The pedestal against the north wall, a stair up its west side,
        # the dish on it: a mast and a broad plate tilted on top.
        build.solid(cx - 4, self.wide - 8, 0, cx + 4, self.wide - 1, self.pedestal);
        stair(build, cx - 4 - self.pedestal, self.wide - 6, 0, 0, self.pedestal, 3);
        build.solid(cx, self.wide - 4, self.pedestal, cx + 1, self.wide - 3, self.pedestal + 6);
        build.solid(cx - 3, self.wide - 5, self.pedestal + 6, cx + 4, self.wide - 2, self.pedestal + 7);
        for y in range(self.wide - 6, self.wide - 3) {
            build.keep(yard, cx - 4, y, self.pedestal);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx + index % 2 * 3) + 0.5, 3.5 + float(index) * 3.0, 0, base3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 2.5, float(self.wide) - 6.5, self.pedestal, base3_foe(dice, self.danger, True), 270.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall flooded below, a catwalk along its wall over the water, broken in
its middle: swum across, a stair up out of the water either side."""
node FloodedLevel(Prefab) {
    has deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded level";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(5, 6);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 3), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=1, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        walk_y = self.wide - 5;
        gx0 = self.long // 2 - 3;
        gx1 = self.long // 2 + 3;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The water over the hall's floor, the catwalk along the north wall
        # (solid to the floor) but for the gap in its middle, a stair up out
        # of the water onto it either side of the gap.
        build.pool(1, 1, low, self.long - 1, self.wide - 1, 0, 2, False, False);
        build.solid(1, walk_y, low, gx0, self.wide - 1, 0);
        build.solid(gx1, walk_y, low, self.long - 1, self.wide - 1, 0);
        stair(build, gx0 - 2, walk_y - self.deep, low, 1, self.deep, 2);
        stair(build, gx1, walk_y - self.deep, low, 1, self.deep, 2);
        for x in [gx0 - 2, gx0 - 1, gx1, gx1 + 1] {
            build.keep(hall, x, walk_y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(6 + index * 8) + 0.5, 4.5, low, "monster_flipper", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(gx1 + 3 + index * 3) + 0.5, float(self.wide) - 2.5, 0, base3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(gx0) - 4.0, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A control room, a pit of consoles sunk in its middle, galleries along
two walls up stairs."""
node ControlCenter(Prefab) {
    has sunk: int = 3,
        gallery: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control center";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.sunk = dice.between(3, 4);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + 10;
        self.low = -self.sunk - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, -self.sunk);
        build.level(room, self.gallery);
        # The pit, steps down at its west and east ends, consoles in it.
        build.widen(room, cx - 7, cy - 4, -self.sunk, cx + 7, cy + 4, 0);
        stair(build, cx - 7 + self.sunk - 1, cy - 2, -self.sunk, 2, self.sunk, 4);
        stair(build, cx + 7 - self.sunk, cy - 2, -self.sunk, 0, self.sunk, 4);
        for x in [cx - 2, cx + 1] {
            build.solid(x, cy - 3, -self.sunk, x + 1, cy - 1, -self.sunk + 2);
            build.solid(x, cy + 1, -self.sunk, x + 1, cy + 3, -self.sunk + 2);
        }
        # The galleries along the north and south walls, a stair up to each
        # along the west wall.
        under = self.gallery - 1;
        build.solid(6, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(6, 1, under, self.long - 1, 4, self.gallery);
        stair(build, self.long - 4 - self.gallery, self.wide - 7, 0, 0, self.gallery, 3);
        stair(build, self.long - 4 - self.gallery, 4, 0, 0, self.gallery, 3);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(cy) + 0.5, -self.sunk, base3_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 6) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, self.gallery, base3_foe(dice, self.danger, True), 0.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a control booth high on a wall, a lift up to it; taking it
opens the closets."""
node DishBooth(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        booth: int = 7,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish booth (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.booth = dice.between(6, 8);
        self.tall = self.booth + 8;
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
        build.level(room, self.booth);
        build.doorway(room, self.enter);
        bx = self.long - 5;
        build.solid(bx, 1, self.booth - 1, self.long - 1, side, self.booth);
        build.solid(bx, 1, self.booth, bx + 1, cy - 2, self.booth + 2);
        build.solid(bx, cy + 3, self.booth, bx + 1, side, self.booth + 2);
        build.put_box({"classname": "func_plat", "height": str(self.booth * 16), "speed": "200"}, float(bx - 3), float(cy - 1), float(self.booth) - 0.5, float(bx), float(cy + 2), float(self.booth), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, bx, y, self.booth);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.booth, side, 0, [2, bx - 6], [base3_foe(dice, self.danger, True), base3_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.booth, base3_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a stair down to the way out at the bottom."""
node CommExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Comm exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BASE3;
        self.district = level_district(BASE3);
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        below = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(below, 0);
        build.doorway(hall, self.enter);
        build.widen(below, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        build.solid(wall + 1, 1, low, wall + 3, self.wide - 1, 0);
        stair(build, wall + 2 + self.deep, middle - 2, low, 2, self.deep, 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, base3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, low, base3_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""base3's stretches: [name, role]."""
glob BASE3_STRETCHES: list[list[str]] = [
         ["dish", "start"],
         ["flooded", "flow"],
         ["control", "hub"],
         ["control", "flow"],
         ["booth", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of base3's stretches by its name."""
def make_base3(name: str, key: str) -> Prefab {
    if name == "dish" {
        return DishYard();
    }
    if name == "flooded" {
        return FloodedLevel();
    }
    if name == "control" {
        return ControlCenter();
    }
    if name == "booth" {
        return DishBooth(key=key if key else "key_silver");
    }
    return CommExit(key=key);
}
