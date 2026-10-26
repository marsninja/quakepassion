"""Prefabs drawn from Quake II's waste2, the Waste Disposal works: a bay of
water channels under the sky, a sluice where a gate holds back the
water swum through once a button raises it, a pumping hall with pumps on
a dais under a gantry, the key in a filter room. Raised in waste2's own
palette.

- `ChannelBay`: the start. A bay under the sky, water channels across it,
  footbridges over them; ways on beyond.
- `Sluice`: a hall split by a sluice wall over a deep channel, a gate in
  the wall raised by a button; beyond, the way on.
- `PumpHall`: pumps on a raised floor in a hall's middle, a gantry over
  them reached by a lift; ways on from the floor and the gantry (a hub).
- `FilterRoom`: the key on a filter bed up steps across a pool; taking it
  opens the closets.
- `Waste2Exit`: the end. A door (a key's, as a gate), a drain shaft's
  rim, the way out on a ledge in it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob WASTE2: str = "q2:waste2";

"""waste2's foes: gunners and soldiers, flyers, gladiators deeper in."""
def waste2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gladiator", "monster_gunner"] if heavy else ["monster_soldier", "monster_gunner", "monster_flyer"], ["monster_gladiator"] if heavy else ["monster_berserk"], danger * 0.4 if heavy else danger * 0.6));
}

"""The start: a bay, water channels across it, footbridges over them."""
node ChannelBay(Prefab) {
    has tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Channel bay";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(16, 20);
        self.low = -5;
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
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for cx in [7, 15] {
            build.pool(cx, 1, -4, cx + 4, self.wide - 1, 0, 2, False, True, True);
            stair(build, cx, middle + 3, -4, 0, 4, 2);
            build.solid(cx, middle - 2, -1, cx + 4, middle + 1, 0);
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(12 + index % 2 * 8) + 0.5, 3.5 + float(index) * 4.0, 0, waste2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall split by a sluice wall over a deep channel, a gate in the wall
raised by a button."""
node Sluice(Prefab) {
    has deep: int = 5,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sluice";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = 4;
        self.tall = dice.between(12, 14);
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
        wx = self.long // 2;
        near = build.room(1, 1, 0, wx, self.wide - 1, self.tall, variant=dice.below(3));
        far = build.room(wx + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # The channel along the hall's south side under the wall, the wall's
        # gate over the north walk raised by a button.
        build.pool(3, 1, -self.deep, self.long - 3, 7, 0, 2);
        stair(build, self.long - 7, 1, -self.deep, 0, self.deep, 2);
        gate = build.name("sluice");
        build.widen(far, wx, middle - 1, 0, wx + 1, middle + 3, 7);
        build.rising_door(float(wx), float(middle - 1), 0.0, float(wx + 1), float(middle + 3), 7.0, {"targetname": gate, "wait": "-1"});
        build.button(float(wx), float(self.wide) - 3.5, 1.3, 2, gate);
        build.doorway(near, self.enter);
        for port in self.taken {
            build.doorway(far, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wx) - 4.5, float(middle) + 1.5 + float(index) * 2.0, 0, waste2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 2.5, 0, waste2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""Pumps on a raised floor in a hall's middle, a gantry over them reached
by a lift."""
node PumpHall(Prefab) {
    has dais: int = 2,
        gantry: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump hall";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.dais = dice.between(2, 3);
        self.gantry = dice.between(8, 9);
        self.tall = self.gantry + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gantry),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gantry)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.dais);
        build.level(hall, self.gantry);
        build.solid(cx - 6, cy - 5, 0, cx + 6, cy + 5, self.dais);
        stair(build, cx - 6 - self.dais, cy - 2, 0, 0, self.dais, 4);
        for x in [cx - 4, cx + 1] {
            for y in [cy - 3, cy + 1] {
                build.solid(x, y, self.dais, x + 3, y + 2, self.dais + 4);
            }
        }
        under = self.gantry - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gantry);
        lift(build, 2, self.wide - 7, 5, self.wide - 4, 0, self.gantry);
        for x in range(1, 6) {
            build.keep(hall, x, self.wide - 4, self.gantry);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, 4.5 + float(index) * 3.0, 0, waste2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) - 0.5, self.dais, waste2_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 4.5, float(self.wide) - 2.5, self.gantry, waste2_foe(dice, self.danger), 270.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gantry, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on a filter bed up steps across a pool; taking it opens the
closets."""
node FilterRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        bed: int = 2,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Filter room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.bed = dice.between(2, 3);
        self.tall = dice.between(11, 13);
        self.low = -5;
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
        build.level(room, self.bed);
        build.doorway(room, self.enter);
        build.pool(5, 2, -4, self.long - 7, side - 1, 0, 2, False, True, True);
        build.solid(5, cy - 1, -4, self.long - 7, cy + 2, 0);
        bx = self.long - 7;
        build.solid(bx, 1, 0, self.long - 1, side, self.bed);
        stair(build, bx - self.bed, cy - 1, 0, 0, self.bed, 3);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.bed, side, 0, [1], [waste2_foe(dice, self.danger, True)]);
        build.foe(float(self.long) - 3.0, 2.5, self.bed, waste2_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a drain shaft's rim, the way out on a ledge in it."""
node Waste2Exit(Prefab) {
    has key: str = "",
        deep: int = 4,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drain exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(3, 5);
        self.tall = dice.between(11, 13);
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
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, waste2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, low, waste2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste2's stretches: [name, role]."""
glob WASTE2_STRETCHES: list[list[str]] = [
         ["bay", "start"],
         ["sluice", "flow"],
         ["pumps", "hub"],
         ["pumps", "flow"],
         ["filter", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of waste2's stretches by its name."""
def make_waste2(name: str, key: str) -> Prefab {
    if name == "bay" {
        return ChannelBay();
    }
    if name == "sluice" {
        return Sluice();
    }
    if name == "pumps" {
        return PumpHall();
    }
    if name == "filter" {
        return FilterRoom(key=key if key else "key_silver");
    }
    return Waste2Exit(key=key);
}
