"""Prefabs drawn from Quake III's q3tourney3, Hell's Gate: a gate over a river of lava. Quake III's
arenas hold no foes of their own; q3tourney3's are hell_knight, knight, demon1.
Raised in q3tourney3's own palette.

- `HellsGateBridge`: a narrow bridge over lava to a landing, a stair up to the stage before the gate.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney3."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY3: str = "q3:q3tourney3",
     Q3TOURNEY3_LIGHT: list[str] = ["monster_hell_knight", "monster_knight"],
     Q3TOURNEY3_HEAVY: list[str] = ["monster_demon1"];

"""A gate across a river of lava: a narrow bridge over it to a landing,
a stair up from the landing to the stage before the gate; the ways on from
the stage (and one from the landing)."""
node HellsGateBridge(Prefab) {
    has stage: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hell's gate bridge";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.stage = dice.between(3, 4);
        self.tall = dice.between(15, 17);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.stage), Port(face=1, along=float(self.long - 3), floor=self.stage), Port(face=3, along=float(self.long - 8), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        land = self.long - 10;
        gate = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(gate, self.stage);
        build.pool(7, 1, -3, land, self.wide - 1, 0, 4, False, False);
        build.solid(7, middle - 1, -1, land, middle + 2, 0);
        build.solid(land + 4, 1, 0, self.long - 1, self.wide - 1, self.stage);
        stair(build, land + 4 - self.stage, middle - 1, 0, 0, self.stage, 3);
        for y in range(middle - 1, middle + 2) {
            build.keep(gate, 6, y, 0);
            build.keep(gate, land, y, 0);
        }
        build.doorway(gate, self.enter);
        for port in self.taken {
            build.doorway(gate, port);
        }
        build.foe(float(land) + 1.5, float(middle) + 3.5, 0, arena_foe(dice, self.danger, Q3TOURNEY3_LIGHT, Q3TOURNEY3_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, self.stage, arena_foe(dice, self.danger, Q3TOURNEY3_LIGHT, Q3TOURNEY3_HEAVY, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.stage, Q3_HEALTH, "q3");
    }
}

"""q3tourney3's stretches: [name, role]."""
glob Q3TOURNEY3_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["bridge", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney3's stretches by its name."""
def make_q3tourney3(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY3, label="Hellgate hall", light=Q3TOURNEY3_LIGHT, heavy=Q3TOURNEY3_HEAVY, sky=False);
    }
    if name == "bridge" {
        return HellsGateBridge();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY3, label="Hellgate tower", light=Q3TOURNEY3_LIGHT, heavy=Q3TOURNEY3_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY3, label="Hellgate atrium", light=Q3TOURNEY3_LIGHT, heavy=Q3TOURNEY3_HEAVY, sky=False, liquid=4);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY3, label="Hellgate vault", key=key if key else "key_silver", light=Q3TOURNEY3_LIGHT, heavy=Q3TOURNEY3_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY3, label="Hellgate portal", key=key, light=Q3TOURNEY3_LIGHT, heavy=Q3TOURNEY3_HEAVY, sky=False);
}
