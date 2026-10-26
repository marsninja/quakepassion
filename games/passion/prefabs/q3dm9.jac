"""Prefabs drawn from Quake III's q3dm9, Hero's Keep: a keep round a void, platforms out in it. Quake III's
arenas hold no foes of their own; q3dm9's are knight, ogre, hell_knight.
Raised in q3dm9's own palette.

- `KeepVoid`: a walk round a void of lava, a platform out in it reached by a jump pad, a teleporter back.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm9."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM9: str = "q3:q3dm9",
     Q3DM9_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3DM9_HEAVY: list[str] = ["monster_hell_knight"];

"""A walk round the edge of a void with lava far below, platforms out in it
a jump pad apart, a teleporter back from the farthest; the way on beyond
the walk."""
node KeepVoid(Prefab) {
    has deep: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep void";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(7, 9);
        self.tall = dice.between(15, 17);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.solid(1, 1, low, self.long - 1, self.wide - 1, 0);
        build.widen(hall, 5, 5, low, self.long - 5, self.wide - 5, 0);
        build.pool(5, 5, low, self.long - 5, self.wide - 5, low + 3, 4, True, False);
        cx = self.long // 2;
        cy = self.wide // 2;
        build.solid(cx - 2, cy - 2, low, cx + 2, cy + 2, 2);
        build.jump_pad(3.0, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy) + 0.5, 2);
        build.teleporter(float(cx) + 1.0, float(cy) + 0.5, 2, float(self.long) - 3.0, float(cy) + 0.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(3.0 if index % 2 == 0 else float(self.long) - 3.0, 3.0 + float(index) * 5.0, 0, arena_foe(dice, self.danger, Q3DM9_LIGHT, Q3DM9_HEAVY), 0.0);
        }
        build.foe(float(cx) - 1.0, float(cy) - 1.0, 2, arena_foe(dice, self.danger, Q3DM9_LIGHT, Q3DM9_HEAVY, True), 180.0);
        build.supply(float(cx) - 1.0, float(cy) + 1.5, 2, Q3_ARMOR, "q3");
    }
}

"""q3dm9's stretches: [name, role]."""
glob Q3DM9_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["void", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm9's stretches by its name."""
def make_q3dm9(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM9, label="Keep hall", light=Q3DM9_LIGHT, heavy=Q3DM9_HEAVY, sky=False);
    }
    if name == "void" {
        return KeepVoid();
    }
    if name == "tower" {
        return PadTower(source=Q3DM9, label="Keep tower", light=Q3DM9_LIGHT, heavy=Q3DM9_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM9, label="Keep atrium", light=Q3DM9_LIGHT, heavy=Q3DM9_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM9, label="Keep vault", key=key if key else "key_silver", light=Q3DM9_LIGHT, heavy=Q3DM9_HEAVY);
    }
    return ArenaPortal(source=Q3DM9, label="Keep portal", key=key, light=Q3DM9_LIGHT, heavy=Q3DM9_HEAVY, sky=False);
}
