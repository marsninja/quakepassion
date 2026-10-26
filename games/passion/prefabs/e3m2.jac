"""Prefabs drawn from e3m2, the Vaults of Zin: a castle of vaults behind
door after door, its moat and drawbridge, a great hall with a balcony
reached by teleporter, the key across a pit of the dead. Raised in
e3m2's own palette.

- `ZinDrawbridge`: the start. Open ground, a moat across it, a drawbridge
  over it let down by shooting the button on the gatehouse beyond; the
  moat swum across in the meantime.
- `VaultCorridor`: a corridor shut across by door after door, bays along
  its walls between them, the dead in the bays.
- `ZinHall`: a great hall, a balcony across its far end reached by a
  teleporter in its middle and dropped from; ways on from the floor and
  the balcony (a hub).
- `ZinVault`: a pit across a vault, a narrow bridge over it, stairs up
  out of it, the key on the far side; taking it opens the closets.
- `ZinExit`: the end. A door (a key's, as a gate) into a chapel, the
  slipgate on a dais between pillars."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M2: str = "q1:e3m2";

"""e3m2's foes: the dead and ogres, scrags, fiends deeper in."""
def e3m2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_demon1"] if heavy else ["monster_wizard"], danger));
}

"""The start: open ground, a moat, a drawbridge let down by a button shot
on the gatehouse beyond."""
node ZinDrawbridge(Prefab) {
    has wall: int = 12,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin drawbridge";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.wall = dice.between(11, 13);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 9), floor=0), Port(face=3, along=float(self.long - 9), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        # The moat, steps up out of it on both banks.
        build.pool(10, 1, -5, 15, self.wide - 1, 0, 2);
        stair(build, 10, self.wide - 3, -5, 0, 5, 2);
        # The gatehouse wall, its gate through it.
        wall_x = self.long - 6;
        build.solid(wall_x, 1, 0, self.long - 1, self.wide - 1, self.wall);
        build.widen(ground, wall_x, middle - 2, 0, self.long - 1, middle + 2, 8);
        # The drawbridge, sunk under the moat until the button is shot.
        span = build.name("span");
        build.bridge(10.0, float(middle - 2), 15.0, float(middle + 2), 0, 6, span);
        build.button(float(wall_x), float(middle) + 4.5, 6.0, 2, span, True);
        for y in range(middle - 2, middle + 2) {
            build.keep(ground, 9, y, 0);
            build.keep(ground, 15, y, 0);
        }
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall_x) - 3.5, 3.5 + float(index) * 5.0, 0, e3m2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(wall_x) + 2.5, 3.5, self.wall, e3m2_foe(dice, self.danger, True), 180.0);
        build.supply(float(wall_x) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A corridor shut across by door after door, bays along its walls, the
dead in the bays."""
node VaultCorridor(Prefab) {
    has tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vault corridor";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(12, 14);
        self.tall = dice.between(11, 13);
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
        corridor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        doors = [self.long // 4, self.long // 2, 3 * self.long // 4];
        for x in doors {
            build.solid(x, 1, 0, x + 1, middle - 2, self.tall);
            build.solid(x, middle + 2, 0, x + 1, self.wide - 1, self.tall);
            build.solid(x, middle - 2, 8, x + 1, middle + 2, self.tall);
            build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 8.0, {"wait": "-1"});
        }
        # Bays: piers along both walls between the doors.
        bays: list[list[float]] = [];
        for x in range(3, self.long - 4, 3) {
            if x in doors or x - 1 in doors or x + 1 in doors {
                continue;
            }
            build.solid(x, 1, 0, x + 1, 3, self.tall);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 1, self.tall);
            bays.append([float(x) + 1.5, 2.0]);
            bays.append([float(x) + 1.5, float(self.wide) - 2.0]);
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        count = dice.between(3, 5);
        for index in range(min(count, len(bays))) {
            bay = bays[(index * 5 + 1) % len(bays)];
            build.foe(bay[0], bay[1], 0, "monster_zombie" if index % 2 == 0 else e3m2_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, e3m2_foe(dice, self.danger, True), 180.0);
        build.supply(float(doors[1]) + 2.5, float(middle) + 2.5, 0, "item_health");
        build.supply(float(doors[0]) - 2.5, float(middle) - 1.5, 0, "item_rockets");
    }
}

"""A great hall, a balcony across its far end reached by a teleporter in
its middle and dropped from."""
node ZinHall(Prefab) {
    has balcony: int = 9,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin hall";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(20, 24);
        self.balcony = dice.between(9, 10);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.balcony),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.balcony),
            Port(face=1, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.balcony);
        bx = self.long - 7;
        build.solid(bx, 1, self.balcony - 1, self.long - 1, self.wide - 1, self.balcony);
        for y in range(3, self.wide - 3) {
            build.keep(hall, bx, y, self.balcony);
        }
        build.teleporter(float(self.long // 2) - 2.0, float(middle) + 0.5, 0, float(self.long) - 3.5, float(middle) + 0.5, self.balcony, 180.0);
        clear = [[0, middle - 3, 5, middle + 3], [self.long // 2 - 5, middle - 3, self.long // 2 + 1, middle + 3], [6, self.wide - 4, 11, self.wide], [self.long // 2 - 3, 0, self.long // 2 + 3, 4]];
        pillars(build, 4, 4, bx - 1, 5, 0, self.tall, 4, clear);
        pillars(build, 4, self.wide - 5, bx - 1, self.wide - 4, 0, self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, e3m2_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * (float(self.wide) - 7.0), self.balcony, e3m2_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, self.balcony, "item_health");
        build.supply(2.5, 2.5, 0, "item_shells");
    }
}

"""A pit across a vault, a narrow bridge over it, the key on the far side;
taking it opens the closets."""
node ZinVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(13, 15);
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
        low = -self.deep;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, low);
        build.doorway(vault, self.enter);
        x0 = 6;
        x1 = self.long - 6;
        build.widen(vault, x0, 1, low, x1, side, 0);
        build.solid(x0, cy, low, x1, cy + 2, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        stair(build, x0 + self.deep - 1, side - 2, low, 2, self.deep, 2);
        for y in [cy, cy + 1] {
            build.keep(vault, x0 - 1, y, 0);
            build.keep(vault, x1, y, 0);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 1.0, 0, side, 0, [2, x1 + 1], [e3m2_foe(dice, self.danger, True), "monster_zombie"]);
        for index in range(dice.between(2, 4)) {
            build.foe(float(x0 + self.deep + index // 2) + 0.5, float(side) - 1.5 if index % 2 == 0 else 2.5, low, "monster_zombie", 270.0);
        }
        build.foe(float(self.long) - 2.5, 2.5, 0, e3m2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a chapel, the slipgate on a dais between pillars."""
node ZinExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(15, 17);
        self.low = -1;
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
        chapel = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(chapel, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        dais_x = self.long - 6;
        build.solid(dais_x, middle - 3, 0, self.long - 1, middle + 3, 2);
        stair(build, dais_x - 2, middle - 2, 0, 0, 2, 4);
        pillars(build, wall + 3, 2, self.long - 2, 3, 0, self.tall, 4, []);
        pillars(build, wall + 3, self.wide - 3, self.long - 2, self.wide - 2, 0, self.tall, 4, []);
        build.way_out(float(self.long) - 3.0, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dais_x) - 3.5, float(self.wide) - 4.5, 0, e3m2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m2's stretches: [name, role]."""
glob E3M2_STRETCHES: list[list[str]] = [
         ["drawbridge", "start"],
         ["corridor", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m2's stretches by its name."""
def make_e3m2(name: str, key: str) -> Prefab {
    if name == "drawbridge" {
        return ZinDrawbridge();
    }
    if name == "corridor" {
        return VaultCorridor();
    }
    if name == "hall" {
        return ZinHall();
    }
    if name == "vault" {
        return ZinVault(key=key if key else "key_silver");
    }
    return ZinExit(key=key);
}
