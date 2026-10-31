"""Prefabs drawn from Quake III's q3dm8, Brimstone Abbey: an abbey of great
height, its naves and aisles flooded, galleries and a tower's deck far over
its floors thrown up to by jump pads, a crypt sunk deep under it, its
halls shut by great doors sliding apart in pairs. Quake III's arenas hold
no foes of their own; q3dm8's are zombie, wizard, ogre. Raised in q3dm8's
own palette.

- `AbbeyGate`: the start. A vestibule behind great sliding doors, a hall
  with a flooded channel down its middle under galleries round three
  walls, thrown up to by jump pads or climbed by a long stair.
- `AbbeyNave`: a raised nave between flooded aisles, clerestory walks high
  over the aisles thrown up to from the nave by jump pads (or climbed from
  the aisles' ends), great doors at the far end before the chancel.
- `AbbeyCrossing`: the hub. The crossing under the tower: galleries half
  way up two walls thrown up to by jump pads from the floor (or climbed),
  jump pads on the galleries up to the tower's deck round all four walls
  far over the floor; ways on from the floor and the deck.
- `AbbeyCrypt`: a ledge over a crypt sunk deep under the abbey, a long
  stair (or a lift) down, a flooded pool in its floor, a jump pad back up
  to the ledge, a walk high along a wall over it all.
- `AbbeyBelfry`: the key room. A bell tower, the key at the top of a stair
  winding up its walls over itself (or of two jump pads, ledge to ledge);
  the well open to drop down; taking the key opens the closets below.
- `AbbeyChoir`: the end (or a gate). Great doors into the choir, the way
  out on the presbytery raised at its end, climbed by stairs or thrown up
  to by a jump pad, galleries high over the aisles whose guards wake."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, hint, wake_later, pad_to, flying_stair, sliding_pair }

glob Q3DM8: str = "q3:q3dm8",
     Q3DM8_LIGHT: list[str] = ["monster_zombie", "monster_wizard"],
     Q3DM8_HEAVY: list[str] = ["monster_ogre"];

"""A foe for q3dm8's stretches."""
glob Q3DM8_FOES: FoeMix = FoeMix(light=Q3DM8_LIGHT, strong=Q3DM8_HEAVY, heavy_light=Q3DM8_HEAVY, scale=0.5);

"""The start: a vestibule behind great sliding doors, a hall with a flooded
channel under galleries round three walls."""
node AbbeyGate(Prefab) {
    has access: int = 0,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey gate";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(28, 30);
        self.wide = dice.between(19, 21);
        self.access = dice.below(3);
        self.tall = 26;
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=3.0, floor=12),
            Port(face=1, along=float(self.long // 2), floor=12),
            Port(face=3, along=10.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = 12;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The vestibule's wall and the great doors in it.
        build.solid(6, 1, 0, 7, self.wide - 1, 20);
        build.widen(hall, 6, middle - 3, 0, 7, middle + 3, g);
        sliding_pair(build, 6, middle - 3, middle + 3, 0, g);
        # The flooded channel down the hall's middle.
        build.pool(12, middle - 2, -2, self.long - 8, middle + 2, 0, 2, False, True, True);
        # The galleries round the side and far walls.
        slab(build, 8, 1, self.long - 1, 5, g);
        slab(build, 8, self.wide - 5, self.long - 1, self.wide - 1, g);
        slab(build, self.long - 5, 5, self.long - 1, self.wide - 5, g);
        for x in range(10, self.long - 5, 4) {
            build.solid(x, 4, 0, x + 1, 5, g - 1);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, g - 1);
        }
        if self.access == 2 {
            stair(build, 9, 5, 0, 0, g, 3);
            keep_box(build, hall, 19, 4, 22, 5, g);
        } else {
            pad_to(build, hall, 10.0, 8.0, 0, 10.0, 3.0, g, 8, 4, 12, 5);
            if self.access == 1 {
                pad_to(build, hall, float(self.long - 10), float(self.wide) - 8.0, 0, float(self.long - 10), float(self.wide) - 3.0, g, self.long - 12, self.wide - 5, self.long - 8, self.wide - 4);
            }
        }
        keep_box(build, hall, self.long - 5, 8, self.long - 4, self.wide - 8, g);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        hint(build, 7.0, float(middle - 3), 0.0, 9.0, float(middle + 3), 6.0, "Brimstone Abbey", "The pads throw you up to its galleries", 2.5);
        midway = build.touch(float(self.long // 2), 5.0, 0.0, float(self.long // 2 + 2), float(self.wide - 5), 6.0);
        above = wake_later(build, midway, 0.5);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, g, Q3DM8_FOES.pick(dice, self.danger, True), 180.0, waits=above);
        build.foe(float(self.long) - 8.5, 3.0, g, Q3DM8_FOES.pick(dice, self.danger), 180.0, waits=above);
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, Q3DM8_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 3.0, 3.0, g, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 4.5, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""A raised nave between flooded aisles, clerestory walks high over the
aisles thrown up to from the nave, great doors at the far end."""
node AbbeyNave(Prefab) {
    has nave: int = 2,
        pads: int = 1,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey nave";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.nave = 2;
        self.pads = dice.below(3);
        self.tall = 26;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.nave);
        self.leaves = [
            Port(face=0, along=middle, floor=self.nave),
            Port(face=0, along=3.0, floor=12),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        n = self.nave;
        c = 12;
        dx = self.long - 7;
        abbey = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(abbey, n);
        build.level(abbey, c);
        # The raised nave, the flooded aisles either side, steps up out of
        # them at their ends.
        build.solid(1, middle - 3, 0, self.long - 1, middle + 3, n);
        build.pool(4, 1, -4, dx - 2, middle - 3, 0, 2);
        build.pool(4, middle + 3, -4, dx - 2, self.wide - 1, 0, 2, False, False);
        stair(build, dx - 6, self.wide - 3, -4, 0, 4, 2);
        for x in range(5, dx - 2, 4) {
            build.solid(x, middle - 3, n, x + 1, middle - 2, c - 1);
            build.solid(x, middle + 2, n, x + 1, middle + 3, c - 1);
        }
        stair(build, 2, middle - 3 - n, 0, 1, n, 2);
        stair(build, 2, middle + 2 + n, 0, 3, n, 2);
        # The clerestory walks over the aisles, a bridge between them over
        # the nave's far end.
        slab(build, 4, 1, self.long - 1, 5, c);
        slab(build, 4, self.wide - 5, self.long - 1, self.wide - 1, c);
        slab(build, dx - 3, 5, dx, self.wide - 5, c);
        # Jump pads on the nave between its columns up to the walks.
        pad_to(build, abbey, 11.0, float(middle) - 2.0, n, 11.0, 3.0, c, 9, 4, 13, 5);
        keep_box(build, abbey, 9, middle - 3, 13, middle - 2, n);
        if self.pads > 0 {
            pad_to(build, abbey, 15.0, float(middle) + 2.0, n, 15.0, float(self.wide) - 3.0, c, 13, self.wide - 5, 17, self.wide - 4);
            keep_box(build, abbey, 13, middle + 2, 17, middle + 3, n);
        }
        if self.pads < 2 {
            pad_to(build, abbey, 19.0, float(middle) - 2.0, n, 19.0, 3.0, c, 17, 4, 21, 5);
            keep_box(build, abbey, 17, middle - 3, 21, middle - 2, n);
        }
        keep_box(build, abbey, 14, 4, 18, 5, c);
        # The great doors across the nave before the chancel.
        build.solid(dx, 1, 0, dx + 1, self.wide - 1, c - 1);
        build.widen(abbey, dx, middle - 3, n, dx + 1, middle + 3, n + 9);
        sliding_pair(build, dx, middle - 3, middle + 3, n, n + 9);
        build.widen(abbey, dx, 1, 0, dx + 1, 4, 8);
        build.widen(abbey, dx, self.wide - 4, 0, dx + 1, self.wide - 1, 8);
        build.doorway(abbey, self.enter);
        for port in self.taken {
            build.doorway(abbey, port);
        }
        up = build.touch(9.0, float(middle - 3), float(n), 11.0, float(middle + 3), float(n + 6));
        walks = wake_later(build, up, 1.0);
        build.foe(float(dx) - 4.5, 3.0, c, Q3DM8_FOES.pick(dice, self.danger), 180.0, waits=walks);
        build.foe(float(dx) - 8.5, float(self.wide) - 3.0, c, Q3DM8_FOES.pick(dice, self.danger), 180.0, waits=walks);
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 4) + 0.5, float(middle) + 0.5, n, Q3DM8_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, n, Q3DM8_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(dx) - 1.5, 3.0, c, "item_rockets");
    }
}

"""The hub: the crossing under the tower, galleries half way up two walls,
jump pads up to them and on up to the tower's deck round all four walls."""
node AbbeyCrossing(Prefab) {
    has both: bool = True,
        climbed: bool = False,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey crossing";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(28, 30);
        self.wide = dice.between(28, 30);
        self.both = dice.chance(0.5);
        self.climbed = dice.chance(0.4);
        self.tall = 56;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=18),
            Port(face=0, along=3.0, floor=18),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = 9;
        d = 18;
        cx = long // 2;
        cross = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(cross, g);
        build.level(cross, d);
        # The tower's deck round all four walls, far over the floor.
        slab(build, 1, 1, long - 1, 5, d);
        slab(build, 1, wide - 5, long - 1, wide - 1, d);
        slab(build, 1, 5, 5, wide - 5, d);
        slab(build, long - 5, 5, long - 1, wide - 5, d);
        keep_box(build, cross, 8, 4, 12, 5, d);
        keep_box(build, cross, long - 12, wide - 5, long - 8, wide - 4, d);
        # The galleries half way up the -y wall (and the +y), in front of the
        # deck and partly under it.
        slab(build, 7, 4, long - 7, 9, g);
        keep_box(build, cross, cx - 6, 8, cx - 2, 9, g);
        pad_to(build, cross, float(cx + 3), 12.0, 0, float(cx + 3), 6.5, g, cx + 1, 8, cx + 5, 9);
        pad_to(build, cross, float(cx - 3), 7.0, g, float(cx - 3), 2.5, d, cx - 5, 4, cx - 1, 5);
        if self.both {
            slab(build, 7, wide - 9, long - 7, wide - 4, g);
            pad_to(build, cross, float(cx - 3), float(wide - 12), 0, float(cx - 3), float(wide) - 6.5, g, cx - 5, wide - 9, cx - 1, wide - 8);
            pad_to(build, cross, float(cx + 3), float(wide - 7), g, float(cx + 3), float(wide) - 2.5, d, cx + 1, wide - 5, cx + 5, wide - 4);
            keep_box(build, cross, cx + 2, wide - 9, cx + 6, wide - 8, g);
        }
        if self.climbed {
            # A stair up the -x side of the floor to the -y gallery's end.
            flying_stair(build, 7, 9 + g - 1, 0, 3, g, 3);
        }
        build.doorway(cross, self.enter);
        for port in self.taken {
            build.doorway(cross, port);
        }
        hint(build, 2.0, 6.0, 0.0, 4.0, float(wide - 6), 6.0, "The crossing under the tower", "Its pads throw you up to the deck", 2.5);
        up = build.touch(float(cx - 5), 4.0, float(g), float(cx), 9.0, float(g + 6));
        deck = wake_later(build, up, 0.5);
        build.foe(float(long) - 3.0, 3.0, d, Q3DM8_FOES.pick(dice, self.danger, True), 180.0, waits=deck);
        build.foe(3.0, float(wide) - 3.0, d, Q3DM8_FOES.pick(dice, self.danger), 0.0, waits=deck);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(wide // 2) + 0.5, 0, Q3DM8_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(long) - 9.5, 6.5, g, Q3DM8_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(cx) + 0.5, float(wide // 2) + 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) + 0.5, 2.5, d, "item_armor_body", "q3");
        build.supply(9.5, 6.5, g, "item_rockets");
        build.supply(float(long) - 3.0, float(wide // 2) + 0.5, 0, "item_rockets");
    }
}

"""A ledge over a crypt sunk deep under the abbey, a long stair (or a lift)
down, a flooded pool in its floor, a jump pad back up to the ledge, a walk
high along a wall over it all."""
node AbbeyCrypt(Prefab) {
    has deep: int = 12,
        down: int = 0,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey crypt";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(26, 28);
        self.wide = dice.between(19, 21);
        self.deep = dice.between(12, 14);
        self.down = dice.below(2);
        self.tall = 21;
        self.low = -self.deep - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-self.deep),
            Port(face=1, along=4.0, floor=0),
            Port(face=0, along=float(self.wide) - 3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        crypt = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(crypt, 0);
        build.solid(1, 1, low, 8, self.wide - 1, 0);
        # Down along the -y wall, or by a lift.
        if self.down == 0 {
            stair(build, 7 + self.deep, 1, low, 2, self.deep, 3);
            keep_box(build, crypt, 7, 1, 8, 4, 0);
        } else {
            lift(build, 8, 1, 11, 4, low, 0);
            keep_box(build, crypt, 7, 1, 8, 4, 0);
            keep_box(build, crypt, 8, 1, 12, 5, low);
        }
        # The flooded pool in the crypt's floor, steps out both sides.
        build.pool(12, middle - 2, low - 2, self.long - 4, middle + 2, low, 2, False, True, True);
        # The jump pad by the ledge's foot back up to it, between the pool and
        # the walk.
        py = float(middle + 2 + self.wide - 5) * 0.5;
        pad_to(build, crypt, 11.0, py, low, 4.0, py, 0, 7, int(py) - 2, 8, int(py) + 2);
        # The walk high along the +y wall from the ledge to the far wall.
        slab(build, 8, self.wide - 5, self.long - 1, self.wide - 1, 0);
        keep_box(build, crypt, 14, self.wide - 5, 18, self.wide - 4, 0);
        build.doorway(crypt, self.enter);
        for port in self.taken {
            build.doorway(crypt, port);
        }
        hint(build, 4.0, 1.0, 0.0, 6.0, float(self.wide - 1), 6.0, "The crypt under the abbey", "A pad by the ledge throws you back up", 3.0);
        foot = build.touch(float(7 + self.deep), 1.0, float(low), float(10 + self.deep), 4.0, float(low + 6));
        dead = wake_later(build, foot, 0.5);
        for index in range(dice.between(3, 4)) {
            build.foe(float(13 + index * 3) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.5), low, "monster_zombie" if index > 0 else Q3DM8_FOES.pick(dice, self.danger, True), 180.0, waits=dead);
        }
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, 0, Q3DM8_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, low, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, "item_rockets");
    }
}

"""The key room: a bell tower, the key at the top of a stair winding up its
walls over itself (or of two jump pads, ledge to ledge); the well open to
drop down."""
node AbbeyBelfry(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        steps: int = 20,
        pads: bool = False,
        tall: int = 29;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey belfry (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(15, 16);
        self.hall_wide = dice.between(15, 16);
        self.wide = self.hall_wide + 4;
        self.pads = dice.chance(0.4);
        side = self.hall_wide - 1;
        fits: list[int] = [];
        for steps in range(18, 30) {
            landing = ring_landing(1, 1, self.long - 1, side, 3, steps, 5);
            if landing and landing[0] != 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 20;
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
        s = self.steps;
        tower = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(tower, s);
        build.doorway(tower, self.enter);
        top = ring_landing(1, 1, self.long - 1, side, 3, s, 5);
        if self.pads {
            # Two jump pads, from the floor to a ledge half way up, and from
            # the ledge to the top, the key on a ledge there.
            # Both ledges along the far wall, the higher at its -y end.
            half = s // 2;
            fx = self.long - 5;
            slab(build, fx, 5, self.long - 1, side, half);
            slab(build, fx, 1, self.long - 1, 5, s);
            pad_to(build, tower, float(fx) - 3.0, float(side) - 4.0, 0, float(fx) + 1.5, float(side) - 4.0, half, fx, side - 6, fx + 1, side - 2);
            pad_to(build, tower, float(fx) + 2.0, 8.0, half, float(fx) + 2.0, 3.0, s, fx, 4, fx + 4, 5);
            keep_box(build, tower, fx, 1, fx + 1, 4, s);
            keep_box(build, tower, fx, 6, fx + 1, side - 7, half);
            key_ambush(build, self.key, float(self.long) - 2.5, 2.5, s, side, 0, [4, fx - 4], [Q3DM8_FOES.pick(dice, self.danger, True), Q3DM8_FOES.pick(dice, self.danger)]);
        } else {
            landing = spiral(build, 1, 1, self.long - 1, side, 0, s, 3, 5);
            for cell in landing {
                keep_box(build, tower, cell[0], cell[1], cell[2], cell[3], s);
            }
            middle = landing[2];
            key_ambush(build, self.key, float(middle[0] + middle[2]) * 0.5, float(middle[1] + middle[3]) * 0.5, s, side, 0, [5, self.long - 9], [Q3DM8_FOES.pick(dice, self.danger, True), Q3DM8_FOES.pick(dice, self.danger)]);
        }
        hint(build, 2.0, 1.0, 0.0, 4.0, float(side), 6.0, "The bell tower", "The key waits at its top", 2.0);
        build.foe(float(self.long // 2) + 0.5, float(side // 2) + 0.5, 0, Q3DM8_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long // 2) - 2.5, float(side // 2) + 2.5, 0, Q3DM8_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): great doors into the choir, the way out on the
presbytery raised at its end, galleries high over the aisles."""
node AbbeyChoir(Prefab) {
    has key: str = "",
        climb: int = 0,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abbey choir" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM8;
        self.district = level_district(Q3DM8);
        self.long = dice.between(30, 32);
        self.wide = dice.between(19, 21);
        self.climb = dice.below(2);
        self.tall = 28;
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
        dw = wall + 4;
        p = 6;
        px = self.long - 9;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, p);
        build.level(room, 14);
        # The great doors into the choir, in a screen open over its top.
        build.solid(dw, 1, 0, dw + 1, self.wide - 1, 20);
        build.widen(room, dw, middle - 3, 0, dw + 1, middle + 3, 12);
        sliding_pair(build, dw, middle - 3, middle + 3, 0, 12);
        # The presbytery, raised at the far end, the way out on it.
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, p);
        if self.climb == 0 {
            stair(build, px - p, 1, 0, 0, p, 3);
            stair(build, px - p, self.wide - 4, 0, 0, p, 3);
        } else {
            pad_to(build, room, float(px) - 3.0, float(middle) + 0.5, 0, float(px) + 3.0, float(middle) + 0.5, p, px, middle - 2, px + 1, middle + 3);
        }
        build.way_out(float(self.long) - 4.0, float(middle), p);
        # The galleries high over the aisles.
        slab(build, dw + 1, 1, px, 4, 14);
        slab(build, dw + 1, self.wide - 4, px, self.wide - 1, 14);
        inside = build.touch(float(dw + 1), 4.0, 0.0, float(dw + 3), float(self.wide - 4), 6.0);
        galleries = wake_later(build, inside, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(dw + 4 + index * 4) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 14, Q3DM8_FOES.pick(dice, self.danger, index == 0), 0.0, waits=galleries);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(px) + 2.5, 5.5 + float(index) * 3.0, p, Q3DM8_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(wall) + 2.5, 3.0, 0, Q3DM8_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(dw) + 3.5, float(middle) + 3.5, 0, Q3_ARMOR, "q3");
    }
}

"""q3dm8's stretches: [name, role]."""
glob Q3DM8_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["nave", "flow"],
         ["crypt", "flow"],
         ["crossing", "hub"],
         ["belfry", "keyroom"],
         ["choir", "end"],
         ["choir", "gate"]
     ];

"""One of q3dm8's stretches by its name."""
def make_q3dm8(name: str, key: str) -> Prefab {
    if name == "gate" {
        return AbbeyGate();
    }
    if name == "nave" {
        return AbbeyNave();
    }
    if name == "crypt" {
        return AbbeyCrypt();
    }
    if name == "crossing" {
        return AbbeyCrossing();
    }
    if name == "belfry" {
        return AbbeyBelfry(key=key if key else "key_silver");
    }
    return AbbeyChoir(key=key);
}
