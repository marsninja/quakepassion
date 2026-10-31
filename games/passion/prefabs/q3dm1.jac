"""Prefabs drawn from Quake III's q3dm1, Arena Gate: a small gothic arena
on two floors, its halls and courts high and its lower court and crypt
sunk under them, a great arched gate between, its courts open to a sky far
overhead. Quake III's arenas hold no foes of their own; q3dm1's are knight, hell_knight, ogre. Raised in
q3dm1's own palette.

- `GateCourt`: the start. A terrace the run begins on, stairs down (in
  the middle or along a wall) to a court cut across by the great gate's
  arch, a far terrace beyond thrown up to by a jump pad or reached along a
  ledge high on the wall through the gate's pier; ways on from both
  terraces and the court beyond the gate.
- `GatePit`: a hall, a pit across its middle crossed by a bridge, by a
  walk along one wall, or not at all (a stair down and jump pads up);
  what waits in the pit wakes as the player crosses.
- `GateNave`: the hub. A nave between arcades, galleries over both aisles
  joined by a bridge across the nave's far end, climbed by stairs in the
  aisles, a jump pad or a lift; an apse sunk at the far end; ways on from
  the apse and both galleries.
- `GateCloister`: a court open to the sky, a walk round it under an upper
  walk, a stair up through the upper walk at one side; ways on from both
  walks.
- `GateCrypt`: the key room. A crypt sunk under the floor, the key on a
  ledge across it over a bridge, on a plinth on its floor, or on the ledge
  thrown up to by a jump pad; taking it opens the closets in the crypt.
- `GateDais`: the end (or a gate). A dais under an arch, galleries along
  both walls to it, climbed by a grand stair, stairs at the galleries'
  feet or a jump pad; its guards wake as the player comes up."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, slab_except, keep_box, hint, wake_later, pad, flying_stair }

glob Q3DM1: str = "q3:q3dm1",
     Q3DM1_LIGHT: list[str] = ["monster_knight", "monster_hell_knight"],
     Q3DM1_HEAVY: list[str] = ["monster_ogre"];

"""A foe for q3dm1's stretches."""
glob Q3DM1_FOES: FoeMix = FoeMix(light=Q3DM1_LIGHT, strong=Q3DM1_HEAVY, heavy_light=Q3DM1_HEAVY, scale=0.5);

"""The start: a terrace, stairs down to a court cut by the great gate's
arch, a far terrace beyond reached by a jump pad or along a high ledge."""
node GateCourt(Prefab) {
    has terrace: int = 6,
        side_stair: bool = False,
        ledge: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate court";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(32, 34);
        self.wide = dice.between(16, 18);
        self.terrace = dice.between(5, 6);
        self.side_stair = dice.chance(0.5);
        self.ledge = dice.chance(0.5);
        self.tall = self.terrace + 38;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        gx = 8 + self.terrace + 3;
        self.enter = Port(face=2, along=middle, floor=self.terrace);
        self.leaves = [
            Port(face=0, along=middle, floor=self.terrace),
            Port(face=3, along=float(gx + 5), floor=0),
            Port(face=1, along=4.0, floor=self.terrace)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        t = self.terrace;
        gx = 8 + t + 3;
        far = self.long - 8;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, t);
        # The terraces at either end.
        build.solid(1, 1, 0, 8, self.wide - 1, t);
        build.solid(far, 1, 0, self.long - 1, self.wide - 1, t);
        # Down from the near terrace: a broad stair in the middle, or a
        # narrow one along the -y wall.
        if self.side_stair {
            stair(build, 8 + t - 1, 1, 0, 2, t, 3);
            keep_box(build, court, 7, 1, 8, 4, t);
        } else {
            stair(build, 8 + t - 1, middle - 2, 0, 2, t, 4);
            keep_box(build, court, 7, middle - 2, 8, middle + 2, t);
        }
        # The great gate: a wall across the court, free-standing under the
        # sky, a high arch through it.
        build.solid(gx, 1, 0, gx + 2, self.wide - 1, t + 10);
        build.widen(court, gx, middle - 3, 0, gx + 2, middle + 3, 10);
        # A ledge high along the +y wall from terrace to terrace, through a
        # door in the gate's pier; else a jump pad up to the far terrace.
        if self.ledge {
            slab(build, 8, self.wide - 4, far, self.wide - 1, t);
            build.widen(court, gx, self.wide - 4, t, gx + 2, self.wide - 1, t + 8);
            keep_box(build, court, far - 4, self.wide - 4, far - 1, self.wide - 3, t);
        }
        if not self.ledge or dice.chance(0.5) {
            pad(build, court, float(far) - 3.0, float(middle) + 0.5, 0, float(far) + 1.5, float(middle) + 0.5, t, far, middle - 2, far + 1, middle + 3);
        }
        # The far terrace's edge to drop from, back into the court.
        keep_box(build, court, far, 1, far + 1, 4, t);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, t, 0.0);
        build.supply(2.5, float(middle) - 1.5, t, "ammo_shells", "q2");
        # What holds the far terrace wakes as the player comes through the
        # arch.
        arch = build.touch(float(gx), float(middle - 3), 0.0, float(gx + 2), float(middle + 3), 8.0);
        guards = wake_later(build, arch, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.0 + float(index) * float(self.wide - 6), t, Q3DM1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + t) + 1.5, 3.5 + float(index) * float(self.wide - 8), 0, Q3DM1_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(gx + 4) + 0.5, float(middle) + 3.5, 0, Q3DM1_FOES.pick(dice, self.danger, True), 180.0);
        if self.ledge {
            build.foe(float(gx - 2) + 0.5, float(self.wide) - 2.5, t, Q3DM1_FOES.pick(dice, self.danger), 0.0);
        }
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, t, Q3_ARMOR, "q3");
        build.supply(float(gx + 3) + 0.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A hall, a pit across its middle, crossed by a bridge, a walk along a
wall, or by a stair down and jump pads up the far side."""
node GatePit(Prefab) {
    has deep: int = 6,
        cross: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate pit";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(6, 7);
        self.cross = dice.below(3);
        self.tall = dice.between(18, 22);
        self.low = -self.deep - 1;
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
        build.level(hall, low);
        x0 = 8;
        x1 = self.long - 8;
        build.widen(hall, x0, 1, low, x1, self.wide - 1, 0);
        lane = middle - 1;
        if self.cross == 0 {
            slab(build, x0, lane, x1, lane + 3, 0);
            keep_box(build, hall, x0 - 1, lane, x0, lane + 3, 0);
            keep_box(build, hall, x1, lane, x1 + 1, lane + 3, 0);
        } elif self.cross == 1 {
            lane = 1;
            slab(build, x0, 1, x1, 4, 0);
            keep_box(build, hall, x0 - 1, 1, x0, 4, 0);
            keep_box(build, hall, x1, 1, x1 + 1, 4, 0);
        } else {
            # No way across but down: a stair into the pit from the near side.
            stair(build, x0 + self.deep - 1, middle - 2, low, 2, self.deep, 4);
            keep_box(build, hall, x0 - 1, middle - 2, x0, middle + 2, 0);
        }
        # Jump pads in the pit's floor throwing a body up to either side.
        py = self.wide - 4;
        pad(build, hall, float(x1) - 3.0, float(py), low, float(x1) + 1.5, float(py), 0, x1, py - 2, x1 + 1, py + 2);
        pad(build, hall, float(x0) + 3.0, float(py), low, float(x0) - 1.5, float(py), 0, x0 - 1, py - 2, x0, py + 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What waits in the pit wakes as the player crosses (or goes down).
        over = build.touch(float(self.long // 2 - 1), float(lane), 0.0, float(self.long // 2 + 1), float(lane + 3), 6.0) if self.cross < 2 else build.touch(float(x0), float(middle - 2), float(low), float(x0 + 2), float(middle + 2), float(low + 6));
        below = wake_later(build, over, 0.3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) - 2.5 - float(index) * 3.0, 2.5 + float(index % 2) * 2.0, low, Q3DM1_FOES.pick(dice, self.danger), 0.0, waits=below);
        }
        build.foe(float(x1) + 3.0, float(middle) + 0.5, 0, Q3DM1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(3.5, 3.5, 0, Q3DM1_FOES.pick(dice, self.danger), 0.0);
        build.supply(float(x1) - 2.5, float(middle) + 0.5, low, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The hub: a nave between arcades, galleries over both aisles joined by a
bridge across its far end, an apse sunk beyond."""
node GateNave(Prefab) {
    has gallery: int = 9,
        apse: int = 4,
        up: int = 0,
        broad: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate nave";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.gallery = 9;
        self.apse = 4;
        self.up = dice.below(3);
        self.broad = dice.chance(0.5);
        self.tall = self.gallery + 15;
        self.low = -self.apse - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-self.apse),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=3.5, floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        a = self.apse;
        middle = self.wide // 2;
        north = self.wide - 6;
        ax = self.long - 8;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, g);
        build.level(nave, -a);
        # The apse, sunk at the far end, its steps down across the nave (or
        # in its middle).
        build.widen(nave, ax, 1, -a, self.long - 1, self.wide - 1, 0);
        if self.broad {
            stair(build, ax + a - 1, 6, -a, 2, a, north - 6);
        } else {
            stair(build, ax + a - 1, middle - 2, -a, 2, a, 4);
        }
        # The arcades between nave and aisles.
        for x in range(5, ax - 1, 4) {
            build.solid(x, 5, 0, x + 1, 6, g - 1);
            build.solid(x, north, 0, x + 1, north + 1, g - 1);
        }
        # The galleries over the aisles, from past the aisle stairs' tops.
        gs = 2 + g;
        slab(build, gs, 1, self.long - 1, 6, g);
        flying_stair(build, 2, 1, 0, 0, g, 3);
        if self.up == 0 {
            slab(build, gs, north, self.long - 1, self.wide - 1, g);
            flying_stair(build, 2, self.wide - 4, 0, 0, g, 3);
        } else {
            slab(build, 2, north, self.long - 1, self.wide - 1, g);
            if self.up == 1 {
                px = 15;
                pad(build, nave, float(px), float(north - 3), 0, float(px), float(north) + 2.0, g, px - 2, north, px + 2, north + 1);
            } else {
                lift(build, ax - 4, north - 3, ax - 1, north, 0, g);
                keep_box(build, nave, ax - 4, north, ax - 1, north + 1, g);
                keep_box(build, nave, ax - 5, north - 4, ax, north, 0);
            }
        }
        # The bridge across the nave's far end between the galleries.
        slab(build, ax - 3, 6, ax, north, g);
        # Edges of the galleries to drop from, into the nave.
        keep_box(build, nave, gs + 2, 5, gs + 5, 6, g);
        keep_box(build, nave, ax - 8, north, ax - 5, north + 1, g);
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        # The galleries' guards wake as the player reaches the nave's
        # middle; a guard walks the -y aisle.
        midway = build.touch(float(self.long // 2 - 1), 6.0, 0.0, float(self.long // 2 + 1), float(north), 6.0);
        above = wake_later(build, midway, 0.5);
        build.foe(float(self.long) - 3.5, 3.5, g, Q3DM1_FOES.pick(dice, self.danger, True), 180.0, waits=above);
        build.foe(float(self.long) - 6.5, float(self.wide) - 3.5, g, Q3DM1_FOES.pick(dice, self.danger), 180.0, waits=above);
        build.foe(float(gs) + 1.5, 4.5, 0, Q3DM1_FOES.pick(dice, self.danger), 0.0, patrol=[[float(gs) + 1.5, 4.5], [float(ax) - 2.5, 4.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, Q3DM1_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, -a, Q3DM1_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(middle) + 3.5, -a, Q3_ARMOR, "q3");
        build.supply(float(ax) - 1.5, 3.5, g, Q3_HEALTH, "q3");
        build.supply(3.5, float(middle) + 0.5, 0, "ammo_shells", "q2");
        build.supply(float(ax) - 1.5, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""A court open to the sky, a walk round it under an upper walk, a stair
up through the upper walk at one side."""
node GateCloister(Prefab) {
    has upper: int = 9,
        east: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate cloister";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(24, 26);
        self.upper = 9;
        self.east = dice.chance(0.5);
        self.tall = self.upper + 38;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=3, along=float(self.long // 2), floor=0) if self.east else Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.upper),
            Port(face=3, along=3.5, floor=self.upper),
            Port(face=0, along=float(self.wide) - 3.5, floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        u = self.upper;
        long = self.long;
        wide = self.wide;
        walk = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(walk, u);
        # The stair up through the upper walk, and the hole it comes up by.
        hole: list[int] = [];
        if self.east {
            stair(build, long - 4, 7, 0, 1, u, 3);
            hole = [long - 4, 7, long - 1, 7 + u];
        } else {
            stair(build, 7, 1, 0, 0, u, 3);
            hole = [7, 1, 7 + u, 4];
        }
        # The upper walk round the court.
        slab_except(build, 1, 1, long - 1, 6, u, hole);
        slab_except(build, 1, wide - 6, long - 1, wide - 1, u, hole);
        slab_except(build, 1, 6, 6, wide - 6, u, hole);
        slab_except(build, long - 6, 6, long - 1, wide - 6, u, hole);
        # Columns along the court's edge holding the upper walk up.
        for x in range(6, long - 6, 4) {
            build.solid(x, 5, 0, x + 1, 6, u - 1);
            build.solid(x, wide - 6, 0, x + 1, wide - 5, u - 1);
        }
        for y in range(10, wide - 6, 4) {
            build.solid(5, y, 0, 6, y + 1, u - 1);
            if not self.east {
                build.solid(long - 6, y, 0, long - 5, y + 1, u - 1);
            }
        }
        # Plinths in the court's corners.
        for spot in [[8, 8], [long - 10, 8], [8, wide - 10], [long - 10, wide - 10]] {
            build.solid(spot[0], spot[1], 0, spot[0] + 2, spot[1] + 2, 2);
        }
        # The upper walk's inner edge to drop from, into the court.
        keep_box(build, walk, 10, wide - 6, 13, wide - 5, u);
        keep_box(build, walk, 5, 10, 6, 13, u);
        build.doorway(walk, self.enter);
        for port in self.taken {
            build.doorway(walk, port);
        }
        foot = build.touch(6.0, 1.0, 0.0, 9.0, 5.0, 6.0) if not self.east else build.touch(float(long - 5), 5.0, 0.0, float(long - 1), 8.0, 6.0);
        above = wake_later(build, foot, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(long - 3) - float(index) * 7.0, float(wide) - 3.0, u, Q3DM1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=above);
        }
        build.foe(3.0, 3.0, 0, Q3DM1_FOES.pick(dice, self.danger), 0.0, patrol=[[3.0, 3.0], [3.0, float(wide) - 3.0], [float(long) - 7.0, float(wide) - 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(long // 2) + 0.5, float(wide // 2) + (2.5 if index == 0 else -2.5), 0, Q3DM1_FOES.pick(dice, self.danger), 90.0);
        }
        build.supply(float(long // 2) + 0.5, float(wide // 2) + 0.5, 0, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, u, Q3_HEALTH, "q3");
        build.supply(3.0, float(wide) - 3.0, u, Q3_ARMOR, "q3");
    }
}

"""The key room: a crypt sunk under the floor, the key across it on a
ledge over a bridge, on a plinth on its floor, or on the ledge thrown up
to by a jump pad."""
node GateCrypt(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        crypt: int = 6,
        form: int = 0,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate crypt (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.crypt = 6;
        self.form = dice.below(3);
        self.tall = dice.between(18, 20);
        self.low = -self.crypt - 1;
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
        c = -self.crypt;
        far = self.long - 6;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, c);
        build.doorway(vault, self.enter);
        build.widen(vault, 8, 1, c, self.long - 1, side, 0);
        key_x = float(self.long) - 3.0;
        key_z = 0;
        if self.form == 1 {
            # The key on a plinth on the crypt's floor, a broad stair down.
            stair(build, 8 + self.crypt - 1, cy - 2, c, 2, self.crypt, 4);
            keep_box(build, vault, 7, cy - 2, 8, cy + 2, 0);
            build.solid(far, cy - 1, c, far + 3, cy + 2, c + 1);
            key_x = float(far) + 1.5;
            key_z = c + 1;
        } else {
            # The far ledge, at the floor's height, the key on it; a stair up
            # out of the crypt along the -y wall.
            build.solid(far, 1, c, self.long - 1, side, 0);
            stair(build, 8 + self.crypt - 1, 1, c, 2, self.crypt, 3);
            keep_box(build, vault, 7, 1, 8, 4, 0);
            if self.form == 0 {
                slab(build, 8, cy - 1, far, cy + 2, 0);
                keep_box(build, vault, 7, cy - 1, 8, cy + 2, 0);
                keep_box(build, vault, far, cy - 1, far + 1, cy + 2, 0);
            } else {
                pad(build, vault, float(far) - 3.0, float(cy) + 0.5, c, float(far) + 1.5, float(cy) + 0.5, 0, far, cy - 2, far + 1, cy + 3);
            }
            # The ledge's edge to drop from, back into the crypt.
            keep_box(build, vault, far, side - 4, far + 1, side - 1, 0);
        }
        key_ambush(build, self.key, key_x, float(cy) + 0.5, key_z, side, c, [9, far - 3], [Q3DM1_FOES.pick(dice, self.danger, True), Q3DM1_FOES.pick(dice, self.danger)]);
        hint(build, 3.0, 1.0, 0.0, 6.0, float(side), 6.0, "The crypt", "Its dead do not rest", 2.0);
        for index in range(dice.between(1, 2)) {
            build.foe(9.5 + float(index) * 3.0, float(cy) + 3.5, c, Q3DM1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(3.5, 3.5, 0, Q3DM1_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a dais under an arch, galleries along both walls to
it, climbed by a grand stair, stairs at the galleries' feet or a jump pad."""
node GateDais(Prefab) {
    has key: str = "",
        dais: int = 7,
        access: int = 0,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate dais" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM1;
        self.district = level_district(Q3DM1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(18, 20);
        self.dais = 7;
        self.access = dice.below(3);
        self.tall = self.dais + 20;
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
        wall = 7;
        d = self.dais;
        dx = self.long - 8;
        gs = wall + 2 + d;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(room, d);
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, d);
        slab(build, gs, 1, dx, 5, d);
        slab(build, gs, self.wide - 5, dx, self.wide - 1, d);
        if self.access == 0 {
            stair(build, dx - d, middle - 2, 0, 0, d, 4);
            keep_box(build, room, dx, middle - 2, dx + 1, middle + 2, d);
        } elif self.access == 1 {
            flying_stair(build, wall + 2, 1, 0, 0, d, 3);
            flying_stair(build, wall + 2, self.wide - 4, 0, 0, d, 3);
        } else {
            pad(build, room, float(dx) - 3.0, float(middle) + 0.5, 0, float(dx) + 2.0, float(middle) + 0.5, d, dx, middle - 2, dx + 1, middle + 3);
        }
        # The galleries' inner edges to drop from.
        keep_box(build, room, gs + 2, 4, gs + 5, 5, d);
        keep_box(build, room, gs + 2, self.wide - 5, gs + 5, self.wide - 4, d);
        # The arch on the dais, the way out under it.
        ax = self.long - 5;
        build.solid(ax, middle - 3, d, ax + 1, middle - 2, d + 9);
        build.solid(ax, middle + 2, d, ax + 1, middle + 3, d + 9);
        build.solid(ax, middle - 3, d + 9, ax + 1, middle + 3, d + 10);
        build.way_out(float(ax) + 2.0, float(middle), d);
        # The dais's guards wake as the player comes up to it.
        up = build.touch(float(dx), 1.0, float(d), float(dx + 2), float(self.wide - 1), float(d + 6));
        guards = wake_later(build, up, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(dx + 3) + 0.5, 3.0 + float(index) * 3.5, d, Q3DM1_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall + 4 + index * 3) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.5), 0, Q3DM1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(gs) + 2.5, 3.0, d, Q3DM1_FOES.pick(dice, self.danger, True), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(gs) + 1.5, float(self.wide) - 3.0, d, Q3_ARMOR, "q3");
    }
}

"""q3dm1's stretches: [name, role]."""
glob Q3DM1_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["pit", "flow"],
         ["cloister", "flow"],
         ["nave", "hub"],
         ["crypt", "keyroom"],
         ["dais", "end"],
         ["dais", "gate"]
     ];

"""One of q3dm1's stretches by its name."""
def make_q3dm1(name: str, key: str) -> Prefab {
    if name == "court" {
        return GateCourt();
    }
    if name == "pit" {
        return GatePit();
    }
    if name == "cloister" {
        return GateCloister();
    }
    if name == "nave" {
        return GateNave();
    }
    if name == "crypt" {
        return GateCrypt(key=key if key else "key_silver");
    }
    return GateDais(key=key);
}
