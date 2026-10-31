"""Prefabs drawn from Quake II's mine4, the Lower Mines: the deepest
workings, unstable and caving in. A landing high over a flooded cavern; a
gallery half under water with a timber walk over its planks; a drift whose
floor has fallen into the drift under it; an ore crusher's hall of
slamming presses over a conveyor; a cavern of lava with an ore cart over
it and a gallery round it; the key in an ore vault; the cage up to the way
out. Raised in mine4's own palette.

- `LowerLanding`: the start. A landing high over a cavern's flooded floor,
  a stair down the wall and a lift cage beside it; the help computer's
  warning ("Unstable conditions ahead"); floaters come as the player gets
  down, a guard walks the floor; a panel in a rock pillar under the
  landing breaks open on a stash (the secret); fallen rocks break when
  shot.
- `FloodedGallery`: a gallery flooded along its length, a walk of planks
  on piers over the water broken twice where it is swum; rocks come down
  as the player wades in and something swims at the gaps.
- `CaveIn`: a drift whose floor has fallen through into the drift under
  it: walking in shakes the ground and brings the roof down in blasts;
  down the rubble into the lower drift and back up through the hole on an
  updraft (or a cage); the lower drift goes on under it all; floaters come
  up out of it.
- `OreCrusher`: a hall of presses slamming down into a conveyor pit, ore
  carts riding along it, a catwalk along the wall over it all; guards come
  as the player walks in, a gunner walks the catwalk.
- `LavaCavern`: a cavern over lava, a conveyor's causeway raised across it,
  an ore cart riding across beside it, a gallery along the wall over the
  floor; floaters come over the lava as the player crosses, one is sent
  onto the gallery (a hub).
- `OreVault`: the key in an ore vault behind a door a button opens up a
  stair; taking it opens the closets.
- `LiftCage`: the end. A door (a key's, as a gate), a shaft, a lift cage up
  to the way out on a ledge high over a sump; rocks come down as the cage
  rises."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, stalactites, key_ambush, gate_into, lift }
import from .q2floors_parts { sunken, stepped_bed }
import from .minefact { slab, hurt, burning, sparking, stash, charges, cart, crusher, quake }

glob MINE4: str = "q2:mine4";

"""mine4's foes: gunners and floaters, a tank deeper in."""
glob MINE4_FOES: FoeMix = FoeMix(light=["monster_gunner", "monster_floater", "monster_soldier"], strong=["monster_floater"], heavy_light=["monster_gunner", "monster_floater"], heavy_strong=["monster_tank"], scale=0.7, heavy_scale=0.3);

"""Fallen rocks: a lump of rock `size` cells square and two lifts high at
(x, y) on lift `z` that breaks apart when shot."""
def rock_fall(build: Raising, x: int, y: int, z: int, size: int) -> Cue {
    return build.breakable(float(x), float(y), float(z), float(x + size), float(y + size), float(z + 2), 40);
}

"""The start: a landing high over a flooded cavern, a stair down the wall
and a lift cage beside it."""
node LowerLanding(Prefab) {
    has drop: int = 10,
        landing: int = 10,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lower landing";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        self.drop = dice.between(12, 15);
        self.landing = dice.between(10, 12);
        self.tall = dice.between(11, 13);
        self.low = -self.drop - 4;
        self.high = self.tall + 16;
        lx = self.landing;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-self.drop),
            Port(face=1, along=float(dice.between(lx + 6, self.long - 5)), floor=-self.drop),
            Port(face=3, along=float(dice.between(3, lx - 3)), floor=0),
            Port(face=1, along=float(dice.between(3, lx - 3)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.drop;
        lx = self.landing;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 0);
        build.level(cave, low);
        # The landing over the cavern's floor; a stair down the south wall, a
        # lift cage by the north wall.
        slab(build, 1, 1, lx, self.wide - 1, 0, 2);
        stair(build, lx + self.drop - 1, 1, low, 2, self.drop, 3);
        lift(build, lx, self.wide - 5, lx + 3, self.wide - 2, low, 0);
        for y in range(self.wide - 5, self.wide - 2) {
            build.keep(cave, lx - 1, y, 0);
        }
        for y in range(1, 4) {
            build.keep(cave, lx - 1, y, 0);
        }
        # The flooded floor beyond, steps out of it on both sides.
        build.pool(lx + 1, 5, low - 3, self.long - 4, self.wide - 5, low, 2, False, True, True);
        stepped_bed(build, lx + 3, 5, self.long - 4, self.wide - 5, low - 3, 5);
        # The floor under the landing a step down; a rock pillar on it, a
        # stash behind a panel in it.
        sunken(build, cave, 1, 1, lx, self.wide - 1, low);
        build.solid(2, 2, low - 1, 5, 5, -2);
        stash(build, 2, 2, low, 0, Q2_ARMOR);
        stalactites(build, dice, lx, 3, self.long - 3, self.wide - 3, self.tall, dice.between(5, 8));
        rock_fall(build, self.long - 4, 2, low, 2);
        rock_fall(build, lx - 3, middle + 3, 0, 2);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(middle - 3), 0.0, 5.0, float(middle + 3), 6.0) +>:Fires:+> build.objective("Unstable conditions ahead. Proceed with caution.");
        sparking(build, float(lx) - 0.5, float(self.wide) - 1.1, 3.0, 3, 4.0);
        # Floaters come as the player gets down; a guard walks the floor.
        down = build.touch(float(lx), 1.0, float(low), float(lx + 4), float(self.wide - 1), float(low + 5));
        floaters = build.waiting();
        down +>:Fires:+> floaters;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 4) + 0.5, float(middle) + 0.5, low + 4, "monster_floater", 180.0, waits=floaters);
        }
        floor_y = float(self.wide) - 3.5;
        build.foe(float(lx) + 2.5, floor_y, low, "monster_gunner", 0.0, patrol=[[float(lx) + 2.5, floor_y], [float(self.long) - 2.5, floor_y], [float(self.long) - 2.5, 3.5], [float(lx) + 5.5, 3.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * 6.0, low, MINE4_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(lx + self.drop) + 1.5, 2.5, low, Q2_HEALTH, "q2");
    }
}

"""A gallery flooded along its length, a walk of planks over the water on
piers, broken twice where it is swum."""
node FloodedGallery(Prefab) {
    has deep: int = 5,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded gallery";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(30, 34);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(15, 18);
        self.low = -self.deep - 1;
        self.high = self.tall + 16;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gallery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 4;
        x1 = self.long - 4;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2);
        stepped_bed(build, x0 + 2, 1, x1, self.wide - 1, -self.deep, 6);
        gaps = [x0 + (x1 - x0) // 3, x0 + 2 * (x1 - x0) // 3];
        x = x0;
        for gap in gaps + [x1] {
            build.solid(x, middle - 1, -1, gap, middle + 2, 0);
            x = gap + 3;
        }
        for gap in gaps {
            stair(build, gap + 3 - self.deep, middle + 2, -self.deep, 0, self.deep, 2);
        }
        for px in range(x0 + 2, x1 - 1, 4) {
            build.solid(px, middle - 1, -self.deep, px + 1, middle, -1);
        }
        stair(build, x1 - self.deep, 1, -self.deep, 0, self.deep, 2);
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        # Wading in brings rocks down from the roof; something swims.
        wade = build.touch(float(x0), 1.0, float(-self.deep), float(x0 + 4), float(self.wide - 4), 0.0);
        charges(build, wade, [[float(gaps[0]) + 1.5, float(middle) - 3.0, float(self.tall - 2)], [float(gaps[1]) + 1.5, float(middle) + 1.0, float(self.tall - 2)]], 0.5);
        swimmers = build.waiting();
        wade +>:Fires:+> swimmers;
        for index in range(dice.between(1, 2)) {
            build.foe(float(gaps[index]) + 1.5, float(middle) - 2.5, -self.deep + 1, "monster_flipper", 0.0, waits=swimmers);
        }
        build.foe(2.5, 2.5, 0, "monster_gunner", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "monster_gunner", 270.0, patrol=[[float(self.long) - 2.5, float(self.wide) - 2.5], [float(self.long) - 2.5, 4.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1 - 4 - index * 6) + 0.5, float(middle) + 0.5, 0, MINE4_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        rock_fall(build, 1, self.wide - 3, 0, 2);
        build.supply(2.5, 4.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, 0, "ammo_bullets", "q2");
    }
}

"""A drift whose floor has fallen through into the drift under it."""
node CaveIn(Prefab) {
    has under: int = 10,
        by_lift: bool = False,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cave-in";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.under = dice.between(12, 14);
        self.long = dice.between(self.under + 26, self.under + 30);
        self.wide = dice.between(14, 16);
        self.by_lift = dice.chance(0.4);
        # A ceiling nine lifts and more over the floor the updraft lands on.
        self.tall = dice.between(10, 11);
        self.low = -self.under - 4;
        self.high = self.tall + 16;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy), floor=-self.under),
            Port(face=1, along=float(dice.between(self.under + 16, self.long - 4)), floor=0)
        ];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(dice.between(self.under + 16, self.long - 4)), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.under;
        cy = self.wide // 2;
        hx = 10;
        east = hx + self.under + 4;
        drift = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(drift, 0);
        build.level(drift, low);
        # The ground at the near end; the floor beyond it over the lower
        # drift; the hole where it fell through, the rubble down it.
        build.solid(1, 1, low, 8, self.wide - 1, 0);
        slab(build, 8, 1, self.long - 1, self.wide - 1, 0, 1);
        build.widen(drift, hx, 3, -1, east, self.wide - 3, 0);
        stair(build, hx + self.under - 1, 3, low, 2, self.under, self.wide - 6);
        # What is left of the floor beside the hole heaved up a step.
        build.solid(hx, 1, 0, east, 3, 1);
        build.solid(hx, self.wide - 3, 0, east, self.wide - 1, 1);
        # The lower drift flooded beyond the hole.
        build.pool(east + 1, 4, low - 3, self.long - 5, self.wide - 4, low, 2);
        # Back up on the far side: an updraft three cells back from the
        # floor's edge, or a cage.
        if self.by_lift {
            lift(build, east - 4, cy - 2, east, cy + 2, low, 0);
        } else {
            build.jump_pad(float(east - 3) + 0.5, float(cy) + 0.5, low, float(east) + 1.5, float(cy) + 0.5, 0);
            sparking(build, float(east - 3) + 0.5, float(cy) + 0.5, float(low) + 0.5, 1, 2.5);
        }
        for y in range(cy - 2, cy + 3) {
            build.keep(drift, east, y, 0);
        }
        # A stash in the ground's face, under the near end.
        stash(build, 5, 3, low, 0, "ammo_grenades");
        build.doorway(drift, self.enter);
        for port in self.taken {
            build.doorway(drift, port);
        }
        # Walking in shakes the ground and brings the roof down in blasts;
        # floaters come up out of the lower drift.
        walk_in = build.touch(2.0, 1.0, 0.0, 7.0, float(self.wide - 1), 6.0, True, "Unstable conditions ahead. Proceed with caution.");
        walk_in +>:Fires:+> quake(build, float(hx + 6), float(cy), 4.0, 5);
        charges(build, walk_in, [[float(hx) + 3.5, float(cy) - 3.0, float(self.tall - 2)], [float(hx) + 8.5, float(cy) + 2.0, float(self.tall - 2)], [float(east) - 1.5, float(cy), float(self.tall - 2)]], 0.6);
        lower = build.waiting();
        walk_in +>:Fires:+> lower;
        for index in range(dice.between(2, 3)) {
            build.foe(float(east + 2 + index * 3) + 0.5, float(cy) + 0.5, low + 3, "monster_floater", 180.0, waits=lower);
        }
        under_y = float(self.wide) - 3.5;
        build.foe(float(east) + 1.5, under_y, low, "monster_gunner", 0.0, patrol=[[float(east) + 1.5, under_y], [float(self.long) - 3.5, under_y], [float(self.long) - 3.5, 3.5], [float(east) + 1.5, 3.5]]);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, 0, MINE4_FOES.pick(dice, self.danger, True), 180.0);
        rock_fall(build, self.long - 4, 1, low, 2);
        rock_fall(build, self.long - 4, cy - 1, 0, 2);
        build.supply(float(east) + 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(east) + 3.5, 2.5, low, "ammo_bullets", "q2");
    }
}

"""A hall of presses slamming down into a conveyor pit, ore carts along
it, a catwalk along the wall over it all."""
node OreCrusher(Prefab) {
    has deck: int = 6,
        presses: int = 3,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ore crusher";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.deck = 6;
        self.presses = dice.between(2, 3);
        self.tall = dice.between(15, 17);
        self.low = -5;
        self.high = self.tall + 16;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(dice.between(3, cy - 4)), floor=0);
        self.leaves = [Port(face=0, along=float(dice.between(3, cy - 4)), floor=0)];
        if dice.chance(0.5) {
            self.leaves.append(Port(face=0, along=float(self.wide - 3), floor=self.deck));
        }
        if dice.chance(0.4) {
            self.leaves.append(Port(face=3, along=float(dice.between(6, self.long - 6)), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.deck);
        sunken(build, hall, 8, 1, self.long - 8, cy - 2, 0);
        # The conveyor pit down the middle, a step out at each end, an ore
        # cart riding along it.
        build.widen(hall, 4, cy - 1, -2, self.long - 4, cy + 2, 0);
        build.solid(4, cy - 1, -2, 5, cy + 2, -1);
        build.solid(self.long - 5, cy - 1, -2, self.long - 4, cy + 2, -1);
        cart(build, [[5.0, float(cy - 1), -2.0], [float(self.long - 8), float(cy - 1), -2.0]], 50.0, 1.5);
        # The presses slamming down into it.
        for index in range(self.presses) {
            px = 8 + index * (self.long - 16) // max(1, self.presses - 1);
            crusher(build, float(px), float(cy - 1), [3.0, 3.0, 3.0], -1.0, 5.0, 120.0, 1.5, 20);
            hurt(build, float(px), float(cy - 1), -2.0, float(px + 3), float(cy + 2), 0.0, 10);
        }
        # A channel flooded along the north wall under the catwalk.
        build.pool(6, cy + 2, -3, self.long - 6, self.wide - 1, 0, 2);
        # The catwalk along the north wall, a stair up at each end.
        slab(build, 1, self.wide - 4, self.long - 1, self.wide - 1, self.deck, 1);
        stair(build, 1, self.wide - 4 - self.deck, 0, 1, self.deck, 3);
        stair(build, self.long - 4, self.wide - 4 - self.deck, 0, 1, self.deck, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(cy - 1), 6.0);
        hall_guard = build.waiting();
        come_in +>:Fires:+> hall_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 4 - index * 5) + 0.5, 3.5, 0, MINE4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=hall_guard);
        }
        walk_y = float(self.wide) - 2.5;
        build.foe(5.5, walk_y, self.deck, "monster_gunner", 0.0, patrol=[[5.5, walk_y], [float(self.long) - 2.5, walk_y]]);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 3.5, 3, "monster_floater", 180.0);
        timer = build.timer(4.0);
        timer +>:Fires:+> build.sparks(8.5, float(cy) - 1.2, 4.0, 3);
        rock_fall(build, 1, self.wide - 3, 0, 2);
        rock_fall(build, 5, cy - 4, 0, 2);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, walk_y, self.deck, "ammo_bullets", "q2");
    }
}

"""A cavern over lava, a conveyor's causeway raised across it, an ore cart
riding across beside it, a gallery along the wall over the floor."""
node LavaCavern(Prefab) {
    has walk: int = 3,
        upper: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava cavern";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.walk = dice.between(3, 4);
        self.upper = dice.between(10, 11);
        self.tall = self.upper + dice.between(13, 17);
        self.low = -13;
        self.high = self.tall + 16;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.walk),
            Port(face=1, along=float(self.long // 2), floor=self.upper),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.walk);
        build.level(cave, self.upper);
        burning(build, 6, 6, -4, self.long - 6, self.wide - 6, 0, 4);
        sunken(build, cave, 7, 1, self.long - 1, 5, 0);
        build.solid(6, middle - 1, -4, self.long - 1, middle + 2, self.walk);
        stair(build, 6 - self.walk, middle - 1, 0, 0, self.walk, 3);
        for x in range(9, self.long - 6, 5) {
            build.solid(x, middle - 2, -4, x + 1, middle - 1, self.walk + 5);
            build.solid(x, middle + 2, -4, x + 1, middle + 3, self.walk + 5);
            build.solid(x, middle - 1, self.walk + 4, x + 1, middle + 2, self.walk + 5);
        }
        # An ore cart riding across the lava south of the causeway.
        cart(build, [[6.0, float(middle - 6), -1.0], [float(self.long - 9), float(middle - 6), -1.0]], 60.0, 2.5);
        for y in range(middle - 6, middle - 3) {
            build.keep(cave, 5, y, 0);
            build.keep(cave, self.long - 6, y, 0);
        }
        # The gallery along the north wall over the floor's margin, a stair
        # up to it at its west end.
        slab(build, 2 + self.upper, self.wide - 4, self.long - 1, self.wide - 1, self.upper, 1);
        stair(build, 2, self.wide - 4, 0, 0, self.upper, 3);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 5, self.tall, dice.between(6, 10));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        # Floaters come over the lava as the player crosses; one is sent
        # onto the gallery when the player reaches it.
        crossing = build.touch(float(self.long // 2 - 1), float(middle - 1), float(self.walk), float(self.long // 2 + 1), float(middle + 2), float(self.walk + 4));
        over_lava = build.waiting();
        crossing +>:Fires:+> over_lava;
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 5) + 0.5, float(middle) + 5.5, 4, "monster_floater", 270.0, waits=over_lava);
        }
        up_top = build.touch(float(self.upper), float(self.wide - 4), float(self.upper), float(self.upper + 3), float(self.wide - 1), float(self.upper + 6));
        up_top +>:Fires:+> build.summon(self.long - 5, 1, -12, MINE4_FOES.pick(dice, self.danger, True), float(self.long) - 4.5, float(self.wide) - 2.5, self.upper, 180.0);
        ring = [[3.5, 3.5], [float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 5.5], [3.5, float(self.wide) - 5.5]];
        build.foe(3.5, 3.5, 0, "monster_gunner", 0.0, patrol=ring);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 4.5 + float(index) * 5.0, 0, MINE4_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 2.5, float(middle) + 0.5, self.walk, MINE4_FOES.pick(dice, self.danger, True), 180.0);
        rock_fall(build, 1, 1, 0, 2);
        rock_fall(build, self.long - 3, self.wide - 7, 0, 2);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, float(self.wide) - 6.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an ore vault behind a door a button opens up a stair; taking
it opens the closets."""
node OreVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        vault: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ore vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.vault = dice.between(3, 4);
        self.tall = dice.between(11, 13);
        self.low = -1;
        self.high = self.tall + 16;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(cave, self.vault);
        build.doorway(cave, self.enter);
        vx = self.long - 7;
        build.solid(vx, 1, 0, self.long - 1, side, self.vault);
        stair(build, vx - self.vault, cy - 2, 0, 0, self.vault, 4);
        build.solid(vx + 1, 1, self.vault, vx + 2, cy - 2, self.tall);
        build.solid(vx + 1, cy + 2, self.vault, vx + 2, side, self.tall);
        build.solid(vx + 1, cy - 2, self.vault + 7, vx + 2, cy + 2, self.tall);
        vault_door = build.opened(float(vx + 1), float(cy - 2), float(self.vault), float(vx + 2), float(cy + 2), float(self.vault + 7));
        build.push(float(vx + 1), float(cy) - 4.0, float(self.vault) + 1.3, 2) +>:Fires:+> vault_door;
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.vault, side, 0, [2, vx - 5], [MINE4_FOES.pick(dice, self.danger, True), MINE4_FOES.pick(dice, self.danger)]);
        vault_guard = build.waiting();
        vault_door +>:Fires:+> vault_guard;
        build.foe(float(self.long) - 2.5, float(cy) - 3.0, self.vault, "monster_floater", 180.0, waits=vault_guard);
        build.foe(4.5, 2.5, 0, "monster_gunner", 0.0, patrol=[[4.5, 2.5], [float(vx) - 4.5, 2.5]]);
        rock_fall(build, 1, side - 3, 0, 2);
        sparking(build, float(vx) + 0.9, float(cy) - 4.0, float(self.vault) + 3.0, 2, 4.0);
        build.supply(2.5, 4.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a shaft, a lift cage up to the way out on a ledge high
over a sump."""
node LiftCage(Prefab) {
    has key: str = "",
        upper: int = 12,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lift cage" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE4;
        self.district = level_district(MINE4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.upper = dice.between(15, 18);
        self.tall = self.upper + 9;
        self.low = -4;
        self.high = self.tall + 16;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, self.upper);
        ux = self.long - 7;
        sunken(build, room, wall + 1, 1, ux - 4, self.wide - 1, 0);
        slab(build, ux, 1, self.long - 1, self.wide - 1, self.upper, 1);
        lift(build, ux - 3, middle - 1, ux, middle + 2, 0, self.upper);
        for y in range(middle - 2, middle + 3) {
            build.keep(room, ux, y, self.upper);
        }
        build.way_out(float(self.long) - 3.5, float(middle), self.upper);
        # A sump of slime under the ledge.
        burning(build, ux + 1, 2, -3, self.long - 2, self.wide - 2, 0, 3, 8);
        # Rocks come down as the cage rises; guards wake on the floor.
        board = build.touch(float(ux - 3), float(middle - 1), 0.0, float(ux), float(middle + 2), 4.0);
        board +>:Fires:+> quake(build, float(ux), float(middle), 6.0, 3);
        charges(build, board, [[float(ux) - 5.5, 3.0, float(self.tall - 2)], [float(ux) - 2.5, float(self.wide) - 3.0, float(self.tall - 2)]], 0.5);
        ledge = build.waiting();
        board +>:Fires:+> ledge;
        build.foe(float(self.long) - 2.5, 2.5, self.upper, MINE4_FOES.pick(dice, self.danger, True), 180.0, waits=ledge);
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        floor_guard = build.waiting();
        come_in +>:Fires:+> floor_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(ux) - 4.5, 2.5 + float(index) * (float(self.wide) - 5.0), 0, MINE4_FOES.pick(dice, self.danger), 180.0, waits=floor_guard);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, MINE4_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        rock_fall(build, wall + 2, self.wide - 4, -1, 2);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine4's stretches: [name, role]."""
glob MINE4_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["gallery", "flow"],
         ["cavein", "flow"],
         ["crusher", "flow"],
         ["lava", "hub"],
         ["crusher", "hub"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mine4's stretches by its name."""
def make_mine4(name: str, key: str) -> Prefab {
    if name == "landing" {
        return LowerLanding();
    }
    if name == "gallery" {
        return FloodedGallery();
    }
    if name == "cavein" {
        return CaveIn();
    }
    if name == "crusher" {
        return OreCrusher();
    }
    if name == "lava" {
        return LavaCavern();
    }
    if name == "vault" {
        return OreVault(key=key if key else "key_silver");
    }
    return LiftCage(key=key);
}
