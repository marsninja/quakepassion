"""Prefabs drawn from Quake II's mine1, the Upper Mines: a level that
climbs. The foot of the great shaft by the lower mines' exit, sealed for
the toxic air; a cage riding up the shaft past its galleries; the great
lift a switch sets going; a gallery where charges keep going off until
the blasting is stopped; a cavern of terraces whose valves must all be
opened; a bridge whose barrier a control switch lifts; the ventilation
controls and the way out once the air is clear. Raised in mine1's own
palette.

- `ShaftFoot`: the start. A hall at the foot of the shaft, the sealed
  exit to the lower mines ("Access denied. Toxic conditions"), a cage
  riding up beside a middle gallery and a top gallery, both over the hall
  (and a stair to the middle one, or not); the help computer's objective;
  guards come out onto the galleries as the player boards the cage; a
  panel on a pump breaks open on a stash (the secret). Ways on from the
  floor and both galleries.
- `GreatLift`: a shaft twenty lifts and more deep, a landing over its
  floor at the top, a platform a switch at either end sets riding between
  them (mine1's great lift); entered at the foot or at the top, by the
  seed; guards come at the far end as it starts; a slime sump in a corner.
- `BlastGallery`: a long gallery, a scaffold along its side over the
  floor, a rock fall across it; walking in sets charges going off along
  it again and again until the switch at its far end (on the scaffold or
  the floor) stops them (mine1's timed blasts, killed by a button); a
  panel on a machine breaks open on a stash.
- `ValveCavern`: a cavern of terraces, each higher and the top one a
  gallery over the floor; a valve on each, and all three open the ways on
  (mine1's counter), hovers coming in one after another as they turn; a
  lift up to the gallery and a pool in the floor, or not (a hub).
- `BarrierBridge`: a gorge, a bridge across it barred at its head
  ("Bridge access denied"); the switch that lifts the barrier is on a
  control balcony over the gorge or down on the gorge's floor; guards
  appear on the far side as it lifts.
- `VentControl`: the key on a control deck over the fan room, up a lift or
  a stair; taking it opens the closets below.
- `ToxicExit`: the end. A door (a key's, as a gate), a hall, the way out
  behind a door sealed for the toxic air that the ventilation switch on
  a gantry opens ("Ventilation systems active")."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, stalactites, key_ambush, gate_into, lift }
import from .minefact { slab, hurt, burning, sparking, stash, charges, timer_off, port_door, sealed }

glob MINE1: str = "q2:mine1";

"""mine1's foes: soldiers and gunners, hovers, gladiators deeper in."""
glob MINE1_FOES: FoeMix = FoeMix(light=["monster_soldier", "monster_soldier", "monster_gunner"], strong=["monster_gladiator"], heavy_light=["monster_gunner", "monster_gladiator"], heavy_strong=["monster_mutant"], scale=0.7, heavy_scale=0.5, flying="monster_hover");

"""The start: the foot of the great shaft, a cage up past two galleries."""
node ShaftFoot(Prefab) {
    has mid: int = 10,
        top: int = 19,
        stair_up: bool = True,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shaft foot";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 24);
        self.mid = dice.between(9, 11);
        self.top = self.mid + dice.between(9, 12);
        self.tall = self.top + 9;
        self.stair_up = dice.chance(0.6);
        self.low = -1;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=self.top),
            Port(face=3, along=float(dice.between(8, self.long - 9)), floor=self.mid),
            Port(face=1, along=float(dice.between(8, self.long - 9)), floor=self.top),
            Port(face=1, along=float(dice.between(8, self.long - 9)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.mid);
        build.level(hall, self.top);
        # The galleries over the hall, a jetty from each to the cage.
        slab(build, 6, 1, self.long - 1, 6, self.mid, 2);
        slab(build, self.long - 6, 6, self.long - 2, cy - 2, self.mid, 2);
        slab(build, 6, self.wide - 6, self.long - 1, self.wide - 1, self.top, 2);
        slab(build, self.long - 6, cy + 2, self.long - 2, self.wide - 6, self.top, 2);
        cage = [float(self.long - 6), float(cy - 2)];
        build.train([4.0, 4.0, 1.0], [[cage[0], cage[1], 0.0], [cage[0], cage[1], float(self.mid - 1)], [cage[0], cage[1], float(self.top - 1)], [cage[0], cage[1], float(self.mid - 1)]], 90.0, 2.5);
        for x in range(self.long - 6, self.long - 2) {
            build.keep(hall, x, cy - 3, self.mid);
            build.keep(hall, x, cy + 2, self.top);
        }
        if self.stair_up {
            stair(build, 6, 6, 0, 0, self.mid, 3);
            for x in range(4 + self.mid, 7 + self.mid) {
                build.keep(hall, x, 5, self.mid);
            }
        } else {
            # An updraft from a vent in the floor, three cells back from the
            # middle gallery's edge, throws a body up onto it.
            vx = self.long // 2 - 2;
            build.jump_pad(float(vx) + 0.5, 8.5, 0, float(vx) + 0.5, 3.0, self.mid);
            for x in range(vx - 1, vx + 2) {
                build.keep(hall, x, 5, self.mid);
            }
            sparking(build, float(vx) + 0.5, 8.5, 0.5, 1, 2.5);
        }
        # A pump against the north wall by the sealed exit, a stash behind
        # a panel on it.
        build.solid(1, self.wide - 6, 0, 4, self.wide - 1, 6);
        stash(build, 1, self.wide - 5, 0, 0, Q2_ARMOR);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The exit to the lower mines, sealed for the toxic air.
        sealed(build, self.long, self.wide, self.enter, kit.door);
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 6.0, True, "Access denied. Toxic conditions in the lower mines.");
        sparking(build, 1.1, float(cy) - 3.5, 3.0, 0, 4.0);
        build.start(6.5, float(cy) + 0.5, 0, 0.0);
        build.supply(6.5, float(cy) - 2.5, 0, "ammo_shells", "q2");
        build.touch(5.0, float(cy - 3), 0.0, 9.0, float(cy + 3), 6.0) +>:Fires:+> build.objective("Toxic conditions found in the lower mines. Find the ventilation controls.");
        # Guards come out onto the galleries as the player boards the cage.
        board = build.touch(cage[0], cage[1], 0.0, cage[0] + 4.0, cage[1] + 4.0, 4.0);
        galleries = build.waiting();
        board +>:Fires:+> galleries;
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 5) + 0.5, 3.5, self.mid, MINE1_FOES.pick(dice, self.danger), 90.0, waits=galleries);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.5, self.top, MINE1_FOES.pick(dice, self.danger, True), 270.0, waits=galleries);
        top_y = float(self.wide) - 3.5;
        build.foe(8.5, top_y, self.top, "monster_gunner", 0.0, patrol=[[8.5, top_y], [float(self.long) - 3.5, top_y]]);
        # Stepping off the cage at the top brings more out of the drift.
        arrive = build.touch(float(self.long - 6), float(cy + 2), float(self.top), float(self.long - 2), float(self.wide - 6), float(self.top + 6));
        drift = build.waiting();
        arrive +>:Fires:+> drift;
        for index in range(dice.between(1, 2)) {
            build.foe(7.5 + float(index) * 3.0, top_y, self.top, MINE1_FOES.pick(dice, self.danger), 0.0, waits=drift);
        }
        build.foe(float(self.long) - 8.5, float(cy) + 3.5, 0, MINE1_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, self.mid + 3, MINE1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 3.5, 3.5, self.mid, Q2_HEALTH, "q2");
        build.supply(8.5, float(self.wide) - 3.5, self.top, "ammo_bullets", "q2");
    }
}

"""A deep shaft, a landing over its floor at the top, a platform a switch
at either end sets riding between them."""
node GreatLift(Prefab) {
    has up: int = 22,
        down: bool = False,
        lift_x: int = 6,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Great lift";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(22, 26);
        self.wide = dice.between(20, 22);
        self.up = dice.between(24, 30);
        self.tall = self.up + 9;
        self.down = dice.chance(0.25);
        self.lift_x = dice.between(5, self.long - 10);
        self.low = -4;
        self.high = self.tall + 1;
        floor_along = float(dice.between(3, self.wide - 14));
        top_along = float(self.wide - 4);
        # The ways out along the walls the switches are on keep clear of
        # them.
        lx = self.lift_x;
        clear_x = float(dice.between(4, lx - 2)) if lx >= 9 else float(dice.between(lx + 8, self.long - 5));
        if self.down {
            self.enter = Port(face=2, along=top_along, floor=self.up);
            self.leaves = [
                Port(face=0, along=floor_along, floor=0),
                Port(face=3, along=clear_x, floor=0),
                Port(face=1, along=clear_x, floor=self.up)
            ];
        } else {
            self.enter = Port(face=2, along=floor_along, floor=0);
            self.leaves = [
                Port(face=0, along=top_along, floor=self.up),
                Port(face=1, along=clear_x, floor=self.up),
                Port(face=3, along=clear_x, floor=0)
            ];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lx = self.lift_x;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.up);
        # The landing at the top along the north wall, over the floor.
        slab(build, 1, self.wide - 7, self.long - 1, self.wide - 1, self.up, 2);
        # The great lift beside it, set going by a switch at either end.
        ride = build.train([5.0, 5.0, 1.0], [[float(lx), float(self.wide - 12), 0.0], [float(lx), float(self.wide - 12), float(self.up - 1)]], 100.0, 3.0, True);
        for x in range(lx, lx + 5) {
            build.keep(shaft, x, self.wide - 7, self.up);
        }
        foot_switch = build.push(float(lx) + 2.5, 1.0, 1.0, 1);
        top_switch = build.push(float(lx) + 2.5, float(self.wide - 1), float(self.up) + 1.0, 3);
        foot_switch +>:Fires:+> ride;
        top_switch +>:Fires:+> ride;
        # Guards come at the far end as it starts.
        far_end = build.waiting();
        (top_switch if self.down else foot_switch) +>:Fires:+> far_end;
        for index in range(dice.between(2, 3)) {
            if self.down {
                build.foe(float(3 + index * 5) + 0.5, 3.5, 0, MINE1_FOES.pick(dice, self.danger, index == 0), 90.0, waits=far_end);
            } else {
                build.foe(float(self.long - 3 - index * 5) + 0.5, float(self.wide) - 3.5, self.up, MINE1_FOES.pick(dice, self.danger, index == 0), 270.0, waits=far_end);
            }
        }
        # Arriving at the other end brings a second wave.
        arrival = build.touch(float(lx), float(self.wide - 7), float(0 if self.down else self.up), float(lx + 5), float(self.wide - 4), float((0 if self.down else self.up) + 6));
        second = build.waiting();
        arrival +>:Fires:+> second;
        for index in range(dice.between(1, 2)) {
            if self.down {
                build.foe(float(self.long // 2 + index * 3) + 0.5, 4.5, 0, MINE1_FOES.pick(dice, self.danger), 90.0, waits=second);
            } else {
                build.foe(float(self.long) - 3.5, float(self.wide) - 2.5 - 2.0 * float(index), self.up, MINE1_FOES.pick(dice, self.danger), 180.0, waits=second);
            }
        }
        # A slime sump in the floor's corner.
        burning(build, self.long - 6, 2, -3, self.long - 2, 6, 0, 3, 8);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        sparking(build, float(lx) + 5.2, float(self.wide - 12) + 0.5, 3.0, 0, 5.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) - 3.5, 0, MINE1_FOES.pick(dice, self.danger), 0.0);
        build.foe(3.5, float(self.wide) - 4.0, self.up, MINE1_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) - 4.5, self.up // 2, MINE1_FOES.pick(dice, self.danger, False, True), 90.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.5, self.up, "ammo_bullets", "q2");
    }
}

"""A long gallery falling (or climbing) a few lifts partway along where its
roof came down, a scaffold along its side over both floors, where charges
keep going off until the switch at its far end stops them."""
node BlastGallery(Prefab) {
    has deck: int = 5,
        far_z: int = -5,
        fall_x: int = 14,
        house_x: int = 6,
        east_stair: bool = True,
        high_switch: bool = True,
        tall: int = 12;

    """Where the scaffold ends (the cell column past it)."""
    def deck_end -> int {
        dip = abs(self.far_z);
        if self.east_stair {
            return self.long - 4 - (self.deck - self.far_z);
        }
        return self.fall_x + dip + 4;
    }

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blast gallery";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(34, 38);
        self.wide = dice.between(12, 14);
        dip = dice.between(4, 7);
        self.far_z = dip if dice.chance(0.6) else -dip;
        self.deck = max(0, self.far_z) + 5;
        self.tall = max(0, self.far_z) + dice.between(12, 13);
        self.long = max(self.long, self.deck + dip + 16);
        self.fall_x = dice.between(self.deck + 7, self.long - dip - 9);
        east_top = self.long - 4 - (self.deck - self.far_z);
        self.east_stair = self.fall_x + dip + 2 <= east_top;
        self.house_x = dice.between(5, self.fall_x - 5);
        self.high_switch = dice.chance(0.5);
        self.low = min(0, self.far_z) - 9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(6, self.wide - 3)), floor=0);
        self.leaves = [Port(face=0, along=6.0, floor=self.far_z)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(dice.between(6 + self.deck, self.deck_end() - 6)), floor=self.deck));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        fz = self.far_z;
        dip = abs(fz);
        zmin = min(0, fz);
        rx = self.fall_x;
        last = self.deck_end();
        gallery = build.room(1, 1, zmin, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(gallery, 0);
        build.level(gallery, fz);
        build.level(gallery, self.deck);
        # Where the roof came down the floor falls (or climbs) a lift a cell.
        if fz < 0 {
            build.solid(1, 1, fz, rx, self.wide - 1, 0);
            stair(build, rx + dip - 1, 1, fz, 2, dip, self.wide - 2);
        } else {
            build.solid(rx + dip, 1, 0, self.long - 1, self.wide - 1, fz);
            stair(build, rx, 1, 0, 0, dip, self.wide - 2);
        }
        # The scaffold along the south wall over both floors, a stair up at
        # the near end and (room allowing) at the far end; posts under it.
        slab(build, 4 + self.deck, 1, last, 4, self.deck, 1);
        stair(build, 4, 1, 0, 0, self.deck, 3);
        if self.east_stair {
            stair(build, self.long - 5, 1, fz, 2, self.deck - fz, 3);
        } else {
            # Its end hangs over the far floor, a drop down kept clear.
            for y in range(1, 4) {
                build.keep(gallery, last - 1, y, self.deck);
            }
        }
        for x in range(6 + self.deck, last - 1, 4) {
            if x < rx or x >= rx + dip {
                base = 0 if x < rx else fz;
                build.solid(x, 1, base, x + 1, 2, self.deck - 1);
            }
        }
        # Timber props along the north wall.
        for x in range(4, self.long - 3, 5) {
            build.solid(x, self.wide - 2, zmin, x + 1, self.wide - 1, self.tall);
        }
        # The rock fall's rubble on the far floor: a bank, a crest a
        # barrier's jump higher.
        px = rx + dip + 1;
        build.solid(px, 5, fz, px + 2, self.wide - 2, fz + 1);
        build.solid(px, 6, fz + 1, px + 1, self.wide - 3, fz + 3);
        # A machine against the north wall, a stash behind a panel on it.
        hx = self.house_x;
        build.solid(hx, self.wide - 4, 0, hx + 4, self.wide - 1, 5);
        stash(build, hx + 1, self.wide - 3, 0, 3, "ammo_grenades");
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        # Walking in sets charges going off along the gallery, again and
        # again, until the switch at the far end stops them.
        walk_in = build.touch(2.0, 4.0, 0.0, 6.0, float(self.wide - 1), 8.0);
        if self.high_switch {
            stop = build.push(float(last - 2), 1.0, float(self.deck) + 1.0, 1);
        } else {
            stop = build.push(float(self.long - 1), float(self.wide) - 2.5, float(fz) + 1.0, 2);
        }
        for index in range(3) {
            blasts = timer_off(build, 3.5);
            walk_in +>:Fires:+> blasts;
            stop +>:Fires:+> blasts;
            at = 8 + index * (self.long - 14) // 2;
            blasts +>:Fires:+> build.explosion(float(at) + 0.5, float(self.wide) - 2.5 if index % 2 == 0 else 5.5, float(self.tall - 3));
        }
        # Down (or up) the fall the guards come; the switch brings more.
        crest = build.touch(float(rx), 4.0, float(zmin), float(rx + dip), float(self.wide - 1), float(max(0, fz) + 6));
        beyond = build.waiting();
        crest +>:Fires:+> beyond;
        for index in range(dice.between(1, 2)) {
            build.foe(float(px + 3 + index * 3) + 0.5, float(self.wide) - 4.5, fz, MINE1_FOES.pick(dice, self.danger), 180.0, waits=beyond);
        }
        callers = build.waiting();
        stop +>:Fires:+> callers;
        stop +>:Fires:+> build.summon(self.long - 5, self.wide - 4, zmin - 8, MINE1_FOES.pick(dice, self.danger, True), float(px + 3) + 0.5, float(self.wide // 2) + 1.5, fz, 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide // 2) + 1.5, fz, MINE1_FOES.pick(dice, self.danger, True), 180.0, waits=callers);
        build.foe(float(5 + self.deck) + 0.5, 2.5, self.deck, "monster_soldier", 0.0, patrol=[[float(5 + self.deck) + 0.5, 2.5], [float(last) - 1.5, 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(rx - 3 - index * 3) + 0.5, float(self.wide // 2) + 1.5, 0, MINE1_FOES.pick(dice, self.danger), 0.0);
        }
        build.supply(float(rx) + 0.5, 2.5, self.deck, Q2_HEALTH, "q2");
        build.supply(float(px) + 0.5, 5.5, fz + 1, "ammo_bullets", "q2");
    }
}

"""A cavern of terraces, each higher, the top one a gallery over the
floor; a valve on each, and all three open the ways on."""
node ValveCavern(Prefab) {
    has door_a: int = 10,
        valve_a: int = 4,
        door_b: int = 6,
        valve_b: int = 12,
        door_c: int = 10,
        valve_c: int = 16,
        foot_a: int = 6,
        shortcut: bool = False,
        lake: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Valve cavern";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(24, 28);
        self.tall = dice.between(19, 21);
        self.shortcut = dice.chance(0.5);
        self.lake = dice.chance(0.5);
        # Each valve keeps clear of the way out on its terrace.
        self.door_a = dice.between(9, self.long - 13);
        self.valve_a = self.door_a + 5 if self.door_a + 5 <= self.long - 12 else self.door_a - 5;
        self.foot_a = dice.between(6, self.long - 14);
        self.door_b = dice.between(4, self.wide - 9);
        self.valve_b = self.door_b + 5 if self.door_b + 5 <= self.wide - 8 else self.door_b - 4;
        self.door_c = dice.between(9, self.long - 9);
        self.valve_c = self.door_c + 4 if self.door_c + 4 <= self.long - 8 else self.door_c - 4;
        self.low = -6;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(8, self.wide - 11)), floor=0);
        self.leaves = [
            Port(face=3, along=float(self.door_a), floor=4),
            Port(face=0, along=float(self.door_b), floor=8),
            Port(face=1, along=float(self.door_c), floor=12),
            Port(face=1, along=float(dice.between(8, self.long - 9)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [4, 8, 12] {
            build.level(cave, z);
        }
        east = self.long - 6;
        # The terraces: the low one along the south wall, the middle one
        # along the east wall, its north corner raised to the gallery's
        # height, and the gallery along the north wall over the floor.
        build.solid(1, 1, 0, east, 5, 4);
        build.solid(east, 1, 0, self.long - 1, self.wide - 1, 8);
        build.solid(east, self.wide - 6, 8, self.long - 1, self.wide - 1, 12);
        west = 2 if self.shortcut else 6;
        slab(build, west, self.wide - 5, east, self.wide - 1, 12, 2);
        stair(build, self.foot_a, 8, 0, 3, 4, 3);
        stair(build, self.long - 10, 1, 4, 0, 4, 3);
        stair(build, east, self.wide - 10, 8, 1, 4, 3);
        for x in range(self.foot_a, self.foot_a + 3) {
            build.keep(cave, x, 4, 4);
        }
        # An updraft from a vent in the floor, three cells back from the low
        # terrace's edge, throws a body up onto it.
        vx = self.foot_a + 6 if self.foot_a + 6 < east - 4 else self.foot_a - 4;
        build.jump_pad(float(vx) + 0.5, 8.5, 0, float(vx) + 0.5, 2.5, 4);
        for x in range(vx - 1, vx + 2) {
            build.keep(cave, x, 4, 4);
        }
        if self.shortcut {
            lift(build, 2, self.wide - 8, 5, self.wide - 5, 0, 12);
            for x in range(2, 5) {
                build.keep(cave, x, self.wide - 5, 12);
            }
        }
        if self.lake {
            build.pool(self.long // 2 - 5, 11, -5, self.long // 2 + 3, self.wide - 8, 0, 2);
        }
        stalactites(build, dice, 6, 6, east - 1, self.wide - 6, self.tall, dice.between(4, 7));
        build.doorway(cave, self.enter);
        # The valves: all three open the ways on, hovers coming in one after
        # another as they turn.
        opened = build.tally(3, "The valves are open. The way on is clear.");
        build.push(float(self.valve_a) + 0.5, 1.0, 5.0, 1) +>:Fires:+> opened;
        build.push(float(self.long - 1), float(self.valve_b) + 0.5, 9.0, 2) +>:Fires:+> opened;
        build.push(float(self.valve_c) + 0.5, float(self.wide - 1), 13.0, 3) +>:Fires:+> opened;
        build.touch(1.0, float(self.enter.along - 2.0), 0.0, 4.0, float(self.enter.along + 2.0), 6.0, True, "Open the three valves to clear the way on.");
        for port in self.taken {
            build.doorway(cave, port);
            port_door(build, self.long, self.wide, port, opened);
        }
        for index in range(3) {
            late = build.delay(1.5 * float(index));
            opened +>:Fires:+> late;
            wave = build.waiting();
            late +>:Fires:+> wave;
            build.foe(float(self.long // 2 - 3 + index * 3) + 0.5, float(self.wide // 2) + 0.5, 9, MINE1_FOES.pick(dice, self.danger, False, True), 270.0, waits=wave);
        }
        # Guards on the terraces; a gunner walks the low one.
        build.foe(3.5, 3.0, 4, "monster_gunner", 0.0, patrol=[[3.5, 3.0], [float(east) - 5.5, 3.0]]);
        build.foe(float(self.long) - 3.5, float(self.wide // 2) + 0.5, 8, MINE1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(east) - 3.5, float(self.wide) - 3.0, 12, MINE1_FOES.pick(dice, self.danger), 180.0);
        step_in = build.touch(1.0, 5.0, 0.0, 5.0, float(self.wide - 5), 6.0);
        floor_wake = build.waiting();
        step_in +>:Fires:+> floor_wake;
        for index in range(dice.between(2, 3)) {
            build.foe(float(east) - 3.5, float(9 + index * 4) + 0.5, 0, MINE1_FOES.pick(dice, self.danger), 180.0, waits=floor_wake);
        }
        build.supply(float(east) - 2.5, 2.5, 4, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 3.5, 8, "ammo_bullets", "q2");
        build.supply(float(east) - 6.5, float(self.wide) - 3.0, 12, Q2_ARMOR, "q2");
    }
}

"""A gorge, a bridge across it barred at its head; the switch that lifts
the barrier on a balcony over the gorge or down on its floor."""
node BarrierBridge(Prefab) {
    has near: int = 7,
        gorge: int = 13,
        far: int = 6,
        deep: int = 10,
        balcony: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Barrier bridge";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.near = 7;
        self.deep = dice.between(10, 13);
        self.gorge = dice.between(self.deep + 3, self.deep + 5);
        self.far = 6;
        self.long = 1 + self.near + self.gorge + self.far + 1;
        self.wide = dice.between(16, 18);
        self.balcony = dice.chance(0.5);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        x0 = 1 + self.near;
        x1 = x0 + self.gorge;
        self.enter = Port(face=2, along=float(dice.between(4, self.wide - 7)), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0)];
        if x1 - 3 >= x0 + self.deep + 3 and dice.chance(0.5) {
            self.leaves.append(Port(face=3, along=float(dice.between(x0 + self.deep + 3, x1 - 3)), floor=-self.deep));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        cy = self.wide // 2;
        x0 = 1 + self.near;
        x1 = x0 + self.gorge;
        gorge = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(gorge, 0);
        build.level(gorge, low);
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        slab(build, x0, cy - 2, x1, cy + 2, 0, 2);
        # The stair down the gorge's south wall to its floor.
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 3);
        for y in range(1, 4) {
            build.keep(gorge, x0 - 1, y, 0);
        }
        for y in range(cy - 2, cy + 2) {
            build.keep(gorge, x1, y, 0);
        }
        # The barrier across the bridge's head.
        barrier = build.opened(float(x0 - 1), float(cy - 3), 0.0, float(x0), float(cy + 3), 7.0);
        build.touch(float(x0 - 4), float(cy - 2), 0.0, float(x0 - 1), float(cy + 2), 6.0, True, "Bridge access denied.");
        if self.balcony {
            slab(build, x0, self.wide - 5, x0 + 5, self.wide - 1, 7, 1);
            stair(build, x0 - 7, self.wide - 4, 0, 0, 7, 3);
            control = build.push(float(x0) + 3.5, float(self.wide - 1), 8.0, 3);
        } else {
            control = build.push(float(x1), float(self.wide) - 3.5, float(low) + 1.0, 2);
        }
        control +>:Fires:+> barrier;
        # A control on the far ledge's wall lifts it too, for a body come
        # round to the far side.
        build.push(float(self.long - 1), float(cy) + 3.5, 1.0, 2) +>:Fires:+> barrier;
        sparking(build, float(x0) - 1.5, float(cy) - 2.2, 4.0, 3, 3.0);
        sparking(build, float(x0) - 1.5, float(cy) + 2.2, 5.0, 1, 4.0);
        build.doorway(gorge, self.enter);
        for port in self.taken {
            build.doorway(gorge, port);
        }
        # Guards appear on the far side as the barrier lifts.
        far_side = build.waiting();
        control +>:Fires:+> far_side;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1 + 2) + 0.5, float(cy - 4 + index * 4) + 0.5, 0, MINE1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=far_side);
        }
        foot = build.touch(float(x0 + self.deep), 1.0, float(low), float(x0 + self.deep + 3), 4.0, float(low + 6));
        down_here = build.waiting();
        foot +>:Fires:+> down_here;
        build.foe(float(x1) - 2.5, float(cy) - 3.5, low, MINE1_FOES.pick(dice, self.danger), 180.0, waits=down_here);
        floor_y = float(cy) + 0.5;
        build.foe(float(x0 + self.deep) + 1.5, floor_y, low, "monster_soldier", 0.0, patrol=[[float(x0 + self.deep) + 1.5, floor_y], [float(x1) - 1.5, floor_y], [float(x1) - 1.5, float(self.wide) - 2.5]]);
        build.foe(float(x0 + x1) * 0.5, float(cy) + 4.5, 5, MINE1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.foe(float(x1) + 4.5, float(self.wide) - 3.0, 0, MINE1_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x1) - 2.5, 2.5, low, "ammo_bullets", "q2");
    }
}

"""The key on a control deck over the fan room, up a lift or a stair."""
node VentControl(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deck: int = 6,
        by_lift: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vent control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deck = dice.between(6, 7);
        self.by_lift = dice.chance(0.5);
        self.tall = self.deck + 8;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.deck);
        build.doorway(room, self.enter);
        dx = self.long - 8;
        # The deck over the fan bay, posts along its front.
        slab(build, dx, 1, self.long - 1, side, self.deck, 1);
        for y in range(2, side - 1, 4) {
            if y < cy - 2 or y > cy + 2 {
                build.solid(dx, y, 0, dx + 1, y + 1, self.deck - 1);
            }
        }
        # Fan housings on the floor, sparking.
        for at in [[4, 3], [4, side - 5]] {
            build.solid(at[0], at[1], 0, at[0] + 3, at[1] + 3, 4);
        }
        sparking(build, 7.2, 4.5, 2.0, 0, 3.0);
        if self.by_lift {
            lift(build, dx - 3, cy - 1, dx, cy + 2, 0, self.deck);
        } else {
            stair(build, dx - self.deck, cy - 1, 0, 0, self.deck, 3);
        }
        for y in range(cy - 1, cy + 2) {
            build.keep(room, dx, y, self.deck);
        }
        # The fans' controls along the deck's back wall.
        build.solid(self.long - 2, 3, self.deck, self.long - 1, side - 2, self.deck + 2);
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.deck, side, 0, [2, dx - 4], [MINE1_FOES.pick(dice, self.danger, True), MINE1_FOES.pick(dice, self.danger)]);
        fans = build.waiting();
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 3), 6.0) +>:Fires:+> fans;
        build.foe(float(dx) - 1.5, float(side) - 3.5, 0, MINE1_FOES.pick(dice, self.danger), 180.0, waits=fans);
        deck_guard = build.waiting();
        build.touch(float(dx), float(cy - 2), float(self.deck), float(dx + 2), float(cy + 3), float(self.deck + 6)) +>:Fires:+> deck_guard;
        build.foe(float(self.long) - 3.5, 3.5, self.deck, MINE1_FOES.pick(dice, self.danger, True), 180.0, waits=deck_guard);
        build.foe(8.5, 2.5, 0, "monster_soldier", 90.0, patrol=[[8.5, 2.5], [8.5, float(side) - 2.5]]);
        build.supply(2.5, float(cy) + 3.5, 0, Q2_HEALTH, "q2");
        build.timer(5.0) +>:Fires:+> build.sparks(float(self.long) - 2.2, float(cy) - 3.5, float(self.deck) + 1.5, 2);
    }
}

"""The end: a door, a hall, the way out behind a door sealed for the toxic
air that the ventilation switch on a gantry opens."""
node ToxicExit(Prefab) {
    has key: str = "",
        gantry: int = 6,
        by_lift: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Toxic exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE1;
        self.district = level_district(MINE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.gantry = dice.between(6, 7);
        self.by_lift = dice.chance(0.4);
        self.tall = self.gantry + dice.between(7, 9);
        self.low = -4;
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
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, self.gantry);
        # The exit's chamber beyond a wall, its door sealed.
        ex = self.long - 8;
        build.solid(ex, 1, 0, ex + 1, self.wide - 1, self.tall);
        build.widen(room, ex, cy - 2, 0, ex + 1, cy + 2, 8);
        seal = build.opened(float(ex), float(cy - 2), 0.0, float(ex + 1), float(cy + 2), 8.0);
        build.touch(float(ex - 3), float(cy - 2), 0.0, float(ex), float(cy + 2), 6.0, True, "Access denied. Toxic conditions.");
        build.way_out(float(self.long) - 4.0, float(cy), 0);
        # The gantry along the south wall, the ventilation switch at its end.
        slab(build, wall + 1, 1, ex, 4, self.gantry, 1);
        if self.by_lift {
            lift(build, ex - 5, 4, ex - 2, 7, 0, self.gantry);
            for x in range(ex - 5, ex - 2) {
                build.keep(room, x, 3, self.gantry);
            }
        } else {
            stair(build, ex - 1 - self.gantry, 4, 0, 0, self.gantry, 3);
            for x in range(ex - 4, ex - 1) {
                build.keep(room, x, 3, self.gantry);
            }
        }
        vent = build.push(float(wall + 3), 1.0, float(self.gantry) + 1.0, 1);
        vent +>:Fires:+> seal;
        chamber = build.waiting();
        vent +>:Fires:+> chamber;
        build.foe(float(self.long) - 2.5, float(cy) - 3.5, 0, MINE1_FOES.pick(dice, self.danger, True), 180.0, waits=chamber);
        vent +>:Fires:+> build.objective("Ventilation systems active. Leave the mines.");
        vent +>:Fires:+> build.sparks(float(ex) - 0.2, float(cy) - 2.5, 6.0, 2);
        # A slime sump by the north wall.
        burning(build, ex - 6, self.wide - 5, -3, ex - 2, self.wide - 1, 0, 3, 8);
        # Guards on the floor wake as the player comes in; one on the gantry.
        come_in = build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0);
        floor_guard = build.waiting();
        come_in +>:Fires:+> floor_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(ex - 4 - index * 4) + 0.5, float(cy + 2) + 0.5, 0, MINE1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=floor_guard);
        }
        build.foe(float(ex) - 3.5, 2.5, self.gantry, MINE1_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(cy) + 3.5, 0, MINE1_FOES.pick(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, MINE1_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine1's stretches: [name, role]."""
glob MINE1_STRETCHES: list[list[str]] = [
         ["foot", "start"],
         ["lift", "flow"],
         ["blast", "flow"],
         ["bridge", "flow"],
         ["valves", "hub"],
         ["lift", "hub"],
         ["vents", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine1's stretches by its name."""
def make_mine1(name: str, key: str) -> Prefab {
    if name == "foot" {
        return ShaftFoot();
    }
    if name == "lift" {
        return GreatLift();
    }
    if name == "blast" {
        return BlastGallery();
    }
    if name == "bridge" {
        return BarrierBridge();
    }
    if name == "valves" {
        return ValveCavern();
    }
    if name == "vents" {
        return VentControl(key=key if key else "key_silver");
    }
    return ToxicExit(key=key);
}
