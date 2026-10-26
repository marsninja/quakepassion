"""Prefabs drawn from Quake III's q3dm7, Temple of Retribution: a temple of pools and ledges, jump pads up out of the water. Quake III's
arenas hold no foes of their own; q3dm7's are knight, wizard, hell_knight.
Raised in q3dm7's own palette.

- `RetributionPool`: a temple, a pool in its floor, a jump pad by it up to a ledge and the way on.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm7."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM7: str = "q3:q3dm7",
     Q3DM7_LIGHT: list[str] = ["monster_knight", "monster_wizard"],
     Q3DM7_HEAVY: list[str] = ["monster_hell_knight"];

"""A temple, a pool in its floor stepped round, a jump pad by the pool's
far edge throwing a body up to a ledge and the way on there (and one at
the floor)."""
node RetributionPool(Prefab) {
    has ledge: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution pool";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.ledge = dice.between(6, 8);
        self.tall = self.ledge + 10;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        temple = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(temple, self.ledge);
        build.pool(6, 4, -4, self.long - 10, self.wide - 4, 0, 2, False, True, True);
        stair(build, self.long - 14, 4, -4, 0, 4, 2);
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, self.wide - 1, self.ledge);
        build.jump_pad(float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 1.0, float(middle) + 0.5, self.ledge);
        for y in range(2, self.wide - 2) {
            build.keep(temple, lx, y, self.ledge);
        }
        build.doorway(temple, self.enter);
        for port in self.taken {
            build.doorway(temple, port);
        }
        build.foe(float(self.long // 2) + 0.5, 2.5, 0, arena_foe(dice, self.danger, Q3DM7_LIGHT, Q3DM7_HEAVY), 90.0);
        build.foe(float(self.long) - 3.0, 3.0, self.ledge, arena_foe(dice, self.danger, Q3DM7_LIGHT, Q3DM7_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.ledge, Q3_HEALTH, "q3");
    }
}

"""q3dm7's stretches: [name, role]."""
glob Q3DM7_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["pool", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm7's stretches by its name."""
def make_q3dm7(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM7, label="Retribution hall", light=Q3DM7_LIGHT, heavy=Q3DM7_HEAVY, sky=False);
    }
    if name == "pool" {
        return RetributionPool();
    }
    if name == "tower" {
        return PadTower(source=Q3DM7, label="Retribution tower", light=Q3DM7_LIGHT, heavy=Q3DM7_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM7, label="Retribution atrium", light=Q3DM7_LIGHT, heavy=Q3DM7_HEAVY, sky=False, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM7, label="Retribution vault", key=key if key else "key_silver", light=Q3DM7_LIGHT, heavy=Q3DM7_HEAVY);
    }
    return ArenaPortal(source=Q3DM7, label="Retribution portal", key=key, light=Q3DM7_LIGHT, heavy=Q3DM7_HEAVY, sky=False);
}
