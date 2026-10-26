"""Prefabs drawn from e3m6, the Chambers of Torment: yards sunk below their
walkways, doors that burst open on a fiend, a narrow bridge high over a
chasm, platforms riding across a pit, a cage of spike traps, a hall whose
bars open only when three buttons are pressed (e3m6's counter), the key
on a pillar over a pit, ogres walking their rounds everywhere. Raised in
e3m6's own palette.

- `TormentYard`: the start. A yard sunk below walkways along two sides, a
  stair (or a drop, and a lift back up) down into it, gallows on its
  floor; reaching the yard's floor bursts open the doors in its far wall
  on what waits there; a button lowers a door under the walkway on the
  quad damage. Ogres walk the walkways.
- `TormentBridge`: a bridge three cells wide high over a chasm, straight
  across or by an island in the middle with a lift down; a stair up the
  chasm's wall for whoever falls; ogres walk the chasm's floor, and those
  on the far ledge wake as the player reaches the bridge's middle.
- `TrainPit`: a pit between two ledges, a platform riding across it from
  ledge to ledge (running from the start, or set going by a button), the
  pit's floor walked by hell knights, a stair up its near wall and a lift
  (or a platform riding up and down) at its far wall.
- `SpikeCage`: a tall chamber, galleries round three of its walls climbed
  to by a stair or a lift; spikes fly across the floor and along the
  galleries while anyone is in its middle (e3m6's cage of shooters); a
  button high on the far wall, shot, opens a niche on the gallery (a
  secret) where hell knights wait.
- `ButtonHall`: a hall, a balcony along its far wall, a pit sunk in a
  corner; three buttons, on the balcony, down in the pit and in an alcove
  of the floor, counted together open the bars across the ways on ("These
  bars are opened elsewhere"); a hub.
- `TormentPillar`: the key room. The key on a pillar in a pit, reached by
  a teleporter (and one back) or by a bridge drawn out by a shot button;
  taking it opens the closets along the walkway; a lift up out of the pit.
- `TormentExit`: the end. A door (a key's, as a gate) into a chamber, ogres
  on a balcony over it, racks along its walls, and the slipgate behind a
  door that sinks slowly when its button is pressed (or shot)."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, lift }
import from .e3m5 { keep_run, sealed_way, bursting }

glob E3M6: str = "q1:e3m6";

"""e3m6's foes: ogres and scrags, hell knights, vores deeper in."""
def e3m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_ogre", "monster_wizard"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.3 if heavy else danger * 0.7));
}

"""A foe walking its round along a line from (x0, y0) to (x1, y1) on lift
z and back (e3m6's ogres on their paths)."""
def rounds(build: Raising, kind: str, x0: float, y0: float, x1: float, y1: float, z: int) {
    build.foe(x0, y0, z, kind, 0.0, patrol=[[x0, y0], [x1, y1]]);
}

"""The start: a yard sunk below walkways along two sides, a stair (or a
drop and a lift) down, doors bursting open in its far wall."""
node TormentYard(Prefab) {
    has sunk: int = 5,
        tall: int = 16,
        side: int = 14,
        climb: int = 0,
        closets: int = 2,
        quad: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment yard";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(26, 30);
        self.wide = dice.between(19, 22);
        self.tall = dice.between(15, 17);
        self.sunk = dice.between(6, 7);
        self.climb = dice.below(2);
        self.closets = dice.between(1, 2);
        self.quad = dice.chance(0.6);
        self.side = self.wide - 5;
        self.low = -2 * self.sunk - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.side // 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(6 + self.side) * 0.5, floor=-self.sunk),
            Port(face=3, along=float(self.long - 5), floor=0),
            Port(face=0, along=3.5, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        low = -self.sunk;
        side = self.side;
        mid = (6 + side) // 2;
        yard = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.level(yard, low);
        # The yard sunk below the walkways along the west and south.
        build.widen(yard, 7, 6, low, long - 1, side, 0);
        if self.climb == 0 {
            stair(build, 6 + self.sunk, mid - 2, low, 2, self.sunk, 4);
            keep_run(build, yard, 6, mid - 2, 7, mid + 2, 0);
        } else {
            lift(build, 7, mid - 2, 10, mid + 2, low, 0);
            keep_run(build, yard, 6, mid - 3, 7, mid + 3, 0);
            keep_run(build, yard, 6, 6, 10, 7, 0);
        }
        # A footbridge across over the yard from the south walkway to a
        # perch on the north wall.
        fx = 10 + self.sunk;
        build.solid(fx, 6, -1, fx + 3, side, 0);
        keep_run(build, yard, fx, side - 2, fx + 3, side, 0);
        build.supply(float(fx) + 1.5, float(side) - 1.5, 0, "item_rockets");
        # Gallows on the sunk floor.
        clear = [[6, mid - 4, 12 + self.sunk, mid + 4], [long - 4, mid - 4, long, mid + 4], [fx - 1, 6, fx + 4, side]];
        pillars(build, 12 + self.sunk, 8, long - 3, side - 1, low, low + 7, 4, clear);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(side // 2) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        # Reaching the yard's floor bursts open the doors in its far wall.
        foot = build.touch(7.0, float(mid - 3), float(low), float(9 + self.sunk), float(mid + 3), float(low + 6));
        burst = build.delay(0.5);
        foot +>:Fires:+> burst;
        loose = build.waiting();
        burst +>:Fires:+> loose;
        for index in range(self.closets) {
            at = long - 8 - index * 7;
            build.room(at, side + 1, low, at + 3, side + 4, low + 7);
            build.widen(yard, at, side, low, at + 3, side + 1, low + 6);
            burst +>:Fires:+> bursting(build, float(at), float(side), float(low), float(at + 3), float(side + 1), float(low + 6));
            build.foe(float(at) + 1.5, float(side) + 2.5, low, "monster_demon1" if index == 0 else e3m6_foe(dice, self.danger, True), 270.0, waits=loose);
        }
        # Ogres walking the walkways, a scrag over the yard, a guard woken
        # in the yard.
        rounds(build, "monster_ogre", 9.5, 3.5, float(long) - 3.5, 3.5, 0);
        rounds(build, "monster_ogre", 3.5, 3.5, 3.5, float(side) - 2.5, 0);
        build.foe(float(long // 2) + 0.5, float(mid) + 0.5, 4, "monster_wizard", 180.0, patrol=[[float(long // 2) + 0.5, float(mid) + 0.5], [float(long) - 4.5, float(mid) + 0.5]]);
        build.foe(float(long) - 3.5, float(mid) + 2.5, low, e3m6_foe(dice, self.danger), 180.0, waits=loose);
        if self.quad {
            # A closet under the south walkway, its door sunk by the button
            # on the yard's east wall: the quad damage.
            qx = 14 + dice.below(max(1, long - 20));
            build.room(qx, 2, low, qx + 3, 6, -1);
            press = build.push(float(long - 1), float(side) - 2.5, float(low) + 1.5, 2);
            press +>:Fires:+> build.sinking(float(qx), 5.0, float(qx + 3), 6.0, -1, self.sunk - 1);
            build.secret(float(qx), 2.0, float(low), float(qx + 3), 5.0, float(low + 3));
            build.supply(float(qx) + 1.5, 3.5, low, "item_artifact_super_damage");
            press +>:Fires:+> build.summon(1, 7, low - 4, e3m6_foe(dice, self.danger, True), 3.5, float(side) - 3.5, 0, 0.0);
        }
        build.supply(float(long) - 2.5, float(side) - 2.5, low, "item_health");
    }
}

"""A bridge high over a chasm, straight or by an island with a lift down,
a stair up the chasm's wall."""
node TormentBridge(Prefab) {
    has deep: int = 10,
        tall: int = 12,
        island: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment bridge";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(28, 32);
        self.wide = dice.between(15, 17);
        self.deep = dice.between(10, 12);
        self.tall = dice.between(11, 13);
        self.island = dice.chance(0.5);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=1, along=float(self.long // 2 + 3), floor=-self.deep)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, low, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        x0 = 6;
        x1 = long - 7;
        build.solid(1, 1, low, x0, wide - 1, 0);
        build.solid(x1, 1, low, long - 1, wide - 1, 0);
        lane = middle - 1;
        m = (x0 + x1) // 2;
        if self.island {
            # Two spans by an island in the middle, a lift down from it.
            build.solid(m - 2, lane - 1, low, m + 3, lane + 4, 0);
            build.solid(x0, lane, -1, m - 2, lane + 3, 0);
            build.solid(m + 3, lane, -1, x1, lane + 3, 0);
            lift(build, m - 2, lane + 4, m + 1, lane + 7, low, 0);
            keep_run(build, hall, m - 2, lane + 3, m + 1, lane + 4, 0);
            keep_run(build, hall, m - 3, lane + 4, m + 2, lane + 8, low);
        } else {
            build.solid(x0, lane, -1, x1, lane + 3, 0);
        }
        keep_run(build, hall, x0 - 1, lane, x0, lane + 3, 0);
        keep_run(build, hall, x1, lane, x1 + 1, lane + 3, 0);
        # The stair up the chasm's south wall to the near ledge.
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 3);
        keep_run(build, hall, x0 - 1, 1, x0, 4, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Ogres walk the chasm's floor; those on the far ledge wake as the
        # player reaches the bridge's middle.
        rounds(build, "monster_ogre", float(x0 + self.deep) + 1.5, float(wide) - 3.5, float(x1) - 1.5, float(wide) - 3.5, low);
        rounds(build, e3m6_foe(dice, self.danger, True), float(x1) - 1.5, 5.5, float(x0 + self.deep) + 1.5, 5.5, low);
        crossing = build.touch(float(m - 1), float(lane), 0.0, float(m + 2), float(lane + 3), 6.0);
        guard = build.waiting();
        crossing +>:Fires:+> guard;
        # Behind the player as the bridge is crossed, a foe teleported in.
        crossing +>:Fires:+> build.summon(1, 1, low - 1, e3m6_foe(dice, self.danger), 3.5, float(middle) + 0.5, 0, 0.0);
        if not self.island {
            # A teleporter on the chasm's floor back up to the near ledge.
            build.teleporter(float(x1) - 2.5, float(middle) + 0.5, low, 3.0, float(middle) + 2.5, 0, 0.0);
        }
        # A closet in the near ledge's foot, behind a wall that opens when
        # shot (a secret).
        build.room(3, wide - 5, low, 5, wide - 2, low + 4);
        build.secret_door(5.0, float(wide - 5), float(low), 6.0, float(wide - 2), float(low + 4), 2);
        build.secret(3.0, float(wide - 5), float(low), 5.0, float(wide - 2), float(low + 3));
        build.supply(4.0, float(wide) - 3.5, low, "item_artifact_super_damage" if dice.chance(0.4) else "item_armor2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 3.5, 3.5 + float(index) * 4.0, 0, e3m6_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(float(m) + 0.5, float(middle) + 3.5, 3, "monster_wizard", 180.0, waits=guard);
        build.supply(float(x0 + 13) + 0.5, 3.0, low, "item_health");
        build.supply(float(long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""A pit between two ledges, a platform riding across it, a stair up its
near wall and a lift (or a platform riding up) at its far wall."""
node TrainPit(Prefab) {
    has deep: int = 9,
        tall: int = 14,
        fired: bool = False,
        riser: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Train pit";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.fired = dice.chance(0.5);
        self.riser = dice.chance(0.4);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0),
            Port(face=1, along=float(self.long // 2), floor=-self.deep)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        low = -self.deep;
        hall = build.room(1, 1, low, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        x0 = 7;
        x1 = long - 8;
        build.solid(1, 1, low, x0, wide - 1, 0);
        build.solid(x1, 1, low, long - 1, wide - 1, 0);
        # The platform riding across, docking flush at each ledge's edge.
        ty = wide // 2 - 1 + dice.between(-2, 0);
        ride = build.train([3.0, 3.0, 1.0], [[float(x0), float(ty), -1.0], [float(x1 - 3), float(ty), -1.0]], 100.0, 2.0, self.fired);
        keep_run(build, hall, x0 - 1, ty - 1, x0, ty + 4, 0);
        keep_run(build, hall, x1, ty - 1, x1 + 1, ty + 4, 0);
        if self.fired {
            build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Press the button to call the platform");
            build.push(4.5, 1.0, 1.5, 1) +>:Fires:+> ride;
        }
        # The stair up the near wall, and up the far wall a lift (or a
        # platform riding up and down).
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 3);
        keep_run(build, hall, x0 - 1, 1, x0, 4, 0);
        py = wide - 5;
        if self.riser {
            build.train([3.0, 3.0, 1.0], [[float(x1 - 3), float(py), float(low - 1)], [float(x1 - 3), float(py), -1.0]], 80.0, 3.0);
        } else {
            lift(build, x1 - 3, py, x1, py + 3, low, 0);
        }
        keep_run(build, hall, x1, py - 1, x1 + 1, py + 4, 0);
        keep_run(build, hall, x1 - 4, py - 1, x1, py + 4, low);
        # A teleporter on the pit's floor up onto the far ledge.
        build.teleporter(float(x0 + self.deep) + 3.5, 7.5, low, float(long) - 3.5, float(wide // 2) + 0.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Hell knights walk the pit's floor; the far ledge's guard wakes as
        # a body rides over.
        rounds(build, e3m6_foe(dice, self.danger, True), float(x0 + self.deep) + 1.5, 4.5, float(x1) - 5.5, 4.5, low);
        rounds(build, "monster_hell_knight", float(x1) - 5.5, float(wide) - 3.5, float(x0 + self.deep) + 1.5, float(wide) - 3.5, low);
        over = build.touch(float(x0 + 3), float(ty), -1.0, float(x1 - 3), float(ty + 3), 5.0);
        guard = build.waiting();
        over +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 3.5, 3.5 + float(index) * 4.0, 0, e3m6_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(float(long // 2) + 0.5, float(ty) + 1.5, 4, "monster_wizard", 180.0, waits=guard);
        build.supply(3.5, float(wide) - 3.5, 0, "item_spikes");
        build.supply(float(x1) + 2.5, float(wide) - 2.5, 0, "item_health");
    }
}

"""A tall chamber, galleries round three walls, spikes across its floor
and galleries, a niche opened by a shot button."""
node SpikeCage(Prefab) {
    has gallery: int = 9,
        tall: int = 19,
        climb: int = 0,
        niche: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike cage";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(24, 28);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(9, 11);
        self.climb = dice.below(2);
        self.niche = dice.chance(0.7);
        self.low = -9;
        self.high = self.tall + 1;
        g = self.gallery;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 3), floor=g),
            Port(face=1, along=float(self.long - 11), floor=g),
            Port(face=3, along=float(self.long - 11), floor=g),
            Port(face=0, along=float(self.wide // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = self.gallery;
        mid = wide // 2;
        cage = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(cage, g);
        # The galleries: along both side walls and across the far end.
        start = 4 + g if self.climb == 0 else 8;
        build.solid(start, 1, g - 1, long - 1, 5, g);
        build.solid(8, wide - 5, g - 1, long - 1, wide - 1, g);
        build.solid(long - 7, 5, g - 1, long - 1, wide - 5, g);
        if self.climb == 0 {
            stair(build, 4, 1, 0, 0, g, 4);
            keep_run(build, cage, start - 2, 1, start + 1, 5, g);
        } else {
            lift(build, 5, 1, 8, 5, 0, g);
            build.solid(8, 1, g - 1, 9, 5, g);
            keep_run(build, cage, 7, 1, 9, 5, g);
            keep_run(build, cage, 4, 1, 8, 6, 0);
        }
        # Drops from the north gallery to the floor.
        keep_run(build, cage, 10, wide - 6, 13, wide - 5, g);
        # The cage of spikes: shooters along both walls at the floor and
        # down the galleries from the west, firing while anyone is in the
        # chamber's middle.
        zone = build.touch(7.0, 1.0, 0.0, float(long - 8), float(wide - 1), float(g + 5), False);
        for x in range(9, long - 9, 4) {
            zone +>:Fires:+> build.spikes(float(x) + 0.5, 1.2, 2.5, 1);
            zone +>:Fires:+> build.spikes(float(x) + 2.5, float(wide) - 1.2, 2.5, 3);
        }
        zone +>:Fires:+> build.spikes(float(start) + 0.2, 3.0, float(g) + 2.5, 0);
        zone +>:Fires:+> build.spikes(8.2, float(wide) - 3.0, float(g) + 2.5, 0);
        build.doorway(cage, self.enter);
        for port in self.taken {
            build.doorway(cage, port);
        }
        if self.niche {
            # A niche off the far gallery behind a door the shot button
            # high on the far wall opens: hell knights and a prize (a
            # secret).
            build.solid(long - 4, mid - 3, g, long - 1, mid + 3, self.tall);
            build.room(long - 3, mid - 2, g, long - 1, mid + 2, g + 6);
            build.widen(cage, long - 4, mid - 2, g, long - 3, mid + 2, g + 6);
            shot = build.cue([build.button(float(long - 4), float(mid) + 0.5, float(g) + 8.0, 2, "", True)], "button");
            shot +>:Fires:+> build.opened(float(long - 4), float(mid - 2), float(g), float(long - 3), float(mid + 2), float(g + 6));
            build.secret(float(long - 3), float(mid - 2), float(g), float(long - 1), float(mid + 2), float(g + 4));
            inside = build.waiting();
            shot +>:Fires:+> inside;
            shot +>:Fires:+> build.summon(1, 1, -8, e3m6_foe(dice, self.danger, True), float(long) - 5.5, float(wide) - 3.0, g, 180.0);
            build.foe(float(long) - 2.0, float(mid) - 0.5, g, "monster_hell_knight", 180.0, waits=inside);
            build.supply(float(long) - 2.0, float(mid) + 1.0, g, "item_armor2");
        }
        # Ogres walking the floor and the galleries, those on the galleries
        # woken by the spikes' first volley.
        rounds(build, "monster_ogre", 9.5, float(mid) + 0.5, float(long) - 9.5, float(mid) + 0.5, 0);
        rounds(build, e3m6_foe(dice, self.danger), float(long) - 4.5, 7.5, float(long) - 4.5, float(wide) - 7.5, g);
        guard = build.waiting();
        zone +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 5) + 0.5, float(wide) - 2.5 if index % 2 == 0 else 3.0, g, e3m6_foe(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        build.supply(2.5, float(wide) - 2.5, 0, "item_health");
        build.supply(float(long) - 3.0, 3.0, g, "item_spikes");
    }
}

"""A hall, a balcony along its far wall, a pit in a corner, three buttons
counted together to open the bars across the ways on."""
node ButtonHall(Prefab) {
    has balcony: int = 7,
        pit: int = 6,
        tall: int = 17,
        climb: int = 0,
        alcove_x: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Button hall";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(28, 32);
        self.wide = dice.between(22, 26);
        self.balcony = dice.between(7, 8);
        self.pit = dice.between(5, 7);
        self.tall = self.balcony + dice.between(9, 11);
        self.climb = dice.below(2);
        self.alcove_x = dice.between(6, 12);
        self.low = -self.pit - 2;
        self.high = self.tall + 1;
        b = self.balcony;
        self.enter = Port(face=2, along=float(dice.between(5, 9)), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=b),
            Port(face=1, along=float(self.long // 3), floor=b),
            Port(face=3, along=float(self.long // 3), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        b = self.balcony;
        low = -self.pit;
        bal_y = wide - 6;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, b);
        build.level(hall, low);
        # The balcony along the north wall.
        build.solid(1, bal_y, b - 1, long - 1, wide - 1, b);
        if self.climb == 0 {
            stair(build, 4, bal_y - 3, 0, 0, b, 3);
            keep_run(build, hall, b + 1, bal_y, b + 5, bal_y + 1, b);
        } else {
            lift(build, 4, bal_y - 3, 7, bal_y, 0, b);
            keep_run(build, hall, 3, bal_y, 8, bal_y + 1, b);
            keep_run(build, hall, 3, bal_y - 4, 8, bal_y, 0);
        }
        keep_run(build, hall, long - 10, bal_y, long - 7, bal_y + 1, b);
        # The pit sunk in the south-east corner, a stair up out of it.
        px0 = long - 13;
        build.widen(hall, px0, 1, low, long - 1, 9, 0);
        stair(build, px0 + self.pit - 1, 6, low, 2, self.pit, 3);
        keep_run(build, hall, px0 - 1, 6, px0, 9, 0);
        # The three buttons, counted together.
        count = build.tally(3, "The bars are open");
        build.push(float(long // 2) + 0.5, float(wide - 1), float(b) + 1.2, 3) +>:Fires:+> count;
        build.push(float(long - 1), 4.5, float(low) + 1.2, 2) +>:Fires:+> count;
        ax = self.alcove_x;
        build.solid(ax, bal_y - 6, 0, ax + 2, bal_y - 4, 6);
        build.push(float(ax) + 1.0, float(bal_y - 6), 1.2, 3) +>:Fires:+> count;
        build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Three buttons open the bars");
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.face == 0 {
                sealed_way(build, hall, long, wide, port, count, "These bars are opened elsewhere");
            } else {
                build.doorway(hall, port);
            }
        }
        # The last button brings in an ambush; the pit's dead wake as a
        # body drops in.
        count +>:Fires:+> build.summon(1, 1, low - 2, e3m6_foe(dice, self.danger, True), float(long) - 4.5, float(wide // 2) + 0.5, 0, 180.0);
        dropped = build.touch(float(px0), 1.0, float(low), float(long - 1), 9.0, float(low + 4));
        pit_guard = build.waiting();
        dropped +>:Fires:+> pit_guard;
        build.foe(float(long) - 3.5, 7.5, low, e3m6_foe(dice, self.danger, True), 180.0, waits=pit_guard);
        build.foe(float(px0) + 2.5, 2.5, low, e3m6_foe(dice, self.danger), 0.0, waits=pit_guard);
        rounds(build, "monster_ogre", 3.5, float(wide) - 3.5, float(long) - 3.5, float(wide) - 3.5, b);
        rounds(build, "monster_hell_knight", 12.5, float(bal_y) - 3.5, float(long) - 4.5, float(bal_y) - 3.5, 0);
        rounds(build, e3m6_foe(dice, self.danger), 3.5, 11.5, float(px0) - 3.5, 11.5, 0);
        build.foe(float(long // 2) + 0.5, float(wide // 2) + 0.5, 6, "monster_wizard", 90.0);
        build.supply(3.5, float(wide) - 2.5, b, "item_rockets");
        build.supply(float(long) - 2.5, 2.5, low, "item_health");
    }
}

"""The key on a pillar in a pit, a teleporter out to it and back (or a
bridge drawn out by a shot button); taking it opens the closets."""
node TormentPillar(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 8,
        tall: int = 14,
        drawn_in: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment pillar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(17, 19);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(7, 9);
        self.tall = dice.between(13, 15);
        self.drawn_in = dice.chance(0.5);
        self.low = -2 * self.deep - 4;
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
        low = -self.deep;
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, low);
        build.doorway(hall, self.enter);
        # The pit, walkways along both side walls round it.
        x0 = 6;
        x1 = long - 2;
        build.widen(hall, x0, 4, low, x1, side - 3, 0);
        cx = (x0 + x1) // 2 + 1;
        build.solid(cx - 2, cy - 2, low, cx + 1, cy + 2, 0);
        keep_run(build, hall, cx - 2, cy - 2, cx + 1, cy + 2, 0);
        # A lift up out of the pit onto the south walkway.
        lift(build, x0 + 1, 4, x0 + 4, 7, low, 0);
        keep_run(build, hall, x0, 3, x0 + 5, 4, 0);
        keep_run(build, hall, x0, 4, x0 + 5, 8, low);
        if self.drawn_in {
            # A bridge from the near ledge to the pillar, drawn out when
            # the button high on the far wall is shot.
            shot = build.cue([build.button(float(long - 1), float(cy) + 0.5, 6.0, 2, "", True)], "button");
            shot +>:Fires:+> build.drawn(float(x0), float(cy - 1), float(cx - 2), float(cy + 2), 0, self.deep + 1);
            keep_run(build, hall, x0 - 1, cy - 1, x0, cy + 2, 0);
            build.touch(1.0, 1.0, 0.0, 4.0, float(side), 6.0, True, "Shoot the button to draw out the bridge");
        } else {
            build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy) - 1.0, 0, 0.0);
            build.teleporter(float(cx) - 0.5, float(cy) + 1.0, 0, 3.0, 3.0, 0, 180.0);
        }
        key_ambush(build, self.key, float(cx) - 0.5, float(cy) - 1.0, 0, side, 0, [2, long - 6], [e3m6_foe(dice, self.danger, True), e3m6_foe(dice, self.danger)]);
        dropped = build.touch(float(x0), 4.0, float(low), float(x1), float(side - 3), float(low + 4));
        below = build.waiting();
        dropped +>:Fires:+> below;
        build.foe(float(x1) - 2.5, float(cy) + 0.5, low, e3m6_foe(dice, self.danger, True), 180.0, waits=below);
        rounds(build, "monster_hell_knight", float(x0) + 6.5, 5.5, float(x1) - 1.5, 5.5, low);
        rounds(build, e3m6_foe(dice, self.danger), float(x1) - 1.5, float(side) - 4.5, float(x0) + 6.5, float(side) - 4.5, low);
        rounds(build, "monster_ogre", float(x0) + 1.5, float(side) - 1.5, float(x1) - 1.5, float(side) - 1.5, 0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 5, "monster_wizard", 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a chamber, ogres on a balcony over it, the slipgate
behind a door sunk by its button."""
node TormentExit(Prefab) {
    has key: str = "",
        tall: int = 16,
        balcony: int = 7,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(30, 33);
        self.wide = dice.between(16, 18);
        self.balcony = dice.between(7, 8);
        self.tall = self.balcony + dice.between(8, 10);
        self.shot = dice.chance(0.5);
        self.low = -9;
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
        b = self.balcony;
        wall = 8;
        hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
        chamber = build.room(wall + 1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, b);
        build.doorway(hall, self.enter);
        build.widen(chamber, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The balcony along the north wall, a stair up to it at its east
        # end.
        bx0 = wall + 1 + b;
        build.solid(bx0, wide - 5, b - 1, long - 8, wide - 1, b);
        stair(build, wall + 1, wide - 5, 0, 0, b, 4);
        keep_run(build, chamber, bx0 - 2, wide - 5, bx0 + 1, wide - 1, b);
        keep_run(build, chamber, long - 12, wide - 5, long - 9, wide - 4, b);
        # Racks along the south wall.
        for x in range(wall + 3, long - 9, 4) {
            build.solid(x, 1, 0, x + 2, 3, 2);
        }
        # The slipgate's alcove behind a door that sinks slowly when its
        # button is pressed (or shot from afar).
        gate_x = long - 7;
        build.solid(gate_x, 1, 0, gate_x + 1, wide - 1, self.tall);
        build.widen(chamber, gate_x, middle - 2, 0, gate_x + 1, middle + 2, 8);
        opener = build.sinking(float(gate_x), float(middle - 2), float(gate_x + 1), float(middle + 2), 8, 8);
        if self.shot {
            build.cue([build.button(float(gate_x), float(middle) + 3.5, 9.0, 2, "", True)], "button") +>:Fires:+> opener;
        } else {
            build.push(float(gate_x), float(middle) + 3.5, 1.5, 2) +>:Fires:+> opener;
        }
        build.way_out(float(long) - 3.5, float(middle), 0);
        build.touch(float(gate_x - 2), float(middle - 2), 0.0, float(gate_x), float(middle + 2), 6.0, True, "This door is opened elsewhere.");
        # Coming through the door wakes the balcony's ogres.
        through = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guard = build.waiting();
        through +>:Fires:+> guard;
        through +>:Fires:+> build.summon(1, 1, -9, e3m6_foe(dice, self.danger, True), 4.5, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx0 + 1 + index * 3) + 0.5, float(wide) - 2.5, b, "monster_ogre" if index > 0 else e3m6_foe(dice, self.danger, True), 270.0, waits=guard);
        }
        rounds(build, e3m6_foe(dice, self.danger), float(wall) + 3.5, float(middle) - 3.5, float(gate_x) - 2.5, float(middle) - 3.5, 0);
        rounds(build, "monster_ogre", 3.5, 2.5, 3.5, float(wide) - 3.5, 0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(long) - 9.5, float(wide) - 2.5, b, "item_rockets");
    }
}

"""e3m6's stretches: [name, role]."""
glob E3M6_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["bridge", "flow"],
         ["trains", "flow"],
         ["trains", "hub"],
         ["spikes", "flow"],
         ["buttons", "hub"],
         ["buttons", "flow"],
         ["pillar", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m6's stretches by its name."""
def make_e3m6(name: str, key: str) -> Prefab {
    if name == "yard" {
        return TormentYard();
    }
    if name == "bridge" {
        return TormentBridge();
    }
    if name == "trains" {
        return TrainPit();
    }
    if name == "spikes" {
        return SpikeCage();
    }
    if name == "buttons" {
        return ButtonHall();
    }
    if name == "pillar" {
        return TormentPillar(key=key if key else "key_gold");
    }
    return TormentExit(key=key);
}
