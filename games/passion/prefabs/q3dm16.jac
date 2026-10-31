"""Prefabs drawn from Quake III's q3dm16, The Bouncy Map: platforms in the
sky over a ground that hurts (the original's floor at 0 under its decks at
256 and 384), thrown between by big jump pads, gaps jumped from one to the
next, perches over the platforms, every way up a pad and every way down a
drop, so that it is all loops. Quake III's arenas hold no foes of their
own; q3dm16's are grunts and scrags, ogres as a run goes deeper.

- `BounceLanding`: the start. Three platforms over a hurting ground, gaps
  between them jumped (or bridged), a perch over the far one a pad on the
  middle one throws a body up to, ledges along the walls pads throw up to
  from the first, pads up out of the ground.
- `BounceSteps`: platforms rising one past another from side to side, a
  pad on each up to the next, drops back down; a long pad from the first
  straight up to the last, now and then, and a perch over the last.
- `BounceRing`: a ring round a lava moat a body jumps, a base inside it and
  a tower on the base; galleries along the walls over the ring, pads up to
  them, bridges from them to the tower's top, a drop from it to the base.
- `BounceArena`: the hub. Platforms at both ends and one in the middle
  over a hurting ground, bridges (or a pad) between them, walkways along
  both walls pads throw up to, pads out of the ground.
- `BounceVault`: the key room. Platforms rising to the key, a pad from
  each up to the next, over a hurting ground; taking the key opens a
  closet and brings a foe in by teleporter.
- `BounceExit`: the end (or a gate). Past the door, platforms rising to
  the way out over a hurting ground, a pad from each up to the next."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { gate_into }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, hurt, key_taken, pit_fall, pad_to, closets, wake_on }

glob Q3DM16: str = "q3:q3dm16",
     Q3DM16_LIGHT: list[str] = ["monster_army", "monster_wizard"],
     Q3DM16_HEAVY: list[str] = ["monster_ogre"];

"""A foe for the Bouncy Map."""
glob BOUNCE_FOES: FoeMix = FoeMix(light=Q3DM16_LIGHT, strong=Q3DM16_HEAVY, heavy_light=Q3DM16_HEAVY, scale=0.5);

"""The start: three platforms over a hurting ground, a perch, ledges."""
node BounceLanding(Prefab) {
    has bridged: bool = False,
        ledges: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy landing";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(16, 17);
        self.bridged = dice.chance(0.4);
        self.ledges = dice.chance(0.6);
        self.low = -13;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=6),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -12;
        mid = self.wide // 2;
        p1x = self.long - 11;
        sky = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(sky, 0);
        build.level(sky, 6);
        # The platforms, and the gaps between them jumped (or bridged).
        build.solid(1, 1, lo, 8, self.wide - 1, 0);
        build.solid(11, mid - 3, lo, p1x, mid + 3, 0);
        build.solid(self.long - 8, 1, lo, self.long - 1, self.wide - 1, 0);
        keep_box(build, sky, 7, mid - 3, 8, mid + 3, 0);
        keep_box(build, sky, 11, mid - 3, 12, mid + 3, 0);
        keep_box(build, sky, p1x - 1, mid - 3, p1x, mid + 3, 0);
        keep_box(build, sky, self.long - 8, mid - 3, self.long - 7, mid + 3, 0);
        if self.bridged {
            deck(build, 8, mid - 1, 11, mid + 2, 0);
            deck(build, p1x, mid - 1, self.long - 8, mid + 2, 0);
        }
        # The hurting ground, pads up out of it to the first and the last.
        guards = build.waiting();
        pit_fall(build, 8, 1, self.long - 8, self.wide - 1, lo, "The ground burns", guards);
        pad_to(build, 11.0, float(mid + 5), lo, 4.0, float(mid + 5), 0);
        keep_box(build, sky, 7, mid + 4, 8, mid + 7, 0);
        pad_to(build, float(self.long - 11), float(mid - 5), lo, float(self.long) - 4.0, float(mid - 5), 0);
        keep_box(build, sky, self.long - 8, mid - 7, self.long - 7, mid - 4, 0);
        # The perch over the far platform's north end, a pad up to it from
        # the middle one; its south lip dropped from.
        deck(build, self.long - 8, self.wide - 8, self.long - 1, self.wide - 1, 6);
        pad_to(build, float(p1x - 3), float(mid) + 1.5, 0, float(self.long) - 4.0, float(self.wide) - 4.0, 6);
        keep_box(build, sky, self.long - 8, self.wide - 8, self.long - 7, self.wide - 1, 6);
        keep_box(build, sky, self.long - 6, self.wide - 8, self.long - 3, self.wide - 7, 6);
        # Ledges along the walls, pads up to them from the first platform,
        # their far ends jumped down from to the last.
        if self.ledges {
            build.level(sky, 4);
            for (y0, y1, py) in [(1, 4, 2.5), (self.wide - 4, self.wide - 1, float(self.wide) - 2.5)] {
                deck(build, 9, y0, self.long - 9, y1, 4);
                pad_to(build, 6.0, py, 0, 11.0, py, 4);
                keep_box(build, sky, 9, y0, 10, y1, 4);
                keep_box(build, sky, self.long - 10, y0, self.long - 9, y1, 4);
                keep_box(build, sky, self.long - 8, y0, self.long - 7, y1, 0);
            }
        }
        build.doorway(sky, self.enter);
        for port in self.taken {
            build.doorway(sky, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # On the middle platform, what waits on the far one wakes.
        middle = build.touch(11.0, float(mid - 3), 0.0, float(p1x), float(mid + 3), 6.0);
        middle +>:Fires:+> guards;
        build.foe(float(self.long) - 3.5, float(mid) - 2.5, 0, BOUNCE_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 6, "monster_wizard", 180.0, waits=guards);
        build.foe(float(self.long) - 4.5, float(mid) + 1.5, 0, BOUNCE_FOES.pick(dice, self.danger), 180.0);
        build.foe(13.5, float(mid) - 1.5, 0, "monster_army", 180.0);
        build.foe(4.5, 3.5, 0, "monster_army", 0.0, patrol=[[4.5, 3.5], [4.5, float(self.wide) - 3.5]]);
        build.supply(float(self.long) - 3.0, float(self.wide) - 6.0, 6, Q3_ARMOR, "q3");
        build.supply(float(p1x) - 2.5, float(mid) - 2.0, 0, Q3_HEALTH, "q3");
    }
}

"""Platforms rising one past another from side to side, a pad on each up
to the next, drops back down; a long pad, a perch."""
node BounceSteps(Prefab) {
    has long_pad: bool = True,
        perch: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy steps";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(32, 34);
        self.wide = dice.between(16, 18);
        self.long_pad = dice.chance(0.6);
        self.perch = dice.chance(0.5);
        self.tall = 27 if self.perch else 22;
        self.low = -13;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=12), Port(face=3, along=12.0, floor=4), Port(face=1, along=22.0, floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -12;
        mid = self.wide // 2;
        p3 = 28;
        sky = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, 4, 8, 12] {
            build.level(sky, z);
        }
        # The platforms: the first full across, the second along the south
        # wall, the third along the north, the last full across.
        build.solid(1, 1, lo, 7, self.wide - 1, 0);
        build.solid(9, 1, lo, 17, 8, 4);
        build.solid(19, self.wide - 8, lo, 26, self.wide - 1, 8);
        build.solid(p3, 1, lo, self.long - 1, self.wide - 1, 12);
        # A pad on each up to the next; drops back down their lips.
        pad_to(build, 4.0, 4.5, 0, 10.5, 4.5, 4);
        keep_box(build, sky, 6, 2, 7, 8, 0);
        keep_box(build, sky, 9, 2, 10, 8, 4);
        pad_to(build, 14.0, 5.5, 4, 21.0, float(self.wide) - 4.5, 8);
        keep_box(build, sky, 16, 2, 17, 8, 4);
        keep_box(build, sky, 19, self.wide - 8, 20, self.wide - 1, 8);
        pad_to(build, 23.0, float(self.wide) - 4.5, 8, float(self.long) - 3.0, float(mid) + 0.5, 12);
        keep_box(build, sky, 25, self.wide - 8, 26, self.wide - 1, 8);
        keep_box(build, sky, p3, self.wide - 8, p3 + 1, self.wide - 1, 12);
        # The long pad from the first straight up to the last.
        if self.long_pad {
            pad_to(build, 4.0, float(self.wide) - 3.5, 0, float(self.long) - 3.0, float(self.wide) - 3.5, 12);
            keep_box(build, sky, 6, self.wide - 6, 7, self.wide - 1, 0);
        }
        # A perch over the last platform, a pad up to it.
        if self.perch {
            build.level(sky, 18);
            deck(build, self.long - 4, 1, self.long - 1, 7, 18);
            pad_to(build, float(self.long - 7), 4.0, 12, float(self.long) - 2.5, 4.0, 18);
            keep_box(build, sky, self.long - 4, 2, self.long - 3, 6, 18);
            build.supply(float(self.long) - 2.5, 2.5, 18, Q3_ARMOR, "q3");
        }
        # The hurting ground, pads up out of it.
        guards = build.waiting();
        pit_fall(build, 7, 1, p3, self.wide - 1, lo, "The ground burns", guards);
        pad_to(build, 10.0, float(self.wide) - 3.5, lo, 4.0, float(self.wide) - 6.5, 0);
        pad_to(build, 25.0, 4.0, lo, float(self.long) - 3.0, 4.0, 12);
        keep_box(build, sky, p3, 2, p3 + 1, 6, 12);
        build.doorway(sky, self.enter);
        for port in self.taken {
            build.doorway(sky, port);
        }
        top = build.touch(19.0, float(self.wide - 8), 8.0, 26.0, float(self.wide - 1), 14.0);
        top +>:Fires:+> guards;
        build.foe(float(self.long) - 3.5, 3.5, 12, BOUNCE_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 12, BOUNCE_FOES.pick(dice, self.danger), 180.0, waits=guards);
        build.foe(12.5, 2.5, 4, "monster_army", 0.0);
        build.foe(22.5, float(self.wide) - 2.5, 8, BOUNCE_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(mid) + 4.0, float(mid) + 2.5, 2, "monster_wizard", 0.0);
        build.supply(12.5, 6.0, 4, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 5.5, float(mid) + 3.5, 12, Q3_HEALTH, "q3");
    }
}

"""A ring round a lava moat, a base and a tower in it, galleries over the
ring, bridges from them to the tower's top."""
node BounceRing(Prefab) {
    has both: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy ring";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(28, 30);
        self.wide = self.long;
        self.both = dice.chance(0.6);
        self.tall = dice.between(17, 18);
        self.low = -3;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=cx + 6.0, floor=8 if self.both else 0), Port(face=3, along=cx + 6.0, floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        sky = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(sky, 8);
        # The moat of lava a cell wide between the ring and the base, jumped.
        m0 = 8;
        m1 = self.long - 8;
        for strip in [[m0, m0, m1, m0 + 1], [m0, m1 - 1, m1, m1], [m0, m0 + 1, m0 + 1, m1 - 1], [m1 - 1, m0 + 1, m1, m1 - 1]] {
            build.pool(strip[0], strip[1], -2, strip[2], strip[3], 0, 4, False, False);
            hurt(build, float(strip[0]), float(strip[1]), -2.0, float(strip[2]), float(strip[3]), 0.0);
        }
        keep_box(build, sky, m0 - 1, m0 - 1, m1 + 1, m0, 0);
        keep_box(build, sky, m0 - 1, m1, m1 + 1, m1 + 1, 0);
        keep_box(build, sky, m0 - 1, m0, m0, m1, 0);
        keep_box(build, sky, m1, m0, m1 + 1, m1, 0);
        keep_box(build, sky, m0 + 1, m0 + 1, m1 - 1, m0 + 2, 0);
        keep_box(build, sky, m0 + 1, m1 - 2, m1 - 1, m1 - 1, 0);
        keep_box(build, sky, m0 + 1, m0 + 2, m0 + 2, m1 - 2, 0);
        keep_box(build, sky, m1 - 2, m0 + 2, m1 - 1, m1 - 2, 0);
        # The tower on the base, its top dropped from to the base.
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, 8);
        keep_box(build, sky, cx - 2, cy - 2, cx - 1, cy + 2, 8);
        keep_box(build, sky, cx + 1, cy - 2, cx + 2, cy + 2, 8);
        # The galleries along the walls over the ring, pads up to them from
        # it, bridges from them to the tower's top.
        sides: list[list[int]] = [[1, 4, 7, 4, cy - 2]];
        if self.both {
            sides.append([self.wide - 4, self.wide - 1, self.wide - 7, cy + 2, self.wide - 4]);
        }
        for side in sides {
            land_y = float(side[0] + side[1]) * 0.5;
            deck(build, 1, side[0], self.long - 1, side[1], 8);
            pad_to(build, 5.0, float(side[2]), 0, 5.0, land_y, 8);
            pad_to(build, float(self.long - 5), float(side[2]), 0, float(self.long - 5), land_y, 8);
            keep_box(build, sky, 4, side[0], 7, side[1], 8);
            keep_box(build, sky, self.long - 6, side[0], self.long - 3, side[1], 8);
            deck(build, cx - 1, side[3], cx + 2, side[4], 8);
        }
        build.doorway(sky, self.enter);
        for port in self.taken {
            build.doorway(sky, port);
        }
        # On the tower's top, what waits on the base wakes.
        base = wake_on(build, float(cx - 2), float(cy - 2), float(cx + 2), float(cy + 2), 8.0);
        build.foe(float(cx) - 4.5, float(cy) + 4.5, 0, BOUNCE_FOES.pick(dice, self.danger), 0.0, waits=base);
        build.foe(float(cx) + 4.5, float(cy) - 4.5, 0, BOUNCE_FOES.pick(dice, self.danger, True), 180.0, waits=base);
        build.foe(float(cx) + 0.5, 2.5, 8, BOUNCE_FOES.pick(dice, self.danger), 90.0);
        build.foe(3.5, float(cy) + 4.5, 0, "monster_army", 0.0, patrol=[[3.5, float(cy) + 4.5], [3.5, float(cy) - 4.5]]);
        build.foe(float(cx) + 0.5, float(cy) + 6.5, 4, "monster_wizard", 180.0);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 8, Q3_ARMOR, "q3");
        build.supply(float(cx) - 4.5, float(cy) - 4.5, 0, Q3_HEALTH, "q3");
    }
}

"""The hub: platforms at both ends and in the middle over a hurting
ground, bridges (or a pad), walkways along the walls, pads."""
node BounceArena(Prefab) {
    has padded: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy arena";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(18, 19);
        self.padded = dice.chance(0.4);
        self.low = -15;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=1, along=cx, floor=8), Port(face=3, along=cx, floor=8), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -14;
        cx = self.long // 2;
        cy = self.wide // 2;
        sky = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(sky, 0);
        build.level(sky, 8);
        build.solid(1, 1, lo, 7, self.wide - 1, 0);
        build.solid(self.long - 7, 1, lo, self.long - 1, self.wide - 1, 0);
        build.solid(cx - 4, cy - 4, lo, cx + 4, cy + 4, 0);
        # From the first platform to the middle: a bridge, or a pad; on to
        # the last a bridge.
        if self.padded {
            pad_to(build, 4.0, float(cy) + 2.5, 0, float(cx) - 2.0, float(cy) + 2.5, 0);
            keep_box(build, sky, 6, cy + 1, 7, cy + 4, 0);
            keep_box(build, sky, cx - 4, cy + 1, cx - 3, cy + 4, 0);
        } else {
            deck(build, 7, cy + 1, cx - 4, cy + 4, 0);
        }
        deck(build, cx + 4, cy + 1, self.long - 7, cy + 4, 0);
        # The walkways along both walls: a pad up to the south one from the
        # middle platform, to the north one from the first; their ends
        # dropped from onto the platforms at both ends.
        deck(build, 7, 1, self.long - 7, 4, 8);
        deck(build, 7, self.wide - 4, self.long - 7, self.wide - 1, 8);
        pad_to(build, float(cx), float(cy - 1), 0, float(cx), 2.5, 8);
        keep_box(build, sky, cx - 1, 3, cx + 2, 4, 8);
        pad_to(build, 4.0, float(self.wide) - 2.5, 0, 9.0, float(self.wide) - 2.5, 8);
        keep_box(build, sky, 7, self.wide - 4, 8, self.wide - 1, 8);
        keep_box(build, sky, self.long - 8, 1, self.long - 7, 4, 8);
        keep_box(build, sky, self.long - 8, self.wide - 4, self.long - 7, self.wide - 1, 8);
        keep_box(build, sky, 7, 1, 8, 4, 8);
        # The hurting ground, pads up out of it.
        guards = build.waiting();
        pit_fall(build, 7, 1, self.long - 7, self.wide - 1, lo, "The ground burns", guards);
        pad_to(build, float(cx - 7), float(cy - 2), lo, float(cx) - 1.5, float(cy - 2), 0);
        keep_box(build, sky, cx - 4, cy - 3, cx - 3, cy, 0);
        pad_to(build, float(self.long - 10), float(cy - 6), lo, float(self.long) - 3.5, float(cy - 6), 0);
        keep_box(build, sky, self.long - 7, cy - 8, self.long - 6, cy - 4, 0);
        build.doorway(sky, self.enter);
        for port in self.taken {
            build.doorway(sky, port);
        }
        # On the middle platform, the walkways' guards wake.
        middle = build.touch(float(cx - 4), float(cy - 4), 0.0, float(cx + 4), float(cy + 4), 6.0);
        middle +>:Fires:+> guards;
        build.foe(float(cx) + 5.5, 2.5, 8, BOUNCE_FOES.pick(dice, self.danger), 90.0, waits=guards);
        build.foe(float(cx) - 5.5, float(self.wide) - 2.5, 8, BOUNCE_FOES.pick(dice, self.danger, True), 270.0, waits=guards);
        build.foe(float(cx) + 2.5, float(cy) - 2.5, 0, BOUNCE_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, 0, BOUNCE_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, 4.5, 0, "monster_army", 0.0);
        build.foe(float(cx) + 0.5, float(cy) + 7.5, 4, "monster_wizard", 0.0);
        build.supply(float(cx) - 2.5, float(cy) + 0.5, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) - 4.5, 2.5, 8, Q3_HEALTH, "q3");
    }
}

"""The key room: platforms rising to the key over a hurting ground."""
node BounceVault(Prefab) {
    has key: str = "key_silver",
        tower: bool = False,
        hall_wide: int = 16,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tower = dice.chance(0.5);
        self.tall = 22 if self.tower else 18;
        self.low = -11;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -10;
        side = self.hall_wide - 1;
        cy = side // 2;
        room = build.room(1, 1, lo, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(room, 0);
        build.level(room, 4);
        build.level(room, 8);
        build.doorway(room, self.enter);
        build.solid(1, 1, lo, 7, side, 0);
        guards = build.waiting();
        taken: Cue | None = None;
        if self.tower {
            # A block six lifts up beyond a slot of lava a body jumps, a
            # perch over its far end, the key on the perch.
            build.level(room, 6);
            build.level(room, 12);
            build.solid(8, 1, lo, self.long - 1, side, 6);
            build.pool(7, 1, lo, 8, side, 0, 4, True, False);
            keep_box(build, room, 6, 1, 7, side, 0);
            keep_box(build, room, 8, 1, 9, side, 6);
            pad_to(build, 4.0, float(cy) + 0.5, 0, 12.0, float(cy) + 0.5, 6);
            deck(build, self.long - 6, 1, self.long - 1, side, 12);
            pad_to(build, float(self.long - 9), float(cy) + 0.5, 6, float(self.long) - 3.0, float(cy) + 0.5, 12);
            keep_box(build, room, self.long - 6, cy - 1, self.long - 5, cy + 2, 12);
            keep_box(build, room, self.long - 6, side - 4, self.long - 5, side - 1, 12);
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(side) - 3.0, 12);
            build.foe(float(self.long) - 10.5, float(side) - 3.5, 6, BOUNCE_FOES.pick(dice, self.danger), 180.0, waits=guards);
        } else {
            build.solid(9, 1, lo, 17, 8, 4);
            build.solid(19, side - 8, lo, self.long - 1, side, 8);
            pad_to(build, 4.0, 4.5, 0, 11.0, 4.5, 4);
            keep_box(build, room, 6, 2, 7, 8, 0);
            keep_box(build, room, 9, 2, 10, 8, 4);
            pad_to(build, 14.0, 5.5, 4, 21.5, float(side) - 4.0, 8);
            keep_box(build, room, 16, 2, 17, 8, 4);
            keep_box(build, room, 19, side - 8, 20, side, 8);
            pit_fall(build, 7, 1, self.long - 1, side, lo, "The ground burns", guards);
            pad_to(build, 10.0, float(side) - 3.0, lo, 4.0, float(side) - 3.0, 0);
            keep_box(build, room, 6, side - 5, 7, side - 1, 0);
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(side) - 3.0, 8);
            build.foe(12.5, 3.5, 4, "monster_army", 0.0);
            build.foe(float(self.long) - 3.5, float(side) - 6.5, 8, BOUNCE_FOES.pick(dice, self.danger), 180.0, waits=guards);
            build.foe(14.0, float(side) - 3.0, 2, "monster_wizard", 0.0);
        }
        if taken is not None {
            closets(build, taken, side, 0, [2], [BOUNCE_FOES.pick(dice, self.danger, True)]);
        }
        if taken is not None {
            taken +>:Fires:+> guards;
            taken +>:Fires:+> build.summon(8, side + 1, 0, BOUNCE_FOES.pick(dice, self.danger), 3.5, float(cy) + 0.5, 0, 0.0);
        }
        build.foe(5.5, 2.5, 0, "monster_army", 0.0, waits=guards);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(15.0, 2.5, 4, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): platforms rising to the way out over a hurting
ground, a pad on each up to the next."""
node BounceExit(Prefab) {
    has key: str = "",
        zig: bool = False,
        long_pad: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bouncy exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM16;
        self.district = level_district(Q3DM16);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(22, 23);
        self.zig = dice.chance(0.5);
        self.long_pad = dice.chance(0.5);
        self.low = -11;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -10;
        mid = self.wide // 2;
        wall = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(room, 6);
        build.level(room, 12);
        build.widen(room, wall + 1, 1, lo, self.long - 1, self.wide - 1, 0);
        build.solid(wall + 1, 1, lo, 15, self.wide - 1, 0);
        # The middle platform in the middle, or over against the north wall.
        p0 = self.wide - 8 if self.zig else mid - 3;
        py = float(p0) + 3.5;
        build.solid(18, p0, lo, 26, p0 + 7, 6);
        build.solid(28, 1, lo, self.long - 1, self.wide - 1, 12);
        pad_to(build, 12.0, py, 0, 20.0, py, 6);
        keep_box(build, room, 14, p0 + 2, 15, p0 + 5, 0);
        keep_box(build, room, 18, p0 + 2, 19, p0 + 5, 6);
        pad_to(build, 23.0, py, 6, float(self.long) - 3.5, float(mid) + 3.5, 12);
        keep_box(build, room, 25, p0 + 1, 26, p0 + 6, 6);
        if self.long_pad {
            pad_to(build, 11.0, float(self.wide) - 3.0 if not self.zig else 6.0, 0, float(self.long) - 3.0, float(self.wide) - 3.0 if not self.zig else 3.0, 12);
        }
        keep_box(build, room, 28, mid - 2, 29, mid + 3, 12);
        build.way_out(float(self.long) - 3.0, float(mid) - 2.0, 12);
        guards = build.waiting();
        pit_fall(build, 15, 1, 28, self.wide - 1, lo, "The ground burns", guards);
        gy = float(self.wide) - 3.0 if not self.zig else 3.0;
        if not self.zig and self.long_pad {
            gy = 3.0;
        }
        pad_to(build, 18.0, gy, lo, 12.0, gy, 0);
        keep_box(build, room, 14, int(gy) - 2, 15, int(gy) + 2, 0);
        inside = build.touch(float(wall + 1), float(mid - 2), 0.0, float(wall + 3), float(mid + 2), 6.0);
        inside +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, 3.0, 12, BOUNCE_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(22.0, py - 2.0, 6, BOUNCE_FOES.pick(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, BOUNCE_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(21.0, float(self.wide) - 3.0, 4, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 12, Q3_HEALTH, "q3");
    }
}

"""q3dm16's stretches: [name, role]."""
glob Q3DM16_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["steps", "flow"],
         ["ring", "flow"],
         ["arena", "hub"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of q3dm16's stretches by its name."""
def make_q3dm16(name: str, key: str) -> Prefab {
    if name == "landing" {
        return BounceLanding();
    }
    if name == "steps" {
        return BounceSteps();
    }
    if name == "ring" {
        return BounceRing();
    }
    if name == "arena" {
        return BounceArena();
    }
    if name == "vault" {
        return BounceVault(key=key if key else "key_silver");
    }
    return BounceExit(key=key);
}
