"""Prefabs drawn from Quake III's q3tourney2, The Proving Grounds: a sunken ring of stone to fight in. Quake III's
arenas hold no foes of their own; q3tourney2's are knight, ogre, hell_knight.
Raised in q3tourney2's own palette.

- `ProvingRing`: a sunken ring, a walk round it, stairs down at opposite corners.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney2."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY2: str = "q3:q3tourney2",
     Q3TOURNEY2_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3TOURNEY2_HEAVY: list[str] = ["monster_hell_knight"];

"""A sunken ring to fight in, a walk round it at the floor, stairs down
into it at opposite corners; the ways on from the walk."""
node ProvingRing(Prefab) {
    has deep: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Proving ring";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(3, 4);
        self.tall = dice.between(13, 15);
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
        d = self.deep;
        low = -d;
        ring = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(ring, 0);
        build.solid(1, 1, low, self.long - 1, 5, 0);
        build.solid(1, self.wide - 5, low, self.long - 1, self.wide - 1, 0);
        build.solid(1, 5, low, 5, self.wide - 5, 0);
        build.solid(self.long - 5, 5, low, self.long - 1, self.wide - 5, 0);
        stair(build, 4 + d, 5, low, 2, d, 3);
        stair(build, self.long - 5 - d, self.wide - 8, low, 0, d, 3);
        build.doorway(ring, self.enter);
        for port in self.taken {
            build.doorway(ring, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 3) + 0.5, float(self.wide // 2) + (2.5 if index % 2 == 0 else -2.5), low, arena_foe(dice, self.danger, Q3TOURNEY2_LIGHT, Q3TOURNEY2_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, low, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3tourney2's stretches: [name, role]."""
glob Q3TOURNEY2_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["ring", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney2's stretches by its name."""
def make_q3tourney2(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY2, label="Proving hall", light=Q3TOURNEY2_LIGHT, heavy=Q3TOURNEY2_HEAVY, sky=False);
    }
    if name == "ring" {
        return ProvingRing();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY2, label="Proving tower", light=Q3TOURNEY2_LIGHT, heavy=Q3TOURNEY2_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY2, label="Proving atrium", light=Q3TOURNEY2_LIGHT, heavy=Q3TOURNEY2_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY2, label="Proving vault", key=key if key else "key_silver", light=Q3TOURNEY2_LIGHT, heavy=Q3TOURNEY2_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY2, label="Proving portal", key=key, light=Q3TOURNEY2_LIGHT, heavy=Q3TOURNEY2_HEAVY, sky=False);
}
