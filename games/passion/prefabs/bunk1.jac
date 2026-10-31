"""Prefabs drawn from Quake II's bunk1, the Ammo Depot: a depot of loading
docks and crate stacks under cranes, a warehouse climbed crate by crate to
a high way out, a hall with cargo lifts up to its mezzanine, a flooded
basement under a grated hall, doors opened from elsewhere by their
buttons, the key in an armory opened by a button, the transports at the
way out. Raised in bunk1's own palette.

- `LoadingDock`: the start. A yard, a dock raised along its far end up a
  ramp, a gantry over the yard up a stair from the dock, a crane riding
  overhead, crates about (some break when shot); the help computer says to
  find the supply station's entrance; the dock's door is opened by a
  button down in the yard; guards appear on the dock as the player climbs.
- `CrateStacks`: a warehouse, crates stacked in a climb from the floor to a
  deck at the far end, a catwalk back along the far wall from the deck to
  the button that opens the high door; guards appear on the catwalk.
- `CargoLifts`: a hall, a mezzanine across its far half, cargo lifts up to
  it and a cargo car riding up and down beside them; a button on the
  mezzanine opens the doors below (a hub).
- `SubBasement`: a hall over a flooded basement, wells down into the water
  through its floor; the hall's way on is opened by a button deep in the
  basement (or on its far wall in some seeds); guards appear in the hall
  as it opens.
- `ArmoryVault`: the key room. The key in an armory behind a door a button
  on the wall opens; taking it opens the closets and brings guards in.
- `DepotExit`: the end. A door (a key's, as a gate), a ramp up to a dock,
  the Strogg transports parked by it; the button on the dock sets charges
  off under them and opens the way out a moment later."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }
import from .e4m6 { flood, onward_ports, port_door, told }
import from .base2 { spark_timer, blast_chain, spawn_in, panel_stash, guard_closet }

glob BUNK1: str = "q2:bunk1";

"""bunk1's foes: soldiers and berserkers, enforcers deeper in."""
glob BUNK1_FOES: FoeMix = FoeMix(light=["monster_soldier", "monster_soldier_ss", "monster_soldier_light"], strong=["monster_berserk", "monster_infantry"], heavy_light=["monster_berserk", "monster_soldier_ss"], heavy_strong=["monster_gladiator"]);

"""Crates: boxes of one to three lifts at the given cells ([x, y] each,
a crate two cells square)."""
def crates(build: Raising, dice: Stream, spots: list[list[int]], z: int) {
    for spot in spots {
        build.solid(spot[0], spot[1], z, spot[0] + 2, spot[1] + 2, z + dice.between(2, 3));
    }
}

"""Ammunition crates a cell square and two lifts high at `spots` ([x, y]
each) on lift `z`, broken apart when shot."""
def ammo_crates(build: Raising, spots: list[list[int]], z: int) {
    for at in spots {
        build.breakable(float(at[0]), float(at[1]), float(z), float(at[0] + 1), float(at[1] + 1), float(z + 2), 10);
    }
}

"""A locker in a block of solid: its door three cells wide at x..x+3 on
the cell line y (facing +y, `face` 1, the locker behind at y-2..y; or -y,
`face` 3, the locker at y+1..y+3), on lift `z`, opened by the button set
in the block's face beside it; `item` in it."""
def locker(build: Raising, x: int, y: int, face: int, z: int, item: str) {
    if face == 1 {
        build.room(x, y - 2, z, x + 3, y, z + 5);
        door = build.opened(float(x), float(y), float(z), float(x + 3), float(y + 1), float(z + 5));
        build.push(float(x + 3) + 0.5, float(y + 1), float(z) + 1.5, 1) +>:Fires:+> door;
        build.supply(float(x) + 1.5, float(y) - 1.0, z, item, "q2");
    } else {
        build.room(x, y + 1, z, x + 3, y + 3, z + 5);
        door = build.opened(float(x), float(y), float(z), float(x + 3), float(y + 1), float(z + 5));
        build.push(float(x + 3) + 0.5, float(y), float(z) + 1.5, 3) +>:Fires:+> door;
        build.supply(float(x) + 1.5, float(y) + 2.0, z, item, "q2");
    }
}

"""The start: a yard, a dock raised along its far end up a ramp, a gantry
over the yard, a crane overhead."""
node LoadingDock(Prefab) {
    has dock: int = 4,
        gantry: int = 9,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Loading dock";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.dock = dice.between(4, 5);
        self.gantry = 9;
        self.tall = dice.between(16, 18);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        dx = self.long - 8;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.dock), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0), Port(face=1, along=float(dx - 4), floor=self.gantry)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(yard, self.dock);
        build.level(yard, self.gantry);
        dx = self.long - 8;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, 2, 0, 0, self.dock, 3);
        for y in [2, 3, 4] {
            build.keep(yard, dx, y, self.dock);
        }
        # The gantry along the +y wall over the yard, up a stair on the dock.
        rise_up = self.gantry - self.dock;
        build.solid(4, self.wide - 5, self.gantry - 1, dx, self.wide - 1, self.gantry);
        stair(build, dx + rise_up - 1, self.wide - 5, self.dock, 2, rise_up, 4);
        for y in range(self.wide - 5, self.wide - 1) {
            build.keep(yard, dx - 1, y, self.gantry);
        }
        # The crane riding over the yard.
        build.train([4.0, 4.0, 1.0], [[6.0, float(middle - 2), float(self.tall - 3)], [float(dx - 6), float(middle - 2), float(self.tall - 3)]], 40.0, 3.0);
        crates(build, dice, [[12, 7], [15, middle - 1]], 0);
        crates(build, dice, [[dx + 5, middle + 3]], self.dock);
        ammo_crates(build, [[10, middle + 3], [18, 7], [dx - 2, middle + 2]], 0);
        build.solid(10, self.wide - 4, 0, 17, self.wide - 1, 7);
        locker(build, 11, self.wide - 4, 3, 0, "ammo_bullets");
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        # The dock's door, opened by a button down in the yard.
        press = build.push(float(self.long // 2) - 1.5, 1.0, 1.5, 1);
        for port in onward_ports(self) {
            if port.floor == self.dock {
                press +>:Fires:+> port_door(build, self, port);
            }
        }
        build.touch(float(dx), float(middle - 3), float(self.dock), float(self.long - 1), float(middle + 3), float(self.dock + 6), True, "This door is opened elsewhere");
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        into = build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0);
        into +>:Fires:+> build.objective("Find the entrance to the supply station");
        late = build.delay(2.0);
        into +>:Fires:+> late;
        late +>:Fires:+> build.objective("Destroy the Strogg logistical transports", False);
        # Climbing the ramp, guards appear on the dock and the gantry.
        climb = build.touch(float(dx - self.dock), 2.0, 0.0, float(dx), 5.0, float(self.dock + 6));
        spawn_in(build, dice, self.danger, climb, [[float(self.long) - 3.5, float(middle) + 3.5], [float(dx) + 2.5, float(middle) - 3.5]], self.dock, 180.0, True);
        doors_late = build.delay(1.0);
        climb +>:Fires:+> doors_late;
        build.solid(dx + 3, 1, self.dock, self.long - 1, 4, self.dock + 7);
        for x in range(dx + 3, self.long - 3, 4) {
            guard_closet(build, dice, self.danger, x, 3, 1, doors_late, self.dock);
        }
        spawn_in(build, dice, self.danger, climb, [[8.5, float(self.wide) - 3.0]], self.gantry, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(dx) - 6.5 + float(index % 2) * 2.0, 6.5 + float(index) * 3.0, 0, BUNK1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(6.5, 5.5, 0, "monster_soldier", 0.0, patrol=[[6.5, 5.5], [float(dx) - 6.5, 5.5]]);
        spark_timer(build, float(dx) - 0.1, float(middle) + 4.5, 2.0, 2, 4.0);
        panel_stash(build, 4, 0);
        build.supply(float(self.long) - 2.5, 2.5, self.dock, Q2_HEALTH, "q2");
    }
}

"""A warehouse, crates stacked in a climb from the floor to a deck at its
far end, a catwalk back along the far wall to the high door's button."""
node CrateStacks(Prefab) {
    has top: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crate stacks";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.top = dice.between(9, 10);
        self.tall = self.top + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 4), floor=self.top), Port(face=0, along=4.0, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=3, along=10.0, floor=self.top)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        house = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(house, self.top);
        # The climb: crates two cells square along the +y wall, each a lift
        # higher than the last, to a deck of crates at the far end.
        deck = self.long - 6;
        build.solid(deck, self.wide - 7, 0, self.long - 1, self.wide - 1, self.top);
        x = deck - 2;
        z = self.top - 1;
        while z > 0 and x > 3 {
            build.solid(x, self.wide - 4, 0, x + 2, self.wide - 1, z);
            x -= 2;
            z -= 1;
        }
        # The catwalk: a bridge from the deck across to the -y wall, and on
        # back along it over the floor.
        build.solid(self.long - 6, 4, self.top - 1, self.long - 2, self.wide - 7, self.top);
        build.solid(6, 1, self.top - 1, self.long - 2, 4, self.top);
        press = build.push(7.0, 1.0, float(self.top) + 1.5, 1);
        for port in onward_ports(self) {
            if port.floor == self.top and port.face == 0 {
                press +>:Fires:+> port_door(build, self, port);
            }
        }
        build.touch(float(deck), float(self.wide - 7), float(self.top), float(self.long - 1), float(self.wide - 1), float(self.top + 6), True, "The high door is opened from the end of the catwalk");
        crates(build, dice, [[6, 6], [10, 7], [14, 5], [18, 7]], 0);
        ammo_crates(build, [[8, 9], [16, 9], [21, 6]], 0);
        build.doorway(house, self.enter);
        for port in self.taken {
            build.doorway(house, port);
        }
        # Reaching the deck, guards appear on the catwalk.
        topped = build.touch(float(deck), float(self.wide - 7), float(self.top), float(deck + 2), float(self.wide - 1), float(self.top + 6));
        spawn_in(build, dice, self.danger, topped, [[12.5, 2.5], [20.5, 2.5]], self.top, 0.0);
        build.solid(self.long // 2 + 3, 1, 0, self.long - 6, 4, 7);
        burst = build.delay(1.5);
        topped +>:Fires:+> burst;
        for x in range(self.long // 2 + 4, self.long - 9, 4) {
            guard_closet(build, dice, self.danger, x, 3, 1, burst, 0);
        }
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "Climb the crates to the deck");
        floor_press = build.push(float(self.long - 1), 7.5, 1.5, 2);
        for port in onward_ports(self) {
            if port.floor == 0 {
                floor_press +>:Fires:+> port_door(build, self, port);
            }
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + 0.5, 0, BUNK1_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(8.5, 2.5, self.top, "monster_soldier", 0.0, patrol=[[8.5, 2.5], [float(self.long) - 4.5, 2.5]]);
        build.foe(float(self.long) - 3.0, float(self.wide) - 4.5, self.top, BUNK1_FOES.pick(dice, self.danger, True), 180.0);
        spark_timer(build, float(self.long) - 1.1, 6.5, float(self.top) + 2.0, 2, 5.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.top, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall, a mezzanine across its far half, cargo lifts up to it and a car
riding up and down beside them."""
node CargoLifts(Prefab) {
    has mezzanine: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cargo lifts";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.mezzanine = dice.between(9, 10);
        self.tall = 2 * self.mezzanine + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.mezzanine),
            Port(face=1, along=float(self.long - 5), floor=self.mezzanine),
            Port(face=3, along=8.0, floor=0),
            Port(face=1, along=8.0, floor=0),
            Port(face=0, along=float(self.wide - 4), floor=2 * self.mezzanine)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.mezzanine);
        mx = self.long // 2;
        build.solid(mx, 1, self.mezzanine - 1, self.long - 1, self.wide - 1, self.mezzanine);
        step = kit_of(build.district).step;
        for y0 in [3, self.wide - 7] {
            build.put_box({"classname": "func_plat", "height": str(self.mezzanine * 16), "speed": "150"}, float(mx - 4), float(y0), float(self.mezzanine) - 0.5, float(mx), float(y0 + 4), float(self.mezzanine), step);
            for y in range(y0, y0 + 4) {
                build.keep(hall, mx, y, self.mezzanine);
            }
        }
        # The cargo car riding up and down between the lifts.
        build.train([4.0, 4.0, 1.0], [[float(mx - 4), float(middle - 2), -1.0], [float(mx - 4), float(middle - 2), float(self.mezzanine - 1)]], 60.0, 3.0);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, mx, y, self.mezzanine);
        }
        for x in range(mx + 3, self.long - 2, 4) {
            build.solid(x, middle - 1, 0, x + 1, middle, self.mezzanine - 1);
        }
        # The upper deck over the mezzanine's far end, a lift up to it.
        upper = 2 * self.mezzanine;
        build.solid(self.long - 7, 1, upper - 1, self.long - 1, self.wide - 1, upper);
        build.put_box({"classname": "func_plat", "height": str(self.mezzanine * 16), "speed": "150"}, float(self.long - 10), 2.0, float(upper) - 0.5, float(self.long - 7), 5.0, float(upper), step);
        for y in range(2, 5) {
            build.keep(hall, self.long - 7, y, upper);
        }
        build.level(hall, upper);
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, upper, BUNK1_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, upper, Q2_ARMOR, "q2");
        build.solid(mx + 2, self.wide - 4, 0, mx + 9, self.wide - 1, self.mezzanine - 1);
        locker(build, mx + 3, self.wide - 4, 3, 0, Q2_HEALTH);
        # Guards' closets in a block along the -y wall under the mezzanine.
        build.solid(mx + 2, 1, 0, self.long - 3, 4, self.mezzanine - 1);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The button on the mezzanine opens the doors below.
        press = build.push(float(self.long - 1), float(middle) + 4.5, float(self.mezzanine) + 1.5, 2);
        for port in onward_ports(self) {
            if port.floor == 0 {
                press +>:Fires:+> port_door(build, self, port);
            }
        }
        build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 6.0, True, "The doors below are opened from the mezzanine");
        for x in range(mx + 3, self.long - 6, 4) {
            guard_closet(build, dice, self.danger, x, 3, 1, press, 0);
        }
        # Riding up, guards appear on the mezzanine.
        for y0 in [3, self.wide - 7] {
            ride = build.touch(float(mx - 4), float(y0), 0.0, float(mx), float(y0 + 4), 6.0);
            spawn_in(build, dice, self.danger, ride, [[float(self.long) - 4.5, float(y0) + 2.0]], self.mezzanine, 180.0, True);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, BUNK1_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(mx) + 2.5, 2.5, self.mezzanine, "monster_soldier", 0.0, patrol=[[float(mx) + 2.5, 2.5], [float(self.long) - 3.5, 2.5]]);
        ammo_crates(build, [[3, 2], [3, self.wide - 3], [mx - 6, middle + 5]], 0);
        spark_timer(build, float(mx) + 0.1, float(middle) + 3.5, float(self.mezzanine) - 3.0, 0, 4.0);
        build.supply(float(self.long) - 2.5, 2.5, self.mezzanine, Q2_HEALTH, "q2");
        build.supply(2.5, 5.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall over a flooded basement, wells down into the water through its
floor; the hall's way on opened by a button in the basement."""
node SubBasement(Prefab) {
    has deep: int = 8,
        wall_button: bool = False,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sub-basement";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(9, 11);
        self.wall_button = dice.chance(0.4);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # The basement under the hall's floor, flooded to the floor's
        # underside, pillars holding the floor up.
        build.room(5, 2, low, self.long - 5, self.wide - 2, -1, variant=dice.below(3));
        for x in range(8, self.long - 6, 5) {
            for y in range(5, self.wide - 4, 5) {
                build.solid(x, y, low, x + 1, y + 1, -1);
            }
        }
        flood(build, 5, 2, low, self.long - 5, self.wide - 2, -1);
        # The wells: three cells square down through the floor into the
        # water, a swimmer climbing out of each.
        wells = [[7, 3], [self.long - 9, self.wide - 6], [self.long // 2 - 1, 3]];
        for at in wells {
            build.widen(hall, at[0], at[1], -1, at[0] + 3, at[1] + 3, 0);
            for dx in range(-1, 4) {
                build.keep(hall, at[0] + dx, at[1] - 1, 0);
                build.keep(hall, at[0] + dx, at[1] + 3, 0);
            }
            for dy in range(3) {
                build.keep(hall, at[0] - 1, at[1] + dy, 0);
                build.keep(hall, at[0] + 3, at[1] + dy, 0);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The button that opens the ways on: deep in the basement, or on the
        # hall's far wall.
        deep = build.push(float(self.long - 5), float(middle) + 0.5, float(low) + 1.5, 2);
        press = build.delay(0.2);
        deep +>:Fires:+> press;
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "The way on is opened from the flooded basement");
        if self.wall_button {
            build.push(float(self.long - 1), float(middle) + 4.5, 1.5, 2) +>:Fires:+> press;
        }
        for at in wells {
            build.touch(float(at[0] - 1), float(at[1] - 1), 0.0, float(at[0] + 4), float(at[1] + 4), 6.0, True, "A well down into the flooded basement");
        }
        for port in onward_ports(self) {
            press +>:Fires:+> port_door(build, self, port);
        }
        late = build.delay(1.5);
        press +>:Fires:+> late;
        spawn_in(build, dice, self.danger, late, [[float(self.long) - 4.5, 3.5], [float(self.long) - 4.5, float(self.wide) - 3.5], [12.5, float(middle) + 0.5]], 0, 180.0, True);
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 7) + 0.5, float(middle) + 2.5, low + 1, "monster_flipper", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -2.5), 0, BUNK1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(3.5, 3.5, 0, "monster_soldier", 90.0, patrol=[[3.5, 3.5], [3.5, float(self.wide) - 3.5]]);
        ammo_crates(build, [[self.long - 3, 2], [self.long - 3, self.wide - 3]], 0);
        build.secret(float(self.long - 9), float(self.wide - 6), float(low), float(self.long - 6), float(self.wide - 3), float(low + 3));
        build.supply(float(self.long) - 7.5, float(self.wide) - 4.5, low, "item_armor_combat", "q2");
        spark_timer(build, 1.1, float(middle) + 3.5, 3.0, 0, 5.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an armory behind a door a button on the wall opens; taking it
opens the closets and brings guards in."""
node ArmoryVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Armory vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(11, 13);
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
        build.doorway(hall, self.enter);
        # The armory: the far end walled off, a door through its wall that
        # the button by it opens a moment after it is pressed.
        ax = self.long - 7;
        build.solid(ax, 1, 0, ax + 1, side, self.tall);
        build.widen(hall, ax, cy - 2, 0, ax + 1, cy + 2, 7);
        door = build.opened(float(ax), float(cy - 2), 0.0, float(ax + 1), float(cy + 2), 7.0);
        press = build.push(float(ax), float(cy) + 4.5, 1.3, 2);
        opening = told(build, 1.0, "The armory is open");
        press +>:Fires:+> opening;
        opening +>:Fires:+> door;
        crates(build, dice, [[4, 2], [8, side - 3]], 0);
        ammo_crates(build, [[ax - 3, side - 2], [ax + 2, 2]], 0);
        build.solid(ax - 7, 1, 0, ax - 1, 4, 7);
        locker(build, ax - 6, 3, 1, 0, "ammo_grenades");
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [3, ax - 5], [BUNK1_FOES.pick(dice, self.danger, True), BUNK1_FOES.pick(dice, self.danger)]);
        taken = build.touch(float(self.long - 5), float(cy - 2), 0.0, float(self.long - 1), float(cy + 3), 6.0);
        spawn_in(build, dice, self.danger, taken, [[float(ax) - 4.5, float(cy) + 0.5], [3.5, float(cy) - 3.5]], 0, 0.0, True);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0) +>:Fires:+> build.objective("Take the key from the armory");
        build.foe(float(self.long) - 3.0, 2.5, 0, BUNK1_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(side) - 5.5, 0, "monster_soldier", 0.0, patrol=[[3.5, float(side) - 5.5], [float(ax) - 2.5, float(side) - 5.5]]);
        spark_timer(build, float(ax) - 0.1, float(cy) - 4.0, 4.0, 2, 4.0);
        build.supply(float(self.long) - 3.0, float(side) - 2.5, 0, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a ramp up to a dock, the transports by it; the button
on the dock blows them and opens the way out."""
node DepotExit(Prefab) {
    has key: str = "",
        dock: int = 4,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Depot exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BUNK1;
        self.district = level_district(BUNK1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.dock = dice.between(4, 5);
        self.tall = dice.between(14, 16);
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
        court = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        dx = self.long - 12;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        stair(build, dx - self.dock, middle - 2, 0, 0, self.dock, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(court, dx, y, self.dock);
        }
        # The way out in a bay behind the dock's back wall, opened a moment
        # after the dock's button.
        bay = self.long - 6;
        build.solid(bay - 1, 1, self.dock, self.long - 1, self.wide - 1, self.tall);
        bay_room = build.room(bay, middle - 3, self.dock, self.long - 1, middle + 3, self.dock + 8, variant=dice.below(3));
        build.widen(bay_room, bay - 1, middle - 2, self.dock, bay, middle + 2, self.dock + 7);
        build.way_out(float(self.long) - 3.5, float(middle), self.dock);
        door = build.opened(float(bay - 1), float(middle - 2), float(self.dock), float(bay), float(middle + 2), float(self.dock + 7));
        press = build.push(float(bay - 1), float(middle) + 3.5, float(self.dock) + 1.5, 2);
        blow = told(build, 1.2, "The transports are destroyed");
        press +>:Fires:+> blow;
        blow +>:Fires:+> door;
        # The transports: two hulks on the yard floor by the dock, blown to
        # pieces when the button is pressed.
        hulks = build.cue([], "transports");
        for y0 in [2, self.wide - 6] {
            fields = {"classname": "func_explosive", "asset_game": "q2"};
            build.put_box(fields, float(dx - 9), float(y0), 0.0, float(dx - 5), float(y0 + 4), 4.0, kit_of(build.district).wall);
            hulks.items.append(fields);
        }
        blow +>:Fires:+> hulks;
        blast_chain(build, press, [[float(dx) - 7.0, 4.0, 2.0], [float(dx) - 7.0, float(self.wide) - 4.0, 2.0], [float(dx) - 3.0, float(middle) + 0.5, 6.0]]);
        spawn_in(build, dice, self.danger, press, [[float(wall) + 3.5, 3.5], [float(wall) + 3.5, float(self.wide) - 3.5]], 0, 0.0, True);

        build.touch(float(dx - self.dock), float(middle - 2), 0.0, float(dx), float(middle + 2), float(self.dock + 6), True, "Destroy the transports from the dock's console");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, BUNK1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 3.5, 2.5, 0, BUNK1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(dx) + 2.5, float(self.wide) - 2.5, self.dock, "monster_soldier", 270.0, patrol=[[float(dx) + 2.5, float(self.wide) - 2.5], [float(dx) + 2.5, 2.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""bunk1's stretches: [name, role]."""
glob BUNK1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["crates", "flow"],
         ["lifts", "hub"],
         ["lifts", "flow"],
         ["basement", "flow"],
         ["armory", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of bunk1's stretches by its name."""
def make_bunk1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return LoadingDock();
    }
    if name == "crates" {
        return CrateStacks();
    }
    if name == "lifts" {
        return CargoLifts();
    }
    if name == "basement" {
        return SubBasement();
    }
    if name == "armory" {
        return ArmoryVault(key=key if key else "key_silver");
    }
    return DepotExit(key=key);
}
