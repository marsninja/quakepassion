"""Prefabs drawn from Quake II's city2, the Lower Palace: a palace of door
after door, its force fields brought down from lever rooms, laser fences
blinking across its galleries, colonnades of bays where berserkers are
let loose, the throne hall where the tank commander waits, the treasury of
the data CD, and the chamber of the communication laser. Raised in
city2's own palette.

- `PalaceSteps`: the start. A court, broad steps up to the gate's double
  doors, a vestibule beyond under a gallery up steps a button raises;
  panels spark at random; a wall in the vestibule that opens when shot
  (a secret); "Obtain the data CD. Shut down
  the communication laser".
- `RedField`: a hall cut by the red force field, a gallery over its near
  end; its lever in a side room through double doors (or up on the
  gallery), a laser fence blinking
  across the way to it; the field down, the sparks stop and the guards
  behind it come on.
- `Colonnade`: a long hall, bays between its columns on both sides under
  galleries; walking down it lets the berserkers out of the bays, and
  their deaths count down to the far doors opening.
- `ThroneHall`: the throne on a dais under balconies on three walls up
  stairs (a button on the throne's back calls the guard), double doors on every side; climbing to the throne brings in
  the tank commander; a panel on the far balcony breaks on a stash. A hub.
- `YellowGate`: a gallery over a hall and a mezzanine across its end, the way on through a door
  "opened elsewhere": its lever at the gallery's far end behind a laser
  fence; pressing it opens the door and the lasers go dark.
- `Treasury`: the data CD (the key) on a pedestal in the treasury behind
  double doors, steps up to it a button raises; taking it opens the
  closets and the guards come in.
- `CommLaser`: the end. A door (a key's, as a gate), the chamber where the
  communication laser beams across, its lever on the gallery; shut down,
  the charges go off and the way out opens."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, pillars }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, rounds, beamed, held_door, key_taken, closets, barrels }

glob CITY2: str = "q2:city2";

"""city2's foes: elite guards, berserkers and floaters, brains and a tank
commander deeper in."""
glob CITY2_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_berserk", "monster_floater"], strong=["monster_brain"], heavy_light=["monster_berserk", "monster_brain"], heavy_strong=["monster_tank_commander"], scale=0.5, heavy_scale=0.3);

"""The palace's double doors in a wall a cell thick: across x (the wall
the cell line x0, its opening y0..y0+4) or across y (the wall at y0, the
opening x0..x0+4), on lift `z`: two halves, each opening when touched,
in air carved for them in `space`."""
def double_doors(build: Raising, space: Space, x0: int, y0: int, z: int, across_x: bool) {
    if across_x {
        build.widen(space, x0, y0, z, x0 + 1, y0 + 4, z + 7);
        build.rising_door(float(x0), float(y0), float(z), float(x0 + 1), float(y0 + 2), float(z + 7), {"wait": "4"});
        build.rising_door(float(x0), float(y0 + 2), float(z), float(x0 + 1), float(y0 + 4), float(z + 7), {"wait": "4"});
    } else {
        build.widen(space, x0, y0, z, x0 + 4, y0 + 1, z + 7);
        build.rising_door(float(x0), float(y0), float(z), float(x0 + 2), float(y0 + 1), float(z + 7), {"wait": "4"});
        build.rising_door(float(x0 + 2), float(y0), float(z), float(x0 + 4), float(y0 + 1), float(z + 7), {"wait": "4"});
    }
}

"""A laser fence: two beams from the cell point (x, y) out the way
`direction` goes (0 +x ... 3 -y), a lift and two and a half lifts over
lift `z`, burning while on, blinking on and off every `seconds` (a timer
toggling them). Answers the beams' cue, to lever them off for good."""
def laser_fence(build: Raising, x: float, y: float, z: int, direction: int, seconds: float) -> Cue {
    beams: list[dict[str, str]] = [];
    for lift_at in [1.0, 2.5] {
        fields = {"classname": "target_laser", "angle": str(build.facing(direction)), "dmg": "5", "spawnflags": "1"};
        build.put_point(fields, x, y, float(z) + lift_at, "q2");
        beams.append(fields);
    }
    fence = build.cue(beams, "fence");
    build.timer(seconds) +>:Fires:+> fence;
    return fence;
}

"""Panels that spark at random: one timer each at the points `at` ([x, y,
z, direction] each), every `seconds` or so."""
def random_sparks(build: Raising, at: list[list[float]], seconds: float) {
    for (index, point) in enumerate(at) {
        sparking(build, point[0], point[1], point[2], int(point[3]), seconds + float(index) * 0.7);
    }
}

"""The start: a court, broad steps up to the gate's double doors, a
vestibule under a gallery beyond."""
node PalaceSteps(Prefab) {
    has gate_x: int = 16,
        terrace: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace steps";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.terrace = dice.between(3, 4);
        self.gate_x = dice.between(15, 17);
        self.tall = 18;
        self.low = -9;
        self.high = 22;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=self.terrace),
            Port(face=1, along=float(self.long - 5), floor=self.terrace),
            Port(face=3, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        te = self.terrace;
        gx = self.gate_x;
        court = build.room(1, 1, 0, gx, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        hall = build.room(gx + 1, 1, te, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(court, te);
        # The broad steps up to the terrace before the gate.
        build.solid(gx - 4, 1, 0, gx, self.wide - 1, te);
        stair(build, gx - 4 - te, middle - 4, 0, 0, te, 8);
        keep_box(build, court, gx - 4, middle - 4, gx - 3, middle + 4, te);
        double_doors(build, hall, gx, middle - 2, te, True);
        # The vestibule's gallery over its floor along the far wall, up a
        # stair; a wall in the court that opens when shot.
        deck(build, gx + 8, 1, self.long - 1, 7, te + 7);
        raised = build.rising_steps(gx + 1, 1, te, 0, 7, 3);
        build.push(float(gx + 1), 4.5, float(te) + 1.5, 0) +>:Fires:+> raised;
        build.touch(float(gx + 1), 4.0, float(te), float(gx + 3), 7.0, float(te + 6), True, "The gallery's steps are raised from the wall");
        keep_box(build, hall, gx + 8, 1, gx + 9, 4, te + 7);
        hidden_closet(build, gx + 3, middle + 2, te, 1, Q2_ARMOR, 6) +>:Fires:+> build.sparks(float(gx) + 5.0, float(middle) + 6.2, float(te) + 3.0, 1);
        build.doorway(court, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                build.doorway(court, port);
            } else {
                build.doorway(hall, port);
            }
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Obtain the data CD. Shut down the communication laser");
        # Guards come out onto the terrace as the player climbs the steps, and
        # into the vestibule as the gate opens; one walks the court.
        steps = build.touch(float(gx - 4 - te), float(middle - 4), 0.0, float(gx - 4), float(middle + 4), 6.0);
        squad(build, steps, [[float(gx) - 2.0, 3.0, float(te)], [float(gx) - 2.0, float(self.wide) - 3.0, float(te)]], ["monster_soldier_ss", CITY2_FOES.pick(dice, self.danger)], 180.0);
        inside = build.touch(float(gx + 1), float(middle - 2), float(te), float(gx + 3), float(middle + 2), float(te + 6));
        build.touch(float(self.long - 4), float(middle - 2), float(te), float(self.long - 2), float(middle + 2), float(te + 6), True, "The lower palace");
        squad(build, inside, [[float(self.long) - 4.5, float(self.wide) - 3.5, float(te)], [float(self.long) - 4.5, 3.0, float(te + 7)]], [CITY2_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        beamed(build, inside, 2, 2, -8, CITY2_FOES.pick(dice, self.danger), float(gx) + 6.5, float(middle) - 3.0, te, 180.0);
        rounds(build, "monster_soldier_ss", [[3.5, 3.5], [float(gx) - 6.5, 3.5], [float(gx) - 6.5, float(self.wide) - 3.5], [3.5, float(self.wide) - 3.5]], 0);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [1.2, 3.0, 4.0, 0.0], [1.2, float(self.wide) - 3.0, 4.0, 0.0], [float(gx) + 1.2, 3.5, float(te) + 3.0, 0.0], [float(self.long) - 1.2, float(middle), float(te) + 2.0, 2.0], [float(gx) - 0.2, float(self.wide) - 3.0, float(te) + 4.0, 2.0], [float(self.long) - 1.2, 3.0, float(te) + 9.0, 2.0]], 3.0);
        barrels(build, dice, 1, 1, gx - 4, self.wide - 1, 0, 2, [[0, middle - 3, 4, middle + 3], [5, 0, 11, 3], [gx - 10, middle - 5, gx, middle + 5]]);
        build.touch(float(gx - 4), float(middle - 4), float(te), float(gx), float(middle + 4), float(te + 6), True, "The palace gate");
        upstairs = build.touch(float(gx + 7), 1.0, float(te + 7), float(gx + 9), 5.0, float(te + 13));
        squad(build, upstairs, [[float(self.long) - 3.0, 3.0, float(te + 7)]], [CITY2_FOES.pick(dice, self.danger, True)], 180.0);
        build.supply(float(gx) + 3.0, float(self.wide) - 3.0, te, Q2_HEALTH, "q2");
    }
}

"""A hall cut by the red force field; its lever in a side room through
double doors, a laser fence across the way to it."""
node RedField(Prefab) {
    has field_x: int = 14,
        upstairs: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Red field";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.field_x = dice.between(13, 15);
        self.upstairs = dice.chance(0.45);
        self.tall = 16;
        self.low = -9;
        self.high = 22;
        self.enter = Port(face=2, along=float(self.wide // 2 - 3), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2 - 3), floor=0),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        fx = self.field_x;
        side = self.wide - 7;
        mid = side // 2 + 1;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        # The red force field across the hall.
        build.solid(fx, 1, 0, fx + 1, side, self.tall);
        build.widen(hall, fx, mid - 3, 0, fx + 1, mid + 3, 8);
        field = build.opened(float(fx), float(mid - 3), 0.0, float(fx + 1), float(mid + 3), 8.0);
        build.touch(float(fx - 2), float(mid - 3), 0.0, float(fx), float(mid + 3), 6.0, False, "The force field is switched off from the side room");
        # The lever room beyond the near wall through double doors, or up on
        # a gallery over the hall's near end.
        build.level(hall, 9);
        deck(build, 2, side - 4, fx, side, 9);
        stair(build, fx - 10, side - 7, 0, 0, 9, 3);
        keep_box(build, hall, fx - 3, side - 4, fx - 1, side - 3, 9);
        up_there = build.touch(float(fx - 3), float(side - 4), 9.0, float(fx - 1), float(side), 15.0);
        squad(build, up_there, [[3.5, float(side) - 2.0, 9.0]], [CITY2_FOES.pick(dice, self.danger)], 0.0);
        if self.upstairs {
            lever = build.push(1.0, float(side) - 2.0, 10.5, 0);
            fence = laser_fence(build, 6.5, float(side) - 0.1, 9, 3, 2.0);
        } else {
            room = build.room(3, side + 1, 0, fx - 1, self.wide - 1, 8, variant=dice.below(3));
            double_doors(build, room, 4, side, 0, False);
            lever = build.push(float(fx - 1), float(self.wide) - 3.5, 1.5, 2);
            fence = laser_fence(build, 9.0, float(self.wide) - 1.1, 0, 3, 2.0);
        }
        # The field down: the sparks stop, the guards behind it come on.
        lever +>:Fires:+> field;
        lever +>:Fires:+> fence;
        lever +>:Fires:+> build.objective("Red force field down", False);
        blast_chain(build, lever, [[float(fx) + 0.5, float(mid) - 2.0, 2.0], [float(fx) + 0.5, float(mid) + 2.0, 5.0]], 0.25);
        late = build.delay(2.0);
        lever +>:Fires:+> late;
        squad(build, late, [[float(fx) + 4.5, float(mid) - 2.0, 0.0], [float(fx) + 4.5, float(mid) + 2.0, 0.0], [float(self.long) - 3.5, 3.5, 0.0]], [CITY2_FOES.pick(dice, self.danger), "monster_soldier_ss", CITY2_FOES.pick(dice, self.danger, True)], 180.0);
        beamed(build, late, 2, 2, -8, CITY2_FOES.pick(dice, self.danger), float(fx) + 7.5, float(side) - 2.5, 0, 180.0);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [1.2, 3.0, 3.0, 0.0], [float(self.long) - 1.2, float(side) - 3.0, 4.0, 2.0], [float(fx) - 0.2, float(mid) - 4.0, 3.0, 2.0], [float(fx) + 1.2, float(mid) + 4.0, 4.0, 0.0], [float(fx) - 0.2, float(mid) + 4.0, 6.0, 2.0], [float(self.long) - 1.2, 3.0, 3.0, 2.0]], 1.5);
        barrels(build, dice, fx + 2, 2, self.long - 2, side - 1, 0, 2, [[self.long - 7, self.wide // 2 - 6, self.long, self.wide // 2 + 1], [self.long - 8, 0, self.long - 2, 3], [fx + 2, side - 6, fx + 8, side], [fx, mid - 4, fx + 4, mid + 4]]);
        near_lever = build.touch(float(fx - 5), float(side - 3), 0.0, float(fx - 2), float(side), 6.0);
        squad(build, near_lever, [[3.5, 3.5, 0.0]], ["monster_floater"], 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(side), 6.0);
        squad(build, come_in, [[float(fx) - 3.5, 3.5, 0.0], [5.5, float(side) - 2.5, 0.0]], ["monster_soldier_ss", CITY2_FOES.pick(dice, self.danger)], 0.0);
        rounds(build, "monster_berserk", [[float(fx) + 3.5, 3.0], [float(self.long) - 3.5, 3.0], [float(self.long) - 3.5, float(side) - 3.0]], 0);
        stash(build, fx + 3, side - 5, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.explosion(float(fx) + 5.0, float(side) - 6.0, 1.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A long hall, bays between its columns under galleries; the berserkers
let out of the bays, their deaths count down to the far doors."""
node Colonnade(Prefab) {
    has gal: int = 7,
        bays: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Colonnade";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(28, 31);
        self.wide = dice.between(20, 22);
        self.gal = dice.between(7, 9);
        self.bays = dice.between(2, 3);
        self.tall = self.gal + 16;
        self.low = -9;
        self.high = 22;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gal),
            Port(face=3, along=float(self.long // 2 - 4), floor=self.gal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gal;
        hall = build.room(1, 1, 0, self.long - 4, self.wide - 1, self.tall, variant=dice.below(3));
        far = build.room(self.long - 3, middle - 3, 0, self.long - 1, middle + 3, 9);
        build.level(hall, g);
        # The galleries over the bays on both sides, the stairs up at the near
        # end; the columns along the floor.
        deck(build, 1 + g, 1, self.long - 4, 5, g);
        deck(build, 1 + g, self.wide - 5, self.long - 4, self.wide - 1, g);
        stair(build, 1, 1, 0, 0, g, 3);
        stair(build, 1, self.wide - 4, 0, 0, g, 3);
        keep_box(build, hall, 1 + g, 1, 2 + g, 4, g);
        keep_box(build, hall, 1 + g, self.wide - 4, 2 + g, self.wide - 1, g);
        # The upper gallery over the near one, up a stair from its far end.
        build.level(hall, g + 7);
        deck(build, 1 + g, 1, self.long - 11, 4, g + 7);
        stair(build, self.long - 5, 1, g, 2, 7, 3);
        keep_box(build, hall, self.long - 12, 1, self.long - 11, 4, g + 7);
        build.touch(float(self.long - 14), 1.0, float(g + 7), float(self.long - 12), 4.0, float(g + 13), True, "The upper gallery looks down on the bays");
        sparking(build, float(1 + g) + 0.5, 1.2, float(g) + 9.0, 1, 5.5);
        pillars(build, 8, 5, self.long - 5, 6, 0, g - 1, 4, []);
        pillars(build, 8, self.wide - 6, self.long - 5, self.wide - 5, 0, g - 1, 4, []);
        # The bays under the galleries, their foes let out as the player walks
        # down the hall; their deaths open the far doors.
        brutes = build.waiting();
        count = build.tally(self.bays * 2, "The far doors open");
        brutes +>:Fires:+> count;
        for index in range(self.bays) {
            bx = 9 + index * 6;
            build.foe(float(bx) + 1.5, 2.5, 0, "monster_berserk", 90.0, waits=brutes);
            build.foe(float(bx) + 1.5, float(self.wide) - 2.5, 0, CITY2_FOES.pick(dice, self.danger), 270.0, waits=brutes);
        }
        walk = build.touch(8.0, float(middle - 3), 0.0, 10.0, float(middle + 3), 6.0);
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "The colonnade of the lower palace");
        walk +>:Fires:+> brutes;
        later = build.delay(1.0);
        walk +>:Fires:+> later;
        later +>:Fires:+> build.sparks(float(self.long) - 4.2, float(middle), 4.0, 2);
        build.widen(far, self.long - 4, middle - 3, 0, self.long - 3, middle + 3, 8);
        gate = build.opened(float(self.long - 4), float(middle - 3), 0.0, float(self.long - 3), float(middle + 3), 8.0);
        count +>:Fires:+> gate;
        # A lever on the upper gallery opens the far doors too.
        build.push(float(2 + g), 1.0, float(g + 7) + 1.5, 1) +>:Fires:+> gate;
        build.touch(float(self.long - 7), float(middle - 3), 0.0, float(self.long - 5), float(middle + 3), 6.0, False, "This door is opened elsewhere");
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                build.doorway(far, port);
            } else {
                build.doorway(hall, port);
            }
        }
        on_gallery = build.touch(float(1 + g), 1.0, float(g), float(3 + g), 5.0, float(g + 6));
        squad(build, on_gallery, [[float(self.long) - 6.5, 3.0, float(g)], [float(self.long) - 6.5, float(self.wide) - 3.0, float(g)]], ["monster_soldier_ss", "monster_floater"], 180.0);
        beamed(build, on_gallery, 2, middle - 2, -8, CITY2_FOES.pick(dice, self.danger, True), float(self.long // 2) + 0.5, float(middle) + 0.5, 0, 180.0);
        rounds(build, "monster_soldier_ss", [[8.0, float(middle)], [float(self.long) - 6.0, float(middle)]], 0);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [1.2, 6.0, float(g) + 3.0, 0.0], [1.2, float(middle) - 3.0, 3.0, 0.0], [float(self.long) - 4.2, 3.0, float(g) + 2.0, 2.0], [float(self.long) - 4.2, float(self.wide) - 3.0, float(g) + 2.0, 2.0], [1.2, float(middle) + 3.0, 4.0, 0.0]], 4.0);
        far_end = build.touch(float(self.long - 10), float(middle - 3), 0.0, float(self.long - 8), float(middle + 3), 6.0, True, "The far doors are held while the guards live");
        squad(build, far_end, [[float(self.long) - 6.5, float(middle) - 3.5, 0.0]], [CITY2_FOES.pick(dice, self.danger, True)], 180.0);
        for index in range(2) {
            bx = 11 + index * 8;
            build.breakable(float(bx), 6.0, 0.0, float(bx + 1), 7.0, 2.0, 10);
            build.breakable(float(bx), float(self.wide - 7), 0.0, float(bx + 1), float(self.wide - 6), 2.0, 10);
        }
        build.supply(2.5, float(middle) - 4.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 6.5, 3.0, g, "ammo_shells", "q2");
    }
}

"""The throne on a dais under balconies on three walls, double doors on
every side; the tank commander comes in."""
node ThroneHall(Prefab) {
    has bal: int = 7,
        dais: int = 2,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Throne hall";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.bal = dice.between(8, 9);
        self.dais = dice.between(2, 3);
        self.tall = 18;
        self.low = -9;
        self.high = 22;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2 + 1), floor=0),
            Port(face=3, along=float(self.long // 2 + 1), floor=0),
            Port(face=1, along=float(self.long - 6), floor=self.bal),
            Port(face=3, along=float(self.long - 6), floor=self.bal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        b = self.bal;
        hall = build.room(4, 4, 0, self.long - 1, self.wide - 4, self.tall, variant=dice.below(3));
        build.level(hall, b);
        # Vestibules on three sides through double doors.
        west = build.room(1, middle - 3, 0, 3, middle + 3, 9);
        north = build.room(self.long // 2 - 2, self.wide - 3, 0, self.long // 2 + 4, self.wide - 1, 9);
        south = build.room(self.long // 2 - 2, 1, 0, self.long // 2 + 4, 3, 9);
        double_doors(build, hall, 3, middle - 2, 0, True);
        double_doors(build, hall, self.long // 2 - 1, self.wide - 4, 0, False);
        double_doors(build, hall, self.long // 2 - 1, 3, 0, False);
        for (index, spot) in enumerate([[2.0, float(middle) - 3.0, 2.0, float(middle) + 3.0], [float(self.long // 2 - 2), float(self.wide - 3), float(self.long // 2 + 4), float(self.wide - 1)], [float(self.long // 2 - 2), 1.0, float(self.long // 2 + 4), 3.0]]) {
            by_door = build.touch(spot[0], spot[1], 0.0, spot[2], spot[3], 6.0);
            squad(build, by_door, [[float(self.long // 2) + 1.0, float(middle) + (4.5 if index == 1 else -4.5), 0.0]], [CITY2_FOES.pick(dice, self.danger)], 90.0);
        }
        # The balconies on three walls, stairs up at the near corners.
        deck(build, 4 + b, 4, self.long - 1, 9, b);
        deck(build, 4 + b, self.wide - 9, self.long - 1, self.wide - 4, b);
        deck(build, self.long - 6, 9, self.long - 1, self.wide - 9, b);
        stair(build, 4, 4, 0, 0, b, 3);
        stair(build, 4, self.wide - 7, 0, 0, b, 3);
        keep_box(build, hall, 4 + b, 4, 5 + b, 7, b);
        keep_box(build, hall, 4 + b, self.wide - 7, 5 + b, self.wide - 4, b);
        build.widen(hall, self.long - 8, 1, b, self.long - 4, 4, b + 8);

        build.widen(hall, self.long - 8, self.wide - 4, b, self.long - 4, self.wide - 1, b + 8);
        # The dais and the throne at the far end; a stash in the far balcony
        # behind a panel that breaks when shot.
        dx = self.long - 12;
        build.solid(dx, middle - 4, 0, self.long - 5, middle + 4, self.dais);
        build.solid(self.long - 7, middle - 3, self.dais, self.long - 6, middle - 1, self.dais + 4);
        # A button on the throne's back brings the palace guard down.
        summons = build.push(float(self.long) - 6.5, float(middle - 1), float(self.dais) + 1.5, 1);
        squad(build, summons, [[float(dx) - 2.0, float(middle) - 6.0, 0.0], [float(dx) - 2.0, float(middle) + 6.0, 0.0]], ["monster_soldier_ss", CITY2_FOES.pick(dice, self.danger)], 180.0);
        summons +>:Fires:+> build.explosion(float(self.long) - 6.5, float(middle) + 1.0, float(self.dais) + 2.0);
        stash(build, self.long - 5, middle - 2, b, 1, "item_quad", 6) +>:Fires:+> build.sparks(float(self.long) - 3.0, float(middle) + 2.2, float(b) + 3.0, 1);
        build.doorway(west, self.enter);
        for port in self.taken {
            if port.floor == b {
                build.doorway(hall, port);
            } elif port.face == 1 {
                build.doorway(north, port);
            } else {
                build.doorway(south, port);
            }
        }
        # Climbing to the throne brings in the tank commander and his guard.
        climb = build.touch(float(dx), float(middle - 4), float(self.dais), float(dx + 2), float(middle + 4), float(self.dais + 6));
        heavy = ["monster_tank_commander"] if self.danger > 0.5 else ["monster_gladiator"];
        squad(build, climb, [[float(dx) - 5.0, float(middle), 0.0]], heavy, 0.0);
        squad(build, climb, [[float(self.long) - 3.0, 6.0, float(b)], [float(self.long) - 3.0, float(self.wide) - 6.0, float(b)]], ["monster_soldier_ss", CITY2_FOES.pick(dice, self.danger)], 180.0);
        beamed(build, climb, self.long - 5, 1, -8, CITY2_FOES.pick(dice, self.danger, True), float(dx) - 2.5, float(middle) + 5.5, 0, 0.0);
        blast_chain(build, climb, [[float(dx) - 1.0, float(middle) - 5.0, 1.0], [float(dx) - 1.0, float(middle) + 5.0, 1.0]], 0.4);
        come_in = build.touch(4.0, float(middle - 3), 0.0, 7.0, float(middle + 3), 6.0);
        squad(build, come_in, [[14.5, 6.0, float(b)], [14.5, float(self.wide) - 6.0, float(b)]], [CITY2_FOES.pick(dice, self.danger), "monster_floater"], 270.0);
        rounds(build, CITY2_FOES.pick(dice, self.danger), [[10.0, float(middle) - 3.0], [float(dx) - 2.0, float(middle) - 3.0], [float(dx) - 2.0, float(middle) + 3.0], [10.0, float(middle) + 3.0]], 0);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [4.2, float(middle) + 5.0, 3.0, 0.0], [4.2, 6.0, 3.0, 0.0], [float(self.long) - 1.2, 6.0, float(b) + 2.0, 2.0], [float(self.long) - 1.2, float(self.wide) - 6.0, float(b) + 2.0, 2.0], [4.2, float(self.wide) - 6.0, 3.0, 0.0], [float(dx) - 0.2, float(middle) + 3.0, 1.0, 2.0]], 3.5);
        barrels(build, dice, 12, 9, self.long // 2 + 6, self.wide - 9, 0, 2, [[0, middle - 4, 9, middle + 4], [self.long // 2 - 3, 0, self.long // 2 + 5, 6], [self.long // 2 - 3, self.wide - 6, self.long // 2 + 5, self.wide], [self.long - 13, middle - 5, self.long, middle + 5]]);
        build.supply(6.0, 6.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(middle) + 4.0, b, "ammo_rockets", "q2");
    }
}

"""A gallery over a hall, the way on through a door opened elsewhere: its
lever at the gallery's far end behind a laser fence."""
node YellowGate(Prefab) {
    has gal: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Yellow gate";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.gal = 9;
        self.tall = 18;
        self.low = -9;
        self.high = 22;
        middle = float(self.wide // 2 + 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2 + 2;
        g = self.gal;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery along the near wall, up a stair; the lever at its far
        # end behind a laser fence.
        deck(build, 4 + g, 1, self.long - 1, 7, g);
        # A mezzanine across the hall's far end, joined to the gallery.
        deck(build, self.long - 8, 7, self.long - 1, self.wide - 1, g);
        keep_box(build, hall, self.long - 9, 7, self.long - 8, self.wide - 1, g);
        stair(build, 4, 1, 0, 0, g, 3);
        keep_box(build, hall, 4 + g, 1, 5 + g, 4, g);
        fence = laser_fence(build, float(self.long - 7) + 0.5, 1.1, g, 1, 2.5);
        lever = build.push(float(self.long - 1), 3.5, float(g) + 1.5, 2);
        lever +>:Fires:+> fence;
        lever +>:Fires:+> build.objective("Yellow gate open", False);
        build.touch(float(self.long - 10), 1.0, float(g), float(self.long - 8), 6.0, float(g + 6), True, "Lasers guard the gate's lever");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            held_door(build, self, port, lever);
        }
        # Guards come out on the gallery as the player climbs; the floor's
        # berserkers come on as the lever is pressed.
        climb = build.touch(4.0, 1.0, 1.0, float(4 + g), 4.0, 7.0);
        come_in = build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0);
        squad(build, come_in, [[float(self.long) - 6.5, float(middle) + 2.0, 0.0]], [CITY2_FOES.pick(dice, self.danger)], 180.0);
        squad(build, climb, [[float(self.long) - 4.5, 3.0, float(g)], [float(self.long // 2), 4.0, float(g)]], [CITY2_FOES.pick(dice, self.danger), "monster_soldier_ss"], 180.0);
        squad(build, lever, [[float(self.long) - 4.5, float(self.wide) - 3.0, 0.0], [8.5, float(self.wide) - 3.0, 0.0]], ["monster_berserk", CITY2_FOES.pick(dice, self.danger, True)], 180.0);
        beamed(build, lever, 2, self.wide - 6, -8, CITY2_FOES.pick(dice, self.danger), float(self.long // 2) + 0.5, float(middle) + 0.5, 0, 90.0);
        rounds(build, "monster_soldier_ss", [[3.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]], 0);
        stash(build, self.long - 7, self.wide - 6, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.sparks(float(self.long) - 5.0, float(self.wide) - 6.2, 2.0, 3);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [1.2, 3.0, 3.0, 0.0], [float(self.long) - 1.2, 3.0, float(g) + 3.0, 2.0], [1.2, float(middle) + 3.0, 3.0, 0.0], [float(self.long) - 1.2, float(self.wide) - 8.0, 3.0, 2.0]], 2.5);
        barrels(build, dice, 4, 8, self.long - 4, self.wide - 3, 0, 2, [[0, middle - 3, 4, middle + 3], [self.long - 4, middle - 3, self.long, middle + 3], [self.long // 2 - 3, self.wide - 3, self.long // 2 + 3, self.wide], [self.long - 8, self.wide - 7, self.long - 2, self.wide], [4, 1, 5 + g, 8]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The data CD on a pedestal in the treasury behind double doors, steps up
to it a button raises; taking it opens the closets."""
node Treasury(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        level: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Treasury (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.level = dice.between(4, 6);
        self.tall = 17;
        self.low = -9;
        self.high = 18;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        ante = build.room(1, 1, 0, 8, side, 10, variant=dice.below(3));
        vault = build.room(9, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, self.level);
        build.doorway(ante, self.enter);
        double_doors(build, vault, 8, cy - 2, 0, True);
        # A gallery along the vault's near wall up a stair.
        build.level(vault, 9);
        deck(build, 18, 1, self.long - 1, 4, 9);
        stair(build, 9, 1, 0, 0, 9, 3);
        keep_box(build, vault, 18, 1, 19, 4, 9);
        build.foe(float(self.long) - 3.0, 2.5, 9, CITY2_FOES.pick(dice, self.danger), 180.0);
        # The pedestal, the steps up to it a button on the wall raises.
        px = self.long - 7;
        build.solid(px, cy - 2, 0, px + 4, cy + 2, self.level);
        steps = build.rising_steps(px - self.level, cy - 1, 0, 0, self.level, 3);
        keep_box(build, vault, px, cy - 1, px + 1, cy + 2, self.level);
        raised = build.push(float(px) - 2.0, float(side), 1.5, 3);
        raised +>:Fires:+> steps;
        build.touch(9.0, float(cy - 2), 0.0, 11.0, float(cy + 2), 6.0, True, "The steps to the pedestal are raised from the wall");
        taken = key_taken(build, self.key, float(px) + 2.0, float(cy), self.level);
        taken +>:Fires:+> build.objective("Data CD obtained", False);
        build.touch(float(px - 3), 1.0, 0.0, float(px - 1), float(side), 6.0, True, "The data CD lies on the pedestal");
        closets(build, taken, side, 0, [10, self.long - 5], [CITY2_FOES.pick(dice, self.danger, True), CITY2_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[4.5, 3.0, 0.0], [4.5, float(side) - 3.0, 0.0]], ["monster_soldier_ss", "monster_floater"], 0.0);
        beamed(build, taken, 2, 2, -8, CITY2_FOES.pick(dice, self.danger, True), 12.5, float(cy) + 0.5, 0, 0.0);
        taken +>:Fires:+> build.explosion(float(px) + 2.0, float(cy) - 4.0, 1.0);
        hidden_closet(build, 2, 1, 0, 1, "ammo_cells", 6);
        build.foe(float(self.long) - 3.5, 3.5, 0, CITY2_FOES.pick(dice, self.danger), 180.0);
        rounds(build, "monster_soldier_ss", [[11.5, 2.5], [float(self.long) - 3.5, 2.5]], 0);
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [1.2, 3.0, 3.0, 0.0], [float(self.long) - 1.2, 3.0, 4.0, 2.0], [float(self.long) - 1.2, float(cy), 3.0, 2.0], [9.2, 3.0, 4.0, 0.0], [7.8, float(side) - 3.0, 3.0, 2.0]], 3.0);
        barrels(build, dice, 2, 6, 7, side - 1, 0, 1, [[0, cy - 3, 4, cy + 3], [6, cy - 3, 9, cy + 3], [1, 0, 7, 6]]);
        build.supply(6.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into the chamber of the communication laser, its lever
on the gallery; shut down, the way out opens."""
node CommLaser(Prefab) {
    has key: str = "",
        gal: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Comm laser" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY2;
        self.district = level_district(CITY2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.gal = 11;
        self.tall = 22;
        self.low = -1;
        self.high = 22;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        g = self.gal;
        chamber = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(chamber, g);
        # The laser's emitter and the beam across the chamber high up.
        build.solid(self.long - 4, middle - 2, 0, self.long - 1, middle + 2, self.tall);
        beam = build.cue([{"classname": "target_laser", "angle": str(build.facing(2)), "dmg": "20", "spawnflags": "1"}], "beam");
        build.put_point(beam.items[0], float(self.long) - 4.1, float(middle), float(g) + 5.0, "q2");
        # The gallery along the near wall, up a stair, the lever at its end.
        deck(build, wall + 1 + g, 1, self.long - 1, 6, g);
        stair(build, wall + 1, 1, 0, 0, g, 3);
        keep_box(build, chamber, wall + 1 + g, 1, wall + 2 + g, 4, g);
        off = build.push(float(self.long - 1), 3.0, float(g) + 1.5, 2);
        # A bridge from the gallery out across the chamber.
        deck(build, self.long - 15, 6, self.long - 12, self.wide - 1, g);
        keep_box(build, chamber, self.long - 15, 5, self.long - 12, 6, g);
        off +>:Fires:+> beam;
        off +>:Fires:+> build.objective("Communication laser shut down");
        blast_chain(build, off, [[float(self.long) - 5.0, float(middle) - 3.0, 3.0], [float(self.long) - 5.0, float(middle) + 3.0, 6.0], [float(self.long) - 5.0, float(middle), 10.0]], 0.3);
        # The way out in an alcove behind a door the lever opens.
        ex = self.long - 9;
        build.solid(ex, self.wide - 6, 0, self.long - 4, self.wide - 1, self.tall);
        alcove = build.room(ex + 1, self.wide - 5, 0, self.long - 4, self.wide - 1, 8);
        build.widen(alcove, ex + 1, self.wide - 6, 0, ex + 4, self.wide - 5, 7);
        out = build.delay(2.0);
        off +>:Fires:+> out;
        out +>:Fires:+> build.opened(float(ex + 1), float(self.wide - 6), 0.0, float(ex + 4), float(self.wide - 5), 7.0);
        build.way_out(float(ex) + 2.5, float(self.wide) - 3.0, 0);
        # A store beside the emitter, its shutter opening as the laser dies.
        build.solid(self.long - 4, 1, 0, self.long - 1, middle - 2, 8);
        store = build.room(self.long - 3, 2, 0, self.long - 1, middle - 3, 5);
        build.widen(store, self.long - 4, 3, 0, self.long - 3, middle - 4, 5);
        out +>:Fires:+> build.opened(float(self.long - 4), 3.0, 0.0, float(self.long - 3), float(middle - 4), 5.0);
        build.supply(float(self.long) - 2.0, 4.0, 0, Q2_ARMOR, "q2");
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0, True, "The communication laser");
        squad(build, come_in, [[float(self.long) - 6.0, 3.0, float(g)], [float(ex) - 3.0, float(self.wide) - 3.0, 0.0]], [CITY2_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        top = build.touch(float(wall + g), 1.0, float(g), float(wall + g + 2), 5.0, float(g + 6));
        squad(build, top, [[float(self.long) - 3.0, 3.0, float(g)]], ["monster_floater"], 180.0);
        squad(build, off, [[float(wall) + 6.0, float(middle), 0.0], [float(ex) - 2.0, float(middle) - 2.0, 0.0]], ["monster_berserk", CITY2_FOES.pick(dice, self.danger)], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, CITY2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        random_sparks(build, [[float(self.long // 2) + 0.5, 1.2, 5.0, 1.0], [float(self.long // 2) - 2.5, 1.2, 3.0, 1.0], [float(wall) + 1.2, 3.0, 3.0, 0.0], [float(self.long) - 4.2, float(middle) - 1.0, 4.0, 2.0], [float(self.long) - 4.2, float(middle) + 1.0, 8.0, 2.0], [float(wall) + 1.2, float(self.wide) - 3.0, 3.0, 0.0]], 1.5);
        barrels(build, dice, wall + 4, 7, ex - 2, self.wide - 2, 0, 2, [[wall, middle - 3, wall + 4, middle + 3], [ex - 1, self.wide - 7, ex + 5, self.wide], [self.long - 6, middle - 3, self.long, middle + 3]]);
        build.touch(float(self.long - 7), float(middle - 3), 0.0, float(self.long - 5), float(middle + 3), 6.0, True, "The laser is shut down from the gallery");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_cells", "q2");
    }
}

"""city2's stretches: [name, role]."""
glob CITY2_STRETCHES: list[list[str]] = [
         ["steps", "start"],
         ["redfield", "flow"],
         ["colonnade", "flow"],
         ["yellow", "flow"],
         ["throne", "hub"],
         ["treasury", "keyroom"],
         ["laser", "end"],
         ["laser", "gate"]
     ];

"""One of city2's stretches by its name."""
def make_city2(name: str, key: str) -> Prefab {
    if name == "steps" {
        return PalaceSteps();
    }
    if name == "redfield" {
        return RedField();
    }
    if name == "colonnade" {
        return Colonnade();
    }
    if name == "yellow" {
        return YellowGate();
    }
    if name == "throne" {
        return ThroneHall();
    }
    if name == "treasury" {
        return Treasury(key=key if key else "key_silver");
    }
    return CommLaser(key=key);
}
