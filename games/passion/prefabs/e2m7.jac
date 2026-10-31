"""Prefabs drawn from e2m7, Underearth: caves deep under the earth and halls
cut into them, its exit barred until the player "goes for a swim first",
marks on its walls shot one by one to open the way on, a chamber of
spikes sweeping round a pillar while four buttons are found, a river of
lava crossed stone by stone or on a platform a plate on the floor sets
going, plates that loose a fan of spikes, the gold key caged on a
balcony. Raised in e2m7's own palette.

- `UnderearthCave`: the start. A cave, a pool in it and a shelf over its
  north side up a stair; the way on through the far wall is barred ("Go
  for a swim first...") until a button under the water and one on the
  shelf are both pushed. Diving brings scrags in by teleporter; a low
  button by a rock opens a niche under the shelf (a secret).
- `ShotMarks`: a hall of pillars, a gallery along its north side; marks
  on the walls and pillars (e2m7's shootable triggers) must all be shot
  before the bars across its ways on below sink, counting down as each
  is hit.
- `SpikeRing`: a chamber round a pillar, a gallery round its walls; coming
  in sets spikes sweeping round the pillar (e2m7's ring of spike shooters
  fired one after another), and the four buttons on its walls, two below
  and two on the gallery, open its ways on below (a hub as well).
- `LavaRiver`: a cave, a river of lava crossed stone by stone, on a span
  of rock, or on a platform a plate on the floor sets riding; a shelf
  beyond whose way on is opened by a button near by ("This door is opened
  near by..."), plates before the shelf's stair loosing a fan of spikes
  from the wall (a hub).
- `CagedKey`: the key room. A balcony across a hall's far end, the key
  caged on it behind bars a button high on the near wall opens when shot,
  a lift or a stair up; plates before the balcony loose spikes; taking the
  key opens the closets below and brings scrags in.
- `UnderearthExit`: the end. A cave, a shelf high at its far end over a
  hollow under it, a stair up in two flights; as a gate, a key's bars
  across the cave; climbing brings scrags in."""
import math;
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..cast { BUTTON_MATERIAL }
import from .roster { FoeMix }
import from .common { stair, boulders, stalactites, lift, ring_path }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_moat, e2m4_stash }

glob E2M7: str = "q1:e2m7";

"""e2m7's foes: the dead and ogres, scrags, hell knights deeper in."""
glob E2M7_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_ogre", "monster_wizard", "monster_zombie"], strong=["monster_hell_knight"], heavy_light=["monster_ogre", "monster_hell_knight"], heavy_strong=["monster_demon1"]);

"""A mark on a wall to be shot (e2m7's shootable triggers): a plate in the
wall's face at the prefab's cell point (x, y), `z` lifts up, facing
`direction` (0 +x ... 3 -y, out of the wall), and before it a trigger
that fires its cue when shot."""
def e2m7_mark(build: Raising, x: float, y: float, z: float, direction: int) -> Cue {
    half = 0.4;
    deep = 0.3;
    x0 = x - half;
    x1 = x + half;
    y0 = y - half;
    y1 = y + half;
    px0 = x0;
    px1 = x1;
    py0 = y0;
    py1 = y1;
    if direction == 0 {
        px0 = x;
        px1 = x + 0.05;
        x0 = x + 0.05;
        x1 = x + deep;
    } elif direction == 2 {
        px0 = x - 0.05;
        px1 = x;
        x0 = x - deep;
        x1 = x - 0.05;
    } elif direction == 1 {
        py0 = y;
        py1 = y + 0.05;
        y0 = y + 0.05;
        y1 = y + deep;
    } else {
        py0 = y - 0.05;
        py1 = y;
        y0 = y - deep;
        y1 = y - 0.05;
    }
    build.put_box({"classname": "func_wall"}, px0, py0, z, px1, py1, z + 0.8, BUTTON_MATERIAL);
    fields = {"classname": "trigger_once", "health": "1"};
    build.put_box(fields, x0, y0, z, x1, y1, z + 0.8, "trigger");
    return build.cue([fields], "mark");
}

"""A plate in the floor: a button of the prefab's cells x0..x1, y0..y1 on
lift `z` that sinks a little when stood on (e2m7's floor plates), firing
its cue."""
def e2m7_plate(build: Raising, x0: float, y0: float, x1: float, y1: float, z: int) -> Cue {
    fields = {"classname": "func_button", "angle": "-2", "wait": "-1", "lip": "2"};
    build.put_box(fields, x0, y0, float(z), x1, y1, float(z) + 0.25, BUTTON_MATERIAL);
    return build.cue([fields], "plate");
}

"""Spikes fanned out of a wall: shooters at the prefab's cell point
(x, y), `z` lifts up, aimed at each of `angles` (degrees of the prefab's
own), all fired by one cue."""
def e2m7_fan(build: Raising, x: float, y: float, z: float, angles: list[float]) -> Cue {
    items: list[dict[str, str]] = [];
    for angle in angles {
        fields = {"classname": "trap_spikeshooter", "angle": str(build.heading(angle))};
        build.put_point(fields, x, y, z, "q1");
        items.append(fields);
    }
    return build.cue(items, "fan");
}

"""The start: a cave, a pool, a shelf over it, the way on barred until a
button under the water and one on the shelf are pushed."""
node UnderearthCave(Prefab) {
    has shelf: int = 8,
        tall: int = 17,
        secret_nook: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Underearth cave";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(16, 18);
        self.secret_nook = dice.chance(0.6);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 6), floor=self.shelf), Port(face=3, along=float(self.long - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        s = self.shelf;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, s);
        # The pool, a button under its water on its south wall.
        e2m4_moat(build, 9, 17, 2, 9, 7);
        below = build.push(13.0, 2.0, -6.0, 1);
        # The shelf along the north wall over the pool's edge, a stair up.
        build.solid(2, self.wide - 6, s - 1, self.long - 1, self.wide - 1, s);
        stair(build, 6, self.wide - 6 - s, 0, 1, s, 3);
        for x in range(6, 9) {
            build.keep(cave, x, self.wide - 6, s);
        }
        build.solid(self.long - 4, self.wide - 4, s, self.long - 3, self.wide - 3, s + 3);
        above = build.push(float(self.long - 4), float(self.wide) - 3.5, float(s) + 1.2, 2);
        both = build.tally(2, "The way on is open");
        below +>:Fires:+> both;
        above +>:Fires:+> both;
        for port in self.taken {
            build.doorway(cave, port);
            if port.face == 0 {
                both +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "Go for a swim first...");
            }
        }
        # Diving brings scrags in over the pool.
        dive = build.touch(11.0, 3.0, -6.0, 15.0, 8.0, -2.0);
        late = build.delay(0.5);
        dive +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(1 + index * 4, 2, -9, "monster_wizard", 12.5 + float(index) * 3.0, float(middle) + 1.5, 6, 270.0);
        }
        # A niche under the shelf, opened by a low button by its face.
        if self.secret_nook {
            build.solid(self.long - 6, self.wide - 6, 0, self.long - 1, self.wide - 1, s - 1);
            build.room(self.long - 5, self.wide - 5, 0, self.long - 2, self.wide - 3, 4);
            door = e2m4_bars(build, float(self.long - 6), float(self.wide - 5), float(self.long - 5), float(self.wide - 3), 0, 4, "");
            build.push(float(self.long) - 3.5, float(self.wide - 6), 0.4, 3) +>:Fires:+> door;
            build.secret(float(self.long - 5), float(self.wide - 5), 0.0, float(self.long - 2), float(self.wide - 3), 3.0);
            build.supply(float(self.long) - 3.5, float(self.wide) - 4.0, 0, "item_artifact_super_damage");
        }
        clear = [[0, middle - 3, 5, middle + 3], [8, 1, 18, 10], [5, self.wide - 7 - s, 10, self.wide - 5], [self.long - 6, middle - 3, self.long, middle + 3], [self.long - 9, 0, self.long - 3, 4]];
        boulders(build, dice, 1, 1, self.long - 1, self.wide - 7, 0, dice.between(3, 5), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 7, self.tall, dice.between(5, 8));
        # The dead about the cave wake as the player comes past the pool;
        # an ogre walks the shelf.
        past = build.touch(17.0, 1.0, 0.0, 19.0, float(self.wide - 6), 6.0);
        dead = build.waiting();
        past +>:Fires:+> dead;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 6.5 - float(index) * 2.0, 3.5 + float(index) * 3.0, 0, E2M7_FOES.pick(dice, self.danger, index == 0), 180.0, waits=dead);
        }
        build.foe(10.5, float(self.wide) - 3.0, s, "monster_ogre", 0.0, patrol=[[10.5, float(self.wide) - 3.0], [float(self.long) - 7.5, float(self.wide) - 3.0]]);
        build.foe(20.5, float(middle) + 0.5, 0, "monster_zombie", 90.0, patrol=[[20.5, 3.5], [20.5, float(self.wide) - 8.5]]);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, 0, "item_health");
    }
}

"""A hall of pillars, a gallery along it; the marks on its walls shot one
by one sink the bars across its ways on."""
node ShotMarks(Prefab) {
    has gallery: int = 8,
        marks: list[int] = [],
        stash: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shot marks";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(17, 20);
        self.tall = dice.between(15, 17);
        self.stash = dice.chance(0.5);
        self.marks = dice.order(9)[:dice.between(5, 7)];
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2) - 1.0;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 8), floor=0), Port(face=1, along=float(self.long - 6), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        gy = self.wide - 5;
        middle = self.wide // 2 - 1;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery along the north wall, a stair up beside it.
        build.solid(2, gy, g - 1, self.long - 1, self.wide - 1, g);
        stair(build, 6, gy - 3, 0, 0, g, 3);
        for x in range(5 + g, 8 + g) {
            build.keep(hall, x, gy, g);
        }
        # A row of pillars down the hall's south half.
        columns: list[float] = [];
        for x in range(8, self.long - 5, 6) {
            build.solid(x, 5, 0, x + 1, 6, self.tall);
            columns.append(float(x));
        }
        # The marks: on the south wall, on the pillars' faces, high on the
        # north wall over the gallery, on the far wall.
        spots: list[list[float]] = [
            [5.5, 1.0, 3.0, 1.0], [float(self.long // 2) + 0.5, 1.0, 5.0, 1.0], [float(self.long) - 4.5, 1.0, 2.0, 1.0],
            [float(self.long) - 1.0, 3.5, 4.0, 2.0], [float(self.long // 3) + 0.5, float(self.wide - 1), float(g) + 3.0, 3.0],
            [float(2 * self.long // 3) + 0.5, float(self.wide - 1), float(g) + 4.0, 3.0], [1.0, 3.5, 6.0, 0.0]
        ];
        for x in columns {
            spots.append([x + 0.5, 6.0, 4.0, 1.0]);
            spots.append([x + 1.0, 5.5, 2.5, 0.0]);
        }
        count = len([spot for spot in self.marks if spot < len(spots)]);
        tally = build.tally(max(1, count), "The way on is open");
        for spot in self.marks {
            if spot < len(spots) {
                at = spots[spot];
                e2m7_mark(build, at[0], at[1], at[2], int(at[3])) +>:Fires:+> tally;
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                low = port.along - 2.0;
                if port.face == 0 {
                    tally +>:Fires:+> e2m4_bars(build, float(self.long - 2), low, float(self.long - 1), low + 4.0, 0, 8, "Shoot the marks...");
                } else {
                    tally +>:Fires:+> e2m4_bars(build, low, 1.0, low + 4.0, 2.0, 0, 8, "Shoot the marks...");
                }
            }
        }
        # Coming in wakes what keeps the gallery; knights walk the floor.
        coming = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 6.0);
        guard = build.waiting();
        coming +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5 - float(index) * 6.0, float(self.wide) - 3.0, g, E2M7_FOES.pick(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        build.foe(10.5, 3.0, 0, "monster_knight" if self.danger < 0.4 else "monster_hell_knight", 0.0, patrol=[[10.5, 3.0], [float(self.long) - 3.5, 3.0]]);
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, 0, "monster_zombie", 180.0, patrol=[[float(self.long) - 6.5, float(middle) + 0.5], [8.5, float(middle) + 0.5]]);
        if self.stash {
            build.solid(2, gy, g, 7, self.wide - 1, g + 6);
            e2m4_stash(build, 3, gy + 1, 5, self.wide - 2, g, 0, "item_artifact_super_damage");
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.0, g, "item_health");
        build.supply(2.5, 2.5, 0, "item_shells");
    }
}

"""A chamber round a pillar, a gallery round its walls; spikes sweep round
the pillar while four buttons are found."""
node SpikeRing(Prefab) {
    has gallery: int = 9,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike ring";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(22, 26);
        self.wide = dice.between(22, 26);
        self.tall = self.gallery + dice.between(10, 12);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=1, along=float(self.long - 5), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        cx = self.long // 2;
        cy = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, g);
        # The gallery round the walls, a stair up to it along the south.
        for cell in ring_path(1, 1, self.long - 1, self.wide - 1, 3) {
            build.solid(cell[0], cell[1], g - 1, cell[2], cell[3], g);
        }
        stair(build, 5, 4, 0, 0, g, 3);
        for x in range(g + 1, g + 4) {
            build.keep(room, x, 3, g);
        }
        # The pillar, and the ring of spike shooters about it, fired one
        # after another round and round once the player comes in.
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.tall);
        # The links of the ring are triggers sealed in the pillar, each
        # firing the next a tenth of a second on (as e2m7's are).
        relays: list[Cue] = [];
        for index in range(12) {
            link = {"classname": "trigger_multiple", "delay": "0.1", "wait": "1"};
            at = float(cx - 2) + 0.5 + float(index % 6) * 0.5;
            build.put_box(link, at, float(cy) - 0.5 + float(index // 6) * 0.6, 6.0, at + 0.3, float(cy) - 0.2 + float(index // 6) * 0.6, 6.5, "trigger");
            relays.append(build.cue([link], "link"));
        }
        for index in range(12) {
            angle = float(index) * 30.0;
            rad = angle * 3.14159265 / 180.0;
            fields = {"classname": "trap_spikeshooter", "angle": str(build.heading(angle))};
            build.put_point(fields, float(cx) + 2.7 * math.cos(rad), float(cy) + 2.7 * math.sin(rad), 1.5, "q1");
            relays[index] +>:Fires:+> build.cue([fields], "spikes");
            relays[index] +>:Fires:+> relays[(index + 1) % 12];
        }
        coming = build.touch(1.0, float(cy - 2), 0.0, 3.0, float(cy + 2), 6.0);
        coming +>:Fires:+> relays[0];
        # The four buttons, two below and two on the gallery; all pushed,
        # the ways on below open and what was waiting is brought in.
        four = build.tally(4, "The way on is open");
        for at in [[float(self.long - 1), float(cy) + 5.5, 1.2, 2.0], [float(self.long) - 5.5, 1.0, 1.2, 1.0], [5.5, float(self.wide - 1), float(g) + 1.2, 3.0], [float(self.long - 1), 5.5, float(g) + 1.2, 2.0]] {
            build.push(at[0], at[1], at[2], int(at[3])) +>:Fires:+> four;
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
            if port.floor == 0 {
                low = port.along - 2.0;
                if port.face == 0 {
                    four +>:Fires:+> e2m4_bars(build, float(self.long - 2), low, float(self.long - 1), low + 4.0, 0, 8, "Find the four buttons");
                } else {
                    four +>:Fires:+> e2m4_bars(build, low, 1.0, low + 4.0, 2.0, 0, 8, "Find the four buttons");
                }
            }
        }
        late = build.delay(1.0);
        four +>:Fires:+> late;
        late +>:Fires:+> build.summon(2, 6, -8, E2M7_FOES.pick(dice, self.danger, True), float(cx) - 5.5, float(cy) + 0.5, 0, 0.0);
        # What waits in the chamber wakes as the player comes in; an ogre
        # walks the gallery.
        guard = build.waiting();
        coming +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 4.5, float(cy) - 4.5 + float(index) * 4.5, 0, E2M7_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(2.5, float(self.wide) - 2.5, g, "monster_ogre", 0.0, patrol=[[2.5, float(self.wide) - 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5], [float(self.long) - 2.5, 2.5], [2.5, 2.5]]);
        build.foe(float(cx) + 0.5, float(cy) - 5.5, 6, "monster_wizard", 0.0);
        build.foe(float(cx) - 5.5, float(cy) + 5.5, 0, "monster_zombie", 0.0, patrol=[[float(cx) - 5.5, float(cy) + 5.5], [float(cx) + 5.5, float(cy) + 5.5]]);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(2.5, 2.5, g, "item_rockets");
    }
}

"""A cave, a river of lava across it crossed by stones, a span or a
platform set riding by a plate; a shelf beyond, its way on opened near
by."""
node LavaRiver(Prefab) {
    has shelf: int = 6,
        rafted: bool = False,
        stash: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava river";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(16, 20);
        self.shelf = dice.between(6, 7);
        self.rafted = dice.chance(0.5);
        self.stash = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle - 3.0, floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.shelf),
            Port(face=3, along=float(self.long - 5), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=self.shelf)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        s = self.shelf;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, s);
        # The river across the cave, seven cells wide: stones a jump apart
        # on its north half; a span of rock, or a platform a plate on the
        # floor sets riding, on its south.
        rx = 10;
        build.pool(rx, 1, -3, rx + 7, self.wide - 1, 0, 4, False, False);
        for at in [rx + 1, rx + 3, rx + 5] {
            build.solid(at, self.wide - 7, -3, at + 1, self.wide - 5, 0);
        }
        if self.rafted {
            plate = e2m7_plate(build, float(rx - 3), 4.0, float(rx - 1), 6.0, 0);
            plate +>:Fires:+> build.train([3.0, 4.0, 1.0], [[float(rx), 3.0, -1.0], [float(rx + 4), 3.0, -1.0]], 160.0, 2.0, True);
        } else {
            build.solid(rx, 3, -3, rx + 7, 7, 0);
        }
        for y in range(3, 7) {
            build.keep(cave, rx - 1, y, 0);
            build.keep(cave, rx + 7, y, 0);
        }
        # The shelf along the far end's north side, a stair up its face; the
        # way on from its end opened by a button near by, at the stair's
        # foot; plates before the stair loose a fan of spikes from the wall.
        sx = self.long - 8;
        sy = self.wide - 7;
        build.solid(sx, sy, 0, self.long - 1, self.wide - 1, s);
        stair(build, sx, sy - s, 0, 1, s, 3);
        for x in range(sx, sx + 3) {
            build.keep(cave, x, sy, s);
        }
        near = build.push(float(sx + 5), float(sy), 1.2, 3);
        for (index, y0) in enumerate([sy - s - 3, sy - s - 6]) {
            plate_fan = build.touch(float(sx), float(y0), 0.0, float(sx + 3), float(y0 + 2), 4.0, False);
            plate_fan +>:Fires:+> e2m7_fan(build, float(self.long) - 1.2, float(y0) + 1.0, 1.5, [150.0, 165.0, 180.0, 195.0, 210.0]);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
            if port.floor == s and port.face == 0 {
                near +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, s, 8, "This door is opened near by...");
            }
        }
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        # The dead wake as the player reaches the far bank; a hell knight
        # walks it; an ogre keeps the shelf; scrags over the lava.
        bank = build.touch(float(rx + 7), 1.0, 0.0, float(rx + 9), float(self.wide - 1), 6.0);
        dead = build.waiting();
        bank +>:Fires:+> dead;
        for index in range(dice.between(2, 4)) {
            build.foe(float(rx + 11 + index * 2) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, E2M7_FOES.pick(dice, self.danger, index == 0), 180.0, waits=dead);
        }
        build.foe(float(rx + 10) + 0.5, 3.0, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_knight", 90.0, patrol=[[float(rx + 10) + 0.5, 3.0], [float(rx + 10) + 0.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, s, E2M7_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 3.5, float(self.wide) - 3.5], [float(sx) + 3.5, float(self.wide) - 3.5]]);
        build.foe(float(rx) + 3.5, float(middle) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.0, s, "item_health");
        build.supply(3.5, 3.5, 0, "item_spikes");
        build.supply(float(rx + 9) + 0.5, float(middle) + 0.5, 0, "item_health");
        build.foe(4.5, float(self.wide) - 4.5, 0, "monster_zombie", 0.0, patrol=[[4.5, float(self.wide) - 4.5], [float(rx) - 2.5, float(self.wide) - 4.5]]);
        if self.stash {
            build.solid(1, 1, 0, 6, 6, 8);
            e2m4_stash(build, 2, 2, 4, 4, 0, 1, "item_artifact_super_damage");
        }
    }
}

"""The key room: a balcony across the far end, the key caged on it behind
bars a shot button opens; taking it opens the closets."""
node CagedKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        balcony: int = 7,
        lifted: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Caged key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(22, 26);
        self.hall_wide = dice.between(15, 17);
        self.wide = self.hall_wide + 4;
        self.balcony = dice.between(6, 7);
        self.lifted = dice.chance(0.5);
        self.tall = self.balcony + dice.between(9, 10);
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
        cy = side // 2;
        b = self.balcony;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, b);
        build.doorway(hall, self.enter);
        # The balcony across the far end, a slab over the floor, a lift or a
        # stair up to it.
        bx = self.long - 8;
        build.solid(bx, 1, b - 1, self.long - 1, side, b);
        for y in [3, side - 4] {
            build.solid(bx, y, 0, bx + 1, y + 1, b - 1);
        }
        if self.lifted {
            lift(build, bx - 3, 2, bx, 5, 0, b);
            for y in range(2, 5) {
                build.keep(hall, bx, y, b);
                build.keep(hall, bx - 4, y, 0);
            }
        } else {
            stair(build, bx - b, 1, 0, 0, b, 3);
            for y in range(1, 4) {
                build.keep(hall, bx, y, b);
            }
        }
        # The cage on the balcony: walls round its middle, bars across its
        # front a button high on the near wall opens when shot.
        cx = self.long - 5;
        build.solid(cx, cy - 3, 0, self.long - 1, cy + 3, b - 1);
        build.solid(cx, cy - 3, b, self.long - 1, cy - 2, b + 6);
        build.solid(cx, cy + 2, b, self.long - 1, cy + 3, b + 6);
        build.solid(cx, cy - 3, b + 6, self.long - 1, cy + 3, b + 7);
        bars = e2m4_bars(build, float(cx), float(cy - 2), float(cx + 1), float(cy + 2), b, 6, "The cage opens elsewhere...");
        build.push(1.0, float(cy) + 4.5, float(b) + 2.0, 0, True) +>:Fires:+> bars;
        # Plates before the balcony loose spikes from the side walls.
        for x0 in [bx - 7, bx - 4] {
            plate = build.touch(float(x0), float(cy - 1), 0.0, float(x0 + 2), float(cy + 1), 4.0, False);
            plate +>:Fires:+> e2m7_fan(build, float(x0) + 1.0, 1.2, 1.5, [60.0, 90.0, 120.0]);
        }
        # The key; taking it opens the closets below and brings scrags in.
        taken = e2m4_key(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, b);
        out = build.waiting();
        taken +>:Fires:+> out;
        for (index, at) in enumerate([3, bx - 5]) {
            closet = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(closet, at, side, 0, at + 3, side + 1, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0, fields);
            taken +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E2M7_FOES.pick(dice, self.danger, index == 0), 270.0, waits=out);
        }
        late = build.delay(0.5);
        taken +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(2 + index * 4, 2, -8, "monster_wizard", float(bx) - 4.5, float(cy) - 2.5 + float(index) * 5.0, 5, 0.0);
        }
        build.foe(float(bx) - 2.5, float(side) - 2.5, 0, E2M7_FOES.pick(dice, self.danger), 180.0, patrol=[[float(bx) - 2.5, float(side) - 2.5], [4.5, float(side) - 2.5]]);
        build.foe(float(bx) + 2.5, 2.5, b, E2M7_FOES.pick(dice, self.danger, True), 180.0, patrol=[[float(bx) + 2.5, 2.5], [float(bx) + 2.5, float(side) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(bx) + 1.5, float(side) - 2.5, b, "item_health");
    }
}

"""The end: a cave, a shelf high at its far end over a hollow, a stair up
in two flights; as a gate, a key's bars across the cave."""
node UnderearthExit(Prefab) {
    has key: str = "",
        shelf: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Underearth exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.shelf = dice.between(9, 10);
        self.tall = self.shelf + dice.between(8, 10);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        s = self.shelf;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, s);
        build.doorway(cave, self.enter);
        # The wall across the cave, a key's bars in its gap as a gate.
        wall = 9;
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 8, wall + 1, middle + 2, self.tall);
        if self.key {
            e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key);
        }
        # The shelf, a slab over a hollow at the far end, the slipgate on it;
        # a stair up in two flights along the south wall, turning on a
        # landing.
        sx = self.long - 8;
        build.solid(sx, 1, s - 1, self.long - 1, self.wide - 1, s);
        for y in [4, self.wide - 5] {
            build.solid(sx, y, 0, sx + 1, y + 1, s - 1);
        }
        half = s // 2;
        stair(build, sx - 4 - half, 1, 0, 0, half, 3);
        build.solid(sx - 4, 1, 0, sx, 5, half);
        stair(build, sx - 4, 5, half, 1, s - half, 4);
        for y in range(3 + s - half, 6 + s - half) {
            build.keep(cave, sx, y, s);
        }
        build.way_out(float(self.long) - 3.5, float(middle), s);
        # Climbing brings scrags in; the hollow's dead wake as the player
        # passes the wall.
        climb = build.touch(float(sx - 4), 1.0, float(half), float(sx), 5.0, float(half + 6));
        late = build.delay(0.5);
        climb +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(2 + index * 4, 2, -8, "monster_wizard", float(sx) - 6.5, float(middle) + float(index) * 3.0, 6, 0.0);
        }
        passing = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        hollow = build.waiting();
        passing +>:Fires:+> hollow;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 6.5 + float(index) * 2.5, 0, E2M7_FOES.pick(dice, self.danger, index == 0), 180.0, waits=hollow);
        }
        clear = [[0, middle - 3, 5, middle + 3], [wall - 4, middle - 3, wall + 4, middle + 3], [sx - 6, 0, self.long, self.wide]];
        boulders(build, dice, 1, 1, self.long - 1, self.wide - 1, 0, dice.between(3, 6), clear);
        stalactites(build, dice, 3, 3, sx - 2, self.wide - 3, self.tall, dice.between(4, 7));
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E2M7_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, s, E2M7_FOES.pick(dice, self.danger, True), 180.0, patrol=[[float(self.long) - 3.5, 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.foe(float(wall) + 3.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[float(wall) + 3.5, 2.5], [float(wall) + 3.5, float(self.wide) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(sx) - 2.5, 2.5, half, "item_health");
    }
}

"""e2m7's stretches: [name, role]."""
glob E2M7_STRETCHES: list[list[str]] = [
         ["cave", "start"],
         ["marks", "flow"],
         ["ring", "flow"],
         ["river", "hub"],
         ["ring", "hub"],
         ["river", "flow"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m7's stretches by its name."""
def make_e2m7(name: str, key: str) -> Prefab {
    if name == "cave" {
        return UnderearthCave();
    }
    if name == "marks" {
        return ShotMarks();
    }
    if name == "ring" {
        return SpikeRing();
    }
    if name == "river" {
        return LavaRiver();
    }
    if name == "cage" {
        return CagedKey(key=key if key else "key_gold");
    }
    return UnderearthExit(key=key);
}
