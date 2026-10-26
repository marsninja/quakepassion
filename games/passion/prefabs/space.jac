"""Prefabs drawn from Quake II's space, the Comm Satellite: a station out
in the dark, an airlock in, catwalks across a void between solar
arrays, a control ring round the station's core with lifts up it, the
key at the docking port; the Hornet waits at the dish late in a run.
Raised in space's own palette.

- `AirlockEntry`: the start. A docking hall, an airlock across its far end
  of two doors; ways on beyond.
- `SolarWalk`: a void under the stars, catwalks across it between arrays,
  a lower walk below for whoever falls, stairs back up.
- `ControlRing`: a ring of rooms round the station's core, a gallery over
  the ring up lifts; ways on from the ring and the gallery (a hub).
- `DockingPort`: the key at a docking port up a lift; taking it opens the
  closets.
- `DishExit`: the end. A door (a key's, as a gate), the dish's platform
  under the stars, the way out on it; the Hornet there late in a run."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob SPACE: str = "q2:space";

"""space's foes: flyers above all, hovers and floaters."""
def space_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hover", "monster_floater"] if heavy else ["monster_flyer", "monster_flyer", "monster_hover"], ["monster_floater"], danger * 0.5));
}

"""The start: a docking hall, an airlock across its far end."""
node AirlockEntry(Prefab) {
    has tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Airlock entry";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(12, 14);
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
        a = self.long - 12;
        b = self.long - 6;
        hall = build.room(1, 1, 0, a, self.wide - 1, self.tall, variant=dice.below(3));
        lock = build.room(a + 1, middle - 3, 0, b, middle + 3, 8, variant=dice.below(3));
        beyond = build.room(b + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for x in [a, b] {
            build.widen(lock, x, middle - 2, 0, x + 1, middle + 2, 7);
            build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 7.0, {"wait": "-1"});
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(a) - 4.5, 3.5 + float(index) * 4.0, 4, space_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 3, space_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A void under the stars, catwalks across it between arrays, a lower walk
below for whoever falls, stairs back up."""
node SolarWalk(Prefab) {
    has drop: int = 8,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Solar walk";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.drop = dice.between(7, 9);
        self.tall = dice.between(13, 15);
        self.low = -self.drop - 1;
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
        low = -self.drop;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        x0 = 6;
        x1 = self.long - 6;
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        # The catwalk zigzags across, the arrays standing either side.
        build.solid(x0, middle - 1, -1, x0 + 9, middle + 2, 0);
        build.solid(x0 + 6, middle + 2, -1, x0 + 9, middle + 6, 0);
        build.solid(x0 + 6, middle + 3, -1, x1, middle + 6, 0);
        # The arrays stand clear of the stair up out of the void.
        for x in range(x0 + self.drop + 1, x1 - 2, 6) {
            build.solid(x, 2, low, x + 3, 3, 4);
            build.solid(x, self.wide - 3, low, x + 3, self.wide - 2, 4);
        }
        stair(build, x0 + self.drop - 1, 2, low, 2, self.drop, 2);
        for y in [middle - 1, middle, middle + 1] {
            build.keep(void, x0 - 1, y, 0);
        }
        for y in [middle + 3, middle + 4, middle + 5] {
            build.keep(void, x1, y, 0);
        }
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(x0 + 4 + index * 4) + 0.5, float(middle) + 2.0, 4, space_foe(dice, self.danger), 180.0);
        }
        build.supply(float(x1) + 2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x0) + 2.5, 3.0, low, "ammo_cells", "q2");
    }
}

"""A ring of rooms round the station's core, a gallery over the ring up
lifts."""
node ControlRing(Prefab) {
    has gallery: int = 7,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control ring";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        ring = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(ring, self.gallery);
        build.solid(cx - 5, cy - 5, 0, cx + 5, cy + 5, self.tall);
        # Partitions out from the walls to near the core, cutting the ring
        # into rooms: north and south at the middle, west and east off it.
        build.solid(cx - 1, 1, 0, cx + 1, 6, 5);
        build.solid(cx - 1, self.wide - 6, 0, cx + 1, self.wide - 1, 5);
        build.solid(1, cy + 3, 0, 6, cy + 5, 5);
        build.solid(self.long - 6, cy + 3, 0, self.long - 1, cy + 5, 5);
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.gallery);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        lift(build, 4, 4, 7, 7, 0, self.gallery);
        lift(build, self.long - 7, self.wide - 7, self.long - 4, self.wide - 4, 0, self.gallery);
        for x in range(4, 7) {
            build.keep(ring, x, 3, self.gallery);
        }
        for x in range(self.long - 7, self.long - 4) {
            build.keep(ring, x, self.wide - 4, self.gallery);
        }
        build.doorway(ring, self.enter);
        for port in self.taken {
            build.doorway(ring, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 + float(index % 2) * (float(self.long) - 7.0), 7.5 + float(index) * 3.0, 3, space_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 3.0, 2.5, self.gallery + 3, space_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, float(self.wide) - 6.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key at a docking port up a lift; taking it opens the closets."""
node DockingPort(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Docking port (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = SPACE;
        self.district = level_district(SPACE);
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
        ux = self.long - 6;
        build.solid(ux, 1, self.upper - 1, self.long - 1, side, self.upper);
        build.solid(self.long - 2, cy - 2, self.upper, self.long - 1, cy + 3, self.upper + 5);
        lift(build, ux - 3, cy - 1, ux, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, ux, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.upper, side, 0, [2, ux - 5], [space_foe(dice, self.danger, True), space_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper + 2, space_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the dish's platform under the stars, the way out on
it."""
node DishExit(Prefab) {
    has key: str = "",
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish platform" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(18, 22);
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
        dx = self.long - 8;
        build.solid(dx, middle - 1, 0, dx + 1, middle + 1, 10);
        build.solid(dx - 3, middle - 5, 10, dx + 4, middle + 5, 11);
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        boss = "monster_boss2" if self.danger > 0.85 else "monster_hover";
        build.foe(float(dx) - 2.5, float(middle) + 5.5, 6, boss, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 3, space_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""space's stretches: [name, role]."""
glob SPACE_STRETCHES: list[list[str]] = [
         ["airlock", "start"],
         ["solar", "flow"],
         ["ring", "hub"],
         ["ring", "flow"],
         ["docking", "keyroom"],
         ["dish", "end"],
         ["dish", "gate"]
     ];

"""One of space's stretches by its name."""
def make_space(name: str, key: str) -> Prefab {
    if name == "airlock" {
        return AirlockEntry();
    }
    if name == "solar" {
        return SolarWalk();
    }
    if name == "ring" {
        return ControlRing();
    }
    if name == "docking" {
        return DockingPort(key=key if key else "key_silver");
    }
    return DishExit(key=key);
}
