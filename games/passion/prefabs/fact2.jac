"""Prefabs drawn from Quake II's fact2, the Processing Plant, where the
Strogg process their captives: hooks riding their tracks overhead,
steam and sparks from every pipe, presses and grinders over pits of
slime, door after door. An entrance hall of plant doors each opened by
its own switch, a grinder pit walked round on ledges under a gantry, a
hall round a control tower, a hook line of presses over a trench that
three switches stop, the key in a vault, a corridor of doors to the way
out. Raised in fact2's own palette.

- `PlantGate`: the start. An entrance hall, an office on stilts over its
  floor up a stair or a lift, a row of plant doors across its far end,
  each opened by the switch beside it (fact2's doors fired each by its own
  button); hooks riding overhead, steam from the pipes; the objective;
  guards come out of the office as the player comes up; a panel on a
  machine breaks open on a stash (the secret).
- `GrinderPit`: a pit of slime under grinders, walked round on ledges and
  across on a walkway ("Emulsifying flesh"), a gantry along its wall up a
  stair or steps a switch raises; hooks overhead.
- `ControlTower`: a hall round a control tower, a stair, an elevator or
  steps a switch raises up its side, bridges from its top to ways on high
  in two walls; a switch on the tower's top and one on the floor together
  open a locker; ways on below too (a hub).
- `HookLine`: the processing line: presses slamming into a trench of
  slime, hooks riding overhead, a catwalk along the wall; the way on is
  shut until all three of the line's switches are thrown (fact2's
  counters).
- `PlantVault`: the key in a vault behind a door its switch opens; taking
  it opens the closets.
- `DoorCorridor`: the end. A door (a key's, as a gate), a corridor of
  doors (each a key's too, when it is a gate's), grinders in pits beside
  it, the way out at its end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }
import from .minefact { slab, hurt, burning, sparking, stash, charges, port_door, press, crusher }

glob FACT2: str = "q2:fact2";

"""fact2's foes: light and shotgun guards, gunners, infantry, parasites,
gladiators and tanks deeper in."""
def fact2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_parasite"] if heavy else ["monster_soldier_light", "monster_soldier_ss", "monster_gunner"], ["monster_gladiator", "monster_tank"] if heavy else ["monster_infantry"], danger * 0.4 if heavy else danger * 0.7));
}

"""Hooks riding a track under the roof from x0 to x1 along the line y on
lift z and back, `count` of them spaced along it (each a train of its
own)."""
def hooks(build: Raising, x0: float, x1: float, y: float, z: float, count: int) {
    for index in range(count) {
        at = x0 + (x1 - x0) * float(index) / float(count);
        build.train([1.0, 1.0, 2.0], [[at, y, z], [x1, y, z], [x0, y, z]], 40.0, 0.5);
    }
}

"""Steam and sparks from pipes along a wall: a timer each at `points`
([x, y, z] in the prefab's cells), out the way `direction` goes."""
def steam(build: Raising, points: list[list[float]], direction: int) {
    for (index, point) in enumerate(points) {
        sparking(build, point[0], point[1], point[2], direction, 2.5 + float(index));
    }
}

"""The start: an entrance hall, an office on stilts over its floor, a row
of plant doors across its far end, each opened by its own switch."""
node PlantGate(Prefab) {
    has deck: int = 7,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant gate";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 26);
        self.deck = 7;
        self.by_lift = dice.chance(0.4);
        self.tall = dice.between(15, 17);
        self.low = -1;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy - 4), floor=0);
        self.leaves = [
            Port(face=0, along=5.0, floor=0),
            Port(face=0, along=float(cy), floor=0),
            Port(face=0, along=float(self.wide - 5), floor=0),
            Port(face=1, along=5.0, floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        d = self.deck;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, d);
        # The office on stilts over the near end of the floor.
        slab(build, 1, self.wide - 7, self.long - 4, self.wide - 1, d, 1);
        for x in range(3, self.long - 5, 6) {
            build.solid(x, self.wide - 7, 0, x + 1, self.wide - 6, d - 1);
        }
        # Up by a cargo lift at its far end, and (or not) a stair at its near
        # end.
        lift(build, self.long - 7, self.wide - 10, self.long - 4, self.wide - 7, 0, d);
        for x in range(self.long - 7, self.long - 4) {
            build.keep(hall, x, self.wide - 7, d);
        }
        if not self.by_lift {
            stair(build, 10, self.wide - 7 - d, 0, 1, d, 3);
            for x in range(10, 13) {
                build.keep(hall, x, self.wide - 7, d);
            }
        }
        # A machine by the south wall, a stash behind a panel on it.
        build.solid(12, 1, 0, 16, 5, 5);
        stash(build, 13, 2, 0, 1, Q2_ARMOR);
        build.doorway(hall, self.enter);
        # The plant doors: each way on through the far wall shut, opened by
        # the switch beside it.
        for port in self.taken {
            build.doorway(hall, port);
            if port.face == 0 {
                beside = port.along - 3.5 if port.along < float(cy) - 1.0 else (port.along + 3.5 if port.along < float(cy) + 1.0 else port.along + 3.5);
                trip = build.push(float(self.long - 1), beside, 1.0, 2);
                port_door(build, self.long, self.wide, port, trip);
                trip +>:Fires:+> build.sparks(float(self.long) - 1.2, port.along, 6.0, 2);
            }
        }
        build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(self.wide - 1), 6.0, True, "Each plant door opens from the switch beside it.");
        hooks(build, 3.0, float(self.long - 4), float(cy), float(self.tall - 3), 3);
        steam(build, [[1.1, 3.5, 4.0], [float(self.long) - 1.1, float(cy) - 4.5, 5.0], [16.1, 3.0, 3.0]], 0);
        build.start(3.5, float(cy) - 4.5, 0, 0.0);
        build.supply(3.5, float(cy) - 6.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(cy - 7), 0.0, 5.0, float(cy - 1), 6.0) +>:Fires:+> build.objective("Shut down the processing plant's machinery.");
        # Coming up into the office brings its guards out.
        office = build.waiting();
        build.touch(9.0, float(self.wide - 7), float(d), 14.0, float(self.wide - 5), float(d + 6)) +>:Fires:+> office;
        build.touch(float(self.long - 8), float(self.wide - 7), float(d), float(self.long - 4), float(self.wide - 5), float(d + 6)) +>:Fires:+> office;
        build.foe(3.5, float(self.wide) - 3.5, d, fact2_foe(dice, self.danger), 0.0, waits=office);
        floor_y = float(cy) + 1.5;
        build.foe(5.5, floor_y, 0, "monster_soldier_light", 0.0, patrol=[[5.5, floor_y], [float(self.long) - 5.5, floor_y]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 6.5, 4.5 + float(index) * 6.0, 0, fact2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 3.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A pit of slime under grinders, walked round on ledges and across on a
walkway, a gantry along its wall."""
node GrinderPit(Prefab) {
    has deep: int = 5,
        deck: int = 7,
        rising: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grinder pit";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(4, 6);
        self.deck = 7;
        self.rising = dice.chance(0.6);
        self.tall = dice.between(14, 16);
        self.low = -self.deck - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(dice.between(12, self.long - 9)), floor=self.deck));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.deck);
        x0 = 9;
        x1 = self.long - 6;
        burning(build, x0, 4, -self.deep, x1, self.wide - 4, 0, 3, 10);
        build.solid(x0, middle - 1, -1, x1, middle + 2, 0);
        for y in range(middle - 1, middle + 2) {
            build.keep(room, x0 - 1, y, 0);
            build.keep(room, x1, y, 0);
        }
        # The grinders slamming down into the slime either side.
        for at in [[x0 + 3, 5], [x1 - 6, self.wide - 7]] {
            crusher(build, float(at[0]), float(at[1]), [3.0, 3.0, 3.0], float(-self.deep + 1), 3.0, 90.0, 1.0, 30);
        }
        # The gantry along the south wall over the ledge, up a stair or
        # steps a switch raises.
        slab(build, x0, 1, x1, 5, self.deck, 1);
        build.solid(x1 + 1, 1, 0, self.long - 1, 5, 5);
        stash(build, x1 + 2, 2, 0, 2, Q2_ARMOR);
        if self.rising {
            build.push(1.0, 5.5, 1.0, 0) +>:Fires:+> build.rising_steps(2, 1, 0, 0, self.deck, 3);
        } else {
            stair(build, 2, 1, 0, 0, self.deck, 3);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        build.touch(float(x0 - 3), float(middle - 1), 0.0, float(x0), float(middle + 2), 6.0, True, "Emulsifying flesh.");
        hooks(build, float(x0), float(x1 - 1), float(middle) + 3.0, float(self.tall - 3), 3);
        steam(build, [[float(x1) + 0.5, float(self.wide) - 1.1, 3.0], [float(x0) + 4.5, 1.1, float(self.deck) + 3.0], [float(self.long) - 1.1, 3.5, 6.0]], 1);
        # Halfway over, guards come at the far end and on the gantry.
        halfway = build.touch(float(self.long // 2 - 1), float(middle - 1), 0.0, float(self.long // 2 + 1), float(middle + 2), 6.0);
        far_end = build.waiting();
        halfway +>:Fires:+> far_end;
        build.foe(float(x1) + 2.5, float(middle) + 0.5, 0, fact2_foe(dice, self.danger, True), 180.0, waits=far_end);
        build.foe(float(x1) - 2.5, 2.5, self.deck, fact2_foe(dice, self.danger), 180.0, waits=far_end);
        ledge_y = float(self.wide) - 2.5;
        build.foe(float(x0) + 0.5, ledge_y, 0, "monster_soldier_ss", 0.0, patrol=[[float(x0) + 0.5, ledge_y], [float(x1) - 0.5, ledge_y]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 6) + 0.5, 2.5, 0, fact2_foe(dice, self.danger), 0.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall round a control tower, a way up its side, bridges from its top
to ways on high in two walls; a locker two switches open."""
node ControlTower(Prefab) {
    has tower: int = 7,
        way_up: int = 0,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control tower";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        # High enough that the ways out on the floor pass under the
        # galleries.
        self.tower = dice.between(9, self.long // 2 - 6);
        self.way_up = dice.below(3);
        self.tall = self.tower + 12;
        self.low = -self.tower - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tower),
            Port(face=0, along=middle, floor=self.tower),
            Port(face=3, along=float(self.long // 2) + 4.0, floor=self.tower),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        t = self.tower;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, t);
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, t);
        build.solid(cx - 3, cy - 3, t + 4, cx + 3, cy + 3, t + 5);
        for corner in [[cx - 3, cy - 3], [cx + 2, cy - 3], [cx - 3, cy + 2], [cx + 2, cy + 2]] {
            build.solid(corner[0], corner[1], t, corner[0] + 1, corner[1] + 1, t + 4);
        }
        if self.way_up == 0 {
            stair(build, cx - 3 - t, cy - 3, 0, 0, t, 3);
        } elif self.way_up == 1 {
            build.push(float(cx) + 1.5, float(cy - 3), 1.0, 3) +>:Fires:+> build.rising_steps(cx - 3 - t, cy - 3, 0, 0, t, 3);
        } else {
            lift(build, cx - 6, cy - 3, cx - 3, cy, 0, t);
        }
        build.solid(cx - 2, cy + 3, t - 1, cx + 2, self.wide - 1, t);
        build.solid(cx + 3, cy - 2, t - 1, self.long - 1, cy + 2, t);
        # Galleries along the north and east walls the bridges come to.
        slab(build, 9, self.wide - 4, self.long - 1, self.wide - 1, t, 1);
        slab(build, self.long - 4, 7, self.long - 1, self.wide - 1, t, 1);
        # And a gallery along the south wall, bridged to from the tower's
        # south face; a cargo lift up to the east gallery.
        slab(build, 9, 1, self.long - 1, 5, t, 1);
        build.solid(cx - 2, 5, t - 1, cx + 2, cy - 3, t);
        for at in range(-2, 2) {
            build.keep(hall, cx + at, cy - 3, t);
        }
        lift(build, self.long - 7, 7, self.long - 4, 10, 0, t);
        for y in range(7, 10) {
            build.keep(hall, self.long - 4, y, t);
        }
        for at in range(-2, 2) {
            build.keep(hall, cx + at, cy + 2, t);
            build.keep(hall, cx + 2, cy + at, t);
        }
        for y in range(cy - 3, cy) {
            build.keep(hall, cx - 3, y, t);
        }
        # The locker in the south-west corner, opened by a switch on a post
        # of the tower's top and one on the floor together.
        build.solid(2, 1, 0, 8, 6, 7);
        locker = build.room(3, 1, 0, 7, 4, 6);
        build.widen(locker, 3, 4, 0, 7, 5, 6);
        shut = build.opened(3.0, 4.0, 0.0, 7.0, 5.0, 6.0);
        both = build.tally(2, "The locker is open.");
        build.push(float(cx - 2), float(cy) - 2.5, float(t) + 1.0, 0) +>:Fires:+> both;
        build.push(1.0, 7.5, 1.0, 0) +>:Fires:+> both;
        both +>:Fires:+> shut;
        build.supply(4.5, 2.5, 0, Q2_ARMOR, "q2");
        build.supply(5.5, 2.0, 0, "ammo_rockets", "q2");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        hooks(build, 3.0, float(self.long - 4), float(cy) + 6.0, float(self.tall - 3), 3);
        steam(build, [[float(cx) + 3.1, float(cy) - 1.5, 3.0], [float(cx) - 3.1, float(cy) + 1.5, 4.0], [1.1, float(self.wide) - 4.5, 3.0], [float(self.long) - 1.1, 7.5, 5.0]], 0);
        # Up on the tower its guard wakes; one walks round its foot.
        top = build.waiting();
        build.touch(float(cx - 3), float(cy - 3), float(t), float(cx - 2), float(cy), float(t + 4)) +>:Fires:+> top;
        build.foe(float(cx) + 0.5, float(cy) + 0.5, t, fact2_foe(dice, self.danger, True), 180.0, waits=top);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, t, fact2_foe(dice, self.danger), 180.0, waits=top);
        ring = [[float(cx) - 6.5, float(cy) + 6.5], [float(cx) + 6.5, float(cy) + 6.5], [float(cx) + 6.5, float(cy) - 6.5], [float(cx) - 7.5, float(cy) - 6.5]];
        build.foe(ring[0][0], ring[0][1], 0, "monster_soldier_ss", 0.0, patrol=ring);
        for index in range(dice.between(2, 3)) {
            build.foe(float(4 + index * 7) + 0.5, float(self.wide) - 3.5, 0, fact2_foe(dice, self.danger), 0.0);
        }
        build.supply(float(cx) - 1.5, float(cy) + 1.5, t, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The processing line: presses slamming into a trench of slime, hooks
overhead, a catwalk along the wall; three switches stop the line and open
the way on."""
node HookLine(Prefab) {
    has deck: int = 6,
        presses: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hook line";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(32, 36);
        self.wide = dice.between(15, 17);
        self.deck = 6;
        self.presses = dice.between(2, 3);
        self.tall = dice.between(13, 15);
        self.low = -4;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(dice.between(3, cy - 4)), floor=0);
        self.leaves = [Port(face=0, along=float(dice.between(3, cy - 4)), floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=1, along=float(dice.between(10, self.long - 10)), floor=self.deck));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        d = self.deck;
        line = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(line, d);
        burning(build, 4, cy - 1, -3, self.long - 4, cy + 2, 0, 3, 10);
        for index in range(self.presses) {
            px = 7 + index * (self.long - 17) // max(1, self.presses - 1);
            crusher(build, float(px), float(cy - 1), [3.0, 3.0, 3.0], -2.0, 5.0, 110.0, 1.0, 40);
            hurt(build, float(px), float(cy - 1), -3.0, float(px + 3), float(cy + 2), 1.0, 40);
        }
        # The catwalk along the north wall, a stair up at each end.
        slab(build, 7, self.wide - 5, self.long - 7, self.wide - 1, d, 1);
        stair(build, 1, self.wide - 5, 0, 0, d, 4);
        stair(build, self.long - 2, self.wide - 5, 0, 2, d, 4);
        build.breakable(float(self.long - 4), 1.0, 0.0, float(self.long - 2), 3.0, 2.0, 20);
        build.doorway(line, self.enter);
        # The line's three switches: on the floor's south wall, on the
        # catwalk and under it; all three stop it and open the way on.
        stopped = build.tally(3, "The line is stopped. The way on is open.");
        build.push(float(self.long // 2) + 0.5, 1.0, 1.0, 1) +>:Fires:+> stopped;
        build.push(float(self.long // 2) + 3.5, float(self.wide - 1), float(d) + 1.0, 3) +>:Fires:+> stopped;
        build.push(float(self.long // 2) - 3.5, float(self.wide - 1), 1.0, 3) +>:Fires:+> stopped;
        for port in self.taken {
            build.doorway(line, port);
            port_door(build, self.long, self.wide, port, stopped);
        }
        hooks(build, 3.0, float(self.long - 4), float(cy), float(self.tall - 3), 4);
        steam(build, [[1.1, 3.5, 3.0], [float(self.long) - 1.1, float(cy) + 3.5, 4.0], [float(self.long // 2) + 0.5, 1.1, 5.0], [float(self.long // 2) - 6.5, float(self.wide) - 1.1, float(d) + 3.0]], 0);
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(cy - 1), 6.0, True, "Emulsifying flesh.");
        line_guard = build.waiting();
        come_in +>:Fires:+> line_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 5 - index * 5) + 0.5, 3.5, 0, fact2_foe(dice, self.danger, index == 0), 180.0, waits=line_guard);
        }
        walk_y = float(self.wide) - 3.0;
        build.foe(8.5, walk_y, d, "monster_gunner", 0.0, patrol=[[8.5, walk_y], [float(self.long) - 8.5, walk_y]]);
        build.foe(5.5, 3.0, 0, "monster_soldier_light", 0.0, patrol=[[5.5, 3.0], [float(self.long) - 5.5, 3.0]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, walk_y, d, "ammo_bullets", "q2");
    }
}

"""The key in a vault behind a door its switch opens."""
node PlantVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(20, 22);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(room, self.enter);
        vx = self.long - 7;
        build.solid(vx, 1, 0, vx + 1, side, self.tall);
        build.widen(room, vx, cy - 2, 0, vx + 1, cy + 2, 7);
        vault = build.opened(float(vx), float(cy - 2), 0.0, float(vx + 1), float(cy + 2), 7.0);
        build.push(float(vx), float(cy) + 3.5, 1.3, 2) +>:Fires:+> vault;
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [3, vx - 5], [fact2_foe(dice, self.danger, True), fact2_foe(dice, self.danger)]);
        inside = build.waiting();
        vault +>:Fires:+> inside;
        build.foe(float(self.long) - 2.5, 2.5, 0, fact2_foe(dice, self.danger), 180.0, waits=inside);
        build.foe(3.5, 2.5, 0, "monster_soldier_ss", 0.0, patrol=[[3.5, 2.5], [float(vx) - 2.5, 2.5]]);
        hooks(build, 2.0, float(vx - 2), float(cy) + 0.5, float(self.tall - 3), 2);
        steam(build, [[float(vx) - 0.1, float(cy) - 4.5, 4.0], [1.1, float(side) - 3.5, 3.0]], 2);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a corridor of doors, grinders in pits beside it, the
way out at its end."""
node DoorCorridor(Prefab) {
    has key: str = "",
        tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Door corridor" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT2;
        self.district = level_district(FACT2);
        self.long = dice.between(37, 39);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(10, 12);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 7;
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        # The corridor's doors, each a key's when it is a gate's, each
        # opened by walking up to it otherwise; guards behind each come as it
        # is passed.
        doors = [wall + 5, wall + 10, wall + 15, wall + 20, wall + 25];
        for (index, x) in enumerate(doors) {
            build.solid(x, 1, 0, x + 1, middle - 2, self.tall);
            build.solid(x, middle + 2, 0, x + 1, self.wide - 1, self.tall);
            build.solid(x, middle - 2, 8, x + 1, middle + 2, self.tall);
            if self.key {
                build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
            } else {
                gate = build.opened(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 8.0);
                build.touch(float(x - 2), float(middle - 2), 0.0, float(x), float(middle + 2), 6.0) +>:Fires:+> gate;
                build.touch(float(x + 1), float(middle - 2), 0.0, float(x + 3), float(middle + 2), 6.0) +>:Fires:+> gate;
            }
            passed = build.touch(float(x + 1), float(middle - 2), 0.0, float(x + 2), float(middle + 2), 6.0);
            behind = build.waiting();
            passed +>:Fires:+> behind;
            build.foe(float(x + 2) + 0.5, float(middle) + 3.5, 0, fact2_foe(dice, self.danger, index == 2), 180.0, waits=behind);
            steam(build, [[float(x) - 0.1, float(middle) - 3.5, 4.0]], 2);
        }
        # Grinders in pits of slime beside the corridor between the doors.
        for x in [wall + 6, wall + 16] {
            burning(build, x, 1, -3, x + 3, 4, 0, 3, 10);
            crusher(build, float(x), 1.0, [3.0, 3.0, 3.0], -2.0, 3.0, 80.0, 1.0, 30);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        build.breakable(float(wall + 11), float(self.wide - 3), 0.0, float(wall + 13), float(self.wide - 1), 2.0, 20);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.0, 2.5 + float(index) * 3.5, 0, fact2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact2's stretches: [name, role]."""
glob FACT2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["grinder", "flow"],
         ["line", "flow"],
         ["tower", "hub"],
         ["tower", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact2's stretches by its name."""
def make_fact2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PlantGate();
    }
    if name == "grinder" {
        return GrinderPit();
    }
    if name == "line" {
        return HookLine();
    }
    if name == "tower" {
        return ControlTower();
    }
    if name == "vault" {
        return PlantVault(key=key if key else "key_silver");
    }
    return DoorCorridor(key=key);
}
