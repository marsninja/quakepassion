"""Prefabs drawn from Quake III's q3dm4, The Place of Many Deaths: halls round deep pits, teleporters up out of them. Quake III's
arenas hold no foes of their own; q3dm4's are zombie, ogre, hell_knight.
Raised in q3dm4's own palette.

- `ManyDeathsPit`: a ledge over a deep pit, a stair down to its floor, a teleporter back up.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm4."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM4: str = "q3:q3dm4",
     Q3DM4_LIGHT: list[str] = ["monster_zombie", "monster_ogre"],
     Q3DM4_HEAVY: list[str] = ["monster_hell_knight"];

"""A ledge in over a deep pit, a stair down the pit's wall to its floor, a
teleporter on the floor back up to the ledge; the ways on from the floor."""
node ManyDeathsPit(Prefab) {
    has deep: int = 8,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many deaths pit";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(7, 9);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=3, along=float(self.long - 5), floor=-self.deep), Port(face=1, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        pit = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        stair(build, 5 + self.deep, 1, low, 2, self.deep, 3);
        build.teleporter(float(self.long // 2) + 2.0, float(middle) + 0.5, low, 3.0, float(middle) + 0.5, 0, 0.0);
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(10 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), low, arena_foe(dice, self.danger, Q3DM4_LIGHT, Q3DM4_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, low, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, "ammo_rockets", "q2");
    }
}

"""q3dm4's stretches: [name, role]."""
glob Q3DM4_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["pit", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm4's stretches by its name."""
def make_q3dm4(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM4, label="Deaths hall", light=Q3DM4_LIGHT, heavy=Q3DM4_HEAVY, sky=False);
    }
    if name == "pit" {
        return ManyDeathsPit();
    }
    if name == "tower" {
        return PadTower(source=Q3DM4, label="Deaths tower", light=Q3DM4_LIGHT, heavy=Q3DM4_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM4, label="Deaths atrium", light=Q3DM4_LIGHT, heavy=Q3DM4_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM4, label="Deaths vault", key=key if key else "key_silver", light=Q3DM4_LIGHT, heavy=Q3DM4_HEAVY);
    }
    return ArenaPortal(source=Q3DM4, label="Deaths portal", key=key, light=Q3DM4_LIGHT, heavy=Q3DM4_HEAVY, sky=False);
}
