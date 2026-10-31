"""Prefabs drawn from Quake II's hangar2, the Inner Hangar: a fan hall at
the top of the works, berserker pens under a mezzanine, the turbine shaft
whose updraft is shut down from its gallery, the flooded lower works under
catwalks and crates riding overhead, the giant lift down its shaft, the
hangar bay round a dropship where the Hornet waits, hangar control, and
the climb to the surface. Raised in hangar2's own palette.

- `FanHall`: the start. A hall, a control booth on a deck over its floor
  up a stair, the help computer's first objective; the way on goes down,
  by the well's floor that a button sinks (the original's great plat) or
  by a stair winding down the walls of a pit. A panel in an outcrop
  breaks when shot on a stash and sparks (a secret).
- `BlastPens`: a hall under a mezzanine, a flooded culvert across its
  floor; crossing it opens the pens along
  its wall, and the two berserkers' deaths count down to the blast wall
  under the mezzanine bursting, hovers flying out (hangar2's counter of
  two and its exploding wall). A catwalk over the hall (or a lift to a
  ledge) leads to the way on high.
- `TurbineShaft`: a tall shaft, the turbine's housing in it, a gallery
  round three walls over a cooling pool; the updraft throws the player up to the gallery (or
  a lift rides up), where the button shuts the turbine down and opens the
  way on below ("This door is opened elsewhere").
- `LowerWorks`: a long works hall split by a flooded trench (two pools,
  a footbridge between), galleries along both walls joined by catwalks
  over the water, crates riding a rail overhead (trains); charges go off
  along the trench as the player crosses, and a button raises the steps
  to the dock (hangar2's slow rising platform). An underwater nook is a
  secret. A hub.
- `GiantLift`: a landing over a deep shaft, its floor sunk by a button
  with the player on it (hangar2's giant lift); a gallery across the far
  end of the hall at its foot, and a lift back up to a ledge at the top.
- `HangarBay`: the hangar round a dropship, galleries along both walls
  reached by lifts or a stair, a catwalk over the ship, a flooded service
  pit under a gallery; the button in the
  control booth opens the bay doors ("Hangar bay open, ground access")
  and brings the flyers in (the Hornet late in a run). A hub.
- `HangarControl`: the key on a control deck over the lower consoles,
  up a stair or a lift; taking it opens the closets.
- `SurfaceExit`: the end. A door (a key's, as a gate) into a shaft under
  the sky, a stair winding up its walls (or a lift to a tower) to the way
  out at the top; charges go off as the player climbs."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift, spiral, ring_path }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, held_door, rounds, beamed }

glob HANGAR2: str = "q2:hangar2";

"""hangar2's foes: gunners and berserkers, hovers and brains deeper in."""
glob HANGAR2_FOES: FoeMix = FoeMix(light=["monster_gunner", "monster_gunner", "monster_hover"], strong=["monster_berserk"], heavy_light=["monster_berserk", "monster_gunner"], heavy_strong=["monster_brain"], scale=0.6, heavy_scale=0.4);

"""The start: a hall, a control booth over its floor, the way on down a
well or a pit."""
node FanHall(Prefab) {
    has booth: int = 6,
        drop: int = 12,
        tall: int = 17,
        winding: bool = False,
        pit_x: int = 20,
        well: int = 6,
        well_y: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fan hall";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.winding = dice.chance(0.5);
        self.long = dice.between(30, 32);
        self.wide = dice.between(19, 22);
        self.booth = dice.between(6, 7);
        self.tall = self.booth + dice.between(10, 12);
        self.drop = dice.between(12, 14);
        self.low = -2 * self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        if self.winding {
            self.pit_x = self.long - 12;
            bottom = Port(face=3, along=float(self.pit_x + 4), floor=-self.drop);
        } else {
            self.well = dice.between(5, 6);
            self.pit_x = self.long - 1 - self.well;
            self.well_y = dice.between(2, self.wide - 7 - self.well);
            bottom = Port(face=0, along=float(self.well_y) + float(self.well) * 0.5, floor=-self.drop);
        }
        bx0 = 3 + self.booth;
        self.leaves = [bottom, Port(face=1, along=float((bx0 + self.long - 1) // 2), floor=self.booth)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.booth);
        # The control booth: a deck along the far wall over the floor, its
        # stair up along the wall from the entry's end.
        by0 = self.wide - 6;
        bx0 = 3 + self.booth;
        deck(build, bx0, by0, self.long - 1, self.wide - 1, self.booth);
        stair(build, 3, self.wide - 4, 0, 0, self.booth, 3);
        keep_box(build, hall, bx0, self.wide - 4, bx0 + 1, self.wide - 1, self.booth);
        below = hall;
        if self.winding {
            # A pit at the far end, a stair winding down its walls.
            px0 = self.pit_x;
            px1 = self.long - 1;
            below = build.room(px0, 1, -self.drop, px1, 12, 0);
            build.level(below, -self.drop);
            lap = len(ring_path(px0, 1, px1, 12, 3));
            spiral(build, px0, 1, px1, 12, -self.drop, self.drop, 3, 3, (25 - self.drop) % lap);
            keep_box(build, hall, px0 - 1, 8, px0 + 3, 12, 0);
        } else {
            # The well: its floor flush with the hall's until the button on
            # the far wall over it sinks it, whoever stands on it riding down.
            wx = self.pit_x;
            below = build.room(wx, self.well_y, -self.drop, wx + self.well, self.well_y + self.well, 0);
            build.level(below, -self.drop);
            keep_box(build, hall, wx - 1, self.well_y - 1, wx, self.well_y + self.well + 1, 0);
            keep_box(build, hall, wx, self.well_y - 1, self.long - 1, self.well_y, 0);
            keep_box(build, hall, wx, self.well_y + self.well, self.long - 1, self.well_y + self.well + 1, 0);
            sunk = build.sinking(float(wx), float(self.well_y), float(wx + self.well), float(self.well_y + self.well), 0, self.drop);
            press = build.push(float(self.long - 1), float(self.well_y) + float(self.well) * 0.5, 2.5, 2);
            press +>:Fires:+> sunk;
            build.touch(float(wx - 2), float(self.well_y), 0.0, float(wx), float(self.well_y + self.well), 6.0, True, "The lift is worked from the far wall");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor < 0 {
                build.doorway(below, port);
            } else {
                build.doorway(hall, port);
            }
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 5.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Locate hangar control. Shut down the turbine on the way");
        # The stash in an outcrop by the entry: shot open, its pipes burst
        # and spark.
        broken = stash(build, 5, 1, 0, 1, Q2_ARMOR);
        broken +>:Fires:+> build.explosion(7.0, 5.5, 2.0);
        late = build.delay(1.5);
        broken +>:Fires:+> late;
        late +>:Fires:+> build.sparks(7.0, 5.2, 3.0, 1);
        # The booth's consoles spark; guards appear in it as the player comes
        # halfway down the hall.
        sparking(build, float(self.long) - 1.2, float(self.wide) - 3.5, float(self.booth) + 1.5, 2, 4.0);
        halfway = build.touch(float(self.long // 2 - 1), 1.0, 0.0, float(self.long // 2 + 1), float(by0), 8.0);
        squad(build, halfway, [[float(self.long) - 5.5, float(self.wide) - 3.5, float(self.booth)], [float(bx0) + 4.5, float(self.wide) - 2.5, float(self.booth)]], [HANGAR2_FOES.pick(dice, self.danger), "monster_gunner"], 270.0);
        rounds(build, "monster_gunner", [[10.5, float(middle) - 1.5], [float(self.pit_x) - 2.5, float(middle) - 1.5], [float(self.pit_x) - 2.5, float(by0) - 1.5], [10.5, float(by0) - 1.5]], 0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.pit_x) - 3.5, 3.5 + float(index) * 4.0, 0, HANGAR2_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 6, "monster_hover", 180.0);
        if self.winding {
            build.foe(float(self.pit_x) + 5.5, 5.5, -self.drop, HANGAR2_FOES.pick(dice, self.danger, True), 90.0);
            build.supply(float(self.pit_x) + 5.5, 6.5, -self.drop, Q2_HEALTH, "q2");
        } else {
            build.supply(float(self.pit_x) - 2.5, float(self.well_y) + 1.5, 0, Q2_HEALTH, "q2");
        }
        build.supply(float(self.long) - 3.5, float(self.wide) - 2.5, self.booth, "ammo_bullets", "q2");
    }
}

"""A hall under a mezzanine, berserker pens along its wall, the blast wall
under the mezzanine, a catwalk (or a lift to a ledge) to the way on high."""
node BlastPens(Prefab) {
    has mez: int = 7,
        side: int = 16,
        catwalk: bool = True,
        walk_x: int = 14,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blast pens";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(28, 31);
        self.side = dice.between(17, 19);
        self.wide = self.side + 5;
        self.mez = dice.between(6, 7);
        self.tall = self.mez + dice.between(9, 10);
        self.catwalk = dice.chance(0.6);
        self.walk_x = dice.between(self.mez + 9, self.long - 9);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.side // 2 + 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.side // 2 + 2), floor=0),
            Port(face=1, along=float(self.walk_x + 2), floor=self.mez),
            Port(face=3, along=float(self.long - 5), floor=self.mez)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.side;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.mez);
        # The mezzanine along the near wall, its stair up from the entry's
        # end; the bay under it walled off from the hall.
        mx0 = 4 + self.mez;
        deck(build, mx0, 1, self.long - 1, 6, self.mez);
        stair(build, 4, 1, 0, 0, self.mez, 3);
        keep_box(build, hall, mx0, 1, mx0 + 1, 4, self.mez);
        build.solid(mx0, 1, 0, mx0 + 1, 6, self.mez - 1);
        build.solid(mx0, 5, 0, self.long - 1, 6, self.mez - 1);
        bay = build.room(mx0 + 1, 1, 0, self.long - 1, 5, self.mez - 1);
        wall_x = (mx0 + self.long) // 2;
        build.widen(bay, wall_x, 5, 0, wall_x + 3, 6, 4);
        blast = build.breakable(float(wall_x), 5.0, 0.0, float(wall_x + 3), 6.0, 4.0, 40);
        # A flooded culvert across the floor before the mezzanine, a stair
        # up out of its near end.
        build.pool(8, 7, -3, self.long - 6, 10, 0, 2, steps=False);
        stair(build, 8, 7, -3, 0, 3, 2);
        # The way on high: a catwalk over the hall from the mezzanine to the
        # far wall, or a ledge on the far wall a lift rides up to.
        wx = self.walk_x;
        if self.catwalk {
            deck(build, wx, 6, wx + 4, side, self.mez);
            keep_box(build, hall, wx, 5, wx + 4, 6, self.mez);
        } else {
            deck(build, wx - 2, side - 4, wx + 6, side, self.mez);
            lift(build, wx, side - 7, wx + 3, side - 4, 0, self.mez);
            keep_box(build, hall, wx, side - 4, wx + 3, side - 3, self.mez);
        }
        build.widen(hall, wx, side, self.mez, wx + 4, self.wide - 2, self.mez + 8);
        # The pens beyond the far wall, clear of the way up.
        spots: list[int] = [];
        for at in [6, 11, self.long - 9, self.long - 5] {
            if (at + 3 < wx - 2 or at > wx + 6) and len(spots) < 2 and (not spots or at >= spots[-1] + 4) and at + 3 <= self.long - 1 {
                spots.append(at);
            }
        }
        cross = build.touch(float(self.long // 2 - 1), 6.0, 0.0, float(self.long // 2 + 1), float(side), 8.0);
        doors: list[dict[str, str]] = [];
        brutes = build.waiting();
        cross +>:Fires:+> brutes;
        for at in spots {
            pen = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(pen, at, side, 0, at + 3, side + 1, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0, fields);
            doors.append(fields);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, "monster_berserk", 270.0, waits=brutes);
        }
        cross +>:Fires:+> build.cue(doors, "pens");
        # Both brutes dead, the blast wall bursts and the hovers kept behind
        # it fly out.
        count = build.tally(len(spots), "");
        brutes +>:Fires:+> count;
        count +>:Fires:+> blast;
        blast_chain(build, count, [[float(wall_x) - 2.0, 6.5, 1.0], [float(wall_x) + 1.5, 6.5, 2.0], [float(wall_x) + 5.0, 6.5, 1.0]], 0.3);
        squad(build, count, [[float(wall_x) - 3.5, 3.0, 0.0], [float(wall_x) + 5.5, 3.0, 0.0]], ["monster_hover"], 90.0);
        build.supply(float(self.long) - 3.5, 3.0, 0, Q2_ARMOR, "q2");
        build.supply(float(mx0) + 2.5, 3.0, 0, "ammo_cells", "q2");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # A guard on the mezzanine wakes as the player reaches the stair's
        # top; a gunner walks the floor.
        top = build.touch(float(mx0 - 2), 1.0, float(self.mez), float(mx0 + 1), 4.0, float(self.mez + 6));
        squad(build, top, [[float(self.long) - 4.5, 3.5, float(self.mez)]], [HANGAR2_FOES.pick(dice, self.danger, True)], 180.0);
        rounds(build, "monster_gunner", [[4.5, 8.5], [float(self.long) - 3.5, 8.5], [float(self.long) - 3.5, float(side) - 2.5], [4.5, float(side) - 2.5]], 0);
        build.foe(float(mx0) + 6.5, 3.5, self.mez, HANGAR2_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 4.5, float(side) - 3.5, 0, HANGAR2_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(side) - 6.5, 3.0, 2, 5.0);
    }
}

"""A tall shaft, the turbine's housing in it, a gallery round three walls;
the updraft (or a lift) up, the button that shuts the turbine down."""
node TurbineShaft(Prefab) {
    has top: int = 12,
        updraft: bool = True,
        hub_x: int = 6,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Turbine shaft";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(20, 22);
        self.wide = dice.between(20, 22);
        self.top = dice.between(11, 12);
        self.tall = self.top + dice.between(9, 10);
        self.updraft = dice.chance(0.6);
        self.hub_x = dice.between(5, self.long - 15);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2 + 2), floor=self.top),
            Port(face=3, along=float(self.long // 2 + 2), floor=self.top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.top);
        # The gallery round the far and side walls.
        gx = self.long - 5;
        deck(build, 6, 1, self.long - 1, 5, self.top);
        deck(build, 6, self.wide - 5, self.long - 1, self.wide - 1, self.top);
        deck(build, gx, 5, self.long - 1, self.wide - 5, self.top);
        # The turbine's housing: a drum on the floor, its hub up to the roof.
        hx = self.hub_x;
        build.solid(hx, middle - 2, 0, hx + 4, middle + 2, 2);
        build.solid(hx + 1, middle - 1, 2, hx + 3, middle + 1, self.tall);
        keep_box(build, shaft, gx, middle - 2, gx + 1, middle + 2, self.top);
        # The cooling pool under the near gallery, a stair up out of it.
        build.pool(7, 1, -4, gx - 1, 5, 0, 2, steps=False);
        stair(build, gx - 2, 3, -4, 2, 4, 2);
        if self.updraft {
            build.jump_pad(float(gx) - 3.0, float(middle), 0, float(gx) + 1.0, float(middle), self.top);
            build.touch(float(gx - 6), float(middle - 2), 0.0, float(gx - 4), float(middle + 2), 6.0, True, "The turbine's updraft carries you up");
        } else {
            lift(build, gx - 3, middle - 1, gx, middle + 2, 0, self.top);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # The turbine's button on the far wall of the gallery: it shuts the
        # turbine down (its housing bursts), opens the way on below and
        # brings the hovers in.
        press = build.push(float(self.long - 1), float(middle) + 3.5, float(self.top) + 1.5, 2);
        for port in self.taken {
            if port.floor == 0 and port.face == 0 {
                held_door(build, self, port, press);
            }
        }
        press +>:Fires:+> build.objective("Turbine shut down. Make for the lower works");
        blast_chain(build, press, [[float(hx) + 2.0, float(middle) - 2.5, 3.0], [float(hx) + 2.0, float(middle) + 2.5, 6.0], [float(hx) + 2.0, float(middle) - 1.5, float(self.top)]], 0.4);
        squad(build, press, [[float(hx) + 2.0, float(middle) - 5.0, float(self.top - 3)], [float(hx) + 2.0, float(middle) + 5.0, float(self.top - 3)]], ["monster_hover"], 0.0);
        sparking(build, float(hx) + 4.2, float(middle) + 0.5, 1.0, 0, 2.5);
        beamed(build, press, 2, 2, -8, HANGAR2_FOES.pick(dice, self.danger, True), float(gx) - 6.5, float(middle) + 5.5, 0, 0.0);
        # Guards appear on the gallery as the player lands on it.
        landing = build.touch(float(gx), float(middle - 3), float(self.top), float(self.long - 1), float(middle + 3), float(self.top + 6));
        squad(build, landing, [[float(self.long) - 6.5, 3.0, float(self.top)], [float(self.long) - 6.5, float(self.wide) - 3.0, float(self.top)]], [HANGAR2_FOES.pick(dice, self.danger), "monster_gunner"], 0.0);
        rounds(build, "monster_gunner", [[8.5, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [8.5, float(self.wide) - 3.0]], self.top);
        build.foe(float(hx) + 2.0, float(middle) + 4.5, 8, "monster_hover", 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(gx) - 2.5, float(self.wide) - 3.5 - float(index) * 3.0, 0, HANGAR2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, self.top, "ammo_bullets", "q2");
    }
}

"""A long works hall split by a flooded trench, galleries along both walls
joined by catwalks over the water, crates riding a rail overhead, steps a
button raises to the dock."""
node LowerWorks(Prefab) {
    has walk: int = 7,
        deep: int = 5,
        tall: int = 18,
        foot_x: int = 14,
        walks: list[int] = [],
        nook: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lower works";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(29, 32);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(6, 7);
        self.deep = dice.between(6, 7);
        self.tall = self.walk + 11;
        self.foot_x = dice.between(14, self.long - 15);
        # One catwalk over a pool, or one over each.
        if dice.chance(0.4) {
            self.walks = [dice.between(9, self.foot_x - 4), dice.between(self.foot_x + 5, self.long - 10)];
        } elif dice.chance(0.5) {
            self.walks = [dice.between(9, self.foot_x - 4)];
        } else {
            self.walks = [dice.between(self.foot_x + 5, self.long - 10)];
        }
        self.nook = dice.chance(0.7);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle - 5), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 5), floor=0),
            Port(face=0, along=float(middle + 6), floor=self.walk),
            Port(face=1, along=float(self.long // 2 + 3), floor=self.walk),
            Port(face=3, along=float(self.long // 2 + 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ty0 = middle - 4;
        ty1 = middle + 4;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The trench: two pools, the footbridge between them, a stair up out
        # of each to the floor beside it.
        fx = self.foot_x;
        build.pool(6, ty0, -self.deep, fx, ty1, 0, 2, steps=False);
        stair(build, 6, ty0, -self.deep, 0, self.deep, 2);
        build.pool(fx + 3, ty0, -self.deep, self.long - 6, ty1, 0, 2, steps=False);
        stair(build, self.long - 7, ty1 - 2, -self.deep, 2, self.deep, 2);
        if self.nook {
            # An underwater nook under the near floor, a secret.
            nx = fx + 6;
            build.room(nx, ty0 - 3, -self.deep, nx + 3, ty0, -self.deep + 3);
            for x in range(nx, nx + 3) {
                for y in range(ty0 - 3, ty0) {
                    for z in range(-self.deep, -self.deep + 3) {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
            build.secret(float(nx), float(ty0 - 3), float(-self.deep), float(nx + 3), float(ty0 - 1), float(-self.deep + 3));
            build.supply(float(nx) + 1.5, float(ty0) - 2.0, -self.deep, Q2_ARMOR, "q2");
        }
        # The galleries along both walls, the stair up to the near one, the
        # catwalks across.
        deck(build, 8, 1, self.long - 1, 4, self.walk);
        deck(build, 8, self.wide - 4, self.long - 1, self.wide - 1, self.walk);
        stair(build, 8 - self.walk, 1, 0, 0, self.walk, 3);
        keep_box(build, hall, 8, 1, 9, 4, self.walk);
        for wx in self.walks {
            deck(build, wx, 4, wx + 3, self.wide - 4, self.walk);
            keep_box(build, hall, wx, 3, wx + 3, 4, self.walk);
            keep_box(build, hall, wx, self.wide - 4, wx + 3, self.wide - 3, self.walk);
        }
        # The dock at the far end of the far floor, up to the galleries'
        # height; the steps to it rise from the floor when the button on
        # its face is pressed.
        dx = self.long - 4;
        build.solid(dx, ty1, 0, self.long - 1, self.wide - 4, self.walk);
        keep_box(build, hall, dx, ty1, dx + 1, ty1 + 3, self.walk);
        steps = build.rising_steps(dx - self.walk, ty1, 0, 0, self.walk, 3);
        raised = build.push(float(dx), float(self.wide) - 4.5, 1.5, 2);
        raised +>:Fires:+> steps;
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Crates riding a rail overhead, one each way.
        rail = float(self.walk + 4);
        build.train([2.0, 2.0, 2.0], [[9.0, float(middle) - 1.0, rail], [float(self.long) - 11.0, float(middle) - 1.0, rail]], 60.0, 2.0);
        build.train([2.0, 2.0, 2.0], [[float(self.long) - 11.0, float(middle) + 1.5, rail], [9.0, float(middle) + 1.5, rail]], 60.0, 2.0);
        # Charges go off along the trench as the player walks out over it.
        for wx in self.walks {
            over = build.touch(float(wx), float(ty0), float(self.walk), float(wx + 3), float(ty1), float(self.walk + 6));
            blast_chain(build, over, [[float(wx) - 3.0, float(ty0) - 0.5, 1.0], [float(wx) + 1.5, float(ty1) + 0.5, 1.0], [float(wx) + 6.0, float(ty0) - 0.5, 1.0], [float(wx) + 1.5, float(middle), -1.0]], 0.25);
        }
        # Gunners come onto the far gallery as the player comes in; one
        # walks the near gallery, another the floor.
        come_in = build.touch(1.0, 3.0, 0.0, 4.0, float(ty0), 8.0);
        beamed(build, come_in, 2, self.wide - 6, -8, HANGAR2_FOES.pick(dice, self.danger, True), float(fx) + 1.5, float(ty1) + 2.5, 0, 180.0);
        squad(build, come_in, [[14.5, float(self.wide) - 2.5, float(self.walk)], [float(self.long) - 5.5, float(self.wide) - 2.5, float(self.walk)]], ["monster_gunner", HANGAR2_FOES.pick(dice, self.danger)], 270.0);
        rounds(build, "monster_gunner", [[10.5, 2.5], [float(self.long) - 3.5, 2.5]], self.walk);
        rounds(build, HANGAR2_FOES.pick(dice, self.danger), [[3.5, float(ty1) + 2.5], [float(dx) - 1.5, float(self.wide) - 2.5]], 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx) + 1.5, float(ty0) - 2.5 + float(index % 2) * 9.0, 0, HANGAR2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        sparking(build, float(self.long) - 1.2, 5.5, 2.0, 2, 3.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 6.5, self.walk, "ammo_grenades", "q2");
        build.supply(float(fx) + 1.5, float(middle), 0, Q2_HEALTH, "q2");
    }
}

"""A landing over a deep shaft whose floor a button sinks with the player
on it; the hall at its foot, a gallery across its far end, a lift back up."""
node GiantLift(Prefab) {
    has drop: int = 15,
        gallery: bool = True,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Giant lift";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(27, 29);
        self.wide = dice.between(18, 20);
        self.drop = dice.between(17, 20);
        self.gallery = dice.chance(0.7);
        self.tall = 10;
        self.low = -2 * self.drop - 1;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [Port(face=0, along=float(middle), floor=-self.drop)];
        if self.gallery {
            self.leaves.append(Port(face=1, along=float(self.long - 4), floor=-self.drop + 9));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bottom = -self.drop;
        s0 = middle - 3;
        s1 = middle + 3;
        # The landing at the top, a ledge along beside the shaft.
        landing = build.room(1, 1, 0, 6, self.wide - 1, self.tall, variant=dice.below(3));
        build.widen(landing, 6, s1, 0, 12, self.wide - 1, self.tall);
        # The shaft, its floor flush with the landing until the button on
        # its wall sinks it, whoever stands on it riding down.
        build.room(6, s0, bottom, 12, s1, self.tall);
        sunk = build.sinking(6.0, float(s0), 12.0, float(s1), 0, self.drop);
        press = build.push(9.0, float(s0), 2.5, 1);
        press +>:Fires:+> sunk;
        build.touch(3.0, float(s0), 0.0, 6.0, float(s1), 6.0, True, "Step onto the lift and press its button");
        keep_box(build, landing, 5, s0, 6, s1, 0);
        # The hall at its foot, the gallery across its far end over it.
        foot = build.room(12, 1, bottom, self.long - 1, self.wide - 1, 0, variant=dice.below(3));
        build.level(foot, bottom);
        # A sump in the foot's floor, a stair up out of it.
        build.pool(16, middle + 1, bottom - 4, self.long - 8, self.wide - 5, bottom, 2, steps=False);
        stair(build, self.long - 9, middle + 1, bottom - 4, 2, 4, 2);
        mid = bottom + 9;
        if self.gallery {
            build.level(foot, mid);
            deck(build, self.long - 6, 1, self.long - 1, self.wide - 1, mid);
            stair(build, self.long - 15, 1, bottom, 0, 9, 3);
            keep_box(build, foot, self.long - 6, 1, self.long - 5, 4, mid);
        }
        # The way back up: a lift from the foot to the ledge beside the shaft.
        lift(build, 12, self.wide - 4, 15, self.wide - 1, bottom, 0);
        build.widen(landing, 12, self.wide - 4, 0, 15, self.wide - 1, self.tall);
        keep_box(build, landing, 11, self.wide - 4, 12, self.wide - 1, 0);
        build.doorway(landing, self.enter);
        for port in self.taken {
            if port.floor < 0 {
                build.doorway(foot, port);
            } else {
                build.doorway(landing, port);
            }
        }
        # Pressing the button brings foes onto the gallery and the floor at
        # the shaft's foot; sparks fly as the lift passes the hall's roof.
        spots = [[float(self.long) - 8.5, float(middle) - 2.5, float(bottom)], [16.5, 3.5, float(bottom)]];
        if self.gallery {
            spots.append([float(self.long) - 3.5, float(middle) + 0.5, float(mid)]);
        }
        squad(build, press, spots, [HANGAR2_FOES.pick(dice, self.danger), "monster_gunner", HANGAR2_FOES.pick(dice, self.danger, True)], 180.0);
        down = build.touch(6.0, float(s0), float(bottom + 2), 12.0, float(s1), float(bottom + 8));
        down +>:Fires:+> build.sparks(12.2, float(middle), float(bottom) + 3.0, 0);
        build.foe(18.5, float(middle) + 0.5, bottom + 6, "monster_hover", 180.0);
        build.foe(float(self.long) - 8.5, 3.5, bottom, HANGAR2_FOES.pick(dice, self.danger, True), 180.0);
        sparking(build, 6.2, float(s0) + 1.0, float(bottom) + 4.0, 0, 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 5.5, float(self.wide) - 3.5, bottom, "ammo_shells", "q2");
    }
}

"""The hangar round a dropship, galleries along both walls, a catwalk over
the ship; the control booth's button opens the bay doors."""
node HangarBay(Prefab) {
    has gallery: int = 10,
        roof: int = 5,
        ship_x: int = 10,
        ship_y: int = 9,
        walk_x: int = 18,
        lifts: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar bay";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.gallery = 10;
        self.roof = 5;
        self.tall = self.gallery + dice.between(11, 13);
        self.lifts = dice.chance(0.5);
        self.ship_x = dice.between(11, 13);
        self.ship_y = self.wide // 2 - 4 + dice.between(-1, 1);
        self.walk_x = dice.between(self.ship_x + 3, self.ship_x + 9);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 6), floor=self.gallery),
            Port(face=3, along=float(self.long - 6), floor=self.gallery),
            Port(face=1, along=9.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, g);
        build.level(bay, self.roof);
        # The galleries along both walls, the catwalk across between them.
        gx0 = 8 if self.lifts else 13;
        deck(build, gx0, 1, self.long - 1, 5, g);
        deck(build, gx0, self.wide - 5, self.long - 1, self.wide - 1, g);
        wx = self.walk_x;
        deck(build, wx, 5, wx + 3, self.wide - 5, g);
        keep_box(build, bay, wx, 4, wx + 3, 5, g);
        keep_box(build, bay, wx, self.wide - 5, wx + 3, self.wide - 4, g);
        # The dropship: its hull to the roof, a ramp up its tail.
        sx = self.ship_x;
        sy = self.ship_y;
        build.solid(sx, sy, 0, sx + 12, sy + 8, self.roof);
        build.solid(sx + 12, sy + 2, 0, sx + 14, sy + 6, 3);
        stair(build, sx - self.roof, sy + 3, 0, 0, self.roof, 3);
        keep_box(build, bay, sx, sy + 3, sx + 1, sy + 6, self.roof);
        # A flooded service pit under the near gallery, a stair out of it.
        build.pool(14, 1, -4, self.long - 6, 5, 0, 2, steps=False);
        stair(build, self.long - 7, 3, -4, 2, 4, 2);
        if self.lifts {
            lift(build, 8, 5, 11, 8, 0, g);
            keep_box(build, bay, 8, 4, 11, 5, g);
            lift(build, self.long - 5, self.wide - 8, self.long - 2, self.wide - 5, 0, g);
            keep_box(build, bay, self.long - 5, self.wide - 5, self.long - 2, self.wide - 4, g);
        } else {
            stair(build, 3, 1, 0, 0, g, 4);
            keep_box(build, bay, 13, 1, 14, 5, g);
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        # The control booth's button at the far end of the far gallery: the
        # bay doors open, the objective moves on, the flyers come in.
        press = build.push(float(self.long - 1), float(self.wide) - 3.0, float(g) + 1.5, 2);
        for port in self.taken {
            if port.floor == 0 and port.face == 0 {
                held_door(build, self, port, press, "The bay doors open from the control booth");
            }
        }
        press +>:Fires:+> build.objective("Hangar bay open, ground access. Proceed to the surface");
        boss = ["monster_boss2"] if self.danger > 0.85 else ["monster_hover", "monster_flyer"];
        squad(build, press, [[float(sx) + 6.0, float(sy) + 4.0, float(self.roof + 5)], [float(self.long) - 6.0, float(middle), 6.0]], boss, 180.0);
        blast_chain(build, press, [[float(self.long) - 2.0, float(middle) - 3.0, 4.0], [float(self.long) - 2.0, float(middle) + 3.0, 4.0]], 0.5);
        # The secret: a closet in an outcrop by the way in, behind a wall
        # that opens when shot.
        if dice.chance(0.7) {
            hidden_closet(build, 2, self.wide - 6, 0, 0, Q2_ARMOR, 6) +>:Fires:+> build.sparks(5.5, float(self.wide) - 4.0, 4.0, 0);
        }
        # Foes on the floor round the ship, a gunner walking round it,
        # guards on the galleries woken as the player comes in.
        rounds(build, "monster_gunner", [[float(sx) - 7.5, float(sy) - 1.5], [float(sx) + 15.5, float(sy) - 1.5], [float(sx) + 15.5, float(sy) + 9.5], [float(sx) - 7.5, float(sy) + 9.5]], 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx) + 3.5 + float(index) * 4.0, float(sy) + 4.0, self.roof, HANGAR2_FOES.pick(dice, self.danger), 180.0);
        }
        come_in = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 8.0);
        squad(build, come_in, [[float(self.long) - 4.5, 3.0, float(g)], [float(wx) + 1.5, float(self.wide) - 3.0, float(g)]], [HANGAR2_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        beamed(build, come_in, 2, 2, -8, HANGAR2_FOES.pick(dice, self.danger, True), float(sx) + 6.0, float(sy) - 2.5, 0, 180.0);
        build.foe(float(self.long) - 3.5, float(middle) + 6.5, 0, HANGAR2_FOES.pick(dice, self.danger, True), 180.0);
        sparking(build, float(self.long) - 1.2, 3.0, float(g) + 1.5, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(sx) + 6.0, float(sy) + 4.0, self.roof, "ammo_rockets", "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, Q2_HEALTH, "q2");
    }
}

"""The key on a control deck over the lower consoles, up a stair or a
lift; taking it opens the closets."""
node HangarControl(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        level: int = 6,
        by_lift: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.level = dice.between(6, 7);
        self.by_lift = dice.chance(0.5);
        self.tall = self.level + dice.between(8, 9);
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.level);
        build.doorway(room, self.enter);
        # The control deck over the far end, the lower consoles under it.
        dx = self.long - 9;
        deck(build, dx, 1, self.long - 1, side, self.level);
        build.solid(self.long - 2, 3, self.level, self.long - 1, side - 2, self.level + 2);
        if self.by_lift {
            lift(build, dx - 3, cy - 1, dx, cy + 2, 0, self.level);
            keep_box(build, room, dx, cy - 1, dx + 1, cy + 2, self.level);
        } else {
            stair(build, dx - self.level, 1, 0, 0, self.level, 3);
            keep_box(build, room, dx, 1, dx + 1, 4, self.level);
        }
        broken = stash(build, self.long - 6, side - 5, 0, 2, "ammo_cells", self.level - 1);
        broken +>:Fires:+> build.sparks(float(self.long) - 6.2, float(side) - 3.0, 2.0, 2);
        key_ambush(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, self.level, side, 0, [3, dx - 5], [HANGAR2_FOES.pick(dice, self.danger, True), HANGAR2_FOES.pick(dice, self.danger)]);
        build.foe(float(self.long) - 4.5, 3.5, self.level, HANGAR2_FOES.pick(dice, self.danger), 180.0);
        rounds(build, "monster_gunner", [[float(dx) + 2.5, 3.5], [float(dx) + 2.5, float(side) - 3.5]], 0);
        build.foe(5.5, float(cy) + 3.5, 0, HANGAR2_FOES.pick(dice, self.danger), 0.0);
        sparking(build, float(self.long) - 2.2, float(cy) - 2.5, float(self.level) + 1.5, 2, 3.0);
        sparking(build, float(dx) + 0.5, float(side) - 0.2, 2.0, 3, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into a shaft under the sky, a stair winding up its
walls (or a lift to a tower) to the way out at the top."""
node SurfaceExit(Prefab) {
    has key: str = "",
        climb: int = 12,
        winding: bool = True,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Surface exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = HANGAR2;
        self.district = level_district(HANGAR2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.climb = dice.between(11, 14);
        self.winding = dice.chance(0.6);
        self.tall = self.climb + 12;
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
        wall = 8;
        shaft = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(shaft, self.climb);
        x0 = wall + 1;
        x1 = self.long - 1;
        if self.winding {
            found = spiral(build, x0, 1, x1, self.wide - 1, 0, self.climb, 3, 4, 3);
            cell = found[1];
            build.way_out(float(cell[0] + cell[2]) * 0.5, float(cell[1] + cell[3]) * 0.5, self.climb);
        } else {
            # A tower in the shaft's middle, a lift up its side.
            tx = (x0 + x1) // 2 - 2;
            build.solid(tx, middle - 3, 0, tx + 5, middle + 3, self.climb);
            lift(build, tx - 3, middle - 1, tx, middle + 2, 0, self.climb);
            keep_box(build, shaft, tx, middle - 1, tx + 1, middle + 2, self.climb);
            build.way_out(float(tx) + 3.0, float(middle), self.climb);
        }
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Proceed to the surface");
        # Charges go off down the shaft as the player starts up; hovers come
        # in over the top.
        up = build.touch(float(x0), 1.0, 1.0, float(x1), float(self.wide - 1), 5.0);
        blast_chain(build, up, [[float(x0) + 2.0, 2.0, 0.5], [float(x1) - 2.0, float(self.wide) - 2.0, 0.5], [float(x0) + 6.0, float(middle), 0.5]], 0.4);
        squad(build, up, [[float(x0) + 6.0, float(middle) - 2.0, float(self.climb + 4)], [float(x1) - 4.0, float(middle) + 2.0, float(self.climb + 4)]], ["monster_hover"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, HANGAR2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 6.5, float(middle) + 0.5, 0, HANGAR2_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""hangar2's stretches: [name, role]."""
glob HANGAR2_STRETCHES: list[list[str]] = [
         ["fans", "start"],
         ["pens", "flow"],
         ["turbine", "flow"],
         ["works", "flow"],
         ["works", "hub"],
         ["lift", "flow"],
         ["bay", "hub"],
         ["control", "keyroom"],
         ["surface", "end"],
         ["surface", "gate"]
     ];

"""One of hangar2's stretches by its name."""
def make_hangar2(name: str, key: str) -> Prefab {
    if name == "fans" {
        return FanHall();
    }
    if name == "pens" {
        return BlastPens();
    }
    if name == "turbine" {
        return TurbineShaft();
    }
    if name == "works" {
        return LowerWorks();
    }
    if name == "lift" {
        return GiantLift();
    }
    if name == "bay" {
        return HangarBay();
    }
    if name == "control" {
        return HangarControl(key=key if key else "key_silver");
    }
    return SurfaceExit(key=key);
}
