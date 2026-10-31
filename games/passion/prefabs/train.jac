"""Prefabs drawn from Quake II's train, the Lost Station: a station sunk deep
in rock, platforms beside a track bed, a tunnel the track runs down with
walkways either side, a chasm crossed only by a riding car, a great lift
up a shaft a station high, a concourse on three levels joined by lifts,
turrets in a hall whose door is opened elsewhere, the key in a signal box
up a stair. Raised in train's own palette.

- `StationPlatform`: the start. A platform beside a deep track bed sunk
  across the hall, sumps deeper still in the bed either side of a
  footbridge over it, a signal gantry over the bed up a stair; parasites appear in the bed as the player crosses and a stash is
  hidden behind a panel shot open.
- `TrackTunnel`: a tunnel, the track bed deep down its middle and a
  walkway either side, water in a sump in the bed with sharks, a
  footbridge over it; guards appear on the far walkway.
- `TrainChasm`: a chasm between two platforms crossed only by a car riding
  to and fro over it (started by a button in some seeds); a lift up out of
  the chasm's floor to the near side; guards appear on the far platform as
  the car sets off.
- `GreatLift`: a shaft a station high, a pool at its foot; a lift (or two)
  from the floor to a landing at the top, ledges on the walls on the way
  up, a vent's wind throwing a body up to one; a drop from the landing
  back into the pool.
- `Concourse`: a concourse on three levels, a lift from each to the next;
  ways on from every level (a hub); guards appear on the upper levels as
  the player rides up.
- `BlasterHall`: a hall of turrets: plates in its floor set the blasters in
  its walls firing; its far door ("Access denied") is opened by a button
  in a control room up a stair, over the hall.
- `ServiceWarren`: small rooms in a grid between the platforms, each a step
  from its neighbours, a flooded sump in one, guards in the others.
- `SignalBox`: the key room. The key in a signal box up a stair along the
  wall; taking it opens the closets on the floor and brings guards in.
- `StationExit`: the end. A door (a key's, as a gate) onto a platform over
  a track bed, the way out at its end; guards appear in the bed."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..space { Space }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, lift }
import from .q2_flood { office }
import from .e4m6 { flood, onward_ports, port_door, pool_steps, told }
import from .base2 { spark_timer, blast_chain, spawn_in, panel_stash, guard_closet }

glob TRAIN: str = "q2:train";

"""A blaster set in a wall at (x, y), `z` lifts up, firing the way
`direction` goes when `cue` fires, sparks with it."""
def blaster(build: Raising, x: float, y: float, z: float, direction: int, cue: Cue) {
    shot = {"classname": "target_blaster", "angle": str(build.facing(direction)), "dmg": "15", "speed": "600"};
    build.put_point(shot, x, y, z, "q2");
    cue +>:Fires:+> build.cue([shot], "blaster");
    cue +>:Fires:+> build.sparks(x, y, z, direction);
}

"""The start: a platform beside a deep track bed, a footbridge over it, a
signal gantry over the bed."""
node StationPlatform(Prefab) {
    has bed: int = 6,
        gantry: bool = True,
        flooded: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station platform";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.bed = dice.between(6, 7);
        self.gantry = dice.chance(0.65);
        self.flooded = dice.chance(0.9);
        self.tall = dice.between(18, 20);
        self.low = -self.bed - 7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 4), floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=-self.bed)];
        if self.gantry {
            self.leaves.append(Port(face=0, along=3.5, floor=9));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.bed;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        # The track bed across the hall's middle, x-long, rails in it.
        build.widen(hall, 1, middle - 3, low, self.long - 1, middle + 3, 0);
        for y in [middle - 2, middle + 1] {
            build.solid(1, y, low, self.long - 1, y + 1, low + 1);
        }
        stair(build, 3, middle + 2, low, 3, self.bed, 3);
        stair(build, self.long - 6, middle - 3, low, 1, self.bed, 3);
        # Sumps deep in the bed either side of the footbridge.
        fx = self.long // 2 - 2;
        build.pool(6, middle - 3, low - 5, fx, middle + 3, low, 2, True, True, True);
        build.pool(fx + 4, middle - 3, low - 5, self.long - 6, middle + 3, low, 2, True, True, True);
        if self.flooded {
            flood(build, 6, middle - 3, low, self.long - 6, middle + 3, -1);
        }

        # The footbridge over the bed.
        build.solid(fx, middle - 3, -1, fx + 4, middle + 3, 0);
        for x in range(fx, fx + 4) {
            build.keep(hall, x, middle - 4, 0);
            build.keep(hall, x, middle + 3, 0);
        }
        # The signal gantry: a slab at eight lifts across the far end of the
        # hall over the bed, up a stair along the +y wall.
        if self.gantry {
            gx = self.long - 6;
            build.solid(gx, 1, 8, self.long - 1, self.wide - 1, 9);
            stair(build, gx - 9, 1, 0, 0, 9, 3);
            for y in range(1, 4) {
                build.keep(hall, gx, y, 9);
            }
            spawn_in(build, dice, self.danger, build.touch(float(gx - 9), 1.0, 0.0, float(gx - 6), 4.0, 6.0), [[float(self.long) - 3.5, 6.5], [float(self.long) - 3.5, float(middle) + 0.5]], 9, 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, 4.5, 0, 0.0);
        build.supply(4.5, 2.5, 0, "ammo_shells", "q2");
        into = build.touch(1.0, 2.0, 0.0, 4.0, 7.0, 6.0);
        into +>:Fires:+> build.objective("Find the way down through the lost station");
        # Crossing the footbridge, parasites appear in the bed.
        over = build.touch(float(fx), float(middle - 3), 0.0, float(fx + 4), float(middle + 3), 6.0);
        late = build.delay(1.0);
        over +>:Fires:+> late;
        spawn_in(build, dice, self.danger, late, [[float(fx) - 5.5, float(middle) - 0.5], [float(fx) + 7.5, float(middle) + 0.5]], low, 90.0, True);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(self.wide) - 3.5, 0, q2_foe(dice, self.danger), 270.0);
        }
        build.foe(6.5, float(middle) - 5.5, 0, "monster_soldier", 0.0, patrol=[[6.5, float(middle) - 5.5], [float(self.long) - 7.5, float(middle) - 5.5]]);
        spark_timer(build, float(fx) + 2.0, float(middle) - 3.1, -2.0, 3, 5.0);
        panel_stash(build, 8, 0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A tunnel, the track bed deep down its middle and a walkway either side,
water in a sump in the bed, a footbridge over it."""
node TrackTunnel(Prefab) {
    has bed: int = 6,
        flooded: bool = False,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Track tunnel";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.bed = dice.between(6, 7);
        self.flooded = dice.chance(0.9);
        self.tall = dice.between(12, 14);
        self.low = -self.bed - 9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.bed;
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tunnel, low);
        build.widen(tunnel, 1, middle - 3, low, self.long - 1, middle + 3, 0);
        # The sump in the bed's middle, deep, sharks in it, steps out of it.
        sx = self.long // 2 - 4;
        build.pool(sx, middle - 3, low - 8, sx + 8, middle + 3, low, 2, False, False);
        stair(build, sx + 7, middle - 3, low - 8, 2, 8, 2);
        stair(build, sx + 7, middle + 1, low - 8, 2, 8, 2);
        # Steps down into the bed at either end, a footbridge over the sump.
        stair(build, 2, middle + 2, low, 3, self.bed, 3);
        stair(build, self.long - 5, middle - 3, low, 1, self.bed, 3);
        build.solid(sx + 2, middle - 3, -1, sx + 6, middle + 3, 0);
        for x in range(sx + 2, sx + 6) {
            build.keep(tunnel, x, middle - 4, 0);
            build.keep(tunnel, x, middle + 3, 0);
        }
        build.solid(6, middle - 3, -1, sx + 1, middle - 2, 0);
        build.solid(sx + 7, middle + 2, -1, self.long - 6, middle + 3, 0);
        if self.flooded {
            flood(build, 6, middle - 3, low, self.long - 6, middle + 3, -1);
        }
        # The service gallery along the +y wall over the walkway, up a stair
        # from the walkway's near end.
        gy = middle + 4;
        build.solid(10, gy, 7, self.long - 8, self.wide - 1, 8);
        stair(build, 2, gy, 0, 0, 8, 3);
        for y in range(gy, gy + 3) {
            build.keep(tunnel, 10, y, 8);
        }
        build.foe(float(self.long) - 10.5, float(self.wide) - 2.5, 8, q2_foe(dice, self.danger), 180.0);
        build.supply(12.5, float(self.wide) - 2.5, 8, "ammo_grenades", "q2");
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        if self.danger > 0.25 {
            build.foe(float(sx) + 4.5, float(middle) + 0.5, low - 2, "monster_flipper", 0.0);
        }
        # Crossing the footbridge, guards appear on the far walkways.
        over = build.touch(float(sx + 2), float(middle - 3), 0.0, float(sx + 6), float(middle + 3), 6.0);
        spawn_in(build, dice, self.danger, over, [[float(self.long) - 4.5, 2.5], [float(self.long) - 4.5, float(self.wide) - 2.5]], 0, 180.0, True);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 5) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5, float(self.wide) - 2.5, 0, "monster_soldier", 0.0, patrol=[[4.5, float(self.wide) - 2.5], [float(self.long) - 6.5, float(self.wide) - 2.5]]);
        spark_timer(build, float(self.long // 2) + 0.5, 1.1, 4.0, 1, 4.0);
        build.supply(float(self.long // 2) + 0.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A chasm between two platforms crossed only by a car riding over it, a
lift up out of its floor to the near side."""
node TrainChasm(Prefab) {
    has deep: int = 12,
        gap: int = 14,
        lane: int = 6,
        started: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Train chasm";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.deep = dice.between(14, 18);
        self.gap = dice.between(12, 16);
        self.long = 9 + self.gap + 9;
        self.wide = dice.between(16, 18);
        self.lane = dice.between(5, self.wide - 9);
        self.started = dice.chance(0.4);
        self.tall = dice.between(30, 33);
        self.low = -self.deep - 9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        x0 = 9;
        x1 = 9 + self.gap;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        chasm = build.room(x0 - 2, 1, low, x1 + 2, self.wide - 1, 0, variant=dice.below(3));
        build.level(chasm, low);
        # The platforms' lips: slabs out over the chasm's edges.
        build.solid(x0 - 2, 1, -1, x0, self.wide - 1, 0);
        build.solid(x1, 1, -1, x1 + 2, self.wide - 1, 0);
        # A stream down the chasm's floor.
        build.pool(x0 + 4, 1, low - 8, x1, self.wide - 1, low, 2, False, True, True);
        crates_at = [[self.long - 2, middle - 4], [self.long - 2, middle + 3]];
        for at in crates_at {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 1), float(at[1] + 1), 2.0, 10);
        }
        # The car: four cells square, riding from the near lip to the far.
        car = build.train([4.0, 4.0, 1.0], [[float(x0), float(self.lane), -1.0], [float(x1 - 4), float(self.lane), -1.0]], 100.0, 2.0, self.started);
        for y in range(self.lane, self.lane + 4) {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        if self.started {
            press = build.push(4.0, 1.0, 1.5, 1);
            press +>:Fires:+> car;
            build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "The button by the lip starts the car");
            spawn_in(build, dice, self.danger, press, [[float(x1) + 3.5, 3.5], [float(x1) + 3.5, float(self.wide) - 3.5]], 0, 180.0, True);
        } else {
            riding = build.touch(float(x0), float(self.lane), 0.0, float(x0 + 4), float(self.lane + 4), 4.0);
            spawn_in(build, dice, self.danger, riding, [[float(x1) + 3.5, 3.5], [float(x1) + 3.5, float(self.wide) - 3.5]], 0, 180.0, True);
        }
        # The lift up out of the chasm to the near platform, clear of the
        # car's lane.
        ly = 1 if self.lane > 5 else self.wide - 5;
        build.solid(x0 - 2, ly, low, x0, ly + 4, 0);
        build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "200"}, float(x0), float(ly), -0.5, float(x0 + 3), float(ly + 4), 0.0, kit_of(build.district).step);
        for y in range(ly, ly + 4) {
            build.keep(hall, x0 - 1, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 5) + 0.5, float(middle) + 0.5, 6, q2_foe(dice, self.danger, False, True), 0.0);
        }
        build.foe(3.5, 2.5, 0, "monster_soldier", 90.0, patrol=[[3.5, 2.5], [3.5, float(self.wide) - 2.5]]);
        build.foe(float(x0) + 1.5, float(middle) + 0.5, low, q2_foe(dice, self.danger), 0.0);
        spark_timer(build, float(x1) + 0.1, float(self.lane) + 2.0, -3.0, 0, 4.0);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A shaft a station high, a pool at its foot, a lift (or two) from the
floor to a landing at the top, ledges on the way up, a drop from the
landing back into the pool."""
node GreatLift(Prefab) {
    has height: int = 30,
        twin: bool = False,
        tall: int = 40;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Great lift";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.height = dice.between(48, 56);
        self.twin = dice.chance(0.5);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.tall = self.height + 10;
        self.low = -16;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.height),
            Port(face=1, along=float(self.long - 3), floor=self.height),
            Port(face=3, along=float(self.long - 3), floor=self.height),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        h = self.height;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, h);
        build.level(shaft, h // 2);
        step = kit_of(build.district).step;
        # The landing at the top along the +x wall, and the pool below its
        # lip.
        lx = self.long - 10;
        build.solid(lx, 1, h - 1, self.long - 1, self.wide - 1, h);
        build.pool(9, 5, -15, lx, self.wide - 5, 0, 2, False, False);
        lift(build, lx - 3, 5, lx, 8, -15, 0);
        for y in range(5, 8) {
            build.keep(shaft, lx, y, 0);
        }
        for y in range(5, self.wide - 5) {
            build.keep(shaft, lx, y, h);
        }
        # The lift: a plat from the floor to the landing, by the -y wall; a
        # second by the +y wall in some seeds, slower.
        build.put_box({"classname": "func_plat", "height": str(h * 16), "speed": "350"}, float(lx - 4), 1.0, float(h) - 0.5, float(lx), 5.0, float(h), step);
        for x in range(lx - 4, lx) {
            build.keep(shaft, x, 5, 0);
        }
        if self.twin {
            build.put_box({"classname": "func_plat", "height": str(h * 16), "speed": "180"}, float(lx - 4), float(self.wide - 5), float(h) - 0.5, float(lx), float(self.wide - 1), float(h), step);
            for x in range(lx - 4, lx) {
                build.keep(shaft, x, self.wide - 6, 0);
            }
        }
        # Ledges on the walls on the way up, a stash on one, the wind of a
        # vent on the floor throwing a body up to the lowest.
        mid = h // 2;
        build.solid(1, 1, mid - 1, 6, self.wide - 1, mid);
        build.solid(6, self.wide - 5, 11, lx - 7, self.wide - 1, 12);
        build.teleporter(float(self.long) - 3.5, float(self.wide // 2) + 0.5, h, 3.0, float(self.wide // 2) - 3.5, 0, 0.0);
        build.jump_pad(7.5, float(middle) + 0.5, 0, 3.0, float(middle) + 0.5, mid);
        for y in range(middle - 3, middle + 4) {
            build.keep(shaft, 5, y, mid);
        }
        build.secret(1.0, 1.0, float(mid), 6.0, float(self.wide - 1), float(mid + 4));
        build.supply(2.5, 3.0, mid, "item_armor_combat", "q2");
        build.foe(3.5, float(self.wide) - 3.5, mid, q2_foe(dice, self.danger), 0.0);
        build.foe(9.5, float(self.wide) - 2.5, 12, q2_foe(dice, self.danger, True), 0.0);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Riding up, guards appear on the landing; flyers circle the shaft.
        up = build.touch(float(lx - 4), 1.0, 0.0, float(lx), 5.0, 6.0);
        spawn_in(build, dice, self.danger, up, [[float(self.long) - 3.5, float(middle) + 3.5], [float(self.long) - 3.5, 6.5]], h, 180.0, True);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 8 + index * 10, "monster_flyer", 90.0);
        }
        build.foe(3.5, 4.5, 0, "monster_soldier", 0.0, patrol=[[3.5, 4.5], [3.5, float(self.wide) - 4.5]]);
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "The lift goes up to the station's upper levels");
        spark_timer(build, float(self.long) - 1.1, float(middle) + 0.5, float(h) + 3.0, 2, 4.0);
        spark_timer(build, 1.1, float(middle) - 3.5, 4.0, 0, 6.0);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, h, "ammo_bullets", "q2");
    }
}

"""A concourse on three levels, a lift from each to the next."""
node Concourse(Prefab) {
    has rise_by: int = 6,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Concourse";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.rise_by = dice.between(10, 12);
        self.tall = 2 * self.rise_by + 10;
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=2 * self.rise_by),
            Port(face=1, along=float(self.long // 2), floor=self.rise_by),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=self.rise_by)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        first = self.rise_by;
        second = 2 * self.rise_by;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, first);
        build.level(hall, second);
        step = kit_of(build.district).step;
        # The first level: a mezzanine over the floor's far two-thirds, a
        # well cut through it.
        m1 = self.long // 3;
        build.solid(m1, 1, first - 1, self.long - 1, self.wide - 1, first);
        build.widen(hall, m1 + 4, 6, first - 1, self.long - 8, self.wide - 6, first);
        # A pool on the floor under the well.
        build.pool(m1 + 4, 6, -10, self.long - 8, self.wide - 6, 0, 2, False, True, True);
        # The station's offices under the far end of the first level.
        office(build, self.long - 8, 2, self.long - 1, 9, 0, 8, 2, 4);
        office(build, self.long - 8, self.wide - 9, self.long - 1, self.wide - 2, 0, 8, 2, self.wide - 7);
        build.supply(float(self.long) - 3.5, 5.0, 1, "ammo_shells", "q2");
        build.foe(float(self.long) - 3.5, float(self.wide) - 5.5, 1, q2_foe(dice, self.danger), 180.0);
        # The second level: a gallery across the far end.
        m2 = self.long - 7;
        build.solid(m2, 1, second - 1, self.long - 1, self.wide - 1, second);
        build.widen(hall, m2 - 3, 2, first - 1, m2, 5, first);
        build.put_box({"classname": "func_plat", "height": str(first * 16), "speed": "200"}, float(m1 - 3), float(middle - 1), float(first) - 0.5, float(m1), float(middle + 2), float(first), step);
        build.put_box({"classname": "func_plat", "height": str((second - first) * 16), "speed": "200"}, float(m2 - 3), 2.0, float(second) - 0.5, float(m2), 5.0, float(second), step);
        for y in range(middle - 2, middle + 3) {
            build.keep(hall, m1, y, first);
        }
        for y in range(1, 6) {
            build.keep(hall, m2, y, second);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Riding up, guards appear on the levels above.
        first_ride = build.touch(float(m1 - 3), float(middle - 1), 0.0, float(m1), float(middle + 2), 6.0);
        spawn_in(build, dice, self.danger, first_ride, [[float(m1 + 2) + 0.5, float(self.wide) - 3.0], [float(self.long) - 9.5, 3.0]], first, 180.0);
        second_ride = build.touch(float(m2 - 3), 2.0, float(first), float(m2), 5.0, float(first + 6));
        spawn_in(build, dice, self.danger, second_ride, [[float(self.long) - 3.0, float(middle) + 3.5]], second, 180.0, True);
        for index in range(dice.between(2, 3)) {
            build.foe(float(m1 // 2) + 0.5, 3.5 + float(index) * 5.0, 0, q2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(m1 + 2) + 0.5, 3.0, first, "monster_soldier", 0.0, patrol=[[float(m1 + 2) + 0.5, 3.0], [float(self.long) - 9.5, 3.0]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, first + 4, q2_foe(dice, self.danger, False, True), 180.0);
        spark_timer(build, 1.1, float(middle) + 4.5, 3.0, 0, 5.0);
        build.supply(float(self.long) - 2.5, 2.5, second, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, Q2_ARMOR, "q2");
    }
}

"""A hall of turrets, plates in its floor setting the blasters in its walls
firing; its far door opened by a button in a control room up a stair."""
node BlasterHall(Prefab) {
    has room_up: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blaster hall";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.room_up = 8;
        self.tall = self.room_up + dice.between(7, 8);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        up = self.room_up;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, up);
        # The control room: a slab along the -y wall over the hall, up a
        # stair from the near end, the button on its back wall.
        build.solid(1 + up, 1, up - 1, self.long - 1, 5, up);
        stair(build, 1, 1, 0, 0, up, 3);
        # A bridge across the far end to a gallery along the +y wall, over the
        # plates and the turrets.
        build.solid(self.long - 11, 5, up - 1, self.long - 7, self.wide - 4, up);
        build.solid(8, self.wide - 4, up - 1, self.long - 7, self.wide - 1, up);
        build.foe(10.5, float(self.wide) - 2.5, up, q2_foe(dice, self.danger), 0.0);
        press = build.push(float(self.long // 2) + 0.5, 1.0, float(up) + 1.5, 1);
        for port in onward_ports(self) {
            press +>:Fires:+> port_door(build, self, port);
        }
        build.touch(float(self.long - 6), float(middle - 3), 0.0, float(self.long - 1), float(middle + 3), 6.0, True, "Access denied: the door is opened from the control room");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The plates down the hall, each setting the blasters in the +y wall
        # off a moment later.
        for x in range(8, self.long - 6, 6) {
            plate = build.touch(float(x), float(middle - 2), 0.0, float(x + 2), float(middle + 2), 2.0, False);
            plate.items[0]["wait"] = "1.5";
            late = build.delay(0.4);
            plate +>:Fires:+> late;
            blaster(build, float(x) + 1.0, float(self.wide - 1) - 0.1, 2.0, 3, late);
            blaster(build, float(x) + 3.0, float(self.wide - 1) - 0.1, 4.0, 3, late);
        }
        # Pressing the button brings guards in on the hall floor.
        spawn_in(build, dice, self.danger, press, [[float(self.long) - 4.5, float(middle) + 3.5], [float(self.long) - 7.5, float(middle) - 1.5]], 0, 180.0, True);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long - 4 - index * 5) + 0.5, 3.0, up, q2_foe(dice, self.danger), 180.0);
        }
        build.foe(4.5, float(self.wide) - 2.5, 0, "monster_soldier", 0.0, patrol=[[4.5, float(self.wide) - 2.5], [float(self.long) - 4.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, up, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_cells", "q2");
        for at in [[self.long - 3, 6], [6, self.wide - 3]] {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 1), float(at[1] + 1), 2.0, 10);
        }
    }
}

"""The key in a signal box up a stair along the wall; taking it opens the
closets on the floor and brings guards in."""
node SignalBox(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        box: int = 7,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Signal box (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.box = dice.between(6, 7);
        self.tall = self.box + 8;
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
        cy = side // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.box);
        build.doorway(hall, self.enter);
        bx = self.long - 7;
        build.solid(bx, 1, self.box - 1, self.long - 1, 7, self.box);
        stair(build, bx - self.box, 1, 0, 0, self.box, 3);
        build.solid(bx, 7, self.box, self.long - 1, 8, self.box + 2);
        key_ambush(build, self.key, float(self.long) - 3.0, 4.0, self.box, side, 0, [3, bx - 3], [q2_foe(dice, self.danger, True), q2_foe(dice, self.danger)]);
        taken = build.touch(float(self.long - 5), 2.0, float(self.box), float(self.long - 1), 6.0, float(self.box + 6));
        spawn_in(build, dice, self.danger, taken, [[4.5, float(cy) + 0.5], [float(bx) - 3.5, float(side) - 3.5]], 0, 0.0);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "The key is in the signal box");
        build.foe(float(self.long) - 3.0, float(cy) + 3.5, 0, q2_foe(dice, self.danger), 180.0);
        build.foe(3.5, float(side) - 4.5, 0, "monster_soldier", 0.0, patrol=[[3.5, float(side) - 4.5], [float(bx) - 1.5, float(side) - 4.5]]);
        spark_timer(build, float(self.long) - 1.1, 4.5, float(self.box) + 2.0, 2, 4.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door onto a platform over a track bed, the way out at its
end."""
node StationExit(Prefab) {
    has key: str = "",
        bed: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.bed = dice.between(6, 7);
        self.tall = dice.between(12, 14);
        self.low = -self.bed - 7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        platform = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(platform, -self.bed);
        build.doorway(hall, self.enter);
        build.widen(platform, wall, 2, 0, wall + 1, 6, 8);
        if self.key {
            build.rising_door(float(wall), 2.0, 0.0, float(wall + 1), 6.0, 8.0, {"key": self.key, "wait": "-1"});
        }
        # The track bed along the platform, its lip a slab out over it.
        build.widen(platform, wall + 1, 8, -self.bed, self.long - 1, self.wide - 1, 0);
        build.solid(wall + 1, 8, -1, self.long - 1, 10, 0);
        stair(build, wall + 3, 9 + self.bed, -self.bed, 3, self.bed, 3);
        build.pool(wall + 8, 10, -self.bed - 5, self.long - 1, self.wide - 1, -self.bed, 2, True, True, True);
        flood(build, wall + 7, 10, -self.bed, self.long - 1, self.wide - 1, -1);
        build.way_out(float(self.long) - 3.5, 4.0, 0);
        into = build.touch(float(wall + 1), 2.0, 0.0, float(wall + 3), 6.0, 6.0);
        spawn_in(build, dice, self.danger, into, [[float(self.long) - 6.5, float(self.wide) - 3.0], [float(wall) + 8.5, float(self.wide) - 3.0]], -self.bed, 180.0, True);
        blast_chain(build, into, [[float(self.long) - 4.5, float(self.wide) - 4.0, float(1 - self.bed)], [float(wall) + 10.5, float(self.wide) - 2.0, float(1 - self.bed)]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 4.5, 3.0, 0, "monster_soldier", 0.0, patrol=[[float(wall) + 4.5, 3.0], [float(self.long) - 7.5, 3.0]]);
        build.touch(float(self.long - 6), 1.0, 0.0, float(self.long - 1), 7.0, 6.0, True, "The last train is gone: take the way out");
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The floor of a warren's room in column `col`, row `row`: one lift apart
from each of its neighbours."""
def warren_floor(col: int, row: int) -> int {
    return [0, 1, 2, 1][(col + row + 3) % 4];
}

"""A service warren between the platforms: small rooms in a grid, each a step
from its neighbours, a walk along one side of each with the ways through; a
flooded sump in one, offices with a guard or a store in the others."""
node ServiceWarren(Prefab) {
    has cols: int = 3,
        room_x: int = 7,
        room_y: int = 7,
        tall: int = 14;

    def box_of(col: int, row: int) -> list[int] {
        x0 = 1 + col * (self.room_x + 1);
        y0 = 1 + row * (self.room_y + 1);
        return [x0, y0, x0 + self.room_x, y0 + self.room_y];
    }

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Service warren";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.cols = dice.between(3, 4);
        self.room_x = dice.between(7, 8);
        self.room_y = 7;
        self.long = 1 + self.cols * (self.room_x + 1);
        self.wide = 1 + 3 * (self.room_y + 1);
        self.tall = dice.between(12, 14);
        self.low = -8;
        self.high = self.tall + 4;
        last = self.cols - 1;
        self.enter = Port(face=2, along=float(self.box_of(0, 1)[1]) + 4.5, floor=warren_floor(0, 1));
        self.leaves = [
            Port(face=0, along=float(self.box_of(last, 1)[1]) + 4.5, floor=warren_floor(last, 1)),
            Port(face=1, along=float(self.box_of(1, 2)[0]) + 3.5, floor=warren_floor(1, 2)),
            Port(face=3, along=float(self.box_of(last, 0)[0]) + 3.5, floor=warren_floor(last, 0))
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        spaces: dict[str, Space] = {};
        for col in range(self.cols) {
            for row in range(3) {
                box = self.box_of(col, row);
                floor = warren_floor(col, row);
                spaces[str(col) + ":" + str(row)] = build.room(box[0], box[1], floor, box[2], box[3], floor + self.tall, variant=dice.below(3));
            }
        }
        # The ways through: along each row by the walk at the room's +y side,
        # always; between the rows at least once in each, more in some seeds.
        for row in range(3) {
            for col in range(self.cols - 1) {
                box = self.box_of(col, row);
                top = max(warren_floor(col, row), warren_floor(col + 1, row));
                build.widen(spaces[str(col) + ":" + str(row)], box[2], box[3] - 3, top, box[2] + 1, box[3], top + 7);
                if dice.chance(0.3) {
                    build.rising_door(float(box[2]), float(box[3] - 3), float(top), float(box[2] + 1), float(box[3]), float(top + 7), {"wait": "-1"});
                }
            }
        }
        for row in range(2) {
            always = dice.below(self.cols);
            for col in range(self.cols) {
                if col == always or dice.chance(0.4) {
                    box = self.box_of(col, row);
                    top = max(warren_floor(col, row), warren_floor(col, row + 1));
                    build.widen(spaces[str(col) + ":" + str(row)], box[0] + 2, box[3], top, box[0] + 5, box[3] + 1, top + 7);
                }
            }
        }
        # The sump: the second room of the first row flooded but for its walk,
        # a stair up out of it onto the walk, a store at its foot.
        sump = self.box_of(1, 0);
        low_floor = warren_floor(1, 0);
        build.pool(sump[0], sump[1], low_floor - 7, sump[2], sump[3] - 3, low_floor, 2, steps=False);
        stair(build, sump[0], sump[3] - 5, low_floor - 7, 0, 7, 2);
        build.supply(float(sump[2]) - 1.5, float(sump[1]) + 1.0, low_floor - 7, "ammo_cells", "q2");
        if self.danger > 0.25 {
            build.foe(float(sump[0]) + 3.5, float(sump[1]) + 1.5, low_floor - 4, "monster_flipper", 0.0);
        }
        build.doorway(spaces["0:1"], self.enter);
        for port in self.taken {
            if port.face == 0 {
                build.doorway(spaces[str(self.cols - 1) + ":1"], port);
            } elif port.face == 1 {
                build.doorway(spaces["1:2"], port);
            } else {
                build.doorway(spaces[str(self.cols - 1) + ":0"], port);
            }
        }
        # Foes about the rooms; a touch in the middle wakes those beyond.
        for col in range(self.cols) {
            for row in range(3) {
                if (col + row) % 2 == 1 and not (col == 1 and row == 0) and not (col == 0 and row == 1) {
                    box = self.box_of(col, row);
                    build.foe(float(box[0]) + 2.5, float(box[1]) + 2.5, warren_floor(col, row), q2_foe(dice, self.danger), 180.0);
                }
            }
        }
        middle = self.box_of(1, 1);
        woken = build.touch(float(middle[0]), float(middle[1]), float(warren_floor(1, 1)), float(middle[2]), float(middle[3]), float(warren_floor(1, 1) + 6));
        far = self.box_of(self.cols - 1, 2);
        spawn_in(build, dice, self.danger, woken, [[float(far[0]) + 3.5, float(far[1]) + 2.5]], warren_floor(self.cols - 1, 2), 180.0, True);
        spark_timer(build, float(middle[0]) + 0.1, float(middle[1]) + 1.5, float(warren_floor(1, 1)) + 3.0, 0, 4.0);
        store = self.box_of(0, 2);
        build.supply(float(store[0]) + 2.5, float(store[1]) + 2.5, warren_floor(0, 2), Q2_HEALTH, "q2");
        build.supply(float(store[0]) + 4.5, float(store[1]) + 2.5, warren_floor(0, 2), "ammo_bullets", "q2");
        corner = self.box_of(0, 0);
        build.supply(float(corner[0]) + 2.5, float(corner[1]) + 2.5, warren_floor(0, 0), Q2_ARMOR, "q2");
    }
}

"""train's stretches: [name, role]."""
glob TRAIN_STRETCHES: list[list[str]] = [
         ["platform", "start"],
         ["tunnel", "flow"],
         ["chasm", "flow"],
         ["lift", "flow"],
         ["lift", "hub"],
         ["concourse", "hub"],
         ["concourse", "flow"],
         ["blasters", "flow"],
         ["warren", "flow"],
         ["signal", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of train's stretches by its name."""
def make_train(name: str, key: str) -> Prefab {
    if name == "platform" {
        return StationPlatform();
    }
    if name == "tunnel" {
        return TrackTunnel();
    }
    if name == "chasm" {
        return TrainChasm();
    }
    if name == "lift" {
        return GreatLift();
    }
    if name == "concourse" {
        return Concourse();
    }
    if name == "blasters" {
        return BlasterHall();
    }
    if name == "warren" {
        return ServiceWarren();
    }
    if name == "signal" {
        return SignalBox(key=key if key else "key_silver");
    }
    return StationExit(key=key);
}
