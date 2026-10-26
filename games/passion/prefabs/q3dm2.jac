"""Prefabs drawn from Quake III's q3dm2, House of Pain: a gothic house on
two floors, its upper halls and walks standing over the lower ones half a
storey down, a great door twelve lifts high at its gate, stairs and lifts
between. Quake III's arenas hold no foes of their own; q3dm2's are
knight, zombie, hell_knight. Raised in q3dm2's own palette.

- `PainGate`: the start. A vestibule behind the great sliding doors, a
  ledge beyond over a hall half a storey down, a stair down one wall or
  a lift, and a walk along the other wall over the hall (or none); ways on
  from the ledge, the walk and the hall's floor.
- `PainLifts`: a hall, a balcony across its far end over an undercroft,
  ridden up to by lifts at its corners, by a lift and a stair, or by a
  lift and a gallery back along a wall; ways on from the balcony and the
  floor under it.
- `PainPit`: the hub. A deep pit hall under walks along both sides and a
  bridge across, a stair down from the near floor, a ramp up the far side
  or a lift; the armor on the pit's floor; ways on from the walks and the
  pit.
- `PainHalls`: two halls one over the other, the upper's floor slotted to
  look down, stairs between at both ends (or a stair and a lift); ways on
  from both.
- `PainCells`: the key room. A block of cells sunk under a catwalk, the
  key on a platform across it reached over the catwalk (spikes fire across
  it), up a stair or by a jump pad; taking it opens the cells.
- `PainAltar`: the end (or a gate). A ledge over a sanctum, balconies down
  its walls, a stair, a drop or a lift down to the altar the way out
  stands on; touching the sanctum's floor brings a foe in behind and wakes
  the balconies."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, hint, wake_later, pad, flying_stair, sliding_pair }

glob Q3DM2: str = "q3:q3dm2",
     Q3DM2_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3DM2_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for q3dm2's stretches."""
def q3dm2_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM2_LIGHT, Q3DM2_HEAVY, strong);
}

"""The start: the great doors, a ledge over a hall half a storey down, a
stair or a lift down, a walk along a wall over the hall."""
node PainGate(Prefab) {
    has down: int = 0,
        walk: int = 0,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain gate";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.down = dice.below(3);
        # The walk runs along the wall the stair does not (0 none, 1 -y,
        # 2 +y).
        if self.down == 0 {
            self.walk = 2 if dice.chance(0.6) else 0;
        } elif self.down == 2 {
            self.walk = 1 if dice.chance(0.6) else 0;
        } else {
            self.walk = dice.below(3);
        }
        self.tall = 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-8),
            Port(face=1 if self.walk == 1 else 3, along=float(self.long - 5), floor=-8),
            Port(face=1, along=8.0, floor=0)
        ];
        if self.walk == 1 {
            self.leaves.append(Port(face=0, along=3.0, floor=0));
        } elif self.walk == 2 {
            self.leaves.append(Port(face=0, along=float(self.wide) - 3.0, floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, -8, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The ledge, and the vestibule's wall with the great doors in it.
        build.solid(1, 1, -8, 10, self.wide - 1, 0);
        build.solid(5, 1, 0, 6, self.wide - 1, self.tall);
        build.widen(hall, 5, middle - 3, 0, 6, middle + 3, self.tall);
        sliding_pair(build, 5, middle - 3, middle + 3, 0, self.tall);
        # Down from the ledge.
        if self.down == 0 {
            stair(build, 17, 1, -8, 2, 8, 3);
            keep_box(build, hall, 9, 1, 10, 4, 0);
        } elif self.down == 1 {
            lift(build, 10, middle - 1, 13, middle + 2, -8, 0);
            keep_box(build, hall, 9, middle - 1, 10, middle + 2, 0);
            keep_box(build, hall, 10, middle - 2, 14, middle + 3, -8);
        } else {
            stair(build, 17, self.wide - 4, -8, 2, 8, 3);
            keep_box(build, hall, 9, self.wide - 4, 10, self.wide - 1, 0);
        }
        # The walk along a wall over the hall, from the ledge to the far wall.
        if self.walk == 1 {
            slab(build, 10, 1, self.long - 1, 5, 0);
            keep_box(build, hall, 16, 4, 19, 5, 0);
        } elif self.walk == 2 {
            slab(build, 10, self.wide - 5, self.long - 1, self.wide - 1, 0);
            keep_box(build, hall, 16, self.wide - 5, 19, self.wide - 4, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        hint(build, 6.0, float(middle - 3), 0.0, 8.0, float(middle + 3), 6.0, "The House of Pain", "Its halls lie below", 2.0);
        # What waits in the hall below wakes as the player comes to the
        # ledge's rim.
        rim = build.touch(8.0, 1.0, 0.0, 10.0, float(self.wide - 1), 6.0);
        below = wake_later(build, rim, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5 - float(index) * 4.0, float(middle) + (2.5 if index % 2 == 0 else -2.5), -8, q3dm2_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, -8, q3dm2_foe(dice, self.danger), 180.0);
        if self.walk == 1 {
            build.foe(float(self.long) - 3.5, 3.0, 0, q3dm2_foe(dice, self.danger), 180.0);
        } elif self.walk == 2 {
            build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, 0, q3dm2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 3.0, float(middle) + 3.5, -8, Q3_HEALTH, "q3");
        build.supply(20.5, float(middle) + 0.5, -8, Q3_ARMOR, "q3");
    }
}

"""A hall, a balcony across its far end over an undercroft, ridden up to by
lifts at its corners, by a lift and a stair, or by a lift and a gallery."""
node PainLifts(Prefab) {
    has balcony: int = 9,
        form: int = 0,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain lifts";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.balcony = 9;
        self.form = dice.below(3);
        self.tall = self.balcony + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.balcony),
            Port(face=1, along=8.0, floor=0),
            Port(face=0, along=3.5, floor=0),
            Port(face=3, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        b = self.balcony;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, b);
        bx = self.long - 7;
        slab(build, bx, 1, self.long - 1, self.wide - 1, b);
        # The +y corner's lift is always there.
        lift(build, bx - 3, self.wide - 5, bx, self.wide - 2, 0, b);
        keep_box(build, hall, bx, self.wide - 5, bx + 1, self.wide - 2, b);
        keep_box(build, hall, bx - 4, self.wide - 6, bx, self.wide - 1, 0);
        if self.form == 0 {
            lift(build, bx - 3, 2, bx, 5, 0, b);
            keep_box(build, hall, bx, 2, bx + 1, 5, b);
            keep_box(build, hall, bx - 4, 1, bx, 6, 0);
        } elif self.form == 1 {
            flying_stair(build, bx - b, 1, 0, 0, b, 3);
            keep_box(build, hall, bx, 1, bx + 1, 4, b);
        } else {
            # A gallery back along the -y wall from the balcony, its near end
            # an rim to drop from.
            slab(build, 6, 1, bx, 5, b);
            keep_box(build, hall, 6, 4, 9, 5, b);
        }
        pillars(build, 6, middle - 2, bx - 4, middle + 3, 0, self.tall, 5, [[0, middle - 3, 4, middle + 3]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The balcony's guards wake as the player steps onto a lift.
        ride = build.touch(float(bx - 3), float(self.wide - 5), 0.0, float(bx), float(self.wide - 2), 4.0);
        above = wake_later(build, ride, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.0, 3.5 + float(index) * float(self.wide - 7), b, q3dm2_foe(dice, self.danger, index == 0), 180.0, waits=above);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 4) + 0.5, 3.0 if index % 2 == 0 else float(self.wide) - 3.0, 0, q3dm2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, q3dm2_foe(dice, self.danger), 180.0);
        if self.form == 2 {
            build.foe(10.5, 3.0, b, q3dm2_foe(dice, self.danger), 0.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 2.5, b, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.5, 3.5, 0, "ammo_nails");
    }
}

"""The hub: a deep pit hall under walks along both sides and a bridge
across, a stair down from the near floor and a ramp or a lift up."""
node PainPit(Prefab) {
    has down: int = 0,
        bridge: bool = True,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain pit";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.down = dice.below(3);
        self.bridge = dice.chance(0.6);
        self.tall = 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-8),
            Port(face=1, along=float(self.long // 2 + 5), floor=0),
            Port(face=3, along=float(self.long // 2 + 5), floor=0),
            Port(face=0, along=3.5, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        north = wide - 6;
        pit = build.room(1, 1, -8, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        # The near floor, and the walks along both sides over the pit.
        build.solid(1, 1, -8, 7, wide - 1, 0);
        slab(build, 7, 1, long - 1, 6, 0);
        slab(build, 7, north, long - 1, wide - 1, 0);
        for x in range(12, long - 1, 5) {
            build.solid(x, 5, -8, x + 1, 6, -1);
            build.solid(x, north, -8, x + 1, north + 1, -1);
        }
        bx = long // 2 - 1;
        if self.bridge {
            slab(build, bx, 6, bx + 3, north, 0);
            keep_box(build, pit, bx, 5, bx + 3, 6, 0);
            keep_box(build, pit, bx, north, bx + 3, north + 1, 0);
        }
        # Down into the pit and back up: the near stair, the far ramp, or
        # both; a lift by the +y walk now and then.
        if self.down != 1 {
            stair(build, 14, middle - 2, -8, 2, 8, 4);
            keep_box(build, pit, 6, middle - 2, 7, middle + 2, 0);
        }
        if self.down != 0 {
            stair(build, long - 9, 6, -8, 0, 8, 3);
        }
        if self.down == 1 or dice.chance(0.4) {
            lift(build, long - 6, north - 3, long - 3, north, -8, 0);
            keep_box(build, pit, long - 6, north, long - 3, north + 1, 0);
            keep_box(build, pit, long - 7, north - 4, long - 2, north, -8);
        }
        # The walks' inner edges to drop from, into the pit.
        keep_box(build, pit, 9, 5, 12, 6, 0);
        keep_box(build, pit, 9, north, 12, north + 1, 0);
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        # What lies in the pit wakes as the player comes to its rim; a
        # guard walks the -y walk.
        rim = build.touch(5.0, 6.0, 0.0, 7.0, float(north), 6.0);
        below = wake_later(build, rim, 1.5);
        for index in range(dice.between(3, 4)) {
            build.foe(float(16 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), -8, q3dm2_foe(dice, self.danger), 180.0, waits=below);
        }
        build.foe(float(long) - 3.5, float(middle) + 0.5, -8, q3dm2_foe(dice, self.danger, True), 180.0);
        build.foe(9.5, 3.0, 0, q3dm2_foe(dice, self.danger), 0.0, patrol=[[9.5, 3.0], [float(long) - 3.5, 3.0]]);
        build.foe(float(long) - 3.5, float(wide) - 3.0, 0, q3dm2_foe(dice, self.danger, True), 180.0);
        build.supply(float(bx) + 1.5, float(middle) + 0.5, -8, "item_armor_body", "q3");
        build.supply(3.5, 3.5, 0, Q3_HEALTH, "q3");
        if self.bridge {
            build.supply(float(bx) + 1.5, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
        }
    }
}

"""Two halls one over the other, the upper's floor slotted to look down,
stairs between at both ends (or a stair and a lift)."""
node PainHalls(Prefab) {
    has lift_far: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain halls";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.lift_far = dice.chance(0.4);
        self.tall = 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=3.5, floor=0),
            Port(face=0, along=float(self.wide) - 4.0, floor=-8, high=7),
            Port(face=1, along=float(self.long // 2), floor=-8, high=7),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        halls = build.room(1, 1, -8, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(halls, 0);
        # The upper hall's floor over the lower, then the holes in it: the
        # slot to look down by, and where the stairs come up.
        slab(build, 1, 1, long - 1, wide - 1, 0);
        build.widen(halls, 10, middle - 1, -1, long - 10, middle + 1, 0);
        # The near stair, up the -y wall to the upper floor's near end.
        build.widen(halls, 4, 1, -1, 12, 4, 0);
        stair(build, 11, 1, -8, 2, 8, 3);
        keep_box(build, halls, 3, 1, 4, 4, 0);
        # The far stair up the +y wall, or a lift.
        if self.lift_far {
            build.widen(halls, long - 7, wide - 5, -1, long - 4, wide - 2, 0);
            lift(build, long - 7, wide - 5, long - 4, wide - 2, -8, 0);
            keep_box(build, halls, long - 8, wide - 6, long - 3, wide - 1, -8);
        } else {
            build.widen(halls, long - 13, wide - 4, -1, long - 5, wide - 1, 0);
            stair(build, long - 13, wide - 4, -8, 0, 8, 3);
            keep_box(build, halls, long - 5, wide - 4, long - 4, wide - 1, 0);
        }
        # Pillars down the lower hall holding the upper floor.
        for x in range(7, long - 6, 5) {
            build.solid(x, 4, -8, x + 1, 5, -1);
            build.solid(x, wide - 5, -8, x + 1, wide - 4, -1);
        }
        build.doorway(halls, self.enter);
        for port in self.taken {
            build.doorway(halls, port);
        }
        # The lower hall's foes wake a moment after the player looks down
        # through the slot.
        look = build.touch(10.0, float(middle - 2), 0.0, 12.0, float(middle + 2), 6.0);
        below = wake_later(build, look, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(long) - 5.5 - float(index) * 5.0, float(middle) + (2.5 if index % 2 == 0 else -2.5), -8, q3dm2_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(14.5, 2.5, -8, q3dm2_foe(dice, self.danger), 0.0, patrol=[[14.5, 2.5], [float(long) - 3.5, 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(long // 2 + index * 6) + 0.5, 3.0, 0, q3dm2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(long) - 3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(4.5, float(wide) - 3.0, -8, Q3_ARMOR, "q3");
    }
}

"""The key room: a block of cells sunk under a catwalk, the key on a
platform across it reached over the catwalk, up a stair or by a jump pad."""
node PainCells(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        form: int = 0,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain cells (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.form = dice.below(3);
        self.tall = 9;
        self.low = -7;
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
        far = self.long - 6;
        block = build.room(1, 1, -6, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(block, 0);
        build.doorway(block, self.enter);
        # The landing by the way in, the platform at the far end, and the
        # stair down from the landing into the cells' floor.
        build.solid(1, 1, -6, 6, side, 0);
        build.solid(far, 1, -6, self.long - 1, side, 0);
        stair(build, 11, 1, -6, 2, 6, 3);
        keep_box(build, block, 5, 1, 6, 4, 0);
        if self.form == 0 {
            # The catwalk across, spikes firing over it from the walls.
            slab(build, 6, cy - 1, far, cy + 2, 0);
            keep_box(build, block, 5, cy - 1, 6, cy + 2, 0);
            keep_box(build, block, far, cy - 1, far + 1, cy + 2, 0);
            over = build.touch(float(self.long // 2 - 2), float(cy - 1), 0.0, float(self.long // 2 + 2), float(cy + 2), 5.0, False);
            over +>:Fires:+> build.spikes(float(self.long // 2) - 1.0, 1.2, 1.5, 1);
            over +>:Fires:+> build.spikes(float(self.long // 2) + 1.0, float(side) - 0.2, 1.5, 3);
        } elif self.form == 1 {
            stair(build, self.long - 12, 1, -6, 0, 6, 3);
            keep_box(build, block, far, 1, far + 1, 4, 0);
        } else {
            pad(build, block, float(far) - 3.0, float(cy) + 0.5, -6, float(far) + 1.5, float(cy) + 0.5, 0, far, cy - 2, far + 1, cy + 3);
        }
        # The platform's rim to drop from, back into the cells.
        keep_box(build, block, far, side - 4, far + 1, side - 1, 0);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, -6, [8, self.long - 10], [q3dm2_foe(dice, self.danger, True), q3dm2_foe(dice, self.danger)]);
        hint(build, 2.0, 1.0, 0.0, 4.0, float(side), 6.0, "The cells of the house", "Those kept here wait for you", 2.0);
        for index in range(dice.between(2, 3)) {
            build.foe(13.5 + float(index) * 2.5, float(cy) + (3.5 if index % 2 == 0 else -2.5), -6, "monster_zombie", 90.0);
        }
        build.foe(float(self.long) - 3.5, 3.0, 0, q3dm2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a ledge over a sanctum, balconies down its walls,
a stair, a drop or a lift down to the altar the way out stands on."""
node PainAltar(Prefab) {
    has key: str = "",
        down: int = 0,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pain altar" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM2;
        self.district = level_district(Q3DM2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(18, 20);
        self.down = dice.below(3);
        self.tall = 9;
        self.low = -9;
        self.high = 11;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 7;
        rim = wall + 7;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, -8, self.tall, self.key);
        build.solid(wall + 1, 1, -8, rim, self.wide - 1, 0);
        slab(build, rim, 1, self.long - 1, 5, 0);
        slab(build, rim, self.wide - 5, self.long - 1, self.wide - 1, 0);
        if self.down == 0 {
            stair(build, rim + 7, middle - 2, -8, 2, 8, 4);
            keep_box(build, room, rim - 1, middle - 2, rim, middle + 2, 0);
        } elif self.down == 1 {
            keep_box(build, room, rim - 1, middle - 2, rim, middle + 2, 0);
            stair(build, rim + 8, 5, -8, 2, 8, 3);
        } else {
            lift(build, rim, middle - 1, rim + 3, middle + 2, -8, 0);
            keep_box(build, room, rim - 1, middle - 1, rim, middle + 2, 0);
            keep_box(build, room, rim, middle - 2, rim + 4, middle + 3, -8);
        }
        # The balconies' edges to drop from.
        keep_box(build, room, self.long - 8, 4, self.long - 5, 5, 0);
        keep_box(build, room, self.long - 8, self.wide - 5, self.long - 5, self.wide - 4, 0);
        # The altar, two steps up, the way out on it.
        build.solid(self.long - 7, middle - 3, -8, self.long - 1, middle + 3, -7);
        build.solid(self.long - 6, middle - 2, -7, self.long - 1, middle + 2, -6);
        build.way_out(float(self.long) - 3.5, float(middle), -6);
        # Touching the sanctum's floor brings a foe in behind, out of a
        # closet sealed under the hall, and wakes the balconies.
        floor = build.touch(float(rim + 4), 5.0, -8.0, float(rim + 6), float(self.wide - 5), -2.0);
        floor +>:Fires:+> build.summon(2, 2, -8, q3dm2_foe(dice, self.danger, True), float(rim) + 1.5, float(middle) + 4.5, -8, 0.0);
        above = wake_later(build, floor, 0.5);
        build.foe(float(self.long) - 4.0, 3.0, 0, q3dm2_foe(dice, self.danger, True), 180.0, waits=above);
        build.foe(float(self.long) - 4.0, float(self.wide) - 3.0, 0, q3dm2_foe(dice, self.danger), 180.0, waits=above);
        for index in range(dice.between(2, 3)) {
            build.foe(float(rim + 8 + index * 3) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.0), -8, q3dm2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(wall) + 3.5, 3.0, 0, q3dm2_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(rim) + 2.5, float(self.wide) - 3.0, 0, "item_haste", "q3");
    }
}

"""q3dm2's stretches: [name, role]."""
glob Q3DM2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["lifts", "flow"],
         ["halls", "flow"],
         ["pit", "hub"],
         ["cells", "keyroom"],
         ["altar", "end"],
         ["altar", "gate"]
     ];

"""One of q3dm2's stretches by its name."""
def make_q3dm2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PainGate();
    }
    if name == "lifts" {
        return PainLifts();
    }
    if name == "halls" {
        return PainHalls();
    }
    if name == "pit" {
        return PainPit();
    }
    if name == "cells" {
        return PainCells(key=key if key else "key_silver");
    }
    return PainAltar(key=key);
}
