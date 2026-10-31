"""Prefabs drawn from Quake II's jail3, the Security Complex high in the
mountains: a checkpoint barred by yellow lasers, ledges switching back up
a cliff under the sky, a core of two rings of walkways round a shaft, the
security pyramid whose control opens its chamber, a tram shaft with a
stair winding round it, the key in a cage a button opens. Raised in
jail3's own palette.

- `Checkpoint`: the start. A hall, a booth raised by one wall up steps, a
  barrier across the far end whose gate is barred by lasers (or shut) until
  the booth's console is used; a walkway along the far wall over the floor;
  pipes drip; guards appear beyond the barrier as it opens.
- `CliffRamps`: a cliff under the sky climbed by ramps switching back along
  its ledges, an overhang over the floor at the top to drop from, a lift
  now and then; a cave in the cliff's foot breaks open on a stash; snipers
  appear on the ledges as the player starts up.
- `ComplexCore`: a shaft through a room down to a pit, a walkway round it
  on the floor and a ring high up, both shut across by bulkheads with gates
  over sills, stairs (or a lift) between; pipes drip, a vent in the pit breaks
  open on a stash; guards appear on the ring. Ways on from both (a hub).
- `SecurityPyramid`: a stepped pyramid in a hall, a stair cut up its face
  to the control on its top, which opens its chamber below; inside, the
  switch that opens the ways out. Guards appear on the tiers.
- `TramShaft`: a deep shaft, a tram riding up and down its middle and a
  stair winding round its walls to a landing at the top; what waits below
  wakes as the player reaches the top.
- `ButtonCage`: the key room. The key on a dais in a cage, a button on the
  wall (or a shot one high up) that raises its gate; taking the key opens
  the closets and switches on lasers.
- `ComplexExit`: the end. A door (a key's, as a gate) out onto the mountain
  under the sky: three lanes between ribs of rock, along the middle one to its
  far end, back up the second by a stair or a lift called down, over the
  middle one by a bridge and up the third to the way out on a landing."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, spiral, ring_landing }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, stash, keep_row, called_lift, closets, post_button, laser, laser_grid, bars, drip }
import from .q2walls_parts { partition, gate_yard }

glob JAIL3: str = "q2:jail3";

"""jail3's foes: infantry and gunners, flyers in the open, gladiators and
a tank deeper in."""
glob JAIL3_FOES: FoeMix = FoeMix(light=["monster_infantry", "monster_gunner", "monster_soldier_ss"], strong=["monster_gladiator"], heavy_light=["monster_gunner", "monster_gladiator"], heavy_strong=["monster_tank"], heavy_scale=0.5, flying="monster_flyer");


"""The start: a hall, a booth raised by one wall, a barrier across its far
end barred by lasers."""
node Checkpoint(Prefab) {
    has booth: int = 4,
        walk: int = 8,
        lasers: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Checkpoint";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(26, 29);
        self.wide = dice.between(19, 21);
        self.booth = dice.between(3, 4);
        self.lasers = dice.chance(0.6);
        self.tall = self.walk + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=1, along=float(self.long - 12), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.booth);
        build.level(hall, self.walk);
        # The booth along the south wall up steps, a parapet along its edge,
        # a console at its far end.
        b = self.booth;
        build.solid(6, 1, 0, 13, 6, b);
        stair(build, 6 - b, 1, 0, 0, b, 3);
        build.solid(7, 5, b, 11, 6, b + 2);
        build.solid(12, 2, b, 13, 5, b + 2);
        # The barrier across the far end, its gate in the middle.
        bx = self.long - 8;
        build.solid(bx, 1, 0, bx + 1, self.wide - 1, self.tall);
        build.widen(hall, bx, middle - 2, 1, bx + 1, middle + 2, 8);
        # The walkway along the north wall over the floor, up a stair at the
        # near end, to the barrier.
        build.solid(2 + self.walk, self.wide - 5, self.walk - 1, bx, self.wide - 1, self.walk);
        stair(build, 2, self.wide - 4, 0, 0, self.walk, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The booth's console: lasers across the barrier's gate it shuts
        # off, or a gate it raises.
        press = build.push(12.0, 3.5, float(b) + 0.5, 2);
        if self.lasers {
            for height in [1.5, 3.0, 4.5, 6.0] {
                press +>:Fires:+> laser(build, float(bx) + 0.5, float(middle - 2) + 0.2, height, 1);
            }
            build.touch(float(bx - 3), float(middle - 3), 0.0, float(bx - 1), float(middle + 3), 6.0, False, "Yellow lasers still activated");
        } else {
            press +>:Fires:+> build.opened(float(bx), float(middle - 2), 1.0, float(bx + 1), float(middle + 2), 8.0);
            build.touch(float(bx - 3), float(middle - 3), 0.0, float(bx - 1), float(middle + 3), 6.0, True, "The gate is worked from the booth");
        }
        press +>:Fires:+> build.objective("Proceed to the security pyramid");
        guards(build, press, [[float(bx) + 3.5, float(middle) + 3.5], [float(bx) + 3.5, float(middle) - 3.5]], 0, JAIL3_FOES.squad(dice, self.danger, 2, True), 180.0);
        auto_shutters(build, dice, self, self.taken, 0.5);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Find the security pass and get it past the checkpoint");
        # Up the booth's steps, guards appear on the walkway.
        steps = build.touch(float(6 - b), 1.0, 0.0, 6.0, 4.0, 6.0);
        guards(build, steps, [[float(bx) - 2.5, float(self.wide) - 3.0], [float(bx) - 7.5, float(self.wide) - 3.0]], self.walk, JAIL3_FOES.squad(dice, self.danger, 2), 270.0);
        build.foe(10.5, 3.5, b, JAIL3_FOES.pick(dice, self.danger), 90.0);
        build.foe(8.5, float(middle) + 2.5, 0, "monster_infantry", 0.0, patrol=[[8.5, float(middle) + 2.5], [float(bx) - 2.5, float(middle) + 2.5]]);
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, JAIL3_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(bx) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        for x in [9.5, 16.5, float(bx) - 1.5] {
            drip(build, x, float(middle) + 0.5, float(self.tall) - 0.5, 2.0 + x * 0.1);
        }
    }
}

"""A cliff under the sky climbed by ramps switching back along its
ledges, an overhang at the top."""
node CliffRamps(Prefab) {
    has flight: int = 6,
        by_lift: bool = False,
        cave: bool = True,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cliff ramps";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(23, 26);
        self.wide = dice.between(18, 20);
        self.flight = dice.between(5, 6);
        self.by_lift = dice.chance(0.4);
        self.cave = dice.chance(0.6);
        self.tall = 3 * self.flight + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [
            Port(face=2, along=float(self.wide - 3), floor=3 * self.flight),
            Port(face=1, along=float(self.long // 2), floor=3 * self.flight),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.flight;
        cliff = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [f, 2 * f, 3 * f] {
            build.level(cliff, z);
        }
        # Three ledges stepping back up the cliff (the north wall), each a
        # band deeper than the one below; a ramp up to each from the one
        # below, switching back.
        bands = [self.wide - 10, self.wide - 7, self.wide - 4];
        for (index, y0) in enumerate(bands) {
            build.solid(1, y0, 0, self.long - 1, self.wide - 1, (index + 1) * f);
        }
        stair(build, self.long - 2 - f, bands[0] - 3, 0, 0, f, 3);
        stair(build, f + 1, bands[0], f, 2, f, 3);
        stair(build, self.long - 2 - f, bands[1], 2 * f, 0, f, 3);
        for x in range(self.long - 5, self.long - 1) {
            build.keep(cliff, x, bands[0], f);
        }
        # The overhang: the top ledge thrust out over the floor at the near
        # end, its edge to drop from.
        top = 3 * f;
        build.solid(1, bands[0] - 4, top - 1, 7, bands[2], top);
        for x in range(2, 6) {
            build.keep(cliff, x, bands[0] - 4, top);
        }
        # Now and then a lift from the floor to a deck by the overhang,
        # called down.
        if self.by_lift {
            post_button(build, 8, bands[0] - 7, 0, 3) +>:Fires:+> called_lift(build, 8, bands[0] - 6, 11, bands[0] - 3, 0, top);
            build.solid(7, bands[0] - 3, top - 1, 11, bands[0], top);
            keep_row(build, cliff, 7, bands[0] - 3, top, 1, 5);
        }
        # A cave in the cliff's foot behind rock that breaks: a stash.
        if self.cave {
            stash(build, 12, bands[0] + 1, 15, bands[0] + 3, 0, 3, Q2_ARMOR, "q2");
        }
        build.doorway(cliff, self.enter);
        for port in self.taken {
            build.doorway(cliff, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.4);
        # Starting up, snipers appear on the ledges.
        start_up = build.touch(float(self.long - 2 - f), float(bands[0] - 3), 0.0, float(self.long - f), float(bands[0]), 6.0);
        guards(build, start_up, [[float(self.long) - 4.5, float(bands[0]) + 1.5], [float(self.long) - 8.5, float(bands[0]) + 1.5]], f, JAIL3_FOES.squad(dice, self.danger, 2), 270.0);
        guards(build, start_up, [[4.5, float(bands[1]) + 1.5]], 2 * f, JAIL3_FOES.squad(dice, self.danger, 1, True), 270.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, top, "monster_infantry", 0.0, patrol=[[8.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 5) + 0.5, 4.5, 0, JAIL3_FOES.pick(dice, self.danger), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, 14, JAIL3_FOES.pick(dice, self.danger, False, True), 90.0);
        build.supply(3.5, float(bands[0]) - 2.5, top, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A shaft through a room down to a pit, a walkway round it on the floor
and a ring high up, stairs between."""
node ComplexCore(Prefab) {
    has upper: int = 8,
        east_lift: bool = False,
        vent: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Complex core";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.upper = dice.between(8, 9);
        self.east_lift = dice.chance(0.4);
        self.vent = dice.chance(0.6);
        self.tall = self.upper + 16;
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        core = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(core, self.upper);
        # The shaft in the middle, a pit far down with a floor, a stair down
        # its side.
        build.widen(core, cx - 4, cy - 4, -7, cx + 4, cy + 4, 0);
        build.solid(cx - 4, cy - 4, -7, cx + 4, cy + 4, -6);
        stair(build, cx - 4, cy + 3, -6, 3, 6, 2);
        # A vent in the pit's wall behind a grate that breaks: a stash.
        if self.vent {
            stash(build, cx + 5, cy - 1, cx + 7, cy + 1, -6, 2, "ammo_cells", "q2");
        }
        # The upper ring: a walkway five cells wide round the walls.
        under = self.upper - 1;
        build.solid(1, 1, under, self.long - 1, 6, self.upper);
        build.solid(1, self.wide - 6, under, self.long - 1, self.wide - 1, self.upper);
        build.solid(1, 6, under, 6, self.wide - 6, self.upper);
        build.solid(self.long - 6, 6, under, self.long - 1, self.wide - 6, self.upper);
        # Up to it: a stair on the west along the walkway's inner edge, and
        # on the east another stair or a lift called down.
        stair(build, 6, 6 + self.upper, 0, 3, self.upper, 3);
        if self.east_lift {
            post_button(build, self.long - 10, self.wide - 11, 0, 3) +>:Fires:+> called_lift(build, self.long - 9, self.wide - 9, self.long - 6, self.wide - 6, 0, self.upper);
            keep_row(build, core, self.long - 10, self.wide - 6, self.upper, 1, 5);
        } else {
            stair(build, self.long - 9, self.wide - 7 - self.upper, 0, 1, self.upper, 3);
        }
        # Bulkheads across the floor's walkway, and across the ring over it,
        # each with a gate over a sill.
        partition(build, core, cx, 1, cx + 1, cy - 4, 0, self.upper - 1, [[2, 5]]);
        partition(build, core, cx, cy + 4, cx + 1, self.wide - 1, 0, self.upper - 1, [[self.wide - 5, self.wide - 2]]);
        partition(build, core, cx + 4, 1, cx + 5, 6, self.upper, self.upper + 8, [[2, 5]]);
        partition(build, core, cx - 5, self.wide - 6, cx - 4, self.wide - 1, self.upper, self.upper + 8, [[self.wide - 5, self.wide - 2]]);
        build.doorway(core, self.enter);
        for port in self.taken {
            build.doorway(core, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Coming to the shaft's rim, guards appear on the ring; pipes drip
        # into the pit.
        rim = build.touch(float(cx - 6), float(cy - 6), 0.0, float(cx - 4), float(cy + 6), 6.0);
        guards(build, rim, [[float(cx) + 0.5, 3.5], [float(cx) + 0.5, float(self.wide) - 3.5], [float(self.long) - 3.5, float(cy) + 0.5]], self.upper, JAIL3_FOES.squad(dice, self.danger, 3, True), 180.0);
        for spot in [[cx - 2, cy - 2], [cx + 2, cy + 1], [cx - 1, cy + 2]] {
            drip(build, float(spot[0]) + 0.5, float(spot[1]) + 0.5, float(self.tall) - 0.5, 2.0 + float(spot[0] % 3));
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, float(cy - 3 + index * 3) + 0.5, 0, JAIL3_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 0.5, float(cy) - 2.5, -6, JAIL3_FOES.pick(dice, self.danger, True), 90.0);
        build.foe(3.5, 3.5, self.upper, "monster_infantry", 0.0, patrol=[[3.5, 3.5], [float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5], [3.5, float(self.wide) - 3.5]]);
        build.supply(float(cx) + 2.5, float(cy) - 2.5, -6, Q2_HEALTH, "q2");
        build.supply(3.5, float(self.wide) - 3.5, self.upper, Q2_ARMOR, "q2");
    }
}

"""A stepped pyramid in a hall, a stair cut up its face to the control on
its top, its chamber below."""
node SecurityPyramid(Prefab) {
    has tier: int = 2,
        tiers: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security pyramid";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(31, 34);
        self.wide = dice.between(26, 28);
        self.tiers = dice.between(3, 4);
        self.tall = self.tiers * self.tier + 18;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        h = self.tier;
        top = self.tiers * h;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, top);
        # The pyramid: three or four tiers, each two cells in from the one
        # under it.
        for k in range(self.tiers) {
            half = 9 - 2 * k;
            build.solid(cx - half, cy - half, k * h, cx + half, cy + half, (k + 1) * h);
        }
        # A stair up its near face from the floor to the top, cut into the
        # tiers, each step three lifts thick.
        crown = 9 - 2 * (self.tiers - 1);
        sx = cx - crown - top + 1;
        for step in range(top) {
            x = sx + step;
            build.widen(hall, x, cy - 1, step + 1, x + 1, cy + 2, step + 7);
            build.solid(x, cy - 1, max(0, step - 2), x + 1, cy + 2, step + 1);
        }
        # Its chamber: a room inside under the upper tiers east of the stair,
        # its door on the far face.
        chamber = build.room(cx - 1, cy - 3, 0, cx + 5, cy + 3, 2 * h + 1);
        build.widen(chamber, cx + 5, cy - 2, 0, cx + 9, cy + 2, 2 * h);
        door = build.opened(float(cx + 8), float(cy - 2), 0.0, float(cx + 9), float(cy + 2), float(2 * h));
        # The control on the top: a console whose button opens the chamber.
        build.solid(cx + 1, cy - 1, top, cx + 2, cy + 2, top + 2);
        press = build.push(float(cx + 1), float(cy) + 0.5, float(top) + 0.6, 2);
        press +>:Fires:+> door;
        press +>:Fires:+> build.objective("Control pyramid open");
        build.touch(float(cx + 9), float(cy - 3), 0.0, float(cx + 11), float(cy + 3), 6.0, True, "The chamber is opened from the pyramid's top");
        # In the chamber, the switch that opens the ways out.
        inner = build.push(float(cx) + 2.5, float(cy - 3), 1.0, 1);
        for port in self.taken {
            inner +>:Fires:+> shutter(build, self, port);
        }
        build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(self.wide - 1), 6.0, True, "This door is opened elsewhere");
        # Pipes laid across the aisles either side of the pyramid, stepped
        # over.
        build.solid(cx, 1, 0, cx + 1, cy - 9, 1);
        build.solid(cx, cy + 9, 0, cx + 1, self.wide - 1, 1);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Climbing, guards appear on the tiers; opening the chamber, more
        # behind the pyramid.
        climbing = build.touch(float(sx), float(cy - 1), 0.0, float(sx + 2), float(cy + 2), 6.0);
        guards(build, climbing, [[float(cx) - 6.5, float(cy) - 6.5], [float(cx) + 6.5, float(cy) + 6.5]], 2 * h, JAIL3_FOES.squad(dice, self.danger, 2), 180.0);
        guards(build, press, [[float(self.long) - 4.5, float(cy) - 4.5], [float(self.long) - 4.5, float(cy) + 4.5]], 0, JAIL3_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(float(cx) + 3.5, float(cy) + 1.5, 0, JAIL3_FOES.pick(dice, self.danger, True), 0.0);
        build.foe(4.5, 3.5, 0, "monster_infantry", 0.0, patrol=[[4.5, 3.5], [float(self.long) - 4.5, 3.5], [float(self.long) - 4.5, float(self.wide) - 3.5], [4.5, float(self.wide) - 3.5]]);
        build.foe(float(cx) - 8.0, float(cy) + 6.5, h, JAIL3_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(cx) + 1.5, float(cy) - 1.5, 0, Q2_ARMOR, "q2");
        build.supply(float(cx) - 0.5, float(cy) + 2.5, top, Q2_HEALTH, "q2");
        for spot in [[cx - 7, 3], [cx + 7, self.wide - 4]] {
            sparking(build, float(spot[0]) + 0.5, float(spot[1]) + 0.5, float(self.tall) - 1.0, 3, 3.0);
        }
    }
}

"""A deep shaft, a tram riding its middle, a stair winding round its
walls to a landing at the top."""
node TramShaft(Prefab) {
    has climb: int = 13,
        box: int = 12,
        tall: int = 20,
        landing: list[float] = [];

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tram shaft";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.box = 12;
        self.climb = dice.between(12, 14);
        self.long = self.box + 8;
        self.wide = self.box + 4;
        self.tall = self.climb + 8;
        self.low = -2;
        self.high = self.tall + 1;
        # Where the winding stair lands at the top: on the ring's east side,
        # a deck from there to the east wall.
        self.landing = ring_landing(2, 2, 2 + self.box, 2 + self.box, 3, self.climb, 4);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        if self.landing and int(self.landing[0]) == 0 {
            self.leaves.append(Port(face=0, along=float(int(self.landing[1])), floor=self.climb));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        b = self.box;
        cx = 2 + b // 2;
        cy = 2 + b // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.climb);
        # The stair winding up the inside walls of the shaft's square, from
        # its near corner, to a landing at the top; a deck on from it.
        spiral(build, 2, 2, 2 + b, 2 + b, 0, self.climb, 3, 4, 0);
        if self.landing and int(self.landing[0]) == 0 {
            along = int(self.landing[1]);
            build.solid(2 + b, along - 2, self.climb - 1, self.long - 1, along + 2, self.climb);
        }
        # The tram riding up and down the middle.
        build.train([4.0, 4.0, 1.0], [[float(cx - 2), float(cy - 2), -1.0], [float(cx - 2), float(cy - 2), float(self.climb - 1)]], 70.0, 3.0);
        build.room(cx - 2, cy - 2, -1, cx + 2, cy + 2, 0);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        auto_shutters(build, dice, self, [port for port in self.taken if port.floor == 0], 0.5);
        # Reaching the top, guards below wake and come.
        topped = build.touch(float(2 + b - 3), 2.0, float(self.climb), float(2 + b), float(2 + b), float(self.climb + 6));
        guards(build, topped, [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]], 0, JAIL3_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(float(self.long) - 4.5, float(cy) + 0.5, 0, JAIL3_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(cx) + 3.5, float(cy) + 3.5, 0, "monster_infantry", 0.0, patrol=[[float(cx) + 3.5, float(cy) + 3.5], [float(cx) - 2.5, float(cy) + 3.5]]);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.climb + 3, JAIL3_FOES.pick(dice, self.danger, False, True), 0.0);
        build.supply(float(self.long) - 3.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        for spot in [[cx - 1, cy + 1], [cx + 1, cy - 1]] {
            drip(build, float(spot[0]) + 0.5, float(spot[1]) + 0.5, float(self.tall) - 0.5, 2.5);
        }
    }
}

"""The key room: the key on a dais in a cage of bars, a button that opens
it."""
node ButtonCage(Prefab) {
    has key: str = "key_silver",
        shot: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Button cage (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(22, 25);
        self.wide = dice.between(22, 24);
        self.shot = dice.chance(0.4);
        self.tall = dice.between(13, 15);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide + 4) // 2 - 1), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = 4;
        middle = (self.wide + 4) // 2 - 1;
        room = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(room, self.enter);
        # The dais at the far end, the cage of bars round a pedestal on it,
        # the key on the pedestal; a button on the side wall (or a shot one
        # high on the far wall) opens the cage.
        dx = self.long - 8;
        build.solid(dx, middle - 3, 0, dx + 6, middle + 4, 2);
        stair(build, dx - 2, middle - 1, 0, 0, 2, 3);
        build.solid(dx + 2, middle - 1, 2, dx + 4, middle + 2, 3);
        # The cage: bars on three sides that do not open, a gate of bars
        # across its front that rises.
        build.solid(dx + 4, middle - 2, 2, dx + 5, middle + 3, 7);
        build.solid(dx + 2, middle - 2, 2, dx + 4, middle - 1, 7);
        build.solid(dx + 2, middle + 2, 2, dx + 4, middle + 3, 7);
        sides = [build.opened(float(dx + 1), float(middle - 2), 2.0, float(dx + 2), float(middle + 3), 7.0)];
        if self.shot {
            press = build.push(float(self.long - 1), float(middle) + 0.5, 9.0, 2, True);
        } else {
            press = build.push(float(dx) - 3.5, float(self.wide - 1), 1.3, 3);
        }
        for cage in sides {
            press +>:Fires:+> cage;
        }
        build.touch(float(dx - 3), float(middle - 3), 0.0, float(dx - 1), float(middle + 4), 6.0, True, "The cage is worked from elsewhere");
        taken = key_cue(build, self.key, float(dx) + 3.0, float(middle) + 0.5, 3);
        closets(build, taken, [3, 8, 13] if dice.chance(0.5) else [4, 11], side, -1, 0, JAIL3_FOES.squad(dice, self.danger, 3, True), 90.0);
        for x in [6.5, 12.5] {
            taken +>:Fires:+> laser(build, x, float(side) + 1.2, 2.0, 1, False);
        }
        taken +>:Fires:+> build.objective("Security pass taken. Get it to its door");
        guards(build, taken, [[float(self.long) - 2.5, float(self.wide) - 3.5]], 0, JAIL3_FOES.squad(dice, self.danger, 1, True), 180.0);
        build.foe(float(dx) - 4.5, float(middle) + 5.5, 0, JAIL3_FOES.pick(dice, self.danger), 0.0);
        build.foe(4.5, float(side) + 3.5, 0, "monster_infantry", 0.0, patrol=[[4.5, float(side) + 3.5], [float(dx) - 3.5, float(side) + 3.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(middle) - 3.5, 4.0, 2, 4.0);
    }
}

"""The end: a door out onto the mountain, three lanes between ribs of rock
climbed in a switchback, the way out on a landing at the top."""
node ComplexExit(Prefab) {
    has key: str = "",
        first: int = 6,
        second: int = 6,
        by_lift: bool = False,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Complex exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.first = dice.between(7, 8);
        self.second = dice.between(5, 7);
        self.by_lift = dice.chance(0.4);
        self.tall = self.first + self.second + dice.between(14, 18);
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
        room = gate_yard(build, [dice.below(3), dice.below(3)], self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        l1 = self.first;
        l2 = self.first + self.second;
        build.level(room, l1);
        build.level(room, l2);
        lx0 = wall + 1;
        lx1 = self.long - 1;
        # The ribs of rock between the lanes; the middle lane opens at its far
        # end into the second (+y) lane.
        south = middle - 3;
        north = middle + 2;
        build.solid(lx0, south, 0, lx1, south + 1, l2 + 2);
        build.solid(lx0, north, 0, lx1 - 4, north + 1, l2 + 2);
        # Back along the second lane up to its first landing, by a stair or a
        # lift called down at the far end and a walk back along the lane.
        if self.by_lift {
            build.solid(lx0, north + 1, l1 - 1, lx1 - 4, self.wide - 1, l1);
            post_button(build, lx1 - 2, north - 3, 0, 2) +>:Fires:+> called_lift(build, lx1 - 4, north + 1, lx1 - 1, north + 4, 0, l1);
            keep_row(build, room, lx1 - 5, north + 1, l1, 0, 3);
        } else {
            stair(build, lx1 - 3, north + 1, 0, 2, l1, 3);
            build.solid(lx0, north + 1, l1 - 1, lx1 - 2 - l1, self.wide - 1, l1);
        }
        # The bridge over the middle lane by the door's wall, through both
        # ribs, to the third (-y) lane.
        build.widen(room, lx0, south, l1, lx0 + 3, south + 1, l1 + 7);
        build.widen(room, lx0, north, l1, lx0 + 3, north + 1, l1 + 7);
        build.solid(lx0, south + 1, l1 - 1, lx0 + 3, north, l1);
        keep_row(build, room, lx0, north + 1, l1, 0, 3);
        keep_row(build, room, lx0, north - 1, l1, 0, 3);
        # The third lane rock up to the bridge's height, then a stair the
        # lane's whole width to the landing and the way out.
        build.solid(lx0, 1, 0, lx1, south, l1);
        stair(build, lx0 + 4, 1, l1, 0, self.second, south - 1);
        lx = lx0 + 4 + self.second;
        build.solid(lx, 1, l1, lx1, south, l2);
        build.way_out(float(lx1) - 3.5, float(1 + south) * 0.5, l2);
        # Coming in, guards appear along the lanes; pipes drip.
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards(build, come_in, [[float(lx0) + 3.5, float(self.wide) - 2.5]], l1, JAIL3_FOES.squad(dice, self.danger, 1, True), 0.0);
        guards(build, come_in, [[float(lx1) - 5.5, float(1 + south) * 0.5]], l2, JAIL3_FOES.squad(dice, self.danger, 1), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, JAIL3_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 3.5, float(middle) - 0.5, 0, "monster_infantry", 0.0, patrol=[[float(wall) + 3.5, float(middle) - 0.5], [float(lx1) - 2.5, float(middle) - 0.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(lx1) - 2.5, float(middle) - 0.5, 0, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
        drip(build, float(wall) + 6.5, float(middle) - 0.5, float(self.tall) - 0.5, 2.5);
    }
}

"""jail3's stretches: [name, role]."""
glob JAIL3_STRETCHES: list[list[str]] = [
         ["checkpoint", "start"],
         ["cliff", "flow"],
         ["core", "hub"],
         ["core", "flow"],
         ["pyramid", "flow"],
         ["pyramid", "hub"],
         ["tram", "flow"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail3's stretches by its name."""
def make_jail3(name: str, key: str) -> Prefab {
    if name == "checkpoint" {
        return Checkpoint();
    }
    if name == "cliff" {
        return CliffRamps();
    }
    if name == "core" {
        return ComplexCore();
    }
    if name == "pyramid" {
        return SecurityPyramid();
    }
    if name == "tram" {
        return TramShaft();
    }
    if name == "cage" {
        return ButtonCage(key=key if key else "key_silver");
    }
    return ComplexExit(key=key);
}
