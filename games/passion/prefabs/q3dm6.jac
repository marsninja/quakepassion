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
- `LowerHall`: the start. A long hall under the grounds, columns down its
  open side, a gallery along one wall over the aisle, climbed by a stair
  beside it or thrown up to by a pad; its guards wake as the player sets
  out up.
- `RailLedge`: the railgun on a ledge high along a far wall over an
  undercroft, thrown up to by a pad or climbed by two flights; now and then
  a teleporter on the ledge back to the near end.
- `QuadChamber`: a hole in the floor drops a body into a chamber under it,
  the quad on a plinth; a pad throws it back up through the hole (or a
  teleporter sends it); now and then a button down there opens the ways on
  above.
- `CampingVault`: the key room. Tiers stepping up the far end, thrown up to
  tier by tier by pads or climbed by stairs, the key on the top one;
  taking it opens the closets on the floor.
- `CampingGate`: the end (or a gate). A door (a key's) into a court, the way
  out on a tier up a pad or two stairs, a gallery whose campers wake as the
  player comes in."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing, ring_path }
import from .e1m1_parts { deck, bars }
import from .e2m2 { spiral_landing, foot_clear }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { keep_box, hint, wake_later, pad_to, flying_stair }
import from .q3tiers { key_taken, closets }

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

"""A foe for q3dm6's stretches."""
def q3dm6_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM6_LIGHT, Q3DM6_HEAVY, strong);
}

"""The start: a long hall under the grounds (q3dm6's lower halls), columns
down its open side, a gallery along one wall over the aisle under it,
climbed by a stair beside it or thrown up to by a jump pad; ways on from
the floor and the gallery."""
node LowerHall(Prefab) {
    has gallery: int = 7,
        tall: int = 15,
        side_low: bool = True,
        by_pad: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lower hall";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + dice.between(8, 9);
        self.side_low = dice.chance(0.5);
        self.by_pad = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        gy0 = 1 if self.side_low else self.wide - 5;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=float(gy0) + 2.0, floor=self.gallery),
            Port(face=3 if self.side_low else 1, along=float(self.long // 2 + 4), floor=self.gallery),
            Port(face=1 if self.side_low else 3, along=float(self.long - 6), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        gy0 = 1 if self.side_low else self.wide - 5;
        edge_y = gy0 + 3 if self.side_low else gy0;
        # The gallery, a deck four cells deep over the aisle along its wall.
        deck(build, 6, gy0, self.long - 1, gy0 + 4, g);
        foot: list[float] = [];
        if self.by_pad {
            # A pad on the floor three cells out from the gallery's edge.
            pad_y = float(edge_y) + (4.0 if self.side_low else -3.0);
            land_y = float(gy0) + 2.0;
            pad_to(build, hall, 12.0, pad_y, 0, 12.0, land_y, g, 10, edge_y, 15, edge_y + 1);
            foot = [12.0, pad_y];
        } else {
            # A stair beside the gallery, its steps floating over the floor.
            sy = gy0 + 4 if self.side_low else gy0 - 3;
            flying_stair(build, 6, sy, 0, 0, g, 3);
            keep_box(build, hall, 3 + g, edge_y, 6 + g, edge_y + 1, g);
            foot = [7.0, float(sy) + 1.5];
        }
        # A stretch of the gallery's edge unrailed, to drop from.
        keep_box(build, hall, self.long - 8, edge_y, self.long - 5, edge_y + 1, g);
        # Columns down the open side.
        far_y = self.wide - 3 if self.side_low else 2;
        for x in range(8, self.long - 10, 5) {
            build.solid(x, far_y, 0, x + 1, far_y + 1, self.tall);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        hint(build, 1.0, float(middle - 2), 0.0, 4.0, float(middle + 3), 6.0, "The Camping Grounds lie above", "The gallery climbs to them", 2.0);
        # The gallery's guards wake as the player sets foot on the way up.
        climb = build.touch(foot[0] - 1.5, foot[1] - 1.5, 0.0, foot[0] + 1.5, foot[1] + 1.5, 6.0);
        above = wake_later(build, climb, 0.4);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.5 - float(index) * 6.0, float(gy0) + 2.0, g, q3dm6_foe(dice, self.danger, index == 0), 180.0, waits=above);
        }
        build.foe(float(self.long) - 5.5, float(middle) + 0.5, 0, q3dm6_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(middle) - 2.5, 0, Q3_HEALTH, "q3");
        build.supply(8.5, float(gy0) + 2.0, g, Q3_ARMOR, "q3");
    }
}

"""A tall room, the railgun on a ledge high along its far wall (q3dm6's
rail ledges), thrown up to by a jump pad or climbed by two flights; the
undercroft under the ledge; ways on from the ledge and the floor."""
node RailLedge(Prefab) {
    has ledge: int = 12,
        tall: int = 22,
        by_pad: bool = True,
        tele: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rail ledge";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(22, 26);
        self.wide = dice.between(15, 17);
        self.ledge = dice.between(12, 14);
        self.tall = self.ledge + 9;
        self.by_pad = dice.chance(0.55);
        self.tele = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2) - 2.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        h = self.ledge;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(room, h);
        lx = self.long - 5;
        # The ledge, two lifts deep, the undercroft open under it.
        deck(build, lx, 1, self.long - 1, self.wide - 1, h);
        build.solid(lx, 1, h - 2, self.long - 1, self.wide - 1, h - 1);
        start_box: list[float] = [];
        if self.by_pad {
            pad_to(build, room, float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 2.0, float(middle) + 0.5, h, lx, middle - 2, lx + 1, middle + 3);
            start_box = [float(lx) - 5.0, float(middle - 2), float(lx - 1), float(middle + 3)];
        } else {
            # Up the -y wall to a landing, then along the ledge's face.
            mid = h // 2;
            stair(build, lx - 6 - mid, 1, 0, 0, mid, 3);
            deck(build, lx - 6, 1, lx, 4, mid);
            flying_stair(build, lx - 3, 4, mid, 1, h - mid, 3);
            keep_box(build, room, lx - 3, 3 + h - mid, lx, 4 + h - mid, h);
            keep_box(build, room, lx, 4 + h - mid - 1, lx + 1, 4 + h - mid + 1, h);
            start_box = [float(lx - 6 - mid), 1.0, float(lx - 4 - mid), 4.0];
        }
        # A stretch of the ledge's edge unrailed, to drop back from.
        keep_box(build, room, lx, self.wide - 5, lx + 1, self.wide - 2, h);
        # A teleporter on the ledge sends a body back to the near end.
        if self.tele {
            build.teleporter(float(self.long) - 2.5, 2.5, h, 3.5, float(self.wide) - 3.5, 0, 0.0);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # The ledge's campers wake as the player starts up.
        up = build.touch(start_box[0], start_box[1], 0.0, start_box[2], start_box[3], 6.0);
        campers = wake_later(build, up, 0.3);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, float(middle) + 3.5 - float(index) * 7.0, h, q3dm6_foe(dice, self.danger, index == 0), 180.0, waits=campers);
        }
        build.foe(float(lx) + 2.5, float(middle) + 0.5, 0, q3dm6_foe(dice, self.danger), 180.0);
        build.foe(5.5, float(middle) + 3.5, 0, q3dm6_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, h, "weapon_railgun", "q3");
        build.supply(float(lx) + 2.0, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A chamber under the grounds' floor (q3dm6's quad area): a hole in the
floor drops a body into it, the quad on a plinth down there; a jump pad
under the hole throws a body back up through it (or a teleporter sends it
up); now and then a button down there opens the ways on above."""
node QuadChamber(Prefab) {
    has deep: int = 10,
        tall: int = 14,
        by_pad: bool = True,
        barred: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Quad chamber";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(22, 24);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(10, 11);
        self.tall = dice.between(13, 15);
        self.by_pad = dice.chance(0.55);
        self.barred = dice.chance(0.5);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        cross = float(self.long // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=cross + 4.0, floor=0), Port(face=3, along=cross + 4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        bottom = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        below = build.room(4, 3, bottom, self.long - 4, self.wide - 3, bottom + 7, variant=dice.below(3));
        build.level(below, bottom);
        # The hole in the floor over the chamber, open on its near side to
        # drop through.
        build.room(cx - 3, cy - 3, bottom + 7, cx + 3, cy + 3, 0);
        keep_box(build, hall, cx - 4, cy - 2, cx - 3, cy + 2, 0);
        # The quad on its plinth in the chamber's far corner.
        build.solid(self.long - 8, self.wide - 7, bottom, self.long - 5, self.wide - 4, bottom + 1);
        build.supply(float(self.long) - 6.5, float(self.wide) - 5.5, bottom + 1, "item_quad", "q3");
        # The way back up: a pad under the hole throwing a body up over its
        # far edge, or a teleporter in a corner up to the floor above.
        if self.by_pad {
            pad_to(build, hall, float(cx) + 0.5, float(cy), bottom, float(cx) + 0.5, float(cy) + 5.0, 0, cx - 2, cy + 3, cx + 3, cy + 4);
        } else {
            build.teleporter(5.5, 4.5, bottom, 3.5, 3.5, 0, 0.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What waits below wakes as a body lands; the button down there (when
        # barred) opens the ways on above.
        landed = build.touch(float(cx - 3), float(cy - 3), float(bottom), float(cx + 3), float(cy + 3), float(bottom + 4));
        lurkers = wake_later(build, landed, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(5.5 + float(index) * 4.0, float(self.wide) - 4.5, bottom, q3dm6_foe(dice, self.danger, index == 0), 0.0, waits=lurkers);
        }
        if self.barred and self.taken {
            lever = build.push(float(self.long - 4), float(cy) + 0.5, float(bottom) + 2.0, 2);
            bars(build, lever, self.taken, self.long, self.wide);
            hint(build, 1.0, float(cy - 2), 0.0, 4.0, float(cy + 3), 6.0, "The ways on are shut", "The switch is down below", 2.0);
        }
        build.foe(float(self.long) - 4.5, 3.5, 0, q3dm6_foe(dice, self.danger), 180.0);
        build.foe(4.5, float(self.wide) - 3.5, 0, q3dm6_foe(dice, self.danger), 0.0);
        build.supply(3.5, 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) - 5.5, float(cy) + 0.5, bottom, Q3_HEALTH, "q3");
    }
}

"""The key room: tiers stepping up the far end (q3dm6's tiers joined by
jump pads), the key on the top tier, thrown up to tier by tier or climbed
by stairs; taking it opens the closets on the floor."""
node CampingVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        by_pad: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.by_pad = dice.chance(0.55);
        self.tall = 21;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        t1 = 6;
        t2 = 11;
        x1 = self.long - 10;
        x2 = self.long - 5;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(room, t1);
        build.level(room, t2);
        build.doorway(room, self.enter);
        # The lower tier over the floor's far end, the upper over its far
        # wall; the floor runs on under both.
        deck(build, x1, 1, self.long - 1, side, t1);
        deck(build, x2, 1, self.long - 1, side, t2);
        if self.by_pad {
            pad_to(build, room, float(x1) - 3.0, float(cy) + 0.5, 0, float(x1) + 1.5, float(cy) + 0.5, t1, x1, cy - 2, x1 + 1, cy + 3);
            pad_to(build, room, float(x2) - 3.0, float(cy) - 2.5, t1, float(x2) + 1.5, float(cy) - 2.5, t2, x2, cy - 5, x2 + 1, cy);
            start = [float(x1) - 5.0, float(cy - 2), float(x1 - 1), float(cy + 3)];
        } else {
            stair(build, x1 - t1, 1, 0, 0, t1, 3);
            keep_box(build, room, x1, 1, x1 + 1, 4, t1);
            flying_stair(build, x1, side - 3, t1, 0, t2 - t1, 3);
            keep_box(build, room, x2, side - 3, x2 + 1, side, t2);
            start = [float(x1 - t1), 1.0, float(x1 - t1 + 2), 4.0];
        }
        # The upper tier's edge open to drop from.
        keep_box(build, room, x2, cy + 1, x2 + 1, cy + 4, t2);
        # The key on the top tier; taking it opens the closets below.
        taken = key_taken(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, t2);
        closets(build, taken, side, 0, [3, 8], [q3dm6_foe(dice, self.danger, True), q3dm6_foe(dice, self.danger)]);
        up = build.touch(start[0], start[1], 0.0, start[2], start[3], 6.0);
        tiers = wake_later(build, up, 0.3);
        build.foe(float(x1) + 2.5, float(cy) + 3.5, t1, q3dm6_foe(dice, self.danger), 180.0, waits=tiers);
        build.foe(float(self.long) - 3.0, 3.0, t2, q3dm6_foe(dice, self.danger), 180.0, waits=tiers);
        hint(build, 1.0, float(cy - 2), 0.0, 4.0, float(cy + 3), 6.0, "The key is on the top tier", "Climb from tier to tier", 2.0);
        build.foe(float(x1) - 6.5, float(cy) + 3.5, 0, q3dm6_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(x1) + 2.5, float(side) - 4.5, t1, Q3_ARMOR, "q3");
    }
}

"""The end (or a gate): a door (a key's, as a gate) into a court, the way
out on a camping tier at its far end thrown up to by a jump pad or up two
stairs, a gallery along one wall whose campers wake as the player comes
in."""
node CampingGate(Prefab) {
    has key: str = "",
        by_pad: bool = True,
        gallery_low: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Camping gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM6;
        self.district = level_district(Q3DM6);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.by_pad = dice.chance(0.5);
        self.gallery_low = dice.chance(0.5);
        self.tall = 20;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 7;
        t = 8;
        tx = self.long - 7;
        court = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(court, t);
        build.level(court, 12);
        # The tier at the far end, the floor running on under it.
        deck(build, tx, 1, self.long - 1, self.wide - 1, t);
        if self.by_pad {
            pad_to(build, court, float(tx) - 3.0, float(middle) + 0.5, 0, float(tx) + 2.0, float(middle) + 0.5, t, tx, middle - 2, tx + 1, middle + 3);
        } else {
            stair(build, tx - t, 1, 0, 0, t, 3);
            stair(build, tx - t, self.wide - 4, 0, 0, t, 3);
            keep_box(build, court, tx, 1, tx + 1, 4, t);
            keep_box(build, court, tx, self.wide - 4, tx + 1, self.wide - 1, t);
        }
        build.way_out(float(self.long) - 3.5, float(middle), t);
        # The gallery high along one wall, its campers woken as the player
        # comes through the door.
        gy = 1 if self.gallery_low else self.wide - 4;
        deck(build, wall + 4, gy, tx if self.by_pad else tx - t - 1, gy + 3, 12);
        through = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        campers = wake_later(build, through, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall + 6 + index * 5) + 0.5, float(gy) + 1.5, 12, q3dm6_foe(dice, self.danger, index == 0), 0.0, waits=campers);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(tx) + 2.5, 3.5 + float(index) * 5.0, t, q3dm6_foe(dice, self.danger), 180.0);
        }
        build.foe(float(wall) - 3.5, 3.0, 0, q3dm6_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(wall) + 3.5, float(self.wide) - 3.5 if self.gallery_low else 3.5, 0, Q3_ARMOR, "q3");
    }
}

"""q3dm6's stretches: [name, role]."""
glob Q3DM6_STRETCHES: list[list[str]] = [
         ["lower", "start"],
         ["climb", "flow"],
         ["ledge", "flow"],
         ["quad", "flow"],
         ["bridge", "flow"],
         ["yard", "hub"],
         ["bridge", "hub"],
         ["vault", "keyroom"],
         ["gate", "end"],
         ["gate", "gate"]
     ];

"""One of q3dm6's stretches by its name."""
def make_q3dm6(name: str, key: str) -> Prefab {
    if name == "lower" {
        return LowerHall();
    }
    if name == "climb" {
        return CampingTower();
    }
    if name == "ledge" {
        return RailLedge();
    }
    if name == "quad" {
        return QuadChamber();
    }
    if name == "yard" {
        return CampingYard();
    }
    if name == "bridge" {
        return StoneBridge();
    }
    if name == "vault" {
        return CampingVault(key=key if key else "key_silver");
    }
    return CampingGate(key=key);
}
