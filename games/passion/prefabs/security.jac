"""Prefabs drawn from Quake II's security, Grid Control: a short, tall run of
rooms riding lifts through the security grid, its lasers sweeping on fast
carriers and pulsing in waves; a lift tower climbed platform by platform,
a maze of laser fences under a catwalk, the grid's control room whose
units are to be destroyed, the key in a monitor room over it. Raised in
security's own palette.

- `GridEntry`: the start. A hall, a raised walk along one wall up a stair
  (or a lift), lasers sweeping across the floor from emitters whose
  generators break, a fence of beams pulsing before the far ways; the help
  computer gives the objective.
- `LiftTower`: a tower of lifts, each up from a platform to the next on the
  wall across, beams sweeping across the shaft, a teleporter back down from
  the top; the way on from the top.
- `LaserMaze`: a hall of laser fences, each with a gap and pulsing in a
  wave, live plates in some gaps, generators that break; a catwalk over it
  all up a lift, its far end to drop from.
- `GridControl`: a tall control room round the grid's control: its units
  break, and with all of them gone the grid goes down in charges; beams
  sweep the floor; a balcony up a lift whose lever opens the ways below
  (a hub).
- `MonitorRoom`: the key room. The key in a monitor room up a lift; taking
  it opens the closets below and switches on lasers.
- `GridExit`: the end. A door (a key's, as a gate), a ledge and a stair
  down into a pit swept by lasers, the way out at its bottom."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, lift }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, keep_row, called_lift, closets, gate_pair, post_button, laser, laser_grid, drip, hurt, sweeper, pulse_wave }

glob SECURITY: str = "q2:security";

"""security's foes: berserkers and tanks, gunners and gladiators beside."""
glob SECURITY_FOES: FoeMix = FoeMix(light=["monster_berserk", "monster_gunner", "monster_infantry"], strong=["monster_gladiator"], heavy_light=["monster_berserk", "monster_gladiator"], heavy_strong=["monster_tank"], heavy_scale=0.5);


"""A sweeping laser from an emitter in the wall at the cell line y = 1 (at
x `lx`), aimed at a carrier riding along y = `ty` from `x0` to `x1`; its
generator beside the emitter breaks, shutting the beam off."""
def swept(build: Raising, dice: Stream, lx: int, x0: int, x1: int, ty: float) -> Cue {
    beam = sweeper(build, float(x0) + 0.25, ty, float(x1) + 0.25, ty, 1.5, float(lx) + 0.5, 1.2, 2.0, float(dice.between(300, 700)));
    build.breakable(float(lx + 1), 1.0, 0.0, float(lx + 2), 2.0, 3.0, 20) +>:Fires:+> beam;
    return beam;
}

"""A fence of beams across a floor at x `x` from the wall at y = 1 to the
far wall, at three heights, pulsing in a wave every `period` seconds."""
def pulsing_fence(build: Raising, xs: list[float], z: int, period: float) -> list[Cue] {
    beams = laser_grid(build, xs, 1.2, z, [0.8, 1.8, 2.8, 3.8, 4.8]);
    pulse_wave(build, beams, period, 0.25);
    pulse_wave(build, list(reversed(beams)), period * 1.7, 0.2);
    return beams;
}

"""The start: a hall, a raised walk along one wall, lasers sweeping the
floor."""
node GridEntry(Prefab) {
    has walk: int = 4,
        by_lift: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid entry";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(27, 30);
        self.wide = dice.between(18, 20);
        self.walk = dice.between(4, 5);
        self.by_lift = dice.chance(0.4);
        self.tall = dice.between(13, 15);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.walk), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        wy = self.wide - 5;
        # The walk along the north wall, up a stair or a lift.
        build.solid(10, wy, 0, self.long - 1, self.wide - 1, self.walk);
        if self.by_lift {
            lift(build, 6, wy, 10, self.wide - 1, 0, self.walk);
            for y in range(wy - 1, self.wide - 1) {
                build.keep(hall, 10, y, self.walk);
            }
        } else {
            stair(build, 10 - self.walk, wy, 0, 0, self.walk, 4);
        }
        # Lasers sweeping the floor, each from an emitter in the south wall
        # at a carrier riding along under the walk's front.
        beams = [swept(build, dice, 8, 9, 16, float(wy) - 0.5), swept(build, dice, 17, 16, self.long - 9, float(wy) - 0.5)];
        # A fence of beams before the far ways, pulsing.
        beams.append(sweeper(build, float(self.long - 4) + 0.25, 3.0, float(self.long - 4) + 0.25, float(wy) - 2.0, 1.5, 3.5, float(wy) - 1.2, 2.0, float(dice.between(300, 600))));
        pulse_wave(build, beams, 4.0, 0.5);
        fence = pulsing_fence(build, [float(self.long - 6) + 0.5], 0, 3.0);
        # A grid lever on the walk shuts the fence.
        lever = build.push(float(self.long) - 6.5, float(self.wide - 1), float(self.walk) + 1.0, 3);
        for beam in fence {
            lever +>:Fires:+> beam;
        }
        build.touch(float(self.long - 9), 1.0, 0.0, float(self.long - 8), float(wy), 6.0, False, "Grid sensors active");
        build.touch(6.0, 1.0, 0.0, 7.0, float(wy), 6.0, False, "Lasers ahead");
        hurt(build, float(self.long - 12), 2.0, 0.0, float(self.long - 10), 4.0, 1.0, 6);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        build.start(2.5, float(middle) - 1.5, 0, 0.0);
        build.supply(2.5, float(middle) - 3.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Locate and destroy grid control");
        # Halfway, guards appear on the walk.
        halfway = build.touch(float(self.long // 2), 1.0, 0.0, float(self.long // 2 + 1), float(wy), 6.0);
        guards(build, halfway, [[float(self.long) - 3.5, float(self.wide) - 3.0], [float(self.long) - 8.5, float(self.wide) - 3.0]], self.walk, SECURITY_FOES.squad(dice, self.danger, 2), 180.0);
        build.foe(12.5, float(self.wide) - 3.0, self.walk, "monster_infantry", 0.0, patrol=[[12.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, float(middle) - 3.5 + float(index) * 3.0, 0, SECURITY_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(14.5, float(self.wide) - 2.5, self.walk, Q2_ARMOR, "q2");
        drip(build, float(self.long // 2) + 0.5, float(middle) + 0.5, float(self.tall) - 0.5, 2.5);
    }
}

"""A tower of lifts, each up from a platform to the next on the wall
across, beams sweeping across the shaft."""
node LiftTower(Prefab) {
    has rise_by: int = 6,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lift tower";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(14, 16);
        self.wide = dice.between(16, 18);
        self.rise_by = dice.between(6, 7);
        self.tall = 3 * self.rise_by + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=3 * self.rise_by), Port(face=3, along=float(self.long // 2), floor=2 * self.rise_by)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        r = self.rise_by;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [r, 2 * r, 3 * r] {
            build.level(tower, z);
        }
        north = self.wide - 5;
        # Platforms: the first and third along the north wall, the second
        # along the south; lifts between, each beside the platform it leaves.
        build.solid(1, north, r - 1, self.long - 1, self.wide - 1, r);
        build.solid(1, 1, 2 * r - 1, self.long - 1, 5, 2 * r);
        build.solid(1, north, 3 * r - 1, self.long - 1, self.wide - 1, 3 * r);
        lift(build, self.long - 5, north - 3, self.long - 2, north, 0, r);
        lift(build, 2, 5, 5, north, r, 2 * r);
        lift(build, self.long - 5, 5, self.long - 2, north, 2 * r, 3 * r);
        for x in range(1, self.long - 1) {
            build.keep(tower, x, north, r);
            build.keep(tower, x, 4, 2 * r);
            build.keep(tower, x, north, 3 * r);
        }
        # Beams sweeping across the shaft, from emitters on the east wall at
        # carriers riding up and down the west wall.
        sweeps: list[Cue] = [];
        for (index, z) in enumerate([r + 2, 2 * r + 2, 2]) {
            sweeps.append(sweeper(build, 1.25, 6.0, 1.25, float(north - 2), float(z), float(self.long - 1) - 0.2, 7.0 + float(index) * 2.0, float(z) + 0.5, float(dice.between(250, 500))));
        }
        pulse_wave(build, sweeps, 3.5, 0.6);
        for z in [r, 2 * r, 3 * r] {
            build.touch(1.0, 1.0, float(z), 4.0, float(self.wide - 1), float(z + 6), False, "Grid sensors active");
        }
        # A grid lever on each platform shuts the beam over it.
        build.push(float(self.long // 2) + 0.5, float(self.wide - 1), float(r) + 1.0, 3) +>:Fires:+> sweeps[0];
        build.push(2.5, 1.0, float(2 * r) + 1.0, 1) +>:Fires:+> sweeps[1];
        # A teleporter on the top platform's far corner, back down to the
        # foot of the tower.
        build.teleporter(2.5, float(self.wide) - 2.5, 3 * r, float(self.long // 2) + 0.5, 7.5, 0, 0.0);
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Riding up, guards appear on the platforms above.
        first = build.touch(1.0, float(north), float(r), float(self.long - 1), float(self.wide - 1), float(r + 6));
        guards(build, first, [[float(self.long // 2) + 0.5, 3.0]], 2 * r, SECURITY_FOES.squad(dice, self.danger, 1), 90.0);
        guards(build, first, [[float(self.long // 2) + 0.5, float(self.wide) - 3.0]], 3 * r, SECURITY_FOES.squad(dice, self.danger, 1, True), 270.0);
        build.foe(float(self.long // 2) + 0.5, 4.5, 0, SECURITY_FOES.pick(dice, self.danger), 90.0);
        build.foe(3.5, float(self.wide) - 2.5, r, "monster_infantry", 0.0, patrol=[[3.5, float(self.wide) - 2.5], [float(self.long) - 6.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 3.5, 2.5, 2 * r, Q2_HEALTH, "q2");
        build.supply(4.5, float(self.wide) - 2.5, 3 * r, Q2_HEALTH, "q2");
        drip(build, float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, float(self.tall) - 0.5, 2.0);
    }
}

"""A hall of laser fences pulsing in waves, a catwalk over it all."""
node LaserMaze(Prefab) {
    has walk: int = 9,
        fences: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Laser maze";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(28, 32);
        self.wide = dice.between(17, 19);
        self.fences = dice.between(3, 4);
        self.tall = self.walk + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [
            Port(face=0, along=middle - 2.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.walk),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The catwalk along the north wall over the whole hall, up a lift at
        # the near end; its far end's edge to drop from.
        cy = self.wide - 5;
        build.solid(5, cy, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        lift(build, 2, cy, 5, self.wide - 1, 0, self.walk);
        for y in range(cy - 1, self.wide - 1) {
            build.keep(hall, 5, y, self.walk);
        }
        for x in range(self.long - 7, self.long - 3) {
            build.keep(hall, x, cy, self.walk);
        }
        # The fences: walls across the floor up to the catwalk's height,
        # each with a gap at one end or the other, beams across the gap
        # pulsing; a generator by each that breaks and shuts its beams off.
        span = self.long - 16;
        for fence in range(self.fences) {
            x = 8 + (span * fence) // max(1, self.fences - 1);
            gap_low = fence % 2 == 0;
            g0 = 1 if gap_low else cy - 5;
            g1 = g0 + 5;
            # (The walls run on under the catwalk, so the gap is the only way
            # by below.)
            if gap_low {
                build.solid(x, g1, 0, x + 1, self.wide - 1, 6);
            } else {
                build.solid(x, 1, 0, x + 1, g0, 6);
                build.solid(x, g1, 0, x + 1, self.wide - 1, 6);
            }
            beams = laser_grid(build, [float(x) + 0.5], float(g0) + 0.2, 0, [0.8, 1.8, 2.8, 3.8, 4.8]);
            pulse_wave(build, beams, 2.5 + float(fence) * 0.5, 0.3);
            pulse_wave(build, list(reversed(beams)), 4.0 + float(fence) * 0.5, 0.2);
            generator = build.breakable(float(x) + 1.0, float(g1) if gap_low else float(g0) - 1.0, 0.0, float(x) + 2.0, float(g1 + 1) if gap_low else float(g0), 3.0, 20);
            for beam in beams {
                generator +>:Fires:+> beam;
            }
            if fence % 2 == 1 {
                hurt(build, float(x) + 1.0, float(g0), 0.0, float(x) + 3.0, float(g1), 1.0, 6);
            }
            build.touch(float(x) - 2.0, float(g0), 0.0, float(x) - 1.0, float(g1), 6.0, False, "Laser fence");
            # A lever on the catwalk's wall over each fence shuts it.
            lever = build.push(float(x) + 0.5, float(self.wide - 1), float(self.walk) + 1.0, 3);
            for beam in beams {
                lever +>:Fires:+> beam;
            }
            sweeper(build, float(x) + 2.25, float(g0) + 1.0, float(x) + 2.25, float(g1) - 1.0, 1.5, float(x) + 3.5, float(cy) - 0.2, 2.0, float(dice.between(300, 600)));
        }
        # A teleporter at the far end back to the near end.
        build.teleporter(float(self.long) - 3.5, float(cy) - 2.5, 0, 3.5, float(middle) - 2.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # On the catwalk, guards appear at its far end.
        up = build.touch(5.0, float(cy), float(self.walk), 8.0, float(self.wide - 1), float(self.walk + 6));
        guards(build, up, [[float(self.long) - 3.5, float(self.wide) - 3.0]], self.walk, SECURITY_FOES.squad(dice, self.danger, 1, True), 180.0);
        guards(build, up, [[float(self.long) - 4.5, float(middle) - 3.5]], 0, SECURITY_FOES.squad(dice, self.danger, 1), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(12 + index * 8) + 0.5, float(middle) - 2.5, 0, SECURITY_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 3.0, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 4.5, float(self.wide) - 3.0, self.walk, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(middle) - 2.5, 3.0, 2, 3.0);
    }
}

"""A tall control room round the grid's control, a balcony up a lift."""
node GridControl(Prefab) {
    has balcony: int = 9,
        from_balcony: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid control";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.balcony = dice.between(9, 10);
        self.from_balcony = dice.chance(0.6);
        self.tall = self.balcony + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.balcony),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        b = self.balcony;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, b);
        # The balcony on two walls, up a lift.
        build.solid(1, self.wide - 4, b - 1, self.long - 1, self.wide - 1, b);
        build.solid(self.long - 4, cy + 3, b - 1, self.long - 1, self.wide - 4, b);
        lift(build, 2, self.wide - 7, 5, self.wide - 4, 0, b);
        for x in range(1, 6) {
            build.keep(room, x, self.wide - 4, b);
        }
        # Consoles round the floor's walls.
        for x in range(10, self.long - 10, 3) {
            if abs(x - cx) > 3 {
                build.solid(x, 1, 0, x + 2, 2, 2);
            }
        }
        # The grid's control: a block in the middle, its four units on its
        # top that break; with all four gone the grid goes down in charges.
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, 3);
        down = build.tally(4, "Grid control damaged");
        for corner in [[cx - 2, cy - 2], [cx + 1, cy - 2], [cx - 2, cy + 1], [cx + 1, cy + 1]] {
            build.breakable(float(corner[0]), float(corner[1]), 3.0, float(corner[0] + 1), float(corner[1] + 1), 5.0, 25) +>:Fires:+> down;
        }
        charges(build, down, [[float(cx) - 2.5, float(cy) - 2.5, 2.0], [float(cx) + 2.5, float(cy) + 2.5, 2.0], [float(cx) + 2.5, float(cy) - 2.5, 4.0], [float(cx) - 2.5, float(cy) + 2.5, 4.0]], 0.3);
        down +>:Fires:+> build.objective("Primary objective complete: the grid is down");
        # Beams sweeping the floor round it, and live plates by the block;
        # all go off when the grid does.
        beams = [swept(build, dice, 5, 4, 9, float(cy) + 4.5), swept(build, dice, self.long - 8, self.long - 9, self.long - 5, float(cy) + 4.5)];
        beams.append(sweeper(build, float(cx - 6) + 0.25, float(cy - 4), float(cx + 6) + 0.25, float(cy - 4), 1.5, float(cx) + 0.5, float(self.wide - 4) - 0.2, 2.0, float(dice.between(300, 600))));
        pulse_wave(build, beams, 3.0, 0.4);
        pulse_wave(build, beams, 5.0, 0.3);
        build.touch(float(cx - 6), float(cy - 6), 0.0, float(cx - 5), float(cy + 6), 6.0, False, "Grid control ahead");
        build.teleporter(float(self.long) - 2.5, float(cy) + 4.5, b, 3.5, float(cy) + 0.5, 0, 0.0);
        plates = [hurt(build, float(cx - 4), float(cy - 2), 0.0, float(cx - 2), float(cy + 2), 1.0, 6), hurt(build, float(cx + 2), float(cy - 2), 0.0, float(cx + 4), float(cy + 2), 1.0, 6)];
        for cue in beams + plates {
            down +>:Fires:+> cue;
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # The ways below, worked from the balcony's lever (or open as a body
        # nears).
        low_ports = [port for port in self.taken if port.floor == 0];
        if self.from_balcony {
            press = build.push(float(self.long) - 6.5, float(self.wide - 1), float(b) + 1.0, 3);
            for port in low_ports {
                press +>:Fires:+> shutter(build, self, port);
            }
            build.touch(float(self.long - 4), float(cy - 3), 0.0, float(self.long - 1), float(cy + 3), 6.0, True, "This door is opened elsewhere");
            auto_shutters(build, dice, self, [port for port in self.taken if port.floor != 0], 0.5);
        } else {
            auto_shutters(build, dice, self, self.taken, 0.6);
        }
        # Coming in, guards appear on the balcony; the tank waits by the
        # control late in a run.
        come_in = build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 6.0);
        guards(build, come_in, [[float(cx) + 0.5, float(self.wide) - 2.5]], b, SECURITY_FOES.squad(dice, self.danger, 1), 270.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(4 + index * 6) + 0.5, 4.5, 0, SECURITY_FOES.pick(dice, self.danger, index == 0), 90.0);
        }
        build.foe(float(cx) + 4.5, float(cy) + 0.5, 0, "monster_tank" if self.danger > 0.7 else SECURITY_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(3.5, float(self.wide) - 2.5, b, "monster_infantry", 0.0, patrol=[[6.5, float(self.wide) - 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, b, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 8.5, 0, Q2_HEALTH, "q2");
        build.supply(float(cx) + 6.5, float(self.wide) - 2.5, b, Q2_HEALTH, "q2");
        for x in [float(cx) - 5.5, float(cx) + 5.5] {
            sparking(build, x, 1.2, 3.0, 1, 2.5);
        }
    }
}

"""The key room: the key in a monitor room up a lift; taking it opens the
closets below and switches on lasers."""
node MonitorRoom(Prefab) {
    has key: str = "key_silver",
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Monitor room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(20, 22);
        self.wide = dice.between(21, 23);
        self.upper = dice.between(6, 7);
        self.tall = self.upper + 8;
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
        build.level(room, self.upper);
        build.doorway(room, self.enter);
        mx = self.long - 6;
        build.solid(mx, side + 1, self.upper - 1, self.long - 1, self.wide - 1, self.upper);
        build.solid(self.long - 2, side + 2, self.upper, self.long - 1, self.wide - 2, self.upper + 3);
        lift(build, mx - 3, cy - 1, mx, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, mx, y, self.upper);
        }
        # The key by the monitors; taking it opens the closets, switches on
        # lasers across the floor and a sweep along it.
        taken = key_cue(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.upper);
        closets(build, taken, [3, 8] if dice.chance(0.5) else [3, 9], side, -1, 0, SECURITY_FOES.squad(dice, self.danger, 2, True), 90.0);
        for x in [6.5, 10.5] {
            taken +>:Fires:+> laser(build, x, float(side) + 1.2, 2.0, 1, False);
        }
        taken +>:Fires:+> build.objective("Key taken. Proceed to the next combat unit");
        sweep = sweeper(build, 2.25, float(self.wide) - 2.0, float(mx) - 2.0, float(self.wide) - 2.0, 1.5, float(mx) - 0.2, float(side) + 2.0, 2.0, float(dice.between(300, 600)));
        build.breakable(float(mx - 2), float(side + 1), 0.0, float(mx - 1), float(side + 2), 3.0, 20) +>:Fires:+> sweep;
        build.push(1.0, float(side) + 2.5, 1.0, 0) +>:Fires:+> sweep;
        build.touch(float(mx - 4), float(side + 1), 0.0, float(mx - 3), float(self.wide - 1), 6.0, False, "Grid sensors active");
        pulse_wave(build, [sweep], 3.0, 0.5);
        build.foe(float(self.long) - 3.0, float(side) + 2.5, self.upper, SECURITY_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, float(cy) + 3.5, 0, "monster_infantry", 0.0, patrol=[[4.5, float(cy) + 3.5], [float(mx) - 4.5, float(cy) + 3.5]]);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 2.2, float(cy) - 2.5, float(self.upper) + 2.0, 2, 3.0);
    }
}

"""The end: a door, a ledge and a stair down into a pit swept by lasers,
the way out at its bottom."""
node GridExit(Prefab) {
    has key: str = "",
        deep: int = 5,
        tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grid exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = SECURITY;
        self.district = level_district(SECURITY);
        self.long = dice.between(24, 26);
        self.wide = dice.between(15, 17);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(11, 12);
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
        build.solid(wall + 1, 1, low, wall + 4, self.wide - 1, 0);
        stair(build, wall + 3 + self.deep, 2, low, 2, self.deep, 3);
        build.way_out(float(self.long) - 3.5, float(middle), low);
        # Lasers sweep the pit; a fence pulses before the way out.
        sweeper(build, float(wall + 6) + 0.25, float(self.wide) - 2.0, float(self.long - 6) + 0.25, float(self.wide) - 2.0, float(low) + 1.5, float(wall + 7) + 0.5, 1.2, float(low) + 2.0, float(dice.between(300, 600)));
        fence = pulsing_fence(build, [float(self.long - 6) + 0.5], low, 3.0);
        lever = build.push(float(wall) + 2.5, float(self.wide - 1), 1.0, 3);
        for beam in fence {
            lever +>:Fires:+> beam;
        }
        # On the ledge, guards appear in the pit.
        ledge = build.touch(float(wall + 1), 1.0, 0.0, float(wall + 4), float(self.wide - 1), 6.0);
        guards(build, ledge, [[float(self.long) - 5.5, 3.5], [float(self.long) - 5.5, float(self.wide) - 3.5]], low, SECURITY_FOES.squad(dice, self.danger, 2, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, SECURITY_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.touch(float(self.long - 9), 1.0, float(low), float(self.long - 8), float(self.wide - 1), float(low + 6), False, "Grid sensors active");
    }
}

"""security's stretches: [name, role]."""
glob SECURITY_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["tower", "flow"],
         ["maze", "flow"],
         ["maze", "hub"],
         ["control", "hub"],
         ["control", "flow"],
         ["monitor", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of security's stretches by its name."""
def make_security(name: str, key: str) -> Prefab {
    if name == "entry" {
        return GridEntry();
    }
    if name == "tower" {
        return LiftTower();
    }
    if name == "maze" {
        return LaserMaze();
    }
    if name == "control" {
        return GridControl();
    }
    if name == "monitor" {
        return MonitorRoom(key=key if key else "key_silver");
    }
    return GridExit(key=key);
}
