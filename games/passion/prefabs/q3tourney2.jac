"""Prefabs drawn from Quake III's q3tourney2, The Proving Grounds: a
gothic keep in four floors, a pit at its foot whose jump pads throw a
body up to the high walks, galleries over arcades round its courts,
stairs that double back on themselves, teleporters from the top back
down, fires burning in troughs and braziers that flare now and then. Quake III's arenas hold no foes of
their own; q3tourney2's are knight, ogre, hell_knight. Raised in
q3tourney2's own palette.

- `ProvingGate`: the start. A hall, a gallery over the way in up a stair
  along one wall (the lightning gun up there), and by the seed a sunken
  way down steps at the far end. Climbing the stair wakes the gallery.
- `ProvingRing`: a sunken ring to fight in, a walk round it, stairs down
  at opposite corners; from the ring's floor pads (one or two) throw a
  body up to a balcony across the far end, over the walk, and from it a
  teleporter (or a drop) back down.
- `SwitchbackHall`: a stair hall: a flight up one wall to a landing across
  the far end, a flight flying back over the floor along the other wall to
  a gallery high over the way in (which wall first by the seed), a drop
  (or a teleporter) back down from it.
- `ProvingCourt`: the hub. A court, galleries on three sides over arcades
  of columns, a stair up to them, a sunken pit in its middle with a pad
  from it up to the far gallery, a balcony high over that one thrown up
  to from a side gallery, and a teleporter from the balcony to the court.
- `TrialShrine`: the key room. A ledge over a pit, a stair down into it,
  the key on a shrine high across the pit's far side thrown up to by a
  pad from the pit's floor; a fire in a trough along the pit; taking the
  key opens the closets on the ledge; a teleporter (or a drop) back.
- `ProvingEnd`: the end (or a gate, the door a key's). A hall, a chamber,
  the way out on a dais high across its far end, a pad up (and by the
  seed a stair), fire burning in front of the dais."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .common { key_ambush }
import from .q3late_parts { deck, keep_box, hurt, throw, wake_later, flying_stair, columns }

glob Q3TOURNEY2: str = "q3:q3tourney2",
     Q3TOURNEY2_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3TOURNEY2_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for q3tourney2's stretches."""
def proving_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3TOURNEY2_LIGHT, Q3TOURNEY2_HEAVY, strong);
}

"""A brazier's fire flaring up now and then at (x, y), `z` lifts up: a
timer firing a harmless burst (the original's looping fires)."""
def flare(build: Raising, x: float, y: float, z: float, seconds: float) {
    build.timer(seconds) +>:Fires:+> build.explosion(x, y, z);
}

"""The start: a hall, a gallery over the way in up a stair, a sunken way
at the far end by the seed."""
node ProvingGate(Prefab) {
    has gallery: int = 10,
        side: int = 0,
        sunk: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Proving gate";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(10, 11);
        self.side = dice.below(2);
        self.sunk = dice.chance(0.6);
        self.tall = self.gallery + 8;
        self.low = -5 if self.sunk else -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        gface = 1 if self.side == 0 else 3;
        oy = self.wide - 5 if self.side == 0 else 1;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=gface, along=4.5, floor=self.gallery), Port(face=0, along=float(oy) + 2.0, floor=-4) if self.sunk else Port(face=gface, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery over the way in, its stair up the side wall.
        deck(build, 1, 1, 9, self.wide - 1, g, 2);
        sy = 1 if self.side == 0 else self.wide - 4;
        stair(build, 8 + g, sy, 0, 2, g, 3);
        keep_box(build, hall, 8, sy, 9, sy + 3, g);
        columns(build, [[8, y] for y in range(4, self.wide - 4, 4) if y < middle - 3 or y > middle + 2], 0, g - 2);
        if self.sunk {
            # The sunken way: steps down along the other wall at the far end.
            oy = self.wide - 5 if self.side == 0 else 1;
            build.widen(hall, self.long - 9, oy, -4, self.long - 1, oy + 4, 0);
            build.level(hall, -4);
            stair(build, self.long - 6, oy, -4, 2, 4, 4);
            build.foe(float(self.long) - 3.0, float(oy) + 2.0, -4, proving_foe(dice, self.danger), 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(3.0, py, g, "weapon_lightning", "q3");
        build.supply(5.0, py + 2.0, g, "ammo_lightning", "q3");
        for index in range(3) {
            build.supply(float(12 + index * 3) + 0.5, py, 0, "item_armor_shard", "q3");
        }
        build.foe(float(self.long) - 4.5, py, 0, proving_foe(dice, self.danger), 180.0);
        flare(build, 2.0, 2.0, 1.0, 5.0);
        flare(build, 2.0, float(self.wide) - 2.0, 1.0, 6.0);
        # Halfway up the stair, the gallery's guards come to meet the climber.
        climb = build.touch(float(8 + g // 2 - 1), float(sy), 1.0, float(8 + g // 2 + 1), float(sy + 3), float(g // 2 + 6));
        guards = wake_later(build, climb, 0.5);
        build.foe(4.0, float(self.wide) - float(sy) - 2.5, g, proving_foe(dice, self.danger, True), 0.0, waits=guards);
        build.supply(float(self.long) - 3.0, 3.0 if self.side == 1 else float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""A sunken ring, a walk round it, stairs down at opposite corners, pads
from its floor up to a balcony across the far end."""
node ProvingRing(Prefab) {
    has deep: int = 6,
        balcony: int = 10,
        two_pads: bool = False,
        tele: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Proving ring";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.deep = dice.between(6, 7);
        self.balcony = 10;
        self.two_pads = dice.chance(0.5);
        self.tele = dice.chance(0.5);
        self.tall = self.balcony + 10;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deep;
        low = -d;
        b = self.balcony;
        cy = self.wide // 2;
        ring = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(ring, 0);
        build.level(ring, b);
        # The walk round the ring, and the stairs down at opposite corners.
        build.solid(1, 1, low, self.long - 1, 5, 0);
        build.solid(1, self.wide - 5, low, self.long - 1, self.wide - 1, 0);
        build.solid(1, 5, low, 5, self.wide - 5, 0);
        build.solid(self.long - 5, 5, low, self.long - 1, self.wide - 5, 0);
        stair(build, 4 + d, 5, low, 2, d, 3);
        stair(build, self.long - 5 - d, self.wide - 8, low, 0, d, 3);
        # The balcony across the far end over the walk, the pads up to it.
        deck(build, self.long - 5, 1, self.long - 1, self.wide - 1, b, 2);
        throw(build, ring, float(self.long) - 9.0, float(cy) - 2.5, low, float(self.long) - 3.0, float(cy) - 2.5, b, None, [self.long - 5, cy - 5, self.long - 4, cy + 2]);
        if self.two_pads {
            throw(build, ring, float(self.long) - 9.0, float(cy) + 0.5, low, float(self.long) - 3.0, float(cy) + 0.5, b, None, [self.long - 5, cy - 1, self.long - 4, cy + 3]);
        }
        if self.tele {
            build.teleporter(float(self.long) - 2.5, float(self.wide) - 3.5, b, 3.0, float(cy) + 3.5, 0, 0.0);
        } else {
            keep_box(build, ring, self.long - 5, self.wide - 5, self.long - 4, self.wide - 2, b);
        }
        build.doorway(ring, self.enter);
        for port in self.taken {
            build.doorway(ring, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(9 + index * 3) + 0.5, float(cy) + (2.5 if index % 2 == 0 else -2.5), low, proving_foe(dice, self.danger), 180.0);
        }
        build.foe(3.0, 3.0, 0, proving_foe(dice, self.danger), 0.0, patrol=[[3.0, 3.0], [float(self.long) - 7.0, 3.0]]);
        # Down in the ring, the balcony's guards come to its rail.
        down = build.touch(6.0, 6.0, float(low), float(self.long - 6), float(self.wide - 6), float(low + 4));
        guards = wake_later(build, down, 1.0);
        build.foe(float(self.long) - 2.5, 3.5, b, proving_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 2.5, float(cy) + 3.5, b, proving_foe(dice, self.danger), 180.0, waits=guards);
        # And a while on, a second wave down the stairs into the ring.
        wave = wake_later(build, down, 6.0);
        build.foe(3.0, float(self.wide) - 3.0, 0, proving_foe(dice, self.danger), 0.0, waits=wave);
        flare(build, float(self.long // 2) + 0.5, float(cy) + 0.5, float(low) + 1.0, 7.0);
        build.supply(float(self.long // 2) + 0.5, float(cy) + 0.5, low, Q3_ARMOR, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(cy) - 1.0, b, "ammo_rockets", "q3");
    }
}

"""A stair hall: a flight up one wall to a landing across the far end, a
flight flying back along the other to a gallery high over the way in."""
node SwitchbackHall(Prefab) {
    has side: int = 0,
        tele: bool = False,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Switchback hall";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.side = dice.below(2);
        self.tele = dice.chance(0.4);
        self.tall = 25;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        aface = 3 if self.side == 0 else 1;
        bface = 1 if self.side == 0 else 3;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=8), Port(face=bface, along=3.5, floor=16), Port(face=bface, along=10.0, floor=0), Port(face=aface, along=float(self.long - 4), floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        a0 = 1 if self.side == 0 else self.wide - 4;
        b0 = self.wide - 4 if self.side == 0 else 1;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        build.level(hall, 16);
        # The first flight up one wall, the landing across the far end.
        stair(build, 6, a0, 0, 0, 8, 3);
        deck(build, 14, 1, self.long - 1, self.wide - 1, 8, 2);
        keep_box(build, hall, 14, a0, 15, a0 + 3, 8);
        # The second flight flying back over the floor along the other wall,
        # to the gallery high over the way in.
        flying_stair(build, 13, b0, 8, 2, 8, 3, 2);
        keep_box(build, hall, 14, b0, 15, b0 + 3, 8);
        deck(build, 1, 1, 6, self.wide - 1, 16, 2);
        keep_box(build, hall, 5, b0, 6, b0 + 3, 16);
        if self.tele {
            build.teleporter(3.0, float(middle) + 0.5, 16, float(self.long) - 4.0, float(middle) + 0.5, 8, 180.0);
        } else {
            # A drop off the gallery's edge beside the first flight's foot.
            keep_box(build, hall, 5, a0, 6, a0 + 3, 16);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(10.5, float(middle) + 0.5, 0, proving_foe(dice, self.danger), 180.0);
        # At the first flight's head, the landing's guards come on.
        head = build.touch(12.0, float(a0), 6.0, 16.0, float(a0 + 3), 14.0);
        guards = wake_later(build, head, 1.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, float(middle) + (2.5 if index == 0 else -2.5), 8, proving_foe(dice, self.danger), 180.0, waits=guards);
        }
        build.foe(3.0, float(a0) + 1.5, 16, proving_foe(dice, self.danger, True), 0.0);
        build.supply(3.0, float(b0) + 1.5, 16, Q3_ARMOR, "q3");
        flare(build, float(self.long) - 2.0, float(a0) + 1.5, 9.0, 5.0);
        build.supply(float(self.long) - 3.0, float(b0) + 1.5, 8, Q3_HEALTH, "q3");
        build.supply(3.0, float(middle) + 3.5, 0, "ammo_shells", "q2");
    }
}

"""The hub: a court, galleries on three sides over arcades, a pit in its
middle with a pad up, a high balcony and a teleporter back down."""
node ProvingCourt(Prefab) {
    has gallery: int = 10,
        balcony: int = 18,
        tall: int = 27;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Proving court";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.gallery = 10;
        self.balcony = 18;
        self.tall = 27;
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=self.gallery), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gallery;
        hb = self.balcony;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, g);
        build.level(court, hb);
        build.level(court, -6);
        # The galleries on three sides over arcades of columns.
        deck(build, 1, 1, self.long - 1, 5, g, 2);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g, 2);
        deck(build, self.long - 5, 5, self.long - 1, self.wide - 5, g, 2);
        spots: list[list[int]] = [];
        for x in range(6, self.long - 6, 4) {
            if x > 17 {
                spots.append([x, 4]);
            }
            spots.append([x, self.wide - 5]);
        }
        columns(build, spots, 0, g - 2);
        # The stair up to the -y gallery.
        stair(build, 6, 5, 0, 0, g, 3);
        keep_box(build, court, 3 + g, 4, 6 + g, 5, g);
        # The sunken pit, its stair out, its pad up to the far gallery.
        build.widen(court, cx - 4, cy - 3, -6, cx + 4, cy + 3, 0);
        stair(build, cx + 1, cy - 1, -6, 2, 6, 2);
        throw(build, court, float(cx) + 3.0, float(cy) + 2.0, -6, float(self.long) - 3.0, float(cy) + 2.0, g, None, [self.long - 5, cy - 1, self.long - 4, cy + 4]);
        # The balcony high over the far gallery, a pad up to it from the -y
        # gallery, and a teleporter from it down to the court.
        deck(build, self.long - 4, cy - 4, self.long - 1, cy + 4, hb, 2);
        throw(build, court, float(self.long) - 8.0, 3.0, g, float(self.long) - 2.5, float(cy) - 2.0, hb, None, [self.long - 4, cy - 4, self.long - 1, cy - 3]);
        build.teleporter(float(self.long) - 2.5, float(cy) + 2.5, hb, 4.0, float(cy) + 0.5, 0, 0.0);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.supply(float(self.long) - 2.5, float(cy) - 0.5, hb, "item_armor_combat", "q3");
        build.foe(float(cx) - 2.5, float(cy) + 1.5, -6, proving_foe(dice, self.danger), 0.0);
        build.foe(4.5, float(cy) + 7.5, 0, proving_foe(dice, self.danger), 0.0, patrol=[[4.5, float(cy) + 7.5], [float(self.long) - 7.5, float(cy) + 7.5], [float(self.long) - 7.5, float(cy) - 7.5], [20.5, float(cy) - 7.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx + 6 + index * 3) + 0.5, 3.0, g, proving_foe(dice, self.danger), 90.0);
        }
        # Into the pit, the far galleries' guards come on.
        pit = build.touch(float(cx - 4), float(cy - 3), -6.0, float(cx + 4), float(cy + 3), -2.0);
        guards = wake_later(build, pit, 1.0);
        build.foe(float(self.long) - 3.0, float(cy) + 5.0, g, proving_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0, g, proving_foe(dice, self.danger), 270.0, waits=guards);
        build.supply(3.0, 3.0, g, Q3_HEALTH, "q3");
        build.supply(4.0, float(cy) - 3.5, 0, Q3_HEALTH, "q3");
        flare(build, float(cx) - 4.5, float(cy) - 3.5, 1.0, 5.0);
        flare(build, float(cx) + 4.5, float(cy) + 3.5, 1.0, 6.5);
        build.supply(float(cx) + 0.5, float(cy) - 2.0, -6, "weapon_rocketlauncher", "q3");
    }
}

"""The key room: a ledge over a pit, the key on a shrine high across it
thrown up to by a pad from the pit's floor."""
node TrialShrine(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        tele: bool = False,
        two_pads: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Trial shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.tele = dice.chance(0.5);
        self.two_pads = dice.chance(0.5);
        self.tall = 20;
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
        room = build.room(1, 1, -8, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, 0);
        build.level(room, 10);
        build.doorway(room, self.enter);
        # The ledge, the stair down into the pit, the shrine across it.
        build.solid(1, 1, -8, 10, side, 0);
        stair(build, 17, 1, -8, 2, 8, 3);
        sx = self.long - 7;
        build.solid(sx, 1, -8, self.long - 1, side, 10);
        throw(build, room, float(sx) - 4.0, float(cy) + 0.5, -8, float(sx) + 3.0, float(cy) + 0.5, 10, None, [sx, cy - 2, sx + 1, cy + 3]);
        if self.two_pads {
            throw(build, room, float(sx) - 4.0, float(side) - 3.5, -8, float(sx) + 3.0, float(side) - 3.5, 10, None, [sx, side - 6, sx + 1, side - 1]);
        }
        # The fire in a trough along the pit's far wall.
        hurt(build, 12.0, float(side - 3), -8.0, float(sx - 6), float(side), -6.0, 6);
        flare(build, 14.0, float(side) - 1.5, -7.0, 4.0);
        flare(build, float(sx) - 8.0, float(side) - 1.5, -7.0, 5.5);
        if self.tele {
            build.teleporter(float(self.long) - 2.5, 3.0, 10, 5.0, float(cy) + 0.5, 0, 0.0);
        } else {
            keep_box(build, room, sx, 2, sx + 1, 5, 10);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 10, side, 0, [2, 6], [proving_foe(dice, self.danger, True), proving_foe(dice, self.danger)]);
        build.foe(float(sx) - 5.5, float(cy) - 3.0, -8, proving_foe(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.0, float(side) - 3.0, 10, proving_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(14.0, float(cy) + 0.5, -8, "item_armor_shard", "q3");
    }
}

"""The end (or a gate): a hall, a chamber, the way out on a dais high
across its far end, a pad up and a stair by the seed."""
node ProvingEnd(Prefab) {
    has key: str = "",
        dais: int = 8,
        steps: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Proving end" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY2;
        self.district = level_district(Q3TOURNEY2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.dais = dice.between(7, 8);
        self.steps = dice.chance(0.5);
        self.tall = self.dais + 10;
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
        py = float(middle) + 0.5;
        wall = 8;
        d = self.dais;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, d);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        dx = self.long - 7;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, d);
        throw(build, room, float(dx) - 3.5, py - 4.0, 0, float(dx) + 3.0, py - 4.0, d, None, [dx, middle - 6, dx + 1, middle - 2]);
        if self.steps {
            stair(build, dx - d, middle + 2, 0, 0, d, 3);
            keep_box(build, room, dx, middle + 2, dx + 1, middle + 5, d);
        }
        # Fire burning in front of the dais, either side of the way up.
        hurt(build, float(dx - 2), float(middle - 1), 0.0, float(dx), float(middle + 2), 2.0, 8);
        flare(build, float(dx) - 1.0, float(middle) + 0.5, 1.0, 4.0);
        build.way_out(float(self.long) - 3.5, py, d);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * float(self.wide - 6) / 2.0, d, proving_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, proving_foe(dice, self.danger), 180.0);
        }
        build.foe(float(dx) - 6.5, py + 4.0, 0, proving_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(wall) + 3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""q3tourney2's stretches: [name, role]."""
glob Q3TOURNEY2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["ring", "flow"],
         ["switchback", "flow"],
         ["court", "hub"],
         ["court", "flow"],
         ["shrine", "keyroom"],
         ["end", "end"],
         ["end", "gate"]
     ];

"""One of q3tourney2's stretches by its name."""
def make_q3tourney2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return ProvingGate();
    }
    if name == "ring" {
        return ProvingRing();
    }
    if name == "switchback" {
        return SwitchbackHall();
    }
    if name == "court" {
        return ProvingCourt();
    }
    if name == "shrine" {
        return TrialShrine(key=key if key else "key_silver");
    }
    return ProvingEnd(key=key);
}
