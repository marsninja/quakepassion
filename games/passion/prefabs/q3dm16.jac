"""Prefabs drawn from Quake III's q3dm16, The Bouncy Map: platforms in the sky thrown between by jump pads. Quake III's
arenas hold no foes of their own; q3dm16's are army, wizard, ogre.
Raised in q3dm16's own palette.

- `BouncePads`: platforms rising one past another, a jump pad on each up to the next.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm16."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM16: str = "q3:q3dm16",
     Q3DM16_LIGHT: list[str] = ["monster_army", "monster_wizard"],
     Q3DM16_HEAVY: list[str] = ["monster_ogre"];

"""A hall of platforms rising one past another, a jump pad on each
throwing a body on to the next, the floor round them to fall back to; the
ways on from the highest."""
node BouncePads(Prefab) {
    has stage: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bounce pads";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(30, 32);
        self.wide = dice.between(16, 18);
        self.stage = 3;
        self.tall = 3 * self.stage + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=3 * self.stage), Port(face=1, along=float(self.long - 3), floor=3 * self.stage), Port(face=3, along=12.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.stage;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, r);
        build.level(hall, 2 * r);
        build.level(hall, 3 * r);
        build.solid(8, 4, 0, 16, self.wide - 4, r);
        build.solid(18, 4, 0, 24, self.wide - 4, 2 * r);
        build.solid(26, 1, 0, self.long - 1, self.wide - 1, 3 * r);
        pad_y = float(middle) + 0.5;
        build.jump_pad(5.0, pad_y, 0, 9.0, pad_y, r);
        build.jump_pad(15.0, pad_y, r, 19.0, pad_y, 2 * r);
        build.jump_pad(23.0, pad_y, 2 * r, 27.0, pad_y, 3 * r);
        # No railing at the edges the pads throw a body over.
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, 15, y, r);
            build.keep(hall, 23, y, 2 * r);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(11.5, float(middle) - 2.5, r, arena_foe(dice, self.danger, Q3DM16_LIGHT, Q3DM16_HEAVY), 180.0);
        build.foe(20.5, float(middle) + 2.5, 2 * r, arena_foe(dice, self.danger, Q3DM16_LIGHT, Q3DM16_HEAVY), 180.0);
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, 3 * r, arena_foe(dice, self.danger, Q3DM16_LIGHT, Q3DM16_HEAVY, True), 180.0);
        build.supply(20.5, float(middle) - 2.5, 2 * r, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm16's stretches: [name, role]."""
glob Q3DM16_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["bounce", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm16's stretches by its name."""
def make_q3dm16(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM16, label="Bouncy hall", light=Q3DM16_LIGHT, heavy=Q3DM16_HEAVY, sky=True);
    }
    if name == "bounce" {
        return BouncePads();
    }
    if name == "tower" {
        return PadTower(source=Q3DM16, label="Bouncy tower", light=Q3DM16_LIGHT, heavy=Q3DM16_HEAVY, sky=True);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM16, label="Bouncy atrium", light=Q3DM16_LIGHT, heavy=Q3DM16_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM16, label="Bouncy vault", key=key if key else "key_silver", light=Q3DM16_LIGHT, heavy=Q3DM16_HEAVY);
    }
    return ArenaPortal(source=Q3DM16, label="Bouncy portal", key=key, light=Q3DM16_LIGHT, heavy=Q3DM16_HEAVY, sky=True);
}
