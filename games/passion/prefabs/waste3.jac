"""Prefabs drawn from Quake II's waste3, Pumping Station Two: a sump under a
gallery and a bridge, a canal lock between a high deck and a low basin, a
blower hall whose updraft throws the player up to its duct, the reactor
catwalks over a pit of slime ridden between on lifts, the blue key's
store, the blast doors to the reactor core. Raised in waste3's own
palette.

- `SumpGallery`: the start. A sump of water (or slime) in the middle of a
  room, a gallery up a stair along two walls, a bridge across from it.
  The help computer gives the mission (waste3's "Kill all resistance");
  soldiers patrol the floor, the gallery and the bridge; technicians come
  in as the player climbs; a stash behind a panel in a block.
- `LockChamber`: a canal lock. A deck high at the near end with the upper
  canal in it, a basin below with the lower canal between towpaths, a
  pier out over the basin, a stair and a lift down, a barge riding the
  lower canal. Drums go off and guards come as the player reaches the
  towpath; a panel in the lock's wall hides a stash.
- `BlowerHall`: a hall in three tiers, a gantry halfway up and the duct
  at the top; a blower in the floor throws the player up to the duct (or
  a lift carries them), a stair up to the gantry.
- `ReactorCatwalks`: a hub. Catwalks across a pit of slime, a second
  catwalk over the first, freight platforms riding between them, a stair
  up from the floor round the pit. Soldiers patrol both levels.
- `BlueKeyStore`: the key room. A store with a loft along two walls, the
  key in the loft's corner; taking it opens the closets; a stash.
- `CoreDoors`: the end. Blast doors one after another (each a key's, as a
  gate) down a corridor into the reactor core, the way out on its dais;
  charges go off at each door."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, stash, crate_pile, squad, keep_box, plat, hurting }

glob WASTE3: str = "q2:waste3";

"""waste3's foes: soldiers and gunners, floaters and berserkers, a tank
deeper in."""
glob WASTE3_FOES: FoeMix = FoeMix(light=["monster_soldier", "monster_soldier", "monster_gunner"], strong=["monster_berserk"], heavy_light=["monster_gunner", "monster_berserk"], heavy_strong=["monster_tank"], scale=0.6, heavy_scale=0.3, flying="monster_floater");

"""The start: a sump in the middle of a room, a gallery along two walls, a
bridge across."""
node SumpGallery(Prefab) {
    has gallery: int = 9,
        tall: int = 18,
        bridge_x: int = 14,
        foul: bool = False,
        climb_lift: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sump gallery";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 28);
        self.gallery = 9;
        self.tall = self.gallery + dice.between(8, 10);
        self.bridge_x = dice.between(10, self.long - 12);
        self.foul = dice.chance(0.3);
        self.climb_lift = dice.chance(0.4);
        self.low = -8;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.gallery), Port(face=1, along=float(self.bridge_x) + 2.0, floor=self.gallery), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        g = self.gallery;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, g);
        # The sump in the middle.
        build.pool(8, 7, -6, self.long - 8, self.wide - 7, 0, 3 if self.foul else 2, False, True, True);
        if self.foul {
            hurting(build, 8.0, 7.0, -6.0, float(self.long - 8), float(self.wide - 7), -1.0, 8);
        }
        # The gallery along the low wall and the far wall, its stair or
        # lift, the bridge across from it to the high wall.
        build.solid(2 + g, 1, g - 1, self.long - 1, 5, g);
        build.solid(self.long - 6, 5, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(self.bridge_x, 5, g - 1, self.bridge_x + 4, self.wide - 1, g);
        if self.climb_lift {
            plat(build, room, 8, 1, 11, 4, 0, g);
            build.solid(2 + g, 1, g - 1, 11, 5, g);
        } else {
            stair(build, 2, 1, 0, 0, g, 3);
        }
        # A block in the near high corner, a stash behind a panel in it.
        build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 6);
        stash(build, self.wide - 6, 2, 0, False, -1, Q2_ARMOR);
        # A store under the far gallery, its shutter raised by the switch
        # beside it on what waits inside.
        build.solid(self.long - 5, self.wide - 7, 0, self.long - 1, self.wide - 1, g - 1);
        build.room(self.long - 5, self.wide - 6, 0, self.long - 2, self.wide - 2, 5);
        shutter = build.opened(float(self.long - 5), float(self.wide - 6), 0.0, float(self.long - 4), float(self.wide - 2), 5.0);
        lever = build.push(float(self.long) - 3.0, float(self.wide - 7), 1.5, 3);
        lever +>:Fires:+> shutter;
        squad(build, lever, [[float(self.long) - 2.5, float(self.wide) - 4.5, 0.0]], [WASTE3_FOES.pick(dice, self.danger, True)], 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_rockets", "q2");
        open_ways(build, room, self);
        build.start(3.0, float(cy) + 0.5, 0, 0.0);
        build.supply(3.0, float(cy) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(cy - 3), 0.0, 6.0, float(cy + 3), 8.0) +>:Fires:+> build.objective("Proceed to reactor core.\nKill all resistance.");
        up = build.touch(float(g), 1.0, float(g), float(g + 3), 5.0, float(g + 6));
        squad(build, up, [[float(self.long // 2), float(cy) + 0.5, 5.0], [float(self.long) - 3.5, float(self.wide) - 3.5, float(g)]], ["monster_floater", WASTE3_FOES.pick(dice, self.danger)], 180.0);
        build.foe(4.5, 6.5, 0, "monster_soldier", 0.0, patrol=[[4.5, 6.5], [4.5, float(self.wide) - 8.0]]);
        build.foe(8.5, float(self.wide) - 4.0, 0, "monster_soldier", 0.0, patrol=[[8.5, float(self.wide) - 4.0], [float(self.long) - 8.5, float(self.wide) - 4.0]]);
        build.foe(float(2 + g) + 1.5, 3.0, g, "monster_soldier", 0.0, patrol=[[float(2 + g) + 1.5, 3.0], [float(self.long) - 3.5, 3.0], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        build.foe(float(self.bridge_x) + 2.0, 6.5, g, "monster_gunner", 90.0, patrol=[[float(self.bridge_x) + 2.0, 6.5], [float(self.bridge_x) + 2.0, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 5.5, float(cy) + 0.5, 0, WASTE3_FOES.pick(dice, self.danger), 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(self.long) - 1.2, 3.0, float(g) + 2.0, 2);
        build.supply(float(self.long) - 3.0, 3.0, g, Q2_HEALTH, "q2");
    }
}

"""A canal lock: a deck high at the near end with the upper canal in it,
the basin below with the lower canal between towpaths, a pier out over
the basin."""
node LockChamber(Prefab) {
    has lock_x: int = 12,
        tall: int = 14,
        barge: bool = True,
        low_bridge: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lock chamber";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(32, 36);
        self.wide = dice.between(18, 22);
        self.lock_x = dice.between(11, 14);
        self.tall = dice.between(12, 14);
        self.barge = dice.chance(0.6);
        self.low_bridge = not self.barge or dice.chance(0.4);
        self.low = -10;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=3.0, floor=0), Port(face=0, along=float(self.wide - 4), floor=-6), Port(face=1, along=float(self.lock_x // 2 + 1), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        lx = self.lock_x;
        chamber = build.room(1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, 0);
        build.level(chamber, -6);
        # The deck at the near end, the upper canal in it held back by the
        # lock, a footbridge over it on the lock.
        build.solid(1, 1, -6, lx, self.wide - 1, 0);
        build.pool(4, cy - 3, -3, lx, cy + 3, 0, 2, False, True, True);
        build.solid(lx - 3, cy - 3, -1, lx, cy + 3, 0);
        # The lower canal between the towpaths, the barge on it or a low
        # bridge over it.
        build.pool(lx, cy - 3, -9, self.long - 1, cy + 3, -6, 2, False, True, True);
        if self.barge {
            build.train([3.0, 3.0, 1.0], [[float(lx + 3), float(cy - 1), -7.0], [float(self.long - 5), float(cy - 1), -7.0]], 45.0, 3.0);
        }
        if self.low_bridge {
            bx = self.long - 8;
            build.solid(bx, cy - 3, -7, bx + 3, cy + 3, -6);
            keep_box(build, chamber, bx, cy - 4, bx + 3, cy + 4, -6);
        }
        # The pier along the low wall out over the basin, a stair and a
        # lift down to the towpaths.
        build.solid(lx, 1, -1, self.long - 1, 5, 0);
        keep_box(build, chamber, self.long - 10, 4, self.long - 7, 5, 0);
        stair(build, lx + 5, self.wide - 4, -6, 2, 6, 3);
        # A panel in the lock's wall hides a stash.
        stash(build, lx, cy + 4, -6, True, 1, "item_adrenaline");
        open_ways(build, chamber, self);
        down = build.touch(float(lx + 1), float(cy + 3), -6.0, float(lx + 3), float(self.wide - 1), 0.0);
        charges(build, down, [[float(self.long) - 6.0, float(cy) + 1.0, -8.0], [float(self.long) - 12.0, float(cy) - 1.0, -8.0]], 0.4);
        squad(build, down, [[float(self.long) - 3.5, float(self.wide) - 3.5, -6.0], [float(self.long) - 3.5, 3.5, 0.0]], [WASTE3_FOES.pick(dice, self.danger, True), WASTE3_FOES.pick(dice, self.danger)], 180.0);
        pier = build.touch(float(lx), 1.0, 0.0, float(lx + 2), 5.0, 6.0, True, "The pier runs out over the lower canal");
        squad(build, pier, [[float(self.long) - 4.5, 3.0, 0.0]], ["monster_soldier"], 180.0);
        build.foe(3.5, 3.0, 0, "monster_soldier", 0.0, patrol=[[3.5, 3.0], [float(lx) - 2.5, 3.0], [float(lx) - 2.5, float(self.wide) - 3.0]]);
        build.foe(float(lx + 6) + 0.5, float(self.wide) - 3.0, -6, "monster_gunner", 0.0, patrol=[[float(lx + 6) + 0.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.foe(float(lx + 4) + 0.5, 3.0, 0, "monster_soldier", 0.0, patrol=[[float(lx + 4) + 0.5, 3.0], [float(self.long) - 4.5, 3.0]]);
        build.foe(float(self.long) - 6.5, float(cy) - 5.0, -6, WASTE3_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2), float(cy) + 0.5, 0, WASTE3_FOES.pick(dice, self.danger, False, True), 180.0);
        sparking(build, dice.uniform(4.0, 6.0), float(lx) + 0.2, float(cy) - 5.0, -4.0, 0);
        build.supply(float(lx) - 2.0, 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 5.0, -6, "ammo_bullets", "q2");
    }
}

"""A hall in three tiers: a gantry halfway up, the duct at the top, a
blower in the floor throwing the player up to the duct."""
node BlowerHall(Prefab) {
    has duct: int = 11,
        tall: int = 20,
        blower: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blower hall";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(24, 28);
        self.wide = dice.between(18, 20);
        self.duct = dice.between(11, 13);
        self.tall = self.duct + dice.between(8, 9);
        self.blower = dice.chance(0.65);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.duct), Port(face=1, along=float(self.long - 4), floor=self.duct), Port(face=3, along=float(self.long // 2 - 2), floor=self.duct // 2)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        d = self.duct;
        m = d // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, m);
        build.level(hall, d);
        # The duct across the far end, the gantry along the low wall
        # halfway up, a stair to the gantry.
        dx = self.long - 8;
        build.solid(dx, 1, d - 1, self.long - 1, self.wide - 1, d);
        build.solid(2 + m, 1, m - 1, dx - 1, 5, m);
        stair(build, 2, 1, 0, 0, m, 3);
        # Up to the duct: a lift from the gantry's end, and the blower.
        plat(build, hall, dx - 3, 1, dx, 4, m, d);
        if self.blower {
            build.jump_pad(float(dx) - 3.0, float(cy) + 1.5, 0, float(dx) + 3.0, float(cy) + 1.5, d);
            keep_box(build, hall, dx, cy - 1, dx + 1, cy + 4, d);
            build.touch(float(dx) - 8.0, float(cy - 1), 0.0, float(dx) - 7.0, float(cy + 4), 6.0, True, "The blower's draught lifts a body to the duct");
        } else {
            plat(build, hall, dx - 3, self.wide - 5, dx, self.wide - 2, 0, d);
        }
        # Crates on the floor that break.
        crate_pile(build, 8, self.wide - 3, 0, 0, 2);
        open_ways(build, hall, self);
        mid = build.touch(float(2 + m), 1.0, float(m), float(4 + m), 5.0, float(m + 6));
        squad(build, mid, [[float(self.long) - 4.5, float(cy) + 0.5, float(d)], [float(dx) - 4.0, 3.0, float(m)]], [WASTE3_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        top = build.touch(float(dx), 1.0, float(d), float(dx + 2), float(self.wide - 1), float(d + 6));
        squad(build, top, [[float(self.long // 2), float(cy) + 0.5, float(d - 2)]], [WASTE3_FOES.pick(dice, self.danger, False, True)], 180.0);
        build.foe(float(3 + m) + 0.5, 3.0, m, "monster_soldier", 0.0, patrol=[[float(3 + m) + 0.5, 3.0], [float(dx) - 4.5, 3.0]]);
        build.foe(4.5, float(cy) + 3.5, 0, "monster_soldier", 0.0, patrol=[[4.5, float(cy) + 3.5], [float(dx) - 5.5, float(cy) + 3.5]]);
        build.foe(float(self.long) - 3.5, 3.5, d, "monster_gunner", 90.0, patrol=[[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        sparking(build, dice.uniform(3.0, 5.0), float(dx) - 0.2, float(cy) - 4.0, float(d) - 3.0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, d, Q2_HEALTH, "q2");
        build.supply(float(dx) - 3.0, float(cy) + 4.5, 0, "ammo_cells", "q2");
    }
}

"""Catwalks across a pit of slime, a second over the first, freight
platforms riding between them."""
node ReactorCatwalks(Prefab) {
    has upper: int = 9,
        tall: int = 18,
        freights: int = 2;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor catwalks";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(32, 36);
        self.wide = dice.between(28, 32);
        self.upper = dice.between(9, 10);
        self.tall = self.upper + dice.between(8, 10);
        self.freights = dice.between(1, 2);
        self.low = -11;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.upper), Port(face=1, along=cx, floor=0), Port(face=3, along=cx + 6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        u = self.upper;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The pit, slime far down in it.
        build.widen(hall, 5, 5, -7, self.long - 5, self.wide - 5, 0);
        build.pool(5, 5, -10, self.long - 5, self.wide - 5, -7, 3, True, False);
        hurting(build, 5.0, 5.0, -10.0, float(cx), float(self.wide - 5), -7.0, 30);
        hurting(build, float(cx), 5.0, -10.0, float(self.long - 5), float(self.wide - 5), -7.0, 30);
        # The cross of catwalks over the pit, and the catwalk over the one
        # along it, up a stair from the floor.
        build.solid(5, cy - 1, -1, self.long - 5, cy + 2, 0);
        build.solid(cx - 1, 5, -1, cx + 2, self.wide - 5, 0);
        build.solid(1, cy - 1, u - 1, self.long - 1, cy + 2, u);
        stair(build, 1, cy + 1 + u, 0, 3, u, 3);
        # Freight platforms beside the catwalks, riding between them.
        spots = [cx - 6, cx + 3][:self.freights];
        for x in spots {
            build.train([3.0, 3.0, 1.0], [[float(x), float(cy + 2), -1.0], [float(x), float(cy + 2), float(u - 1)]], 55.0, 3.0);
            keep_box(build, hall, x, cy + 1, x + 3, cy + 2, 0);
            keep_box(build, hall, x, cy + 1, x + 3, cy + 2, u);
        }
        # A block in the far corner, a stash behind a panel in it.
        build.solid(self.long - 5, self.wide - 5, 0, self.long - 1, self.wide - 1, 6);
        stash(build, self.long - 5, self.wide - 4, 0, True, -1, Q2_ARMOR);
        open_ways(build, hall, self);
        middle = build.touch(float(cx - 1), float(cy - 1), 0.0, float(cx + 2), float(cy + 2), 6.0);
        squad(build, middle, [[float(cx) + 6.5, float(cy) + 0.5, 4.0], [float(cx) - 6.5, float(cy) + 0.5, 4.0]], ["monster_floater", WASTE3_FOES.pick(dice, self.danger, False, True)], 180.0);
        up = build.touch(1.0, float(cy - 1), float(u), 4.0, float(cy + 2), float(u + 6));
        squad(build, up, [[float(self.long) - 3.5, float(cy) + 0.5, float(u)]], [WASTE3_FOES.pick(dice, self.danger, True)], 180.0);
        charges(build, up, [[float(cx), float(cy) + 5.0, -6.0], [float(cx) + 5.0, float(cy) - 5.0, -6.0]], 0.5);
        far_up = build.touch(float(self.long - 5), float(cy - 1), float(u), float(self.long - 3), float(cy + 2), float(u + 6));
        charges(build, far_up, [[float(self.long) - 8.0, float(cy) + 6.0, -6.0]], 0.3);
        squad(build, far_up, [[3.5, float(cy) + 0.5, float(u)]], ["monster_gunner"], 0.0);
        build.foe(6.5, float(cy) + 0.5, 0, "monster_soldier", 0.0, patrol=[[6.5, float(cy) + 0.5], [float(self.long) - 6.5, float(cy) + 0.5]]);
        build.foe(float(self.long) - 4.5, float(cy) + 0.5, u, "monster_gunner", 180.0, patrol=[[float(self.long) - 4.5, float(cy) + 0.5], [5.5, float(cy) + 0.5]]);
        build.foe(3.0, 3.0, 0, "monster_soldier", 0.0, patrol=[[3.0, 3.0], [float(self.long) - 3.0, 3.0]]);
        build.foe(float(cx) + 0.5, float(self.wide) - 6.5, 0, WASTE3_FOES.pick(dice, self.danger), 270.0);
        sparking(build, dice.uniform(3.0, 5.0), 1.2, float(cy) + 3.0, float(u) + 2.0, 0);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, u, "ammo_rockets", "q2");
    }
}

"""The key room: a store with a loft along two walls, the key in the
loft's corner."""
node BlueKeyStore(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        loft: int = 6,
        stairs: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key store (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.long = dice.between(22, 25);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.loft = dice.between(6, 7);
        self.stairs = dice.chance(0.6);
        self.low = -1;
        self.high = self.loft + 9;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        f = self.loft;
        store = build.room(1, 1, 0, self.long - 1, side, f + 8, variant=dice.below(3));
        build.level(store, f);
        build.doorway(store, self.enter);
        # The loft along the far wall and the low wall.
        build.solid(self.long - 6, 1, f - 1, self.long - 1, side, f);
        build.solid(8, 1, f - 1, self.long - 6, 5, f);
        if self.stairs {
            stair(build, 8 - f, 1, 0, 0, f, 3);
        } else {
            plat(build, store, 5, 1, 8, 4, 0, f);
        }
        # The loft's gate at the stair's head, raised by the switch below.
        gate = build.opened(10.0, 1.0, float(f), 11.0, 5.0, float(f + 5));
        build.push(1.0, 6.5, 1.5, 0) +>:Fires:+> gate;
        build.touch(2.0, 1.0, 0.0, 4.0, 5.0, 6.0, True, "The loft's gate is raised from the switch by the stair");
        # Crates under the loft, a block with a stash.
        build.solid(10, 6, 0, 14, 10, 6);
        stash(build, 10, 7, 0, True, -1, "item_adrenaline");
        crate_pile(build, self.long - 9, side - 3, 0, 2, 2);
        key_ambush(build, self.key, float(self.long) - 3.0, 3.0, f, side, 0, [3, 9], [WASTE3_FOES.pick(dice, self.danger, True), WASTE3_FOES.pick(dice, self.danger)]);
        up = build.touch(8.0, 1.0, float(f), 10.0, 5.0, float(f + 6));
        squad(build, up, [[float(self.long) - 3.5, float(side) - 3.5, float(f)], [5.5, float(side) - 4.5, 0.0]], [WASTE3_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        build.foe(float(self.long) - 9.5, float(cy) + 2.5, 0, "monster_soldier", 180.0, patrol=[[float(self.long) - 9.5, float(cy) + 2.5], [4.5, float(cy) + 2.5]]);
        build.foe(12.5, 3.0, f, "monster_soldier", 0.0, patrol=[[12.5, 3.0], [float(self.long) - 3.5, 3.0], [float(self.long) - 3.5, float(side) - 3.0]]);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(cy), float(f) + 2.0, 2);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: blast doors one after another down a corridor into the reactor
core, the way out on its dais."""
node CoreDoors(Prefab) {
    has key: str = "",
        tall: int = 18,
        doors: int = 2,
        lift_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Core doors" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE3;
        self.district = level_district(WASTE3);
        self.doors = 3;
        self.long = 12 + self.doors * 6 + dice.between(14, 17);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(16, 19);
        self.lift_up = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, 8, self.wide - 1, 10, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The corridor of blast doors, one every six cells.
        end_x = 8 + self.doors * 6;
        corridor = build.room(8, cy - 3, 0, end_x, cy + 3, 9, variant=dice.below(3));
        for index in range(self.doors) {
            dx = 8 + index * 6;
            if self.key {
                key_doors(build, float(dx), float(cy - 3), float(cy + 3), self.key);
            } else {
                approach = build.touch(float(dx - 2), float(cy - 3), 0.0, float(dx), float(cy + 3), 6.0);
                approach +>:Fires:+> build.opened(float(dx), float(cy - 3), 0.0, float(dx + 1), float(cy + 3), 8.0);
            }
            through = build.touch(float(dx + 1), float(cy - 3), 0.0, float(dx + 3), float(cy + 3), 6.0);
            charges(build, through, [[float(dx) + 4.0, float(cy) - 2.5, 6.0], [float(dx) + 4.0, float(cy) + 2.5, 6.0]], 0.3);
        }
        # The core: a hall, the way out on the dais at its end.
        core = build.room(end_x, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(core, 5);
        build.widen(core, end_x - 1, cy - 3, 0, end_x, cy + 3, 9);
        build.solid(self.long - 8, cy - 5, 0, self.long - 2, cy + 5, 5);
        if self.lift_up {
            plat(build, core, self.long - 11, cy - 1, self.long - 8, cy + 2, 0, 5);
        } else {
            stair(build, self.long - 13, cy - 1, 0, 0, 5, 3);
            keep_box(build, core, self.long - 8, cy - 1, self.long - 7, cy + 2, 5);
        }
        # The core's columns, sparking.
        for side in [-1, 1] {
            build.solid(end_x + 4, cy + side * 6 - 1, 0, end_x + 6, cy + side * 6 + 1, self.tall);
            sparking(build, dice.uniform(3.0, 5.0), float(end_x + 5), float(cy + side * 6) - float(side) * 1.2, 4.0, 1 if side < 0 else 3);
        }
        build.way_out(float(self.long) - 4.0, float(cy), 5);
        into = build.touch(float(end_x), 1.0, 0.0, float(end_x + 2), float(self.wide - 1), 6.0);
        squad(build, into, [[float(self.long) - 4.5, float(cy) + 3.5, 5.0], [float(self.long) - 10.5, 3.5, 0.0], [float(self.long) - 10.5, float(self.wide) - 3.5, 0.0]], [WASTE3_FOES.pick(dice, self.danger, True), WASTE3_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(4.5, 2.5 + float(index) * 4.0, 0, WASTE3_FOES.pick(dice, self.danger, index == 0), 0.0);
        }
        build.foe(float(end_x) + 3.5, float(cy) + 0.5, 0, "monster_soldier", 0.0, patrol=[[float(end_x) + 3.5, 3.5], [float(end_x) + 3.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long) - 6.5, float(cy) + 0.5, 9, WASTE3_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste3's stretches: [name, role]."""
glob WASTE3_STRETCHES: list[list[str]] = [
         ["sump", "start"],
         ["lock", "flow"],
         ["blower", "flow"],
         ["catwalks", "hub"],
         ["lock", "hub"],
         ["store", "keyroom"],
         ["core", "end"],
         ["core", "gate"]
     ];

"""One of waste3's stretches by its name."""
def make_waste3(name: str, key: str) -> Prefab {
    if name == "sump" {
        return SumpGallery();
    }
    if name == "lock" {
        return LockChamber();
    }
    if name == "blower" {
        return BlowerHall();
    }
    if name == "catwalks" {
        return ReactorCatwalks();
    }
    if name == "store" {
        return BlueKeyStore(key=key if key else "key_silver");
    }
    return CoreDoors(key=key);
}
