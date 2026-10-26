"""Prefabs drawn from e1m4, the Grisly Grotto: caves of rock and water,
lakes to swim (deep, wells sunk in their floors) or cross over arches of
rock, tunnels swum under the rock with a pocket of air on the way,
galleries of rock over the water, teleporters up to high ledges, a cave
opened by two buttons, the silver key on an island, a climb up the shaft
of a waterfall. Raised in e1m4's own palette. Each stretch takes its shape
from its dice as well as its sizes.

- `GrottoMouth`: the start. A shelf high at the back of a cave (rock at
  its back, an overhang on pillars over the floor at its front), a ramp of
  rock or a lift down, a gallery on from the shelf along one wall to a
  drop, a plunge pool under the shelf's edge or not, a stream across the
  floor under a rock footbridge. Shooting the two buttons (one beside the
  shelf, one high on the far wall) counts to a rock that sinks from the
  mouth of a niche under the shelf: a secret (e1m4's two shot buttons and
  their counter). What is below wakes as the player steps to the edge.
- `FloodedCaverns`: a lake across a cavern, an arch of rock along one wall
  over the water (steps up to it on both shores, a drop from it into the
  lake, a way on from its far end); the lake crossed by rocks, or swum
  under a curtain of rock, or both. Scrags come in by a teleporter as the
  swimmer passes the middle; the far shore's guards wake as he climbs out.
- `TeleportGrotto`: a tall cavern, a deep pool, ledges high on three walls
  reached by teleporters on its floor (sometimes a bridge of rock across
  between two of them), low rocks about the floor; ways on from the
  ledges and the floor (a hub); the ledges' guards wake as the pool is
  neared.
- `SilverGrotto`: the key room. A deep lake, a ledge of rock along the far
  wall over it (a ramp up from the near shore), the key on an island:
  swum to, or high on a pillar of rock reached by a bridge from the ledge.
  Taking it opens the closets in the far wall over the ledge (scrags) and
  sends an ogre in behind.
- `WaterfallClimb`: a tall shaft, a basin at its foot (a niche under its
  water a secret); flights of rock steps switching back up its side, the
  third over the first, or one flight and a long lift (e1m4's great lift);
  ways on at the middle and the top, and the top landing reaching out
  over the basin to drop into it.
- `SecretCave`: a cave walled off at its far end, a gallery along one
  wall, a pool in its middle. Two buttons (one on the wall under the
  gallery, one up on a ledge or out on a rock in the pool) count to the
  wall's opening ("A secret cave has opened..."), scrags sent in as it
  opens, the cave beyond with its ways on and a shelf two lifts up.
- `SunkenTunnel`: two caves joined by a tunnel under the rock, swum from a
  pool in the first (under its floor) to a pool in the second, a pocket of
  air on the way (a secret); a gallery over each cave's pool (a lift up to
  each), sometimes joined through a hole in the rock: a way over without
  the swim.
- `GrottoExit`: the end. A cave, a shelf of rock along one wall with
  ogres on it, a pool crossed by a causeway or boulders before the
  slipgate's ledge; as a gate, a key door across the ledge's mouth. The
  shelf's guards wake as the ledge is neared, and a foe comes in behind."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, boulders, stalactites, apart, lift }
import from .e1m2_parts { slab, keep_box, keep_ring, arcade, closets, key_cue, ramp, flood, low_rocks, sump }

glob E1M4: str = "q1:e1m4";

"""e1m4's foes: knights and ogres on the rock, scrags in the air."""
def e1m4_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_knight", "monster_knight", "monster_ogre"] if heavy else ["monster_knight", "monster_knight"], ["monster_ogre"] if heavy else ["monster_ogre", "monster_wizard"], danger));
}

"""The start: a shelf high at the back of a cave, a way down, a stream
across the floor; two shot buttons open a secret."""
node GrottoMouth(Prefab) {
    has shelf: int = 9,
        top: int = 9,
        tall: int = 20,
        lifted: bool = False,
        plunge: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grotto mouth";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.top = dice.between(8, 10);
        self.shelf = dice.between(8, 9);
        self.wide = dice.between(16, 20);
        self.tall = self.top + dice.between(10, 12);
        self.lifted = dice.chance(0.4);
        self.plunge = dice.chance(0.5);
        edge_x = 1 + self.shelf;
        self.long = edge_x + self.top + dice.between(14, 16);
        self.low = -15;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=self.top);
        self.leaves = [
            Port(face=0, along=float(mid), floor=0),
            Port(face=1, along=float(self.long - 6), floor=0),
            Port(face=1, along=4.0, floor=self.top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        edge_x = 1 + self.shelf;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.top);
        # The shelf: rock at its back, an overhang on pillars at its front.
        build.solid(1, 1, 0, 4, self.wide - 1, self.top);
        slab(build, 4, 1, edge_x, self.wide - 1, self.top);
        arcade(build, edge_x - 1, 6, self.wide - 6, 0, self.top - 1, 5, True);
        # Down from the shelf: a ramp of rock along the side wall, or a lift.
        if self.lifted {
            lift(build, edge_x, 1, edge_x + 3, 4, 0, self.top);
            keep_box(build, cave, edge_x - 1, 1, edge_x + 4, 5, self.top);
            keep_box(build, cave, edge_x, 1, edge_x + 4, 5, 0);
        } else {
            ramp(build, edge_x + self.top - 2, 1, 0, 2, self.top - 1, 3);
            keep_box(build, cave, edge_x - 1, 1, edge_x + 1, 4, self.top);
        }
        # A plunge pool under the shelf's edge, the edge open over it.
        if self.plunge {
            build.pool(edge_x, 6, -8, edge_x + 6, self.wide - 2, 0, 2);
            sump(build, edge_x + 3, 9, -14, -8, 3);
            keep_box(build, cave, edge_x - 1, 7, edge_x, self.wide - 6, self.top);
        }
        # A gallery of rock on from the shelf along the far side wall over
        # the cave, its end open to drop from.
        gallery_end = self.long - 10;
        slab(build, edge_x, self.wide - 5, gallery_end, self.wide - 1, self.top);
        arcade(build, self.wide - 5, edge_x + 4, gallery_end - 1, 0, self.top - 1, 5, False);
        keep_box(build, cave, gallery_end - 1, self.wide - 5, gallery_end, self.wide - 1, self.top);
        # The stream across the floor, a footbridge of rock over it.
        stream_x = edge_x + self.top + 2;
        build.pool(stream_x, 1, -4, stream_x + 3, self.wide - 1, 0, 2, False, True, True);
        build.solid(stream_x, mid - 2, -4, stream_x + 3, mid + 2, 0);
        keep_box(build, cave, stream_x - 1, mid - 2, stream_x + 4, mid + 2, 0);
        # The secret: a niche in the rock under the shelf, its mouth shut by
        # a rock that sinks when both buttons have been shot.
        build.room(2, mid + 2, 0, 4, mid + 5, 4);
        rock = build.train([1.0, 3.0, 4.0], [[4.0, float(mid + 2), 0.0], [4.0, float(mid + 2), -5.0]], 120.0, -1.0, True);
        build.secret(2.0, float(mid + 2), 0.0, 4.0, float(mid + 5), 3.0);
        build.supply(3.0, float(mid) + 3.5, 0, "item_armor2");
        both = build.tally(2, "A secret cave has opened...");
        both +>:Fires:+> rock;
        build.push(2.5, 1.0, float(self.top) + 1.5, 1, True) +>:Fires:+> both;
        build.push(float(self.long - 1), float(mid) + 3.5, float(self.top) + 2.0, 2, True) +>:Fires:+> both;
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        clear = [[0, 0, edge_x + self.top, 5], [0, 0, edge_x + 1, self.wide], [stream_x - 1, 0, stream_x + 4, self.wide], [self.long - 5, mid - 3, self.long, mid + 3], [self.long - 9, self.wide - 5, self.long - 3, self.wide]];
        if self.plunge {
            clear.append([edge_x - 1, 5, edge_x + 7, self.wide]);
        }
        boulders(build, dice, edge_x, 1, self.long - 1, self.wide - 1, 0, dice.between(3, 5), clear);
        low_rocks(build, dice, edge_x, 1, self.long - 1, self.wide - 1, 0, dice.between(4, 6), 2, clear);
        stalactites(build, dice, edge_x + 2, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        build.start(2.5, float(mid) + 0.5, self.top, 0.0);
        build.supply(2.5, float(mid) - 1.5, self.top, "item_shells");
        # What waits below wakes as the player steps to the shelf's edge.
        rim = build.touch(float(edge_x - 2), 5.0, float(self.top), float(edge_x), float(self.wide - 1), float(self.top + 6));
        below = build.waiting();
        rim +>:Fires:+> below;
        for index in range(dice.between(2, 3)) {
            build.foe(float(stream_x) + 4.5 + float(index) * 2.0, 3.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(float(stream_x) + 5.5, float(self.wide) - 3.5, 0, "monster_knight", 0.0, patrol=[[float(stream_x) + 5.5, float(self.wide) - 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        build.foe(float(stream_x) + 1.5, float(mid) + 0.5, 6, e1m4_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(edge_x) + 1.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A lake across a cavern, an arch of rock over it along one wall; swum
(under a curtain of rock down into it) or crossed by rocks."""
node FloodedCaverns(Prefab) {
    has shore: int = 6,
        tall: int = 16,
        mode: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded caverns";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(16, 19);
        self.mode = dice.below(3);
        self.low = -15;
        self.high = self.tall + 1;
        far = float(self.long - 1 - self.shore) + float(self.shore) * 0.5;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2 - 2), floor=0), Port(face=3, along=far, floor=0), Port(face=0, along=float(self.wide - 3), floor=6)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 6);
        lake_x0 = 1 + self.shore;
        lake_x1 = self.long - 1 - self.shore;
        cx = (lake_x0 + lake_x1) // 2;
        build.pool(lake_x0, 1, -8, lake_x1, self.wide - 1, 0, 2);
        sump(build, lake_x0 + 3, 1, -14, -8, 3);
        # Steps up out of it onto the far shore too.
        stair(build, lake_x1 - 8, 1, -8, 0, 8, 2);
        # Rocks across the lake, two cells apart, zigzagging about the middle
        # (unless the curtain alone stands in the water).
        x = lake_x0 + 2;
        index = 0;
        while x + 3 <= lake_x1 - 2 and self.mode != 1 {
            y = middle - 1 + (dice.between(-3, 3) if index > 0 else 0);
            y = max(4, min(self.wide - 8, y));
            build.solid(x, y, -8, x + 3, y + 3, 0);
            keep_ring(build, cave, x, y, x + 3, y + 3, 0);
            x += 5;
            index += 1;
        }
        # The arch: a shelf of rock along the far side wall over the water,
        # steps up to it on both shores, its edge open over the lake's
        # middle, a way on from its far end.
        stair(build, lake_x0 - 6, self.wide - 5, 0, 0, 6, 4);
        slab(build, lake_x0, self.wide - 5, self.long - 1, self.wide - 1, 6);
        stair(build, lake_x1, self.wide - 11, 0, 1, 6, 3);
        keep_box(build, cave, lake_x0 - 2, self.wide - 5, lake_x0 + 1, self.wide - 1, 6);
        keep_box(build, cave, lake_x1, self.wide - 7, lake_x1 + 3, self.wide - 4, 6);
        keep_box(build, cave, cx - 1, self.wide - 5, cx + 3, self.wide - 4, 6);
        if self.mode > 0 {
            # A curtain of rock down into the water across the lake, the arch
            # passing over it.
            build.solid(cx, 1, -3, cx + 1, self.wide - 5, self.tall);
            build.solid(cx, self.wide - 5, -3, cx + 1, self.wide - 1, 5);
            build.touch(float(lake_x0 - 3), 1.0, 0.0, float(lake_x0), float(self.wide - 6), 6.0, True, "The way on is under the rock");
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        near = [[0, middle - 3, lake_x0, middle + 3], [lake_x0 - 1, 0, lake_x0 + 1, self.wide], [0, self.wide - 6, lake_x0, self.wide]];
        boulders(build, dice, 1, 1, lake_x0, self.wide - 1, 0, dice.between(2, 4), near);
        far_clear = [[lake_x1 - 1, 0, lake_x1 + 4, self.wide], [self.long - 5, middle - 5, self.long, middle + 3], [lake_x1, self.wide - 5, self.long, self.wide], [lake_x1, 0, self.long, 5]];
        boulders(build, dice, lake_x1, 1, self.long - 1, self.wide - 1, 0, dice.between(2, 4), far_clear);
        stalactites(build, dice, lake_x0, 2, lake_x1, self.wide - 6, self.tall, dice.between(8, 12));
        for index in range(dice.between(1, 2)) {
            build.foe(float(lake_x0 + 3 + index * 5), float(middle) + 3.5, -6, "monster_fish", 90.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(lake_x0 + 4 + index * 4), float(middle) + 0.5, 7, e1m4_foe(dice, self.danger, False, True), 180.0);
        }
        # Halfway over the water, scrags are sent in behind the swimmer; the
        # far shore's guards wake as he climbs out.
        halfway = build.touch(float(cx - 1), 1.0, -8.0, float(cx + 2), float(self.wide - 1), 6.0);
        halfway +>:Fires:+> build.summon(2, 2, -8, e1m4_foe(dice, self.danger, False, True), float(lake_x0) + 1.5, float(middle) + 0.5, 5, 0.0);
        out = build.touch(float(lake_x1 - 1), 1.0, -2.0, float(lake_x1 + 2), float(self.wide - 1), 6.0);
        guards = build.waiting();
        out +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(lake_x1) + 3.5, 3.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(lake_x1) + 4.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(lake_x1) + 4.5, 2.5], [float(lake_x1) + 4.5, float(self.wide) - 7.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""A tall cavern, a pool in its middle, ledges high on three walls reached
by teleporters on its floor; ways on from the ledges and the floor."""
node TeleportGrotto(Prefab) {
    has ledge: int = 11,
        tall: int = 24,
        bridge: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport grotto";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(22, 26);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(22, 26);
        self.ledge = dice.between(10, 12);
        self.bridge = dice.chance(0.5);
        self.low = -15;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=1, along=cx, floor=self.ledge),
            Port(face=0, along=cy, floor=self.ledge),
            Port(face=3, along=cx, floor=self.ledge),
            Port(face=0, along=cy - 6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.ledge);
        # The pool, deep, reaching west from the middle (clear of the
        # teleporters).
        build.pool(cx - 7, cy - 2, -8, cx + 2, cy + 2, 0, 2);
        sump(build, cx - 1, cy, -14, -8, 2);
        under = self.ledge - 1;
        # The ledges, slabs a lift thick high on the north, east and south.
        build.solid(6, self.wide - 5, under, self.long - 6, self.wide - 1, self.ledge);
        build.solid(self.long - 5, 6, under, self.long - 1, self.wide - 6, self.ledge);
        build.solid(6, 1, under, self.long - 6, 5, self.ledge);
        # A stretch of each ledge's edge with no railing, to drop from.
        for x in range(cx - 5, cx - 1) {
            build.keep(cave, x, self.wide - 6, self.ledge);
            build.keep(cave, x, 5, self.ledge);
        }
        for y in range(cy + 2, cy + 6) {
            build.keep(cave, self.long - 6, y, self.ledge);
        }
        # A bridge of rock across between the north and south ledges.
        if self.bridge {
            slab(build, cx - 1, 5, cx + 2, self.wide - 5, self.ledge);
            keep_box(build, cave, cx - 2, 4, cx + 3, 6, self.ledge);
            keep_box(build, cave, cx - 2, self.wide - 6, cx + 3, self.wide - 4, self.ledge);
        }
        build.teleporter(float(cx) + 0.5, float(self.wide) - 7.5, 0, float(cx) + 0.5, float(self.wide) - 3.0, self.ledge, 90.0);
        build.teleporter(float(self.long) - 7.5, float(cy) + 0.5, 0, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, 0.0);
        build.teleporter(float(cx) + 0.5, 7.5, 0, float(cx) + 0.5, 3.0, self.ledge, 270.0);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        stalactites(build, dice, 6, 6, self.long - 6, self.wide - 6, self.tall, dice.between(6, 10));
        # Boulders against the floor's walls, clear of the ways through.
        clear = [[0, cy - 3, 5, cy + 3], [cx - 11, cy - 5, cx + 3, cy + 6], [cx - 2, self.wide - 10, cx + 3, self.wide], [cx - 2, 0, cx + 3, 10], [self.long - 10, cy - 9, self.long, cy + 3], [2, 2, 5, self.wide - 2]];
        low_rocks(build, dice, 2, 2, self.long - 2, self.wide - 2, 0, dice.between(5, 8), 2, clear);
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 3.0, float(cy) + 4.5, 0, e1m4_foe(dice, self.danger), 0.0);
        }
        build.foe(3.5, 3.5, 0, "monster_knight", 90.0, patrol=[[3.5, 3.5], [3.5, float(self.wide) - 3.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, self.ledge + 4, e1m4_foe(dice, self.danger, False, True), 0.0);
        }
        # The ledges' guards wake as the player comes up to the pool.
        nearing = build.touch(float(cx - 10), float(cy - 5), 0.0, float(cx - 8), float(cy + 6), 6.0);
        guards = build.waiting();
        nearing +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, float(cy) - 3.5, self.ledge, e1m4_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(cx) + 4.5, float(self.wide) - 3.0, self.ledge, e1m4_foe(dice, self.danger, True), 270.0, waits=guards);
        build.foe(float(cx) - 4.5, 3.0, self.ledge, e1m4_foe(dice, self.danger), 90.0, waits=guards);
        build.supply(float(cx) - 2.5, float(self.wide) - 3.0, self.ledge, "item_health");
        build.supply(float(cx) + 3.5, 3.0, self.ledge, "item_spikes");
    }
}

"""A deep lake, the key on an island in it, swum to or reached high by a
bridge; taking it opens the closets high in the wall."""
node SilverGrotto(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        tall: int = 18,
        raised: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver grotto (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(24, 28);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(22, 24);
        self.raised = dice.chance(0.5);
        self.low = -15;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(cave, self.enter);
        lake_x = 8;
        build.pool(lake_x, 2, -8, self.long - 2, side - 1, 0, 2);
        sump(build, self.long - 6, 2, -14, -8, 3);
        ix = (lake_x + self.long - 2) // 2 + 1;
        iy = side // 2;
        top = 8 if self.raised else 0;
        build.solid(ix - 3, iy - 3, -8, ix + 3, iy + 3, top);
        # A ledge of rock along the far wall over the water, before the
        # closets high in it, a ramp up to it from the near shore.
        build.level(cave, 8);
        ramp(build, 1, side - 4, 0, 0, 8, 4);
        slab(build, lake_x + 1, side - 4, self.long - 1, side, 8);
        keep_box(build, cave, lake_x - 1, side - 4, lake_x + 2, side, 8);
        if self.raised {
            # The island a pillar of rock as high as the ledge, a bridge of
            # rock out to it from the ledge.
            slab(build, ix - 1, iy + 3, ix + 2, side - 4, 8);
            keep_box(build, cave, ix - 1, iy + 2, ix + 2, iy + 4, 8);
            keep_box(build, cave, ix - 1, side - 5, ix + 2, side - 3, 8);
        } else {
            keep_ring(build, cave, ix - 3, iy - 3, ix + 3, iy + 3, 0);
        }
        # The key on the island: taking it opens the closets high in the far
        # wall, scrags in them, and sends an ogre in behind.
        taken = key_cue(build, self.key, float(ix) + 0.5, float(iy) + 0.5, top);
        starts = [x for x in [lake_x + 2, lake_x + 7, lake_x + 12] if x + 3 < self.long - 2];
        closets(build, taken, side, starts, 8, 1, [e1m4_foe(dice, self.danger, False, True)]);
        taken +>:Fires:+> build.summon(2, 2, -8, e1m4_foe(dice, self.danger, True), 4.5, float(side) - 6.5, 0, 0.0);
        stalactites(build, dice, lake_x, 2, self.long - 2, side - 1, self.tall, dice.between(6, 10));
        build.foe(float(ix) + 2.5, float(iy) + 2.5, top, e1m4_foe(dice, self.danger, True), 180.0);
        build.foe(float(ix) - 5.0, float(iy) + 0.5, -6, "monster_fish", 0.0);
        build.foe(float(lake_x) + 2.5, float(side) - 2.5, 8, e1m4_foe(dice, self.danger), 0.0, patrol=[[float(lake_x) + 2.5, float(side) - 2.5], [float(self.long) - 3.5, float(side) - 2.5]]);
        build.foe(3.5, 3.5, 0, "monster_knight", 0.0, patrol=[[3.5, 3.5], [3.5, float(side) - 6.5]]);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""A tall shaft, a basin at its foot, flights of steps switching back up
its side (or a flight and a long lift) to ways on at the middle and the
top."""
node WaterfallClimb(Prefab) {
    has n: int = 7,
        tall: int = 30,
        lifted: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Waterfall climb";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.n = dice.between(6, 8);
        self.lifted = dice.chance(0.4);
        self.long = self.n + 9;
        self.wide = dice.between(15, 17);
        top = 3 * self.n;
        self.tall = top + dice.between(8, 10);
        self.low = -13;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 5), floor=0);
        self.leaves = [
            Port(face=0, along=4.0, floor=top),
            Port(face=0, along=4.0, floor=self.n),
            Port(face=1, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        n = self.n;
        top = 3 * n;
        a = 4;
        land = a + n;
        # The basin, and a niche under its water in the far corner.
        build.pool(5, 7, -6, self.long - 2, self.wide - 3, 0, 2);
        sump(build, 9, 9, -12, -6, 2);
        build.room(self.long - 5, self.wide - 3, -6, self.long - 3, self.wide - 1, -3);
        flood(build, self.long - 5, self.wide - 3, -6, self.long - 3, self.wide - 1, -3);
        build.secret(float(self.long - 5), float(self.wide - 3), -6.0, float(self.long - 3), float(self.wide - 1), -3.0);
        build.supply(float(self.long) - 4.0, float(self.wide) - 2.0, -6, "item_armor1");
        # The first flight, along the near wall climbing +x, to a landing.
        ramp(build, a, 1, 0, 0, n, 3);
        build.solid(land, 1, max(0, n - 3), self.long - 1, 7, n);
        if self.lifted {
            # A long lift in the near corner up to a landing over the first
            # flight the shaft's length.
            lift(build, 1, 1, a, 4, 0, top);
            slab(build, a, 1, self.long - 1, 7, top);
            keep_box(build, shaft, 1, 1, a + 2, 5, top);
            keep_box(build, shaft, 1, 1, a + 1, 5, 0);
        } else {
            # The second flight back along beside the first, a landing at the
            # near wall, and the third over the first to the top landing.
            ramp(build, land - 1, 4, n, 2, n, 3);
            build.solid(1, 1, 2 * n - 3, a, 7, 2 * n);
            ramp(build, a, 1, 2 * n, 0, n, 3);
            build.solid(land, 1, top - 3, self.long - 1, 7, top);
            keep_box(build, shaft, land - 1, 1, land + 1, 8, n);
            keep_box(build, shaft, a - 1, 1, a + 1, 8, 2 * n);
            keep_box(build, shaft, land - 1, 1, land + 1, 5, top);
        }
        # The top landing reaches out over the basin, its edge open to drop
        # from into the water.
        slab(build, land, 7, self.long - 1, 10, top);
        keep_box(build, shaft, land, 9, self.long - 2, 10, top);
        for index in range(4) {
            build.level(shaft, index * n);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # What is on the first landing wakes as the climb begins.
        foot = build.touch(float(a), 1.0, 0.0, float(a + 3), 4.0, 6.0);
        landing = build.waiting();
        foot +>:Fires:+> landing;
        build.foe(float(self.long) - 2.5, 5.5, n, e1m4_foe(dice, self.danger), 180.0, waits=landing);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide) - 6.5, 6 + index * 6, e1m4_foe(dice, self.danger, False, True), float(index * 120));
        }
        build.foe(float(self.long) - 2.5, 3.5, top, e1m4_foe(dice, self.danger, True), 180.0);
        build.foe(6.5, float(self.wide) - 2.5, 0, "monster_knight", 0.0, patrol=[[6.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, n, "item_health");
    }
}

"""A cave walled off at its far end; two buttons count to the wall's
opening, and the cave beyond holds the ways on."""
node SecretCave(Prefab) {
    has wall_x: int = 20,
        tall: int = 15,
        island: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Secret cave";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(14, 16);
        self.island = dice.chance(0.5);
        self.wall_x = self.long - 9;
        self.low = -15;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid), floor=0),
            Port(face=1, along=float(self.wall_x + 5), floor=0),
            Port(face=0, along=3.0, floor=2)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        w = self.wall_x;
        cave = build.room(1, 1, 0, w, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(w + 1, 1, 0, self.long - 1, self.wide - 1, self.tall - 2, variant=dice.below(3));
        build.widen(beyond, w, mid - 2, 0, w + 1, mid + 2, 8);
        count = build.tally(2, "A secret cave has opened...");
        count +>:Fires:+> build.opened(float(w), float(mid - 2), 0.0, float(w + 1), float(mid + 2), 8.0);
        # A gallery of rock along the near side wall, a ramp up to it; the
        # first button on the wall under it.
        ramp(build, 2, 1, 0, 0, 7, 4);
        slab(build, 9, 1, w, 5, 7);
        keep_box(build, cave, 7, 1, 10, 5, 7);
        build.level(cave, 7);
        bx = dice.between(10, w - 6);
        build.push(float(bx) + 0.5, 1.0, 1.2, 1) +>:Fires:+> count;
        kept: list[list[int]] = [[0, mid - 3, 5, mid + 3], [0, 0, w, 6], [w - 4, mid - 4, w + 1, mid + 4]];
        # A pool in the cave's middle.
        px = dice.between(7, w - 12);
        build.pool(px, mid - 3, -6, px + 8, mid + 3, 0, 2);
        sump(build, px + 6, mid - 3, -12, -6, 2);
        kept.append([px - 1, mid - 4, px + 9, mid + 4]);
        if self.island {
            # The second button out on a rock in the pool.
            build.solid(px + 3, mid - 1, -6, px + 6, mid + 2, 0);
            keep_ring(build, cave, px + 3, mid - 1, px + 6, mid + 2, 0);
            build.solid(px + 4, mid, 0, px + 5, mid + 1, 3);
            build.push(float(px + 5), float(mid) + 0.5, 1.2, 0) +>:Fires:+> count;
        } else {
            # The second up on a ledge along the far side wall, steps up to it.
            lx = dice.between(9, w - 8);
            slab(build, lx, self.wide - 5, lx + 6, self.wide - 1, 5);
            stair(build, lx - 5, self.wide - 4, 0, 0, 5, 3);
            keep_box(build, cave, lx - 2, self.wide - 5, lx + 1, self.wide - 1, 5);
            build.push(float(lx) + 5.5, float(self.wide - 1), 6.2, 3) +>:Fires:+> count;
            kept.append([lx - 6, self.wide - 6, lx + 7, self.wide]);
        }
        # Scrags are sent in as the wall opens.
        for index in range(2) {
            count +>:Fires:+> build.summon(3 + index * 5, 2, -8, e1m4_foe(dice, self.danger, False, True), float(w) - 3.5 - float(index) * 3.0, float(mid) + 0.5, 4, 180.0);
        }
        # Beyond: a shelf of rock two lifts up along one side, the ways on.
        build.solid(w + 1, 1, 0, self.long - 1, 5, 2);
        build.solid(w + 3, 5, 0, w + 6, 6, 1);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        boulders(build, dice, 1, 1, w, self.wide - 1, 0, dice.between(2, 4), kept);
        low_rocks(build, dice, 1, 1, w, self.wide - 1, 0, dice.between(3, 5), 2, kept);
        stalactites(build, dice, 3, 3, w - 2, self.wide - 3, self.tall, dice.between(5, 8));
        for index in range(dice.between(2, 3)) {
            build.foe(float(w) - 4.5 - float(index) * 3.0, 3.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5, float(self.wide) - 3.5, 0, "monster_knight", 0.0, patrol=[[4.5, float(self.wide) - 3.5], [float(w) - 3.5, float(self.wide) - 6.5]]);
        build.foe(float(w) - 2.5, 3.0, 7, e1m4_foe(dice, self.danger, True), 180.0);
        inside = build.waiting();
        count +>:Fires:+> inside;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 6.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, True), 180.0, waits=inside);
        }
        build.supply(float(self.long) - 2.5, 2.5, 2, "item_rockets");
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""Two caves joined by a tunnel swum under the rock, a pocket of air on the
way; sometimes a high shelf through the rock too."""
node SunkenTunnel(Prefab) {
    has cave_a: int = 13,
        rock: int = 7,
        cave_b: int = 11,
        lane: int = 5,
        tall: int = 13,
        shelf: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sunken tunnel";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.cave_a = dice.between(16, 19);
        self.rock = dice.between(6, 8);
        self.cave_b = dice.between(13, 15);
        self.wide = dice.between(15, 18);
        self.tall = dice.between(13, 15);
        # The pools and the tunnel lie along the far side wall, under the
        # galleries.
        self.lane = self.wide - 6;
        self.shelf = dice.chance(0.4);
        self.long = 1 + self.cave_a + self.rock + self.cave_b + 1;
        self.low = -15;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 10)), floor=0);
        far = float(self.long - 1 - self.cave_b // 2);
        self.leaves = [
            Port(face=0, along=4.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=8),
            Port(face=3, along=far, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        wall_x = 1 + self.cave_a;
        far_x = wall_x + self.rock;
        first = build.room(1, 1, 0, wall_x, self.wide - 1, self.tall, variant=dice.below(3));
        second = build.room(far_x, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # A pool at the near end of each cave, the tunnel from the first's
        # bottom on under the first cave's floor and the rock to the
        # second's: all of it water.
        build.pool(3, self.lane - 1, -7, 11, self.lane + 4, 0, 2);
        build.pool(far_x, self.lane - 1, -7, far_x + 8, self.lane + 4, 0, 2);
        sump(build, 6, self.lane + 1, -13, -7, 3);
        sump(build, far_x + 3, self.lane + 1, -13, -7, 3);
        build.room(11, self.lane - 1, -7, far_x, self.lane + 4, -3);
        flood(build, 11, self.lane - 1, -7, far_x, self.lane + 4, -3);
        # The pocket of air under the rock: water at its foot, a dry ledge
        # in it, a secret and a reward.
        px = wall_x + self.rock // 2 - 1;
        build.room(px, self.lane - 1, -7, px + 3, self.lane + 4, 1);
        flood(build, px, self.lane, -7, px + 3, self.lane + 3, -4);
        build.solid(px, self.lane + 3, -7, px + 3, self.lane + 4, -4);
        build.solid(px, self.lane - 1, -7, px + 3, self.lane, -4);
        build.secret(float(px), float(self.lane - 1), -4.0, float(px + 3), float(self.lane + 4), 0.0);
        build.supply(float(px) + 1.5, float(self.lane) - 0.5, -4, "item_health");
        build.touch(1.0, 1.0, 0.0, 3.0, float(self.wide - 1), 6.0, True, "The way on is under the water");
        # A gallery along the first cave's far side wall over its pool, a
        # lift up to it, its edge over the pool open to drop from; sometimes
        # it runs on through a hole in the rock into the second cave's
        # gallery (a way over without the swim).
        build.level(first, 8);
        slab(build, 3, self.wide - 5, wall_x, self.wide - 1, 8);
        lift(build, 12, self.wide - 9, 15, self.wide - 5, 0, 8);
        keep_box(build, first, 11, self.wide - 10, 16, self.wide - 4, 8);
        keep_box(build, first, 11, self.wide - 10, 16, self.wide - 5, 0);
        keep_box(build, first, 4, self.wide - 5, 9, self.wide - 4, 8);
        if self.shelf {
            slab(build, wall_x, self.wide - 4, far_x, self.wide - 1, 8);
            build.widen(first, wall_x, self.wide - 4, 8, far_x, self.wide - 1, 13);
        }
        build.foe(float(wall_x) - 2.5, float(self.wide) - 3.0, 8, e1m4_foe(dice, self.danger), 180.0);
        # A gallery along the second cave's far side wall, a lift up to it,
        # a stretch of its edge open to drop from, a way on from its end.
        build.level(second, 8);
        slab(build, far_x, self.wide - 5, self.long - 1, self.wide - 1, 8);
        lift(build, self.long - 4, self.wide - 9, self.long - 1, self.wide - 5, 0, 8);
        keep_box(build, second, self.long - 5, self.wide - 10, self.long - 1, self.wide - 4, 8);
        keep_box(build, second, self.long - 5, self.wide - 10, self.long - 1, self.wide - 5, 0);
        keep_box(build, second, far_x + 9, self.wide - 5, far_x + 12, self.wide - 4, 8);
        build.foe(float(far_x) + 4.5, float(self.wide) - 2.5, 8, e1m4_foe(dice, self.danger), 0.0, patrol=[[float(far_x) + 4.5, float(self.wide) - 2.5], [float(self.long) - 6.5, float(self.wide) - 2.5]]);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(second, port);
        }
        clear_a = [[0, 0, 5, self.wide], [0, self.wide - 11, wall_x, self.wide]];
        boulders(build, dice, 1, 1, wall_x, self.wide - 1, 0, dice.between(2, 3), clear_a);
        low_rocks(build, dice, 1, 1, wall_x, self.wide - 1, 0, dice.between(3, 5), 2, clear_a);
        clear_b = [[far_x - 1, self.wide - 11, self.long, self.wide], [self.long - 6, 0, self.long, 7], [self.long - 1 - self.cave_b // 2 - 3, 0, self.long - 1 - self.cave_b // 2 + 3, 5]];
        boulders(build, dice, far_x, 1, self.long - 1, self.wide - 1, 0, dice.between(2, 4), clear_b);
        low_rocks(build, dice, far_x, 1, self.long - 1, self.wide - 1, 0, dice.between(2, 4), 2, clear_b);
        for index in range(dice.between(1, 2)) {
            build.foe(float(13 + index * 4), float(self.lane) + 1.5, -6, "monster_fish", 0.0);
        }
        build.foe(float(wall_x) - 3.5, 2.5, 0, e1m4_foe(dice, self.danger, True), 180.0);
        # The second cave's guards wake as the swimmer comes up out of its
        # pool.
        out = build.touch(float(far_x), float(self.lane - 1), -2.0, float(far_x + 8), float(self.lane + 4), 6.0);
        guards = build.waiting();
        out +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(self.long) - 6.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(self.long) - 6.5, 2.5], [float(self.long) - 6.5, float(self.wide) - 8.5]]);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""The end: a cave, a shelf of rock along one wall, the slipgate on a rock
ledge up a stair; as a gate, a key door across the ledge's mouth."""
node GrottoExit(Prefab) {
    has key: str = "",
        ledge_x: int = 14,
        tall: int = 15,
        causeway: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grotto exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(28, 31);
        self.wide = dice.between(15, 17);
        self.tall = dice.between(20, 22);
        self.causeway = dice.chance(0.5);
        self.ledge_x = self.long - 1 - 6;
        self.low = -15;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 7);
        build.doorway(cave, self.enter);
        # The ledge three lifts up, a wall across its mouth with a way in.
        wall = self.ledge_x - 1;
        build.solid(self.ledge_x, 1, 0, self.long - 1, self.wide - 1, 3);
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 11, wall + 1, middle + 2, self.tall);
        stair(build, wall - 3, middle - 2, 0, 0, 3, 4);
        build.solid(wall, middle - 2, 0, wall + 1, middle + 2, 3);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 3.0, float(wall + 1), float(middle + 2), 11.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(float(self.ledge_x) + 3.0, float(middle), 3);
        # A shelf of rock along the near side wall seven lifts up, steps up
        # to it from the cave's near end.
        slab(build, 9, 1, wall, 5, 7);
        stair(build, 2, 1, 0, 0, 7, 3);
        keep_box(build, cave, 7, 1, 10, 5, 7);
        # Before the ledge: a pool crossed by a causeway, or boulders.
        clear = [[0, middle - 3, 5, middle + 3], [wall - 5, middle - 3, wall + 1, middle + 3], [0, 0, wall, 6]];
        if self.causeway {
            px = 10;
            build.pool(px, 1, -5, px + 5, self.wide - 1, 0, 2, False, True, True);
            sump(build, px + 2, 2, -10, -5, 3);
            build.solid(px, middle - 1, -5, px + 5, middle + 2, 0);
            keep_box(build, cave, px - 1, middle - 1, px + 6, middle + 2, 0);
            clear.append([px - 1, 0, px + 6, self.wide]);
        }
        boulders(build, dice, 1, 6, wall, self.wide - 1, 0, dice.between(2, 3), clear);
        low_rocks(build, dice, 1, 6, wall, self.wide - 1, 0, dice.between(3, 5), 2, clear);
        stalactites(build, dice, 3, 3, wall - 1, self.wide - 3, self.tall, dice.between(5, 8));
        # Nearing the ledge's stair wakes the shelf's guards and brings a foe
        # in behind the player.
        nearing = build.touch(float(wall - 6), float(middle - 2), 0.0, float(wall - 3), float(middle + 2), 6.0);
        guards = build.waiting();
        nearing +>:Fires:+> guards;
        nearing +>:Fires:+> build.summon(2, middle - 1, -8, e1m4_foe(dice, self.danger, True), 3.5, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 2.5 - float(index) * 3.0, 3.0, 7, e1m4_foe(dice, self.danger, True), 270.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 5.5 - float(index % 2) * 3.0, float(self.wide) - 2.5 - float(index), 0, e1m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5, float(self.wide) - 2.5, 0, "monster_knight", 0.0, patrol=[[4.5, float(self.wide) - 2.5], [float(wall) - 6.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""e1m4's stretches: [name, role]."""
glob E1M4_STRETCHES: list[list[str]] = [
         ["mouth", "start"],
         ["caverns", "flow"],
         ["teleports", "hub"],
         ["teleports", "flow"],
         ["silver", "keyroom"],
         ["waterfall", "flow"],
         ["secret", "flow"],
         ["tunnel", "flow"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e1m4's stretches by its name."""
def make_e1m4(name: str, key: str) -> Prefab {
    if name == "mouth" {
        return GrottoMouth();
    }
    if name == "caverns" {
        return FloodedCaverns();
    }
    if name == "teleports" {
        return TeleportGrotto();
    }
    if name == "silver" {
        return SilverGrotto(key=key if key else "key_silver");
    }
    if name == "waterfall" {
        return WaterfallClimb();
    }
    if name == "secret" {
        return SecretCave();
    }
    if name == "tunnel" {
        return SunkenTunnel();
    }
    return GrottoExit(key=key);
}
