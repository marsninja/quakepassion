"""Prefabs drawn from Quake III's q3dm11, Deva Station: a station of catwalks over a deep floor. Quake III's
arenas hold no foes of their own; q3dm11's are army, enforcer, ogre.
Raised in q3dm11's own palette.

- `DevaCatwalks`: a station hall, catwalks along its walls at two heights ridden up to by lifts.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm11."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM11: str = "q3:q3dm11",
     Q3DM11_LIGHT: list[str] = ["monster_army", "monster_enforcer"],
     Q3DM11_HEAVY: list[str] = ["monster_ogre"];

"""A station hall, catwalks along its walls at two heights, a lift from the
floor to the lower and another from it to the upper; the way on at the
top (and one below)."""
node DevaCatwalks(Prefab) {
    has first: int = 6,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva catwalks";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(22, 24);
        self.wide = dice.between(18, 20);
        self.first = dice.between(5, 6);
        self.tall = 2 * self.first + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=2 * self.first), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.first;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, f);
        build.level(hall, 2 * f);
        north = self.wide - 4;
        build.solid(1, north, f - 1, self.long - 1, self.wide - 1, f);
        build.solid(1, 1, 2 * f - 1, self.long - 1, 4, 2 * f);
        build.solid(self.long - 4, 4, 2 * f - 1, self.long - 1, self.wide - 1, 2 * f);
        lift(build, 4, north - 3, 7, north, 0, f);
        lift(build, self.long - 7, north - 3, self.long - 4, north, f, 2 * f);
        for x in range(1, self.long - 1) {
            build.keep(hall, x, north, f);
            build.keep(hall, x, 3, 2 * f);
        }
        for y in range(north - 3, north) {
            build.keep(hall, self.long - 4, y, 2 * f);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, f, arena_foe(dice, self.danger, Q3DM11_LIGHT, Q3DM11_HEAVY), 270.0);
        build.foe(float(self.long // 2) + 0.5, 2.5, 2 * f, arena_foe(dice, self.danger, Q3DM11_LIGHT, Q3DM11_HEAVY, True), 90.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 2 * f, Q3_HEALTH, "q3");
    }
}

"""q3dm11's stretches: [name, role]."""
glob Q3DM11_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["catwalks", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm11's stretches by its name."""
def make_q3dm11(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM11, label="Deva hall", light=Q3DM11_LIGHT, heavy=Q3DM11_HEAVY, sky=False);
    }
    if name == "catwalks" {
        return DevaCatwalks();
    }
    if name == "tower" {
        return PadTower(source=Q3DM11, label="Deva tower", light=Q3DM11_LIGHT, heavy=Q3DM11_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM11, label="Deva atrium", light=Q3DM11_LIGHT, heavy=Q3DM11_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM11, label="Deva vault", key=key if key else "key_silver", light=Q3DM11_LIGHT, heavy=Q3DM11_HEAVY);
    }
    return ArenaPortal(source=Q3DM11, label="Deva portal", key=key, light=Q3DM11_LIGHT, heavy=Q3DM11_HEAVY, sky=False);
}
