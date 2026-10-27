"""Prefabs drawn from Quake III's q3dm11, Deva Station: a station of decks
and catwalks over a machine floor, glass doors opened by a shot button
whose grenade traps go off down the corridor (the original's shooters on
staggered delays), a hurting pit under an atrium with a pad up out of it
and teleporters, a reactor ringed by catwalks one over another, and a
secret behind a wall. Quake III's arenas hold no foes of their own;
q3dm11's are grunts and enforcers, ogres as a run goes deeper.

- `DevaDock`: the start. A bay, a control platform across its far end up
  a ramp or a lift, a service trench along one side under a grate, a way
  on from each of the three.
- `DevaGlassDoors`: a corridor split by a glass wall. Shooting the button
  beside its doors opens them and sets off the traps along the walls; or
  the long way round, over a catwalk through the wall's top, up a stair or
  a lift. A secret closet behind a wall that opens when shot.
- `DevaCatwalks`: a machine hall: platforms at both ends joined by
  catwalks over a machine floor with slime in it, a crosswalk, a high
  catwalk ridden up to by a lift; a teleporter from the machine floor back
  up, a way on down there too.
- `DevaAtrium`: the hub. Balconies on arcades along both walls over a
  floor round a hurting pit; a pad in the pit throws a body up onto a
  balcony, teleporters on the balconies back down, a bridge over the pit.
- `DevaReactor`: a reactor core ringed by catwalks at two heights, one
  over the other, stairs (or a lift) between them, bridges out from each.
- `DevaControl`: the key room. A control deck up a lift or a stair, the
  key behind glass doors a shot button opens (or out on the deck); taking
  it sets off the traps and opens the closets.
- `DevaAirlock`: the end (or a gate). Past the door, its traps go off; the
  way out on a gantry a pad throws a body up to, or on a dais."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, hurt, key_taken, pit_fall, pad_to, closets, wake_on }

glob Q3DM11: str = "q3:q3dm11",
     Q3DM11_LIGHT: list[str] = ["monster_army", "monster_enforcer"],
     Q3DM11_HEAVY: list[str] = ["monster_ogre"];

"""A foe for Deva Station."""
def deva_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM11_LIGHT, Q3DM11_HEAVY, strong);
}

"""Traps along a wall (the cell line y = `line`, firing the way `out`
goes, 1 +y or 3 -y) at each of `xs`, `z` lifts up, set off one after
another when `fired` fires (Deva's grenade shooters on their delays)."""
def deva_traps(build: Raising, fired: Cue, xs: list[int], line: float, z: float, out: int) {
    for (index, x) in enumerate(xs) {
        late = build.delay(0.4 + 0.6 * float(index));
        fired +>:Fires:+> late;
        late +>:Fires:+> build.spikes(float(x) + 0.5, line, z, out);
    }
}

"""The start: a bay, a control platform across its far end, a service
trench along one side."""
node DevaDock(Prefab) {
    has lifted: bool = False,
        grated: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva dock";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(24, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(14, 16);
        self.lifted = dice.chance(0.4);
        self.grated = dice.chance(0.7);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=5),
            Port(face=1, along=float(self.long - 4), floor=5),
            Port(face=3, along=6.0, floor=-6),
            Port(face=1, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        p = 5;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, p);
        build.level(bay, -6);
        # The control platform across the far end, up a ramp or a lift.
        build.solid(self.long - 6, 1, 0, self.long - 1, self.wide - 1, p);
        if self.lifted {
            lift(build, self.long - 9, mid - 1, self.long - 6, mid + 2, 0, p);
            keep_box(build, bay, self.long - 6, mid - 1, self.long - 5, mid + 2, p);
        } else {
            stair(build, self.long - 11, mid - 2, 0, 0, p, 4);
            keep_box(build, bay, self.long - 6, mid - 2, self.long - 5, mid + 2, p);
        }
        # The service trench along the south wall, steps up at its east end,
        # a grate over part of it, its west end open to step down into.
        build.widen(bay, 4, 1, -6, self.long - 7, 5, 0);
        stair(build, self.long - 13, 1, -6, 0, 6, 4);
        if self.grated and self.long - 14 - 8 >= 3 {
            deck(build, 8, 1, self.long - 14, 5, 0);
        }
        keep_box(build, bay, 4, 5, 8, 6, 0);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # At the platform's foot its guards wake.
        guards = wake_on(build, float(self.long - 12), float(mid - 3), float(self.long - 7), float(mid + 3), 0.0);
        build.foe(float(self.long) - 3.5, 3.5, p, deva_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, p, deva_foe(dice, self.danger, True), 180.0, waits=guards);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(mid) + 3.5, 0, deva_foe(dice, self.danger), 180.0);
        }
        build.foe(5.5, 2.5, -6, "monster_enforcer", 0.0, patrol=[[5.5, 2.5], [float(self.long) - 15.5, 2.5]]);
        build.supply(float(self.long) - 3.0, float(mid) + 0.5, p, Q3_ARMOR, "q3");
        build.supply(6.0, 2.5, -6, Q3_HEALTH, "q3");
    }
}

"""A corridor split by a glass wall, its doors opened by a shot button that
sets off the traps; a catwalk through the wall's top the long way round;
a secret closet."""
node DevaGlassDoors(Prefab) {
    has lifted: bool = False,
        hidden: bool = False,
        traps: int = 3,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva glass doors";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(30, 32);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(15, 16);
        self.lifted = dice.chance(0.4);
        self.hidden = dice.chance(0.5);
        self.traps = dice.between(2, 3);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        gx = self.long // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 8);
        # The glass wall, its doors, the button beside them shot to open them;
        # the traps along the south wall go off one after another.
        build.solid(gx, 1, 0, gx + 1, self.wide - 1, self.tall);
        build.widen(hall, gx, mid - 2, 0, gx + 1, mid + 2, 7);
        doors = build.opened(float(gx), float(mid - 2), 0.0, float(gx + 1), float(mid + 2), 7.0);
        press = build.push(float(gx), float(mid) + 3.5, 3.0, 2, True);
        press +>:Fires:+> doors;
        deva_traps(build, press, [gx - 2 - index * 2 for index in range(self.traps)], 1.2, 2.0, 1);
        far = build.waiting();
        late = build.delay(1.0);
        press +>:Fires:+> late;
        late +>:Fires:+> far;
        # The long way round: a catwalk through the wall's top along the
        # north wall, up a stair or a lift, dropped off on the far side.
        build.widen(hall, gx, self.wide - 4, 8, gx + 1, self.wide - 1, self.tall);
        deck(build, gx - 6, self.wide - 4, gx + 7, self.wide - 1, 8);
        if self.lifted {
            lift(build, gx - 9, self.wide - 4, gx - 6, self.wide - 1, 0, 8);
        } else {
            stair(build, gx - 14, self.wide - 4, 0, 0, 8, 3);
        }
        keep_box(build, hall, gx - 6, self.wide - 4, gx - 5, self.wide - 1, 8);
        keep_box(build, hall, gx + 6, self.wide - 4, gx + 7, self.wide - 1, 8);
        over = build.touch(float(gx + 3), float(self.wide - 4), 8.0, float(gx + 7), float(self.wide - 1), 14.0);
        over +>:Fires:+> far;
        # The secret: a closet in a block by the south wall, behind a stretch
        # of its wall that opens when shot.
        if self.hidden {
            build.solid(3, 1, 0, 9, 4, self.tall);
            build.room(5, 1, 0, 7, 3, 4);
            build.secret_door(5.0, 3.0, 0.0, 7.0, 4.0, 4.0, 3);
            build.secret(5.0, 1.0, 0.0, 7.0, 3.0, 3.0);
            build.supply(6.0, 2.0, 0, Q3_ARMOR, "q3");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(gx) - 4.5, float(mid) + 3.5, 0, deva_foe(dice, self.danger), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(gx + 4 + index * 3) + 0.5, float(mid) + (2.5 if index % 2 == 0 else -2.5), 0, deva_foe(dice, self.danger, index == 2), 180.0, waits=far);
        }
        build.foe(float(gx) + 1.5, float(self.wide) - 2.5, 8, "monster_enforcer", 180.0);
        build.foe(float(self.long) - 4.5, 3.5, 0, "monster_army", 90.0, patrol=[[float(self.long) - 4.5, 3.5], [float(gx) + 3.5, 3.5]]);
        build.supply(float(self.long) - 3.0, float(mid) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""A machine hall: platforms at both ends joined by catwalks over a machine
floor with slime in it, a high catwalk, a teleporter back up."""
node DevaCatwalks(Prefab) {
    has upper: bool = True,
        crossed: bool = False,
        pools: int = 1,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva catwalks";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(16, 17);
        self.upper = dice.chance(0.7);
        self.crossed = dice.chance(0.5);
        self.pools = dice.between(1, 2);
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long // 2), floor=-8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -8;
        mid = self.wide // 2;
        cx = self.long // 2;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The platforms at both ends, the catwalks between them.
        build.solid(1, 1, lo, 6, self.wide - 1, 0);
        build.solid(self.long - 6, 1, lo, self.long - 1, self.wide - 1, 0);
        deck(build, 6, 2, self.long - 6, 5, 0);
        deck(build, 6, self.wide - 5, self.long - 6, self.wide - 2, 0);
        if self.crossed {
            deck(build, cx - 1, 5, cx + 2, self.wide - 5, 0);
        }
        # A lip of the south catwalk to step off down to the machine floor.
        keep_box(build, hall, cx + 3, 4, cx + 6, 5, 0);
        # The high catwalk, ridden up to by a lift on the far platform and
        # dropped off at its west end.
        if self.upper {
            uc = mid + 2;
            build.level(hall, 7);
            deck(build, 6, uc, self.long - 6, uc + 3, 7);
            lift(build, self.long - 6, uc, self.long - 3, uc + 3, 0, 7);
            keep_box(build, hall, 6, uc, 7, uc + 3, 7);
            keep_box(build, hall, self.long - 7, uc, self.long - 6, uc + 3, 7);
            build.foe(float(cx) + 0.5, float(uc) + 1.5, 7, deva_foe(dice, self.danger, True), 180.0);
        }
        # Slime in the machine floor, and the teleporter back up.
        for index in range(self.pools) {
            px = 8 + index * 7;
            build.pool(px, 7, lo - 2, px + 4, 11, lo, 3);
            hurt(build, float(px), 7.0, float(lo - 2), float(px + 4), 11.0, float(lo));
        }
        build.teleporter(float(self.long) - 9.0, 4.0, lo, 3.5, 3.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down on the machine floor what waits there wakes.
        below = wake_on(build, float(cx + 2), 5.0, float(cx + 7), 7.0, float(lo));
        build.foe(float(self.long) - 10.5, float(self.wide) - 6.5, lo, deva_foe(dice, self.danger), 180.0, waits=below);
        build.foe(9.5, 5.5, lo, "monster_army", 0.0, patrol=[[9.5, 5.5], [float(self.long) - 9.5, 5.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, 3.5 if index % 2 == 0 else float(self.wide) - 3.5, 0, deva_foe(dice, self.danger), 0.0);
        }
        build.supply(float(self.long) - 3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 11.0, float(mid) + 2.5, lo, Q3_ARMOR, "q3");
    }
}

"""The hub: balconies on arcades over a floor round a hurting pit, a pad up
out of it, teleporters back down, a bridge over it."""
node DevaAtrium(Prefab) {
    has lifted: bool = False,
        bridged: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva atrium";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(19, 20);
        self.lifted = dice.chance(0.4);
        self.bridged = dice.chance(0.5);
        self.low = -11;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=1, along=float(self.long - 6), floor=8),
            Port(face=3, along=float(self.long - 6), floor=8),
            Port(face=0, along=3.0, floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        gal = 8;
        px = cx - 3;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, gal);
        build.level(hall, -10);
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        for x in range(4, self.long - 3, 4) {
            if x < px - 2 or x > px + 2 {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        # The pit: its floor hurts, a pad in it throws a body up onto the
        # north balcony.
        guards = build.waiting();
        build.widen(hall, cx - 5, cy - 4, -10, cx + 5, cy + 4, 0);
        pit_fall(build, cx - 5, cy - 4, cx + 5, cy + 4, -10, "The pit drains your strength", guards);
        pad_to(build, float(px) + 0.5, float(cy + 1), -10, float(px) + 0.5, float(self.wide) - 3.0, gal);
        keep_box(build, hall, px - 1, self.wide - 5, px + 2, self.wide - 4, gal);
        if self.bridged {
            deck(build, cx - 1, cy - 4, cx + 2, cy + 4, 0);
            keep_box(build, hall, cx - 1, cy - 5, cx + 2, cy - 4, 0);
            keep_box(build, hall, cx - 1, cy + 4, cx + 2, cy + 5, 0);
        }
        # Up to the south balcony: a stair, or a lift.
        if self.lifted {
            lift(build, 4, 5, 7, 8, 0, gal);
            keep_box(build, hall, 4, 4, 7, 5, gal);
        } else {
            stair(build, 3, 5, 0, 0, gal, 3);
            keep_box(build, hall, 9, 4, 12, 5, gal);
        }
        # Teleporters on the balconies back down to the floor by the way in.
        build.teleporter(float(self.long - 10), 3.0, gal, 3.5, float(cy) + 3.5, 0, 0.0);
        build.teleporter(float(self.long - 10), float(self.wide) - 3.0, gal, 3.5, float(cy) - 2.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(cx) + 5.5, float(self.wide) - 2.5, gal, deva_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(cx) + 5.5, 2.5, gal, deva_foe(dice, self.danger, True), 180.0, waits=guards);
        up = wake_on(build, 3.0, 1.0, 12.0, 5.0, float(gal));
        build.foe(float(self.long) - 4.5, 3.5, gal, deva_foe(dice, self.danger), 180.0, waits=up);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 6 + index * 6) + 0.5, float(cy) + (6.5 if index % 2 == 0 else -6.5), 0, deva_foe(dice, self.danger), 0.0);
        }
        build.foe(4.5, float(cy) + 6.5, 0, "monster_enforcer", 0.0, patrol=[[4.5, float(cy) + 6.5], [float(self.long) - 4.5, float(cy) + 6.5]]);
        build.foe(float(cx) + 2.5, float(cy) - 1.5, -10, deva_foe(dice, self.danger), 180.0);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, -10, Q3_ARMOR, "q3");
        build.supply(3.0, float(self.wide) - 3.0, gal, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(cy) + 3.5, 0, Q3_HEALTH, "q3");
    }
}

"""A reactor core ringed by catwalks at two heights, one over the other,
stairs (or a lift) between them, bridges out from each."""
node DevaReactor(Prefab) {
    has lifted: bool = False,
        open_side: bool = False,
        tall: int = 23;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva reactor";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(20, 22);
        self.wide = self.long;
        self.tall = dice.between(23, 24);
        self.lifted = dice.chance(0.4);
        self.open_side = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        cx = self.long // 2;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [Port(face=0, along=float(cy), floor=14), Port(face=3, along=float(cx + 4), floor=7), Port(face=1, along=5.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 7);
        build.level(hall, 14);
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tall);
        # The rings round the core, the higher over the lower (its west side
        # left open to drop from, now and then).
        for z in [7, 14] {
            deck(build, cx - 6, cy - 6, cx + 6, cy - 3, z);
            deck(build, cx - 6, cy + 3, cx + 6, cy + 6, z);
            deck(build, cx + 3, cy - 3, cx + 6, cy + 3, z);
            if z == 7 or not self.open_side {
                deck(build, cx - 6, cy - 3, cx - 3, cy + 3, z);
            }
        }
        if self.open_side {
            keep_box(build, hall, cx - 6, cy + 3, cx - 3, cy + 4, 14);
        }
        # Up from the floor along the south wall to the lower ring.
        stair(build, cx - 6, cy - 9, 0, 0, 7, 3);
        keep_box(build, hall, cx - 1, cy - 6, cx + 2, cy - 5, 7);
        # From the lower ring to the higher along the north wall.
        if self.lifted {
            lift(build, cx + 2, cy + 6, cx + 5, cy + 9, 7, 14);
            keep_box(build, hall, cx + 2, cy + 5, cx + 5, cy + 6, 7);
            keep_box(build, hall, cx + 2, cy + 5, cx + 5, cy + 6, 14);
        } else {
            stair(build, cx + 5, cy + 6, 7, 2, 7, 3);
            keep_box(build, hall, cx + 3, cy + 5, cx + 6, cy + 6, 7);
            keep_box(build, hall, cx - 2, cy + 5, cx + 1, cy + 6, 14);
        }
        # Bridges out: from the higher ring east, from the lower south.
        deck(build, cx + 6, cy - 2, self.long - 1, cy + 2, 14);
        deck(build, cx + 2, 1, cx + 6, cy - 6, 7);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        lower = wake_on(build, float(cx - 1), float(cy - 6), float(cx + 2), float(cy - 3), 7.0);
        build.foe(float(cx) + 4.5, float(cy) + 4.5, 7, deva_foe(dice, self.danger), 180.0, waits=lower);
        build.foe(float(cx) - 4.5, float(cy) + 4.5, 14, deva_foe(dice, self.danger), 0.0, waits=lower);
        build.foe(float(cx) + 4.5, float(cy) - 0.5, 14, deva_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) - 4.5, float(cy) - 4.5, 0, "monster_army", 0.0, patrol=[[float(cx) - 4.5, float(cy) - 4.5], [float(cx) + 4.5, float(cy) - 4.5], [float(cx) + 4.5, float(cy) + 4.5], [float(cx) - 4.5, float(cy) + 4.5]]);
        build.supply(float(cx) + 4.5, float(cy) + 1.5, 14, Q3_ARMOR, "q3");
        build.supply(float(cx) - 4.5, float(cy) - 1.5, 7, Q3_HEALTH, "q3");
    }
}

"""The key room: a control deck, the key behind glass doors a shot button
opens (or out on the deck); taking it sets off the traps and opens the
closets."""
node DevaControl(Prefab) {
    has key: str = "key_silver",
        glass: bool = True,
        lifted: bool = False,
        hall_wide: int = 16,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(21, 23);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.glass = dice.chance(0.6);
        self.lifted = dice.chance(0.5);
        self.tall = 16;
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
        dh = 6;
        dx = self.long - 9;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, dh);
        build.doorway(room, self.enter);
        build.solid(dx, 1, 0, self.long - 1, side, dh);
        if self.lifted {
            lift(build, dx - 3, cy - 1, dx, cy + 2, 0, dh);
            keep_box(build, room, dx, cy - 1, dx + 1, cy + 2, dh);
        } else {
            stair(build, dx - dh, 1, 0, 0, dh, 3);
            keep_box(build, room, dx, 1, dx + 1, 4, dh);
        }
        taken: Cue | None = None;
        if self.glass {
            # The alcove behind the glass, its doors opened by the button
            # beside them, shot.
            build.solid(self.long - 5, 1, dh, self.long - 4, side, self.tall);
            build.widen(room, self.long - 5, cy - 2, dh, self.long - 4, cy + 2, dh + 7);
            doors = build.opened(float(self.long - 5), float(cy - 2), float(dh), float(self.long - 4), float(cy + 2), float(dh + 7));
            press = build.push(float(self.long - 5), float(cy) + 3.5, float(dh) + 3.0, 2, True);
            press +>:Fires:+> doors;
            taken = key_taken(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, dh);
        } else {
            taken = key_taken(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, dh);
        }
        if taken is not None {
            closets(build, taken, side, 0, [2, 7], [deva_foe(dice, self.danger, True), deva_foe(dice, self.danger)]);
            deva_traps(build, taken, [3, 7, 11], float(side) - 0.2, 9.0, 3);
        }
        build.foe(float(dx) + 2.5, 3.5, dh, deva_foe(dice, self.danger), 180.0);
        build.foe(float(dx) - 5.5, float(cy) + 3.5, 0, deva_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(dx) + 1.5, float(side) - 2.5, dh, Q3_ARMOR, "q3");
    }
}

"""An end (or a gate): past the door its traps go off; the way out on a
gantry thrown up to by a pad, or on a dais."""
node DevaAirlock(Prefab) {
    has key: str = "",
        gantry: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deva airlock" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM11;
        self.district = level_district(Q3DM11);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gantry = dice.chance(0.5);
        self.tall = dice.between(17, 18);
        self.low = -1;
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
        inside = build.touch(float(wall + 1), float(mid - 2), 0.0, float(wall + 3), float(mid + 2), 6.0);
        guards = build.waiting();
        late = build.delay(0.8);
        inside +>:Fires:+> late;
        late +>:Fires:+> guards;
        deva_traps(build, inside, [wall + 4, wall + 7, wall + 10], 1.2, 2.0, 1);
        if self.gantry {
            gx = self.long - 6;
            build.level(room, 8);
            deck(build, gx, 1, self.long - 1, self.wide - 1, 8);
            for y in range(3, self.wide - 2, 4) {
                build.solid(gx, y, 0, gx + 1, y + 1, 7);
            }
            pad_to(build, float(gx - 3), float(mid), 0, float(gx) + 2.5, 3.0, 8);
            keep_box(build, room, gx, mid - 2, gx + 1, mid + 2, 8);
            build.way_out(float(self.long) - 3.0, float(mid), 8);
            build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, 8, deva_foe(dice, self.danger, True), 180.0, waits=guards);
        } else {
            dx = self.long - 10;
            build.solid(dx, mid - 4, 0, self.long - 2, mid + 4, 3);
            stair(build, dx - 3, mid - 2, 0, 0, 3, 4);
            build.way_out(float(dx) + 4.0, float(mid), 3);
            build.foe(float(self.long) - 3.5, 2.5, 0, deva_foe(dice, self.danger, True), 180.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, deva_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 8.5, float(self.wide) - 3.5, 0, deva_foe(dice, self.danger), 180.0, waits=guards);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm11's stretches: [name, role]."""
glob Q3DM11_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["glass", "flow"],
         ["catwalks", "flow"],
         ["reactor", "flow"],
         ["atrium", "hub"],
         ["control", "keyroom"],
         ["airlock", "end"],
         ["airlock", "gate"]
     ];

"""One of q3dm11's stretches by its name."""
def make_q3dm11(name: str, key: str) -> Prefab {
    if name == "dock" {
        return DevaDock();
    }
    if name == "glass" {
        return DevaGlassDoors();
    }
    if name == "catwalks" {
        return DevaCatwalks();
    }
    if name == "reactor" {
        return DevaReactor();
    }
    if name == "atrium" {
        return DevaAtrium();
    }
    if name == "control" {
        return DevaControl(key=key if key else "key_silver");
    }
    return DevaAirlock(key=key);
}
