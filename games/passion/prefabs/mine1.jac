"""Prefabs drawn from Quake II's mine1, the Upper Mines: workings cut into
the mountain, a shaft head over a long drop with a lift's cage beside
it, a gallery shored with timbers, a cavern climbed ledge by ledge, the
key in a drill room behind a door a button opens. Raised in mine1's own
palette.

- `ShaftHead`: the start. A cavern, a shaft dropping far down through its
  middle railed round, the way on across a walk beside it.
- `ShoredGallery`: a long gallery, timber props down both sides, a rock
  fall half across it climbed over.
- `LedgeCavern`: a cavern of ledges stepping up its far wall, stairs of
  rock between; ways on from the floor and the top ledge (a hub).
- `DrillRoom`: the key in a drill room behind a door a button opens;
  taking it opens the closets.
- `Mine1Exit`: the end. A door (a key's, as a gate), a cage down to the way
  out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, stalactites, key_ambush, gate_into }

glob MINE1: str = "q2:mine1";

"""mine1's foes: soldiers and gunners, hovers, gladiators deeper in."""
def mine1_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover";
    }
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_soldier", "monster_soldier", "monster_gunner"], ["monster_mutant"] if heavy else ["monster_gladiator"], danger * 0.5 if heavy else danger * 0.7));
}

"""The start: a cavern, a shaft dropping far down through its middle, a
walk beside it."""
node ShaftHead(Prefab) {
    has deep: int = 10,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shaft head";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
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
        low = -self.deep;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, low);
        # The shaft: a pit through the cavern's middle, a stair down its
        # north wall to its floor for whoever falls.
        sx0 = 8;
        sx1 = self.long - 8;
        build.widen(cave, sx0, 4, low, sx1, self.wide - 4, 0);
        stair(build, sx0, self.wide - 6, low, 0, self.deep, 2);
        clear = [[0, middle - 3, 5, middle + 3], [sx0 - 2, 0, sx1 + 2, self.wide], [self.long - 6, 0, self.long, self.wide]];
        boulders(build, dice, 1, 1, sx0 - 1, self.wide - 1, 0, dice.between(2, 4), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(5, 8));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx1) + 2.5, 3.5 + float(index) * 5.0, 0, mine1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 4, mine1_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(sx0) + 2.5, float(middle) + 0.5, low, Q2_HEALTH, "q2");
    }
}

"""A long gallery, timber props down both sides, a rock fall half across
it climbed over."""
node ShoredGallery(Prefab) {
    has fall: int = 4,
        tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shored gallery";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(12, 14);
        self.fall = dice.between(3, 4);
        self.tall = dice.between(10, 12);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gallery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for x in range(4, self.long - 4, 4) {
            build.solid(x, 1, 0, x + 1, 2, self.tall);
            build.solid(x, self.wide - 2, 0, x + 1, self.wide - 1, self.tall);
            build.solid(x, 1, self.tall - 1, x + 1, self.wide - 1, self.tall);
        }
        # The rock fall: a heap across the gallery's middle, stepped up and
        # down, a gap left along one wall to squeeze by beneath the roof.
        fx = self.long // 2 - self.fall;
        for step in range(self.fall) {
            build.solid(fx + step, 2, 0, fx + step + 1, self.wide - 2, step + 1);
            build.solid(fx + 2 * self.fall - step, 2, 0, fx + 2 * self.fall - step + 1, self.wide - 2, step + 1);
        }
        build.solid(fx + self.fall, 2, 0, fx + self.fall + 1, self.wide - 2, self.fall);
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx + 2 * self.fall + 3 + index * 3) + 0.5, float(middle) + (1.5 if index % 2 == 0 else -1.5), 0, mine1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(fx + self.fall) + 0.5, float(middle) + 0.5, self.fall, mine1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A cavern of ledges stepping up its far wall, stairs of rock between."""
node LedgeCavern(Prefab) {
    has rise_by: int = 4,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ledge cavern";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.rise_by = dice.between(4, 5);
        self.tall = 3 * self.rise_by + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        top = 3 * self.rise_by;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=top),
            Port(face=1, along=6.0, floor=0),
            Port(face=3, along=6.0, floor=0),
            Port(face=1, along=float(self.long - 4), floor=top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.rise_by;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # Three ledges stepping up toward the far wall, each the full width,
        # a stair of rock up each one's face, alternating sides.
        edges = [self.long - 16, self.long - 11, self.long - 6];
        for (index, x0) in enumerate(edges) {
            top = (index + 1) * r;
            build.level(cave, top);
            build.solid(x0, 1, 0, self.long - 1, self.wide - 1, top);
            y0 = 3 if index % 2 == 0 else self.wide - 6;
            stair(build, x0 - r, y0, top - r, 0, r, 3);
            for y in range(y0, y0 + 3) {
                build.keep(cave, x0, y, top);
            }
        }
        clear = [[0, middle - 3, 5, middle + 3], [3, 0, 9, 4], [3, self.wide - 4, 9, self.wide], [edges[0] - r - 1, 0, edges[0], self.wide]];
        boulders(build, dice, 1, 1, edges[0] - r - 1, self.wide - 1, 0, dice.between(3, 5), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(edges[0]) - 6.5, 4.5 + float(index) * 6.0, 0, mine1_foe(dice, self.danger), 0.0);
        }
        for (index, x0) in enumerate(edges) {
            build.foe(float(x0) + 2.5, float(middle) + 0.5, (index + 1) * r, mine1_foe(dice, self.danger, index == 2), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 3 * r + 4, mine1_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 3 * r, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a drill room behind a door a button opens; taking it opens
the closets."""
node DrillRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE1;
        self.district = level_district(MINE1);
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
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(cave, self.enter);
        dx = self.long - 8;
        build.solid(dx, 1, 0, dx + 1, side, self.tall);
        door = build.name("drill");
        build.widen(cave, dx, cy - 2, 0, dx + 1, cy + 2, 7);
        build.rising_door(float(dx), float(cy - 2), 0.0, float(dx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(dx), float(cy) - 4.5, 1.3, 2, door);
        # The drill: a rig in the room's far end.
        build.solid(self.long - 4, cy - 1, 0, self.long - 2, cy + 2, 5);
        key_ambush(build, self.key, float(dx) + 2.5, float(cy) + 0.5, 0, side, 0, [3, dx - 5], [mine1_foe(dice, self.danger, True), mine1_foe(dice, self.danger)]);
        build.foe(float(dx) - 3.5, float(side) - 3.0, 0, mine1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a cage down to the way out."""
node Mine1Exit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Mine cage" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(22, 24);
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
        build.solid(wall + 1, 1, low, wall + 4, self.wide - 1, 0);
        stair(build, wall + 3 + self.deep, middle - 2, low, 2, self.deep, 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mine1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, 2.5, low, mine1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine1's stretches: [name, role]."""
glob MINE1_STRETCHES: list[list[str]] = [
         ["shaft", "start"],
         ["gallery", "flow"],
         ["ledges", "hub"],
         ["ledges", "flow"],
         ["drill", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine1's stretches by its name."""
def make_mine1(name: str, key: str) -> Prefab {
    if name == "shaft" {
        return ShaftHead();
    }
    if name == "gallery" {
        return ShoredGallery();
    }
    if name == "ledges" {
        return LedgeCavern();
    }
    if name == "drill" {
        return DrillRoom(key=key if key else "key_silver");
    }
    return Mine1Exit(key=key);
}
