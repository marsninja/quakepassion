"""Prefabs drawn from Quake III's q3dm12, The Dredwerkz: ironworks over lava.
Rooms behind pairs of doors that slide apart, a pit of lava with a platform
out in it and pads off it up to a ledge (the original's rocket platform),
pump rooms with a floor over a floor, a furnace hall of three tiers and a
perch above them all (its floors at -256, 0, 64 and 320), lava along the
works' floors that hurts. Quake III's arenas hold no foes of their own;
q3dm12's are enforcers and ogres, fiends as a run goes deeper.

- `DredGate`: the start. A hall behind a partition whose doors slide
  apart; beyond, a sluice of lava down the works, a low south quay and a
  north quay four lifts over it, gangways climbing across from one to the
  other, a crane's gantry from wall to wall over them all, thrown up to
  from the low quay or up a stair from the high.
- `DredLavaPit`: a pit of lava, a rim round it, a platform out in it
  reached by a bridge (and one more, now and then); a pad on the platform
  throws a body up onto a ledge along the far wall, another from the rim
  too, a teleporter from the ledge back to the near rim.
- `DredPumpRoom`: a floor over a floor: the upper over the west of the
  room, a pump pit open in its east with a stair down and a pad back up,
  a lift or a stair through the upper floor in its west; under it a slime
  sump and a partition whose doors slide apart.
- `DredFurnace`: the hub. A sunken furnace floor with lava pools, a stair
  down and a pad back up; the floor round it; galleries along both walls
  up their stairs; a perch over the north gallery's end a pad throws a
  body up to; a teleporter from the furnace floor to the south gallery.
- `DredVault`: the key room. The key on a pillar out in a pool of lava, a
  pad thrown onto it and steps down off it; or on a gantry beyond a lava
  trough bridged. Taking it opens the closets.
- `DredExit`: the end (or a gate). A lava moat across the room, bridged;
  the way out on a block at the far end, up a stair or a pad."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, hurt, key_taken, pad_to, closets, wake_on, sliding_pair }
import from .q3open_parts { vista, daylight }

glob Q3DM12: str = "q3:q3dm12",
     Q3DM12_LIGHT: list[str] = ["monster_enforcer", "monster_ogre"],
     Q3DM12_HEAVY: list[str] = ["monster_demon1"];

"""A foe for the Dredwerkz."""
glob DRED_FOES: FoeMix = FoeMix(light=Q3DM12_LIGHT, strong=Q3DM12_HEAVY, heavy_light=Q3DM12_HEAVY, scale=0.5);

"""The start: a hall behind a partition with sliding doors, a sluice of
lava between two quays, gangways across it, a crane's gantry over them."""
node DredGate(Prefab) {
    has part: int = 8,
        padded: bool = False,
        gangways: int = 1,
        crane: int = 16,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz gate";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(22, 26);
        self.part = dice.between(7, 9);
        self.padded = dice.chance(0.5);
        self.gangways = dice.between(1, 2);
        self.crane = self.long - dice.between(9, 11);
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=4.0, floor=0),
            Port(face=0, along=float(self.wide - 4), floor=4),
            Port(face=1, along=float(self.crane + 2), floor=11),
            Port(face=3, along=float(self.crane + 2), floor=11)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        pw = self.part;
        ch = pw + 4;
        cr = self.crane;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 4);
        build.level(hall, 11);
        # The partition and its sliding doors.
        build.solid(pw, 1, 0, pw + 1, self.wide - 1, self.tall);
        sliding_pair(build, hall, pw, mid - 2, mid + 2, 0, 7);
        # A sluice of lava down the works from the doors to the far wall,
        # the low south quay on one side of it, the north quay four lifts up
        # on the other, a stair up to that from the doors' landing.
        build.pool(ch, mid - 1, -2, self.long - 1, mid + 2, 0, 4, False, False);
        hurt(build, float(ch), float(mid - 1), -2.0, float(self.long - 1), float(mid + 2), 0.0);
        build.solid(ch, mid + 2, 0, self.long - 1, self.wide - 1, 4);
        stair(build, pw + 1, mid + 2, 0, 1, 4, 3);
        build.solid(pw + 1, mid + 6, 0, ch, self.wide - 1, 4);
        # Gangways climbing across the sluice from quay to quay.
        spots = [ch + 3];
        if self.gangways > 1 and cr - 4 >= ch + 7 {
            spots.append(cr - 4);
        }
        for gx in spots {
            for step in range(3) {
                build.solid(gx, mid - 1 + step, -2, gx + 3, mid + step, step + 1);
            }
            keep_box(build, hall, gx, mid + 2, gx + 3, mid + 3, 4);
        }
        # The crane's gantry from wall to wall over both quays and the sluice:
        # thrown up to from the south quay, or up a stair from the north.
        deck(build, cr, 1, cr + 4, self.wide - 1, 11);
        if self.padded {
            pad_to(build, float(cr - 3), 4.5, 0, float(cr + 2), 4.5, 11);
            keep_box(build, hall, cr, 3, cr + 1, 7, 11);
        } else {
            stair(build, cr - 7, self.wide - 4, 4, 0, 7, 3);
            keep_box(build, hall, cr, self.wide - 4, cr + 1, self.wide - 1, 11);
        }
        keep_box(build, hall, cr + 3, 1, cr + 4, 5, 11);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # At the doors, what waits in the works wakes.
        works = wake_on(build, float(pw - 2), float(mid - 2), float(pw), float(mid + 2), 0.0);
        build.foe(float(pw) + 5.5, 4.5, 0, DRED_FOES.pick(dice, self.danger), 180.0, waits=works);
        build.foe(float(self.long) - 4.5, 6.5, 0, DRED_FOES.pick(dice, self.danger), 180.0, waits=works);
        build.foe(float(self.long) - 3.5, float(self.wide) - 2.5, 4, DRED_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(4.5, float(mid) + 3.5, 0, "monster_enforcer", 0.0);
        build.foe(float(ch) + 1.5, float(self.wide) - 3.5, 4, "monster_enforcer", 0.0, patrol=[[float(ch) + 1.5, float(self.wide) - 3.5], [float(cr) - 8.5, float(self.wide) - 3.5]]);
        build.foe(float(cr) + 1.5, float(mid) + 0.5, 11, DRED_FOES.pick(dice, self.danger), 270.0);
        build.supply(float(cr) + 2.0, float(self.wide) - 3.0, 11, Q3_ARMOR, "q3");
        build.supply(float(pw) - 2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A pit of lava, a platform out in it, pads up to a ledge along the far
wall, a teleporter back."""
node DredLavaPit(Prefab) {
    has north: bool = False,
        padded: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz lava pit";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(36, 40);
        self.north = dice.chance(0.5);
        self.padded = dice.chance(0.6);
        self.low = -7;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = vista(2, cy, 0);
        self.leaves = [
            vista(0, cy, 8),
            Port(face=1, along=float(self.long - 6), floor=0),
            Port(face=3, along=float(self.long - 6), floor=0),
            Port(face=1, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        cx = (self.long - 2) // 2;
        px1 = self.long - 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        daylight(build, 1, 1, self.long - 1, self.wide - 1, [0, 8]);
        build.level(hall, 8);
        # The pit, lava in its bottom.
        build.pool(6, 5, -6, px1, self.wide - 5, -3, 4, False, False);
        build.widen(hall, 6, 5, -3, px1, self.wide - 5, 0);
        hurt(build, 6.0, 5.0, -6.0, float(px1), float(self.wide - 5), -3.0);
        # The platform out in it, and the bridges to it.
        build.solid(cx - 3, cy - 3, -6, cx + 3, cy + 3, 0);
        deck(build, 6, cy - 1, cx - 3, cy + 2, 0);
        keep_box(build, hall, 5, cy - 1, 6, cy + 2, 0);
        if self.north {
            deck(build, cx - 1, cy + 3, cx + 2, self.wide - 5, 0);
            keep_box(build, hall, cx - 1, self.wide - 5, cx + 2, self.wide - 4, 0);
        }
        # The ledge along the far wall over its arcade; the pad on the
        # platform up to it (and one from the rim); a lip to drop from.
        deck(build, self.long - 4, 1, self.long - 1, self.wide - 1, 8);
        for y in range(3, self.wide - 2, 4) {
            if y < cy - 3 or y > cy + 3 {
                build.solid(self.long - 4, y, 0, self.long - 3, y + 1, 7);
            }
        }
        pad_to(build, float(cx), float(cy) + 0.5, 0, float(self.long) - 2.5, float(cy) + 0.5, 8);
        keep_box(build, hall, cx + 2, cy - 1, cx + 3, cy + 2, 0);
        keep_box(build, hall, self.long - 4, cy - 2, self.long - 3, cy + 3, 8);
        if self.padded {
            pad_to(build, float(self.long - 7), 4.0, 0, float(self.long) - 2.5, 4.0, 8);
            keep_box(build, hall, self.long - 4, 3, self.long - 3, 6, 8);
        }
        keep_box(build, hall, self.long - 4, self.wide - 8, self.long - 3, self.wide - 5, 8);
        build.teleporter(float(self.long) - 2.5, float(self.wide) - 3.0, 8, 3.0, 3.0, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Out on the platform, the ledge's guards wake.
        ledge = wake_on(build, float(cx - 3), float(cy - 3), float(cx + 3), float(cy + 3), 0.0);
        build.foe(float(self.long) - 2.5, 3.5, 8, DRED_FOES.pick(dice, self.danger), 180.0, waits=ledge);
        build.foe(float(self.long) - 2.5, float(self.wide) - 6.5, 8, DRED_FOES.pick(dice, self.danger, True), 180.0, waits=ledge);
        build.foe(float(cx) - 1.5, float(cy) - 1.5, 0, DRED_FOES.pick(dice, self.danger, True), 0.0);
        build.foe(3.5, 3.5, 0, DRED_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 6.5, float(self.wide) - 3.5, 0, "monster_enforcer", 180.0, patrol=[[float(self.long) - 6.5, float(self.wide) - 3.5], [float(self.long) - 6.5, 6.5]]);
        build.supply(float(cx) + 0.5, float(cy) - 1.5, 0, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, float(cy) - 3.5, 8, Q3_HEALTH, "q3");
    }
}

"""A floor over a floor: a pump pit open in the east, a stair down and a
pad back up; a lift or a stair in the west; a sump and sliding doors."""
node DredPumpRoom(Prefab) {
    has lifted: bool = False,
        sump: bool = True,
        doors: bool = True,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz pump room";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(9, 10);
        self.lifted = dice.chance(0.5);
        self.sump = dice.chance(0.6);
        self.doors = dice.chance(0.6);
        self.low = -12;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        dx = self.long - 9;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-9), Port(face=1, along=float(dx - 2), floor=-9), Port(face=3, along=float(dx - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -9;
        mid = self.wide // 2;
        dx = self.long - 9;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The upper floor over the west of the room.
        build.solid(1, 1, -1, dx, self.wide - 1, 0);
        # The west way between them: a lift through it, or a stair.
        if self.lifted {
            build.widen(hall, 3, self.wide - 5, -1, 6, self.wide - 2, 0);
            lift(build, 3, self.wide - 5, 6, self.wide - 2, lo, 0);
            keep_box(build, hall, 6, self.wide - 5, 7, self.wide - 2, 0);
            keep_box(build, hall, 2, self.wide - 5, 3, self.wide - 2, 0);
        } else {
            build.widen(hall, 5, self.wide - 4, -1, 13, self.wide - 1, 0);
            stair(build, 12, self.wide - 4, lo, 2, 9, 3);
        }
        # The pump pit: a stair down along its south wall, a pad back up onto
        # the upper floor's lip.
        stair(build, self.long - 2, 1, lo, 2, 8, 3);
        pad_to(build, float(dx + 3), float(mid) + 0.5, lo, float(dx) - 2.0, float(mid) + 0.5, 0);
        keep_box(build, hall, dx - 1, mid - 2, dx, mid + 3, 0);
        # Under the upper floor: a partition whose doors slide apart, a sump
        # of slime.
        if self.doors {
            build.solid(14, 1, lo, 15, self.wide - 1, -1);
            sliding_pair(build, hall, 14, mid - 2, mid + 2, lo, 7);
        }
        if self.sump {
            build.pool(5, 2, lo - 2, 9, 6, lo, 3);
            hurt(build, 5.0, 2.0, float(lo - 2), 9.0, 6.0, float(lo));
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down in the pit, what waits under the upper floor wakes.
        below = wake_on(build, float(dx), 4.0, float(self.long - 1), float(self.wide - 1), float(lo));
        build.foe(10.5, float(mid) + 0.5, lo, DRED_FOES.pick(dice, self.danger), 0.0, waits=below);
        build.foe(float(dx) - 3.5, float(mid) - 3.5, lo, DRED_FOES.pick(dice, self.danger, True), 180.0, waits=below);
        build.foe(float(self.long) - 4.5, float(mid) + 3.5, lo, "monster_enforcer", 180.0);
        build.foe(float(dx) - 4.5, float(mid) + 0.5, 0, DRED_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, 3.5, 0, "monster_enforcer", 0.0, patrol=[[4.5, 3.5], [float(dx) - 3.5, 3.5]]);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, lo, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, lo, Q3_ARMOR, "q3");
    }
}

"""The hub: a sunken furnace floor, the floor round it, galleries along
both walls, a perch over the north gallery's end."""
node DredFurnace(Prefab) {
    has bridged: bool = False,
        pools: int = 2,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz furnace";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(36, 38);
        self.bridged = dice.chance(0.5);
        self.pools = dice.between(1, 2);
        self.low = -11;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = vista(2, cy, 0);
        self.leaves = [
            vista(0, cy, 0),
            Port(face=1, along=float(self.long - 14), floor=8),
            Port(face=3, along=float(self.long - 6), floor=8),
            Port(face=1, along=float(self.long - 3), floor=16)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        gal = 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, gal);
        build.level(hall, 16);
        build.level(hall, -8);
        # The furnace floor sunk in the middle, lava in two pools on it, a
        # stair down along its south side, a pad back up at its east end.
        build.widen(hall, 7, 8, -8, self.long - 7, self.wide - 8, 0);
        for px in ([9, self.long - 13] if self.pools == 2 else [self.long // 2 - 2]) {
            build.pool(px, cy - 2, -10, px + 4, cy + 2, -8, 4, False, False);
            hurt(build, float(px), float(cy - 2), -10.0, float(px + 4), float(cy + 2), -8.0);
        }
        stair(build, 14, 8, -8, 2, 8, 3);
        pad_to(build, float(self.long - 10), float(self.wide) - 9.5, -8, float(self.long) - 4.0, float(self.wide) - 9.5, 0);
        keep_box(build, hall, self.long - 7, self.wide - 11, self.long - 6, self.wide - 8, 0);
        build.teleporter(9.0, float(self.wide) - 10.0, -8, 5.0, 3.0, gal, 0.0);
        # The galleries on their arcades, each up a stair.
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        for x in range(4, self.long - 3, 4) {
            build.solid(x, 4, 0, x + 1, 5, gal - 1);
            if x < self.long - 11 {
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        stair(build, 2, 5, 0, 0, gal, 3);
        keep_box(build, hall, 8, 4, 11, 5, gal);
        # A bridge across the furnace floor between the floor's two sides,
        # now and then.
        if self.bridged {
            deck(build, cx - 1, 8, cx + 2, self.wide - 8, 0);
            keep_box(build, hall, cx - 1, 7, cx + 2, 8, 0);
            keep_box(build, hall, cx - 1, self.wide - 8, cx + 2, self.wide - 7, 0);
        }
        stair(build, self.long - 3, self.wide - 8, 0, 2, gal, 3);
        keep_box(build, hall, self.long - 11, self.wide - 5, self.long - 8, self.wide - 4, gal);
        # The perch over the north gallery's east end, a pad up to it.
        deck(build, self.long - 7, self.wide - 7, self.long - 1, self.wide - 1, 16);
        pad_to(build, float(self.long - 10), float(self.wide) - 3.0, gal, float(self.long) - 3.5, float(self.wide) - 3.0, 16);
        keep_box(build, hall, self.long - 7, self.wide - 5, self.long - 6, self.wide - 1, 16);
        keep_box(build, hall, self.long - 7, self.wide - 7, self.long - 6, self.wide - 5, 16);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down on the furnace floor, the galleries' guards wake.
        down = wake_on(build, 7.0, 8.0, 10.0, 11.0, -8.0);
        build.foe(float(cx) + 0.5, 2.5, gal, DRED_FOES.pick(dice, self.danger), 90.0, waits=down);
        build.foe(float(cx) - 3.5, float(self.wide) - 2.5, gal, DRED_FOES.pick(dice, self.danger), 270.0, waits=down);
        build.foe(float(self.long) - 3.5, float(self.wide) - 4.5, 16, DRED_FOES.pick(dice, self.danger, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 3 + index * 3) + 0.5, float(cy) + (4.5 if index % 2 == 0 else -4.5), -8, DRED_FOES.pick(dice, self.danger, index == 1), 0.0);
        }
        build.foe(4.5, float(cy) + 0.5, 0, "monster_enforcer", 0.0, patrol=[[4.5, float(cy) + 0.5], [4.5, float(self.wide) - 6.5]]);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, -8, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 16, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.0, gal, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a pillar in a pool of lava, or on a gantry
beyond a lava trough; taking it opens the closets."""
node DredVault(Prefab) {
    has key: str = "key_silver",
        pillar: bool = True,
        hall_wide: int = 16,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.pillar = dice.chance(0.5);
        self.tall = 24;
        self.low = -4;
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
        cx = self.long // 2;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(room, self.enter);
        taken: Cue | None = None;
        if self.pillar {
            # The pool of lava, the pillar out in it, a pad from the west rim
            # onto it and steps down off it to the east rim.
            build.level(room, 4);
            build.pool(5, 4, -3, cx + 7, side - 3, 0, 4, False, False);
            hurt(build, 5.0, 4.0, -3.0, float(cx + 7), float(side - 3), 0.0);
            build.solid(cx - 2, cy - 2, -3, cx + 3, cy + 3, 4);
            pad_to(build, 2.0, float(cy) + 4.5, 0, float(cx) - 0.5, float(cy) + 2.0, 4);
            keep_box(build, room, 4, cy + 2, 5, cy + 6, 0);
            keep_box(build, room, cx - 2, cy - 1, cx - 1, cy + 2, 4);
            for step in range(4) {
                build.solid(cx + 3 + step, cy - 1, -3, cx + 4 + step, cy + 2, 3 - step);
            }
            taken = key_taken(build, self.key, float(cx) + 1.5, float(cy) + 1.5, 4);
            build.foe(float(cx) + 1.5, float(cy) - 0.5, 4, DRED_FOES.pick(dice, self.danger), 180.0);
        } else {
            # A lava trough across the room, bridged; beyond it a gantry
            # across the far wall up a stair along the north wall.
            build.level(room, 7);
            build.pool(5, 1, -2, 7, side, 0, 4, False, False);
            hurt(build, 5.0, 1.0, -2.0, 7.0, float(side), 0.0);
            deck(build, 5, cy - 1, 7, cy + 2, 0);
            keep_box(build, room, 4, cy - 1, 5, cy + 2, 0);
            keep_box(build, room, 7, cy - 1, 8, cy + 2, 0);
            deck(build, self.long - 6, 1, self.long - 1, side, 7);
            stair(build, self.long - 14, side - 3, 0, 0, 7, 3);
            keep_box(build, room, self.long - 6, side - 3, self.long - 5, side, 7);
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 7);
            build.foe(float(self.long) - 3.0, 3.0, 7, DRED_FOES.pick(dice, self.danger), 180.0);
        }
        if taken is not None {
            closets(build, taken, side, 0, [1, 8], [DRED_FOES.pick(dice, self.danger, True), DRED_FOES.pick(dice, self.danger)]);
            late = build.delay(1.5);
            taken +>:Fires:+> late;
            wake = build.waiting();
            late +>:Fires:+> wake;
            build.foe(float(self.long) - 3.5, float(side) - 2.5, 0, DRED_FOES.pick(dice, self.danger), 180.0, waits=wake);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): a lava moat across the room, bridged; the way out
on a block at the far end, up a stair or a pad."""
node DredExit(Prefab) {
    has key: str = "",
        padded: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.padded = dice.chance(0.5);
        self.tall = dice.between(26, 30);
        self.low = -3;
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
        build.level(room, 8);
        # The moat, bridged.
        build.pool(wall + 3, 1, -2, wall + 5, self.wide - 1, 0, 4, False, False);
        hurt(build, float(wall + 3), 1.0, -2.0, float(wall + 5), float(self.wide - 1), 0.0);
        deck(build, wall + 3, mid - 1, wall + 5, mid + 2, 0);
        keep_box(build, room, wall + 2, mid - 1, wall + 3, mid + 2, 0);
        keep_box(build, room, wall + 5, mid - 1, wall + 6, mid + 2, 0);
        # The block at the far end, the way out on it.
        bx = self.long - 8;
        build.solid(bx, 1, 0, self.long - 1, self.wide - 1, 8);
        if self.padded {
            pad_to(build, float(bx - 3), float(mid) + 0.5, 0, float(bx) + 3.5, 3.5, 8);
            keep_box(build, room, bx, mid - 2, bx + 1, mid + 3, 8);
        } else {
            stair(build, bx - 3, 1, 0, 1, 8, 3);
            keep_box(build, room, bx, 6, bx + 1, 10, 8);
        }
        build.way_out(float(self.long) - 4.0, float(mid), 8);
        # Over the bridge, the block's guards wake.
        guards = wake_on(build, float(wall + 3), float(mid - 1), float(wall + 5), float(mid + 2), 0.0);
        build.foe(float(self.long) - 3.5, 3.5, 8, DRED_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 8, DRED_FOES.pick(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, DRED_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(bx) - 3.5, float(self.wide) - 3.5, 0, "monster_enforcer", 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm12's stretches: [name, role]."""
glob Q3DM12_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["lavapit", "flow"],
         ["pumps", "flow"],
         ["furnace", "hub"],
         ["lavapit", "hub"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of q3dm12's stretches by its name."""
def make_q3dm12(name: str, key: str) -> Prefab {
    if name == "gate" {
        return DredGate();
    }
    if name == "lavapit" {
        return DredLavaPit();
    }
    if name == "pumps" {
        return DredPumpRoom();
    }
    if name == "furnace" {
        return DredFurnace();
    }
    if name == "vault" {
        return DredVault(key=key if key else "key_silver");
    }
    return DredExit(key=key);
}
