"""Prefabs drawn from Quake III's q3dm10, The Nameless Place: a gothic warren
of three tiers a storey apart (the original's floors at -128, 0 and 128),
halls under galleries on arcades, corridors stacked over corridors with
grates looking down, a well of deep water, stairs winding over themselves.
No pads, no teleporters: stairs and drops only. Quake III's arenas hold no
foes of their own; q3dm10's are scrags and zombies, shamblers as a run
goes deeper.

- `NamelessHall`: the start. A hall between two galleries on arcades (and
  an apse across its far end), a stair up to each or a bridge between
  them, a sunken nave in its floor; the galleries' guards wake as the
  player comes up.
- `NamelessUndercroft`: two corridors, one over the other: the upper's
  floor is the lower's roof, a stair at each end between them (or a lift
  at one), a grate in the upper floor to look down through and drop by;
  ways on from both.
- `NamelessWell`: a hall round a deep well of water, a bridge over it or
  half-bridges to an island in it, a balcony along one wall up a stair.
- `NamelessNave`: the hub. Three tiers: a sunken nave with stairs down at
  both ends, the floor round it, balconies on arcades along both walls up
  their own stairs, a bridge across between them over the nave.
- `NamelessSpiral`: a stair winding up round a tower's walls, over itself
  where it laps, round a newel or over a well of water.
- `NamelessReliquary`: the key room. The key on a balcony across the far
  wall up a stair, or down in a crypt under a bridge; taking it opens
  closets along the side wall.
- `NamelessPortal`: the end (or a gate). The way out on a balcony up twin
  stairs, or on a dais between two galleries; their guards wake at the
  door."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, pillars, gate_into, lift, spiral, ring_landing, ring_path }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, key_taken, closets, wake_on }

glob Q3DM10: str = "q3:q3dm10",
     Q3DM10_LIGHT: list[str] = ["monster_wizard", "monster_zombie"],
     Q3DM10_HEAVY: list[str] = ["monster_shambler"];

"""A foe for the Nameless Place: a shambler now and then where `strong`
(more often as a run goes deeper), else scrags and zombies."""
def nameless_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    if strong and dice.chance(0.2 + 0.5 * danger) {
        return "monster_shambler";
    }
    return arena_foe(dice, danger * 0.5, Q3DM10_LIGHT, Q3DM10_HEAVY);
}

"""The start: a hall between two galleries on arcades, a sunken nave."""
node NamelessHall(Prefab) {
    has apse: bool = False,
        sunk: bool = True,
        bridged: bool = False,
        east: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless hall";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(24, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(18, 20);
        self.apse = dice.chance(0.5);
        self.sunk = dice.chance(0.6);
        self.bridged = dice.chance(0.5);
        self.east = dice.chance(0.5);
        self.low = -5 if self.sunk else -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=8 if self.apse else 0),
            Port(face=0, along=3.0, floor=8),
            Port(face=1, along=float(self.long - 6), floor=8),
            Port(face=3, along=float(self.long - 6), floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gal = 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, gal);
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        bx = 6 if self.east else self.long - 10;
        for x in range(4, self.long - 5, 4) {
            if not self.bridged or x < bx - 1 or x > bx + 3 {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        if self.apse {
            deck(build, self.long - 5, 5, self.long - 1, self.wide - 5, gal);
            for y in range(7, self.wide - 6, 4) {
                build.solid(self.long - 5, y, 0, self.long - 4, y + 1, gal - 1);
            }
        }
        # The stair up to the south gallery, from the west or from the east.
        up_x = 11;
        if self.east {
            stair(build, self.long - 6, 5, 0, 2, gal, 3);
            keep_box(build, hall, self.long - 14, 4, self.long - 11, 5, gal);
            up_x = self.long - 13;
        } else {
            stair(build, 4, 5, 0, 0, gal, 3);
            keep_box(build, hall, 10, 4, 13, 5, gal);
        }
        # Up to the north gallery: a bridge across, or a stair of its own.
        if self.bridged {
            deck(build, bx, 5, bx + 3, self.wide - 5, gal);
            keep_box(build, hall, bx, 4, bx + 3, 5, gal);
            keep_box(build, hall, bx, self.wide - 5, bx + 3, self.wide - 4, gal);
        } elif self.east {
            stair(build, 4, self.wide - 8, 0, 0, gal, 3);
            keep_box(build, hall, 10, self.wide - 5, 13, self.wide - 4, gal);
        } else {
            stair(build, self.long - 6, self.wide - 8, 0, 2, gal, 3);
            keep_box(build, hall, self.long - 14, self.wide - 5, self.long - 11, self.wide - 4, gal);
        }
        # The sunken nave, steps down at both ends.
        floor_z = 0;
        if self.sunk {
            floor_z = -4;
            build.level(hall, -4);
            build.widen(hall, 8, 8, -4, self.long - 8, self.wide - 8, 0);
            stair(build, 11, 8, -4, 2, 4, self.wide - 16);
            stair(build, self.long - 12, 8, -4, 0, 4, self.wide - 16);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        # At the stair's top the galleries' guards wake.
        guards = wake_on(build, float(up_x - 2), 1.0, float(up_x + 2), 5.0, float(gal));
        build.foe(float(self.long) - 4.5, 2.5, gal, nameless_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, gal, nameless_foe(dice, self.danger, True), 180.0, waits=guards);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 2) + 0.5, float(middle) + 0.5, floor_z, "monster_zombie", 180.0);
        }
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, 0, nameless_foe(dice, self.danger, True), 180.0);
        build.foe(3.5, 2.5, 0, "monster_zombie", 0.0, patrol=[[3.5, 2.5], [float(self.long) - 4.5, 2.5]]);
        build.supply(float(self.long) - 3.0, float(self.wide) - 2.5, gal, Q3_ARMOR, "q3");
        build.supply(float(self.long // 2) + 0.5, float(middle) - 1.5, floor_z, Q3_HEALTH, "q3");
        build.supply(3.5, 3.5, 0, "item_rockets");
    }
}

"""Two corridors, one over the other, stairs (or a lift) between them, a
grate in the upper floor."""
node NamelessUndercroft(Prefab) {
    has lifted: bool = False,
        grates: int = 1,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless undercroft";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(32, 36);
        self.wide = dice.between(15, 17);
        self.tall = dice.between(9, 10);
        self.lifted = dice.chance(0.4);
        self.grates = dice.between(1, 2);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=middle, floor=-9),
            Port(face=1, along=float(self.long // 2), floor=-9),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -9;
        mid = self.wide // 2;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The upper corridor's floor, the lower's roof.
        build.solid(1, 1, -1, self.long - 1, self.wide - 1, 0);
        # The east stair, down along the south wall.
        build.widen(hall, self.long - 12, 1, -1, self.long - 1, 4, 0);
        stair(build, self.long - 5, 1, lo, 2, 9, 3);
        # The west way between them: a stair down along the north wall, or a
        # lift.
        if self.lifted {
            build.widen(hall, 4, self.wide - 4, -1, 7, self.wide - 1, 0);
            lift(build, 4, self.wide - 4, 7, self.wide - 1, lo, 0);
            keep_box(build, hall, 7, self.wide - 4, 8, self.wide - 1, 0);
            keep_box(build, hall, 3, self.wide - 4, 4, self.wide - 1, 0);
        } else {
            build.widen(hall, 5, self.wide - 4, -1, 13, self.wide - 1, 0);
            stair(build, 12, self.wide - 4, lo, 2, 9, 3);
        }
        # Grates in the upper floor between the stairs, to look down through
        # (and drop by, off the first's west lip).
        holes: list[list[int]] = [];
        for index in range(self.grates) {
            hx = 14 + index * 5;
            if hx + 3 <= self.long - 13 {
                build.widen(hall, hx, mid - 1, -1, hx + 3, mid + 2, 0);
                holes.append([hx - 1, mid - 2, hx + 4, mid + 3]);
            }
        }
        if holes {
            keep_box(build, hall, holes[0][0], mid - 1, holes[0][0] + 1, mid + 2, 0);
        }
        clear = [[self.long - 13, 0, self.long, 5], [3, self.wide - 5, 14, self.wide], [self.long - 5, mid - 3, self.long, mid + 3], [self.long // 2 - 3, self.wide - 5, self.long // 2 + 3, self.wide]] + holes;
        pillars(build, 3, 3, self.long - 3, self.wide - 3, lo, -1, 5, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down the east stair, what waits below in the west wakes; dropped
        # through a grate, what waits under it.
        below = wake_on(build, float(self.long - 5), 1.0, float(self.long - 1), 4.0, float(lo));
        for index in range(dice.between(1, 2)) {
            build.foe(6.5 + float(index) * 3.0, float(mid) - 2.5, lo, nameless_foe(dice, self.danger), 0.0, waits=below);
        }
        if holes {
            under = wake_on(build, float(holes[0][0] + 1), float(mid - 1), float(holes[0][0] + 4), float(mid + 2), float(lo));
            build.foe(float(holes[0][0]) + 6.5, float(mid) + 0.5, lo, nameless_foe(dice, self.danger, True), 180.0, waits=under);
        }
        build.foe(float(self.long) - 7.5, float(mid) + 0.5, lo, "monster_zombie", 180.0, patrol=[[float(self.long) - 7.5, float(mid) + 0.5], [15.5, float(mid) + 2.5]]);
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, nameless_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 4.5, float(mid) + 2.5, 0, "monster_wizard", 180.0);
        build.supply(float(self.long) - 3.0, float(mid) + 0.5, lo, Q3_HEALTH, "q3");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 3.0, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 9.5, float(mid) - 2.5, lo, "item_spikes");
    }
}

"""A hall round a deep well of water, a bridge (or half-bridges to an
island), a balcony up a stair."""
node NamelessWell(Prefab) {
    has deep: int = 6,
        island: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless well";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(6, 8);
        self.island = dice.chance(0.5);
        self.tall = dice.between(17, 18);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=8.0, floor=8), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        build.pool(6, 5, -self.deep, self.long - 6, self.wide - 5, 0, 2, False, True, True);
        # The balcony along the north wall over its arcade, up a stair along
        # that wall from the east.
        deck(build, 1, self.wide - 5, self.long - 9, self.wide - 1, 8);
        for x in range(4, self.long - 10, 4) {
            if x < cx - 1 or x > cx + 3 {
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, 7);
            }
        }
        stair(build, self.long - 2, self.wide - 4, 0, 2, 8, 3);
        keep_box(build, hall, self.long - 10, self.wide - 4, self.long - 9, self.wide - 1, 8);
        # Across the water: a bridge, or half-bridges to an island.
        if self.island {
            build.solid(cx - 2, cy - 2, -self.deep, cx + 2, cy + 2, 0);
            deck(build, 6, cy - 1, cx - 2, cy + 2, 0);
            deck(build, cx + 2, cy - 1, self.long - 6, cy + 2, 0);
            keep_box(build, hall, 5, cy - 1, 6, cy + 2, 0);
            keep_box(build, hall, self.long - 6, cy - 1, self.long - 5, cy + 2, 0);
        } else {
            deck(build, cx, 5, cx + 3, self.wide - 5, 0);
            keep_box(build, hall, cx, 4, cx + 3, 5, 0);
            keep_box(build, hall, cx, self.wide - 5, cx + 3, self.wide - 4, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Out over the water, the balcony's scrags wake.
        over = wake_on(build, float(cx - 1), float(cy - 2), float(cx + 3), float(cy + 2), 0.0);
        build.foe(5.5, float(self.wide) - 2.5, 8, "monster_wizard", 0.0, waits=over);
        build.foe(float(self.long) - 12.5, float(self.wide) - 2.5, 8, nameless_foe(dice, self.danger, True), 180.0, waits=over);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 6.5 + float(index) * 4.0, 0, nameless_foe(dice, self.danger), 180.0);
        }
        build.foe(4.5, 2.5, 0, "monster_zombie", 0.0, patrol=[[4.5, 2.5], [float(self.long) - 4.5, 2.5]]);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 0, Q3_ARMOR, "q3");
        build.supply(3.0, float(self.wide) - 2.5, 8, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, 0, "item_rockets");
    }
}

"""The hub: a sunken nave, the floor round it, balconies along both walls,
a bridge across between them."""
node NamelessNave(Prefab) {
    has spanned: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless nave";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(19, 21);
        self.spanned = dice.chance(0.5);
        self.low = -7;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=1, along=float(self.long - 6), floor=8),
            Port(face=3, along=float(self.long - 6), floor=8),
            Port(face=0, along=3.0, floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        gal = 8;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, gal);
        build.level(nave, -6);
        # The sunken nave, stairs down at both ends.
        build.widen(nave, 8, 8, -6, self.long - 8, self.wide - 8, 0);
        stair(build, 13, cy - 1, -6, 2, 6, 3);
        stair(build, self.long - 14, cy - 1, -6, 0, 6, 3);
        # The balconies on their arcades, each up its own stair.
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        for x in range(4, self.long - 3, 4) {
            if not self.spanned or x < cx - 2 or x > cx + 2 {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        stair(build, 2, 5, 0, 0, gal, 3);
        keep_box(build, nave, 8, 4, 11, 5, gal);
        stair(build, self.long - 3, self.wide - 8, 0, 2, gal, 3);
        keep_box(build, nave, self.long - 11, self.wide - 5, self.long - 8, self.wide - 4, gal);
        if self.spanned {
            deck(build, cx - 1, 5, cx + 2, self.wide - 5, gal);
            keep_box(build, nave, cx - 1, 4, cx + 2, 5, gal);
            keep_box(build, nave, cx - 1, self.wide - 5, cx + 2, self.wide - 4, gal);
        }
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        # Down into the nave, the balconies' scrags wake; up the north stair,
        # its guard.
        down = wake_on(build, 8.0, float(cy - 1), 11.0, float(cy + 2), -3.0);
        build.foe(float(cx) + 4.5, 2.5, gal, "monster_wizard", 180.0, waits=down);
        build.foe(float(cx) - 4.5, float(self.wide) - 2.5, gal, nameless_foe(dice, self.danger), 0.0, waits=down);
        up = wake_on(build, float(self.long - 11), float(self.wide - 5), float(self.long - 8), float(self.wide - 1), float(gal));
        build.foe(4.5, float(self.wide) - 2.5, gal, nameless_foe(dice, self.danger, True), 0.0, waits=up);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 3 + index * 3) + 0.5, float(cy) + (2.5 if index % 2 == 0 else -2.5), -6, nameless_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, -6, nameless_foe(dice, self.danger, True), 180.0);
        build.foe(3.5, 2.5, 0, "monster_zombie", 0.0, patrol=[[3.5, 2.5], [float(self.long) - 4.5, 2.5]]);
        build.supply(float(cx) + 0.5, float(cy) - 2.5, -6, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, 2.5, gal, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) - 2.5, float(cy) + 2.5, -6, "item_rockets");
    }
}

"""A stair winding up round a tower's walls, round a newel or over a well."""
node NamelessSpiral(Prefab) {
    has steps: int = 20,
        newel: bool = True,
        tall: int = 29;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless spiral";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(12, 13);
        self.wide = self.long;
        self.newel = dice.chance(0.5);
        fits: list[int] = [];
        for steps in range(18, 40) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 4);
            if landing and (landing[0] == 0.0 or landing[0] == 1.0) {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -1 if self.newel else -5;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 4);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=int(top[0]), along=top[1], floor=self.steps), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tower, self.steps);
        build.level(tower, self.steps // 2);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 4);
        # Round a newel, or over a well of water in the tower's foot.
        if self.newel {
            build.solid(4, 4, 0, self.long - 4, self.wide - 4, self.tall);
        } else {
            build.pool(4, 4, -4, self.long - 4, self.wide - 4, 0, 2);
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        # Halfway up, what waits at the top wakes.
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        cell = path[(self.steps // 2) % len(path)];
        top = wake_on(build, float(cell[0]), float(cell[1]), float(cell[2]), float(cell[3]), float(self.steps // 2 + 1));
        last = path[(self.steps + 2) % len(path)];
        build.foe(float(last[0] + last[2]) * 0.5, float(last[1] + last[3]) * 0.5, self.steps, nameless_foe(dice, self.danger, True), 180.0, waits=top);
        build.foe(2.5, float(self.wide) - 2.5, 0, "monster_zombie", 0.0);
        build.foe(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "monster_wizard", 180.0);
        build.supply(float(last[0] + last[2]) * 0.5, float(last[1] + last[3]) * 0.5, self.steps, Q3_HEALTH, "q3");
        build.supply(2.5, float(self.wide) - 4.5, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, float(self.wide) - 4.5, 0, "item_spikes");
    }
}

"""The key room: the key on a balcony across the far wall, or down in a
crypt under a bridge; taking it opens the closets."""
node NamelessReliquary(Prefab) {
    has key: str = "key_silver",
        crypt: bool = False,
        hall_wide: int = 16,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless reliquary (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.crypt = dice.chance(0.5);
        self.tall = dice.between(17, 18);
        self.low = -8 if self.crypt else -1;
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        taken: Cue | None = None;
        if self.crypt {
            # The crypt: seven lifts down, a stair along its south side, a
            # bridge across it, the key at its far end.
            build.level(hall, -7);
            build.widen(hall, 6, 4, -7, self.long - 2, side - 3, 0);
            stair(build, 12, 4, -7, 2, 7, 3);
            deck(build, self.long - 7, 4, self.long - 4, side - 3, 0);
            keep_box(build, hall, self.long - 7, 3, self.long - 4, 4, 0);
            keep_box(build, hall, self.long - 7, side - 3, self.long - 4, side - 2, 0);
            taken = key_taken(build, self.key, float(self.long) - 4.5, float(cy) + 1.5, -7);
            build.foe(float(self.long) - 9.5, float(cy) + 1.5, -7, nameless_foe(dice, self.danger), 180.0);
            build.foe(float(self.long) - 5.5, 1.5 + float(side - 3), 0, "monster_wizard", 180.0);
            build.supply(14.5, float(cy) + 1.5, -7, Q3_HEALTH, "q3");
        } else {
            # A balcony across the far wall over its arcade, up a stair along
            # the south wall; the key on it.
            gal = 8;
            build.level(hall, gal);
            deck(build, self.long - 6, 1, self.long - 1, side, gal);
            for y in range(5, side - 1, 4) {
                build.solid(self.long - 6, y, 0, self.long - 5, y + 1, gal - 1);
            }
            stair(build, self.long - 14, 1, 0, 0, gal, 3);
            keep_box(build, hall, self.long - 6, 1, self.long - 5, 4, gal);
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, gal);
            build.foe(float(self.long) - 3.0, float(side) - 2.5, gal, nameless_foe(dice, self.danger), 180.0);
            build.supply(float(self.long) - 3.0, 2.5, gal, Q3_HEALTH, "q3");
        }
        if taken is not None {
            closets(build, taken, side, 0, [2, 7], [nameless_foe(dice, self.danger, True), nameless_foe(dice, self.danger)]);
            late = build.delay(2.0);
            taken +>:Fires:+> late;
            wake = build.waiting();
            late +>:Fires:+> wake;
            build.foe(3.5, 2.5, 0, "monster_wizard", 0.0, waits=wake);
        }
        build.foe(float(self.long) - 9.5, float(cy) + 3.5, 0, nameless_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): the way out on a balcony up twin stairs, or on a
dais between two galleries."""
node NamelessPortal(Prefab) {
    has key: str = "",
        upper: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless portal" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM10;
        self.district = level_district(Q3DM10);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.upper = dice.chance(0.5);
        self.tall = dice.between(18, 19);
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
        wall = 8;
        gal = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, gal);
        inside = wake_on(build, float(wall + 1), float(middle - 2), float(wall + 3), float(middle + 2), 0.0);
        if self.upper {
            # A balcony across the far wall, twin stairs up the side walls,
            # the way out on the balcony.
            deck(build, self.long - 6, 1, self.long - 1, self.wide - 1, gal);
            for y in range(5, self.wide - 4, 4) {
                build.solid(self.long - 6, y, 0, self.long - 5, y + 1, gal - 1);
            }
            stair(build, self.long - 14, 1, 0, 0, gal, 3);
            stair(build, self.long - 14, self.wide - 4, 0, 0, gal, 3);
            keep_box(build, room, self.long - 6, 1, self.long - 5, 4, gal);
            keep_box(build, room, self.long - 6, self.wide - 4, self.long - 5, self.wide - 1, gal);
            build.way_out(float(self.long) - 3.0, float(middle), gal);
            build.foe(float(self.long) - 3.0, 2.5, gal, nameless_foe(dice, self.danger, True), 180.0, waits=inside);
            build.foe(float(self.long) - 3.0, float(self.wide) - 2.5, gal, "monster_wizard", 180.0, waits=inside);
        } else {
            # Two galleries along the side walls, each up a stair from the far
            # end; the way out on a dais between them.
            deck(build, wall + 1, 1, self.long - 1, 5, gal);
            deck(build, wall + 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
            stair(build, self.long - 2, 5, 0, 2, gal, 3);
            stair(build, self.long - 2, self.wide - 8, 0, 2, gal, 3);
            keep_box(build, room, self.long - 10, 4, self.long - 8, 5, gal);
            keep_box(build, room, self.long - 10, self.wide - 5, self.long - 8, self.wide - 4, gal);
            build.solid(12, middle - 3, 0, self.long - 9, middle + 3, 2);
            stair(build, 10, middle - 2, 0, 0, 2, 4);
            build.way_out(float(12 + self.long - 9) * 0.5, float(middle), 2);
            build.foe(float(wall) + 4.5, 2.5, gal, nameless_foe(dice, self.danger, True), 0.0, waits=inside);
            build.foe(float(wall) + 4.5, float(self.wide) - 2.5, gal, "monster_wizard", 0.0, waits=inside);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, nameless_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 8.5, float(middle) + 4.5, 0, "monster_zombie", 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm10's stretches: [name, role]."""
glob Q3DM10_STRETCHES: list[list[str]] = [
         ["hall", "start"],
         ["undercroft", "flow"],
         ["well", "flow"],
         ["spiral", "flow"],
         ["nave", "hub"],
         ["reliquary", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm10's stretches by its name."""
def make_q3dm10(name: str, key: str) -> Prefab {
    if name == "hall" {
        return NamelessHall();
    }
    if name == "undercroft" {
        return NamelessUndercroft();
    }
    if name == "well" {
        return NamelessWell();
    }
    if name == "spiral" {
        return NamelessSpiral();
    }
    if name == "nave" {
        return NamelessNave();
    }
    if name == "reliquary" {
        return NamelessReliquary(key=key if key else "key_silver");
    }
    return NamelessPortal(key=key);
}
