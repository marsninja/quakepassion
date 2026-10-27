"""Prefabs drawn from Quake III's q3dm18, Space Chamber: a station's halls
and chambers in two floors far apart, the lower one's floor and the upper
one's galleries and ring walks round it, thrown up between by jump pads,
windows onto space where the floor drops away into the void, and walks
out over the void between the station's parts. Quake III's arenas hold
no foes of their own; q3dm18's are enforcer, army, shambler. Raised in
q3dm18's own palette.

- `DockingBay`: the start. A bay, a gallery high along one wall over an
  arcade of columns, pads up to it from the floor at its middle and far
  end (and by the seed a lift up its near end); by the seed a trench along
  the other wall drops away into the void, a window onto space. Walking in
  wakes the gallery's guards a moment on.
- `PadChamber`: the great chamber. A ring walk round it high up (by the
  seed broken on one long side, a trench to the void under the gap), a pit
  in the floor's middle with two pads in it that throw a body up to the
  ring and a stair out; pads from the floor's corners up to the ring's
  ends, at one end or the other or both; when the ring is whole, pads up
  on it throw a body across the chamber from one long side to the other.
- `SpaceWalk`: out over the void between two parts of the station: a low
  bridge, broken in the middle and thrown across by a pad (by the seed it
  doglegs past the break), and a high one beside it, thrown up to from the
  near deck (and from near the low one's end), to an upper deck over the
  far one; a lift between the far decks. The break's touch wakes what
  holds the far deck.
- `QuadDais`: the hub. A chamber, a dais in its middle (the quad on it),
  balconies high on two or three walls, a lift up to them, a pad from the
  floor, and from the dais a teleporter (or, by the seed, a pad) up to the
  far balcony. Stepping onto the dais lets loose the balcony's guards.
- `RailPerch`: the key room. The key high on a perch (a pillar in the
  room's middle, or a ledge across its far end) thrown up to by a pad;
  taking it opens the closets; by the seed a window onto the void along
  one wall; a shorting panel sparks.
- `AirlockPortal`: the end (or a gate, the door a key's). An airlock hall,
  a bay with a pit to the void in its floor, the way out on a ledge high
  across the bay's far end, up a pad (or, by the seed, a lift)."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, void_floor, throw, wake_later, columns }

glob Q3DM18: str = "q3:q3dm18",
     Q3DM18_LIGHT: list[str] = ["monster_enforcer", "monster_army"],
     Q3DM18_HEAVY: list[str] = ["monster_shambler"];

"""A foe for q3dm18's stretches."""
def space_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM18_LIGHT, Q3DM18_HEAVY, strong);
}

"""The start: a bay, a gallery high along one wall, a pad up to it, a
trench to the void along the other wall."""
node DockingBay(Prefab) {
    has upper: int = 14,
        gallery: int = 0,
        use_lift: bool = False,
        trench: bool = False,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Docking bay";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.upper = dice.between(14, 16);
        self.gallery = dice.below(2);
        self.use_lift = dice.chance(0.6);
        self.trench = dice.chance(0.6);
        self.tall = self.upper + 10;
        self.low = -11 if self.trench else -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        gmid = 3.5 if self.gallery == 0 else float(self.wide) - 3.5;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=gmid, floor=self.upper), Port(face=3 if self.gallery == 0 else 1, along=float(self.long - 6), floor=self.upper)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(bay, self.upper);
        # The gallery along one wall, on columns along its lip.
        gy0 = 1 if self.gallery == 0 else self.wide - 6;
        gy1 = gy0 + 5;
        lip_y = gy1 - 1 if self.gallery == 0 else gy0;
        out = 1.0 if self.gallery == 0 else -1.0;
        deck(build, 6, gy0, self.long - 1, gy1, self.upper, 2);
        columns(build, [[x, lip_y] for x in range(8, self.long - 2, 5) if (x < 10 or x > 15) and x < self.long - 9], 0, self.upper - 2);
        throw(build, bay, 12.5, float(lip_y) + 0.5 + out * 3.0, 0, 12.5, float(lip_y) + 0.5 - out * 2.0, self.upper, None, [10, lip_y, 15, lip_y + 1]);
        far_x = float(self.long) - 5.5;
        throw(build, bay, far_x, float(lip_y) + 0.5 + out * 3.0, 0, far_x, float(lip_y) + 0.5 - out * 2.0, self.upper, None, [self.long - 8, lip_y, self.long - 3, lip_y + 1]);
        if self.use_lift {
            ly0 = gy0 if self.gallery == 0 else gy1 - 3;
            lift(build, 3, ly0, 6, ly0 + 3, 0, self.upper);
            keep_box(build, bay, 6, ly0, 7, ly0 + 3, self.upper);
        }
        if self.trench {
            # A window onto space: the floor along the other wall drops away
            # into the void, whose teleporter sends a body back to the door.
            ty0 = self.wide - 5 if self.gallery == 0 else 1;
            build.widen(bay, 8, ty0, -10, self.long - 3, ty0 + 4, 0);
            build.level(bay, -10);
            void_floor(build, 8, ty0, self.long - 3, ty0 + 4, -10, 3.0, py, 0, 0.0);
            build.supply(float(self.long) - 6.5, float(ty0) + (-1.5 if self.gallery == 0 else 5.5), 0, "weapon_rocketlauncher", "q3");
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        gy = float(gy0) + 2.5;
        build.supply(float(self.long) - 4.0, gy, self.upper, Q3_ARMOR, "q3");
        build.foe(float(self.long) - 3.5, py + out * 2.0, 0, space_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 6.5, gy, self.upper, space_foe(dice, self.danger, True), 180.0);
        # A few steps in, the gallery's guards come out a moment on.
        walked = build.touch(8.0, 1.0, 0.0, 10.0, float(self.wide - 1), 6.0);
        guards = wake_later(build, walked, 2.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(16 + index * 5) + 0.5, gy, self.upper, space_foe(dice, self.danger), 180.0, waits=guards);
        }
        build.supply(float(self.long) - 3.5, py - out * 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""The great chamber: a ring walk round it high up, a pit in the floor's
middle with pads up to the ring."""
node PadChamber(Prefab) {
    has upper: int = 14,
        open_side: int = 0,
        corner_pads: bool = False,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pad chamber";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.upper = dice.between(14, 16);
        self.open_side = [0, 1, 3][dice.below(3)];
        self.corner_pads = dice.chance(0.5);
        self.tall = self.upper + 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        up_face = 3 if self.open_side == 1 else 1;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.upper),
            Port(face=up_face, along=float(self.long // 2 + 5), floor=self.upper),
            Port(face=0, along=4.0 if up_face == 1 else float(self.wide - 4), floor=0),
            Port(face=up_face, along=float(self.long // 2 - 6), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        u = self.upper;
        ring = 4;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=self.open_side != 0);
        build.level(hall, u);
        build.level(hall, -6);
        # The ring walk, but on the open side.
        if self.open_side != 3 {
            deck(build, 1, 1, self.long - 1, 1 + ring, u, 2);
        }
        if self.open_side != 1 {
            deck(build, 1, self.wide - 1 - ring, self.long - 1, self.wide - 1, u, 2);
        }
        deck(build, 1, 1 + ring, 1 + ring, self.wide - 1 - ring, u, 2);
        deck(build, self.long - 1 - ring, 1 + ring, self.long - 1, self.wide - 1 - ring, u, 2);
        # Under the open side, a trench to the void: a window onto space.
        if self.open_side != 0 {
            ty0 = self.wide - 5 if self.open_side == 1 else 1;
            build.widen(hall, 7, ty0, -8, self.long - 7, ty0 + 4, 0);
            build.level(hall, -8);
            void_floor(build, 7, ty0, self.long - 7, ty0 + 4, -8, 3.0, float(cy) + 0.5, 0, 0.0);
        }
        # The pit, its stair out and its two pads up to the ring.
        build.widen(hall, cx - 4, cy - 3, -6, cx + 4, cy + 3, 0);
        stair(build, cx + 2, cy + 2, -6, 3, 6, 2);
        if self.open_side != 3 {
            throw(build, hall, float(cx) - 2.0, float(cy) - 1.0, -6, float(cx) - 2.0, 2.5, u, None, [cx - 4, ring, cx + 1, ring + 1]);
        } else {
            throw(build, hall, float(cx) - 2.0, float(cy) - 1.0, -6, float(self.long) - 3.0, float(cy) - 1.0, u, None, [self.long - 1 - ring, cy - 3, self.long - ring, cy + 1]);
        }
        if self.open_side != 1 {
            throw(build, hall, float(cx) - 2.0, float(cy) + 1.0, -6, float(cx) - 2.0, float(self.wide) - 2.5, u, None, [cx - 4, self.wide - 1 - ring, cx + 1, self.wide - ring]);
        } else {
            throw(build, hall, float(cx) - 2.0, float(cy) + 1.0, -6, 3.0, float(cy) + 1.0, u, None, [ring, cy - 1, ring + 1, cy + 3]);
        }
        # Pads from the floor's corners up to the ring's ends, at the near
        # end or the far end by the seed (and both, now and then).
        if self.corner_pads or dice.chance(0.4) {
            throw(build, hall, float(ring) + 4.5, float(cy) + 5.0, 0, 3.0, float(cy) + 5.0, u, None, [ring, cy + 3, ring + 1, cy + 7]);
        }
        if not self.corner_pads or dice.chance(0.4) {
            throw(build, hall, float(self.long - ring) - 4.5, float(cy) - 5.0, 0, float(self.long) - 3.0, float(cy) - 5.0, u, None, [self.long - 1 - ring, cy - 7, self.long - ring, cy - 3]);
        }
        if self.open_side == 0 {
            # Up on the ring, pads across the chamber from one long side to
            # the other, over the floor, each way.
            throw(build, hall, float(cx) + 6.5, 2.5, u, float(cx) + 6.5, float(self.wide) - 2.5, u, [cx + 5, ring, cx + 9, ring + 1], [cx + 5, self.wide - 1 - ring, cx + 9, self.wide - ring]);
            throw(build, hall, float(cx) + 10.5, float(self.wide) - 2.5, u, float(cx) + 10.5, 2.5, u, [cx + 9, self.wide - 1 - ring, cx + 12, self.wide - ring], [cx + 9, ring, cx + 12, ring + 1]);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.supply(float(cx) - 3.0, float(cy) + 0.5, -6, "item_armor_body", "q3");
        build.supply(float(cx) - 0.5, float(cy) + 2.0, -6, Q3_HEALTH, "q3");
        build.foe(float(cx) + 3.0, float(cy) - 2.0, -6, space_foe(dice, self.danger), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 7) + 0.5, 4.5 + float(index) * float(self.wide - 9) / 2.0, 0, space_foe(dice, self.danger), 180.0);
        }
        # Out on the floor, the ring's guards come round a moment on.
        walked = build.touch(6.0, 6.0, 0.0, 9.0, float(self.wide - 6), 6.0);
        guards = wake_later(build, walked, 2.5);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, u, space_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(3.0, float(cy) + 3.5, u, space_foe(dice, self.danger), 0.0, waits=guards);
        build.supply(float(self.long) - 3.0, float(cy) + 3.5, u, Q3_HEALTH, "q3");
        build.supply(3.0, float(cy) - 3.5, u, "ammo_rockets", "q3");
    }
}

"""Out over the void: a low bridge broken in the middle and thrown across
by a pad, a high one beside it to an upper deck over the far one."""
node SpaceWalk(Prefab) {
    has deep: int = 10,
        upper: int = 9,
        upper_first: bool = False,
        twist: bool = False,
        brk: int = 16,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Space walk";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(34, 38);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(10, 12);
        self.upper = dice.between(8, 10);
        self.upper_first = dice.chance(0.5);
        self.twist = dice.chance(0.5);
        self.brk = self.long // 2 - 2 + dice.between(-2, 2);
        self.tall = self.upper + 10;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 4) if self.upper_first else 4.0, floor=self.upper), Port(face=3 if self.upper_first else 1, along=float(self.long - 4), floor=self.upper)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -self.deep;
        u = self.upper;
        walk = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(walk, 0);
        build.level(walk, u);
        if self.upper_first {
            uy0 = 2;
            ly0 = 8;
            ly1 = ly0 + (3 if self.twist else 0);
        } else {
            uy0 = self.wide - 5;
            ly0 = self.wide - 12;
            ly1 = ly0 - (3 if self.twist else 0);
        }
        far = self.long - 8;
        g = self.brk;
        # The near deck, the far decks one over the other, a lift between.
        deck(build, 1, 1, 10, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, u, 2);
        build.widen(walk, self.long - 7, middle - 1, u - 2, self.long - 4, middle + 2, u);
        lift(build, self.long - 7, middle - 1, self.long - 4, middle + 2, 0, u);
        keep_box(build, walk, far, middle - 2, self.long - 1, middle - 1, u);
        keep_box(build, walk, far, middle + 2, self.long - 1, middle + 3, u);
        keep_box(build, walk, far, uy0, far + 1, uy0 + 3, u);
        # The low bridge, broken in the middle, a pad across the break.
        deck(build, 10, ly0, g, ly0 + 4, 0, 2);
        deck(build, g + 6, ly1, far, ly1 + 4, 0, 2);
        throw(build, walk, float(g) - 2.5, float(ly0) + 2.0, 0, float(g) + 8.5, float(ly1) + 2.0, 0, [g - 1, ly0, g, ly0 + 4], [g + 6, ly1, g + 7, ly1 + 4]);
        # The high bridge beside it, thrown up to from the near deck.
        deck(build, 12, uy0, far, uy0 + 3, u, 2);
        throw(build, walk, 5.5, float(uy0) + 1.5, 0, 15.5, float(uy0) + 1.5, u, None, [12, uy0, 13, uy0 + 3]);
        # Near the low bridge's end, a pad back up and over to the high one.
        throw(build, walk, float(far) - 3.5, float(ly1) + 2.0, 0, float(far) - 11.0, float(uy0) + 1.5, u, None, [far - 13, uy0, far - 9, uy0 + 3]);
        outer = uy0 if self.upper_first else uy0 + 2;
        keep_box(build, walk, g, outer, g + 3, outer + 1, u);
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 3.5, py, 0, 0.0, 14);
        build.doorway(walk, self.enter);
        for port in self.taken {
            build.doorway(walk, port);
        }
        build.supply(float(g) + 1.5, float(uy0) + 1.5, u, Q3_ARMOR, "q3");
        build.supply(float(g) + 4.5, float(uy0) + 1.5, u, Q3_HEALTH, "q3");
        build.supply(float(far) - 2.0, float(ly1) + 2.0, 0, "ammo_rockets", "q3");
        build.foe(float(g) - 5.5, float(ly0) + 2.0, 0, space_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(uy0) + 1.5, u, space_foe(dice, self.danger, True), 180.0);
        build.foe(float(far) - 4.5, float(uy0) + 1.5, u, space_foe(dice, self.danger), 180.0);
        # At the break, what holds the far deck comes on.
        brink = build.touch(float(g - 3), float(ly0), 0.0, float(g), float(ly0 + 4), 6.0);
        far_side = wake_later(build, brink, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.0 + float(index) * float(self.wide - 6) / 2.0, 0, space_foe(dice, self.danger), 180.0, waits=far_side);
        }
        build.supply(float(self.long) - 3.5, float(ly1) + 2.0, 0, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, "ammo_bullets", "q2");
    }
}

"""The hub: a chamber, a dais in its middle, balconies high on two or
three walls, a lift and pads up, a teleporter (or a pad) from the dais."""
node QuadDais(Prefab) {
    has upper: int = 12,
        three: bool = False,
        tele: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Quad dais";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.upper = dice.between(12, 14);
        self.three = dice.chance(0.5);
        self.tele = dice.chance(0.6);
        self.tall = self.upper + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.upper),
            Port(face=1, along=float(self.long // 2), floor=self.upper),
            Port(face=3, along=float(self.long // 2), floor=self.upper if self.three else 0),
            Port(face=0, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        cx = (self.long - 6) // 2;
        u = self.upper;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 2);
        build.level(hall, u);
        # The balconies: across the far end, along the +y wall, and by the
        # seed along the -y wall too.
        deck(build, self.long - 6, 1, self.long - 1, self.wide - 1, u, 2);
        deck(build, 8, self.wide - 6, self.long - 6, self.wide - 1, u, 2);
        if self.three {
            deck(build, 8, 1, self.long - 6, 6, u, 2);
            throw(build, hall, float(cx) + 6.0, 9.5, 0, float(cx) + 6.0, 3.5, u, None, [cx + 4, 5, cx + 9, 6]);
        }
        # The lift up to the +y balcony's end.
        lift(build, 5, self.wide - 4, 8, self.wide - 1, 0, u);
        keep_box(build, hall, 8, self.wide - 4, 9, self.wide - 1, u);
        # A pad from the floor up to the +y balcony.
        throw(build, hall, float(cx) + 6.0, float(self.wide) - 9.5, 0, float(cx) + 6.0, float(self.wide) - 3.5, u, None, [cx + 4, self.wide - 6, cx + 9, self.wide - 5]);
        # The dais, stepped up to at both ends; from it up to the far
        # balcony by a teleporter, or a pad.
        build.solid(cx - 3, cy - 3, 0, cx + 4, cy + 4, 2);
        stair(build, cx - 5, cy - 1, 0, 0, 2, 3);
        stair(build, cx + 5, cy - 1, 0, 2, 2, 3);
        if self.tele {
            build.teleporter(float(cx) + 0.5, float(cy) + 2.0, 2, float(self.long) - 3.0, float(cy) + 0.5, u, 180.0);
        } else {
            throw(build, hall, float(cx) + 2.5, float(cy) + 2.0, 2, float(self.long) - 3.0, float(cy) + 2.0, u, None, [self.long - 6, cy, self.long - 5, cy + 4]);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.supply(float(cx) + 0.5, float(cy) - 1.5, 2, "item_quad", "q3");
        # A guard walks round the dais; others hold the floor's corners.
        build.foe(float(cx) - 6.5, float(cy) - 6.5, 0, space_foe(dice, self.danger), 0.0, patrol=[[float(cx) - 6.5, float(cy) - 6.5], [float(cx) + 7.5, float(cy) - 6.5], [float(cx) + 7.5, float(cy) + 5.5], [float(cx) - 6.5, float(cy) + 5.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 8.5, 3.5 + float(index) * 5.0, 0, space_foe(dice, self.danger), 180.0);
        }
        # Up on the dais, the balconies' guards let loose.
        dais = build.touch(float(cx - 3), float(cy - 3), 2.0, float(cx + 4), float(cy + 4), 8.0);
        guards = build.waiting();
        dais +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, 4.5, u, space_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(cx) + 2.5, float(self.wide) - 3.0, u, space_foe(dice, self.danger), 270.0, waits=guards);
        if self.three {
            build.foe(float(cx) + 2.5, 3.0, u, space_foe(dice, self.danger), 90.0, waits=guards);
        }
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.5, u, "item_health_mega", "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) - 6.5, float(cy) + 5.5, 0, "ammo_slugs", "q3");
        build.supply(float(cx) + 0.5, float(self.wide) - 3.0, u, "weapon_railgun", "q3");
    }
}

"""The key room: the key high on a perch thrown up to by a pad."""
node RailPerch(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        upper: int = 11,
        far_ledge: bool = False,
        window: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rail perch (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.upper = dice.between(10, 13);
        self.far_ledge = dice.chance(0.5);
        self.window = dice.chance(0.5);
        self.tall = self.upper + 9;
        self.low = -11 if self.window else -1;
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
        u = self.upper;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=self.window);
        build.level(room, u);
        build.doorway(room, self.enter);
        if self.far_ledge {
            px0 = self.long - 7;
            build.solid(px0, 1, 0, self.long - 1, side, u);
            key_x = float(self.long) - 3.0;
        } else {
            px0 = self.long // 2 - 1;
            build.solid(px0, cy - 2, 0, px0 + 6, cy + 3, u);
            key_x = float(px0) + 3.5;
        }
        throw(build, room, float(px0) - 3.0, float(cy) + 0.5, 0, float(px0) + 2.5, float(cy) + 0.5, u, [px0 - 1, cy - 1, px0, cy + 2], [px0, cy - 1, px0 + 1, cy + 2]);
        # A drop back down off the perch's near edge.
        keep_box(build, room, px0, cy - 2, px0 + 1, cy - 1, u);
        if self.window {
            # A window onto space along the wall across from the closets:
            # the floor drops away into the void there.
            build.widen(room, 6, 1, -10, px0 - 1, 5, 0);
            build.level(room, -10);
            void_floor(build, 6, 1, px0 - 1, 5, -10, 3.0, float(cy) + 0.5, 0, 0.0, 8);
        }
        key_ambush(build, self.key, key_x, float(cy) + 0.5, u, side, 0, [2, 7], [space_foe(dice, self.danger, True), space_foe(dice, self.danger)]);
        build.foe(key_x, float(cy) + 2.5, u, space_foe(dice, self.danger), 180.0);
        build.foe(float(px0) - 4.5, float(side) - 3.0, 0, space_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(px0) - 2.0, float(cy) + 3.5, 0, "ammo_rockets", "q3");
        # A shorting panel by the door, sparking now and then.
        build.timer(5.0) +>:Fires:+> build.sparks(1.2, float(side) - 2.5, 3.0, 0);
    }
}

"""The end (or a gate): an airlock hall, a bay with a pit to the void, the
way out on a ledge high across its far end."""
node AirlockPortal(Prefab) {
    has key: str = "",
        upper: int = 9,
        use_lift: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Airlock portal" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM18;
        self.district = level_district(Q3DM18);
        self.long = dice.between(30, 32);
        self.wide = dice.between(20, 22);
        self.upper = dice.between(8, 10);
        self.use_lift = dice.chance(0.5);
        self.tall = self.upper + 10;
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
        py = float(middle) + 0.5;
        u = self.upper;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        bay = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(bay, u);
        build.doorway(hall, self.enter);
        build.widen(bay, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The pit to the void in the bay's floor.
        lx = self.long - 8;
        build.widen(bay, wall + 4, middle - 3, -8, lx - 5, middle + 4, 0);
        build.level(bay, -8);
        void_floor(build, wall + 4, middle - 3, lx - 5, middle + 4, -8, float(wall) + 2.0, py, 0, 0.0, 8);
        # The ledge high across the far end, and the way up to it.
        deck(build, lx, 1, self.long - 1, self.wide - 1, u, 2);
        throw(build, bay, float(lx) - 3.0, float(middle) - 3.5, 0, float(lx) + 3.0, float(middle) - 3.5, u, None, [lx, middle - 6, lx + 1, middle - 1]);
        if self.use_lift {
            lift(build, lx - 3, 1, lx, 4, 0, u);
            keep_box(build, bay, lx, 1, lx + 1, 4, u);
        }
        keep_box(build, bay, lx, self.wide - 5, lx + 1, self.wide - 2, u);
        build.way_out(float(self.long) - 3.0, float(middle) + 3.0, u);
        # Through the airlock, the ledge's guards come on.
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, u, space_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, space_foe(dice, self.danger), 180.0);
        }
        build.foe(float(lx) - 2.5, float(self.wide) - 3.5, 0, space_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(2.5, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(lx) - 2.0, 3.0, 0, "ammo_rockets", "q3");
        build.timer(4.0) +>:Fires:+> build.sparks(float(wall) + 0.2, float(middle) + 3.5, 4.0, 0);
    }
}

"""q3dm18's stretches: [name, role]."""
glob Q3DM18_STRETCHES: list[list[str]] = [
         ["bay", "start"],
         ["chamber", "flow"],
         ["walk", "flow"],
         ["dais", "hub"],
         ["dais", "flow"],
         ["perch", "keyroom"],
         ["airlock", "end"],
         ["airlock", "gate"]
     ];

"""One of q3dm18's stretches by its name."""
def make_q3dm18(name: str, key: str) -> Prefab {
    if name == "bay" {
        return DockingBay();
    }
    if name == "chamber" {
        return PadChamber();
    }
    if name == "walk" {
        return SpaceWalk();
    }
    if name == "dais" {
        return QuadDais();
    }
    if name == "perch" {
        return RailPerch(key=key if key else "key_silver");
    }
    return AirlockPortal(key=key);
}
