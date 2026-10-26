"""Prefabs drawn from Quake III's q3dm10, The Nameless Place: halls round a well of deep water. Quake III's
arenas hold no foes of their own; q3dm10's are wizard, zombie, shambler.
Raised in q3dm10's own palette.

- `NamelessWell`: a hall round a deep well of water, steps up out of it at both ends.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm10."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM10: str = "q3:q3dm10",
     Q3DM10_LIGHT: list[str] = ["monster_wizard", "monster_zombie"],
     Q3DM10_HEAVY: list[str] = ["monster_shambler"];

"""A hall round a deep well of water, a walk round it, steps up out of the
water at both ends."""
node NamelessWell(Prefab) {
    has deep: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless well";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(5, 7);
        self.tall = dice.between(15, 17);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(6, 5, -self.deep, self.long - 6, self.wide - 5, 0, 2, False, True, True);
        stair(build, self.long - 6 - self.deep, 5, -self.deep, 0, self.deep, 2);
        stair(build, self.long - 6 - self.deep, self.wide - 7, -self.deep, 0, self.deep, 2);
        for corner in [[3, 2], [3, self.wide - 3], [self.long - 4, 2], [self.long - 4, self.wide - 3]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 1, corner[1] + 1, self.tall);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, 3.0 if index % 2 == 0 else float(self.wide) - 3.0, 0, arena_foe(dice, self.danger, Q3DM10_LIGHT, Q3DM10_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, float(middle) + 0.5, -self.deep, Q3_ARMOR, "q3");
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm10's stretches: [name, role]."""
glob Q3DM10_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["well", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm10's stretches by its name."""
def make_q3dm10(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM10, label="Nameless hall", light=Q3DM10_LIGHT, heavy=Q3DM10_HEAVY, sky=False);
    }
    if name == "well" {
        return NamelessWell();
    }
    if name == "tower" {
        return PadTower(source=Q3DM10, label="Nameless tower", light=Q3DM10_LIGHT, heavy=Q3DM10_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM10, label="Nameless atrium", light=Q3DM10_LIGHT, heavy=Q3DM10_HEAVY, sky=False, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM10, label="Nameless vault", key=key if key else "key_silver", light=Q3DM10_LIGHT, heavy=Q3DM10_HEAVY);
    }
    return ArenaPortal(source=Q3DM10, label="Nameless portal", key=key, light=Q3DM10_LIGHT, heavy=Q3DM10_HEAVY, sky=False);
}
