"""Prefabs drawn from Quake II's biggun, the Big Gun: an approach under the
sky up a ramp to the gun's works, a battery of emplacements along a
parapet, the chamber of the great gun itself on its platform under
galleries, the key in the firing control room; the Hornet waits at the
breech late in a run. Raised in biggun's own palette.

- `GunApproach`: the start. Ground under the sky, a ramp up to a terrace
  before the works; ways on from the terrace and the ground.
- `GunBattery`: a parapet under the sky, emplacements along it, a walk
  behind them; the way on at its end.
- `GunChamber`: the great gun's chamber, the gun on a platform up a
  stair, galleries along both walls over it; ways on from the floor, the
  platform and the galleries (a hub).
- `FiringControl`: the key in the control room up a lift; taking it opens
  the closets.
- `BreechExit`: the end. A door (a key's, as a gate), the gun's breech, the
  way out beyond it; the Hornet there late in a run."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob BIGGUN: str = "q2:biggun";

"""biggun's foes: elite soldiers and flyers, gunners and gladiators deeper
in."""
def biggun_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_soldier_ss"] if heavy else ["monster_soldier_ss", "monster_soldier_ss", "monster_flyer"], ["monster_gladiator"] if heavy else ["monster_gunner"], danger * 0.4 if heavy else danger * 0.6));
}

"""The start: ground under the sky, a ramp up to a terrace before the
works."""
node GunApproach(Prefab) {
    has terrace: int = 5,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun approach";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.terrace = dice.between(4, 6);
        self.tall = dice.between(20, 24);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.terrace), Port(face=1, along=7.0, floor=0), Port(face=3, along=7.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, self.terrace);
        tx = self.long - 9;
        build.solid(tx, 1, 0, self.long - 1, self.wide - 1, self.terrace);
        stair(build, tx - self.terrace, middle - 3, 0, 0, self.terrace, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(ground, tx, y, self.terrace);
        }
        for y in [3, self.wide - 5] {
            build.solid(tx + 2, y, self.terrace, tx + 4, y + 2, self.terrace + 3);
        }
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(tx) - 6.5, 4.5 + float(index) * 5.0, 0, biggun_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.terrace, biggun_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 9, "monster_flyer", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.terrace, Q2_HEALTH, "q2");
    }
}

"""A parapet under the sky, emplacements along it, a walk behind them."""
node GunBattery(Prefab) {
    has parapet: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun battery";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.parapet = dice.between(2, 3);
        self.tall = dice.between(14, 18);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        battery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        py = self.wide - 4;
        build.solid(1, py, 0, self.long - 1, self.wide - 1, self.parapet + 1);
        for x in range(5, self.long - 5, 6) {
            build.solid(x, py - 3, 0, x + 3, py, self.parapet);
            build.solid(x + 1, py - 2, self.parapet, x + 2, py + 2, self.parapet + 1);
        }
        build.doorway(battery, self.enter);
        for port in self.taken {
            build.doorway(battery, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 6) + 0.5, float(py) - 1.5, self.parapet, biggun_foe(dice, self.danger, index == 0), 270.0);
        }
        build.foe(float(self.long // 2) + 0.5, 3.0, 6, "monster_flyer", 90.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""The great gun's chamber, the gun on a platform up a stair, galleries
along both walls over it."""
node GunChamber(Prefab) {
    has platform: int = 4,
        gallery: int = 9,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun chamber";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.platform = dice.between(3, 5);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=self.platform),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        chamber = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, self.platform);
        build.level(chamber, self.gallery);
        # The platform down the chamber's middle to its far wall, the gun's
        # barrel a long block on it pointing up the far wall.
        build.solid(8, cy - 4, 0, self.long - 1, cy + 4, self.platform);
        stair(build, 8 - self.platform, cy - 2, 0, 0, self.platform, 4);
        build.solid(12, cy - 1, self.platform, self.long - 4, cy + 1, self.platform + 4);
        build.solid(self.long - 6, cy - 2, self.platform, self.long - 4, cy + 2, self.tall - 2);
        under = self.gallery - 1;
        build.solid(4, 1, under, self.long - 1, 4, self.gallery);
        build.solid(4, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        lift(build, 1, 1, 4, 4, 0, self.gallery);
        lift(build, 1, self.wide - 4, 4, self.wide - 1, 0, self.gallery);
        build.doorway(chamber, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(10 + index * 4) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, biggun_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 8.5, float(cy) + 2.5, self.platform, biggun_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, 2.5, self.gallery, biggun_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(10.0, float(cy) + 3.0, self.platform, Q2_HEALTH, "q2");
    }
}

"""The key in the control room up a lift; taking it opens the closets."""
node FiringControl(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Firing control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
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
        build.solid(self.long - 2, 2, self.upper, self.long - 1, side - 1, self.upper + 2);
        lift(build, ux - 3, cy - 1, ux, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, ux, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.upper, side, 0, [2, ux - 5], [biggun_foe(dice, self.danger, True), biggun_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper, biggun_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the gun's breech, the way out beyond it; the Hornet
there late in a run."""
node BreechExit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Breech" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(17, 19);
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
        bx = wall + 6;
        build.solid(bx, middle - 3, 0, bx + 6, middle + 3, 8);
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        boss = "monster_boss2" if self.danger > 0.85 else "monster_gladiator";
        build.foe(float(bx + 8) + 0.5, float(middle) + 5.0, 6 if boss == "monster_boss2" else 0, boss, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, biggun_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(bx) - 2.0, 2.5, 0, "ammo_rockets", "q2");
    }
}

"""biggun's stretches: [name, role]."""
glob BIGGUN_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["battery", "flow"],
         ["chamber", "hub"],
         ["chamber", "flow"],
         ["control", "keyroom"],
         ["breech", "end"],
         ["breech", "gate"]
     ];

"""One of biggun's stretches by its name."""
def make_biggun(name: str, key: str) -> Prefab {
    if name == "approach" {
        return GunApproach();
    }
    if name == "battery" {
        return GunBattery();
    }
    if name == "chamber" {
        return GunChamber();
    }
    if name == "control" {
        return FiringControl(key=key if key else "key_silver");
    }
    return BreechExit(key=key);
}
