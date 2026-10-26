"""Prefabs drawn from Quake III's q3tourney5, Fatal Instinct: halls of pools of water, deeper and deeper. Quake III's
arenas hold no foes of their own; q3tourney5's are knight, zombie, ogre.
Raised in q3tourney5's own palette.

- `FatalPools`: three pools of water each deeper than the last, a dais beyond.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney5."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY5: str = "q3:q3tourney5",
     Q3TOURNEY5_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3TOURNEY5_HEAVY: list[str] = ["monster_ogre"];

"""A hall of three pools of water, each deeper than the last and stepped
out of at both ends, a dais beyond them; the ways on from the dais and
the floor."""
node FatalPools(Prefab) {
    has dais: int = 2,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fatal pools";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(32, 34);
        self.wide = dice.between(16, 18);
        self.dais = dice.between(2, 3);
        self.tall = dice.between(13, 15);
        self.low = -6;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.dais), Port(face=1, along=10.0, floor=0), Port(face=3, along=18.5, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.dais);
        for index in range(3) {
            x0 = 4 + index * 8;
            build.pool(x0, 4, -3 - index, x0 + 5, self.wide - 4, 0, 2, False, True, True);
        }
        build.solid(self.long - 4, 1, 0, self.long - 1, self.wide - 1, self.dais);
        stair(build, self.long - 4 - self.dais, middle - 1, 0, 0, self.dais, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 8) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, arena_foe(dice, self.danger, Q3TOURNEY5_LIGHT, Q3TOURNEY5_HEAVY, index == 0), 180.0);
        }
        build.supply(22.5, float(middle) + 0.5, -5, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, 2.5, self.dais, Q3_HEALTH, "q3");
    }
}

"""q3tourney5's stretches: [name, role]."""
glob Q3TOURNEY5_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["pools", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney5's stretches by its name."""
def make_q3tourney5(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY5, label="Fatal hall", light=Q3TOURNEY5_LIGHT, heavy=Q3TOURNEY5_HEAVY, sky=False);
    }
    if name == "pools" {
        return FatalPools();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY5, label="Fatal tower", light=Q3TOURNEY5_LIGHT, heavy=Q3TOURNEY5_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY5, label="Fatal atrium", light=Q3TOURNEY5_LIGHT, heavy=Q3TOURNEY5_HEAVY, sky=False, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY5, label="Fatal vault", key=key if key else "key_silver", light=Q3TOURNEY5_LIGHT, heavy=Q3TOURNEY5_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY5, label="Fatal portal", key=key, light=Q3TOURNEY5_LIGHT, heavy=Q3TOURNEY5_HEAVY, sky=False);
}
