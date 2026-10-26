"""Prefabs drawn from e4m1, the Sewage System: sewers of metal and stone
where water runs everywhere, channels down halls between walkways, locks
stepping down level by level under a catwalk, settling tanks either side
of a raised spine, the gold key on a shelf across a sump swum to. Raised
in e4m1's own palette.

- `SewerOutfall`: the start. A channel down the length of a hall between
  two walkways, a pipe pouring into it; ways on from the walkways and the
  far end.
- `SewerLocks`: three floors stepping down a hall one under another, a
  basin in each, a catwalk along the wall over them all at the top's
  height; ways on below and from the catwalk.
- `SettlingTanks`: two deep tanks either side of a spine raised down the
  middle of a hall, a stair up it; ways on from the floor and the spine's
  end (a hub).
- `SumpKey`: the key on a shelf across a sump, swum to; taking it opens
  the closets on the near side.
- `SewerExit`: the end. A door (a key's, as a gate), a walkway over a
  channel to the slipgate."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E4M1: str = "q1:e4m1";

"""e4m1's foes: grunts and dogs, enforcers growing with the danger."""
def e4m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_enforcer", "monster_army"] if heavy else ["monster_army", "monster_army", "monster_dog"], ["monster_enforcer"], danger));
}

"""The start: a channel down a hall between two walkways, a pipe pouring
into it."""
node SewerOutfall(Prefab) {
    has tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer outfall";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(12, 14);
        self.low = -6;
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
        build.pool(5, middle - 3, -5, self.long - 5, middle + 3, 0, 2);
        stair(build, self.long - 10, middle - 3, -5, 0, 5, 2);
        # The pipe: a block on the far wall over the channel's end.
        build.solid(self.long - 3, middle - 2, 5, self.long - 1, middle + 2, 9);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 5) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, e4m1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, 2.5, 0, e4m1_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, -4, "monster_fish", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""Three floors stepping down a hall, a basin in each, a catwalk along the
wall over them all at the top's height."""
node SewerLocks(Prefab) {
    has step_down: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer locks";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.step_down = dice.between(3, 4);
        self.tall = dice.between(11, 13);
        self.low = -2 * self.step_down - 4;
        self.high = self.tall + 1;
        bottom = -2 * self.step_down;
        self.enter = Port(face=2, along=float(self.wide // 2) - 2.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2) - 2.0, floor=bottom), Port(face=3, along=float(self.long - 4), floor=bottom), Port(face=0, along=float(self.wide - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        drop = self.step_down;
        bottom = -2 * drop;
        walk_y = self.wide - 5;
        hall = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, -drop);
        build.level(hall, bottom);
        third = self.long // 3;
        # The floors: the first at the top, the second a drop down, the
        # third another, a stair down between each.
        build.solid(1, 1, bottom, third, walk_y, 0);
        build.solid(third, 1, bottom, 2 * third, walk_y, -drop);
        stair(build, third + drop - 1, 1, -drop, 2, drop, 3);
        stair(build, 2 * third + drop - 1, 1, bottom, 2, drop, 3);
        # A basin in each floor.
        for (index, floor_at) in enumerate([0, -drop, bottom]) {
            x0 = index * third + 4;
            build.pool(x0, walk_y - 5, floor_at - 2, x0 + 4, walk_y - 1, floor_at, 2);
        }
        # The catwalk along the north wall at the top's height.
        build.solid(1, walk_y, bottom, third, self.wide - 1, 0);
        build.solid(third, walk_y, -1, self.long - 1, self.wide - 1, 0);
        for x in range(third + 4, self.long - 2, 6) {
            build.solid(x, walk_y, bottom, x + 1, walk_y + 1, -1);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(2 * third + 3 + index * 3) + 0.5, 3.5, bottom, e4m1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(third + 3) + 0.5, 3.0, -drop, e4m1_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, 0, e4m1_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, bottom, "item_health");
        build.supply(float(third) + 2.5, float(self.wide) - 2.5, 0, "item_shells");
    }
}

"""Two deep tanks either side of a spine raised down the middle of a hall,
a stair up it."""
node SettlingTanks(Prefab) {
    has spine: int = 4,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Settling tanks";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.tall = dice.between(15, 17);
        self.spine = dice.between(4, 5);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.spine),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.spine);
        # The spine down the middle from a stair at its near end to the far
        # wall, three cells wide.
        sx = 6 + self.spine;
        build.solid(sx, cy - 1, 0, self.long - 1, cy + 2, self.spine);
        stair(build, 6, cy - 1, 0, 0, self.spine, 3);
        # The tanks either side of it, steps up out of each at both ends.
        build.pool(sx + 2, 4, -6, self.long - 4, cy - 2, 0, 2, False, True);
        build.pool(sx + 2, cy + 3, -6, self.long - 4, self.wide - 4, 0, 2, False, True);
        stair(build, self.long - 10, 4, -6, 0, 6, 2);
        stair(build, self.long - 10, self.wide - 6, -6, 0, 6, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx + 4 + index * 5) + 0.5, float(cy) + 0.5, self.spine, e4m1_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx + 3 + index * 6) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, e4m1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 6.5, -5, "monster_fish", 0.0);
        build.supply(float(self.long) - 2.5, float(cy) + 0.5, self.spine, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The key on a shelf across a sump, swum to; taking it opens the closets
on the near side."""
node SumpKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sump key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x1 = self.long - 5;
        build.pool(6, 1, -self.deep, x1, side, 0, 2);
        stair(build, x1 - self.deep, side - 2, -self.deep, 0, self.deep, 2);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [2], [e4m1_foe(dice, self.danger, True)]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(9 + index * 4) + 0.5, float(cy) + 0.5, -self.deep + 1, "monster_fish", 0.0);
        }
        build.foe(float(self.long) - 2.5, 2.5, 0, e4m1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a walkway over a channel to the slipgate."""
node SewerExit(Prefab) {
    has key: str = "",
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(11, 13);
        self.low = -5;
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The channel across the room, the walkway over it, steps up out of
        # it either side of the walkway.
        cx0 = wall + 4;
        cx1 = self.long - 5;
        build.pool(cx0, 1, -4, cx1, self.wide - 1, 0, 2, False, True, True);
        build.solid(cx0, middle - 1, -4, cx1, middle + 1, 0);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 2.5, 2.5, 0, e4m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m1's stretches: [name, role]."""
glob E4M1_STRETCHES: list[list[str]] = [
         ["outfall", "start"],
         ["locks", "flow"],
         ["tanks", "hub"],
         ["tanks", "flow"],
         ["sump", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m1's stretches by its name."""
def make_e4m1(name: str, key: str) -> Prefab {
    if name == "outfall" {
        return SewerOutfall();
    }
    if name == "locks" {
        return SewerLocks();
    }
    if name == "tanks" {
        return SettlingTanks();
    }
    if name == "sump" {
        return SumpKey(key=key if key else "key_gold");
    }
    return SewerExit(key=key);
}
