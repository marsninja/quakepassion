"""Prefabs drawn from Quake II's security, Grid Control: a short, tall run of
rooms riding lifts, a lift tower climbed platform by platform, the grid's
control room where a super tank waits, the key in a monitor room over
it. Raised in security's own palette.

- `GridEntry`: the start. A hall, a raised walk along one wall up a stair;
  ways on from the floor and the walk.
- `LiftTower`: a tower of lifts, each up from a platform to the next on
  the wall across, the way on from the top.
- `GridControl`: a tall control room, consoles round its walls, a balcony
  over it on two walls up a lift, the super tank on its floor late in a
  run; ways on from the floor and the balcony (a hub).
- `MonitorRoom`: the key in a monitor room up a lift; taking it opens the
  closets below.
- `GridExit`: the end. A door (a key's, as a gate), a lift down to the way
  out at the bottom."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob SECURITY: str = "q2:security";

"""security's foes: berserkers and tanks, gunners and gladiators beside."""
def security_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_gladiator"] if heavy else ["monster_berserk", "monster_gunner", "monster_infantry"], ["monster_tank"] if heavy else ["monster_gladiator"], danger * 0.5 if heavy else danger));
}

"""The start: a hall, a raised walk along one wall up a stair."""
node GridEntry(Prefab) {
    has walk: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid entry";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.walk = dice.between(4, 5);
        self.tall = dice.between(13, 15);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.walk), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        wy = self.wide - 5;
        build.solid(6 + self.walk, wy, 0, self.long - 1, self.wide - 1, self.walk);
        stair(build, 6, wy, 0, 0, self.walk, 4);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) - 1.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 4) + 0.5, 3.5 + float(index % 2) * 3.0, 0, security_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, self.walk, security_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A tower of lifts, each up from a platform to the next on the wall
across."""
node LiftTower(Prefab) {
    has rise_by: int = 6,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lift tower";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(14, 16);
        self.wide = dice.between(16, 18);
        self.rise_by = dice.between(6, 7);
        self.tall = 3 * self.rise_by + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=3 * self.rise_by), Port(face=3, along=float(self.long // 2), floor=2 * self.rise_by)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        r = self.rise_by;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [r, 2 * r, 3 * r] {
            build.level(tower, z);
        }
        north = self.wide - 5;
        # Platforms: the first and third along the north wall, the second
        # along the south; lifts between, each beside the platform it leaves.
        build.solid(1, north, r - 1, self.long - 1, self.wide - 1, r);
        build.solid(1, 1, 2 * r - 1, self.long - 1, 5, 2 * r);
        build.solid(1, north, 3 * r - 1, self.long - 1, self.wide - 1, 3 * r);
        lift(build, self.long - 5, north - 3, self.long - 2, north, 0, r);
        lift(build, 2, 5, 5, north, r, 2 * r);
        lift(build, self.long - 5, 5, self.long - 2, north, 2 * r, 3 * r);
        for x in range(1, self.long - 1) {
            build.keep(tower, x, north, r);
            build.keep(tower, x, 4, 2 * r);
            build.keep(tower, x, north, 3 * r);
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, r, security_foe(dice, self.danger), 270.0);
        build.foe(float(self.long // 2) + 0.5, 2.5, 2 * r, security_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 3 * r, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide // 2) + 0.5, 0, Q2_ARMOR, "q2");
    }
}

"""A tall control room, consoles round its walls, a balcony over it on two
walls up a lift, the super tank on its floor late in a run."""
node GridControl(Prefab) {
    has balcony: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid control";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.balcony = dice.between(8, 9);
        self.tall = self.balcony + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.balcony),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.balcony);
        under = self.balcony - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.balcony);
        build.solid(self.long - 4, cy + 3, under, self.long - 1, self.wide - 4, self.balcony);
        lift(build, 2, self.wide - 7, 5, self.wide - 4, 0, self.balcony);
        for x in range(1, 6) {
            build.keep(room, x, self.wide - 4, self.balcony);
        }
        # Consoles round the floor's walls, a gap before each way on.
        for x in range(4, self.long - 4, 3) {
            if abs(x - cx) > 3 {
                build.solid(x, 1, 0, x + 2, 2, 2);
            }
        }
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, 3);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        boss = "monster_supertank" if self.danger > 0.75 else "monster_tank";
        build.foe(float(cx) + 5.5, float(cy) + 0.5, 0, boss, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 5) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, security_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(self.wide) - 2.5, self.balcony, security_foe(dice, self.danger), 270.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.balcony, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(cx) - 4.5, float(cy) - 4.5, 0, "ammo_rockets", "q2");
    }
}

"""The key in a monitor room up a lift; taking it opens the closets
below."""
node MonitorRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Monitor room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.upper = dice.between(6, 7);
        self.tall = self.upper + 8;
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
        build.level(room, self.upper);
        build.doorway(room, self.enter);
        mx = self.long - 6;
        build.solid(mx, 1, self.upper - 1, self.long - 1, side, self.upper);
        build.solid(self.long - 2, 2, self.upper, self.long - 1, side - 1, self.upper + 3);
        lift(build, mx - 3, cy - 1, mx, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, mx, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.upper, side, 0, [2, mx - 5], [security_foe(dice, self.danger, True), security_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper, security_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a lift shaft down to the way out at the bottom."""
node GridExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = SECURITY;
        self.district = level_district(SECURITY);
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
        stair(build, wall + 3 + self.deep, 2, low, 2, self.deep, 3);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, security_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, low, security_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""security's stretches: [name, role]."""
glob SECURITY_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["tower", "flow"],
         ["control", "hub"],
         ["control", "flow"],
         ["monitor", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of security's stretches by its name."""
def make_security(name: str, key: str) -> Prefab {
    if name == "entry" {
        return GridEntry();
    }
    if name == "tower" {
        return LiftTower();
    }
    if name == "control" {
        return GridControl();
    }
    if name == "monitor" {
        return MonitorRoom(key=key if key else "key_silver");
    }
    return GridExit(key=key);
}
