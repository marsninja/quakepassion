"""Prefabs drawn from Quake II's mine2, the Borehole: workings stacked
storey over storey round the mine's elevator, a borehole stairwell
falling flight under flight, ore buckets over a channel of lava, the
mine machinery that two switches set going, the key at the bottom of a
flooded sump, the elevator shaft down to the way out. Raised in mine2's
own palette.

- `ElevatorStation`: the start (or a hub). Three storeys over each other
  round an open shaft, the mine's elevator riding between them (mine2's
  trigger_elevator cage), stairs between the storeys (some, or none);
  guards on the lower storeys come out as the player reaches them, one
  walks the middle storey round the shaft; a panel on a pump breaks open
  on a stash (the secret). Ways on from every storey.
- `BoreholeStair`: the borehole: a stairwell falling flight under flight
  round an open middle, three or four flights deep, a sump of water at its
  foot; each landing's foes come as the player reaches the one above; a
  way out at a landing partway and at the foot.
- `ConveyorWorks`: a channel of lava, ore buckets riding across it (set
  going by a switch, or running), a catwalk along the wall over it all to
  a way out high up; guards on the far side come as the buckets start.
- `MachineHall`: a hall of two storeys, a lava trench along one wall with
  an ore cart in it, a booth over the trench and a catwalk to the upper
  storey; the machinery is inoperative until both its switches are thrown
  (mine2's counter of two buttons): then the ways on open, the cart runs,
  sparks fly and guards come (a hub).
- `FloodedSump`: the key on the floor of a flooded sump split by a
  walkway; taking it opens the closets round it; something swims in it.
- `ShaftBottom`: the end. A door (a key's, as a gate), the elevator shaft
  and its cage down to the way out at its foot ("Return to elevator
  shaft")."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, stalactites, key_ambush, gate_into, lift }
import from .minefact { slab, hurt, burning, sparking, stash, charges, port_door }

glob MINE2: str = "q2:mine2";

"""mine2's foes: shotgun guards and gunners, berserkers, gladiators
deeper in."""
glob MINE2_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_soldier_ss", "monster_gunner"], strong=["monster_berserk"], heavy_light=["monster_berserk", "monster_gunner"], heavy_strong=["monster_gladiator"], scale=0.8, heavy_scale=0.6);

"""Three storeys round an open shaft, the elevator riding between them."""
node ElevatorStation(Prefab) {
    has storey: int = 9,
        low_stair: bool = True,
        high_stair: bool = True,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elevator station";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(24, 28);
        self.wide = dice.between(22, 26);
        self.storey = dice.between(9, 10);
        self.tall = 10;
        self.low_stair = dice.chance(0.6);
        self.high_stair = dice.chance(0.6);
        h = self.storey;
        self.low = -2 * h - 10;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(5, self.wide - 6)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(5, self.wide - 8)), floor=0),
            Port(face=3, along=float(dice.between(6 + h, self.long - 4)), floor=-h),
            Port(face=1, along=float(dice.between(5, self.long - 6)), floor=-2 * h),
            Port(face=0, along=float(dice.between(8, self.wide - 4)), floor=-2 * h)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        h = self.storey;
        bottom = -2 * h;
        sx = self.long // 2 - 2;
        sy = self.wide // 2 - 2;
        hall = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, -h);
        # The storeys' floors, each a slab over the one below, the shaft open
        # through them and a well over each stair.
        for z in [0, -h] {
            slab(build, 1, 1, self.long - 1, self.wide - 1, z, 1);
            build.widen(hall, sx, sy, z - 1, sx + 5, sy + 5, z);
        }
        if self.low_stair {
            build.widen(hall, 3, 1, -h - 1, 3 + h, 4, -h);
            stair(build, 3, 1, bottom, 0, h, 3);
        }
        if self.high_stair {
            build.widen(hall, self.long - 3 - h, self.wide - 4, -1, self.long - 3, self.wide - 1, 0);
            stair(build, self.long - 4, self.wide - 4, -h, 2, h, 3);
        } else {
            build.widen(hall, self.long - 6, self.wide - 4, -1, self.long - 3, self.wide - 1, 0);
            lift(build, self.long - 6, self.wide - 4, self.long - 3, self.wide - 1, -h, 0);
        }
        # The elevator, riding from the foot to the top and back.
        cage = [float(sx) + 0.5, float(sy) + 0.5];
        cage_ride = build.train([4.0, 4.0, 1.0], [[cage[0], cage[1], float(bottom)], [cage[0], cage[1], float(-h - 1)], [cage[0], cage[1], -1.0], [cage[0], cage[1], float(-h - 1)]], 90.0, 2.5, True);
        # A call switch on each storey, on a column by the shaft, sets it
        # going.
        build.solid(sx - 2, sy + 5, bottom, sx - 1, sy + 6, self.tall);
        for z in [0, -h, bottom] {
            build.push(float(sx) - 1.5, float(sy + 5), float(z) + 1.0, 3) +>:Fires:+> cage_ride;
        }
        for y in range(sy, sy + 5) {
            build.keep(hall, sx - 1, y, 0);
            build.keep(hall, sx - 1, y, -h);
        }
        # A pump on the bottom storey, a stash behind a panel on it.
        build.solid(self.long - 6, 2, bottom, self.long - 2, 6, -h - 1);
        stash(build, self.long - 5, 3, bottom, 2, Q2_ARMOR);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(3.5, self.enter.along, 0, 0.0);
        build.supply(3.5, self.enter.along - 2.0, 0, "ammo_shells", "q2");
        build.touch(1.0, self.enter.along - 2.0, 0.0, 5.0, self.enter.along + 2.0, 6.0) +>:Fires:+> build.objective("Activate the mine machinery. Find the borehole.");
        sparking(build, float(sx) - 0.1, float(sy) - 0.5, float(-h) + 4.0, 2, 4.0);
        # Reaching each lower storey (by the cage or the stairs) brings its
        # guards out.
        for z in [-h, bottom] {
            arrive = build.touch(float(sx - 3), float(sy - 3), float(z), float(sx + 8), float(sy + 8), float(z + 4));
            storey_guard = build.waiting();
            arrive +>:Fires:+> storey_guard;
            if z == bottom {
                arrive +>:Fires:+> build.summon(2, 2, bottom - 9, MINE2_FOES.pick(dice, self.danger, True), float(self.long // 2) + 0.5, 6.5, bottom, 90.0);
            }
            for index in range(dice.between(1, 2)) {
                build.foe(float(3 + index * 4) + 0.5, float(self.wide) - 3.5, z, MINE2_FOES.pick(dice, self.danger, index == 1), 270.0, waits=storey_guard);
            }
        }
        ring = [[float(sx) - 2.5, float(sy) - 2.5], [float(sx) + 7.5, float(sy) - 2.5], [float(sx) + 7.5, float(sy) + 7.5], [float(sx) - 2.5, float(sy) + 7.5]];
        build.foe(ring[0][0], ring[0][1], -h, "monster_soldier_ss", 0.0, patrol=ring);
        build.foe(float(self.long) - 3.5, float(self.wide // 2) + 0.5, 0, MINE2_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, 6.5, bottom, MINE2_FOES.pick(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 3.5, 3.5, -h, Q2_HEALTH, "q2");
        build.supply(3.5, float(self.wide) - 3.5, bottom, "ammo_bullets", "q2");
    }
}

"""The borehole: a stairwell falling flight under flight round an open
middle, a sump at its foot."""
node BoreholeStair(Prefab) {
    has flight: int = 7,
        flights: int = 3,
        well: int = 9,
        exit_at: int = 1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Borehole stair";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.flight = dice.between(6, 8);
        self.flights = dice.between(3, 4);
        self.well = dice.between(9, 11);
        self.exit_at = dice.between(1, self.flights - 1);
        self.long = 8 + self.flight;
        self.wide = self.well + 2;
        deep = self.flight * self.flights;
        self.low = -deep - 6;
        self.high = 9;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0 if self.flights % 2 == 1 else 2, along=middle, floor=-deep),
            Port(face=0 if self.exit_at % 2 == 1 else 2, along=middle, floor=-self.flight * self.exit_at)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.flight;
        deep = f * self.flights;
        west = [1, 4];
        east = [4 + f, 7 + f];
        hole = build.room(1, 1, -deep, self.long - 1, self.wide - 1, 8, variant=dice.below(3));
        # The landings, west and east in turn, each a flight lower; the
        # flights between them along the south and north walls.
        for j in range(self.flights) {
            top = -j * f;
            build.level(hole, top);
            span = west if j % 2 == 0 else east;
            slab(build, span[0], 1, span[1], self.wide - 1, top, 2);
            for k in range(f) {
                step_top = top - k - 1;
                x = 4 + k if j % 2 == 0 else 3 + f - k;
                y0 = 1 if j % 2 == 0 else self.wide - 4;
                build.solid(x, y0, max(-deep, step_top - 2), x + 1, y0 + 3, step_top);
            }
        }
        build.level(hole, -deep);
        # The sump of water in the middle of the foot.
        build.pool(5, 4, -deep - 4, 3 + f, self.wide - 4, -deep, 2);
        build.doorway(hole, self.enter);
        for port in self.taken {
            build.doorway(hole, port);
        }
        # Each landing's foes come out as the player reaches the one above.
        for j in range(self.flights) {
            top = -j * f;
            span = west if j % 2 == 0 else east;
            here_touch = build.touch(float(span[0]), 4.0, float(top), float(span[1]), float(self.wide - 4), float(top + 5));
            below = build.waiting();
            here_touch +>:Fires:+> below;
            nxt = east if j % 2 == 0 else west;
            build.foe(float(nxt[0]) + 1.5, float(self.wide // 2) + 0.5, top - f, MINE2_FOES.pick(dice, self.danger, j == self.flights - 1), 180.0 if j % 2 == 0 else 0.0, waits=below);
            sparking(build, float(span[0]) + 1.5, 1.1, float(top) + 3.0, 1, 3.0 + float(j));
        }
        foot_y = float(self.wide) - 2.5;
        build.foe(2.5, foot_y, -deep, "monster_soldier_ss", 0.0, patrol=[[2.5, foot_y], [float(self.long) - 2.5, foot_y], [float(self.long) - 2.5, 2.5], [2.5, 2.5]]);
        build.supply(float(self.long) - 2.5, float(self.wide // 2) + 0.5, -f, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, -deep, "ammo_bullets", "q2");
    }
}

"""A channel of lava, ore buckets riding across it, a catwalk along the
wall over it all."""
node ConveyorWorks(Prefab) {
    has channel: int = 12,
        buckets: int = 2,
        fired: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Conveyor works";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.channel = dice.between(11, 13);
        self.long = 1 + 7 + self.channel + 7 + 1;
        self.wide = dice.between(18, 20);
        self.buckets = dice.between(1, 2);
        self.fired = dice.chance(0.6);
        self.tall = dice.between(15, 17);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 9)), floor=0);
        self.leaves = [Port(face=0, along=float(dice.between(3, self.wide // 2)), floor=0)];
        if dice.chance(0.5) {
            self.leaves.append(Port(face=0, along=float(self.wide - 3), floor=8));
        }
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(self.long - 5), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        x0 = 8;
        x1 = 8 + self.channel;
        cy = self.wide // 2;
        works = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(works, 8);
        burning(build, x0, 1, -3, x1, self.wide - 1, 0, 4, 20);
        # The catwalk along the north wall over the floors and the channel, a
        # stair up to it on the near floor.
        slab(build, 1, self.wide - 5, self.long - 1, self.wide - 1, 8, 1);
        stair(build, 4, self.wide - 13, 0, 1, 8, 3);
        for x in range(4, 7) {
            build.keep(works, x, self.wide - 5, 8);
        }
        # The ore buckets riding across, each a floor flush with the banks.
        lanes = [cy - 4, cy] if self.buckets == 2 else [cy - 2];
        rides: list[Cue] = [];
        for lane in lanes {
            rides.append(build.train([3.0, 3.0, 1.0], [[float(x0), float(lane), -1.0], [float(x1 - 3), float(lane), -1.0]], 70.0, 2.5, self.fired));
            for y in range(lane, lane + 3) {
                build.keep(works, x0 - 1, y, 0);
                build.keep(works, x1, y, 0);
            }
        }
        build.doorway(works, self.enter);
        for port in self.taken {
            build.doorway(works, port);
        }
        # The switch on the near bank sets the buckets going (when they wait
        # for it); the far side's guards come as they start.
        far_side = build.waiting();
        if self.fired {
            # A switch on each bank, so a body come down onto the far one
            # can start them too.
            start_up = build.push(3.5, 1.0, 1.0, 1);
            far_switch = build.push(float(self.long) - 3.5, 1.0, 1.0, 1);
            for ride in rides {
                start_up +>:Fires:+> ride;
                far_switch +>:Fires:+> ride;
            }
            start_up +>:Fires:+> far_side;
            start_up +>:Fires:+> build.sparks(float(x0) - 0.5, 1.1, 2.0, 1);
            build.touch(1.0, 1.0, 0.0, 6.0, 5.0, 6.0, True, "Mine machinery inoperative. Start the buckets.");
        } else {
            build.touch(float(x0 - 3), 1.0, 0.0, float(x0), float(self.wide - 5), 6.0) +>:Fires:+> far_side;
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1 + 2 + index % 2 * 2) + 0.5, float(2 + index * 3) + 0.5, 0, MINE2_FOES.pick(dice, self.danger, index == 0), 180.0, waits=far_side);
        }
        # Up on the catwalk the gunners wake.
        up_top = build.touch(4.0, float(self.wide - 5), 8.0, 7.0, float(self.wide - 1), 14.0);
        catwalk = build.waiting();
        up_top +>:Fires:+> catwalk;
        build.foe(float(x1) + 0.5, float(self.wide) - 3.0, 8, "monster_gunner", 180.0, waits=catwalk);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, 8, MINE2_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 3.5, float(self.wide) - 3.0], [float(x0) + 0.5, float(self.wide) - 3.0]]);
        sparking(build, float(x1) + 0.5, 1.1, 3.0, 1, 5.0);
        build.supply(2.5, float(self.wide) - 7.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 3.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall of two storeys, a lava trench with an ore cart, a booth over the
trench; the machinery runs once both its switches are thrown."""
node MachineHall(Prefab) {
    has booth_x: int = 12,
        low_door: int = 6,
        low_switch: int = 10,
        by_lift: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Machine hall";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 26);
        self.tall = dice.between(16, 18);
        self.by_lift = dice.chance(0.4);
        self.booth_x = dice.between(10, self.long - 12);
        mid = self.wide // 2;
        self.low_door = dice.between(6, mid - 3);
        self.low_switch = self.low_door + 4 if self.low_door + 4 <= mid - 2 else self.low_door - 4;
        self.low = -13;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(6, mid - 3)), floor=0);
        self.leaves = [
            Port(face=1, along=float(dice.between(4, self.long - 5)), floor=8),
            Port(face=0, along=float(dice.between(mid + 2, self.wide - 4)), floor=8),
            Port(face=0, along=float(self.low_door), floor=0),
            Port(face=2, along=float(dice.between(mid + 2, self.wide - 4)), floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        bx = self.booth_x;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        # The upper storey over the hall's north half; the way up to it.
        slab(build, 1, mid, self.long - 1, self.wide - 1, 8, 1);
        if self.by_lift {
            lift(build, 4, mid - 3, 7, mid, 0, 8);
        } else {
            stair(build, 4, mid - 8, 0, 1, 8, 3);
        }
        for x in range(4, 7) {
            build.keep(hall, x, mid, 8);
        }
        # The lava trench along the south wall, the ore cart in it.
        burning(build, 3, 1, -3, self.long - 3, 4, 0, 4);
        cart = build.train([3.0, 3.0, 1.0], [[3.0, 1.0, -1.0], [float(self.long - 6), 1.0, -1.0]], 60.0, 2.0, True);
        # The booth over the trench, a catwalk from it to the upper storey.
        slab(build, bx, 1, bx + 5, 4, 8, 1);
        slab(build, bx + 1, 4, bx + 4, mid, 8, 1);
        build.doorway(hall, self.enter);
        # The machinery: both switches open the ways on, run the cart, throw
        # sparks and bring guards.
        running = build.tally(2, "Mine machinery activated.");
        build.push(float(self.long - 1), float(self.low_switch) + 0.5, 1.0, 2) +>:Fires:+> running;
        build.push(float(bx) + 2.5, 1.0, 9.0, 1) +>:Fires:+> running;
        build.touch(1.0, self.enter.along - 2.0, 0.0, 4.0, self.enter.along + 2.0, 6.0, True, "Mine machinery inoperative.");
        running +>:Fires:+> cart;
        running +>:Fires:+> build.sparks(float(self.long) - 3.5, float(mid) - 0.2, 6.0, 3);
        charges(build, running, [[float(self.long) - 2.5, 2.5, 4.0]], 0.5);
        for port in self.taken {
            build.doorway(hall, port);
            port_door(build, self.long, self.wide, port, running);
        }
        running +>:Fires:+> build.summon(self.long - 5, self.wide - 5, -12, "monster_gladiator" if self.danger > 0.3 else "monster_berserk", float(self.long // 2) + 0.5, float(mid) - 5.5, 0, 180.0);
        guards = build.waiting();
        late = build.delay(1.0);
        running +>:Fires:+> late;
        late +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 4 - index * 4) + 0.5, float(mid + 3) + 0.5, 8, MINE2_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        # Berserkers wake on the floor as the player comes in.
        come_in = build.touch(1.0, 5.0, 0.0, 5.0, float(mid - 1), 6.0);
        floor_guard = build.waiting();
        come_in +>:Fires:+> floor_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, float(mid) - 3.5, 0, "monster_berserk", 180.0, waits=floor_guard);
        }
        top_y = float(self.wide) - 3.0;
        build.foe(3.5, top_y, 8, "monster_gunner", 0.0, patrol=[[3.5, top_y], [float(self.long) - 4.5, top_y]]);
        build.foe(float(bx) + 2.5, 2.5, 8, MINE2_FOES.pick(dice, self.danger), 90.0);
        build.supply(float(self.long) - 3.5, float(mid) - 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(bx) + 0.5, 2.5, 8, "ammo_bullets", "q2");
    }
}

"""The key on the floor of a flooded sump split by a walkway."""
node FloodedSump(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded sump (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 7);
        self.tall = dice.between(11, 13);
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
        cy = side // 2;
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(cave, 6);
        build.doorway(cave, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -self.deep, x1, side - 2, 0, 2, False, False);
        # Steps up out of each half of it, along the walls away from the
        # walkway.
        stair(build, x0 + self.deep - 1, 3, -self.deep, 2, self.deep, 2);
        stair(build, x0 + self.deep - 1, side - 4, -self.deep, 2, self.deep, 2);
        # The walkway across the sump, and a gallery over the far end.
        slab(build, x0, cy - 1, x1, cy + 2, 0, 1);
        slab(build, x1 - 4, 1, self.long - 1, side, 6, 1);
        stair(build, x1 - 4 - 6, 1, 0, 0, 6, 2);
        key_ambush(build, self.key, float(x1) - 2.5, float(cy) - 2.5, -self.deep, side, 0, [2, self.long - 5], [MINE2_FOES.pick(dice, self.danger, True), MINE2_FOES.pick(dice, self.danger)]);
        swim = build.waiting();
        build.touch(float(x0), 3.0, float(-self.deep), float(x1), float(side - 2), -1.0) +>:Fires:+> swim;
        build.foe(float(x0 + 3) + 0.5, float(side) - 4.5, -self.deep + 1, "monster_flipper", 0.0, waits=swim);
        build.foe(float(self.long) - 2.5, float(cy) + 0.5, 6, MINE2_FOES.pick(dice, self.danger), 180.0);
        sparking(build, float(x1) - 4.2, float(cy) + 0.5, 3.0, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the elevator shaft and its cage down to the way out."""
node ShaftBottom(Prefab) {
    has key: str = "",
        shaft: int = 14,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shaft bottom" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE2;
        self.district = level_district(MINE2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.shaft = dice.between(12, 16);
        self.tall = dice.between(11, 13);
        self.low = -self.shaft - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wall = 8;
        low = -self.shaft;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, low, self.tall, self.key);
        build.level(room, low);
        sx = wall + 5;
        build.solid(wall + 1, 1, low, sx, self.wide - 1, 0);
        # The cage down the shaft, a perch over its foot.
        cage_ride = build.train([4.0, 4.0, 1.0], [[float(sx), float(cy - 2), -1.0], [float(sx), float(cy - 2), float(low)]], 90.0, 3.0, True);
        build.push(float(sx) - 1.5, float(self.wide - 1), 1.0, 3) +>:Fires:+> cage_ride;
        for y in range(cy - 2, cy + 2) {
            build.keep(room, sx - 1, y, 0);
        }
        slab(build, self.long - 4, 1, self.long - 1, self.wide - 1, low + 7, 1);
        build.way_out(float(self.long) - 6.0, float(cy), low);
        build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0) +>:Fires:+> build.objective("Return to the elevator shaft. Proceed down.");
        # The cage's arrival at the foot brings the guards out.
        foot = build.touch(float(sx), float(cy - 2), float(low), float(sx + 4), float(cy + 2), float(low + 4));
        below = build.waiting();
        foot +>:Fires:+> below;
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx + 6) + 0.5, 2.5 + float(index) * (float(self.wide) - 5.0) * 0.5, low, MINE2_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(float(self.long) - 2.5, float(cy) + 0.5, low + 7, MINE2_FOES.pick(dice, self.danger), 180.0);
        sparking(build, float(sx) + 0.5, 1.1, 3.0, 1, 4.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, MINE2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine2's stretches: [name, role]."""
glob MINE2_STRETCHES: list[list[str]] = [
         ["station", "start"],
         ["borehole", "flow"],
         ["conveyor", "flow"],
         ["machines", "hub"],
         ["station", "hub"],
         ["sump", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine2's stretches by its name."""
def make_mine2(name: str, key: str) -> Prefab {
    if name == "station" {
        return ElevatorStation();
    }
    if name == "borehole" {
        return BoreholeStair();
    }
    if name == "conveyor" {
        return ConveyorWorks();
    }
    if name == "machines" {
        return MachineHall();
    }
    if name == "sump" {
        return FloodedSump(key=key if key else "key_silver");
    }
    return ShaftBottom(key=key);
}
