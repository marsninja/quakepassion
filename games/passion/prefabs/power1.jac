"""Prefabs drawn from Quake II's power1, the Power Plant: a plant under the
sky round its cooling towers, a turbine hall with a crane walk over it, a
reactor pit with lifts down and up, the key in a control booth over the
turbines. Raised in power1's own palette.

- `PlantYard`: the start. A yard under the sky, two cooling towers standing
  in it, the plant's door up steps; ways on from the door and the yard.
- `TurbineHall`: a hall of turbines in a row, a crane's walk along its
  wall over them up a stair; ways on from the floor and the walk.
- `ReactorPit`: a hall round a reactor's pit, a lift down into it and one
  back up the far side, a gallery over all; ways on from the floor, the
  pit and the gallery (a hub).
- `ControlBooth`: the key in a booth up a stair over a turbine; taking it
  opens the closets.
- `Power1Exit`: the end. A door (a key's, as a gate), a switchyard under
  the sky, the way out between its transformers."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob POWER1: str = "q2:power1";

"""power1's foes: berserkers and iron maidens, flyers and hovers, gladiators
deeper in."""
def power1_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover" if dice.chance(0.4) else "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_chick"] if heavy else ["monster_berserk", "monster_chick", "monster_soldier"], ["monster_gladiator"] if heavy else ["monster_chick"], danger * 0.5 if heavy else danger * 0.7));
}

"""The start: a yard, two cooling towers in it, the plant's door up steps."""
node PlantYard(Prefab) {
    has porch: int = 3,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant yard";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.porch = dice.between(3, 4);
        self.tall = dice.between(22, 26);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.porch), Port(face=1, along=7.0, floor=0), Port(face=3, along=7.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.porch);
        px = self.long - 6;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.porch);
        stair(build, px - self.porch, middle - 3, 0, 0, self.porch, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(yard, px, y, self.porch);
        }
        # Cooling towers: hollow drums of rock standing in the yard.
        for ty in [3, self.wide - 9] {
            tx = self.long // 2 - 3;
            build.solid(tx, ty, 0, tx + 6, ty + 6, 16);
            build.widen(yard, tx + 1, ty + 1, 1, tx + 5, ty + 5, 16);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(px) - 4.5, 3.5 + float(index) * 4.5, 0, power1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 10, power1_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.porch, Q2_HEALTH, "q2");
    }
}

"""A hall of turbines in a row, a crane's walk along its wall over them up
a stair."""
node TurbineHall(Prefab) {
    has walk: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Turbine hall";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.walk = dice.between(7, 8);
        self.tall = self.walk + 8;
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
        wy = self.wide - 4;
        build.solid(4 + self.walk, wy, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        stair(build, 4, wy, 0, 0, self.walk, 3);
        for x in range(6, self.long - 5, 6) {
            build.solid(x, middle - 2, 0, x + 4, middle + 2, 4);
            build.solid(x + 1, middle - 1, 4, x + 3, middle + 1, 6);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 5) + 0.5, 3.0 if index % 2 == 0 else float(middle) + 4.0, 0, power1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, self.walk, power1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.walk, "ammo_bullets", "q2");
    }
}

"""A hall round a reactor's pit, a lift down into it and one back up the
far side, a gallery over all."""
node ReactorPit(Prefab) {
    has deep: int = 6,
        gallery: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor pit";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(5, 7);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + 10;
        self.low = -self.deep - 1;
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
        low = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        build.level(hall, self.gallery);
        build.widen(hall, 7, 7, low, self.long - 7, self.wide - 7, 0);
        build.solid(cx - 2, cy - 2, low, cx + 2, cy + 2, self.tall);
        lift(build, 7, 7, 10, 10, low, 0);
        lift(build, self.long - 10, self.wide - 10, self.long - 7, self.wide - 7, low, 0);
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.gallery);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        stair(build, 5, 4, 0, 0, self.gallery, 2);
        stair(build, self.long - 5 - self.gallery, self.wide - 6, 0, 0, self.gallery, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(cy) + 4.5, low, power1_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, float(cy) + 0.5 + float(index), 0, power1_foe(dice, self.danger, index == 0), 0.0);
        }
        build.supply(float(cx) + 3.0, float(cy) + 0.5, low, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.0, 2.5, self.gallery, Q2_HEALTH, "q2");
    }
}

"""The key in a booth up a stair over a turbine; taking it opens the
closets."""
node ControlBooth(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        booth: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control booth (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.booth = dice.between(6, 7);
        self.tall = self.booth + 8;
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
        build.level(room, self.booth);
        build.doorway(room, self.enter);
        bx = self.long - 6;
        build.solid(bx, 1, self.booth - 1, self.long - 1, side, self.booth);
        stair(build, bx - self.booth, 1, 0, 0, self.booth, 3);
        build.solid(5, cy - 2, 0, 10, cy + 3, 4);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.booth, side, 0, [2, bx - 4], [power1_foe(dice, self.danger, True), power1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, float(side) - 2.5, self.booth, power1_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a switchyard under the sky, the way out between its
transformers."""
node Power1Exit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Switchyard" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(16, 20);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        for x in range(wall + 4, self.long - 4, 5) {
            build.solid(x, 2, 0, x + 2, middle - 3, 5);
            build.solid(x, middle + 3, 0, x + 2, self.wide - 2, 5);
        }
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, power1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 5.5, float(middle) + 4.5, 7, power1_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""power1's stretches: [name, role]."""
glob POWER1_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["turbines", "flow"],
         ["reactor", "hub"],
         ["reactor", "flow"],
         ["booth", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of power1's stretches by its name."""
def make_power1(name: str, key: str) -> Prefab {
    if name == "yard" {
        return PlantYard();
    }
    if name == "turbines" {
        return TurbineHall();
    }
    if name == "reactor" {
        return ReactorPit();
    }
    if name == "booth" {
        return ControlBooth(key=key if key else "key_silver");
    }
    return Power1Exit(key=key);
}
