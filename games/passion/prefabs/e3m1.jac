"""Prefabs drawn from e3m1, Termination Central: a base of metal over pits
and rivers of slime, crossed on walkways, bridges and teleporters, lifts up
to its decks and galleries, doors that slam shut on whoever lingers, the
gold key on a dais in slime reached by teleporter, and enforcers let out
at the end. Raised in e3m1's own palette.

- `TerminationEntry`: the start. A deck high over a hall, a stair or a lift
  down, a pit of slime across the hall crossed on a walkway, by teleporters
  or on a bridge drawn out when a button across it is shot; a balcony over
  the far floor ridden up to by a lift. Walking by under the deck opens a
  wall on a stash (e3m1's secret doors opened by a touch).
- `SlimeWorks`: a works over a sea of slime in ponds, walkways between
  them in a cross or an H, a gallery along its south wall ridden up to by
  a lift; each way on from the far landing behind its own door, opened by
  a button at the end of a walkway (e3m1's two switches); a teleporter off
  the gallery's end in some (a hub).
- `CrusherHall`: a tunnel along a hall's side, doors across it that slam
  open and shut, windows down into the pit of the hall beside it, a stair
  or a lift down into the pit and a lift up out of it at its far end, a
  gallery over the pit's far side ridden up to by a lift;
  what keeps the pit wakes as the player passes the windows.
- `TeleportRelay`: a river of slime across a hall, crossed by teleporters
  (and in some by a bridge drawn out when a button is shot), a teleporter
  in the slime that takes whoever falls in back to the near bank; in some
  a ledge over the far bank ridden up to by a lift, running on as a
  walkway high over the river to drop from onto the near bank.
- `GoldTerminal`: the key room. The key on a dais in a pool of slime, a
  teleporter onto it and one back, a balcony along the wall over the pool;
  taking the key opens the closets and brings enforcers in.
- `TerminationExit`: the end. A door (a key's, as a gate) into a room, a
  moat of slime round a platform, a walkway out to the slipgate on it, a
  gallery over the moat; coming onto the walkway lets the enforcers out of
  their closets (e3m1's doors slammed open at the end)."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires, RockWant }
import from ..kits { level_district, kit_of }
import from ..cast { origin_text }
import from .roster { FoeMix }
import from .common { stair, lift }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_stash, e2m4_wall_opens }

glob E3M1: str = "q1:e3m1";

"""e3m1's foes: grunts and dogs, enforcers growing with the danger."""
glob E3M1_FOES: FoeMix = FoeMix(light=["monster_army", "monster_army", "monster_dog"], strong=["monster_enforcer"], heavy_light=["monster_enforcer", "monster_army"]);

"""A door across a way that slams open when touched and shut a moment
later, hurting whoever it shuts on: a door of the prefab's cells x0..x1,
y0..y1 from lift `z`, `high` lifts tall, sinking into the floor fast."""
def e3m1_slam(build: Raising, x0: float, y0: float, x1: float, y1: float, z: int, high: int) {
    fields = {"classname": "func_door", "angle": "-2", "speed": "500", "wait": "1", "lip": "2", "dmg": "20"};
    build.put_box(fields, x0, y0, float(z), x1, y1, float(z + high), kit_of(build.district).door);
    corners = build.box_units(x0, y0, float(z - high), x1, y1, float(z));
    build.rocks.append(RockWant(low=corners[0], high=corners[1]));
    build.casting.doors += 1;
}

"""A teleporter filling the box of the prefab's cells x0..x1, y0..y1 from
lift z0 to z1 (a pit's floor), sending whoever falls in to (tx, ty) on
lift `tz`, facing a heading of the prefab's own."""
def e3m1_rescue(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, tx: float, ty: float, tz: int, angle: float) {
    name = build.name("rescue" + str(len(build.casting.items)));
    build.put_box({"classname": "trigger_teleport", "target": name}, x0, y0, z0, x1, y1, z1, "trigger");
    arrive = build.units(tx, ty, float(tz));
    build.casting.put({"classname": "info_teleport_destination", "targetname": name, "origin": origin_text(arrive.x, arrive.y, arrive.z + 32.0), "angle": str(build.heading(angle))});
}

"""The start: a deck high over a hall, a pit of slime across the hall, a
balcony over the far floor."""
node TerminationEntry(Prefab) {
    has deck: int = 9,
        cross: int = 0,
        stairs: bool = True,
        nook: bool = True,
        high_walk: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Termination entry";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(18, 22);
        self.cross = dice.below(3);
        self.stairs = dice.chance(0.5);
        self.nook = dice.chance(0.6);
        self.high_walk = dice.chance(0.7);
        self.tall = 19;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.deck);
        self.leaves = [Port(face=0, along=middle, floor=self.deck), Port(face=3, along=float(self.long - 7), floor=0), Port(face=1, along=float(self.long - 7), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deck;
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, d);
        # The deck the run begins on, a slab over the hall's near end.
        build.solid(1, 1, d - 1, 8, self.wide - 1, d);
        for y in [4, self.wide - 5] {
            build.solid(5, y, 0, 6, y + 1, d - 1);
        }
        if self.stairs {
            stair(build, 8, self.wide - 2, 0, 3, d, 3);
            for y in range(self.wide - 2 - d, self.wide + 1 - d) {
                build.keep(hall, 7, y, d);
            }
        } else {
            lift(build, 8, 2, 11, 5, 0, d);
            for y in range(2, 5) {
                build.keep(hall, 7, y, d);
                build.keep(hall, 11, y, 0);
            }
        }
        # The pit of slime across the hall, steps up out of it at its ends;
        # a walkway over it, teleporters, or a bridge a shot button draws.
        px0 = 13;
        px1 = self.long - 10;
        build.pool(px0, 1, -3, px1, self.wide - 1, 0, 3, False, True, True);
        if self.cross == 0 {
            build.solid(px0, middle - 1, -3, px1, middle + 2, 0);
        } elif self.cross == 1 {
            build.teleporter(float(px0) - 1.5, float(middle) + 0.5, 0, float(px1) + 3.5, float(middle) + 0.5, 0, 0.0);
            build.teleporter(float(px1) + 2.5, float(middle) - 3.5, 0, 3.5, float(middle) - 3.5, d, 180.0);
        } else {
            shot = build.push(float(self.long - 1), float(middle) + 4.5, 4.0, 2, True);
            shot +>:Fires:+> build.drawn(float(px0), float(middle - 1), float(px1), float(middle + 2), 0, 4);
        }
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, px0 - 1, y, 0);
            build.keep(hall, px1, y, 0);
        }
        # In some a walkway high along the north wall over the slime, from
        # the deck to the balcony.
        if self.high_walk {
            build.solid(8, self.wide - 5, d - 1, self.long - 6, self.wide - 1, d);
            for y in range(self.wide - 5, self.wide - 1) {
                build.keep(hall, 7, y, d);
                build.keep(hall, self.long - 6, y, d);
            }
        }
        # The balcony over the far floor, a lift up to it.
        build.solid(self.long - 6, 1, d - 1, self.long - 1, self.wide - 1, d);
        lift(build, self.long - 9, 2, self.long - 6, 5, 0, d);
        for y in range(2, 5) {
            build.keep(hall, self.long - 6, y, d);
            build.keep(hall, self.long - 10, y, 0);
        }
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Walking by under the deck opens a wall on a stash.
        if self.nook {
            build.solid(1, 1, 0, 5, 5, d - 1);
            build.room(2, 2, 0, 4, 4, 4);
            passing = build.touch(5.0, 1.0, 0.0, 8.0, 6.0, 6.0, False);
            passing +>:Fires:+> e2m4_wall_opens(build, 4.0, 2.0, 0.0, 5.0, 4.0, 4.0, 2);
            build.secret(2.0, 2.0, 0.0, 4.0, 4.0, 3.0);
            build.supply(3.0, 3.0, 0, "item_artifact_super_damage");
        }
        # Dogs under the deck wake as the player comes down; the balcony's
        # enforcers as the player reaches the far floor; a grunt walks it.
        down = build.touch(8.0, 1.0, 0.0, 12.0, float(self.wide - 1), 6.0);
        dogs = build.waiting();
        down +>:Fires:+> dogs;
        for index in range(dice.between(1, 2)) {
            build.foe(3.5, float(middle) - 2.5 + float(index) * 5.0, 0, "monster_dog", 0.0, waits=dogs);
        }
        far = build.touch(float(px1), 1.0, 0.0, float(px1 + 2), float(self.wide - 1), 6.0);
        guard = build.waiting();
        far +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, float(middle) - 2.5 + float(index) * 5.0, d, E3M1_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        }
        build.foe(float(self.long) - 8.5, 6.5, 0, "monster_army", 90.0, patrol=[[float(self.long) - 8.5, 6.5], [float(self.long) - 8.5, float(self.wide) - 6.5]]);
        build.foe(10.5, float(middle) + 0.5, 0, E3M1_FOES.pick(dice, self.danger), 0.0, patrol=[[10.5, 6.5], [10.5, float(self.wide) - 6.5]]);
        build.start(2.5, float(middle) + 0.5, d, 0.0);
        build.supply(2.5, float(middle) - 1.5, d, "item_shells");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, d, "item_health");
        build.supply(float(px1) + 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A works over ponds of slime, walkways between them, a gallery along the
south wall; each way on behind its own door, opened by a button at a
walkway's end."""
node SlimeWorks(Prefab) {
    has gallery: int = 9,
        layout: int = 0,
        tele: bool = True,
        stash: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime works";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(24, 28);
        self.layout = dice.below(2);
        self.tele = dice.chance(0.5);
        self.stash = dice.chance(0.5);
        self.tall = self.gallery + dice.between(10, 12);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=3.0, floor=self.gallery), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        middle = self.wide // 2;
        mx = self.long // 2 - 1;
        works = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(works, g);
        # The ponds between the walkways: one across the works and one
        # along it (a cross), or two along it (an H).
        xs = [[6, mx], [mx + 3, self.long - 7]];
        ys = [[1, middle - 1], [middle + 2, self.wide - 1]] if self.layout == 0 else [[1, 7], [10, self.wide - 10], [self.wide - 7, self.wide - 1]];
        for span_x in xs {
            for span_y in ys {
                build.pool(span_x[0], span_y[0], -3, span_x[1], span_y[1], 0, 3);
            }
        }
        # The galleries along the south and north walls over the ponds, a
        # walkway across between them over the walkway below, a lift up from
        # the near landing.
        build.solid(1, 1, g - 1, self.long - 1, 6, g);
        build.solid(1, self.wide - 6, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(mx, 6, g - 1, mx + 3, self.wide - 6, g);
        for x in range(mx, mx + 3) {
            build.keep(works, x, 5, g);
            build.keep(works, x, self.wide - 6, g);
        }
        lift(build, 2, 7, 5, 10, 0, g);
        for x in range(2, 5) {
            build.keep(works, x, 6, g);
            build.keep(works, x, 11, 0);
        }
        if self.tele {
            build.teleporter(float(self.long) - 4.0, 3.0, g, 3.5, float(middle) + 3.5, 0, 0.0);
        }
        build.doorway(works, self.enter);
        # Each way on from the far landing behind its own door, opened by a
        # button at an end of the walkway across the works.
        spots = [[float(mx) + 1.5, 1.0, 1], [float(mx) + 1.5, float(self.wide - 1), 3]];
        doors = 0;
        for port in self.taken {
            build.doorway(works, port);
            if port.floor != 0 {
                continue;
            }
            spot = spots[doors % 2];
            press = build.push(spot[0], spot[1], 1.2, int(spot[2]));
            doors += 1;
            low = port.along - 2.0;
            if port.face == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), low, float(self.long - 1), low + 4.0, 0, 8, "This door opens elsewhere...");
            } elif port.face == 1 {
                press +>:Fires:+> e2m4_bars(build, low, float(self.wide - 2), low + 4.0, float(self.wide - 1), 0, 8, "This door opens elsewhere...");
            } else {
                press +>:Fires:+> e2m4_bars(build, low, 1.0, low + 4.0, 2.0, 0, 8, "This door opens elsewhere...");
            }
        }
        # Grunts walk the walkways; enforcers keep the far landing, waking as
        # the player sets out; one keeps the gallery.
        build.foe(7.5, float(middle) + 0.5, 0, "monster_army", 0.0, patrol=[[7.5, float(middle) + 0.5], [float(self.long) - 8.5, float(middle) + 0.5]] if self.layout == 0 else [[7.5, 8.5], [float(self.long) - 8.5, 8.5]]);
        build.foe(float(mx) + 1.5, float(self.wide) - 2.5, 0, "monster_army", 270.0, patrol=[[float(mx) + 1.5, float(self.wide) - 2.5], [float(mx) + 1.5, 6.5]]);
        out = build.touch(6.0, 1.0, 0.0, 8.0, float(self.wide - 1), 6.0);
        guard = build.waiting();
        out +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, float(middle) - 4.5 + float(index) * 4.5, 0, E3M1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(float(self.long) - 8.5, 3.0, g, E3M1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(mx) + 1.5, float(middle) + 0.5, 0, "monster_dog", 180.0);
        if self.stash {
            build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 8);
            e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 1, 0, 3, "item_armor2");
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 6.5, 0, "item_health");
        build.supply(3.0, 3.0, g, "item_health");
        build.supply(3.0, float(middle) - 2.5, 0, "item_shells");
    }
}

"""A tunnel along a hall's side, doors across it that slam open and shut,
windows down into the pit of the hall beside it."""
node CrusherHall(Prefab) {
    has stairs: bool = True,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crusher hall";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(17, 19);
        self.stairs = dice.chance(0.5);
        self.low = -10;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.5, floor=0);
        self.leaves = [Port(face=0, along=3.5, floor=0), Port(face=0, along=float(self.wide - 5), floor=-8), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tunnel = build.room(1, 1, 0, self.long - 1, 6, self.tall, variant=dice.below(3));
        pit = build.room(1, 7, -8, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, -8);
        # Windows from the tunnel down into the pit.
        for x in range(6, self.long - 6, 6) {
            build.widen(pit, x, 6, 2, x + 2, 7, 5);
        }
        # Down into the pit at the tunnel's near end: a stair or a lift; a
        # lift up out of it at the far end.
        build.widen(tunnel, 2, 6, 0, 5, 7, 8);
        if self.stairs {
            stair(build, 2, 14, -8, 3, 8, 3);
        } else {
            lift(build, 2, 7, 5, 10, -8, 0);
            for x in range(2, 5) {
                build.keep(pit, x, 11, -8);
            }
        }
        build.widen(tunnel, self.long - 5, 6, 0, self.long - 2, 7, 8);
        lift(build, self.long - 5, 7, self.long - 2, 10, -8, 0);
        for x in range(self.long - 5, self.long - 2) {
            build.keep(pit, x, 11, -8);
        }
        # A gallery along the pit's north wall over its floor, a lift up to
        # it, a way on from it.
        build.solid(6, self.wide - 5, -1, self.long - 6, self.wide - 1, 0);
        lift(build, 8, self.wide - 8, 11, self.wide - 5, -8, 0);
        for x in range(8, 11) {
            build.keep(pit, x, self.wide - 5, 0);
            build.keep(pit, x, self.wide - 9, -8);
        }
        # The doors across the tunnel that slam open and shut.
        for x in [self.long // 4, self.long // 2, (3 * self.long) // 4] {
            e3m1_slam(build, float(x), 1.0, float(x + 1), 6.0, 0, 8);
        }
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel if port.floor == 0 and port.face != 1 else pit, port);
        }
        # What keeps the pit wakes as the player passes the first window;
        # a grunt walks the tunnel, dogs the pit.
        passing = build.touch(6.0, 1.0, 0.0, 8.0, 6.0, 6.0);
        guard = build.waiting();
        passing +>:Fires:+> guard;
        for index in range(dice.between(2, 4)) {
            build.foe(float(8 + index * 5) + 0.5, float(self.wide) - 3.5 - float(index % 2) * 3.0, -8, E3M1_FOES.pick(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        build.foe(3.5, 3.5, 0, "monster_army", 0.0, patrol=[[3.5, 3.5], [float(self.long) - 3.5, 3.5]]);
        build.foe(7.5, 8.5, -8, "monster_dog", 0.0, patrol=[[7.5, 8.5], [float(self.long) - 7.5, 8.5]]);
        build.foe(float(self.long) - 8.5, float(self.wide) - 3.0, 0, "monster_army", 180.0, patrol=[[float(self.long) - 8.5, float(self.wide) - 3.0], [13.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 3.5, 3.5, 0, E3M1_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long // 2) + 2.5, 3.5, 0, "item_health");
        build.supply(float(self.long) - 6.5, float(self.wide) - 2.5, -8, "item_health");
        build.supply(8.5, float(self.wide) - 2.5, -8, "item_shells");
    }
}

"""A river of slime across a hall, crossed by teleporters, a teleporter in
the slime back to the near bank."""
node TeleportRelay(Prefab) {
    has river: int = 7,
        ledge: bool = True,
        bridged: bool = False,
        stash: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport relay";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 20);
        self.river = dice.between(6, 8);
        self.ledge = dice.chance(0.8);
        self.bridged = dice.chance(0.4);
        self.stash = dice.chance(0.5);
        self.tall = 16 if self.ledge else 13;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        if self.ledge {
            self.leaves = [Port(face=0, along=middle - 2.0, floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=1, along=float(self.long - 3), floor=8)];
        } else {
            self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # The river, steps up out of it onto the near bank, and a teleporter
        # in its slime that takes whoever falls in back to the near bank.
        x0 = 9;
        x1 = x0 + self.river;
        build.pool(x0, 1, -3, x1, self.wide - 1, 0, 3);
        e3m1_rescue(build, float(x0 + 2), 1.0, -3.0, float(x1), float(self.wide - 1), -2.0, 3.5, float(middle) - 2.5, 0, 0.0);
        build.teleporter(5.5, float(middle) + 0.5, 0, float(x1) + 5.0, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(x1) + 3.0, 3.5, 0, 3.0, 3.0, 0, 180.0);
        if self.bridged {
            shot = build.push(float(self.long - 1), float(middle) + 3.5, 6.0, 2, True);
            shot +>:Fires:+> build.drawn(float(x0), float(middle - 1), float(x1), float(middle + 2), 0, 4);
            for y in range(middle - 1, middle + 2) {
                build.keep(hall, x0 - 1, y, 0);
                build.keep(hall, x1, y, 0);
            }
        }
        # The ledge over the far bank's north side, a lift up to it.
        if self.ledge {
            build.level(hall, 8);
            build.solid(self.long - 6, self.wide - 6, 7, self.long - 1, self.wide - 1, 8);
            lift(build, self.long - 5, self.wide - 9, self.long - 2, self.wide - 6, 0, 8);
            for x in range(self.long - 5, self.long - 2) {
                build.keep(hall, x, self.wide - 6, 8);
                build.keep(hall, x, self.wide - 10, 0);
            }
            # The ledge runs on as a walkway high along the north wall back
            # over the river, its near end open to drop from.
            build.solid(6, self.wide - 5, 7, self.long - 6, self.wide - 1, 8);
            for x in range(6, 9) {
                build.keep(hall, x, self.wide - 6, 8);
            }
            build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 8, E3M1_FOES.pick(dice, self.danger, True), 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Dogs wake as the player comes through to the far bank; a grunt
        # walks it.
        come = build.touch(float(x1) + 3.0, float(middle - 2), 0.0, float(x1) + 7.0, float(middle + 3), 6.0);
        pack = build.waiting();
        come +>:Fires:+> pack;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5 - float(index % 2) * 3.0, 3.5 + float(index) * 3.0, 0, "monster_dog" if index > 0 else E3M1_FOES.pick(dice, self.danger, True), 180.0, waits=pack);
        }
        build.foe(float(x1) + 2.5, float(self.wide) - 2.5, 0, "monster_army", 0.0, patrol=[[float(x1) + 2.5, float(self.wide) - 2.5], [float(self.long) - 10.5, float(self.wide) - 2.5]]);
        build.foe(4.5, float(self.wide) - 3.5, 0, E3M1_FOES.pick(dice, self.danger), 0.0);
        if self.stash {
            build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 8);
            e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 1, 0, 3, "item_artifact_envirosuit");
        }
        build.supply(2.5, float(middle) + 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 0, "item_spikes");
    }
}

"""The key room: the key on a dais in a pool of slime, a teleporter onto
it and one back, a balcony over the pool."""
node GoldTerminal(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        balcony: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold terminal (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.balcony = dice.chance(0.9);
        self.tall = dice.between(15, 17);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 2;
        build.pool(x0, 4, -3, x1, side - 3, 0, 3);
        cx = (x0 + x1) // 2 + 1;
        build.solid(cx - 2, cy - 2, -3, cx + 2, cy + 2, 2);
        build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy), 2, 0.0);
        build.teleporter(float(cx) + 1.0, float(cy) + 1.0, 2, 2.5, 6.5, 0, 180.0);
        # The balcony along the south wall over the pool, a lift up to it.
        if self.balcony {
            build.level(hall, 8);
            build.solid(5, 1, 7, self.long - 1, 8, 8);
            lift(build, 2, 1, 5, 4, 0, 8);
            for y in range(1, 4) {
                build.keep(hall, 5, y, 8);
            }
            build.foe(float(self.long) - 3.5, 2.5, 8, E3M1_FOES.pick(dice, self.danger, True), 180.0, patrol=[[float(self.long) - 3.5, 2.5], [float(x0) + 2.5, 2.5]]);
        }
        # The key; taking it opens the closets along the side wall and brings
        # enforcers in.
        taken = e2m4_key(build, self.key, float(cx) + 1.0, float(cy) - 1.0, 2);
        out = build.waiting();
        taken +>:Fires:+> out;
        for (index, at) in enumerate([2, self.long - 5]) {
            closet = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(closet, at, side, 0, at + 3, side + 1, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0, fields);
            taken +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E3M1_FOES.pick(dice, self.danger, index == 0), 270.0, waits=out);
        }
        late = build.delay(1.5);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 4, -8, "monster_enforcer", 3.5, float(cy) - 2.5, 0, 0.0);
        build.foe(3.0, float(side) - 3.0, 0, E3M1_FOES.pick(dice, self.danger), 0.0, patrol=[[3.0, float(side) - 3.0], [float(x1) - 1.5, float(side) - 1.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(cx) - 1.0, float(cy) + 1.0, 2, "item_health");
    }
}

"""The end: a door into a room, a moat of slime round a platform, a
walkway to the slipgate, enforcers let out of their closets."""
node TerminationExit(Prefab) {
    has key: str = "",
        gallery: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Termination exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M1;
        self.district = level_district(E3M1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gallery = dice.chance(0.9);
        self.tall = dice.between(15, 17);
        self.low = -9;
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 4, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key);
        }
        # The moat round the platform: a ring of slime, the walkway in.
        px0 = wall + 7;
        px1 = self.long - 4;
        build.pool(wall + 4, 4, -3, self.long - 1, self.wide - 7, 0, 3, False, True, True);
        build.solid(px0, middle - 3, -3, px1, middle + 3, 1);
        build.solid(wall + 4, middle - 1, -3, px0, middle + 1, 0);
        for y in range(middle - 1, middle + 1) {
            build.keep(room, wall + 3, y, 0);
        }
        build.way_out(float(px0 + px1) * 0.5, float(middle), 1);
        # The gallery along the south wall over the moat, a lift up.
        if self.gallery {
            build.level(room, 8);
            build.solid(wall + 1, 1, 7, self.long - 1, 4, 8);
            lift(build, wall + 1, 4, wall + 4, 7, 0, 8);
            for x in range(wall + 1, wall + 4) {
                build.keep(room, x, 4, 8);
            }
            for index in range(dice.between(1, 2)) {
                build.foe(float(px0 + index * 5) + 0.5, 2.5, 8, "monster_army", 90.0);
            }
        }
        # Coming onto the walkway lets the enforcers out of the closets
        # behind the room's north wall.
        onto = build.touch(float(wall + 4), float(middle - 1), 0.0, float(wall + 6), float(middle + 1), 6.0);
        out = build.waiting();
        onto +>:Fires:+> out;
        for at in [wall + 6, self.long - 8] {
            closet = build.room(at, self.wide - 3, 0, at + 3, self.wide - 1, 7);
            build.widen(closet, at, self.wide - 4, 0, at + 3, self.wide - 3, 6);
            fields = {"wait": "-1", "speed": "400"};
            build.rising_door(float(at), float(self.wide - 4), 0.0, float(at + 3), float(self.wide - 3), 6.0, fields);
            onto +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, float(self.wide) - 2.0, 0, "monster_enforcer", 270.0, waits=out);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E3M1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px1) - 1.0, float(middle) + 2.0, 1, E3M1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(wall) + 2.5, 2.5, 0, "monster_army", 90.0, patrol=[[float(wall + 5) + 0.5, 2.5], [float(self.long) - 2.5, 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(wall) + 2.5, float(self.wide) - 5.5, 0, "item_shells");
    }
}

"""e3m1's stretches: [name, role]."""
glob E3M1_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["works", "hub"],
         ["works", "flow"],
         ["crusher", "flow"],
         ["relay", "flow"],
         ["relay", "hub"],
         ["terminal", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m1's stretches by its name."""
def make_e3m1(name: str, key: str) -> Prefab {
    if name == "entry" {
        return TerminationEntry();
    }
    if name == "works" {
        return SlimeWorks();
    }
    if name == "crusher" {
        return CrusherHall();
    }
    if name == "relay" {
        return TeleportRelay();
    }
    if name == "terminal" {
        return GoldTerminal(key=key if key else "key_gold");
    }
    return TerminationExit(key=key);
}
