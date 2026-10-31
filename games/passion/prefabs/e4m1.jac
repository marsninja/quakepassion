"""Prefabs drawn from e4m1, the Sewage System: sewers of metal and stone
flooded deep, channels down halls between walkways and under catwalks,
flood gates closed across them until a button far off opens them ("You
have opened the flood gate"), locks stepping down level by level, deep
settling tanks, cisterns dropped into, grunts and enforcers walking their
rounds and teleported in behind. Raised in e4m1's own palette.

- `SewerOutfall`: the start. A deep channel down the length of a hall
  between two walkways, a pipe over its end, a catwalk across it high up
  climbed to by a stair, a footbridge low across it; a quad damage in an
  alcove under the water (a secret).
- `FloodGate`: a deep channel through a wall, a flood gate across it
  ("This flood gate is closed..."): a button on a control platform (and,
  by the dice, another down in the water, counted together) opens it, and
  the way on is swum through; enforcers teleport in beyond.
- `SewerLocks`: three floors stepping down a hall one under another, a
  deep basin in each, a catwalk along the wall over them all, a platform
  riding up and down between the lowest floor and the catwalk.
- `SettlingTanks`: two deep tanks either side of a spine raised down a
  hall, a stair up it, bridges from it over the tanks to ledges on the
  side walls; ways on from the floor, the spine and the ledges (a hub).
- `CisternDrop`: a ledge high over a deep cistern; a catwalk along the
  wall broken over the water (or whole once a shot button draws out its
  missing span), a drop into the water, its steps up to a low floor, and
  a lift (or a teleporter) back up to the way on.
- `SumpKey`: the key room. The key on a shelf across a deep sump, swum to;
  taking it opens the closets and teleports grunts in.
- `SewerExit`: the end. A door (a key's, as a gate), a walkway over a deep
  channel to the slipgate, enforcers teleported in as it is crossed."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix }
import from .common { stair, pillars, key_ambush, lift, key_item }
import from .e3m5 { keep_run, sealed_way, bursting }
import from .e3m6 { rounds }

glob E4M1: str = "q1:e4m1";

"""e4m1's foes: grunts and dogs, enforcers growing with the danger."""
glob E4M1_FOES: FoeMix = FoeMix(light=["monster_army", "monster_army", "monster_dog"], strong=["monster_enforcer"], heavy_light=["monster_enforcer", "monster_army"]);

"""An alcove under the water off a pool: the prefab's cells x0..x1, y0..y1
from lift z0 three lifts up, carved and flooded, a secret in it and a
pickup of `kind`."""
def drowned_alcove(build: Raising, x0: int, y0: int, x1: int, y1: int, z0: int, kind: str) {
    build.room(x0, y0, z0, x1, y1, z0 + 3);
    for z in range(z0, z0 + 3) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                build.liquid(x, y, z, 2);
            }
        }
    }
    build.secret(float(x0), float(y0), float(z0), float(x1), float(y1), float(z0 + 3));
    build.supply(float(x0 + x1) * 0.5, float(y0 + y1) * 0.5, z0, kind);
}

"""The start: a deep channel down a hall between walkways, a catwalk across
it high up, a footbridge low across it."""
node SewerOutfall(Prefab) {
    has deep: int = 10,
        catwalk: int = 8,
        tall: int = 17,
        cx: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer outfall";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.deep = min(dice.between(10, 12), self.wide - 10);
        self.catwalk = dice.between(8, 9);
        self.tall = self.catwalk + 9;
        self.cx = dice.between(14, self.long - 14);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=3.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=0),
            Port(face=1, along=float(self.cx) + 1.5, floor=self.catwalk),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cy = wide // 2;
        u = self.catwalk;
        cx = self.cx;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The channel down the hall, its steps along its south edge.
        build.pool(5, 5, -self.deep, long - 5, wide - 5, 0, 2);
        # The pipe: a block on the far wall over the channel's end.
        build.solid(long - 3, cy - 2, 5, long - 1, cy + 2, 9);
        # The catwalk across high up: a stair up the south walkway to it,
        # over the channel to the north wall.
        stair(build, cx - u, 1, 0, 0, u, 3);
        build.solid(cx, 1, u - 1, cx + 3, wide - 1, u);
        keep_run(build, hall, cx - 2, 1, cx + 1, 4, u);
        keep_run(build, hall, cx, 4, cx + 3, 5, u);
        # Ledges jutting out over the channel from both walkways, its
        # middle open; drops off them into the water.
        build.solid(9, 5, -1, long - 5, 8, 0);
        build.solid(9, wide - 8, -1, long - 5, wide - 5, 0);
        keep_run(build, hall, 12, 7, 15, 8, 0);
        keep_run(build, hall, long - 13, wide - 8, long - 10, wide - 7, 0);
        # A footbridge low across the channel near its far end.
        fx = long - 10;
        build.solid(fx, 5, -1, fx + 3, wide - 5, 0);
        keep_run(build, hall, fx, 4, fx + 3, 5, 0);
        keep_run(build, hall, fx, wide - 5, fx + 3, wide - 4, 0);
        # An alcove under the water off the channel's north side.
        ax = cx + 5 + dice.below(max(1, fx - cx - 8));
        drowned_alcove(build, ax, wide - 5, ax + 2, wide - 3, -self.deep, "item_artifact_super_damage");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        # Grunts walk the walkways; the catwalk's guard wakes as the stair
        # is climbed.
        rounds(build, "monster_army", 6.5, 2.5, float(long) - 4.5, 2.5, 0);
        rounds(build, E4M1_FOES.pick(dice, self.danger), float(long) - 4.5, float(wide) - 2.5, 6.5, float(wide) - 2.5, 0);
        climb = build.touch(float(cx - u), 1.0, 0.0, float(cx - u + 3), 4.0, 6.0);
        guard = build.waiting();
        climb +>:Fires:+> guard;
        build.foe(float(cx) + 1.5, float(wide) - 3.5, u, E4M1_FOES.pick(dice, self.danger, True), 270.0, waits=guard);
        build.foe(float(long) - 3.5, float(wide) - 3.0, 0, "monster_dog", 180.0, waits=guard);
        build.supply(float(long) - 2.5, float(wide) - 2.5, 0, "item_health");
    }
}

"""A deep channel through a wall, a flood gate across it opened by a
button on a control platform (and one under the water)."""
node FloodGate(Prefab) {
    has deep: int = 10,
        deck: int = 7,
        tall: int = 15,
        two: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flood gate";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.deep = dice.between(9, 10);
        self.long = 2 * self.deep + dice.between(12, 14);
        self.wide = dice.between(20, 22);
        self.deck = dice.between(6, 7);
        self.tall = self.deck + dice.between(8, 9);
        self.two = dice.chance(0.5);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy - 7), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy - 7), floor=0),
            Port(face=0, along=float(cy + 7), floor=0),
            Port(face=1, along=float(self.long - 5), floor=0),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cy = wide // 2;
        d = self.deep;
        p = self.deck;
        gx = long // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, p);
        # The channel down the hall, its steps out on the near side, its own
        # stair out on the far side.
        build.pool(4, cy - 5, -d, long - 4, cy + 5, 0, 2);
        stair(build, long - 4 - d, cy - 1, -d, 0, d, 2);
        # Ledges jutting out over the channel from both walkways on both
        # sides of the gate, its middle open.
        for (x0, x1) in [(8, gx - 6), (gx + 2, long - 4)] {
            build.solid(x0, cy - 5, -1, x1, cy - 1, 0);
            build.solid(x0, cy + 1, -1, x1, cy + 5, 0);
        }
        keep_run(build, hall, 10, cy - 2, 13, cy - 1, 0);
        keep_run(build, hall, gx + 4, cy + 1, gx + 7, cy + 2, 0);
        # The wall across the hall, the flood gate in it over the channel.
        build.solid(gx, 1, -d, gx + 1, wide - 1, self.tall);
        build.widen(hall, gx, cy - 5, -d, gx + 1, cy + 5, 2);
        gate: dict[str, str] = {"wait": "-1", "message": "This flood gate is closed..."};
        build.rising_door(float(gx), float(cy - 5), float(-d), float(gx + 1), float(cy + 5), 2.0, gate);
        opens = build.cue([gate], "door");
        balcony = build.waiting();
        # The control platform along the north wall on the near side, a
        # stair up to it, its button; by the dice a second button down in
        # the water by the gate, the two counted together.
        build.solid(gx - 6, 1, p - 1, gx, wide - 1, p);
        stair(build, gx - 6 - p, 1, 0, 0, p, 3);
        # A gallery along the north wall from the deck back over the near
        # walkway, and beyond the gate a balcony along the south wall where
        # enforcers stand.
        build.solid(4, wide - 4, p - 1, gx - 6, wide - 1, p);
        build.solid(gx + 1, 1, p - 1, long - 6, 4, p);
        build.solid(gx + 1, wide - 4, p - 1, long - 8, wide - 1, p);
        # A bridge across the channel between the far balconies.
        build.solid(long - 12, 4, p - 1, long - 9, wide - 4, p);
        keep_run(build, hall, 8, wide - 5, 12, wide - 4, p);
        for index in range(dice.between(1, 2)) {
            build.foe(float(gx + 4 + index * 5) + 0.5, 2.5, p, "monster_enforcer", 90.0, waits=balcony);
        }
        keep_run(build, hall, gx - 8, 1, gx - 5, 4, p);
        keep_run(build, hall, gx - 6, 5, gx - 5, wide - 5, p);
        press = build.push(float(gx), float(cy) + 0.5, float(p) + 1.2, 2);
        if self.two {
            both = build.tally(2, "You have opened the flood gate");
            press +>:Fires:+> both;
            build.push(float(gx) - 8.5, float(cy + 5), float(-d) + 1.5, 3) +>:Fires:+> both;
            opener = both;
            build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Two switches work the flood gate");
        } else {
            opener = press;
        }
        later = build.delay(0.5);
        opener +>:Fires:+> later;
        later +>:Fires:+> opens;
        later +>:Fires:+> balcony;
        build.touch(float(gx + 1), float(cy - 5), float(-d), float(gx + 3), float(cy + 5), 2.0, True, "You have opened the flood gate");
        # Beyond the gate, enforcers teleported in as it opens.
        later +>:Fires:+> build.summon(1, 1, -d - 2, E4M1_FOES.pick(dice, self.danger, True), float(long) - 4.5, 3.5, 0, 180.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Grunts walk the near walkways and the far ones.
        rounds(build, "monster_army", 3.5, 3.5, float(gx) - 2.5, 3.5, 0);
        rounds(build, E4M1_FOES.pick(dice, self.danger), float(gx) + 3.5, float(wide) - 3.5, float(long) - 3.5, float(wide) - 3.5, 0);
        up = build.touch(float(gx - 6 - p), 1.0, 0.0, float(gx - 6), 4.0, float(p + 6));
        deck_guard = build.waiting();
        up +>:Fires:+> deck_guard;
        build.foe(float(gx) - 2.5, float(wide) - 2.5, p, E4M1_FOES.pick(dice, self.danger, True), 270.0, waits=deck_guard);
        build.foe(float(long) - 3.5, float(cy) - 7.5, 0, E4M1_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(gx) - 2.5, 2.5, p, "item_health");
        build.supply(float(long) - 2.5, float(wide) - 2.5, 0, "item_shells");
    }
}

"""Three floors stepping down a hall, a deep basin in each, a catwalk over
them all, a platform riding up and down at the far end."""
node SewerLocks(Prefab) {
    has step_down: int = 4,
        tall: int = 14,
        riser: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer locks";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(28, 31);
        self.wide = dice.between(15, 17);
        self.step_down = dice.between(4, 5);
        self.tall = dice.between(12, 14);
        self.riser = dice.chance(0.6);
        self.low = -2 * self.step_down - 14;
        self.high = self.tall + 1;
        bottom = -2 * self.step_down;
        self.enter = Port(face=2, along=float(self.wide // 2) - 2.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2) - 3.0, floor=bottom), Port(face=3, along=float(self.long - 4), floor=bottom), Port(face=0, along=float(self.wide - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        drop = self.step_down;
        bottom = -2 * drop;
        walk_y = wide - 5;
        hall = build.room(1, 1, bottom, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, -drop);
        build.level(hall, bottom);
        third = long // 3;
        # The floors: the first at the top, the second a drop down, the
        # third another, a stair down between each.
        build.solid(1, 1, bottom, third, walk_y, 0);
        build.solid(third, 1, bottom, 2 * third, walk_y, -drop);
        stair(build, third + drop - 1, 1, -drop, 2, drop, 3);
        stair(build, 2 * third + drop - 1, 1, bottom, 2, drop, 3);
        keep_run(build, hall, third - 1, 4, third, walk_y, 0);
        keep_run(build, hall, 2 * third - 1, 4, 2 * third, walk_y, -drop);
        # A deep basin in each floor.
        for (index, floor_at) in enumerate([0, -drop, bottom]) {
            x0 = index * third + (4 if index == 0 else 2);
            x1 = (index + 1) * third - 1 if index < 2 else long - 6;
            build.pool(x0, 4, floor_at - (walk_y - 5), x1, walk_y - 1, floor_at, 2);
            build.solid(x0 + 3, 4, floor_at - 1, x1, walk_y - 1, floor_at);
        }
        # The catwalk along the north wall at the top's height.
        build.solid(1, walk_y, bottom, third, wide - 1, 0);
        build.solid(third, walk_y, -1, long - 1, wide - 1, 0);
        for x in range(third + 4, long - 2, 6) {
            build.solid(x, walk_y, bottom, x + 1, walk_y + 1, -1);
        }
        keep_run(build, hall, third + 2, walk_y, third + 5, walk_y + 1, 0);
        # The way back up from the lowest floor to the catwalk at the far
        # end: a platform riding up and down, or a lift.
        if self.riser {
            build.train([3.0, 3.0, 1.0], [[float(long - 4), float(walk_y - 3), float(bottom - 1)], [float(long - 4), float(walk_y - 3), -1.0]], 90.0, 2.5);
        } else {
            lift(build, long - 4, walk_y - 3, long - 1, walk_y, bottom, 0);
        }
        keep_run(build, hall, long - 4, walk_y, long - 1, walk_y + 1, 0);
        keep_run(build, hall, long - 5, walk_y - 4, long - 1, walk_y, bottom);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Each floor's grunts wake as a body comes down the stair to it.
        for (index, floor_at) in enumerate([-drop, bottom]) {
            at = (index + 1) * third;
            down = build.touch(float(at), 1.0, float(floor_at), float(at + drop), 4.0, float(floor_at + 6));
            below = build.waiting();
            down +>:Fires:+> below;
            build.foe(float(at + third) - 2.5, float(walk_y) - 2.5, floor_at, E4M1_FOES.pick(dice, self.danger, index == 1), 180.0, waits=below);
        }
        rounds(build, E4M1_FOES.pick(dice, self.danger), float(2 * third) + 3.5, 3.5, float(long) - 5.5, 3.5, bottom);
        rounds(build, "monster_army", 3.5, float(wide) - 2.5, float(long) - 5.5, float(wide) - 2.5, 0);
        build.supply(float(long) - 6.5, 2.5, bottom, "item_health");
        build.supply(float(third) + 2.5, float(wide) - 2.5, 0, "item_shells");
    }
}

"""Two deep tanks either side of a spine raised down a hall, a stair up it,
bridges from it over the tanks to ledges on the side walls."""
node SettlingTanks(Prefab) {
    has spine: int = 5,
        deep: int = 10,
        tall: int = 17,
        bridges: bool = True,
        east: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Settling tanks";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(32, 34);
        self.wide = dice.between(24, 26);
        self.spine = dice.between(5, 6);
        self.deep = dice.between(8, 9);
        self.tall = self.spine + dice.between(15, 16);
        self.bridges = True;
        self.east = dice.chance(0.5);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        s = self.spine;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=s),
            Port(face=1, along=float(self.long // 2), floor=s if self.bridges else 0),
            Port(face=3, along=float(self.long // 2), floor=s if self.bridges else 0),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cy = wide // 2;
        s = self.spine;
        d = self.deep;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, s);
        # The spine down the middle from a stair at its near end to the far
        # wall, three cells wide.
        sx = 6 + s;
        build.solid(sx, cy - 1, 0, long - 1, cy + 2, s);
        stair(build, 6, cy - 1, 0, 0, s, 3);
        # The tanks either side of it, a stair up out of each at its near
        # end; past the stairs piers across each tank and ledges along its
        # outer side, over the water.
        tx0 = sx + 2;
        build.pool(tx0, 4, -d, long - 4, cy - 2, 0, 2, False, False);
        build.pool(tx0, cy + 3, -d, long - 4, wide - 4, 0, 2, False, False);
        stair(build, tx0 + d - 1, 6, -d, 2, d, 2);
        stair(build, tx0 + d - 1, wide - 8, -d, 2, d, 2);
        px = tx0 + d + 1;
        for x in range(px + 1, long - 6, 5) {
            if x + 4 <= long - 4 {
                build.solid(x, 4, -1, x + 4, cy - 2, 0);
                build.solid(x, cy + 3, -1, x + 4, wide - 4, 0);
            }
        }
        build.solid(px, 4, -1, long - 4, 7, 0);
        build.solid(px, wide - 7, -1, long - 4, wide - 4, 0);
        # A gantry at the spine's height over both tanks' near halves, over
        # their stairs; drops off it into the water.
        build.solid(tx0, 4, s - 1, px, wide - 4, s);
        keep_run(build, hall, px - 1, 6, px, cy - 3, s);
        keep_run(build, hall, px - 1, cy + 4, px, wide - 6, s);
        keep_run(build, hall, px + 4, 5, px + 6, 6, 0);
        if self.bridges {
            # Bridges from the spine over each tank to ledges on the side
            # walls at the spine's height.
            bx = long // 2 - 1 + (3 if self.east else 0);
            build.solid(sx, 1, s - 1, long - 1, 4, s);
            build.solid(sx, wide - 4, s - 1, long - 1, wide - 1, s);
            build.solid(bx, 4, s - 1, bx + 3, cy - 1, s);
            build.solid(bx, cy + 2, s - 1, bx + 3, wide - 4, s);
            keep_run(build, hall, bx - 3, 3, bx, 4, s);
            keep_run(build, hall, bx + 3, wide - 4, bx + 6, wide - 3, s);
        }
        # A high catwalk over the spine, a lift up to it from the spine's
        # near end, and a high bridge across both tanks near the far end.
        hi = s + 7;
        build.level(hall, hi);
        lift(build, sx, cy - 1, sx + 3, cy + 2, s, hi);
        build.solid(sx + 3, cy - 2, hi - 1, long - 3, cy + 3, hi);
        build.solid(long - 9, 1, hi - 1, long - 6, wide - 1, hi);
        keep_run(build, hall, sx + 3, cy - 2, sx + 4, cy + 3, hi);
        keep_run(build, hall, sx + 6, cy - 3, sx + 9, cy - 2, hi);
        build.foe(float(long) - 7.5, 3.5, hi, E4M1_FOES.pick(dice, self.danger), 90.0, patrol=[[float(long) - 7.5, 3.5], [float(long) - 7.5, float(wide) - 3.5]]);
        # Drops off the spine into the tanks.
        keep_run(build, hall, sx + 4, cy - 1, sx + 8, cy, s);
        keep_run(build, hall, sx + 4, cy + 1, sx + 8, cy + 2, s);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        up = build.touch(6.0, float(cy - 1), 0.0, float(sx), float(cy + 2), 6.0);
        guard = build.waiting();
        up +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx + 5 + index * 5) + 0.5, float(cy) + 0.5, s, E4M1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        rounds(build, "monster_army", float(sx) + 2.5, 2.5, float(long) - 3.5, 2.5, 0);
        rounds(build, "monster_dog", float(long) - 3.5, float(wide) - 2.5, float(sx) + 2.5, float(wide) - 2.5, 0);
        build.foe(float(long) - 2.5, float(cy) + 0.5, s, E4M1_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(long) - 2.5, float(cy) - 0.5, s, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""A ledge high over a deep cistern, a catwalk along the wall broken over
the water (or whole once a shot button draws out its span), a drop into
the water, its steps up to a low floor, a lift (or a teleporter) back
up."""
node CisternDrop(Prefab) {
    has down: int = 9,
        deep: int = 9,
        tall: int = 12,
        drawn_span: bool = False,
        tele_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern drop";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.down = dice.between(10, 12);
        self.deep = dice.between(10, 12);
        self.tall = dice.between(11, 13);
        self.drawn_span = dice.chance(0.5);
        self.tele_up = dice.chance(0.4);
        self.low = -self.down - 2 * self.deep - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=0, along=3.0, floor=-self.down)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        h = self.down;
        d = self.deep;
        cistern = build.room(1, 1, -h, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(cistern, 0);
        build.level(cistern, -h);
        # The near ledge and the far ledge at the top, the low floor at the
        # cistern's far side.
        build.solid(1, 1, -h, 7, wide - 1, 0);
        fx = long - 7;
        build.solid(fx, 5, -h, long - 1, wide - 1, 0);
        build.pool(7, 1, -h - d, fx - 4, wide - 1, -h, 2, False, False);
        stair(build, fx - 4 - d, middle - 1, -h - d, 0, d, 2);
        keep_run(build, cistern, 6, 2, 7, wide - 6, 0);
        # Ledges at the water's edge along both side walls, over it, from
        # the low floor back toward the near ledge.
        build.solid(9, 1, -h - 1, fx - 4, 4, -h);
        build.solid(9, wide - 4, -h - 1, fx - 4, wide - 1, -h);
        keep_run(build, cistern, 9, 3, 13, 4, -h);
        # A second catwalk along the south wall at the top, out to a drop
        # onto the low floor.
        build.solid(7, 1, -1, fx - 2, 4, 0);
        keep_run(build, cistern, fx - 3, 1, fx - 2, 4, 0);
        # Catwalks across the cistern between the two along the walls.
        for x in [9, fx - 9] {
            build.solid(x, 4, -1, x + 3, wide - 4, 0);
        }
        keep_run(build, cistern, 12, 6, 13, wide - 6, 0);
        # The catwalk along the north wall from ledge to ledge, a span of it
        # missing over the water (drawn out by the shot button, by the dice).
        build.solid(7, wide - 4, -1, fx, wide - 1, 0);
        gap = 7 + (fx - 7) // 2 - 2;
        build.widen(cistern, gap, wide - 4, -1, gap + 4, wide - 1, 0);
        if self.drawn_span {
            shot = build.cue([build.button(float(long - 1), 3.5, -float(h) + 4.0, 2, "", True)], "button");
            shot +>:Fires:+> build.drawn(float(gap), float(wide - 4), float(gap + 4), float(wide - 1), 0, h + 2);
        }
        keep_run(build, cistern, gap - 1, wide - 4, gap, wide - 1, 0);
        keep_run(build, cistern, gap + 4, wide - 4, gap + 5, wide - 1, 0);
        # Up from the low floor to the far ledge: a lift, or a teleporter.
        if self.tele_up {
            build.teleporter(float(fx) + 1.5, 3.0, -h, float(long) - 3.5, float(middle) + 0.5, 0, 180.0);
        } else {
            lift(build, fx, 2, fx + 3, 5, -h, 0);
            keep_run(build, cistern, fx, 5, fx + 3, 6, 0);
        }
        keep_run(build, cistern, fx - 4, 1, fx + 4, 5, -h);
        drowned_alcove(build, 4, 3, 7, 6, -h - d, "item_armor2" if dice.chance(0.6) else "item_artifact_super_damage");
        build.doorway(cistern, self.enter);
        for port in self.taken {
            build.doorway(cistern, port);
        }
        # What waits on the low floor wakes as a body hits the water.
        splash = build.touch(7.0, 1.0, float(-h - 2), float(fx - 4), float(wide - 1), float(-h + 1));
        below = build.waiting();
        splash +>:Fires:+> below;
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx) - 2.5, 2.5 + float(index) * 1.5, -h, E4M1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        rounds(build, E4M1_FOES.pick(dice, self.danger), float(fx) + 2.5, float(wide) - 3.5, float(long) - 3.5, float(wide) - 3.5, 0);
        build.supply(float(fx) - 2.5, float(wide) - 2.5, -h, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""The key on a shelf across a deep sump, swum to; taking it opens the
closets and teleports grunts in."""
node SumpKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 9,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sump key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(10, 12);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        long = self.long;
        cy = side // 2;
        d = self.deep;
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x1 = long - 5;
        build.pool(6, 1, -d, x1, side, 0, 2);
        stair(build, x1 - d, cy - 1, -d, 0, d, 2);
        build.solid(9, side - 4, -1, x1, side, 0);
        keep_run(build, hall, 12, side - 5, 15, side - 4, 0);
        # A catwalk high along the south wall over the sump, a lift up to it
        # from the near side, a drop off its far end onto the shelf.
        build.solid(4, 1, 6, x1, 4, 7);
        # Catwalks from it across the sump to the north wall.
        for x in [9, x1 - 5] {
            build.solid(x, 4, 6, x + 3, side, 7);
        }
        keep_run(build, hall, 12, 6, 13, side - 2, 7);
        lift(build, 1, 1, 4, 4, 0, 7);
        keep_run(build, hall, 4, 1, 5, 4, 7);
        keep_run(build, hall, x1 - 1, 1, x1, 4, 7);
        fields: dict[str, str] = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(long) - 2.5, float(cy) + 0.5, 0);
        taken = build.cue([fields], "key");
        for at in [2, long - 8] {
            build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(hall, at, side, 0, at + 3, side + 1, 6);
            taken +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E4M1_FOES.pick(dice, self.danger, at == 2), 270.0);
        }
        taken +>:Fires:+> build.summon(1, 5, -d - 2, E4M1_FOES.pick(dice, self.danger, True), 3.5, float(cy) + 0.5, 0, 0.0);
        drowned_alcove(build, 9, side, 11, side + 2, -d, "item_health");
        rounds(build, E4M1_FOES.pick(dice, self.danger), float(long) - 2.5, 2.5, float(long) - 2.5, float(side) - 2.5, 0);
        build.foe(float(x1) - 4.5, 2.5, 7, E4M1_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door, a walkway over a deep channel to the slipgate."""
node SewerExit(Prefab) {
    has key: str = "",
        deep: int = 9,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M1;
        self.district = level_district(E4M1);
        self.deep = dice.between(9, 11);
        self.long = self.deep + dice.between(19, 21);
        self.wide = dice.between(15, 17);
        self.tall = dice.between(12, 14);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        d = self.deep;
        wall = 8;
        hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The channel across the room, the walkway over it, steps up out of
        # it either side of the walkway.
        cx0 = wall + 3;
        cx1 = long - 5;
        build.pool(cx0, 1, -d, cx1, wide - 1, 0, 2, False, False);
        stair(build, cx1 - d, 1, -d, 0, d, 2);
        stair(build, cx1 - d, wide - 3, -d, 0, d, 2);
        build.solid(cx0, 3, -1, cx1, wide - 3, 0);
        keep_run(build, room, cx0 + 2, 3, cx0 + 5, 4, 0);
        build.way_out(float(long) - 3.0, float(middle), 0);
        # Crossing the walkway, enforcers teleported in at its far end.
        over = build.touch(float(cx0 + 3), float(middle - 1), 0.0, float(cx0 + 5), float(middle + 2), 6.0);
        over +>:Fires:+> build.summon(1, 1, -d - 2, E4M1_FOES.pick(dice, self.danger, True), float(cx1) + 1.5, 2.5, 0, 180.0);
        if dice.chance(0.6) {
            over +>:Fires:+> build.summon(1, wide - 5, -d - 2, "monster_enforcer", float(cx1) + 1.5, float(wide) - 2.5, 0, 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E4M1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        rounds(build, "monster_dog", float(cx1) + 2.5, 2.5, float(cx1) + 2.5, float(wide) - 2.5, 0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m1's stretches: [name, role]."""
glob E4M1_STRETCHES: list[list[str]] = [
         ["outfall", "start"],
         ["gate", "flow"],
         ["locks", "flow"],
         ["tanks", "hub"],
         ["tanks", "flow"],
         ["cistern", "flow"],
         ["cistern", "hub"],
         ["sump", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m1's stretches by its name."""
def make_e4m1(name: str, key: str) -> Prefab {
    if name == "outfall" {
        return SewerOutfall();
    }
    if name == "gate" {
        return FloodGate();
    }
    if name == "locks" {
        return SewerLocks();
    }
    if name == "tanks" {
        return SettlingTanks();
    }
    if name == "cistern" {
        return CisternDrop();
    }
    if name == "sump" {
        return SumpKey(key=key if key else "key_gold");
    }
    return SewerExit(key=key);
}
