"""Prefabs drawn from Quake III's q3dm9, Hero's Keep: a gothic keep over an
abyss. Its main floors run round pits whose hurting floors lie far below,
where wind pads throw a fallen body back up by way of ledges in the pit
walls (the original's pushes at -512, -93 and 11), a trench cut down
through a plaza to a lower hall with lava in its floor, a court round a
tower with a gallery bridged from its top, and jump pads up to every
high place. Quake III's arenas hold no foes of their own; q3dm9's are
knights and ogres, hell knights as a run goes deeper.

- `KeepGatehouse`: the start. A hall open to the sky under one or two
  galleries over arcades, its floor climbing in three bays from the gate,
  the galleries climbed by a stair or a jump pad; a bridge across between
  them when there are two. The gallery's guards wake as the player comes
  up.
- `KeepPit`: the abyss (a flow, or a hub). A rim round (or across) a deep
  pit under the sky, its far side stood higher than its near, crossed by
  a bridge or by jump pads to an island and on; the pit's
  floor hurts, its fall wakes what waits on the far rim, and a wind pad
  (or two, by a ledge in the pit wall, a way out leaving from that ledge)
  throws a body back up.
- `KeepTrench`: a plaza under the sky, each bank of it at heights of its
  own, a trench cut down through it to a lower hall, reached by a grand
  stair or by a narrow stair beside a lift; lava down
  one side of its floor, bridges over it at the plaza's height, a pad back
  up out of it; ways on above and below.
- `KeepCourt`: the hub. A court under the sky going up round a tower in
  terraces, the tower climbed by a stair or a jump pad, a bridge from its
  top to a gallery along the far wall (a pad up to that too), a hurting
  wind pit beside the tower; ways on from the court and the gallery.
- `KeepReliquary`: the key room. The key on a spire, thrown up to by a pad
  from a gallery; or at the bottom of a crypt, a wind pad back out. Taking
  it brings foes in by teleporter and wakes the ones lying in wait.
- `KeepBattlements`: the end (or a gate). Past the door, battlements along
  the far wall over an arcade, climbed by stairs up both side walls or by
  a jump pad; the way out on the battlements, its guards woken by the
  door."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, hurt, key_taken, pit_fall, pad_to }
import from .q3open_parts { vista, rising_bays, bay_floor }

glob Q3DM9: str = "q3:q3dm9",
     Q3DM9_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3DM9_HEAVY: list[str] = ["monster_hell_knight"];

"""A foe for Hero's Keep."""
glob KEEP_FOES: FoeMix = FoeMix(light=Q3DM9_LIGHT, strong=Q3DM9_HEAVY, heavy_light=Q3DM9_HEAVY, scale=0.5);

"""The start: a hall under one or two galleries over arcades."""
node KeepGatehouse(Prefab) {
    has gallery: int = 9,
        both: bool = False,
        padded: bool = False,
        well: bool = True,
        span_x: int = 12,
        bay1: int = 9,
        bay2: int = 18,
        tall: int = 46;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep gatehouse";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(24, 28);
        self.wide = dice.between(18, 21);
        self.gallery = dice.between(9, 10);
        self.both = dice.chance(0.6);
        self.padded = dice.chance(0.5);
        self.well = dice.chance(0.7);
        # The bridge stands clear of the stair up to the gallery, off its top.
        self.span_x = dice.between(self.long // 2 - 2, self.long - 11) if self.padded else 6 + self.gallery;
        self.bay1 = dice.between(8, 10);
        self.bay2 = self.long - dice.between(8, 10);
        self.tall = self.gallery + dice.between(36, 40);
        self.low = -9 if self.well else -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=4),
            Port(face=0, along=3.0, floor=self.gallery),
            Port(face=3, along=float(self.long - 5), floor=self.gallery),
            Port(face=1, along=float(self.long - 5), floor=self.gallery if self.both else 4)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gal = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, gal);
        build.level(hall, 2);
        build.level(hall, 4);
        # The hall's floor climbs in three bays from the gate, a step between
        # each, as the keep's floors stand at heights of their own.
        rising_bays(build, self.bay1, self.bay2, 1, self.long - 1, self.wide - 1);
        # The south gallery over its arcade (and the north one).
        deck(build, 1, 1, self.long - 1, 6, gal);
        for x in range(4, self.long - 3, 4) {
            build.solid(x, 5, 0, x + 1, 6, gal - 1);
        }
        if self.both {
            deck(build, 1, self.wide - 6, self.long - 1, self.wide - 1, gal);
            for x in range(4, self.long - 3, 4) {
                if x < self.span_x - 1 or x > self.span_x + 3 {
                    build.solid(x, self.wide - 6, 0, x + 1, self.wide - 5, gal - 1);
                }
            }
            # The bridge across between them, a step up from either.
            deck(build, self.span_x, 6, self.span_x + 3, self.wide - 6, gal + 1);
            keep_box(build, hall, self.span_x, 6, self.span_x + 3, 7, gal + 1);
            keep_box(build, hall, self.span_x, self.wide - 7, self.span_x + 3, self.wide - 6, gal + 1);
            keep_box(build, hall, self.span_x, 5, self.span_x + 3, 6, gal);
            keep_box(build, hall, self.span_x, self.wide - 6, self.span_x + 3, self.wide - 5, gal);
        }
        # Up to the south gallery: a stair along its edge, or a jump pad.
        up_x = 6;
        if self.padded {
            pad_to(build, 6.5, 9.0, bay_floor(6, self.bay1, self.bay2), 6.5, 3.0, gal);
            keep_box(build, hall, 5, 5, 9, 6, gal);
            up_x = 5;
        } else {
            stair(build, 6, 6, 0, 0, gal, 3);
            keep_box(build, hall, 3 + gal, 5, 7 + gal, 6, gal);
            up_x = 4 + gal;
        }
        # The well at the hall's far end: its floor burns, a wind pad in it
        # throws a body up onto the south gallery.
        if self.well {
            wx = self.long - 7;
            build.widen(hall, wx, middle - 1, -8, wx + 4, middle + 3, 4);
            pit_fall(build, wx, middle - 1, wx + 4, middle + 3, -8, "The well's floor burns", build.waiting());
            pad_to(build, float(wx + 2), float(middle) + 1.5, -8, float(wx + 2), 3.0, gal);
            keep_box(build, hall, wx, middle - 2, wx + 4, middle - 1, 4);
            keep_box(build, hall, wx, 5, wx + 4, 6, gal);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        # The gallery's guards wake as the player comes up to it.
        up = build.touch(float(up_x - 2), 1.0, float(gal), float(up_x + 3), 6.0, float(gal + 6));
        guards = build.waiting();
        up +>:Fires:+> guards;
        build.foe(float(self.long) - 4.5, 3.5, gal, KEEP_FOES.pick(dice, self.danger), 180.0, waits=guards);
        if self.both {
            build.foe(float(self.long) - 4.5, float(self.wide) - 3.5, gal, KEEP_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
            build.supply(float(self.span_x) + 1.5, float(middle) + 0.5, gal + 1, Q3_ARMOR, "q3");
        } else {
            build.supply(float(self.long) - 3.0, 2.5, gal, Q3_ARMOR, "q3");
        }
        for index in range(dice.between(1, 2)) {
            at = self.bay1 + 2 + index * 3;
            build.foe(float(at) + 0.5, float(middle) + (2.5 if index % 2 == 0 else 1.5), bay_floor(at, self.bay1, self.bay2), KEEP_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) - 2.5, 4, KEEP_FOES.pick(dice, self.danger, True), 180.0);
        # A knight walks the middle bay's length.
        build.foe(float(self.bay1) + 2.5, float(middle) + 4.0, 2, "monster_knight", 0.0, patrol=[[float(self.bay1) + 2.5, float(middle) + 4.0], [float(self.bay2) - 1.5, float(middle) + 4.0]]);
        build.supply(float(self.long) - 3.0, float(middle) - 2.5, 4, Q3_HEALTH, "q3");
    }
}

"""The abyss: a rim round (or across) a deep pit, a bridge or pads over
it, a hurting floor and wind pads back up."""
node KeepPit(Prefab) {
    has deep: int = 12,
        shelf: int = 0,
        crossing: int = 0,
        ring: bool = False,
        tall: int = 46;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep pit";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        if dice.chance(0.5) {
            self.deep = dice.between(22, 26);
            self.shelf = self.deep // 2;
            self.ring = False;
        } else {
            self.deep = dice.between(14, 16);
            self.shelf = 0;
            self.ring = dice.chance(0.5);
        }
        self.crossing = dice.below(2);
        self.tall = dice.between(46, 50);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        px1 = self.long - 7;
        self.enter = vista(2, middle, 0);
        self.leaves = [vista(0, middle, 2), Port(face=1, along=float(self.long - 4), floor=2)];
        if self.shelf > 0 {
            self.leaves.append(Port(face=3, along=float(px1 - 3), floor=-self.shelf));
        } else {
            self.leaves.append(Port(face=3, along=float(self.long - 4), floor=2));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        mid = self.wide // 2;
        cx = self.long // 2;
        px0 = 7;
        px1 = self.long - 7;
        y0 = 5 if self.ring else 1;
        y1 = self.wide - 5 if self.ring else self.wide - 1;
        far = 2;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 0);
        build.level(hall, far);
        build.solid(1, 1, low, self.long - 1, self.wide - 1, 0);
        build.widen(hall, px0, y0, low, px1, y1, 0);
        # The far rim stands two lifts over the near (the rim's sides between
        # them a lift up, when it runs right round), so no floor runs on.
        build.solid(px1, 1, 0, self.long - 1, self.wide - 1, far);
        if self.ring {
            build.solid(px0, 1, 0, px1, y0, 1);
            build.solid(px0, y1, 0, px1, self.wide - 1, 1);
        }
        # What waits on the far rim wakes when the pit is fallen into or
        # crossed.
        guards = build.waiting();
        pit_fall(build, px0, y0, px1, y1, low, "The pit's floor burns", guards);
        # The way back up: a wind pad, or two by a ledge in the pit's far
        # wall (a way out leaving from that ledge).
        if self.shelf > 0 {
            build.level(hall, -self.shelf);
            build.solid(px1 - 6, 1, low, px1, 9, -self.shelf);
            pad_to(build, float(px1 - 9), 5.0, low, float(px1) - 2.0, 6.5, -self.shelf);
            keep_box(build, hall, px1 - 6, 2, px1 - 5, 9, -self.shelf);
            pad_to(build, float(px1 - 3), 3.0, -self.shelf, float(px1) + 2.0, 3.0, far);
            keep_box(build, hall, px1, 1, px1 + 1, 6, far);
            build.foe(float(px1) - 2.5, 7.5, -self.shelf, KEEP_FOES.pick(dice, self.danger), 180.0, waits=guards);
        } else {
            py = y0 + 2;
            pad_to(build, float(px1 - 3), float(py), low, float(px1) + 2.0, float(py), far);
            keep_box(build, hall, px1, py - 2, px1 + 1, py + 2, far);
        }
        # Where a body may step off into the pit.
        keep_box(build, hall, px0 - 1, y1 - 4, px0, y1, 0);
        # A high ledge along the north wall over the pit, thrown up to from
        # the near rim, dropped off at its far end.
        hl = 8;
        build.level(hall, hl);
        deck(build, px0, self.wide - 4, px1, self.wide - 1, hl);
        pad_to(build, float(px0 - 3), float(self.wide) - 2.5, 0, float(px0) + 2.0, float(self.wide) - 2.5, hl);
        keep_box(build, hall, px0, self.wide - 4, px0 + 1, self.wide - 1, hl);
        keep_box(build, hall, px1 - 1, self.wide - 4, px1, self.wide - 1, hl);
        build.supply(float(cx) + 0.5, float(self.wide) - 2.5, hl, Q3_HEALTH, "q3");
        build.foe(float(px1) - 3.5, float(self.wide) - 2.5, hl, KEEP_FOES.pick(dice, self.danger), 180.0, waits=guards);
        # The crossing: a bridge a lift up from the near rim and a lift down
        # from the far, or pads to an island and on.
        if self.crossing == 0 {
            deck(build, px0, mid - 1, px1, mid + 2, 1);
            keep_box(build, hall, px0 - 1, mid - 1, px0, mid + 2, 0);
            keep_box(build, hall, px1, mid - 1, px1 + 1, mid + 2, far);
            build.supply(float(cx) + 0.5, float(mid) + 0.5, 1, Q3_ARMOR, "q3");
        } else {
            # Out along one lane and back along the other, so a body that went
            # over can come back.
            ix0 = cx - 3;
            ix1 = cx + 4;
            out = float(mid) - 1.5;
            back = float(mid) + 1.5;
            build.solid(ix0, mid - 3, low, ix1, mid + 3, 0);
            pad_to(build, float(px0 - 3), out, 0, float(ix0) + 1.5, out, 0);
            pad_to(build, float(ix1 - 3), out, 0, float(px1) + 2.0, out, far);
            pad_to(build, float(px1 + 3), back, far, float(ix1) - 1.5, back, 0);
            pad_to(build, float(ix0 + 3), back, 0, float(px0) - 2.0, back, 0);
            keep_box(build, hall, px0 - 1, mid - 3, px0, mid + 3, 0);
            keep_box(build, hall, ix0, mid - 3, ix0 + 1, mid + 3, 0);
            keep_box(build, hall, ix1 - 1, mid - 3, ix1, mid + 3, 0);
            keep_box(build, hall, px1, mid - 3, px1 + 1, mid + 3, far);
            build.supply(float(cx) - 2.5, float(mid), 0, Q3_ARMOR, "q3");
        }
        cross = build.touch(float(cx - 1), float(mid - 2), 0.0, float(cx + 1), float(mid + 2), 6.0);
        cross +>:Fires:+> guards;
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(px1) + 3.5, float(mid) + (3.5 if index == 0 else -3.5), far, KEEP_FOES.pick(dice, self.danger, index == 1), 180.0, waits=guards);
        }
        build.foe(3.5, float(mid) + 4.5, 0, KEEP_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 2.5, float(mid) + 0.5, far, KEEP_FOES.pick(dice, self.danger, True), 180.0);
        if self.ring {
            build.foe(float(cx) + 0.5, 2.5, 1, "monster_knight", 0.0, patrol=[[float(px0) + 1.5, 2.5], [float(px1) - 1.5, 2.5]]);
        }
        build.supply(float(self.long) - 3.0, 2.5, far, Q3_HEALTH, "q3");
    }
}

"""A plaza, a trench cut down through it to a lower hall, lava down one
side of its floor, bridges over it, a pad back up."""
node KeepTrench(Prefab) {
    has trench: int = 9,
        grand: bool = True,
        lava: bool = True,
        bridges: int = 1,
        tall: int = 46;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep trench";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(30, 34);
        self.wide = dice.between(20, 22);
        self.trench = dice.between(8, 10);
        self.grand = dice.chance(0.5);
        self.lava = dice.chance(0.5);
        self.bridges = dice.between(1, 2);
        self.tall = dice.between(46, 50);
        self.low = -self.trench - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = vista(2, middle, 0);
        self.leaves = [
            Port(face=0, along=middle, floor=-self.trench),
            Port(face=1, along=float(self.long - 4), floor=3),
            Port(face=3, along=float(self.long - 4), floor=2),
            Port(face=0, along=3.0, floor=2)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.trench;
        mid = self.wide // 2;
        ty0 = mid - 3;
        ty1 = mid + 4;
        head = 9;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 0);
        build.level(hall, 2);
        build.level(hall, 3);
        build.solid(1, 1, low, self.long - 1, self.wide - 1, 0);
        build.widen(hall, head, ty0, low, self.long - 1, ty1, 0);
        # The plaza breaks as the trench cuts it: past the way in its head is
        # a lift up; the south bank goes on and up another at a step halfway
        # along it, the north bank a lift and two more, by steps of its own.
        step_x = (head + self.long) // 2;
        build.solid(5, 1, 0, head, self.wide - 1, 1);
        build.solid(head, 1, 0, self.long - 1, ty0, 1);
        build.solid(step_x, 1, 1, self.long - 1, ty0, 2);
        build.solid(head, ty1, 0, self.long - 1, self.wide - 1, 1);
        build.solid(head + 1, ty1, 1, self.long - 1, self.wide - 1, 2);
        build.solid(step_x, ty1, 2, self.long - 1, self.wide - 1, 3);
        # Down into the trench: a grand stair its whole width, or a narrow
        # one beside a lift.
        if self.grand {
            stair(build, head + self.trench - 1, ty0, low, 2, self.trench, ty1 - ty0);
        } else {
            stair(build, head + self.trench - 1, ty0, low, 2, self.trench, 3);
            lift(build, head, ty0 + 4, head + 3, ty1, low, 0);
            keep_box(build, hall, head - 1, ty0 + 4, head, ty1, 1);
        }
        foot = head + self.trench;
        pad_x = self.long - 7;
        # Lava down the north side of the trench's floor (and the south).
        build.pool(foot + 1, ty1 - 2, low - 2, pad_x - 1, ty1, low, 4, False, False);
        hurt(build, float(foot + 1), float(ty1 - 2), float(low - 2), float(pad_x - 1), float(ty1), float(low));
        if self.lava {
            build.pool(foot + 1, ty0, low - 2, pad_x - 1, ty0 + 2, low, 4, False, False);
            hurt(build, float(foot + 1), float(ty0), float(low - 2), float(pad_x - 1), float(ty0 + 2), float(low));
        }
        # Bridges over it, level with the south bank where they meet it and a
        # step under the north; each as high as the banks it joins allow.
        spots = [foot + 1, pad_x + 2];
        for index in range(self.bridges) {
            bx = spots[index];
            south = 2 if bx + 3 > step_x else 1;
            deck(build, bx, ty0, bx + 3, ty1, south);
            for z in [south - 1, south, south + 1] {
                keep_box(build, hall, bx, ty0 - 1, bx + 3, ty0, z);
                keep_box(build, hall, bx, ty1, bx + 3, ty1 + 1, z);
            }
        }
        # A pad near the trench's far end throws a body back up onto the
        # south bank; a stretch of that bank's lip may be stepped off.
        pad_to(build, float(pad_x), float(ty0 + 3), low, float(pad_x), float(ty0) - 2.0, 2);
        keep_box(build, hall, pad_x - 1, ty0 - 1, pad_x + 2, ty0, 2);
        if foot + 7 < pad_x - 1 {
            keep_box(build, hall, foot + 5, ty0 - 1, foot + 7, ty0, 1);
            keep_box(build, hall, foot + 5, ty0 - 1, foot + 7, ty0, 2);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Down at the stair's foot, what waits on the banks wakes.
        below = build.touch(float(foot), float(ty0), float(low), float(foot + 2), float(ty1), float(low + 6));
        banks = build.waiting();
        below +>:Fires:+> banks;
        build.foe(float(self.long) - 4.5, float(ty0) - 2.5, 2, KEEP_FOES.pick(dice, self.danger), 180.0, waits=banks);
        build.foe(float(self.long) - 6.5, float(ty1) + 2.5, 3, KEEP_FOES.pick(dice, self.danger, True), 180.0, waits=banks);
        build.foe(float(foot) + 2.5, float(mid) + 0.5, low, "monster_knight", 0.0, patrol=[[float(foot) + 2.5, float(mid) + 0.5], [float(pad_x) - 2.0, float(mid) + 0.5]]);
        build.foe(6.5, float(mid) + 4.5, 1, KEEP_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.5, float(ty0) + 2.5, low, KEEP_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(ty0) + 1.0, low, Q3_HEALTH, "q3");
        first = spots[0];
        build.supply(float(first) + 1.5, float(mid) + 0.5, 2 if first + 3 > step_x else 1, Q3_ARMOR, "q3");
    }
}

"""The hub: a court round a tower, a bridge from its top to a gallery, a
hurting wind pit beside it."""
node KeepCourt(Prefab) {
    has tower: int = 10,
        padded: bool = False,
        pit: bool = True,
        tall: int = 48;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep court";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tower = dice.between(10, 12);
        self.padded = dice.chance(0.5);
        self.pit = dice.chance(0.85);
        self.tall = self.tower + dice.between(36, 40);
        self.low = -10;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = vista(2, cy, 0);
        self.leaves = [
            Port(face=0, along=cy, floor=self.tower),
            Port(face=1, along=3.0, floor=0),
            Port(face=3, along=float(self.long // 2 + 6), floor=2),
            Port(face=1, along=float(self.long - 3), floor=self.tower)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        tw = self.tower;
        gx = self.long - 5;
        near = cx - 10;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, tw);
        build.level(court, 2);
        # The court goes up round its tower in terraces, each a step over the
        # last: from the gate a lift, each side of the tower two, behind it
        # three.
        build.solid(near, 1, 0, self.long - 1, self.wide - 1, 1);
        build.solid(cx - 4, 1, 1, self.long - 1, cy - 4, 2);
        build.solid(cx - 4, cy + 4, 1, self.long - 1, self.wide - 1, 2);
        build.solid(cx + 4, 1, 1, self.long - 1, self.wide - 1, 2);
        build.solid(cx + 4, cy - 4, 2, self.long - 1, cy + 4, 3);
        # The tower, and the gallery along the far wall over its arcade.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, tw);
        deck(build, gx, 1, self.long - 1, self.wide - 1, tw);
        for y in range(3, self.wide - 2, 4) {
            if y < cy - 2 or y > cy + 3 {
                build.solid(gx, y, 0, gx + 1, y + 1, tw - 1);
            }
        }
        # The bridge from the tower's top to the gallery.
        deck(build, cx + 4, cy - 1, gx, cy + 2, tw);
        keep_box(build, court, cx + 3, cy - 1, cx + 4, cy + 2, tw);
        keep_box(build, court, gx, cy - 1, gx + 1, cy + 2, tw);
        # Up the tower: a stair along its south face, or a pad.
        if self.padded {
            pad_to(build, float(cx - 7), float(cy), 1, float(cx) - 2.0, float(cy), tw);
            keep_box(build, court, cx - 4, cy - 2, cx - 3, cy + 2, tw);
        } else {
            stair(build, cx + 4 - tw, cy - 7, 0, 0, tw, 3);
            keep_box(build, court, cx + 1, cy - 4, cx + 4, cy - 3, tw);
        }
        # A pad up to the gallery from the court's floor; a stretch of the
        # gallery's lip to drop from.
        pad_to(build, float(gx - 3), 5.0, 2, float(gx) + 2.0, 5.0, tw);
        keep_box(build, court, gx, 3, gx + 1, 8, tw);
        keep_box(build, court, gx, self.wide - 6, gx + 1, self.wide - 3, tw);
        # The wind pit north of the tower.
        if self.pit {
            build.widen(court, cx - 3, cy + 6, -9, cx + 3, self.wide - 2, 2);
            guards = build.waiting();
            pit_fall(build, cx - 3, cy + 6, cx + 3, self.wide - 2, -9, "The pit's floor burns", guards);
            pad_to(build, float(cx), float(self.wide - 4), -9, float(cx) + 5.0, float(self.wide - 4), 2);
            keep_box(build, court, cx + 3, cy + 6, cx + 4, self.wide - 2, 2);
            build.foe(float(gx) + 2.5, float(self.wide) - 4.5, tw, KEEP_FOES.pick(dice, self.danger), 180.0, waits=guards);
        }
        # With the tower padded, its south side is clear for a second pit.
        if self.padded {
            build.widen(court, cx - 3, 2, -9, cx + 3, cy - 6, 2);
            south = build.waiting();
            pit_fall(build, cx - 3, 2, cx + 3, cy - 6, -9, "The pit's floor burns", south);
            pad_to(build, float(cx), 4.5, -9, float(cx) + 5.0, 4.5, 2);
            keep_box(build, court, cx + 3, 2, cx + 4, cy - 6, 2);
            build.foe(float(cx) + 6.5, 7.5, 2, KEEP_FOES.pick(dice, self.danger), 180.0, waits=south);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # On the tower's top, the gallery's guards wake.
        top = build.touch(float(cx - 4), float(cy - 4), float(tw), float(cx + 4), float(cy + 4), float(tw + 6));
        gallery = build.waiting();
        top +>:Fires:+> gallery;
        build.foe(float(gx) + 2.5, 3.5, tw, KEEP_FOES.pick(dice, self.danger), 180.0, waits=gallery);
        build.foe(float(gx) + 2.5, float(cy) + 0.5, tw, KEEP_FOES.pick(dice, self.danger, True), 180.0, waits=gallery);
        build.foe(float(cx) + 1.5, float(cy) + 1.5, tw, KEEP_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(near) + 1.5, float(cy + 5) + 0.5, 1, "monster_knight", 0.0, patrol=[[float(near) + 1.5, float(cy + 5) + 0.5], [float(near) + 1.5, float(self.wide) - 3.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(3.5, float(self.wide) - 3.5 - float(index) * 3.0, 0, KEEP_FOES.pick(dice, self.danger), 270.0);
        }
        build.supply(float(cx) - 1.5, float(cy) - 1.5, tw, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.0, tw, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a spire thrown up to from a gallery, or at the
bottom of a crypt with a wind pad out; taking it brings foes in."""
node KeepReliquary(Prefab) {
    has key: str = "key_silver",
        crypt: bool = False,
        hall_wide: int = 16,
        spire: int = 12,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep reliquary (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.crypt = dice.chance(0.5);
        self.spire = dice.between(11, 13);
        self.tall = self.spire + 22;
        self.low = -11 if self.crypt else -3;
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.doorway(hall, self.enter);
        ambush = build.waiting();
        if self.crypt {
            # The crypt: its floor ten lifts down, the key at its far end, a
            # wind pad back up onto the rim.
            build.level(hall, -10);
            build.widen(hall, 6, 4, -10, self.long - 5, side - 3, 0);
            keep_box(build, hall, 5, 4, 6, side - 3, 0);
            pit_fall(build, 6, 4, self.long - 5, side - 3, -10, "The crypt's floor burns", ambush);
            pad_to(build, float(self.long - 8), float(cy), -10, float(self.long) - 3.0, float(cy), 0);
            keep_box(build, hall, self.long - 5, cy - 2, self.long - 4, cy + 3, 0);
            taken = key_taken(build, self.key, float(self.long) - 6.5, float(side) - 5.5, -10);
            build.foe(9.5, float(cy) + 0.5, -10, KEEP_FOES.pick(dice, self.danger), 0.0);
            build.foe(float(self.long) - 2.5, float(side) - 2.5, 0, KEEP_FOES.pick(dice, self.danger), 180.0, waits=ambush);
            build.supply(8.0, float(side) - 5.0, -10, Q3_HEALTH, "q3");
        } else {
            # A gallery along the south wall over its arcade, up a stair; from
            # it a pad throws a body onto the spire, the key on its top.
            gal = 6;
            build.level(hall, gal);
            build.level(hall, self.spire);
            deck(build, 1, 1, self.long - 1, 5, gal);
            for x in range(4, self.long - 2, 4) {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
            }
            stair(build, 4, 5, 0, 0, gal, 3);
            keep_box(build, hall, 1 + gal, 4, 4 + gal, 5, gal);
            pad_to(build, float(self.long - 10), 8.0, 0, float(self.long - 10), 3.0, gal);
            keep_box(build, hall, self.long - 11, 4, self.long - 9, 5, gal);
            sx = self.long - 8;
            build.solid(sx, 9, 0, sx + 4, 13, self.spire);
            pad_to(build, float(sx + 2), 2.0, gal, float(sx + 2), 11.0, self.spire);
            keep_box(build, hall, sx + 1, 4, sx + 3, 5, gal);
            keep_box(build, hall, sx, 9, sx + 4, 10, self.spire);
            taken = key_taken(build, self.key, float(sx) + 2.0, 11.5, self.spire);
            # Lava in a channel behind the spire.
            build.pool(self.long - 3, 7, -2, self.long - 1, side, 0, 4, False, False);
            hurt(build, float(self.long - 3), 7.0, -2.0, float(self.long - 1), float(side), 0.0);
            build.foe(float(self.long) - 2.5, 2.5, gal, KEEP_FOES.pick(dice, self.danger), 180.0, waits=ambush);
            build.supply(2.5, 2.5, gal, Q3_HEALTH, "q3");
        }
        # Taken, the key brings foes in by teleporter and wakes the rest.
        taken +>:Fires:+> ambush;
        taken +>:Fires:+> build.summon(2, side + 1, 0, KEEP_FOES.pick(dice, self.danger, True), 3.5, float(cy) + 0.5, 0, 0.0);
        late = build.delay(1.5);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(8, side + 1, 0, KEEP_FOES.pick(dice, self.danger), 3.5, float(side) - 2.5, 0, 0.0);
        build.foe(float(self.long) - 3.5, 2.5, 0, KEEP_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): battlements along the far wall over an arcade, the
way out on them."""
node KeepBattlements(Prefab) {
    has key: str = "",
        wall_high: int = 9,
        padded: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep battlements" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM9;
        self.district = level_district(Q3DM9);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.wall_high = dice.between(9, 11);
        self.padded = dice.chance(0.5);
        self.tall = self.wall_high + dice.between(34, 38);
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        bh = self.wall_high;
        bx = self.long - 6;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        guards = build.waiting();
        build.level(room, bh);
        deck(build, bx, 1, self.long - 1, self.wide - 1, bh);
        for y in range(3, self.wide - 2, 4) {
            build.solid(bx, y, 0, bx + 1, y + 1, bh - 1);
        }
        if self.padded {
            pad_to(build, float(bx - 3), float(middle), 1, float(bx) + 2.5, 3.0, bh);
            keep_box(build, room, bx, middle - 2, bx + 1, middle + 2, bh);
        } else {
            # Stairs up both side walls to the battlements' ends.
            stair(build, bx - bh, 1, 0, 0, bh, 3);
            stair(build, bx - bh, self.wide - 4, 0, 0, bh, 3);
            keep_box(build, room, bx, 1, bx + 1, 4, bh);
            keep_box(build, room, bx, self.wide - 4, bx + 1, self.wide - 1, bh);
        }
        build.way_out(float(self.long) - 3.0, float(middle), bh);
        # The moat across the court, the ground a step higher past it: the
        # moat's floor burns, its wind throws a body up onto the battlements'
        # north end.
        mx = wall + 3;
        build.solid(mx + 4, 1, 0, self.long - 1, self.wide - 1, 1);
        build.widen(room, mx, 4, -7, mx + 4, self.wide - 4, 0);
        pit_fall(build, mx, 4, mx + 4, self.wide - 4, -7, "The moat's floor burns", guards);
        pad_to(build, float(mx + 2), float(middle), -7, float(bx) + 2.5, float(self.wide) - 3.0, bh);
        keep_box(build, room, bx, self.wide - 6, bx + 1, self.wide - 1, bh);
        # Through the door, the battlements' guards wake.
        inside = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        inside +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, 3.0, bh, KEEP_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, bh, KEEP_FOES.pick(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, KEEP_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(bx) - 1.5, float(middle) + 3.5, 1, KEEP_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(bx) + 2.0, float(middle) + 3.5, bh, Q3_ARMOR, "q3");
    }
}

"""q3dm9's stretches: [name, role]."""
glob Q3DM9_STRETCHES: list[list[str]] = [
         ["gatehouse", "start"],
         ["pit", "flow"],
         ["trench", "flow"],
         ["court", "hub"],
         ["pit", "hub"],
         ["reliquary", "keyroom"],
         ["battlements", "end"],
         ["battlements", "gate"]
     ];

"""One of q3dm9's stretches by its name."""
def make_q3dm9(name: str, key: str) -> Prefab {
    if name == "gatehouse" {
        return KeepGatehouse();
    }
    if name == "pit" {
        return KeepPit();
    }
    if name == "trench" {
        return KeepTrench();
    }
    if name == "court" {
        return KeepCourt();
    }
    if name == "reliquary" {
        return KeepReliquary(key=key if key else "key_silver");
    }
    return KeepBattlements(key=key);
}
