"""Prefabs drawn from Quake III's q3dm6, The Camping Grounds: a tower of stone stairs and ledges over a yard. Quake III's
arenas hold no foes of their own; q3dm6's are ogre, army, demon1.
Raised in q3dm6's own palette.

- `CampingTower`: a tower, a stair winding up its inside walls to the way on at the top.
- `CampingYard`: the hub. An open yard, two towers standing in it thrown up
  to by jump pads from the ground, a pad from the lower tower's top across
  to a high ledge along the far wall, a stair from the higher tower's top
  up to the ledge too (q3dm6's pads up to its camping spots); ways on from
  the ground and the ledge.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm6."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM6: str = "q3:q3dm6",
     Q3DM6_LIGHT: list[str] = ["monster_ogre", "monster_army"],
     Q3DM6_HEAVY: list[str] = ["monster_demon1"];

"""A tall tower, a stair winding up round its walls to a deck high on its
east wall and the way on there (and one at its foot)."""
node CampingTower(Prefab) {
    has steps: int = 16,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping tower";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        fits: list[int] = [];
        for steps in range(12, 30) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(tower, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, self.steps - 2, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY, True), 180.0);
        build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, 0, Q3_ARMOR, "q3");
    }
}

"""An open yard, two towers in it reached by jump pads, a pad from the
lower one's top to a high ledge along the far wall, a stair from the
higher one's top up to the ledge; ways on from the ground and the ledge."""
node CampingYard(Prefab) {
    has ledge: int = 16,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping yard";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.ledge = 16;
        self.tall = self.ledge + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=1, along=6.0, floor=0), Port(face=0, along=5.0, floor=self.ledge), Port(face=3, along=float(self.long) - 2.5, floor=self.ledge), Port(face=0, along=float(self.wide) - 3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, 6);
        build.level(yard, 12);
        build.level(yard, self.ledge);
        # The lower tower, six lifts, and its pad from the ground.
        build.solid(8, 4, 0, 13, 9, 6);
        build.jump_pad(5.0, 6.5, 0, 9.0, 6.5, 6);
        # The higher tower, twelve lifts, and its pad from the ground.
        bx0 = self.long - 10;
        by0 = self.wide - 10;
        build.solid(bx0, by0, 0, self.long - 4, self.wide - 4, 12);
        build.jump_pad(float(self.long) - 7.0, float(by0) - 3.0, 0, float(self.long) - 7.0, float(by0) + 1.0, 12);
        # The ledge along the far wall, and the stair up to it from the
        # higher tower's top.
        build.solid(self.long - 4, 1, 0, self.long - 1, self.wide - 4, self.ledge);
        stair(build, self.long - 8, self.wide - 7, 12, 0, 4, 3);
        # From the lower tower's top, a pad across to the ledge.
        build.jump_pad(11.0, 6.5, 6, float(self.long) - 3.0, 5.5, self.ledge);
        # No railings where the pads throw a body over an edge or land it.
        for y in range(5, 9) {
            build.keep(yard, 8, y, 6);
            build.keep(yard, 12, y, 6);
            build.keep(yard, self.long - 4, y, self.ledge);
        }
        for x in range(self.long - 9, self.long - 5) {
            build.keep(yard, x, by0, 12);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.foe(10.5, 6.5, 6, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 0.0);
        build.foe(float(bx0) + 2.5, float(by0) + 3.5, 12, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY, True), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, self.ledge, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, 3.5 + float(index) * 8.0, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 90.0);
        }
        build.supply(10.5, 3.0, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, Q3_HEALTH, "q3");
    }
}

"""q3dm6's stretches: [name, role]."""
glob Q3DM6_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["climb", "flow"],
         ["tower", "flow"],
         ["yard", "hub"],
         ["atrium", "flow"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm6's stretches by its name."""
def make_q3dm6(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM6, label="Camping hall", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True);
    }
    if name == "climb" {
        return CampingTower();
    }
    if name == "tower" {
        return PadTower(source=Q3DM6, label="Camping tower", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True);
    }
    if name == "yard" {
        return CampingYard();
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM6, label="Camping atrium", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM6, label="Camping vault", key=key if key else "key_silver", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY);
    }
    return ArenaPortal(source=Q3DM6, label="Camping portal", key=key, light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True);
}
