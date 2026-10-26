"""Prefabs drawn from Quake II's mine3, the Drilling Area: a drilling
platform over a pit, a shaft climbed by a chain of lifts, a hall round a
great drill rig with a walk round its top, the key among core samples on
a rack. Raised in mine3's own palette.

- `DrillPlatform`: the start. A cavern, a platform out over a pit on its
  far side, a stair down into the pit; ways on from the platform's far
  end and the pit.
- `LiftChain`: a shaft, a lift from the floor to a ledge and another from
  the ledge to the top, the way on there.
- `DrillRig`: a hall round a great drill rig, a stair up its side to a walk
  round its top and bridges out to the walls; ways on from the floor and
  the bridges (a hub).
- `CoreSamples`: the key among core samples on a rack up steps; taking it
  opens the closets.
- `Mine3Exit`: the end. A door (a key's, as a gate), a passage up a ramp,
  the way out at its top."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, gate_into, lift }

glob MINE3: str = "q2:mine3";

"""mine3's foes: gunners and soldiers, gladiators and mutants, a tank
deeper in."""
def mine3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_soldier", "monster_gunner", "monster_soldier_light"], ["monster_tank", "monster_mutant"] if heavy else ["monster_mutant"], danger * 0.4 if heavy else danger * 0.7));
}

"""The start: a cavern, a platform out over a pit, a stair down into it."""
node DrillPlatform(Prefab) {
    has deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill platform";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(5, 7);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 6), floor=-self.deep), Port(face=1, along=5.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 0);
        px = 9;
        build.solid(1, 1, low, px, self.wide - 1, 0);
        # The platform out over the pit to the far wall, a stair down off its
        # north side into the pit.
        build.solid(px, middle - 2, -1, self.long - 1, middle + 2, 0);
        stair(build, px + self.deep - 1, self.wide - 4, low, 2, self.deep, 3);
        for x in range(px, self.long - 1) {
            if x % 5 == 0 {
                build.solid(x, middle - 2, low, x + 1, middle - 1, -1);
            }
        }
        clear = [[px, 0, px + self.deep + 1, self.wide], [self.long - 9, 0, self.long - 3, 4], [px, middle - 3, self.long, middle + 3]];
        boulders(build, dice, px, 1, self.long - 1, self.wide - 1, low, dice.between(3, 5), clear);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(px + 6 + index * 4) + 0.5, 3.5, low, mine3_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, mine3_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, low, Q2_HEALTH, "q2");
    }
}

"""A shaft, a lift from the floor to a ledge and another from the ledge to
the top."""
node LiftChain(Prefab) {
    has first: int = 8,
        second: int = 16,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lift chain";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        self.first = dice.between(7, 9);
        self.second = self.first + dice.between(7, 9);
        self.tall = self.second + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=self.second), Port(face=1, along=float(self.long // 2), floor=self.first)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.first);
        build.level(shaft, self.second);
        north = self.wide - 5;
        build.solid(1, north, self.first - 1, self.long - 1, self.wide - 1, self.first);
        build.solid(self.long - 5, 1, self.second - 1, self.long - 1, self.wide - 1, self.second);
        lift(build, 2, north - 3, 5, north, 0, self.first);
        lift(build, self.long - 8, north - 3, self.long - 5, north, self.first, self.second);
        for x in range(1, 6) {
            build.keep(shaft, x, north, self.first);
        }
        for y in range(north - 4, north) {
            build.keep(shaft, self.long - 5, y, self.second);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.0, self.first, mine3_foe(dice, self.danger), 270.0);
        build.foe(float(self.long) - 3.0, 3.5, self.second, mine3_foe(dice, self.danger, True), 90.0);
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, mine3_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.second, Q2_HEALTH, "q2");
    }
}

"""A hall round a great drill rig, a stair up its side to a walk round its
top and bridges out to the walls."""
node DrillRig(Prefab) {
    has rig: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill rig";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.rig = dice.between(7, 8);
        self.tall = self.rig + 13;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.rig),
            Port(face=0, along=middle, floor=self.rig),
            Port(face=3, along=float(self.long // 2) + 6.0, floor=0),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.rig);
        # The rig: a block, its drill column up through the roof, the walk
        # round its top three cells wide.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.rig);
        build.solid(cx - 1, cy - 1, self.rig, cx + 1, cy + 1, self.tall);
        stair(build, cx - 4, cy - 4 - self.rig, 0, 1, self.rig, 3);
        build.solid(cx - 2, cy + 4, self.rig - 1, cx + 2, self.wide - 1, self.rig);
        build.solid(cx + 4, cy - 2, self.rig - 1, self.long - 1, cy + 2, self.rig);
        for at in range(-2, 2) {
            build.keep(hall, cx + at, cy + 3, self.rig);
            build.keep(hall, cx + 3, cy + at, self.rig);
        }
        for x in range(cx - 4, cx - 1) {
            build.keep(hall, x, cy - 4, self.rig);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, mine3_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 2.5, float(cy) - 2.5, self.rig, mine3_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.rig, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key among core samples on a rack up steps; taking it opens the
closets."""
node CoreSamples(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        rack: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Core samples (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.rack = dice.between(3, 4);
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
        build.level(room, self.rack);
        build.doorway(room, self.enter);
        rx = self.long - 6;
        build.solid(rx, cy - 3, 0, self.long - 1, cy + 3, self.rack);
        stair(build, rx - self.rack, cy - 1, 0, 0, self.rack, 2);
        for y in [cy - 3, cy + 2] {
            for x in range(rx + 1, self.long - 1, 2) {
                build.solid(x, y, self.rack, x + 1, y + 1, self.rack + 3);
            }
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.rack, side, 0, [2, rx - 4], [mine3_foe(dice, self.danger, True), mine3_foe(dice, self.danger)]);
        build.foe(float(rx) - 3.5, 2.5, 0, mine3_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a passage up a ramp, the way out at its top."""
node Mine3Exit(Prefab) {
    has key: str = "",
        rise_to: int = 4,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.rise_to = dice.between(3, 5);
        self.tall = dice.between(12, 14);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        tx = self.long - 6;
        build.solid(tx, 1, 0, self.long - 1, self.wide - 1, self.rise_to);
        stair(build, tx - self.rise_to, middle - 2, 0, 0, self.rise_to, 4);
        build.way_out(float(self.long) - 3.0, float(middle), self.rise_to);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mine3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(tx) - 4.5, 2.5, 0, mine3_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine3's stretches: [name, role]."""
glob MINE3_STRETCHES: list[list[str]] = [
         ["platform", "start"],
         ["lifts", "flow"],
         ["rig", "hub"],
         ["rig", "flow"],
         ["samples", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine3's stretches by its name."""
def make_mine3(name: str, key: str) -> Prefab {
    if name == "platform" {
        return DrillPlatform();
    }
    if name == "lifts" {
        return LiftChain();
    }
    if name == "rig" {
        return DrillRig();
    }
    if name == "samples" {
        return CoreSamples(key=key if key else "key_silver");
    }
    return Mine3Exit(key=key);
}
