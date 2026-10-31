"""Prefabs drawn from e2m6, the Dismal Oubliette: dungeons of brick and wood
sunk over black water, a ledge over a flooded pit, a lake whose second
floor opens when a button is found, bridges that rise as the player comes
("A bridge has been raised", "The center bridge has changed") under
spikes, a block of barred cells whose third floor opens from inside a
cell, a well wound down into, the gold key behind a grate at the bottom of
a drowned pit, and the way out on an island. Raised in e2m6's own palette.

- `OublietteLedge`: the start. A ledge high over a flooded pit, the low
  floor running on under it, a stair or a lift down to the water's edge,
  the water swum to a far strip and a lift up to the far ledge; in some a
  bridge high along the wall. Landing below brings the dead in by
  teleporter; a grate under the water opens to a button beside it (a
  secret).
- `SunkenLake`: a hall whose floor is a lake, a gallery round two of its
  walls (its second floor), a lift up to it in an alcove behind bars that
  open only when the button (on an island, or high on the wall to be
  shot) is used ("The second floor is accessible"); a raft rides across
  the lake in some; ways on from the shore and the gallery (a hub as
  well).
- `ChangingBridge`: water crossed to an island and on to a far shore by
  two bridges that rise out of it as the player comes to each edge, spikes
  shooting across them while anyone is on them; in some a walkway high
  along the wall back over the water from the far shore.
- `CellBlock`: a corridor between two rows of barred cells, a gallery over
  each row (its third floor), a stair up at the far end behind bars that a
  button inside a cell opens; walking up the corridor opens the cells on
  their dead, and coming up the stair brings more in behind (a hub).
- `DeepWell`: a well entered at its top, a stair winding down round its
  walls to a pool at its foot; scrags wake halfway down, and coming to the
  foot wakes what keeps it and brings the dead in onto the stair behind.
- `DrownedKey`: the key room. A deep pool, the key behind a grate at its
  bottom that a button on the rim opens, a lift up out of the water beside
  it; taking the key opens the closets in the wall and brings the dead in.
- `DismalExit`: the end. A door (the gold door, as a gate: "You must grab
  the Black Magic") into a cavern of water, a raft set riding out to the
  island of the slipgate (or a swim), a balcony over the water ridden up to
  by a lift; opening the door brings fiends in by teleporter."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix }
import from .common { stair, spiral, ring_path, ring_landing, lift }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_moat, e2m4_stash }

glob E2M6: str = "q1:e2m6";

"""e2m6's foes: the dead and fiends, hell knights and ogres, a vore deeper
in."""
glob E2M6_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_zombie", "monster_ogre"], strong=["monster_demon1"], heavy_light=["monster_hell_knight", "monster_ogre"], heavy_strong=["monster_shalrath"], heavy_scale=0.5);

"""A relay that says `message` to who set it off (e2m6's "The second floor
is accessible"), fired by the cues wired to it."""
def e2m6_say(build: Raising, message: str) -> Cue {
    said = build.delay(0.1);
    said.items[0]["message"] = message;
    return said;
}

"""A grate under the water at a walkway's foot: a flooded niche of the
prefab's cells x0..x1, y0..y0+3 from lift `bottom` (four lifts high, its
mouth at x1 on the water), a grate across the mouth that sinks into the
rock under it when the button beside it on the wall at x1 is pushed,
`item` in it, a secret."""
def e2m6_grate(build: Raising, x0: int, x1: int, y0: int, bottom: int, item: str) {
    build.room(x0, y0, bottom, x1, y0 + 3, bottom + 4);
    for z in range(bottom, bottom + 4) {
        for y in range(y0, y0 + 3) {
            for x in range(x0, x1) {
                build.liquid(x, y, z, 2);
            }
        }
    }
    grate = e2m4_bars(build, float(x1 - 1), float(y0), float(x1), float(y0 + 3), bottom, 4, "");
    build.push(float(x1), float(y0) + 4.5, float(bottom) + 1.0, 0) +>:Fires:+> grate;
    build.secret(float(x0), float(y0), float(bottom), float(x1 - 1), float(y0 + 3), float(bottom + 3));
    build.supply(float(x0) + 1.0, float(y0) + 1.5, bottom, item);
}

"""The start: a ledge high over a flooded pit, the low floor under it, the
water's edge reached by a stair or a lift."""
node OublietteLedge(Prefab) {
    has high_ledge: int = 12,
        deep: int = 7,
        lifted: bool = False,
        bridge: bool = False,
        grate: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Oubliette ledge";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(32, 36);
        self.wide = dice.between(16, 20);
        self.high_ledge = dice.between(12, 14);
        self.deep = min(dice.between(6, 8), self.wide - 9);
        self.lifted = dice.chance(0.5);
        self.bridge = dice.chance(0.4);
        self.grate = dice.chance(0.6);
        self.tall = self.high_ledge + 10;
        self.low = -13;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.high_ledge);
        self.leaves = [
            Port(face=0, along=middle, floor=self.high_ledge),
            Port(face=1, along=float(self.long - 4), floor=self.high_ledge),
            Port(face=3, along=float(self.long - 9), floor=0),
            Port(face=3, along=12.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        h = self.high_ledge;
        d = self.deep;
        middle = self.wide // 2;
        nl = 8;
        pit = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, h);
        # The ledge the run begins on, a slab over the low floor, on piers.
        build.solid(1, 1, h - 1, nl, self.wide - 1, h);
        for y in [4, self.wide - 5] {
            build.solid(4, y, 0, 5, y + 1, h - 1);
        }
        build.solid(self.long - 7, 1, 0, self.long - 1, self.wide - 1, h);
        e2m4_moat(build, nl + 6, self.long - 11, 1, self.wide - 1, d);
        # Down to the water's edge: a lift, or a stair along the north wall.
        if self.lifted {
            lift(build, nl, 2, nl + 3, 5, 0, h);
            for y in range(2, 5) {
                build.keep(pit, nl - 1, y, h);
                build.keep(pit, nl + 3, y, 0);
            }
        } else {
            stair(build, nl, self.wide - 2, 0, 3, h, 3);
            for y in range(self.wide - 2 - h, self.wide + 1 - h) {
                build.keep(pit, nl - 1, y, h);
            }
        }
        # A stretch of the ledge's edge left open, to jump from.
        for y in range(middle - 1, middle + 2) {
            build.keep(pit, nl - 1, y, h);
        }
        build.touch(float(nl - 2), float(middle - 1), float(h), float(nl), float(middle + 2), float(h + 6), True, "You can jump down from here");
        # The far strip at the water's other side, a lift up to the far
        # ledge.
        lift(build, self.long - 10, 2, self.long - 7, 5, 0, h);
        for y in range(2, 5) {
            build.keep(pit, self.long - 7, y, h);
            build.keep(pit, self.long - 11, y, 0);
        }
        if self.bridge {
            build.solid(nl, self.wide - 4, h - 1, self.long - 7, self.wide - 1, h);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(pit, nl - 1, y, h);
                build.keep(pit, self.long - 7, y, h);
            }
        }
        if self.grate {
            e2m6_grate(build, nl + 2, nl + 6, d + 2, -d, "item_artifact_super_damage");
        }
        for port in self.taken {
            build.doorway(pit, port);
        }
        # Landing on the low floor brings the dead in by teleporter; the far
        # ledge's keepers wake as the player reaches the far strip.
        below = build.touch(float(nl), 1.0, 0.0, float(nl + 6), float(self.wide - 1), 6.0);
        late = build.delay(1.0);
        below +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(1 + index * 4, 2, -9, "monster_zombie", float(nl) + 4.5, float(middle) - 1.5 + float(index) * 3.0, 0, 180.0);
        }
        across = build.touch(float(self.long - 11), 1.0, 0.0, float(self.long - 7), float(self.wide - 1), 6.0);
        guard = build.waiting();
        across +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 4.5 + float(index) * 5.0, h, E2M6_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(float(self.long) - 4.5, 2.5, h, "monster_ogre", 90.0, patrol=[[float(self.long) - 4.5, 2.5], [float(self.long) - 4.5, float(self.wide) - 2.5]]);
        build.foe(float(nl + 12) + 0.5, float(middle) + 0.5, 5, "monster_wizard", 180.0);
        build.foe(float(nl + 9) + 0.5, float(middle) + 0.5, -d + 1, "monster_fish", 0.0);
        build.start(2.5, float(middle) + 0.5, h, 0.0);
        build.supply(2.5, float(middle) - 1.5, h, "item_shells");
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, h, "item_health");
    }
}

"""A hall whose floor is a lake, a gallery round two walls, a lift to it
behind bars a button opens."""
node SunkenLake(Prefab) {
    has deep: int = 7,
        isle: bool = True,
        stash: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sunken lake";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(30, 34);
        self.wide = dice.between(22, 26);
        self.deep = dice.between(6, 8);
        self.isle = dice.chance(0.6);
        self.stash = dice.chance(0.5);
        self.tall = 9 + dice.between(10, 12);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=9), Port(face=0, along=float(self.wide - 3), floor=9), Port(face=3, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deep;
        s = 9;
        middle = self.wide // 2;
        fx = self.long - 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, s);
        e2m4_moat(build, 6, fx, 1, self.wide - 1, d, 0, True);
        # The gallery along the north and east walls.
        build.solid(7, self.wide - 5, s - 1, self.long - 1, self.wide - 1, s);
        build.solid(self.long - 5, 6, s - 1, self.long - 1, self.wide - 1, s);
        # The lift up to it in an alcove behind bars at the far landing.
        build.solid(self.long - 5, 1, 0, self.long - 4, 6, s);
        build.solid(self.long - 4, 5, 0, self.long - 1, 6, s);
        build.widen(hall, self.long - 5, 2, 0, self.long - 4, 5, 8);
        bars = e2m4_bars(build, float(self.long - 5), 2.0, float(self.long - 4), 5.0, 0, 8, "This door opens elsewhere...");
        lift(build, self.long - 4, 1, self.long - 1, 5, 0, s);
        for x in range(self.long - 4, self.long - 1) {
            build.keep(hall, x, 5, s);
            build.keep(hall, x, 6, s);
        }
        # The button that opens the bars: on an island in the lake (steps up
        # onto it from the water), or under the water on the south wall.
        press: Cue | None = None;
        if self.isle {
            ix = self.long // 2 - 1;
            iy = middle - (d + 1) // 2 - 1;
            build.solid(ix, iy, -d, ix + 3, iy + d + 1, 0);
            for step in range(d) {
                build.solid(ix - 2, iy + step, -d, ix, iy + step + 1, -d + step + 1);
            }
            build.solid(ix + 2, iy + 1, 0, ix + 3, iy + 2, 3);
            press = build.push(float(ix + 2), float(iy) + 1.5, 1.2, 2);
        } else {
            press = build.push(float(self.long // 2), 1.0, 6.0, 1, True);
            # A raft riding to and fro across the lake.
            build.train([4.0, 4.0, 1.0], [[6.0, float(middle - 2), -1.0], [float(fx - 4), float(middle - 2), -1.0]], 70.0, 2.0);
            for y in range(middle - 2, middle + 2) {
                build.keep(hall, 5, y, 0);
                build.keep(hall, fx, y, 0);
            }
        }
        if press is not None {
            press +>:Fires:+> bars;
            press +>:Fires:+> e2m6_say(build, "The second floor is accessible");
            late = build.delay(1.5);
            press +>:Fires:+> late;
            late +>:Fires:+> build.summon(1, 2, -9, "monster_zombie", float(fx) + 2.5, float(middle) + 3.5, 0, 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The far landing's keeper wakes as the player comes to the water.
        brink = build.touch(4.0, 1.0, 0.0, 6.0, float(self.wide - 1), 6.0);
        guard = build.waiting();
        brink +>:Fires:+> guard;
        build.foe(float(fx) + 2.5, float(middle) - 1.5, 0, E2M6_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        for index in range(dice.between(1, 2)) {
            build.foe(float(fx) + 3.5, float(middle) + 2.5 + float(index) * 3.0, 0, E2M6_FOES.pick(dice, self.danger), 180.0, waits=guard);
        }
        build.foe(8.5, float(self.wide) - 3.0, s, "monster_hell_knight" if self.danger > 0.3 else "monster_knight", 0.0, patrol=[[8.5, float(self.wide) - 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [float(self.long) - 3.0, 7.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 7) + 0.5, float(middle) + 0.5, 4, "monster_wizard", 180.0);
        }
        build.foe(12.5, float(middle) - 3.5, -d + 1, "monster_fish", 0.0);
        if self.stash {
            build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 8);
            e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 1, 0, 3, "item_armor2");
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.0, s, "item_health");
        build.supply(float(fx) + 1.5, float(self.wide) - 3.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""Water crossed to an island and on to a far shore by two bridges that
rise as the player comes to each edge, spikes across them."""
node ChangingBridge(Prefab) {
    has deep: int = 5,
        first: int = 7,
        second: int = 7,
        lane_one: int = 8,
        lane_two: int = 9,
        upper: bool = False,
        spiky: bool = True,
        stash: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Changing bridge";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.upper = dice.chance(0.5);
        self.spiky = dice.chance(0.6);
        self.stash = dice.chance(0.5);
        self.first = dice.between(6, 8);
        self.second = dice.between(6, 8);
        self.long = 6 + self.first + 3 + self.second + 7;
        self.wide = dice.between(20, 22) if self.upper else dice.between(18, 22);
        self.lane_one = dice.between(self.deep + 2, self.wide - self.deep - 5);
        self.lane_two = dice.between(self.deep + 2, self.wide - self.deep - 5);
        self.tall = 19 if self.upper else 12;
        self.low = -2 * self.deep - 3;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        if self.upper {
            self.leaves = [Port(face=0, along=3.0, floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=1, along=4.0, floor=9)];
        } else {
            self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deep;
        p0 = 6;
        i0 = p0 + self.first;
        p1 = i0 + 3 + self.second;
        one = self.lane_one;
        two = self.lane_two;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        e2m4_moat(build, p0, p1, 1, self.wide - 1, d, 0, True);
        # The island, long across the way and short along it.
        build.solid(i0, min(one, two) - 1, -d, i0 + 3, max(one, two) + 4, 0);
        # Walking up to the near edge raises the first bridge; to the
        # island's far edge, the second.
        near = build.touch(float(p0 - 2), float(one), 0.0, float(p0), float(one + 3), 6.0, True, "A bridge has been raised.");
        near +>:Fires:+> build.drawn(float(p0), float(one), float(i0), float(one + 3), 0, d + 1);
        middle_touch = build.touch(float(i0 + 1), float(two), 0.0, float(i0 + 3), float(two + 3), 6.0, True, "The center bridge has changed.");
        middle_touch +>:Fires:+> build.drawn(float(i0 + 3), float(two), float(p1), float(two + 3), 0, d + 1);
        for y in range(one, one + 3) {
            build.keep(hall, p0 - 1, y, 0);
            build.keep(hall, i0, y, 0);
        }
        for y in range(two, two + 3) {
            build.keep(hall, i0 + 2, y, 0);
            build.keep(hall, p1, y, 0);
        }
        # Spikes shoot across each bridge while anyone is on it.
        if self.spiky {
            on_one = build.touch(float(p0), float(one), 0.0, float(i0), float(one + 3), 6.0, False);
            on_one +>:Fires:+> build.spikes(float(p0 + self.first // 2) + 0.5, 1.2, 1.5, 1);
            on_two = build.touch(float(i0 + 3), float(two), 0.0, float(p1), float(two + 3), 6.0, False);
            on_two +>:Fires:+> build.spikes(float(i0 + 3 + self.second // 2) + 0.5, float(self.wide) - 1.2, 1.5, 3);
        }
        if self.upper {
            u = 9;
            build.level(hall, u);
            # The walkway high along the north wall back over the water, a
            # stair up to it on the far shore.
            build.solid(1, self.wide - 5, u - 1, self.long - 1, self.wide - 1, u);
            stair(build, self.long - 4, self.wide - 5 - u, 0, 1, u, 3);
            for x in range(self.long - 4, self.long - 1) {
                build.keep(hall, x, self.wide - 5, u);
            }
            build.foe(4.5, float(self.wide) - 3.0, u, "monster_ogre", 0.0, patrol=[[4.5, float(self.wide) - 3.0], [float(p1) - 2.5, float(self.wide) - 3.0]]);
            build.supply(2.5, float(self.wide) - 2.5, u, "item_rockets");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The far shore's guard wakes as the second bridge rises; the dead
        # are brought in behind the player as the first does.
        guard = build.waiting();
        middle_touch +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(p1) + 2.5, 3.5 + float(index) * 4.0, 0, E2M6_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        late = build.delay(2.0);
        near +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -2 * d - 2, "monster_zombie", 2.5, float(self.wide // 2) + 2.5, 0, 0.0);
        build.foe(float(p1) + 1.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(p1) + 1.5, 2.5], [float(p1) + 1.5, float(self.wide) - 6.5]]);
        build.foe(float(i0) + 1.5, float(self.wide // 2) + 0.5, 4, "monster_wizard", 180.0);
        build.foe(float(p0 + 3) + 0.5, 2.5, -d + 1, "monster_fish", 0.0);
        if self.stash {
            build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 8);
            e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 1, 0, 3, "item_health");
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A corridor between two rows of barred cells, a gallery over each row, a
stair up at the far end behind bars a button in a cell opens."""
node CellBlock(Prefab) {
    has gallery: int = 9,
        barred: bool = True,
        bridged: bool = True,
        button_cell: int = 0,
        stash: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell block";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(30, 34);
        self.wide = dice.between(20, 22);
        self.gallery = 9;
        self.barred = dice.chance(0.7);
        self.bridged = dice.chance(0.5);
        self.button_cell = dice.below(3);
        self.stash = dice.chance(0.5);
        self.tall = dice.between(17, 19);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        under = g - 1;
        block = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(block, g);
        # The cells: walls every four cells along each row, under the
        # galleries.
        cells: list[int] = [];
        for x in range(4, self.long - g - 6, 4) {
            build.solid(x, 1, 0, x + 1, 5, under);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 1, under);
            build.solid(x + 4, 1, 0, x + 5, 5, under);
            build.solid(x + 4, self.wide - 5, 0, x + 5, self.wide - 1, under);
            cells.append(x);
        }
        build.solid(1, 1, under, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, under, self.long - 1, self.wide - 1, g);
        build.solid(self.long - 4, 5, under, self.long - 1, self.wide - 5, g);
        if self.bridged {
            mx = self.long // 2 - 6;
            build.solid(mx, 5, under, mx + 3, self.wide - 5, g);
            for x in range(mx, mx + 3) {
                build.keep(block, x, 4, g);
                build.keep(block, x, self.wide - 5, g);
            }
        }
        for y in range(5, self.wide - 5) {
            build.keep(block, self.long - 4, y, g);
        }
        # The stair up to the south gallery in its well at the far end, bars
        # across its foot.
        sx = self.long - 4 - g;
        stair(build, sx, 5, 0, 0, g, 3);
        build.solid(sx - 1, 8, 0, self.long - 4, 9, g);
        build.solid(sx - 1, 4, 0, self.long - 4, 5, under);
        for x in range(self.long - 7, self.long - 4) {
            build.keep(block, x, 4, g);
        }
        stair_bars = e2m4_bars(build, float(sx - 1), 5.0, float(sx), 8.0, 0, 8, "This door opens elsewhere...");
        build.doorway(block, self.enter);
        for port in self.taken {
            build.doorway(block, port);
        }
        # Walking up the corridor opens the cells on their dead.
        corridor = build.touch(float(self.long // 2 - 2), float(middle - 2), 0.0, float(self.long // 2 + 2), float(middle + 2), 6.0);
        dead = build.waiting();
        corridor +>:Fires:+> dead;
        for (index, x) in enumerate(cells) {
            if self.barred {
                corridor +>:Fires:+> e2m4_bars(build, float(x + 1), 4.0, float(x + 4), 5.0, 0, under, "");
                corridor +>:Fires:+> e2m4_bars(build, float(x + 1), float(self.wide - 5), float(x + 4), float(self.wide - 4), 0, under, "");
            }
            if index % 2 == 0 {
                build.foe(float(x) + 2.5, 2.5, 0, "monster_zombie", 90.0, waits=dead);
            } else {
                build.foe(float(x) + 2.5, float(self.wide) - 2.5, 0, E2M6_FOES.pick(dice, self.danger), 270.0, waits=dead);
            }
        }
        # A button on the back wall of a cell opens the stair's bars.
        if cells {
            cx = cells[min(self.button_cell, len(cells) - 1)];
            press = build.push(float(cx) + 2.5, 1.0, 1.5, 1);
            press +>:Fires:+> stair_bars;
            press +>:Fires:+> e2m6_say(build, "The third floor is accessible");
        } else {
            corridor +>:Fires:+> stair_bars;
        }
        # Coming up the stair brings the dead in behind the player.
        top = build.touch(float(self.long - 7), 5.0, float(g), float(self.long - 4), 8.0, float(g + 6));
        late = build.delay(1.0);
        top +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(2 + index * 5, 6, -8, "monster_zombie", float(sx) - 3.5, float(middle) - 1.5 + float(index) * 3.0, 0, 180.0);
        }
        build.foe(7.5, float(self.wide) - 3.0, g, "monster_hell_knight" if self.danger > 0.3 else "monster_knight", 0.0, patrol=[[7.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 6.5, 3.0, g, E2M6_FOES.pick(dice, self.danger, True), 180.0);
        if self.stash {
            build.solid(1, self.wide - 5, g, 6, self.wide - 1, g + 6);
            e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 2, g, 0, "item_artifact_super_damage");
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, g, "item_health");
        build.supply(float(self.long) - 6.5, float(middle) + 3.5, 0, "item_spikes");
        build.supply(3.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""A well entered at its top, a stair winding down round its walls to a
pool at its foot."""
node DeepWell(Prefab) {
    has steps: int = 28,
        tall: int = 36;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deep well";
        self.source = E2M6;
        self.district = level_district(E2M6);
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
        self.low = -10;
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
        e2m4_moat(build, 5, self.long - 5, 5, self.wide - 5, 4);
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        lap = len(path);
        # Scrags wake as the player comes halfway down.
        half = path[(self.steps // 2) % lap];
        down = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        air = build.waiting();
        down +>:Fires:+> air;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 4 + index * 6, "monster_wizard", float(index * 120), waits=air);
        }
        # Coming to the foot wakes what keeps it and brings the dead in onto
        # the stair behind.
        foot = build.touch(4.0, 4.0, 0.0, float(self.long - 4), 5.0, 6.0);
        keeper = build.waiting();
        foot +>:Fires:+> keeper;
        build.foe(float(self.long) - 4.5, float(self.wide // 2) + 0.5, 0, E2M6_FOES.pick(dice, self.danger, True), 180.0, waits=keeper);
        late = build.delay(1.5);
        foot +>:Fires:+> late;
        behind = path[(self.steps // 3) % lap];
        late +>:Fires:+> build.summon(1, 1, -9, "monster_zombie", float(behind[0] + behind[2]) * 0.5, float(behind[1] + behind[3]) * 0.5, self.steps // 3 + 1, 0.0);
        build.foe(4.5, 4.5, 0, "monster_zombie", 0.0, patrol=[[4.5, 4.5], [float(self.long) - 4.5, 4.5]]);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, -3, "monster_fish", 0.0);
        build.supply(float(self.long) - 4.5, float(self.wide) - 4.5, 0, "item_health");
        build.supply(2.5, 2.5, 1, "item_shells");
    }
}

"""The key room: a deep pool, the key behind a grate at its bottom, a lift
up out of the water."""
node DrownedKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 7,
        grated: bool = True,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drowned key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(7, 9);
        self.grated = dice.chance(0.7);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 6;
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
        d = self.deep;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The pool, steps out of it along its near side at both ends.
        build.pool(6, 4, -d, self.long - 4, side - 3, 0, 2, False, True, True);
        # The niche at the pool's far wall behind its grate, the button on
        # a post on the rim, and a lift up out of the water before it.
        key_at = [float(self.long) - 9.5, float(cy) + 0.5];
        if self.grated {
            build.room(self.long - 4, cy - 1, -d, self.long - 1, cy + 2, -d + 4);
            for z in range(-d, -d + 4) {
                for y in range(cy - 1, cy + 2) {
                    for x in range(self.long - 4, self.long - 1) {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
            grate = e2m4_bars(build, float(self.long - 4), float(cy - 1), float(self.long - 3), float(cy + 2), -d, 4, "The grate opens elsewhere...");
            build.solid(self.long - 3, 1, 0, self.long - 2, 2, 3);
            build.push(float(self.long - 3), 1.5, 1.2, 2) +>:Fires:+> grate;
            key_at = [float(self.long) - 2.0, float(cy) + 0.5];
        }
        lift(build, self.long - 7, cy - 1, self.long - 4, cy + 2, -d, 0);
        for y in range(cy - 1, cy + 2) {
            build.keep(hall, self.long - 4, y, 0);
        }
        # The key; taking it opens the closets along the side wall and
        # brings the dead in on the rim.
        taken = e2m4_key(build, self.key, key_at[0], key_at[1], -d);
        out = build.waiting();
        taken +>:Fires:+> out;
        for (index, at) in enumerate([2, self.long - 6]) {
            closet = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(closet, at, side, 0, at + 3, side + 1, 6);
            door = {"wait": "-1"};
            build.rising_door(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0, door);
            taken +>:Fires:+> build.cue([door], "door");
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E2M6_FOES.pick(dice, self.danger, index == 0), 270.0, waits=out);
        }
        late = build.delay(1.0);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 3, -9, "monster_zombie", 3.5, 2.5, 0, 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(9 + index * 5) + 0.5, float(cy) + 2.5, -d + 1, "monster_fish", 0.0);
        }
        build.foe(float(self.long) - 2.5, float(side) - 1.5, 0, E2M6_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 2.5, float(side) - 1.5], [3.5, float(side) - 1.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(3.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a cavern of water, a raft out to the island of the
slipgate, a balcony over the water."""
node DismalExit(Prefab) {
    has key: str = "",
        rafted: bool = True,
        stash: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dismal exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(30, 34);
        self.wide = dice.between(20, 22);
        self.rafted = dice.chance(0.8);
        self.stash = dice.chance(0.5);
        self.tall = dice.between(15, 17);
        self.low = -10;
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
        d = 6;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        cavern = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cavern, 8);
        build.doorway(hall, self.enter);
        build.widen(cavern, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        # The door: the gold door as a gate (its opening bringing fiends in);
        # else a touch past it.
        through = e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "You must grab the Black Magic", self.key) if self.key else build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        # The water from the shore to the far wall, the island in it with a
        # stair up its south side, the slipgate on it.
        x0 = wall + 5;
        e2m4_moat(build, x0, self.long - 1, 1, self.wide - 1, d, 0, True);
        ix = (x0 + self.long - 1) // 2 + 2;
        build.solid(ix - 2, middle - 3, -d, ix + 3, middle + 3, 0);
        stair(build, ix - 1, middle - 3 - d, -d, 1, d, 3);
        build.way_out(float(ix) + 0.5, float(middle), 0);
        # The raft set riding out to the island as the player comes to the
        # water.
        brink = build.touch(float(x0 - 2), 1.0, 0.0, float(x0), float(self.wide - 1), 6.0);
        if self.rafted {
            brink +>:Fires:+> build.train([3.0, 3.0, 1.0], [[float(x0), float(middle - 1), -1.0], [float(ix - 5), float(middle - 1), -1.0]], 70.0, 2.0, True);
            for y in range(middle - 1, middle + 2) {
                build.keep(cavern, x0 - 1, y, 0);
                build.keep(cavern, ix - 2, y, 0);
            }
        }
        # The balcony along the south wall over the water, a lift up to it
        # from the shore; ogres on it wake at the water's edge.
        build.solid(wall + 1, 1, 7, self.long - 1, 4, 8);
        lift(build, wall + 1, 5, wall + 4, 8, 0, 8);
        for x in range(wall + 1, wall + 4) {
            build.keep(cavern, x, 4, 8);
        }
        wake = build.waiting();
        brink +>:Fires:+> wake;
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 4 + index * 6) + 0.5, 2.5, 8, "monster_ogre", 90.0, waits=wake);
        }
        build.foe(float(ix) + 1.5, float(middle) + 1.5, 0, E2M6_FOES.pick(dice, self.danger, True), 180.0, waits=wake);
        # Fiends brought in on the shore as the door opens.
        late = build.delay(3.0);
        through +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -9, E2M6_FOES.pick(dice, self.danger, True), float(wall) + 3.5, float(middle) + 4.5, 0, 0.0);
        late +>:Fires:+> build.summon(5, 2, -9, "monster_demon1" if self.danger > 0.4 else "monster_ogre", float(wall) + 2.5, float(middle) + 2.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 6.5 + float(index) * 4.0, 0, E2M6_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 4.5, float(middle) + 4.5, -d + 1, "monster_fish", 0.0);
        if self.stash {
            build.solid(1, 1, 0, 6, 5, 8);
            e2m4_stash(build, 2, 1, 4, 3, 0, 1, "item_artifact_super_damage");
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(wall) + 2.5, float(self.wide) - 2.5, 0, "item_rockets");
    }
}

"""e2m6's stretches: [name, role]."""
glob E2M6_STRETCHES: list[list[str]] = [
         ["ledge", "start"],
         ["lake", "flow"],
         ["bridge", "flow"],
         ["well", "flow"],
         ["cells", "hub"],
         ["lake", "hub"],
         ["cells", "flow"],
         ["drowned", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m6's stretches by its name."""
def make_e2m6(name: str, key: str) -> Prefab {
    if name == "ledge" {
        return OublietteLedge();
    }
    if name == "lake" {
        return SunkenLake();
    }
    if name == "bridge" {
        return ChangingBridge();
    }
    if name == "well" {
        return DeepWell();
    }
    if name == "cells" {
        return CellBlock();
    }
    if name == "drowned" {
        return DrownedKey(key=key if key else "key_gold");
    }
    return DismalExit(key=key);
}
