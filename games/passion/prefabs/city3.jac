"""Prefabs drawn from Quake II's city3, the Upper Palace: a gate whose
grand stair rises step after step at a button, stairways climbing in
flights over one another, the gun gallery whose blasters fire down it,
a rotunda round a sunken pool under its galleries, the security hall
held by its force field, the royal chamber where the pass lies, and the
summit balcony over the city. Raised in city3's own palette.

- `UpperGate`: the start. A hall, the gate's gallery high at its far end;
  the button at the stair's foot raises its steps one after another
  (city3's rising stair); a stash behind a panel; "Find the security
  pass".
- `PalaceStairs`: a stairway climbing in three flights along a tall hall's
  walls, each landing over what is below it, urns that burst; guards come
  out on each landing as it is reached, charges go off as the top is.
- `GunGallery`: a long gallery, gun ports in its wall that fire blasters
  down it one after another while a body walks it (city3's trap guns), a
  blast shield over the way on that a shot button lifts; a balcony over
  it.
- `Rotunda`: a round hall, its sunken middle a pool, a gallery round it
  up stairs and a higher one over half of it up a lift; the ambush of
  five soldiers as the player crosses. A hub.
- `SecurityHall`: a hall cut by a force field (the pass's), its lever on
  a gallery behind a laser fence; a slow lift down to a sunken floor and
  its way on.
- `RoyalChamber`: the security pass (the key) on a dais whose steps rise
  one after another at a button; taking it opens the closets.
- `SummitBalcony`: the end. A door (a key's, as a gate), a balcony over
  the city up a stair, the way out at its end; charges go off below."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, pillars }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, rounds, beamed, held_door, key_taken, closets, barrels, pad_to, hurting }
import from .city2 { double_doors, laser_fence, random_sparks }

glob CITY3: str = "q2:city3";

"""city3's foes: soldiers and gunners, iron maidens and floaters, tank
commanders deeper in."""
glob CITY3_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_soldier", "monster_chick"], strong=["monster_floater"], heavy_light=["monster_gunner", "monster_chick"], heavy_strong=["monster_tank_commander"], scale=0.5, heavy_scale=0.3);

"""Steps rising out of a floor one after another when `cue` fires, `gap`
seconds apart (city3's stair): `count` steps from the cell (x, y) on lift
`z` the way `direction` goes, `width` cells across, each its own door on
a chain of relays."""
def stair_in_turn(build: Raising, cue: Cue, x: int, y: int, z: int, direction: int, count: int, width: int, gap: float) {
    steps = build.rising_steps(x, y, z, direction, count, width);
    last = cue;
    for item in steps.items {
        late = build.delay(gap);
        last +>:Fires:+> late;
        late +>:Fires:+> build.cue([item], "step");
        last = late;
    }
    steps.items = [];
}

"""Gun ports in a wall firing blasters one after another, `gap` seconds
apart, each time `cue` fires: a blaster at each of `ports` ([x, y, z]
each, z in lifts) firing the way `direction` goes."""
def gun_ports(build: Raising, cue: Cue, ports: list[list[float]], direction: int, gap: float) {
    last = cue;
    for at in ports {
        late = build.delay(gap);
        last +>:Fires:+> late;
        fields = {"classname": "target_blaster", "angle": str(build.facing(direction)), "dmg": "8"};
        build.put_point(fields, at[0], at[1], at[2], "q2");
        late +>:Fires:+> build.cue([fields], "gun");
        last = late;
    }
}

"""The start: a hall, the gate's gallery high at its far end, the grand
stair whose steps rise one after another."""
node UpperGate(Prefab) {
    has gal: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Upper gate";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gal = 11;
        self.tall = self.gal + 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=self.gal),
            Port(face=0, along=3.5, floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.gal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gal;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gate's gallery across the far end, a balcony back along the
        # far wall from it.
        gx = self.long - 7;
        deck(build, gx, 1, self.long - 1, self.wide - 1, g);
        deck(build, 10, self.wide - 4, gx, self.wide - 1, g);
        # The grand stair up to the gallery, its steps rising at the button
        # by its foot one after another.
        raise_it = build.push(float(gx - g - 2), float(middle) + 3.5, 1.5, 2);
        build.solid(gx - g - 2, middle + 3, 0, gx - g - 1, middle + 4, 3);
        stair_in_turn(build, raise_it, gx - g, middle - 2, 0, 0, g, 4, 0.2);
        keep_box(build, hall, gx, middle - 2, gx + 1, middle + 2, g);
        build.touch(float(gx - g - 4), float(middle - 3), 0.0, float(gx - g - 2), float(middle + 3), 6.0, True, "The stair rises at the button by its foot");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Find the security pass. The upper palace is sealed by its force fields");
        # Guards on the gallery come forward as the stair rises; a gunner
        # walks the floor; a stash in an outcrop by the way in.
        squad(build, raise_it, [[float(gx) + 3.0, 3.0, float(g)], [float(gx) + 3.0, float(self.wide) - 3.0, float(g)], [14.5, float(self.wide) - 2.5, float(g)]], [CITY3_FOES.pick(dice, self.danger, True), "monster_soldier_ss", CITY3_FOES.pick(dice, self.danger)], 180.0);
        beamed(build, raise_it, 2, 2, -8, CITY3_FOES.pick(dice, self.danger), float(gx) - 3.5, 3.5, 0, 180.0);
        rounds(build, "monster_soldier", [[6.5, 3.5], [float(gx) - 3.5, 3.5]], 0);
        stash(build, 4, self.wide - 6, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.sparks(6.0, float(self.wide) - 6.2, 3.0, 3);
        random_sparks(build, [[float(self.long) - 1.2, 3.0, float(g) + 3.0, 2.0], [float(self.long) - 1.2, float(self.wide) - 3.0, float(g) + 3.0, 2.0], [1.2, 3.0, 4.0, 0.0]], 3.5);
        barrels(build, dice, 5, 1, gx - g - 3, self.wide - 1, 0, 2, [[0, middle - 3, 5, middle + 3], [3, self.wide - 7, 9, self.wide], [gx - g - 4, middle - 3, gx, middle + 5]]);
        alarm = build.push(float(self.long - 1), float(middle) + 0.5, float(g) + 1.5, 2);
        squad(build, alarm, [[6.5, 3.5, 0.0], [6.5, float(self.wide) - 8.5, 0.0]], ["monster_soldier", CITY3_FOES.pick(dice, self.danger)], 0.0);
        alarm +>:Fires:+> build.objective("The alarm is raised", False);
        build.touch(float(gx), float(middle - 2), float(g), float(gx + 2), float(middle + 2), float(g + 6), True, "The gate of the upper palace");
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, g, Q2_HEALTH, "q2");
    }
}

"""A stairway climbing in flights along a tall hall's walls, a landing
over a landing; guards come out on each landing."""
node PalaceStairs(Prefab) {
    has flight: int = 6,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace stairs";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.flight = dice.between(7, 8);
        self.tall = 3 * self.flight + 10;
        self.low = -9;
        self.high = self.tall + 1;
        f = self.flight;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=1, along=8.0, floor=0),
            Port(face=1, along=4.0, floor=2 * f),
            Port(face=3, along=float(self.long - 5), floor=3 * f)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.flight;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # Flight one along the near wall to the first landing at the far
        # end, which turns along the far end; flight two back along the far
        # wall over the floor to the second landing over the near end; flight
        # three along the near wall again to the top landing over the first.
        l1 = self.long - 6;
        w = self.wide;
        deck(build, l1, 1, self.long - 1, 6, f);
        deck(build, self.long - 4, 6, self.long - 1, w - 1, f);
        stair(build, l1 - f, 1, 0, 0, f, 3);
        keep_box(build, hall, l1, 1, l1 + 1, 4, f);
        stair(build, self.long - 5, w - 4, f, 2, f, 3);
        keep_box(build, hall, self.long - 5, w - 4, self.long - 4, w - 1, f);
        top2 = self.long - 4 - f;
        deck(build, 1, w - 6, top2, w - 1, 2 * f);
        deck(build, 1, 1, 6, w - 6, 2 * f);
        keep_box(build, hall, top2 - 1, w - 4, top2, w - 1, 2 * f);
        stair(build, 6, 1, 2 * f, 0, f, 3);
        deck(build, 6 + f, 1, self.long - 1, 5, 3 * f);
        keep_box(build, hall, 6 + f, 1, 7 + f, 4, 3 * f);
        build.level(hall, f);
        build.level(hall, 2 * f);
        build.level(hall, 3 * f);
        for corner in [[1, 1], [1, w - 9]] {
            build.breakable(float(corner[0]), float(corner[1]), float(2 * f), float(corner[0] + 2), float(corner[1] + 2), float(2 * f + 2), 10);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Guards come out on each landing as the player reaches the one before.
        first = build.touch(float(l1), 1.0, float(f), float(l1 + 2), 6.0, float(f + 6));
        squad(build, first, [[3.0, 3.0, float(2 * f)], [3.5, float(self.wide) - 3.0, float(2 * f)]], [CITY3_FOES.pick(dice, self.danger), "monster_soldier_ss"], 0.0);
        second = build.touch(float(top2 - 3), float(self.wide - 6), float(2 * f), float(top2), float(self.wide - 1), float(2 * f + 6));
        squad(build, second, [[float(self.long) - 3.0, 3.0, float(3 * f)], [float(self.long) - 8.0, 3.0, float(3 * f)]], [CITY3_FOES.pick(dice, self.danger, True), "monster_soldier"], 180.0);
        beamed(build, second, 2, 2, -8, CITY3_FOES.pick(dice, self.danger), float(self.long // 2), float(self.wide // 2), 0, 90.0);
        alarm = build.push(float(self.long - 1), 3.0, float(3 * f) + 1.5, 2);
        squad(build, alarm, [[3.0, 3.0, float(2 * f)], [float(self.long) - 3.0, float(self.wide) - 3.0, float(f)]], ["monster_soldier_ss", CITY3_FOES.pick(dice, self.danger, True)], 0.0);
        build.touch(1.0, float(self.wide // 2 - 2), 0.0, 3.0, float(self.wide // 2 + 2), 6.0, True, "The palace stairs climb to the upper halls");
        # Charges go off down the stairwell as the top is reached.
        top = build.touch(float(6 + f), 1.0, float(3 * f), float(8 + f), 5.0, float(3 * f + 6));
        blast_chain(build, top, [[float(self.long // 2), float(self.wide // 2), 2.0], [float(self.long) - 3.0, float(self.wide // 2), float(f) + 2.0]], 0.4);
        rounds(build, "monster_soldier", [[3.5, float(self.wide // 2)], [float(self.long) - 8.5, float(self.wide // 2)]], 0);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, f, CITY3_FOES.pick(dice, self.danger), 180.0);
        random_sparks(build, [[1.2, float(self.wide // 2), 4.0, 0.0], [float(self.long) - 1.2, float(self.wide // 2), float(f) + 3.0, 2.0], [1.2, 3.0, float(3 * f) + 2.0, 0.0]], 3.0);
        build.supply(2.5, float(self.wide // 2) - 2.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, 3 * f, "ammo_bullets", "q2");
    }
}

"""A long gallery, gun ports in its wall firing down it while a body walks
it, a blast shield over the way on lifted by a shot button."""
node GunGallery(Prefab) {
    has bal: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun gallery";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.bal = dice.between(7, 8);
        self.tall = self.bal + 9;
        self.low = -9;
        self.high = 22;
        self.enter = Port(face=2, along=float(self.wide // 2 + 1), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2 + 1), floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.bal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2 + 1;
        b = self.bal;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, b);
        # The balcony along the near wall over the gallery, up a stair.
        deck(build, 4 + b, 1, self.long - 1, 5, b);
        stair(build, 4, 1, 0, 0, b, 3);
        keep_box(build, hall, 4 + b, 1, 5 + b, 4, b);
        # The gun ports along the far wall: walking the gallery sets them off
        # one after another.
        walking = build.touch(5.0, 5.0, 0.0, float(self.long - 6), float(self.wide - 1), 6.0, False);
        gun_ports(build, walking, [[float(x) + 0.5, float(self.wide) - 1.2, 2.0] for x in range(8, self.long - 4, 4)], 3, 0.2);
        # The blast shield over the way on, lifted by a shot button.
        shield = build.opened(float(self.long - 2), float(middle - 2), 0.0, float(self.long - 1), float(middle + 2), 8.0);
        build.widen(hall, self.long - 2, middle - 2, 0, self.long - 1, middle + 2, 8);
        shot = build.push(float(self.long - 1), float(middle) + 3.5, 6.0, 2, True);
        shot +>:Fires:+> shield;
        shot +>:Fires:+> build.explosion(float(self.long) - 3.0, float(middle), 2.0);
        build.touch(float(self.long - 6), float(middle - 2), 0.0, float(self.long - 3), float(middle + 2), 6.0, True, "The blast shield's button is shot from the gallery");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        squad(build, walking, [[float(self.long) - 6.0, 3.0, float(b)], [float(self.long // 2), 3.0, float(b)]], ["monster_gunner", CITY3_FOES.pick(dice, self.danger)], 180.0);
        beamed(build, shot, 2, 2, -8, CITY3_FOES.pick(dice, self.danger, True), float(self.long // 2) + 0.5, float(middle) + 0.5, 0, 0.0);
        rounds(build, "monster_soldier_ss", [[6.5, float(middle)], [float(self.long) - 6.5, float(middle)]], 0);
        stash(build, 8, self.wide - 6, 0, 3, Q2_ARMOR, 5) +>:Fires:+> build.sparks(10.0, float(self.wide) - 6.2, 2.0, 3);
        for index in range(2) {
            build.breakable(float(self.long - 9 + index * 3), 5.0, 0.0, float(self.long - 8 + index * 3), 6.0, 2.0, 10);
        }
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "Gun ports line the gallery");
        alarm = build.push(float(self.long - 1), 3.0, float(b) + 1.5, 2);
        squad(build, alarm, [[6.5, float(self.wide) - 3.0, 0.0], [float(self.long // 2), float(self.wide) - 3.0, 0.0]], ["monster_soldier", CITY3_FOES.pick(dice, self.danger)], 0.0);
        alarm +>:Fires:+> build.objective("The guards are called", False);
        random_sparks(build, [[1.2, float(middle), 3.0, 0.0], [float(self.long) - 1.2, 3.0, float(b) + 2.0, 2.0]], 3.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, b, "ammo_bullets", "q2");
    }
}

"""A round hall, its sunken middle a pool, a gallery round it and a higher
one over half of it; five soldiers lie in wait."""
node Rotunda(Prefab) {
    has gal: int = 7,
        upper: int = 14,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rotunda";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.gal = 9;
        self.upper = 17;
        self.tall = 26;
        self.low = -9;
        self.high = 27;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gal),
            Port(face=3, along=float(self.long // 2), floor=self.gal),
            Port(face=1, along=float(self.long - 6), floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gal;
        u = self.upper;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        build.level(hall, u);
        # The corners filled to round the hall.
        for corner in [[1, 1], [self.long - 4, 1], [1, self.wide - 4], [self.long - 4, self.wide - 4]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 3, corner[1] + 3, self.tall);
        }
        # The sunken pool in the middle, a stair up out of it.
        build.pool(cx - 5, cy - 5, -4, cx + 5, cy + 5, 0, 2, steps=False);
        stair(build, cx - 5, cy - 5, -4, 0, 4, 2);
        build.solid(cx - 1, cy - 1, -4, cx + 1, cy + 1, 4);
        # The gallery round the walls up stairs at two sides, the higher one
        # over the far half up a lift.
        deck(build, 4, 1, self.long - 4, 5, g);
        deck(build, 4, self.wide - 5, self.long - 4, self.wide - 1, g);
        deck(build, 1, 4, 5, self.wide - 4, g);
        deck(build, self.long - 5, 4, self.long - 1, self.wide - 4, g);
        stair(build, 6, 5, 0, 0, g, 3);
        stair(build, 6, self.wide - 8, 0, 0, g, 3);
        keep_box(build, hall, 5 + g, 4, 6 + g, 5, g);
        keep_box(build, hall, 5 + g, self.wide - 5, 6 + g, self.wide - 4, g);
        deck(build, cx, self.wide - 5, self.long - 4, self.wide - 1, u);
        deck(build, self.long - 5, cy, self.long - 1, self.wide - 4, u);
        lift(build, self.long - 8, cy, self.long - 5, cy + 3, g, u);
        keep_box(build, hall, self.long - 5, cy, self.long - 4, cy + 3, u);
        keep_box(build, hall, self.long - 5, cy, self.long - 4, cy + 3, g);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        pad_to(build, float(cx) + 4.5, 7.5, 0, float(cx) + 4.5, 3.0, g);
        keep_box(build, hall, cx + 3, 4, cx + 7, 5, g);
        # The five soldiers come on as the player crosses the floor.
        crossing = build.touch(float(cx - 7), 5.0, 0.0, float(cx - 5), float(self.wide - 5), 6.0);
        squad(build, crossing, [[float(cx) + 7.0, 6.5, 0.0], [float(cx) + 7.0, float(self.wide) - 6.5, 0.0], [float(cx), 3.0, float(g)], [float(cx), float(self.wide) - 3.0, float(g)], [float(self.long) - 3.0, float(cy) + 3.0, float(u)]], ["monster_soldier", "monster_soldier", "monster_soldier_ss", "monster_soldier", CITY3_FOES.pick(dice, self.danger, True)], 180.0);
        beamed(build, crossing, 2, cy - 2, -8, CITY3_FOES.pick(dice, self.danger), float(cx) - 7.0, float(cy) + 0.5, 0, 0.0);
        hidden_closet(build, self.long - 9, self.wide - 9, 0, 3, Q2_ARMOR, 6);
        vault = build.room(2, 2, 0, 4, 4, 5);
        build.widen(vault, 4, 2, 0, 5, 4, 5);
        opener = build.push(float(self.long - 4), float(self.wide) - 6.5, float(u) + 1.5, 2);
        opener +>:Fires:+> build.opened(4.0, 2.0, 0.0, 5.0, 4.0, 5.0);
        build.supply(3.0, 3.0, 0, "item_health_mega", "q2");
        squad(build, opener, [[float(cx) - 7.0, float(cy) + 7.0, 0.0]], [CITY3_FOES.pick(dice, self.danger)], 0.0);
        for (index, at) in enumerate([[cx - 8, cy - 8], [cx + 6, cy + 6]]) {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 2), float(at[1] + 2), 2.0, 10);
        }
        rounds(build, "monster_chick", [[6.5, 3.0], [float(self.long) - 6.5, 3.0], [float(self.long) - 3.0, float(cy) - 3.0]], g);
        build.foe(float(cx) + 0.5, float(cy) + 7.5, 0, CITY3_FOES.pick(dice, self.danger), 270.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 8, "monster_floater", 0.0);
        random_sparks(build, [[1.2, float(cy) + 6.0, 3.0, 0.0], [float(self.long) - 1.2, float(cy) - 6.0, float(g) + 2.0, 2.0], [float(cx) + 1.2, float(cy), 2.0, 0.0]], 3.0);
        build.supply(2.5, float(cy) + 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 6.0, u, "ammo_rockets", "q2");
    }
}

"""A hall cut by a force field, its lever on a gallery behind a laser
fence; a slow lift down to a sunken floor and its way on."""
node SecurityHall(Prefab) {
    has gal: int = 7,
        sunk: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security hall";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gal = 7;
        self.sunk = dice.between(8, 10);
        self.tall = 16;
        self.low = -2 * self.sunk - 1;
        self.high = 22;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=0),
            Port(face=1, along=float(self.long - 5), floor=-self.sunk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gal;
        fx = self.long // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The force field across the hall, held until the lever is thrown.
        build.solid(fx, 1, 0, fx + 1, self.wide - 1, self.tall);
        build.widen(hall, fx, middle - 2, 0, fx + 1, middle + 2, 8);
        field = build.opened(float(fx), float(middle - 2), 0.0, float(fx + 1), float(middle + 2), 8.0);
        build.touch(float(fx - 2), float(middle - 2), 0.0, float(fx), float(middle + 2), 6.0, False, "Security pass required to deactivate the force field");
        # The gallery along the near wall up a stair, the lever at its end
        # behind a laser fence.
        deck(build, 4 + g, 1, fx, 5, g);
        stair(build, 4, 1, 0, 0, g, 3);
        keep_box(build, hall, 4 + g, 1, 5 + g, 4, g);
        fence = laser_fence(build, float(fx - 3) + 0.5, 1.1, g, 1, 2.0);
        lever = build.push(float(fx), 3.0, float(g) + 1.5, 2);
        lever +>:Fires:+> field;
        lever +>:Fires:+> fence;
        lever +>:Fires:+> build.objective("Force field down", False);
        hurting(build, float(fx) - 1.0, float(middle) - 4.0, 0.0, float(fx), float(middle) - 2.0, 4.0, 4);
        # Beyond the field, the sunken floor down a slow lift (or by a drop
        # from its edge), its way on.
        pit = build.room(fx + 4, middle + 2, -self.sunk, self.long - 1, self.wide - 1, 0);
        build.level(pit, -self.sunk);
        lift(build, fx + 4, middle - 1, fx + 7, middle + 2, -self.sunk, 0);
        build.widen(pit, fx + 4, middle - 1, -self.sunk, fx + 7, middle + 2, 0);
        keep_box(build, hall, fx + 4, middle + 1, self.long - 1, middle + 2, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor < 0 {
                build.doorway(pit, port);
            } else {
                build.doorway(hall, port);
            }
        }
        late = build.delay(2.0);
        lever +>:Fires:+> late;
        squad(build, late, [[float(fx) + 3.0, 3.5, 0.0], [float(self.long) - 4.0, float(self.wide) - 3.0, float(-self.sunk)]], [CITY3_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        beamed(build, late, 2, 2, -2 * self.sunk + 1, CITY3_FOES.pick(dice, self.danger), float(fx) + 3.0, float(middle) - 4.0, 0, 180.0);
        up = build.touch(float(4 + g), 1.0, float(g), float(6 + g), 5.0, float(g + 6), True, "The field's lever lies behind the lasers");
        squad(build, up, [[float(fx) - 2.0, 3.0, float(g)]], [CITY3_FOES.pick(dice, self.danger)], 180.0);
        rounds(build, "monster_soldier", [[3.5, float(middle) + 3.0], [float(fx) - 3.5, float(middle) + 3.0]], 0);
        random_sparks(build, [[float(fx) - 0.2, float(middle) - 4.0, 4.0, 2.0], [float(fx) + 1.2, float(middle) + 4.0, 4.0, 0.0], [float(self.long) - 1.2, float(middle) + 5.0, -2.0, 2.0]], 1.5);
        barrels(build, dice, 1, middle + 1, fx - 1, self.wide - 1, 0, 1, [[0, middle - 3, 4, middle + 3], [fx - 4, middle - 3, fx, middle + 3]]);
        hidden_closet(build, fx - 6, self.wide - 6, 0, 2, Q2_ARMOR, 6);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, -self.sunk, "ammo_cells", "q2");
    }
}

"""The security pass on a dais whose steps rise one after another at a
button; taking it opens the closets."""
node RoyalChamber(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        dais: int = 5,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Royal chamber (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.dais = dice.between(4, 6);
        self.tall = 16;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.dais);
        build.level(room, 9);
        build.doorway(room, self.enter);
        # The dais at the far end, its steps rising one after another at the
        # button on the wall; a gallery over the near end.
        px = self.long - 7;
        build.solid(px, cy - 3, 0, self.long - 1, cy + 3, self.dais);
        raise_it = build.push(float(px) - 2.5, float(side), 1.5, 3);
        stair_in_turn(build, raise_it, px - self.dais, cy - 1, 0, 0, self.dais, 3, 0.25);
        keep_box(build, room, px, cy - 1, px + 1, cy + 2, self.dais);
        deck(build, 1, 1, 8, side, 9);
        lift(build, 8, 1, 11, 4, 0, 9);
        keep_box(build, room, 7, 1, 8, 4, 9);
        taken = key_taken(build, self.key, float(self.long) - 3.5, float(cy), self.dais);
        taken +>:Fires:+> build.objective("Security pass taken", False);
        closets(build, taken, side, 0, [3, self.long - 9], [CITY3_FOES.pick(dice, self.danger, True), CITY3_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[4.5, 3.0, 9.0], [4.5, float(side) - 3.0, 9.0]], ["monster_soldier_ss", CITY3_FOES.pick(dice, self.danger)], 0.0);
        beamed(build, taken, 2, 2, -8, CITY3_FOES.pick(dice, self.danger, True), 11.5, float(cy) + 0.5, 0, 0.0);
        build.touch(float(px - 8), 1.0, 0.0, float(px - 6), float(side), 6.0, True, "The steps rise at the button by the dais");
        rounds(build, "monster_soldier", [[11.5, 2.5], [float(px) - 2.5, 2.5]], 0);
        call = build.push(1.0, float(cy) + 0.5, 10.5, 0);
        squad(build, call, [[float(px) - 4.0, float(cy) + 4.0, 0.0]], ["monster_chick"], 180.0);
        build.breakable(12.0, float(side) - 3.0, 0.0, 14.0, float(side) - 1.0, 2.0, 10);
        build.touch(1.0, float(cy - 2), 0.0, 3.0, float(cy + 2), 6.0, True, "The royal chamber");
        build.foe(float(self.long) - 3.5, float(cy) + 2.0, self.dais, CITY3_FOES.pick(dice, self.danger), 180.0);
        random_sparks(build, [[float(self.long) - 1.2, float(cy) - 2.0, float(self.dais) + 2.0, 2.0], [1.2, float(cy), 3.0, 0.0], [1.2, float(cy) + 3.0, 11.0, 0.0]], 3.0);
        build.supply(10.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a balcony over the city up a stair, the way out at its
end; charges go off below."""
node SummitBalcony(Prefab) {
    has key: str = "",
        bal: int = 10,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Summit balcony" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY3;
        self.district = level_district(CITY3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.bal = dice.between(12, 14);
        self.tall = self.bal + 10;
        self.low = -8;
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
        b = self.bal;
        court = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(court, b);
        # The city below: the court's far part sunk, the balcony along the
        # near wall over it, up a stair, the way out at its end.
        build.room(wall + 7, 4, -7, self.long - 1, self.wide - 1, 0);
        build.level(court, -7);
        stair(build, wall + 9, 10, -7, 3, 7, 3);
        deck(build, wall + 1 + b, 1, self.long - 1, 5, b);
        stair(build, wall + 1, 1, 0, 0, b, 3);
        keep_box(build, court, wall + 1 + b, 1, wall + 2 + b, 4, b);
        build.solid(self.long - 4, 1, b, self.long - 1, 5, b + 1);
        build.way_out(float(self.long) - 6.0, 3.0, b);
        # Charges go off in the city below as the player climbs; guards on
        # the balcony.
        climb = build.touch(float(wall + 1), 1.0, 1.0, float(wall + 4), 4.0, 7.0);
        blast_chain(build, climb, [[float(wall) + 10.0, 8.0, -5.0], [float(self.long) - 6.0, float(self.wide) - 4.0, -5.0], [float(wall) + 14.0, float(self.wide) - 6.0, -5.0]], 0.4);
        squad(build, climb, [[float(self.long) - 10.0, 3.0, float(b)], [float(wall) + 12.0, float(self.wide) - 4.0, -6.0]], [CITY3_FOES.pick(dice, self.danger, True), "monster_floater"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, CITY3_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        rounds(build, "monster_soldier_ss", [[float(wall) + 3.5, float(middle)], [float(wall) + 5.5, float(self.wide) - 3.0]], 0);
        random_sparks(build, [[float(wall) + 1.2, float(self.wide) - 3.0, 3.0, 0.0], [float(self.long) - 1.2, 3.0, float(b) + 2.0, 2.0]], 3.0);
        signal = build.push(float(self.long - 1), 3.0, float(b) + 1.5, 2);
        blast_chain(build, signal, [[float(self.long) - 8.0, float(self.wide) - 3.0, -5.0], [float(wall) + 12.0, float(self.wide) - 3.0, -5.0]], 0.3);
        build.breakable(float(wall + 2), float(self.wide - 4), 0.0, float(wall + 4), float(self.wide - 2), 2.0, 10);
        build.touch(float(wall + 1 + b), 1.0, float(b), float(wall + 3 + b), 5.0, float(b + 6), True, "The city lies below");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""city3's stretches: [name, role]."""
glob CITY3_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["stairs", "flow"],
         ["guns", "flow"],
         ["security", "flow"],
         ["rotunda", "hub"],
         ["royal", "keyroom"],
         ["summit", "end"],
         ["summit", "gate"]
     ];

"""One of city3's stretches by its name."""
def make_city3(name: str, key: str) -> Prefab {
    if name == "gate" {
        return UpperGate();
    }
    if name == "stairs" {
        return PalaceStairs();
    }
    if name == "guns" {
        return GunGallery();
    }
    if name == "security" {
        return SecurityHall();
    }
    if name == "rotunda" {
        return Rotunda();
    }
    if name == "royal" {
        return RoyalChamber(key=key if key else "key_silver");
    }
    return SummitBalcony(key=key);
}
