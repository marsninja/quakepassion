"""Prefabs drawn from Quake III's q3dm14, Grim Dungeons: dungeon halls of cells along trenches of lava. Quake III's
arenas hold no foes of their own; q3dm14's are knight, zombie, hell_knight.
Raised in q3dm14's own palette.

- `GrimCells`: a dungeon corridor, cells along one side, a trench of lava along the other.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm14."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM14: str = "q3:q3dm14",
     Q3DM14_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3DM14_HEAVY: list[str] = ["monster_hell_knight"];

"""A dungeon corridor, cells opening off one side, a trench of lava along
the other walked past on a ledge."""
node GrimCells(Prefab) {
    has tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim cells";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(11, 13);
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
        corridor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(4, 1, -3, self.long - 4, 4, 0, 4, False, False);
        for x in range(4, self.long - 4, 5) {
            build.solid(x, self.wide - 6, 0, x + 1, self.wide - 1, self.tall);
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(6 + index * 5) + 0.5, float(self.wide) - 3.0, 0, arena_foe(dice, self.danger, Q3DM14_LIGHT, Q3DM14_HEAVY, index == 0), 270.0);
        }
        build.supply(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_rockets", "q2");
    }
}

"""q3dm14's stretches: [name, role]."""
glob Q3DM14_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["cells", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm14's stretches by its name."""
def make_q3dm14(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM14, label="Grim hall", light=Q3DM14_LIGHT, heavy=Q3DM14_HEAVY, sky=False);
    }
    if name == "cells" {
        return GrimCells();
    }
    if name == "tower" {
        return PadTower(source=Q3DM14, label="Grim tower", light=Q3DM14_LIGHT, heavy=Q3DM14_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM14, label="Grim atrium", light=Q3DM14_LIGHT, heavy=Q3DM14_HEAVY, sky=False, liquid=4);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM14, label="Grim vault", key=key if key else "key_silver", light=Q3DM14_LIGHT, heavy=Q3DM14_HEAVY);
    }
    return ArenaPortal(source=Q3DM14, label="Grim portal", key=key, light=Q3DM14_LIGHT, heavy=Q3DM14_HEAVY, sky=False);
}
