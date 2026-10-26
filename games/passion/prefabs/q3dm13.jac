"""Prefabs drawn from Quake III's q3dm13, Lost World: ruins under the sky, pools among broken columns. Quake III's
arenas hold no foes of their own; q3dm13's are dog, ogre, shambler.
Raised in q3dm13's own palette.

- `LostRuins`: ruins under the sky, a pool among broken columns, a stair up a broken wall to its top.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm13."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM13: str = "q3:q3dm13",
     Q3DM13_LIGHT: list[str] = ["monster_dog", "monster_ogre"],
     Q3DM13_HEAVY: list[str] = ["monster_shambler"];

"""Ruins under the sky, a pool among broken columns, a broken wall's top
walked to the way on up a stair of fallen blocks."""
node LostRuins(Prefab) {
    has wall: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost ruins";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.wall = dice.between(4, 6);
        self.tall = dice.between(17, 19);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=3.0, floor=self.wall), Port(face=0, along=middle + 2.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ruins = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ruins, self.wall);
        build.pool(8, middle - 2, -3, 16, middle + 4, 0, 2);
        build.solid(1, 1, 0, self.long - 1, 5, self.wall);
        stair(build, self.long - 6, 5 + self.wall - 1, 0, 3, self.wall, 3);
        for x in range(4, self.long - 3, 5) {
            if dice.chance(0.7) {
                build.solid(x, middle + 6, 0, x + 1, middle + 7, dice.between(2, 9));
            }
        }
        for x in [9, 14] {
            build.solid(x, 1, self.wall, x + 2, 2, self.wall + dice.between(1, 2));
        }
        build.doorway(ruins, self.enter);
        for port in self.taken {
            build.doorway(ruins, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(18 + index * 3) + 0.5, float(middle) + 2.5, 0, arena_foe(dice, self.danger, Q3DM13_LIGHT, Q3DM13_HEAVY), 180.0);
        }
        build.foe(float(self.long) - 3.0, 3.0, self.wall, arena_foe(dice, self.danger, Q3DM13_LIGHT, Q3DM13_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm13's stretches: [name, role]."""
glob Q3DM13_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["ruins", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm13's stretches by its name."""
def make_q3dm13(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM13, label="Lost hall", light=Q3DM13_LIGHT, heavy=Q3DM13_HEAVY, sky=True);
    }
    if name == "ruins" {
        return LostRuins();
    }
    if name == "tower" {
        return PadTower(source=Q3DM13, label="Lost tower", light=Q3DM13_LIGHT, heavy=Q3DM13_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM13, label="Lost atrium", light=Q3DM13_LIGHT, heavy=Q3DM13_HEAVY, sky=True, liquid=2);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM13, label="Lost vault", key=key if key else "key_silver", light=Q3DM13_LIGHT, heavy=Q3DM13_HEAVY);
    }
    return ArenaPortal(source=Q3DM13, label="Lost portal", key=key, light=Q3DM13_LIGHT, heavy=Q3DM13_HEAVY, sky=True);
}
