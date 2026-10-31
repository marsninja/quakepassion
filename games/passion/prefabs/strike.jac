"""Prefabs drawn from Quake II's strike, the Outlands: a landing on a beach
under the sky by the deep sea where the flippers hunt, sea cliffs with a
cave under their overhang and an arch to a sea stack, a canyon over its
river crossed by a bridge, an outpost of bunkers and a watchtower, the
airstrike marker in its radio bunker, and the target zone where the
airstrike is called in. Raised in strike's own palette.

- `Landing`: the start. A landing craft at a jetty over the deep sea,
  the beach, a bunker on it, the cliff behind (a cave under its
  overhang) up a stair (or a lift);
  shells throw up the sea now and then; "Retrieve the airstrike marker".
- `SeaCliffs`: the beach under a cliff whose overhang shades a cave, a
  stair up the cliff's face to its top, and an arch from the top out to a
  sea stack (or a jetty to it); the flippers in the sea, guards coming
  onto the cliff as the player climbs.
- `Canyon`: a canyon under a high sky, a broad river at the foot, a path along each wall (the
  far one higher) over caves at the canyon's floor, a bridge over it stepping up to the far path, a stair
  down to the canyon floor and a tunnel on from there; flyers come in
  over the canyon.
- `Outpost`: a compound under the sky by a harbor: a bunker whose roof is walked,
  up a stair, bridged to a walkway along the far wall, its door into the
  guardroom; a watchtower up a lift (or
  none, and a second bunker); barrels. A hub.
- `MarkerSite`: a cove, a quay round two sides over the drowned rock, a
  radio bunker on an islet (a jetty to it, or swum), the airstrike marker
  (the key) on its roof up a lift or a stair; taking it opens the closets
  on the quay and brings the flyers; "Place the airstrike marker in the
  target area".
- `StrikeZone`: the end. A door (a key's, as a gate) out to the target
  zone; the marker placed at its console, the airstrike falls round it
  and the way out opens; a ledge along one side with its guards."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, boulders }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, squad, rounds, beamed, held_door, key_taken, closets, splashing, barrels }

glob STRIKE: str = "q2:strike";

"""strike's foes: elite soldiers and flyers, infantry and gunners."""
glob STRIKE_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_soldier", "monster_flyer"], strong=["monster_soldier_ss"], heavy_light=["monster_soldier_ss", "monster_gunner"], heavy_strong=["monster_infantry"], scale=0.6);

"""The start: a landing craft at a jetty over the sea, the beach, a bunker,
the cliff behind."""
node Landing(Prefab) {
    has deep: int = 9,
        jetty_x: int = 16,
        cliff: int = 8,
        by_lift: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Landing";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(10, 12);
        self.cliff = 9;
        self.tall = 44;
        self.by_lift = dice.chance(0.4);
        self.jetty_x = dice.between(14, self.long - 12);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 8), floor=0);
        self.leaves = [
            Port(face=0, along=13.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.cliff),
            Port(face=1, along=float(self.long - 6), floor=self.cliff)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        jx = self.jetty_x;
        c = self.cliff;
        shore = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(shore, c);
        # The sea along the near side, a stair up out of it onto the beach.
        build.pool(1, 1, -self.deep, self.long - 1, 10, 0, 2, steps=False);
        stair(build, 3, 8, -self.deep, 0, self.deep, 2);
        # The jetty out over the sea, two steps up from the beach, and the
        # landing craft moored at its end.
        deck(build, jx, 2, jx + 3, 11, 2);
        stair(build, jx, 12, 0, 3, 2, 3);
        build.solid(jx + 3, 2, -3, jx + 8, 5, 2);
        keep_box(build, shore, jx, 10, jx + 3, 11, 2);
        # The cliff behind the beach, up a stair along its foot or a lift.
        build.solid(10, self.wide - 6, 6, self.long - 1, self.wide - 1, c);
        for x in range(13, self.long - 2, 6) {
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 1, 6);
        }
        if self.by_lift {
            lift(build, 11, self.wide - 9, 14, self.wide - 6, 0, c);
            keep_box(build, shore, 11, self.wide - 6, 14, self.wide - 5, c);
        } else {
            stair(build, 2, self.wide - 6, 0, 0, c, 3);
            keep_box(build, shore, 11, self.wide - 6, 12, self.wide - 3, c);
        }
        # The bunker on the beach, its door, a guard inside.
        bx = 14 if jx > 20 else 21;
        build.solid(bx, 13, 0, bx + 6, 18, 9);
        hut = build.room(bx + 1, 14, 0, bx + 5, 17, 4);
        build.widen(hut, bx + 2, 13, 0, bx + 4, 14, 4);
        build.rising_door(float(bx + 2), 13.0, 0.0, float(bx + 4), 14.0, 4.0, {"wait": "-1"});
        build.foe(float(bx) + 3.0, 15.5, 0, STRIKE_FOES.pick(dice, self.danger, True), 270.0);
        build.supply(float(bx) + 2.0, 16.0, 0, Q2_ARMOR, "q2");
        build.doorway(shore, self.enter);
        for port in self.taken {
            build.doorway(shore, port);
        }
        build.start(float(jx) + 5.5, 3.5, 2, 90.0);
        build.supply(float(jx) + 1.5, 4.5, 2, "ammo_shells", "q2");
        build.touch(float(jx), 2.0, 2.0, float(jx + 8), 10.0, 8.0) +>:Fires:+> build.objective("Retrieve the airstrike marker");
        # Shells throw up the sea now and then; the flippers hunt in it.
        splashing(build, 6.5, 4.0, -1.0, 3.0);
        splashing(build, float(self.long) - 5.5, 3.0, -1.0, 4.0);
        for index in range(dice.between(2, 3)) {
            build.foe(5.5 + float(index) * 8.0, 4.5, -self.deep + 2, "monster_flipper", 0.0);
        }
        # A soldier walks the beach; guards come onto the cliff top as the
        # player climbs it.
        rounds(build, "monster_soldier", [[4.5, 12.0], [float(jx) - 1.5, 12.0]], 0);
        top = build.touch(8.0, float(self.wide - 6), float(c - 3), 12.0, float(self.wide - 1), float(c + 6));
        squad(build, top, [[float(self.long) - 4.5, float(self.wide) - 3.5, float(c)], [20.5, float(self.wide) - 3.0, float(c)]], [STRIKE_FOES.pick(dice, self.danger), "monster_soldier_ss"], 180.0);
        build.foe(float(self.long) - 4.5, 13.5, 0, STRIKE_FOES.pick(dice, self.danger), 180.0);
        sparking(build, float(bx) - 0.2, 15.5, 3.0, 2, 5.0);
        build.supply(4.5, float(self.wide) - 8.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, c, "ammo_bullets", "q2");
    }
}

"""The beach under a cliff whose overhang shades a cave, a stair up its
face, an arch from its top out to a sea stack."""
node SeaCliffs(Prefab) {
    has deep: int = 9,
        ledge: int = 10,
        arch: bool = True,
        stack_x: int = 18,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sea cliffs";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(10, 12);
        self.ledge = 10;
        self.tall = 44;
        self.arch = dice.chance(0.65);
        self.stack_x = dice.between(16, self.long - 8);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=12.0, floor=0);
        self.leaves = [
            Port(face=0, along=12.0, floor=0),
            Port(face=0, along=float(self.wide - 4), floor=self.ledge),
            Port(face=1, along=float(self.long - 8), floor=self.ledge)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        top = self.ledge;
        oy = self.wide - 7;
        shore = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(shore, top);
        # The sea along the near side, a stair up out of it.
        build.pool(1, 1, -self.deep, self.long - 1, 10, 0, 2, steps=False);
        stair(build, 3, 8, -self.deep, 0, self.deep, 2);
        # The cliff's overhang over the cave, pillars of rock at its back.
        build.solid(1, oy, 7, self.long - 1, self.wide - 1, top);
        for x in range(6, self.long - 3, 7) {
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 1, 7);
        }
        # The stair up the cliff's face to its top.
        stair(build, 4, oy - 3, 0, 0, top, 3);
        keep_box(build, shore, 4, oy, 14, oy + 1, top);
        # The sea stack, and an arch from the cliff top out to it, or a jetty
        # from the beach.
        sx = self.stack_x;
        if self.arch {
            build.solid(sx, 3, -self.deep, sx + 4, 6, top);
            deck(build, sx, 6, sx + 4, oy, top);
            keep_box(build, shore, sx, oy, sx + 4, oy + 1, top);
            keep_box(build, shore, sx, 5, sx + 4, 6, top);
        } else {
            build.solid(sx, 3, -self.deep, sx + 4, 6, 3);
            deck(build, sx + 1, 6, sx + 4, 10, 3);
            stair(build, sx + 1, 12, 0, 3, 3, 3);
            keep_box(build, shore, sx + 1, 5, sx + 4, 6, 3);
        }
        # A stash at the back of the cave.
        stash(build, self.long - 7, self.wide - 5, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.sparks(float(self.long) - 5.0, float(self.wide) - 5.2, 2.0, 3);
        build.doorway(shore, self.enter);
        for port in self.taken {
            build.doorway(shore, port);
        }
        # Guards come onto the cliff top as the player climbs; one on the sea
        # stack; the flippers in the sea.
        climb = build.touch(6.0, float(oy - 3), 3.0, 9.0, float(oy), 9.0);
        squad(build, climb, [[float(self.long) - 4.5, float(self.wide) - 3.5, float(top)], [16.5, float(self.wide) - 3.0, float(top)]], [STRIKE_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        build.foe(float(sx) + 2.0, 4.5, top if self.arch else 3, "monster_soldier_ss", 270.0);
        for index in range(dice.between(2, 3)) {
            build.foe(6.5 + float(index) * 7.0, 4.0, -self.deep + 2, "monster_flipper", 0.0);
        }
        rounds(build, "monster_soldier", [[3.5, 11.5], [float(self.long) - 3.5, 11.5], [float(self.long) - 3.5, float(oy) + 2.5], [16.5, float(oy) + 2.5]], 0);
        splashing(build, 9.5, 3.0, -1.0, 3.5);
        splashing(build, float(self.long) - 4.5, 4.0, -1.0, 5.0);
        build.supply(2.5, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, top, "ammo_rockets", "q2");
    }
}

"""A canyon over its river, a path along each wall, a bridge over it
stepping up to the far path, a stair down to its floor."""
node Canyon(Prefab) {
    has far_path: int = 4,
        bridge_x: int = 14,
        by_lift: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canyon";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(27, 28);
        self.far_path = 4;
        self.tall = 40;
        self.bridge_x = dice.between(8, self.long - 16);
        self.by_lift = dice.chance(0.4);
        self.low = -14;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=self.far_path),
            Port(face=1, along=float(self.long // 2), floor=self.far_path),
            Port(face=0, along=float(cy + 6), floor=-8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        fp = self.far_path;
        y0 = 7;
        y1 = self.wide - 7;
        rim = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        floor = build.room(1, 1, -8, self.long - 1, self.wide - 1, 0);
        build.level(rim, fp);
        build.level(floor, -8);
        build.solid(1, y1, 0, self.long - 1, self.wide - 1, fp);
        # The near path a shelf over a cave, the far path over another; rock
        # pillars in each.
        deck(build, 1, 1, self.long - 1, y0, 0);
        for x in range(5, self.long - 3, 7) {
            build.solid(x, 2, -8, x + 1, 3, -1);
            build.solid(x, self.wide - 3, -8, x + 1, self.wide - 2, 0);
        }
        # The river along the canyon's foot, a stair up out of it.
        build.pool(1, cy - 5, -13, self.long - 1, cy + 3, -8, 2, steps=False);
        stair(build, 4, cy - 5, -13, 0, 5, 2);
        stair(build, self.long - 9, cy + 1, -13, 0, 5, 2);
        # The bridge over the canyon from the near path, stepping up to the
        # far one.
        bx = self.bridge_x;
        deck(build, bx, y0, bx + 3, y1, 0);
        stair(build, bx, y1 - 4, 0, 1, fp, 3);
        keep_box(build, rim, bx, y0 - 1, bx + 3, y0, 0);
        keep_box(build, rim, bx, y1, bx + 3, y1 + 1, fp);
        # The way down to the canyon floor: a stair along the near wall, or a
        # lift.
        if self.by_lift {
            lift(build, self.long - 6, y0, self.long - 3, y0 + 3, -8, 0);
            keep_box(build, rim, self.long - 6, y0 - 1, self.long - 3, y0, 0);
        } else {
            stair(build, self.long - 10, y0, -8, 0, 8, 3);
            keep_box(build, rim, self.long - 4, y0 - 1, self.long - 2, y0, 0);
        }
        boulders(build, dice, 2, cy + 4, self.long - 6, self.wide - 4, -8, dice.between(2, 4), [[bx - 1, y0, bx + 4, y1], [self.long - 10, cy, self.long, self.wide], [2, cy + 4, self.long - 7, cy + 5]]);
        build.doorway(rim, self.enter);
        for port in self.taken {
            if port.floor < 0 {
                build.doorway(floor, port);
            } else {
                build.doorway(rim, port);
            }
        }
        # Guards come onto the far path as the player starts over the bridge;
        # flyers come in over the canyon; a soldier walks its floor.
        over = build.touch(float(bx), float(y0), 0.0, float(bx + 3), float(y0 + 3), 6.0);
        squad(build, over, [[float(bx) + 8.5, float(self.wide) - 3.5, float(fp)], [float(self.long) - 4.5, float(self.wide) - 3.5, float(fp)]], [STRIKE_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 270.0);
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(y0), 8.0);
        squad(build, come_in, [[float(self.long // 2), float(cy), 6.0], [float(self.long) - 6.0, float(cy) + 2.0, 8.0]], ["monster_flyer"], 180.0);
        rounds(build, STRIKE_FOES.pick(dice, self.danger), [[3.5, float(cy) + 4.5], [float(self.long) - 10.5, float(cy) + 4.5]], -8);
        build.foe(float(self.long) - 4.5, 3.5, 0, STRIKE_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(bx) + 1.5, float(cy) + 5.5, -8, STRIKE_FOES.pick(dice, self.danger, True), 90.0);
        splashing(build, 10.5, float(cy), -9.0, 4.0);
        sparking(build, float(self.long) - 1.2, float(cy) + 4.0, -6.0, 2, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 4.0, -8, "ammo_grenades", "q2");
    }
}

"""A compound under the sky: a bunker whose roof is walked, its guardroom,
a watchtower up a lift; barrels."""
node Outpost(Prefab) {
    has bunker_x: int = 10,
        bunker_y: int = 8,
        tower: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Outpost";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = 44;
        self.tower = dice.chance(0.6);
        self.bunker_x = dice.between(9, 12);
        self.bunker_y = dice.between(9, self.wide - 17);
        self.low = -13;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 4), floor=0),
            Port(face=1, along=6.0, floor=0),
            Port(face=3, along=float(self.long - 8), floor=0)
        ];
        if self.tower {
            self.leaves.append(Port(face=0, along=float(self.wide - 4), floor=12));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, 8);
        # The harbor along the near side short of the quay by the way on
        # there, a stair up out of it.
        build.pool(1, 1, -12, self.long - 11, 5, 0, 2, steps=False);
        stair(build, 3, 3, -12, 0, 12, 2);
        splashing(build, 8.5, 2.5, -1.0, 4.0);
        build.foe(16.5, 2.5, -6, "monster_flipper", 0.0);
        # The bunker: its walls and roof, the guardroom in it, its door, the
        # stair up to its roof along its near wall.
        bx = self.bunker_x;
        yb = self.bunker_y;
        build.solid(bx, yb, 0, bx + 10, yb + 8, 8);
        guard = build.room(bx + 1, yb + 1, 0, bx + 9, yb + 7, 6, variant=dice.below(3));
        build.widen(guard, bx + 9, yb + 3, 0, bx + 10, yb + 5, 4);
        build.rising_door(float(bx + 9), float(yb + 3), 0.0, float(bx + 10), float(yb + 5), 4.0, {"wait": "-1"});
        stair(build, bx, yb - 3, 0, 0, 8, 3);
        keep_box(build, yard, bx + 7, yb, bx + 8, yb + 1, 8);
        broken = stash(build, bx + 1, yb + 3, 0, 0, Q2_ARMOR, 5);
        broken +>:Fires:+> build.explosion(float(bx) + 5.0, float(yb) + 4.0, 1.0);
        inside = build.touch(float(bx + 10), float(yb + 2), 0.0, float(bx + 12), float(yb + 6), 6.0);
        squad(build, inside, [[float(bx) + 7.0, float(yb) + 2.0, 0.0], [float(bx) + 7.0, float(yb) + 6.0, 0.0]], [STRIKE_FOES.pick(dice, self.danger, True), "monster_soldier"], 0.0);
        # The watchtower against the far wall, up a lift; or a second bunker.
        if self.tower {
            build.solid(self.long - 5, self.wide - 6, 0, self.long - 1, self.wide - 2, 12);
            lift(build, self.long - 8, self.wide - 5, self.long - 5, self.wide - 2, 0, 12);
            keep_box(build, yard, self.long - 5, self.wide - 5, self.long - 4, self.wide - 2, 12);
            build.level(yard, 12);
            build.foe(float(self.long) - 2.5, float(self.wide) - 4.0, 12, "monster_soldier_ss", 180.0);
        } else {
            build.solid(self.long - 8, self.wide - 7, 0, self.long - 2, self.wide - 2, 5);
            build.room(self.long - 7, self.wide - 6, 0, self.long - 3, self.wide - 3, 4);
            build.widen(yard, self.long - 6, self.wide - 7, 0, self.long - 4, self.wide - 6, 4);
            build.foe(float(self.long) - 5.0, float(self.wide) - 4.5, 0, STRIKE_FOES.pick(dice, self.danger), 270.0);
        }
        # A walkway along the far wall, bridged to from the bunker's roof.
        deck(build, 9, self.wide - 5, self.long - 9, self.wide - 1, 8);
        deck(build, bx + 3, yb + 8, bx + 6, self.wide - 5, 8);
        keep_box(build, yard, bx + 3, yb + 7, bx + 6, yb + 8, 8);
        keep_box(build, yard, bx + 3, self.wide - 5, bx + 6, self.wide - 4, 8);
        rounds(build, "monster_soldier_ss", [[10.5, float(self.wide) - 3.0], [float(self.long) - 10.5, float(self.wide) - 3.0]], 8);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        clear = [[0, 0, self.long, 6], [0, middle - 3, 5, middle + 3], [bx - 1, yb - 4, bx + 13, yb + 9], [self.long - 9, self.wide - 8, self.long, self.wide], [self.long - 5, middle - 7, self.long, middle - 1], [3, self.wide - 4, 10, self.wide], [self.long - 11, 0, self.long - 5, 4]];
        barrels(build, dice, 2, 2, self.long - 2, self.wide - 2, 0, dice.between(3, 4), clear);
        # A gunner on the roof, soldiers walking the yard.
        build.foe(float(bx) + 5.0, float(yb) + 4.0, 8, STRIKE_FOES.pick(dice, self.danger, True), 180.0);
        rounds(build, "monster_soldier", [[3.5, 7.0], [float(self.long) - 3.5, 7.0]], 0);
        rounds(build, STRIKE_FOES.pick(dice, self.danger), [[float(bx) - 2.5, float(self.wide) - 3.5], [float(self.long) - 10.5, float(self.wide) - 3.5]], 0);
        come_in = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 8.0);
        beamed(build, come_in, 2, self.wide - 6, -8, STRIKE_FOES.pick(dice, self.danger), float(bx) + 12.5, float(yb) - 2.5, 0, 180.0);
        sparking(build, float(bx) + 0.2, float(yb) + 6.5, 4.0, 2, 4.0);
        build.supply(2.5, 7.0, 0, Q2_HEALTH, "q2");
        build.supply(float(bx) + 8.5, float(yb) + 6.5, 8, "ammo_bullets", "q2");
    }
}

"""A cove under the sky, a quay round two sides over the drowned rock, a
radio bunker on an islet in the sea, the airstrike marker on its roof up a
lift or a stair; taking it opens the closets on the quay."""
node MarkerSite(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 24,
        by_lift: bool = False,
        jetty: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Marker site (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(34, 36);
        self.hall_wide = dice.between(24, 26);
        self.wide = self.hall_wide + 4;
        self.by_lift = dice.chance(0.5);
        self.jetty = dice.chance(0.6);
        self.tall = 44;
        self.low = -9;
        self.high = 46;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        cove = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.doorway(cove, self.enter);
        # The sea, and the quay along the far wall a deck over it; a stair up
        # out of the water onto the near quay and one onto the far.
        build.pool(6, 1, -8, self.long - 1, side, 0, 2, steps=False);
        quay = side - 5;
        build.solid(6, quay, -1, self.long - 1, side, 0);
        stair(build, 13, 1, -8, 2, 8, 3);
        keep_box(build, cove, 5, 1, 6, 4, 0);
        stair(build, self.long - 4, quay - 8, -8, 1, 8, 3);
        keep_box(build, cove, self.long - 4, quay, self.long - 1, quay + 1, 0);
        # The islet: rock up from the bottom, the bunker on it, a walk along
        # its near side and its front.
        ix0 = 15;
        ix1 = self.long - 7;
        iy0 = 4;
        iy1 = quay - 3;
        bx0 = ix0 + 6;
        by1 = iy1 - 3;
        roof = 6;
        build.solid(ix0, iy0, -8, ix1, iy1, 0);
        build.solid(bx0, iy0, 0, ix1, by1, roof);
        # A guardroom in the bunker, its door in the front.
        guard = build.room(bx0 + 1, iy0 + 1, 0, ix1 - 1, by1 - 1, roof - 2, variant=dice.below(3));
        build.widen(guard, bx0 + 1, by1 - 1, 0, bx0 + 4, by1, 4);
        build.rising_door(float(bx0 + 1), float(by1 - 1), 0.0, float(bx0 + 4), float(by1), 4.0, {"wait": "-1"});
        build.foe(float(bx0) + 2.5, float(iy0) + 2.5, 0, STRIKE_FOES.pick(dice, self.danger, True), 90.0);
        build.supply(float(ix1) - 2.5, float(iy0) + 2.5, 0, Q2_ARMOR, "q2");
        # Up to the roof by the islet's edge, a deck over the walk to it; the
        # radio sets on it.
        if self.by_lift {
            lift(build, ix0, iy0 + 2, ix0 + 3, iy0 + 5, 0, roof);
            deck(build, ix0 + 3, iy0 + 2, bx0, iy0 + 5, roof);
            keep_box(build, cove, ix0 + 3, iy0 + 2, ix0 + 4, iy0 + 5, roof);
        } else {
            stair(build, ix0, iy0 + 1, 0, 1, roof, 3);
            deck(build, ix0 + 3, iy0 + 4, bx0, iy0 + 7, roof);
            keep_box(build, cove, ix0 + 3, iy0 + 4, ix0 + 4, iy0 + 7, roof);
        }
        build.solid(ix1 - 2, iy0 + 1, roof, ix1 - 1, by1 - 1, roof + 3);
        # The way to the islet: a jetty from the far quay, or swum, the lift
        # up out of the water by its near side either way.
        if self.jetty {
            deck(build, ix0 + 1, iy1, ix0 + 4, quay, 0);
            keep_box(build, cove, ix0 + 1, quay, ix0 + 4, quay + 1, 0);
            keep_box(build, cove, ix0 + 1, iy1 - 1, ix0 + 4, iy1, 0);
        } else {
            build.touch(3.0, float(cy - 2), 0.0, 5.0, float(cy + 2), 6.0, True, "The radio bunker stands out in the water");
        }
        lift(build, ix0, iy0 - 3, ix0 + 3, iy0, -8, 0);
        keep_box(build, cove, ix0, iy0, ix0 + 3, iy0 + 1, 0);
        taken = key_taken(build, self.key, float(bx0) + 3.0, float(iy0 + by1) * 0.5, roof);
        taken +>:Fires:+> build.objective("Place the airstrike marker in the target area");
        closets(build, taken, side, 0, [3, self.long - 9], [STRIKE_FOES.pick(dice, self.danger, True), STRIKE_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[10.5, float(cy) - 4.0, 6.0], [float(self.long) - 3.0, 7.0, 6.0]], ["monster_flyer"], 0.0);
        rounds(build, "monster_soldier_ss", [[8.5, float(quay) + 2.5], [float(self.long) - 3.5, float(quay) + 2.5]], 0);
        for index in range(dice.between(2, 3)) {
            build.foe(10.5, 7.5 + float(index) * 4.0, -6, "monster_flipper", 0.0);
        }
        splashing(build, 10.5, float(cy) - 2.0, -2.0, 3.5);
        build.foe(float(bx0) + 2.5, float(iy1) - 1.5, 0, STRIKE_FOES.pick(dice, self.danger), 180.0);
        sparking(build, float(ix1) - 2.2, float(iy0) + 2.5, float(roof) + 1.5, 2, 3.0);
        sparking(build, float(ix1) - 2.2, float(by1) - 2.5, float(roof) + 2.0, 2, 4.5);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door out to the target zone; the marker placed at its
console, the airstrike falls and the way out opens."""
node StrikeZone(Prefab) {
    has key: str = "",
        ledge: int = 6,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Strike zone" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = STRIKE;
        self.district = level_district(STRIKE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.ledge = 6;
        self.tall = 44;
        self.low = -8;
        self.high = self.tall + 2;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        zone = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(zone, self.ledge);
        # The ledge along the far side, up a stair, its guards.
        deck(build, wall + 7, self.wide - 5, self.long - 8, self.wide - 1, self.ledge);
        stair(build, wall + 1, self.wide - 4, 0, 0, self.ledge, 3);
        keep_box(build, zone, wall + 7, self.wide - 4, wall + 8, self.wide - 1, self.ledge);
        # A crater flooded in the yard, a stair up out of it.
        build.pool(wall + 2, 2, -7, wall + 9, middle - 4, 0, 2, steps=False);
        stair(build, wall + 2, middle - 6, -7, 0, 7, 2);
        # The target zone: a pad in the yard's middle, its console.
        tx = (wall + 1 + self.long - 8) // 2;
        build.solid(tx - 3, middle - 3, 0, tx + 3, middle + 3, 1);
        build.solid(tx + 1, middle - 1, 1, tx + 2, middle + 1, 3);
        # The way out in a bunker at the far end behind its blast door.
        ex = self.long - 7;
        build.solid(ex, 1, 0, self.long - 1, self.wide - 1, self.tall);
        refuge = build.room(ex + 1, middle - 3, 0, self.long - 1, middle + 3, 8);
        build.widen(refuge, ex, middle - 2, 0, ex + 1, middle + 2, 7);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        # The marker placed, the airstrike falls round the zone and the blast
        # door opens.
        placed = build.push(float(tx + 1), float(middle) + 0.5, 1.5, 2);
        placed +>:Fires:+> build.objective("Airstrike inbound. Get to the bunker");
        blast_chain(build, placed, [[float(tx) - 6.0, 3.0, 1.0], [float(tx) + 6.0, float(self.wide) - 7.0, 1.0], [float(tx) - 2.0, float(self.wide) - 8.0, 2.0], [float(tx) + 4.0, 3.5, 1.0], [float(wall) + 3.0, float(middle) + 5.0, 1.0], [float(ex) - 3.0, 3.0, 2.0]], 0.4);
        clear = build.delay(3.0);
        placed +>:Fires:+> clear;
        clear +>:Fires:+> build.opened(float(ex), float(middle - 2), 0.0, float(ex + 1), float(middle + 2), 7.0);
        build.touch(float(tx - 5), float(middle - 3), 0.0, float(tx - 3), float(middle + 3), 6.0, True, "Place the airstrike marker at the console");
        # Guards come out onto the ledge and the yard as the player comes out;
        # flyers come in with the strike.
        out = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        squad(build, out, [[float(self.long) - 10.5, float(self.wide) - 3.0, float(self.ledge)], [float(tx) + 6.5, 3.5, 0.0]], [STRIKE_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        squad(build, placed, [[float(tx), 4.0, 8.0], [float(tx), float(self.wide) - 8.0, 9.0]], ["monster_flyer"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, STRIKE_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        sparking(build, float(ex) - 0.2, float(middle) + 3.5, 4.0, 2, 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""strike's stretches: [name, role]."""
glob STRIKE_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["cliffs", "flow"],
         ["canyon", "flow"],
         ["outpost", "hub"],
         ["cliffs", "hub"],
         ["marker", "keyroom"],
         ["zone", "end"],
         ["zone", "gate"]
     ];

"""One of strike's stretches by its name."""
def make_strike(name: str, key: str) -> Prefab {
    if name == "landing" {
        return Landing();
    }
    if name == "cliffs" {
        return SeaCliffs();
    }
    if name == "canyon" {
        return Canyon();
    }
    if name == "outpost" {
        return Outpost();
    }
    if name == "marker" {
        return MarkerSite(key=key if key else "key_silver");
    }
    return StrikeZone(key=key);
}
