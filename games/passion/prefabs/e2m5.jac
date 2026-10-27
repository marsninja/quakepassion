"""Prefabs drawn from e2m5, the Wizard's Manse: a manse of stone and wood
over a flooded underworks, its court and fountain, a cistern crossed on a
raft or swum, a grand stair down under a walkway, a sanctum of terraces
whose altar opens the way on, the gold key on a needle high in a spire
over a pool, and a gold door whose opening lets loose what waits behind
the walls. Raised in e2m5's own palette.

- `ManseCourt`: the start. A court under the sky, a fountain (or a canal
  across it, bridged or swum), a porch up a stair (or two) across its far
  end and in some a gallery over the porch ridden up to by a lift. Scrags
  are brought in as the player steps onto the porch (e2m5's teleported
  scrags) and what keeps the porch wakes; a knight walks it; a stash
  behind a wall in the court opens when shot.
- `CisternDive`: a cistern of deep water between a walkway and a far
  landing, crossed on a raft riding to and fro (e2m5's trains), along a
  walk by the wall, or swum; in some a stair up the far landing to a
  gallery over it and a catwalk back over the water to a gallery over the
  way in. Under the water a grate opens to a button beside it on a flooded
  niche (a secret). The far landing's guard wakes as the player comes to
  the water's edge.
- `GrandStair`: a stair down to a floor far below, across the hall's width
  or in two flights turning back on each other, a walkway along the wall
  over it, a channel of water across the floor below (bridged, or swum).
  What keeps the walkway wakes as the player comes to the channel, and a
  fiend is brought in behind; a stash in the landing's foot opens when shot.
- `SanctumTerraces`: a sanctum climbing in two terraces, in some a gallery
  round its west end and a catwalk on to the top terrace, a lift up to it
  (a hub). The altar's button on the top terrace opens the way on from it
  (as e2m5's buttons open its bars) and brings in what was waiting.
- `GoldSpire`: the key room. A stair winding up a spire's walls, the key
  on its landing or on a needle in the middle reached by a bridge, a pool
  at the spire's foot to drop into; taking the key opens the closets at
  the foot and brings scrags in.
- `ManseExit`: the end. A hall, a door (the gold door, as a gate) out onto
  a balcony over a lower hall, a stair or a lift down, the slipgate on a
  dais (on an island in a pool in some). Opening the door lets loose what
  waits behind the lower hall's walls (e2m5's gold door firing its
  ambush) and brings scrags in."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, spiral, ring_landing, lift }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_moat, e2m4_stash }

glob E2M5: str = "q1:e2m5";

"""e2m5's foes: ogres and scrags, hell knights and fiends deeper in, a
shambler at the deepest."""
def e2m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_ogre", "monster_wizard", "monster_hell_knight"], ["monster_demon1"] if heavy else ["monster_hell_knight"], danger));
}

"""The start: a court, a fountain or a canal, a porch up a stair."""
node ManseCourt(Prefab) {
    has porch: int = 4,
        tall: int = 20,
        canal: bool = False,
        bridged: bool = True,
        sides: bool = False,
        upper: bool = True,
        stash: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Manse court";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 26);
        self.porch = dice.between(4, 5);
        self.canal = dice.chance(0.45);
        self.bridged = dice.chance(0.6);
        self.sides = dice.chance(0.5);
        self.upper = dice.chance(0.8);
        self.stash = dice.chance(0.5);
        self.tall = self.porch + 9 + dice.between(9, 11);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.porch), Port(face=1, along=float(self.long - 6), floor=self.porch), Port(face=3, along=4.0, floor=0)] + ([Port(face=1, along=float(self.long - 3), floor=self.porch + 9)] if self.upper else []);
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        p = self.porch;
        g = p + 9;
        px = self.long - 10;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, p);
        # The porch across the far end, a stair up its middle or one at each
        # end, columns along its front.
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, p);
        if self.sides {
            for y0 in [2, self.wide - 5] {
                stair(build, px - p, y0, 0, 0, p, 3);
                for y in range(y0, y0 + 3) {
                    build.keep(court, px, y, p);
                }
            }
        } else {
            stair(build, px - p, middle - 3, 0, 0, p, 6);
            for y in range(middle - 3, middle + 3) {
                build.keep(court, px, y, p);
            }
        }
        for y in range(3, self.wide - 3, 4) {
            if (self.sides and (y < 6 or y >= self.wide - 6)) or (not self.sides and abs(y - middle) <= 3) {
                continue;
            }
            build.solid(px, y, p, px + 1, y + 1, self.tall - 4);
        }
        # The gallery over the porch's back, a lift up to it.
        if self.upper {
            build.level(court, g);
            build.solid(self.long - 5, 1, g - 1, self.long - 1, self.wide - 1, g);
            lift(build, self.long - 8, 2, self.long - 5, 5, p, g);
            for y in range(2, 5) {
                build.keep(court, self.long - 5, y, g);
                build.keep(court, self.long - 9, y, p);
            }
        }
        # The fountain, a column in its basin; or a canal across the court.
        if self.canal {
            e2m4_moat(build, 7, 13, 1, self.wide - 1, 7, 0, self.bridged);
            if self.bridged {
                build.solid(7, middle - 2, -1, 13, middle + 2, 0);
                for y in range(middle - 2, middle + 2) {
                    build.keep(court, 6, y, 0);
                    build.keep(court, 13, y, 0);
                }
            }
        } else {
            e2m4_moat(build, 7, 13, middle - 4, middle + 4, 6);
            build.solid(9, middle - 1, -6, 11, middle + 1, 4);
            build.foe(5.5, float(middle) - 5.5, 0, "monster_ogre", 0.0, patrol=[[5.5, float(middle) - 5.5], [14.5, float(middle) - 5.5], [14.5, float(middle) + 5.5], [5.5, float(middle) + 5.5]]);
        }
        for port in self.taken {
            build.doorway(court, port);
        }
        # Scrags brought in over the court as the player steps onto the
        # porch; what keeps the porch (or the gallery) wakes.
        onto = build.touch(float(px), 1.0, float(p), float(px + 2), float(self.wide - 1), float(p + 6));
        late = build.delay(0.5);
        onto +>:Fires:+> late;
        for index in range(dice.between(2, 3)) {
            late +>:Fires:+> build.summon(2, 2 + index * 5, -8, "monster_wizard", 9.5 + float(index) * 2.0, float(middle) - 4.5 + float(index) * 4.0, 5, 0.0);
        }
        guard = build.waiting();
        onto +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            if self.upper {
                build.foe(float(self.long) - 3.0, 8.5 + float(index) * 6.0, g, e2m5_foe(dice, self.danger, index == 0), 180.0, waits=guard);
            } else {
                build.foe(float(self.long) - 3.5, 8.5 + float(index) * 6.0, p, e2m5_foe(dice, self.danger, index == 0), 180.0, waits=guard);
            }
        }
        build.foe(float(px) + 1.5, 3.5, p, "monster_knight", 90.0, patrol=[[float(px) + 1.5, 3.5], [float(px) + 1.5, float(self.wide) - 3.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(px - p) - 1.5, 3.5 + float(index) * (float(self.wide) - 7.0), 0, e2m5_foe(dice, self.danger), 180.0);
        }
        if self.stash {
            build.solid(1, self.wide - 6, 0, 7, self.wide - 1, 8);
            e2m4_stash(build, 3, self.wide - 4, 5, self.wide - 1, 0, 3, "item_artifact_super_damage");
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.5, p, "item_health");
    }
}

"""A hall over a flooded cistern: a gap across its floor looking down into
the water, a lift down through a hatch to a walkway, the water crossed on
a raft, along a walk or swum to a far landing, a stair up through the
floor on the far side."""
node CisternDive(Prefab) {
    has deep: int = 7,
        cross: int = 0,
        gap_x: int = 12,
        grate: bool = True,
        barred: bool = True,
        lane: int = 9,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.deep = min(dice.between(7, 10), self.wide - 11);
        self.cross = dice.weighted([2.0, 1.0, 1.0]);
        self.gap_x = dice.between(9, self.long - 15);
        self.grate = dice.chance(0.6);
        self.barred = dice.chance(0.5);
        self.lane = dice.between(self.deep + 2, self.wide - 9);
        self.tall = 10 + dice.between(9, 11);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=10);
        self.leaves = [Port(face=0, along=4.0, floor=0), Port(face=3, along=float(self.long - 4), floor=10), Port(face=3, along=4.0, floor=10)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deep;
        u = 10;
        nx = 6;
        fx = self.long - 7;
        gx = self.gap_x;
        under = build.room(1, 1, 0, self.long - 1, self.wide - 1, u - 1, variant=dice.below(3));
        over = build.room(1, 1, u - 1, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(over, u);
        build.level(under, 0);
        e2m4_moat(build, nx, fx, 1, self.wide - 1, d);
        # The floor over the cistern, the gap across it, pillars under it.
        build.solid(1, 1, u - 1, self.long - 1, self.wide - 1, u);
        build.widen(over, gx, 1, u - 1, gx + 5, self.wide - 1, u);
        clear = [[nx, self.lane - 1, fx, self.lane + 5], [nx, self.wide - 5, fx, self.wide], [gx - 1, 0, gx + 6, self.wide]];
        pillars(build, nx + 3, 3, fx - 3, self.wide - 3, -d, u - 1, 6, clear);
        # The hatch in the floor at the near end, a lift down through it to
        # the walkway.
        hy = self.wide - 6;
        build.widen(over, 2, hy, u - 1, 5, hy + 3, u);
        lift(build, 2, hy, 5, hy + 3, 0, u);
        for x in range(2, 5) {
            build.keep(over, x, hy - 1, u);
            build.keep(under, x, hy - 1, 0);
        }
        # The stair up the far landing's back through the floor.
        stair(build, self.long - 4, self.wide - 2, 0, 3, u, 3);
        build.widen(over, self.long - 4, self.wide - 1 - u, u - 1, self.long - 1, self.wide - 1, u);
        for x in range(self.long - 4, self.long - 1) {
            build.keep(over, x, self.wide - 2 - u, u);
        }
        # The crossing: a raft riding to and fro under the floor, a walk
        # along the north wall, or nothing (a swim).
        if self.cross == 0 {
            build.train([4.0, 4.0, 1.0], [[float(nx), float(self.lane), -1.0], [float(fx - 4), float(self.lane), -1.0]], 80.0, 2.0);
            for y in range(self.lane, self.lane + 4) {
                build.keep(under, nx - 1, y, 0);
                build.keep(under, fx, y, 0);
            }
        } elif self.cross == 1 {
            build.solid(nx, self.wide - 4, -1, fx, self.wide - 1, 0);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(under, nx - 1, y, 0);
                build.keep(under, fx, y, 0);
            }
        }
        # A grate under the water at the walkway's foot, opened by a button
        # beside it, a flooded niche behind it (a secret).
        if self.grate {
            ay = d + 2;
            build.room(2, ay, -d, nx, ay + 3, -d + 4);
            for z in range(-d, -d + 4) {
                for y in range(ay, ay + 3) {
                    for x in range(2, nx) {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
            fields = {"wait": "-1"};
            build.rising_door(float(nx - 1), float(ay), float(-d), float(nx), float(ay + 3), float(-d + 4), fields);
            build.push(float(nx), float(ay) + 4.5, float(-d) + 1.0, 0) +>:Fires:+> build.cue([fields], "grate");
            build.secret(2.0, float(ay), float(-d), float(nx - 1), float(ay + 3), float(-d + 3));
            build.supply(3.5, float(ay) + 1.5, -d, "item_artifact_super_damage");
        }
        build.doorway(over, self.enter);
        for port in self.taken {
            build.doorway(under if port.floor == 0 else over, port);
            # The far landing's way on barred until a button over it, on the
            # floor above, is pressed.
            if self.barred and port.floor == 0 {
                press = build.push(float(self.long - 6), 3.5, float(u) + 1.2, 2);
                build.solid(self.long - 6, 3, u, self.long - 5, 4, u + 3);
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "These bars open elsewhere...");
            }
        }
        # The far landing's guard wakes as the player comes to the water's
        # edge, and blocks start grinding along the cistern's floor (e2m5's
        # trains under the water); a knight walks the landing; scrags hang
        # over the water.
        brink = build.touch(float(nx - 2), 1.0, 0.0, float(nx), float(self.wide - 1), 6.0);
        guard = build.waiting();
        brink +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(fx) + 2.5, 3.5 + float(index) * 4.0, 0, e2m5_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        later = build.delay(3.0);
        brink +>:Fires:+> later;
        later +>:Fires:+> build.train([3.0, 2.0, 2.0], [[float(gx + 1), 2.0, float(-d)], [float(gx + 1), float(self.wide - 4), float(-d)]], 40.0, 1.0, True);
        build.foe(float(fx) + 1.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(fx) + 1.5, 2.5], [float(fx) + 1.5, float(self.wide - 3 - u)]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(nx + 4 + index * 6) + 0.5, float(self.wide // 2) + 0.5, 4, "monster_wizard", 180.0);
        }
        build.foe(3.5, 3.5, u, "monster_ogre", 0.0, patrol=[[3.5, 3.5], [float(gx) - 2.5, 3.5]]);
        roof = build.touch(float(gx + 5), 1.0, float(u), float(gx + 7), float(self.wide - 1), float(u + 6));
        keeper = build.waiting();
        roof +>:Fires:+> keeper;
        build.foe(float(self.long) - 6.5, float(self.wide // 2) - 1.5, u, e2m5_foe(dice, self.danger, True), 180.0, waits=keeper);
        build.foe(3.5, float(hy) - 2.5, 0, e2m5_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, u, "item_rockets");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A stair down to a floor far below, a walkway along the wall over it, a
channel across the floor."""
node GrandStair(Prefab) {
    has deep: int = 9,
        tall: int = 12,
        switchback: bool = False,
        channel: bool = True,
        bridged: bool = True,
        stash: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grand stair";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(32, 34);
        self.wide = dice.between(16, 19);
        self.deep = dice.between(11, 13);
        self.tall = dice.between(11, 13);
        self.switchback = dice.chance(0.5);
        self.channel = dice.chance(0.6);
        self.bridged = dice.chance(0.6);
        self.stash = dice.chance(0.6);
        self.low = -self.deep - 7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2) - 1.0;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=3, along=float(self.long - 4), floor=-self.deep), Port(face=0, along=float(self.wide - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        walk_y = self.wide - 6;
        middle = self.wide // 2 - 1;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The landing in, and the way down from it: one stair across the
        # width, or two flights turning back on each other.
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        h1 = self.deep // 2 + 1;
        if self.switchback {
            h2 = self.deep - h1;
            stair(build, 6 + h1 - 1, 1, -h1, 2, h1, 4);
            mid = 6 + h1;
            build.solid(mid, 1, low, mid + 4, 10, -h1);
            stair(build, mid - h2, 6, low, 0, h2, 4);
        } else {
            stair(build, 5 + self.deep, 1, low, 2, self.deep, walk_y - 1);
        }
        # The walkway along the north wall, a slab over the floor below,
        # piers under it.
        build.solid(6, walk_y, -1, self.long - 1, self.wide - 1, 0);
        for x in range(8 + self.deep, self.long - 2, 5) {
            build.solid(x, walk_y, low, x + 1, walk_y + 1, -1);
        }
        for x in range(6, self.long - 1) {
            if x % 6 != 0 {
                build.keep(hall, x, walk_y, 0);
            }
        }
        # The channel across the floor below, bridged or swum.
        cx = max(7 + self.deep, 12 + self.deep // 2);
        if self.channel {
            e2m4_moat(build, cx, cx + 5, 1, walk_y, 5, low, self.bridged);
            if self.bridged {
                build.solid(cx, middle - 2, low - 1, cx + 5, middle + 2, low);
                for y in range(middle - 2, middle + 2) {
                    build.keep(hall, cx - 1, y, low);
                    build.keep(hall, cx + 5, y, low);
                }
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What keeps the walkway wakes as the player comes to the channel's
        # near side; a fiend is brought in behind.
        near = build.touch(float(cx - 2), 1.0, float(low), float(cx), float(walk_y), float(low + 6));
        guard = build.waiting();
        near +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long - 4 - index * 5) + 0.5, float(self.wide) - 2.5, 0, e2m5_foe(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        late = build.delay(1.5);
        near +>:Fires:+> late;
        late +>:Fires:+> build.summon(2, 1, low, e2m5_foe(dice, self.danger, True), float(self.long) - 4.5, float(walk_y) + 2.0, low, 180.0);
        build.foe(float(cx) + 7.5, 3.5, low, e2m5_foe(dice, self.danger), 90.0, patrol=[[float(cx) + 7.5, 3.5], [float(cx) + 7.5, float(walk_y) - 1.5]]);
        build.foe(float(self.long // 2) + 0.5, 4.5, low + 6, "monster_wizard", 180.0);
        build.foe(8.5, float(self.wide) - 2.5, 0, "monster_ogre", 0.0, patrol=[[8.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        if self.stash and self.switchback {
            e2m4_stash(build, 2, 7, 4, 9, low, 0, "item_artifact_envirosuit");
        }
        build.supply(float(self.long) - 2.5, 2.5, low, "item_health");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A sanctum climbing in two terraces; an altar on the top one whose button
opens the way on from it."""
node SanctumTerraces(Prefab) {
    has first: int = 5,
        second: int = 11,
        gallery: bool = True,
        lifted: bool = False,
        sealed: bool = True,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sanctum terraces";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(28, 32);
        self.wide = dice.between(22, 24);
        self.first = dice.between(5, 6);
        self.second = self.first + 6;
        self.gallery = dice.chance(0.8);
        self.lifted = self.gallery and dice.chance(0.6);
        self.sealed = dice.chance(0.6);
        self.tall = self.second + dice.between(11, 13);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.second),
            Port(face=3, along=float(self.long - 4), floor=self.second),
            Port(face=3, along=float(self.long // 2 - 4), floor=0),
            Port(face=1, along=6.0, floor=0)
        ] + ([Port(face=1, along=4.0, floor=self.second)] if self.gallery else []);
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        f = self.first;
        s = self.second;
        t1 = self.long - 13;
        t2 = self.long - 7;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, f);
        build.level(hall, s);
        build.solid(t1, 1, 0, self.long - 1, self.wide - 1, f);
        build.solid(t2, 1, 0, self.long - 1, self.wide - 1, s);
        stair(build, t1 - f, middle - 2, 0, 0, f, 4);
        stair(build, t2 - 6, 2, f, 0, 6, 3);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, t1, y, f);
        }
        for y in range(2, 5) {
            build.keep(hall, t2, y, s);
        }
        # The altar on the top terrace, its button on a post.
        build.solid(self.long - 4, self.wide - 7, s, self.long - 2, self.wide - 4, s + 1);
        build.solid(self.long - 3, self.wide - 7, s + 1, self.long - 2, self.wide - 6, s + 3);
        press = build.push(float(self.long - 3), float(self.wide) - 6.5, float(s) + 1.5, 2);
        # The gallery round the west end over the way in, a catwalk along
        # the north wall on to the top terrace, a lift up from the floor.
        if self.gallery {
            build.solid(1, 1, s - 1, 5, self.wide - 1, s);
            build.solid(5, self.wide - 4, s - 1, t2, self.wide - 1, s);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(hall, t2 - 1, y, s);
            }
            if self.lifted {
                lift(build, 5, 3, 8, 6, 0, s);
                for y in range(3, 6) {
                    build.keep(hall, 4, y, s);
                    build.keep(hall, 8, y, 0);
                }
            }
            build.foe(3.0, 6.5, s, "monster_ogre", 90.0, patrol=[[3.0, 6.5], [3.0, float(self.wide) - 3.0], [float(t2) - 2.5, float(self.wide) - 3.0]]);
            # A platform the altar's button sets riding between the floor
            # and the catwalk.
            press +>:Fires:+> build.train([3.0, 3.0, 1.0], [[9.0, float(self.wide - 7), -1.0], [9.0, float(self.wide - 7), float(s - 1)]], 90.0, 2.0, True);
            for x in range(9, 12) {
                build.keep(hall, x, self.wide - 4, s);
            }
        } else {
            for x in range(5, t1 - 2, 5) {
                for y in [4, self.wide - 5] {
                    build.solid(x, y, 0, x + 1, y + 1, self.tall);
                }
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            # The way on from the top terrace stays barred until the altar's
            # button is pressed.
            if self.sealed and port.floor == s and port.face == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, s, 8, "The altar opens the way");
            }
        }
        # The altar's button brings in what was waiting, behind the player.
        late = build.delay(1.5);
        press +>:Fires:+> late;
        late +>:Fires:+> build.summon(2, 2, -8, e2m5_foe(dice, self.danger, True), float(t1) + 2.5, float(middle) + 4.5, f, 180.0);
        late +>:Fires:+> build.summon(7, 2, -8, "monster_wizard", float(t1) - 4.5, float(middle) + 0.5, 4, 0.0);
        # The top terrace's guard wakes as the player comes up onto the
        # first; a knight walks the floor.
        up = build.touch(float(t1), float(middle - 2), float(f), float(t1 + 2), float(middle + 2), float(f + 6));
        guard = build.waiting();
        up +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 4.5 + float(index) * 5.0, s, e2m5_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(3.5, 3.5, 0, "monster_knight", 90.0, patrol=[[3.5, 3.5], [3.5, float(self.wide) - 3.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(t1) + 3.5, float(self.wide) - 6.5 - float(index) * 4.0, f, e2m5_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, s, "item_health");
        build.supply(float(t1) + 2.5, 2.5, f, "item_shells");
        build.supply(3.5, float(middle) + 4.5, 0, "item_health");
    }
}

"""A stair winding up a spire's walls to a landing, the key on it or on a
needle bridged to from it; taking it opens the closets at the foot."""
node GoldSpire(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 15,
        steps: int = 12,
        needle: bool = False,
        pooled: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold spire (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(15, 17);
        self.hall_wide = dice.between(15, 17);
        self.wide = self.hall_wide + 4;
        side = self.hall_wide - 1;
        self.needle = dice.chance(0.5);
        self.pooled = not self.needle and dice.chance(0.7);
        fits: list[int] = [];
        threaded: list[int] = [];
        for steps in range(12, 21) {
            at = ring_landing(1, 1, self.long - 1, side, 3, steps, 4);
            if at and at[0] != 2.0 and at[0] != 1.0 {
                fits.append(steps);
                reach = float(self.long - 6) if at[0] == 3.0 else float(side - 6);
                if 5.0 <= at[1] and at[1] <= reach {
                    threaded.append(steps);
                }
            }
        }
        if self.needle and not threaded {
            self.needle = False;
        }
        pick = threaded if self.needle else fits;
        self.steps = pick[dice.below(len(pick))];
        self.tall = self.steps + 9;
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cx = self.long // 2;
        cy = side // 2;
        spire = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(spire, self.steps);
        build.doorway(spire, self.enter);
        landing = spiral(build, 1, 1, self.long - 1, side, 0, self.steps, 3, 4);
        # A pool at the spire's foot to drop into from on high.
        bottom = 0;
        if self.pooled {
            e2m4_moat(build, 5, self.long - 5, 5, side - 4, 5);
            bottom = -5;
        }
        top = landing[2];
        key_at = [float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5];
        if self.needle {
            at = ring_landing(1, 1, self.long - 1, side, 3, self.steps, 4);
            k = self.steps;
            if at[0] == 3.0 {
                x0 = int(at[1]) - 1;
                build.solid(x0, cy - 1, bottom, x0 + 3, cy + 2, k);
                build.solid(x0, 4, k - 1, x0 + 3, cy - 1, k);
                key_at = [float(x0) + 1.5, float(cy) + 0.5];
                for x in range(x0, x0 + 3) {
                    build.keep(spire, x, 3, k);
                    build.keep(spire, x, 4, k);
                }
            } else {
                y0 = int(at[1]) - 1;
                build.solid(cx - 1, y0, bottom, cx + 2, y0 + 3, k);
                build.solid(cx + 2, y0, k - 1, self.long - 4, y0 + 3, k);
                key_at = [float(cx) + 0.5, float(y0) + 1.5];
                for y in range(y0, y0 + 3) {
                    build.keep(spire, self.long - 4, y, k);
                    build.keep(spire, self.long - 5, y, k);
                }
            }
        }
        # The key; taking it opens the closets along the side wall at the
        # foot and brings scrags in.
        taken = e2m4_key(build, self.key, key_at[0], key_at[1], self.steps);
        out = build.waiting();
        taken +>:Fires:+> out;
        for (index, cx0) in enumerate([4, self.long - 7]) {
            closet = build.room(cx0, side + 1, 0, cx0 + 3, side + 4, 7);
            build.widen(closet, cx0, side, 0, cx0 + 3, side + 1, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(cx0), float(side), 0.0, float(cx0 + 3), float(side + 1), 6.0, fields);
            taken +>:Fires:+> build.cue([fields], "door");
            build.foe(float(cx0) + 1.5, float(side) + 2.5, 0, e2m5_foe(dice, self.danger, index == 0), 270.0, waits=out);
        }
        late = build.delay(1.0);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, side - 4, -7, "monster_wizard", float(cx) + 0.5, float(cy) + 0.5, self.steps - 3, 0.0);
        build.foe(4.5, float(side) - 2.0, 0, e2m5_foe(dice, self.danger), 0.0, patrol=[[4.5, float(side) - 2.0], [float(self.long) - 4.5, float(side) - 2.0]]);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps - 2, "monster_wizard", 180.0);
        build.supply(2.5, float(side) - 4.5, 0, "item_health");
        build.supply(key_at[0] + 1.0, key_at[1], self.steps, "item_health");
    }
}

"""The end: a hall, a door out onto a balcony, a way down to the slipgate;
opening the door lets loose what waits behind the walls below."""
node ManseExit(Prefab) {
    has key: str = "",
        deep: int = 7,
        lifted: bool = False,
        moat: bool = True,
        stash: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Manse exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M5;
        self.district = level_district(E2M5);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(8, 11);
        self.lifted = dice.chance(0.4);
        self.moat = dice.chance(0.6);
        self.stash = dice.chance(0.6);
        self.tall = self.deep + dice.between(10, 12);
        self.low = -self.deep - 7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        wall = 10;
        inner = self.wide - 5;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 12, variant=dice.below(3));
        below = build.room(wall + 1, 1, low, self.long - 1, inner, self.tall, variant=dice.below(3));
        build.level(below, 0);
        build.doorway(hall, self.enter);
        build.widen(below, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        # The door out: the key's, as a gate, its opening letting loose the
        # ambush; else a touch past it does.
        loose = e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key) if self.key else build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        # The balcony past the door, a slab over the lower floor, and the way
        # down off it.
        build.solid(wall + 1, 1, -1, wall + 5, inner, 0);
        for y in range(3, inner - 1, 5) {
            build.solid(wall + 4, y, low, wall + 5, y + 1, -1);
        }
        if self.lifted {
            lift(build, wall + 5, middle - 1, wall + 8, middle + 2, low, 0);
            for y in range(middle - 1, middle + 2) {
                build.keep(below, wall + 4, y, 0);
                build.keep(below, wall + 8, y, low);
            }
        } else {
            stair(build, wall + 5, 1, low, 1, self.deep, 3);
            for y in range(self.deep - 1, self.deep + 2) {
                build.keep(below, wall + 4, y, 0);
            }
        }
        # The slipgate on a dais, on an island in a pool in some.
        if self.moat {
            e2m4_moat(build, self.long - 10, self.long - 1, 1, inner, 5, low, True);
            build.solid(self.long - 7, middle - 3, low - 5, self.long - 2, middle + 3, low + 1);
            build.solid(self.long - 10, middle - 2, low - 1, self.long - 7, middle + 2, low);
            for y in range(middle - 2, middle + 2) {
                build.keep(below, self.long - 11, y, low);
            }
        } else {
            build.solid(self.long - 7, middle - 3, low, self.long - 2, middle + 3, low + 1);
        }
        build.way_out(float(self.long) - 4.5, float(middle), low + 1);
        # The closets behind the lower hall's north wall, opened with the
        # door; scrags brought in over the hall.
        out = build.waiting();
        loose +>:Fires:+> out;
        for (index, at) in enumerate([wall + 5, wall + 9]) {
            closet = build.room(at, inner + 1, low, at + 3, self.wide - 1, low + 7);
            build.widen(closet, at, inner, low, at + 3, inner + 1, low + 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), float(inner), float(low), float(at + 3), float(inner + 1), float(low + 6), fields);
            loose +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, float(inner) + 2.5, low, "monster_shambler" if index == 0 and self.danger > 0.6 else e2m5_foe(dice, self.danger, True), 270.0, waits=out);
        }
        late = build.delay(2.0);
        loose +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(1, 2 + index * 5, low - 6, "monster_wizard", float(wall + 10 + index * 5) + 0.5, float(middle) - 2.5, 3, 180.0);
        }
        build.foe(float(wall) + 10.5, 2.5, low, "monster_knight", 90.0, patrol=[[float(wall) + 10.5, 2.5], [float(wall) + 10.5, float(inner) - 2.5]]);
        if self.stash {
            e2m4_stash(build, wall - 3, 2, wall - 1, 4, low, 0, "item_artifact_super_damage");
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 5.5, float(middle) + 0.5, low + 1, e2m5_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(wall) + 2.5, 2.5, 0, "item_rockets");
        build.supply(float(wall) + 9.5, float(middle) + 2.5, low, "item_health");
    }
}

"""e2m5's stretches: [name, role]."""
glob E2M5_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["cistern", "flow"],
         ["stair", "flow"],
         ["terraces", "hub"],
         ["cistern", "hub"],
         ["terraces", "flow"],
         ["spire", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m5's stretches by its name."""
def make_e2m5(name: str, key: str) -> Prefab {
    if name == "court" {
        return ManseCourt();
    }
    if name == "cistern" {
        return CisternDive();
    }
    if name == "stair" {
        return GrandStair();
    }
    if name == "terraces" {
        return SanctumTerraces();
    }
    if name == "spire" {
        return GoldSpire(key=key if key else "key_gold");
    }
    return ManseExit(key=key);
}
