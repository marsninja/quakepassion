"""Prefabs drawn from Quake II's fact2, the Processing Plant: a plant of
door after door, a grinder over a pit of slime walked round on ledges, a
hall round a control tower bridged to from its top, the key in a vault
behind a door its button opens. Raised in fact2's own palette.

- `PlantGate`: the start. An entrance hall, a row of doors across its far
  end into the plant; ways on through them.
- `GrinderPit`: a pit of slime under a grinder across a room, ledges along
  its walls walked round it and a catwalk over its middle.
- `ControlTower`: a hall round a control tower, a stair up the tower's
  side, bridges from its top to ways on high in two walls; ways on below
  too (a hub).
- `PlantVault`: the key in a vault behind a door its button beside it
  opens; taking it opens the closets.
- `Fact2Exit`: the end. A door (a key's, as a gate), a corridor of doors,
  the way out at its end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob FACT2: str = "q2:fact2";

"""fact2's foes: soldiers and gunners, parasites and flyers, a gladiator
or a tank deeper in."""
def fact2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_parasite"] if heavy else ["monster_soldier_light", "monster_soldier_ss", "monster_gunner"], ["monster_gladiator", "monster_tank"] if heavy else ["monster_infantry"], danger * 0.4 if heavy else danger * 0.7));
}

"""The start: an entrance hall, a row of doors across its far end."""
node PlantGate(Prefab) {
    has tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant gate";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(12, 14);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=4.0, floor=0), Port(face=0, along=float(self.wide - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gx = self.long - 6;
        hall = build.room(1, 1, 0, gx, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(gx + 1, 1, 0, self.long - 1, self.wide - 1, 10, variant=dice.below(3));
        for y0 in [2, middle - 2, self.wide - 6] {
            build.widen(beyond, gx, y0, 0, gx + 1, y0 + 4, 7);
            build.rising_door(float(gx), float(y0), 0.0, float(gx + 1), float(y0 + 4), 7.0, {"wait": "-1"});
        }
        for x in range(4, gx - 2, 5) {
            build.solid(x, 2, 0, x + 1, 3, self.tall);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 2, self.tall);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(gx) - 3.5, 4.5 + float(index) * 5.0, 0, fact2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, 0, fact2_foe(dice, self.danger, True), 180.0);
        build.supply(float(gx) - 2.5, float(self.wide) - 4.5, 0, Q2_HEALTH, "q2");
    }
}

"""A pit of slime under a grinder across a room, ledges along its walls
walked round it and a catwalk over its middle."""
node GrinderPit(Prefab) {
    has deep: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grinder pit";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
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
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 6;
        x1 = self.long - 6;
        build.pool(x0, 4, -self.deep, x1, self.wide - 4, 0, 3, False, True, True);
        stair(build, x1 - self.deep, 4, -self.deep, 0, self.deep, 2);
        stair(build, x1 - self.deep, self.wide - 6, -self.deep, 0, self.deep, 2);
        build.solid(x0, middle - 1, -1, x1, middle + 1, 0);
        # The grinder: rollers across the pit's middle under the catwalk.
        for x in range(x0 + 2, x1 - 2, 3) {
            build.solid(x, 4, -self.deep, x + 1, middle - 1, -2);
            build.solid(x, middle + 1, -self.deep, x + 1, self.wide - 4, -2);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 3 + index * 5) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, fact2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(x1) + 2.5, float(middle) + 0.5, 0, fact2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall round a control tower, a stair up its side, bridges from its top
to ways on high in two walls."""
node ControlTower(Prefab) {
    has tower: int = 7,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control tower";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tower = dice.between(7, 8);
        self.tall = self.tower + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tower),
            Port(face=0, along=middle, floor=self.tower),
            Port(face=3, along=float(self.long // 2) + 5.0, floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.tower);
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tower);
        build.solid(cx - 3, cy - 3, self.tower + 4, cx + 3, cy + 3, self.tower + 5);
        for corner in [[cx - 3, cy - 3], [cx + 2, cy - 3], [cx - 3, cy + 2], [cx + 2, cy + 2]] {
            build.solid(corner[0], corner[1], self.tower, corner[0] + 1, corner[1] + 1, self.tower + 4);
        }
        stair(build, cx - 3 - self.tower, cy - 3, 0, 0, self.tower, 3);
        build.solid(cx - 2, cy + 3, self.tower - 1, cx + 2, self.wide - 1, self.tower);
        build.solid(cx + 3, cy - 2, self.tower - 1, self.long - 1, cy + 2, self.tower);
        for at in range(-2, 2) {
            build.keep(hall, cx + at, cy + 2, self.tower);
            build.keep(hall, cx + 2, cy + at, self.tower);
        }
        for y in range(cy - 3, cy) {
            build.keep(hall, cx - 3, y, self.tower);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, fact2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.tower, fact2_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 1.5, float(cy) + 1.5, self.tower, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a vault behind a door its button beside it opens; taking it
opens the closets."""
node PlantVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT2;
        self.district = level_district(FACT2);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(room, self.enter);
        vx = self.long - 7;
        build.solid(vx, 1, 0, vx + 1, side, self.tall);
        door = build.name("vault");
        build.widen(room, vx, cy - 2, 0, vx + 1, cy + 2, 7);
        build.rising_door(float(vx), float(cy - 2), 0.0, float(vx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(vx), float(cy) + 3.5, 1.3, 2, door);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [3, vx - 5], [fact2_foe(dice, self.danger, True), fact2_foe(dice, self.danger)]);
        build.foe(float(vx) - 3.5, 2.5, 0, fact2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a corridor of doors, the way out at its end."""
node Fact2Exit(Prefab) {
    has key: str = "",
        tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(12, 14);
        self.tall = dice.between(10, 12);
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
        wall = 7;
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        for x in [wall + 6, wall + 12] {
            if x < self.long - 5 {
                build.solid(x, 1, 0, x + 1, middle - 2, self.tall);
                build.solid(x, middle + 2, 0, x + 1, self.wide - 1, self.tall);
                build.solid(x, middle - 2, 8, x + 1, middle + 2, self.tall);
                build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 8.0, {"wait": "-1"});
            }
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.0, 2.5 + float(index) * 3.5, 0, fact2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall + 9) + 0.5, float(middle) + 0.5, 0, fact2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact2's stretches: [name, role]."""
glob FACT2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["grinder", "flow"],
         ["tower", "hub"],
         ["tower", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact2's stretches by its name."""
def make_fact2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PlantGate();
    }
    if name == "grinder" {
        return GrinderPit();
    }
    if name == "tower" {
        return ControlTower();
    }
    if name == "vault" {
        return PlantVault(key=key if key else "key_silver");
    }
    return Fact2Exit(key=key);
}
