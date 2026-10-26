"""Prefabs drawn from Quake III's q3dm19, Apocalypse Void: walks over a lake of lava under the sky. Quake III's
arenas hold no foes of their own; q3dm19's are knight, ogre, shalrath.
Raised in q3dm19's own palette.

- `ApocalypseVoid`: a causeway over lava to a platform, a jump pad over a cell of lava to the far ledge.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm19."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM19: str = "q3:q3dm19",
     Q3DM19_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3DM19_HEAVY: list[str] = ["monster_shalrath"];

"""Walks over a lake of lava: a causeway out to a wide platform, a jump
pad there throwing a body over a cell of lava up to the far ledge (a teleporter back); an arm
of the platform to a way on at the side."""
node ApocalypseVoid(Prefab) {
    has ledge: int = 4,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Apocalypse void";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.ledge = dice.between(3, 5);
        self.tall = dice.between(15, 17);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=1, along=float(self.long - 3), floor=self.ledge), Port(face=3, along=16.5, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        far = self.long - 5;
        void = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, self.ledge);
        build.pool(5, 1, -3, far, self.wide - 1, 0, 4, False, False);
        build.solid(5, middle - 1, -1, 13, middle + 2, 0);
        build.solid(13, 3, -1, far - 1, self.wide - 3, 0);
        build.solid(15, 1, -1, 18, 3, 0);
        build.solid(far, 1, 0, self.long - 1, self.wide - 1, self.ledge);
        build.jump_pad(float(far) - 3.0, float(middle) + 0.5, 0, float(far) + 1.0, float(middle) + 0.5, self.ledge);
        build.teleporter(float(far) + 1.0, 3.0, self.ledge, 14.0, float(middle) + 0.5, 0, 180.0);
        for y in range(middle - 1, middle + 2) {
            build.keep(void, 4, y, 0);
            build.keep(void, 13, y, 0);
        }
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(15 + index * 2) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, arena_foe(dice, self.danger, Q3DM19_LIGHT, Q3DM19_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, Q3_HEALTH, "q3");
    }
}

"""q3dm19's stretches: [name, role]."""
glob Q3DM19_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["causeway", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm19's stretches by its name."""
def make_q3dm19(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM19, label="Apocalypse hall", light=Q3DM19_LIGHT, heavy=Q3DM19_HEAVY, sky=True);
    }
    if name == "causeway" {
        return ApocalypseVoid();
    }
    if name == "tower" {
        return PadTower(source=Q3DM19, label="Apocalypse tower", light=Q3DM19_LIGHT, heavy=Q3DM19_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM19, label="Apocalypse atrium", light=Q3DM19_LIGHT, heavy=Q3DM19_HEAVY, sky=True, liquid=4);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM19, label="Apocalypse vault", key=key if key else "key_silver", light=Q3DM19_LIGHT, heavy=Q3DM19_HEAVY);
    }
    return ArenaPortal(source=Q3DM19, label="Apocalypse portal", key=key, light=Q3DM19_LIGHT, heavy=Q3DM19_HEAVY, sky=True);
}
