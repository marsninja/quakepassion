"""Prefabs drawn from Quake III's q3dm14, Grim Dungeons: a castle over its
dungeons. Halls with shafts in their floors down to the dungeons under
them, a deep shaft with a platform bobbing up and down it and pads
throwing a body up from ledge to ledge (the original's pushes at -512,
-448 and -352, its func_bobbing), cells along a corridor under walkways
with lava in a channel down its floor, doors that slide apart, a lava pit
at the bottom of things. Its floors run from 0 down to -832. Quake III's
arenas hold no foes of their own; q3dm14's are knights and zombies, hell
knights as a run goes deeper.

- `GrimHall`: the start. A hall whose floor is the roof of a dungeon, a
  shaft in it to drop down by, a pad under the shaft back up (and a stair
  up through the floor, now and then); a vestibule behind sliding doors.
- `GrimShaft`: a deep shaft, a platform bobbing between its top and its
  bottom, ledges along its walls at two depths, pads from the bottom to
  the lower ledge, across to the higher and up to the top; lava under the
  higher ledge; ways on from the bottom and both ledges.
- `GrimCells`: a dungeon corridor under walkways along both walls, cells
  under the south one, lava in a channel down its floor, bridges between
  the walkways, a stair down at the far end and a pad up at the near,
  sliding doors across the corridor.
- `GrimUndercroft`: the hub. A dungeon floor round a lava pit under
  walkways along three walls and a platform across the fourth; a bridge
  over the pit, pads up to the walkways, a stair up to the platform, a
  vestibule behind sliding doors; ways on above and below.
- `GrimOubliette`: the key room. The key at the bottom of an oubliette,
  ridden down to on a bobbing platform, or dropped into and climbed out of
  by pads from ledge to rim. Taking it opens the closets.
- `GrimGate`: the end (or a gate). The far half of the room sunk to the
  dungeon's depth, under the near floor too; a stair down or a bobbing
  platform; the way out at the bottom."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, hurt, key_taken, pad_to, closets, wake_on, sliding_pair }
import from .q3open_parts { daylight }

glob Q3DM14: str = "q3:q3dm14",
     Q3DM14_LIGHT: list[str] = ["monster_knight", "monster_zombie"],
     Q3DM14_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for the Grim Dungeons."""
glob GRIM_FOES: FoeMix = FoeMix(light=Q3DM14_LIGHT, strong=Q3DM14_HEAVY, heavy_light=Q3DM14_HEAVY, scale=0.5);

"""The start: a hall over a dungeon, a shaft down, a pad back up."""
node GrimHall(Prefab) {
    has stairway: bool = False,
        vestibule: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim hall";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(24, 28);
        self.stairway = dice.chance(0.5);
        self.vestibule = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 7), floor=0), Port(face=3, along=6.0, floor=-10)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        cx = (9 + self.long - 11) // 2;
        hall = build.room(1, 1, -10, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The hall's floor over the dungeon, the shaft through it, and the
        # tunnel from the dungeon to the way on below.
        build.solid(1, 1, -10, self.long - 1, self.wide - 1, 0);
        build.widen(hall, 4, 3, -10, self.long - 4, self.wide - 3, -1);
        build.widen(hall, 9, 6, -1, self.long - 11, self.wide - 6, 0);
        build.widen(hall, 4, 1, -10, 9, 3, -2);
        keep_box(build, hall, 8, 6, 9, self.wide - 6, 0);
        # The pad under the shaft throws a body back up onto the floor.
        pad_to(build, float(cx), 9.0, -10, float(cx), 3.5, 0);
        keep_box(build, hall, cx - 1, 5, cx + 2, 6, 0);
        # A stair up through the floor east of the shaft, now and then.
        if self.stairway {
            build.widen(hall, self.long - 8, 3, -1, self.long - 5, 12, 0);
            stair(build, self.long - 8, 3, -10, 1, 10, 3);
        }
        # A vestibule behind sliding doors at the far end.
        if self.vestibule {
            build.solid(self.long - 5, 1, 0, self.long - 4, self.wide - 1, self.tall);
            sliding_pair(build, hall, self.long - 5, mid - 2, mid + 2, 0, 7);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # Down in the dungeon, what waits there wakes.
        below = wake_on(build, 9.0, 6.0, float(self.long - 11), float(self.wide - 6), -10.0);
        build.foe(5.5, float(self.wide) - 4.5, -10, GRIM_FOES.pick(dice, self.danger), 0.0, waits=below);
        build.foe(float(self.long) - 5.5, 4.5, -10, GRIM_FOES.pick(dice, self.danger, True), 180.0, waits=below);
        build.foe(5.5, 4.5, -10, "monster_zombie", 0.0, patrol=[[5.5, 4.5], [5.5, float(self.wide) - 4.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5 + float(index) * 3.0, float(self.wide) - 3.5, 0, GRIM_FOES.pick(dice, self.danger), 270.0);
        }
        build.foe(float(self.long) - 7.5, 2.5, 0, "monster_knight", 90.0);
        build.supply(float(cx) - 2.5, float(mid) + 0.5, -10, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 6.0, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A deep shaft, a bobbing platform, ledges at two depths, pads from ledge
to ledge."""
node GrimShaft(Prefab) {
    has bobbing: bool = True,
        lava: bool = True,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim shaft";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(20, 22);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(28, 30);
        self.bobbing = dice.chance(0.6);
        self.lava = dice.chance(0.6);
        self.low = -27;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-24), Port(face=0, along=3.0, floor=-8), Port(face=1, along=float(self.long - 4), floor=-16)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        shaft = build.room(1, 1, -24, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [-24, -8]);
        build.level(shaft, 0);
        build.level(shaft, -8);
        build.level(shaft, -16);
        # The top ledge at the way in, the ledges along the walls.
        build.solid(1, 1, -24, 6, self.wide - 1, 0);
        deck(build, 6, 1, self.long - 1, 5, -8);
        deck(build, 6, self.wide - 5, self.long - 1, self.wide - 1, -16);
        # The platform bobbing between the top and the bottom; without it, the
        # way down is a drop from ledge to ledge.
        if self.bobbing {
            build.train([3.0, 3.0, 1.0], [[6.0, float(mid - 1), -1.0], [6.0, float(mid - 1), -24.0]], 80.0, 2.0);
            keep_box(build, shaft, 5, mid - 1, 6, mid + 2, 0);
        } else {
            keep_box(build, shaft, 10, 4, 14, 5, -8);
        }
        # Pads: the bottom to the lower ledge, across to the higher, up to the
        # top.
        pad_to(build, float(self.long - 6), float(self.wide - 8), -24, float(self.long - 6), float(self.wide) - 3.0, -16);
        keep_box(build, shaft, self.long - 7, self.wide - 5, self.long - 5, self.wide - 4, -16);
        pad_to(build, float(self.long - 10), float(self.wide - 2), -16, float(self.long - 10), 3.0, -8);
        keep_box(build, shaft, self.long - 11, self.wide - 5, self.long - 9, self.wide - 4, -16);
        keep_box(build, shaft, self.long - 11, 4, self.long - 9, 5, -8);
        pad_to(build, 9.0, 3.0, -8, 3.0, 3.0, 0);
        keep_box(build, shaft, 5, 1, 6, 5, 0);
        # Lava under the higher ledge's far end, now and then.
        if self.lava {
            build.pool(self.long - 8, 1, -26, self.long - 1, 5, -24, 4, False, False);
            hurt(build, float(self.long - 8), 1.0, -26.0, float(self.long - 1), 5.0, -24.0);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        bottom = wake_on(build, 9.0, 6.0, float(self.long - 1), float(self.wide - 6), -24.0);
        build.foe(float(self.long) - 4.5, float(mid) + 0.5, -24, GRIM_FOES.pick(dice, self.danger, True), 180.0, waits=bottom);
        build.foe(12.5, float(mid) + 0.5, -24, "monster_zombie", 0.0);
        build.foe(float(self.long) - 3.5, 3.0, -8, GRIM_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, -16, GRIM_FOES.pick(dice, self.danger), 180.0, waits=bottom);
        build.foe(3.5, 3.5, 0, "monster_knight", 0.0);
        build.supply(float(self.long) - 6.0, float(self.wide) - 2.5, -16, Q3_ARMOR, "q3");
        build.supply(14.0, 3.0, -8, Q3_HEALTH, "q3");
        build.supply(10.0, float(mid) + 3.0, -24, Q3_HEALTH, "q3");
    }
}

"""A dungeon corridor under walkways, cells under the south one, lava down
its floor, bridges, a stair and a pad, sliding doors across."""
node GrimCells(Prefab) {
    has doors: bool = True,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim cells";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(20, 22);
        self.doors = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=float(self.wide - 3), floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-8), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -8;
        mid = self.wide // 2;
        cut = self.long // 2;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The walkways along both walls, the cells under the south one.
        deck(build, 1, 1, self.long - 1, 5, 0);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, 0);
        for x in range(4, self.long - 5, 4) {
            build.solid(x, 1, lo, x + 1, 4, -1);
        }
        # Lava in a channel down the corridor's floor.
        build.pool(8, mid, lo - 2, self.long - 10, mid + 1, lo, 4, False, False);
        hurt(build, 8.0, float(mid), float(lo - 2), float(self.long - 10), float(mid + 1), float(lo));
        # Bridges between the walkways.
        for bx in [10, self.long - 15] {
            deck(build, bx, 5, bx + 3, self.wide - 5, 0);
            keep_box(build, hall, bx, 4, bx + 3, 5, 0);
            keep_box(build, hall, bx, self.wide - 5, bx + 3, self.wide - 4, 0);
        }
        # Down from the north walkway at the far end, up to the south one by
        # a pad at the near.
        build.widen(hall, self.long - 11, self.wide - 4, -1, self.long - 4, self.wide - 1, 0);
        stair(build, self.long - 11, self.wide - 4, lo, 0, 8, 3);
        pad_to(build, 6.0, 8.0, lo, 6.0, 3.0, 0);
        keep_box(build, hall, 5, 4, 8, 5, 0);
        # Doors across the corridor that slide apart.
        if self.doors {
            build.solid(cut, 1, lo, cut + 1, self.wide - 1, -1);
            sliding_pair(build, hall, cut, mid + 1, mid + 5, lo, 7);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down the stair, what lies in the cells wakes.
        cells = wake_on(build, float(self.long - 12), float(self.wide - 4), float(self.long - 8), float(self.wide - 1), float(lo));
        for x in range(5, self.long - 6, 8) {
            build.foe(float(x) + 1.5, 2.5, lo, "monster_zombie", 90.0, waits=cells);
        }
        build.foe(float(cut) + 4.5, float(mid) + 2.5, lo, GRIM_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(4.5, float(mid) + 2.5, lo, "monster_knight", 0.0, patrol=[[4.5, float(mid) + 2.5], [float(cut) - 2.5, float(mid) + 2.5]]);
        build.foe(float(cut) + 0.5, 3.0, 0, GRIM_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 6.5, float(self.wide) - 3.0, 0, GRIM_FOES.pick(dice, self.danger), 180.0);
        build.supply(10.5, 2.5, lo, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, 0, Q3_ARMOR, "q3");
    }
}

"""The hub: a dungeon floor round a lava pit under walkways and a platform,
a bridge over the pit, pads, a stair, sliding doors."""
node GrimUndercroft(Prefab) {
    has bridged: bool = True,
        lifted: bool = False,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim undercroft";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(32, 36);
        self.bridged = dice.chance(0.6);
        self.lifted = dice.chance(0.4);
        self.low = -15;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=-10),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, -10, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The walkways along three walls over the dungeon floor, the platform
        # across the fourth, the bridge between them over the pit.
        deck(build, 1, 1, 6, self.wide - 1, 0);
        deck(build, 6, 1, self.long - 6, 5, 0);
        deck(build, 6, self.wide - 5, self.long - 6, self.wide - 1, 0);
        build.solid(self.long - 6, 1, -10, self.long - 1, self.wide - 1, 0);
        if self.bridged {
            deck(build, 6, cy - 1, self.long - 6, cy + 2, 0);
        }
        # The lava pit in the dungeon floor.
        build.pool(cx - 4, cy - 4, -14, cx + 4, cy + 4, -10, 4, False, False);
        hurt(build, float(cx - 4), float(cy - 4), -14.0, float(cx + 4), float(cy + 4), -10.0);
        # Pads up to the walkways, a stair up to the platform.
        pad_to(build, float(cx - 7), float(self.wide - 8), -10, float(cx - 7), float(self.wide) - 3.0, 0);
        keep_box(build, hall, cx - 8, self.wide - 5, cx - 6, self.wide - 4, 0);
        pad_to(build, float(cx + 7), 8.0, -10, float(cx + 7), 3.0, 0);
        keep_box(build, hall, cx + 6, 4, cx + 8, 5, 0);
        if self.lifted {
            lift(build, self.long - 9, cy + 4, self.long - 6, cy + 7, -10, 0);
            keep_box(build, hall, self.long - 6, cy + 4, self.long - 5, cy + 7, 0);
        } else {
            stair(build, self.long - 16, cy + 4, -10, 0, 10, 3);
        }
        # A vestibule behind sliding doors on the platform.
        build.solid(self.long - 5, 1, 0, self.long - 4, self.wide - 1, self.tall);
        sliding_pair(build, hall, self.long - 5, cy - 2, cy + 2, 0, 7);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Out on the bridge (or down on the dungeon floor), the walkways'
        # guards wake.
        bridge = wake_on(build, float(cx - 2), float(cy - 1), float(cx + 2), float(cy + 2), 0.0) if self.bridged else wake_on(build, 7.0, 6.0, float(cx - 5), float(self.wide - 6), -10.0);
        build.foe(float(cx) + 3.5, 3.0, 0, GRIM_FOES.pick(dice, self.danger), 90.0, waits=bridge);
        build.foe(float(cx) - 3.5, float(self.wide) - 3.0, 0, GRIM_FOES.pick(dice, self.danger, True), 270.0, waits=bridge);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 6 + index * 6) + 0.5, float(cy) + (6.5 if index % 2 == 0 else -6.5), -10, GRIM_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(8.5, 8.5, -10, "monster_zombie", 0.0, patrol=[[8.5, 8.5], [8.5, float(self.wide) - 8.5]]);
        build.foe(float(self.long) - 7.0, 3.5, 0, GRIM_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 0, Q3_ARMOR, "q3");
        build.supply(float(cx) - 6.5, float(cy) - 6.0, -10, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key at the bottom of an oubliette, ridden down to or
climbed out of by pads; taking it opens the closets."""
node GrimOubliette(Prefab) {
    has key: str = "key_silver",
        bobbing: bool = True,
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim oubliette (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.bobbing = dice.chance(0.5);
        self.tall = 34;
        self.low = -17;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, -16);
        build.doorway(room, self.enter);
        build.widen(room, 6, 4, -16, self.long - 5, side - 3, 0);
        keep_box(build, room, 5, 4, 6, side - 3, 0);
        taken: Cue | None = None;
        if self.bobbing {
            build.train([3.0, 3.0, 1.0], [[6.0, float(cy - 1), -1.0], [6.0, float(cy - 1), -16.0]], 80.0, 2.0);
            taken = key_taken(build, self.key, float(self.long) - 8.0, float(cy) + 0.5, -16);
        } else {
            # A ledge in the far wall, a pad from the bottom onto it, another
            # from it up onto the rim.
            build.level(room, -8);
            build.solid(self.long - 10, 4, -16, self.long - 5, side - 3, -8);
            pad_to(build, float(self.long - 13), float(cy) + 0.5, -16, float(self.long) - 6.0, float(cy) + 0.5, -8);
            keep_box(build, room, self.long - 10, cy - 1, self.long - 9, cy + 2, -8);
            pad_to(build, float(self.long - 8), float(cy) + 3.5, -8, float(self.long) - 3.0, float(cy) + 3.5, 0);
            keep_box(build, room, self.long - 5, cy + 2, self.long - 4, cy + 5, 0);
            taken = key_taken(build, self.key, 8.5, float(cy) + 2.5, -16);
        }
        if taken is not None {
            closets(build, taken, side, 0, [2, 8], [GRIM_FOES.pick(dice, self.danger, True), GRIM_FOES.pick(dice, self.danger)]);
            late = build.delay(1.5);
            taken +>:Fires:+> late;
            wake = build.waiting();
            late +>:Fires:+> wake;
            build.foe(float(self.long) - 3.0, 2.5, 0, GRIM_FOES.pick(dice, self.danger), 180.0, waits=wake);
        }
        build.foe(10.5, float(cy) - 1.5, -16, "monster_zombie", 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(12.5, float(cy) + 2.5, -16, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): the far half sunk to the dungeon's depth, a stair
or a bobbing platform down, the way out at the bottom."""
node GrimGate(Prefab) {
    has key: str = "",
        bobbing: bool = False,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grim gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM14;
        self.district = level_district(Q3DM14);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.bobbing = dice.chance(0.5);
        self.tall = dice.between(28, 30);
        self.low = -11;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        wall = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, -10);
        build.widen(room, 12, 1, -10, self.long - 1, self.wide - 1, 0);
        build.widen(room, 9, 1, -10, 12, self.wide - 1, -1);
        if self.bobbing {
            build.train([3.0, 3.0, 1.0], [[12.0, float(mid - 1), -1.0], [12.0, float(mid - 1), -10.0]], 80.0, 2.0);
            keep_box(build, room, 11, mid - 1, 12, mid + 2, 0);
        } else {
            stair(build, 21, 1, -10, 2, 10, 3);
        }
        build.way_out(float(self.long) - 3.0, float(mid), -10);
        below = wake_on(build, 13.0, 4.0, float(self.long - 6), float(self.wide - 4), -10.0);
        build.foe(float(self.long) - 4.5, 3.5, -10, GRIM_FOES.pick(dice, self.danger, True), 180.0, waits=below);
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.5, -10, GRIM_FOES.pick(dice, self.danger), 180.0, waits=below);
        build.foe(10.5, float(mid) + 3.5, -10, "monster_zombie", 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, GRIM_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 6.0, float(mid) + 3.5, -10, Q3_HEALTH, "q3");
    }
}

"""q3dm14's stretches: [name, role]."""
glob Q3DM14_STRETCHES: list[list[str]] = [
         ["hall", "start"],
         ["shaft", "flow"],
         ["cells", "flow"],
         ["undercroft", "hub"],
         ["oubliette", "keyroom"],
         ["gate", "end"],
         ["gate", "gate"]
     ];

"""One of q3dm14's stretches by its name."""
def make_q3dm14(name: str, key: str) -> Prefab {
    if name == "hall" {
        return GrimHall();
    }
    if name == "shaft" {
        return GrimShaft();
    }
    if name == "cells" {
        return GrimCells();
    }
    if name == "undercroft" {
        return GrimUndercroft();
    }
    if name == "oubliette" {
        return GrimOubliette(key=key if key else "key_silver");
    }
    return GrimGate(key=key);
}
