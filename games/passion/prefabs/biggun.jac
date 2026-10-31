"""Prefabs drawn from Quake II's biggun, the Big Gun: a yard under the gun's
barrel with a laser fence across it, the laser guard's hall under a
gallery, the shell hoist, the turret hall round the gun's breech, the bay
where the key is kept, the breech itself, blown apart on a countdown.
Raised in biggun's own palette.

- `GunYard`: the start. A yard under the sky, the gun's barrel high over
  it, walked along its top up a tall lift, a bunker at the far end under
  it; a laser fence across the yard switched off by a shot switch on a
  pylon (biggun's "Lock down laser guard"). The help computer gives the
  mission; the gun fires now and then (biggun's timed blasts); guards
  appear on the bunker as the player crosses.
- `LaserGuard`: a hall crossed by laser fences, a gallery along one wall
  up a stair; the switch at the gallery's end (or shot from the floor in
  some seeds) locks the lasers down and raises the shutters on the ways on
  at the floor.
- `ShellHoist`: a shaft, a stair up to a ledge halfway, a lift on to the
  top landing, and the hoist riding all the way; the gun's charges shake
  the top as the player reaches the ledge.
- `GunTurret`: a hub. The gun's breech standing in a hall, a gallery round
  the walls up a stair or a lift, a flight up from the gallery onto the
  breech's top. The turret fires; flyers come in at the gallery.
- `GunBay`: the key room. The key on a pad at the far end whose steps rise
  out of the floor when the switch by the door is pressed; taking it opens
  the closets.
- `GunBreech`: the end. Doors (a key's, as a gate), then the breech
  chamber: the switch on its control platform starts the countdown, the
  breech blows apart charge after charge, the floor shakes and the
  escape door opens on the way out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, shelling, stash, crate_pile, squad, keep_box, plat, port_door, laser, quake }

glob BIGGUN: str = "q2:biggun";

"""biggun's foes: Strogg elite guards and gunners, flyers, gladiators
deeper in."""
glob BIGGUN_FOES: FoeMix = FoeMix(light=["monster_soldier_ss", "monster_soldier_ss", "monster_gunner"], strong=["monster_gunner"], heavy_light=["monster_gunner", "monster_soldier_ss"], heavy_strong=["monster_gladiator"], scale=0.6, heavy_scale=0.4, flying="monster_flyer");

"""The start: a yard under the gun's barrel, a laser fence across it, a
bunker at its far end."""
node GunYard(Prefab) {
    has barrel: int = 16,
        tall: int = 26,
        porch: int = 5,
        fence_x: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun yard";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(32, 36);
        self.wide = dice.between(24, 28);
        self.barrel = dice.between(14, 17);
        self.tall = self.barrel + dice.between(8, 10);
        self.porch = 5;
        self.fence_x = dice.between(self.long // 2 - 3, self.long // 2 + 2);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=self.porch), Port(face=0, along=cy, floor=self.barrel + 3), Port(face=1, along=float(self.long // 2 - 6), floor=0), Port(face=3, along=float(self.long // 2 - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        b = self.barrel;
        top = b + 3;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.porch);
        build.level(yard, top);
        # The barrel high over the yard, walked along its top.
        build.solid(6, cy - 2, b, self.long - 1, cy + 2, top);
        # The bunker at the far end under it, its steps; the lift up to the
        # barrel beside the bunker.
        bx = self.long - 7;
        build.solid(bx, 1, 0, self.long - 1, self.wide - 1, self.porch);
        stair(build, bx - self.porch, cy - 6, 0, 0, self.porch, 3);
        keep_box(build, yard, bx, cy - 6, bx + 1, cy - 3, self.porch);
        plat(build, yard, bx - 4, cy + 2, bx - 1, cy + 5, 0, top);
        stash(build, bx, cy + 6, 0, True, -1, Q2_ARMOR);
        crate_pile(build, 2, self.wide - 3, 0, 0, 2);
        open_ways(build, yard, self);
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_bullets", "q2");
        mission = build.touch(1.0, float(cy - 3), 0.0, 5.0, float(cy + 3), 8.0);
        mission +>:Fires:+> build.objective("Destroy Big Gun.");
        mission +>:Fires:+> build.objective("Eliminate all resistance.", False);
        # The laser fence across the yard and the shot switch on its pylon.
        fx = self.fence_x;
        build.solid(fx, 1, 0, fx + 1, 3, 8);
        build.solid(fx, self.wide - 3, 0, fx + 1, self.wide - 1, 8);
        beams: list[Cue] = [];
        for z in [1.2, 2.8, 4.4] {
            beams.append(laser(build, float(fx) + 0.5, 3.1, z, float(fx) + 0.5, float(self.wide) - 3.1, z));
        }
        lockdown = build.push(float(fx), 2.0, 6.0, 2, True);
        for beam in beams {
            lockdown +>:Fires:+> beam;
        }
        build.touch(float(fx - 4), 1.0, 0.0, float(fx - 3), float(self.wide - 1), 8.0, True, "Lock down laser guard.\nShoot the switch on the pylon.");
        lockdown +>:Fires:+> build.objective("Laser guard down.\nDestroy Big Gun.", False);
        # The gun fires now and then: blasts at its muzzle, the next a
        # moment later down the barrel.
        shelling(build, dice.uniform(8.0, 12.0), [[5.0, float(cy), float(b + 1)], [3.0, float(cy) - 2.0, float(b + 2)], [3.0, float(cy) + 2.0, float(b)], [8.0, float(cy), float(b + 4)], [12.0, float(cy) - 3.0, float(b + 5)], [16.0, float(cy) + 3.0, float(b + 5)], [2.0, float(cy), float(b + 6)]]);
        sparking(build, dice.uniform(2.0, 4.0), 6.0, float(cy) - 2.2, float(b) + 1.5, 3);
        sparking(build, dice.uniform(2.0, 4.0), 6.0, float(cy) + 2.2, float(b) + 1.5, 1);
        # Crossing the fence, guards appear on the bunker.
        past = build.touch(float(fx + 1), 3.0, 0.0, float(fx + 3), float(self.wide - 3), 6.0);
        squad(build, past, [[float(self.long) - 4.5, float(cy) - 4.5, float(self.porch)], [float(self.long) - 3.5, float(cy) + 4.5, float(self.porch)], [float(self.long) - 5.5, float(cy) + 0.5, float(top)]], [BIGGUN_FOES.pick(dice, self.danger, True), BIGGUN_FOES.pick(dice, self.danger), "monster_soldier_ss"], 180.0);
        charges(build, past, [[float(fx) + 6.0, 3.0, 2.0], [float(fx) + 8.0, float(self.wide) - 3.0, 2.0]], 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx + 4 + index * 3) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, BIGGUN_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(8.5, float(cy) + 0.5, top, "monster_soldier_ss", 0.0, patrol=[[8.5, float(cy) + 0.5], [float(bx) - 2.5, float(cy) + 0.5]]);
        build.foe(float(fx) + 3.5, float(cy) + 0.5, 10, BIGGUN_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.porch, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, top, "ammo_rockets", "q2");
    }
}

"""A hall crossed by laser fences, a gallery along one wall; the switch
locks the lasers down and raises the shutters on the ways on."""
node LaserGuard(Prefab) {
    has gallery: int = 9,
        tall: int = 17,
        fences: int = 3,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Laser guard";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(30, 34);
        self.wide = dice.between(17, 20);
        self.gallery = 9;
        self.tall = self.gallery + dice.between(7, 9);
        self.fences = dice.between(2, 3);
        self.shot = dice.chance(0.4);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy - 2.0, floor=0);
        self.leaves = [Port(face=0, along=cy - 2.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery), Port(face=3, along=float(self.long - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery along the high wall, its stair at the near end.
        build.solid(g + 1, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        stair(build, 1, self.wide - 4, 0, 0, g, 3);
        # An updraft from the floor onto the gallery's far end.
        build.jump_pad(float(self.long - 5), float(self.wide - 8), 0, float(self.long - 5), float(self.wide) - 2.5, g);
        keep_box(build, hall, self.long - 7, self.wide - 5, self.long - 2, self.wide - 4, g);
        # Pillars down the hall's middle, the fences between them.
        beams: list[Cue] = [];
        for index in range(self.fences) {
            fx = 10 + index * 6;
            build.solid(fx, 1, 0, fx + 1, 2, 8);
            for z in [1.2, 2.8] {
                beams.append(laser(build, float(fx) + 0.5, 2.1, z, float(fx) + 0.5, float(self.wide) - 1.1, z));
            }
        }
        open_ways(build, hall, self);
        # The switch: at the gallery's end, or high on the far wall to be
        # shot from the floor.
        if self.shot {
            lockdown = build.push(float(self.long - 1), float(cy) + 1.5, 5.0, 2, True);
        } else {
            lockdown = build.push(float(self.long) - 4.5, float(self.wide - 1), float(g) + 1.2, 3);
        }
        for beam in beams {
            lockdown +>:Fires:+> beam;
        }
        for port in self.taken {
            if port.floor == 0 {
                port_door(build, self, port, lockdown);
            }
        }
        charges(build, lockdown, [[12.0, 3.0, 4.0], [18.0, 3.0, 4.0], [24.0, 3.0, 4.0], [float(self.long) - 3.0, float(cy), 6.0]], 0.4);
        for index in range(self.fences) {
            sparking(build, dice.uniform(2.5, 4.5), float(10 + index * 6) + 0.5, 2.2, 6.0, 1);
        }
        build.touch(4.0, 1.0, 0.0, 5.0, float(self.wide - 5), 8.0, True, "Lock down laser guard.");
        up = build.touch(float(g + 1), float(self.wide - 5), float(g), float(g + 3), float(self.wide - 1), float(g + 6));
        squad(build, up, [[float(self.long) - 4.5, 3.5, 0.0], [float(self.long) - 4.5, float(cy) + 0.5, 0.0]], ["monster_soldier_ss", BIGGUN_FOES.pick(dice, self.danger, True)], 180.0);
        build.foe(float(g + 2) + 0.5, float(self.wide) - 3.0, g, "monster_soldier_ss", 0.0, patrol=[[float(g + 2) + 0.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 5.5, 3.5, 0, BIGGUN_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, 6, BIGGUN_FOES.pick(dice, self.danger, False, True), 180.0);
        sparking(build, dice.uniform(3.0, 5.0), 10.5, 2.2, 5.0, 1);
        crate_pile(build, 4, 1, 0, 0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, Q2_HEALTH, "q2");
    }
}

"""A shaft, a stair up to a ledge halfway, a lift on to the top landing,
the hoist riding all the way."""
node ShellHoist(Prefab) {
    has top: int = 22,
        hoist: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shell hoist";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.top = dice.between(20, 24);
        self.long = self.top // 2 + 16;
        self.wide = dice.between(16, 18);
        self.hoist = dice.chance(0.6);
        self.low = -1;
        self.high = self.top + 9;
        cy = float(self.wide // 2);
        m = self.top // 2;
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=self.top), Port(face=0, along=cy, floor=0), Port(face=3, along=float(m + 6), floor=m)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        h = self.top;
        m = h // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, h + 8, variant=dice.below(3));
        build.level(shaft, m);
        build.level(shaft, h);
        # The top landing across the far end, the ledge halfway along the
        # low wall, the stair up to the ledge.
        tx = self.long - 7;
        build.solid(tx, 1, h - 1, self.long - 1, self.wide - 1, h);
        build.solid(m + 2, 1, m - 1, tx, 5, m);
        stair(build, 2, 1, 0, 0, m, 3);
        # The lift from the ledge to the top, and the hoist all the way.
        plat(build, shaft, tx - 3, 5, tx, 8, m, h);
        if self.hoist {
            build.train([4.0, 4.0, 1.0], [[float(tx - 4), float(self.wide - 6), 0.0], [float(tx - 4), float(self.wide - 6), float(h - 1)]], 80.0, 3.0);
            keep_box(build, shaft, tx, self.wide - 6, tx + 1, self.wide - 2, h);
        } else {
            plat(build, shaft, tx - 3, self.wide - 5, tx, self.wide - 2, 0, h);
        }
        # A stash in the stair's side behind a panel; an updraft from the
        # floor up onto the ledge.
        stash(build, 4, 8, 0, False, 1, "item_adrenaline");
        build.jump_pad(float(m + 5), 8.0, 0, float(m + 5), 2.5, m);
        keep_box(build, shaft, m + 3, 4, m + 8, 5, m);
        open_ways(build, shaft, self);
        ledge = build.touch(float(m + 2), 1.0, float(m), float(m + 4), 5.0, float(m + 6));
        squad(build, ledge, [[float(self.long) - 3.5, float(cy) + 0.5, float(h)], [float(tx) - 6.0, float(cy) + 1.0, float(m + 3)]], [BIGGUN_FOES.pick(dice, self.danger, True), "monster_flyer"], 180.0);
        ledge +>:Fires:+> quake(build, float(tx), float(cy), float(h), 2);
        charges(build, ledge, [[float(self.long) - 2.0, 2.0, float(h + 3)], [float(self.long) - 2.0, float(self.wide) - 2.0, float(h + 4)], [float(tx) + 2.0, float(cy), float(h + 5)], [float(tx) - 3.0, float(cy) + 3.0, float(m + 5)], [4.0, float(cy) + 3.0, float(m + 4)]], 0.5);
        alarm = build.timer(dice.uniform(3.0, 5.0));
        alarm +>:Fires:+> build.sparks(float(tx) - 0.2, 3.0, float(h) - 2.0, 2);
        alarm +>:Fires:+> build.sparks(float(tx) - 0.2, float(self.wide) - 3.0, float(h) - 2.0, 2);
        build.foe(float(m + 3) + 0.5, 3.0, m, "monster_soldier_ss", 0.0, patrol=[[float(m + 3) + 0.5, 3.0], [float(tx) - 1.5, 3.0]]);
        build.foe(float(self.long // 2), float(cy) + 2.5, 0, BIGGUN_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, 3.5, h, "monster_soldier_ss", 90.0, patrol=[[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        sparking(build, dice.uniform(3.0, 5.0), 1.2, float(cy) + 2.0, float(m) + 2.0, 0);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, h, Q2_HEALTH, "q2");
        build.supply(float(tx) - 2.0, 3.0, m, "ammo_grenades", "q2");
    }
}

"""The gun's breech standing in a hall, a gallery round the walls, a
flight up from the gallery onto the breech's top."""
node GunTurret(Prefab) {
    has gallery: int = 9,
        tall: int = 26,
        hoist: bool = False,
        flights: int = 1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun turret";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(32, 36);
        self.wide = dice.between(32, 34);
        self.gallery = 9;
        self.tall = self.gallery + 6 + dice.between(9, 11);
        self.hoist = dice.chance(0.5);
        self.flights = dice.between(1, 2);
        self.low = -1;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.gallery), Port(face=1, along=cx, floor=self.gallery), Port(face=1, along=cx + 8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gallery;
        b = g + 6;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        build.level(hall, b);
        # The breech, its top six lifts over the gallery round the walls.
        build.solid(cx - 5, 11, 0, cx + 5, self.wide - 11, b);
        build.solid(1, 1, g - 1, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(1, 5, g - 1, 5, self.wide - 5, g);
        build.solid(self.long - 5, 5, g - 1, self.long - 1, self.wide - 5, g);
        # The flight from the gallery up onto the breech (and its twin from
        # the far side in some seeds).
        stair(build, cx - 1, 5, g, 1, 6, 3);
        if self.flights > 1 {
            stair(build, cx - 1, self.wide - 6, g, 3, 6, 3);
        }
        # Up to the gallery: a stair along it, and a lift or the hoist.
        stair(build, 6, 5, 0, 0, g, 3);
        keep_box(build, hall, 6 + g - 3, 4, 6 + g, 5, g);
        if self.hoist {
            build.train([3.0, 3.0, 1.0], [[float(self.long - 9), 5.0, 0.0], [float(self.long - 9), 5.0, float(g - 1)]], 70.0, 3.0);
            keep_box(build, hall, self.long - 9, 4, self.long - 6, 5, g);
        } else {
            plat(build, hall, self.long - 9, 5, self.long - 6, 8, 0, g);
        }
        stash(build, cx - 5, cy + 1, 0, True, -1, Q2_ARMOR);
        open_ways(build, hall, self);
        # The turret fires now and then; flyers come in at the gallery.
        shelling(build, dice.uniform(6.0, 9.0), [[float(cx), float(cy), float(b + 4)], [float(cx) - 3.0, float(cy) + 3.0, float(b + 6)], [float(cx) + 3.0, float(cy) - 3.0, float(b + 5)], [float(cx) - 4.0, float(cy) - 4.0, float(b + 7)], [float(cx) + 4.0, float(cy) + 4.0, float(b + 7)], [float(cx), float(cy), float(b + 8)]]);
        # An updraft from the floor onto the gallery along the high wall.
        build.jump_pad(float(cx + 8), float(self.wide - 8), 0, float(cx + 8), float(self.wide) - 2.5, g);
        keep_box(build, hall, cx + 6, self.wide - 5, cx + 11, self.wide - 4, g);
        up = build.touch(float(6 + g - 3), 1.0, float(g), float(6 + g), 5.0, float(g + 6));
        squad(build, up, [[float(cx) - 8.0, float(cy) + 0.5, float(g + 3)], [float(cx) + 8.0, float(cy) + 0.5, float(g + 3)], [float(cx) + 0.5, float(cy) + 0.5, float(b)]], ["monster_flyer", BIGGUN_FOES.pick(dice, self.danger, False, True), BIGGUN_FOES.pick(dice, self.danger, True)], 180.0);
        onto = build.touch(float(cx - 1), float(cy - 5), float(b), float(cx + 2), float(cy - 3), float(b + 6));
        charges(build, onto, [[float(cx) + 4.0, float(cy) + 4.0, float(b + 2)], [float(cx) - 4.0, float(cy) + 4.0, float(b + 2)], [float(cx) + 4.0, float(cy) - 4.0, float(b + 3)], [float(cx) - 4.0, float(cy) - 4.0, float(b + 3)]], 0.3);
        build.foe(3.0, 3.0, g, "monster_soldier_ss", 0.0, patrol=[[3.0, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [3.0, float(self.wide) - 3.0]]);
        build.foe(float(cx) - 8.5, float(cy) + 0.5, 0, "monster_gunner", 90.0, patrol=[[float(cx) - 8.5, float(cy) - 7.5], [float(cx) - 8.5, float(cy) + 7.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 8.5, float(cy - 6 + index * 6) + 0.5, 0, BIGGUN_FOES.pick(dice, self.danger), 180.0);
        }
        sparking(build, dice.uniform(3.0, 5.0), float(cx) - 5.2, float(cy) - 2.0, 3.0, 2);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, b, "ammo_rockets", "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, Q2_HEALTH, "q2");
        build.supply(3.0, float(self.wide) - 7.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key room: the key on a pad at the far end whose steps rise out of
the floor when the switch by the door is pressed."""
node GunBay(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        pad: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun bay (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(24, 27);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.pad = dice.between(4, 5);
        self.tall = dice.between(13, 15);
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
        p = self.pad;
        bay = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(bay, p);
        build.doorway(bay, self.enter);
        # The pad at the far end; its steps rise when the switch is pressed.
        px = self.long - 7;
        build.solid(px, cy - 3, 0, self.long - 1, cy + 4, p);
        lever = build.push(1.0, float(cy) + 4.5, 1.5, 0);
        lever +>:Fires:+> build.rising_steps(px - p, cy - 1, 0, 0, p, 3);
        build.touch(2.0, float(cy - 3), 0.0, 4.0, float(cy + 4), 6.0, True, "The pad's steps are raised from the switch by the door");
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, p, side, 0, [3, 10], [BIGGUN_FOES.pick(dice, self.danger, True), BIGGUN_FOES.pick(dice, self.danger)]);
        on_pad = build.touch(float(px), float(cy - 3), float(p), float(px + 2), float(cy + 4), float(p + 6));
        charges(build, on_pad, [[4.0, 3.0, 4.0], [4.0, float(side) - 3.0, 4.0], [float(px) - 4.0, 3.0, 5.0], [float(px) - 8.0, float(side) - 3.0, 5.0], [10.0, float(cy), 7.0]], 0.4);
        squad(build, on_pad, [[float(px) - 3.5, 3.5, 0.0]], ["monster_soldier_ss"], 0.0);
        heavy = "monster_tank_commander" if self.danger > 0.8 else ("monster_tank" if self.danger > 0.4 else "monster_gladiator");
        build.foe(float(px) - 8.5, float(cy) + 0.5, 0, heavy, 180.0);
        build.foe(5.5, 3.5, 0, "monster_soldier_ss", 0.0, patrol=[[5.5, 3.5], [float(px) - 3.5, 3.5]]);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(cy) - 4.5, 3.0, 2);
        crate_pile(build, 6, side - 3, 0, 0, 2);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: doors, the breech chamber, the countdown, the breech blown
apart and the escape door opening on the way out."""
node GunBreech(Prefab) {
    has key: str = "",
        tall: int = 20,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gun breech" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BIGGUN;
        self.district = level_district(BIGGUN);
        self.long = dice.between(36, 40);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(18, 22);
        self.shot = dice.chance(0.4);
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
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        build.doorway(hall, self.enter);
        ex = self.long - 9;
        chamber = build.room(wall + 1, 1, 0, ex, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, 4);
        build.widen(chamber, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # The breech in the chamber's middle, its control platform.
        bx = wall + 8;
        build.solid(bx - 3, cy - 3, 0, bx + 3, cy + 3, self.tall - 4);
        build.solid(ex - 6, self.wide - 6, 0, ex, self.wide - 1, 4);
        stair(build, ex - 6, self.wide - 10, 0, 1, 4, 3);
        # The escape room beyond the chamber's far wall, its door.
        escape = build.room(ex + 1, 1, 0, self.long - 1, self.wide - 1, 10, variant=dice.below(3));
        build.widen(escape, ex, cy - 2, 0, ex + 1, cy + 2, 8);
        door = build.opened(float(ex), float(cy - 2), 0.0, float(ex + 1), float(cy + 2), 8.0);
        build.way_out(float(self.long) - 4.0, float(cy), 0);
        if self.shot {
            control = build.push(float(bx - 3), float(cy) + 0.5, 8.0, 2, True);
        } else {
            control = build.push(float(ex - 3), float(self.wide - 1), 5.2, 3);
        }
        build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0, True, "Destroy Big Gun.\nThe breech's control starts the countdown.");
        # The countdown: the breech blows apart charge after charge, the
        # floor shakes, the escape door opens.
        points: list[list[float]] = [];
        for index in range(20) {
            side = 1.0 if index % 2 == 0 else -1.0;
            points.append([float(bx) + side * 3.4, float(cy) + float(index % 5 - 2) * 1.5, float(2 + index % 14)]);
        }
        charges(build, control, points, 0.5);
        control +>:Fires:+> quake(build, float(bx), float(cy), 4.0, 6);
        control +>:Fires:+> build.objective("Big Gun destroyed.\nGet out.");
        late = build.delay(4.0);
        control +>:Fires:+> late;
        late +>:Fires:+> door;
        squad(build, late, [[float(ex) - 3.5, 3.5, 0.0], [float(ex) - 3.5, float(self.wide) - 3.5, 0.0]], [BIGGUN_FOES.pick(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, BIGGUN_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(bx) + 6.5, float(cy) + 0.5, 0, BIGGUN_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(bx) - 6.5, 3.5, 0, "monster_soldier_ss", 0.0, patrol=[[float(bx) - 6.5, 3.5], [float(bx) + 6.5, 3.5]]);
        build.foe(float(bx) + 0.5, float(cy) + 0.5, self.tall - 4, BIGGUN_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""biggun's stretches: [name, role]."""
glob BIGGUN_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["lasers", "flow"],
         ["hoist", "flow"],
         ["turret", "hub"],
         ["hoist", "hub"],
         ["bay", "keyroom"],
         ["breech", "end"],
         ["breech", "gate"]
     ];

"""One of biggun's stretches by its name."""
def make_biggun(name: str, key: str) -> Prefab {
    if name == "yard" {
        return GunYard();
    }
    if name == "lasers" {
        return LaserGuard();
    }
    if name == "hoist" {
        return ShellHoist();
    }
    if name == "turret" {
        return GunTurret();
    }
    if name == "bay" {
        return GunBay(key=key if key else "key_silver");
    }
    return GunBreech(key=key);
}
