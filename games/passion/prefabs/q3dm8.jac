"""Prefabs drawn from Quake III's q3dm8, Brimstone Abbey: an abbey of naves and aisles flooded with water. Quake III's
arenas hold no foes of their own; q3dm8's are zombie, wizard, ogre.
Raised in q3dm8's own palette.

- `AbbeyNave`: a raised nave between aisles of water, stairs down to the aisles' ends.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm8."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM8: str = "q3:q3dm8",
     Q3DM8_LIGHT: list[str] = ["monster_zombie", "monster_wizard"],
     Q3DM8_HEAVY: list[str] = ["monster_ogre"];

"""An abbey's nave raised between aisles flooded with fog-dark water, stairs
down into the aisles and up out of them."""
node AbbeyNave(Prefab) {
    has nave: int = 2,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey nave";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.nave = dice.between(2, 3);
        self.tall = dice.between(15, 17);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.nave);
        self.leaves = [Port(face=0, along=middle, floor=self.nave), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        abbey = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(abbey, self.nave);
        build.solid(1, middle - 3, 0, self.long - 1, middle + 3, self.nave);
        build.pool(4, 1, -4, self.long - 4, middle - 3, 0, 2);
        build.pool(4, middle + 3, -4, self.long - 4, self.wide - 1, 0, 2, False, False);
        stair(build, self.long - 8, self.wide - 3, -4, 0, 4, 2);
        for x in range(5, self.long - 5, 4) {
            build.solid(x, middle - 3, self.nave, x + 1, middle - 2, self.tall);
            build.solid(x, middle + 2, self.nave, x + 1, middle + 3, self.tall);
        }
        stair(build, self.long - 3, middle - 3 - self.nave, 0, 1, self.nave, 2);
        stair(build, self.long - 3, middle + 2 + self.nave, 0, 3, self.nave, 2);
        build.doorway(abbey, self.enter);
        for port in self.taken {
            build.doorway(abbey, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + 0.5, self.nave, arena_foe(dice, self.danger, Q3DM8_LIGHT, Q3DM8_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm8's stretches: [name, role]."""
glob Q3DM8_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["nave", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm8's stretches by its name."""
def make_q3dm8(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM8, label="Abbey hall", light=Q3DM8_LIGHT, heavy=Q3DM8_HEAVY, sky=False);
    }
    if name == "nave" {
        return AbbeyNave();
    }
    if name == "tower" {
        return PadTower(source=Q3DM8, label="Abbey tower", light=Q3DM8_LIGHT, heavy=Q3DM8_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM8, label="Abbey atrium", light=Q3DM8_LIGHT, heavy=Q3DM8_HEAVY, sky=False, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM8, label="Abbey vault", key=key if key else "key_silver", light=Q3DM8_LIGHT, heavy=Q3DM8_HEAVY);
    }
    return ArenaPortal(source=Q3DM8, label="Abbey portal", key=key, light=Q3DM8_LIGHT, heavy=Q3DM8_HEAVY, sky=False);
}
