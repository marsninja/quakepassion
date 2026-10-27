"""Prefabs drawn from Quake III's q3dm6, The Camping Grounds: a tower of
stone stairs and ledges over a yard, a stone bridge over a sunken court,
camping spots high up thrown up to by jump pads. Quake III's arenas hold
no foes of their own; q3dm6's are ogre, army, demon1. Raised in q3dm6's
own palette.

- `CampingTower`: a tower, a stair winding up its inside walls between
  its foot and a deck high on one wall, climbed or come down by the dice;
  a jump pad in its foot may throw a body up onto the stair's middle.
- `CampingYard`: the hub. An open yard, two towers standing in it thrown
  up to by jump pads from the ground, a pad from the lower tower's top
  across to a high ledge along the far wall, a stair from the higher
  tower's top up to the ledge too (q3dm6's pads up to its camping
  spots); a balcony over the way in may be thrown up to by a pad of its
  own; ways on from the ground and the ledge.
- `StoneBridge`: a sunken court, terraces at either end, a stone bridge
  across it from terrace to terrace, stairs down into it, a pad up onto
  the bridge from the court, now and then a pool under the bridge and a
  walkway high along one wall; ways on from the terraces, the court and
  the walkway (a hub as well).
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm6."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing, ring_path }
import from .e1m1_parts { deck }
import from .e2m2 { spiral_landing, foot_clear }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM6: str = "q3:q3dm6",
     Q3DM6_LIGHT: list[str] = ["monster_ogre", "monster_army"],
     Q3DM6_HEAVY: list[str] = ["monster_demon1"];

"""A tall tower, a stair winding up round its walls between its foot and
a deck high on one wall; a pad may throw a body up onto the stair."""
node CampingTower(Prefab) {
    has steps: int = 16,
        tall: int = 26,
        down: bool = False,
        pad_at: int = -1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping tower";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        self.down = dice.chance(0.45);
        middle = float(self.wide // 2);
        fits: list[int] = [];
        for steps in range(12, 30) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if not landing {
                continue;
            }
            if self.down {
                if landing[0] == 2.0 and foot_clear(self.long, self.wide, steps, 5, 1, float(self.long // 2)) {
                    fits.append(steps);
                }
            } elif landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        if not fits {
            self.down = False;
            for steps in range(12, 30) {
                landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
                if landing and landing[0] == 0.0 {
                    fits.append(steps);
                }
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        # A pad in the foot throws a body up onto a step half way up that
        # lies along a wall (not at a corner).
        self.pad_at = -1;
        if dice.chance(0.6) {
            path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
            for index in range(self.steps // 2 - 2, self.steps // 2 + 3) {
                cell = path[index];
                along_ok = (cell[0] >= 5 and cell[2] <= self.long - 5) if cell[4] % 2 == 1 else (cell[1] >= 5 and cell[3] <= self.wide - 5);
                if self.pad_at < 0 and along_ok and index + 1 >= 6 {
                    self.pad_at = index;
                }
            }
        }
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        if self.down {
            self.enter = Port(face=2, along=top[1], floor=self.steps);
            self.leaves = [Port(face=1, along=float(self.long // 2), floor=0)];
        } else {
            self.enter = Port(face=2, along=middle, floor=0);
            self.leaves = [Port(face=0, along=top[1], floor=self.steps), Port(face=1, along=float(self.long // 2), floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(tower, self.steps);
        build.level(tower, self.steps // 2);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        if self.pad_at >= 0 {
            # The pad three cells in from the step's inner edge, throwing a
            # body over it onto the step.
            path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
            cell = path[self.pad_at];
            face = cell[4];
            mx = float(cell[0] + cell[2]) * 0.5;
            my = float(cell[1] + cell[3]) * 0.5;
            px = mx;
            py = my;
            if face == 0 {
                px = float(cell[0]) - 3.0;
            } elif face == 2 {
                px = float(cell[2]) + 3.0;
            } elif face == 1 {
                py = float(cell[1]) - 3.0;
            } else {
                py = float(cell[3]) + 3.0;
            }
            build.jump_pad(px, py, 0, mx, my, self.pad_at + 1);
            for x in range(cell[0], cell[2]) {
                for y in range(cell[1], cell[3]) {
                    build.keep(tower, x, y, self.pad_at + 1);
                }
            }
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        # What stands in the foot, in the corner away from the pad.
        spot = [float(self.long) - 6.0, float(self.wide) - 6.0];
        if self.pad_at >= 0 and ring_path(1, 1, self.long - 1, self.wide - 1, 3)[self.pad_at][4] in [0, 1] {
            spot = [6.0, 6.0];
        }
        build.foe(spot[0], spot[1], 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, self.steps - 2, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY, True), 180.0);
        build.supply(spot[0] + 1.5, spot[1], 0, Q3_ARMOR, "q3");
    }
}

"""An open yard, two towers in it reached by jump pads, a pad from the
lower one's top to a high ledge along the far wall, a stair from the
higher one's top up to the ledge, a balcony over the way in now and then;
ways on from the ground and the ledge."""
node CampingYard(Prefab) {
    has ledge: int = 16,
        low_top: int = 6,
        high_top: int = 12,
        balcony: int = 0,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping yard";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.ledge = dice.between(15, 17);
        self.low_top = dice.between(5, 7);
        self.high_top = self.ledge - dice.between(3, 5);
        self.balcony = dice.between(9, 10) if dice.chance(0.5) else 0;
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
        build.level(yard, self.low_top);
        build.level(yard, self.high_top);
        build.level(yard, self.ledge);
        # The lower tower and its pad from the ground on its south side.
        build.solid(8, 4, 0, 13, 9, self.low_top);
        build.jump_pad(10.5, 12.0, 0, 10.5, 8.0, self.low_top);
        for x in range(8, 13) {
            build.keep(yard, x, 8, self.low_top);
        }
        # The higher tower, and its pad from the ground.
        bx0 = self.long - 10;
        by0 = self.wide - 10;
        build.solid(bx0, by0, 0, self.long - 4, self.wide - 4, self.high_top);
        build.jump_pad(float(self.long) - 7.0, float(by0) - 3.0, 0, float(self.long) - 7.0, float(by0) + 1.0, self.high_top);
        # The ledge along the far wall, and the stair up to it from the
        # higher tower's top.
        build.solid(self.long - 4, 1, 0, self.long - 1, self.wide - 4, self.ledge);
        climb = self.ledge - self.high_top;
        stair(build, self.long - 4 - climb, self.wide - 7, self.high_top, 0, climb, 3);
        # From the lower tower's top, a pad across to the ledge.
        build.jump_pad(11.0, 6.5, self.low_top, float(self.long) - 3.0, 5.5, self.ledge);
        # No railings where the pads throw a body over an edge or land it.
        for y in range(4, 9) {
            build.keep(yard, 12, y, self.low_top);
            build.keep(yard, self.long - 4, y + 1, self.ledge);
        }
        for x in range(self.long - 9, self.long - 5) {
            build.keep(yard, x, by0, self.high_top);
        }
        # The balcony over the way in, a camping spot thrown up to by its own
        # pad.
        middle = self.wide // 2;
        if self.balcony > 0 {
            build.level(yard, self.balcony);
            deck(build, 1, 1, 5, self.wide - 1, self.balcony);
            build.jump_pad(8.0, float(middle) + 3.5, 0, 3.0, float(middle) + 3.5, self.balcony);
            for y in range(middle + 2, middle + 6) {
                build.keep(yard, 4, y, self.balcony);
            }
            build.foe(2.5, 3.5, self.balcony, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 0.0);
            build.supply(2.5, float(self.wide) - 3.5, self.balcony, Q3_HEALTH, "q3");
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.foe(10.5, 6.5, self.low_top, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 0.0);
        build.foe(float(bx0) + 2.5, float(by0) + 3.5, self.high_top, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY, True), 180.0);
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, self.ledge, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, 3.5 + float(index) * 8.0, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 90.0);
        }
        build.supply(15.5, 3.0, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, Q3_HEALTH, "q3");
    }
}

"""A sunken court, terraces at either end, a stone bridge across from one
to the other, stairs down into the court, a pad up onto the bridge; a pool
under it and a walkway high along a wall now and then."""
node StoneBridge(Prefab) {
    has deep: int = 7,
        lane: int = 8,
        tall: int = 18,
        pool: bool = False,
        upper: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Stone bridge";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.deep = dice.between(7, 8);
        self.long = dice.between(28, 31);
        self.wide = dice.between(18, 21);
        self.lane = dice.between(8, self.wide - 8);
        self.pool = dice.chance(0.5);
        self.upper = dice.chance(0.5);
        self.tall = dice.between(16, 18);
        self.low = -self.deep - 7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=-self.deep)];
        if self.upper {
            self.leaves.append(Port(face=0, along=float(self.wide) - 3.0, floor=7));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        bottom = -self.deep;
        court = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, 0);
        build.level(court, bottom);
        x0 = 7;
        x1 = self.long - 7;
        build.solid(1, 1, bottom, x0, self.wide - 1, 0);
        build.solid(x1, 1, bottom, self.long - 1, self.wide - 1, 0);
        # The bridge from terrace to terrace, four cells wide, its ends
        # unrailed.
        deck(build, x0, self.lane, x1, self.lane + 4, 0);
        for y in range(self.lane, self.lane + 4) {
            build.keep(court, x0 - 1, y, 0);
            build.keep(court, x1, y, 0);
        }
        # The stairs down into the court, both along the south wall.
        stair(build, x0 + self.deep - 1, 1, bottom, 2, self.deep, 3);
        stair(build, x1 - self.deep, 1, bottom, 0, self.deep, 3);
        for y in range(1, 4) {
            build.keep(court, x0 - 1, y, 0);
            build.keep(court, x1, y, 0);
        }
        # The pad up onto the bridge's middle from the court.
        cx = self.long // 2;
        build.jump_pad(float(cx) - 2.0, float(self.lane) - 3.0, bottom, float(cx) - 2.0, float(self.lane) + 1.5, 0);
        for x in range(cx - 4, cx + 1) {
            build.keep(court, x, self.lane, 0);
        }
        # A pool under the bridge's far half, steps out at both ends.
        if self.pool {
            build.pool(cx + 1, 5, bottom - 5, x1 - 1, self.wide - 3, bottom, 2, False, True, True);
        }
        # The walkway high along the north wall, up a stair on the near
        # terrace, to a way on in the far wall.
        if self.upper {
            build.level(court, 7);
            for step in range(6) {
                build.solid(1 + step, self.wide - 4, 0, 2 + step, self.wide - 1, step + 1);
            }
            deck(build, 7, self.wide - 5, self.long - 1, self.wide - 1, 7);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(court, 6, y, 7);
                build.keep(court, 7, y, 7);
            }
            build.foe(float(x1) + 2.5, float(self.wide) - 3.0, 7, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.foe(float(x1) + 3.5, float(self.wide // 2) + 0.5, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY, True), 180.0);
        build.foe(float(x1) + 2.5, float(self.wide) - 3.5, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 180.0);
        build.foe(float(cx) + 0.5, float(self.lane) + 2.0, 0, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0) + 3.5 + float(index) * 4.0, float(self.wide) - 3.5, bottom, arena_foe(dice, self.danger, Q3DM6_LIGHT, Q3DM6_HEAVY), 90.0);
        }
        build.supply(float(cx) + 0.5, float(self.wide) - 2.5, bottom, Q3_ARMOR, "q3");
        build.supply(float(x0) - 2.5, float(self.lane) + 2.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm6's stretches: [name, role]."""
glob Q3DM6_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["climb", "flow"],
         ["tower", "flow"],
         ["bridge", "flow"],
         ["yard", "hub"],
         ["bridge", "hub"],
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
    if name == "bridge" {
        return StoneBridge();
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM6, label="Camping atrium", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True, liquid=0);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM6, label="Camping vault", key=key if key else "key_silver", light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY);
    }
    return ArenaPortal(source=Q3DM6, label="Camping portal", key=key, light=Q3DM6_LIGHT, heavy=Q3DM6_HEAVY, sky=True);
}
