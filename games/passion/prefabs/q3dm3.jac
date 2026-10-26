"""Prefabs drawn from Quake III's q3dm3, Arena of Death: an arena under the sky on three levels, terraces stepping up it. Quake III's
arenas hold no foes of their own; q3dm3's are ogre, knight, demon1.
Raised in q3dm3's own palette.

- `DeathTerraces`: three terraces stepping up an arena under the sky, stairs between; the ways on from the middle and the top.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm3."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM3: str = "q3:q3dm3",
     Q3DM3_LIGHT: list[str] = ["monster_ogre", "monster_knight"],
     Q3DM3_HEAVY: list[str] = ["monster_demon1"];

"""An arena under the sky in three terraces stepping up its length, stairs
between them; the ways on from the middle and the top."""
node DeathTerraces(Prefab) {
    has rise_by: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death terraces";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.rise_by = dice.between(3, 4);
        self.tall = dice.between(18, 22);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=2 * self.rise_by), Port(face=1, along=float(self.long // 2) + 2.0, floor=self.rise_by)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.rise_by;
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        t1 = self.long // 3;
        t2 = 2 * self.long // 3;
        build.level(arena, r);
        build.level(arena, 2 * r);
        build.solid(t1, 1, 0, self.long - 1, self.wide - 1, r);
        build.solid(t2, 1, 0, self.long - 1, self.wide - 1, 2 * r);
        stair(build, t1 - r, 2, 0, 0, r, 3);
        stair(build, t2 - r, self.wide - 5, r, 0, r, 3);
        for y in range(2, 5) {
            build.keep(arena, t1, y, r);
        }
        for y in range(self.wide - 5, self.wide - 2) {
            build.keep(arena, t2, y, 2 * r);
        }
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        build.foe(float(t1) - 3.5, float(middle) + 0.5, 0, arena_foe(dice, self.danger, Q3DM3_LIGHT, Q3DM3_HEAVY), 0.0);
        build.foe(float(t2) - 3.5, float(middle) + 0.5, r, arena_foe(dice, self.danger, Q3DM3_LIGHT, Q3DM3_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, 2 * r, arena_foe(dice, self.danger, Q3DM3_LIGHT, Q3DM3_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 2 * r, Q3_ARMOR, "q3");
    }
}

"""q3dm3's stretches: [name, role]."""
glob Q3DM3_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["terraces", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm3's stretches by its name."""
def make_q3dm3(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM3, label="Death court", light=Q3DM3_LIGHT, heavy=Q3DM3_HEAVY, sky=True);
    }
    if name == "terraces" {
        return DeathTerraces();
    }
    if name == "tower" {
        return PadTower(source=Q3DM3, label="Death tower", light=Q3DM3_LIGHT, heavy=Q3DM3_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM3, label="Death atrium", light=Q3DM3_LIGHT, heavy=Q3DM3_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM3, label="Death vault", key=key if key else "key_silver", light=Q3DM3_LIGHT, heavy=Q3DM3_HEAVY);
    }
    return ArenaPortal(source=Q3DM3, label="Death portal", key=key, light=Q3DM3_LIGHT, heavy=Q3DM3_HEAVY, sky=True);
}
