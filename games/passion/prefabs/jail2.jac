"""Prefabs drawn from Quake II's jail2, the Detention Center: a reception
hall under a guard post, cells in two tiers round an atrium, a drain
hall over deep water, the key in an observation room over an
interrogation cell. Raised in jail2's own palette.

- `Reception`: the start. A hall, a guard post raised in its middle up
  steps, gates out on three sides.
- `CellTiers`: an atrium, cells along both walls on two tiers, the upper
  a walkway up a stair at the far end; ways on from both tiers.
- `DrainHall`: a hall round a deep drain pit of water, walkways across
  it, a lift up to a gallery; ways on from the floor and the gallery (a
  hub).
- `Observation`: the key in an observation room up a lift, looking down on
  an interrogation cell; taking it opens the cells below.
- `DetentionExit`: the end. A door (a key's, as a gate), a processing room,
  the way out through its far gate."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob JAIL2: str = "q2:jail2";

"""jail2's foes: infantry and gunners, medics among them, berserkers,
gladiators and a tank deeper in."""
def jail2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_infantry", "monster_infantry", "monster_medic"], ["monster_tank"] if heavy else ["monster_berserk", "monster_parasite"], danger * 0.5 if heavy else danger));
}

"""The start: a hall, a guard post raised in its middle up steps."""
node Reception(Prefab) {
    has post: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reception";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.post = dice.between(3, 4);
        self.tall = dice.between(13, 15);
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
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.post);
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.post);
        stair(build, cx - 3 - self.post, cy - 1, 0, 0, self.post, 2);
        for corner in [[cx - 3, cy - 3], [cx + 2, cy - 3], [cx - 3, cy + 2], [cx + 2, cy + 2]] {
            build.solid(corner[0], corner[1], self.post, corner[0] + 1, corner[1] + 1, self.post + 6);
        }
        build.keep(hall, cx - 3, cy - 1, self.post);
        build.keep(hall, cx - 3, cy, self.post);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 5) + 0.5, 3.5 + float(index) * 5.0, 0, jail2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.post, jail2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""An atrium, cells along both walls on two tiers, the upper a walkway up
a stair at the far end."""
node CellTiers(Prefab) {
    has tier: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell tiers";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.tier = dice.between(6, 7);
        self.tall = self.tier + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=self.tier), Port(face=3, along=float(self.long // 2), floor=self.tier)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        atrium = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(atrium, self.tier);
        under = self.tier - 1;
        # Cell walls down both sides on the floor, the walkway over them.
        for x in range(4, self.long - 6, 4) {
            build.solid(x, 1, 0, x + 1, 5, under);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 1, under);
            build.solid(x, 1, self.tier, x + 1, 2, self.tier + 5);
            build.solid(x, self.wide - 2, self.tier, x + 1, self.wide - 1, self.tier + 5);
        }
        build.solid(1, 1, under, self.long - 1, 5, self.tier);
        build.solid(1, self.wide - 5, under, self.long - 1, self.wide - 1, self.tier);
        build.solid(self.long - 4, 5, under, self.long - 1, self.wide - 5, self.tier);
        stair(build, self.long - 4 - self.tier, 5, 0, 0, self.tier, 3);
        for x in range(self.long - 7, self.long - 4) {
            build.keep(atrium, x, 4, self.tier);
        }
        build.doorway(atrium, self.enter);
        for port in self.taken {
            build.doorway(atrium, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 4) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, jail2_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, 4.0, self.tier, jail2_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.tier, Q2_HEALTH, "q2");
        build.supply(2.5, float(middle) + 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall round a deep drain pit of water, walkways across it, a lift up
to a gallery."""
node DrainHall(Prefab) {
    has deep: int = 6,
        gallery: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drain hall";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(26, 28);
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
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        build.pool(6, 6, -self.deep, self.long - 6, self.wide - 6, 0, 2, False, True, True);
        stair(build, self.long - 6 - self.deep, 6, -self.deep, 0, self.deep, 2);
        stair(build, self.long - 6 - self.deep, self.wide - 8, -self.deep, 0, self.deep, 2);
        build.solid(cx - 1, 6, -1, cx + 2, self.wide - 6, 0);
        under = self.gallery - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        lift(build, 2, self.wide - 7, 5, self.wide - 4, 0, self.gallery);
        for x in range(1, 6) {
            build.keep(hall, x, self.wide - 4, self.gallery);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, 7.5 + float(index) * 3.0, 0, jail2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 0, jail2_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 4.5, float(self.wide) - 2.5, self.gallery, jail2_foe(dice, self.danger), 270.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an observation room up a lift, looking down on an
interrogation cell; taking it opens the cells below."""
node Observation(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Observation (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(20, 22);
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
        ox = self.long - 6;
        build.solid(ox, 1, self.upper - 1, self.long - 1, side, self.upper);
        build.solid(ox, 1, self.upper, ox + 1, cy - 2, self.upper + 2);
        build.solid(ox, cy + 3, self.upper, ox + 1, side, self.upper + 2);
        lift(build, ox - 3, cy - 1, ox, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, ox, y, self.upper);
        }
        build.solid(5, 3, 0, 7, 5, 2);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.upper, side, 0, [2, 7, ox - 4], [jail2_foe(dice, self.danger, True), jail2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.upper, jail2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a processing room, the way out through its far gate."""
node DetentionExit(Prefab) {
    has key: str = "",
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Detention exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(12, 14);
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
        gx = self.long - 7;
        build.solid(gx, 1, 0, gx + 1, middle - 2, self.tall);
        build.solid(gx, middle + 2, 0, gx + 1, self.wide - 1, self.tall);
        build.solid(gx, middle - 2, 8, gx + 1, middle + 2, self.tall);
        build.rising_door(float(gx), float(middle - 2), 0.0, float(gx + 1), float(middle + 2), 8.0, {"wait": "-1"});
        for x in [wall + 4, wall + 8] {
            build.solid(x, 3, 0, x + 2, 5, 2);
            build.solid(x, self.wide - 5, 0, x + 2, self.wide - 3, 2);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, jail2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(gx) - 2.5, 2.5, 0, jail2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail2's stretches: [name, role]."""
glob JAIL2_STRETCHES: list[list[str]] = [
         ["reception", "start"],
         ["tiers", "flow"],
         ["drain", "hub"],
         ["drain", "flow"],
         ["observation", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail2's stretches by its name."""
def make_jail2(name: str, key: str) -> Prefab {
    if name == "reception" {
        return Reception();
    }
    if name == "tiers" {
        return CellTiers();
    }
    if name == "drain" {
        return DrainHall();
    }
    if name == "observation" {
        return Observation(key=key if key else "key_silver");
    }
    return DetentionExit(key=key);
}
