"""Prefabs drawn from Quake II's hangar2, the Inner Hangar: a gate into the
inner hangars, a repair bay of pits under a crane's rail, a shuttle bay
with a shuttle on a lift platform under galleries, the key in an armory
locker; the Hornet waits at the launch tube late in a run. Raised in
hangar2's own palette.

- `InnerGate`: the start. A gatehouse, a blast door across its far end and
  a guard post over it up a stair; ways on beyond.
- `RepairBay`: a bay of repair pits sunk in its floor, a crane rail walk
  along its wall, stairs down into the pits.
- `ShuttleBay`: a shuttle on a platform in a bay's middle, galleries along
  both walls up lifts, a bridge from one to the shuttle's roof; ways on
  from the floor and the galleries (a hub).
- `ArmoryLocker`: the key in a locker behind a door a button opens; taking
  it opens the closets.
- `LaunchExit`: the end. A door (a key's, as a gate), a launch tube, the
  way out at its end; the Hornet there late in a run."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob HANGAR2: str = "q2:hangar2";

"""hangar2's foes: gunners and berserkers, hovers and brains deeper in."""
def hangar2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_gunner"] if heavy else ["monster_gunner", "monster_gunner", "monster_hover"], ["monster_brain"] if heavy else ["monster_berserk"], danger * 0.4 if heavy else danger * 0.6));
}

"""The start: a gatehouse, a blast door across its far end, a guard post
over it up a stair."""
node InnerGate(Prefab) {
    has post: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Inner gate";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.post = dice.between(5, 6);
        self.tall = self.post + 9;
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
        gx = self.long - 6;
        hall = build.room(1, 1, 0, gx, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(gx + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.post);
        build.widen(beyond, gx, middle - 3, 0, gx + 1, middle + 3, 8);
        build.rising_door(float(gx), float(middle - 3), 0.0, float(gx + 1), float(middle + 3), 8.0, {"wait": "-1", "speed": "60"});
        build.solid(gx - 4, self.wide - 5, 0, gx, self.wide - 1, self.post);
        stair(build, gx - 4 - self.post, self.wide - 4, 0, 0, self.post, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(gx) - 6.5, 3.5 + float(index) * 4.0, 0, hangar2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(gx) - 2.0, float(self.wide) - 3.0, self.post, hangar2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, hangar2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A bay of repair pits sunk in its floor, a crane rail walk along its
wall, stairs down into the pits."""
node RepairBay(Prefab) {
    has pit: int = 4,
        rail: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Repair bay";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.pit = dice.between(3, 4);
        self.rail = dice.between(7, 8);
        self.tall = self.rail + 8;
        self.low = -self.pit - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.rail), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, -self.pit);
        build.level(bay, self.rail);
        for x0 in range(5, self.long - 9, 8) {
            build.widen(bay, x0, 4, -self.pit, x0 + 6, self.wide - 6, 0);
            stair(build, x0 + self.pit - 1, 4, -self.pit, 2, self.pit, 2);
            stair(build, x0 + 6 - self.pit, self.wide - 8, -self.pit, 0, self.pit, 2);
        }
        ry = self.wide - 4;
        build.solid(4 + self.rail, ry, self.rail - 1, self.long - 1, self.wide - 1, self.rail);
        stair(build, 4, ry, 0, 0, self.rail, 3);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(7 + index * 5) + 0.5, float(middle) + 0.5 - float(index % 2), -self.pit if index % 2 == 0 else 0, hangar2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, self.rail, hangar2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.rail, "ammo_bullets", "q2");
    }
}

"""A shuttle on a platform in a bay's middle, galleries along both walls
up lifts, a bridge from one to the shuttle's roof."""
node ShuttleBay(Prefab) {
    has gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shuttle bay";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.gallery = dice.between(8, 9);
        self.tall = self.gallery + 11;
        self.low = -1;
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
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, self.gallery);
        # The shuttle: a platform a lift high, the hull on it to the
        # gallery's height, its roof walked.
        build.solid(cx - 6, cy - 4, 0, cx + 6, cy + 4, 1);
        build.solid(cx - 5, cy - 2, 1, cx + 5, cy + 2, self.gallery);
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.gallery);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(cx - 1, cy + 2, under, cx + 2, self.wide - 4, self.gallery);
        lift(build, 2, 4, 5, 7, 0, self.gallery);
        lift(build, self.long - 5, self.wide - 7, self.long - 2, self.wide - 4, 0, self.gallery);
        for x in range(2, 5) {
            build.keep(bay, x, 3, self.gallery);
        }
        for x in range(self.long - 5, self.long - 2) {
            build.keep(bay, x, self.wide - 4, self.gallery);
        }
        for x in range(cx - 1, cx + 2) {
            build.keep(bay, x, cy + 1, self.gallery);
            build.keep(bay, x, self.wide - 4, self.gallery);
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 8 + index * 5) + 0.5, float(cy) + (6.5 if index % 2 == 0 else -6.5), 0, hangar2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 3.0, float(cy) + 0.5, self.gallery, hangar2_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 3.0, float(cy) + 0.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a locker behind a door a button opens; taking it opens the
closets."""
node ArmoryLocker(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Armory locker (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
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
        lx = self.long - 6;
        build.solid(lx, 1, 0, lx + 1, side, self.tall);
        door = build.name("locker");
        build.widen(room, lx, cy - 2, 0, lx + 1, cy + 2, 7);
        build.rising_door(float(lx), float(cy - 2), 0.0, float(lx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(lx), float(cy) + 3.5, 1.3, 2, door);
        for y in [2, side - 3] {
            build.solid(4, y, 0, lx - 2, y + 1, 4);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [6, lx - 4], [hangar2_foe(dice, self.danger, True), hangar2_foe(dice, self.danger)]);
        build.foe(float(lx) - 3.5, float(cy) - 3.0, 0, hangar2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a launch tube, the way out at its end; the Hornet there
late in a run."""
node LaunchExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Launch tube" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        for x in range(wall + 4, self.long - 3, 4) {
            build.solid(x, 1, 0, x + 1, 3, self.tall);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 1, self.tall);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        boss = "monster_boss2" if self.danger > 0.85 else "monster_gunner";
        build.foe(float(self.long) - 6.5, float(middle) + 3.5, 5 if boss == "monster_boss2" else 0, boss, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, hangar2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""hangar2's stretches: [name, role]."""
glob HANGAR2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["repair", "flow"],
         ["shuttle", "hub"],
         ["shuttle", "flow"],
         ["locker", "keyroom"],
         ["launch", "end"],
         ["launch", "gate"]
     ];

"""One of hangar2's stretches by its name."""
def make_hangar2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return InnerGate();
    }
    if name == "repair" {
        return RepairBay();
    }
    if name == "shuttle" {
        return ShuttleBay();
    }
    if name == "locker" {
        return ArmoryLocker(key=key if key else "key_silver");
    }
    return LaunchExit(key=key);
}
