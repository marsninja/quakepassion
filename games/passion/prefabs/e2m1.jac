"""Prefabs drawn from e2m1, the Installation: a base built over water, its
docks and canals under footbridges, tunnels flooded to be swum under, a
pumping hall over a flooded pit with a catwalk round it, a sluice crossed
by walkways at two heights, a corridor of lasers over a trench, a key on
an island in slime, a bunker for the slipgate. Barriers open from
elsewhere and enforcers come in by teleporters, as e2m1's do. Raised in
e2m1's own palette. Each stretch takes its shape from its dice as well as
its sizes.

- `InstallationDock`: the start. Docks either side of a deep canal, two
  footbridges over it (the second drawn up from the deck, or not), a
  control deck over a garage up a stair; stepping onto the deck opens the
  barriers on the ways on ("This barrier opens elsewhere"); a niche under
  the canal's water a secret.
- `FloodedTunnels`: a tunnel flooded most of its length, a wall down into
  the water across it to dive under, or with a door in it and a catwalk
  along the wall to it; a catwalk past the wall over the water; fish.
- `PumpingStation`: the hub: a tall hall, machinery standing in a flooded
  pit, a catwalk round the walls ridden up to by lifts; the floor's ways
  on barred until the catwalk's button is pressed; enforcers sent onto the
  catwalk as the pit is neared.
- `Sluice`: a flooded hall crossed by a walkway low over the water and a
  catwalk high over it (a lift up); the walkway's barrier opened by the
  catwalk's button, or the walkway broken to swim; a drop from the
  catwalk's end.
- `LaserCorridor`: a grated walkway over a flooded trench, lasers firing
  across it from both walls while anyone walks there (e2m1's laser
  traps); straight, or jogging round a pump.
- `KeyLab`: the key room: the key on an island in a pool of slime, a
  bridge drawn out by a button shot; a gallery round two walls (a lift up)
  with guards; taking the key opens the closets and brings enforcers in.
- `SlipgateBunker`: the end: a hall over a flooded trench, a stair down
  into a bunker, the slipgate at its foot past lasers; as a gate, a key
  door at the stair's head; enforcers sent in as the stair is reached."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, lift, apart }
import from .e1m2_parts { slab, keep_box, arcade, stash, closets, spike_wall, key_cue, flood, sump }
import from .e1m2 { port_gate }

glob E2M1: str = "q1:e2m1";

"""e2m1's foes: grunts and dogs, enforcers growing with the danger."""
def e2m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_enforcer", "monster_army"] if heavy else ["monster_army", "monster_army", "monster_dog"], ["monster_enforcer"], danger));
}

"""Lasers set in a wall (as `spike_wall`), each firing when `cue` does."""
def laser_wall(build: Raising, cue: Cue, line: int, start: int, finish: int, high: float, every: int, direction: int) {
    inset = 0.2 if direction in [0, 1] else -0.2;
    for at in range(start, finish, every) {
        shooter = build.spikes(float(at) + 0.5, float(line) + inset, high, direction);
        for item in shooter.items {
            item["spawnflags"] = "2";
        }
        cue +>:Fires:+> shooter;
    }
}

"""A niche under water off a pool's side (cells x0..x1, y0..y1, lifts
z0..z1, flooded): a secret, and `reward` in it."""
def wet_niche(build: Raising, x0: int, y0: int, x1: int, y1: int, z0: int, z1: int, reward: str) {
    build.room(x0, y0, z0, x1, y1, z1);
    flood(build, x0, y0, z0, x1, y1, z1);
    build.secret(float(x0), float(y0), float(z0), float(x1), float(y1), float(z1));
    build.supply(float(x0 + x1) * 0.5, float(y0 + y1) * 0.5, z0, reward);
}

"""A barrier on a way out: `port_gate` that says it opens elsewhere."""
def barrier(build: Raising, long: int, wide: int, port: Port) -> Cue {
    seal = port_gate(build, long, wide, port);
    for item in seal.items {
        item["message"] = "This barrier opens elsewhere..";
    }
    return seal;
}

"""The start: docks either side of a deep canal, footbridges over it, a
control deck over a garage."""
node InstallationDock(Prefab) {
    has deck: int = 6,
        tall: int = 14,
        bridged: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation dock";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(14, 16);
        self.bridged = dice.chance(0.5);
        self.low = -14;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [Port(face=0, along=4.0, floor=0), Port(face=3, along=float(self.long - 6), floor=0), Port(face=1, along=float(self.long - 5), floor=self.deck)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        dock = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(dock, self.deck);
        # The canal down the middle, eight lifts deep, steps up out of it at
        # both ends, a well in its bed.
        build.pool(6, middle - 3, -8, self.long - 4, middle + 4, 0, 2);
        for step in range(8) {
            build.solid(self.long - 5 - step, middle + 2, -8, self.long - 4 - step, middle + 4, -step);
        }
        sump(build, self.long // 2, middle - 1, -13, -8, 2);
        # A niche under the canal's water in the south dock's side: a secret.
        build.room(14, middle - 6, -7, 17, middle - 3, -3);
        flood(build, 14, middle - 6, -7, 17, middle - 3, -3);
        build.secret(14.0, float(middle - 6), -7.0, 17.0, float(middle - 3), -3.0);
        build.supply(15.5, float(middle) - 5.0, -7, "item_armor2");
        # The footbridges: one near the start; the second drawn up out of
        # the water from the deck, or always there.
        slab(build, 10, middle - 3, 13, middle + 4, 0);
        far_bridge = self.long // 2 + 3;
        if self.bridged {
            drawn = build.drawn(float(far_bridge), float(middle - 3), float(far_bridge + 3), float(middle + 4), 0, 9);
        } else {
            slab(build, far_bridge, middle - 3, far_bridge + 3, middle + 4, 0);
        }
        for x in [10, far_bridge] {
            keep_box(build, dock, x, middle - 4, x + 3, middle - 3, 0);
            keep_box(build, dock, x, middle + 4, x + 3, middle + 5, 0);
        }
        # The control deck over a garage at the far end's north side, a stair
        # up to it.
        deck_x = self.long - 10;
        deck_y = self.wide - 6;
        slab(build, deck_x, deck_y, self.long - 1, self.wide - 1, self.deck);
        arcade(build, deck_y, deck_x + 2, self.long - 2, 0, self.deck - 1, 3, False);
        stair(build, deck_x - self.deck, deck_y + 1, 0, 0, self.deck, 3);
        keep_box(build, dock, deck_x - 1, deck_y, deck_x + 1, deck_y + 4, self.deck);
        # Stepping onto the deck opens the barriers on the ways on below (and
        # draws the second footbridge up).
        onto = build.touch(float(deck_x), float(deck_y), float(self.deck), float(deck_x + 3), float(self.wide - 1), float(self.deck + 6));
        if self.bridged {
            onto +>:Fires:+> drawn;
        }
        build.doorway(dock, self.enter);
        for port in self.taken {
            build.doorway(dock, port);
            if port.floor == 0 {
                onto +>:Fires:+> barrier(build, self.long, self.wide, port);
            }
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        # Grunts walk the docks; dogs in the garage wake as the deck is
        # reached; the deck's own guard.
        build.foe(8.5, 2.5, 0, "monster_army", 0.0, patrol=[[8.5, 2.5], [float(self.long) - 4.5, 2.5]]);
        build.foe(8.5, float(self.wide) - 2.5, 0, "monster_army", 0.0, patrol=[[8.5, float(self.wide) - 2.5], [float(deck_x) - 7.5, float(self.wide) - 2.5]]);
        garage = build.waiting();
        onto +>:Fires:+> garage;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5 - float(index) * 3.0, float(self.wide) - 3.5, 0, "monster_dog", 180.0, waits=garage);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(14 + index * 4) + 0.5, 4.5, 0, e2m1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, self.deck, e2m1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.deck, "item_health");
    }
}

"""A tunnel flooded most of its length, a wall down into the water across
it to dive under (or a door in it, a catwalk along the wall to it)."""
node FloodedTunnels(Prefab) {
    has deep: int = 8,
        tall: int = 12,
        walled: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded tunnels";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(12, 14);
        self.deep = dice.between(8, 9);
        self.walled = dice.chance(0.5);
        self.low = -self.deep - 6;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 5;
        x1 = self.long - 5;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2);
        # The far shore's steps up out of the water, climbing east.
        stair(build, x1 - self.deep, 1, -self.deep, 0, self.deep, 3);
        sump(build, x0 + 4, self.wide - 5, -self.deep - 5, -self.deep, 3);
        # The wall across, down into the water.
        build.solid(10, 1, -2, 11, self.wide - 1, self.tall);
        if self.walled {
            build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "The way on is under the water");
            walk_x0 = 11;
        } else {
            # A door through the wall at its north end, the catwalk along the
            # wall to it from the near shore.
            build.widen(tunnel, 10, self.wide - 4, 0, 11, self.wide - 1, 8);
            build.rising_door(10.0, float(self.wide - 4), 0.0, 11.0, float(self.wide - 1), 8.0, {});
            walk_x0 = 5;
        }
        # The catwalk along the north wall over the water to the far shore,
        # and one along the south wall past the wall.
        slab(build, walk_x0, self.wide - 4, x1, self.wide - 1, 0);
        keep_box(build, tunnel, walk_x0, self.wide - 5, x1, self.wide - 4, 0);
        slab(build, 11, 1, x1 - self.deep - 1, 4, 0);
        keep_box(build, tunnel, 11, 4, x1 - self.deep - 1, 5, 0);
        # Gantries across between them, over the water.
        for gx in range(14, x1 - self.deep - 2, 6) {
            slab(build, gx, 4, gx + 2, self.wide - 4, 0);
        }
        wet_niche(build, x1, 5, x1 + 2, 8, -self.deep, -self.deep + 3, "item_armor1");
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(13 + index * 6) + 0.5, float(self.wide // 2) - 1.5, -self.deep + 1, "monster_fish", 0.0);
        }
        # The far shore's guards wake as a body comes out of the water.
        out = build.touch(float(x1 - 2), 1.0, -2.0, float(x1 + 2), float(self.wide - 1), 6.0);
        guards = build.waiting();
        out +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 3.5 + float(index) * 3.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(2.5, 2.5, 0, "monster_army", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        build.foe(float(walk_x0) + 2.5, float(self.wide) - 2.5, 0, "monster_army", 0.0, patrol=[[float(walk_x0) + 2.5, float(self.wide) - 2.5], [float(x1) - 1.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""The hub: a tall hall, machinery in a flooded pit, a catwalk round its
walls ridden up to by lifts; the floor's ways on barred."""
node PumpingStation(Prefab) {
    has walk: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pumping station";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(19, 22);
        self.walk = dice.between(9, 10);
        self.low = -14;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The pit, flooded eight lifts deep, steps up out of it, machinery
        # standing in the water, a well in its bed.
        build.pool(8, 7, -8, self.long - 8, self.wide - 7, 0, 2);
        gantry = self.long // 2 - 3;
        pillars(build, 12, 9, self.long - 9, self.wide - 8, -8, 3, 3, [[7, 6, 12, self.wide - 6], [gantry - 1, 6, gantry + 4, self.wide - 6], [gantry + 2, self.wide - 11, self.long - 10, self.wide - 6]]);
        sump(build, self.long // 2, middle, -13, -8, 2);
        # A gantry across the pit at the floor's height, and a bridge over it
        # between the catwalk's long sides; a platform riding along the pit.
        gx = self.long // 2 - 3;
        slab(build, gx, 7, gx + 3, self.wide - 7, 0);
        keep_box(build, hall, gx, 6, gx + 3, 8, 0);
        keep_box(build, hall, gx, self.wide - 8, gx + 3, self.wide - 6, 0);
        slab(build, gx + 6, 4, gx + 9, self.wide - 4, self.walk);
        keep_box(build, hall, gx + 6, 3, gx + 9, 5, self.walk);
        keep_box(build, hall, gx + 6, self.wide - 5, gx + 9, self.wide - 3, self.walk);
        build.train([3.0, 3.0, 1.0], [[float(gx + 3), float(self.wide - 10), -1.0], [float(self.long - 11), float(self.wide - 10), -1.0]], 80.0, 2.0);
        wet_niche(build, self.long - 8, 9, self.long - 6, 12, -8, -5, "item_armor2");
        # The catwalk round the walls, a lift thick, three cells wide.
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(1, 4, under, 4, self.wide - 4, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        # Lifts up to it in two corners, waiting at their feet.
        for corner in [[4, 4], [self.long - 6, self.wide - 6]] {
            lift(build, corner[0], corner[1], corner[0] + 2, corner[1] + 2, 0, self.walk);
            keep_box(build, hall, corner[0] - 1, corner[1] - 1, corner[0] + 3, corner[1] + 3, self.walk);
        }
        # The floor's ways on are barred until the button on the catwalk is
        # pressed.
        press = build.push(float(self.long - 1), float(middle) - 5.5, float(self.walk) + 1.2, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                press +>:Fires:+> barrier(build, self.long, self.wide, port);
            }
        }
        # Nearing the pit brings enforcers in onto the catwalk.
        nearing = build.touch(5.0, 6.0, 0.0, 8.0, float(self.wide - 6), 6.0);
        nearing +>:Fires:+> build.summon(2, 2, -9, "monster_enforcer", 2.5, float(middle) + 0.5, self.walk, 0.0);
        if self.danger > 0.3 {
            nearing +>:Fires:+> build.summon(self.long - 5, 2, -9, "monster_enforcer", float(self.long) - 2.5, float(middle) - 2.5, self.walk, 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, 5.0, 0, e2m1_foe(dice, self.danger), 0.0);
        }
        build.foe(6.5, float(self.wide) - 2.5, self.walk, "monster_army", 0.0, patrol=[[6.5, float(self.wide) - 2.5], [float(self.long) - 6.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 6.5, 2.5, self.walk, "monster_enforcer", 180.0, patrol=[[float(self.long) - 6.5, 2.5], [6.5, 2.5]]);
        build.foe(float(self.long) - 5.5, 5.5, 0, e2m1_foe(dice, self.danger), 180.0);
        if dice.chance(0.5) {
            build.foe(float(self.long // 2) + 1.5, float(middle) + 1.5, -6, "monster_fish", 0.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, self.walk, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, self.walk, "item_armor1");
    }
}

"""A flooded hall crossed by a walkway low over the water and a catwalk
high over it; the walkway's barrier opened from the catwalk."""
node Sluice(Prefab) {
    has deep: int = 9,
        tall: int = 18,
        broken: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sluice";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(18, 20);
        self.broken = dice.chance(0.5);
        self.low = -self.deep - 6;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid), floor=0), Port(face=3, along=float(self.long - 3), floor=0), Port(face=0, along=float(self.wide - 3), floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        d = self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        # The water between the shores, steps up out of it on both.
        build.pool(5, 1, -d, self.long - 5, self.wide - 1, 0, 2);
        for step in range(d) {
            build.solid(self.long - 6 - step, self.wide - 5, -d, self.long - 5 - step, self.wide - 2, -step);
        }
        sump(build, self.long // 2, mid - 1, -d - 5, -d, 3);
        wet_niche(build, self.long - 5, mid - 2, self.long - 3, mid + 1, -d, -d + 3, "item_armor1");
        # The walkway low over the water along the south wall: whole, with a
        # barrier near its far end opened from the catwalk; or broken, to
        # swim across its gap.
        gap = self.long // 2;
        if self.broken {
            slab(build, 5, 1, gap - 2, 4, 0);
            slab(build, gap + 2, 1, self.long - 5, 4, 0);
            keep_box(build, hall, gap - 3, 1, gap + 3, 4, 0);
        } else {
            slab(build, 5, 1, self.long - 5, 4, 0);
        }
        keep_box(build, hall, 5, 4, self.long - 5, 5, 0);
        # Gantries across from the walkway toward the north wall, over the
        # water, a third and two thirds of the way along.
        for gx in [self.long // 3, 2 * self.long // 3]
        {
            slab(build, gx, 4, gx + 3, self.wide - 6, 0);
        }
        # The catwalk high over the water along the north wall, a lift up to
        # it on the near shore, its far end open to drop from.
        slab(build, 5, self.wide - 5, self.long - 1, self.wide - 1, 8);
        lift(build, 1, self.wide - 5, 4, self.wide - 2, 0, 8);
        keep_box(build, hall, 1, self.wide - 6, 6, self.wide - 1, 8);
        keep_box(build, hall, 1, self.wide - 6, 5, self.wide - 1, 0);
        keep_box(build, hall, self.long - 9, self.wide - 6, self.long - 5, self.wide - 5, 8);
        # The catwalk's button opens the walkway's barrier and the ways on.
        press = build.push(float(gap) + 0.5, float(self.wide - 1), 9.2, 3);
        if not self.broken {
            press +>:Fires:+> build.sinking(float(self.long - 9), 1.0, float(self.long - 8), 4.0, 8, 8);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                press +>:Fires:+> barrier(build, self.long, self.wide, port);
            }
        }
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 6), 6.0, True, "This barrier opens elsewhere..");
        # Halfway along the catwalk the far shore's guards wake and one more
        # is sent in onto the walkway.
        halfway = build.touch(float(gap - 1), float(self.wide - 5), 8.0, float(gap + 2), float(self.wide - 1), 14.0);
        guards = build.waiting();
        halfway +>:Fires:+> guards;
        halfway +>:Fires:+> build.summon(1, 1, -9, e2m1_foe(dice, self.danger, True), 7.5, 2.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 4.5 + float(index) * 3.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(7.5, float(self.wide) - 3.0, 8, "monster_army", 0.0, patrol=[[7.5, float(self.wide) - 3.0], [float(self.long) - 7.5, float(self.wide) - 3.0]]);
        build.foe(6.5, 2.5, 0, "monster_dog", 0.0, patrol=[[6.5, 2.5], [float(gap) - 3.5, 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 6) + 0.5, float(mid) + 0.5, -d + 2, "monster_fish", 0.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A grated walkway over a flooded trench, lasers firing across it."""
node LaserCorridor(Prefab) {
    has tall: int = 12,
        jog: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Laser corridor";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(13, 15);
        self.tall = dice.between(12, 14);
        self.jog = dice.chance(0.5);
        self.low = -12;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # The trench, six lifts of water, steps up out of it at both ends.
        build.pool(4, 1, -6, self.long - 4, self.wide - 1, 0, 2, False, False);
        for step in range(6) {
            build.solid(4 + step, 1, -6, 5 + step, 3, -step);
            build.solid(self.long - 5 - step, 1, -6, self.long - 4 - step, 3, -step);
        }
        sump(build, self.long // 2, 2, -11, -6, 2);
        wet_niche(build, self.long - 4, self.wide - 4, self.long - 2, self.wide - 2, -6, -3, "item_health");
        # The grated walkway over it: straight down the middle, or jogging
        # round a pump in the middle.
        if self.jog {
            third = self.long // 3;
            slab(build, 4, mid - 2, third + 2, mid + 2, 0);
            slab(build, third - 2, mid - 2, third + 2, self.wide - 1, 0);
            slab(build, third - 2, self.wide - 5, 2 * third + 2, self.wide - 1, 0);
            slab(build, 2 * third - 2, mid - 2, 2 * third + 2, self.wide - 1, 0);
            slab(build, 2 * third - 2, mid - 2, self.long - 4, mid + 2, 0);
            build.solid(third + 3, mid - 2, -6, 2 * third - 3, mid + 1, self.tall);
        } else {
            slab(build, 4, mid - 2, self.long - 4, mid + 2, 0);
        }
        # Lasers fire across it from both walls while anyone walks its middle.
        third = self.long // 3;
        walking = build.touch(float(third), 1.0, -2.0, float(2 * third), float(self.wide - 1), 6.0, False);
        laser_wall(build, walking, 1, third + 1, 2 * third, 1.5, 3, 1);
        laser_wall(build, walking, self.wide - 1, third + 2, 2 * third, 2.5, 3, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What waits at the far end wakes as the lasers do; a grunt walks
        # the near end.
        far = build.waiting();
        walking +>:Fires:+> far;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * 3.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0, waits=far);
        }
        build.foe(2.5, 2.5, 0, "monster_army", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        if dice.chance(0.5) {
            build.foe(float(self.long // 2) + 0.5, 2.5, -5, "monster_fish", 0.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""The key on an island in slime, a bridge drawn out by a button shot; a
gallery round two walls; taking the key opens the closets."""
node KeyLab(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 15,
        shot: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key lab (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(15, 17);
        self.shot = dice.chance(0.5);
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
        lab = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(lab, 7);
        build.doorway(lab, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -3, x1, side - 2, 0, 3);
        cx = (x0 + x1) // 2;
        cy = side // 2;
        build.solid(cx - 1, cy - 1, -3, cx + 2, cy + 2, 0);
        # The bridge from the near shore out to the island, drawn out when
        # the button is shot (on the near wall) or pressed (on a post).
        span = build.drawn(float(x0), float(cy - 1), float(cx - 1), float(cy + 2), 0, 4);
        if self.shot {
            build.push(1.0, float(cy - 4) + 0.5, 2.0, 0, True) +>:Fires:+> span;
        } else {
            build.solid(x0 - 2, cy - 4, 0, x0 - 1, cy - 3, 4);
            build.push(float(x0 - 1), float(cy) - 3.5, 1.3, 0) +>:Fires:+> span;
        }
        for y in range(cy - 1, cy + 2) {
            build.keep(lab, x0 - 1, y, 0);
        }
        # A gallery round the far end and the south wall over the slime, a
        # lift up to it on the near shore.
        slab(build, x0, 1, self.long - 1, 4, 7);
        slab(build, self.long - 4, 4, self.long - 1, side, 7);
        lift(build, 2, 1, 5, 4, 0, 7);
        keep_box(build, lab, 1, 1, 7, 5, 7);
        keep_box(build, lab, 1, 1, 6, 5, 0);
        # The key: taking it opens the closets in the north wall and brings
        # an enforcer in behind; the gallery's guards wake.
        taken = key_cue(build, self.key, float(cx) + 0.5, float(cy) + 0.5, 0);
        closets(build, taken, side, [3, self.long - 7], 0, 1, [e2m1_foe(dice, self.danger, True), e2m1_foe(dice, self.danger)]);
        taken +>:Fires:+> build.summon(2, side - 5, -8, "monster_enforcer", 3.5, float(side) - 2.5, 0, 0.0);
        gallery = build.waiting();
        taken +>:Fires:+> gallery;
        build.foe(float(self.long) - 2.5, float(cy) + 0.5, 7, e2m1_foe(dice, self.danger, True), 180.0, waits=gallery);
        build.foe(float(x0) + 2.5, 2.5, 7, "monster_army", 0.0, patrol=[[float(x0) + 2.5, 2.5], [float(self.long) - 5.5, 2.5]]);
        build.foe(float(self.long) - 2.5, float(side) - 2.5, 0, e2m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a hall over a flooded trench, a stair down into a bunker, the
slipgate at its foot past lasers; as a gate, a key door at the stair's
head."""
node SlipgateBunker(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slipgate bunker" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(13, 15);
        self.low = -12;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = self.long - 11;
        hall = build.room(1, 1, 0, wall, self.wide - 1, self.tall, variant=dice.below(3));
        bunker = build.room(wall + 1, 1, -4, self.long - 1, self.wide - 1, self.tall - 2, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The hall over a flooded trench crossed by a grated walkway, steps up
        # out of it at its ends.
        build.pool(5, 1, -6, wall - 2, self.wide - 1, 0, 2, False, False);
        for step in range(6) {
            build.solid(5 + step, 1, -6, 6 + step, 3, -step);
            build.solid(wall - 3 - step, self.wide - 3, -6, wall - 2 - step, self.wide - 1, -step);
        }
        slab(build, 5, middle - 2, wall - 2, middle + 2, 0);
        wet_niche(build, wall - 2, 4, wall, 6, -6, -3, "item_armor1");
        build.widen(bunker, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        stair(build, wall + 4, middle - 2, -4, 2, 4, 4);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(float(self.long) - 4.0, float(middle), -4);
        # Lasers across the bunker's floor before the slipgate.
        nearing = build.touch(float(wall + 5), 1.0, -4.0, float(self.long - 6), float(self.wide - 1), 2.0, False);
        laser_wall(build, nearing, 1, wall + 6, self.long - 6, -2.5, 2, 1);
        # Reaching the stair's head brings enforcers in behind.
        head = build.touch(float(wall - 3), float(middle - 2), 0.0, float(wall), float(middle + 2), 6.0);
        head +>:Fires:+> build.summon(1, 1, -11, "monster_enforcer", 3.5, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * (float(self.wide) - 5.0), -4, e2m1_foe(dice, self.danger, True), 180.0);
        }
        build.foe(3.5, 2.5, 0, "monster_army", 90.0, patrol=[[3.5, 2.5], [3.5, float(self.wide) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m1's stretches: [name, role]."""
glob E2M1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["tunnels", "flow"],
         ["station", "hub"],
         ["station", "flow"],
         ["sluice", "flow"],
         ["lasers", "flow"],
         ["lab", "keyroom"],
         ["bunker", "end"],
         ["bunker", "gate"]
     ];

"""One of e2m1's stretches by its name."""
def make_e2m1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return InstallationDock();
    }
    if name == "tunnels" {
        return FloodedTunnels();
    }
    if name == "station" {
        return PumpingStation();
    }
    if name == "sluice" {
        return Sluice();
    }
    if name == "lasers" {
        return LaserCorridor();
    }
    if name == "lab" {
        return KeyLab(key=key if key else "key_silver");
    }
    return SlipgateBunker(key=key);
}
