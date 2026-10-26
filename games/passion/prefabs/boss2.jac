"""Prefabs drawn from Quake II's boss2, the Final Showdown: the way up to
the Makron's last stand, a gate over a lava moat, a ramp winding up a
shaft, an arena of tiers round a pit, the key in a sanctum; Jorg waits
in the arena at the end late in a run. Raised in boss2's own palette.

- `ShowdownGate`: the start. A hall, a moat of lava across it bridged,
  the gate beyond; ways on.
- `ShowdownRamp`: a shaft, a ramp winding up its walls to the way on high
  up.
- `ShowdownTiers`: an arena of tiers stepping down to a pit, stairs
  between; ways on from the top tier and the pit (a hub).
- `ShowdownSanctum`: the key in a sanctum up a lift; taking it opens the
  closets.
- `JorgArena`: the end. A door (a key's, as a gate), the arena, the way
  out across it; Jorg there late in a run."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift, spiral, ring_landing }

glob BOSS2: str = "q2:boss2";

"""boss2's foes: the Makron's last guard: gladiators and tanks, iron
maidens."""
def boss2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gladiator", "monster_chick"] if heavy else ["monster_chick", "monster_gunner", "monster_gladiator"], ["monster_tank"] if heavy else ["monster_gladiator"], danger * 0.3 if heavy else danger * 0.4));
}

"""The start: a hall, a moat of lava across it bridged, the gate beyond."""
node ShowdownGate(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown gate";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(15, 17);
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
        mx = 10;
        build.pool(mx, 1, -3, mx + 5, self.wide - 1, 0, 4, False, False);
        build.solid(mx, middle - 2, -3, mx + 5, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, mx - 1, y, 0);
            build.keep(hall, mx + 5, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(mx + 8 + index % 2 * 4) + 0.5, 3.5 + float(index) * 5.0, 0, boss2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_ARMOR, "q2");
    }
}

"""A shaft, a ramp winding up its walls to the way on high up."""
node ShowdownRamp(Prefab) {
    has steps: int = 20,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown ramp";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        fits: list[int] = [];
        for steps in range(12, 30) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, boss2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 12, boss2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""An arena of tiers stepping down to a pit, stairs between."""
node ShowdownTiers(Prefab) {
    has drop: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown tiers";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.drop = dice.between(3, 4);
        self.tall = dice.between(18, 22);
        self.low = -2 * self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        d = self.drop;
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(arena, -d);
        build.level(arena, -2 * d);
        build.widen(arena, 5, 5, -d, self.long - 5, self.wide - 5, 0);
        build.widen(arena, 9, 9, -2 * d, self.long - 9, self.wide - 9, -d);
        stair(build, 5 + d - 1, cy - 2, -d, 2, d, 4);
        stair(build, self.long - 5 - d, cy - 2, -d, 0, d, 4);
        stair(build, cx - 2, 9 + d - 1, -2 * d, 3, d, 4);
        stair(build, cx - 2, self.wide - 9 - d, -2 * d, 1, d, 4);
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 4 + index * 3) + 0.5, float(cy) + 0.5, -2 * d, boss2_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(3.0 if index % 2 == 0 else float(self.long) - 3.0, 4.0 + float(index) * 5.0, 0, boss2_foe(dice, self.danger, index == 0), 0.0);
        }
        build.supply(float(cx) + 0.5, float(cy) - 3.0, -2 * d, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a sanctum up a lift; taking it opens the closets."""
node ShowdownSanctum(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown sanctum (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
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
        lift(build, ux - 3, cy - 1, ux, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, ux, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.upper, side, 0, [2, ux - 5], [boss2_foe(dice, self.danger, True), boss2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper, boss2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the arena, the way out across it; Jorg there late in a
run."""
node JorgArena(Prefab) {
    has key: str = "",
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Jorg arena" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(20, 24);
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
        for corner in [[wall + 6, 4], [wall + 6, self.wide - 7], [self.long - 8, 4], [self.long - 8, self.wide - 7]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 3, corner[1] + 3, 6);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        boss = "monster_jorg" if self.danger > 0.9 else "monster_tank_commander";
        build.foe(float(self.long // 2) + 3.5, float(middle) + 0.5, 0, boss, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, boss2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 6.0, 0, "ammo_rockets", "q2");
        build.supply(float(wall) + 3.0, float(middle) - 6.0, 0, "ammo_cells", "q2");
    }
}

"""boss2's stretches: [name, role]."""
glob BOSS2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["ramp", "flow"],
         ["tiers", "hub"],
         ["tiers", "flow"],
         ["sanctum", "keyroom"],
         ["arena", "end"],
         ["arena", "gate"]
     ];

"""One of boss2's stretches by its name."""
def make_boss2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return ShowdownGate();
    }
    if name == "ramp" {
        return ShowdownRamp();
    }
    if name == "tiers" {
        return ShowdownTiers();
    }
    if name == "sanctum" {
        return ShowdownSanctum(key=key if key else "key_silver");
    }
    return JorgArena(key=key);
}
