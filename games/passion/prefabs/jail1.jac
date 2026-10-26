"""Prefabs drawn from Quake II's jail1, the Main Gate: a prison behind its
moat, a gatehouse whose portcullis a guard's button raises, a yard round
a guard tower whose top is bridged to the wall-walk, the key in the
warden's office. Raised in jail1's own palette.

- `PrisonMoat`: the start. Open ground under the sky, a moat before the
  prison's wall, a bridge over it to the gate; the moat's banks stepped.
- `Gatehouse`: a guard room, a portcullis across its far end raised by a
  button on a balcony up a stair; the way on beyond the portcullis.
- `GuardTowerYard`: a yard round a guard tower, a stair up the tower and a
  bridge from its top to the wall-walk; ways on below and from the walk
  (a hub).
- `WardenOffice`: the key on the warden's desk in an office over the yard
  up a stair; taking it opens the cells along the wall.
- `CellBlockExit`: the end. A door (a key's, as a gate), a block of cells,
  the way out at its far end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob JAIL1: str = "q2:jail1";

"""jail1's foes: infantry and gunners, flyers, berserkers and a gladiator
deeper in."""
def jail1_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_infantry", "monster_infantry", "monster_gunner"], ["monster_gladiator"] if heavy else ["monster_berserk"], danger * 0.6 if heavy else danger));
}

"""The start: open ground, a moat before the prison's wall, a bridge over
it to the gate."""
node PrisonMoat(Prefab) {
    has wall: int = 12,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Prison moat";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.wall = dice.between(11, 13);
        self.tall = dice.between(20, 24);
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
        build.pool(10, 1, -6, 16, self.wide - 1, 0, 2, False, True, True);
        stair(build, 10, self.wide - 3, -6, 0, 6, 2);
        build.solid(10, middle - 2, -1, 16, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(ground, 9, y, 0);
            build.keep(ground, 16, y, 0);
        }
        wx = self.long - 6;
        build.solid(wx, 1, 0, self.long - 1, self.wide - 1, self.wall);
        build.widen(ground, wx, middle - 2, 0, self.long - 1, middle + 2, 8);
        for y in range(2, self.wide - 2, 2) {
            build.solid(wx, y, self.wall, wx + 1, y + 1, self.wall + 2);
        }
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wx) - 3.5, 3.5 + float(index) * 5.0, 0, jail1_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wx) + 2.5, 4.5 + float(index) * 8.0, self.wall, jail1_foe(dice, self.danger), 180.0);
        }
        build.foe(13.0, float(middle) + 5.0, 6, jail1_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(wx) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A guard room, a portcullis across its far end raised by a button on a
balcony up a stair."""
node Gatehouse(Prefab) {
    has balcony: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gatehouse";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.balcony = dice.between(5, 6);
        self.tall = self.balcony + 8;
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
        px = self.long - 7;
        room = build.room(1, 1, 0, px, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(px + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.balcony);
        # The portcullis across the opening in the far wall.
        gate = build.name("portcullis");
        build.widen(beyond, px, middle - 3, 0, px + 1, middle + 3, 8);
        build.rising_door(float(px), float(middle - 3), 0.0, float(px + 1), float(middle + 3), 8.0, {"targetname": gate, "wait": "-1", "speed": "60"});
        # The balcony along the north wall up a stair, the button on the far
        # wall at its end.
        build.solid(4 + self.balcony, self.wide - 4, self.balcony - 1, px, self.wide - 1, self.balcony);
        stair(build, 4, self.wide - 4, 0, 0, self.balcony, 3);
        build.button(float(px), float(self.wide) - 2.5, float(self.balcony) + 1.3, 2, gate);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(px) - 4.5 - float(index) * 3.0, 3.5 + float(index % 2) * 3.0, 0, jail1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(px) - 2.5, float(self.wide) - 2.5, self.balcony, jail1_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, jail1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A yard round a guard tower, a stair up the tower, a bridge from its top
to the wall-walk."""
node GuardTowerYard(Prefab) {
    has tower: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard tower yard";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.tower = dice.between(8, 9);
        self.tall = self.tower + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tower),
            Port(face=0, along=float(self.wide - 3), floor=self.tower),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=middle - 3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.tower);
        # The wall-walk along the north and east walls at the tower's height.
        build.solid(1, self.wide - 4, 0, self.long - 1, self.wide - 1, self.tower);
        build.solid(self.long - 4, cy + 2, 0, self.long - 1, self.wide - 4, self.tower);
        # The tower, a stair up its west face, a bridge from its top north
        # to the walk.
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tower);
        stair(build, cx - 3 - self.tower, cy - 3, 0, 0, self.tower, 3);
        build.solid(cx - 2, cy + 3, self.tower - 1, cx + 2, self.wide - 4, self.tower);
        for y in range(cy - 3, cy) {
            build.keep(yard, cx - 3, y, self.tower);
        }
        for x in range(cx - 2, cx + 2) {
            build.keep(yard, x, cy + 2, self.tower);
            build.keep(yard, x, self.wide - 4, self.tower);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * 3.0, 0, jail1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.tower, jail1_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide) - 2.5, self.tower, jail1_foe(dice, self.danger), 180.0);
        build.foe(float(cx) + 6.5, float(cy) - 5.5, 10, jail1_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(cx) - 1.5, float(cy) - 1.5, self.tower, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key on the warden's desk in an office up a stair; taking it opens
the cells along the wall."""
node WardenOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Warden office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(5, 7);
        self.tall = self.office + 8;
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
        build.level(room, self.office);
        build.doorway(room, self.enter);
        ox = self.long - 7;
        build.solid(ox, 1, 0, self.long - 1, cy, self.office);
        stair(build, ox - self.office, 1, 0, 0, self.office, 2);
        build.solid(self.long - 4, 3, self.office, self.long - 2, 5, self.office + 1);
        key_ambush(build, self.key, float(self.long) - 3.0, 3.0, self.office + 1, side, 0, [2, 6, ox], [jail1_foe(dice, self.danger, True), jail1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 4.0, float(cy) - 2.0, self.office, jail1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a block of cells, the way out at its far end."""
node CellBlockExit(Prefab) {
    has key: str = "",
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell block exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(11, 13);
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
        # Cells along both walls: bays between cell walls.
        for x in range(wall + 3, self.long - 6, 4) {
            build.solid(x, 1, 0, x + 1, 4, self.tall);
            build.solid(x, self.wide - 4, 0, x + 1, self.wide - 1, self.tall);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.0, 2.5 + float(index) * 4.0, 0, jail1_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall + 5 + index * 4) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, jail1_foe(dice, self.danger), 90.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail1's stretches: [name, role]."""
glob JAIL1_STRETCHES: list[list[str]] = [
         ["moat", "start"],
         ["gatehouse", "flow"],
         ["tower", "hub"],
         ["tower", "flow"],
         ["warden", "keyroom"],
         ["cells", "end"],
         ["cells", "gate"]
     ];

"""One of jail1's stretches by its name."""
def make_jail1(name: str, key: str) -> Prefab {
    if name == "moat" {
        return PrisonMoat();
    }
    if name == "gatehouse" {
        return Gatehouse();
    }
    if name == "tower" {
        return GuardTowerYard();
    }
    if name == "warden" {
        return WardenOffice(key=key if key else "key_silver");
    }
    return CellBlockExit(key=key);
}
