"""Prefabs drawn from Quake III's q3dm1, Arena Gate: a gothic arena round a pit bridged, jump pads up out of it. Quake III's
arenas hold no foes of their own; q3dm1's are knight, hell_knight, ogre.
Raised in q3dm1's own palette.

- `GatePit`: a hall, a pit across its middle bridged narrowly, jump pads in the pit throwing a body up either side.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm1."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM1: str = "q3:q3dm1",
     Q3DM1_LIGHT: list[str] = ["monster_knight", "monster_hell_knight"],
     Q3DM1_HEAVY: list[str] = ["monster_ogre"];

"""A hall, a pit across its middle, a narrow bridge over it, a jump pad in
the pit's floor throwing a body back up to the far side."""
node GatePit(Prefab) {
    has deep: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate pit";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(5, 7);
        self.tall = dice.between(14, 16);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        x0 = 8;
        x1 = self.long - 8;
        build.widen(hall, x0, 1, low, x1, self.wide - 1, 0);
        build.solid(x0, middle - 1, -1, x1, middle + 1, 0);
        build.jump_pad(float(x1) - 3.0, 3.0, low, float(x1) + 1.0, 3.0, 0);
        build.jump_pad(float(x0) + 3.0, float(self.wide) - 3.0, low, float(x0) - 1.0, float(self.wide) - 3.0, 0);
        for y in [middle - 1, middle] {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 3 + index * 4) + 0.5, float(middle) + 3.5, low, arena_foe(dice, self.danger, Q3DM1_LIGHT, Q3DM1_HEAVY), 0.0);
        }
        build.foe(float(x1) + 3.0, float(middle) + 0.5, 0, arena_foe(dice, self.danger, Q3DM1_LIGHT, Q3DM1_HEAVY, True), 180.0);
        build.supply(float(x0) + 4.0, float(middle) + 4.0, low, Q3_ARMOR, "q3");
    }
}

"""q3dm1's stretches: [name, role]."""
glob Q3DM1_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["pit", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm1's stretches by its name."""
def make_q3dm1(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM1, label="Gate hall", light=Q3DM1_LIGHT, heavy=Q3DM1_HEAVY, sky=False);
    }
    if name == "pit" {
        return GatePit();
    }
    if name == "tower" {
        return PadTower(source=Q3DM1, label="Gate tower", light=Q3DM1_LIGHT, heavy=Q3DM1_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM1, label="Gate atrium", light=Q3DM1_LIGHT, heavy=Q3DM1_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM1, label="Gate vault", key=key if key else "key_silver", light=Q3DM1_LIGHT, heavy=Q3DM1_HEAVY);
    }
    return ArenaPortal(source=Q3DM1, label="Gate portal", key=key, light=Q3DM1_LIGHT, heavy=Q3DM1_HEAVY, sky=False);
}
