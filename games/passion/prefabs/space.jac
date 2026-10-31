"""Prefabs drawn from Quake II's space, the Comm Satellite: the docking bay
under its gantries, the ring transporter whose rings drop one after
another before its lift rises, solar arrays over a void crossed by
catwalks and jump pads, the dish on its mast whose four clamps are
released to bring it down, the power core shot out section by section,
the control room where the key lies, and the shuttle home. Raised in
space's own palette.

- `DockingBay`: the start. The shuttle on the bay's floor, its exhaust
  still hot, gantries along two walls high over the floor reached by a
  great plat (or from the walkway under them, up its stair, by a plat), a
  cargo sled riding a rail over them; "Find and disable the power core".
- `RingTransporter`: a tall shaft, a gallery round it at the top over a
  well (in the middle or a corner) a plat rides up; stepping on the pad
  drops the rings one after another ("Transport engaged").
- `SolarArray`: a void under the stars between two platforms, a catwalk
  over it and a solar panel floating in it reached by jump pads, the
  maintenance walk at its foot and a lift back up.
- `DishArray`: the dish high on its mast, a stair winding up round the
  mast, a catwalk along the wall; four clamps released (two on the mast
  at the floor, two up the stair) bring the dish down in flames and open
  the ways on.
- `PowerCore`: the core in a tall chamber, galleries round it at two
  heights up plats, bridges to the core; four couplings shot out on its
  faces disable it, the station powers down section by section and the
  doors on open one after another. A hub.
- `ControlRoom`: a ring of walkway round a pit, the key on a pod in the
  pit's middle: a lift rides up to it from the pit's floor, and in some
  seeds a console on the far wall draws out a bridge to it; taking it opens
  the closets and brings in the flyers.
- `ShuttlePort`: the end. A door (a key's, as a gate) into the shuttle's
  bay, a ramp up into the shuttle's cabin and the way out in it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, spiral }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, squad, rounds, beamed, held_door, key_taken, closets, pad_to, hurting }

glob SPACE: str = "q2:space";

"""space's foes: flyers and hovers, floaters deeper in."""
glob SPACE_FOES: FoeMix = FoeMix(light=["monster_flyer", "monster_flyer", "monster_hover"], strong=["monster_floater"], heavy_light=["monster_hover", "monster_floater"], scale=0.5);

"""The start: the shuttle on the bay's floor, gantries high over it up a
great plat or a stair and a plat."""
node DockingBay(Prefab) {
    has up: int = 18,
        two_stage: bool = False,
        tall: int = 27;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Docking bay";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.up = dice.between(19, 22);
        self.tall = self.up + 9;
        self.two_stage = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 4), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.up),
            Port(face=1, along=float(self.long - 10), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        u = self.up;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, u);
        # The shuttle on the floor, its exhaust still hot behind it.
        build.solid(3, 2, 0, 12, 7, 4);
        build.solid(12, 3, 0, 14, 6, 3);
        hurting(build, 1.0, 3.0, 0.0, 3.0, 6.0, 3.0, 3);
        # The gantries along the far wall and the far end, high up.
        deck(build, 1, self.wide - 6, self.long - 1, self.wide - 1, u);
        deck(build, self.long - 6, 1, self.long - 1, self.wide - 6, u);
        # A walkway under the gantry up a stair.
        build.level(bay, 9);
        deck(build, 10, self.wide - 6, self.long - 6, self.wide - 1, 9);
        stair(build, 1, self.wide - 5, 0, 0, 9, 3);
        keep_box(build, bay, 10, self.wide - 5, 11, self.wide - 2, 9);
        if self.two_stage {
            # The plat from the walkway's end to the gantry.
            lift(build, self.long - 9, self.wide - 9, self.long - 6, self.wide - 6, 9, u);
            keep_box(build, bay, self.long - 9, self.wide - 6, self.long - 6, self.wide - 5, 9);
        } else {
            lift(build, self.long - 9, self.wide - 9, self.long - 6, self.wide - 6, 0, u);
        }
        keep_box(build, bay, self.long - 9, self.wide - 6, self.long - 6, self.wide - 5, u);
        keep_box(build, bay, self.long - 6, self.wide - 9, self.long - 5, self.wide - 6, u);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        build.start(7.5, 8.5, 0, 0.0);
        build.supply(9.5, 8.5, 0, "ammo_shells", "q2");
        build.touch(4.0, 7.0, 0.0, 12.0, 11.0, 8.0) +>:Fires:+> build.objective("Find and disable the power core");
        # Flyers come in over the bay as the player arrives on the gantry; a
        # hover walks it.
        arrive = build.touch(float(self.long - 9), float(self.wide - 6), float(u), float(self.long - 5), float(self.wide - 3), float(u + 6));
        squad(build, arrive, [[8.0, float(middle), float(u - 4)], [float(self.long) - 12.0, 5.0, float(u - 3)]], ["monster_flyer", SPACE_FOES.pick(dice, self.danger, True)], 180.0);
        beamed(build, arrive, 2, 2, -8, SPACE_FOES.pick(dice, self.danger, True), 18.5, 3.5, 0, 90.0);
        rounds(build, SPACE_FOES.pick(dice, self.danger), [[4.5, float(self.wide) - 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [float(self.long) - 3.0, 3.0]], u);
        for index in range(dice.between(1, 2)) {
            build.foe(16.5 + float(index) * 4.0, float(middle) + 2.5, 3, "monster_flyer", 180.0);
        }
        # A cargo sled riding a rail across the bay over the gantry's height.
        build.train([2.0, 2.0, 1.0], [[4.0, float(middle) - 1.0, float(u + 4)], [float(self.long) - 9.0, float(middle) - 1.0, float(u + 4)]], 60.0, 2.0);
        sparking(build, 12.2, 4.5, 2.0, 0, 3.0);
        sparking(build, float(self.long) - 1.2, float(middle) - 4.0, float(u) + 2.0, 2, 5.0);
        build.supply(float(self.long) - 3.5, 3.5, u, Q2_HEALTH, "q2");
        build.supply(18.5, float(self.wide) - 8.5, 0, Q2_HEALTH, "q2");
    }
}

"""A tall shaft, a gallery round it at the top over a well a plat rides
up; the pad drops the rings one after another."""
node RingTransporter(Prefab) {
    has top: int = 22,
        corner: bool = False,
        tall: int = 31;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ring transporter";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(18, 20);
        self.wide = dice.between(18, 20);
        self.top = dice.between(24, 28);
        self.tall = self.top + 9;
        self.corner = dice.chance(0.4);
        self.low = -9;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy - 4), floor=0),
            Port(face=3, along=float(self.long // 2 + 2), floor=0),
            Port(face=0, along=float(cy + 4), floor=self.top),
            Port(face=1, along=float(self.long // 2), floor=self.top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        t = self.top;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, t);
        # The well the plat rides up: in the middle or a corner.
        hx = self.long - 6 if self.corner else cx - 2;
        hy = self.wide - 6 if self.corner else cy - 2;
        # The gallery round the well at the top.
        deck(build, 1, 1, self.long - 1, hy, t);
        deck(build, 1, hy + 4, self.long - 1, self.wide - 1, t);
        deck(build, 1, hy, hx, hy + 4, t);
        deck(build, hx + 4, hy, self.long - 1, hy + 4, t);
        lift(build, hx, hy, hx + 4, hy + 4, 0, t);
        keep_box(build, shaft, hx - 1, hy, hx, hy + 4, t);
        keep_box(build, shaft, hx + 4, hy, hx + 5, hy + 4, t);
        keep_box(build, shaft, hx, hy - 1, hx + 4, hy, t);
        keep_box(build, shaft, hx, hy + 4, hx + 4, hy + 5, t);
        # The rings: stepping on the pad drops them one after another down
        # the emitter on the near wall.
        pad = build.touch(float(hx), float(hy), 0.0, float(hx + 4), float(hy + 4), 4.0, True, "Transport engaged");
        last = pad;
        for ring in range(7) {
            late = build.delay(0.2);
            last +>:Fires:+> late;
            z = 2 + ring * 3;
            late +>:Fires:+> build.sinking(float(self.long - 2), float(cy - 1), float(self.long - 1), float(cy + 2), z, 1);
            last = late;
        }
        last +>:Fires:+> build.sparks(float(self.long) - 2.5, float(cy) + 0.5, float(t) - 2.0, 2);
        hurting(build, float(self.long - 2), float(cy - 1), 2.0, float(self.long - 1), float(cy + 2), float(t - 2), 2);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Flyers come down the shaft as the player rides up; floaters on the
        # gallery, a hover walking it.
        up = build.touch(float(hx), float(hy), float(t - 6), float(hx + 4), float(hy + 4), float(t - 2));
        squad(build, up, [[3.5, 3.5, float(t)], [float(self.long) - 3.5, float(self.wide) - 3.5, float(t)]], [SPACE_FOES.pick(dice, self.danger, True), "monster_flyer"], 180.0);
        pad +>:Fires:+> build.explosion(float(cx) + 0.5, 2.5, float(t) - 4.0);
        rounds(build, SPACE_FOES.pick(dice, self.danger), [[3.0, 3.0], [float(self.long) - 3.0, 3.0]], t);
        build.foe(float(cx) + 0.5, float(cy) + 5.5, 10, "monster_flyer", 180.0);
        build.foe(4.5, float(cy) + 4.5, 0, SPACE_FOES.pick(dice, self.danger), 0.0);
        sparking(build, float(self.long) - 1.2, float(cy) - 3.0, float(t) + 2.0, 2, 4.0);
        sparking(build, 1.2, 3.5, 3.0, 0, 6.0);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, t, "ammo_cells", "q2");
    }
}

"""A void under the stars between two platforms, a catwalk over it, a
solar panel in it reached by jump pads, the maintenance walk at its foot."""
node SolarArray(Prefab) {
    has deep: int = 12,
        panel: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Solar array";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.deep = dice.between(14, 16);
        self.panel = dice.chance(0.7);
        self.tall = 48;
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 5), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 5), floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=0, along=6.0, floor=0),
            Port(face=3, along=float(self.long // 2), floor=-self.deep)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        b = -self.deep;
        x0 = 7;
        x1 = self.long - 7;
        stars = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        void = build.room(x0, 1, b, x1, self.wide - 1, 0);
        build.level(void, b);
        # The catwalk straight over the void, along the far wall's side.
        cy = self.wide - 6;
        deck(build, x0, cy, x1, cy + 3, 0);
        keep_box(build, stars, x0 - 1, cy, x0, cy + 3, 0);
        keep_box(build, stars, x1, cy, x1 + 1, cy + 3, 0);
        # A solar panel floating in the void, jump pads to it and on.
        if self.panel {
            px = self.long // 2 - 3;
            deck(build, px, 3, px + 6, 9, 4);
            pad_to(build, 3.0, 6.0, 0, float(px) + 3.0, 6.0, 4);
            pad_to(build, float(px) + 2.0, 6.0, 4, float(x1) + 3.0, 6.0, 0);
            keep_box(build, stars, x0 - 1, 4, x0, 8, 0);
            keep_box(build, stars, px + 5, 4, px + 6, 8, 4);
            keep_box(build, stars, px, 4, px + 1, 8, 4);
            build.foe(float(px) + 4.5, 7.5, 4, "monster_hover", 180.0);
            build.supply(float(px) + 4.5, 4.5, 4, Q2_ARMOR, "q2");
        }
        # Vents to the vacuum at the void's foot, and a lower panel over it.
        hurting(build, float(x1 - 3), 1.0, float(b), float(x1), 4.0, float(b + 3), 5);
        deck(build, x0 + 3, self.wide // 2 - 1, x0 + 8, self.wide // 2 + 2, b + 6);
        # The maintenance walk at the void's foot, the lift back up.
        lift(build, x0, 1, x0 + 3, 4, b, 0);
        keep_box(build, stars, x0 - 1, 1, x0, 4, 0);
        build.doorway(stars, self.enter);
        for port in self.taken {
            if port.floor < 0 {
                build.doorway(void, port);
            } else {
                build.doorway(stars, port);
            }
        }
        # Flyers come in over the void as the player starts across; soldiers
        # of the station on the far platform.
        out = build.touch(float(x0), float(cy), 0.0, float(x0 + 3), float(cy + 3), 6.0);
        squad(build, out, [[float(self.long // 2), float(cy) - 4.0, 6.0], [float(x1) - 3.0, 4.0, 8.0], [float(x0) + 4.0, 4.0, 5.0]], ["monster_flyer", SPACE_FOES.pick(dice, self.danger), "monster_flyer"], 180.0);
        rounds(build, SPACE_FOES.pick(dice, self.danger, True), [[float(x1) + 3.0, 3.0], [float(x1) + 3.0, float(self.wide) - 3.0]], 0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2), b, SPACE_FOES.pick(dice, self.danger, True), 90.0);
        sparking(build, float(x1) - 0.2, float(cy) - 1.0, -3.0, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 2.5, 3.5, b, "ammo_cells", "q2");
    }
}

"""The dish high on its mast, a stair winding up round the mast; four
clamps released bring the dish down."""
node DishArray(Prefab) {
    has walk: int = 8,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish array";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.walk = 8;
        self.tall = 48;
        self.low = -9;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy), floor=0),
            Port(face=1, along=float(self.long // 2 + 2), floor=0),
            Port(face=3, along=float(self.long - 6), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        deck_room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(deck_room, 12);
        build.level(deck_room, self.walk);
        # The mast, the stalk and the dish on it; the stair winding up round
        # the mast to a landing under the dish.
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, 16);
        spiral(build, cx - 5, cy - 5, cx + 5, cy + 5, 0, 12, 3, 4, 0);
        dish = build.breakable(float(cx - 4), float(cy - 4), 16.0, float(cx + 4), float(cy + 4), 17.0, 400);
        # The catwalk along the near wall, up a stair.
        deck(build, 9, 1, self.long - 1, 5, self.walk);
        stair(build, 1, 1, 0, 0, self.walk, 3);
        keep_box(build, deck_room, 9, 1, 10, 4, self.walk);
        deck(build, 9, self.wide - 5, self.long - 1, self.wide - 1, self.walk);
        stair(build, 1, self.wide - 4, 0, 0, self.walk, 3);
        keep_box(build, deck_room, 9, self.wide - 4, 10, self.wide - 1, self.walk);
        hurting(build, float(cx - 1), float(cy - 1), 16.0, float(cx + 1), float(cy + 1), 20.0, 10);
        # The four clamps: two on the mast at the floor, two up the stair.
        count = build.tally(4, "The dish is loose");
        build.push(float(cx), float(cy + 2), 1.5, 1) +>:Fires:+> count;
        build.push(float(cx - 2), float(cy), 1.5, 2) +>:Fires:+> count;
        build.push(float(cx), float(cy - 2), 7.5, 3) +>:Fires:+> count;
        build.push(float(cx + 2), float(cy - 2) + 0.5, 12.5, 0) +>:Fires:+> count;
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "Four clamps hold the dish");
        fall = build.delay(1.0);
        count +>:Fires:+> fall;
        fall +>:Fires:+> dish;
        blast_chain(build, fall, [[float(cx - 3), float(cy - 3), 16.0], [float(cx + 3), float(cy + 3), 16.0], [float(cx + 3), float(cy - 3), 12.0], [float(cx - 3), float(cy + 3), 8.0], [float(cx), float(cy), 2.0]], 0.3);
        fall +>:Fires:+> build.objective("The dish is down. Disable the power core");
        boss = ["monster_boss2"] if self.danger > 0.85 else ["monster_flyer", "monster_hover"];
        squad(build, fall, [[float(cx), 3.0, 14.0], [float(cx) + 8.0, float(cy) + 6.0, 10.0]], boss, 180.0);
        opened = build.delay(2.0);
        fall +>:Fires:+> opened;
        build.doorway(deck_room, self.enter);
        for port in self.taken {
            build.doorway(deck_room, port);
            if port.floor == 0 {
                held_door(build, self, port, opened, "The way on opens once the dish is down");
            }
        }
        # Hovers over the dish, guards on the catwalk and the landing.
        squad(build, count, [[float(cx) + 4.0, float(cy) + 0.5, 12.0]], [SPACE_FOES.pick(dice, self.danger, True)], 180.0);
        rounds(build, SPACE_FOES.pick(dice, self.danger), [[11.0, 3.0], [float(self.long) - 3.0, 3.0]], self.walk);
        build.foe(float(cx) - 8.5, float(cy) + 7.5, 6, "monster_flyer", 0.0);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, 0, SPACE_FOES.pick(dice, self.danger, True), 180.0);
        beamed(build, count, 2, self.wide - 6, -8, SPACE_FOES.pick(dice, self.danger), float(cx) - 7.5, float(cy) + 0.5, 0, 0.0);
        sparking(build, float(cx + 2) + 0.2, float(cy) + 1.0, 4.0, 0, 3.0);
        sparking(build, float(cx - 2) - 0.2, float(cy) - 1.0, 9.0, 2, 4.5);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, self.walk, "ammo_rockets", "q2");
    }
}

"""The core in a tall chamber, galleries round it at two heights, bridges
to the core; four couplings shot out on its faces disable it."""
node PowerCore(Prefab) {
    has low_ring: int = 9,
        high_ring: int = 18,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Power core";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.low_ring = 9;
        self.high_ring = 18;
        self.tall = 26;
        self.low = -9;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=3, along=float(self.long - 8), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.low_ring),
            Port(face=3, along=float(self.long // 2), floor=self.high_ring)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g1 = self.low_ring;
        g2 = self.high_ring;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g1);
        build.level(hall, g2);
        # The core to the roof.
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tall);
        # The low gallery round all four walls, bridges from it to the core,
        # a plat up to it in a corner.
        deck(build, 1, 1, self.long - 1, 5, g1);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g1);
        deck(build, 1, 5, 5, self.wide - 5, g1);
        deck(build, self.long - 5, 5, self.long - 1, self.wide - 5, g1);
        deck(build, 5, cy - 1, cx - 3, cy + 2, g1);
        deck(build, cx + 3, cy - 1, self.long - 5, cy + 2, g1);
        keep_box(build, hall, 4, cy - 1, 5, cy + 2, g1);
        keep_box(build, hall, self.long - 5, cy - 1, self.long - 4, cy + 2, g1);
        lift(build, 5, 5, 8, 8, 0, g1);
        keep_box(build, hall, 5, 4, 8, 5, g1);
        # The high gallery along three walls, a plat up to it from the low.
        deck(build, 1, 1, self.long - 1, 5, g2);
        deck(build, 1, self.wide - 5, self.long - 5, self.wide - 1, g2);
        deck(build, 1, 5, 5, self.wide - 5, g2);
        lift(build, self.long - 5, self.wide - 5, self.long - 2, self.wide - 2, g1, g2);
        keep_box(build, hall, self.long - 6, self.wide - 5, self.long - 5, self.wide - 2, g2);
        hurting(build, float(cx - 4), float(cy - 4), 0.0, float(cx - 3), float(cy - 3), 3.0, 4);
        hurting(build, float(cx + 3), float(cy + 3), 0.0, float(cx + 4), float(cy + 4), 3.0, 4);
        # The four couplings on the core's faces, each shot out; all four
        # gone, the core is disabled and the station powers down.
        count = build.tally(4, "Power core disabled");
        build.push(float(cx - 3), float(cy) + 1.5, 3.0, 2, True) +>:Fires:+> count;
        build.push(float(cx + 3), float(cy) - 1.5, float(g1) + 2.0, 0, True) +>:Fires:+> count;
        build.push(float(cx) + 1.5, float(cy - 3), float(g2) + 2.0, 3, True) +>:Fires:+> count;
        build.push(float(cx) - 1.5, float(cy + 3), 13.0, 1, True) +>:Fires:+> count;
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "Shoot out the core's four couplings");
        count +>:Fires:+> build.objective("Power core disabled. Get back to the shuttle");
        last = blast_chain(build, count, [[float(cx) - 3.5, float(cy) - 3.5, 4.0], [float(cx) + 3.5, float(cy) + 3.5, 10.0], [float(cx) - 3.5, float(cy) + 3.5, 16.0], [float(cx) + 3.5, float(cy) - 3.5, 22.0]], 0.5);
        for (index, at) in enumerate([[cx - 4, cy - 1], [cx + 3, cy + 2], [cx, cy - 4], [cx - 1, cy + 3]]) {
            count +>:Fires:+> build.breakable(float(at[0]), float(at[1]), float(4 + index * 5), float(at[0] + 1), float(at[1] + 1), float(6 + index * 5), 30);
        }
        floors = build.delay(2.0);
        last +>:Fires:+> floors;
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                held_door(build, self, port, floors, "The doors are held while the core has power");
            }
        }
        squad(build, count, [[float(cx), 3.0, 14.0], [float(cx), float(self.wide) - 3.0, 14.0]], ["monster_floater", "monster_hover"], 180.0);
        beamed(build, count, 2, self.wide - 6, -8, SPACE_FOES.pick(dice, self.danger, True), float(cx) + 0.5, float(cy) - 6.5, 0, 90.0);
        # Foes round the core and on the galleries.
        rounds(build, SPACE_FOES.pick(dice, self.danger), [[3.0, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [3.0, float(self.wide) - 3.0]], g1);
        come_in = build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0);
        squad(build, come_in, [[3.0, float(self.wide) - 3.0, float(g2)], [float(self.long) - 8.0, 3.0, float(g2)]], [SPACE_FOES.pick(dice, self.danger, True), "monster_flyer"], 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) - 6.5 + float(index) * 13.0, float(cy) + 6.5, 0, SPACE_FOES.pick(dice, self.danger), 270.0);
        }
        build.foe(float(cx) + 0.5, float(cy) - 6.5, 6, "monster_flyer", 90.0);
        sparking(build, float(cx - 3) - 0.2, float(cy) - 2.0, 8.0, 2, 3.0);
        sparking(build, float(cx + 3) + 0.2, float(cy) + 2.0, 15.0, 0, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g1, "ammo_cells", "q2");
        build.supply(3.0, float(cy) + 0.5, g2, Q2_ARMOR, "q2");
    }
}

"""A ring of walkway round a pit, the key on a pod in the pit's middle: a
lift from the pit's floor rides up beside it, and in some seeds the far
wall's console draws out a bridge to it; taking the key opens the closets and
brings in the flyers."""
node ControlRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(19, 21);
        self.wide = self.hall_wide + 4;
        self.by_lift = dice.chance(0.5);
        self.tall = 16;
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
        build.level(room, -7);
        build.doorway(room, self.enter);
        # The pit, the ring of walkway left round it, the pod on its stalk in
        # the middle, a gap of three cells all round it.
        px0 = 7;
        px1 = self.long - 5;
        py0 = 4;
        py1 = side - 3;
        pit = build.room(px0, py0, -7, px1, py1, 0);
        build.level(pit, -7);
        build.solid(px0 + 3, py0 + 3, -7, px1 - 3, py1 - 3, 0);
        # The consoles on the pod, a low wall round its far half.
        build.solid(px1 - 4, py0 + 3, 0, px1 - 3, py1 - 3, 2);
        # The lift beside the pod, its top flush with the ring and the pod:
        # stepped down to from the ring, it rides up. In some seeds a console
        # on the far wall draws out a bridge straight from the near ring too.
        mx = (px0 + px1) // 2;
        lift(build, mx - 1, py0, mx + 2, py0 + 3, -7, 0);
        keep_box(build, room, mx - 1, py0 - 1, mx + 2, py0, 0);
        keep_box(build, room, mx - 1, py0 + 3, mx + 2, py0 + 4, 0);
        if self.by_lift {
            build.touch(float(px0 - 3), float(cy - 2), 0.0, float(px0 - 1), float(cy + 2), 6.0, True, "The pod's lift rides up from the pit");
        } else {
            bridge_way = build.drawn(float(px0), float(cy - 1), float(px0 + 3), float(cy + 2), 0, 8);
            keep_box(build, room, px0 - 1, cy - 1, px0, cy + 2, 0);
            keep_box(build, room, px0 + 3, cy - 1, px0 + 4, cy + 2, 0);
            console = build.push(float(self.long - 1), float(cy) + 0.5, 1.5, 2);
            console +>:Fires:+> bridge_way;
            console +>:Fires:+> build.sparks(float(self.long) - 1.2, float(cy) + 0.5, 3.0, 2);
            build.touch(float(px0 - 3), float(cy - 2), 0.0, float(px0 - 1), float(cy + 2), 6.0, True, "The pod's bridge is worked from the far wall");
        }
        # A stash in the pit's floor, the spare parts of the station.
        build.supply(float(px0) + 1.5, float(py1) - 1.5, -7, "ammo_cells", "q2");
        build.supply(float(px1) - 1.5, float(py1) - 1.5, -7, Q2_ARMOR, "q2");
        taken = key_taken(build, self.key, float(mx) + 0.5, float(cy) + 0.5, 0);
        closets(build, taken, side, 0, [3, self.long - 7], [SPACE_FOES.pick(dice, self.danger, True), SPACE_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[float(px0) + 1.5, float(py0) + 1.5, 4.0], [float(px1) - 1.5, float(py1) - 1.5, 4.0]], ["monster_flyer"], 0.0);
        beamed(build, taken, 2, 2, -8, SPACE_FOES.pick(dice, self.danger, True), 3.5, float(cy) + 0.5, 0, 0.0);
        rounds(build, SPACE_FOES.pick(dice, self.danger), [[float(px1) + 2.0, 2.5], [float(px1) + 2.0, float(side) - 2.0], [4.0, float(side) - 2.0]], 0);
        build.foe(float(px0) + 3.5, float(py1) - 1.5, -7, SPACE_FOES.pick(dice, self.danger), 0.0);
        sparking(build, float(self.long) - 1.2, float(cy) - 3.5, 2.5, 2, 3.0);
        sparking(build, float(px1) - 4.2, float(cy) + 1.0, 1.5, 2, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into the shuttle's bay, a ramp up into the cabin, the
way out in it."""
node ShuttlePort(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shuttle port" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = SPACE;
        self.district = level_district(SPACE);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
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
        build.level(bay, 4);
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Return to the shuttle");
        # The shuttle: its hull at the bay's far end, the cabin in it, the
        # ramp up to its hatch.
        sx = self.long - 12;
        build.solid(sx, middle - 4, 0, self.long - 1, middle + 4, 12);
        cabin = build.room(sx + 1, middle - 3, 4, self.long - 2, middle + 3, 10);
        build.widen(cabin, sx, middle - 2, 4, sx + 1, middle + 2, 10);
        stair(build, sx - 4, middle - 2, 0, 0, 4, 4);
        keep_box(build, bay, sx - 1, middle - 2, sx, middle + 2, 4);
        build.way_out(float(self.long) - 4.0, float(middle), 4);

        aboard = build.touch(float(sx + 1), float(middle - 3), 4.0, float(sx + 3), float(middle + 3), 9.0);
        blast_chain(build, aboard, [[float(sx) - 3.0, 2.5, 2.0], [float(sx) - 3.0, float(self.wide) - 2.5, 2.0]], 0.4);
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        squad(build, come_in, [[float(sx) - 3.0, 3.0, 6.0], [float(sx) - 3.0, float(self.wide) - 3.0, 6.0]], ["monster_flyer", SPACE_FOES.pick(dice, self.danger, True)], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, SPACE_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        hurting(build, float(self.long) - 2.0, 1.0, 0.0, float(self.long) - 1.0, float(middle - 4), 3.0, 3);
        sparking(build, float(sx) - 0.2, float(middle) + 5.0, 3.0, 2, 3.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_cells", "q2");
    }
}

"""space's stretches: [name, role]."""
glob SPACE_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["rings", "flow"],
         ["solar", "flow"],
         ["dish", "flow"],
         ["core", "hub"],
         ["rings", "hub"],
         ["control", "keyroom"],
         ["shuttle", "end"],
         ["shuttle", "gate"]
     ];

"""One of space's stretches by its name."""
def make_space(name: str, key: str) -> Prefab {
    if name == "dock" {
        return DockingBay();
    }
    if name == "rings" {
        return RingTransporter();
    }
    if name == "solar" {
        return SolarArray();
    }
    if name == "dish" {
        return DishArray();
    }
    if name == "core" {
        return PowerCore();
    }
    if name == "control" {
        return ControlRoom(key=key if key else "key_silver");
    }
    return ShuttlePort(key=key);
}
