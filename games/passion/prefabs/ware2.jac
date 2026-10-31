"""Prefabs drawn from Quake II's ware2, the Warehouse's back end, where the
power to the key warehouses is to be restored: a truck bay below the
loading floor, two storeys of offices, a hall where crates ride a belt
up an incline once the power is on, storage racks reached by a stair that
rises out of the floor, a freight platform that sinks a storey (ware2's
great lowering door), the foreman's office over a storeroom, the freight
bay out. Raised in ware2's own palette.

- `TruckBay`: the start. A bay under the sky, trucks backed up to the loading floor
  along its far end (one or two), up a ramp or a lift called down; the
  help computer gives the objective. A trailer's back breaks open on a
  stash (a secret); explosive crates; guards appear on the loading floor
  as the player passes the cabs; one walks between the trucks.
- `OfficeRow`: a corridor of offices, and over it a second storey of them
  (or not), both opening on a hall at the far end whose stair climbs to a
  gallery; an office's window breaks on a stash; a button in an upper
  office opens the hall's ways below (or they open as a body comes near);
  guards appear upstairs as the player tops the stair.
- `CrateIncline`: a hall, a deck over its far half, crates riding a belt
  up an incline from the floor to the deck; up by a stair or a lift. Two
  power switches (one on the deck, one under it) restore the power: the
  belt starts, the shutters open, guards come to look. Ways out on both
  floors (a hub).
- `StorageRacks`: racks walked along their tops, planks across between;
  a stair to them rises out of the floor when its button is pressed
  (ware2's stair of doors), and guards appear on the racks as it rises; a
  fixed stair at the far end now and then. Ways out below and from the
  racks' tops (a hub).
- `FreightDrop`: an upper room on a freight platform that sinks a storey
  into the hall below when its button is pressed, waking what waits
  there; a stair (or a lift) back up; ways out on both storeys.
- `ForemanOffice`: the key room. A loading floor and, through a wall, a low
  store of racks; the foreman's office over the store, up a stair hall (or a
  lift) walled off the loading floor, a window looking down from it; the key
  on his desk; taking it opens the closets below and brings guards into the
  store.
- `FreightBay`: the end. Big bay doors (a key's, as a gate) out to a yard
  under the sky, containers stood along its walls, crates riding a belt, the
  way out on a platform in the yard's middle up a lift called down or a
  stair; calling it sets off charges about the yard one after another."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, lift }
import from .warejail_parts { shutter, auto_shutters, key_cue, belt_crates, sparking, guards, charges, stash, keep_row, called_lift, closets, post_button, crane }
import from .q2walls_parts { gate_yard }

glob WARE2: str = "q2:ware2";

"""ware2's foes: infantry and parasites, berserkers and gunners, a tank
deeper in."""
glob WARE2_FOES: FoeMix = FoeMix(light=["monster_infantry", "monster_infantry", "monster_parasite"], strong=["monster_berserk", "monster_soldier_ss"], heavy_light=["monster_gunner", "monster_berserk"], heavy_strong=["monster_tank"], heavy_scale=0.5);


"""An explosive crate two cells square standing on lift `z` at (x, y):
it blows apart when shot."""
def blast_crate(build: Raising, x: int, y: int, z: int) {
    build.breakable(float(x), float(y), float(z), float(x + 2), float(y + 2), float(z + 2), 10);
}

"""The start: a bay, trucks backed up to the loading floor."""
node TruckBay(Prefab) {
    has dock: int = 4,
        trucks: int = 2,
        by_lift: bool = False,
        hidden: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Truck bay";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(32, 36);
        self.wide = dice.between(23, 26);
        self.dock = dice.between(4, 5);
        self.tall = dice.between(50, 54);
        self.trucks = dice.between(1, 2);
        self.by_lift = dice.chance(0.45);
        self.hidden = dice.chance(0.7);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.dock), Port(face=1, along=float(self.long - 4), floor=self.dock), Port(face=3, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(bay, self.dock);
        fx = self.long - 8;
        build.solid(fx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        # Up to the loading floor: a ramp along the far side wall, or a lift
        # called down by the button beside it.
        if self.by_lift {
            build.push(float(fx), float(self.wide) - 6.5, 1.0, 2) +>:Fires:+> called_lift(build, fx - 3, self.wide - 5, fx, self.wide - 2, 0, self.dock);
            keep_row(build, bay, fx, self.wide - 5, self.dock, 0, 3);
        } else {
            stair(build, fx - self.dock, self.wide - 5, 0, 0, self.dock, 4);
            keep_row(build, bay, fx, self.wide - 5, self.dock, 0, 4);
        }
        # The trucks, backed up to the loading floor: a trailer four cells
        # wide, hollow, its back two cells short of the floor; a cab before.
        rows = [3, middle + 1] if self.trucks == 2 else [middle - 2];
        for (index, y0) in enumerate(rows) {
            build.solid(fx - 12, y0, 0, fx - 9, y0 + 4, 3);
            build.solid(fx - 9, y0, 0, fx - 2, y0 + 4, 5);
            if index == 0 and self.hidden {
                stash(build, fx - 8, y0 + 1, fx - 3, y0 + 3, 0, 0, Q2_ARMOR, "q2");
            }
        }
        # A belt along the loading floor's near side, crates riding it.
        build.solid(fx + 1, 1, self.dock, self.long - 1, 4, self.dock + 1);
        belt_crates(build, dice, fx + 1, self.long - 1, 1, self.dock + 1, 2);
        crane(build, fx - 6, 2, self.wide - 4, 14);
        blast_crate(build, fx - 2, 1, 0);
        blast_crate(build, 3, self.wide - 3, 0);
        sparking(build, float(fx) - 0.1, float(middle) + 0.5, float(self.dock) - 2.0, 2, 4.0);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 5.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Restore power to the key warehouses");
        # Passing the cabs, guards appear on the loading floor.
        passing = build.touch(float(fx - 13), 1.0, 0.0, float(fx - 11), float(self.wide - 1), 8.0);
        guards(build, passing, [[float(self.long) - 3.5, 5.5], [float(self.long) - 4.5, float(self.wide) - 3.5]], self.dock, WARE2_FOES.squad(dice, self.danger, 2), 180.0);
        lane = float(middle) - 0.5 if self.trucks == 2 else 3.5;
        build.foe(4.5, lane, 0, "monster_infantry", 0.0, patrol=[[4.5, lane], [float(fx) - 1.5, lane]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5 - float(index) * 2.0, float(middle) + 0.5 + float(index % 2) * 3.0, self.dock, WARE2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.dock, Q2_HEALTH, "q2");
    }
}

"""A corridor of offices, a second storey over it, a hall at its far end
whose stair climbs to a gallery."""
node OfficeRow(Prefab) {
    has upper: int = 11,
        storeys: int = 2,
        from_office: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Office row";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(31, 34);
        self.wide = dice.between(18, 20);
        self.storeys = 2 if dice.chance(0.65) else 1;
        self.from_office = self.storeys == 2 and dice.chance(0.6);
        self.tall = self.upper + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        hx = self.long - 15;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(hx + 2), floor=self.upper),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        if self.storeys == 2 {
            self.leaves.append(Port(face=3, along=5.0, floor=self.upper));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hx = self.long - 15;
        corridor = build.room(1, middle - 2, 0, hx, middle + 3, 10, variant=dice.below(3));
        # The far hall, full height, and a stair up its side wall to a
        # gallery along its near wall, at the upper storey's floor.
        hall = build.room(hx, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.upper);
        build.solid(hx, 1, self.upper - 1, hx + 3, self.wide - 1, self.upper);
        stair(build, self.long - 2, self.wide - 4, 0, 2, self.upper, 3);
        # Offices off both sides, each open to the corridor (and, over them,
        # the upper storey's); one whose way in is a window that breaks.
        windowed = dice.below(4);
        index = 0;
        button_at: list[float] = [];
        for x in range(2, hx - 5, 6) {
            for south in [True, False] {
                y0 = 1 if south else middle + 4;
                y1 = middle - 3 if south else self.wide - 1;
                door_y = middle - 3 if south else middle + 3;
                if self.storeys == 2 and x == 2 and not south {
                    # The first office on the far side is a lift shaft between
                    # the storeys.
                    shaft = build.room(x, y0, 0, x + 5, y1, self.upper + 9, variant=dice.below(3));
                    for floor in [0, self.upper] {
                        build.widen(shaft, x + 1, door_y, floor, x + 4, door_y + 1, floor + 6);
                    }
                    lift(build, x + 1, y0, x + 4, y0 + 3, 0, self.upper);
                    keep_row(build, shaft, x + 1, door_y, self.upper, 1, 3);
                    index += 1;
                    continue;
                }
                storeys = [0, self.upper] if self.storeys == 2 else [0];
                for floor in storeys {
                    office = build.room(x, y0, floor, x + 5, y1, floor + 9, variant=dice.below(3));
                    # A desk against its back wall.
                    back = y0 if south else y1 - 1;
                    build.solid(x + 1, back, floor, x + 4, back + 1, floor + 2);
                    if floor == 0 and index == windowed {
                        build.breakable(float(x + 1), float(door_y), 1.0, float(x + 4), float(door_y + 1), 5.0, 15);
                        build.secret(float(x + 1), float(y0 + 1), 0.0, float(x + 4), float(y1 - 1), 3.0);
                        build.supply(float(x) + 2.5, float(y0 + y1) * 0.5, 0, Q2_ARMOR, "q2");
                    } else {
                        build.widen(office, x + 1, door_y, floor, x + 4, door_y + 1, floor + 6);
                    }
                    if floor == self.upper and south and not button_at {
                        button_at = [float(x) + 5.0, float(y0 + y1) * 0.5];
                    }
                }
                if index % 2 == 1 {
                    build.foe(float(x) + 2.5, float(y0 + y1) * 0.5, 0, WARE2_FOES.pick(dice, self.danger), 90.0 if south else 270.0);
                }
                index += 1;
            }
        }
        if self.storeys == 2 {
            upstairs = build.room(1, middle - 2, self.upper, hx, middle + 3, self.upper + 10, variant=dice.below(3));
            build.level(upstairs, self.upper);
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # A button in an upper office opens the hall's ways below; else they
        # open as a body comes near.
        low_ports = [port for port in self.taken if port.floor == 0];
        if self.from_office and button_at {
            press = build.push(button_at[0], button_at[1], float(self.upper) + 1.5, 2);
            for port in low_ports {
                press +>:Fires:+> shutter(build, self, port);
            }
            build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(self.wide - 4), 6.0, True, "This door is opened elsewhere");
        } else {
            auto_shutters(build, dice, self, low_ports, 0.7);
        }
        # Topping the stair, guards appear on the gallery and upstairs.
        topped = build.touch(float(hx), float(self.wide - 4), float(self.upper), float(hx + 3), float(self.wide - 1), float(self.upper + 6));
        spots = [[float(hx) + 1.5, 3.5]];
        if self.storeys == 2 {
            spots.append([float(hx) - 4.5, float(middle) + 0.5]);
        }
        guards(build, topped, spots, self.upper, WARE2_FOES.squad(dice, self.danger, 2, True), 0.0);
        build.foe(3.5, float(middle) + 0.5, 0, "monster_infantry", 0.0, patrol=[[3.5, float(middle) + 0.5], [float(hx) + 4.5, float(middle) + 0.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 5.0, 0, WARE2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 6.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(hx) + 0.1, 2.5, 5.0, 0, 5.0);
    }
}

"""A hall, a deck over its far half, crates riding a belt up an incline
from the floor to the deck; power switches that start it."""
node CrateIncline(Prefab) {
    has deck: int = 9,
        deck_x: int = 16,
        by_lift: bool = False,
        powered: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crate incline";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.deck = dice.between(14, 16);
        self.long = dice.between(34, 37);
        self.wide = dice.between(19, 21);
        self.deck_x = self.long - dice.between(11, 13);
        self.tall = self.deck + dice.between(12, 14);
        self.by_lift = dice.chance(0.45);
        self.powered = dice.chance(0.65);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=middle, floor=self.deck),
            Port(face=1, along=float(self.long - 5), floor=self.deck),
            Port(face=3, along=float(self.deck_x + 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.deck);
        # The deck over the far part of the floor, on pillars.
        build.solid(self.deck_x, 1, self.deck - 1, self.long - 1, self.wide - 1, self.deck);
        for y in range(4, self.wide - 3, 5) {
            build.solid(self.deck_x, y, 0, self.deck_x + 1, y + 1, self.deck - 1);
        }
        # The incline: a belt two cells wide up the near side wall from the
        # floor to the deck, crates riding up it (once the power is on).
        bx = self.deck_x - self.deck;
        stair(build, bx, 1, 0, 0, self.deck, 2);
        crates: list[Cue] = [];
        for index in range(2) {
            crates.append(build.train([2.0, 2.0, 2.0], [[float(bx), 1.0, 1.0], [float(self.deck_x - 2), 1.0, float(self.deck)], [float(self.deck_x) + 1.0, 1.0, float(self.deck)]], float(40 + index * 15), 1.0 + float(index), self.powered));
        }
        # A flat belt under the deck along the far side wall, crates riding
        # it.
        build.solid(self.deck_x + 1, self.wide - 3, 0, self.long - 1, self.wide - 1, 2);
        belt_crates(build, dice, self.deck_x + 1, self.long - 1, self.wide - 3, 2, 2);
        # Up to the deck: a stair along the far side wall, or a lift called
        # down by the button beside it.
        if self.by_lift {
            build.push(float(self.deck_x) - 4.5, float(self.wide - 1), 1.0, 3) +>:Fires:+> called_lift(build, self.deck_x - 3, self.wide - 5, self.deck_x, self.wide - 2, 0, self.deck);
            keep_row(build, hall, self.deck_x, self.wide - 5, self.deck, 0, 3);
        } else {
            stair(build, self.deck_x - self.deck, self.wide - 4, 0, 0, self.deck, 3);
            keep_row(build, hall, self.deck_x, self.wide - 4, self.deck, 0, 3);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        if self.powered {
            # The power: a switch on the deck and one on the wall under it,
            # both wanted; then the belt starts, the ways below open, panels
            # spark, and guards come up to look.
            power = build.tally(2, "One more switch to throw");
            build.push(float(self.long - 1), float(middle) + 3.5, float(self.deck) + 1.5, 2) +>:Fires:+> power;
            build.push(float(self.long - 1), float(middle) - 4.5, 1.5, 2) +>:Fires:+> power;
            for crate in crates {
                power +>:Fires:+> crate;
            }
            power +>:Fires:+> build.objective("Power restored to this warehouse");
            low_ports = [port for port in self.taken if port.floor == 0];
            for port in low_ports {
                power +>:Fires:+> shutter(build, self, port);
            }
            later = build.delay(1.5);
            power +>:Fires:+> later;
            later +>:Fires:+> build.sparks(float(self.deck_x) - 0.2, float(middle) + 0.5, float(self.deck) - 2.0, 2);
            guards(build, later, [[float(self.deck_x) + 3.5, float(middle) + 0.5], [6.5, float(self.wide) - 6.5]], 0, WARE2_FOES.squad(dice, self.danger, 2, True), 0.0);
            build.touch(float(self.long - 4), float(middle - 3), 0.0, float(self.long - 1), float(middle + 3), 6.0, True, "There is no power to this door");
            auto_shutters(build, dice, self, [port for port in self.taken if port.floor != 0], 0.5);
        } else {
            auto_shutters(build, dice, self, self.taken, 0.6);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 0.5, self.deck, WARE2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(4.5, float(middle) + 2.5, 0, "monster_parasite", 0.0, patrol=[[4.5, float(middle) + 2.5], [float(self.long) - 3.5, float(middle) + 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.deck_x) + 2.5 + float(index) * 3.0, 4.5 + float(index % 2) * 8.0, 0, WARE2_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 5.5, 3.5, self.deck, "ammo_bullets", "q2");
        build.supply(2.5, 4.5, 0, Q2_HEALTH, "q2");
        blast_crate(build, self.deck_x + 7, 5, 0);
    }
}

"""A storeroom of racks walked along their tops, planks across between; a
stair to them that rises out of the floor."""
node StorageRacks(Prefab) {
    has rack: int = 6,
        rising: bool = True,
        far_stair: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Storage racks";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(30, 33);
        self.wide = dice.between(24, 26);
        self.rack = dice.between(6, 8);
        self.tall = self.rack + 22;
        self.rising = dice.chance(0.7);
        self.far_stair = not self.rising or dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.rack),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.rack),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        store = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(store, self.rack);
        # Racks along x, three cells deep, the outer two against the walls;
        # planks across their tops between them at both ends; a stair at
        # each end climbing to them.
        rx0 = self.rack + 2;
        rx1 = self.long - self.rack - 2;
        rows = [1, middle - 1, self.wide - 4];
        for y0 in rows {
            build.solid(rx0, y0, 0, rx1, y0 + 3, self.rack);
        }
        for x in [rx0, rx1 - 3] {
            build.solid(x, 4, self.rack - 1, x + 3, self.wide - 4, self.rack);
        }
        # The near stair: one that rises out of the floor when the button on
        # the near wall is pressed, or one that stands.
        if self.rising {
            steps = build.rising_steps(2, 1, 0, 0, self.rack, 3);
            press = build.push(1.0, 5.5, 1.5, 0);
            press +>:Fires:+> steps;
            # Guards appear on the racks as it rises.
            guards(build, press, [[float(self.long // 2) + 0.5, 2.5], [float(self.long // 2) - 4.5, float(self.wide) - 2.5]], self.rack, WARE2_FOES.squad(dice, self.danger, 2), 180.0);
            build.touch(2.0, 4.0, 0.0, float(rx0), 8.0, 6.0, True, "The stair is worked from the wall");
        } else {
            stair(build, 2, 1, 0, 0, self.rack, 3);
        }
        if self.far_stair {
            stair(build, self.long - 3, self.wide - 4, 0, 2, self.rack, 3);
        }
        # Crates riding a belt along the middle rack's top; crates on the
        # others, a blasting crate among them.
        belt_crates(build, dice, rx0 + 4, rx1 - 4, middle, self.rack, 2);
        crane(build, self.long // 2 + 2, 2, self.wide - 4, self.rack + 7);
        build.solid(rx0 + 2, self.wide - 3, self.rack, rx0 + 4, self.wide - 1, self.rack + 2);
        blast_crate(build, rx1 - 4, 1, self.rack);
        build.doorway(store, self.enter);
        for port in self.taken {
            build.doorway(store, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        for index in range(dice.between(3, 4)) {
            build.foe(float(rx0 + 2 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -2.5), 0, WARE2_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(rx0) + 0.5, float(self.wide) - 3.5, self.rack, "monster_infantry", 0.0, patrol=[[float(rx0) + 0.5, float(self.wide) - 3.5], [float(rx1) - 1.5, float(self.wide) - 3.5]]);
        build.foe(float(rx1) - 6.5, 2.5, self.rack, WARE2_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(rx0) + 1.5, float(middle) + 0.5, self.rack, Q2_ARMOR, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(rx0) - 0.2, float(middle) + 0.5, 3.0, 2, 5.0);
    }
}

"""An upper room on a freight platform that sinks a storey into the hall
below; a stair or a lift back up."""
node FreightDrop(Prefab) {
    has drop: int = 13,
        room_x: int = 14,
        by_stair: bool = True,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Freight drop";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.drop = dice.between(17, 20);
        self.long = dice.between(self.drop + 10, self.drop + 12);
        self.wide = dice.between(18, 20);
        self.room_x = dice.between(14, 15);
        self.by_stair = dice.chance(0.55);
        self.tall = 14;
        self.low = -self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [
            Port(face=0, along=middle - 2.0, floor=-self.drop),
            Port(face=3, along=float(self.long - 5), floor=-self.drop),
            Port(face=3, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bottom = -self.drop;
        # The upper room, and the hall a storey under it and beyond.
        upper = build.room(1, 1, 0, self.room_x, self.wide - 1, self.tall, variant=dice.below(3));
        hall = build.room(1, 1, bottom, self.long - 1, self.wide - 1, bottom + 15, variant=dice.below(3));
        build.level(hall, bottom);
        # The freight platform: a block six cells square filling its shaft
        # from the upper floor down to the hall's, sinking to the hall when
        # its button is pressed.
        px = self.room_x - 7;
        py = middle - 4;
        build.room(px, py, bottom, px + 6, py + 6, 0);
        platform = build.sinking(float(px), float(py), float(px + 6), float(py + 6), 0, self.drop);
        press = post_button(build, px, py - 1, 0, 1);
        press +>:Fires:+> platform;
        for x in range(px, px + 6) {
            build.keep(upper, x, py - 1, 0);
            build.keep(upper, x, py + 6, 0);
        }
        for y in range(py, py + 6) {
            build.keep(upper, px - 1, y, 0);
            build.keep(upper, px + 6, y, 0);
        }
        build.touch(float(px), float(py), 0.0, float(px + 6), float(py + 6), 6.0, True, "Use the switch to lower the platform");
        # Back up: a stair along the hall's side wall rising into a well up
        # to the upper room, or a lift called down.
        if self.by_stair {
            sx = 2;
            build.room(sx, self.wide - 4, bottom, sx + self.drop + 1, self.wide - 1, bottom + 9);
            build.widen(upper, sx, self.wide - 4, bottom + 9, sx + self.drop + 1, self.wide - 1, 0);
            for step in range(self.drop) {
                x = sx + self.drop - step;
                build.solid(x, self.wide - 4, bottom, x + 1, self.wide - 1, bottom + step + 1);
            }
            build.solid(1, self.wide - 4, bottom, sx + 1, self.wide - 1, 0);
            keep_row(build, upper, sx + 1, self.wide - 5, 0, 1, 3);
        } else {
            lx = self.room_x - 4;
            build.room(lx, self.wide - 5, bottom, lx + 3, self.wide - 2, 0);
            post_button(build, lx - 1, self.wide - 6, bottom, 1) +>:Fires:+> called_lift(build, lx, self.wide - 5, lx + 3, self.wide - 2, bottom, 0);
            keep_row(build, upper, lx, self.wide - 6, 0, 1, 3);
            for y in range(self.wide - 5, self.wide - 2) {
                build.keep(upper, lx - 1, y, 0);
            }
        }
        build.doorway(upper, self.enter);
        for port in self.taken {
            build.doorway(hall if port.floor == bottom else upper, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        # What waits in the hall wakes as the platform goes down; charges go
        # off as it lands.
        guards(build, press, [[float(self.long) - 4.5, float(middle) + 3.5], [float(self.long) - 6.5, float(middle) + 0.5]], bottom, WARE2_FOES.squad(dice, self.danger, 2, True), 180.0);
        landing = build.delay(float(self.drop) * 0.27);
        press +>:Fires:+> landing;
        charges(build, landing, [[float(px) - 1.5, float(py) - 1.5, float(bottom) + 2.0], [float(px + 7) + 0.5, float(py + 7) + 0.5, float(bottom) + 2.0]], 0.4);
        build.solid(self.room_x + 2, 4, bottom, self.long - 2, 7, bottom + 2);
        belt_crates(build, dice, self.room_x + 2, self.long - 2, 4, bottom + 2, 2);
        build.foe(float(self.room_x) + 4.5, 8.5, bottom, "monster_parasite", 0.0, patrol=[[float(self.room_x) + 4.5, 8.5], [float(self.long) - 3.5, 8.5]]);
        build.foe(3.5, 3.5, 0, WARE2_FOES.pick(dice, self.danger), 0.0);
        build.supply(3.5, float(middle) + 3.5, 0, "ammo_bullets", "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, bottom, Q2_HEALTH, "q2");
        sparking(build, float(self.room_x) - 0.2, float(middle) + 0.5, float(bottom) + 6.0, 0, 4.0);
    }
}

"""The key room: a loading floor, a low store of racks through a wall, the
foreman's office over the store up a stair hall, the key on his desk."""
node ForemanOffice(Prefab) {
    has key: str = "key_silver",
        office: int = 9,
        by_lift: bool = False,
        glass: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Foreman office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(30, 33);
        self.wide = dice.between(22, 24);
        self.office = dice.between(9, 10);
        self.tall = self.office + 10;
        self.by_lift = dice.chance(0.4);
        self.glass = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide + 4) // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = 4;
        middle = (self.wide + 4) // 2;
        ox = self.long - 13;
        # The loading floor; through the wall at `ox` the low store, stepped
        # up into, and the office over it.
        floor_room = build.room(1, side + 1, 0, ox, self.wide - 1, self.tall, variant=dice.below(3));
        store = build.room(ox + 1, side + 1, 0, self.long - 1, self.wide - 1, self.office - 1, variant=dice.below(3));
        upstairs = build.room(ox + 1, side + 1, self.office, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(upstairs, self.office);
        build.doorway(floor_room, self.enter);
        build.widen(store, ox, middle - 2, 1, ox + 1, middle + 2, 7);
        # The office's window over the loading floor, and its door at the
        # head of the way up.
        build.widen(upstairs, ox, middle - 2, self.office + 2, ox + 1, middle + 2, self.office + 5);
        if self.glass {
            build.breakable(float(ox), float(middle - 2), float(self.office + 2), float(ox + 1), float(middle + 2), float(self.office + 5), 10);
        }
        build.widen(upstairs, ox, self.wide - 4, self.office, ox + 1, self.wide - 1, self.office + 6);
        for y in range(self.wide - 4, self.wide - 1) {
            build.keep(upstairs, ox, y, self.office);
            build.keep(upstairs, ox + 1, y, self.office);
        }
        # Up to it: a stair hall walled off the floor, or a lift called down
        # in a bay of its own.
        if self.by_lift {
            build.solid(ox - 5, self.wide - 5, 0, ox, self.wide - 4, self.tall);
            build.push(float(ox) - 4.5, float(self.wide - 1), 1.0, 3) +>:Fires:+> called_lift(build, ox - 3, self.wide - 4, ox, self.wide - 1, 0, self.office);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(floor_room, ox - 1, y, self.office);
            }
            belt_end = ox - 6;
        } else {
            build.solid(ox - self.office, self.wide - 5, 0, ox, self.wide - 4, self.tall);
            stair(build, ox - self.office, self.wide - 4, 0, 0, self.office, 3);
            belt_end = ox - self.office - 1;
        }
        # The store's racks, floor to roof, a way round alternate ends.
        for (index, x) in enumerate([ox + 4, ox + 8]) {
            if index % 2 == 0 {
                build.solid(x, side + 1, 0, x + 1, self.wide - 4, self.office - 1);
            } else {
                build.solid(x, side + 4, 0, x + 1, self.wide - 1, self.office - 1);
            }
        }
        # The desk, the key beside it; taking it opens the closets in the
        # floor's near wall and brings guards into the store.
        build.solid(self.long - 3, middle - 2, self.office, self.long - 2, middle + 2, self.office + 2);
        taken = key_cue(build, self.key, float(self.long) - 4.0, float(middle) + 0.5, self.office);
        closets(build, taken, [3, 8, 13] if dice.chance(0.5) else [4, 11], side, -1, 0, WARE2_FOES.squad(dice, self.danger, 3, True), 90.0);
        guards(build, taken, [[float(ox) + 2.5, float(side) + 2.5]], 0, WARE2_FOES.squad(dice, self.danger, 1), 0.0);
        taken +>:Fires:+> build.objective("Key taken: get it to its door");
        # A belt along the floor's far wall, crates riding it.
        build.solid(2, self.wide - 3, 0, belt_end, self.wide - 1, 2);
        belt_crates(build, dice, 2, belt_end, self.wide - 3, 2, 2);
        # Crates on the floor.
        for spot in [[6, middle + 2], [11, side + 3], [ox - 6, side + 2]] {
            build.solid(spot[0], spot[1], 0, spot[0] + 2, spot[1] + 2, dice.between(2, 3));
        }
        build.foe(float(self.long) - 4.0, float(side) + 2.5, self.office, WARE2_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, float(middle) - 3.5, 0, "monster_infantry", 0.0, patrol=[[4.5, float(middle) - 3.5], [float(ox) - 2.5, float(middle) - 3.5]]);
        build.foe(float(self.long) - 2.5, float(self.wide) - 3.5, 0, WARE2_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(ox) + 6.5, float(self.wide) - 3.5, 0, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
        sparking(build, float(self.long) - 1.2, float(middle) + 3.5, float(self.office) + 3.0, 2, 6.0);
    }
}

"""The end: big bay doors out to a yard under the sky, containers along its
walls, the way out on a platform in its middle."""
node FreightBay(Prefab) {
    has key: str = "",
        deck: int = 5,
        by_lift: bool = True,
        tall: int = 46;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Freight bay" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WARE2;
        self.district = level_district(WARE2);
        self.long = dice.between(32, 35);
        self.wide = dice.between(23, 25);
        self.deck = dice.between(5, 6);
        self.tall = dice.between(50, 54);
        self.by_lift = dice.chance(0.6);
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
        bay = gate_yard(build, [dice.below(3), dice.below(3)], self.enter, self.long, self.wide, wall, 0, self.tall, self.key, 4);
        build.level(bay, self.deck);
        # The platform in the yard's middle.
        px0 = wall + 9;
        px1 = self.long - 6;
        build.solid(px0, middle - 4, 0, px1, middle + 4, self.deck);
        build.way_out(float(px0 + px1) * 0.5, float(middle) + 0.5, self.deck);
        # Containers stood along the yard's -y wall; a belt with riding crates
        # along its +y wall.
        for x in range(wall + 4, self.long - 5, 7) {
            build.solid(x, 1, 0, x + 5, 4, 6);
        }
        build.solid(wall + 3, self.wide - 3, 0, self.long - 2, self.wide - 1, 2);
        belt_crates(build, dice, wall + 3, self.long - 2, self.wide - 3, 2, 2);
        crane(build, wall + 6, 2, self.wide - 6, 15);
        # Up to it: a lift called down by its button (which sets off charges
        # about the yard one after another), or a stair.
        if self.by_lift {
            press = post_button(build, px0 - 4, middle - 3, 0, 2);
            press +>:Fires:+> called_lift(build, px0 - 3, middle - 2, px0, middle + 1, 0, self.deck);
            charges(build, press, [[float(wall) + 3.5, 5.5, 1.0], [float(wall) + 8.5, float(self.wide) - 5.5, 1.0], [float(px1) + 2.5, float(middle) + 0.5, 1.0]], 1.2);
            keep_row(build, bay, px0, middle - 2, self.deck, 0, 3);
        } else {
            stair(build, px0 - self.deck, middle - 2, 0, 0, self.deck, 3);
            on_deck = build.touch(float(px0), float(middle - 4), float(self.deck), float(px0 + 2), float(middle + 4), float(self.deck + 6));
            charges(build, on_deck, [[float(wall) + 3.5, 5.5, 1.0], [float(wall) + 8.5, float(self.wide) - 5.5, 1.0]], 0.6);
            keep_row(build, bay, px0, middle - 2, self.deck, 0, 3);
        }
        blast_crate(build, wall + 5, self.wide - 6, 0);
        # Coming in, guards appear on the platform.
        come_in = build.touch(float(wall + 1), float(middle - 4), 0.0, float(wall + 3), float(middle + 4), 6.0);
        guards(build, come_in, [[float(px0) + 3.5, float(middle) + 2.5], [float(px1) - 2.5, float(middle) - 2.5]], self.deck, WARE2_FOES.squad(dice, self.danger, 2, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, WARE2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 4.5, float(middle) + 5.5, 0, "monster_parasite", 0.0, patrol=[[float(wall) + 4.5, float(middle) + 5.5], [float(self.long) - 3.5, float(middle) + 5.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""ware2's stretches: [name, role]."""
glob WARE2_STRETCHES: list[list[str]] = [
         ["trucks", "start"],
         ["offices", "flow"],
         ["incline", "flow"],
         ["incline", "hub"],
         ["racks", "hub"],
         ["racks", "flow"],
         ["drop", "flow"],
         ["foreman", "keyroom"],
         ["freight", "end"],
         ["freight", "gate"]
     ];

"""One of ware2's stretches by its name."""
def make_ware2(name: str, key: str) -> Prefab {
    if name == "trucks" {
        return TruckBay();
    }
    if name == "offices" {
        return OfficeRow();
    }
    if name == "incline" {
        return CrateIncline();
    }
    if name == "racks" {
        return StorageRacks();
    }
    if name == "drop" {
        return FreightDrop();
    }
    if name == "foreman" {
        return ForemanOffice(key=key if key else "key_silver");
    }
    return FreightBay(key=key);
}
