"""Prefabs drawn from e1m7, the House of Chthon: a vast cavern of lava, its
ledges and flights of stone stepping down from on high, a shaft climbed by
a stair winding twice round it, teleporters between tiers, a catwalk of
buttons over the lava (e1m7's electrodes), pillars to leap across a lava
lake, and the arena where Chthon rises (here its shamblers wait instead).
Raised in e1m7's own palette. e1m7 holds no keys of its own; its vault and
gate keep the run's keys in its manner. Each stretch takes its shape from
its dice as well as its sizes.

- `ChthonApproach`: the start. A platform high in the cavern, a flight of
  stone down along the wall to a landing and a second back down to the
  floor (the floor running on under the first); a lava lake along one
  side. Shooting the button high on the far wall opens the ways on below;
  a teleporter on the floor goes back up to the platform; what waits on
  the floor wakes as the landing is reached.
- `ChthonDescent`: a shaft over a pit of lava, a stair winding up its
  walls twice round (its second turn over its first), the way on at its
  head and one at its foot; a teleporter at the foot up to the head, or
  an altar in the pit with one; scrags in the shaft.
- `TeleportJunction`: the hub: a hall of three tiers, rings at two
  heights one over the other round a floor with a lava pit at its heart;
  teleporters up from tier to tier and drops back down; ways on from every
  tier; the button on the top ring opens the way out of the floor.
- `ElectrodeWalk`: a hall floored with lava, a lift up to a catwalk over
  it (straight, or crooked round a pillar), three buttons on its spurs
  that together open the ways on (e1m7's buttons and their counter); a
  teleporter back across from the far floor.
- `LavaPillars`: a lava lake crossed by leaping from pillar to pillar (level
  or climbing as they go), a ledge round its far side; a teleporter back;
  the far shore's guards wake as it is reached, and a closet opens.
- `RuneVault`: the key room: the key on a pillar of stone in lava, reached
  by a teleporter (and one back), or by a bridge drawn up by a button;
  taking it opens the closets and sends a shambler's worth in behind.
- `ChthonArena`: the end: a great pit of lava, a ring of stone round it, an
  island in its middle; the bridges to the way out drawn up by shooting
  the button over the far ledge, or by pressing the two on the ring; as a
  gate, a key door across the far ledge's mouth."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, stalactites, lift, spiral, ring_landing, ring_path }
import from .e1m2_parts { slab, keep_box, keep_ring, arcade, closets, key_cue, ramp, low_rocks }
import from .e1m2 { port_gate }

glob E1M7: str = "q1:e1m7";

"""e1m7's foes: zombies and knights, ogres where `heavy` (a shambler deep in
a run)."""
def e1m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    if heavy {
        return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"], ["monster_shambler"] if danger >= 0.5 else ["monster_demon1"], danger * 0.6));
    }
    return q1_foe(dice, q1_palette(["monster_zombie", "monster_zombie", "monster_knight"], ["monster_ogre"], danger));
}

"""The start: a platform high in the cavern, two flights down to the floor,
a lava lake along one side."""
node ChthonApproach(Prefab) {
    has a: int = 10,
        b: int = 8,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon approach";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.a = dice.between(10, 11);
        self.b = self.a - dice.between(1, 2);
        self.long = self.a + 11;
        self.wide = dice.between(18, 20);
        top = self.a + self.b;
        self.tall = top + dice.between(7, 9);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=top);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=0, along=5.0, floor=self.b)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        top = self.a + self.b;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, top);
        build.level(cave, self.b);
        # The platform the run begins on; the first flight down along the
        # wall (the floor running on under it), a landing at the far end,
        # the second flight back down beside the first.
        build.solid(1, 1, 0, 4, 9, top);
        ramp(build, 4 + self.a - 1, 1, self.b, 2, self.a, 3);
        land_x = 4 + self.a;
        build.solid(land_x, 1, self.b - 3, self.long - 1, 9, self.b);
        ramp(build, land_x - self.b, 4, 0, 0, self.b, 3);
        keep_box(build, cave, 3, 1, 6, 4, top);
        keep_box(build, cave, land_x - 1, 1, land_x + 1, 8, self.b);
        # The flights' open sides unrailed: a drop from the first onto the
        # second, or to the floor.
        for step in range(self.a) {
            build.keep(cave, 3 + self.a - step, 3, self.b + step + 1);
        }
        keep_box(build, cave, land_x, 8, self.long - 1, 9, self.b);
        # A lava lake along the far side of the floor.
        build.pool(6, 10, -3, self.long - 6, self.wide - 1, 0, 4, False, False);
        build.doorway(cave, self.enter);
        # The ways on below are shut until the button high on the far wall
        # is shot.
        shot = build.push(float(self.long - 1), 6.5, float(top) - 2.0, 2, True);
        for port in self.taken {
            build.doorway(cave, port);
            if port.floor == 0 {
                shot +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(1.0, 1.0, float(top), 4.0, 9.0, float(top + 6), True, "Shoot the button on the far wall");
        # A teleporter on the floor back up to the platform.
        build.teleporter(float(land_x) + 2.5, 3.0, 0, 2.5, 6.5, top, 0.0);
        stalactites(build, dice, 6, 10, self.long - 6, self.wide - 2, self.tall, dice.between(6, 10));
        rocks = [[0, 0, 5, 10], [land_x - self.b - 1, 3, land_x + 1, 8], [land_x, 1, land_x + 5, 5], [self.long - 7, 9, self.long, self.wide], [5, 9, self.long - 5, self.wide]];
        low_rocks(build, dice, 5, 1, self.long - 1, 10, 0, dice.between(6, 8), 2, rocks);
        build.start(2.5, 4.5, top, 0.0);
        build.supply(2.5, 2.0, top, "item_shells");
        # What waits on the floor wakes as the landing is reached.
        landed = build.touch(float(land_x), 1.0, float(self.b), float(land_x + 2), 9.0, float(self.b + 6));
        below = build.waiting();
        landed +>:Fires:+> below;
        landed +>:Fires:+> build.summon(2, 11, -8, e1m7_foe(dice, self.danger), float(land_x) - 2.5, 7.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, float(self.wide) - 3.5 - float(index) * 2.5, 0, e1m7_foe(dice, self.danger), 180.0, waits=below);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + float(index) * 3.0, float(self.wide) - 5.5, 6, "monster_wizard", 180.0);
        }
        build.foe(5.5, 2.5, 0, "monster_zombie", 0.0, patrol=[[5.5, 2.5], [float(land_x) - 1.5, 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, self.b, "item_health");
    }
}

"""A shaft over a pit of lava, a stair winding up its walls twice round, the
way on at its head and at its foot."""
node ChthonDescent(Prefab) {
    has n: int = 10,
        steps: int = 32,
        tall: int = 40,
        altar: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon descent";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.n = 10;
        self.steps = 32;
        self.altar = dice.chance(0.5);
        self.long = self.n + 2;
        self.wide = self.n + 2;
        self.tall = self.steps + dice.between(8, 9);
        self.low = -4;
        self.high = self.tall + 1;
        landing = ring_landing(1, 1, self.n + 1, self.n + 1, 3, self.steps, 3);
        self.enter = Port(face=2, along=6.0, floor=0);
        self.leaves = [
            Port(face=int(landing[0]) if landing else 3, along=float(int(landing[1])) if landing else 6.0, floor=self.steps),
            Port(face=0, along=6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        n = self.n;
        shaft = build.room(1, 1, 0, n + 1, n + 1, self.tall, variant=dice.below(3));
        for index in range(1, 5) {
            build.level(shaft, index * self.steps // 4);
        }
        # The pit of lava at the shaft's heart.
        build.pool(4, 4, -3, n - 2, n - 2, 0, 4, False, False);
        # The stair winding up the walls, twice round at its top.
        spiral(build, 1, 1, n + 1, n + 1, 0, self.steps, 3, 3, 0);
        keep_box(build, shaft, 4, 1, 9, 4, self.steps);
        # No railing on the stair below its head: a misstep drops onto the
        # turn below, or into the pit.
        path = ring_path(1, 1, n + 1, n + 1, 3);
        for step in range(self.steps - 4) {
            cell = path[step % len(path)];
            keep_box(build, shaft, cell[0], cell[1], cell[2], cell[3], step + 1);
        }
        if self.altar {
            # An altar of stone in the pit, a jump from the floor's edge, a
            # teleporter on it up to the stair's head.
            build.solid(5, 5, -3, n - 3, n - 3, 1);
            keep_ring(build, shaft, 5, 5, n - 3, n - 3, 1);
            build.teleporter(float(n // 2) + 0.5, float(n // 2) + 0.5, 1, 6.0, 2.5, self.steps, 0.0);
        } else {
            build.teleporter(2.5, 6.5, 0, 6.0, 2.5, self.steps, 0.0);
        }
        build.doorway(shaft, self.enter);
        # The way on at the head is shut until the button at the foot is
        # pressed.
        press = build.push(float(n + 1), float(n) - 1.5, 1.2, 2);
        for port in self.taken {
            build.doorway(shaft, port);
            if port.floor > 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        # Halfway up, what waits at the head wakes; scrags in the shaft.
        halfway = build.touch(float(n - 2), 1.0, float(self.steps // 2 - 2), float(n + 1), float(n + 1), float(self.steps // 2 + 4));
        head = build.waiting();
        halfway +>:Fires:+> head;
        build.foe(6.0, 3.0, self.steps, e1m7_foe(dice, self.danger), 0.0, waits=head);
        build.foe(float(n) - 1.0, float(n) - 2.0, 15, e1m7_foe(dice, self.danger), 180.0, waits=head);
        for index in range(dice.between(2, 3)) {
            build.foe(float(n // 2) + 0.5, float(n // 2) + 0.5, 6 + index * 8, "monster_wizard", float(index * 90));
        }
        build.foe(float(n) - 1.0, 2.5, 0, "monster_zombie", 90.0, patrol=[[float(n) - 1.0, 4.5], [float(n) - 1.0, float(n) - 1.0]]);
        build.supply(float(n) - 1.0, float(n) - 1.0, 0, "item_health");
    }
}

"""The hub: a hall of three tiers, rings one over the other round a floor
with a lava pit; teleporters up, drops down, ways on from every tier."""
node TeleportJunction(Prefab) {
    has t1: int = 10,
        t2: int = 20,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport junction";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(24, 27);
        self.wide = dice.between(22, 25);
        self.t1 = dice.between(9, 10);
        self.t2 = self.t1 + dice.between(9, 10);
        self.tall = self.t2 + dice.between(14, 16);
        self.low = -9;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.t1),
            Port(face=3, along=float(self.long // 2), floor=self.t2),
            Port(face=0, along=float(self.wide - 3), floor=self.t2)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        cx = self.long // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.t1);
        build.level(hall, self.t2);
        # The rings, four cells deep, one over the other, on pillars.
        for z in [self.t1, self.t2] {
            slab(build, 1, 1, self.long - 1, 5, z);
            slab(build, 1, self.wide - 5, self.long - 1, self.wide - 1, z);
            slab(build, 1, 5, 5, self.wide - 5, z);
            slab(build, self.long - 5, 5, self.long - 1, self.wide - 5, z);
        }
        for line in [4, self.wide - 5] {
            arcade(build, line, 7, self.long - 6, 0, self.t1 - 1, 4, False);
        }
        # The pit of lava at the floor's heart.
        build.pool(cx - 2, mid - 2, -3, cx + 2, mid + 2, 0, 4, False, False);
        # Up: teleporters from the floor to the lower ring and from it to the
        # upper; down: stretches of the rings' edges open to drop from.
        build.teleporter(float(cx) - 4.5, float(mid) + 0.5, 0, float(self.long) - 3.0, float(mid) + 0.5, self.t1, 180.0);
        build.teleporter(float(cx) + 0.5, float(self.wide) - 3.0, self.t1, float(cx) + 0.5, 3.0, self.t2, 270.0);
        build.teleporter(float(cx) + 4.5, float(mid) + 0.5, 0, 3.0, float(mid) + 0.5, self.t2, 0.0);
        # The lower ring's inner edges open to drop from all round; the upper
        # ring's along its long sides.
        keep_box(build, hall, 5, 4, self.long - 5, 5, self.t1);
        keep_box(build, hall, 5, self.wide - 5, self.long - 5, self.wide - 4, self.t1);
        keep_box(build, hall, 4, 6, 5, self.wide - 6, self.t1);
        keep_box(build, hall, self.long - 5, 6, self.long - 4, self.wide - 6, self.t1);
        keep_box(build, hall, cx - 6, 4, cx + 6, 5, self.t2);
        keep_box(build, hall, cx - 6, self.wide - 5, cx + 6, self.wide - 4, self.t2);
        # The button on the upper ring opens the way out of the floor.
        press = build.push(float(self.long - 1), float(mid) - 4.5, float(self.t2) + 1.2, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(2.0, float(mid - 2), 0.0, 4.0, float(mid + 2), 6.0, True, "The way on below is opened from above");
        rocks = [[0, mid - 3, 6, mid + 3], [self.long - 6, mid - 3, self.long, mid + 3], [cx - 6, mid - 2, cx - 3, mid + 3], [cx + 3, mid - 2, cx + 6, mid + 3], [cx - 3, mid - 3, cx + 3, mid + 3], [cx - 6, mid - 7, cx + 6, mid - 4]];
        low_rocks(build, dice, 6, 6, self.long - 6, self.wide - 6, 0, dice.between(4, 6), 2, rocks);
        # More about the floor under the lower ring.
        rocks.extend([[0, mid - 4, 7, mid + 4], [self.long - 7, mid - 4, self.long, mid + 4], [cx - 2, self.wide - 7, cx + 3, self.wide], [cx - 2, 0, cx + 3, 7], [4, 2, 9, 5]]);
        low_rocks(build, dice, 1, 1, self.long - 1, self.wide - 1, 0, dice.between(12, 16), 2, rocks);
        # The rings' guards wake as the floor's middle is reached; one more is
        # sent onto the lower ring.
        nearing = build.touch(float(cx - 6), float(mid - 3), 0.0, float(cx - 3), float(mid + 3), 6.0);
        guards = build.waiting();
        nearing +>:Fires:+> guards;
        nearing +>:Fires:+> build.summon(2, mid - 1, -8, e1m7_foe(dice, self.danger), 3.0, float(mid) + 0.5, self.t1, 0.0);
        build.foe(float(self.long) - 3.0, 3.0, self.t1, e1m7_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(3.0, float(self.wide) - 3.0, self.t2, e1m7_foe(dice, self.danger, True), 0.0, waits=guards);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, self.t2, e1m7_foe(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(mid) - 5.5, 0, e1m7_foe(dice, self.danger), 90.0);
        }
        build.foe(6.5, 3.0, self.t1, "monster_knight", 0.0, patrol=[[6.5, 3.0], [float(self.long) - 6.5, 3.0]]);
        build.foe(float(cx) + 0.5, float(mid) + 0.5, self.t1 + 4, "monster_wizard", 0.0);
        build.supply(3.0, 3.0, self.t1, "item_health");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, self.t2, "item_rockets");
    }
}

"""A hall floored with lava, a lift up to a catwalk over it, three buttons
on its spurs that together open the ways on."""
node ElectrodeWalk(Prefab) {
    has c: int = 11,
        tall: int = 20,
        crooked: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Electrode walk";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(17, 19);
        self.c = dice.between(10, 11);
        self.tall = self.c + dice.between(12, 14);
        self.crooked = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid - 4), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid - 4), floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=0, along=float(mid + 3), floor=self.c)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        c = self.c;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, c);
        # The lava between the near floor and the far.
        build.pool(6, 1, -3, self.long - 6, self.wide - 1, 0, 4, False, False);
        # The lift on the near floor up to the catwalk; the catwalk out over
        # the lava to the far wall, straight, or crooked round a pillar.
        lift(build, 2, mid + 2, 5, mid + 5, 0, c);
        keep_box(build, hall, 1, mid + 1, 6, mid + 6, c);
        keep_box(build, hall, 1, mid + 1, 6, mid + 6, 0);
        if self.crooked {
            bend = self.long // 2;
            slab(build, 5, mid + 2, bend + 2, mid + 5, c);
            slab(build, bend - 1, mid - 3, bend + 2, mid + 5, c);
            slab(build, bend - 1, mid - 3, self.long - 1, mid, c);
            build.solid(bend + 2, mid + 1, -3, bend + 4, mid + 3, self.tall);
            walk_y = [mid + 2, mid + 2, mid - 3];
            build.widen(hall, self.long - 2, mid - 3, c, self.long - 1, mid + 5, c + 8);
            slab(build, self.long - 4, mid - 3, self.long - 1, mid + 5, c);
        } else {
            slab(build, 5, mid + 2, self.long - 1, mid + 5, c);
            walk_y = [mid + 2, mid + 2, mid + 2];
        }
        # Three spurs off the catwalk, a pylon on each with its button; all
        # three pressed open the ways on.
        count = build.tally(3, "The ways on are open");
        for (index, x) in enumerate([9, self.long // 2 + 4, self.long - 8]) {
            wy = walk_y[min(index, 2)];
            if wy == mid + 2 {
                slab(build, x, mid - 1, x + 3, mid + 2, c);
                build.solid(x + 1, mid - 1, c, x + 2, mid, c + 3);
                build.push(float(x) + 1.5, float(mid), float(c) + 1.2, 1) +>:Fires:+> count;
            } else {
                slab(build, x, mid, x + 3, mid + 3, c);
                build.solid(x + 1, mid + 2, c, x + 2, mid + 3, c + 3);
                build.push(float(x) + 1.5, float(mid + 2), float(c) + 1.2, 3) +>:Fires:+> count;
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            count +>:Fires:+> port_gate(build, self.long, self.wide, port);
        }
        # The catwalk's far end open to drop from onto the far floor; a
        # teleporter there back across to the near floor.
        keep_box(build, hall, self.long - 6, mid + 1, self.long - 5, mid + 6, c);
        build.teleporter(float(self.long) - 3.5, 3.5, 0, 3.0, float(mid) - 3.5, 0, 180.0);
        far_y = mid - 6 if self.crooked else mid + 5;
        lift(build, self.long - 5, far_y, self.long - 2, far_y + 3, 0, c);
        keep_box(build, hall, self.long - 6, far_y - 1, self.long - 1, far_y + 4, c);
        keep_box(build, hall, self.long - 6, far_y, self.long - 1, far_y + 3, 0);
        # Scrags over the lava; the far floor's guards wake as the second
        # button is pressed.
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(mid) - 4.5, c + 3, "monster_wizard", 180.0);
        }
        far = build.waiting();
        count +>:Fires:+> far;
        for index in range(2) {
            build.foe(float(self.long) - 3.0, float(mid) - 3.5 + float(index) * 6.0, 0, e1m7_foe(dice, self.danger, index == 0), 180.0, waits=far);
        }
        crossing = build.touch(float(self.long // 2 - 2), float(mid - 3), float(c), float(self.long // 2 + 2), float(mid + 5), float(c + 6));
        crossing +>:Fires:+> build.summon(2, 2, -8, e1m7_foe(dice, self.danger), 3.0, float(mid) - 2.5, 0, 0.0);
        build.foe(2.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[2.5, 2.5], [2.5, float(mid) - 2.5]]);
        rocks = [[0, mid - 7, 6, mid - 1], [0, mid + 1, 6, mid + 6], [0, 0, 4, 5], [self.long - 7, 0, self.long, 6], [self.long - 7, mid - 7, self.long, self.wide]];
        low_rocks(build, dice, 1, 1, 6, self.wide - 1, 0, dice.between(1, 2), 2, rocks);
        low_rocks(build, dice, self.long - 6, 1, self.long - 1, self.wide - 1, 0, dice.between(1, 2), 2, rocks);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_cells");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A lava lake crossed by leaping from pillar to pillar, a ledge round its
far side."""
node LavaPillars(Prefab) {
    has shore: int = 5,
        tall: int = 18,
        climbing: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava pillars";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(17, 20);
        self.tall = dice.between(26, 30);
        self.climbing = dice.chance(0.5);
        self.low = -10;
        self.high = self.tall + 1;
        far = float(self.long - 1 - self.shore) + float(self.shore) * 0.5;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=far, floor=0), Port(face=3, along=far, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        lava_x0 = 1 + self.shore;
        lava_x1 = self.long - 1 - self.shore;
        build.pool(lava_x0, 1, -3, lava_x1, self.wide - 1, 0, 4);
        # Pillars two cells square, a cell's leap apart, wandering across;
        # level, or each a lift higher than the last to the middle and down
        # again.
        x = lava_x0 + 1;
        y = middle - 1;
        index = 0;
        count = (lava_x1 - 1 - x) // 3;
        while x + 2 <= lava_x1 - 1 {
            rise_to = min(index, count - 1 - index) if self.climbing else 0;
            build.solid(x, y, -3, x + 2, y + 2, max(0, rise_to));
            keep_ring(build, cave, x, y, x + 2, y + 2, max(0, rise_to));
            x += 3;
            index += 1;
            y = max(3, min(self.wide - 5, y + dice.between(-1, 1)));
        }
        if x - 3 + 2 < lava_x1 - 1 {
            build.solid(lava_x1 - 3, y, -3, lava_x1 - 1, y + 2, 0);
        }
        # A ledge along the side wall a lift over the lava, a leap's gap in
        # its middle: another way across.
        gap = (lava_x0 + lava_x1) // 2;
        slab(build, lava_x0, 1, gap, 3, 1);
        slab(build, gap + 1, 1, lava_x1, 3, 1);
        keep_box(build, cave, gap - 1, 1, gap + 2, 3, 1);
        build.doorway(cave, self.enter);
        # The ways on from the far shore are shut until the button on the
        # near shore is pressed.
        press = build.push(1.0, float(middle) - 3.5, 1.2, 0);
        for port in self.taken {
            build.doorway(cave, port);
            press +>:Fires:+> port_gate(build, self.long, self.wide, port);
        }
        build.touch(1.0, 1.0, 0.0, 3.0, float(self.wide - 1), 6.0, True, "The far doors are opened from here");
        # A teleporter on the far shore back to the near one.
        build.teleporter(float(lava_x1) + 2.5, float(self.wide) - 3.5, 0, 2.5, float(middle) + 3.5, 0, 0.0);
        stalactites(build, dice, lava_x0, 2, lava_x1, self.wide - 2, self.tall, dice.between(8, 12));
        rocks = [[0, middle - 5, 4, middle + 5], [lava_x0 - 2, 0, lava_x0 + 1, self.wide], [lava_x1 - 1, 0, lava_x1 + 2, self.wide], [lava_x1 + 1, self.wide - 5, lava_x1 + 4, self.wide], [self.long - 4, middle - 3, self.long, middle + 3], [lava_x1, 4, self.long, 12], [lava_x1 + 1, 0, lava_x1 + 6, 4]];
        low_rocks(build, dice, 1, 1, lava_x0, self.wide - 1, 0, dice.between(2, 4), 2, rocks);
        low_rocks(build, dice, lava_x1, 1, self.long - 1, self.wide - 1, 0, dice.between(3, 5), 2, rocks);
        for index in range(dice.between(1, 2)) {
            build.foe(float(lava_x0 + 4 + index * 6) + 0.5, float(middle) + 3.5, 6, "monster_wizard", 180.0);
        }
        # The far shore's guards wake, and a closet in its wall opens, as the
        # last pillar is reached.
        arrived = build.touch(float(lava_x1 - 1), 1.0, 0.0, float(lava_x1 + 2), float(self.wide - 1), 8.0);
        guards = build.waiting();
        arrived +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(lava_x1) + 2.5, 5.5 + float(index) * 3.0, 0, e1m7_foe(dice, self.danger), 180.0, waits=guards);
        }
        arrived +>:Fires:+> build.summon(2, 2, -8, e1m7_foe(dice, self.danger), 3.0, float(middle) - 2.5, 0, 0.0);
        build.foe(float(self.long) - 2.5, float(self.wide) - 3.5, 0, e1m7_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(2.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_cells");
    }
}

"""The key room: the key on a pillar in lava, reached by a teleporter or a
drawn bridge; taking it opens the closets."""
node RuneVault(Prefab) {
    has key: str = "key_silver",
        hw: int = 16,
        tall: int = 18,
        bridged: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rune vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(20, 24);
        self.hw = dice.between(16, 18);
        self.wide = self.hw + 4;
        self.tall = dice.between(18, 20);
        self.bridged = dice.chance(0.5);
        self.low = -15;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hw // 2 - 4), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hw - 1;
        mid = self.hw // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, 6);
        build.doorway(hall, self.enter);
        lava_x = 7;
        build.pool(lava_x, 1, -3, self.long - 1, side, 0, 4, False, False);
        # The pillar, its top six lifts up.
        px = (lava_x + self.long - 1) // 2 - 2;
        build.solid(px, mid - 2, -3, px + 4, mid + 2, 6);
        if self.bridged {
            # A shelf on the shore as high (a way left round it along the near
            # wall), a lift up to it, a bridge drawn up to the pillar by the
            # button on the shelf's post.
            build.solid(4, mid - 2, 0, lava_x, mid + 2, 6);
            lift(build, 4, mid + 2, 7, mid + 5, 0, 6);
            keep_box(build, hall, 3, mid + 1, 8, mid + 6, 6);
            keep_box(build, hall, 3, mid + 2, 8, mid + 6, 0);
            bridge = build.drawn(float(lava_x), float(mid - 1), float(px), float(mid + 2), 6, 10);
            build.solid(4, mid - 2, 6, 5, mid - 1, 9);
            build.push(5.0, float(mid) - 1.5, 7.2, 0) +>:Fires:+> bridge;
            for y in range(mid - 1, mid + 2) {
                build.keep(hall, lava_x - 1, y, 6);
                build.keep(hall, px, y, 6);
            }
        } else {
            # A teleporter on the shore up to the pillar.
            build.teleporter(4.0, float(mid) + 0.5, 0, float(px) + 1.0, float(mid) + 0.5, 6, 0.0);
        }
        # A teleporter on the pillar back to the shore.
        build.teleporter(float(px) + 3.0, float(mid) - 1.0, 6, 3.0, float(side) - 3.0, 0, 180.0);
        # The key: taking it opens the closets in the shore's far wall and
        # sends a heavy foe in behind.
        taken = key_cue(build, self.key, float(px) + 2.0, float(mid) + 1.0, 6);
        closets(build, taken, side, [1, 4] if lava_x >= 7 else [1], 0, 1, [e1m7_foe(dice, self.danger), "monster_zombie"]);
        taken +>:Fires:+> build.summon(2, 2, -8, e1m7_foe(dice, self.danger), 4.0, 3.0, 0, 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(px) + 2.0, float(mid) + 0.5, 10 + index * 2, "monster_wizard", 180.0);
        }
        build.foe(3.0, 2.5, 0, "monster_knight", 90.0, patrol=[[3.0, 2.5], [3.0, float(mid) - 3.5]]);
        rocks = [[0, mid - 7, 4, mid - 1], [0, 0, 5, 4], [2, mid - 3, lava_x + 1, mid + 6], [0, side - 5, 8, side + 1]];
        low_rocks(build, dice, 1, 1, lava_x, side, 0, dice.between(2, 3), 2, rocks);
        build.supply(2.5, float(side) - 1.5, 0, "item_health");
    }
}

"""The end: a great lava pit, a ring of stone round it, an island in its
middle; the bridges to the way out drawn up by its buttons."""
node ChthonArena(Prefab) {
    has key: str = "",
        ring: int = 4,
        tall: int = 26,
        paired: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon arena" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(30, 34);
        self.wide = dice.between(26, 30);
        self.tall = dice.between(42, 48);
        self.paired = dice.chance(0.5);
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
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(arena, self.enter);
        # The lava pit inside the ring, the island in its middle, the far
        # ledge with the way out across from the near ring.
        pit_x0 = 1 + self.ring;
        pit_x1 = self.long - 1 - self.ring - 4;
        build.pool(pit_x0, 1 + self.ring, -3, pit_x1, self.wide - 1 - self.ring, 0, 4);
        cx = (pit_x0 + pit_x1) // 2;
        # The island short along the bridges' line (three cells), wide across.
        build.solid(cx - 1, middle - 4, -3, cx + 2, middle + 4, 1);
        # The far ledge: the ring's east side widened, two lifts up, steps up
        # to it from the ring at its ends; the bridges across to it.
        ledge_x = pit_x1;
        build.solid(ledge_x, 1, 0, self.long - 1, self.wide - 1, 2);
        build.solid(ledge_x - 1, 1, 0, ledge_x, 1 + self.ring, 1);
        build.solid(ledge_x - 1, self.wide - 1 - self.ring, 0, ledge_x, self.wide - 1, 1);
        far_bridge = build.drawn(float(cx + 2), float(middle - 1), float(ledge_x), float(middle + 2), 1, 5);
        near_bridge = build.drawn(float(pit_x0), float(middle - 1), float(cx - 1), float(middle + 2), 1, 5);
        build.solid(pit_x0 - 1, middle - 1, 0, pit_x0, middle + 2, 1);
        for y in range(middle - 1, middle + 2) {
            build.keep(arena, pit_x0 - 1, y, 1);
            build.keep(arena, cx - 1, y, 1);
            build.keep(arena, cx + 1, y, 1);
            build.keep(arena, ledge_x, y, 2);
        }
        if self.paired {
            # Both buttons on the ring pressed draw the bridges up.
            both = build.tally(2, "The bridges rise");
            build.push(3.0, 1.0, 1.2, 1) +>:Fires:+> both;
            build.push(3.0, float(self.wide - 1), 1.2, 3) +>:Fires:+> both;
            both +>:Fires:+> far_bridge;
            both +>:Fires:+> near_bridge;
        } else {
            shot = build.push(float(self.long - 1), float(middle) + 5.5, 8.0, 2, True);
            shot +>:Fires:+> far_bridge;
            shot +>:Fires:+> near_bridge;
            build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 6.0, True, "Shoot the button over the far ledge");
        }
        # As a gate, a key door across the far ledge's mouth.
        if self.key {
            build.solid(self.long - 7, 1, 2, self.long - 6, middle - 2, self.tall);
            build.solid(self.long - 7, middle + 2, 2, self.long - 6, self.wide - 1, self.tall);
            build.solid(self.long - 7, middle - 2, 10, self.long - 6, middle + 2, self.tall);
            build.rising_door(float(self.long - 7), float(middle - 2), 2.0, float(self.long - 6), float(middle + 2), 10.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(float(self.long) - 3.5, float(middle), 2);
        # Crossing onto the island wakes what waits in the arena and brings a
        # shambler's worth in behind.
        onto = build.touch(float(cx - 1), float(middle - 1), 1.0, float(cx + 2), float(middle + 2), 7.0);
        roused = build.waiting();
        onto +>:Fires:+> roused;
        onto +>:Fires:+> build.summon(2, 2, -9, e1m7_foe(dice, self.danger), 3.0, float(middle) + 0.5, 0, 0.0);
        for index in range(1 if self.danger < 0.5 else 2) {
            build.foe(float(ledge_x) + 2.5, float(middle) - 4.5 + float(index) * 9.0, 2, e1m7_foe(dice, self.danger, index == 0), 180.0, waits=roused);
        }
        # What the shamblers want: a rocket launcher and rockets at the mouth.
        build.supply(3.5, float(middle) + 0.5, 0, "weapon_rocketlauncher");
        build.supply(3.5, float(middle) + 2.5, 0, "item_rockets");
        build.supply(3.5, float(middle) - 1.5, 0, "item_rockets");
        for index in range(dice.between(2, 3)) {
            build.foe(3.0, 4.5 + float(index) * 6.0, 0, e1m7_foe(dice, self.danger), 0.0);
        }
        build.foe(3.0, 3.0, 0, "monster_zombie", 0.0, patrol=[[3.0, 3.0], [float(ledge_x) - 2.0, 3.0]]);
        # Rocks about the ring.
        rocks = [[0, middle - 4, 5, middle + 4], [0, 0, 5, 3], [0, self.wide - 3, 5, self.wide], [2, 2, 4, self.wide - 2], [ledge_x - 2, 0, self.long, self.wide], [0, 2, ledge_x, 4]];
        low_rocks(build, dice, 1, 1, ledge_x - 1, self.wide - 1, 0, dice.between(10, 13), 2, rocks);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_cells");
        build.supply(float(self.long) - 2.5, 2.5, 2, "item_armor2");
    }
}

"""e1m7's stretches: [name, role] (its own keys are none; its vault and
gate keep the run's)."""
glob E1M7_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["descent", "flow"],
         ["junction", "hub"],
         ["electrodes", "flow"],
         ["pillars", "flow"],
         ["vault", "keyroom"],
         ["arena", "end"],
         ["arena", "gate"]
     ];

"""One of e1m7's stretches by its name."""
def make_e1m7(name: str, key: str) -> Prefab {
    if name == "approach" {
        return ChthonApproach();
    }
    if name == "descent" {
        return ChthonDescent();
    }
    if name == "junction" {
        return TeleportJunction();
    }
    if name == "electrodes" {
        return ElectrodeWalk();
    }
    if name == "pillars" {
        return LavaPillars();
    }
    if name == "vault" {
        return RuneVault(key=key if key else "key_silver");
    }
    return ChthonArena(key=key);
}
