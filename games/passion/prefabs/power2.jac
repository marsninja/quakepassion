"""Prefabs drawn from Quake II's power2, the Big Gun's power works: a works
over pools of slime and coolant, a canyon walk with a lava bed below, a
hall of capacitor banks with a lift up to its gantry, the key on a
bridge a button lowers. Raised in power2's own palette.

- `CoolantYard`: the start. A yard, coolant pools sunk in its floor, a
  bridge over the larger; ways on from three sides.
- `LavaCanyon`: a canyon, a ledge walk along one wall high over a bed of
  lava, a stair down to a lower walk at its far end; ways on from both.
- `CapacitorHall`: a hall of capacitor banks in rows, a gantry over them
  ridden up to by a lift; ways on from the floor and the gantry (a hub).
- `SwitchBridge`: the key on a ledge across a pit, a bridge to it drawn
  out by a button; taking it opens the closets.
- `Power2Exit`: the end. A door (a key's, as a gate), a pumping room, the
  way out on a platform up steps."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob POWER2: str = "q2:power2";

"""power2's foes: gunners and berserkers, iron maidens and flyers,
gladiators deeper in."""
def power2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gladiator", "monster_berserk"] if heavy else ["monster_gunner", "monster_berserk", "monster_chick"], ["monster_gladiator"] if heavy else ["monster_flyer"], danger * 0.4 if heavy else danger * 0.6));
}

"""The start: a yard, coolant pools sunk in its floor, a bridge over the
larger."""
node CoolantYard(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Coolant yard";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(15, 17);
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
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        px = 8;
        build.pool(px, 3, -4, px + 10, self.wide - 3, 0, 2, False, True, True);
        stair(build, px + 6, 3, -4, 0, 4, 2);
        build.solid(px, middle - 1, -1, px + 10, middle + 1, 0);
        build.pool(px + 13, 3, -2, px + 17, 8, 0, 3);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(px + 12 + index % 2 * 3) + 0.5, float(middle) + 2.5 + float(index), 0, power2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(px) + 4.5, 4.5, -3, "monster_flipper", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A canyon, a ledge walk along one wall high over a bed of lava, a stair
down to a lower walk at its far end."""
node LavaCanyon(Prefab) {
    has ledge: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava canyon";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.ledge = dice.between(5, 7);
        self.tall = self.ledge + 12;
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 3), floor=self.ledge);
        self.leaves = [Port(face=0, along=3.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        canyon = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(canyon, self.ledge);
        wy = self.wide - 5;
        build.pool(1, 5, -3, self.long - 1, wy, 0, 4, False, False);
        build.solid(1, wy, 0, self.long - 1, self.wide - 1, self.ledge);
        # The lower walk along the south wall, a stair down to it from the
        # ledge's far end along the east wall.
        sx = self.long - 4;
        for step in range(self.ledge) {
            y = wy - 1 - step;
            build.solid(sx, y, 0, self.long - 1, y + 1, self.ledge - step - 1);
        }
        build.solid(sx, 5, -3, self.long - 1, wy, 0);
        build.doorway(canyon, self.enter);
        for port in self.taken {
            build.doorway(canyon, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(self.wide) - 2.5, self.ledge, power2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 7.0, 6, "monster_flyer", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(4.0, float(self.wide) - 2.5, self.ledge, "ammo_bullets", "q2");
    }
}

"""A hall of capacitor banks in rows, a gantry over them ridden up to by a
lift."""
node CapacitorHall(Prefab) {
    has gantry: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Capacitor hall";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.gantry = dice.between(7, 8);
        self.tall = self.gantry + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.gantry),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gantry);
        for x in range(6, self.long - 6, 4) {
            for y0 in [3, middle + 3] {
                build.solid(x, y0, 0, x + 2, y0 + 4, 5);
            }
        }
        build.solid(8, middle - 1, self.gantry - 1, self.long - 1, middle + 2, self.gantry);
        lift(build, 4, middle - 1, 7, middle + 2, 0, self.gantry);
        build.keep(hall, 8, middle - 1, self.gantry);
        build.keep(hall, 8, middle, self.gantry);
        build.keep(hall, 8, middle + 1, self.gantry);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + (0.5 if index % 2 == 0 else -2.0), 0, power2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 0.5, self.gantry, power2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.gantry, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on a ledge across a pit, a bridge to it drawn out by a button;
taking it opens the closets."""
node SwitchBridge(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Switch bridge (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(12, 14);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, low);
        build.doorway(room, self.enter);
        x0 = 6;
        x1 = self.long - 5;
        build.widen(room, x0, 1, low, x1, side, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        stair(build, x1 - self.deep, side - 2, low, 0, self.deep, 2);
        span = build.name("span");
        build.bridge(float(x0), float(cy - 1), float(x1), float(cy + 2), 0, self.deep + 1, span);
        build.button(1.0, float(cy) - 3.5, 1.3, 0, span);
        for y in range(cy - 1, cy + 2) {
            build.keep(room, x0 - 1, y, 0);
            build.keep(room, x1, y, 0);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [1], [power2_foe(dice, self.danger, True)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, power2_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a pumping room, the way out on a platform up steps."""
node Power2Exit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pumping room" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
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
        for y in [2, self.wide - 5] {
            build.solid(wall + 3, y, 0, wall + 6, y + 3, 6);
        }
        px = self.long - 6;
        build.solid(px, middle - 4, 0, self.long - 1, middle + 4, 3);
        stair(build, px - 3, middle - 2, 0, 0, 3, 4);
        build.way_out(float(self.long) - 3.0, float(middle), 3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, power2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px) - 4.5, 2.5, 0, power2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""power2's stretches: [name, role]."""
glob POWER2_STRETCHES: list[list[str]] = [
         ["coolant", "start"],
         ["canyon", "flow"],
         ["capacitors", "hub"],
         ["capacitors", "flow"],
         ["bridge", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of power2's stretches by its name."""
def make_power2(name: str, key: str) -> Prefab {
    if name == "coolant" {
        return CoolantYard();
    }
    if name == "canyon" {
        return LavaCanyon();
    }
    if name == "capacitors" {
        return CapacitorHall();
    }
    if name == "bridge" {
        return SwitchBridge(key=key if key else "key_silver");
    }
    return Power2Exit(key=key);
}
