"""Prefabs drawn from e1m8, Ziggurat Vertigo: narrow ways over a void (a
fall lands in water far below, a lift there rising back), a ziggurat
climbed tier by tier in a galleried hall (a chamber hollowed in it), bars
opened by buttons elsewhere, a shaft of great fast lifts, a key on a small
ziggurat out in the void. Raised in e1m8's own palette; its ogres walk
their rounds as e1m8's do. Each stretch takes its shape from its dice as
well as its sizes.

- `VoidLanding`: the start. A platform at the edge of a deep void, a
  narrow way across it (jogging, or blocks a leap apart) to the far
  platform; the far ways on behind bars opened by a button out on a spur
  over the void ("These bars are opened elsewhere"); a niche low in the
  void's wall a secret; a teleporter back from the far platform.
- `Ziggurat`: the hub: a hall, galleries round its walls, a stepped
  ziggurat in it with a chamber hollowed out of it (behind a door that
  opens when shot, a teleporter in it up to the summit); a bridge from the
  summit to the gallery and the way on high; the floor's ways on behind
  bars opened by the button on the summit; ogres walking the galleries.
- `VertigoWalk`: two narrow ways across a void, one over the other, the
  lower stepping up to a far ledge, the upper from a ledge reached by a
  stair to a high ledge; a cell's gap here and there to leap; the far
  ledge's ways on behind bars opened from the high ledge.
- `PlatShaft`: a deep shaft: from a ledge at its head a drop into a pool
  at its foot, the great fast lift back up (e1m8's lifts), a balcony
  round it halfway up a second lift; the way out at the foot behind bars
  opened from the balcony; a teleporter and a secret at the foot.
- `SilverAltar`: the key room: a small ziggurat out in a void reached by a
  narrow way, the key on its top, a bridge from it to a gallery along the
  far wall; taking the key opens the closets onto the gallery and sends
  one in behind; a teleporter back to the near platform.
- `VoidExit`: the end: a narrow way to a platform, a wall across it with a
  door (a key's, as a gate, or bars opened by a shot button), the way out
  beyond."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, lift }
import from .e1m2_parts { slab, keep_box, keep_ring, arcade, stash, closets, key_cue, flood }
import from .e1m2 { port_gate }

glob E1M8: str = "q1:e1m8";

"""e1m8's foes: ogres on the platforms, scrags in the void."""
def e1m8_foe(dice: Stream, danger: float, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_knight", "monster_knight"], ["monster_ogre", "monster_shambler"], danger * 0.3));
}

"""A void: the room's floor a pit `depth` lifts deep over the box x0..x1,
y0..y1, water at its foot with steps up out of it along its near side,
and at the steps' head a lift rising to lift 0 at the pit's near edge,
where the way began. (`lift_x`, `lift_y` are kept for the callers; the
lift always stands at the steps' head.)"""
def void_pit(build: Raising, room: Space, x0: int, x1: int, y0: int, y1: int, depth: int, lift_x: int, lift_y: int) {
    build.widen(room, x0, y0, -depth, x1, y1, 0);
    build.pool(x0, y0, -depth, x1, y1, -depth + 4, 2);
    at_y = y0 + 4;
    build.solid(x0, at_y, -depth, x0 + 2, at_y + 3, -depth + 4);
    build.put_box({"classname": "func_plat", "height": str((depth - 4) * 16), "speed": "220"}, float(x0), float(at_y), -0.5, float(x0 + 2), float(at_y + 3), 0.0, kit_of(build.district).step);
    for x in range(x0 - 1, x0 + 3) {
        for y in range(at_y - 1, at_y + 4) {
            build.keep(room, x, y, 0);
        }
    }
}

"""Keep every cell of a narrow way clear of railings."""
def bare(build: Raising, room: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(room, x, y, z);
        }
    }
}

"""A narrow way across a void from x0 to x1 two cells wide on lift `z`,
starting along the line y, jogging across now and then, blocks a cell's
leap apart where `leaps`. Answers the line it ends on."""
def narrow_way(build: Raising, dice: Stream, x0: int, x1: int, y: int, z: int, low_y: int, high_y: int, leaps: bool) -> int {
    x = x0;
    while x < x1 {
        run = min(x1 - x, dice.between(3, 5));
        build.solid(x, y, z - 1, x + run, y + 2, z);
        x += run;
        if leaps and x < x1 - 2 {
            x += 1;
        }
        shifted = max(low_y, min(high_y, y + dice.between(-3, 3)));
        if shifted != y and x < x1 - 1 {
            build.solid(x, min(y, shifted), z - 1, x + 2, max(y, shifted) + 2, z);
            y = shifted;
            x += 2;
        }
    }
    return y;
}

"""The start: a platform at a void's edge, a narrow way across it, the far
ways on behind bars."""
node VoidLanding(Prefab) {
    has depth: int = 20,
        lane: int = 8,
        tall: int = 14,
        leaps: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void landing";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.depth = dice.between(18, 22);
        self.tall = dice.between(13, 16);
        self.lane = dice.between(6, self.wide - 7);
        self.leaps = dice.chance(0.5);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        far = self.long - 7;
        void_pit(build, room, 7, far, 1, self.wide - 1, self.depth, 7, 1);
        # The way across: two cells wide, jogging, or blocks a leap apart.
        narrow_way(build, dice, 7, far, self.lane, 0, 3, self.wide - 5, self.leaps);
        # A spur out over the void to a post with the button on it.
        half = self.long // 2;
        spur_y = 2 if self.lane > self.wide // 2 else self.wide - 4;
        build.solid(7, spur_y, -1, 11, spur_y + 2, 0);
        build.solid(10, spur_y, 0, 11, spur_y + 1, 3);
        press = build.push(10.0, float(spur_y) + 1.5, 1.2, 2);
        bare(build, room, 6, 1, self.long - 6, self.wide - 1, 0);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
            press +>:Fires:+> port_gate(build, self.long, self.wide, port);
        }
        build.touch(float(far), 1.0, 0.0, float(far + 2), float(self.wide - 1), 6.0, True, "These bars are opened elsewhere");
        # A niche low in the void's far wall: a secret.
        build.room(far, 3, -self.depth + 3, far + 2, 6, -self.depth + 7);
        build.secret(float(far), 3.0, float(-self.depth + 3), float(far + 2), 6.0, float(-self.depth + 6));
        build.supply(float(far) + 1.0, 4.5, -self.depth + 3, "item_armor2");
        # A gallery high along the far wall over the far platform, a lift up
        # to it.
        build.level(room, 8);
        slab(build, self.long - 4, 1, self.long - 1, self.wide - 1, 8);
        lift(build, self.long - 7, self.wide - 8, self.long - 4, self.wide - 5, 0, 8);
        keep_box(build, room, self.long - 8, self.wide - 9, self.long - 3, self.wide - 4, 8);
        keep_box(build, room, self.long - 8, self.wide - 9, self.long - 4, self.wide - 4, 0);
        build.foe(float(self.long) - 2.5, 2.5, 8, "monster_knight", 90.0, patrol=[[float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 5.5]]);
        # A teleporter on the far platform back to the near one.
        build.teleporter(float(self.long) - 5.5, 3.5, 0, 3.5, 3.5, 0, 0.0);
        build.start(2.5, float(self.wide // 2) + 0.5, 0, 0.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
        for index in range(dice.between(1, 2)) {
            build.foe(float(half) + 0.5, float(self.wide // 2) + 0.5, 6, e1m8_foe(dice, self.danger, True), 180.0);
        }
        # Ogres walk the far platform; the near one's knight walks its edge.
        build.foe(float(self.long) - 5.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(self.long) - 5.5, 2.5], [float(self.long) - 5.5, float(self.wide) - 2.5]]);
        build.foe(3.5, 2.5, 0, "monster_knight", 90.0, patrol=[[5.5, 2.5], [5.5, float(self.wide) - 2.5]]);
        midway = build.touch(float(half - 2), 1.0, 0.0, float(half + 2), float(self.wide - 1), 6.0);
        guard = build.waiting();
        midway +>:Fires:+> guard;
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 0, e1m8_foe(dice, self.danger), 180.0, waits=guard);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""The hub: a galleried hall and a stepped ziggurat with a chamber in it; a
bridge from its summit to the gallery; the floor's ways on behind bars."""
node Ziggurat(Prefab) {
    has tiers: int = 6,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ziggurat";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.tiers = dice.between(5, 6);
        self.long = 6 + 4 * self.tiers + 10;
        self.wide = 6 + 4 * self.tiers + 6;
        self.tall = 2 * self.tiers + dice.between(12, 14);
        self.low = -9;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=2 * self.tiers), Port(face=1, along=float(self.long // 2 - 4), floor=0), Port(face=3, along=float(self.long // 2 - 4), floor=0), Port(face=1, along=float(self.long - 5), floor=2 * self.tiers)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        cx = self.long // 2 - 2;
        cy = self.wide // 2;
        biggest = 2 * self.tiers + 1;
        summit = 2 * self.tiers;
        for tier in range(self.tiers) {
            radius = biggest - 2 * tier;
            top = 2 * (tier + 1);
            build.solid(cx - radius, cy - radius, 0, cx + radius, cy + radius, top);
            build.level(hall, top);
            # A step a lift below the tier's top against its west and east
            # faces, on the tier below.
            build.solid(cx - radius - 1, cy - 1, 0, cx - radius, cy + 1, top - 1);
            build.solid(cx + radius, cy - 1, 0, cx + radius + 1, cy + 1, top - 1);
            for (x, y) in [(cx - radius - 1, cy - 1), (cx - radius - 1, cy), (cx + radius, cy - 1), (cx + radius, cy)] {
                build.keep(hall, x, y, top - 1);
                build.keep(hall, x, y, top);
            }
        }
        # The chamber hollowed out of the ziggurat, reached by a passage from
        # the north floor behind a door that opens when shot; a teleporter in
        # it up to the summit; a secret.
        build.room(cx - 3, cy - 3, 0, cx + 3, cy + 3, summit - 3);
        build.room(cx - 1, cy + 3, 0, cx + 2, cy + biggest, 5);
        build.secret_door(float(cx - 1), float(cy + biggest - 1), 0.0, float(cx + 2), float(cy + biggest), 5.0, 3);
        build.secret(float(cx - 3), float(cy - 3), 0.0, float(cx + 3), float(cy + 3), 3.0);
        build.teleporter(float(cx) + 0.5, float(cy) + 0.5, 0, float(cx) - 1.5, float(cy) + 0.5, summit, 0.0);
        build.supply(float(cx) - 2.0, float(cy) - 2.0, 0, "item_artifact_super_damage");
        # The galleries round the walls at the summit's height, on pillars;
        # the bridge from the summit east to them and the way on high.
        g = summit;
        slab(build, 1, 1, self.long - 1, 5, g);
        slab(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g);
        slab(build, self.long - 5, 5, self.long - 1, self.wide - 5, g);
        slab(build, 1, 5, 5, self.wide - 5, g);
        arcade(build, 4, 3, self.long - 3, 0, g - 1, 5, False);
        arcade(build, self.wide - 5, 3, cx - 3, 0, g - 1, 5, False);
        arcade(build, self.wide - 5, cx + 4, self.long - 3, 0, g - 1, 5, False);
        last = biggest - 2 * (self.tiers - 1);
        build.solid(cx + last, cy - 2, summit - 1, self.long - 5, cy + 2, summit);
        keep_box(build, hall, cx + last - 1, cy - 2, cx + last + 1, cy + 2, summit);
        # The floor's ways on are barred until the button on the summit is
        # pressed.
        build.solid(cx - 1, cy - 2, summit, cx, cy - 1, summit + 3);
        press = build.push(float(cx), float(cy) - 1.5, float(summit) + 1.2, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(2.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "These bars are opened elsewhere");
        # Scrags about the summit wake as the first tier is climbed; ogres
        # walk the galleries.
        climbing = build.touch(float(cx - biggest - 1), float(cy - 1), 0.0, float(cx - biggest + 1), float(cy + 1), 6.0);
        scrags = build.waiting();
        climbing +>:Fires:+> scrags;
        climbing +>:Fires:+> build.summon(2, 2, -8, e1m8_foe(dice, self.danger), 3.0, float(cy) + 4.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, summit + 4 + index * 2, e1m8_foe(dice, self.danger, True), float(index * 120), waits=scrags);
        }
        build.foe(float(cx) + 1.5, float(cy) + 1.5, summit, e1m8_foe(dice, self.danger), 180.0);
        build.foe(4.5, 3.0, g, "monster_ogre", 0.0, patrol=[[4.5, 3.0], [float(self.long) - 3.0, 3.0]]);
        build.foe(3.0, 6.5, g, "monster_knight", 90.0, patrol=[[3.0, 6.5], [3.0, float(self.wide) - 6.5]]);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, g, "monster_knight", 180.0, patrol=[[float(self.long) - 3.0, float(self.wide) - 3.0], [4.5, float(self.wide) - 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(3.0, 7.5 + float(index) * float(self.wide - 15), 0, e1m8_foe(dice, self.danger), 0.0);
        }
        build.supply(float(cx) - 1.5, float(cy) + 1.5, summit, "item_health");
        build.supply(float(self.long) - 2.5, float(cy) + 3.5, 0, "item_rockets");
        build.supply(3.0, 3.0, g, "item_health");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "item_health");
        build.supply(2.5, float(cy) - 3.5, 0, "item_armor1");
    }
}

"""Two narrow ways across a void, one over the other; the far ledge's ways
on behind bars opened from the high ledge."""
node VertigoWalk(Prefab) {
    has depth: int = 18,
        tall: int = 18,
        upper: int = 8,
        gaps_low: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vertigo walk";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.depth = dice.between(16, 20);
        self.upper = dice.between(8, 9);
        self.tall = self.upper + dice.between(10, 12);
        self.gaps_low = dice.chance(0.5);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=4.0, floor=2), Port(face=0, along=float(self.wide - 11), floor=2), Port(face=0, along=float(self.wide - 3), floor=self.upper)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.upper);
        void_pit(build, room, 4, self.long - 4, 1, self.wide - 1, self.depth, 4, self.wide - 4);
        # The far ledge two lifts up, the high ledge along the far wall's
        # north end over it, a stair between them.
        build.solid(self.long - 4, 1, 0, self.long - 1, self.wide - 1, 2);
        slab(build, self.long - 4, self.wide - 6, self.long - 1, self.wide - 1, self.upper);
        lift(build, self.long - 4, self.wide - 9, self.long - 1, self.wide - 6, 2, self.upper);
        keep_box(build, room, self.long - 5, self.wide - 10, self.long - 1, self.wide - 5, 2);
        keep_box(build, room, self.long - 4, self.wide - 7, self.long - 1, self.wide - 5, self.upper);
        # The lower way: from the near edge to the far ledge, a lift up
        # halfway (two cells wide, wandering, gaps to leap or not).
        x = 4;
        y = self.wide // 2 - 1;
        rise_by = 0;
        while x < self.long - 4 {
            run = min(self.long - 4 - x, dice.between(3, 5));
            build.solid(x, y, rise_by - 1, x + run, y + 2, rise_by);
            x += run;
            if x >= self.long // 2 and rise_by < 2 {
                rise_by += 1;
            }
            if self.gaps_low and x < self.long - 6 and dice.chance(0.35) {
                x += 1;
            }
            shifted = max(3, min(self.wide - 9, y + dice.between(-3, 3)));
            if shifted != y and x < self.long - 4 {
                build.solid(x, min(y, shifted), rise_by - 1, x + 2, max(y, shifted) + 2, rise_by);
                y = shifted;
                x += 2;
            }
        }
        # The upper way: from a ledge over the near edge (a stair up to it)
        # along the north side to the high ledge, over the lower way's end.
        slab(build, 1, self.wide - 3, 4, self.wide - 1, self.upper);
        lift(build, 1, self.wide - 6, 4, self.wide - 3, 0, self.upper);
        keep_box(build, room, 1, self.wide - 7, 5, self.wide - 1, self.upper);
        keep_box(build, room, 1, self.wide - 7, 5, self.wide - 2, 0);
        narrow_way(build, dice, 4, self.long - 4, self.wide - 4, self.upper, self.wide - 6, self.wide - 3, not self.gaps_low);
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 0);
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 1);
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 2);
        bare(build, room, 4, self.wide - 7, self.long - 4, self.wide - 1, self.upper);
        # The far ledge's ways on are barred until the button on the high
        # ledge is pressed.
        press = build.push(float(self.long - 1), float(self.wide) - 3.5, float(self.upper) + 1.2, 2);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
            if port.floor < self.upper {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(float(self.long - 4), 1.0, 2.0, float(self.long - 2), float(self.wide - 7), 8.0, True, "These bars are opened from above");
        build.teleporter(float(self.long) - 2.5, 2.5, 2, 2.5, 3.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 7) + 0.5, float(self.wide // 2) - 2.5, 5, e1m8_foe(dice, self.danger, True), 180.0);
        }
        reached = build.touch(float(self.long - 6), 1.0, 0.0, float(self.long - 4), float(self.wide - 7), 8.0);
        guards = build.waiting();
        reached +>:Fires:+> guards;
        build.foe(float(self.long) - 2.5, float(self.wide // 2) - 2.5, 2, e1m8_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(self.long) - 2.5, float(self.wide) - 3.0, self.upper, "monster_ogre", 270.0, patrol=[[float(self.long) - 2.5, float(self.wide) - 3.0], [float(self.long) - 2.5, float(self.wide) - 5.0]]);
        build.foe(2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 8.5]]);
        build.supply(float(self.long) - 2.5, 2.5, 2, "item_health");
        build.supply(2.5, float(self.wide) - 2.0, self.upper, "item_health");
    }
}

"""A deep shaft: a drop from its head into a pool at its foot, the great
fast lift back up, a balcony halfway up a second lift; the way out at the
foot behind bars opened from the balcony."""
node PlatShaft(Prefab) {
    has depth: int = 26,
        tall: int = 10,
        north: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plat shaft";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.depth = dice.between(24, 28);
        self.tall = dice.between(10, 12);
        self.north = dice.chance(0.5);
        self.low = -self.depth - 9;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid), floor=-self.depth), Port(face=1, along=float(self.long // 2), floor=-self.depth), Port(face=0, along=float(mid), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.depth;
        mid = self.wide // 2;
        shaft = build.room(1, 1, -d, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        half = -d // 2;
        build.level(shaft, half);
        build.level(shaft, 0);
        # The head: a ledge of rock at each end, a narrow way across the
        # middle between them, unrailed.
        build.solid(1, 1, -d, 5, self.wide - 1, 0);
        build.solid(self.long - 5, 1, -d, self.long - 1, self.wide - 1, 0);
        slab(build, 5, mid - 1, self.long - 5, mid + 2, 0);
        keep_box(build, shaft, 4, mid - 2, self.long - 4, mid + 3, 0);
        # The foot: a floor round a pool under the narrow way (dropped into
        # from it), steps up out of the pool on its near side.
        build.pool(7, 4, -d - 6, self.long - 9, self.wide - 4, -d, 2);
        # The great lift from the foot's south side to the head beside the
        # near ledge.
        build.put_box({"classname": "func_plat", "height": str(d * 16), "speed": "500"}, 5.0, 1.0, -0.5, 7.0, 4.0, 0.0, kit_of(build.district).step);
        keep_box(build, shaft, 4, 1, 8, 5, 0);
        keep_box(build, shaft, 4, 1, 8, 5, -d);
        # A balcony halfway up along the north wall on pillars, a lift up to
        # it from the foot.
        slab(build, 5, self.wide - 4, self.long - 5, self.wide - 1, half);
        arcade(build, self.wide - 4, 8, self.long - 9, -d, half - 1, 4, False);
        slab(build, 8, 1, self.long - 5, 4, half);
        slab(build, self.long - 11, 4, self.long - 8, self.wide - 4, half);
        keep_box(build, shaft, 8, 3, self.long - 11, 5, half);
        lift(build, self.long - 8, self.wide - 8, self.long - 5, self.wide - 4, -d, half);
        keep_box(build, shaft, self.long - 9, self.wide - 9, self.long - 4, self.wide - 3, half);
        keep_box(build, shaft, self.long - 9, self.wide - 9, self.long - 4, self.wide - 4, -d);
        # The way out at the foot is barred until the button on the balcony
        # is pressed; the head's way on is open.
        press = build.push(float(self.long - 5), float(self.wide) - 2.5, float(half) + 1.2, 2);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            if port.floor < 0 and port.face == 0 {
                # Through the far ledge's rock at the foot.
                build.widen(shaft, self.long - 5, mid - 2, -d, self.long - 1, mid + 2, -d + 8);
            }
            build.doorway(shaft, port);
            if port.floor < 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(5.0, 1.0, float(-d), 7.0, float(self.wide - 1), float(-d + 6), True, "These bars are opened from above");
        # A teleporter at the foot back up to the head; a niche in the near
        # rock at the foot a secret.
        build.teleporter(float(self.long // 2) + 0.5, 2.5, -d, 2.5, float(mid) + 0.5, 0, 0.0);
        build.room(1, self.wide - 4, -d, 5, self.wide - 2, -d + 4);
        build.secret(1.0, float(self.wide - 4), float(-d), 5.0, float(self.wide - 2), float(-d + 3));
        build.supply(2.0, float(self.wide) - 3.0, -d, "item_armor1");
        # What waits at the foot wakes as a body lands in the pool.
        landed = build.touch(7.0, 4.0, float(-d - 6), float(self.long - 9), float(self.wide - 4), float(-d + 2));
        below = build.waiting();
        landed +>:Fires:+> below;
        closets(build, landed, 5, [8, 12], -d, 2, [e1m8_foe(dice, self.danger), "monster_knight"]);
        for index in range(2) {
            build.foe(float(self.long) - 7.5, 2.5 + float(index) * 2.0, -d, e1m8_foe(dice, self.danger), 180.0, waits=below);
        }
        build.foe(7.5, float(self.wide) - 2.5, half, "monster_ogre", 0.0, patrol=[[7.5, float(self.wide) - 2.5], [float(self.long) - 9.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 7.5, 2.5, 0, "monster_knight", 0.0, patrol=[[float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, float(mid) + 0.5, half + index * 6, "monster_wizard", 90.0);
        }
        build.supply(float(self.long) - 3.0, 2.5, 0, "item_health");
        build.supply(float(self.long // 2) + 2.5, float(self.wide) - 2.5, -d, "item_health");
    }
}

"""The key room: a small ziggurat out in a void, the key on its top, a bridge
to a gallery along the far wall; taking the key opens the closets."""
node SilverAltar(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        depth: int = 18,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver altar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(24, 28);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.depth = dice.between(16, 20);
        self.tall = dice.between(18, 20);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        middle = self.hall_wide // 2;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, 6);
        void_pit(build, room, 5, self.long - 2, 1, side, self.depth, 5, 1);
        # The small ziggurat: three tiers on a pillar out of the void.
        cx = (5 + self.long - 2) // 2 + 1;
        build.solid(cx - 4, middle - 4, -self.depth, cx + 4, middle + 4, 0);
        for tier in range(3) {
            radius = 3 - tier;
            build.solid(cx - radius, middle - radius, 0, cx + radius, middle + radius, 2 * (tier + 1));
        }
        build.solid(5, middle - 1, -1, cx - 4, middle + 1, 0);
        # Steps up the tiers' west face.
        for tier in range(3) {
            radius = 3 - tier;
            build.solid(cx - radius - 1, middle - 1, 0, cx - radius, middle + 1, 2 * tier + 1);
        }
        bare(build, room, 4, middle - 2, cx + 4, middle + 2, 0);
        # The gallery along the far wall at the top's height, a bridge to it.
        slab(build, 5, side - 4, self.long - 2, side, 6);
        slab(build, cx - 1, middle + 1, cx + 2, side - 4, 6);
        keep_box(build, room, cx - 1, middle, cx + 2, middle + 2, 6);
        keep_box(build, room, cx - 1, side - 5, cx + 2, side - 3, 6);
        build.doorway(room, self.enter);
        # The key: taking it opens the closets onto the gallery and sends one
        # in behind onto the near platform.
        taken = key_cue(build, self.key, float(cx) + 0.5, float(middle) - 0.5, 6);
        starts = [x for x in [6, 12, 18] if x + 3 < self.long - 2];
        closets(build, taken, side, starts, 6, 1, [e1m8_foe(dice, self.danger)]);
        taken +>:Fires:+> build.summon(1, 1, -self.depth + 6, e1m8_foe(dice, self.danger), 2.5, float(middle) + 0.5, 0, 0.0);
        # A teleporter on the gallery back to the near platform.
        build.teleporter(float(self.long) - 4.0, float(side) - 2.0, 6, 2.5, float(middle) - 2.5, 0, 0.0);
        build.foe(float(cx) + 2.5, float(middle) + 2.5, 0, e1m8_foe(dice, self.danger), 180.0);
        build.foe(6.5, float(side) - 2.0, 6, "monster_knight", 0.0, patrol=[[6.5, float(side) - 2.0], [float(self.long) - 6.5, float(side) - 2.0]]);
        build.foe(2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[2.5, 2.5], [2.5, float(side) - 2.5]]);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a narrow way to a platform, a wall across it with a door, the
way out beyond."""
node VoidExit(Prefab) {
    has key: str = "",
        depth: int = 18,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(24, 28);
        self.wide = dice.between(14, 16);
        self.depth = dice.between(16, 20);
        self.tall = dice.between(16, 18);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        platform = self.long - 9;
        void_pit(build, room, 4, platform, 1, self.wide - 1, self.depth, 4, 1);
        narrow_way(build, dice, 4, platform, middle - 1, 0, 3, self.wide - 5, False);
        bare(build, room, 3, 1, platform + 1, self.wide - 1, 0);
        # A wall across the platform with the way through it: a key's door,
        # or bars that rise when the button high on the wall is shot.
        wall = platform + 2;
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 8, wall + 1, middle + 2, self.tall);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        } else {
            shot = build.push(float(wall), float(middle) + 3.5, 10.0, 2, True);
            shot +>:Fires:+> build.opened(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0);
            build.touch(float(platform), 1.0, 0.0, float(wall), float(self.wide - 1), 6.0, True, "Shoot the button over the bars");
        }
        build.way_out(float(self.long) - 4.0, float(middle), 0);
        build.doorway(room, self.enter);
        for index in range(dice.between(1, 2)) {
            build.foe(float(platform // 2) + 0.5, float(middle) + 3.5, 5, e1m8_foe(dice, self.danger, True), 180.0);
        }
        build.foe(float(wall) - 1.5, 2.5, 0, "monster_ogre", 90.0, patrol=[[float(wall) - 1.5, 2.5], [float(wall) - 1.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, 0, e1m8_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e1m8's stretches: [name, role]."""
glob E1M8_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["ziggurat", "hub"],
         ["ziggurat", "flow"],
         ["vertigo", "flow"],
         ["shaft", "flow"],
         ["altar", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e1m8's stretches by its name."""
def make_e1m8(name: str, key: str) -> Prefab {
    if name == "landing" {
        return VoidLanding();
    }
    if name == "ziggurat" {
        return Ziggurat();
    }
    if name == "vertigo" {
        return VertigoWalk();
    }
    if name == "shaft" {
        return PlatShaft();
    }
    if name == "altar" {
        return SilverAltar(key=key if key else "key_silver");
    }
    return VoidExit(key=key);
}
