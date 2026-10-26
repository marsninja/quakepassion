"""Prefabs drawn from Quake II's mine4, the Lower Mines: the deepest
workings, a landing over flooded galleries, a gallery half under water
crossed on a walk of planks, a cavern of lava with an ore conveyor over
it, the key in an ore vault behind a button's door. Raised in mine4's
own palette.

- `LowerLanding`: the start. A landing over a cavern's flooded floor, a
  stair down to the water's edge and a walk round it; ways on.
- `FloodedGallery`: a gallery flooded along its length, a walk of planks
  over the water on piers, broken in two places swum across.
- `LavaCavern`: a cavern over lava, a conveyor's walk raised across it, a
  ledge round its walls; ways on from the ledge and the conveyor (a hub).
- `OreVault`: the key in an ore vault behind a door a button opens up a
  stair; taking it opens the closets.
- `Mine4Exit`: the end. A door (a key's, as a gate), a lift cage up to the
  way out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, stalactites, key_ambush, gate_into, lift }

glob MINE4: str = "q2:mine4";

"""mine4's foes: gunners and floaters, a tank deeper in."""
def mine4_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_floater"] if heavy else ["monster_gunner", "monster_floater", "monster_soldier"], ["monster_tank"] if heavy else ["monster_floater"], danger * 0.3 if heavy else danger * 0.7));
}

"""The start: a landing over a cavern's flooded floor, a stair down to the
water's edge and a walk round it."""
node LowerLanding(Prefab) {
    has drop: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lower landing";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.drop = dice.between(4, 5);
        self.tall = dice.between(13, 15);
        self.low = -self.drop - 4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.drop), Port(face=1, along=float(self.long - 4), floor=-self.drop), Port(face=3, along=float(self.long - 4), floor=-self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.drop;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 0);
        lx = 8;
        build.solid(1, 1, low, lx, self.wide - 1, 0);
        stair(build, lx + self.drop - 1, middle - 2, low, 2, self.drop, 4);
        build.pool(lx + self.drop + 2, 5, low - 3, self.long - 5, self.wide - 5, low, 2, False, True, True);
        stair(build, self.long - 5 - 3, middle - 1, low - 3, 0, 3, 2);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(5, 8));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * 6.0, low, mine4_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 3, mine4_foe(dice, self.danger), 180.0);
        build.supply(float(lx + self.drop) + 1.5, 2.5, low, Q2_HEALTH, "q2");
    }
}

"""A gallery flooded along its length, a walk of planks over the water on
piers, broken in two places swum across."""
node FloodedGallery(Prefab) {
    has deep: int = 5,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded gallery";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(12, 14);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gallery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 4;
        x1 = self.long - 4;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2);
        # The walk: planks a lift thick on piers down the middle, gaps of
        # water across it twice, a stair up out of the water at each gap.
        gaps = [x0 + (x1 - x0) // 3, x0 + 2 * (x1 - x0) // 3];
        x = x0;
        for gap in gaps + [x1] {
            build.solid(x, middle - 1, -1, gap, middle + 2, 0);
            x = gap + 3;
        }
        for gap in gaps {
            stair(build, gap + 3 - self.deep, middle + 2, -self.deep, 0, self.deep, 2);
        }
        for px in range(x0 + 2, x1 - 1, 4) {
            build.solid(px, middle - 1, -self.deep, px + 1, middle, -1);
        }
        stair(build, x1 - self.deep, 1, -self.deep, 0, self.deep, 2);
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(gaps[index]) + 1.5, float(middle) - 2.5, -self.deep + 1, "monster_flipper", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1 - 4 - index * 6) + 0.5, float(middle) + 0.5, 0, mine4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A cavern over lava, a conveyor's walk raised across it, a ledge round
its walls."""
node LavaCavern(Prefab) {
    has walk: int = 3,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava cavern";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(3, 4);
        self.tall = dice.between(17, 19);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.walk),
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
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.walk);
        build.pool(6, 6, -4, self.long - 6, self.wide - 6, 0, 4, False, False);
        # The conveyor's walk: raised across the lava from a stair at the
        # near ledge to the far wall.
        build.solid(6, middle - 1, -4, self.long - 1, middle + 2, self.walk);
        stair(build, 6 - self.walk, middle - 1, 0, 0, self.walk, 3);
        for x in range(9, self.long - 6, 5) {
            build.solid(x, middle - 2, -4, x + 1, middle - 1, self.walk + 5);
            build.solid(x, middle + 2, -4, x + 1, middle + 3, self.walk + 5);
            build.solid(x, middle - 1, self.walk + 4, x + 1, middle + 2, self.walk + 5);
        }
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, 3.5 + float(index) * 5.0, 0, mine4_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long // 2) + 2.5, float(middle) + 0.5, self.walk, mine4_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an ore vault behind a door a button opens up a stair; taking
it opens the closets."""
node OreVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        vault: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ore vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.vault = dice.between(3, 4);
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
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(cave, self.vault);
        build.doorway(cave, self.enter);
        vx = self.long - 7;
        build.solid(vx, 1, 0, self.long - 1, side, self.vault);
        stair(build, vx - self.vault, cy - 2, 0, 0, self.vault, 4);
        build.solid(vx + 1, 1, self.vault, vx + 2, cy - 2, self.tall);
        build.solid(vx + 1, cy + 2, self.vault, vx + 2, side, self.tall);
        build.solid(vx + 1, cy - 2, self.vault + 7, vx + 2, cy + 2, self.tall);
        door = build.name("vault");
        build.rising_door(float(vx + 1), float(cy - 2), float(self.vault), float(vx + 2), float(cy + 2), float(self.vault + 7), {"targetname": door, "wait": "-1"});
        build.button(float(vx + 1), float(cy) - 4.0, float(self.vault) + 1.3, 2, door);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.vault, side, 0, [2, vx - 5], [mine4_foe(dice, self.danger, True), mine4_foe(dice, self.danger)]);
        build.foe(float(vx) - 4.5, 2.5, 0, mine4_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a lift cage up to the way out."""
node Mine4Exit(Prefab) {
    has key: str = "",
        upper: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lower cage" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.upper = dice.between(5, 7);
        self.tall = self.upper + 9;
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
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, self.upper);
        ux = self.long - 6;
        build.solid(ux, 1, self.upper - 1, self.long - 1, self.wide - 1, self.upper);
        lift(build, ux - 3, middle - 1, ux, middle + 2, 0, self.upper);
        for y in range(middle - 2, middle + 3) {
            build.keep(room, ux, y, self.upper);
        }
        build.way_out(float(self.long) - 3.0, float(middle), self.upper);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mine4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(ux) - 4.5, 2.5, 0, mine4_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine4's stretches: [name, role]."""
glob MINE4_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["gallery", "flow"],
         ["lava", "hub"],
         ["lava", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine4's stretches by its name."""
def make_mine4(name: str, key: str) -> Prefab {
    if name == "landing" {
        return LowerLanding();
    }
    if name == "gallery" {
        return FloodedGallery();
    }
    if name == "lava" {
        return LavaCavern();
    }
    if name == "vault" {
        return OreVault(key=key if key else "key_silver");
    }
    return Mine4Exit(key=key);
}
