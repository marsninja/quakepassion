"""Prefabs drawn from Quake III's q3dm5, The Forgotten Place: a gothic
place on five levels, its high walks crossing over the halls under them,
its lowest room thrown out of by a jump pad, chasms of fire under its
bridges. Quake III's arenas hold no foes of their own; q3dm5's are
zombie, knight, shambler. Raised in q3dm5's own palette.

- `ForgottenEntry`: the start. A hall, a walk high down its middle over
  the floor, a landing across its far end climbed by a stair up one wall
  (or both) or thrown up to by a jump pad; the walk's near end dropped
  from; ways on from the floor and the walk.
- `ForgottenBridges`: a chasm of lava crossed low by a bridge (whole, or
  broken by a gap to jump, or gone) and high by another from a stair on
  the near ledge to a ledge high on the far side, a jump pad back up.
- `ForgottenHall`: the hub. A floor and a pit half a storey under it, a
  walk high over both from end to end, a stair down into the pit, a jump
  pad in the pit up to the walk, a ledge along the pit's wall; ways on
  from all three levels.
- `ForgottenGallery`: a nave on four levels, a sunken middle, a raised
  dais at the far end, walks high along both walls (or one) climbed from
  the dais and dropped from at the near end.
- `ForgottenVault`: the key room. The key on a platform across a chasm of
  lava, thrown to by a jump pad (and back), over a bridge, or along a walk
  high over the chasm; taking it opens the closets on the platform.
- `ForgottenSanctum`: the end (or a gate). The way out on an island in a
  chasm of lava, reached by a low bridge, a jump pad or from a walk high
  over it; touching the island wakes its guards."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .roster { q1_foe, q1_palette }
import from .q3low_parts { slab, keep_box, hint, wake_later, pad, pad_to, flying_stair, lava }

glob Q3DM5: str = "q3:q3dm5",
     Q3DM5_LIGHT: list[str] = ["monster_zombie", "monster_knight"],
     Q3DM5_HEAVY: list[str] = ["monster_shambler"],
     # The high walks' floor over the floor below.
     Q3DM5_HIGH: int = 9;

"""A foe for q3dm5's stretches: where `strong`, a shambler only now and then
early in a run, more often as it goes deeper."""
def q3dm5_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    if strong and dice.chance(0.25 + 0.75 * danger) {
        return "monster_shambler";
    }
    return q1_foe(dice, q1_palette(Q3DM5_LIGHT, Q3DM5_HEAVY if dice.chance(danger) else [], danger * 0.5));
}

"""The start: a hall, a walk high down its middle, a landing across its far
end climbed by a stair or thrown up to by a jump pad."""
node ForgottenEntry(Prefab) {
    has access: int = 0,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten entry";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(15, 17);
        self.access = dice.below(3);
        self.tall = Q3DM5_HIGH + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=Q3DM5_HIGH),
            Port(face=0, along=3.0, floor=0),
            Port(face=1, along=10.0, floor=0),
            Port(face=3, along=10.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        u = Q3DM5_HIGH;
        middle = self.wide // 2;
        lx = self.long - 4;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The walk down the hall's middle and the landing across its far end.
        slab(build, 6, middle - 2, lx, middle + 2, u);
        slab(build, lx, 1, self.long - 1, self.wide - 1, u);
        keep_box(build, hall, 6, middle - 2, 7, middle + 2, u);
        for x in range(8, lx - 1, 5) {
            build.solid(x, middle - 1, 0, x + 1, middle + 1, u - 1);
        }
        if self.access != 1 {
            stair(build, lx - u, 1, 0, 0, u, 3);
        }
        if self.access == 1 {
            pad_to(build, hall, 7.5, float(middle) - 5.0, 0, 7.5, float(middle), u, 5, middle - 2, 10, middle - 1);
        }
        if self.access == 2 {
            stair(build, lx - u, self.wide - 4, 0, 0, u, 3);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, 3.5, 0, 0.0);
        build.supply(2.5, 5.5, 0, "ammo_shells", "q2");
        hint(build, 4.0, 1.0, 0.0, 6.0, float(self.wide - 1), 6.0, "The Forgotten Place", "Its walks cross high over its halls", 2.5);
        midway = build.touch(float(self.long // 2), 1.0, 0.0, float(self.long // 2 + 2), float(self.wide - 1), 6.0);
        above = wake_later(build, midway, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(lx) - 3.5 - float(index) * 6.0, float(middle) + 0.5, u, q3dm5_foe(dice, self.danger), 180.0, waits=above);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(9 + index * 4) + 0.5, float(self.wide) - 5.5 if index % 2 == 0 else 4.5, 0, q3dm5_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, u, q3dm5_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, u, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.5, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
        build.supply(4.5, float(self.wide) - 3.0, 0, "weapon_supernailgun");
        build.supply(6.5, float(self.wide) - 3.0, 0, "item_spikes");
        build.supply(float(lx) + 1.5, float(self.wide) - 3.0, u, "item_spikes");
    }
}

"""A chasm of lava crossed low by a bridge (whole, broken or gone) and high
by another from a stair on the near ledge to a ledge high on the far side;
a jump pad back up."""
node ForgottenBridges(Prefab) {
    has upper: int = 6,
        low_form: int = 0,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten bridges";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(17, 19);
        self.upper = 6;
        self.low_form = dice.below(3);
        self.tall = dice.between(17, 19);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=1, along=float(self.long - 3), floor=self.upper)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        u = self.upper;
        x0 = 7;
        x1 = self.long - 7;
        chasm = build.room(1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(chasm, 0);
        build.level(chasm, u);
        build.solid(1, 1, -6, x0, self.wide - 1, 0);
        build.solid(x1, 1, -6, self.long - 1, self.wide - 1, 0);
        lava(build, x0, 1, -6, x1, self.wide - 1, -3, 40, False);
        # The low bridge: whole, broken in its middle by a cell's gap, or
        # gone (the high one the only way over).
        lane = middle - 4;
        if self.low_form == 0 {
            slab(build, x0, lane, x1, lane + 3, 0);
        } elif self.low_form == 1 {
            gap = self.long // 2;
            slab(build, x0, lane, gap, lane + 3, 0);
            slab(build, gap + 1, lane, x1, lane + 3, 0);
            keep_box(build, chasm, gap - 1, lane, gap, lane + 3, 0);
            keep_box(build, chasm, gap + 1, lane, gap + 2, lane + 3, 0);
        }
        if self.low_form < 2 {
            keep_box(build, chasm, x0 - 1, lane, x0, lane + 3, 0);
            keep_box(build, chasm, x1, lane, x1 + 1, lane + 3, 0);
        }
        # The high bridge from a stair on the near ledge to the far high
        # ledge, a jump pad on the far low ledge back up to it.
        uy = self.wide - 4;
        stair(build, x0 - u, uy, 0, 0, u, 3);
        slab(build, x0, uy, x1, uy + 3, u);
        build.solid(x1, uy, 0, self.long - 1, self.wide - 1, u);
        pad_to(build, chasm, float(x1) + 3.0, float(uy) - 3.0, 0, float(x1) + 3.0, float(uy) + 1.5, u, x1 + 1, uy, x1 + 5, uy + 1);
        build.doorway(chasm, self.enter);
        for port in self.taken {
            build.doorway(chasm, port);
        }
        over = build.touch(float(self.long // 2 - 1), 1.0, 0.0, float(self.long // 2 + 1), float(self.wide - 1), float(u + 6));
        far = wake_later(build, over, 0.5);
        build.foe(float(self.long) - 3.0, float(middle) - 2.0, 0, q3dm5_foe(dice, self.danger), 180.0, waits=far);
        build.foe(float(self.long) - 3.0, float(self.wide) - 2.5, u, q3dm5_foe(dice, self.danger, True), 180.0, waits=far);
        build.foe(float(self.long // 2) + 0.5, float(uy) + 1.5, u, q3dm5_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, "item_spikes");
        build.supply(float(self.long) - 3.0, float(middle) + 2.0, 0, "item_rockets");
    }
}

"""The hub: a floor and a pit half a storey under it, a walk high over both
from end to end, a stair down into the pit, a jump pad in it up to the
walk."""
node ForgottenHall(Prefab) {
    has ledge: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten hall";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.ledge = dice.chance(0.6);
        self.tall = Q3DM5_HIGH + 10;
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=Q3DM5_HIGH),
            Port(face=0, along=3.5, floor=-8),
            Port(face=1, along=float(self.long - 6), floor=0) if self.ledge else Port(face=1, along=8.0, floor=0),
            Port(face=3, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        u = Q3DM5_HIGH;
        middle = wide // 2;
        px = 14;
        hall = build.room(1, 1, -8, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, u);
        # The floor, the pit beyond it, the stair down along the -y wall.
        build.solid(1, 1, -8, px, wide - 1, 0);
        stair(build, px + 7, 1, -8, 2, 8, 3);
        keep_box(build, hall, px - 1, 4, px, wide - 1, 0);
        # The walk from end to end over both, a stair up to its near end.
        slab(build, 1, middle - 2, long - 1, middle + 2, u);
        flying_stair(build, 3, middle - 2 - u, 0, 1, u, 3);
        # The jump pad in the pit up to the walk.
        jx = px + 8;
        pad_to(build, hall, float(jx), float(middle) - 5.0, -8, float(jx), float(middle), u, jx - 2, middle - 2, jx + 2, middle - 1);
        # The walk's sides open to drop from, over the pit.
        keep_box(build, hall, px + 2, middle + 1, long - 2, middle + 2, u);
        # The ledge along the pit's +y wall from the floor.
        if self.ledge {
            slab(build, px, wide - 5, long - 1, wide - 1, 0);
            keep_box(build, hall, px + 4, wide - 5, px + 8, wide - 4, 0);
        }
        # A hole of fire in the pit's far corner.
        lava(build, long - 6, 2, -10, long - 2, 6, -8, 50, False);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        down = build.touch(float(px + 4), 1.0, -8.0, float(px + 7), 4.0, -2.0);
        pit = wake_later(build, down, 0.5);
        spots = [[float(px) + 4.5, float(middle) + 4.5], [float(px) + 9.5, float(middle) - 4.5], [float(px) + 12.5, float(middle) + 4.5]];
        for index in range(dice.between(2, 3)) {
            build.foe(spots[index][0], spots[index][1], -8, q3dm5_foe(dice, self.danger), 180.0, waits=pit);
        }
        build.foe(float(long) - 3.0, float(middle) + 0.5, u, q3dm5_foe(dice, self.danger, True), 180.0);
        build.foe(4.5, float(wide) - 3.5, 0, q3dm5_foe(dice, self.danger), 0.0, patrol=[[4.5, float(wide) - 3.5], [float(px) - 2.5, float(wide) - 3.5]]);
        build.supply(float(jx) + 3.5, float(middle) + 0.5, -8, "item_armor_body", "q3");
        build.supply(float(px) - 2.5, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(long) - 6.0, float(middle) + 0.5, u, Q3_HEALTH, "q3");
        build.supply(6.5, float(middle) + 0.5, u, "item_rockets");
        build.supply(float(px) - 2.5, float(wide) - 6.0, 0, "weapon_rocketlauncher");
        build.supply(float(px) - 4.5, float(wide) - 6.0, 0, "item_rockets");
        build.supply(float(px) + 6.5, float(middle) - 4.5, -8, "item_health_mega", "q3");
    }
}

"""A nave on four levels: a sunken middle, a raised dais at the far end,
walks high along both walls (or one) climbed from the dais."""
node ForgottenGallery(Prefab) {
    has both: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten gallery";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(17, 19);
        self.both = dice.chance(0.5);
        self.tall = Q3DM5_HIGH + 10;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=4),
            Port(face=0, along=3.0, floor=Q3DM5_HIGH),
            Port(face=1, along=float(self.long // 2), floor=Q3DM5_HIGH) if self.both else Port(face=1, along=float(self.long // 2), floor=-4)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        u = Q3DM5_HIGH;
        middle = wide // 2;
        dx = long - 8;
        nave = build.room(1, 1, -4, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, 0);
        build.level(nave, 4);
        build.level(nave, u);
        # The near floor, the sunken middle, the dais.
        build.solid(1, 1, -4, 8, wide - 1, 0);
        build.solid(dx, 1, -4, long - 1, wide - 1, 4);
        stair(build, 11, middle - 2, -4, 2, 4, 4);
        stair(build, dx - 8, middle - 2, -4, 0, 8, 4);
        keep_box(build, nave, 7, 1, 8, wide - 1, 0);
        keep_box(build, nave, dx, 1, dx + 1, middle - 2, 4);
        keep_box(build, nave, dx, middle + 2, dx + 1, wide - 1, 4);
        # The walks high along the walls, a stair up from the dais to each,
        # their near ends open to drop from.
        slab(build, 2, 1, dx, 5, u);
        stair(build, dx, 5, 4, 0, u - 4, 3);
        slab(build, dx, 1, long - 1, 5, u);
        keep_box(build, nave, 2, 1, 3, 5, u);
        keep_box(build, nave, 9, 4, dx - 2, 5, u);
        if self.both {
            slab(build, 2, wide - 5, dx, wide - 1, u);
            slab(build, dx, wide - 5, long - 1, wide - 1, u);
            stair(build, dx, wide - 8, 4, 0, u - 4, 3);
            keep_box(build, nave, 2, wide - 5, 3, wide - 1, u);
        }
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        down = build.touch(11.0, 1.0, -4.0, 13.0, float(wide - 1), 2.0);
        walks = wake_later(build, down, 1.0);
        build.foe(float(dx) - 3.5, 3.0, u, q3dm5_foe(dice, self.danger), 180.0, waits=walks);
        if self.both {
            build.foe(float(dx) - 6.5, float(wide) - 3.0, u, q3dm5_foe(dice, self.danger), 180.0, waits=walks);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), -4, q3dm5_foe(dice, self.danger), 180.0);
        }
        build.foe(float(long) - 3.0, float(middle) + 3.5, 4, q3dm5_foe(dice, self.danger, True), 180.0);
        build.supply(float(long) - 3.0, float(middle) - 2.5, 4, Q3_HEALTH, "q3");
        build.supply(15.5, float(middle) + 0.5, -4, "item_spikes");
        build.supply(4.5, 3.0, 0, "item_rockets");
        build.supply(4.5, float(wide) - 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a platform across a chasm of lava, thrown to by
a jump pad, over a bridge, or along a walk high over the chasm."""
node ForgottenVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        cross: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.cross = dice.below(3);
        self.tall = 15;
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
        x0 = 8;
        far = self.long - 8;
        vault = build.room(1, 1, -6, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, 0);
        build.level(vault, 4);
        build.doorway(vault, self.enter);
        build.solid(1, 1, -6, x0, side, 0);
        build.solid(far, 1, -6, self.long - 1, side, 4);
        lava(build, x0, 1, -6, far, side, -4, 40, False);
        if self.cross == 0 {
            # A jump pad over the chasm to the platform, another back.
            pad_to(build, vault, float(x0) - 3.0, float(cy) + 0.5, 0, float(far) + 3.0, float(cy) + 0.5, 4, far, cy - 2, far + 1, cy + 3);
            pad_to(build, vault, float(far) + 3.0, float(cy) - 3.5, 4, 3.0, float(cy) - 3.5, 0, x0 - 1, cy - 6, x0, cy - 1);
            keep_box(build, vault, far, cy - 6, far + 1, cy - 1, 4);
        } elif self.cross == 1 {
            # A bridge over the chasm, steps up to the platform at its end.
            slab(build, x0, cy - 1, far - 4, cy + 2, 0);
            stair(build, far - 4, cy - 1, 0, 0, 4, 3);
            keep_box(build, vault, x0 - 1, cy - 1, x0, cy + 2, 0);
        } else {
            # A walk high along the -y wall over the chasm, a stair up to it
            # on the near floor, a stair down from it to the platform.
            slab(build, x0 - 1, 1, far + 1, 4, 8);
            stair(build, x0 - 7, 4, 0, 0, 8, 3);
            stair(build, far + 3, 4, 4, 2, 4, 3);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 4, side, 4, [far + 1], [q3dm5_foe(dice, self.danger, True)]);
        hint(build, 2.0, 1.0, 0.0, 4.0, float(side), 6.0, "The key lies over the fire", "Do not fall", 2.0);
        build.foe(float(self.long) - 3.0, 3.0, 4, q3dm5_foe(dice, self.danger), 180.0);
        build.foe(3.5, float(side) - 3.5, 0, q3dm5_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(side) - 6.0, 4, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): the way out on an island in a chasm of lava,
reached by a low bridge, a jump pad or from a walk high over it."""
node ForgottenSanctum(Prefab) {
    has key: str = "",
        cross: int = 0,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forgotten sanctum" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM5;
        self.district = level_district(Q3DM5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.cross = dice.below(3);
        self.tall = 17;
        self.low = -7;
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
        x0 = wall + 6;
        ix = self.long - 9;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, -6, self.tall, self.key, True);
        build.solid(wall + 1, 1, -6, x0, self.wide - 1, 0);
        lava(build, x0, 1, -6, self.long - 1, self.wide - 1, -4, 40, False);
        # The island, four lifts up, the way out on it.
        build.solid(ix, middle - 3, -6, self.long - 2, middle + 3, 4);
        build.way_out(float(ix) + 3.5, float(middle), 4);
        if self.cross == 0 {
            slab(build, x0, middle - 1, ix - 4, middle + 2, 0);
            stair(build, ix - 4, middle - 1, 0, 0, 4, 3);
            keep_box(build, room, x0 - 1, middle - 1, x0, middle + 2, 0);
        } elif self.cross == 1 {
            pad_to(build, room, float(x0) - 3.0, float(middle) + 0.5, 0, float(ix) + 3.0, float(middle) + 0.5, 4, ix, middle - 2, ix + 1, middle + 3);
        } else {
            slab(build, wall + 1, 1, self.long - 1, 4, 9);
            stair(build, wall + 2, 4, 0, 0, 9, 3);
            slab(build, ix, 4, ix + 3, middle - 1, 9);
            keep_box(build, room, ix, middle - 2, ix + 3, middle - 1, 9);
        }
        land = build.touch(float(ix), float(middle - 3), 4.0, float(ix + 2), float(middle + 3), 10.0);
        guards = wake_later(build, land, 0.3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.0, float(middle) - 2.0 + float(index) * 2.0, 4, q3dm5_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(wall) + 3.5, 3.0, 0, q3dm5_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(x0) - 2.5, float(self.wide) - 3.0, 0, "item_rockets");
        build.supply(float(x0) - 2.5, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm5's stretches: [name, role]."""
glob Q3DM5_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["bridges", "flow"],
         ["gallery", "flow"],
         ["hall", "hub"],
         ["vault", "keyroom"],
         ["sanctum", "end"],
         ["sanctum", "gate"]
     ];

"""One of q3dm5's stretches by its name."""
def make_q3dm5(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ForgottenEntry();
    }
    if name == "bridges" {
        return ForgottenBridges();
    }
    if name == "gallery" {
        return ForgottenGallery();
    }
    if name == "hall" {
        return ForgottenHall();
    }
    if name == "vault" {
        return ForgottenVault(key=key if key else "key_silver");
    }
    return ForgottenSanctum(key=key);
}
