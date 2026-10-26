"""Prefabs drawn from Quake III's q3tourney1, Power Station 0218: a station round a power core. Quake III's
arenas hold no foes of their own; q3tourney1's are army, enforcer, ogre.
Raised in q3tourney1's own palette.

- `PowerCore`: a station round a core, a ring walk high round it, a stair up and a bridge on.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney1."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY1: str = "q3:q3tourney1",
     Q3TOURNEY1_LIGHT: list[str] = ["monster_army", "monster_enforcer"],
     Q3TOURNEY1_HEAVY: list[str] = ["monster_ogre"];

"""A station round a core: a ring walk high round the core, a stair up to
it and a bridge on from it to the way on; ways on at the floor too."""
node PowerCore(Prefab) {
    has ring: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Power core";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.ring = dice.between(5, 6);
        self.tall = self.ring + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ring), Port(face=1, along=5.0, floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        cx = self.long // 2;
        r = self.ring;
        station = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(station, r);
        build.solid(cx - 5, cy - 5, r - 1, cx + 5, cy + 5, r);
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.tall);
        build.solid(cx + 5, cy - 1, r - 1, self.long - 1, cy + 2, r);
        stair(build, cx - 5 - r, cy + 2, 0, 0, r, 3);
        for y in range(cy - 1, cy + 2) {
            build.keep(station, cx - 5, y + 3, r);
            build.keep(station, cx + 4, y, r);
        }
        build.doorway(station, self.enter);
        for port in self.taken {
            build.doorway(station, port);
        }
        build.foe(float(cx) + 0.5, float(cy - 4) + 0.5, r, arena_foe(dice, self.danger, Q3TOURNEY1_LIGHT, Q3TOURNEY1_HEAVY, True), 180.0);
        build.foe(float(cx) + 0.5, float(cy + 3) + 0.5, r, arena_foe(dice, self.danger, Q3TOURNEY1_LIGHT, Q3TOURNEY1_HEAVY), 180.0);
        build.foe(float(self.long) - 3.0, 3.0, 0, arena_foe(dice, self.danger, Q3TOURNEY1_LIGHT, Q3TOURNEY1_HEAVY), 180.0);
        build.supply(float(cx - 4) + 0.5, float(cy - 4) + 0.5, r, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3tourney1's stretches: [name, role]."""
glob Q3TOURNEY1_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["core", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney1's stretches by its name."""
def make_q3tourney1(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY1, label="Station hall", light=Q3TOURNEY1_LIGHT, heavy=Q3TOURNEY1_HEAVY, sky=False);
    }
    if name == "core" {
        return PowerCore();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY1, label="Station tower", light=Q3TOURNEY1_LIGHT, heavy=Q3TOURNEY1_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY1, label="Station atrium", light=Q3TOURNEY1_LIGHT, heavy=Q3TOURNEY1_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY1, label="Station vault", key=key if key else "key_silver", light=Q3TOURNEY1_LIGHT, heavy=Q3TOURNEY1_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY1, label="Station portal", key=key, light=Q3TOURNEY1_LIGHT, heavy=Q3TOURNEY1_HEAVY, sky=False);
}
