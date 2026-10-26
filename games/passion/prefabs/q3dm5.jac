"""Prefabs drawn from Quake III's q3dm5, The Forgotten Place: a gothic place of bridges over a chasm. Quake III's
arenas hold no foes of their own; q3dm5's are zombie, knight, shambler.
Raised in q3dm5's own palette.

- `ForgottenBridges`: a chasm, lava at its bottom, crossed by a low bridge and a high one reached by a stair.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm5."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM5: str = "q3:q3dm5",
     Q3DM5_LIGHT: list[str] = ["monster_zombie", "monster_knight"],
     Q3DM5_HEAVY: list[str] = ["monster_shambler"];

"""A chasm, lava at its bottom, crossed by a low bridge and a high one: the
high one from a stair on the near ledge to a ledge high on the far side."""
node ForgottenBridges(Prefab) {
    has upper: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten bridges";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.upper = dice.between(5, 6);
        self.tall = dice.between(17, 19);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=1, along=float(self.long - 3), floor=self.upper)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        chasm = build.room(1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(chasm, 0);
        build.level(chasm, self.upper);
        build.solid(1, 1, -6, 7, self.wide - 1, 0);
        build.solid(self.long - 7, 1, -6, self.long - 1, self.wide - 1, 0);
        build.pool(7, 1, -6, self.long - 7, self.wide - 1, -3, 4, True, False);
        build.solid(7, middle - 3, -1, self.long - 7, middle, 0);
        uy = self.wide - 4;
        stair(build, 6 - self.upper + 1, uy, 0, 0, self.upper, 3);
        build.solid(7, uy, self.upper - 1, self.long - 7, uy + 3, self.upper);
        build.solid(self.long - 7, uy, 0, self.long - 1, self.wide - 1, self.upper);
        for y in [middle - 3, middle - 2, middle - 1] {
            build.keep(chasm, 6, y, 0);
            build.keep(chasm, self.long - 7, y, 0);
        }
        build.doorway(chasm, self.enter);
        for port in self.taken {
            build.doorway(chasm, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) - 2.0, 0, arena_foe(dice, self.danger, Q3DM5_LIGHT, Q3DM5_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, self.upper, arena_foe(dice, self.danger, Q3DM5_LIGHT, Q3DM5_HEAVY, True), 180.0);
        build.supply(float(self.long) - 3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm5's stretches: [name, role]."""
glob Q3DM5_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["bridges", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm5's stretches by its name."""
def make_q3dm5(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM5, label="Forgotten hall", light=Q3DM5_LIGHT, heavy=Q3DM5_HEAVY, sky=True);
    }
    if name == "bridges" {
        return ForgottenBridges();
    }
    if name == "tower" {
        return PadTower(source=Q3DM5, label="Forgotten tower", light=Q3DM5_LIGHT, heavy=Q3DM5_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM5, label="Forgotten atrium", light=Q3DM5_LIGHT, heavy=Q3DM5_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM5, label="Forgotten vault", key=key if key else "key_silver", light=Q3DM5_LIGHT, heavy=Q3DM5_HEAVY);
    }
    return ArenaPortal(source=Q3DM5, label="Forgotten portal", key=key, light=Q3DM5_LIGHT, heavy=Q3DM5_HEAVY, sky=True);
}
