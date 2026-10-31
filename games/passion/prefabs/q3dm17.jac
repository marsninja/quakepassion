"""Prefabs drawn from Quake III's q3dm17, The Longest Yard: decks and
islands floating in two tiers over a black void under the stars, thrown
between by jump pads, the railgun on a ledge high over everything, the
red armor on an island of its own. Quake III's arenas hold no foes of
their own; q3dm17's are wizard, army, hell_knight. Raised in q3dm17's own
palette. The sky stands far overhead and the void falls too far to reckon
on; its floor burns whoever falls, and teleporters on it send them back up
to where the stretch was entered. Long pads lead back over it.

- `YardBase`: the start. An end base floating over the void: a deck, a
  balcony over the way in with a stair up a side wall, and a pad from the
  deck's lip over the void to the outer platform (or to an island and on
  from it), and one back; from the balcony, by the seed, the yard's long pad
  throws a body right over the deck to the outer platform. Foes come out on
  the outer platform a moment after the player lands there.
- `LongestYard`: the runway. A long, thin deck out over the void between
  the near and far ledges, pads each way at both ends; by the seed a high
  deck crosses over the runway near its start (a pad from the near ledge up
  to it, drops from it back to the runway) with ways on at both its ends.
- `RailSpire`: a deck floating over the void, the railgun's ledge high
  over its far end; a pad throws a body straight up to the ledge (and, by
  the seed, another by way of a perch hung over the deck, or a teleporter
  does); a drop back down. Landing up there wakes what waits below.
- `BounceIsles`: islands bounced across pad to pad, rising as they zigzag
  over the void (three or four of them), the mega health on the last; by
  the seed a catwalk low along one wall under them and the far ledge, with
  a lift up through the ledge and a way on of its own. A teleporter on the
  far ledge leads back. The first bounce wakes the far ledge's guards.
- `YardHub`: the hub. The main yard's two tiers: a long deck over the
  void and a high bridge crossing over its middle, thrown up to by pads
  from both ends of the deck; the red armor's island off one side, a pad
  to it from the deck and one from it up to the bridge. Ways on from the
  deck's end and both ends of the bridge.
- `ArmorFloat`: the key room. The key on the highest of a climb of
  islands over the void, pad to pad (by the seed zigzagging left first or
  right), the last throw back to the top one hung high over the entry
  deck; taking the key opens closets on the
  deck below, and a teleporter takes the taker back down to them.
- `VoidPortal`: the end (or a gate, the door a key's). A hall, a deck out
  over the void, the way out on a floating dais thrown to by a pad; by
  the seed, stepping stones jumped up to the dais too."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, void_floor, throw, wake_later }
import from .q3open_parts { OPEN_AIR, VOID_DROP }

glob Q3DM17: str = "q3:q3dm17",
     Q3DM17_LIGHT: list[str] = ["monster_wizard", "monster_army"],
     Q3DM17_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for q3dm17's stretches."""
glob YARD_FOES: FoeMix = FoeMix(light=Q3DM17_LIGHT, strong=Q3DM17_HEAVY, heavy_light=Q3DM17_HEAVY, scale=0.5);

"""The start: an end base floating over the void, a balcony over the way
in, pads out over the void to the outer platform."""
node YardBase(Prefab) {
    has deep: int = 10,
        upper: int = 10,
        outer: int = 2,
        lip_x: int = 18,
        stair_side: int = 0,
        island: bool = False,
        long_pad: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Yard base";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.upper = dice.between(10, 11);
        self.island = dice.chance(0.5);
        self.long_pad = dice.chance(0.5);
        self.stair_side = dice.below(2);
        self.outer = [0, 2, 4][dice.below(3)];
        self.lip_x = 8 + self.upper;
        gap = 14 if self.island else dice.between(7, 8);
        self.long = self.lip_x + gap + 7;
        self.wide = dice.between(18, 20);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.tall = self.upper + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        side = 1 if self.stair_side == 0 else 3;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.outer), Port(face=side, along=4.0, floor=self.upper), Port(face=side, along=float(self.lip_x - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        py = float(middle) + 0.5;
        yard = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, self.upper, self.outer] {
            build.level(yard, z);
        }
        # The base's deck, and the balcony over the way in with its stair
        # up the side wall.
        deck(build, 1, 1, self.lip_x, self.wide - 1, 0, 3);
        deck(build, 1, 1, 7, self.wide - 1, self.upper, 2);
        sy = 1 if self.stair_side == 0 else self.wide - 4;
        stair(build, 6 + self.upper, sy, 0, 2, self.upper, 3);
        keep_box(build, yard, 6, sy, 7, sy + 3, self.upper);
        # The outer platform across the void, and the pads out to it.
        ox = self.long - 7;
        deck(build, ox, middle - 4, self.long - 1, middle + 5, self.outer, 3);
        lip = [self.lip_x - 1, middle - 1, self.lip_x, middle + 2];
        landing = [ox, middle - 2, ox + 1, middle + 3];
        # Each platform out over the void keeps a stretch of its side edge
        # unrailed: a way down into the void (and its teleporters back).
        keep_box(build, yard, ox + 2, middle - 4, ox + 5, middle - 3, self.outer);
        if self.island {
            ix = self.lip_x + 3;
            deck(build, ix, middle - 3, ix + 6, middle + 4, 2, 2);
            keep_box(build, yard, ix + 1, middle + 3, ix + 4, middle + 4, 2);
            throw(build, yard, float(self.lip_x) - 2.5, py, 0, float(ix) + 2.0, py, 2, lip, [ix, middle - 2, ix + 1, middle + 3]);
            throw(build, yard, float(ix) + 4.0, py, 2, float(ox) + 3.0, py, self.outer, [ix + 5, middle - 2, ix + 6, middle + 3], landing);
            build.foe(float(ix) + 2.5, py + 2.0, 2, YARD_FOES.pick(dice, self.danger), 180.0);
            build.supply(float(ix) + 1.5, py - 2.0, 2, "item_armor_shard", "q3");
        } else {
            throw(build, yard, float(self.lip_x) - 2.5, py, 0, float(ox) + 3.0, py, self.outer, lip, landing);
        }
        if self.long_pad {
            # The yard's long pad: from the balcony right over the deck.
            throw(build, yard, 3.5, py + 3.0, self.upper, float(self.long) - 3.0, py + 2.0, self.outer, [6, middle + 1, 7, middle + 5], [ox, middle + 1, ox + 1, middle + 5]);
        }
        # The pad back from the outer platform over the void to the deck.
        throw(build, yard, float(ox) + 3.0, py - 3.5, self.outer, float(self.lip_x) - 5.5, py - 3.5, 0, [ox, middle - 4, ox + 1, middle - 2], [self.lip_x - 1, middle - 4, self.lip_x, middle - 2]);
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, py, 0, 0.0);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(float(self.lip_x) - 4.5, py - 3.0, 0, "ammo_rockets", "q3");
        build.supply(3.0, float(self.wide) - 3.0, self.upper, Q3_ARMOR, "q3");
        build.foe(4.5, py - 4.0, self.upper, YARD_FOES.pick(dice, self.danger, True), 0.0);
        build.foe(float(self.lip_x) - 2.5, py + 4.0, 0, YARD_FOES.pick(dice, self.danger), 180.0);
        # Foes come out onto the outer platform a moment after the landing.
        landed = build.touch(float(ox), float(middle - 4), float(self.outer), float(ox + 3), float(middle + 5), float(self.outer + 6));
        out = wake_later(build, landed, 1.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, py - 3.0 + float(index) * 6.0, self.outer, YARD_FOES.pick(dice, self.danger), 180.0, waits=out);
        }
        build.foe(float(self.long) - 3.5, py, self.outer, YARD_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, py + 3.5, self.outer, Q3_HEALTH, "q3");
    }
}

"""The runway: a long, thin deck out over the void between two ledges, a
pad at each end; a high deck crossing over it, by the seed."""
node LongestYard(Prefab) {
    has deep: int = 10,
        lane: int = 6,
        run_z: int = 2,
        far_z: int = 2,
        cross: bool = False,
        cross_z: int = 11,
        cx: int = 19,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Longest yard";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(44, 48);
        self.wide = dice.between(18, 22);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.cross = dice.chance(0.5);
        self.run_z = [0, 2, 4][dice.below(3)];
        self.far_z = self.run_z + [0, 2][dice.below(2)];
        self.cross_z = self.run_z + dice.between(9, 10);
        self.lane = dice.between(3, self.wide - 8);
        self.cx = 19 + dice.between(0, 1);
        self.tall = max(self.cross_z, self.far_z) + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        if self.cross {
            self.leaves = [Port(face=0, along=middle, floor=self.far_z), Port(face=1, along=float(self.cx), floor=self.cross_z), Port(face=3, along=float(self.cx), floor=self.cross_z)];
        } else {
            self.leaves = [Port(face=0, along=middle, floor=self.far_z), Port(face=1, along=float(self.long - 3), floor=self.far_z), Port(face=3, along=float(self.long - 3), floor=self.far_z)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        ry = float(self.lane) + 2.5;
        yard = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, self.run_z, self.far_z] {
            build.level(yard, z);
        }
        # The near ledge, the runway and the far ledge.
        near = 9;
        r0 = 13;
        r1 = self.long - 13;
        far = self.long - 7;
        deck(build, 1, 1, near, self.wide - 1, 0, 3);
        deck(build, r0, self.lane, r1, self.lane + 5, self.run_z, 2);
        deck(build, far, 1, self.long - 1, self.wide - 1, self.far_z, 3);
        # Drops into the void off the runway's side and the far ledge's lip.
        keep_box(build, yard, r0 + 4, self.lane, r0 + 7, self.lane + 1, self.run_z);
        keep_box(build, yard, r1 - 7, self.lane + 4, r1 - 4, self.lane + 5, self.run_z);
        far_drop = 2 if self.lane > self.wide // 2 else self.wide - 5;
        keep_box(build, yard, far, far_drop, far + 1, far_drop + 3, self.far_z);
        throw(build, yard, float(near) - 2.5, ry, 0, float(r0) + 2.5, ry, self.run_z, [near - 1, self.lane, near, self.lane + 5], [r0, self.lane, r0 + 1, self.lane + 5]);
        throw(build, yard, float(r1) - 2.5, ry, self.run_z, float(far) + 3.0, ry, self.far_z, [r1 - 1, self.lane, r1, self.lane + 5], [far, self.lane, far + 1, self.lane + 5]);
        if self.cross {
            build.level(yard, self.cross_z);
            # The high deck across the runway, wall to wall; a pad from the
            # near ledge's corner up to it, and its edges over the runway
            # left open to drop back down.
            deck(build, self.cx - 2, 1, self.cx + 3, self.wide - 1, self.cross_z, 2);
            side_y = 3.0 if self.lane >= self.wide // 2 - 2 else float(self.wide) - 3.0;
            throw(build, yard, float(near) - 2.5, side_y, 0, float(self.cx) + 0.5, side_y, self.cross_z, [near - 1, int(side_y) - 1, near, int(side_y) + 2], [self.cx - 2, int(side_y) - 1, self.cx - 1, int(side_y) + 2]);
            keep_box(build, yard, self.cx - 2, self.lane + 1, self.cx - 1, self.lane + 4, self.cross_z);
            keep_box(build, yard, self.cx + 2, self.lane + 1, self.cx + 3, self.lane + 4, self.cross_z);
            build.foe(float(self.cx) + 0.5, float(self.wide) - side_y, self.cross_z, YARD_FOES.pick(dice, self.danger, True), 180.0);
            build.supply(float(self.cx) + 0.5, side_y + (2.0 if side_y < 5.0 else -2.0), self.cross_z, "weapon_rocketlauncher", "q3");
        }
        # The way back: a pad from the far ledge, beside the runway's line,
        # to the runway's end, and one along it to the near ledge.
        back_y = float(self.lane) + 6.5 if self.lane + 8 < self.wide else float(self.lane) - 1.5;
        back_lo = min(self.lane, int(back_y) - 1);
        back_hi = max(self.lane + 5, int(back_y) + 2);
        throw(build, yard, float(far) + 3.0, back_y, self.far_z, float(r1) - 6.0, ry, self.run_z, [far, back_lo, far + 1, back_hi], [r1 - 1, self.lane, r1, self.lane + 5]);
        throw(build, yard, float(r0) + 4.5, ry + 1.5, self.run_z, float(near) - 4.5, ry + 1.5, 0, [r0, self.lane, r0 + 1, self.lane + 5], [near - 1, self.lane, near, self.lane + 5]);
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, float(middle) + 0.5, 0, 0.0);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        mid = (self.cx + 4 + r1) // 2;
        build.supply(float(mid) + 0.5, ry, self.run_z, Q3_ARMOR, "q3");
        for index in range(dice.between(1, 2)) {
            build.foe(float(r1 - 4 - index * 6) + 0.5, ry + (1.0 if index % 2 == 0 else -1.0), self.run_z, YARD_FOES.pick(dice, self.danger), 180.0);
        }
        # Halfway along, what waits on the far ledge comes for the runner.
        halfway = build.touch(float(mid - 1), float(self.lane), float(self.run_z), float(mid + 1), float(self.lane + 5), float(self.run_z + 6));
        far_side = wake_later(build, halfway, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 2.5 + float(index) * float(self.wide - 5) / 2.0, self.far_z, YARD_FOES.pick(dice, self.danger, index == 0), 180.0, waits=far_side);
        }
        build.supply(float(self.long) - 3.5, float(middle) + 0.5, self.far_z, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, "ammo_shells", "q2");
    }
}

"""A deck floating over the void, the railgun's ledge high over its far
end, a pad straight up to it (and by way of a perch, or a teleporter)."""
node RailSpire(Prefab) {
    has deep: int = 10,
        rail: int = 16,
        perch: bool = False,
        tele: bool = False,
        side: int = 0,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rail spire";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 22);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.rail = dice.between(15, 18);
        self.perch = dice.chance(0.5);
        self.tele = dice.chance(0.5);
        self.side = dice.below(2);
        self.tall = self.rail + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        side = 1 if self.side == 0 else 3;
        self.leaves = [Port(face=0, along=middle, floor=self.rail), Port(face=side, along=float(self.long // 2 - 2), floor=0), Port(face=0, along=float(self.wide - 4) if self.side == 0 else 4.0, floor=self.rail)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        py = float(middle) + 0.5;
        spire = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(spire, 0);
        build.level(spire, self.rail);
        # The deck, the void open along both its sides; a walk from it to
        # the way on in the side wall.
        deck(build, 1, 3, self.long - 1, self.wide - 3, 0, 3);
        px = self.long // 2 - 2;
        if self.side == 0 {
            deck(build, px - 2, self.wide - 3, px + 2, self.wide - 1, 0, 3);
        } else {
            deck(build, px - 2, 1, px + 2, 3, 0, 3);
        }
        # The rail ledge across the far end, high over the deck.
        lx = self.long - 8;
        deck(build, lx, 1, self.long - 1, self.wide - 1, self.rail, 2);
        if self.perch {
            # Halfway up, a perch hung over the deck's side; pad to it, pad on.
            half = self.rail // 2;
            perch_y0 = self.wide - 8 if self.side == 1 else 2;
            deck(build, lx - 9, perch_y0, lx - 3, perch_y0 + 6, half, 2);
            keep_box(build, spire, lx - 4, perch_y0 + 1, lx - 3, perch_y0 + 4, half);
            build.level(spire, half);
            throw(build, spire, 7.5, float(perch_y0) + 3.0, 0, float(lx) - 7.0, float(perch_y0) + 3.0, half, None, [lx - 9, perch_y0, lx - 8, perch_y0 + 6]);
            throw(build, spire, float(lx) - 4.5, float(perch_y0) + 3.0, half, float(lx) + 3.0, float(perch_y0) + 3.0, self.rail, None, [lx, perch_y0, lx + 1, perch_y0 + 6]);
            build.foe(float(lx) - 6.0, float(perch_y0) + 5.0, half, YARD_FOES.pick(dice, self.danger), 180.0);
        }
        throw(build, spire, float(lx) - 9.0, py, 0, float(lx) + 3.5, py, self.rail, None, [lx, middle - 2, lx + 1, middle + 3]);
        if self.tele {
            build.teleporter(3.5, 4.5 if self.side == 0 else float(self.wide) - 4.5, 0, float(self.long) - 3.0, py, self.rail, 180.0);
        }
        # A drop off the ledge back down to the deck.
        keep_box(build, spire, lx, middle + 3, lx + 1, middle + 6, self.rail);
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, py, 0, 0.0);
        build.doorway(spire, self.enter);
        for port in self.taken {
            build.doorway(spire, port);
        }
        build.supply(float(self.long) - 3.0, py + 3.0, self.rail, "weapon_railgun", "q3");
        build.supply(float(self.long) - 3.0, py - 3.0, self.rail, "ammo_slugs", "q3");
        build.foe(float(self.long) - 2.5, 3.5, self.rail, YARD_FOES.pick(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 5) + 0.5, py + (3.0 if index % 2 == 0 else -3.0), 0, YARD_FOES.pick(dice, self.danger), 0.0);
        }
        # Landing up there wakes what waits on the deck below.
        top = build.touch(float(lx), 1.0, float(self.rail), float(lx + 5), float(self.wide - 1), float(self.rail + 6));
        below = wake_later(build, top, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(lx) - 3.5 + float(index), 4.5 + float(index) * 4.0, 0, YARD_FOES.pick(dice, self.danger, index == 0), 0.0, waits=below);
        }
        build.supply(float(lx) - 2.5, py, 0, Q3_HEALTH, "q3");
    }
}

"""Islands bounced across pad to pad, rising as they zigzag over the void,
and by the seed a catwalk low along one wall under them and the far ledge,
a lift from it up through the ledge."""
node BounceIsles(Prefab) {
    has deep: int = 10,
        isles: int = 3,
        first_side: int = 0,
        catwalk: bool = False,
        far_z: int = 9,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bounce isles";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.isles = dice.between(3, 4);
        self.long = 10 + 8 * self.isles + 8;
        self.wide = dice.between(20, 22);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.first_side = dice.below(2);
        self.catwalk = dice.chance(0.6);
        top = 7 + 2 * (self.isles - 1);
        self.far_z = top - [0, 4][dice.below(2)];
        self.tall = top + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.far_z), Port(face=1, along=float(self.long - 4), floor=self.far_z), Port(face=3, along=float(self.long - 4), floor=self.far_z)];
        if self.catwalk {
            self.leaves.append(Port(face=3 if self.first_side == 0 else 1, along=float(self.long // 2), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        isles = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(isles, 0);
        build.level(isles, self.far_z);
        near = 8;
        far = self.long - 8;
        deck(build, 1, 1, near, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, self.far_z, 3);
        # The isles, six cells square, a body landing on each's near half
        # and thrown on from its far half; no railing round them.
        spots: list[list[int]] = [];
        for index in range(self.isles) {
            x0 = 10 + 8 * index;
            y0 = 2 if (index + self.first_side) % 2 == 0 else self.wide - 8;
            z = 7 + 2 * index;
            deck(build, x0, y0, x0 + 6, y0 + 6, z, 2);
            keep_box(build, isles, x0, y0, x0 + 6, y0 + 6, z);
            build.level(isles, z);
            spots.append([x0, y0, z]);
        }
        first = spots[0];
        throw(build, isles, float(near) - 3.0, float(first[1]) + 3.0, 0, float(first[0]) + 1.5, float(first[1]) + 3.0, first[2], [near - 1, first[1] + 1, near, first[1] + 5], None);
        for index in range(self.isles - 1) {
            from_isle = spots[index];
            on = spots[index + 1];
            throw(build, isles, float(from_isle[0]) + 4.5, float(from_isle[1]) + 3.0, from_isle[2], float(on[0]) + 1.5, float(on[1]) + 3.0, on[2], None, None);
        }
        last = spots[-1];
        throw(build, isles, float(last[0]) + 4.5, float(last[1]) + 3.0, last[2], float(far) + 4.5, float(last[1]) + 3.0, self.far_z, None, [far, last[1], far + 1, last[1] + 6]);
        keep_box(build, isles, far, middle - 1, far + 1, middle + 2, self.far_z);
        # The way back: a teleporter on the far ledge, off the line from the
        # last bounce's landing to the ways on, to the near ledge.
        back_y = float(middle) + 3.5 if float(spots[-1][1]) + 3.0 < float(middle) else float(middle) - 3.0;
        build.teleporter(float(far) + 1.0, back_y, self.far_z, 3.5, float(middle) + 0.5, 0, 0.0);
        if self.catwalk {
            # The catwalk along the first isle's wall, under every other
            # isle and on under the far ledge, and a lift up through it.
            cy = 1 if self.first_side == 0 else self.wide - 4;
            deck(build, near, cy, far + 3, cy + 3, 0, 2);
            build.widen(isles, far, cy, self.far_z - 3, far + 3, cy + 3, self.far_z);
            lift(build, far, cy, far + 3, cy + 3, 0, self.far_z);
            keep_box(build, isles, far + 3, cy, far + 4, cy + 3, self.far_z);
            build.supply(float(near) + 6.0, float(cy) + 1.5, 0, "item_armor_shard", "q3");
            build.foe(float(far) - 6.5, float(cy) + 1.5, 0, YARD_FOES.pick(dice, self.danger), 180.0);
        }
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, float(middle) + 0.5, 0, 0.0);
        build.doorway(isles, self.enter);
        for port in self.taken {
            build.doorway(isles, port);
        }
        for (index, spot) in enumerate(spots) {
            if index % 2 == 1 {
                build.foe(float(spot[0]) + 3.0, float(spot[1]) + 1.5, spot[2], YARD_FOES.pick(dice, self.danger), 180.0);
            } else {
                build.supply(float(spot[0]) + 3.0, float(spot[1]) + 4.5, spot[2], "item_armor_shard", "q3");
            }
        }
        build.supply(float(last[0]) + 3.0, float(last[1]) + 1.5, last[2], "item_health_mega", "q3");
        # The first bounce wakes the far ledge's guards a moment on.
        bounced = build.touch(float(first[0]), float(first[1]), float(first[2]), float(first[0] + 6), float(first[1] + 6), float(first[2] + 6));
        guards = wake_later(build, bounced, 2.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, self.far_z, YARD_FOES.pick(dice, self.danger, index == 1), 180.0, waits=guards);
        }
        build.supply(float(self.long) - 3.5, float(middle) + 0.5, self.far_z, Q3_HEALTH, "q3");
    }
}

"""The hub: a long deck over the void, a high bridge crossing its middle
thrown up to from both its ends, the red armor's island off one side."""
node YardHub(Prefab) {
    has deep: int = 10,
        bridge: int = 11,
        cx: int = 17,
        island_side: int = 0,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Yard hub";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(34, 38);
        self.wide = dice.between(30, 32);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.bridge = dice.between(10, 12);
        self.cx = self.long // 2 + dice.between(-2, 2);
        self.island_side = dice.below(2);
        self.tall = self.bridge + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.cx) + 0.5, floor=self.bridge), Port(face=3, along=float(self.cx) + 0.5, floor=self.bridge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        py = float(middle) + 0.5;
        cx = self.cx;
        hub = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hub, 0);
        build.level(hub, self.bridge);
        # The long deck, the void either side of it.
        d0 = middle - 5;
        d1 = middle + 5;
        deck(build, 1, d0, self.long - 1, d1, 0, 3);
        # The high bridge across its middle, wall to wall, and the pads up
        # to it from both ends of the deck.
        deck(build, cx - 3, 1, cx + 4, self.wide - 1, self.bridge, 2);
        throw(build, hub, float(cx) - 8.0, py, 0, float(cx) + 0.5, py, self.bridge, None, [cx - 3, middle - 2, cx - 2, middle + 3]);
        throw(build, hub, float(cx) + 9.0, py, 0, float(cx) + 0.5, py, self.bridge, None, [cx + 3, middle - 2, cx + 4, middle + 3]);
        # The red armor's island off one side, beside the bridge: a pad to
        # it from the deck's edge, and one from it up to the bridge.
        if self.island_side == 0 {
            iy0 = 2;
            iy1 = d0 - 3;
            lip_y = d0;
            land_y = iy1 - 1;
        } else {
            iy0 = d1 + 3;
            iy1 = self.wide - 2;
            lip_y = d1 - 1;
            land_y = iy0;
        }
        iz = dice.between(3, 5);
        ix0 = cx + 7;
        ix1 = cx + 13;
        build.level(hub, iz);
        deck(build, ix0, iy0, ix1, iy1, iz, 2);
        iy = float(iy0 + iy1) * 0.5;
        toward = 1.0 if self.island_side == 1 else -1.0;
        throw(build, hub, float(ix0) + 4.0, float(lip_y) + 0.5 - toward * 2.5, 0, float(ix0) + 4.0, iy, iz, [ix0 + 1, lip_y, ix0 + 5, lip_y + 1], [ix0 + 1, land_y, ix0 + 5, land_y + 1]);
        throw(build, hub, float(ix1) - 2.0, iy, iz, float(cx) + 0.5, iy, self.bridge, [ix0, iy0, ix0 + 1, iy1], [cx + 3, iy0, cx + 4, iy1]);
        build.supply(float(ix1) - 2.0, iy + toward * 1.5, iz, "item_armor_body", "q3");
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, py, 0, 0.0);
        build.doorway(hub, self.enter);
        for port in self.taken {
            build.doorway(hub, port);
        }
        # A guard walks the deck's length; others hold the bridge.
        build.foe(5.5, py + 3.0, 0, YARD_FOES.pick(dice, self.danger), 0.0, patrol=[[5.5, py + 3.0], [float(self.long) - 4.5, py + 3.0], [float(self.long) - 4.5, py - 3.0], [5.5, py - 3.0]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 0.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, self.bridge, YARD_FOES.pick(dice, self.danger, index == 1), 90.0);
        }
        build.foe(float(self.long) - 4.5, py, 0, YARD_FOES.pick(dice, self.danger), 180.0);
        # Taking to the armor's island wakes what waits at the deck's end.
        isle = build.touch(float(ix0), float(iy0), float(iz), float(ix1), float(iy1), float(iz + 6));
        ends = wake_later(build, isle, 2.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, py + 3.0 - float(index) * 6.0, 0, YARD_FOES.pick(dice, self.danger, True), 180.0, waits=ends);
        }
        build.supply(float(cx) + 0.5, py, 0, Q3_HEALTH, "q3");
        build.supply(4.0, py - 3.0, 0, "ammo_shells", "q2");
        build.supply(float(cx) - 1.5, py + 3.5, self.bridge, "ammo_rockets", "q3");
    }
}

"""The key room: the key on the highest of a climb of islands over the
void, pad to pad; taking it opens closets on the entry deck."""
node ArmorFloat(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        deep: int = 10,
        first: int = 0,
        over: bool = False,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Armor float (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(28, 30);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.deep = VOID_DROP + dice.between(0, 2);
        self.first = dice.below(2);
        self.over = dice.chance(0.5);
        self.tall = 13 + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        middle = side // 2;
        low = -self.deep;
        room = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.doorway(room, self.enter);
        # The entry deck, its closets in the side wall.
        dx = 12;
        deck(build, 1, 1, dx, side, 0, 3);
        # The climb: two islands zigzagging over the void, then the key's.
        ya = 2 if self.first == 0 else side - 8;
        yb = side - 8 if self.first == 0 else 2;
        a0 = dx + 3;
        deck(build, a0, ya, a0 + 6, ya + 6, 4, 2);
        b0 = self.long - 8;
        deck(build, b0, yb, self.long - 1, yb + 6, 8, 2);
        # The key's island hangs high over the entry deck, on the second
        # island's side, nearer the way in or the void.
        k0 = 3 if self.over else 5;
        ky = yb;
        kz = 12 if self.over else 13;
        deck(build, k0, ky, k0 + 6, ky + 6, kz, 2);
        for z in [0, 4, 8, kz] {
            build.level(room, z);
        }
        throw(build, room, float(dx) - 3.0, float(ya) + 3.0, 0, float(a0) + 2.0, float(ya) + 3.0, 4, [dx - 1, ya + 1, dx, ya + 5], [a0, ya + 1, a0 + 1, ya + 5]);
        throw(build, room, float(a0) + 3.0, float(ya) + 3.0, 4, float(b0) + 3.5, float(yb) + 3.0, 8, None, [b0, yb, b0 + 1, yb + 6]);
        facing = yb if yb > ya else yb + 5;
        keep_box(build, room, b0, facing, self.long - 1, facing + 1, 8);
        throw(build, room, float(b0) + 3.5, float(yb) + 3.0, 8, float(k0) + 3.0, float(ky) + 3.0, kz, None, [k0, ky, k0 + 6, ky + 6]);
        # From the key's island a teleporter back down to the entry deck.
        build.teleporter(float(k0) + 4.5, float(ky) + 4.5, kz, 4.0, float(middle) + 0.5, 0, 0.0);
        void_floor(build, 1, 1, self.long - 1, side, low, 4.0, float(middle) + 0.5, 0, 0.0);
        key_ambush(build, self.key, float(k0) + 2.0, float(ky) + 2.0, kz, side, 0, [2, 7], [YARD_FOES.pick(dice, self.danger, True), YARD_FOES.pick(dice, self.danger)]);
        build.foe(float(b0) + 5.5, float(yb) + 4.5, 8, YARD_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(a0) + 4.5, float(ya) + 1.5, 4, YARD_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(b0) + 1.5, float(yb) + 1.5, 8, "item_armor_shard", "q3");
    }
}

"""The end (or a gate): a hall, a deck out over the void, the way out on a
floating dais thrown to by a pad, stepping stones up to it too."""
node VoidPortal(Prefab) {
    has key: str = "",
        deep: int = 10,
        dais: int = 5,
        stones: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void portal" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM17;
        self.district = level_district(Q3DM17);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.deep = VOID_DROP + dice.between(0, 2);
        self.dais = dice.between(4, 6);
        self.stones = dice.chance(0.5);
        self.tall = self.dais + OPEN_AIR;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -self.deep;
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        void = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, self.dais);
        build.doorway(hall, self.enter);
        build.widen(void, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The deck out over the void, the dais across it.
        ex = wall + 8;
        deck(build, wall + 1, 1, ex, self.wide - 1, 0, 3);
        dx = self.long - 9;
        deck(build, dx, middle - 4, self.long - 1, middle + 5, self.dais, 2);
        throw(build, void, float(ex) - 2.5, py, 0, float(dx) + 3.5, py, self.dais, [ex - 1, middle - 1, ex, middle + 2], [dx, middle - 1, dx + 1, middle + 2]);
        if self.stones {
            # Stepping stones up to the dais's side, a short jump each.
            sy = 2 if dice.chance(0.5) else self.wide - 5;
            count = (dx - 1 - ex) // 3;
            for index in range(count) {
                x0 = ex + 1 + index * 3;
                deck(build, x0, sy, x0 + 2, sy + 3, (index + 1) * self.dais // (count + 1), 2);
            }
            deck(build, dx, sy, dx + 3, middle - 4 if sy < middle else self.wide - 2, self.dais, 2);
            build.supply(float(ex + 3 * count) - 1.0, float(sy) + 1.5, count * self.dais // (count + 1), Q3_ARMOR, "q3");
        }
        build.way_out(float(self.long) - 4.0, py, self.dais);
        void_floor(build, wall + 1, 1, self.long - 1, self.wide - 1, low, float(wall) + 3.0, py, 0, 0.0);
        # Through the door, what holds the dais comes on.
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(dx) + 2.5 + float(index % 2) * 2.0, py - 3.0 + float(index) * 3.0, self.dais, YARD_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, YARD_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(ex) - 2.0, 2.5, 0, "item_health_mega", "q3");
    }
}

"""q3dm17's stretches: [name, role]."""
glob Q3DM17_STRETCHES: list[list[str]] = [
         ["base", "start"],
         ["yard", "flow"],
         ["spire", "flow"],
         ["isles", "flow"],
         ["hub", "hub"],
         ["float", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm17's stretches by its name."""
def make_q3dm17(name: str, key: str) -> Prefab {
    if name == "base" {
        return YardBase();
    }
    if name == "yard" {
        return LongestYard();
    }
    if name == "spire" {
        return RailSpire();
    }
    if name == "isles" {
        return BounceIsles();
    }
    if name == "hub" {
        return YardHub();
    }
    if name == "float" {
        return ArmorFloat(key=key if key else "key_silver");
    }
    return VoidPortal(key=key);
}
