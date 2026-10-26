"""Prefabs drawn from Quake III's q3dm2, House of Pain: halls of stone and lifts, balconies over the floors. Quake III's
arenas hold no foes of their own; q3dm2's are knight, zombie, hell_knight.
Raised in q3dm2's own palette.

- `PainLifts`: a hall, a balcony across its far end ridden up to by lifts at its corners.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm2."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM2: str = "q3:q3dm2",
     Q3DM2_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3DM2_HEAVY: list[str] = ["monster_hell_knight"];

"""A hall, a balcony across its far end ridden up to by lifts at its two
corners."""
node PainLifts(Prefab) {
    has balcony: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain lifts";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.balcony = dice.between(6, 7);
        self.tall = self.balcony + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=1, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        bx = self.long - 6;
        build.solid(bx, 1, self.balcony - 1, self.long - 1, self.wide - 1, self.balcony);
        lift(build, bx - 3, 2, bx, 5, 0, self.balcony);
        lift(build, bx - 3, self.wide - 5, bx, self.wide - 2, 0, self.balcony);
        for y in [2, 3, 4, self.wide - 5, self.wide - 4, self.wide - 3] {
            build.keep(hall, bx, y, self.balcony);
        }
        pillars(build, 5, middle - 2, bx - 4, middle + 3, 0, self.tall, 5, [[0, middle - 3, 4, middle + 3]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 4) + 0.5, 3.0 if index % 2 == 0 else float(self.wide) - 3.0, 0, arena_foe(dice, self.danger, Q3DM2_LIGHT, Q3DM2_HEAVY), 0.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, self.balcony, arena_foe(dice, self.danger, Q3DM2_LIGHT, Q3DM2_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.balcony, Q3_HEALTH, "q3");
    }
}

"""q3dm2's stretches: [name, role]."""
glob Q3DM2_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["lifts", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm2's stretches by its name."""
def make_q3dm2(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM2, label="Pain hall", light=Q3DM2_LIGHT, heavy=Q3DM2_HEAVY, sky=False);
    }
    if name == "lifts" {
        return PainLifts();
    }
    if name == "tower" {
        return PadTower(source=Q3DM2, label="Pain tower", light=Q3DM2_LIGHT, heavy=Q3DM2_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM2, label="Pain atrium", light=Q3DM2_LIGHT, heavy=Q3DM2_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM2, label="Pain vault", key=key if key else "key_silver", light=Q3DM2_LIGHT, heavy=Q3DM2_HEAVY);
    }
    return ArenaPortal(source=Q3DM2, label="Pain portal", key=key, light=Q3DM2_LIGHT, heavy=Q3DM2_HEAVY, sky=False);
}
