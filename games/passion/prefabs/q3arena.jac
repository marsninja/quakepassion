"""Stretches shared by Quake III's arenas, each made for one arena by what
it is given: the arena it is drawn from (its palette), its name, the foes
that hold it (Quake III's arenas have none of their own, so each arena
names Quake's or Quake II's that suit it), and its touches (open to the
sky, liquid in its pits). Each arena's own module adds the stretch that
is its signature and makes these for the rest.

- `ArenaEntry`: a start. A hall of pillars, item plinths along its walls,
  the ways on from its far end and sides.
- `PadTower`: a tall room, a jump pad throwing a body up to a ledge across
  its far end and the way on there (and one at its foot).
- `ArenaAtrium`: a hub. A tall hall, balconies on two walls each thrown up
  to by a jump pad, a teleporter from one back down, a pit in its floor;
  ways on from the floor and both balconies.
- `ArenaVault`: a key room. The key on a ledge a jump pad throws a body up
  to; taking it opens the closets.
- `ArenaPortal`: an end (or a gate). A door (a key's, as a gate), the way
  out on a dais between pillars."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, gate_into }

glob Q3_HEALTH: str = "item_health_large",
     Q3_ARMOR: str = "item_armor_combat";

"""A foe for an arena: of its `light` kinds, the `heavy` ones growing with
the danger (and more of them where `strong`)."""
def arena_foe(dice: Stream, danger: float, light: list[str], heavy: list[str], strong: bool = False) -> str {
    return q1_foe(dice, q1_palette(heavy if strong else light, heavy, danger * 0.5));
}

"""A start: a hall of pillars, item plinths along its walls."""
node ArenaEntry(Prefab) {
    has label: str = "Arena entry",
        light: list[str] = ["monster_knight"],
        heavy: list[str] = ["monster_ogre"],
        sky: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = self.label;
        self.district = level_district(self.source);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(15, 18);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=self.sky);
        clear = [[0, middle - 3, 5, middle + 3], [self.long - 8, 0, self.long - 2, 4], [self.long - 8, self.wide - 4, self.long - 2, self.wide], [self.long - 5, middle - 3, self.long, middle + 3]];
        pillars(build, 5, 4, self.long - 4, 5, 0, self.tall, 4, clear);
        pillars(build, 5, self.wide - 5, self.long - 4, self.wide - 4, 0, self.tall, 4, clear);
        for x in range(7, self.long - 8, 6) {
            build.solid(x, 1, 0, x + 2, 2, 1);
            build.solid(x, self.wide - 2, 0, x + 2, self.wide - 1, 1);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, arena_foe(dice, self.danger, self.light, self.heavy), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, arena_foe(dice, self.danger, self.light, self.heavy, True), 180.0);
        build.supply(8.0, 1.5, 1, Q3_HEALTH, "q3");
        build.supply(8.0, float(self.wide) - 1.5, 1, Q3_ARMOR, "q3");
    }
}

"""A tall room, a jump pad throwing a body up to a ledge across its far
end and the way on there."""
node PadTower(Prefab) {
    has label: str = "Pad tower",
        light: list[str] = ["monster_knight"],
        heavy: list[str] = ["monster_ogre"],
        sky: bool = False,
        ledge: int = 10,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = self.label;
        self.district = level_district(self.source);
        self.long = dice.between(18, 20);
        self.wide = dice.between(14, 16);
        self.ledge = dice.between(8, 12);
        self.tall = self.ledge + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=1, along=float(self.long - 3), floor=self.ledge), Port(face=3, along=5.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=self.sky);
        build.level(tower, self.ledge);
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, self.wide - 1, self.ledge);
        build.jump_pad(float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 1.0, float(middle) + 0.5, self.ledge);
        for y in range(2, self.wide - 2) {
            build.keep(tower, lx, y, self.ledge);
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        build.foe(float(self.long // 2) - 2.5, float(middle) + 3.5, 0, arena_foe(dice, self.danger, self.light, self.heavy), 180.0);
        build.foe(float(self.long) - 3.0, 3.5, self.ledge, arena_foe(dice, self.danger, self.light, self.heavy, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.ledge, Q3_HEALTH, "q3");
        build.supply(2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A tall hall, balconies on two walls each thrown up to by a jump pad, a
teleporter from one back down, a pit in its floor."""
node ArenaAtrium(Prefab) {
    has label: str = "Arena atrium",
        light: list[str] = ["monster_knight"],
        heavy: list[str] = ["monster_ogre"],
        sky: bool = False,
        liquid: int = 0,
        balcony: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = self.label;
        self.district = level_district(self.source);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.balcony = dice.between(7, 9);
        self.tall = self.balcony + 13;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=self.sky);
        build.level(hall, self.balcony);
        # The pit in the floor's middle: liquid when the arena has it, else a
        # sunken floor with steps.
        if self.liquid > 0 {
            build.pool(cx - 4, cy - 3, -4, cx + 4, cy + 3, 0, self.liquid, False, self.liquid == 2, self.liquid == 2);
        } else {
            build.widen(hall, cx - 4, cy - 3, -3, cx + 4, cy + 3, 0);
            stair(build, cx - 4 + 2, cy - 1, -3, 2, 3, 2);
            stair(build, cx + 4 - 3, cy - 1, -3, 0, 3, 2);
        }
        under = self.balcony - 1;
        build.solid(5, self.wide - 5, under, self.long - 1, self.wide - 1, self.balcony);
        build.solid(5, 1, under, self.long - 1, 5, self.balcony);
        build.jump_pad(8.0, float(self.wide) - 8.0, 0, 8.0, float(self.wide) - 4.0, self.balcony);
        build.jump_pad(float(self.long) - 8.0, 8.0, 0, float(self.long) - 8.0, 4.0, self.balcony);
        build.teleporter(float(self.long) - 3.5, float(self.wide) - 3.0, self.balcony, 3.0, float(cy) + 0.5, 0, 0.0);
        for x in range(6, self.long - 1) {
            build.keep(hall, x, self.wide - 5, self.balcony);
            build.keep(hall, x, 4, self.balcony);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 8 + index * 5) + 0.5, float(cy) + (5.0 if index % 2 == 0 else -5.0), 0, arena_foe(dice, self.danger, self.light, self.heavy), 0.0);
        }
        build.foe(float(cx) + 0.5, 3.0, self.balcony, arena_foe(dice, self.danger, self.light, self.heavy, True), 90.0);
        build.supply(float(cx) - 4.0, float(self.wide) - 3.0, self.balcony, Q3_ARMOR, "q3");
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A key room: the key on a ledge a jump pad throws a body up to."""
node ArenaVault(Prefab) {
    has label: str = "Arena vault",
        key: str = "key_silver",
        light: list[str] = ["monster_knight"],
        heavy: list[str] = ["monster_ogre"],
        hall_wide: int = 16,
        ledge: int = 8,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = self.label + " (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.district = level_district(self.source);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(7, 9);
        self.tall = self.ledge + 9;
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        build.doorway(hall, self.enter);
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, side, self.ledge);
        for y in range(2, side - 1) {
            build.keep(hall, lx, y, self.ledge);
        }
        build.jump_pad(float(lx) - 3.0, float(cy) + 0.5, 0, float(lx) + 1.0, float(cy) + 0.5, self.ledge);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, side, 0, [2, lx - 5], [arena_foe(dice, self.danger, self.light, self.heavy, True), arena_foe(dice, self.danger, self.light, self.heavy)]);
        build.foe(float(self.long) - 3.0, 3.0, self.ledge, arena_foe(dice, self.danger, self.light, self.heavy), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): a door, the way out on a dais between pillars."""
node ArenaPortal(Prefab) {
    has label: str = "Arena portal",
        key: str = "",
        light: list[str] = ["monster_knight"],
        heavy: list[str] = ["monster_ogre"],
        sky: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = self.label + (" (" + self.key[4:] + " door)" if self.key else "");
        self.district = level_district(self.source);
        self.long = dice.between(22, 24);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, self.sky);
        dx = self.long - 6;
        build.solid(dx, middle - 4, 0, self.long - 1, middle + 4, 2);
        stair(build, dx - 2, middle - 2, 0, 0, 2, 4);
        for y in [middle - 5, middle + 4] {
            build.solid(dx - 3, y, 0, dx - 2, y + 1, 10);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, arena_foe(dice, self.danger, self.light, self.heavy, index == 0), 180.0);
        }
        build.foe(float(dx) - 4.5, 2.5, 0, arena_foe(dice, self.danger, self.light, self.heavy, True), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}
