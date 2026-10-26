"""Prefabs drawn from Quake III's q3dm15, Demon Keep: a keep across a moat of water, gothic halls. Quake III's
arenas hold no foes of their own; q3dm15's are knight, hell_knight, demon1.
Raised in q3dm15's own palette.

- `DemonMoat`: a hall across a moat, a drawbridge to a forecourt and a stair up into a raised keep.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm15."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM15: str = "q3:q3dm15",
     Q3DM15_LIGHT: list[str] = ["monster_knight", "monster_hell_knight"],
     Q3DM15_HEAVY: list[str] = ["monster_demon1"];

"""A hall across a moat, a drawbridge over the water to a forecourt, a
stair up from it into a raised keep and the ways on there (and one back on
the near side)."""
node DemonMoat(Prefab) {
    has keep_at: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon moat";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.keep_at = dice.between(3, 4);
        self.tall = dice.between(15, 17);
        self.low = -6;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.keep_at), Port(face=1, along=float(self.long - 4), floor=self.keep_at), Port(face=3, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.keep_at);
        build.pool(9, 1, -5, 14, self.wide - 1, 0, 2, False, True, True);
        build.solid(9, middle - 1, -1, 14, middle + 2, 0);
        keep = 15 + self.keep_at;
        build.solid(keep, 1, 0, self.long - 1, self.wide - 1, self.keep_at);
        stair(build, 15, middle - 1, 0, 0, self.keep_at, 3);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, 8, y, 0);
            build.keep(hall, 14, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(keep) + 3.5, float(middle) + 2.5, self.keep_at, arena_foe(dice, self.danger, Q3DM15_LIGHT, Q3DM15_HEAVY, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(keep) + 6.5, 3.5 + float(index) * float(self.wide - 7), self.keep_at, arena_foe(dice, self.danger, Q3DM15_LIGHT, Q3DM15_HEAVY), 180.0);
        }
        build.foe(5.5, float(self.wide) - 3.5, 0, arena_foe(dice, self.danger, Q3DM15_LIGHT, Q3DM15_HEAVY), 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.keep_at, Q3_HEALTH, "q3");
    }
}

"""q3dm15's stretches: [name, role]."""
glob Q3DM15_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["moat", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm15's stretches by its name."""
def make_q3dm15(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM15, label="Demon hall", light=Q3DM15_LIGHT, heavy=Q3DM15_HEAVY, sky=False);
    }
    if name == "moat" {
        return DemonMoat();
    }
    if name == "tower" {
        return PadTower(source=Q3DM15, label="Demon tower", light=Q3DM15_LIGHT, heavy=Q3DM15_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM15, label="Demon atrium", light=Q3DM15_LIGHT, heavy=Q3DM15_HEAVY, sky=False, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM15, label="Demon vault", key=key if key else "key_silver", light=Q3DM15_LIGHT, heavy=Q3DM15_HEAVY);
    }
    return ArenaPortal(source=Q3DM15, label="Demon portal", key=key, light=Q3DM15_LIGHT, heavy=Q3DM15_HEAVY, sky=False);
}
