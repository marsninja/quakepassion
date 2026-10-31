"""Prefabs drawn from Quake II's jail2, the Detention Center: a reception
hall under a guard post and a gallery, cells in two tiers behind bars, a
drain hall over deep water, the laser control over its corridor, the
security complex round a sunken control pit, the key in an observation
room over an interrogation cell, the processing room's great gate out.
Raised in jail2's own palette.

- `Reception`: the start. A hall, a guard post raised in its middle up
  steps, a gallery along one wall up a stair (or a perch for snipers); a
  checkpoint of lasers before the far gates that the post's console shuts
  off, now and then. Guards appear on the gallery as the player leaves the
  doors.
- `CellTiers`: an atrium, cells along both walls on two tiers, walkways
  over the lower cells up a stair at the far end (or one at the near end
  alongside a walkway), a bridge across between them now and then. Some lower cells are
  barred, each by a button on its wall (jail2's toggled bars); reaching a
  walkway opens upper cells and brings guards to the other.
- `DrainHall`: a hall round a deep drain of water, a walkway across it, a
  gallery along one wall up a lift or a stair that rises when its switch
  high on the far wall is shot (jail2's stair of doors); a grate under the
  water breaks on a stash. Ways on from the floor and the gallery (a hub).
- `LaserControl`: a corridor shut across by walls whose gates are fenced by
  lasers, under a control balcony up a lift (or a lift called down); the
  control on the balcony shuts the fences and guards come up the corridor.
- `SecurityComplex`: a hall round a sunken control pit, offices on a
  mezzanine along one wall up a stair; the console in the pit (or in an
  office) opens the gates out; guards appear in the offices as the player
  goes down into the pit.
- `Observation`: the key room. An observation room over an interrogation
  cell up a lift or a stair, a window over the hall; the key on its
  console; taking it opens the closets along the near wall and the cell's
  bars, and switches on lasers across the hall.
- `Processing`: the end. A door (a key's, as a gate), a processing room
  barred by a great gate raised from a balcony (or from a console by the
  wall), the way out beyond it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, stash, keep_row, called_lift, closets, gate_pair, post_button, laser, laser_grid, bars }
import from .q2walls_parts { partition }

glob JAIL2: str = "q2:jail2";

"""jail2's foes: infantry and gunners, medics among them, berserkers,
gladiators and a tank deeper in."""
glob JAIL2_FOES: FoeMix = FoeMix(light=["monster_infantry", "monster_infantry", "monster_medic"], strong=["monster_berserk", "monster_parasite"], heavy_light=["monster_gunner", "monster_gladiator"], heavy_strong=["monster_tank"], heavy_scale=0.5);


"""The start: a hall, a guard post in its middle, a gallery along a wall."""
node Reception(Prefab) {
    has post: int = 3,
        gallery: int = 9,
        climb: bool = True,
        checkpoint: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reception";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(26, 29);
        self.wide = dice.between(20, 23);
        self.post = dice.between(3, 4);
        self.climb = dice.chance(0.65);
        self.checkpoint = dice.chance(0.6);
        self.tall = self.gallery + 13;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        if self.climb {
            self.leaves.append(Port(face=0, along=float(self.wide - 3), floor=self.gallery));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2 - 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.post);
        build.level(hall, self.gallery);
        # The guard post, steps up its near face, pillars at its corners and
        # a console on it.
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.post);
        stair(build, cx - 3 - self.post, cy - 1, 0, 0, self.post, 3);
        keep_row(build, hall, cx - 3, cy - 1, self.post, 0, 3);
        for corner in [[cx - 3, cy - 3], [cx + 2, cy - 3], [cx - 3, cy + 2], [cx + 2, cy + 2]] {
            build.solid(corner[0], corner[1], self.post, corner[0] + 1, corner[1] + 1, self.post + 6);
        }
        build.solid(cx + 1, cy - 1, self.post, cx + 2, cy + 2, self.post + 2);
        # The gallery along the north wall: up a stair at the near end, or a
        # perch for snipers.
        gy = self.wide - 5;
        if self.climb {
            build.solid(2 + self.gallery, gy, self.gallery - 1, self.long - 1, self.wide - 1, self.gallery);
            stair(build, 2, self.wide - 4, 0, 0, self.gallery, 3);
        } else {
            build.solid(8, gy, self.gallery - 1, self.long - 1, self.wide - 1, self.gallery);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The checkpoint: lasers across the hall before the far gates, shut
        # off by the post's console.
        if self.checkpoint {
            beams = laser_grid(build, [float(self.long - 7) + 0.5], 1.2, 0, [1.0, 2.5, 4.0]);
            press = build.push(float(cx + 1), float(cy) + 0.5, float(self.post) + 0.6, 2);
            for beam in beams {
                press +>:Fires:+> beam;
            }
            press +>:Fires:+> build.objective("Checkpoint open. Find the keycards to the cell blocks");
            guards(build, press, [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(cy) + 3.5]], 0, JAIL2_FOES.squad(dice, self.danger, 2, True), 180.0);
            build.touch(float(self.long - 10), 1.0, 0.0, float(self.long - 9), float(gy), 6.0, True, "The checkpoint's lasers are worked from the guard post");
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Find the keycards to the cell blocks");
        # Leaving the doors, guards appear on the gallery.
        leaving = build.touch(5.0, 1.0, 0.0, 7.0, float(gy), 8.0);
        guards(build, leaving, [[float(self.long) - 4.5, float(self.wide) - 3.0], [float(self.long) - 10.5, float(self.wide) - 3.0]], self.gallery, JAIL2_FOES.squad(dice, self.danger, 2), 270.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx + 6) + 0.5, 3.5 + float(index) * 5.0, 0, JAIL2_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(cx) - 0.5, float(cy) + 0.5, self.post, JAIL2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(cx - 5) + 0.5, float(cy - 5) + 0.5, 0, "monster_infantry", 0.0, patrol=[[float(cx - 5) + 0.5, float(cy - 5) + 0.5], [float(cx + 5) + 0.5, float(cy - 5) + 0.5], [float(cx + 5) + 0.5, float(cy + 4) + 0.5], [float(cx - 5) + 0.5, float(cy + 4) + 0.5]]);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(cx) + 2.2, float(cy) + 0.5, float(self.post) + 1.0, 0, 5.0);
    }
}

"""An atrium, cells along both walls on two tiers, walkways over the
lower cells, some cells barred."""
node CellTiers(Prefab) {
    has tier: int = 7,
        at_far: bool = True,
        bridge: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell tiers";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(28, 31);
        self.wide = dice.between(20, 22);
        self.at_far = dice.chance(0.6);
        self.bridge = dice.chance(0.55);
        self.tall = self.tier + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        # The ways out on the walkways, past the last of the upper cells.
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=self.tier), Port(face=3, along=float(self.long - 3), floor=self.tier)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        t = self.tier;
        atrium = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(atrium, t);
        # The walkways along both walls, a slab over the lower cells and the
        # aisle before them; cell walls on both tiers.
        build.solid(1, 1, t - 1, self.long - 1, 7, t);
        build.solid(1, self.wide - 7, t - 1, self.long - 1, self.wide - 1, t);
        cells: list[int] = [];
        for x in range(4, self.long - 6, 4) {
            build.solid(x, 1, 0, x + 1, 5, t - 1);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 1, t - 1);
            build.solid(x, 1, t, x + 1, 3, t + 5);
            build.solid(x, self.wide - 3, t, x + 1, self.wide - 1, t + 5);
            cells.append(x);
        }
        # Up: a stair at the far end to a landing joining the walkways, or
        # one at the near end alongside the north walkway.
        if self.at_far {
            build.solid(self.long - 4, 7, t - 1, self.long - 1, self.wide - 7, t);
            stair(build, self.long - 4 - t, 7, 0, 0, t, 3);
            top = [float(self.long - 7), 7.0];
        } else {
            stair(build, 6, self.wide - 10, 0, 0, t, 3);
            keep_row(build, atrium, 4 + t, self.wide - 7, t, 1, 3);
            top = [float(4 + t), float(self.wide) - 4.0];
        }
        mid = self.long // 2 - 1;
        if self.bridge {
            build.solid(mid, 7, t - 1, mid + 3, self.wide - 7, t);
            keep_row(build, atrium, mid, 6, t, 1, 3);
            keep_row(build, atrium, mid, self.wide - 7, t, 1, 3);
        }
        # The lower cells' floors a step over the aisle, and a wall across the
        # atrium's floor, a gate through it over a sill.
        for x in cells {
            build.solid(x - 3, 1, 0, x, 5, 1);
            build.solid(x - 3, self.wide - 5, 0, x, self.wide - 1, 1);
        }
        wx = self.long - 6 - t;
        partition(build, atrium, wx, 5, wx + 1, self.wide - 5, 0, t - 1, [[middle - 2, middle + 2]]);
        # Barred cells below, each opened by the button on its wall: a
        # prisoner turned loose, or a stash.
        barred = [cells[index] for index in dice.order(len(cells))][:min(3, len(cells) - 1)] if len(cells) > 1 else [];
        for (index, x) in enumerate(barred) {
            north = index % 2 == 1;
            y_bar = self.wide - 5 if north else 4;
            cell_bars = bars(build, float(x - 3), float(y_bar), 0.0, float(x), float(y_bar + 1), 5.0);
            press = build.push(float(x) + 0.5, float(self.wide - 5) if north else 5.0, 1.0, 3 if north else 1);
            press +>:Fires:+> cell_bars;
            inside_y = float(self.wide) - 3.0 if north else 2.5;
            if index == 0 {
                build.supply(float(x) - 1.5, inside_y, 1, Q2_ARMOR, "q2");
                build.secret(float(x - 3), float(self.wide - 4) if north else 1.0, 0.0, float(x), float(self.wide - 1) if north else 4.0, 3.0);
            } else {
                build.foe(float(x) - 1.5, inside_y, 1, JAIL2_FOES.pick(dice, self.danger), 270.0 if north else 90.0);
            }
        }
        build.doorway(atrium, self.enter);
        for port in self.taken {
            build.doorway(atrium, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Reaching a walkway opens upper cells: guards come out, and more
        # appear on the other walkway.
        reached = build.touch(top[0], top[1] - 3.0, float(t), top[0] + 3.0, top[1], float(t + 6));
        for (index, x) in enumerate(cells[1::2]) {
            door = build.opened(float(x - 3), 3.0, float(t), float(x), 4.0, float(t + 5));
            reached +>:Fires:+> door;
            build.foe(float(x) - 1.5, 1.5, t, JAIL2_FOES.pick(dice, self.danger, index == 0), 90.0);
        }
        guards(build, reached, [[float(mid) + 1.5, float(self.wide) - 4.5], [float(mid) + 6.5, float(self.wide) - 4.5]], t, JAIL2_FOES.squad(dice, self.danger, 2), 270.0);
        build.foe(3.5, 7.5, 0, "monster_infantry", 0.0, patrol=[[3.5, 7.5], [float(wx) - 1.5, 7.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, JAIL2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        sparking(build, 1.2, float(middle) + 3.5, 5.0, 0, 6.0);
    }
}

"""A hall round a deep drain of water, a walkway across it, a gallery up
a lift or a stair that rises when its switch is shot."""
node DrainHall(Prefab) {
    has deep: int = 6,
        gallery: int = 9,
        rising: bool = True,
        grate: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drain hall";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(5, 7);
        self.rising = dice.chance(0.6);
        self.grate = dice.chance(0.6);
        self.tall = self.gallery + 16;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle - 2.0, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        # The drain: a deep pool in the floor's middle, steps out at both
        # ends, a walkway across it a lift over the water.
        py1 = self.wide - 9;
        build.pool(6, 6, -self.deep, self.long - 6, py1, 0, 2, False, True, True);
        stair(build, self.long - 6 - self.deep, 6, -self.deep, 0, self.deep, 2);
        stair(build, self.long - 6 - self.deep, py1 - 2, -self.deep, 0, self.deep, 2);
        build.solid(cx - 1, 6, -1, cx + 2, py1, 0);
        # A drain under the water in its far wall, behind a grate that
        # breaks (or open): a secret.
        build.room(self.long - 6, 10, -self.deep, self.long - 3, 13, -self.deep + 3);
        for z in range(-self.deep, -self.deep + 3) {
            for y in range(10, 13) {
                for x in range(self.long - 6, self.long - 3) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        if self.grate {
            build.breakable(float(self.long - 6), 10.0, float(-self.deep), float(self.long - 5), 13.0, float(-self.deep + 3), 15);
        }
        build.secret(float(self.long - 5), 10.0, float(-self.deep), float(self.long - 3), 13.0, float(-self.deep + 2));
        build.supply(float(self.long) - 3.5, 11.5, -self.deep, "ammo_rockets", "q2");
        # The gallery along the north wall; up a lift at its near end, or a
        # stair that rises out of the floor when the switch high on the far
        # wall is shot.
        gy = self.wide - 5;
        build.solid(1, gy, self.gallery - 1, self.long - 1, self.wide - 1, self.gallery);
        if self.rising {
            build.solid(1, gy, self.gallery - 1, 2 + self.gallery, self.wide - 1, self.gallery);
            steps = build.rising_steps(2, gy - 3, 0, 0, self.gallery, 3);
            build.push(float(self.long) - 8.5, float(self.wide - 1), float(self.gallery) + 3.0, 3, True) +>:Fires:+> steps;
            build.touch(2.0, float(gy - 4), 0.0, 6.0, float(gy - 3), 6.0, True, "Shoot the switch to raise the stair");
            keep_row(build, hall, 2, gy, self.gallery, 1, self.gallery);
        } else {
            post_button(build, 6, gy - 3, 0, 0) +>:Fires:+> called_lift(build, 2, gy - 3, 5, gy, 0, self.gallery);
            keep_row(build, hall, 1, gy, self.gallery, 1, 5);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        # Halfway over the walkway, guards appear on the gallery.
        over = build.touch(float(cx - 1), 6.0, 0.0, float(cx + 2), float(py1), 6.0);
        guards(build, over, [[float(cx) + 4.5, float(self.wide) - 3.0], [float(self.long) - 4.5, float(self.wide) - 3.0]], self.gallery, JAIL2_FOES.squad(dice, self.danger, 2, True), 270.0);
        for index in range(dice.between(2, 3)) {
            build.foe(3.5 + float(index) * 6.0, 3.0, 0, JAIL2_FOES.pick(dice, self.danger, index == 0), 0.0);
        }
        build.foe(float(self.long) - 3.5, 3.5, 0, "monster_parasite", 90.0, patrol=[[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(py1) + 1.5]]);
        build.foe(8.5, float(self.wide) - 3.0, self.gallery, "monster_infantry", 0.0, patrol=[[8.5, float(self.wide) - 3.0], [float(self.long) - 6.5, float(self.wide) - 3.0]]);
        build.supply(float(cx) + 0.5, float(self.wide) - 3.0, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(cx) + 0.5, 1.2, 4.0, 1, 4.0);
    }
}

"""A corridor fenced by lasers under a control balcony up a lift."""
node LaserControl(Prefab) {
    has balcony: int = 10,
        fences: int = 1,
        called: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Laser control";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(30, 33);
        self.wide = dice.between(16, 18);
        self.balcony = dice.between(10, 12);
        self.fences = dice.between(1, 2);
        self.called = dice.chance(0.5);
        self.tall = self.balcony + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=6.0, floor=self.balcony),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        # The control balcony over the corridor's near end, a lift beside
        # it (or one called down from below).
        bx = 12;
        build.solid(1, 1, self.balcony - 1, bx, self.wide - 1, self.balcony);
        # Called down by a post's button at its foot, or by one on the wall
        # beside it.
        if self.called {
            post_button(build, bx + 3, 5, 0, 1) +>:Fires:+> called_lift(build, bx, 1, bx + 3, 5, 0, self.balcony);
        } else {
            build.push(float(bx) + 1.5, 1.0, 1.0, 1) +>:Fires:+> called_lift(build, bx, 2, bx + 3, 5, 0, self.balcony);
        }
        keep_row(build, hall, bx - 1, 1, self.balcony, 0, 6);
        build.solid(1, 3, self.balcony, 2, self.wide - 3, self.balcony + 2);
        # The fences of lasers across the corridor beyond: each across a gate
        # in a wall, over a sill.
        xs: list[float] = [];
        for fence in range(self.fences) {
            at = bx + 6 + fence * 4;
            partition(build, hall, at, 1, at + 1, self.wide - 1, 0, 10, [[middle - 2, middle + 2]]);
            xs.append(float(at) + 0.5);
        }
        beams = laser_grid(build, xs, float(middle - 2) + 0.2, 0, [1.5, 3.0, 4.5]);
        for x in xs {
            build.touch(x - 2.5, 1.0, 0.0, x - 1.5, float(self.wide - 1), 6.0, True, "Find the laser control");
        }
        # The control on the balcony's back wall shuts the fences; guards
        # come up the corridor.
        press = build.push(2.0, float(middle) + 0.5, float(self.balcony) + 1.0, 0);
        for beam in beams {
            press +>:Fires:+> beam;
        }
        press +>:Fires:+> build.objective("Lasers down. Return to the security complex");
        guards(build, press, [[float(self.long) - 4.5, float(middle) - 2.5], [float(self.long) - 4.5, float(middle) + 2.5]], 0, JAIL2_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Riding up, guards appear on the balcony.
        riding = build.touch(float(bx), 1.0, float(self.balcony), float(bx + 3), 5.0, float(self.balcony + 6));
        guards(build, riding, [[5.5, float(self.wide) - 3.5]], self.balcony, JAIL2_FOES.squad(dice, self.danger, 1), 0.0);
        build.foe(float(bx) + 2.5, float(middle) + 3.5, 0, JAIL2_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 6.5, 3.5, 0, "monster_infantry", 90.0, patrol=[[float(self.long) - 6.5, 3.5], [float(self.long) - 6.5, float(self.wide) - 3.5]]);
        build.supply(4.5, float(self.wide) - 2.5, self.balcony, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, "ammo_bullets", "q2");
        sparking(build, float(bx) + 0.2, float(self.wide) - 2.5, float(self.balcony) - 2.0, 0, 3.0);
    }
}

"""A hall round a sunken control pit, offices on a mezzanine along one
wall; the console opens the gates out."""
node SecurityComplex(Prefab) {
    has deck: int = 9,
        in_pit: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security complex";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(28, 31);
        self.wide = dice.between(24, 26);
        self.in_pit = dice.chance(0.6);
        self.tall = self.deck + 12;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2 - 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 6), floor=self.deck),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2 - 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.deck);
        # The control pit, four lifts down, stairs into it at two corners,
        # consoles in its middle.
        px0 = cx - 6;
        px1 = cx + 6;
        py0 = cy - 4;
        py1 = cy + 4;
        pit = build.room(px0, py0, -4, px1, py1, 0);
        build.level(pit, -4);
        for step in range(3) {
            build.solid(px0 + step, py0, -4, px0 + step + 1, py0 + 3, -1 - step);
            build.solid(px1 - step - 1, py1 - 3, -4, px1 - step, py1, -1 - step);
        }
        build.solid(cx - 1, cy - 1, -4, cx + 2, cy + 2, -2);
        # The mezzanine along the north wall, offices on it, a stair up at
        # its near end.
        my = self.wide - 7;
        build.solid(2 + self.deck, my, self.deck - 1, self.long - 1, self.wide - 1, self.deck);
        stair(build, 2, self.wide - 4, 0, 0, self.deck, 3);
        for x in range(8 + self.deck, self.long - 4, 6) {
            build.solid(x, self.wide - 4, self.deck, x + 1, self.wide - 1, self.deck + 6);
        }
        # Walls across the floor either side of the pit, a gate over a sill
        # through each, so the pit's sides are rooms of their own.
        partition(build, hall, px0 - 1, 1, px0, self.wide - 4, 0, self.deck - 1, [[2, 5], [py1 + 1, py1 + 4]]);
        partition(build, hall, px1, 1, px1 + 1, self.wide - 1, 0, self.deck - 1, [[2, 5], [py1 + 1, py1 + 4]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The console that opens the gates out: in the pit, or on the back
        # wall of the farthest office.
        low_ports = [port for port in self.taken if port.floor == 0];
        if self.in_pit {
            press = build.push(float(cx - 1), float(cy) + 0.5, -3.0, 2);
        } else {
            press = build.push(float(self.long - 3) + 0.5, float(self.wide - 1), float(self.deck) + 1.5, 3);
        }
        for port in low_ports {
            press +>:Fires:+> shutter(build, self, port);
        }
        if low_ports {
            build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(my), 6.0, True, "This door is opened elsewhere");
        }
        auto_shutters(build, dice, self, [port for port in self.taken if port.floor != 0], 0.6);
        # Going down into the pit, guards appear in the offices.
        down = build.touch(float(px0), float(py0), -4.0, float(px0 + 4), float(py0 + 3), 2.0);
        guards(build, down, [[float(self.long) - 6.5, float(self.wide) - 5.5], [float(self.deck) + 11.5, float(self.wide) - 5.5]], self.deck, JAIL2_FOES.squad(dice, self.danger, 2, True), 270.0);
        build.foe(float(cx) + 3.5, float(cy) + 0.5, -4, JAIL2_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(px1) + 2.5, 2.5, 0, "monster_infantry", 0.0, patrol=[[float(px1) + 2.5, 2.5], [float(self.long) - 3.5, 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(px1) + 3.5, float(py0) + 1.5 + float(index) * 3.0, 0, JAIL2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(cx) + 0.5, float(py0) + 1.5, -4, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.5, self.deck, Q2_ARMOR, "q2");
        sparking(build, float(cx) + 2.2, float(cy) + 0.5, -3.0, 0, 3.5);
    }
}

"""The key room: an observation room over an interrogation cell, the key
on its console."""
node Observation(Prefab) {
    has key: str = "key_silver",
        upper: int = 7,
        by_lift: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Observation (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(22, 25);
        self.wide = dice.between(22, 24);
        self.upper = dice.between(6, 7);
        self.by_lift = dice.chance(0.5);
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
        middle = (self.wide + 4) // 2 - 1;
        u = self.upper;
        room = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, u);
        build.doorway(room, self.enter);
        # The observation room on a floor over the far end; under it the
        # interrogation cell behind bars; its front wall a window over the
        # hall, its door at the side.
        ox = self.long - 8;
        build.solid(ox, side + 1, u - 1, self.long - 1, self.wide - 1, u);
        build.solid(ox, side + 1, u, ox + 1, self.wide - 1, self.tall);
        build.widen(room, ox, self.wide - 4, u, ox + 1, self.wide - 1, u + 6);
        build.widen(room, ox, middle - 3, u + 2, ox + 1, middle + 3, u + 5);
        build.solid(ox, side + 1, 0, ox + 1, self.wide - 6, u - 1);
        cell_bars = bars(build, float(ox), float(self.wide - 6), 0.0, float(ox + 1), float(self.wide - 1), float(u - 1));
        if self.by_lift {
            post_button(build, ox - 5, self.wide - 6, 0, 1) +>:Fires:+> called_lift(build, ox - 4, self.wide - 4, ox - 1, self.wide - 1, 0, u);
            keep_row(build, room, ox, self.wide - 5, u, 0, 4);
        } else {
            stair(build, ox - u, self.wide - 4, 0, 0, u, 3);
        }
        # The console with the key; taking it opens the closets along the
        # near wall and the cell's bars, switches on lasers across the hall,
        # and the objective moves on.
        build.solid(self.long - 3, middle - 2, u, self.long - 2, middle + 2, u + 2);
        taken = key_cue(build, self.key, float(self.long) - 4.5, float(middle) + 0.5, u);
        closets(build, taken, [3, 8, 13] if dice.chance(0.5) else [4, 11], side, -1, 0, JAIL2_FOES.squad(dice, self.danger, 3, True), 90.0);
        taken +>:Fires:+> cell_bars;
        for x in [6.5, 12.5] {
            taken +>:Fires:+> laser(build, x, float(side) + 1.2, 2.0, 1, False);
        }
        taken +>:Fires:+> build.objective("Keycard taken. Get it to its door");
        build.foe(float(ox) + 3.5, float(self.wide) - 3.5, 0, JAIL2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 4.5, float(side) + 2.5, u, JAIL2_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, float(middle) + 3.5, 0, "monster_medic", 0.0, patrol=[[4.5, float(middle) + 3.5], [float(ox) - 6.5, float(middle) + 3.5]]);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(middle) + 3.5, float(u) + 3.0, 2, 5.0);
    }
}

"""The end: a door, a processing room barred by a great gate, the way out
beyond."""
node Processing(Prefab) {
    has key: str = "",
        balcony: int = 6,
        from_balcony: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Processing" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL2;
        self.district = level_district(JAIL2);
        self.long = dice.between(27, 30);
        self.wide = dice.between(18, 20);
        self.balcony = dice.between(6, 7);
        self.from_balcony = dice.chance(0.6);
        self.tall = self.balcony + 9;
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
        room = gate_pair(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, self.balcony);
        # The great gate across the room, eight cells wide in a wall to the
        # roof.
        gx = self.long - 7;
        build.solid(gx, 1, 0, gx + 1, self.wide - 1, self.tall);
        build.widen(room, gx, middle - 4, 0, gx + 1, middle + 4, 8);
        gate = build.opened(float(gx), float(middle - 4), 0.0, float(gx + 1), float(middle + 4), 8.0);
        # Its switch: on a balcony along the south wall up a stair, or on a
        # console by the wall.
        if self.from_balcony {
            build.solid(wall + 2 + self.balcony, 1, self.balcony - 1, gx, 4, self.balcony);
            stair(build, wall + 2, 1, 0, 0, self.balcony, 3);
            build.push(float(gx), 2.5, float(self.balcony) + 1.3, 2) +>:Fires:+> gate;
        } else {
            post_button(build, gx - 2, 2, 0, 2) +>:Fires:+> gate;
        }
        build.touch(float(gx - 3), float(middle - 4), 0.0, float(gx), float(middle + 4), 6.0, True, "The gate is worked from elsewhere");
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        # Benches.
        for x in [wall + 4, wall + 8] {
            build.solid(x, self.wide - 5, 0, x + 2, self.wide - 3, 2);
        }
        # Coming in, guards appear on the balcony (or before the gate);
        # raising the gate, charges go off beyond it.
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        if self.from_balcony {
            guards(build, come_in, [[float(gx) - 3.5, 2.5], [float(gx) - 7.5, 2.5]], self.balcony, JAIL2_FOES.squad(dice, self.danger, 2, True), 180.0);
        } else {
            guards(build, come_in, [[float(gx) - 3.5, float(middle) + 3.5]], 0, JAIL2_FOES.squad(dice, self.danger, 1, True), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, JAIL2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 3.5, 0, JAIL2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(wall) + 3.5, float(middle) + 0.5, 0, "monster_infantry", 0.0, patrol=[[float(wall) + 3.5, float(middle) + 0.5], [float(gx) - 2.5, float(middle) + 0.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(gx) - 0.2, float(middle) + 5.5, 3.0, 2, 4.0);
    }
}

"""jail2's stretches: [name, role]."""
glob JAIL2_STRETCHES: list[list[str]] = [
         ["reception", "start"],
         ["tiers", "flow"],
         ["drain", "hub"],
         ["drain", "flow"],
         ["lasers", "flow"],
         ["complex", "hub"],
         ["complex", "flow"],
         ["observation", "keyroom"],
         ["processing", "end"],
         ["processing", "gate"]
     ];

"""One of jail2's stretches by its name."""
def make_jail2(name: str, key: str) -> Prefab {
    if name == "reception" {
        return Reception();
    }
    if name == "tiers" {
        return CellTiers();
    }
    if name == "drain" {
        return DrainHall();
    }
    if name == "lasers" {
        return LaserControl();
    }
    if name == "complex" {
        return SecurityComplex();
    }
    if name == "observation" {
        return Observation(key=key if key else "key_silver");
    }
    return Processing(key=key);
}
