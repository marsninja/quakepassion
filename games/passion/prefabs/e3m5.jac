"""Prefabs drawn from e3m5, the Wind Tunnels: tubes of wind that throw a
body far up, deep flooded tunnels swum under walls, bars and sealed air
tubes opened from elsewhere, a hall of spike traps, scrags in the air and
ambushes teleported in. e3m5 holds no keys; its key room and gate are
drawn from its pillars and shafts. Raised in e3m5's own palette.

- `TubeFoot`: the start. A tall hall at the foot of a wind tube ("Jump up
  here...."), a gallery high over its floor that the wind throws a body up
  to, across its far end or along a side; a pool in the floor, a secret
  closet under the gallery behind a wall that opens when shot. What waits
  on the gallery wakes as the player lands; a scrag circles over the hall.
- `FloodedTube`: a long tunnel flooded deep, a wall down into the water
  to swim under (or a stone causeway over it), the far shore's stair up out
  of the water, and a walkway high along one wall over the whole tunnel,
  reached from the far shore by the wind or a lift, with drops back into
  the water. Ways on at the far shore's floor and from the walkway.
- `WindChamber`: a tall chamber, a pool in its floor, a ledge along one
  wall and a higher ledge along another; the wind throws a body from the
  floor to the first (or a stair climbs to it) and from the first to the
  second, a catwalk crosses over the pool; the high way on is barred until
  a button elsewhere in the chamber is pressed (e3m5's "These bars are
  opened elsewhere"), which also teleports an ambush onto the high ledge.
  Ways on at every height (a hub).
- `SpikeGallery`: a long hall, a gallery along one side climbed to at the
  far end by a stair or a lift; spikes fly across the floor from both walls
  while anyone crosses its middle (e3m5's spike traps), over water when the
  floor is a trench; a button on the gallery opens the sealed air tube out
  of the floor ("This air tube is sealed...").
- `QuadPillar`: the key room. The key on a pillar standing in a deep pool,
  the wind throwing a body up to it from the shore, or a lift beside it;
  taking it teleports foes in behind; a secret alcove under the water.
- `WindExit`: the end. A hall, a door (a key's, as a gate), a balcony over
  a deep shaft, the slipgate at its foot: down by a plunge into a pool or
  by ledges stepping down its wall; doors at the foot burst open as the
  player comes out onto the balcony."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .roster { FoeMix }
import from .common { stair, lift, key_item }

glob E3M5: str = "q1:e3m5";

"""e3m5's foes: scrags above all, ogres and fiends, hell knights deeper in."""
glob E3M5_FOES: FoeMix = FoeMix(light=["monster_ogre", "monster_wizard"], strong=["monster_hell_knight"], heavy_light=["monster_ogre", "monster_demon1"], flying="monster_wizard");

"""Whether two ports are the same way (face, floor and place along it)."""
def same_port(a: Port, b: Port) -> bool {
    return a.face == b.face and a.floor == b.floor and abs(a.along - b.along) < 0.01;
}

"""Keep the cells x0..x1, y0..y1 on lift z clear of railings (a drop's
edge, a stair's top, a pad's throw)."""
def keep_run(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for y in range(y0, y1) {
        for x in range(x0, x1) {
            build.keep(space, x, y, z);
        }
    }
}

"""A way out of a prefab `long` by `wide` cut through its wall as the air
of `space`, sealed by a door in the wall that rises only when `opener`
fires (bars, a sealed air tube); `message` is shown to who touches it
shut."""
def sealed_way(build: Raising, space: Space, long: int, wide: int, port: Port, opener: Cue, message: str = "") {
    build.doorway(space, port);
    low = port.along - float(port.wide) * 0.5;
    high = port.along + float(port.wide) * 0.5;
    fields: dict[str, str] = {"wait": "-1"};
    if message {
        fields["message"] = message;
    }
    bottom = float(port.floor);
    top = float(port.floor + port.high);
    if port.face == 0 {
        build.rising_door(float(long - 1), low, bottom, float(long), high, top, fields);
    } elif port.face == 1 {
        build.rising_door(low, float(wide - 1), bottom, high, float(wide), top, fields);
    } elif port.face == 3 {
        build.rising_door(low, 0.0, bottom, high, 1.0, top, fields);
    } else {
        build.rising_door(0.0, low, bottom, 1.0, high, top, fields);
    }
    opener +>:Fires:+> build.cue([fields], "door");
}

"""Doors that burst open (fast, as e3m5's last doors do) when their cue
fires: a door of the prefab's cells x0..x1, y0..y1, z0..z1."""
def bursting(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> Cue {
    fields: dict[str, str] = {"wait": "-1", "speed": "500"};
    build.rising_door(x0, y0, z0, x1, y1, z1, fields);
    return build.cue([fields], "door");
}

"""The start: a tall hall at the foot of a wind tube, a gallery high over
its floor the wind throws a body up to."""
node TubeFoot(Prefab) {
    has gallery: int = 13,
        tall: int = 24,
        form: int = 0,
        secret_in: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tube foot";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.form = dice.below(2);
        self.long = dice.between(22, 26);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(14, 18);
        self.tall = self.gallery + dice.between(16, 20);
        self.secret_in = dice.chance(0.7);
        self.low = -7;
        self.high = self.tall + 1;
        g = self.gallery;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        if self.form == 0 {
            self.leaves = [Port(face=0, along=float(self.wide // 2), floor=g), Port(face=1, along=float(self.long - 4), floor=g), Port(face=3, along=float(self.long - 4), floor=g)];
        } else {
            self.leaves = [Port(face=1, along=6.0, floor=g), Port(face=0, along=float(self.wide - 4), floor=g), Port(face=1, along=float(self.long - 7), floor=g)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        long = self.long;
        wide = self.wide;
        mid = wide // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        landing: list[int] = [];
        rest: list[float] = [];
        if self.form == 0 {
            # The gallery across the far end, a slab on pillars over the
            # floor, and the wind tube up to it.
            gx = long - 7;
            build.solid(gx, 1, g - 1, long - 1, wide - 1, g);
            for y in [2, wide - 3] {
                build.solid(gx, y, 0, gx + 1, y + 1, g - 1);
            }
            build.jump_pad(float(gx) - 3.0, float(mid) + 0.5, 0, float(gx) + 1.0, float(mid) + 0.5, g);
            keep_run(build, hall, gx, mid - 2, gx + 1, mid + 3, g);
            build.touch(float(gx - 7), float(mid - 2), 0.0, float(gx - 5), float(mid + 3), 6.0, False, "Jump up here....");
            build.pool(4, 1, -6, gx - 4, mid - 1, 0, 2);
            landing = [gx, mid - 2, gx + 3, mid + 3];
            rest = [float(long) - 2.5, 3.5];
            if self.secret_in {
                build.solid(long - 6, 1, 0, long - 1, 5, g - 1);
                build.room(long - 4, 1, 0, long - 2, 3, 4);
                build.secret_door(float(long - 4), 3.0, 0.0, float(long - 2), 5.0, 4.0, 3);
                build.secret(float(long - 4), 1.0, 0.0, float(long - 2), 3.0, 3.0);
                build.supply(float(long) - 3.0, 2.0, 0, "item_artifact_envirosuit");
            }
            build.foe(float(gx) - 1.5, float(wide) - 2.5, 0, E3M5_FOES.pick(dice, self.danger), 180.0);
        } else {
            # The gallery along a side wall the length of the hall, the wind
            # tube up to its middle.
            gy = wide - 6;
            px = long // 2 + 1;
            build.solid(1, gy, g - 1, long - 1, wide - 1, g);
            for x in range(5, long - 6, 6) {
                if abs(x - px) > 2 {
                    build.solid(x, gy, 0, x + 1, gy + 1, g - 1);
                }
            }
            build.jump_pad(float(px) + 0.5, float(gy) - 3.0, 0, float(px) + 0.5, float(gy) + 1.0, g);
            keep_run(build, hall, px - 2, gy, px + 3, gy + 1, g);
            build.touch(float(px - 2), float(gy - 7), 0.0, float(px + 3), float(gy - 5), 6.0, False, "Jump up here....");
            build.pool(px + 3, 1, -6, long - 2, gy - 2, 0, 2);
            landing = [px - 2, gy, px + 3, gy + 3];
            rest = [float(long) - 4.5, float(wide) - 2.5];
            if self.secret_in {
                build.solid(long - 6, gy, 0, long - 1, wide - 1, g - 1);
                build.room(long - 4, wide - 3, 0, long - 2, wide - 1, 4);
                build.secret_door(float(long - 4), float(gy), 0.0, float(long - 2), float(wide - 3), 4.0, 1);
                build.secret(float(long - 4), float(wide - 3), 0.0, float(long - 2), float(wide - 1), 3.0);
                build.supply(float(long) - 3.0, float(wide) - 2.0, 0, "item_artifact_envirosuit");
            }
            build.foe(float(px) - 3.5, 2.5, 0, E3M5_FOES.pick(dice, self.danger), 90.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "item_shells");
        # What waits on the gallery wakes as the wind sets a body down.
        landed = build.touch(float(landing[0]), float(landing[1]), float(g), float(landing[2]), float(landing[3]), float(g + 6));
        guard = build.waiting();
        landed +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(rest[0] - float(index) * 3.0, rest[1] + (float(index) * 3.0 if self.form == 0 else 0.0), g, E3M5_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        # A scrag circling over the hall.
        high = g - 3;
        build.foe(6.5, float(mid) + 0.5, high, "monster_wizard", 0.0, patrol=[[6.5, float(mid) + 0.5], [float(long) - 9.5, float(mid) + 0.5], [float(long) - 9.5, 3.5], [6.5, 3.5]]);
        build.supply(rest[0], rest[1] - 1.0 if self.form == 0 else rest[1], g, "item_health");
    }
}

"""A long tunnel flooded deep, a wall down into the water to swim under,
the far shore's stair up out of it and a walkway high over it all."""
node FloodedTube(Prefab) {
    has deep: int = 7,
        walk: int = 9,
        tall: int = 18,
        dive: bool = True,
        climb: int = 0,
        secret_in: bool = False,
        ambush: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded tube";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.deep = dice.between(9, 12);
        self.dive = dice.chance(0.65);
        self.climb = dice.below(2);
        self.ambush = dice.chance(0.6);
        self.long = 2 * self.deep + dice.between(16, 20);
        self.wide = self.deep + dice.between(3, 5);
        self.secret_in = self.dive and self.wide >= 14 and dice.chance(0.7);
        self.walk = dice.between(9, 11);
        self.tall = self.walk + dice.between(22, 28);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        far = self.long - 6;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 6)), floor=0);
        self.leaves = [
            Port(face=0, along=3.0, floor=0),
            Port(face=3, along=float(far + 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.walk),
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=3, along=float(self.long // 2 - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        deep = self.deep;
        u = self.walk;
        x0 = 5;
        x1 = long - 6;
        wy = wide - 5;
        tube = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(tube, u);
        build.pool(x0, 1, -deep, x1, wide - 1, 0, 2);
        # The far shore's stair up out of the water.
        stair(build, x1 - deep, 1, -deep, 0, deep, 2);
        # Walkways high along both walls, the whole length of the tunnel,
        # and bridges across between them over the water.
        build.solid(x0, wy, u - 1, long - 1, wide - 1, u);
        build.solid(x0, 1, u - 1, long - 1, 4, u);
        xm = x0 + 3 + (x1 - deep - x0 - 3) // 2;
        for bx in [x0 + 1 + dice.below(2), x1 - 4 - dice.below(3)] {
            build.solid(bx, 4, u - 1, bx + 3, wy, u);
        }
        if self.dive {
            # The wall down into the water across the tunnel: under it is
            # the way on; over it the walkways run on.
            build.solid(xm, 1, -1, xm + 2, wide - 1, u - 1);
            build.solid(xm, 4, u - 1, xm + 2, wy, self.tall);
            if self.secret_in {
                # A closet in the wall off the walkway, behind a stretch of
                # it that opens when shot.
                build.room(xm, wy - 3, u, xm + 2, wy - 1, u + 4);
                build.secret_door(float(xm), float(wy - 1), float(u), float(xm + 2), float(wy), float(u + 4), 3);
                build.secret(float(xm), float(wy - 3), float(u), float(xm + 2), float(wy - 1), float(u + 3));
                build.supply(float(xm) + 1.0, float(wy) - 2.0, u, "item_artifact_super_damage");
            }
        } else {
            # A stone causeway across the water, just over it.
            build.solid(x0, wy - 4, -1, x1, wy - 1, 0);
            keep_run(build, tube, x0 - 1, wy - 4, x0, wy - 1, 0);
            keep_run(build, tube, x1, wy - 4, x1 + 1, wy - 1, 0);
        }
        # Drops from the walkways back into the water.
        keep_run(build, tube, x0 + 5, wy, x0 + 8, wy + 1, u);
        keep_run(build, tube, xm + 3, 3, xm + 6, 4, u);
        # Up from the far shore to the walkway: the wind, or a lift.
        if self.climb == 0 {
            build.jump_pad(float(x1) + 1.5, float(wy) - 3.0, 0, float(x1) + 1.5, float(wy) + 1.0, u);
            keep_run(build, tube, x1, wy, x1 + 4, wy + 1, u);
        } else {
            lift(build, x1 + 1, wy - 3, x1 + 4, wy, 0, u);
            keep_run(build, tube, x1, wy, x1 + 5, wy + 1, u);
            keep_run(build, tube, x1, wy - 4, x1 + 5, wy, 0);
        }
        build.doorway(tube, self.enter);
        for port in self.taken {
            build.doorway(tube, port);
        }
        # Scrags over the water.
        for index in range(dice.between(1, 2)) {
            y = float(wide // 2) - 1.5 + float(index) * 2.0;
            build.foe(float(x0) + 2.5, y, 3 + index * 2, "monster_wizard", 0.0, patrol=[[float(x0) + 2.5, y], [float(x1) - 2.5, y]]);
        }
        # Coming up onto the far shore wakes the walkway's guard.
        shore = build.touch(float(x1), 1.0, 0.0, float(x1 + 2), float(wide - 1), 6.0);
        guard = build.waiting();
        shore +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(xm) + 4.5 + float(index) * 4.0, float(wide) - 2.5 if index == 0 else 2.5, u, E3M5_FOES.pick(dice, self.danger, index == 0), 0.0, waits=guard);
        }
        if self.ambush {
            shore +>:Fires:+> build.summon(1, 1, -deep - 1, E3M5_FOES.pick(dice, self.danger, True), float(long) - 3.5, 3.5, 0, 180.0);
        }
        build.foe(float(long) - 2.5, float(wy) - 5.5, 0, E3M5_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_spikes");
        build.supply(float(long) - 2.5, float(wide) - 2.5, u, "item_health");
    }
}

"""A tall chamber, a pool in its floor, a ledge along one wall and a higher
ledge along another, the wind between them, a catwalk over the pool, the
high way on barred until a button is pressed."""
node WindChamber(Prefab) {
    has low_ledge: int = 8,
        top_ledge: int = 15,
        deep: int = 6,
        tall: int = 26,
        catwalk: bool = True,
        span: bool = True,
        bars: bool = True,
        ambush: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind chamber";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(28, 32);
        self.wide = dice.between(24, 28);
        self.low_ledge = dice.between(8, 10);
        self.top_ledge = self.low_ledge + dice.between(8, 10);
        self.deep = dice.between(10, 13);
        self.tall = self.top_ledge + dice.between(20, 26);
        self.catwalk = dice.chance(0.55);
        self.span = dice.chance(0.6);
        self.bars = dice.chance(0.7);
        self.ambush = dice.chance(0.6);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        cx = self.long // 2 - 1;
        self.enter = Port(face=2, along=float(dice.between(4, 8)), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=self.top_ledge),
            Port(face=1, along=float(self.long // 3), floor=self.low_ledge),
            Port(face=3, along=float(cx) + 1.5, floor=self.low_ledge if self.catwalk else 0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        h1 = self.low_ledge;
        h2 = self.top_ledge;
        ay = wide - 6;
        bx = long - 6;
        cx = long // 2 - 1;
        chamber = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, h1);
        build.level(chamber, h2);
        # The pool in the floor, steps out of it at both ends.
        build.pool(6, 6, -self.deep, long - 9, wide - 10, 0, 2, False, True, True);
        # The low ledge along the north wall, the high one along the east.
        build.solid(1, ay, h1 - 1, long - 7, wide - 1, h1);
        build.solid(bx, 1, h2 - 1, long - 1, wide - 1, h2);
        # The wind from the low ledge to the high one.
        build.jump_pad(float(long) - 9.0, float(wide) - 3.5, h1, float(long) - 5.0, float(wide) - 3.5, h2);
        keep_run(build, chamber, long - 8, ay + 1, long - 7, wide - 1, h1);
        keep_run(build, chamber, bx, ay + 1, bx + 1, wide - 1, h2);
        # Drops from the high ledge's edge to the floor below.
        keep_run(build, chamber, bx, 1, bx + 1, 4, h2);
        if self.span {
            # A bridge from the high ledge west across the chamber, over the
            # pool and the catwalk, to a platform on the west wall over the
            # way in; a prize on it.
            build.solid(6, 7, h2 - 1, bx, 10, h2);
            build.solid(1, 5, h2 - 1, 6, 12, h2);
            keep_run(build, chamber, 2, 11, 5, 12, h2);
            build.supply(2.5, 8.5, h2, "item_armor2");
            build.foe(3.5, 6.5, h2, E3M5_FOES.pick(dice, self.danger, True), 0.0);
        }
        if self.catwalk {
            # The wind from the floor to the low ledge, and a catwalk from it
            # across over the pool to a platform on the south wall.
            build.jump_pad(4.5, float(ay) - 3.0, 0, 4.5, float(ay) + 1.0, h1);
            keep_run(build, chamber, 3, ay, 7, ay + 1, h1);
            build.solid(cx, 4, h1 - 1, cx + 3, ay, h1);
            build.solid(cx - 3, 1, h1 - 1, cx + 6, 4, h1);
            press = build.push(float(cx) + 4.5, 1.0, float(h1) + 1.2, 1);
        } else {
            # A stair along the low ledge's edge up to it.
            sx = 9;
            stair(build, sx, ay - 3, 0, 0, h1, 3);
            keep_run(build, chamber, sx + h1 - 3, ay, sx + h1 + 1, ay + 1, h1);
            press = build.push(1.0, float(wide // 2), 1.2, 0);
        }
        build.doorway(chamber, self.enter);
        for port in self.taken {
            if self.bars and port.floor == h2 {
                sealed_way(build, chamber, long, wide, port, press, "These bars are opened elsewhere");
            } else {
                build.doorway(chamber, port);
            }
        }
        if self.ambush {
            press +>:Fires:+> build.summon(1, 1, -self.deep - 2, E3M5_FOES.pick(dice, self.danger, True), float(long) - 3.5, float(wide // 2) + 0.5, h2, 180.0);
        }
        # The scrags hang in the air over the pool.
        for index in range(dice.between(2, 3)) {
            build.foe(float(long // 2) + 0.5 - float(index) * 3.0, float(wide // 2) - 2.5 + float(index) * 2.0, h1 + 2 + index * 2, "monster_wizard", float(index * 120));
        }
        # The low ledge's guard wakes as a body reaches it.
        up = build.touch(1.0, float(ay), float(h1), float(long - 7), float(ay + 2), float(h1 + 6));
        guard = build.waiting();
        up +>:Fires:+> guard;
        build.foe(float(long // 3) + 4.5, float(wide) - 2.5, h1, E3M5_FOES.pick(dice, self.danger), 270.0, waits=guard);
        build.foe(float(long) - 3.5, 3.5, h2, E3M5_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        build.foe(float(long) - 4.5, 3.5, 0, E3M5_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(3.5, 3.5, 0, "item_rockets");
        build.supply(float(long) - 2.5, float(wide) - 2.5, h2, "item_health");
        build.supply(2.5, float(wide) - 2.5, h1, "item_spikes");
    }
}

"""A long hall, a gallery along one side, spikes across its floor, the
sealed air tube out of the floor opened from the gallery."""
node SpikeGallery(Prefab) {
    has gallery: int = 7,
        tall: int = 16,
        climb: int = 0,
        trench: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike gallery";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.gallery = dice.between(6, 8);
        self.tall = self.gallery + dice.between(8, 10);
        self.climb = dice.below(2);
        self.trench = dice.chance(0.5);
        self.low = -8;
        self.high = self.tall + 1;
        gy = self.wide - 5;
        self.enter = Port(face=2, along=float(gy // 2 + 1), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 3), floor=self.gallery),
            Port(face=1, along=6.0, floor=self.gallery),
            Port(face=0, along=float(gy // 2 - 1), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        u = self.gallery;
        gy = wide - 5;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        build.solid(1, gy, u - 1, long - 1, wide - 1, u);
        for x in range(6, long - 7, 5) {
            build.solid(x, gy, 0, x + 1, gy + 1, u - 1);
        }
        # Up to the gallery at the far end: a stair along its edge, or a lift.
        if self.climb == 0 {
            stair(build, long - 3 - u, gy - 3, 0, 0, u, 3);
            keep_run(build, hall, long - 6, gy, long - 2, gy + 1, u);
        } else {
            lift(build, long - 5, gy - 3, long - 2, gy, 0, u);
            keep_run(build, hall, long - 6, gy, long - 1, gy + 1, u);
            keep_run(build, hall, long - 6, gy - 4, long - 1, gy, 0);
        }
        # Drops from the gallery back to the floor near the way in.
        keep_run(build, hall, 9, gy, 12, gy + 1, u);
        a = 7;
        b = long - 8;
        if self.trench {
            # The middle of the floor a trench of water, a causeway along
            # under the gallery.
            build.pool(a, 1, -min(7, gy - 4), b, gy - 3, 0, 2);
        }
        # The spike traps: shooters in both walls firing across the floor's
        # middle while anyone is in it.
        zone = build.touch(float(a), 1.0, 0.0, float(b), float(gy), 5.0, False);
        for x in range(a + 2, b - 1, 4) {
            zone +>:Fires:+> build.spikes(float(x) + 0.5, 1.2, 2.5, 1);
            zone +>:Fires:+> build.spikes(float(x) + 2.5, float(wide) - 1.2, 2.5, 3);
        }
        build.touch(2.0, 1.0, 0.0, 4.0, float(gy), 6.0, True, "This air tube is sealed...");
        press = build.push(float(long // 2) + 0.5, float(wide - 1), float(u) + 1.2, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, hall, long, wide, port, press, "This air tube is sealed...");
            } else {
                build.doorway(hall, port);
            }
        }
        # The gallery's guard wakes as a body crosses the traps.
        guard = build.waiting();
        zone +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(long) - 8.5 - float(index) * 5.0, float(wide) - 2.5, u, E3M5_FOES.pick(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        build.foe(float(long) - 3.5, 3.5, 0, E3M5_FOES.pick(dice, self.danger), 180.0, patrol=[[float(long) - 3.5, 3.5], [float(long) - 3.5, float(gy) - 4.5]]);
        build.foe(float(long // 2) + 0.5, float(gy // 2) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(float(long) - 2.5, float(wide) - 2.5, u, "item_health");
        build.supply(3.5, float(gy) + 2.5, 0, "item_spikes");
    }
}

"""The key room: the key on a pillar in a deep pool, the wind or a lift up
to it; taking it teleports foes in behind."""
node QuadPillar(Prefab) {
    has key: str = "key_silver",
        top: int = 9,
        deep: int = 6,
        tall: int = 19,
        form: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Quad pillar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.form = dice.below(2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.top = dice.between(8, 10);
        self.deep = dice.between(8, 10);
        self.tall = self.top + dice.between(18, 24);
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
        p = self.top;
        deep = self.deep;
        cy = wide // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, p);
        build.doorway(hall, self.enter);
        px1 = long - 6;
        build.pool(7, 4, -deep, px1, wide - 4, 0, 2, False, True, True);
        if self.form == 0 {
            # The pillar in the middle of the pool, the wind up to it from
            # the west shore.
            # A pier runs out to two cells short of it, the pad at its end.
            cx = (7 + px1) // 2 + 1;
            build.solid(cx - 2, cy - 2, -deep, cx + 2, cy + 2, p);
            build.solid(7, cy - 2, -deep, cx - 4, cy + 2, 0);
            build.jump_pad(float(cx) - 5.0, float(cy), 0, float(cx) - 1.0, float(cy), p);
            keep_run(build, hall, cx - 5, cy - 2, cx - 4, cy + 2, 0);
        } else {
            # The pillar at the pool's east end, a lift up beside it from
            # the far shore.
            cx = px1 - 2;
            build.solid(cx - 2, cy - 2, -deep, cx + 2, cy + 2, p);
            lift(build, px1, cy - 2, px1 + 3, cy + 2, 0, p);
            keep_run(build, hall, px1, cy - 3, px1 + 4, cy + 3, 0);
        }
        # Galleries round the pool over its shores, along both side walls
        # and across the far end (climbed to by a stair along the south
        # wall, or by the lift through a gap in the far end's floor).
        gx0 = 7 + p if self.form == 0 else 7;
        build.solid(gx0, 1, p - 1, long - 1, 4, p);
        build.solid(7, wide - 4, p - 1, long - 1, wide - 1, p);
        build.solid(px1, 4, p - 1, long - 1, wide - 4, p);
        if self.form == 0 {
            stair(build, 7, 1, 0, 0, p, 3);
            keep_run(build, hall, gx0 - 3, 1, gx0 + 1, 4, p);
        } else {
            build.widen(hall, px1, cy - 2, p - 1, px1 + 3, cy + 2, p);
            keep_run(build, hall, px1 - 1, cy - 3, px1 + 4, cy + 3, p);
        }
        keep_run(build, hall, 10, wide - 5, 13, wide - 4, p);
        build.foe(float(long) - 3.5, float(wide) - 2.5, p, E3M5_FOES.pick(dice, self.danger), 180.0);
        # The pillar's edges kept open, to drop back into the water.
        keep_run(build, hall, cx - 2, cy - 2, cx + 2, cy + 2, p);
        fields: dict[str, str] = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(cx), float(cy), p);
        taken = build.cue([fields], "key");
        taken +>:Fires:+> build.summon(1, 1, -deep - 2, E3M5_FOES.pick(dice, self.danger, True), 3.5, 2.5, 0, 0.0);
        if dice.chance(0.6) {
            taken +>:Fires:+> build.summon(1, wide - 5, -deep - 2, E3M5_FOES.pick(dice, self.danger), 3.5, float(wide) - 2.5, 0, 0.0);
        }
        # A secret alcove under the water off the pool's south side.
        ax = 10 + dice.below(max(1, px1 - 14));
        build.room(ax, 2, -deep, ax + 2, 4, -deep + 3);
        for z in range(-deep, -deep + 3) {
            for y in range(2, 4) {
                for x in range(ax, ax + 2) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        build.secret(float(ax), 2.0, float(-deep), float(ax + 2), 4.0, float(-deep + 3));
        build.supply(float(ax) + 1.0, 3.0, -deep, "item_artifact_super_damage");
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) - 1.5 + float(index) * 2.0, float(cy) + 0.5, p + 3 + index, "monster_wizard", 180.0);
        }
        build.foe(float(long) - 3.5, 2.5, 0, E3M5_FOES.pick(dice, self.danger), 180.0, patrol=[[float(long) - 3.5, 2.5], [float(long) - 3.5, float(wide) - 2.5]]);
        build.supply(2.5, float(wide) - 2.5, 0, "item_health");
    }
}

"""A tower of wind: a deep pool at its foot, ledges up its two long walls
by turns, each higher than the last, the wind throwing a body from each
across to the next; the way on from the highest (barred until a button is
shot) and from the one under it."""
node WindTower(Prefab) {
    has stages: int = 3,
        step_up: int = 8,
        ledge: int = 5,
        deep: int = 9,
        tall: int = 34,
        bars: bool = False;

    """Ledge `k`'s cells along x (from 1, the first): [x0, x1]."""
    def ledge_span(k: int) -> list[int] {
        if k == 1 {
            return [1, self.long - 1];
        }
        if k == 2 {
            return [6, self.long - 1];
        }
        if k == 3 {
            return [1, self.long - 6];
        }
        return [10, self.long - 1];
    }

    """Where the wind on ledge `k` (0 the floor) stands along x."""
    def pad_x(k: int) -> float {
        if k == 0 {
            return 2.5;
        }
        if k == 1 {
            return float(self.long) - 3.5;
        }
        if k == 2 {
            return 7.5;
        }
        return float(self.long) - 7.5;
    }

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind tower";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.stages = dice.between(3, 4);
        self.step_up = dice.between(8, 9);
        self.long = dice.between(19, 20) if self.stages == 4 else dice.between(16, 18);
        self.wide = 14 + 2 * dice.below(2);
        self.ledge = (self.wide - 4) // 2;
        self.deep = dice.between(8, 10);
        self.tall = self.stages * self.step_up + dice.between(13, 17);
        self.bars = dice.chance(0.5);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        n = self.stages;
        e = self.ledge;
        top = self.ledge_span(n);
        below = self.ledge_span(n - 1);
        north = float(self.wide - 1 - e // 2) - 0.5;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        ways: list[Port] = [];
        if n % 2 == 1 {
            ways.append(Port(face=3, along=float(top[0] + top[1]) * 0.5, floor=n * self.step_up));
            ways.append(Port(face=0, along=north, floor=(n - 1) * self.step_up));
            ways.append(Port(face=1, along=float(below[0] + below[1]) * 0.5 + 2.0, floor=(n - 1) * self.step_up));
        } else {
            ways.append(Port(face=0, along=north, floor=n * self.step_up));
            ways.append(Port(face=1, along=float(top[0] + top[1]) * 0.5, floor=n * self.step_up));
            ways.append(Port(face=3, along=float(below[0] + below[1]) * 0.5, floor=(n - 1) * self.step_up));
        }
        self.leaves = ways;
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        h = self.step_up;
        e = self.ledge;
        n = self.stages;
        yb = 1 + e;
        yn = wide - 1 - e;
        tower = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.pool(5, 1, -self.deep, long - 1, wide - 1, 0, 2);
        build.doorway(tower, self.enter);
        for k in range(1, n + 1) {
            span = self.ledge_span(k);
            z = k * h;
            build.level(tower, z);
            if k % 2 == 1 {
                build.solid(span[0], 1, z - 1, span[1], yb, z);
            } else {
                build.solid(span[0], yn, z - 1, span[1], wide - 1, z);
            }
        }
        # The wind from the floor and from each ledge across to the next,
        # each throw's far edge kept clear.
        for k in range(n) {
            x = self.pad_x(k);
            cell = int(x);
            z = k * h;
            if k == 0 {
                # From the floor onto the first ledge, along the south wall.
                build.jump_pad(x, float(yb) + 3.0, 0, x, float(yb) - 1.0, h);
                keep_run(build, tower, cell - 1, yb - 1, cell + 2, yb, h);
                build.touch(float(cell - 1), float(yb + 4), 0.0, float(cell + 2), float(yb + 6), 6.0, False, "Jump up here....");
            } elif k % 2 == 1 {
                # From a south ledge across onto the north one over it.
                build.jump_pad(x, float(yb) - 1.0, z, x, float(yn) + 1.0, z + h);
                keep_run(build, tower, cell - 1, yb - 1, cell + 2, yb, z);
                keep_run(build, tower, cell - 1, yn, cell + 2, yn + 1, z + h);
            } else {
                build.jump_pad(x, float(yn) + 1.0, z, x, float(yb) - 1.0, z + h);
                keep_run(build, tower, cell - 1, yn, cell + 2, yn + 1, z);
                keep_run(build, tower, cell - 1, yb - 1, cell + 2, yb, z + h);
            }
        }
        # Drops off each ledge's far end into the water.
        for k in range(1, n + 1) {
            span = self.ledge_span(k);
            z = k * h;
            if k % 2 == 1 {
                keep_run(build, tower, span[1] - 4, yb - 1, span[1] - 2, yb, z);
            } else {
                keep_run(build, tower, span[0] + 2, yn, span[0] + 4, yn + 1, z);
            }
        }
        # The way on from the top ledge barred until the button high on
        # the end wall is shot.
        shot = build.cue([build.button(float(long - 1), float(wide // 2), float(n * h) - 3.0, 2, "", True)], "button");
        for port in self.taken {
            if self.bars and port.floor == n * h {
                sealed_way(build, tower, long, wide, port, shot, "These bars are opened elsewhere");
            } else {
                build.doorway(tower, port);
            }
        }
        if self.bars {
            build.touch(1.0, 1.0, 0.0, 5.0, float(wide - 1), 6.0, True, "Shoot the button high on the far wall");
        }
        # Scrags in the air of the tower, and on each ledge a guard woken
        # as the wind sets a body down there.
        for index in range(dice.between(2, 3)) {
            build.foe(float(long // 2) + 0.5, float(wide // 2) + 0.5, h * (index + 1) - 2, "monster_wizard", float(index * 90), patrol=[[6.5, float(wide // 2) + 0.5], [float(long) - 3.5, float(wide // 2) + 0.5]]);
        }
        for k in range(1, n + 1) {
            z = k * h;
            span = self.ledge_span(k);
            land = self.pad_x(k - 1);
            y0 = 1 if k % 2 == 1 else yn;
            y1 = yb if k % 2 == 1 else wide - 1;
            landed = build.touch(land - 1.5, float(y0), float(z), land + 1.5, float(y1), float(z + 6));
            guard = build.waiting();
            landed +>:Fires:+> guard;
            gx = float(span[0]) + 2.5 if land > float(long // 2) else float(span[1]) - 2.5;
            build.foe(gx, float(y0 + y1) * 0.5, z, E3M5_FOES.pick(dice, self.danger, k == n), 0.0 if land > float(long // 2) else 180.0, waits=guard);
        }
        build.supply(2.5, float(wide) - 2.5, 0, "item_shells");
        top = self.ledge_span(n);
        build.supply(float(top[0]) + 1.5, float(yb) - 1.5 if n % 2 == 1 else float(yn) + 1.5, n * h, "item_health");
    }
}

"""The end: a hall, a door, a balcony over a deep shaft and the slipgate at
its foot; doors at the foot burst open."""
node WindExit(Prefab) {
    has key: str = "",
        deep: int = 14,
        form: int = 0,
        secret_in: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.form = dice.below(2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(14, 18);
        self.secret_in = dice.chance(0.5);
        self.low = -self.deep - 9;
        self.high = 21;
        self.enter = Port(face=2, along=float((self.wide - 5) // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        d = self.deep;
        side = wide - 5;
        mid = side // 2;
        wall = 9;
        hall = build.room(1, 1, 0, wall, side, 10, variant=dice.below(3));
        shaft = build.room(wall + 1, 1, -d, long - 1, side, 20, variant=dice.below(3));
        build.level(shaft, 0);
        build.doorway(hall, self.enter);
        build.widen(shaft, wall, mid - 2, 0, wall + 1, mid + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(mid - 2), 0.0, float(wall + 1), float(mid + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The balcony, a slab over the shaft's foot.
        rim = wall + 6;
        build.solid(wall + 1, 1, -1, rim, side, 0);
        if self.form == 0 {
            # A plunge into a pool at the foot, a strip of floor past it.
            build.pool(rim, 1, -d - min(8, side - 5), rim + 8, side - 4, -d, 2);
            keep_run(build, shaft, rim - 1, 2, rim, side - 1, 0);
        } else {
            # Ledges stepping down the shaft's south wall.
            one = -(d // 3);
            two = -(2 * d // 3);
            build.solid(rim, 1, -d, rim + 4, 6, one);
            build.solid(rim + 4, 1, -d, rim + 8, 6, two);
            keep_run(build, shaft, rim - 1, 1, rim, 6, 0);
            keep_run(build, shaft, rim + 3, 1, rim + 4, 6, one);
            keep_run(build, shaft, rim + 7, 1, rim + 8, 6, two);
        }
        # The slipgate on a dais at the shaft's far end.
        build.solid(long - 6, 2, -d, long - 1, side - 1, -d + 1);
        build.way_out(float(long) - 3.5, float(mid), -d + 1);
        # Coming out onto the balcony, the doors at the foot burst open.
        out = build.touch(float(wall + 1), 1.0, 0.0, float(wall + 3), float(side), 6.0);
        burst = build.delay(1.5);
        out +>:Fires:+> burst;
        loose = build.waiting();
        burst +>:Fires:+> loose;
        for index in range(dice.between(1, 2)) {
            at = long - 10 - index * 5;
            build.room(at, side + 1, -d, at + 3, side + 4, -d + 7);
            build.widen(shaft, at, side, -d, at + 3, side + 1, -d + 6);
            burst +>:Fires:+> bursting(build, float(at), float(side), float(-d), float(at + 3), float(side + 1), float(-d + 6));
            build.foe(float(at) + 1.5, float(side) + 2.5, -d, E3M5_FOES.pick(dice, self.danger, index == 0), 270.0, waits=loose);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(long) - 8.5, 3.5 + float(index) * 4.0, -d + 6, "monster_wizard", 180.0, waits=loose);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E3M5_FOES.pick(dice, self.danger), 180.0);
        }
        if self.secret_in {
            build.room(3, side + 1, 0, 6, side + 4, 4);
            build.secret_door(3.0, float(side), 0.0, 6.0, float(side + 1), 4.0, 1);
            build.secret(3.0, float(side + 1), 0.0, 6.0, float(side + 4), 3.0);
            build.supply(4.5, float(side) + 2.5, 0, "item_armor2");
        }
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m5's stretches: [name, role]."""
glob E3M5_STRETCHES: list[list[str]] = [
         ["foot", "start"],
         ["flooded", "flow"],
         ["chamber", "hub"],
         ["chamber", "flow"],
         ["tower", "flow"],
         ["tower", "hub"],
         ["spikes", "flow"],
         ["spikes", "hub"],
         ["pillar", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m5's stretches by its name."""
def make_e3m5(name: str, key: str) -> Prefab {
    if name == "foot" {
        return TubeFoot();
    }
    if name == "flooded" {
        return FloodedTube();
    }
    if name == "chamber" {
        return WindChamber();
    }
    if name == "tower" {
        return WindTower();
    }
    if name == "spikes" {
        return SpikeGallery();
    }
    if name == "pillar" {
        return QuadPillar(key=key if key else "key_silver");
    }
    return WindExit(key=key);
}
