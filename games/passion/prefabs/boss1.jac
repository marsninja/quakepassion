"""Prefabs drawn from Quake II's boss1, the Inner Chamber: the way into the
Makron's lair, a hall over lava crossed on stepping plinths, a chamber of
two tiers round a lava pit, the key in a reliquary; the Makron's altar
at the end. Raised in boss1's own palette.

- `ChamberApproach`: the start. A hall of tall columns, a stair up to a
  gallery across its far end; ways on from the gallery and the floor.
- `LavaPlinths`: a hall over lava crossed on plinths a jump apart, a
  walk round the wall for the long way.
- `InnerChamber`: a chamber round a pit of lava, a tier up stairs on two
  sides; ways on from the floor and the tier (a hub).
- `Reliquary`: the key in a reliquary up steps behind a door its button
  opens; taking it opens the closets.
- `MakronAltar`: the end. A door (a key's, as a gate), the altar chamber,
  the way out behind the altar; the Makron's guard late in a run."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, gate_into }

glob BOSS1: str = "q2:boss1";

"""boss1's foes: iron maidens and flyers, gladiators deeper in."""
def boss1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_chick", "monster_gladiator"] if heavy else ["monster_chick", "monster_flyer", "monster_flyer"], ["monster_gladiator"], danger * 0.5));
}

"""The start: a hall of tall columns, a stair up to a gallery across its
far end."""
node ChamberApproach(Prefab) {
    has gallery: int = 6,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chamber approach";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gallery = dice.between(5, 7);
        self.tall = self.gallery + 13;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.gallery), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        gx = self.long - 6;
        build.solid(gx, 1, 0, self.long - 1, self.wide - 1, self.gallery);
        stair(build, gx - self.gallery, middle - 2, 0, 0, self.gallery, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, gx, y, self.gallery);
        }
        clear = [[0, middle - 3, 5, middle + 3], [6, 0, 11, 4], [6, self.wide - 4, 11, self.wide], [gx - self.gallery - 1, middle - 3, gx, middle + 3]];
        pillars(build, 4, 4, gx - 1, self.wide - 4, 0, self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(gx) - 3.5, 3.0 + float(index) * 5.0, 6, boss1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, self.gallery, boss1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_HEALTH, "q2");
    }
}

"""A hall over lava crossed on plinths a jump apart, a walk round the wall
for the long way."""
node LavaPlinths(Prefab) {
    has hops: int = 4,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava plinths";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.hops = dice.between(3, 5);
        self.long = 3 * self.hops + 13;
        self.wide = dice.between(16, 18);
        self.tall = dice.between(15, 17);
        self.low = -4;
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        far = 3 * self.hops + 6;
        build.pool(5, 4, -3, far, self.wide - 1, 0, 4, False, False);
        for hop in range(self.hops) {
            x = 6 + hop * 3;
            build.solid(x, middle - 1, -3, x + 2, middle + 2, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 4) + 0.5, float(middle) + 3.5, 5, boss1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(far) + 3.0, float(middle) + 0.5, 0, boss1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(far) + 3.0, 2.5, 0, "ammo_cells", "q2");
    }
}

"""A chamber round a pit of lava, a tier up stairs on two sides."""
node InnerChamber(Prefab) {
    has tier: int = 6,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Inner chamber";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tier = dice.between(6, 7);
        self.tall = self.tier + 13;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tier),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.tier),
            Port(face=0, along=4.0, floor=self.tier)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        chamber = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, self.tier);
        build.pool(cx - 6, cy - 5, -3, cx + 6, cy + 5, 0, 4, False, False);
        build.solid(cx - 2, cy - 2, -3, cx + 2, cy + 2, 10);
        build.solid(1, 1, 0, self.long - 1, 6, self.tier);
        build.solid(1, self.wide - 6, 0, self.long - 1, self.wide - 1, self.tier);
        stair(build, 4, 5 + self.tier, 0, 3, self.tier, 3);
        stair(build, self.long - 7, self.wide - 6 - self.tier, 0, 1, self.tier, 3);
        build.doorway(chamber, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 6) + 0.5, float(cy) + (7.0 if index % 2 == 0 else -7.0), 0, boss1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, 3.0, self.tier, boss1_foe(dice, self.danger, True), 90.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 12, "monster_flyer", 0.0);
        build.supply(float(cx) - 6.0, 3.0, self.tier, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a reliquary up steps behind a door its button opens; taking
it opens the closets."""
node Reliquary(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reliquary (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(12, 14);
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
        build.level(room, 2);
        build.doorway(room, self.enter);
        rx = self.long - 8;
        build.solid(rx - 2, 1, 0, self.long - 1, side, 2);
        stair(build, rx - 4, cy - 2, 0, 0, 2, 4);
        build.solid(rx, 1, 2, rx + 1, side, self.tall);
        door = build.name("relics");
        build.widen(room, rx, cy - 2, 2, rx + 1, cy + 2, 9);
        build.rising_door(float(rx), float(cy - 2), 2.0, float(rx + 1), float(cy + 2), 9.0, {"targetname": door, "wait": "-1"});
        build.button(float(rx), float(cy) + 4.0, 3.3, 2, door);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 2, side, 0, [3, rx - 7], [boss1_foe(dice, self.danger, True), boss1_foe(dice, self.danger)]);
        build.foe(float(rx) - 6.0, 2.5, 0, boss1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the altar chamber, the way out behind the altar."""
node MakronAltar(Prefab) {
    has key: str = "",
        altar: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Makron altar" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.altar = dice.between(3, 4);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        ax = self.long - 9;
        build.solid(ax, middle - 5, 0, self.long - 1, middle + 5, self.altar);
        stair(build, ax - self.altar, middle - 2, 0, 0, self.altar, 4);
        build.solid(ax + 2, middle - 2, self.altar, ax + 4, middle + 2, self.altar + 2);
        build.way_out(float(self.long) - 3.0, float(middle), self.altar);
        guard = "monster_supertank" if self.danger > 0.85 else "monster_gladiator";
        build.foe(float(ax) - 4.5, float(middle) + 4.5, 0, guard, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, boss1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 5.0, 0, "ammo_rockets", "q2");
    }
}

"""boss1's stretches: [name, role]."""
glob BOSS1_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["plinths", "flow"],
         ["chamber", "hub"],
         ["chamber", "flow"],
         ["reliquary", "keyroom"],
         ["altar", "end"],
         ["altar", "gate"]
     ];

"""One of boss1's stretches by its name."""
def make_boss1(name: str, key: str) -> Prefab {
    if name == "approach" {
        return ChamberApproach();
    }
    if name == "plinths" {
        return LavaPlinths();
    }
    if name == "chamber" {
        return InnerChamber();
    }
    if name == "reliquary" {
        return Reliquary(key=key if key else "key_silver");
    }
    return MakronAltar(key=key);
}
