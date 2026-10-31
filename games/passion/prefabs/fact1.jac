"""Prefabs drawn from Quake II's fact1, the Receiving Center: a factory's
docks over channels of slime with crates riding a conveyor, belts climbing
one over another under a crane, a processing floor of vats under a
catwalk ring, a hall whose door is opened elsewhere, a freight lift, the
key in a shipping office, the loading bay out to the processing plant.
Raised in fact1's own palette.

- `ReceivingDock`: the start. A dock, a channel of slime across it bridged
  once or twice, a gantry along the wall over it all, crates riding a
  conveyor along the other wall once its switch is thrown (fact1's three
  belts set going one after another); the help computer's objective;
  guards come as the player crosses; a crate breaks open on a stash (the
  secret), others break when shot.
- `SorterBelts`: two conveyors raised along a hall, the second over the
  first, up a ramp or a lift; a crane riding a crate along under the roof;
  guards on the upper belt come as the player climbs the first.
- `ProcessingFloor`: a floor of slime vats with presses pumping in them, a
  catwalk ring over it ridden up to by a lift or climbed by a stair, and a
  bridge across the ring (or not); ways on from the floor and the ring (a
  hub).
- `RemoteDoor`: a hall whose way on is shut ("This door is opened
  elsewhere"); the switch is in a control room on stilts over the floor,
  up a stair or a lift; throwing it opens the way and brings guards.
- `FreightLift`: a shaft, a landing high along its wall, the freight
  platform between; entered at the foot or at the top, by the seed.
- `ShippingOffice`: the key in an office up a lift or a stair over a store
  of crates; taking it opens the closets.
- `LoadingBay`: the end. A door (a key's, as a gate), a loading bay, a
  shutter over the dock the way out is on, raised by a switch on the bay's
  wall or by shooting one high over it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }
import from .bunk1 { crates }
import from .minefact { slab, hurt, burning, sparking, stash, charges, port_door, press, cart, crusher }

glob FACT1: str = "q2:fact1";

"""fact1's foes: soldiers and gunners, berserkers and hovers, a gladiator
deeper in."""
glob FACT1_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_gunner", "monster_soldier"], strong=["monster_hover", "monster_parasite"], heavy_light=["monster_gunner", "monster_berserk"], heavy_strong=["monster_gladiator"], scale=0.7, heavy_scale=0.5);

"""A crate two cells square and two lifts high at (x, y) on lift `z` that
breaks apart when shot."""
def crate(build: Raising, x: int, y: int, z: int) -> Cue {
    return build.breakable(float(x), float(y), float(z), float(x + 2), float(y + 2), float(z + 2), 20);
}

"""The start: a dock, a channel of slime across it, a gantry over it all,
crates riding a conveyor along the other wall."""
node ReceivingDock(Prefab) {
    has channel: int = 11,
        bridges: int = 2,
        deck: int = 9,
        rising: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Receiving dock";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 23);
        self.channel = dice.between(10, 12);
        self.bridges = dice.between(1, 2);
        self.deck = 9;
        self.rising = dice.chance(0.5);
        self.tall = self.deck + dice.between(7, 9);
        self.low = -self.deck - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(4, self.wide - 15)), floor=0),
            Port(face=1, along=float(dice.between(self.channel + 7, self.long - 6)), floor=0),
            Port(face=1, along=float(dice.between(4, self.channel - 2)), floor=self.deck),
            Port(face=0, along=float(self.wide - 3), floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cx = self.channel;
        dock = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(dock, self.deck);
        # The channel of slime across the dock, bridged once or twice.
        burning(build, cx, 1, -3, cx + 5, self.wide - 1, 0, 3, 10);
        spans = [[middle - 1, middle + 2]] if self.bridges == 1 else [[4, 7], [self.wide - 8, self.wide - 5]];
        for span in spans {
            build.solid(cx, span[0], -1, cx + 5, span[1], 0);
            for along in range(span[0], span[1]) {
                build.keep(dock, cx - 1, along, 0);
                build.keep(dock, cx + 5, along, 0);
            }
        }
        # The conveyor along the south wall, its crates set going one after
        # another by the switch on its near end.
        build.solid(3, 1, 0, self.long - 3, 3, 3);
        belt = build.push(3.0, 2.0, 1.0, 2);
        for index in range(3) {
            late = build.delay(0.2 + 0.4 * float(index));
            belt +>:Fires:+> late;
            start_x = float(4 + index * 7);
            late +>:Fires:+> build.train([2.0, 2.0, 2.0], [[start_x, 1.0, 3.0], [float(self.long - 6), 1.0, 3.0], [4.0, 1.0, 3.0]], 60.0, 1.0, True);
        }
        # The gantry along the north wall over the floor and the channel, a
        # stair up to it on the far floor.
        slab(build, 3, self.wide - 4, self.long - 1, self.wide - 1, self.deck, 1);
        if self.rising {
            # Its steps rise out of the floor as the conveyor starts.
            belt +>:Fires:+> build.rising_steps(self.long - 4, self.wide - 4 - self.deck, 0, 1, self.deck, 3);
        } else {
            stair(build, self.long - 4, self.wide - 4 - self.deck, 0, 1, self.deck, 3);
        }
        sparking(build, float(self.long) - 1.1, float(self.wide) - 8.5, 4.0, 2, 3.0);
        # A crate stack by the near wall, a stash in it behind a panel.
        build.solid(4, self.wide - 9, 0, 8, self.wide - 5, 5);
        stash(build, 5, self.wide - 8, 0, 3, Q2_ARMOR);
        crate(build, cx + 8, 4 if self.bridges == 1 else middle - 1, 0);
        crate(build, self.long - 8, self.wide - 7, 0);
        crates(build, dice, [[cx + 11, middle - 3]], 0);
        build.doorway(dock, self.enter);
        for port in self.taken {
            build.doorway(dock, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(middle - 3), 0.0, 5.0, float(middle + 3), 6.0) +>:Fires:+> build.objective("Shut down the alien processing plant. Find the entrance to the processing plant.");
        sparking(build, 3.5, 3.1, 4.0, 1, 4.0);
        # Crossing the channel brings the far floor's guards out.
        far_side = build.waiting();
        for span in spans {
            build.touch(float(cx + 1), float(span[0]), 0.0, float(cx + 4), float(span[1]), 6.0) +>:Fires:+> far_side;
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 5 - index * 3) + 0.5, float(4 + index * 4) + 0.5, 0, FACT1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=far_side);
        }
        walk_y = float(self.wide) - 2.5;
        build.foe(4.5, walk_y, self.deck, "monster_soldier", 0.0, patrol=[[4.5, walk_y], [float(self.long) - 2.5, walk_y]]);
        build.foe(float(cx) + 7.5, float(middle) - 3.5, 0, "monster_gunner", 90.0, patrol=[[float(cx) + 7.5, float(middle) - 3.5], [float(self.long) - 5.5, float(middle) - 3.5]]);
        build.foe(float(cx) + 2.5, float(middle) + 0.5, 6, "monster_hover", 180.0);
        build.supply(float(self.long) - 2.5, 4.5, 0, Q2_HEALTH, "q2");
    }
}

"""Two conveyors raised along a hall, the second over the first; a crane
riding a crate along under the roof."""
node SorterBelts(Prefab) {
    has first: int = 4,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sorter belts";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.first = dice.between(4, 5);
        self.by_lift = dice.chance(0.4);
        self.tall = 2 * self.first + dice.between(8, 9);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=2 * self.first), Port(face=0, along=3.0, floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(self.long // 2), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        f = self.first;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, f);
        build.level(hall, 2 * f);
        # The first belt down the middle, a ramp up its near end; the second
        # along the north wall over it, up a ramp from the first's far end
        # or a lift from the floor.
        build.solid(4 + f, middle - 2, 0, self.long - 6, middle + 1, f);
        stair(build, 4, middle - 2, 0, 0, f, 3);
        slab(build, 4, self.wide - 4, self.long - 1, self.wide - 1, 2 * f, 1);
        if self.by_lift {
            lift(build, 6, self.wide - 7, 9, self.wide - 4, 0, 2 * f);
            for x in range(6, 9) {
                build.keep(hall, x, self.wide - 4, 2 * f);
            }
        } else {
            stair(build, self.long - 6, middle - 2, f, 1, f, 3);
            build.solid(self.long - 6, middle - 2 + f, f, self.long - 3, self.wide - 4, 2 * f);
            for x in range(self.long - 6, self.long - 3) {
                build.keep(hall, x, self.wide - 5, 2 * f);
            }
        }
        crates(build, dice, [[8 + f, middle - 2]], f);
        crate(build, self.long // 2, self.wide - 7, 0);
        build.solid(7, 1, 0, 11, 5, 5);
        stash(build, 8, 2, 0, 1, "ammo_grenades");
        crate(build, 3, 2, 0);
        # The crane riding a crate along under the roof.
        build.train([2.0, 2.0, 2.0], [[5.0, float(middle - 1), float(self.tall - 3)], [float(self.long - 7), float(middle - 1), float(self.tall - 3)]], 50.0, 2.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Climbing the first belt brings the upper belt's guards out.
        climb = build.touch(4.0, float(middle - 2), 1.0, float(4 + f), float(middle + 1), float(f + 5));
        upper = build.waiting();
        climb +>:Fires:+> upper;
        build.foe(float(self.long) - 4.0, float(self.wide) - 2.5, 2 * f, FACT1_FOES.pick(dice, self.danger, True), 180.0, waits=upper);
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, 2 * f, FACT1_FOES.pick(dice, self.danger), 180.0, waits=upper);
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 6) + 0.5, 2.5, 0, FACT1_FOES.pick(dice, self.danger), 90.0);
        }
        build.foe(6.5, float(middle) + 2.5, 0, "monster_soldier", 0.0, patrol=[[6.5, float(middle) + 2.5], [float(self.long) - 7.5, float(middle) + 2.5]]);
        sparking(build, 1.1, float(middle) + 3.5, 3.0, 0, 5.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) - 0.5, f, FACT1_FOES.pick(dice, self.danger), 180.0);
        sparking(build, float(self.long) - 6.2, float(middle) - 1.0, float(f) + 2.0, 2, 4.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 2 * f, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A floor of slime vats with presses pumping in them, a catwalk ring
over it, a bridge across the ring."""
node ProcessingFloor(Prefab) {
    has walk: int = 7,
        by_lift: bool = True,
        across: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Processing floor";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(7, 8);
        self.by_lift = dice.chance(0.5);
        self.across = dice.chance(0.6);
        self.tall = self.walk + 10;
        self.low = -self.walk - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=4.0, floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        floor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(floor, self.walk);
        vats: list[list[int]] = [];
        for vx in range(7, self.long - 8, 7) {
            for vy in [5, self.wide - 10] {
                burning(build, vx, vy, -2, vx + 5, vy + 5, 0, 3, 8);
                vats.append([vx, vy]);
            }
        }
        # Presses pumping in two of the vats.
        for vat in vats[:2] {
            crusher(build, float(vat[0] + 1), float(vat[1] + 1), [3.0, 3.0, 3.0], -1.0, 4.0, 80.0, 1.0, 20);
        }
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(1, 4, under, 4, self.wide - 4, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        if self.across {
            slab(build, self.long // 2 - 1, 4, self.long // 2 + 2, self.wide - 4, self.walk, 1);
        }
        if self.by_lift {
            lift(build, 4, middle - 1, 7, middle + 2, 0, self.walk);
            for y in range(middle - 2, middle + 3) {
                build.keep(floor, 3, y, self.walk);
            }
        } else {
            build.push(1.0, float(middle) - 3.5, 1.0, 0) +>:Fires:+> build.rising_steps(4 + self.walk - 1, middle - 1, 0, 2, self.walk, 3);
            for y in range(middle - 1, middle + 2) {
                build.keep(floor, 3, y, self.walk);
            }
        }
        build.solid(1, middle + 3, 0, 4, middle + 7, under);
        stash(build, 2, middle + 4, 0, 0, Q2_ARMOR);
        build.doorway(floor, self.enter);
        for port in self.taken {
            build.doorway(floor, port);
        }
        sparking(build, float(self.long) - 1.1, float(middle) + 0.5, float(self.walk) + 3.0, 2, 3.5);
        # Guards wake on the floor as the player walks in; on the ring as the
        # player comes up.
        come_in = build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0);
        floor_guard = build.waiting();
        come_in +>:Fires:+> floor_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 5) + 0.5, float(middle) + 0.5, 0, FACT1_FOES.pick(dice, self.danger), 0.0, waits=floor_guard);
        }
        up_ring = build.touch(1.0, 4.0, float(self.walk), 4.0, float(self.wide - 4), float(self.walk + 6));
        ring_guard = build.waiting();
        up_ring +>:Fires:+> ring_guard;
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.walk, FACT1_FOES.pick(dice, self.danger, True), 180.0, waits=ring_guard);
        ring = [[2.5, 2.5], [float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5], [2.5, float(self.wide) - 2.5]];
        build.foe(float(self.long // 2) + 0.5, 2.5, self.walk, "monster_soldier_ss", 0.0, patrol=[ring[1], ring[2], ring[3], ring[0]]);
        sparking(build, 4.1, float(middle) + 3.5, 3.0, 0, 4.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, 6.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall whose way on is opened from a control room on stilts over its
floor."""
node RemoteDoor(Prefab) {
    has deck: int = 7,
        way_up: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Remote door";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.deck = 7;
        self.way_up = dice.below(3);
        self.tall = self.deck + dice.between(7, 9);
        self.low = -self.deck - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 10)), floor=0);
        self.leaves = [Port(face=0, along=float(dice.between(4, self.wide - 9)), floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(dice.between(16, self.long - 5)), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deck;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, d);
        # The control room on stilts over the near end of the floor.
        slab(build, 1, self.wide - 7, 10, self.wide - 1, d, 1);
        for at in [[3, self.wide - 7], [8, self.wide - 7]] {
            build.solid(at[0], at[1], 0, at[0] + 1, at[1] + 1, d - 1);
        }
        build.solid(1, self.wide - 7, d, 9, self.wide - 6, d + 2);
        build.widen(hall, 4, self.wide - 7, d, 7, self.wide - 6, d + 2);
        if self.way_up == 1 {
            lift(build, 10, self.wide - 7, 13, self.wide - 4, 0, d);
        } elif self.way_up == 2 {
            build.push(8.5, float(self.wide - 7), 1.0, 3) +>:Fires:+> build.rising_steps(10, self.wide - 13, 0, 1, d, 3);
        } else {
            stair(build, 10, self.wide - 13, 0, 1, d, 3);
        }
        build.solid(self.long - 6, self.wide - 6, 0, self.long - 2, self.wide - 2, 5);
        stash(build, self.long - 5, self.wide - 5, 0, 2, Q2_ARMOR);
        sparking(build, float(self.long) - 6.1, float(self.wide) - 3.5, 3.0, 2, 4.0);
        for y in range(self.wide - 7, self.wide - 4) {
            build.keep(hall, 9, y, d);
        }
        crate(build, self.long - 8, 2, 0);
        crate(build, 14, self.wide - 4, 0);
        crates(build, dice, [[self.long // 2, 3]], 0);
        build.doorway(hall, self.enter);
        # The way on, shut until the switch in the control room is thrown.
        remote = build.push(4.5, float(self.wide - 1), float(d) + 1.0, 3);
        for port in self.taken {
            build.doorway(hall, port);
            port_door(build, self.long, self.wide, port, remote);
        }
        build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(self.wide - 1), 6.0, True, "This door is opened elsewhere.");
        remote +>:Fires:+> build.sparks(4.5, float(self.wide) - 1.2, float(d) + 3.0, 3);
        beyond = build.waiting();
        late = build.delay(1.0);
        remote +>:Fires:+> late;
        late +>:Fires:+> beyond;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 4) + 0.5, float(3 + index * 4) + 0.5, 0, FACT1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=beyond);
        }
        come_in = build.touch(1.0, self.enter.along - 2.0, 0.0, 4.0, self.enter.along + 2.0, 6.0);
        hall_guard = build.waiting();
        come_in +>:Fires:+> hall_guard;
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, FACT1_FOES.pick(dice, self.danger), 180.0, waits=hall_guard);
        build.foe(2.5, float(self.wide) - 3.0, d, FACT1_FOES.pick(dice, self.danger), 0.0);
        mid_y = float(self.wide // 2) - 2.5;
        build.foe(12.5, mid_y, 0, "monster_soldier_ss", 0.0, patrol=[[12.5, mid_y], [float(self.long) - 5.5, mid_y]]);
        build.supply(8.5, float(self.wide) - 3.0, d, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, float(self.wide) - 3.5, 0, "ammo_bullets", "q2");
    }
}

"""A shaft, a landing high along its wall, the freight platform between."""
node FreightLift(Prefab) {
    has up: int = 15,
        down: bool = False,
        lift_x: int = 5,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Freight lift";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(18, 22);
        self.wide = dice.between(17, 19);
        self.up = dice.between(14, 16);
        self.down = dice.chance(0.4);
        self.lift_x = dice.between(4, self.long - 9);
        self.tall = self.up + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top_along = float(self.wide - 4);
        foot_along = float(dice.between(3, self.wide - 13));
        if self.down {
            self.enter = Port(face=2, along=top_along, floor=self.up);
            self.leaves = [Port(face=0, along=foot_along, floor=0), Port(face=3, along=float(dice.between(4, self.long - 5)), floor=0)];
        } else {
            self.enter = Port(face=2, along=foot_along, floor=0);
            self.leaves = [Port(face=0, along=top_along, floor=self.up), Port(face=1, along=float(dice.between(3, self.long - 4)), floor=self.up)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lx = self.lift_x;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.up);
        slab(build, 1, self.wide - 6, self.long - 1, self.wide - 1, self.up, 2);
        lift(build, lx, self.wide - 11, lx + 5, self.wide - 6, 0, self.up);
        for x in range(lx, lx + 5) {
            build.keep(shaft, x, self.wide - 6, self.up);
        }
        crate(build, self.long - 4, self.wide - 9, 0);
        crates(build, dice, [[2, self.wide - 9]], 0);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Arriving at the other end brings its guards out.
        at_top = 0 if self.down else self.up;
        arrive = build.touch(float(lx), float(self.wide - 11), float(at_top), float(lx + 5), float(self.wide - 6), float(at_top + 4));
        arrival = build.waiting();
        arrive +>:Fires:+> arrival;
        for index in range(dice.between(1, 2)) {
            if self.down {
                build.foe(float(self.long - 4) + 0.5, float(5 + index * 3) + 0.5, 0, FACT1_FOES.pick(dice, self.danger), 180.0, waits=arrival);
            } else {
                build.foe(float(self.long - 3) + 0.5, float(self.wide) - 2.5 - float(index) * 2.0, self.up, FACT1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=arrival);
            }
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) - 4.5, self.up // 2, "monster_hover", 90.0);
        build.foe(3.5, float(self.wide) - 3.5, self.up, freight_guard(dice, self.danger), 0.0);
        sparking(build, float(lx) + 5.2, float(self.wide - 11) + 0.5, 3.0, 0, 4.0);
        sparking(build, 1.1, float(self.wide) - 3.5, float(self.up) + 3.0, 0, 5.0);
        build.supply(2.5, float(self.wide) - 8.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.5, self.up, "ammo_bullets", "q2");
    }
}

"""A guard for a high landing: a gunner, or a heavy one deeper in."""
def freight_guard(dice: Stream, danger: float) -> str {
    return FACT1_FOES.pick(dice, danger, dice.chance(danger));
}

"""The key in an office up a lift or a stair over a store of crates;
taking it opens the closets."""
node ShippingOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 6,
        by_lift: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shipping office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(6, 7);
        self.by_lift = dice.chance(0.5);
        self.tall = self.office + 8;
        self.low = -self.office - 1;
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
        store = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(store, self.office);
        build.doorway(store, self.enter);
        ox = self.long - 6;
        build.solid(ox, 1, self.office - 1, self.long - 1, side, self.office);
        if self.by_lift {
            lift(build, ox - 3, cy - 1, ox, cy + 2, 0, self.office);
        } else {
            build.push(float(ox) - 1.5, 1.0, 1.0, 1) +>:Fires:+> build.rising_steps(ox - self.office, cy - 1, 0, 0, self.office, 3);
        }
        for y in range(cy - 2, cy + 3) {
            build.keep(store, ox, y, self.office);
        }
        build.solid(ox - 8, 1, 0, ox - 4, 5, 5);
        stash(build, ox - 7, 2, 0, 1, "ammo_grenades");
        crates(build, dice, [[5, 2], [9, 4]], 0);
        crate(build, 5, side - 3, 0);
        crate(build, ox - 5, side - 4, 0);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.office, side, 0, [2, ox - 3], [FACT1_FOES.pick(dice, self.danger, True), FACT1_FOES.pick(dice, self.danger)]);
        office_guard = build.waiting();
        build.touch(float(ox), float(cy - 2), float(self.office), float(ox + 2), float(cy + 3), float(self.office + 6)) +>:Fires:+> office_guard;
        build.foe(float(self.long) - 2.5, 2.5, self.office, FACT1_FOES.pick(dice, self.danger), 180.0, waits=office_guard);
        build.foe(3.5, float(cy) + 0.5, 0, "monster_soldier", 90.0, patrol=[[3.5, 2.5], [3.5, float(side) - 2.5]]);
        sparking(build, float(self.long) - 1.1, float(cy) - 3.5, float(self.office) + 2.0, 2, 5.0);
        build.supply(2.5, float(cy) + 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a loading bay, a shutter over the dock the way out is
on."""
node LoadingBay(Prefab) {
    has key: str = "",
        dock: int = 3,
        shot: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Loading bay" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT1;
        self.district = level_district(FACT1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.dock = dice.between(3, 4);
        self.shot = dice.chance(0.5);
        self.tall = dice.between(13, 15);
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
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, self.dock);
        dx = self.long - 6;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, middle - 2, 0, 0, self.dock, 4);
        build.way_out(float(self.long) - 3.0, float(middle), self.dock);
        # The shutter across the bay before the dock, raised by a switch on
        # the bay's wall or by shooting one high over it.
        sx = dx - self.dock - 2;
        build.solid(sx, 1, 0, sx + 1, self.wide - 1, self.tall);
        build.widen(room, sx, middle - 3, 0, sx + 1, middle + 3, 8);
        shutter = build.opened(float(sx), float(middle - 3), 0.0, float(sx + 1), float(middle + 3), 8.0);
        if self.shot {
            trip = build.push(float(sx), float(middle) - 5.0, 10.0, 2, True);
        } else {
            trip = build.push(float(wall + 1), 2.5, 1.0, 0);
        }
        trip +>:Fires:+> shutter;
        trip +>:Fires:+> build.objective("Find the entrance to the processing plant.");
        build.touch(float(sx - 3), float(middle - 3), 0.0, float(sx), float(middle + 3), 6.0, True, "This door is opened elsewhere.");
        crate(build, wall + 2, self.wide - 4, 0);
        crate(build, sx - 4, 2, 0);
        sparking(build, float(sx) - 0.1, float(middle) + 4.5, 5.0, 2, 3.0);
        sparking(build, float(self.long) - 1.1, 2.5, float(self.dock) + 3.0, 2, 4.5);
        dock_guard = build.waiting();
        trip +>:Fires:+> dock_guard;
        build.foe(float(self.long) - 2.5, 2.5, self.dock, FACT1_FOES.pick(dice, self.danger, True), 180.0, waits=dock_guard);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, FACT1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(sx) - 3.0, float(middle) + 4.5, 0, "monster_gunner", 270.0, patrol=[[float(sx) - 3.0, float(middle) + 4.5], [float(wall) + 3.0, float(middle) + 4.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact1's stretches: [name, role]."""
glob FACT1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["belts", "flow"],
         ["remote", "flow"],
         ["freight", "flow"],
         ["processing", "hub"],
         ["processing", "flow"],
         ["office", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact1's stretches by its name."""
def make_fact1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return ReceivingDock();
    }
    if name == "belts" {
        return SorterBelts();
    }
    if name == "remote" {
        return RemoteDoor();
    }
    if name == "freight" {
        return FreightLift();
    }
    if name == "processing" {
        return ProcessingFloor();
    }
    if name == "office" {
        return ShippingOffice(key=key if key else "key_silver");
    }
    return LoadingBay(key=key);
}
