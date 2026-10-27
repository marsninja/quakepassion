"""Prefabs drawn from Quake II's lab, the Research Lab: an airlock cycled
for decontamination under an observation deck, a corridor of specimen
tanks that burst one after another, the forcefield hall whose two
switches bring its fields down, a maintenance bridge over a chasm, a
stack of lab floors one over another, the operating theatre where the key
lies, and the way back to the hangar. Raised in lab's own palette.

- `Decontamination`: the start. A hall under an observation deck (its
  door on worked from a panel on it), holding tanks along the wall; the
  airlock's first door opens to a touch, the panel inside runs the cycle
  (steam and sparks) and the second door opens on its own, the tanks behind bursting as it runs. Beyond, a loading floor
  (sunk down a stair, or not), a tank there bursting as the door opens.
- `SpecimenRow`: a corridor of tanks along one wall, a gallery along the
  other up a stair at either end; the tanks shatter one after another
  (lab's chain of breaking glass), a laser burns across the gallery for a
  while as the player comes up, a pod rides a rail overhead; a ledge over
  the tanks bridged from the gallery, or not. A locker under the gallery
  opens to its button, or once every specimen is dead (lab's kill
  counter).
- `ForcefieldHall`: a hall cut by a forcefield wall; one switch on a deck
  up a lift (or a stair), the other down in a pit (or shot high on the
  wall); both thrown, the counter brings the field down ("Forcefields
  deactivated"), its emitters burst and the way on into the bay beyond
  opens; there a button grants access to the store, its parasites let
  out. A hub.
- `MaintenanceBridge`: a chasm, water or slime at its foot and a stair up
  out of it; the button in the booth on a deck (or shot on the far wall)
  extends the bridge ("Maintenance bridge activated"); a laser sweeps the
  bridge as the player crosses.
- `LabStack`: three lab floors one over another, a stair up the near wall
  to the second and one back along the far wall to the third (a floor,
  or galleries round an atrium a pod shuttles across), a lift up through
  the second floor's well and steps a button raises to its edge; foes
  appear (and one is beamed in) as each floor is reached.
- `OperatingTheatre`: the key on the table in a sunken theatre under an
  observation gallery; taking it opens the closets, bursts the tanks and
  brings the medics onto the gallery; a button on the gallery raises
  steps out of the theatre's far end.
- `LabExit`: the end. A door (a key's, as a gate) and the security door
  beyond it a button grants access through, then the way out on a dais
  up steps a button raises, or down
  a well whose floor a button sinks; "Return to the hangar"."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, squad, rounds, beamed, shatter_row, laser_burst, key_taken, closets, held_door }

glob LAB: str = "q2:lab";

"""lab's foes: parasites and iron maidens, medics and brains deeper in."""
def lab_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_chick", "monster_brain"] if heavy else ["monster_parasite", "monster_parasite", "monster_chick"], ["monster_medic"] if heavy else ["monster_brain"], danger * 0.4 if heavy else danger * 0.5));
}

"""Tanks along a room's wall line y = `side`: alcoves three cells wide and
`deep` deep beyond it on lift `floor`, `high` lifts tall, one at each of
`xs`, glass across each in the wall's cells. Answers [panes, insides] for
`shatter_row`."""
def tanks_along(build: Raising, side: int, xs: list[int], floor: int, deep: int, high: int) -> list[list[list[float]]] {
    panes: list[list[float]] = [];
    inside: list[list[float]] = [];
    for at in xs {
        tank = build.room(at, side + 1, floor, at + 3, side + 1 + deep, floor + high);
        build.widen(tank, at, side, floor, at + 3, side + 1, floor + high - 1);
        panes.append([float(at), float(side), float(floor), float(at + 3), float(side + 1), float(floor + high - 1)]);
        inside.append([float(at) + 1.5, float(side) + 1.0 + float(deep) * 0.5, float(floor)]);
    }
    return [panes, inside];
}

"""The start: a hall under an observation deck, holding tanks along its
wall, the airlock cycled through, a loading floor beyond."""
node Decontamination(Prefab) {
    has lock_x: int = 16,
        deck_z: int = 7,
        side: int = 14,
        sunken: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Decontamination";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(34, 36);
        self.side = dice.between(14, 16);
        self.wide = self.side + 5;
        self.deck_z = 7;
        self.tall = self.deck_z + 8;
        self.lock_x = dice.between(16, 17);
        self.sunken = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.side // 2 + 1);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-3 if self.sunken else 0),
            Port(face=3, along=float(self.lock_x + 8), floor=0),
            Port(face=1, along=5.5, floor=self.deck_z)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.side;
        middle = side // 2 + 1;
        lx = self.lock_x;
        hall = build.room(1, 1, 0, lx, side, self.tall, variant=dice.below(3));
        chamber = build.room(lx + 1, 1, 0, lx + 5, side, self.tall, variant=dice.below(3));
        beyond = build.room(lx + 6, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.deck_z);
        # The observation deck over the way in, its stair down along the
        # wall; its way on through the wall behind.
        deck(build, 3, 1, 8, side, self.deck_z);
        stair(build, 8 + self.deck_z - 1, 1, 0, 2, self.deck_z, 3);
        keep_box(build, hall, 7, 1, 8, 4, self.deck_z);
        build.widen(hall, 4, side, self.deck_z, 8, self.wide - 2, self.deck_z + 8);
        # The airlock: the near door opens to a touch, the cycle runs, the
        # far door opens on its own.
        build.widen(chamber, lx, middle - 2, 0, lx + 1, middle + 2, 8);
        build.rising_door(float(lx), float(middle - 2), 0.0, float(lx + 1), float(middle + 2), 8.0, {"wait": "-1"});
        build.widen(beyond, lx + 5, middle - 2, 0, lx + 6, middle + 2, 8);
        far_door = build.opened(float(lx + 5), float(middle - 2), 0.0, float(lx + 6), float(middle + 2), 8.0);
        cycle = build.push(float(lx + 3), float(side), 2.5, 3);
        build.touch(float(lx + 1), 1.0, 0.0, float(lx + 3), float(side), 6.0, True, "Press the panel to run the decontamination cycle");
        cycle +>:Fires:+> build.objective("Decontamination cycle engaged", False);
        sparking(build, float(lx) + 1.5, 1.2, 9.0, 1, 2.0);
        cycle +>:Fires:+> build.sparks(float(lx) + 3.0, 2.0, 8.0, 1);
        cycle +>:Fires:+> build.sparks(float(lx) + 3.0, float(side) - 1.0, 8.0, 3);
        done = build.delay(2.5);
        cycle +>:Fires:+> done;
        done +>:Fires:+> far_door;
        # The holding tanks along the hall's wall burst as the cycle runs.
        held = tanks_along(build, side, [9, 13], 0, 3, 6);
        shatter_row(build, cycle, held[0], held[1], ["monster_parasite", lab_foe(dice, self.danger)], 270.0, 0.6);
        # Beyond: a loading floor, sunk down a stair or not, a tank there
        # bursting as the far door opens.
        px = lx + 11;
        if self.sunken {
            low_floor = build.room(px, 1, -3, self.long - 1, side, 0);
            build.level(beyond, -3);
            stair(build, px + 2, middle - 1, -3, 2, 3, 3);
            keep_box(build, beyond, px - 1, middle - 1, px, middle + 2, 0);
            for port in self.taken {
                if port.floor < 0 {
                    build.doorway(low_floor, port);
                }
            }
        }
        out_tank = tanks_along(build, side, [lx + 7], 0, 3, 6);
        shatter_row(build, done, out_tank[0], out_tank[1], [lab_foe(dice, self.danger, True)], 270.0, 0.4);
        beamed(build, done, 2, 2, -8, lab_foe(dice, self.danger), float(self.long) - 4.5, float(middle) + 0.5, -3 if self.sunken else 0, 180.0);
        build.doorway(hall, self.enter);
        deck_press = build.push(5.5, 1.0, float(self.deck_z) + 1.5, 1);
        for port in self.taken {
            if port.floor == self.deck_z {
                build.doorway(hall, port);
                held_door(build, self, port, deck_press, "The deck's door is worked from its panel");
            } elif port.floor == 0 {
                build.doorway(beyond, port);
            }
        }
        build.start(1.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 3.0, float(side), 6.0) +>:Fires:+> build.objective("Locate the repair facility. Steal the commander's head");
        rounds(build, lab_foe(dice, self.danger), [[5.5, 6.0], [5.5, float(side) - 2.0]], self.deck_z);
        build.foe(12.5, float(middle) + 2.5, 0, lab_foe(dice, self.danger), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 5.0, 0, lab_foe(dice, self.danger), 180.0);
        }
        sparking(build, float(self.long) - 1.2, float(side) - 2.5, 3.0, 2, 4.5);
        sparking(build, float(lx) - 0.2, 2.5, 4.0, 2, 6.0);
        build.supply(float(lx) + 8.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(4.5, float(side) - 2.0, self.deck_z, "ammo_bullets", "q2");
    }
}

"""A corridor of tanks along one wall, a gallery along the other up a
stair; the tanks shatter one after another."""
node SpecimenRow(Prefab) {
    has gal: int = 7,
        side: int = 14,
        far_stair: bool = False,
        ledge: bool = False,
        walk_x: int = 14,
        from_far: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Specimen row";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(28, 31);
        self.side = dice.between(14, 16);
        self.wide = self.side + 5;
        self.gal = dice.between(6, 7);
        self.tall = self.gal + 9;
        self.far_stair = dice.chance(0.5);
        self.ledge = dice.chance(0.5);
        self.walk_x = dice.between(12, self.long - 12);
        self.from_far = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        g0 = 3 if self.far_stair else 4 + self.gal;
        g1 = self.long - 1 - self.gal if self.far_stair else self.long - 1;
        self.enter = Port(face=2, along=float(self.side // 2 + 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.side // 2 + 2), floor=0), Port(face=3, along=float((g0 + g1) // 2), floor=self.gal)];
        if self.ledge {
            self.leaves.append(Port(face=1, along=float(self.walk_x + 2), floor=self.gal));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.side;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.gal);
        # The gallery along the near wall, its stair at one end or the other.
        g0 = 3 if self.far_stair else 4 + self.gal;
        g1 = self.long - 1 - self.gal if self.far_stair else self.long - 1;
        deck(build, g0, 1, g1, 5, self.gal);
        if self.far_stair {
            stair(build, self.long - 2, 1, 0, 2, self.gal, 3);
            keep_box(build, hall, g1 - 1, 1, g1, 4, self.gal);
        } else {
            stair(build, 4, 1, 0, 0, self.gal, 3);
            keep_box(build, hall, g0, 1, g0 + 1, 4, self.gal);
        }
        # A ledge over the tanks' fronts, a catwalk to it from the gallery,
        # and the way on through the wall behind it.
        wx = self.walk_x;
        if self.ledge {
            deck(build, 5, side - 3, self.long - 5, side, self.gal);
            deck(build, wx, 5, wx + 4, side - 3, self.gal);
            keep_box(build, hall, wx, 4, wx + 4, 5, self.gal);
            keep_box(build, hall, wx, side - 3, wx + 4, side - 2, self.gal);
            build.widen(hall, wx, side, self.gal, wx + 4, self.wide - 2, self.gal + 8);
        }
        # The tanks along the far wall, clear of the way through it.
        xs: list[int] = [];
        for at in range(6, self.long - 4, 4) {
            if not self.ledge or at + 3 < wx - 1 or at > wx + 5 {
                xs.append(at);
            }
        }
        if self.from_far {
            xs.reverse();
        }
        held = tanks_along(build, side, xs, 0, 3, 6);
        start_x = float(self.long - 6) if self.from_far else 2.0;
        burst = build.touch(start_x, 6.0, 0.0, start_x + 3.0, float(side), 8.0);
        destroyed = build.tally(len(xs), "Specimens destroyed");
        shatter_row(build, burst, held[0], held[1], ["monster_parasite", "monster_parasite", lab_foe(dice, self.danger, True)], 270.0, 0.6, destroyed);
        for jar_y in [side - 7, side - 10] {
            burst +>:Fires:+> build.breakable(float(self.long // 2 - 3), float(jar_y), 0.0, float(self.long // 2 - 2), float(jar_y + 1), 2.0, 10);
        }
        beamed(build, burst, 2, 2, -8, lab_foe(dice, self.danger), float(self.long // 2) + 0.5, 7.5, 0, 90.0);
        # A locker under the gallery, its shutter opened by the button
        # beside it.
        lx0 = 4 if self.far_stair else self.long - 5;
        build.solid(lx0, 1, 0, lx0 + 4, 5, self.gal - 1);
        locker = build.room(lx0 + 1, 1, 0, lx0 + 3, 4, 5);
        build.widen(locker, lx0 + 1, 4, 0, lx0 + 3, 5, 5);
        shutter = build.opened(float(lx0 + 1), 4.0, 0.0, float(lx0 + 3), 5.0, 5.0);
        build.push(float(lx0) + 3.5, 5.0, 1.5, 1) +>:Fires:+> shutter;
        destroyed +>:Fires:+> shutter;
        sparking(build, float(self.long) - 1.2, float(side) - 3.5, 4.0, 2, 6.0);
        build.supply(float(lx0) + 2.0, 2.0, 0, Q2_ARMOR, "q2");
        sparking(build, float(lx0) + 0.5, 5.2, 3.0, 1, 5.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # A laser burns across the gallery for a while as the player comes up.
        top_x = g1 - 2 if self.far_stair else g0;
        up = build.touch(float(top_x), 1.0, float(self.gal), float(top_x + 2), 5.0, float(self.gal + 6));
        laser_burst(build, up, float((g0 + g1) // 2) + 0.5, 1.1, float(self.gal) + 1.5, 1, 4.0);
        squad(build, up, [[float((g0 + g1) // 2) + 4.5, 3.0, float(self.gal)]], [lab_foe(dice, self.danger, True)], 180.0);
        # A pod riding a rail overhead.
        rail = float(self.gal + 4);
        build.train([2.0, 2.0, 2.0], [[6.0, float(side) - 7.0, rail], [float(self.long) - 8.0, float(side) - 7.0, rail]], 50.0, 3.0);
        rounds(build, lab_foe(dice, self.danger), [[float(g0) + 1.5, 3.0], [float(g1) - 1.5, 3.0]], self.gal);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 5) + 0.5, float(side) - 5.5, 0, lab_foe(dice, self.danger), 180.0);
        }
        sparking(build, float(self.long) - 1.2, 8.5, 3.0, 2, 3.5);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(g1) - 2.5, 3.0, self.gal, "ammo_cells", "q2");
    }
}

"""A hall cut by a forcefield wall; a switch up on a deck, another down in
a pit (or shot high on the wall); both thrown, the field comes down."""
node ForcefieldHall(Prefab) {
    has divide: int = 18,
        deck_z: int = 8,
        pit: bool = True,
        by_lift: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Forcefield hall";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.deck_z = 8;
        self.tall = 18;
        self.divide = self.long - 10;
        self.pit = dice.chance(0.6);
        self.by_lift = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        d0 = 4 if self.by_lift else 12;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.divide + 5), floor=0),
            Port(face=3, along=float(self.divide + 5), floor=0),
            Port(face=3, along=float((d0 + self.divide) // 2), floor=self.deck_z)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        dv = self.divide;
        near = build.room(1, 1, 0, dv, self.wide - 1, self.tall, variant=dice.below(3));
        bay = build.room(dv + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(near, self.deck_z);
        # The deck along the near wall, up a lift or a stair; its switch on
        # the forcefield wall.
        d0 = 4 if self.by_lift else 12;
        deck(build, d0, 1, dv, 6, self.deck_z);
        if self.by_lift {
            lift(build, 4, 6, 7, 9, 0, self.deck_z);
            keep_box(build, near, 4, 5, 7, 6, self.deck_z);
        } else {
            stair(build, 4, 1, 0, 0, self.deck_z, 3);
            keep_box(build, near, 12, 1, 13, 4, self.deck_z);
        }
        count = build.tally(2, "Forcefields deactivated");
        build.push(float(dv), 3.5, float(self.deck_z) + 1.5, 2) +>:Fires:+> count;
        # The other switch: down in a pit, or shot high on the wall.
        if self.pit {
            build.room(8, self.wide - 9, -4, 14, self.wide - 3, 0);
            stair(build, 11, self.wide - 9, -4, 2, 4, 2);
            build.push(14.0, float(self.wide) - 5.0, -2.5, 2) +>:Fires:+> count;
        } else {
            build.push(float(dv), float(self.wide) - 3.5, 10.0, 2, True) +>:Fires:+> count;
        }
        # The forcefield wall: its door down when both are thrown, windows
        # into the bay over it.
        build.widen(bay, dv, middle - 2, 0, dv + 1, middle + 2, 8);
        count +>:Fires:+> build.opened(float(dv), float(middle - 2), 0.0, float(dv + 1), float(middle + 2), 8.0);
        for at in [middle + 4, middle - 5] {
            build.widen(bay, dv, at, 5, dv + 1, at + 3, 9);
            build.breakable(float(dv), float(at), 5.0, float(dv + 1), float(at + 3), 9.0, 15);
        }
        count +>:Fires:+> build.objective("Forcefields down. Find the commander's head");
        for at_y in [middle - 3, middle + 2] {
            count +>:Fires:+> build.breakable(float(dv - 1), float(at_y), 0.0, float(dv), float(at_y + 1), 3.0, 20);
        }
        build.touch(float(dv - 3), float(middle - 2), 0.0, float(dv - 1), float(middle + 2), 6.0, False, "The forcefield is held by two switches");
        sparking(build, float(self.long) - 1.2, float(middle) - 4.0, 3.0, 2, 5.5);
        blast_chain(build, count, [[float(dv) - 1.0, float(middle) - 3.0, 4.0], [float(dv) - 1.0, float(middle) + 3.0, 4.0], [float(dv) + 2.0, float(middle), 7.0]], 0.3);
        squad(build, count, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 3.5, float(self.wide) - 3.5, 0.0], [float(dv) + 4.5, float(middle) + 4.5, 0.0]], ["monster_parasite", lab_foe(dice, self.danger), "monster_parasite"], 180.0);
        beamed(build, count, 2, 2, -8, lab_foe(dice, self.danger, True), 4.5, float(middle) + 0.5, 0, 0.0);
        # The bay's store: its shutter opened by the button by it ("Access
        # granted"), the parasites kept there let out.
        sy0 = middle + 3;
        build.solid(self.long - 5, sy0, 0, self.long - 1, sy0 + 4, 8);
        store = build.room(self.long - 4, sy0 + 1, 0, self.long - 1, sy0 + 3, 6);
        build.widen(store, self.long - 5, sy0 + 1, 0, self.long - 4, sy0 + 3, 6);
        access = build.push(float(self.long - 5), float(sy0) + 3.5, 1.5, 2);
        access +>:Fires:+> build.opened(float(self.long - 5), float(sy0 + 1), 0.0, float(self.long - 4), float(sy0 + 3), 6.0);
        access +>:Fires:+> build.objective("Access granted to the research store", False);
        squad(build, access, [[float(self.long) - 2.5, float(sy0) + 2.0, 0.0]], ["monster_parasite"], 180.0);
        build.train([2.0, 2.0, 1.0], [[6.0, float(middle + 4), 12.0], [float(dv - 4), float(middle + 4), 12.0]], 40.0, 2.0);
        build.doorway(near, self.enter);
        for port in self.taken {
            if port.floor == self.deck_z {
                build.doorway(near, port);
            } else {
                build.doorway(bay, port);
            }
        }
        # A guard comes onto the deck as the player reaches it; foes in the
        # hall, one walking it.
        up = build.touch(float(d0), 1.0, float(self.deck_z), float(d0 + 3), 6.0, float(self.deck_z + 6));
        squad(build, up, [[float(dv) - 3.5, 3.5, float(self.deck_z)]], [lab_foe(dice, self.danger, True)], 180.0);
        rounds(build, lab_foe(dice, self.danger), [[5.5, float(middle) + 1.5], [float(dv) - 2.5, float(middle) + 1.5]], 0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(dv) - 3.5, float(middle) + 5.5 - float(index) * 8.0, 0, lab_foe(dice, self.danger), 180.0);
        }
        sparking(build, float(dv) - 0.2, float(middle) + 3.0, 6.0, 2, 3.0);
        sparking(build, float(dv) + 1.2, float(middle) - 3.0, 6.0, 0, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(dv) - 2.5, 3.0, self.deck_z, "ammo_cells", "q2");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, Q2_ARMOR, "q2");
    }
}

"""A chasm, water or slime at its foot, a stair up out of it; the button
extends the bridge across."""
node MaintenanceBridge(Prefab) {
    has near: int = 7,
        span: int = 7,
        depth: int = 9,
        booth: bool = True,
        slime: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Maintenance bridge";
        self.source = LAB;
        self.district = level_district(LAB);
        self.near = dice.between(7, 8);
        self.span = dice.between(6, 8);
        self.long = 1 + self.near + self.span + dice.between(9, 10) + 1;
        self.wide = dice.between(16, 18);
        self.depth = dice.between(8, 10);
        self.booth = dice.chance(0.6);
        self.slime = dice.chance(0.35);
        self.tall = 16;
        self.low = -2 * self.depth - 3;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 4), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=0),
            Port(face=1, along=float(self.long - 5), floor=0),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cut = 1 + self.near;
        far = cut + self.span;
        lane = self.wide - 5;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.room(cut, 1, -self.depth + 3, far, self.wide - 1, 0);
        build.pool(cut, 1, -self.depth, far, self.wide - 1, -self.depth + 3, 3 if self.slime else 2, steps=False);
        # The stair up out of the chasm along its near wall.
        stair(build, cut, 1, -self.depth, 1, self.depth, 2);
        keep_box(build, room, cut - 1, self.depth - 1, cut, self.depth + 1, 0);
        # The bridge, drawn out across the chasm when the button is pressed.
        bridge = build.drawn(float(cut), float(lane), float(far), float(lane + 3), 0, self.depth + 1);
        keep_box(build, room, cut - 1, lane, cut, lane + 3, 0);
        keep_box(build, room, far, lane, far + 1, lane + 3, 0);
        if self.booth {
            # The booth on a deck over the near ledge, its stair down.
            build.level(room, 6);
            deck(build, 1, 1, cut - 1, 5, 6);
            stair(build, 3, 10, 0, 3, 6, 3);
            keep_box(build, room, 3, 4, 6, 5, 6);
            press = build.push(1.0, 3.0, 7.5, 0);
        } else {
            press = build.push(float(self.long - 1), 3.5, 6.0, 2, True);
            build.touch(float(cut - 3), float(lane), 0.0, float(cut - 1), float(lane + 3), 6.0, True, "Shoot the switch on the far wall");
        }
        press +>:Fires:+> bridge;
        beamed(build, press, 2, 2, -8, lab_foe(dice, self.danger, True), float(far) + 4.5, float(self.wide // 2) - 1.0, 0, 180.0);
        stash(build, 2, 1, 0, 0, "ammo_cells", 5) +>:Fires:+> build.sparks(5.2, 3.0, 2.0, 0);
        late = build.delay(1.2);
        press +>:Fires:+> late;
        late +>:Fires:+> build.breakable(float(self.long - 4), 6.0, 0.0, float(self.long - 3), 7.0, 2.0, 15);
        sparking(build, float(far) + 0.2, 2.5, -2.0, 0, 4.5);
        press +>:Fires:+> build.objective("Maintenance bridge activated", False);
        # Foes come onto the far ledge as the bridge goes out; a laser sweeps
        # the bridge as the player crosses.
        squad(build, press, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 3.5, float(self.wide) - 6.5, 0.0]], [lab_foe(dice, self.danger), lab_foe(dice, self.danger, True)], 180.0);
        crossing = build.touch(float(cut + 2), float(lane), 0.0, float(far - 2), float(lane + 3), 6.0);
        laser_burst(build, crossing, float(cut) + float(self.span) * 0.5, float(self.wide) - 1.1, 1.5, 3, 3.0);
        crossing +>:Fires:+> build.sparks(float(far) + 0.5, float(lane) - 0.5, 2.0, 2);
        build.train([2.0, 2.0, 1.0], [[float(far) - 2.0, 2.0, -5.0], [float(far) - 2.0, float(lane) - 3.0, -5.0]], 40.0, 2.0);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(far) + 3.5, 3.5 + float(index) * 4.0, 0, lab_foe(dice, self.danger), 180.0);
        }
        rounds(build, lab_foe(dice, self.danger), [[float(far) + 2.5, float(self.wide) - 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [float(self.long) - 3.0, 3.0]], 0);
        build.foe(float(cut) + 1.0, 3.5, -self.depth, "monster_parasite", 90.0);
        sparking(build, float(cut) - 0.2, float(lane) - 2.0, -3.0, 0, 3.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide // 2), 0, "ammo_grenades", "q2");
    }
}

"""Three lab floors one over another, stairs between them, a lift up
through the second floor's well."""
node LabStack(Prefab) {
    has mid: int = 9,
        top: int = 18,
        atrium: bool = False,
        tall: int = 27;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lab stack";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(22, 24);
        self.wide = dice.between(18, 20);
        self.mid = 9;
        self.top = 18;
        self.tall = 27;
        self.atrium = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 3), floor=0),
            Port(face=1, along=5.0, floor=0),
            Port(face=0, along=float(middle + 3), floor=self.mid),
            Port(face=3, along=5.0, floor=self.top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        m = self.mid;
        t = self.top;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, m);
        build.level(room, t);
        # The second floor over the far part, its well for the lift.
        deck(build, 10, 1, self.long - 5, self.wide - 1, m);
        deck(build, self.long - 5, 4, self.long - 1, self.wide - 1, m);
        deck(build, self.long - 2, 1, self.long - 1, 4, m);
        lift(build, self.long - 5, 1, self.long - 2, 4, 0, m);
        keep_box(build, room, self.long - 6, 1, self.long - 5, 4, m);
        keep_box(build, room, self.long - 5, 4, self.long - 2, 5, m);
        stair(build, 1, 1, 0, 0, m, 3);
        keep_box(build, room, 10, 1, 11, 4, m);
        # The third floor over the near part, up a stair back along the far
        # wall: a floor, or galleries round an atrium a pod shuttles across.
        stair(build, self.long - 2, self.wide - 4, m, 2, t - m, 3);
        t1 = self.long - 10;
        if self.atrium {
            deck(build, 1, 1, t1, 5, t);
            deck(build, 1, self.wide - 5, t1, self.wide - 1, t);
            deck(build, 3, 5, 6, self.wide - 5, t);
            build.train([3.0, 3.0, 1.0], [[9.0, 6.0, float(t - 1)], [9.0, float(self.wide - 9), float(t - 1)]], 50.0, 2.0);
        } else {
            deck(build, 1, 1, t1, self.wide - 1, t);
        }
        keep_box(build, room, t1 - 1, self.wide - 4, t1, self.wide - 1, t);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # Foes appear as each floor is reached.
        second = build.touch(10.0, 1.0, float(m), 12.0, 4.0, float(m + 6));
        squad(build, second, [[float(self.long) - 4.5, float(middle) + 2.5, float(m)], [14.5, float(self.wide) - 3.5, float(m)]], [lab_foe(dice, self.danger), "monster_parasite"], 180.0);
        third = build.touch(float(t1 - 2), float(self.wide - 4), float(t), float(t1), float(self.wide - 1), float(t + 6));
        squad(build, third, [[3.5, 3.0, float(t)], [3.5, float(self.wide) - 3.0, float(t)]], [lab_foe(dice, self.danger, True), "monster_chick"], 0.0);
        laser_burst(build, second, 13.5, float(self.wide) - 1.1, float(m) + 1.5, 3, 3.5);
        beamed(build, third, 2, 2, -8, lab_foe(dice, self.danger), float(self.long) - 8.5, float(middle) + 3.5, m, 180.0);
        # Steps a button raises from the floor to the second floor's edge.
        steps = build.rising_steps(2, middle + 2, 0, 0, m - 1, 3);
        keep_box(build, room, 10, middle + 2, 11, middle + 5, m);
        build.push(1.0, float(middle) + 6.5, 1.5, 0) +>:Fires:+> steps;
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "Research levels two and three above");
        broken = stash(build, self.long - 6, self.wide - 6, 0, 2, Q2_ARMOR, m - 1);
        broken +>:Fires:+> build.sparks(float(self.long) - 6.2, float(self.wide) - 4.0, 3.0, 2);
        rounds(build, lab_foe(dice, self.danger), [[12.5, float(middle) - 1.5], [float(self.long) - 7.5, float(middle) - 1.5]], m);
        for index in range(dice.between(1, 2)) {
            build.foe(6.5 + float(index) * 5.0, float(middle) + 3.5, 0, lab_foe(dice, self.danger), 0.0);
        }
        sparking(build, 1.2, float(middle) + 3.0, float(t) + 2.0, 0, 4.0);
        sparking(build, float(self.long) - 1.2, float(middle), 3.0, 2, 5.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, float(self.wide) - 6.5, m, "ammo_shells", "q2");
        build.supply(5.5, 3.0, t, Q2_HEALTH, "q2");
    }
}

"""The key on the table of a sunken theatre under an observation gallery;
taking it opens the closets, bursts the tanks, brings the medics in."""
node OperatingTheatre(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        gal: int = 6,
        by_lift: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Operating theatre (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(23, 25);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.gal = 6;
        self.by_lift = dice.chance(0.5);
        self.tall = 14;
        self.low = -9;
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
        build.level(room, self.gal);
        build.doorway(room, self.enter);
        # The theatre sunk three lifts, its stair down, the table in it.
        theatre = build.room(7, 3, -3, self.long - 4, side - 3, 0);
        build.level(theatre, -3);
        stair(build, 9, cy - 1, -3, 2, 3, 3);
        keep_box(build, room, 6, cy - 1, 7, cy + 2, 0);
        tx = (7 + self.long - 4) // 2 + 1;
        build.solid(tx - 2, cy - 1, -3, tx + 2, cy + 1, -2);
        taken = key_taken(build, self.key, float(tx), float(cy), -2);
        # The observation gallery along the near wall over the theatre's
        # edge, up a stair or a lift.
        deck(build, 7, 1, self.long - 1, 4, self.gal);
        if self.by_lift {
            lift(build, 3, 1, 6, 4, 0, self.gal);
            keep_box(build, room, 7, 1, 8, 4, self.gal);
        } else {
            stair(build, 1, 1, 0, 0, self.gal, 3);
            keep_box(build, room, 7, 1, 8, 4, self.gal);
        }
        # Taking the key: the closets open, the tanks burst, the medics come
        # onto the gallery.
        closets(build, taken, side, 0, [3, self.long - 7], [lab_foe(dice, self.danger, True), lab_foe(dice, self.danger)]);
        held = tanks_along(build, side, [8, 12], 0, 3, 6);
        shatter_row(build, taken, held[0], held[1], ["monster_parasite", "monster_chick"], 270.0, 0.5);
        squad(build, taken, [[float(self.long) - 4.5, 2.5, float(self.gal)], [10.5, 2.5, float(self.gal)]], ["monster_medic", lab_foe(dice, self.danger)], 270.0);
        taken +>:Fires:+> build.explosion(float(tx), float(cy) + 3.0, 1.0);
        beamed(build, taken, 2, 2, -8, lab_foe(dice, self.danger, True), float(tx) - 3.5, float(cy) + 0.5, -3, 0.0);
        build.train([2.0, 2.0, 1.0], [[float(tx - 3), float(cy - 1), 7.0], [float(tx + 1), float(cy - 1), 7.0]], 30.0, 1.0);
        steps = build.rising_steps(self.long - 7, cy - 1, -3, 0, 3, 3);
        keep_box(build, room, self.long - 4, cy - 1, self.long - 3, cy + 2, 0);
        build.push(float(self.long - 1), 2.5, float(self.gal) + 1.5, 2) +>:Fires:+> steps;
        build.touch(1.0, 5.0, 0.0, 3.0, float(side - 1), 6.0, True, "The commander lies on the table below");
        sparking(build, 1.2, float(side) - 2.5, 3.0, 0, 4.0);
        build.foe(float(self.long) - 3.5, float(side) - 3.5, 0, lab_foe(dice, self.danger), 180.0);
        rounds(build, lab_foe(dice, self.danger), [[9.5, 2.5], [float(self.long) - 3.5, 2.5]], self.gal);
        sparking(build, float(self.long) - 1.2, float(cy) + 0.5, 2.0, 2, 3.0);
        sparking(build, float(tx) + 2.2, float(cy), -2.0, 0, 5.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the security door beyond it, then the way out on a
dais up steps a button raises, or down a well whose floor a button sinks."""
node LabExit(Prefab) {
    has key: str = "",
        well: bool = False,
        drop: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lab exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = LAB;
        self.district = level_district(LAB);
        self.long = dice.between(30, 32);
        self.wide = dice.between(16, 18);
        self.well = dice.chance(0.45);
        self.drop = dice.between(7, 9);
        self.tall = 16;
        self.low = -2 * self.drop - 1 if self.well else -1;
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
        inner = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Return to the hangar");
        # The security door: the button beside it grants access.
        sx = 17;
        build.solid(sx, 1, 0, sx + 1, self.wide - 1, self.tall);
        build.widen(inner, sx, middle - 2, 0, sx + 1, middle + 2, 8);
        opened = build.opened(float(sx), float(middle - 2), 0.0, float(sx + 1), float(middle + 2), 8.0);
        granted = build.push(float(sx), float(middle) + 3.5, 1.5, 2);
        granted +>:Fires:+> opened;
        granted +>:Fires:+> build.objective("Access granted to the hangar lifts", False);
        # Tanks along the hall's wall burst as the player comes to the door.
        build.solid(9, self.wide - 4, 0, 17, self.wide - 1, self.tall);
        held = tanks_along(build, self.wide - 4, [10, 13], 0, 2, 6);
        near = build.touch(12.0, 1.0, 0.0, 15.0, float(self.wide - 4), 8.0);
        shatter_row(build, near, held[0], held[1], ["monster_parasite", lab_foe(dice, self.danger)], 270.0, 0.5);
        ex = self.long - 6;
        if self.well {
            # The well: its floor sinks with the player on it, the way out at
            # its foot.
            build.room(ex - 2, middle - 3, -self.drop, self.long - 1, middle + 3, 0);
            build.way_out(float(self.long) - 4.0, float(middle), -self.drop);
            sunk = build.sinking(float(ex - 2), float(middle - 3), float(self.long - 1), float(middle + 3), 0, self.drop);
            build.push(float(self.long - 1), float(middle) + 2.0, 2.5, 2) +>:Fires:+> sunk;
            build.touch(float(ex - 4), float(middle - 3), 0.0, float(ex - 2), float(middle + 3), 6.0, True, "The lift down is worked from its far wall");
        } else {
            # The dais, its steps rising when the button on its face is
            # pressed.
            build.solid(ex, 2, 0, self.long - 1, self.wide - 2, 4);
            steps = build.rising_steps(ex - 4, middle - 1, 0, 0, 4, 3);
            build.push(float(ex), float(middle) + 3.5, 1.5, 2) +>:Fires:+> steps;
            build.way_out(float(ex) + 3.0, float(middle), 4);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, lab_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(ex) - 5.5, 3.5, 0, lab_foe(dice, self.danger, True), 180.0);
        build.foe(float(ex) - 5.5, float(self.wide) - 3.5, 0, lab_foe(dice, self.danger), 180.0);
        sparking(build, float(sx) + 1.2, 2.5, 4.0, 0, 3.0);
        sparking(build, float(self.long) - 1.2, 2.5, 5.0, 2, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(sx) + 3.0, float(middle) + 0.5, 0, "ammo_cells", "q2");
    }
}

"""lab's stretches: [name, role]."""
glob LAB_STRETCHES: list[list[str]] = [
         ["decon", "start"],
         ["specimens", "flow"],
         ["bridge", "flow"],
         ["stack", "flow"],
         ["stack", "hub"],
         ["forcefield", "hub"],
         ["theatre", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of lab's stretches by its name."""
def make_lab(name: str, key: str) -> Prefab {
    if name == "decon" {
        return Decontamination();
    }
    if name == "specimens" {
        return SpecimenRow();
    }
    if name == "bridge" {
        return MaintenanceBridge();
    }
    if name == "stack" {
        return LabStack();
    }
    if name == "forcefield" {
        return ForcefieldHall();
    }
    if name == "theatre" {
        return OperatingTheatre(key=key if key else "key_silver");
    }
    return LabExit(key=key);
}
