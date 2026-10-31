"""Prefabs drawn from Quake II's ware1, the Warehouse (the Receiving
Center): a receiving floor where crates ride the belts, a conveyor hall
under catwalks, a crane bay, the freight elevator's shaft, the pit of
tracks the carts run in, the vault whose power cube sets off its alarms,
and the loading bay out. Raised in ware1's own palette.

- `ReceivingDock`: the start. A floor where crates ride a belt (along the
  wall or down the middle), an office deck along one wall on pillars, up
  a stair or a lift. The help computer gives the objective; guards appear
  on the deck as the player leaves the doors; one walks the belt; its
  motor sparks; a stack of crates breaks open on a stash (a secret); now
  and then the way on below is a shutter opened from the deck ("This door
  is opened elsewhere").
- `ConveyorHall`: two aisles either side of the belt that runs down the hall
  through a slot in the wall between them, crates riding it, a catwalk along a
  wall and a gantry across from it over the wall; up by a stair or a lift. A button on the catwalk opens the floor's way on
  (or not); guards appear on the gantry as the player tops the stair; a
  guard walks the floor; ways out on both floors (a hub).
- `CraneBay`: a tall bay, a gantry across it high up, a crane riding its
  rail with a crate; up by a stair turning up two walls or by a lift at the
  gantry's end; a loading pit sunk in the floor. Guards appear on the
  gantry; a stack of crates breaks open on a stash; ways out below and
  from the gantry's ends (a hub).
- `FreightShaft`: ware1's great freight elevator. A ledge over a deep
  shaft, the elevator started by a button on the ledge riding it up and
  down; a stair down the side wall to a gallery round the shaft (or a
  drop and a lift back up), a stair on down from the gallery. What waits
  at the bottom wakes as the player lands.
- `TrackPit`: the pit of tracks: carts run along its floor, its rails
  spark; a bridge over it is drawn out from a booth up a stair (or by
  shooting a button on the far wall); a catwalk crosses high over the pit
  to a way on above. Crossing sets off charges along the pit and brings
  guards in on the far side.
- `CubeVault`: the key room. The power cube (the key) on a tower in a
  vault, reached by a lift, a stair round the tower, or a bridge from a
  gallery; taking it sets off the alarms: a moment on, charges round the
  tower, a panel sparking, guards brought in about the vault.
- `LoadingBay`: the end. A door (a key's, as a gate), a bay where crates
  ride a belt along a dock, the way out on the dock up a stair or a lift;
  guards appear as the player comes in and the bay's charges go off as
  the player climbs onto the dock."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, lift }
import from .warejail_parts { shutter, key_cue, belt_crates, sparking, guards, charges, stash, keep_row, called_lift, closets, gate_pair, auto_shutters }

glob WARE1: str = "q2:ware1";

"""ware1's foes: soldiers and gunners, berserkers growing with the danger."""
glob WARE1_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_soldier_light", "monster_infantry"], strong=["monster_gunner", "monster_berserk"], heavy_light=["monster_gunner", "monster_berserk"], heavy_strong=["monster_gladiator"]);


"""The start: a receiving floor, crates riding a belt, an office deck."""
node ReceivingDock(Prefab) {
    has deck: int = 8,
        deck_x: int = 12,
        deck_deep: int = 5,
        by_lift: bool = False,
        middle_belt: bool = False,
        from_deck: bool = False,
        hidden: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Receiving dock";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 23);
        self.deck = dice.between(8, 9);
        self.tall = self.deck + dice.between(9, 11);
        self.deck_x = dice.between(self.deck + 3, self.deck + 5);
        self.deck_deep = dice.between(5, 6);
        self.by_lift = dice.chance(0.5);
        self.middle_belt = dice.chance(0.5);
        self.from_deck = dice.chance(0.65);
        self.hidden = dice.chance(0.7);
        self.low = -1;
        self.high = self.tall + 1;
        shelf = self.wide - 1 - self.deck_deep;
        self.enter = Port(face=2, along=float(dice.between(7, shelf - 4)), floor=0);
        self.leaves = [
            Port(face=0, along=float(shelf // 2 + 2), floor=0),
            Port(face=0, along=float(shelf + 2 + self.deck_deep - 5), floor=self.deck),
            Port(face=1, along=float(self.long - 6), floor=self.deck),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shelf = self.wide - 1 - self.deck_deep;
        floor_room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(floor_room, self.deck);
        # The office deck along the far wall, on pillars over the floor.
        build.solid(self.deck_x, shelf, self.deck - 1, self.long - 1, self.wide - 1, self.deck);
        for x in range(self.deck_x + 4, self.long - 2, 5) {
            build.solid(x, shelf, 0, x + 1, shelf + 1, self.deck - 1);
        }
        # Up to it: a stair climbing along the far wall, or a lift.
        if self.by_lift {
            lift(build, self.deck_x - 3, shelf + 1, self.deck_x, shelf + 4, 0, self.deck);
            keep_row(build, floor_room, self.deck_x, shelf + 1, self.deck, 0, 3);
        } else {
            stair(build, self.deck_x - self.deck, shelf + 1, 0, 0, self.deck, 3);
            keep_row(build, floor_room, self.deck_x, shelf + 1, self.deck, 0, 3);
        }
        # The belt: along the near wall, or down the middle of the floor,
        # crates riding it.
        belt_y = max(5, shelf // 2 - 1) if self.middle_belt else 1;
        bx0 = 7;
        bx1 = self.long - 7;
        build.solid(bx0, belt_y, 0, bx1, belt_y + 3, 2);
        belt_crates(build, dice, bx0, bx1, belt_y, 2, dice.between(2, 3));
        sparking(build, float(bx0) - 0.1, float(belt_y) + 1.5, 1.0, 2, 4.0);
        # Crate stacks on the floor between, clear of the ways through.
        middle = int(self.enter.along);
        kept: list[list[int]] = [
            [0, middle - 3, 6, middle + 3], [bx0 - 2, belt_y - 1, bx1 + 2, belt_y + 4], [self.deck_x - self.deck - 3, shelf - 2, self.long, self.wide],
            [self.long - 7, shelf // 2 - 1, self.long, shelf // 2 + 5], [self.long - 8, 0, self.long, 5], [1, 1, 7, 5]
        ];
        for index in range(dice.between(3, 5)) {
            x = dice.between(6, self.long - 9);
            y = dice.between(2, shelf - 5);
            box = [x, y, x + 2, y + 2];
            clear = True;
            for other in kept {
                if box[0] < other[2] + 1 and other[0] < box[2] + 1 and box[1] < other[3] + 1 and other[1] < box[3] + 1 {
                    clear = False;
                }
            }
            if clear {
                build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 4));
                kept.append(box);
            }
        }
        build.doorway(floor_room, self.enter);
        for port in self.taken {
            build.doorway(floor_room, port);
        }
        # The way on below, now and then a shutter opened from the deck.
        if self.from_deck {
            press = build.push(float(self.long) - 2.5, float(self.wide - 1), float(self.deck) + 1.5, 3);
            # Now and then a second switch on the wall under the deck: both
            # are wanted.
            if dice.chance(0.5) {
                both = build.tally(2, "One more switch");
                press +>:Fires:+> both;
                build.push(float(self.long) - 5.5, float(self.wide - 1), 1.5, 3) +>:Fires:+> both;
                press = both;
            }
            for port in self.taken {
                if port.floor == 0 {
                    press +>:Fires:+> shutter(build, self, port);
                }
            }
            build.touch(float(self.long - 4), float(shelf // 2 - 1), 0.0, float(self.long - 1), float(shelf // 2 + 5), 6.0, True, "This door is opened elsewhere");
        }
        auto_shutters(build, dice, self, [port for port in self.taken if not (self.from_deck and port.floor == 0)], 0.6);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 5.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Find the power cubes that work the warehouse's doors");
        # Leaving the doors, guards appear on the deck.
        leaving = build.touch(6.0, 1.0, 0.0, 8.0, float(shelf), 8.0);
        spots = [[float(self.long) - 3.5, float(shelf) + 2.5], [float(self.long) - 8.5, float(shelf) + 2.5]];
        guards(build, leaving, spots, self.deck, WARE1_FOES.squad(dice, self.danger, 2), 270.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 5) + 0.5, float(shelf) - 2.5, 0, WARE1_FOES.pick(dice, self.danger), 180.0);
        }
        # A guard walking the floor along the belt.
        lane = float(belt_y + 4) + 0.5;
        build.foe(float(bx0) + 0.5, lane, 0, "monster_soldier_light", 0.0, patrol=[[float(bx0) + 0.5, lane], [float(bx1) - 0.5, lane]]);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.deck, Q2_HEALTH, "q2");
        # The stash in a stack of crates in the near corner, its face
        # broken open.
        if self.hidden {
            build.solid(2, 1, 0, 6, 4, 5);
            stash(build, 3, 1, 5, 3, 0, 1, Q2_ARMOR, "q2");
        }
    }
}

"""A hall, crates riding a belt down it, a catwalk along a wall and a
gantry across over the belt."""
node ConveyorHall(Prefab) {
    has walk: int = 7,
        gantry_x: int = 14,
        by_lift: bool = False,
        from_walk: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Conveyor hall";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 21);
        self.walk = dice.between(7, 8);
        self.tall = self.walk + dice.between(8, 9);
        self.gantry_x = dice.between(13, self.long - 12);
        self.by_lift = dice.chance(0.5);
        self.from_walk = dice.chance(0.7);
        self.low = -1;
        self.high = self.tall + 1;
        catwalk = self.wide - 5;
        self.enter = Port(face=2, along=float(dice.between(4, catwalk - 5)), floor=0);
        self.leaves = [
            Port(face=0, along=float(catwalk // 2), floor=0),
            Port(face=0, along=float(catwalk + 2), floor=self.walk),
            Port(face=3, along=float(self.gantry_x + 2), floor=self.walk),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        catwalk = self.wide - 5;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The catwalk along the far wall, and the gantry across from it to
        # the near wall, both a slab over the floor.
        build.solid(1, catwalk, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        build.solid(self.gantry_x, 1, self.walk - 1, self.gantry_x + 4, catwalk, self.walk);
        # The belt down the hall's middle, under the gantry.
        belt_y = catwalk // 2 - 1;
        bx0 = 6;
        bx1 = self.long - 6;
        build.solid(bx0, belt_y, 0, bx1, belt_y + 3, 2);
        # The wall the belt runs through, up to the catwalk's height; the
        # aisles either side join only round its ends.
        build.solid(bx0, belt_y, 5, bx1, belt_y + 3, self.walk);
        belt_crates(build, dice, bx0, bx1, belt_y, 2, dice.between(2, 3));
        sparking(build, float(bx1) + 0.1, float(belt_y) + 1.5, 1.0, 0, 5.0);
        # Up to the catwalk: a stair under its near end, or a lift at its
        # far end.
        if self.by_lift {
            lx = self.long - 6;
            lift(build, lx, catwalk - 3, lx + 3, catwalk, 0, self.walk);
            keep_row(build, hall, lx, catwalk, self.walk, 1, 3);
            top_x = lx;
        } else {
            stair(build, 2, catwalk - 3, 0, 0, self.walk, 3);
            keep_row(build, hall, 1 + self.walk, catwalk, self.walk, 1, 3);
            top_x = 1 + self.walk;
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # A button on the catwalk opens the way on below, now and then.
        if self.from_walk {
            press = build.push(float(self.long - 8) + 0.5, float(self.wide - 1), float(self.walk) + 1.5, 3);
            # Now and then a second switch on the far wall below: both are
            # wanted.
            if dice.chance(0.5) {
                both = build.tally(2, "One more switch");
                press +>:Fires:+> both;
                build.push(float(self.long - 1), 2.5, 1.5, 2) +>:Fires:+> both;
                press = both;
            }
            for port in self.taken {
                if port.floor == 0 {
                    press +>:Fires:+> shutter(build, self, port);
                }
            }
            build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), float(catwalk - 1), 6.0, True, "This door is opened elsewhere");
        }
        auto_shutters(build, dice, self, [port for port in self.taken if not (self.from_walk and port.floor == 0)], 0.6);
        # Topping the stair (or the lift), guards appear on the gantry.
        topped = build.touch(float(top_x), float(catwalk), float(self.walk), float(top_x + 3), float(self.wide - 1), float(self.walk + 6));
        guards(build, topped, [[float(self.gantry_x) + 2.0, 3.5], [float(self.gantry_x) + 2.0, float(catwalk) - 3.5]], self.walk, WARE1_FOES.squad(dice, self.danger, 2, True), 90.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx0 + 4 + index * 6) + 0.5, float(belt_y) - 2.5 if index % 2 == 0 else float(belt_y) + 4.5, 0, WARE1_FOES.pick(dice, self.danger), 180.0);
        }
        lane = float(belt_y) - 2.5;
        build.foe(3.5, lane, 0, "monster_soldier", 0.0, patrol=[[3.5, lane], [float(self.long) - 3.5, lane]]);
        build.foe(float(self.long) - 3.5, float(catwalk) + 2.0, self.walk, WARE1_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.gantry_x) + 2.0, float(belt_y) + 1.5, self.walk, "ammo_bullets", "q2");
    }
}

"""A tall bay, a gantry across it high up, a crane riding its rail."""
node CraneBay(Prefab) {
    has gantry: int = 10,
        pit: int = 3,
        pit_long: int = 8,
        by_lift: bool = False,
        called: bool = False,
        from_gantry: bool = False,
        hidden: bool = True,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crane bay";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(26, 29);
        self.wide = dice.between(22, 25);
        self.gantry = dice.between(9, 11);
        self.tall = self.gantry + 10;
        self.pit = dice.between(3, 4);
        self.pit_long = dice.between(7, 9);
        self.by_lift = dice.chance(0.45);
        self.called = dice.chance(0.5);
        self.from_gantry = dice.chance(0.7);
        self.hidden = dice.chance(0.6);
        self.low = -self.pit - 1;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=1, along=cx, floor=self.gantry),
            Port(face=0, along=5.0, floor=0),
            Port(face=3, along=cx, floor=self.gantry),
            Port(face=1, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        middle = self.wide // 2;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, self.gantry);
        # The loading pit, sunk in the near side of the floor, steps down
        # into it from its near end.
        px0 = 4;
        px1 = px0 + self.pit_long;
        pit = build.room(px0, 1, -self.pit, px1, 7, 0);
        build.level(pit, -self.pit);
        for step in range(self.pit - 1) {
            build.solid(px0 + step, 1, -self.pit, px0 + step + 1, 7, -step - 1);
        }
        build.supply(float(px1) - 1.5, 2.5, -self.pit, "ammo_grenades", "q2");
        # The gantry across the bay's middle, a crane riding its rail with a
        # crate over a body's head; up to it, a lift at its far end, or a
        # stair up the far wall and a walk along the near side's wall.
        build.solid(cx - 2, 1, self.gantry - 1, cx + 2, self.wide - 1, self.gantry);
        build.train([2.0, 2.0, 2.0], [[float(cx - 1), 2.0, float(self.gantry + 5)], [float(cx - 1), float(self.wide - 4), float(self.gantry + 5)]], 60.0, 2.0);
        if self.by_lift {
            if self.called {
                # Called down by a button on the post at its foot.
                build.solid(cx + 5, middle + 2, 0, cx + 6, middle + 3, 3);
                build.push(float(cx + 5) + 0.5, float(middle + 2), 1.0, 3) +>:Fires:+> called_lift(build, cx + 2, middle - 1, cx + 5, middle + 2, 0, self.gantry);
            } else {
                lift(build, cx + 2, middle - 1, cx + 5, middle + 2, 0, self.gantry);
            }
            keep_row(build, bay, cx + 1, middle - 1, self.gantry, 1, 3);
            # A drop from the gantry's side by the near wall, for the way
            # back down.
            for y in range(1, 5) {
                build.keep(bay, cx + 1, y, self.gantry);
            }
        } else {
            for step in range(self.gantry) {
                y = self.wide - 2 - step;
                build.solid(self.long - 4, y, max(0, step - 2), self.long - 1, y + 1, step + 1);
            }
            build.solid(self.long - 4, 1, self.gantry - 1, self.long - 1, self.wide - 1 - self.gantry, self.gantry);
            build.solid(cx + 2, 1, self.gantry - 1, self.long - 1, 4, self.gantry);
        }
        # Crates on the floor, clear of the stairs and the ways.
        for spot in [[cx + 7, middle - 1], [cx + 5, self.wide - 7]] {
            build.solid(spot[0], spot[1], 0, spot[0] + 2, spot[1] + 2, dice.between(2, 3));
        }
        if self.hidden {
            build.solid(1, self.wide - 6, 0, 5, self.wide - 1, 5);
            stash(build, 2, self.wide - 5, 4, self.wide - 3, 0, 3, "ammo_rockets", "q2");
        }
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        # Now and then the bay's doors below are worked from a post on the
        # gantry.
        if self.from_gantry {
            build.solid(cx + 1, middle + 4, self.gantry, cx + 2, middle + 5, self.gantry + 3);
            press = build.push(float(cx + 1), float(middle) + 4.5, float(self.gantry) + 1.5, 2);
            for port in self.taken {
                if port.floor == 0 {
                    press +>:Fires:+> shutter(build, self, port);
                }
            }
            build.touch(float(self.long - 4), 1.0, 0.0, float(self.long - 1), 9.0, 6.0, True, "These doors are worked from the gantry");
        }
        auto_shutters(build, dice, self, [port for port in self.taken if not (self.from_gantry and port.floor == 0)], 0.6);
        # Coming under the gantry, guards appear on it.
        under = build.touch(float(cx - 3), 1.0, 0.0, float(cx + 3), float(self.wide - 1), 6.0);
        guards(build, under, [[float(cx) + 0.5, 3.5], [float(cx) + 0.5, float(self.wide) - 7.5]], self.gantry, WARE1_FOES.squad(dice, self.danger, 2), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 4 + index * 2) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.5), 0, WARE1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(px0) + 4.5, 4.5, -self.pit, WARE1_FOES.pick(dice, self.danger, True), 0.0);
        lane = float(middle) - 3.5;
        build.foe(3.5, lane, 0, "monster_soldier", 0.0, patrol=[[3.5, lane], [float(self.long) - 6.5, lane]]);
        build.supply(float(cx) + 0.5, float(middle) + 0.5, self.gantry, Q2_ARMOR, "q2");
        build.supply(2.5, float(middle) + 1.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(cx) - 2.2, float(middle) + 0.5, float(self.gantry) - 2.0, 2, 6.0);
    }
}

"""A ledge over the freight elevator's deep shaft: the elevator, a stair
down the side wall to a gallery round the shaft (or a drop and a lift
back), a stair on down."""
node FreightShaft(Prefab) {
    has drop: int = 12,
        ledge: int = 6,
        winding: bool = True,
        from_gallery: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Freight shaft";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.drop = dice.between(12, 14);
        self.long = dice.between(23, 26);
        self.wide = dice.between(18, 20);
        self.ledge = dice.between(6, 7);
        self.tall = dice.between(10, 12);
        self.winding = dice.chance(0.55);
        self.from_gallery = dice.chance(0.65);
        self.low = -self.drop - 2;
        self.high = self.tall + 1;
        gz = 9 - self.drop;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=-self.drop),
            Port(face=1, along=float(self.long - 5), floor=gz),
            Port(face=3, along=float(self.long - 5), floor=gz),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        bottom = -self.drop;
        middle = self.wide // 2;
        # The gallery hangs nine lifts over the shaft's floor.
        gz = bottom + 9;
        shaft = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, 0);
        build.level(shaft, gz);
        # The ledge the way in opens on.
        ex = 1 + self.ledge;
        build.solid(1, 1, bottom, ex, self.wide - 1, 0);
        # The freight elevator beside the ledge: a platform riding the
        # shaft up and down once the button on the ledge is pressed, in a
        # well flush with the floor below.
        ey = middle - 2;
        build.widen(shaft, ex, ey, bottom - 1, ex + 4, ey + 4, bottom);
        car = build.train([4.0, 4.0, 1.0], [[float(ex), float(ey), -1.0], [float(ex), float(ey), float(bottom - 1)]], 90.0, 3.0, True);
        build.solid(ex - 1, ey - 3, 0, ex, ey - 1, 4);
        build.push(float(ex - 1), float(ey) - 2.0, 1.5, 2) +>:Fires:+> car;
        keep_row(build, shaft, ex - 1, ey, 0, 0, 4);
        # The gallery: arms along both side walls and a walk along the far
        # wall, a slab over the shaft's floor.
        gx = self.long - 5;
        arm = ex + (0 - gz) if self.winding else ex;
        build.solid(arm, 1, gz - 1, self.long - 1, 4, gz);
        build.solid(ex + 6, self.wide - 4, gz - 1, self.long - 1, self.wide - 1, gz);
        build.solid(gx, 4, gz - 1, self.long - 1, self.wide - 4, gz);
        # Down from the gallery's near arm to the floor, along the far
        # walk's foot.
        for step in range(9) {
            y = 4 + step;
            build.solid(gx - 3, y, bottom, gx, y + 1, gz - step);
        }
        if self.winding {
            # A stair down the side wall from the ledge to the arm, each
            # step three lifts thick over the floor running under it.
            for step in range(0 - gz) {
                top = -step - 1;
                build.solid(ex + step, 1, max(bottom, top - 3), ex + step + 1, 4, top);
            }
        } else {
            # A drop off the ledge's edge, and a lift back up beside it.
            lift(build, ex, self.wide - 6, ex + 3, self.wide - 3, bottom, 0);
            keep_row(build, shaft, ex - 1, self.wide - 6, 0, 0, 3);
            for y in range(2, 6) {
                build.keep(shaft, ex - 1, y, 0);
            }
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Now and then the way on below is shut, opened from the gallery.
        if self.from_gallery {
            press = build.push(float(self.long - 1), float(middle) + 0.5, float(gz) + 1.5, 2);
            for port in self.taken {
                if port.floor == bottom {
                    press +>:Fires:+> shutter(build, self, port);
                }
            }
        }
        auto_shutters(build, dice, self, [port for port in self.taken if not (self.from_gallery and port.floor == bottom)], 0.6);
        # Landing at the bottom wakes what waits there.
        landed = build.touch(float(ex), 1.0, float(bottom), float(gx - 3), float(self.wide - 1), float(bottom + 4));
        guards(build, landed, [[float(gx) - 5.5, float(middle) + 3.5], [float(gx) - 7.5, float(middle) - 3.5]], bottom, ["monster_berserk", WARE1_FOES.pick(dice, self.danger)], 180.0);
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, gz, WARE1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 2.5, 2.5, gz, "monster_soldier", 90.0, patrol=[[float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5]]);
        build.supply(2.5, 2.5, 0, "ammo_bullets", "q2");
        build.supply(float(gx) - 5.5, float(self.wide) - 3.5, bottom, Q2_HEALTH, "q2");
        sparking(build, float(ex) + 5.0, float(self.wide) - 1.2, float(bottom) + 3.0, 3, 4.5);
    }
}

"""The pit of tracks: carts running its floor, a bridge drawn over it, a
catwalk high over it to a way on above."""
node TrackPit(Prefab) {
    has near: int = 8,
        span: int = 8,
        far: int = 7,
        deep: int = 5,
        walk: int = 8,
        booth: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Track pit";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.near = dice.between(8, 9);
        self.span = dice.between(7, 9);
        self.far = dice.between(7, 9);
        self.deep = dice.between(5, 6);
        self.walk = dice.between(8, 9);
        self.tall = self.walk + 8;
        self.booth = dice.chance(0.5);
        self.long = 1 + self.near + self.span + self.far + 1;
        self.wide = self.walk + 11;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [
            Port(face=0, along=4.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.walk),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.walk);
        cut = 1 + self.near;
        land = cut + self.span;
        pit = build.room(cut, 1, -self.deep, land, self.wide - 1, 0);
        build.level(pit, -self.deep);
        # Steps up out of the pit to the near side, along the near wall
        # past where the bridge comes up.
        for step in range(self.deep) {
            y = self.wide - 2 - step;
            build.solid(cut, y, -self.deep, cut + 3, y + 1, -self.deep + step + 1);
        }
        # The carts running the tracks along the pit's floor.
        for index in range(dice.between(1, 2)) {
            x = cut + 4 + index * 3;
            if x + 2 <= land {
                y0 = 7.0;
                y1 = float(self.wide - 3);
                stops = [[float(x), y0, float(-self.deep)], [float(x), y1, float(-self.deep)]] if index % 2 == 0 else [[float(x), y1, float(-self.deep)], [float(x), y0, float(-self.deep)]];
                build.train([2.0, 2.0, 1.0], stops, float(dice.between(70, 110)), 1.0);
            }
        }
        # The rails spark now and then.
        for index in range(2) {
            sparking(build, float(cut + 4 + index * 2) + 0.5, float(self.wide) - 1.2, float(-self.deep) + 1.0, 3, 3.0 + float(index) * 1.5);
        }
        # The bridge over it against the near wall, drawn out from the booth
        # at the catwalk's head, or by shooting a button on the far wall.
        lane = 1;
        bridge = build.drawn(float(cut), float(lane), float(land), float(lane + 4), 0, self.deep + 1);
        for across in range(4) {
            build.keep(room, cut - 1, lane + across, 0);
            build.keep(room, land, lane + across, 0);
        }
        build.touch(float(cut - 3), 1.0, 0.0, float(cut - 1), 7.0, 6.0, True, "The bridge is worked from elsewhere");
        # The catwalk along the far side wall, high over the pit, up a stair
        # on the near side; a landing at its far end, its edge to drop from.
        cw = self.wide - 4;
        stair(build, 2, 7, 0, 1, self.walk, 3);
        build.solid(1, cw, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        build.solid(land, cw - 1, self.walk - 1, self.long - 1, cw, self.walk);
        for x in range(land + 1, land + 4) {
            build.keep(room, x, cw - 1, self.walk);
        }
        if self.booth {
            build.push(1.0, float(self.wide) - 2.5, float(self.walk) + 1.5, 0) +>:Fires:+> bridge;
        } else {
            build.push(float(self.long - 1), 8.5, 6.0, 2, True) +>:Fires:+> bridge;
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        # Crossing sets off charges along the pit and brings guards in on
        # the far side.
        over = build.touch(float(land), 1.0, 0.0, float(land + 2), float(lane + 4), 6.0);
        charges(build, over, [[float(cut) + 4.5, 7.5, -2.0], [float(cut) + 5.5, float(self.wide) - 6.5, -2.0], [float(land) - 1.5, 9.5, -2.0]], 0.3);
        guards(build, over, [[float(self.long) - 3.5, 2.5], [float(self.long) - 3.5, 9.5]], 0, WARE1_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(float(cut + 3) + 0.5, float(cw) + 1.5, self.walk, WARE1_FOES.pick(dice, self.danger), 0.0, patrol=[[float(cut) - 0.5, float(cw) + 1.5], [float(self.long) - 3.5, float(cw) + 1.5]]);
        build.foe(float(land) + 3.5, 8.5, 0, WARE1_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(cut) + 1.5, 8.5, -self.deep, "ammo_cells", "q2");
    }
}

"""The key room: the power cube on a tower in a vault; taking it sets off
the alarms."""
node CubeVault(Prefab) {
    has key: str = "key_silver",
        tower: int = 6,
        reach: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cube vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(22, 25);
        self.wide = dice.between(24, 26);
        self.tower = dice.between(6, 7);
        self.tall = self.tower + dice.between(8, 10);
        # 0 a lift, 1 a stair round the tower, 2 a bridge from a gallery.
        self.reach = dice.below(3);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide + 4) // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        # The vault from the cell line y = 5 to the far wall; closets beyond
        # its near wall.
        side = 4;
        middle = (self.wide + 4) // 2;
        vault = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(vault, self.tower);
        build.doorway(vault, self.enter);
        # The tower in the vault's far half.
        tx0 = self.long - 11;
        tx1 = self.long - 6;
        ty0 = middle - 2;
        ty1 = middle + 3;
        build.solid(tx0, ty0, 0, tx1, ty1, self.tower);
        if self.reach == 0 {
            # A lift up its near face, called down by a button beside it.
            build.push(float(tx0) - 1.5, float(ty0), 1.0, 3) +>:Fires:+> called_lift(build, tx0 - 3, ty0 + 1, tx0, ty0 + 4, 0, self.tower);
            build.solid(tx0 - 2, ty0, 0, tx0 - 1, ty0 + 1, 3);
            keep_row(build, vault, tx0, ty0 + 1, self.tower, 0, 3);
        } elif self.reach == 1 {
            # A stair up to a plinth along the tower's side, then up its
            # end onto the top.
            low = self.tower - 3;
            build.solid(tx0 - 3, ty0 - 3, 0, tx1, ty0, low);
            stair(build, tx0 - 3 - low, ty0 - 3, 0, 0, low, 3);
            for step in range(3) {
                build.solid(tx1 - 3 + step, ty0 - 3, 0, tx1 - 2 + step, ty0, low + step + 1);
            }
        } else {
            # A gallery along the far wall up a stair, a bridge from it to
            # the tower, the floor running on under both.
            gy = self.wide - 5;
            build.solid(4, gy, self.tower - 1, tx1, self.wide - 1, self.tower);
            build.solid(tx0, ty1, self.tower - 1, tx0 + 3, gy, self.tower);
            stair(build, 4, gy - 3, 0, 0, self.tower, 3);
        }
        # The cube on the tower's top; taking it sets off the alarms: a
        # moment on, charges round the tower, a panel sparking, the closets
        # along the near wall opening and guards brought in, and the
        # objective moves on.
        cube = key_cue(build, self.key, float(tx0 + tx1) * 0.5, float(ty0 + ty1) * 0.5, self.tower);
        late = build.delay(2.0);
        cube +>:Fires:+> late;
        charges(build, late, [[float(tx0) - 1.5, float(ty0) - 1.5, 1.0], [float(tx1) + 1.5, float(ty1) + 1.5, 1.0], [float(tx1) + 1.5, float(ty0) - 1.5, 1.0], [float(tx0) - 1.5, float(ty1) + 1.5, 1.0]], 0.25);
        late +>:Fires:+> build.sparks(float(self.long) - 1.2, float(middle) + 0.5, 4.0, 2);
        cube +>:Fires:+> build.objective("Power cube taken. The alarm is up: get out");
        closets(build, late, [3, tx0 - 4] if dice.chance(0.5) else [3, 7, 11], side, -1, 0, WARE1_FOES.squad(dice, self.danger, 3, True), 90.0);
        guards(build, late, [[3.5, float(self.wide) - 3.5], [float(self.long) - 2.5, float(side) + 2.5]], 0, WARE1_FOES.squad(dice, self.danger, 2), 0.0);
        build.foe(float(tx0) - 1.5, float(side) + 2.5, 0, WARE1_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, "monster_soldier", 90.0, patrol=[[float(self.long) - 3.5, float(side) + 3.5], [float(self.long) - 3.5, float(self.wide) - 4.5]]);
        build.supply(2.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(tx0) - 0.2, float(ty0) + 0.5, 2.0, 2, 5.0);
    }
}

"""The end: a door, a bay where crates ride a belt along a dock, the way
out on the dock."""
node LoadingBay(Prefab) {
    has key: str = "",
        dock: int = 4,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Loading bay" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WARE1;
        self.district = level_district(WARE1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(17, 19);
        self.dock = dice.between(4, 6);
        self.tall = self.dock + dice.between(11, 13);
        self.by_lift = dice.chance(0.4);
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
        bay = gate_pair(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(bay, self.dock);
        # The dock across the far end, a belt along its back with crates
        # riding it, up a stair or a lift.
        dx = self.long - 8;
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, self.dock);
        build.solid(self.long - 3, 1, self.dock, self.long - 1, self.wide - 1, self.dock + 2);
        belt_crates(build, dice, 2, self.wide - 2, self.long - 3, self.dock + 2, 2, False);
        if self.by_lift {
            # Called down by the button beside it.
            build.push(float(dx - 4) - 0.5, 1.0, 1.0, 1) +>:Fires:+> called_lift(build, dx - 3, 2, dx, 5, 0, self.dock);
            keep_row(build, bay, dx, 2, self.dock, 0, 3);
        } else {
            stair(build, dx - self.dock, 2, 0, 0, self.dock, 3);
            keep_row(build, bay, dx, 2, self.dock, 0, 3);
        }
        build.way_out(float(dx) + 2.5, float(middle) + 1.0, self.dock);
        # Crates on the bay's floor.
        build.solid(wall + 4, self.wide - 6, 0, wall + 6, self.wide - 4, dice.between(2, 3));
        build.solid(wall + 9, 8, 0, wall + 11, 10, dice.between(2, 4));
        # Coming in, guards appear in the bay; on the dock, the bay's
        # charges go off.
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards(build, come_in, [[float(dx) - 2.5, float(self.wide) - 3.5], [float(dx) - 2.5, float(self.wide) - 6.5]], 0, WARE1_FOES.squad(dice, self.danger, 2, True), 180.0);
        on_dock = build.touch(float(dx), 1.0, float(self.dock), float(dx + 2), float(self.wide - 1), float(self.dock + 6));
        charges(build, on_dock, [[float(wall) + 2.5, 2.5, 2.0], [float(wall) + 2.5, float(self.wide) - 2.5, 2.0]], 0.4);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, WARE1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) + 4.5, 3.5, self.dock, WARE1_FOES.pick(dice, self.danger), 180.0, patrol=[[float(dx) + 4.5, 3.5], [float(dx) + 4.5, float(self.wide) - 4.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""ware1's stretches: [name, role]."""
glob WARE1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["conveyor", "flow"],
         ["conveyor", "hub"],
         ["crane", "hub"],
         ["crane", "flow"],
         ["shaft", "flow"],
         ["tracks", "flow"],
         ["vault", "keyroom"],
         ["bay", "end"],
         ["bay", "gate"]
     ];

"""One of ware1's stretches by its name."""
def make_ware1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return ReceivingDock();
    }
    if name == "conveyor" {
        return ConveyorHall();
    }
    if name == "crane" {
        return CraneBay();
    }
    if name == "shaft" {
        return FreightShaft();
    }
    if name == "tracks" {
        return TrackPit();
    }
    if name == "vault" {
        return CubeVault(key=key if key else "key_silver");
    }
    return LoadingBay(key=key);
}
