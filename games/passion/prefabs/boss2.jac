"""Prefabs drawn from Quake II's boss2, the Final Showdown: the gate over a
lava moat and its lifts to the gantry, a ramp winding up a shaft beside
plats, the makers' gallery whose five buttons open a hidden room, the
arena of tiers round a pit and its timed doors, the Makron's lair where
reinforcements come in waves, the sanctum of the key, and the escape pod
bay. Raised in boss2's own palette.

- `ShowdownGate`: the start. A hall, a moat of lava across it bridged, the
  gate beyond; plats up to a gantry over the far end; "Destroy the
  Makron".
- `ShowdownRamp`: a shaft, a ramp winding up its walls to the way on high
  up, and a plat up the middle for the quick way; guards come out on the
  ramp as it is climbed.
- `MakersGallery`: a gallery of plinths, a button on each of five; all
  five pressed, the counter blows open a wall on a hidden room (boss2's
  gallery of its makers); a balcony round it.
- `ShowdownTiers`: an arena of tiers stepping down to a pit, stairs
  between, a gantry over it; side rooms behind doors a button opens for
  a while. A hub.
- `MakronLair`: the Makron's hall round his dais, pillars and a gallery;
  his reinforcements come in waves, twelve seconds apart, as the player
  comes in (the Makron himself late in a run).
- `ShowdownSanctum`: the key on a deck up a lift; taking it opens the
  closets.
- `PodBay`: the end. A door (a key's, as a gate), a bay of escape pods
  along both walls, sealed ("Escape pod sealed"); the open pod's hatch at
  the far end opened by its button, the station quaking; the way out in
  the pod."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, spiral, ring_landing, pillars }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, rounds, beamed, held_door, key_taken, closets, hurting, barrels }
import from .city2 { random_sparks }

glob BOSS2: str = "q2:boss2";

"""boss2's foes: iron maidens, gunners and gladiators, tanks deeper in."""
glob BOSS2_FOES: FoeMix = FoeMix(light=["monster_chick", "monster_gunner", "monster_gladiator"], strong=["monster_gladiator"], heavy_light=["monster_gladiator", "monster_chick"], heavy_strong=["monster_tank"], scale=0.4, heavy_scale=0.3);

"""The start: a hall, a moat of lava across it bridged, the gate beyond,
plats up to a gantry over the far end."""
node ShowdownGate(Prefab) {
    has gantry: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown gate";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gantry = dice.between(9, 10);
        self.tall = self.gantry + 9;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gantry),
            Port(face=3, along=float(self.long - 6), floor=self.gantry)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gantry;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        mx = 10;
        build.pool(mx, 1, -3, mx + 5, self.wide - 1, 0, 4, False, False);
        build.solid(mx, middle - 2, -3, mx + 5, middle + 2, 0);
        keep_box(build, hall, mx - 1, middle - 2, mx, middle + 2, 0);
        keep_box(build, hall, mx + 5, middle - 2, mx + 6, middle + 2, 0);
        # The gantry along the far end and the near wall, two plats up to it.
        gx = self.long - 8;
        deck(build, gx, 1, self.long - 1, 5, g);
        deck(build, gx, self.wide - 5, self.long - 1, self.wide - 1, g);
        deck(build, self.long - 5, 5, self.long - 1, self.wide - 5, g);
        lift(build, gx - 3, 2, gx, 5, 0, g);
        lift(build, gx - 3, self.wide - 5, gx, self.wide - 2, 0, g);
        keep_box(build, hall, gx, 2, gx + 1, 5, g);
        keep_box(build, hall, gx, self.wide - 5, gx + 1, self.wide - 2, g);
        gate_lever = build.push(float(self.long - 1), float(middle) + 0.5, float(g) + 1.5, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                held_door(build, self, port, gate_lever, "The gate is opened from the gantry");
            }
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0);
        come_in +>:Fires:+> build.objective("Destroy the Makron");
        over = build.touch(float(mx), float(middle - 2), 0.0, float(mx + 5), float(middle + 2), 6.0);
        squad(build, over, [[float(self.long) - 3.0, 3.0, float(g)], [float(self.long) - 3.0, float(self.wide) - 3.0, float(g)]], [BOSS2_FOES.pick(dice, self.danger, True), "monster_gunner"], 180.0);
        beamed(build, over, 2, 2, -8, BOSS2_FOES.pick(dice, self.danger), float(mx) + 8.5, float(middle) + 0.5, 0, 180.0);
        blast_chain(build, over, [[float(mx) + 1.0, 3.0, 0.0], [float(mx) + 3.0, float(self.wide) - 3.0, 0.0]], 0.4);
        for index in range(dice.between(2, 3)) {
            build.foe(float(mx + 8 + index % 2 * 4) + 0.5, 3.5 + float(index) * 5.0, 0, BOSS2_FOES.pick(dice, self.danger), 180.0);
        }
        rounds(build, "monster_chick", [[3.5, 3.5], [3.5, float(self.wide) - 3.5]], 0);
        random_sparks(build, [[float(self.long) - 1.2, float(middle), float(g) + 3.0, 2.0], [1.2, 3.0, 3.0, 0.0]], 3.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, g, Q2_ARMOR, "q2");
    }
}

"""A shaft, a ramp winding up its walls to the way on high up, a plat up
the middle."""
node ShowdownRamp(Prefab) {
    has steps: int = 20,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown ramp";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        fits: list[int] = [];
        for steps in range(12, 30) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 5);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -9;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        # A plat up the shaft's middle, a catwalk from its top to the ramp's
        # landing.
        landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 5);
        ly = int(landing[1]);
        lift(build, cx - 2, ly - 1, cx + 1, ly + 2, 0, self.steps);
        deck(build, cx + 1, ly - 1, self.long - 4, ly + 2, self.steps);
        keep_box(build, shaft, self.long - 5, ly - 1, self.long - 4, ly + 2, self.steps);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        halfway = build.touch(float(self.long - 4), 1.0, 4.0, float(self.long - 1), float(self.wide - 1), 12.0);
        squad(build, halfway, [[float(self.long) - 2.5, float(cy) + 0.5, float(self.steps)], [2.5, float(self.wide) - 2.5, 12.0]], [BOSS2_FOES.pick(dice, self.danger, True), "monster_chick"], 180.0);
        beamed(build, halfway, 2, 2, -8, BOSS2_FOES.pick(dice, self.danger), float(cx) + 3.5, float(cy) + 0.5, 0, 180.0);
        build.foe(float(cx) + 3.5, float(cy) - 3.5, 0, BOSS2_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 2.5, float(cy) + 0.5, 12, BOSS2_FOES.pick(dice, self.danger, True), 180.0);
        random_sparks(build, [[1.2, float(cy), 4.0, 0.0], [float(self.long) - 1.2, float(cy) + 2.0, float(self.steps) + 2.0, 2.0]], 3.0);
        build.supply(float(cx) - 3.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""A gallery of plinths, a button on each of five; all five pressed, a
wall bursts open on a hidden room."""
node MakersGallery(Prefab) {
    has bal: int = 8,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Makers' gallery";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.bal = dice.between(8, 9);
        self.tall = self.bal + 9;
        self.low = -9;
        self.high = 22;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long - 6), floor=self.bal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        b = self.bal;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, b);
        # The balcony along the near wall up a stair.
        deck(build, 4 + b, 1, self.long - 1, 5, b);
        stair(build, 4, 1, 0, 0, b, 3);
        keep_box(build, hall, 4 + b, 1, 5 + b, 4, b);
        # Five plinths down the gallery, a button on each.
        count = build.tally(5, "The gallery's hidden room opens");
        for index in range(5) {
            px = 7 + index * 4;
            py = middle + 3 if index % 2 == 0 else middle - 3;
            build.solid(px, py, 0, px + 2, py + 2, 4);
            pressed = build.push(float(px) + 1.0, float(py + 2) if index % 2 == 0 else float(py), 1.5, 1 if index % 2 == 0 else 3);
            pressed +>:Fires:+> count;
            pressed +>:Fires:+> build.sparks(float(px) + 1.0, float(py) + 1.0, 3.0, 0);
        }
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "Welcome to the gallery of its makers");
        # The hidden room beyond the far wall's panel, opened by the counter.
        build.solid(self.long - 7, self.wide - 7, 0, self.long - 1, self.wide - 1, self.tall);
        room = build.room(self.long - 6, self.wide - 6, 0, self.long - 1, self.wide - 1, 6);
        build.widen(room, self.long - 5, self.wide - 7, 0, self.long - 3, self.wide - 6, 4);
        panel = build.breakable(float(self.long - 5), float(self.wide - 7), 0.0, float(self.long - 3), float(self.wide - 6), 4.0, 200);
        count +>:Fires:+> panel;
        build.secret(float(self.long - 6), float(self.wide - 6), 0.0, float(self.long - 1), float(self.wide - 1), 3.0);
        build.supply(float(self.long) - 3.5, float(self.wide) - 3.5, 0, "item_health_mega", "q2");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        up = build.touch(float(4 + b), 1.0, float(b), float(6 + b), 5.0, float(b + 6));
        squad(build, up, [[float(self.long) - 3.0, 3.0, float(b)]], [BOSS2_FOES.pick(dice, self.danger, True)], 180.0);
        squad(build, count, [[6.5, float(middle), 0.0], [float(self.long) - 9.0, float(middle), 0.0]], ["monster_gladiator", "monster_chick"], 0.0);
        rounds(build, "monster_gunner", [[5.5, float(middle)], [float(self.long) - 9.5, float(middle)]], 0);
        random_sparks(build, [[1.2, 3.0, 4.0, 0.0], [float(self.long) - 1.2, 3.0, float(b) + 2.0, 2.0]], 3.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""An arena of tiers stepping down to a pit, stairs between, a gantry over
it, side rooms behind doors a button opens for a while."""
node ShowdownTiers(Prefab) {
    has drop: int = 3,
        gantry: int = 9,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown tiers";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.drop = dice.between(3, 4);
        self.gantry = 9;
        self.tall = dice.between(26, 28);
        self.low = -2 * self.drop - 8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        d = self.drop;
        g = self.gantry;
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(arena, -d);
        build.level(arena, -2 * d);
        build.level(arena, g);
        build.widen(arena, 5, 5, -d, self.long - 5, self.wide - 5, 0);
        build.widen(arena, 9, 9, -2 * d, self.long - 9, self.wide - 9, -d);
        stair(build, 5 + d - 1, cy - 2, -d, 2, d, 4);
        stair(build, self.long - 5 - d, cy - 2, -d, 0, d, 4);
        stair(build, cx - 2, 9 + d - 1, -2 * d, 3, d, 4);
        stair(build, cx - 2, self.wide - 9 - d, -2 * d, 1, d, 4);
        # The gantry across the arena over the pit, plats up to its ends.
        deck(build, cx - 2, 1, cx + 2, self.wide - 1, g);
        lift(build, cx + 2, 2, cx + 5, 5, 0, g);
        keep_box(build, arena, cx + 1, 2, cx + 2, 5, g);
        # Side rooms in the corners behind doors the button by each opens
        # for a while.
        for (index, corner) in enumerate([[2, 2], [self.long - 5, self.wide - 5]]) {
            build.solid(corner[0] - 1, corner[1] - 1, 0, corner[0] + 4, corner[1] + 4, 6);
            side_room = build.room(corner[0], corner[1], 0, corner[0] + 3, corner[1] + 3, 5);
            fields = {"wait": "8"};
            dx = corner[0] + 3 if index == 0 else corner[0] - 1;
            build.widen(side_room, dx, corner[1], 0, dx + 1, corner[1] + 3, 5);
            build.rising_door(float(dx), float(corner[1]), 0.0, float(dx + 1), float(corner[1] + 3), 5.0, fields);
            opener = build.push(float(dx) + (1.0 if index == 0 else 0.0), float(corner[1]) + 3.5, 1.5, 0 if index == 0 else 2);
            opener +>:Fires:+> build.cue([fields], "door");
            build.supply(float(corner[0]) + 1.5, float(corner[1]) + 1.5, 0, Q2_HEALTH if index == 0 else "ammo_rockets", "q2");
        }
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        down = build.touch(9.0, 9.0, float(-2 * d), float(self.long - 9), float(self.wide - 9), float(-2 * d + 6));
        squad(build, down, [[3.0, float(cy) + 3.0, 0.0], [float(self.long) - 3.0, float(cy) - 3.0, 0.0], [float(cx), 3.0, float(g)]], [BOSS2_FOES.pick(dice, self.danger, True), "monster_chick", "monster_gunner"], 0.0);
        beamed(build, down, 2, self.wide - 6, -2 * d - 7, BOSS2_FOES.pick(dice, self.danger), float(cx) + 0.5, float(cy) + 0.5, -2 * d, 0.0);
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 4 + index * 3) + 0.5, float(cy) + 0.5, -2 * d, BOSS2_FOES.pick(dice, self.danger), 0.0);
        }
        rounds(build, "monster_gunner", [[3.0, 8.0], [float(self.long) - 3.0, 8.0], [float(self.long) - 3.0, float(self.wide) - 8.0], [3.0, float(self.wide) - 8.0]], 0);
        random_sparks(build, [[1.2, float(cy), 3.0, 0.0], [float(self.long) - 1.2, float(cy), 3.0, 2.0], [float(cx) + 0.5, 1.2, float(g) + 2.0, 1.0]], 3.0);
        build.supply(float(cx) + 0.5, float(cy) - 3.0, -2 * d, Q2_ARMOR, "q2");
    }
}

"""The Makron's hall round his dais, pillars and a gallery; his
reinforcements come in waves."""
node MakronLair(Prefab) {
    has gal: int = 9,
        dais: int = 3,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Makron's lair";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.gal = 9;
        self.dais = dice.between(2, 3);
        self.tall = dice.between(27, 30);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 6), floor=self.gal),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gal;
        lair = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(lair, g);
        build.level(lair, self.dais);
        # The dais in the middle, pillars round it, the gallery along the
        # far wall up a stair.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.dais);
        pillars(build, cx - 7, cy - 7, cx + 8, cy + 8, 0, self.tall, 7, [[cx - 5, cy - 5, cx + 5, cy + 5], [0, cy - 3, 5, cy + 3], [self.long - 5, cy - 3, self.long, cy + 3]]);
        deck(build, 4 + g, self.wide - 5, self.long - 1, self.wide - 1, g);
        stair(build, 4, self.wide - 4, 0, 0, g, 3);
        keep_box(build, lair, 4 + g, self.wide - 4, 5 + g, self.wide - 1, g);
        build.doorway(lair, self.enter);
        for port in self.taken {
            build.doorway(lair, port);
        }
        # The Makron (late in a run) on his dais; his reinforcements come in
        # three waves twelve seconds apart once the player is in.
        boss = "monster_makron" if self.danger > 0.85 else ("monster_tank" if self.danger > 0.4 else "monster_gladiator");
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.dais, boss, 180.0);
        come_in = build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0, True, "The Makron's lair");
        last = come_in;
        for wave in range(3) {
            late = build.delay(12.0 if wave > 0 else 2.0);
            last +>:Fires:+> late;
            squad(build, late, [[float(self.long) - 3.0, 3.0 + float(wave) * 4.0, 0.0], [float(cx) + 6.0, float(self.wide) - 3.0, float(g)]], [BOSS2_FOES.pick(dice, self.danger, wave == 2), "monster_chick"], 180.0);
            late +>:Fires:+> build.explosion(float(self.long) - 3.0, 3.0 + float(wave) * 4.0, 2.0);
            last = late;
        }
        beamed(build, come_in, 2, 2, -8, BOSS2_FOES.pick(dice, self.danger, True), float(cx) - 6.5, float(cy) + 0.5, 0, 0.0);
        build.solid(self.long - 6, 1, 0, self.long - 1, 6, 7);
        armory = build.room(self.long - 5, 2, 0, self.long - 2, 5, 5);
        build.widen(armory, self.long - 6, 2, 0, self.long - 5, 5, 5);
        lever = build.push(float(self.long - 1), float(self.wide) - 3.0, float(g) + 1.5, 2);
        lever +>:Fires:+> build.opened(float(self.long - 6), 2.0, 0.0, float(self.long - 5), 5.0, 5.0);
        build.supply(float(self.long) - 3.5, 3.5, 0, Q2_ARMOR, "q2");
        build.breakable(float(cx) - 9.0, float(cy) + 3.0, 0.0, float(cx) - 8.0, float(cy) + 4.0, 2.0, 10);
        rounds(build, "monster_gunner", [[float(cx) - 6.0, float(cy) - 6.0], [float(cx) + 6.0, float(cy) - 6.0], [float(cx) + 6.0, float(cy) + 6.0], [float(cx) - 6.0, float(cy) + 6.0]], 0);
        barrels(build, dice, 1, 1, self.long - 1, cy - 5, 0, 2, [[0, cy - 4, 5, cy + 4], [self.long // 2 - 3, 0, self.long // 2 + 3, 4], [cx - 8, cy - 8, cx + 9, cy + 9]]);
        random_sparks(build, [[1.2, 3.0, 3.0, 0.0], [float(self.long) - 1.2, float(cy), 4.0, 2.0], [float(cx) + 4.2, float(cy), float(self.dais) + 2.0, 0.0]], 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "ammo_cells", "q2");
    }
}

"""The key on a deck up a lift in the sanctum; taking it opens the
closets."""
node ShowdownSanctum(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Showdown sanctum (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.upper = dice.between(7, 8);
        self.tall = self.upper + 8;
        self.low = -9;
        self.high = 18;
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
        build.level(room, self.upper);
        build.doorway(room, self.enter);
        dx = self.long - 7;
        deck(build, dx, 1, self.long - 1, side, self.upper);
        lift(build, dx - 3, cy - 1, dx, cy + 2, 0, self.upper);
        keep_box(build, room, dx, cy - 1, dx + 1, cy + 2, self.upper);
        taken = key_taken(build, self.key, float(self.long) - 3.5, float(cy), self.upper);
        closets(build, taken, side, 0, [3, dx - 5], [BOSS2_FOES.pick(dice, self.danger, True), BOSS2_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[float(dx) - 5.0, float(cy) + 0.5, 0.0]], ["monster_gladiator"], 0.0);
        beamed(build, taken, 2, 2, -8, BOSS2_FOES.pick(dice, self.danger, True), 6.5, float(cy) + 0.5, 0, 0.0);
        taken +>:Fires:+> build.explosion(float(dx) - 1.0, float(cy) + 3.0, 1.0);
        stash(build, dx + 1, 1, 0, 1, "ammo_cells", self.upper - 1);
        build.foe(float(self.long) - 3.5, 3.5, self.upper, BOSS2_FOES.pick(dice, self.danger), 180.0);
        rounds(build, "monster_chick", [[4.5, 3.0], [float(dx) - 4.5, 3.0]], 0);
        random_sparks(build, [[float(self.long) - 1.2, float(cy) - 2.0, float(self.upper) + 2.0, 2.0], [1.2, float(cy), 3.0, 0.0]], 3.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into a bay of escape pods, sealed; the open pod's hatch
at the far end opened by its button, the way out in the pod."""
node PodBay(Prefab) {
    has key: str = "",
        pods: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pod bay" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BOSS2;
        self.district = level_district(BOSS2);
        self.pods = dice.between(2, 3);
        self.long = 13 + self.pods * 5 + 6;
        self.wide = dice.between(20, 22);
        self.tall = 16;
        self.low = -1;
        self.high = 22;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        bay = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Locate an open escape pod");
        # The sealed pods along both walls: alcoves behind shut hatches.
        for index in range(self.pods) {
            px = wall + 4 + index * 5;
            for (side, y0) in enumerate([1, self.wide - 4]) {
                build.solid(px, y0, 0, px + 4, y0 + 3, 8);
                build.touch(float(px), float(y0 + 3) if side == 0 else float(y0 - 2), 0.0, float(px + 4), float(y0 + 5) if side == 0 else float(y0), 6.0, False, "Escape pod sealed");
            }
        }
        # The open pod at the far end, its hatch opened by the button by it;
        # the station quakes as it opens.
        build.solid(self.long - 6, 1, 0, self.long - 1, self.wide - 1, self.tall);
        pod = build.room(self.long - 5, middle - 3, 0, self.long - 1, middle + 3, 8);
        build.widen(pod, self.long - 6, middle - 2, 0, self.long - 5, middle + 2, 7);
        hatch = build.opened(float(self.long - 6), float(middle - 2), 0.0, float(self.long - 5), float(middle + 2), 7.0);
        opener = build.push(float(self.long - 6), float(middle) + 3.5, 1.5, 2);
        opener +>:Fires:+> hatch;
        opener +>:Fires:+> build.objective("Escape pod open. Get in");
        blast_chain(build, opener, [[float(wall) + 5.0, 3.0, 2.0], [float(wall) + 10.0, float(self.wide) - 3.0, 2.0], [float(self.long) - 8.0, float(middle), 3.0], [float(wall) + 3.0, float(middle), 1.0]], 0.5);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        squad(build, come_in, [[float(self.long) - 9.0, float(middle) - 3.0, 0.0], [float(self.long) - 9.0, float(middle) + 3.0, 0.0]], [BOSS2_FOES.pick(dice, self.danger, True), "monster_chick"], 180.0);
        squad(build, opener, [[float(wall) + 3.0, float(middle) - 4.0, 0.0]], ["monster_gladiator"], 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, BOSS2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        hurting(build, float(self.long - 2), float(middle - 3), 6.0, float(self.long - 1), float(middle + 3), 8.0, 2);
        random_sparks(build, [[float(self.long) - 6.2, float(middle) - 3.5, 3.0, 2.0], [float(wall) + 1.2, 3.0, 4.0, 0.0]], 2.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""boss2's stretches: [name, role]."""
glob BOSS2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["ramp", "flow"],
         ["gallery", "flow"],
         ["lair", "flow"],
         ["tiers", "hub"],
         ["lair", "hub"],
         ["sanctum", "keyroom"],
         ["pods", "end"],
         ["pods", "gate"]
     ];

"""One of boss2's stretches by its name."""
def make_boss2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return ShowdownGate();
    }
    if name == "ramp" {
        return ShowdownRamp();
    }
    if name == "gallery" {
        return MakersGallery();
    }
    if name == "tiers" {
        return ShowdownTiers();
    }
    if name == "lair" {
        return MakronLair();
    }
    if name == "sanctum" {
        return ShowdownSanctum(key=key if key else "key_silver");
    }
    return PodBay(key=key);
}
