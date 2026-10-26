"""Prefabs drawn from Quake III's q3dm7, Temple of Retribution: a great
temple on many levels, its galleries and balconies over its halls, a court
round a deep pit thrown out of by a jump pad, a well wound down to its
lowest floor, a door that opens as a body comes near and a button high up
that opens a way below. Quake III's arenas hold no foes of their own;
q3dm7's are knight, wizard, hell_knight. Raised in q3dm7's own palette.

- `RetributionHall`: the start. A portico the run begins on, a hall below
  it under galleries along both walls climbed from the portico, a door at
  the far end that opens as a body comes near, a sanctum beyond under the
  galleries' bridge; ways on from the sanctum and the galleries.
- `RetributionBasin`: a sunken basin, a ledge high over the far end thrown
  up to by a jump pad (or ridden up to by a lift), a button on the ledge
  that draws a bridge over the basin; ways on from the ledge and the
  floor.
- `RetributionCourt`: the hub. A court round a deep pit, balconies high
  along both walls, stairs up to them, a jump pad and (or) a teleporter in
  the pit up to them, a bridge across between them; ways on from the
  floor and both balconies.
- `RetributionDepths`: a well, a stair winding down its walls over itself
  from the way in at the top to the floor, the middle open to drop down, a
  teleporter at the foot back up.
- `RetributionShrine`: the key room. The key on a shrine high along the
  far wall, thrown up to by a jump pad or climbed by stairs along two
  walls; a button by the key sinks a floor down from the shrine; taking
  the key opens the closets.
- `RetributionAltar`: the end (or a gate). A door that opens as a body
  comes near, the way out on an altar up a grand stair (or two stairs),
  galleries high on both walls whose guards wake as the player climbs."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift, spiral, ring_landing, ring_path }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, hint, wake_later, pad, pad_to, flying_stair }

glob Q3DM7: str = "q3:q3dm7",
     Q3DM7_LIGHT: list[str] = ["monster_knight", "monster_wizard"],
     Q3DM7_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for q3dm7's stretches."""
def q3dm7_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM7_LIGHT, Q3DM7_HEAVY, strong);
}

"""A door across the cell line x (to x + 1), from y0 to y1, `high` lifts
from lift `z`, that rises when a body comes near it from either side and
shuts again behind (q3dm7's door, its touch round it)."""
def near_door(build: Raising, x: int, y0: int, y1: int, z: int, high: int) -> Cue {
    near = build.touch(float(x - 3), float(y0), float(z), float(x + 4), float(y1), float(z + 6), False);
    fields = {"wait": "4"};
    build.rising_door(float(x), float(y0), float(z), float(x + 1), float(y1), float(z + high), fields);
    near +>:Fires:+> build.cue([fields], "door");
    return near;
}

"""The start: a portico, a hall below it under galleries along both walls,
a door at the far end that opens as a body comes near, a sanctum beyond."""
node RetributionHall(Prefab) {
    has both: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution hall";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.both = dice.chance(0.5);
        self.tall = 20;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=4);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=3.0, floor=10),
            Port(face=1, along=float(self.long // 2), floor=10),
            Port(face=3, along=12.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = 10;
        dw = self.long - 7;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 4);
        build.level(hall, g);
        # The portico, a stair down its middle to the hall.
        build.solid(1, 1, 0, 8, self.wide - 1, 4);
        stair(build, 11, middle - 2, 0, 2, 4, 4);
        keep_box(build, hall, 7, 1, 8, middle - 2, 4);
        keep_box(build, hall, 7, middle + 2, 8, self.wide - 1, 4);
        # The galleries along both walls, from the portico's stairs up to the
        # far wall, and their bridge across the sanctum's far end.
        slab(build, 9, 1, self.long - 1, 6, g);
        slab(build, 9, self.wide - 6, self.long - 1, self.wide - 1, g);
        slab(build, self.long - 4, 6, self.long - 1, self.wide - 6, g);
        stair(build, 3, 1, 4, 0, 6, 3);
        if self.both {
            stair(build, 3, self.wide - 4, 4, 0, 6, 3);
        }
        for x in range(12, dw - 1, 4) {
            build.solid(x, 5, 0, x + 1, 6, g - 1);
            build.solid(x, self.wide - 6, 0, x + 1, self.wide - 5, g - 1);
        }
        keep_box(build, hall, 14, 5, 18, 6, g);
        keep_box(build, hall, 14, self.wide - 6, 18, self.wide - 5, g);
        # The far wall and the door through it, opening as a body comes near;
        # the galleries run on through it over the sanctum.
        build.solid(dw, 1, 0, dw + 1, self.wide - 1, g - 1);
        build.solid(dw, 6, g - 1, dw + 1, self.wide - 6, self.tall);
        build.widen(hall, dw, middle - 2, 0, dw + 1, middle + 2, 8);
        near_door(build, dw, middle - 2, middle + 2, 0, 8);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 4, 0.0);
        build.supply(2.5, float(middle) - 1.5, 4, "ammo_shells", "q2");
        hint(build, 4.0, 1.0, 4.0, 6.0, float(self.wide - 1), 10.0, "The Temple of Retribution", "Its doors open as you come near", 2.5);
        midway = build.touch(float(self.long // 2), 6.0, 0.0, float(self.long // 2 + 2), float(self.wide - 6), 6.0);
        above = wake_later(build, midway, 0.5);
        build.foe(float(dw) - 3.5, 3.5, g, q3dm7_foe(dice, self.danger), 180.0, waits=above);
        build.foe(float(dw) - 3.5, float(self.wide) - 3.5, g, q3dm7_foe(dice, self.danger), 180.0, waits=above);
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, q3dm7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, q3dm7_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 3.5, g, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.5, float(middle) + 3.5, 0, Q3_HEALTH, "q3");
    }
}

"""A sunken basin, a ledge high over the far end thrown up to by a jump pad
(or a lift), a button on the ledge that draws a bridge over the basin."""
node RetributionBasin(Prefab) {
    has ledge: int = 9,
        lifted: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution basin";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.ledge = 9;
        self.lifted = dice.chance(0.4);
        self.tall = self.ledge + 10;
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.ledge),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=3.5, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        l = self.ledge;
        bx0 = 7;
        bx1 = self.long - 10;
        lx = self.long - 6;
        temple = build.room(1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(temple, 0);
        build.level(temple, l);
        build.solid(1, 1, -4, self.long - 1, self.wide - 1, 0);
        # The basin, stairs down its long sides.
        build.widen(temple, bx0, 4, -4, bx1, self.wide - 4, 0);
        stair(build, bx0 + 3, 7, -4, 3, 4, 3);
        stair(build, bx1 - 6, self.wide - 8, -4, 1, 4, 3);
        keep_box(build, temple, bx0 - 1, 4, bx0, self.wide - 4, 0);
        keep_box(build, temple, bx1, 4, bx1 + 1, self.wide - 4, 0);
        # The ledge high over the far end, the undercroft under it.
        slab(build, lx, 1, self.long - 1, self.wide - 1, l);
        if self.lifted {
            lift(build, lx - 3, 1, lx, 4, 0, l);
            keep_box(build, temple, lx, 1, lx + 1, 4, l);
            keep_box(build, temple, lx - 4, 1, lx, 5, 0);
        } else {
            pad_to(build, temple, float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 2.5, float(middle) + 0.5, l, lx, middle - 2, lx + 1, middle + 3);
        }
        keep_box(build, temple, lx, self.wide - 5, lx + 1, self.wide - 2, l);
        # The button on the ledge's back wall draws the bridge over the basin.
        press = build.push(float(self.long - 1), float(middle) + 3.5, float(l) + 1.2, 2);
        press +>:Fires:+> build.drawn(float(bx0), float(middle - 1), float(bx1), float(middle + 2), 0, 5);
        keep_box(build, temple, bx0 - 1, middle - 1, bx0, middle + 2, 0);
        keep_box(build, temple, bx1, middle - 1, bx1 + 1, middle + 2, 0);
        build.doorway(temple, self.enter);
        for port in self.taken {
            build.doorway(temple, port);
        }
        down = build.touch(float(bx0), 4.0, -4.0, float(bx1), float(self.wide - 4), 0.0);
        ledge = wake_later(build, down, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * float(self.wide - 6), l, q3dm7_foe(dice, self.danger, index == 0), 180.0, waits=ledge);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx0 + 3 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), -4, q3dm7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(lx) + 2.5, float(middle) + 0.5, 0, q3dm7_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(middle) - 2.5, l, Q3_HEALTH, "q3");
        build.supply(4.5, 3.0, 0, "item_spikes");
    }
}

"""The hub: a court round a deep pit, balconies high along both walls,
stairs up to them, a jump pad or a teleporter in the pit up to them."""
node RetributionCourt(Prefab) {
    has ups: int = 0,
        bridge: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution court";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(30, 32);
        self.wide = dice.between(28, 30);
        self.ups = dice.below(3);
        self.bridge = dice.chance(0.6);
        self.tall = 19;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=9),
            Port(face=3, along=float(self.long // 2), floor=9),
            Port(face=0, along=3.5, floor=9)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        b = 9;
        cx = long // 2;
        cy = wide // 2;
        court = build.room(1, 1, -8, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(court, 0);
        build.level(court, b);
        build.solid(1, 1, -8, long - 1, wide - 1, 0);
        # The deep pit in the court's middle, a stair down its -x side.
        build.widen(court, cx - 5, cy - 5, -8, cx + 5, cy + 5, 0);
        stair(build, cx + 2, cy - 4, -8, 2, 8, 3);
        keep_box(build, court, cx - 6, cy - 5, cx - 5, cy + 5, 0);
        keep_box(build, court, cx + 5, cy - 5, cx + 6, cy + 5, 0);
        # The balconies along both walls, columns under their edges.
        slab(build, 1, 1, long - 1, 6, b);
        slab(build, 1, wide - 6, long - 1, wide - 1, b);
        for x in range(4, long - 2, 5) {
            build.solid(x, 5, 0, x + 1, 6, b - 1);
            build.solid(x, wide - 6, 0, x + 1, wide - 5, b - 1);
        }
        # Up to them: a stair to each, a jump pad from the pit, a teleporter
        # at the pit's foot (by `ups`, two of the three at least).
        flying_stair(build, 6, 6, 0, 0, b, 3);
        if self.ups != 1 {
            flying_stair(build, long - 7, wide - 9, 0, 2, b, 3);
        }
        if self.ups != 2 {
            pad_to(build, court, float(cx - 3), float(cy + 2), -8, float(cx - 3), float(wide) - 3.5, b, cx - 5, wide - 6, cx - 1, wide - 5);
            keep_box(build, court, cx - 5, cy + 5, cx - 1, cy + 6, 0);
        }
        if self.ups != 0 {
            build.teleporter(float(cx + 3), float(cy + 3), -8, 4.5, 3.5, b, 0.0);
        }
        if self.bridge {
            slab(build, cx - 1, 6, cx + 2, wide - 6, b);
        }
        keep_box(build, court, 18, 5, 22, 6, b);
        keep_box(build, court, 8, wide - 6, 12, wide - 5, b);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        hint(build, 2.0, 7.0, 0.0, 4.0, float(wide - 7), 6.0, "The court of the temple", "The pit throws you up to the balconies", 2.5);
        down = build.touch(float(cx - 4), float(cy - 4), -8.0, float(cx + 4), float(cy + 4), -2.0);
        pit = wake_later(build, down, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 3) + 0.5, float(cy - 3 + index * 2) + 0.5, -8, q3dm7_foe(dice, self.danger, index == 0), 180.0, waits=pit);
        }
        build.foe(3.5, 7.5, 0, q3dm7_foe(dice, self.danger), 0.0, patrol=[[3.5, 7.5], [3.5, float(wide) - 8.5]]);
        build.foe(float(long) - 3.5, 3.5, b, q3dm7_foe(dice, self.danger, True), 180.0);
        build.foe(float(long) - 3.5, float(wide) - 3.5, b, q3dm7_foe(dice, self.danger), 180.0);
        build.supply(float(cx) - 3.5, float(cy) - 0.5, -8, "item_health_mega", "q3");
        build.supply(3.5, 3.5, b, Q3_ARMOR, "q3");
        build.supply(float(long) - 3.5, float(cy) + 3.5, 0, Q3_HEALTH, "q3");
    }
}

"""A well, a stair winding down its walls over itself from the way in at
the top to the floor, the middle open to drop down, a teleporter at the
foot back up."""
node RetributionDepths(Prefab) {
    has steps: int = 20,
        tall: int = 29;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution depths";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(14, 15);
        self.wide = dice.between(14, 15);
        fits: list[int] = [];
        for steps in range(16, 28) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] != 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        self.tall = self.steps + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=int(top[0]), along=top[1], floor=self.steps);
        self.leaves = [Port(face=2, along=float(self.wide // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        s = self.steps;
        well = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(well, s);
        landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, s, 3, 5);
        # The landing's inner edge open to drop from, down the well.
        for cell in landing {
            keep_box(build, well, cell[0], cell[1], cell[2], cell[3], s);
        }
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        cx = float(self.long) * 0.5;
        cy = float(self.wide) * 0.5;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, s, 5);
        lx = cx;
        ly = cy;
        if top[0] == 0.0 {
            lx = float(self.long) - 2.5;
            ly = top[1];
        } elif top[0] == 1.0 {
            lx = top[1];
            ly = float(self.wide) - 2.5;
        } elif top[0] == 3.0 {
            lx = top[1];
            ly = 2.5;
        }
        build.teleporter(cx, cy, 0, lx, ly, s, 0.0);
        foot = build.touch(4.0, 4.0, 0.0, float(self.long - 4), float(self.wide - 4), 6.0);
        below = wake_later(build, foot, 0.5);
        build.foe(2.5, cy, 0, q3dm7_foe(dice, self.danger, True), 0.0, waits=below);
        build.foe(cx + 2.0, cy + 2.0, 0, q3dm7_foe(dice, self.danger), 0.0, waits=below);
        on_stair = ring_path(1, 1, self.long - 1, self.wide - 1, 3)[s // 2];
        build.foe(float(on_stair[0]) + 0.5, float(on_stair[1] + on_stair[3]) * 0.5, s // 2 + 1, q3dm7_foe(dice, self.danger), 180.0);
        build.supply(cx - 2.0, cy - 2.0, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a shrine high along the far wall, thrown up to
by a jump pad or climbed by stairs along two walls; a button by the key
sinks a floor down from the shrine."""
node RetributionShrine(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        pad_up: bool = True,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(17, 19);
        self.wide = self.hall_wide + 4;
        self.pad_up = dice.chance(0.5);
        self.tall = 21;
        self.low = -13;
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
        h = 12;
        sx = self.long - 6;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, h);
        build.level(hall, 6);
        build.doorway(hall, self.enter);
        # The shrine along the far wall, the undercroft under it.
        slab(build, sx, 1, self.long - 1, side, h);
        if self.pad_up {
            pad_to(build, hall, float(sx) - 3.0, float(cy) + 0.5, 0, float(sx) + 3.0, float(cy) + 0.5, h, sx, cy - 2, sx + 1, cy + 3);
        } else {
            # Up the -y wall to a landing six lifts up, then along a ledge to
            # the far wall's corner and up again to the shrine.
            stair(build, 4, 1, 0, 0, 6, 3);
            slab(build, 10, 1, sx, 4, 6);
            flying_stair(build, sx - 3, 4, 6, 1, 6, 3);
            slab(build, sx - 3, 10, sx, 13, h);
        }
        # The shrine's edge open to drop from.
        keep_box(build, hall, sx, side - 5, sx + 1, side - 2, h);
        # The button by the key sinks a floor from the shrine to the floor.
        press = build.push(float(self.long - 1), float(cy) - 3.5, float(h) + 1.2, 2);
        build.widen(hall, self.long - 4, 2, h - 1, self.long - 1, 5, h);
        press +>:Fires:+> build.sinking(float(self.long - 4), 2.0, float(self.long - 1), 5.0, h, h);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, h, side, 0, [3, sx - 6], [q3dm7_foe(dice, self.danger, True), q3dm7_foe(dice, self.danger)]);
        hint(build, 2.0, 1.0, 0.0, 4.0, float(side), 6.0, "The shrine holds the key", "The button by it takes you down", 2.0);
        build.foe(float(self.long) - 3.0, float(side) - 3.0, h, q3dm7_foe(dice, self.danger), 180.0);
        build.foe(float(sx) - 4.5, float(cy) + 3.5, 0, q3dm7_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a door that opens as a body comes near, the way
out on an altar up a grand stair, galleries high on both walls."""
node RetributionAltar(Prefab) {
    has key: str = "",
        sides: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Retribution altar" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM7;
        self.district = level_district(Q3DM7);
        self.long = dice.between(30, 32);
        self.wide = dice.between(18, 20);
        self.sides = dice.chance(0.5);
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
        dw = wall + 6;
        d = 6;
        ax = self.long - 9;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, d);
        build.level(room, 12);
        # The inner wall and its door that opens as a body comes near.
        build.solid(dw, 1, 0, dw + 1, self.wide - 1, self.tall);
        build.widen(room, dw, middle - 2, 0, dw + 1, middle + 2, 8);
        near_door(build, dw, middle - 2, middle + 2, 0, 8);
        # The altar's dais, a grand stair (or two) up to it.
        build.solid(ax, 1, 0, self.long - 1, self.wide - 1, d);
        if self.sides {
            stair(build, ax - d, 1, 0, 0, d, 3);
            stair(build, ax - d, self.wide - 4, 0, 0, d, 3);
            keep_box(build, room, ax, 1, ax + 1, 4, d);
            keep_box(build, room, ax, self.wide - 4, ax + 1, self.wide - 1, d);
        } else {
            stair(build, ax - d, middle - 2, 0, 0, d, 4);
            keep_box(build, room, ax, middle - 2, ax + 1, middle + 2, d);
        }
        build.way_out(float(self.long) - 4.0, float(middle), d);
        # The galleries high on both walls over the floor, from the inner
        # wall to the dais, open toward the floor.
        slab(build, dw + 1, 1, ax, 4, 12);
        slab(build, dw + 1, self.wide - 4, ax, self.wide - 1, 12);
        climb = build.touch(float(ax - d), 1.0, 0.0, float(ax - d + 2), float(self.wide - 1), 8.0);
        galleries = wake_later(build, climb, 0.3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(dw + 3 + index * 4) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 12, q3dm7_foe(dice, self.danger, index == 0), 0.0, waits=galleries);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(ax) + 2.5, 3.5 + float(index) * 3.0, d, q3dm7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(wall) + 3.5, 3.0, 0, q3dm7_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(dw) + 2.5, float(middle) + 3.5, 0, Q3_ARMOR, "q3");
    }
}

"""q3dm7's stretches: [name, role]."""
glob Q3DM7_STRETCHES: list[list[str]] = [
         ["hall", "start"],
         ["basin", "flow"],
         ["depths", "flow"],
         ["court", "hub"],
         ["shrine", "keyroom"],
         ["altar", "end"],
         ["altar", "gate"]
     ];

"""One of q3dm7's stretches by its name."""
def make_q3dm7(name: str, key: str) -> Prefab {
    if name == "hall" {
        return RetributionHall();
    }
    if name == "basin" {
        return RetributionBasin();
    }
    if name == "depths" {
        return RetributionDepths();
    }
    if name == "court" {
        return RetributionCourt();
    }
    if name == "shrine" {
        return RetributionShrine(key=key if key else "key_silver");
    }
    return RetributionAltar(key=key);
}
