"""Prefabs drawn from Quake III's q3dm0, Introduction: a small arena to learn in, a platform reached by a teleporter or a stair. Quake III's
arenas hold no foes of their own; q3dm0's are army, knight, ogre.
Raised in q3dm0's own palette.

- `IntroLoop`: a hall, a platform across its far end reached by a teleporter at the near end or a stair; the ways on from the platform.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm0."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM0: str = "q3:q3dm0",
     Q3DM0_LIGHT: list[str] = ["monster_army", "monster_knight"],
     Q3DM0_HEAVY: list[str] = ["monster_ogre"];

"""A hall, a platform across its far end reached by a teleporter at the
near end or by a stair up its side; the ways on from the platform."""
node IntroLoop(Prefab) {
    has platform: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro loop";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.platform = dice.between(4, 5);
        self.tall = dice.between(13, 15);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.platform), Port(face=1, along=float(self.long - 4), floor=self.platform)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.platform);
        px = self.long - 8;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.platform);
        stair(build, px - self.platform, 1, 0, 0, self.platform, 3);
        build.teleporter(4.5, float(middle) + 0.5, 0, float(self.long) - 4.0, float(middle) + 0.5, self.platform, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(px) - 3.5, float(self.wide) - 3.0, 0, arena_foe(dice, self.danger, Q3DM0_LIGHT, Q3DM0_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, 3.0, self.platform, arena_foe(dice, self.danger, Q3DM0_LIGHT, Q3DM0_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.platform, Q3_HEALTH, "q3");
    }
}

"""q3dm0's stretches: [name, role]."""
glob Q3DM0_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["loop", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm0's stretches by its name."""
def make_q3dm0(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM0, label="Intro hall", light=Q3DM0_LIGHT, heavy=Q3DM0_HEAVY, sky=False);
    }
    if name == "loop" {
        return IntroLoop();
    }
    if name == "tower" {
        return PadTower(source=Q3DM0, label="Intro tower", light=Q3DM0_LIGHT, heavy=Q3DM0_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM0, label="Intro atrium", light=Q3DM0_LIGHT, heavy=Q3DM0_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM0, label="Intro vault", key=key if key else "key_silver", light=Q3DM0_LIGHT, heavy=Q3DM0_HEAVY);
    }
    return ArenaPortal(source=Q3DM0, label="Intro portal", key=key, light=Q3DM0_LIGHT, heavy=Q3DM0_HEAVY, sky=False);
}
