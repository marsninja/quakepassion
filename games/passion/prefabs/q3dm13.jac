"""Prefabs drawn from Quake III's q3dm13, Lost World: ruins under the sky
heaped one storey on another (floors from -192 up to 448, a third of them
over another), an aqueduct over a court, cisterns under broken floors, a
tower of floors with holes dropping through them to a well, a pad or two
and a teleporter from the depths up to the heights. Quake III's arenas hold
no foes of their own; q3dm13's are dogs and ogres, a shambler now and then.

- `LostCourt`: the start. A court under the sky crossed by an aqueduct on
  arches, up a broken stair; a walk along the north wall joins it now and
  then; a sunken pool among broken columns.
- `LostCistern`: three storeys: a cistern with water in its floor, the
  broken floor over it (a stair down at each end, or a lift at one), a
  bridge over that thrown up to by a pad, a teleporter from the bridge
  back down into the cistern, a hole looking down.
- `LostTower`: a broken tower of three floors, a stair up each in turn,
  holes dropping through them (the lowest into a well), a teleporter from
  the ground to the top.
- `LostTemple`: the hub. A temple court under the sky, galleries on
  arcades along both walls, a broken bridge between them, a sunken yard
  with a teleporter up to a gallery, a high walk over the galleries' east
  ends a pad throws a body up to.
- `LostShrine`: the key room. The key on a shelf over a ledge up a stair,
  thrown up to by a pad; or down in a cistern under the floor, a
  teleporter back up. Taking it opens the closets.
- `LostGate`: the end (or a gate). A ledge along one wall up a stair, a
  stair on it up to a platform across the far wall, or a pad, the way out
  on the platform."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, key_taken, pad_to, closets, wake_on }
import from .q3vista_parts { vista, daylight }

glob Q3DM13: str = "q3:q3dm13",
     Q3DM13_LIGHT: list[str] = ["monster_dog", "monster_ogre"],
     Q3DM13_HEAVY: list[str] = ["monster_shambler"];

"""A foe for the Lost World: a shambler now and then where `strong` (more
often as a run goes deeper), else dogs and ogres."""
def lost_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    if strong and dice.chance(0.2 + 0.5 * danger) {
        return "monster_shambler";
    }
    return arena_foe(dice, danger * 0.5, Q3DM13_LIGHT, Q3DM13_HEAVY);
}

"""The start: a court crossed by an aqueduct on arches, a sunken pool."""
node LostCourt(Prefab) {
    has aqueduct: int = 10,
        walk: bool = False,
        sunk: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost court";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(38, 42);
        self.aqueduct = dice.between(10, 11);
        self.walk = dice.chance(0.5);
        self.sunk = dice.chance(0.7);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        ax = self.aqueduct;
        self.enter = vista(2, middle, 0);
        self.leaves = [
            vista(0, middle, 0),
            Port(face=1, along=float(ax + 2), floor=8),
            Port(face=3, along=float(ax + 2), floor=8),
            Port(face=1, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        ax = self.aqueduct;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [0, 8]);
        build.level(court, 8);
        # The aqueduct across the court on its arches, the broken stair up.
        deck(build, ax, 1, ax + 4, self.wide - 1, 8);
        for y in range(4, self.wide - 3, 4) {
            build.solid(ax, y, 0, ax + 1, y + 1, 7);
            build.solid(ax + 3, y, 0, ax + 4, y + 1, 7);
        }
        stair(build, ax - 8, 1, 0, 0, 8, 3);
        keep_box(build, court, ax, 1, ax + 1, 4, 8);
        # A walk along the north wall to the aqueduct, a lip to drop from.
        if self.walk {
            deck(build, 1, self.wide - 5, ax, self.wide - 1, 8);
            for x in range(3, ax - 1, 4) {
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, 7);
            }
            keep_box(build, court, 4, self.wide - 5, 7, self.wide - 4, 8);
        }
        # The sunken pool east of the aqueduct, broken columns round it.
        px0 = ax + 5;
        px1 = self.long - 4;
        if self.sunk {
            build.pool(px0, 5, -4, px1, self.wide - 5, 0, 2, False, True, True);
        }
        for corner in [[px0 - 1, 4], [px1, 4], [px0 - 1, self.wide - 5], [px1, self.wide - 5]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 1, corner[1] + 1, dice.between(3, 10));
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # At the stair's top the aqueduct's guards wake.
        up = wake_on(build, float(ax - 2), 1.0, float(ax + 1), 4.0, 8.0);
        build.foe(float(ax) + 2.0, float(self.wide) - 3.5, 8, lost_foe(dice, self.danger), 270.0, waits=up);
        build.foe(float(ax) + 2.0, float(mid) + 0.5, 8, lost_foe(dice, self.danger, True), 270.0, waits=up);
        build.foe(5.5, float(mid) + 3.5, 0, "monster_dog", 0.0, patrol=[[5.5, float(mid) + 3.5], [float(self.long) - 3.5, float(mid) + 3.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(px0) + 1.5 + float(index) * 3.0, 2.5, 0, lost_foe(dice, self.danger), 180.0);
        }
        build.supply(float(ax) + 2.0, 2.5, 8, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""Three storeys: a cistern, the broken floor over it, a bridge over that."""
node LostCistern(Prefab) {
    has lifted: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost cistern";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(28, 30);
        self.wide = dice.between(15, 17);
        self.tall = dice.between(38, 42);
        self.lifted = dice.chance(0.4);
        self.low = -12;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=-9), Port(face=3, along=float(self.long // 2 - 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -9;
        mid = self.wide // 2;
        cx = self.long // 2;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [lo, 0, 8]);
        build.level(hall, 0);
        build.level(hall, 8);
        # The broken floor over the cistern.
        build.solid(1, 1, -1, self.long - 1, self.wide - 1, 0);
        # Down at the east end, a stair along the south wall.
        build.widen(hall, self.long - 12, 1, -1, self.long - 1, 4, 0);
        stair(build, self.long - 5, 1, lo, 2, 9, 3);
        # At the west end, a stair along the north wall, or a lift.
        if self.lifted {
            build.widen(hall, 3, self.wide - 5, -1, 6, self.wide - 2, 0);
            lift(build, 3, self.wide - 5, 6, self.wide - 2, lo, 0);
            keep_box(build, hall, 6, self.wide - 5, 7, self.wide - 2, 0);
            keep_box(build, hall, 2, self.wide - 5, 3, self.wide - 2, 0);
        } else {
            build.widen(hall, 5, self.wide - 4, -1, 13, self.wide - 1, 0);
            stair(build, 12, self.wide - 4, lo, 2, 9, 3);
        }
        # Water down the cistern's middle; a hole in the floor over it.
        build.pool(8, mid - 1, lo - 2, self.long - 8, mid + 2, lo, 2);
        build.widen(hall, cx + 3, mid - 1, -1, cx + 6, mid + 2, 0);
        keep_box(build, hall, cx + 2, mid - 1, cx + 3, mid + 2, 0);
        # The bridge over the floor, a pad up to it, a teleporter on it back
        # down into the cistern; its west end dropped from.
        deck(build, 6, mid - 1, self.long - 6, mid + 2, 8);
        pad_to(build, float(cx - 3), float(mid - 4), 0, float(cx - 3), float(mid) + 0.5, 8);
        keep_box(build, hall, cx - 4, mid - 1, cx - 1, mid, 8);
        keep_box(build, hall, 6, mid - 1, 7, mid + 2, 8);
        build.teleporter(float(self.long) - 8.0, float(mid) + 0.5, 8, 3.5, 3.5, lo, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down the east stair, what waits in the cistern wakes.
        below = wake_on(build, float(self.long - 5), 1.0, float(self.long - 1), 4.0, float(lo));
        build.foe(5.5, 3.5, lo, lost_foe(dice, self.danger), 0.0, waits=below);
        build.foe(float(cx) + 0.5, float(mid) + 3.5, lo, lost_foe(dice, self.danger, True), 180.0, waits=below);
        build.foe(14.5, float(mid) + 3.5, lo, "monster_dog", 180.0, patrol=[[14.5, float(mid) + 3.5], [float(self.long) - 6.5, float(mid) + 3.5]]);
        build.foe(float(cx) + 0.5, float(mid) + 4.5, 0, lost_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 10.5, float(mid) + 0.5, 8, lost_foe(dice, self.danger), 180.0);
        build.supply(float(cx) - 3.0, float(mid) + 0.5, 8, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, float(mid) + 2.5, lo, Q3_HEALTH, "q3");
    }
}

"""A broken tower of three floors, a stair up each, holes dropping through
them, a teleporter from the ground to the top."""
node LostTower(Prefab) {
    has well: bool = True,
        lifted: bool = False,
        warp: bool = True,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost tower";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = 16;
        self.wide = 16;
        self.tall = dice.between(56, 60);
        self.well = dice.chance(0.7);
        self.lifted = dice.chance(0.4);
        self.warp = dice.chance(0.6);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=16), Port(face=3, along=float(self.long - 4), floor=8), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [16]);
        build.level(tower, 8);
        build.level(tower, 16);
        # The floors at eight and sixteen lifts.
        build.solid(1, 1, 7, self.long - 1, self.wide - 1, 8);
        build.solid(1, 1, 15, self.long - 1, self.wide - 1, 16);
        # Up to the first along the south wall.
        build.widen(tower, 3, 1, 7, 10, 4, 8);
        stair(build, 3, 1, 0, 0, 8, 3);
        # Up to the second along the north wall: a stair, or a lift.
        if self.lifted {
            build.widen(tower, self.long - 7, self.wide - 4, 15, self.long - 4, self.wide - 1, 16);
            lift(build, self.long - 7, self.wide - 4, self.long - 4, self.wide - 1, 8, 16);
            keep_box(build, tower, self.long - 8, self.wide - 4, self.long - 7, self.wide - 1, 8);
            keep_box(build, tower, self.long - 8, self.wide - 4, self.long - 7, self.wide - 1, 16);
        } else {
            build.widen(tower, self.long - 10, self.wide - 4, 15, self.long - 3, self.wide - 1, 16);
            stair(build, self.long - 4, self.wide - 4, 8, 2, 8, 3);
        }
        # Holes to drop through: from the top floor to the first, from the
        # first into the well (or onto the ground).
        build.widen(tower, 2, cy - 1, 15, 5, cy + 2, 16);
        keep_box(build, tower, 5, cy - 1, 6, cy + 2, 16);
        build.widen(tower, cx - 2, cy - 2, 7, cx + 2, cy + 2, 8);
        keep_box(build, tower, cx - 2, cy - 3, cx + 2, cy - 2, 8);
        if self.well {
            build.pool(cx - 2, cy - 2, -3, cx + 2, cy + 2, 0, 2);
        }
        if self.warp {
            build.teleporter(float(self.long) - 3.0, float(self.wide) - 3.0, 0, 3.0, float(self.wide) - 3.0, 16, 0.0);
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        first = wake_on(build, 9.0, 1.0, 12.0, 4.0, 8.0);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, 8, lost_foe(dice, self.danger), 180.0, waits=first);
        build.foe(3.5, float(self.wide) - 3.5, 8, lost_foe(dice, self.danger), 0.0, waits=first);
        build.foe(float(cx) + 0.5, 3.5, 16, lost_foe(dice, self.danger, True), 90.0);
        build.foe(3.5, float(cy) + 4.5, 0, "monster_dog", 0.0, patrol=[[3.5, float(cy) + 4.5], [float(self.long) - 4.5, float(cy) + 4.5]]);
        build.supply(float(self.long) - 3.0, 3.0, 16, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 8, Q3_ARMOR, "q3");
    }
}

"""The hub: a temple court, galleries along both walls, a broken bridge, a
sunken yard with a teleporter, a high walk."""
node LostTemple(Prefab) {
    has broken: bool = True,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost temple";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(40, 44);
        self.broken = dice.chance(0.6);
        self.low = -7;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = vista(2, cy, 0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=0, along=cy, floor=16),
            Port(face=1, along=float(self.long // 2 - 4), floor=8),
            Port(face=3, along=float(self.long // 2 - 6), floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        gal = 8;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [0, 8]);
        build.level(court, gal);
        build.level(court, 16);
        build.level(court, -6);
        # The galleries on their arcades.
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        for x in range(4, self.long - 6, 4) {
            if x < cx - 1 or x > cx + 3 {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        # The bridge between them, broken in its middle now and then (a gap
        # a body jumps).
        if self.broken {
            deck(build, cx, 5, cx + 3, cy, gal);
            deck(build, cx, cy + 1, cx + 3, self.wide - 5, gal);
            keep_box(build, court, cx, cy - 1, cx + 3, cy, gal);
            keep_box(build, court, cx, cy + 1, cx + 3, cy + 2, gal);
        } else {
            deck(build, cx, 5, cx + 3, self.wide - 5, gal);
        }
        keep_box(build, court, cx, 4, cx + 3, 5, gal);
        keep_box(build, court, cx, self.wide - 5, cx + 3, self.wide - 4, gal);
        # Up to the south gallery a stair, to the north a pad.
        stair(build, 2, 5, 0, 0, gal, 3);
        keep_box(build, court, 8, 4, 11, 5, gal);
        pad_to(build, float(self.long - 9), float(self.wide - 8), 0, float(self.long - 9), float(self.wide) - 3.0, gal);
        keep_box(build, court, self.long - 10, self.wide - 5, self.long - 8, self.wide - 4, gal);
        # The sunken yard, a stair down and a teleporter up to the north
        # gallery.
        build.widen(court, 6, 8, -6, 12, self.wide - 8, 0);
        stair(build, 11, 8, -6, 2, 6, 3);
        build.teleporter(8.0, float(self.wide) - 10.0, -6, 6.0, float(self.wide) - 3.0, gal, 0.0);
        # The high walk over the galleries' east ends, thrown up to by a pad
        # on the south gallery; a lip to drop from.
        deck(build, self.long - 5, 1, self.long - 1, self.wide - 1, 16);
        pad_to(build, float(self.long - 8), 3.0, gal, float(self.long) - 3.0, 3.0, 16);
        keep_box(build, court, self.long - 5, 2, self.long - 4, 5, 16);
        keep_box(build, court, self.long - 5, self.wide - 6, self.long - 4, self.wide - 3, 16);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # Down in the yard, the galleries' guards wake.
        yard = wake_on(build, 6.0, 8.0, 12.0, float(self.wide - 8), -6.0);
        build.foe(float(cx) + 1.5, 2.5, gal, lost_foe(dice, self.danger), 90.0, waits=yard);
        build.foe(float(cx) - 4.5, float(self.wide) - 2.5, gal, lost_foe(dice, self.danger), 270.0, waits=yard);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 16, lost_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 3 + index * 3) + 0.5, float(cy) + (3.5 if index % 2 == 0 else -3.5), 0, lost_foe(dice, self.danger), 180.0);
        }
        build.foe(9.0, float(cy) + 0.5, -6, "monster_dog", 0.0);
        build.foe(14.5, float(cy) + 4.5, 0, "monster_dog", 0.0, patrol=[[14.5, float(cy) + 4.5], [float(self.long) - 6.5, float(cy) + 4.5]]);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 16, Q3_ARMOR, "q3");
        build.supply(float(cx) + 1.5, float(cy) - 3.0, gal, Q3_HEALTH, "q3");
        build.supply(3.0, float(cy) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a shelf over a ledge, or down in a cistern;
taking it opens the closets."""
node LostShrine(Prefab) {
    has key: str = "key_silver",
        cistern: bool = False,
        hall_wide: int = 16,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.cistern = dice.chance(0.5);
        self.tall = 28;
        self.low = -9 if self.cistern else -1;
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
        taken: Cue | None = None;
        if self.cistern {
            # The cistern under the floor: a stair down along the north wall,
            # the key at its far end, a teleporter back up.
            room = build.room(1, 1, -8, self.long - 1, side, self.tall, variant=dice.below(3));
            build.level(room, 0);
            build.doorway(room, self.enter);
            build.solid(1, 1, -1, self.long - 1, side, 0);
            build.widen(room, 6, side - 3, -1, 13, side, 0);
            stair(build, 12, side - 3, -8, 2, 8, 3);
            build.widen(room, self.long - 8, 3, -1, self.long - 4, 6, 0);
            keep_box(build, room, self.long - 9, 3, self.long - 8, 6, 0);
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, -8);
            build.teleporter(float(self.long) - 4.0, 2.5, -8, 3.0, 3.0, 0, 0.0);
            build.foe(float(self.long) - 6.5, float(cy) + 2.5, -8, lost_foe(dice, self.danger), 180.0);
            build.supply(15.0, float(cy) + 0.5, -8, Q3_HEALTH, "q3");
            closets(build, taken, side, 0, [1, self.long - 6], [lost_foe(dice, self.danger, True), lost_foe(dice, self.danger)]);
        } else {
            # A ledge across the far wall up a stair along the south wall, a
            # shelf over its back thrown up to by a pad, the key on the shelf.
            room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
            build.level(room, 6);
            build.level(room, 12);
            build.doorway(room, self.enter);
            deck(build, self.long - 8, 1, self.long - 1, side, 6);
            for y in range(4, side - 1, 4) {
                build.solid(self.long - 8, y, 0, self.long - 7, y + 1, 5);
            }
            stair(build, self.long - 14, 1, 0, 0, 6, 3);
            keep_box(build, room, self.long - 8, 1, self.long - 7, 4, 6);
            deck(build, self.long - 4, cy - 2, self.long - 1, side, 12);
            pad_to(build, float(self.long - 7), float(cy) + 0.5, 6, float(self.long) - 2.5, float(cy) + 0.5, 12);
            keep_box(build, room, self.long - 4, cy - 1, self.long - 3, cy + 2, 12);
            keep_box(build, room, self.long - 4, side - 3, self.long - 3, side, 12);
            taken = key_taken(build, self.key, float(self.long) - 2.5, float(side) - 3.0, 12);
            build.foe(float(self.long) - 4.5, 3.5, 6, lost_foe(dice, self.danger), 180.0);
            build.supply(float(self.long) - 3.0, 2.5, 6, Q3_HEALTH, "q3");
            closets(build, taken, side, 0, [2, 8], [lost_foe(dice, self.danger, True), lost_foe(dice, self.danger)]);
        }
        if taken is not None {
            late = build.delay(1.5);
            taken +>:Fires:+> late;
            wake = build.waiting();
            late +>:Fires:+> wake;
            build.foe(3.5, 3.5, 0, "monster_dog", 0.0, waits=wake);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): a ledge up a stair, a stair on it up to a platform
across the far wall (or a pad), the way out on the platform."""
node LostGate(Prefab) {
    has key: str = "",
        padded: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lost gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM13;
        self.district = level_district(Q3DM13);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.padded = dice.chance(0.5);
        self.tall = dice.between(38, 42);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        wall = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        daylight(build, wall + 1, 1, self.long - 1, self.wide - 1, [0, 8]);
        build.level(room, 6);
        build.level(room, 12);
        # The platform across the far wall over its arcade, the way out on it.
        px = self.long - 6;
        deck(build, px, 1, self.long - 1, self.wide - 1, 12);
        for y in range(4, self.wide - 3, 4) {
            build.solid(px, y, 0, px + 1, y + 1, 11);
        }
        build.way_out(float(self.long) - 3.0, float(mid), 12);
        if self.padded {
            pad_to(build, float(px - 3), float(mid) + 0.5, 0, float(px) + 2.5, float(self.wide) - 3.5, 12);
            keep_box(build, room, px, mid - 2, px + 1, self.wide - 1, 12);
        } else {
            # A ledge along the south wall over its arcade up a stair, a stair
            # on it up to the platform.
            deck(build, wall + 1, 1, px, 5, 6);
            for x in range(wall + 4, px - 7, 4) {
                build.solid(x, 4, 0, x + 1, 5, 5);
            }
            stair(build, wall + 2, 5, 0, 0, 6, 3);
            keep_box(build, room, wall + 6, 4, wall + 9, 5, 6);
            stair(build, px - 6, 1, 6, 0, 6, 3);
            keep_box(build, room, px, 1, px + 1, 4, 12);
        }
        # Through the door, the platform's guards wake.
        guards = wake_on(build, float(wall + 1), float(mid - 2), float(wall + 3), float(mid + 2), 0.0);
        build.foe(float(self.long) - 3.0, 3.5, 12, lost_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.5, 12, lost_foe(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, lost_foe(dice, self.danger), 180.0);
        }
        build.foe(float(px) - 4.5, float(self.wide) - 3.5, 0, "monster_dog", 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm13's stretches: [name, role]."""
glob Q3DM13_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["cistern", "flow"],
         ["tower", "flow"],
         ["temple", "hub"],
         ["shrine", "keyroom"],
         ["gate", "end"],
         ["gate", "gate"]
     ];

"""One of q3dm13's stretches by its name."""
def make_q3dm13(name: str, key: str) -> Prefab {
    if name == "court" {
        return LostCourt();
    }
    if name == "cistern" {
        return LostCistern();
    }
    if name == "tower" {
        return LostTower();
    }
    if name == "temple" {
        return LostTemple();
    }
    if name == "shrine" {
        return LostShrine(key=key if key else "key_silver");
    }
    return LostGate(key=key);
}
