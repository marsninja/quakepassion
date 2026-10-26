"""Prefabs drawn from Quake III's q3tourney6, The Very End of You: walks over the void to the boss's stage. Quake III's
arenas hold no foes of their own; q3tourney6's are hell_knight, shalrath, shambler.
Raised in q3tourney6's own palette.

- `VeryEndVoid`: walks crossing over a deep drop to a raised stage, teleporters back up.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney6."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY6: str = "q3:q3tourney6",
     Q3TOURNEY6_LIGHT: list[str] = ["monster_hell_knight", "monster_shalrath"],
     Q3TOURNEY6_HEAVY: list[str] = ["monster_shambler"];

"""Walks crossing over a deep drop under the sky: one across from the
near side to a raised far stage, one across it to ways on at either side;
a teleporter on the bottom of the drop back to the near side."""
node VeryEndVoid(Prefab) {
    has deep: int = 9,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Very end void";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=3), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        cx = self.long // 2;
        low = -self.deep;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, 3);
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        build.solid(self.long - 6, 1, low, self.long - 1, self.wide - 1, 3);
        build.solid(6, cy - 1, -1, self.long - 6, cy + 2, 0);
        stair(build, self.long - 9, cy - 1, 0, 0, 3, 3);
        build.solid(cx - 3, 1, low, cx + 3, 4, 0);
        build.solid(cx - 3, self.wide - 4, low, cx + 3, self.wide - 1, 0);
        build.solid(cx - 1, 4, -1, cx + 2, self.wide - 4, 0);
        build.teleporter(float(cx) - 5.0, float(cy) - 4.0, low, 3.0, float(cy) + 0.5, 0, 0.0);
        build.teleporter(float(cx) + 5.0, float(cy) + 5.0, low, 3.0, float(cy) + 0.5, 0, 0.0);
        for y in range(cy - 1, cy + 2) {
            build.keep(void, 5, y, 0);
        }
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.foe(float(cx) + 0.5, 2.5, 0, arena_foe(dice, self.danger, Q3TOURNEY6_LIGHT, Q3TOURNEY6_HEAVY), 90.0);
        build.foe(float(cx) + 0.5, float(self.wide) - 2.5, 0, arena_foe(dice, self.danger, Q3TOURNEY6_LIGHT, Q3TOURNEY6_HEAVY), 270.0);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 3, arena_foe(dice, self.danger, Q3TOURNEY6_LIGHT, Q3TOURNEY6_HEAVY, True), 180.0);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 0, Q3_ARMOR, "q3");
    }
}

"""q3tourney6's stretches: [name, role]."""
glob Q3TOURNEY6_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["walks", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney6's stretches by its name."""
def make_q3tourney6(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY6, label="End hall", light=Q3TOURNEY6_LIGHT, heavy=Q3TOURNEY6_HEAVY, sky=True);
    }
    if name == "walks" {
        return VeryEndVoid();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY6, label="End tower", light=Q3TOURNEY6_LIGHT, heavy=Q3TOURNEY6_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY6, label="End atrium", light=Q3TOURNEY6_LIGHT, heavy=Q3TOURNEY6_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY6, label="End vault", key=key if key else "key_silver", light=Q3TOURNEY6_LIGHT, heavy=Q3TOURNEY6_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY6, label="End portal", key=key, light=Q3TOURNEY6_LIGHT, heavy=Q3TOURNEY6_HEAVY, sky=True);
}
