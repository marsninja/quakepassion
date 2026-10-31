"""Prefabs drawn from Quake II's jail4, the Torture Chambers: chambers sunk
far below the prison, reached by a great elevator and a well wound down
round its walls; cell blocks of three tiers; a grinder pit whose pistons
pound beside a catwalk; the data CD (the key) on a rack. Raised in
jail4's own palette.

- `TortureEntry`: the start. A gallery over a vault of barred cells, a
  broad stair (or two) down from it into the chamber below; the help
  computer gives the objective; guards appear below as the player reaches
  the stair; the cells' bars open by buttons on their walls.
- `TortureWell`: a well entered at its top, a stair winding down round its
  walls past cages hung in it to its floor; pipes drip; guards appear at
  the bottom as the player starts down.
- `ElevatorShaft`: jail4's great elevator: a platform filling a deep shaft,
  stepping onto it at the top sends it down; a stair winds round the
  shaft's walls for the way back. Guards wake at the bottom as it goes.
- `CellTiers`: a cell block of three tiers round an atrium, walkways on
  both sides at each tier, stairs and bridges between; barred cells below
  opened by buttons, cells on the second tier that open as the player
  crosses its bridge. Ways on at all three tiers (a hub).
- `Grinder`: a pit where pistons pound beside a catwalk across it, steps
  out of it for whoever falls, an operator's booth over the far end whose
  switch opens the ways on (or they open as a body nears).
- `RackChamber`: the key room. The data CD on a rack on a gallery up a
  stair; taking it opens the cells along the near wall and switches on
  lasers across the chamber.
- `TortureExit`: the end. A door (a key's, as a gate), a stair down into a
  pit, the way out at its foot; guards appear on the ledge above."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, spiral, ring_path, ring_landing }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, stash, keep_row, called_lift, closets, gate_pair, post_button, laser, bars, drip }

glob JAIL4: str = "q2:jail4";

"""jail4's foes: soldiers and gunners, a tank deeper in."""
glob JAIL4_FOES: FoeMix = FoeMix(light=["monster_soldier_light", "monster_soldier", "monster_soldier_ss"], strong=["monster_gunner"], heavy_light=["monster_gunner", "monster_gunner"], heavy_strong=["monster_tank"], heavy_scale=0.5);


"""Barred cells along a wall: each three cells wide between walls at `xs`
(its west wall at each x) from the wall at y = 1 three cells deep on lift
`z`, its bars across its front, a button on its east wall's end opening
them; a stash in the first, a prisoner turned loose from the others."""
def barred_cells(build: Raising, dice: Stream, danger: float, xs: list[int], z: int, high: int) {
    for (index, x) in enumerate(xs) {
        build.solid(x, 1, z, x + 1, 4, z + high);
        build.solid(x + 4, 1, z, x + 5, 4, z + high);
        cell_bars = bars(build, float(x + 1), 4.0, float(z), float(x + 4), 5.0, float(z + min(5, high)));
        build.push(float(x + 4) + 0.5, 4.0, float(z) + 1.0, 1) +>:Fires:+> cell_bars;
        if index == 0 {
            build.supply(float(x) + 2.5, 2.5, z, Q2_ARMOR, "q2");
            build.secret(float(x + 1), 1.0, float(z), float(x + 4), 4.0, float(z + 3));
        } else {
            build.foe(float(x) + 2.5, 2.5, z, JAIL4_FOES.pick(dice, danger), 90.0);
        }
    }
}

"""The start: a gallery over a vault of barred cells, a broad stair down
into the chamber below."""
node TortureEntry(Prefab) {
    has gallery: int = 6,
        rim: int = 11,
        two_stairs: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture entry";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(27, 30);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(6, 7);
        self.rim = dice.between(11, 12);
        self.two_stairs = dice.chance(0.45);
        self.tall = self.gallery + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.gallery);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=5.0, floor=self.gallery), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        u = self.gallery;
        g = self.rim;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The gallery over the near end's vault, a slab on the cells' walls.
        build.solid(1, 1, u - 1, g, self.wide - 1, u);
        # The broad stair down from it: in the middle, or two along the side
        # walls.
        starts = [2, self.wide - 6] if self.two_stairs else [middle - 2];
        for y0 in starts {
            stair(build, g + u - 1, y0, 0, 2, u, 4);
            keep_row(build, hall, g - 1, y0, u, 0, 4);
        }
        # The vault's barred cells along the south wall under the gallery.
        barred_cells(build, dice, self.danger, [1, 5] if g >= 11 else [1], 0, u - 1);
        # Pillars down the chamber below.
        for x in range(g + u + 2, self.long - 3, 4) {
            build.solid(x, 2, 0, x + 1, 3, 6);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 2, 6);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        build.start(2.5, float(middle) + 0.5, u, 0.0);
        build.supply(2.5, float(middle) - 1.5, u, "ammo_shells", "q2");
        build.touch(1.0, 1.0, float(u), 4.0, float(self.wide - 1), float(u + 8)) +>:Fires:+> build.objective("Retrieve the data CD from the cell blocks");
        # At the stair's head, guards appear below.
        head = build.touch(float(g - 3), 1.0, float(u), float(g), float(self.wide - 1), float(u + 6));
        guards(build, head, [[float(self.long) - 4.5, float(middle) + 3.5], [float(self.long) - 6.5, float(middle) - 3.5]], 0, JAIL4_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(float(g + u) + 3.5, float(middle) + 0.5, 0, "monster_soldier", 0.0, patrol=[[float(g + u) + 3.5, float(middle) + 0.5], [float(self.long) - 3.5, float(middle) + 0.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(g + u + 5 + index * 3) + 0.5, 4.5 + float(index % 2) * float(self.wide - 9), 0, JAIL4_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 4.5, 0, Q2_HEALTH, "q2");
        for x in [float(g) + 3.5, float(self.long) - 6.5] {
            drip(build, x, float(middle) + 3.5, float(self.tall) - 0.5, 3.0);
        }
    }
}

"""A well entered at its top, a stair winding down round its walls past
cages hung in it."""
node TortureWell(Prefab) {
    has steps: int = 28,
        tall: int = 36;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture well";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        fits: list[int] = [];
        for steps in range(20, 34) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] == 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        self.enter = Port(face=2, along=top[1], floor=self.steps);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        well = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(well, self.steps // 2);
        build.level(well, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        # Cages hung in the well's middle, on chains from the roof.
        cx = self.long // 2;
        cy = self.wide // 2;
        for (index, z) in enumerate([self.steps // 3, 2 * self.steps // 3]) {
            x = cx - 2 + index * 2;
            build.solid(x, cy - 1, z, x + 2, cy + 1, z + 1);
            build.solid(x, cy - 1, z + 3, x + 2, cy + 1, z + 4);
            build.solid(x, cy - 1, z + 4, x + 1, cy, self.tall);
        }
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Starting down, guards appear at the bottom; pipes drip.
        down = build.touch(1.0, 1.0, float(self.steps - 2), float(self.long - 1), float(self.wide - 1), float(self.steps + 4));
        guards(build, down, [[float(cx) + 0.5, float(cy) + 0.5], [float(cx) - 1.5, float(cy) + 2.5]], 0, JAIL4_FOES.squad(dice, self.danger, 2, True), 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, 2.5 + float(index) * 2.0, self.steps // 2, JAIL4_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 1.5, float(cy) - 1.5, 0, "monster_soldier", 0.0, patrol=[[float(cx) + 1.5, float(cy) - 1.5], [float(cx) - 2.5, float(cy) - 1.5]]);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
        drip(build, float(cx) + 0.5, float(cy) - 0.5, float(self.tall) - 0.5, 2.5);
        drip(build, float(cx) - 1.5, float(cy) + 1.5, float(self.tall) - 0.5, 3.5);
    }
}

"""Jail4's great elevator: a platform filling a deep shaft that goes down
when stepped onto at the top; a stair winding round the shaft for the
way back."""
node ElevatorShaft(Prefab) {
    has drop: int = 20,
        start: int = 0,
        landing_y: int = 9,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elevator shaft";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(22, 24);
        self.wide = dice.between(19, 21);
        self.drop = dice.between(18, 21);
        self.tall = self.drop + 8;
        self.low = -self.drop - 2;
        self.high = self.tall + 1;
        # The stair winds up the ring round the shaft's walls (the box x 8 to
        # the far wall) to a landing on its west side, by the upper room.
        path = ring_path(8, 1, self.long - 1, self.wide - 1, 3);
        lap = len(path);
        middle = self.wide // 2;
        self.start = 0;
        self.landing_y = middle;
        for index in range(lap) {
            cell = path[index];
            if cell[4] == 2 and cell[1] == middle + 1 {
                self.start = (index - self.drop + lap) % lap;
                self.landing_y = middle;
            }
        }
        climbed = [(self.start + step) % lap for step in range(self.drop)];
        self.enter = Port(face=2, along=float(middle), floor=self.drop);
        # The ways out below where the stair does not climb.
        self.leaves = [];
        faces = [0, 3, 1];
        alongs = [float(middle), float(self.long - 6), float(self.long - 6)];
        for choice in range(3) {
            face = faces[choice];
            along = alongs[choice];
            blocked = False;
            for index in climbed {
                cell = path[index];
                if cell[4] == face {
                    at = float(cell[1]) + 0.5 if face % 2 == 0 else float(cell[0]) + 0.5;
                    if abs(at - along) <= 3.0 {
                        blocked = True;
                    }
                }
            }
            if not blocked {
                self.leaves.append(Port(face=face, along=along, floor=0));
            }
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        t = self.drop;
        shaft = build.room(8, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        upper = build.room(1, middle - 4, t, 8, middle + 4, t + 8, variant=dice.below(3));
        build.level(shaft, t);
        # The stair winding up round the shaft's walls to its landing.
        spiral(build, 8, 1, self.long - 1, self.wide - 1, 0, t, 3, 4, self.start);
        # The platform filling the shaft's middle up to the landing's height;
        # stepping onto it, it goes down a moment later.
        px = 11;
        py = middle - 3;
        platform = build.sinking(float(px), float(py), float(px + 6), float(py + 6), t, t);
        keep_row(build, shaft, px - 1, py, t, 0, 6);
        if dice.chance(0.5) {
            aboard = build.touch(float(px), float(py), float(t), float(px + 6), float(py + 6), float(t + 6), True, "Going down");
            late = build.delay(1.0);
        } else {
            # A button on a post in the upper room; three seconds to step
            # aboard.
            aboard = post_button(build, 6, middle - 3, t, 0);
            late = build.delay(3.0);
        }
        aboard +>:Fires:+> late;
        late +>:Fires:+> platform;
        build.doorway(upper, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # As it goes, guards at the bottom wake.
        guards(build, aboard, [[float(px) + 2.5, 2.5], [float(px) + 2.5, float(self.wide) - 3.5]], 0, JAIL4_FOES.squad(dice, self.danger, 2, True), 90.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, JAIL4_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(middle) + 2.5, t, JAIL4_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(middle) - 2.5, t, "ammo_bullets", "q2");
        build.supply(float(px) + 3.0, float(py) + 3.0, t, Q2_HEALTH, "q2");
        for spot in [[px + 1, py + 1], [px + 4, py + 4]] {
            drip(build, float(spot[0]) + 0.5, float(spot[1]) + 0.5, float(self.tall) - 0.5, 3.0);
        }
    }
}

"""A cell block of three tiers round an atrium, walkways at each tier,
stairs and bridges between."""
node CellTiers(Prefab) {
    has tier: int = 8,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell tiers";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(30, 33);
        self.wide = dice.between(22, 24);
        self.tall = 2 * self.tier + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long - 3), floor=self.tier),
            Port(face=1, along=float(self.long - 3), floor=2 * self.tier)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        t = self.tier;
        atrium = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(atrium, t);
        build.level(atrium, 2 * t);
        # The walkways at the second and third tiers, slabs over the cells
        # and the aisles below; cell walls on all three tiers.
        for floor in [t, 2 * t] {
            build.solid(1, 1, floor - 1, self.long - 1, 7, floor);
            build.solid(1, self.wide - 7, floor - 1, self.long - 1, self.wide - 1, floor);
        }
        walls: list[int] = [];
        for x in range(4, self.long - 6, 4) {
            for floor in [0, t, 2 * t] {
                build.solid(x, 1, floor, x + 1, 4, floor + 6);
                build.solid(x, self.wide - 4, floor, x + 1, self.wide - 1, floor + 6);
            }
            walls.append(x);
        }
        # Stairs at the near end: up from the floor to the south walkway,
        # and from the north walkway up to the north walkway over it.
        stair(build, 3, 7, 0, 0, t, 3);
        keep_row(build, atrium, 1 + t, 6, t, 1, 4);
        stair(build, 3, self.wide - 10, t, 0, t, 3);
        keep_row(build, atrium, 2, self.wide - 7, t, 1, 4);
        keep_row(build, atrium, 1 + t, self.wide - 7, 2 * t, 1, 4);
        # Bridges across the atrium: on the second tier in the middle, on
        # the third near the far end.
        b1 = self.long // 2;
        b2 = self.long - 8;
        build.solid(b1, 7, t - 1, b1 + 3, self.wide - 7, t);
        build.solid(b2, 7, 2 * t - 1, b2 + 3, self.wide - 7, 2 * t);
        for b in [[b1, t], [b2, 2 * t]] {
            keep_row(build, atrium, b[0], 6, b[1], 1, 3);
            keep_row(build, atrium, b[0], self.wide - 7, b[1], 1, 3);
        }
        # Barred cells on the floor, opened by buttons on their walls.
        if len(walls) >= 3 {
            for (index, x) in enumerate([walls[1], walls[-1]]) {
                cell_bars = bars(build, float(x - 3), 4.0, 0.0, float(x), 5.0, 5.0);
                build.push(float(x) + 0.5, 4.0, 1.0, 1) +>:Fires:+> cell_bars;
                if index == 0 {
                    build.supply(float(x) - 1.5, 2.5, 0, Q2_ARMOR, "q2");
                    build.secret(float(x - 3), 1.0, 0.0, float(x), 4.0, 3.0);
                } else {
                    build.foe(float(x) - 1.5, 2.5, 0, JAIL4_FOES.pick(dice, self.danger), 90.0);
                }
            }
        }
        # And on the top tier, more barred cells along the south walkway.
        for (index, x) in enumerate(walls[0::2]) {
            cell_bars = bars(build, float(x - 3), 4.0, float(2 * t), float(x), 5.0, float(2 * t + 5));
            build.push(float(x) + 0.5, 4.0, float(2 * t) + 1.0, 1) +>:Fires:+> cell_bars;
            if index % 2 == 0 {
                build.supply(float(x) - 1.5, 2.5, 2 * t, Q2_AMMO[index % len(Q2_AMMO)], "q2");
            } else {
                build.foe(float(x) - 1.5, 2.5, 2 * t, JAIL4_FOES.pick(dice, self.danger), 90.0);
            }
        }
        build.doorway(atrium, self.enter);
        for port in self.taken {
            build.doorway(atrium, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Crossing the second tier's bridge opens cells on the south walkway:
        # their guards come out; more appear on the third tier.
        crossing = build.touch(float(b1), 9.0, float(t), float(b1 + 3), float(self.wide - 9), float(t + 6));
        for (index, x) in enumerate(walls[1::2]) {
            door = build.opened(float(x - 3), 4.0, float(t), float(x), 5.0, float(t + 5));
            crossing +>:Fires:+> door;
            build.foe(float(x) - 1.5, 2.5, t, JAIL4_FOES.pick(dice, self.danger, index == 0), 90.0);
        }
        guards(build, crossing, [[float(b2) + 1.5, float(self.wide) - 3.5], [float(b2) - 4.5, 4.5]], 2 * t, JAIL4_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(5.5, float(middle) + 0.5, 0, "monster_soldier", 0.0, patrol=[[5.5, float(middle) + 0.5], [float(self.long) - 4.5, float(middle) + 0.5]]);
        build.foe(float(self.long) - 4.5, 5.5, t, "monster_soldier_light", 180.0, patrol=[[float(self.long) - 4.5, 5.5], [13.5, 5.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, JAIL4_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 3.5, float(self.wide) - 4.5, 2 * t, Q2_HEALTH, "q2");
        for x in [9.5, float(b1) + 1.5, float(b2) - 2.5] {
            drip(build, x, float(middle) + 0.5, float(self.tall) - 0.5, 2.0 + x * 0.05);
        }
    }
}

"""A pit where pistons pound beside a catwalk across it, an operator's
booth over the far end."""
node Grinder(Prefab) {
    has deep: int = 7,
        booth: int = 9,
        from_booth: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grinder";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(27, 30);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(6, 7);
        self.from_booth = dice.chance(0.6);
        self.tall = self.booth + 7;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle + 4.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.booth),
            Port(face=1, along=float(self.long - 3), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        d = self.deep;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.booth);
        # The pit, steps up out of it to the near side; the catwalk across.
        x0 = 6;
        x1 = self.long - 7;
        pit = build.room(x0, 1, -d, x1, self.wide - 1, 0);
        build.level(pit, -d);
        stair(build, x0 + d - 1, 1, -d, 2, d, 3);
        build.solid(x0, middle - 1, -1, x1, middle + 2, 0);
        for x in [x0 - 1, x1] {
            for y in range(middle - 1, middle + 2) {
                build.keep(room, x, y, 0);
            }
        }
        # The pistons pounding up and down beside the catwalk.
        for (index, x) in enumerate(range(x0 + d + 1, x1 - 2, 4)) {
            y = middle - 4 if index % 2 == 0 else middle + 3;
            build.train([2.0, 2.0, 4.0], [[float(x), float(y), float(-d)], [float(x), float(y), -2.0]], float(dice.between(90, 140)), 0.5);
        }
        # The operator's booth over the far end's north half, up a stair
        # along the far wall; its switch opens the ways on below.
        bx = self.long - 6;
        build.solid(bx, middle, self.booth - 1, self.long - 1, self.wide - 1, self.booth);
        build.solid(bx, middle, self.booth, bx + 1, self.wide - 1, self.booth + 2);
        stair(build, self.long - 4, middle - self.booth, 0, 1, self.booth, 3);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        low_ports = [port for port in self.taken if port.floor == 0];
        if self.from_booth {
            press = build.push(float(self.long) - 4.5, float(self.wide - 1), float(self.booth) + 1.0, 3);
            for port in low_ports {
                press +>:Fires:+> shutter(build, self, port);
            }
            build.touch(float(x1), float(middle - 1), 0.0, float(x1 + 2), float(middle + 2), 6.0, True, "This door is opened elsewhere");
            auto_shutters(build, dice, self, [port for port in self.taken if port.floor != 0], 0.5);
        } else {
            auto_shutters(build, dice, self, self.taken, 0.6);
        }
        # Halfway over, guards appear in the booth.
        over = build.touch(float((x0 + x1) // 2 - 1), float(middle - 1), 0.0, float((x0 + x1) // 2 + 1), float(middle + 2), 6.0);
        guards(build, over, [[float(self.long) - 3.5, float(middle) + 1.5], [float(self.long) - 3.5, float(self.wide) - 3.5]], self.booth, JAIL4_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(float(x0) + 2.5, float(self.wide) - 4.5, -d, JAIL4_FOES.pick(dice, self.danger), 90.0);
        build.foe(3.5, 3.5, 0, "monster_soldier", 90.0, patrol=[[3.5, 3.5], [3.5, float(self.wide) - 3.5]]);
        build.foe(float(x1) + 1.5, float(middle) + 4.5, 0, JAIL4_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(x0) + 4.5, float(self.wide) - 3.5, -d, "ammo_grenades", "q2");
        build.supply(2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        for x in [float(x0) + 3.5, float(x1) - 2.5] {
            sparking(build, x, 1.2, float(-d) + 2.0, 1, 3.0);
        }
    }
}

"""The key room: the data CD on a rack on a gallery up a stair; taking it
opens the cells and switches on lasers."""
node RackChamber(Prefab) {
    has key: str = "key_silver",
        gallery: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rack chamber (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(22, 24);
        self.wide = dice.between(22, 24);
        self.gallery = dice.between(5, 7);
        self.tall = self.gallery + 12;
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
        cy = (self.wide + 4) // 2 - 1;
        room = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.gallery);
        build.doorway(room, self.enter);
        # The gallery across the far end, a stair up to it; the rack on it.
        gx = self.long - 7;
        build.solid(gx, side + 1, 0, self.long - 1, self.wide - 1, self.gallery);
        stair(build, gx - self.gallery, cy - 2, 0, 0, self.gallery, 4);
        keep_row(build, room, gx, cy - 3, self.gallery, 0, 6);
        build.solid(self.long - 4, cy - 1, self.gallery, self.long - 2, cy + 2, self.gallery + 1);
        build.solid(self.long - 2, cy - 2, self.gallery, self.long - 1, cy + 3, self.gallery + 4);
        # The rack shut behind a gate of bars a button on the gallery raises.
        build.solid(self.long - 2, cy - 2, self.gallery + 4, self.long - 1, cy + 3, self.gallery + 6);
        build.solid(self.long - 5, cy - 2, self.gallery, self.long - 2, cy - 1, self.gallery + 6);
        build.solid(self.long - 5, cy + 2, self.gallery, self.long - 2, cy + 3, self.gallery + 6);
        rack_gate = build.opened(float(self.long - 5), float(cy - 1), float(self.gallery), float(self.long - 4), float(cy + 2), float(self.gallery + 6));
        build.push(float(gx) + 2.5, float(self.wide - 1), float(self.gallery) + 1.0, 3) +>:Fires:+> rack_gate;
        taken = key_cue(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.gallery + 1);
        closets(build, taken, [3, 8, 13] if dice.chance(0.5) else [4, 11], side, -1, 0, JAIL4_FOES.squad(dice, self.danger, 3, True), 90.0);
        for x in [6.5, 12.5] {
            taken +>:Fires:+> laser(build, x, float(side) + 1.2, 2.0, 1, False);
        }
        taken +>:Fires:+> build.objective("Data CD retrieved. Get it to its door");
        guards(build, taken, [[float(gx) - 2.5, float(self.wide) - 3.5]], 0, JAIL4_FOES.squad(dice, self.danger, 1, True), 0.0);
        build.foe(float(self.long) - 4.0, float(self.wide) - 3.5, self.gallery, JAIL4_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, float(cy) + 3.5, 0, "monster_soldier", 0.0, patrol=[[4.5, float(cy) + 3.5], [float(gx) - 7.5, float(cy) + 3.5]]);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
        drip(build, float(gx) - 3.5, float(cy) + 0.5, float(self.tall) - 0.5, 3.0);
    }
}

"""The end: a door, a stair down into a pit, the way out at its foot."""
node TortureExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torture exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL4;
        self.district = level_district(JAIL4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(11, 13);
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
        low = -self.deep;
        wall = 8;
        gate_pair(build, dice, self.enter, self.long, self.wide, wall, low, self.tall, self.key);
        # A ledge inside the door, a stair down from it into the pit.
        build.solid(wall + 1, 1, low, wall + 3, self.wide - 1, 0);
        stair(build, wall + 2 + self.deep, middle - 2, low, 2, self.deep, 4);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        # On the ledge, guards appear in the pit; pistons pound by the way
        # out.
        ledge = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards(build, ledge, [[float(self.long) - 5.5, 3.5], [float(self.long) - 5.5, float(self.wide) - 3.5]], low, JAIL4_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.train([2.0, 2.0, 3.0], [[float(self.long - 6), 2.0, float(low)], [float(self.long - 6), 2.0, float(low + 3)]], 100.0, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, JAIL4_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 7.5, float(middle) + 0.5, low, "monster_soldier", 0.0, patrol=[[float(wall) + 7.5, float(middle) + 0.5], [float(self.long) - 6.5, float(middle) + 0.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        drip(build, float(wall) + 6.5, float(middle) + 3.5, float(self.tall) - 0.5, 2.5);
    }
}

"""jail4's stretches: [name, role]."""
glob JAIL4_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["well", "flow"],
         ["elevator", "flow"],
         ["tiers", "hub"],
         ["tiers", "flow"],
         ["grinder", "flow"],
         ["grinder", "hub"],
         ["rack", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail4's stretches by its name."""
def make_jail4(name: str, key: str) -> Prefab {
    if name == "entry" {
        return TortureEntry();
    }
    if name == "well" {
        return TortureWell();
    }
    if name == "elevator" {
        return ElevatorShaft();
    }
    if name == "tiers" {
        return CellTiers();
    }
    if name == "grinder" {
        return Grinder();
    }
    if name == "rack" {
        return RackChamber(key=key if key else "key_silver");
    }
    return TortureExit(key=key);
}
