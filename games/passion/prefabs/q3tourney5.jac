"""Prefabs drawn from Quake III's q3tourney5, Fatal Instinct: a small gothic
arena on three floors: its halls sunk four lifts below their ledges,
walks and galleries eight lifts over the ledges, stairs between, the quad
on a pedestal or by a pool in a sunken court, a touch that starts a
timer (the original's delayed gift, made foes that come a moment after a
body passes). Quake III's arenas hold no foes of their own; q3tourney5's
are knight, zombie, ogre. Raised in q3tourney5's own palette.

- `InstinctGate`: the start. A ledge over a sunken hall, a stair down, a
  ledge along one wall, a walk high along the other up a stair flying
  over the hall (which wall each by the seed).
- `SunkenCourt`: a sunken court between two ledges, a walk high round
  three sides up a flying stair, a pool in its middle (or a pedestal with
  the quad, by the seed).
- `PillarHall`: a hall of columns, mezzanines high along both walls joined
  by a bridge across, a stair (or two) up to the bridge.
- `InstinctCourt`: the hub. A pit in the middle of a ring floor, stairs
  down into it, a gallery high over the ring up stairwells at opposite
  corners, the quad on a pedestal in the pit.
- `QuadShrine`: the key room. A ledge, a sunken shrine, the key on a
  pedestal, a gallery across the far end up a stair from the floor;
  taking the key opens the closets on the ledge.
- `InstinctEnd`: the end (or a gate, the door a key's). A hall, a sunken
  chamber down steps, the way out on a dais at its far end."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, wake_later, flying_stair, columns, floor_slab }

glob Q3TOURNEY5: str = "q3:q3tourney5",
     Q3TOURNEY5_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3TOURNEY5_HEAVY: list[str] = ["monster_ogre"];

"""A foe for q3tourney5's stretches."""
glob INSTINCT_FOES: FoeMix = FoeMix(light=Q3TOURNEY5_LIGHT, strong=Q3TOURNEY5_HEAVY, heavy_light=Q3TOURNEY5_HEAVY, scale=0.5);

"""The start: a ledge over a sunken hall, a ledge along one wall, a walk
high along the other."""
node InstinctGate(Prefab) {
    has side: int = 0,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Instinct gate";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.side = dice.below(2);
        self.tall = 32;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        sy = 1 if self.side == 0 else self.wide - 5;
        wy = self.wide - 5 if self.side == 0 else 1;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-4), Port(face=0, along=float(sy) + 2.0, floor=0), Port(face=0, along=float(wy) + 2.0, floor=8), Port(face=1 if self.side == 0 else 3, along=float(self.long - 4), floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        sy = 1 if self.side == 0 else self.wide - 5;
        wy = self.wide - 5 if self.side == 0 else 1;
        hall = build.room(1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, 8);
        # The ledge the way in opens on, its stair down into the hall.
        build.solid(1, 1, -4, 7, self.wide - 1, 0);
        stair(build, 10, middle - 1, -4, 2, 4, 3);
        # A ledge along one wall, a walk high along the other up a stair
        # flying over the hall.
        build.solid(7, sy, -4, self.long - 1, sy + 4, 0);
        ws = wy + 1 if self.side == 0 else wy;
        flying_stair(build, 4, ws, 0, 0, 8, 3, 2);
        deck(build, 12, wy, self.long - 1, wy + 4, 8, 2);
        keep_box(build, hall, 12, ws, 13, ws + 3, 8);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(float(self.long) - 3.0, py, -4, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(wy) + 2.0, 8, "weapon_plasmagun", "q3");
        build.foe(float(self.long // 2) + 0.5, py, -4, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        # Down the stair, a moment on, the walk's guards come to its edge.
        down = build.touch(7.0, float(middle - 1), -4.0, 11.0, float(middle + 2), 2.0);
        guards = wake_later(build, down, 3.0);
        build.foe(float(self.long) - 5.5, float(wy) + 2.0, 8, INSTINCT_FOES.pick(dice, self.danger), 180.0, waits=guards);
        build.foe(float(self.long) - 4.5, float(sy) + 2.0, 0, INSTINCT_FOES.pick(dice, self.danger), 180.0);
    }
}

"""A sunken court between two ledges, a walk high round three sides, a
pool (or a pedestal) in its middle."""
node SunkenCourt(Prefab) {
    has pool: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sunken court";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.pool = dice.chance(0.5);
        self.tall = 32;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 8), floor=8), Port(face=1, along=float(self.long // 2), floor=-4), Port(face=0, along=3.5, floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        court = build.room(1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, 0);
        build.level(court, 8);
        # The ledges at both ends, stairs down into the court.
        build.solid(1, 1, -4, 6, self.wide - 1, 0);
        build.solid(self.long - 6, 1, -4, self.long - 1, self.wide - 1, 0);
        stair(build, 9, cy - 1, -4, 2, 4, 3);
        stair(build, self.long - 10, cy - 1, -4, 0, 4, 3);
        # The walk round three sides, up a stair flying from the near ledge.
        deck(build, 14, 1, self.long - 1, 6, 8, 2);
        deck(build, self.long - 6, 6, self.long - 1, self.wide - 6, 8, 2);
        deck(build, 8, self.wide - 6, self.long - 1, self.wide - 1, 8, 2);
        flying_stair(build, 6, 1, 0, 0, 8, 3, 2);
        keep_box(build, court, 14, 1, 15, 4, 8);
        keep_box(build, court, 8, self.wide - 6, 9, self.wide - 1, 8);
        if self.pool {
            build.pool(cx - 3, cy - 3, -8, cx + 3, cy + 3, -4, 2);
            build.supply(float(cx) + 0.5, float(cy) + 0.5, -8, "item_quad", "q3");
        } else {
            build.solid(cx - 2, cy - 2, -4, cx + 2, cy + 2, -2);
            stair(build, cx - 4, cy - 1, -4, 0, 2, 2);
            build.supply(float(cx) + 0.5, float(cy) + 0.5, -2, "item_quad", "q3");
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 5 + index * 4) + 0.5, float(cy) + (5.0 if index % 2 == 0 else -5.0), -4, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        }
        # Down in the court, a moment on, the walk's guards come round.
        down = build.touch(9.0, 6.0, -4.0, float(self.long - 9), float(self.wide - 6), 0.0);
        guards = wake_later(build, down, 3.0);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 8, INSTINCT_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(18.5, 3.5, 8, INSTINCT_FOES.pick(dice, self.danger), 90.0, waits=guards);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.5, 8, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, 0, "ammo_cells", "q3");
    }
}

"""A hall of columns, mezzanines high along both walls joined by a bridge
across, a stair (or two) up to the bridge."""
node PillarHall(Prefab) {
    has bx: int = 13,
        both: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pillar hall";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.bx = self.long // 2 + dice.between(1, 2);
        self.both = dice.chance(0.5);
        self.tall = 32;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=8), Port(face=3, along=float(self.long - 4), floor=8), Port(face=0, along=3.5, floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        bx = self.bx;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        # The mezzanines on arcades of columns, the bridge between them.
        deck(build, 1, 1, self.long - 1, 6, 8, 2);
        deck(build, 1, self.wide - 6, self.long - 1, self.wide - 1, 8, 2);
        deck(build, bx - 2, 6, bx + 2, self.wide - 6, 8, 2);
        spots: list[list[int]] = [];
        for x in range(4, self.long - 3, 4) {
            if x < bx - 3 or x > bx + 2 {
                spots.append([x, 5]);
                spots.append([x, self.wide - 6]);
            }
        }
        columns(build, spots, 0, 6);
        # The stair (or two) up to the bridge.
        stair(build, bx - 10, middle - 1, 0, 0, 8, 3);
        keep_box(build, hall, bx - 2, middle - 1, bx - 1, middle + 2, 8);
        if self.both {
            stair(build, bx + 9, middle - 1, 0, 2, 8, 3);
            keep_box(build, hall, bx + 1, middle - 1, bx + 2, middle + 2, 8);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(self.long) - 4.5, py, 0, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(middle) + 3.5, 0, INSTINCT_FOES.pick(dice, self.danger), 0.0, patrol=[[3.5, float(middle) + 3.5], [float(self.long) - 4.5, float(middle) + 3.5]]);
        # On the bridge, a moment on, the mezzanines' guards come on.
        bridge = build.touch(float(bx - 2), 6.0, 8.0, float(bx + 2), float(self.wide - 6), 14.0);
        guards = wake_later(build, bridge, 2.0);
        build.foe(float(self.long) - 3.5, 3.5, 8, INSTINCT_FOES.pick(dice, self.danger), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 8, INSTINCT_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.supply(3.0, 3.5, 8, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.5, 8, "weapon_rocketlauncher", "q3");
        build.supply(float(bx) + 0.5, py, 8, Q3_ARMOR, "q3");
    }
}

"""The hub: a pit in the middle of a ring floor, a gallery high over the
ring up stairwells at opposite corners, the quad in the pit."""
node InstinctCourt(Prefab) {
    has tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Instinct court";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = 34;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=6.0, floor=10), Port(face=3, along=float(self.long - 4), floor=10), Port(face=0, along=3.5, floor=10)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        court = build.room(1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(court, 0);
        build.level(court, 10);
        # The ring floor round the pit, stairs down into it either end.
        build.solid(1, 1, -4, self.long - 1, 5, 0);
        build.solid(1, self.wide - 5, -4, self.long - 1, self.wide - 1, 0);
        build.solid(1, 5, -4, 5, self.wide - 5, 0);
        build.solid(self.long - 5, 5, -4, self.long - 1, self.wide - 5, 0);
        stair(build, 8, cy - 1, -4, 2, 4, 3);
        stair(build, self.long - 9, cy - 1, -4, 0, 4, 3);
        # The gallery over the ring, up stairwells at opposite corners.
        floor_slab(build, court, 1, 1, self.long - 1, self.wide - 1, 10, [[5, 5, self.long - 5, self.wide - 5], [5, 1, 16, 4], [self.long - 15, self.wide - 4, self.long - 5, self.wide - 1]]);
        stair(build, 6, 1, 0, 0, 10, 3);
        keep_box(build, court, 16, 1, 17, 4, 10);
        stair(build, self.long - 6, self.wide - 4, 0, 2, 10, 3);
        keep_box(build, court, self.long - 16, self.wide - 4, self.long - 15, self.wide - 1, 10);
        # The quad on a pedestal in the pit.
        build.solid(cx - 2, cy - 2, -4, cx + 2, cy + 2, -2);
        stair(build, cx + 3, cy - 1, -4, 2, 2, 2);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.supply(float(cx) + 0.5, float(cy) + 0.5, -2, "item_quad", "q3");
        build.foe(float(cx) - 5.5, float(cy) - 4.5, -4, INSTINCT_FOES.pick(dice, self.danger), 0.0, patrol=[[float(cx) - 5.5, float(cy) - 4.5], [float(cx) + 5.5, float(cy) - 4.5], [float(cx) + 5.5, float(cy) + 4.5], [float(cx) - 5.5, float(cy) + 4.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx + 4 * index) + 0.5, float(cy) + 3.0, -4, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 0, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        # In the pit, a moment on, the gallery's guards come to its rail.
        pit = build.touch(6.0, 6.0, -4.0, float(self.long - 6), float(self.wide - 6), 0.0);
        guards = wake_later(build, pit, 3.0);
        build.foe(float(cx) + 0.5, 3.0, 10, INSTINCT_FOES.pick(dice, self.danger, True), 90.0, waits=guards);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0, 10, INSTINCT_FOES.pick(dice, self.danger), 270.0, waits=guards);
        build.supply(3.0, 3.0, 10, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 10, Q3_ARMOR, "q3");
    }
}

"""The key room: a ledge, a sunken shrine, the key on a pedestal, a
gallery across the far end up a stair."""
node QuadShrine(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Quad shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.tall = 32;
        self.low = -5;
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
        shrine = build.room(1, 1, -4, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(shrine, 0);
        build.level(shrine, 6);
        build.doorway(shrine, self.enter);
        build.solid(1, 1, -4, 9, side, 0);
        stair(build, 12, cy - 1, -4, 2, 4, 3);
        # The pedestal, its steps.
        build.solid(self.long - 8, cy - 2, -4, self.long - 4, cy + 3, -2);
        stair(build, self.long - 10, cy - 1, -4, 0, 2, 3);
        # The gallery across the far end, a stair up to it along the wall.
        deck(build, self.long - 5, 1, self.long - 1, side, 6, 2);
        flying_stair(build, self.long - 15, 1, -4, 0, 10, 3, 2);
        keep_box(build, shrine, self.long - 5, 1, self.long - 4, 4, 6);
        keep_box(build, shrine, self.long - 5, side - 4, self.long - 4, side - 1, 6);
        key_ambush(build, self.key, float(self.long) - 6.0, float(cy) + 0.5, -2, side, 0, [2, 6], [INSTINCT_FOES.pick(dice, self.danger, True), INSTINCT_FOES.pick(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, float(cy) + 3.5, 6, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 11.0, float(cy) + 4.0, -4, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, 6, "ammo_rockets", "q3");
    }
}

"""The end (or a gate): a hall, a sunken chamber down steps, the way out
on a dais at its far end."""
node InstinctEnd(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Instinct end" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY5;
        self.district = level_district(Q3TOURNEY5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = 28;
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, 0);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The landing inside the door, its steps down, the dais beyond.
        build.solid(wall + 1, 1, -4, wall + 5, self.wide - 1, 0);
        stair(build, wall + 8, middle - 1, -4, 2, 4, 3);
        build.solid(self.long - 7, 1, -4, self.long - 1, self.wide - 1, 0);
        stair(build, self.long - 11, middle - 1, -4, 0, 4, 3);
        columns(build, [[wall + 9, 3], [wall + 9, self.wide - 4], [self.long - 10, 3], [self.long - 10, self.wide - 4]], -4, 10);
        build.way_out(float(self.long) - 3.5, py, 0);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = wake_later(build, door, 2.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, 0, INSTINCT_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(self.long // 2) + 0.5, py + 3.0, -4, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, INSTINCT_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long // 2) + 0.5, 3.0, -4, Q3_HEALTH, "q3");
    }
}

"""q3tourney5's stretches: [name, role]."""
glob Q3TOURNEY5_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["court", "flow"],
         ["pillars", "flow"],
         ["hub", "hub"],
         ["hub", "flow"],
         ["shrine", "keyroom"],
         ["end", "end"],
         ["end", "gate"]
     ];

"""One of q3tourney5's stretches by its name."""
def make_q3tourney5(name: str, key: str) -> Prefab {
    if name == "gate" {
        return InstinctGate();
    }
    if name == "court" {
        return SunkenCourt();
    }
    if name == "pillars" {
        return PillarHall();
    }
    if name == "hub" {
        return InstinctCourt();
    }
    if name == "shrine" {
        return QuadShrine(key=key if key else "key_silver");
    }
    return InstinctEnd(key=key);
}
