"""Prefabs drawn from Quake III's q3dm4, The Place of Many Deaths: a great
floor sunk deep under its ledges, pits of lava in it, a tower standing out
of a lava moat in its middle reached by a causeway or a teleporter, and a
long climb winding up over a lake of lava. Quake III's arenas hold
no foes of their own; q3dm4's are zombie, ogre, hell_knight. Raised in
q3dm4's own palette.

- `ManyGate`: the start. A ledge over a floor half a storey down, a broad
  stair, two narrow ones or a lift down, pits of lava in the floor; ways on
  from the floor and the ledge.
- `ManyDeathsPit`: a ledge in over a deep pit, a stair down its wall,
  channels of lava across its floor to jump, a teleporter (or a lift) back
  up to the ledge; ways on from the floor beyond the lava.
- `ManyTower`: the hub. A tower in a moat of lava in a hall's middle, a
  causeway to its top from a ledge high along the far wall (climbed by a
  stair) and a teleporter at the moat's edge (or teleporters both ways);
  ways on from the floor and the ledge.
- `ManyClimb`: the climb out of the fire. A lake of lava under the sky, three
  causeways over it side by side, a flight in each, turning back on itself
  at landings over the lake from the shore to the high far end; the whole
  climb in sight across the lake, a jump pad now and then from the shore to
  the turn half way up, its edge dropped from back to the shore.
- `ManyForge`: the key room. A lake of lava between the shore and the
  key's platform, crossed by stepping stones (a gallery over them too), a
  bridge drawn out when a button high on the far wall is shot, or a pair
  of teleporters.
- `ManyAltar`: the end (or a gate). A moat of lava before the dais the way
  out stands on, crossed by a bridge drawn out by a button, by a
  teleporter or by stepping stones; its guards wake as the player
  crosses."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, keep_frame, hint, wake_later, lava, lava_stones, flying_stair, pad_to }

glob Q3DM4: str = "q3:q3dm4",
     Q3DM4_LIGHT: list[str] = ["monster_zombie", "monster_ogre"],
     Q3DM4_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for q3dm4's stretches."""
glob Q3DM4_FOES: FoeMix = FoeMix(light=Q3DM4_LIGHT, strong=Q3DM4_HEAVY, heavy_light=Q3DM4_HEAVY, scale=0.5);

"""The start: a ledge over a floor half a storey down, stairs or a lift
down, pits of lava in the floor."""
node ManyGate(Prefab) {
    has down: int = 0,
        pits: int = 2,
        walk: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many gate";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.down = dice.below(3);
        self.pits = dice.between(1, 3);
        self.walk = self.down != 1 and dice.chance(0.6);
        self.tall = 32;
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-8),
            Port(face=3, along=float(self.long - 5), floor=-8),
            Port(face=1, along=5.0, floor=0)
        ];
        if self.walk {
            self.leaves.append(Port(face=0, along=float(self.wide) - 3.0, floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, -10, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 0);
        build.level(hall, -8);
        build.solid(1, 1, -10, 9, self.wide - 1, 0);
        build.solid(9, 1, -10, self.long - 1, self.wide - 1, -8);
        if self.down == 0 {
            stair(build, 16, middle - 3, -8, 2, 8, 6);
            keep_box(build, hall, 8, middle - 3, 9, middle + 3, 0);
        } elif self.down == 1 {
            stair(build, 16, 1, -8, 2, 8, 3);
            stair(build, 16, self.wide - 4, -8, 2, 8, 3);
            keep_box(build, hall, 8, 1, 9, 4, 0);
            keep_box(build, hall, 8, self.wide - 4, 9, self.wide - 1, 0);
        } else {
            lift(build, 9, middle - 1, 12, middle + 2, -8, 0);
            keep_box(build, hall, 8, middle - 1, 9, middle + 2, 0);
            keep_box(build, hall, 9, middle - 2, 13, middle + 3, -8);
        }
        # The ledge's front, open to drop from but by the stairs.
        keep_box(build, hall, 8, 4, 9, middle - 3, 0);
        # A walk on along the +y wall over the floor, to the far wall.
        if self.walk {
            slab(build, 9, self.wide - 5, self.long - 1, self.wide - 1, 0);
            keep_box(build, hall, 14, self.wide - 5, 17, self.wide - 4, 0);
            build.foe(float(self.long) - 4.0, float(self.wide) - 3.0, 0, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        }
        # Pits of lava in the floor, clear of the stairs' feet and the ways
        # out.
        spots = [[18, 2], [18, self.wide - 7], [23, self.wide - 6]];
        for index in range(self.pits) {
            spot = spots[index];
            lava(build, spot[0], spot[1], -10, spot[0] + 4, spot[1] + 5, -8, 25, False);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        hint(build, 4.0, 1.0, 0.0, 6.0, float(self.wide - 1), 6.0, "The Place of Many Deaths", "Mind the lava", 2.5);
        rim = build.touch(7.0, 1.0, 0.0, 9.0, float(self.wide - 1), 6.0);
        below = wake_later(build, rim, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5 - float(index) * 2.0, 3.0 + float(index) * 3.0, -8, Q3DM4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(17.5, float(middle) + 0.5 + (3.0 if self.down == 0 else 0.0), -8, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, -8, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, Q3_ARMOR, "q3");
    }
}

"""A ledge in over a deep pit, a stair down its wall, channels of lava
across its floor, a teleporter or a lift back up to the ledge."""
node ManyDeathsPit(Prefab) {
    has deep: int = 8,
        channels: int = 1,
        teleport: bool = True,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many deaths pit";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(27, 29);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(9, 11);
        self.channels = dice.between(1, 2);
        self.teleport = dice.chance(0.6);
        self.tall = dice.between(30, 33);
        self.low = -self.deep - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=3, along=float(self.long - 4), floor=-self.deep), Port(face=1, along=3.0, floor=0), Port(face=0, along=float(self.wide) - 3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        pit = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(pit, 0);
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        stair(build, 5 + self.deep, 1, low, 2, self.deep, 3);
        keep_box(build, pit, 5, 4, 6, self.wide - 5, 0);
        # A walk along the +y wall over the pit from the ledge to the far
        # wall, open to drop from along its middle.
        slab(build, 6, self.wide - 5, self.long - 1, self.wide - 1, 0);
        keep_box(build, pit, 12, self.wide - 5, 18, self.wide - 4, 0);
        # Channels of lava across the floor, a cell wide, to jump.
        for index in range(self.channels) {
            cx = 16 + index * 3;
            lava(build, cx, 1, low - 2, cx + 1, self.wide - 1, low, 30, False);
        }
        if self.teleport {
            build.teleporter(float(self.long) - 5.0, float(middle) + 0.5, low, 3.0, float(middle) + 0.5, 0, 0.0);
        } else {
            lift(build, 6, middle - 1, 9, middle + 2, low, 0);
            keep_box(build, pit, 5, middle - 1, 6, middle + 2, 0);
            keep_box(build, pit, 6, middle - 2, 10, middle + 3, low);
        }
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        down = build.touch(float(self.deep + 6), 1.0, float(low), float(self.deep + 9), 4.0, float(low + 6));
        floor = wake_later(build, down, 0.5);
        spots = [12.5, 17.5, float(self.long) - 6.5, float(self.long) - 3.5];
        for index in range(dice.between(3, 4)) {
            build.foe(spots[index], float(middle) + (3.5 if index % 2 == 0 else -3.5), low, Q3DM4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=floor);
        }
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, low, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, "item_rockets");
        build.foe(float(self.long) - 4.0, float(self.wide) - 3.0, 0, Q3DM4_FOES.pick(dice, self.danger), 180.0);
    }
}

"""The hub: a tower in a moat of lava, a causeway to its top from a ledge
high on the far wall, a teleporter at the moat's edge."""
node ManyTower(Prefab) {
    has top: int = 11,
        access: int = 0,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many tower";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(30, 32);
        self.wide = dice.between(28, 30);
        self.top = 14;
        self.access = dice.below(3);
        self.tall = self.top + 26;
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.top),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=1, along=6.0, floor=0),
            Port(face=0, along=3.5, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        t = self.top;
        cx = long // 2 - 2;
        cy = wide // 2;
        hall = build.room(1, 1, -2, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, t);
        build.solid(1, 1, -2, long - 1, wide - 1, 0);
        # The moat round the tower, in four reaches, and the tower.
        lava(build, cx - 6, cy - 6, -2, cx + 7, cy - 3, 0, 30, False);
        lava(build, cx - 6, cy + 4, -2, cx + 7, cy + 7, 0, 30, False);
        lava(build, cx - 6, cy - 3, -2, cx - 3, cy + 4, 0, 30, False);
        lava(build, cx + 4, cy - 3, -2, cx + 7, cy + 4, 0, 30, False);
        build.solid(cx - 3, cy - 3, -2, cx + 4, cy + 4, t);
        # The ledge high along the far wall, over the floor, a stair up the
        # +y wall to it.
        lx = long - 6;
        slab(build, lx, 1, long - 1, wide - 1, t);
        stair(build, lx - t, wide - 4, 0, 0, t, 3);
        keep_box(build, hall, lx, 4, lx + 1, wide - 5, t);
        # The causeway from the ledge to the tower's top, and the teleporter
        # at the moat's edge up to it (or both ways).
        if self.access != 1 {
            slab(build, cx + 4, cy - 1, lx, cy + 2, t);
        }
        if self.access != 2 {
            build.teleporter(float(cx - 8), float(cy) + 0.5, 0, float(cx) + 0.5, float(cy) + 0.5, t, 0.0);
        }
        if self.access == 1 {
            build.teleporter(float(cx) - 1.5, float(cy) - 1.5, t, float(cx - 9) - 0.5, float(cy) - 4.5, 0, 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        hint(build, 3.0, 1.0, 0.0, 5.0, float(wide - 1), 6.0, "The tower stands in the lava", "Its top is reached by the causeway or the teleporter", 3.0);
        # The tower's guard wakes as the player reaches its top.
        up = build.touch(float(cx - 3), float(cy - 3), float(t), float(cx + 4), float(cy + 4), float(t + 6));
        crown = wake_later(build, up, 0.3);
        build.foe(float(cx) + 2.5, float(cy) + 2.5, t, Q3DM4_FOES.pick(dice, self.danger, True), 180.0, waits=crown);
        build.foe(3.5, 3.5, 0, Q3DM4_FOES.pick(dice, self.danger), 0.0, patrol=[[3.5, 3.5], [float(long) - 8.5, 3.5], [float(long) - 8.5, float(wide) - 6.5], [3.5, float(wide) - 6.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 9) + 0.5, 4.5 + float(index) * 6.0, 0, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(long) - 3.0, 3.0, t, Q3DM4_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(cx) + 0.5, float(cy) + 2.5, t, "item_armor_body", "q3");
        build.supply(float(cx - 9) + 0.5, 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(long) - 3.0, float(wide) - 6.0, t, "item_rockets");
        build.supply(float(long) - 4.5, float(cy) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""The climb out of the fire: a lake of lava under the sky, three causeways
over it side by side, a flight in each, turning back on itself at landings
from the shore up to the high far end; a jump pad now and then from the shore
to the turn half way up."""
node ManyClimb(Prefab) {
    has thrown: bool = False,
        tall: int = 42;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many climb";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(32, 35);
        self.wide = dice.between(23, 25);
        self.thrown = dice.chance(0.5);
        self.tall = 42;
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide) - 3.0, floor=18),
            Port(face=1, along=float(self.long - 6), floor=18),
            Port(face=3, along=21.0, floor=6),
            Port(face=0, along=3.0, floor=6)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cy = wide // 2;
        north = wide - 5;
        hall = build.room(1, 1, -2, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 6);
        build.level(hall, 12);
        build.level(hall, 18);
        # The shore, and the lake from it to the far wall.
        build.solid(1, 1, -2, 6, wide - 1, 0);
        lava(build, 6, 1, -2, long - 1, wide - 1, 0, 30, False);
        # The first causeway along the -y wall, up to the far landing.
        slab(build, 6, 1, 9, 5, 0);
        flying_stair(build, 9, 1, 0, 0, 6, 4);
        slab(build, 15, 1, long - 6, 5, 6);
        slab(build, long - 6, 1, long - 1, cy + 2, 6);
        # A pier under the far landing, standing in the lake.
        build.solid(long - 5, cy - 1, -2, long - 2, cy + 2, 5);
        # The second down the middle, back over the lake to the near landing
        # over the shore.
        slab(build, long - 8, cy - 2, long - 6, cy + 2, 6);
        flying_stair(build, long - 9, cy - 2, 6, 2, 6, 4);
        slab(build, 1, cy - 2, long - 14, cy + 2, 12);
        slab(build, 1, cy + 2, 6, wide - 1, 12);
        # The third along the +y wall, up to the high far end.
        slab(build, 6, north, 9, wide - 1, 12);
        flying_stair(build, 9, north, 12, 0, 6, 4);
        slab(build, 15, north, long - 1, wide - 1, 18);
        # The near landing's edge to drop from, to the shore; a jump pad on
        # the shore up to it.
        keep_box(build, hall, 1, cy - 2, 6, cy - 1, 12);
        if self.thrown {
            pad_to(build, hall, 3.5, float(cy) - 5.0, 0, 3.5, float(cy) + 0.5, 12, 1, cy - 2, 6, cy - 1);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        hint(build, 2.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, "The climb out of the fire", "Mind the lake", 2.5);
        build.foe(21.5, 3.0, 6, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(long) - 3.0, 3.0, 6, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        build.foe(12.5, float(cy) + 0.5, 12, Q3DM4_FOES.pick(dice, self.danger), 0.0);
        # What holds the top wakes as the player turns onto the last flight.
        turn = build.touch(6.0, float(north), 12.0, 9.0, float(wide - 1), 18.0);
        top = wake_later(build, turn, 0.5);
        build.foe(float(long) - 3.0, float(wide) - 3.0, 18, Q3DM4_FOES.pick(dice, self.danger, True), 180.0, waits=top);
        build.foe(float(long) - 8.5, float(wide) - 3.0, 18, Q3DM4_FOES.pick(dice, self.danger), 180.0, waits=top);
        build.supply(float(long) - 3.0, float(cy) + 0.5, 6, Q3_HEALTH, "q3");
        build.supply(3.5, float(wide) - 3.0, 12, "item_spikes");
        build.supply(float(long) - 12.5, float(wide) - 3.0, 18, Q3_HEALTH, "q3");
    }
}

"""The key room: a lake of lava between the shore and the key's platform,
crossed by stepping stones, a bridge a shot button draws out, or
teleporters."""
node ManyForge(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        cross: int = 0,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many forge (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(25, 27);
        self.hall_wide = dice.between(17, 19);
        self.wide = self.hall_wide + 4;
        self.cross = dice.below(3);
        self.tall = 34;
        self.low = -6;
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
        lake_x0 = 7;
        far = lake_x0 + 1 + 3 * ((self.long - 8 - lake_x0) // 3);
        forge = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.doorway(forge, self.enter);
        # The lake between the shore (x < 7) and the key's platform.
        if self.cross == 0 {
            # Stepping stones a cell of lava apart.
            lava_stones(build, lake_x0, far, 1, side, -2, 0, cy - 1, cy + 2, 40);
            hint(build, 3.0, 1.0, 0.0, 5.0, float(side), 6.0, "Leap from stone to stone", "The lava does not forgive", 2.0);
        } else {
            lava(build, lake_x0, 1, -2, far, side, 0, 40, False);
        }
        if self.cross == 1 {
            # A bridge drawn out across the lake when the button high on the
            # far wall is shot.
            shot = build.push(float(self.long - 1), float(cy) + 3.5, 4.0, 2, True);
            shot +>:Fires:+> build.drawn(float(lake_x0), float(cy - 1), float(far), float(cy + 2), 0, 3);
            keep_box(build, forge, lake_x0 - 1, cy - 1, lake_x0, cy + 2, 0);
            keep_box(build, forge, far, cy - 1, far + 1, cy + 2, 0);
            hint(build, 3.0, 1.0, 0.0, 5.0, float(side), 6.0, "Shoot the button over the lava", "The bridge will rise", 2.0);
        } else {
            build.teleporter(3.5, 3.5, 0, float(far) + 2.5, 3.5, 0, 0.0);
            build.teleporter(float(self.long) - 3.0, 3.5, 0, 4.5, float(side) - 3.5, 0, 180.0);
        }
        # The key on a dais at the platform's far end.
        build.solid(self.long - 4, cy - 2, 0, self.long - 1, cy + 3, 1);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 1, side, 0, [2, far + 1], [Q3DM4_FOES.pick(dice, self.danger, True), Q3DM4_FOES.pick(dice, self.danger)]);
        build.foe(float(far) + 2.5, 3.0, 0, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(cy) + 0.5, 0, Q3DM4_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a moat of lava before the dais the way out stands
on, crossed by a drawn bridge, a teleporter or stepping stones."""
node ManyAltar(Prefab) {
    has key: str = "",
        cross: int = 0,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Many altar" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM4;
        self.district = level_district(Q3DM4);
        self.long = dice.between(30, 32);
        self.wide = dice.between(16, 18);
        self.cross = dice.below(3);
        self.tall = 34;
        self.low = -6;
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
        mx = wall + 6;
        mx1 = mx + (4 if self.cross != 2 else 7);
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        if self.cross == 2 {
            lava_stones(build, mx, mx1, 1, self.wide - 1, -2, 0, middle - 1, middle + 2, 40);
        } else {
            lava(build, mx, 1, -2, mx1, self.wide - 1, 0, 40, False);
        }
        if self.cross == 0 {
            press = build.push(float(mx) - 2.5, 1.0, 1.2, 1);
            press +>:Fires:+> build.drawn(float(mx), float(middle - 1), float(mx1), float(middle + 2), 0, 3);
            keep_box(build, room, mx - 1, middle - 1, mx, middle + 2, 0);
            keep_box(build, room, mx1, middle - 1, mx1 + 1, middle + 2, 0);
            hint(build, float(wall + 1), 1.0, 0.0, float(wall + 3), float(self.wide - 1), 6.0, "The button draws the bridge", "Cross the lava", 2.0);
        } elif self.cross == 1 {
            build.teleporter(float(mx) - 3.0, float(middle) + 0.5, 0, float(mx1) + 3.0, float(middle) + 0.5, 0, 0.0);
        }
        # The dais, two steps, the way out on it; ledges either side.
        build.solid(self.long - 8, 2, 0, self.long - 1, self.wide - 2, 1);
        build.solid(self.long - 6, 3, 1, self.long - 1, self.wide - 3, 2);
        build.way_out(float(self.long) - 3.5, float(middle), 2);
        slab(build, mx1 + 2, 1, self.long - 1, 4, 6);
        slab(build, mx1 + 2, self.wide - 4, self.long - 1, self.wide - 1, 6);
        over = build.touch(float(mx1), 1.0, 0.0, float(mx1 + 2), float(self.wide - 1), 6.0);
        guards = wake_later(build, over, 0.3);
        spots = [[float(self.long) - 5.0, 2.5, 1.0], [float(mx1) + 1.5, float(self.wide) - 3.0, 0.0], [float(mx1) + 1.5, 3.0, 0.0]];
        for index in range(dice.between(2, 3)) {
            build.foe(spots[index][0], spots[index][1], int(spots[index][2]), Q3DM4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(self.long) - 4.0, 2.0, 6, Q3DM4_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(wall) + 3.5, float(middle) + 3.5, 0, Q3DM4_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(mx) - 2.5, float(self.wide) - 3.0, 0, "item_rockets");
    }
}

"""q3dm4's stretches: [name, role]."""
glob Q3DM4_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["pit", "flow"],
         ["climb", "flow"],
         ["tower", "hub"],
         ["forge", "keyroom"],
         ["altar", "end"],
         ["altar", "gate"]
     ];

"""One of q3dm4's stretches by its name."""
def make_q3dm4(name: str, key: str) -> Prefab {
    if name == "gate" {
        return ManyGate();
    }
    if name == "pit" {
        return ManyDeathsPit();
    }
    if name == "climb" {
        return ManyClimb();
    }
    if name == "tower" {
        return ManyTower();
    }
    if name == "forge" {
        return ManyForge(key=key if key else "key_silver");
    }
    return ManyAltar(key=key);
}
