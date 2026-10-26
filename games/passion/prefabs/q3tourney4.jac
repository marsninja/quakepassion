"""Prefabs drawn from Quake III's q3tourney4, Vertical Vengeance: a shaft of levels climbed by jump pads. Quake III's
arenas hold no foes of their own; q3tourney4's are wizard, ogre, shambler.
Raised in q3tourney4's own palette.

- `VerticalShaft`: a shaft climbed by jump pads, from the floor to a block, from the block to a gallery.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3tourney4."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3TOURNEY4: str = "q3:q3tourney4",
     Q3TOURNEY4_LIGHT: list[str] = ["monster_wizard", "monster_ogre"],
     Q3TOURNEY4_HEAVY: list[str] = ["monster_shambler"];

"""A shaft climbed by jump pads: from the floor up on to a block at its
far end, from the block up to a gallery high along a side wall; the ways
on from the block and the gallery, the floor to fall back to."""
node VerticalShaft(Prefab) {
    has step_up: int = 5,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vertical shaft";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.step_up = 5;
        self.tall = 2 * self.step_up + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=3, along=4.0, floor=2 * self.step_up), Port(face=1, along=float(self.long - 4), floor=self.step_up), Port(face=0, along=3.0, floor=2 * self.step_up)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.step_up;
        middle = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, f);
        build.level(shaft, 2 * f);
        build.solid(10, 1, 0, self.long - 1, self.wide - 1, f);
        build.solid(1, 1, 2 * f - 1, self.long - 1, 5, 2 * f);
        build.jump_pad(7.0, float(middle) + 2.5, 0, 11.0, float(middle) + 2.5, f);
        build.jump_pad(float(self.long) - 4.0, 8.0, f, float(self.long) - 4.0, 4.0, 2 * f);
        for x in range(1, self.long - 1) {
            build.keep(shaft, x, 4, 2 * f);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        build.foe(5.5, float(middle) + 0.5, 0, arena_foe(dice, self.danger, Q3TOURNEY4_LIGHT, Q3TOURNEY4_HEAVY), 0.0);
        build.foe(14.5, float(self.wide) - 3.5, f, arena_foe(dice, self.danger, Q3TOURNEY4_LIGHT, Q3TOURNEY4_HEAVY), 180.0);
        build.foe(4.5, 3.0, 2 * f, arena_foe(dice, self.danger, Q3TOURNEY4_LIGHT, Q3TOURNEY4_HEAVY, True), 0.0);
        build.supply(8.5, 3.0, 2 * f, Q3_ARMOR, "q3");
    }
}

"""q3tourney4's stretches: [name, role]."""
glob Q3TOURNEY4_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["shaft", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3tourney4's stretches by its name."""
def make_q3tourney4(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3TOURNEY4, label="Vengeance hall", light=Q3TOURNEY4_LIGHT, heavy=Q3TOURNEY4_HEAVY, sky=False);
    }
    if name == "shaft" {
        return VerticalShaft();
    }
    if name == "tower" {
        return PadTower(source=Q3TOURNEY4, label="Vengeance tower", light=Q3TOURNEY4_LIGHT, heavy=Q3TOURNEY4_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3TOURNEY4, label="Vengeance atrium", light=Q3TOURNEY4_LIGHT, heavy=Q3TOURNEY4_HEAVY, sky=False, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3TOURNEY4, label="Vengeance vault", key=key if key else "key_silver", light=Q3TOURNEY4_LIGHT, heavy=Q3TOURNEY4_HEAVY);
    }
    return ArenaPortal(source=Q3TOURNEY4, label="Vengeance portal", key=key, light=Q3TOURNEY4_LIGHT, heavy=Q3TOURNEY4_HEAVY, sky=False);
}
