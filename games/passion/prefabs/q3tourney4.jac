"""Prefabs drawn from Quake III's q3tourney4, Vertical Vengeance: a gothic
tower of three floors stacked one over another, fifteen lifts apart, joined
by stairwells, shafts climbed by jump pads and an atrium through all
three to a high roof, its rooms parted by doors that slide aside as a body comes up to
them, torches flaring on timers. Quake III's arenas hold no foes of their
own; q3tourney4's are wizard, ogre, shambler. Raised in q3tourney4's own
palette.

- `TowerBase`: the start. The tower's ground floor, the next over it: a
  stairwell up one wall and a shaft at the far end with a pad up through
  it (which side each by the seed). Taking the stair wakes the floor above.
- `ClimbShaft`: a tall shaft, ledges on alternating walls one over
  another, each thrown up to by a pad from the one below; drops back down
  from the lower two, a pad back down across from the top one.
- `StackedHalls`: three halls stacked exactly, a flight up one wall from
  the first to the second and back along the other to the third (which
  wall first by the seed), each floor parted from its back room, where
  the ways on are, by a door that slides aside.
- `TowerCore`: the hub. An atrium up through all three floors, galleries
  round it on each, a stairwell up to the first gallery, a lift to the
  second, a pad from the atrium's floor up to the first and one across
  the atrium from the first to the second; the mega health up top.
- `TopVault`: the key room. The key on the third floor, a stair up to the
  second, a pad up a shaft to the third, a door before the key; taking it
  opens the closets below, a teleporter back down.
- `TowerTop`: the end (or a gate, the door a key's). A hall, the tower's
  last room, the way out on its roof up a pad (and by the seed a stair)."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .common { stair, key_ambush, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, throw, wake_later, floor_slab, slide_door, columns }

"""Lifts from one of the tower's floors to the next."""
glob STOREY: int = 15;

glob Q3TOURNEY4: str = "q3:q3tourney4",
     Q3TOURNEY4_LIGHT: list[str] = ["monster_wizard", "monster_ogre"],
     Q3TOURNEY4_HEAVY: list[str] = ["monster_shambler"];

"""A foe for q3tourney4's stretches."""
glob TOWER_FOES: FoeMix = FoeMix(light=Q3TOURNEY4_LIGHT, strong=Q3TOURNEY4_HEAVY, heavy_light=Q3TOURNEY4_HEAVY, scale=0.5);

"""A torch flaring now and then at (x, y), `z` lifts up (the original's
timers)."""
def torch(build: Raising, x: float, y: float, z: float, seconds: float) {
    build.timer(seconds) +>:Fires:+> build.explosion(x, y, z);
}

"""A wall across a floor at the cell line x0..x0+1, from the side wall at
y 1 to the one at y wide - 1, from lift z up to the floor over it, with a
sliding door in it at the cells y0..y0+4 (sliding +y into the wall)."""
def door_wall(build: Raising, space: Space, x0: int, wide: int, z: int, y0: int) {
    build.solid(x0, 1, z, x0 + 1, wide - 1, z + STOREY - 2);
    build.widen(space, x0, y0, z, x0 + 1, y0 + 4, z + 8);
    slide_door(build, float(x0), float(y0), float(z), float(x0 + 1), float(y0 + 4), float(z + 8), 1);
}


"""The start: the ground floor, the next over it, a stairwell and a shaft
with a pad up through it."""
node TowerBase(Prefab) {
    has shaft_side: int = 0,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tower base";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.shaft_side = dice.below(2);
        self.tall = STOREY + 16;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        far_along = float(self.wide - 4) if self.shaft_side == 0 else 4.0;
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=far_along, floor=STOREY), Port(face=3 if self.shaft_side == 0 else 1, along=float(self.long // 2), floor=STOREY)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, STOREY);
        sy = 2 if self.shaft_side == 0 else self.wide - 8;
        wy = self.wide - 4 if self.shaft_side == 0 else 1;
        floor_slab(build, hall, 1, 1, self.long - 1, self.wide - 1, STOREY, [[self.long - 8, sy, self.long - 2, sy + 6], [4, wy, 5 + STOREY, wy + 3]]);
        stair(build, 5, wy, 0, 0, STOREY, 3);
        keep_box(build, hall, 5 + STOREY, wy, 6 + STOREY, wy + 3, STOREY);
        throw(build, hall, float(self.long) - 5.0, float(sy) + 3.0, 0, float(self.long) - 11.0, float(sy) + 3.0, STOREY, None, [self.long - 9, sy, self.long - 8, sy + 6]);
        columns(build, [[8, middle - 3], [8, middle + 3], [13, middle - 3], [13, middle + 3]], 0, STOREY - 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(float(self.long) - 5.0, float(sy) + 1.0, 0, Q3_HEALTH, "q3");
        build.supply(4.0, py, STOREY, "weapon_railgun", "q3");
        build.supply(6.0, py + 2.0, STOREY, "ammo_slugs", "q3");
        torch(build, 1.5, float(middle) - 3.5, 4.0, 5.0);
        build.foe(float(self.long) - 4.5, py + (3.0 if self.shaft_side == 0 else -3.0), 0, TOWER_FOES.pick(dice, self.danger), 180.0);
        # Halfway up the stair, the floor above stirs.
        climb = build.touch(9.0, float(wy), 1.0, 11.0, float(wy + 3), float(STOREY));
        above = wake_later(build, climb, 1.0);
        build.foe(10.5, py, STOREY, TOWER_FOES.pick(dice, self.danger), 180.0, waits=above);
        build.foe(float(self.long) - 3.5, float(self.wide) - float(sy) - 3.0, STOREY, TOWER_FOES.pick(dice, self.danger), 180.0);
    }
}

"""A tall shaft, ledges on alternating walls one over another, each thrown
up to by a pad from the one below."""
node ClimbShaft(Prefab) {
    has side: int = 0,
        tall: int = 34;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Climb shaft";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.side = dice.below(2);
        self.tall = 46;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        ay0 = 1 if self.side == 0 else self.wide - 5;
        by0 = self.wide - 5 if self.side == 0 else 1;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(ay0) + 2.0, floor=10), Port(face=0, along=float(by0) + 2.0, floor=20), Port(face=3 if self.side == 0 else 1, along=float(self.long // 2), floor=30)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cx = self.long // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [10, 20, 30] {
            build.level(shaft, z);
        }
        ay0 = 1 if self.side == 0 else self.wide - 5;
        by0 = self.wide - 5 if self.side == 0 else 1;
        a_lip = ay0 + 3 if self.side == 0 else ay0;
        b_lip = by0 if self.side == 0 else by0 + 3;
        out_a = 1.0 if self.side == 0 else -1.0;
        # The ledges: the first and third on one wall, one over the other,
        # the second on the other wall between them.
        deck(build, 1, ay0, self.long - 1, ay0 + 4, 10, 2);
        deck(build, 1, by0, self.long - 1, by0 + 4, 20, 2);
        deck(build, 1, ay0, self.long - 1, ay0 + 4, 30, 2);
        # The pads: the floor up to the first, the first across to the
        # second, the second across to the third.
        throw(build, shaft, float(cx) + 0.5, float(a_lip) + 0.5 + out_a * 4.0, 0, float(cx) + 0.5, float(ay0) + 2.0, 10, None, [cx - 2, a_lip, cx + 3, a_lip + 1]);
        throw(build, shaft, float(cx) - 4.5, float(ay0) + 2.0, 10, float(cx) - 4.5, float(by0) + 2.0, 20, [cx - 6, a_lip, cx - 3, a_lip + 1], [cx - 6, b_lip, cx - 3, b_lip + 1]);
        throw(build, shaft, float(cx) + 4.5, float(by0) + 2.0, 20, float(cx) + 4.5, float(ay0) + 2.0, 30, [cx + 3, b_lip, cx + 6, b_lip + 1], [cx + 3, a_lip, cx + 6, a_lip + 1]);
        # Drops back down off the first two ledges' ends.
        keep_box(build, shaft, 2, a_lip, 4, a_lip + 1, 10);
        keep_box(build, shaft, 2, b_lip, 4, b_lip + 1, 20);
        # From the top ledge, a pad back down across to the second.
        throw(build, shaft, float(cx) - 4.5, float(ay0) + 2.0, 30, float(cx) + 0.5, float(by0) + 2.0, 20, [cx - 6, a_lip, cx - 3, a_lip + 1], [cx - 2, b_lip, cx + 3, b_lip + 1]);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        torch(build, float(self.long) - 1.5, float(middle) + 0.5, 16.0, 6.0);
        build.foe(5.5, float(middle) + 0.5, 0, TOWER_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.5, float(ay0) + 2.0, 10, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(by0) + 2.0, 20, TOWER_FOES.pick(dice, self.danger), 0.0);
        # On the second ledge, the top one's guard comes to its edge.
        second = build.touch(1.0, float(by0), 20.0, float(self.long - 1), float(by0 + 4), 26.0);
        top = wake_later(build, second, 1.0);
        build.foe(float(self.long) - 3.5, float(ay0) + 2.0, 30, TOWER_FOES.pick(dice, self.danger, True), 180.0, waits=top);
        build.supply(3.0, float(by0) + 2.0, 20, "weapon_rocketlauncher", "q3");
        build.supply(3.0, float(ay0) + 2.0, 30, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(by0) + 2.0, 20, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""Three halls stacked exactly, flights up between them, each parted
from its back room by a sliding door."""
node StackedHalls(Prefab) {
    has first: int = 0,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Stacked halls";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.first = dice.below(2);
        self.tall = 2 * STOREY + 16;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 4) if self.first == 0 else 4.0, floor=STOREY), Port(face=0, along=4.0 if self.first == 0 else float(self.wide - 4), floor=2 * STOREY), Port(face=1 if self.first == 0 else 3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        halls = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(halls, STOREY);
        build.level(halls, 2 * STOREY);
        f1 = 1 if self.first == 0 else self.wide - 4;
        f2 = self.wide - 4 if self.first == 0 else 1;
        # The two floors over the first, each with its flight's well.
        floor_slab(build, halls, 1, 1, self.long - 1, self.wide - 1, STOREY, [[2, f1, 3 + STOREY, f1 + 3]]);
        floor_slab(build, halls, 1, 1, self.long - 1, self.wide - 1, 2 * STOREY, [[4, f2, 4 + STOREY, f2 + 3]]);
        stair(build, 3, f1, 0, 0, STOREY, 3);
        keep_box(build, halls, 3 + STOREY, f1, 4 + STOREY, f1 + 3, STOREY);
        stair(build, 3 + STOREY, f2, STOREY, 2, STOREY, 3);
        keep_box(build, halls, 3, f2, 4, f2 + 3, 2 * STOREY);
        # Each floor's back room behind a wall with a sliding door.
        back = self.long - 7;
        for z in [0, STOREY, 2 * STOREY] {
            door_wall(build, halls, back, self.wide, z, middle - 2);
        }
        build.doorway(halls, self.enter);
        for port in self.taken {
            build.doorway(halls, port);
        }
        # What each floor holds.
        columns(build, [[9, middle - 3], [9, middle + 2], [13, middle - 3], [13, middle + 2]], 0, STOREY - 2);
        build.solid(8, middle - 1, STOREY, 10, middle + 1, STOREY + 2);
        build.solid(12, middle, 2 * STOREY, 14, middle + 2, 2 * STOREY + 1);
        torch(build, float(back) - 0.5, 1.5, 4.0, 5.0);
        torch(build, float(back) - 0.5, float(self.wide) - 1.5, float(2 * STOREY) + 4.0, 6.5);
        build.foe(float(self.long) - 3.5, py, 0, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, py + 3.0, STOREY, TOWER_FOES.pick(dice, self.danger), 180.0);
        # At the first flight's head, the top floor stirs.
        head = build.touch(14.0, float(f1), float(STOREY - 3), 19.0, float(f1 + 3), float(STOREY + 6));
        top = wake_later(build, head, 1.5);
        build.foe(float(self.long // 2) + 0.5, py, 2 * STOREY, TOWER_FOES.pick(dice, self.danger), 180.0, waits=top);
        build.foe(float(self.long) - 3.5, py, 2 * STOREY, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, 3.0, STOREY, Q3_HEALTH, "q3");
        build.supply(3.0, py, 2 * STOREY, Q3_ARMOR, "q3");
        build.supply(3.0, py + 3.0, STOREY, Q3_HEALTH, "q3");
        build.supply(3.0, py, 0, "ammo_shells", "q2");
    }
}

"""The hub: an atrium up through three floors, galleries round it, a
stairwell, a lift, pads up the atrium and across it."""
node TowerCore(Prefab) {
    has tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tower core";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.tall = 2 * STOREY + 38;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=STOREY), Port(face=0, along=4.0, floor=2 * STOREY), Port(face=3, along=float(self.long // 2), floor=2 * STOREY)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        core = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(core, STOREY);
        build.level(core, 2 * STOREY);
        # The galleries round the atrium: the first floor's with a well for
        # its stair, the second's (round a wider opening) for its lift.
        floor_slab(build, core, 1, 1, self.long - 1, self.wide - 1, STOREY, [[cx - 5, cy - 4, cx + 5, cy + 4], [3, 1, 4 + STOREY, 4]]);
        floor_slab(build, core, 1, 1, self.long - 1, self.wide - 1, 2 * STOREY, [[cx - 7, cy - 5, cx + 7, cy + 5], [self.long - 5, self.wide - 5, self.long - 2, self.wide - 2]]);
        stair(build, 4, 1, 0, 0, STOREY, 3);
        keep_box(build, core, 4 + STOREY, 1, 5 + STOREY, 4, STOREY);
        lift(build, self.long - 5, self.wide - 5, self.long - 2, self.wide - 2, STOREY, 2 * STOREY);
        keep_box(build, core, self.long - 6, self.wide - 5, self.long - 5, self.wide - 2, 2 * STOREY);
        keep_box(build, core, self.long - 5, self.wide - 6, self.long - 2, self.wide - 5, 2 * STOREY);
        # The pads: from the atrium's floor up to the first gallery, and
        # from the first gallery's lip across the atrium to the second.
        throw(build, core, float(cx) + 1.0, float(cy) + 0.5, 0, float(cx) - 7.0, float(cy) + 0.5, STOREY, None, [cx - 6, cy - 2, cx - 5, cy + 3]);
        throw(build, core, float(cx) + 6.0, float(cy) + 0.5, STOREY, float(cx) - 10.0, float(cy) + 0.5, 2 * STOREY, None, [cx - 8, cy - 2, cx - 7, cy + 3]);
        build.doorway(core, self.enter);
        for port in self.taken {
            build.doorway(core, port);
        }
        torch(build, float(cx) - 5.5, float(cy) - 4.5, 2.0, 4.0);
        torch(build, float(cx) + 5.5, float(cy) + 4.5, float(STOREY) + 2.0, 5.5);
        build.supply(float(cx) - 11.0, float(cy) + 0.5, 2 * STOREY, "item_health_mega", "q3");
        build.foe(float(cx) - 7.5, float(cy) - 6.5, 0, TOWER_FOES.pick(dice, self.danger), 0.0, patrol=[[float(cx) - 7.5, float(cy) - 6.5], [float(cx) + 7.5, float(cy) - 6.5], [float(cx) + 7.5, float(cy) + 6.5], [float(cx) - 7.5, float(cy) + 6.5]]);
        build.foe(float(self.long) - 4.5, float(cy) + 0.5, 0, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0, STOREY, TOWER_FOES.pick(dice, self.danger), 270.0);
        # Thrown up the atrium, the top gallery's guard comes on.
        thrown = build.touch(float(cx), float(cy - 1), 0.0, float(cx + 2), float(cy + 2), 4.0);
        top = wake_later(build, thrown, 1.0);
        build.foe(float(cx) - 10.0, float(cy) + 4.0, 2 * STOREY, TOWER_FOES.pick(dice, self.danger, True), 0.0, waits=top);
        build.foe(float(self.long) - 3.5, 3.0, 2 * STOREY, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, STOREY, Q3_HEALTH, "q3");
        build.supply(3.0, float(cy) + 0.5, STOREY, "ammo_cells", "q3");
    }
}

"""The key room: the key on the third floor, a stair to the second, a pad
up a shaft to the third, a sliding door before the key."""
node TopVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Top vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(26, 28);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = 2 * STOREY + 12;
        self.low = -1;
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
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, STOREY);
        build.level(vault, 2 * STOREY);
        build.doorway(vault, self.enter);
        floor_slab(build, vault, 1, 1, self.long - 1, side, STOREY, [[4, 1, 5 + STOREY, 4]]);
        floor_slab(build, vault, 1, 1, self.long - 1, side, 2 * STOREY, [[self.long - 7, cy - 2, self.long - 2, cy + 3]]);
        stair(build, 5, 1, 0, 0, STOREY, 3);
        keep_box(build, vault, 5 + STOREY, 1, 6 + STOREY, 4, STOREY);
        throw(build, vault, float(self.long) - 3.5, float(cy) + 0.5, STOREY, float(self.long) - 10.0, float(cy) + 0.5, 2 * STOREY, None, [self.long - 8, cy - 2, self.long - 7, cy + 3]);
        # The key behind a sliding door at the third floor's near end.
        door_wall(build, vault, 6, side + 1, 2 * STOREY, cy - 2);
        key_ambush(build, self.key, 3.0, float(cy) + 0.5, 2 * STOREY, side, 0, [2, 7], [TOWER_FOES.pick(dice, self.danger, True), TOWER_FOES.pick(dice, self.danger)]);
        build.teleporter(3.0, float(cy) + 3.5, 2 * STOREY, float(self.long) - 4.0, float(cy) + 0.5, 0, 180.0);
        torch(build, 1.5, float(cy) - 2.5, float(2 * STOREY) + 4.0, 4.0);
        build.foe(float(self.long) - 9.5, float(cy) + 3.5, 2 * STOREY, TOWER_FOES.pick(dice, self.danger), 180.0);
        build.foe(10.0, float(cy) + 0.5, STOREY, TOWER_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(cy) + 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, STOREY, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a hall, the tower's last room, the way out on its
roof up a pad (and a stair by the seed)."""
node TowerTop(Prefab) {
    has key: str = "",
        steps: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tower top" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY4;
        self.district = level_district(Q3TOURNEY4);
        self.long = dice.between(34, 36);
        self.wide = dice.between(18, 20);
        self.steps = dice.chance(0.5);
        self.tall = STOREY + 38;
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(room, STOREY);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The roof over the room's far part, a shaft through it with a pad.
        rx = wall + 7;
        holes = [[rx, middle - 3, rx + 6, middle + 3]];
        if self.steps {
            holes.append([rx, 1, rx + 1 + STOREY, 4]);
        }
        floor_slab(build, room, rx, 1, self.long - 1, self.wide - 1, STOREY, holes);
        throw(build, room, float(rx) + 2.5, py, 0, float(rx) + 8.5, py, STOREY, None, [rx + 6, middle - 2, rx + 7, middle + 3]);
        if self.steps {
            stair(build, rx + 1, 1, 0, 0, STOREY, 3);
            keep_box(build, room, rx + 1 + STOREY, 1, rx + 2 + STOREY, 4, STOREY);
        }
        build.way_out(float(self.long) - 3.5, py, STOREY);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 6.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, STOREY, TOWER_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, TOWER_FOES.pick(dice, self.danger), 180.0);
        }
        torch(build, float(rx) - 0.5, 1.5, 4.0, 4.5);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(rx) - 2.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(rx) + 9.0, float(self.wide) - 3.0, STOREY, Q3_HEALTH, "q3");
    }
}

"""q3tourney4's stretches: [name, role]."""
glob Q3TOURNEY4_STRETCHES: list[list[str]] = [
         ["base", "start"],
         ["shaft", "flow"],
         ["halls", "flow"],
         ["core", "hub"],
         ["core", "flow"],
         ["vault", "keyroom"],
         ["top", "end"],
         ["top", "gate"]
     ];

"""One of q3tourney4's stretches by its name."""
def make_q3tourney4(name: str, key: str) -> Prefab {
    if name == "base" {
        return TowerBase();
    }
    if name == "shaft" {
        return ClimbShaft();
    }
    if name == "halls" {
        return StackedHalls();
    }
    if name == "core" {
        return TowerCore();
    }
    if name == "vault" {
        return TopVault(key=key if key else "key_silver");
    }
    return TowerTop(key=key);
}
