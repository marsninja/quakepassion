"""Prefabs drawn from e3m1, Termination Central: a base of metal over vats
and rivers of slime, crossed by walkways and teleporters, lifts up to its
control galleries, the gold key on a dais in slime reached by teleporter.
Raised in e3m1's own palette.

- `TerminationEntry`: the start. A hall, a pit of slime across it walked
  over, a balcony along its far end ridden up to by a lift; ways on from
  the balcony and the floor.
- `TeleportRelay`: a river of slime across a hall with no way over it but
  a teleporter to the far bank (and one back).
- `SlimeWorks`: a works of four vats of slime, walkways between them, a
  gallery along one wall ridden up to by a lift; ways on from the floor
  and the gallery (a hub).
- `GoldTerminal`: the key on a dais in a pool of slime, a teleporter onto
  it and one back; taking the key opens the closets in the wall.
- `TerminationExit`: the end. A door (a key's, as a gate) into a room, a
  moat of slime round a platform, a walkway to the slipgate on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M1: str = "q1:e3m1";

"""e3m1's foes: grunts and dogs, enforcers growing with the danger."""
def e3m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_enforcer", "monster_army"] if heavy else ["monster_army", "monster_army", "monster_dog"], ["monster_enforcer"], danger));
}

"""The start: a hall, a pit of slime across it walked over, a balcony
along its far end ridden up to by a lift."""
node TerminationEntry(Prefab) {
    has balcony: int = 7,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Termination entry";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(14, 16);
        self.balcony = dice.between(7, 8);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=3, along=float(self.long // 2), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        # The pit of slime, the walkway over it along the hall.
        x0 = 8;
        x1 = self.long - 9;
        build.pool(x0, 4, -3, x1, self.wide - 4, 0, 3, False, True, True);
        build.solid(x0, middle - 1, -3, x1, middle + 2, 0);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        # The balcony along the far end, the lift up to it.
        bx = self.long - 5;
        build.solid(bx, 1, self.balcony - 1, self.long - 1, self.wide - 1, self.balcony);
        build.put_box({"classname": "func_plat", "height": str(self.balcony * 16), "speed": "200"}, float(bx - 3), 1.0, float(self.balcony) - 0.5, float(bx), 4.0, float(self.balcony), kit_of(build.district).step);
        for y in range(1, 5) {
            build.keep(hall, bx, y, self.balcony);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 3.5 + float(index) * 5.0, 0, e3m1_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, float(middle) + 3.5 - float(index) * 7.0, self.balcony, e3m1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.balcony, "item_health");
    }
}

"""A river of slime across a hall, crossed by a teleporter to the far bank
(and one back)."""
node TeleportRelay(Prefab) {
    has tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport relay";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(24, 28);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(12, 14);
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # The river, a step up out of it onto the far bank too.
        x0 = 9;
        x1 = 16;
        build.pool(x0, 1, -3, x1, self.wide - 1, 0, 3);
        stair(build, x1 - 3, self.wide - 3, -3, 0, 3, 2);
        build.teleporter(5.5, float(middle) + 0.5, 0, float(self.long) - 5.0, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(x1) + 3.0, 3.5, 0, 3.0, 3.0, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 4)) {
            build.foe(float(x1) + 4.5 + float(index % 2) * 3.0, 3.5 + float(index) * 2.5, 0, e3m1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A works of four vats of slime, walkways between them, a gallery along
one wall ridden up to by a lift."""
node SlimeWorks(Prefab) {
    has gallery: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime works";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.tall = dice.between(17, 19);
        self.gallery = dice.between(8, 9);
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2) - 2.0, floor=0),
            Port(face=0, along=middle, floor=self.gallery),
            Port(face=3, along=float(self.long // 2) - 2.0, floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        works = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(works, self.gallery);
        # The vats, two by two, walkways between them.
        for vx in [5, self.long - 15] {
            for vy in [4, self.wide - 10] {
                build.pool(vx, vy, -2, vx + 6, vy + 6, 0, 3);
                build.solid(vx + 2, vy + 2, -2, vx + 4, vy + 4, 5);
            }
        }
        # The gallery along the east wall, the lift up to it.
        gx = self.long - 5;
        build.solid(gx, 1, self.gallery - 1, self.long - 1, self.wide - 1, self.gallery);
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, float(gx - 3), float(middle - 1), float(self.gallery) - 0.5, float(gx), float(middle + 2), float(self.gallery), kit_of(build.district).step);
        for y in range(middle - 2, middle + 3) {
            build.keep(works, gx, y, self.gallery);
        }
        build.doorway(works, self.enter);
        for port in self.taken {
            build.doorway(works, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(13 + index % 2 * 3) + 0.5, 3.0 + float(index) * 5.0, 0, e3m1_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 4.5 + float(index) * (float(self.wide) - 9.0), self.gallery, e3m1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, self.gallery, "item_health");
        build.supply(3.0, 3.0, 0, "item_shells");
        build.supply(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, "item_armor1");
    }
}

"""The key on a dais in a pool of slime, a teleporter onto it and one
back; taking the key opens the closets."""
node GoldTerminal(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold terminal (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 2;
        build.pool(x0, 3, -3, x1, side - 2, 0, 3);
        cx = (x0 + x1) // 2 + 1;
        build.solid(cx - 2, cy - 2, -3, cx + 2, cy + 2, 2);
        build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy), 2, 0.0);
        build.teleporter(float(cx) + 1.0, float(cy) + 1.0, 2, 3.0, 3.0, 0, 180.0);
        key_ambush(build, self.key, float(cx) + 1.0, float(cy) - 1.0, 2, side, 0, [2, self.long - 5], [e3m1_foe(dice, self.danger, True), e3m1_foe(dice, self.danger)]);
        build.foe(3.0, float(side) - 3.0, 0, e3m1_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a room, a moat of slime round a platform, a
walkway to the slipgate on it."""
node TerminationExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Termination exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M1;
        self.district = level_district(E3M1);
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The moat round the platform: a ring of slime, the walkway in.
        px0 = wall + 7;
        px1 = self.long - 4;
        build.pool(wall + 4, 2, -3, self.long - 1, self.wide - 2, 0, 3, False, True, True);
        build.solid(px0, middle - 3, -3, px1, middle + 3, 1);
        build.solid(wall + 4, middle - 1, -3, px0, middle + 1, 0);
        for y in range(middle - 1, middle + 1) {
            build.keep(room, wall + 3, y, 0);
        }
        build.way_out(float(px0 + px1) * 0.5, float(middle), 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px1) - 1.0, float(middle) + 2.0, 1, e3m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m1's stretches: [name, role]."""
glob E3M1_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["relay", "flow"],
         ["works", "hub"],
         ["works", "flow"],
         ["terminal", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m1's stretches by its name."""
def make_e3m1(name: str, key: str) -> Prefab {
    if name == "entry" {
        return TerminationEntry();
    }
    if name == "relay" {
        return TeleportRelay();
    }
    if name == "works" {
        return SlimeWorks();
    }
    if name == "terminal" {
        return GoldTerminal(key=key if key else "key_gold");
    }
    return TerminationExit(key=key);
}
