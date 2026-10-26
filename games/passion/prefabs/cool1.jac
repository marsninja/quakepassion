"""Prefabs drawn from Quake II's cool1, the Cooling Facility: an intake hall
over coolant channels under grates, a great pipe half full of coolant
walked along its ledge, a cooling tower wound up round its walls over a
pool, the key in a valve room behind a door a valve-wheel button opens.
Raised in cool1's own palette.

- `CoolingIntake`: the start. A hall, coolant channels across its floor
  under grates, a walk over them; ways on beyond.
- `CoolantPipe`: a great pipe, coolant down its bottom, a ledge along its
  side to a stair up at the far end.
- `CoolingTower`: a tall tower, a pool at its foot, a stair winding up its
  walls to a landing and a way on high in its wall; ways on from the floor
  and the landing (a hub).
- `ValveRoom`: the key in a valve room behind a door its valve opens;
  taking it opens the closets.
- `Cool1Exit`: the end. A door (a key's, as a gate), a pumping gallery, the
  way out over the pumps."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, spiral, ring_landing }

glob COOL1: str = "q2:cool1";

"""cool1's foes: gunners and berserkers, iron maidens and hovers,
gladiators deeper in."""
def cool1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gladiator", "monster_berserk"] if heavy else ["monster_gunner", "monster_berserk", "monster_chick"], ["monster_gladiator"] if heavy else ["monster_hover"], danger * 0.4 if heavy else danger * 0.6));
}

"""The start: a hall, coolant channels across its floor under grates."""
node CoolingIntake(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cooling intake";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(13, 15);
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
        for cx in [8, 16] {
            build.pool(cx, 1, -3, cx + 4, self.wide - 1, 0, 2);
            stair(build, cx + 1, self.wide - 4, -3, 0, 3, 3);
            build.solid(cx, middle - 2, -1, cx + 4, middle + 2, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 8) + 0.5, 3.5 + float(index % 2) * 9.0, 0, cool1_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A great pipe, coolant down its bottom, a ledge along its side to a stair
up at the far end."""
node CoolantPipe(Prefab) {
    has deep: int = 4,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Coolant pipe";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(12, 14);
        self.deep = dice.between(3, 4);
        self.tall = dice.between(9, 11);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=3.0, floor=3), Port(face=1, along=float(self.long - 4), floor=3)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        pipe = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pipe, 3);
        # The coolant along the pipe's north side, the ledge along its south.
        build.pool(1, 5, -self.deep, self.long - 1, self.wide - 1, 0, 2, False, False);
        for x in [3, self.long // 2, self.long - 8] {
            stair(build, x, 4 + self.deep, -self.deep, 3, self.deep, 2);
        }
        # Ribs round the pipe, and a stair up off the ledge at the far end
        # to a landing over the coolant.
        for x in range(4, self.long - 6, 4) {
            build.solid(x, 1, self.tall - 1, x + 1, self.wide - 1, self.tall);
        }
        stair(build, self.long - 8, 1, 0, 0, 3, 3);
        build.solid(self.long - 5, 1, 0, self.long - 1, self.wide - 1, 3);
        build.doorway(pipe, self.enter);
        for port in self.taken {
            build.doorway(pipe, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, 2.5, 0, cool1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 2.5, float(self.wide) - 3.0, -self.deep + 1, "monster_flipper", 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 3, Q2_HEALTH, "q2");
    }
}

"""A tall tower, a pool at its foot, a stair winding up its walls to a
landing and a way on high in its wall."""
node CoolingTower(Prefab) {
    has steps: int = 12,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cooling tower";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(22, 24);
        self.wide = dice.between(22, 24);
        fits: list[int] = [];
        for steps in range(10, 30) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 10;
        self.low = -4;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tower, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        build.pool(cx - 4, cy - 4, -3, cx + 4, cy + 4, 0, 2);
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 6 + index * 6) + 0.5, float(cy) + 6.5, 0, cool1_foe(dice, self.danger), 270.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 8, "monster_hover", 180.0);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 12, cool1_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) + 5.5, float(cy) - 5.5, 0, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a valve room behind a door its valve opens; taking it opens
the closets."""
node ValveRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Valve room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = COOL1;
        self.district = level_district(COOL1);
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
        door = build.name("valve");
        build.widen(room, vx, cy - 2, 0, vx + 1, cy + 2, 7);
        build.rising_door(float(vx), float(cy - 2), 0.0, float(vx + 1), float(cy + 2), 7.0, {"targetname": door, "wait": "-1"});
        build.button(float(vx), float(cy) - 4.5, 1.3, 2, door);
        for y in [3, side - 4] {
            build.solid(4, y, 0, vx - 2, y + 1, 2);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [6, vx - 5], [cool1_foe(dice, self.danger, True), cool1_foe(dice, self.danger)]);
        build.foe(float(vx) - 3.5, float(side) - 2.5, 0, cool1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a pumping gallery, the way out over the pumps."""
node Cool1Exit(Prefab) {
    has key: str = "",
        gallery: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump gallery" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(3, 5);
        self.tall = dice.between(13, 15);
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
        gx = self.long - 7;
        build.solid(gx, 1, 0, self.long - 1, self.wide - 1, self.gallery);
        stair(build, gx - self.gallery, middle - 2, 0, 0, self.gallery, 4);
        for y in [2, self.wide - 5] {
            build.solid(wall + 3, y, 0, wall + 6, y + 3, 4);
        }
        build.way_out(float(self.long) - 3.0, float(middle), self.gallery);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, cool1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(gx) - 4.5, float(self.wide) - 3.0, 0, cool1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""cool1's stretches: [name, role]."""
glob COOL1_STRETCHES: list[list[str]] = [
         ["intake", "start"],
         ["pipe", "flow"],
         ["tower", "hub"],
         ["tower", "flow"],
         ["valve", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of cool1's stretches by its name."""
def make_cool1(name: str, key: str) -> Prefab {
    if name == "intake" {
        return CoolingIntake();
    }
    if name == "pipe" {
        return CoolantPipe();
    }
    if name == "tower" {
        return CoolingTower();
    }
    if name == "valve" {
        return ValveRoom(key=key if key else "key_silver");
    }
    return Cool1Exit(key=key);
}
