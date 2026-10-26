"""Prefabs drawn from Quake III's q3dm18, Space Chamber: chambers in space, a dais and a high balcony. Quake III's
arenas hold no foes of their own; q3dm18's are enforcer, army, shambler.
Raised in q3dm18's own palette.

- `SpaceChamber`: a chamber, a dais with a teleporter up to a high balcony, a lift up too.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm18."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM18: str = "q3:q3dm18",
     Q3DM18_LIGHT: list[str] = ["monster_enforcer", "monster_army"],
     Q3DM18_HEAVY: list[str] = ["monster_shambler"];

"""A chamber, a dais in its middle stepped up to at both ends with a
teleporter on it to a high balcony across the far end, a lift up beside
the balcony too; the ways on from the balcony and the floor."""
node SpaceChamber(Prefab) {
    has balcony: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Space chamber";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.balcony = dice.between(5, 7);
        self.tall = self.balcony + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        b = self.balcony;
        cx = (self.long - 6) // 2;
        chamber = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(chamber, 2);
        build.level(chamber, b);
        build.solid(self.long - 6, 1, 0, self.long - 1, self.wide - 1, b);
        build.solid(cx - 3, middle - 3, 0, cx + 3, middle + 3, 2);
        stair(build, cx - 5, middle - 1, 0, 0, 2, 3);
        stair(build, cx + 4, middle - 1, 0, 2, 2, 3);
        lift(build, self.long - 9, 2, self.long - 6, 5, 0, b);
        build.teleporter(float(cx) + 0.5, float(middle) + 0.5, 2, float(self.long) - 3.0, float(middle) + 0.5, b, 0.0);
        build.doorway(chamber, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + (-1.5 if index % 2 == 0 else 2.5), float(middle) + (2.0 if index < 2 else -2.0), 2, arena_foe(dice, self.danger, Q3DM18_LIGHT, Q3DM18_HEAVY), 180.0);
        }
        build.foe(float(self.long) - 2.5, 3.0, b, arena_foe(dice, self.danger, Q3DM18_LIGHT, Q3DM18_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.0, b, Q3_HEALTH, "q3");
    }
}

"""q3dm18's stretches: [name, role]."""
glob Q3DM18_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["chamber", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm18's stretches by its name."""
def make_q3dm18(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM18, label="Chamber hall", light=Q3DM18_LIGHT, heavy=Q3DM18_HEAVY, sky=True);
    }
    if name == "chamber" {
        return SpaceChamber();
    }
    if name == "tower" {
        return PadTower(source=Q3DM18, label="Chamber tower", light=Q3DM18_LIGHT, heavy=Q3DM18_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM18, label="Chamber atrium", light=Q3DM18_LIGHT, heavy=Q3DM18_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM18, label="Chamber vault", key=key if key else "key_silver", light=Q3DM18_LIGHT, heavy=Q3DM18_HEAVY);
    }
    return ArenaPortal(source=Q3DM18, label="Chamber portal", key=key, light=Q3DM18_LIGHT, heavy=Q3DM18_HEAVY, sky=True);
}
