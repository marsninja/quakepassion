"""Prefabs drawn from Quake III's q3dm17, The Longest Yard: ledges and islands out over a void. Quake III's
arenas hold no foes of their own; q3dm17's are wizard, army, hell_knight.
Raised in q3dm17's own palette.

- `LongestYard`: ledges over a deep drop, jump pads to an island and the far ledge, teleporters back up.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm17."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM17: str = "q3:q3dm17",
     Q3DM17_LIGHT: list[str] = ["monster_wizard", "monster_army"],
     Q3DM17_HEAVY: list[str] = ["monster_hell_knight"];

"""Ledges out over a deep drop under the sky: from the near one a jump pad
throws a body to an island, from the island another to the far ledge; a
teleporter on the bottom of the drop back to the near ledge."""
node LongestYard(Prefab) {
    has deep: int = 8,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Longest yard";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(7, 9);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=5), Port(face=1, along=float(self.long - 3), floor=5)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        yard = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, 0);
        build.level(yard, 2);
        build.level(yard, 5);
        build.solid(1, 1, low, 10, self.wide - 1, 0);
        build.solid(12, 5, low, 18, self.wide - 5, 2);
        build.solid(20, 1, low, self.long - 1, self.wide - 1, 5);
        pad_y = float(middle) + 0.5;
        build.jump_pad(9.0, pad_y, 0, 13.0, pad_y, 2);
        build.jump_pad(17.0, pad_y, 2, 21.0, pad_y, 5);
        # No railing at the edges the pads throw a body over.
        for y in range(middle - 1, middle + 2) {
            build.keep(yard, 9, y, 0);
            build.keep(yard, 17, y, 2);
        }
        build.teleporter(15.0, 3.0, low, 3.0, pad_y, 0, 0.0);
        build.teleporter(15.0, float(self.wide) - 3.0, low, 3.0, pad_y, 0, 0.0);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.foe(14.5, pad_y - 2.0, 2, arena_foe(dice, self.danger, Q3DM17_LIGHT, Q3DM17_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, 3.0, 5, arena_foe(dice, self.danger, Q3DM17_LIGHT, Q3DM17_HEAVY, True), 180.0);
        build.supply(16.0, pad_y + 2.0, 2, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 5, Q3_HEALTH, "q3");
    }
}

"""q3dm17's stretches: [name, role]."""
glob Q3DM17_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["yard", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm17's stretches by its name."""
def make_q3dm17(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM17, label="Yard hall", light=Q3DM17_LIGHT, heavy=Q3DM17_HEAVY, sky=True);
    }
    if name == "yard" {
        return LongestYard();
    }
    if name == "tower" {
        return PadTower(source=Q3DM17, label="Yard tower", light=Q3DM17_LIGHT, heavy=Q3DM17_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM17, label="Yard atrium", light=Q3DM17_LIGHT, heavy=Q3DM17_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM17, label="Yard vault", key=key if key else "key_silver", light=Q3DM17_LIGHT, heavy=Q3DM17_HEAVY);
    }
    return ArenaPortal(source=Q3DM17, label="Yard portal", key=key, light=Q3DM17_LIGHT, heavy=Q3DM17_HEAVY, sky=True);
}
