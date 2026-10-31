"""Prefabs drawn from Quake II's hangar1, the Outer Hangar: an apron under
the sky by a deep basin, a flooded sump swum through under its dividing
wall, the hangar bay round a docked ship, a laser tunnel under a vent
duct, the control room over its tank, the bay door closed to leave.
Raised in hangar1's own palette.

- `HangarApron`: the start. An apron under the sky, a deep basin along one
  side where flippers patrol under a gantry, landing pads, the bay's face
  at the far end with a balcony up a stair. The help computer gives the
  mission (hangar1's two objectives); guards come out on the balcony as
  the player crosses; infantry patrol; a stash in the stair's side.
- `FloodedSump`: a sump flooded deep under the open sky, a wall across it
  that a body swims under, a shelf in its bed, flippers in both halves; a
  catwalk over the water through a hatch high in the wall, up a lift.
- `BayHangar`: a hub. A ship docked on struts in a great bay, a gantry
  round the walls up a tall lift and a stair, offices under it, bridges from
  it onto the ship's back, a crane riding the roof.
- `LaserTunnel`: a tunnel whose lasers switch on and off on a timer, its
  floor in sections a sill apart, a vent duct over it reached by an updraft
  or a lift.
- `HangarControl`: the key room. A control deck over a tank of water, the
  key on the deck up a stair; taking it opens the closets.
- `BayDoor`: the end. A door (a key's, as a gate), the bay, its great door
  open on the sky: the switch on the control platform closes it (hangar1's
  "Close main hangar bay door"), the blasts go off, the floor shakes and
  the way out opens."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .q2_flood { office }
import from .plant_parts { key_doors, open_ways, charges, sparking, stash, crate_pile, squad, keep_box, plat, laser, quake, port_door, hurting }

glob HANGAR1: str = "q2:hangar1";

"""hangar1's foes: infantry and gunners, hovers, a tank deeper in; flippers
in the water."""
glob HANGAR1_FOES: FoeMix = FoeMix(light=["monster_infantry", "monster_infantry", "monster_gunner"], strong=["monster_gunner"], heavy_light=["monster_infantry", "monster_gunner"], heavy_strong=["monster_tank"], scale=0.6, heavy_scale=0.3, flying="monster_flyer", flying_other="monster_hover", flying_odds=0.7);

"""A door that closes when its cue fires: Quake II's START_OPEN func_door
drawn shut in the cells x0..x1, y0..y1, z0..z1, waiting slid aside into
the rock the way `direction` goes (0 +x ... 3 -y)."""
def closing_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) -> Cue {
    fields = {"classname": "func_door", "spawnflags": "1", "angle": str(build.facing(direction)), "speed": "50", "wait": "-1", "lip": "8"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, kit_of(build.district).door);
    span_x = x1 - x0 if direction % 2 == 0 else 0.0;
    span_y = y1 - y0 if direction % 2 == 1 else 0.0;
    sign = 1.0 if direction < 2 else -1.0;
    build.rock_round(x0 + sign * span_x, y0 + sign * span_y, z0, x1 + sign * span_x, y1 + sign * span_y, z1);
    build.casting.doors += 1;
    return build.cue([fields], "door");
}

"""The start: an apron under the sky by a deep basin, the bay's face at its
far end."""
node HangarApron(Prefab) {
    has balcony: int = 9,
        tall: int = 22,
        pads: int = 2;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar apron";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(34, 38);
        self.wide = dice.between(26, 30);
        self.balcony = 9;
        self.tall = dice.between(48, 52);
        self.pads = dice.between(1, 2);
        self.low = -9;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy + 2.0, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=float(self.wide - 6), floor=self.balcony), Port(face=1, along=float(self.long // 2 - 6), floor=0), Port(face=3, along=float(self.long - 8), floor=6)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        b = self.balcony;
        apron = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(apron, b);
        build.level(apron, 6);
        # The deep basin along the low wall, a gantry over it, a lift up.
        build.pool(6, 1, -8, self.long - 6, 10, 0, 2);
        build.solid(6, 1, 5, self.long - 6, 5, 6);
        plat(build, apron, self.long - 6, 1, self.long - 3, 4, 0, 6);
        # The bay's face: a balcony along the far wall, its stair.
        build.solid(self.long - 6, 10, b - 1, self.long - 1, self.wide - 1, b);
        stair(build, self.long - 15, self.wide - 4, 0, 0, b, 3);
        stash(build, self.wide - 4, self.long - 10, 0, False, -1, Q2_ARMOR);
        # Landing pads on the apron, steps up each.
        build.solid(10, 12, 0, 16, 18, 3);
        stair(build, 7, 13, 0, 0, 3, 3);
        if self.pads > 1 {
            build.solid(self.long - 23, self.wide - 9, 0, self.long - 17, self.wide - 3, 3);
            stair(build, self.long - 15, self.wide - 8, 0, 2, 3, 3);
        }
        crate_pile(build, self.long - 10, 11, 0, 0, 2);
        # A control bridge high across the apron from the balcony, a lift
        # at its near end.
        build.solid(6, cy + 2, b - 1, self.long - 6, cy + 6, b);
        plat(build, apron, 3, cy + 2, 6, cy + 5, 0, b);
        # A store under the balcony, its shutter raised by the switch beside
        # it on what waits inside.
        build.solid(self.long - 6, self.wide - 7, 0, self.long - 1, self.wide - 1, b - 1);
        build.room(self.long - 6, self.wide - 6, 0, self.long - 2, self.wide - 2, 5);
        shutter = build.opened(float(self.long - 6), float(self.wide - 6), 0.0, float(self.long - 5), float(self.wide - 2), 5.0);
        lever = build.push(float(self.long) - 3.0, float(self.wide - 7), 1.5, 3);
        lever +>:Fires:+> shutter;
        squad(build, lever, [[float(self.long) - 3.0, float(self.wide) - 4.0, 0.0]], [HANGAR1_FOES.pick(dice, self.danger, True)], 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_cells", "q2");
        open_ways(build, apron, self);
        build.start(2.5, float(cy) - 1.5, 0, 0.0);
        build.supply(2.5, float(cy) - 3.5, 0, "ammo_bullets", "q2");
        build.foe(10.5, float(cy) + 4.0, b, "monster_infantry", 0.0, patrol=[[10.5, float(cy) + 4.0], [float(self.long) - 8.5, float(cy) + 4.0]]);
        mission = build.touch(1.0, 10.0, 0.0, 5.0, float(self.wide - 1), 8.0);
        mission +>:Fires:+> build.objective("Close main hangar bay door.\nDestroy blackhole generator.");
        mission +>:Fires:+> build.objective("Find a way into the main\nhangar bay installation.", False);
        crossing = build.touch(float(self.long // 2 - 1), 10.0, 0.0, float(self.long // 2 + 1), float(self.wide - 1), 6.0);
        squad(build, crossing, [[float(self.long) - 3.5, float(self.wide) - 4.5, float(b)], [float(self.long) - 3.5, 13.5, float(b)]], [HANGAR1_FOES.pick(dice, self.danger), "monster_infantry"], 180.0);
        charges(build, crossing, [[float(self.long) - 2.0, 6.0, 10.0], [float(self.long) - 8.0, 3.0, 12.0]], 0.3);
        for index in range(2) {
            fx = 9.5 + float(index) * 10.0;
            build.foe(fx, 4.5, -7, "monster_flipper", 0.0, patrol=[[fx, 4.5], [fx + 8.0, 4.5], [fx + 8.0, 7.5], [fx, 7.5]]);
        }
        build.foe(4.5, 10.5, 0, "monster_infantry", 0.0, patrol=[[4.5, 10.5], [float(self.long) - 8.5, 10.5]]);
        build.foe(8.5, 3.0, 6, "monster_infantry", 0.0, patrol=[[8.5, 3.0], [float(self.long) - 7.5, 3.0]]);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 3.5, 8, HANGAR1_FOES.pick(dice, self.danger, False, True), 180.0, patrol=[[float(self.long // 2) + 0.5, float(cy) + 3.5], [8.5, float(cy) + 3.5]]);
        build.foe(float(self.long) - 9.5, float(cy) + 3.5, 0, HANGAR1_FOES.pick(dice, self.danger, True), 180.0);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, 12.0, 4.0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, b, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 8.0, 3.0, 6, "ammo_rockets", "q2");
    }
}

"""A sump flooded deep, a wall across it that a body swims under."""
node FloodedSump(Prefab) {
    has tall: int = 14,
        wall_x: int = 14,
        catwalk: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded sump";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(34, 38);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(36, 40);
        self.wall_x = dice.between(13, 15);
        self.catwalk = True;
        self.low = -11;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wx = self.wall_x;
        sump = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(sump, -10);
        # The flood, the far ledge and the steps up to it from the water.
        build.pool(7, 1, -10, self.long - 7, self.wide - 1, 0, 2);
        build.solid(self.long - 7, 1, -10, self.long - 1, self.wide - 1, 0);
        stair(build, self.long - 17, 1, -10, 0, 10, 3);
        # The wall across the sump, the way under it four lifts high.
        build.solid(wx, 1, -6, wx + 2, self.wide - 1, self.tall);
        # A shelf of the bed in the far half, clear of the way under the wall.
        build.solid(wx + 6, 5, -10, wx + 10, self.wide - 1, -7);
        if self.catwalk {
            # A catwalk along the high wall over the water, through a hatch
            # high in the wall, out over the far ledge to drop from.
            plat(build, sump, 3, self.wide - 5, 6, self.wide - 2, 0, 6);
            build.solid(6, self.wide - 5, 5, self.long - 6, self.wide - 1, 6);
            build.widen(sump, wx, self.wide - 5, 6, wx + 2, self.wide - 1, 12);
            keep_box(build, sump, self.long - 7, self.wide - 5, self.long - 6, self.wide - 1, 6);
        }
        # A fan's intake in the far half's floor, that hurts who swims to it.
        hurting(build, float(self.long - 10), float(self.wide - 3), -10.0, float(self.long - 7), float(self.wide - 1), -8.0, 10);
        sparking(build, dice.uniform(2.0, 3.0), float(self.long) - 8.5, float(self.wide) - 1.2, -9.0, 3);
        open_ways(build, sump, self);
        # Swimming in brings the far half's flippers out.
        dive = build.touch(8.0, 1.0, -10.0, 12.0, float(self.wide - 1), -2.0);
        squad(build, dive, [[float(wx) + 4.0, float(cy) - 2.5, -9.0], [float(wx) + 8.0, float(cy) + 2.5, -6.0]], ["monster_flipper"], 180.0);
        landed = build.touch(float(self.long - 7), 4.0, 0.0, float(self.long - 5), float(self.wide - 1), 6.0);
        landed +>:Fires:+> build.summon(self.long - 5, cy - 1, -9, HANGAR1_FOES.pick(dice, self.danger, True), float(self.long) - 3.5, float(cy) + 0.5, 0, 180.0);
        squad(build, landed, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 3.5, float(self.wide) - 3.5, 0.0]], [HANGAR1_FOES.pick(dice, self.danger), HANGAR1_FOES.pick(dice, self.danger, True)], 180.0);
        build.foe(9.5, float(cy) + 0.5, -9, "monster_flipper", 0.0, patrol=[[9.5, float(cy) + 0.5], [float(wx) - 1.5, float(cy) + 0.5], [float(wx) - 1.5, 3.5], [9.5, 3.5]]);
        build.foe(float(wx) + 4.5, float(cy) + 0.5, -6, "monster_flipper", 0.0, patrol=[[float(wx) + 4.5, float(cy) + 0.5], [float(self.long) - 9.5, float(cy) + 0.5]]);
        build.foe(3.5, 3.5, 0, "monster_infantry", 90.0, patrol=[[3.5, 3.5], [3.5, float(self.wide) - 6.5]]);
        build.foe(float(self.long // 2), float(cy) + 0.5, 4, HANGAR1_FOES.pick(dice, self.danger, False, True), 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(wx) - 0.2, float(cy) - 3.0, 3.0, 2);
        build.supply(3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, 0, Q2_ARMOR, "q2");
    }
}

"""A ship docked on struts in a great bay, a gantry round the walls,
bridges onto the ship's back."""
node BayHangar(Prefab) {
    has gantry: int = 14,
        tall: int = 26,
        both: bool = True,
        climb_stair: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar bay";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(36, 40);
        self.wide = dice.between(32, 36);
        self.gantry = 14;
        self.tall = self.gantry + dice.between(18, 22);
        self.both = dice.chance(0.6);
        self.climb_stair = dice.chance(0.6);
        self.low = -1;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.gantry), Port(face=1, along=cx, floor=self.gantry), Port(face=3, along=cx + 10.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gantry;
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(bay, g);
        build.level(bay, g - 1);
        # The ship on its struts, its back a lift under the gantry.
        build.solid(cx - 8, cy - 5, 5, cx + 8, cy + 5, g - 1);
        for sx in [cx - 7, cx + 5] {
            for sy in [cy - 4, cy + 2] {
                build.solid(sx, sy, 0, sx + 2, sy + 2, 5);
            }
        }
        # The gantry round the walls, bridges from it onto the ship's back.
        build.solid(1, 1, g - 1, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(1, 5, g - 1, 5, self.wide - 5, g);
        build.solid(self.long - 5, 5, g - 1, self.long - 1, self.wide - 5, g);
        build.solid(5, cy - 1, g - 2, cx - 8, cy + 2, g - 1);
        keep_box(build, bay, 5, cy - 1, 6, cy + 2, g - 1);
        if self.both {
            build.solid(cx + 8, cy - 1, g - 2, self.long - 5, cy + 2, g - 1);
            keep_box(build, bay, self.long - 6, cy - 1, self.long - 5, cy + 2, g - 1);
        }
        # Up to the gantry: a tall lift in a corner, a stair in some seeds.
        plat(build, bay, 5, 5, 8, 8, 0, g);
        if self.climb_stair {
            stair(build, 6, self.wide - 5 - g, 0, 1, g, 4);
        }
        # Offices under the gantry along both long walls, breaking up the
        # floor under it; stores and a crew's lockers in them.
        for at in [10, cx]{
            office(build, at, 1, at + 7, 7, 0, 8, 1, at + 2);
        }
        office(build, cx + 12, self.wide - 7, cx + 18, self.wide - 1, 0, 8, 3, cx + 13);
        office(build, 12, self.wide - 7, 19, self.wide - 1, 0, 8, 3, 14);
        build.supply(float(cx) + 3.5, 3.5, 1, "ammo_bullets", "q2");
        build.supply(15.5, float(self.wide) - 3.5, 1, "ammo_grenades", "q2");
        build.foe(13.5, 3.5, 1, "monster_infantry", 90.0);
        # The crane riding the roof.
        build.train([4.0, 4.0, 1.0], [[6.0, float(cy - 2), float(self.tall - 3)], [float(self.long - 10), float(cy - 2), float(self.tall - 3)]], 60.0, 3.0);
        open_ways(build, bay, self);
        up = build.touch(4.0, 4.0, float(g), 9.0, 9.0, float(g + 6));
        squad(build, up, [[float(self.long) - 3.0, float(cy) + 4.5, float(g)], [float(cx) + 0.5, float(cy) + 3.5, float(g - 1)]], [HANGAR1_FOES.pick(dice, self.danger), HANGAR1_FOES.pick(dice, self.danger, True)], 180.0);
        onto = build.touch(float(cx - 8), float(cy - 1), float(g - 1), float(cx - 6), float(cy + 2), float(g + 5));
        onto +>:Fires:+> build.summon(cx - 2, cy - 1, 6, HANGAR1_FOES.pick(dice, self.danger, True), float(cx) + 4.5, float(cy) + 0.5, g - 1, 180.0);
        # The bay's floor doors open from the controls on the gantry.
        controls = build.push(float(self.long - 1), float(cy) + 6.5, float(g) + 1.2, 2);
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0, True, "The bay's floor doors open from the gantry");
        for port in self.taken {
            if port.floor == 0 {
                port_door(build, self, port, controls);
            }
        }
        controls +>:Fires:+> build.sparks(float(self.long) - 1.2, float(cy) + 4.5, float(g) + 3.0, 2);
        charges(build, onto, [[float(cx) + 4.0, float(cy) + 6.0, float(g + 2)], [float(cx) - 4.0, float(cy) - 6.0, float(g + 2)]], 0.4);
        build.foe(3.0, 3.0, g, "monster_infantry", 0.0, patrol=[[3.0, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [3.0, float(self.wide) - 3.0]]);
        build.foe(float(cx) - 10.5, float(cy) + 0.5, 0, "monster_infantry", 0.0, patrol=[[float(cx) - 10.5, float(cy) - 7.5], [float(cx) + 10.5, float(cy) - 7.5]]);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 0, HANGAR1_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(cx) + 0.5, float(cy) + 9.5, 8, "monster_hover", 180.0, patrol=[[float(cx) - 6.5, float(cy) + 9.5], [float(cx) + 6.5, float(cy) + 9.5]]);
        sparking(build, dice.uniform(3.0, 5.0), float(cx) - 8.2, float(cy) + 3.0, 7.0, 2);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, g - 1, "ammo_rockets", "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, Q2_HEALTH, "q2");
    }
}

"""A tunnel whose lasers switch on and off on a timer, a vent duct over
it."""
node LaserTunnel(Prefab) {
    has duct: int = 9,
        tall: int = 16,
        draught: bool = True,
        fences: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Laser tunnel";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(14, 16);
        self.duct = 9;
        self.tall = self.duct + dice.between(6, 8);
        self.draught = dice.chance(0.6);
        self.fences = dice.between(2, 3);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=4.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.duct), Port(face=1, along=float(self.long // 2 + 2), floor=self.duct), Port(face=3, along=float(self.long - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.duct;
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tunnel, d);
        # The vent duct along the high wall, a lift up at its near end, and
        # the draught that throws a body up into it.
        build.solid(6, self.wide - 5, d - 1, self.long - 1, self.wide - 1, d);
        plat(build, tunnel, 2, self.wide - 5, 5, self.wide - 2, 0, d);
        build.solid(5, self.wide - 5, d - 1, 6, self.wide - 1, d);
        if self.draught {
            build.jump_pad(9.0, float(self.wide - 8), 0, 9.0, float(self.wide - 3), d);
            keep_box(build, tunnel, 7, self.wide - 5, 12, self.wide - 4, d);
        }
        # The tunnel's floor in sections, a sill a lift high to every other
        # one, each fence standing where they meet.
        build.solid(14, 1, 0, 19, self.wide - 1, 1);
        build.solid(20, 1, 0, 25, self.wide - 1, 1);
        # The lasers across the tunnel, switched on and off by the timer.
        clock = build.timer(dice.uniform(2.0, 3.0));
        for index in range(self.fences) {
            fx = 13 + index * 6;
            for z in [1.2, 2.8] {
                clock +>:Fires:+> laser(build, float(fx) + 0.5, 1.1, z + 1.0, float(fx) + 0.5, float(self.wide) - 1.1, z + 1.0, index % 2 == 0);
            }
            sparking(build, dice.uniform(3.0, 5.0), float(fx) + 0.5, 1.2, 4.0, 1);
        }
        open_ways(build, tunnel, self);
        build.touch(4.0, 1.0, 0.0, 6.0, float(self.wide - 5), 6.0, True, "The lasers cycle: time the run, or take the duct");
        far_end = build.touch(float(self.long - 6), 1.0, 0.0, float(self.long - 4), float(self.wide - 5), 6.0);
        squad(build, far_end, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 6.5, float(self.wide) - 3.0, float(d)]], ["monster_infantry", HANGAR1_FOES.pick(dice, self.danger, True)], 180.0);
        in_duct = build.touch(6.0, float(self.wide - 5), float(d), 8.0, float(self.wide - 1), float(d + 6));
        squad(build, in_duct, [[float(self.long // 2), float(self.wide) - 3.0, float(d)]], [HANGAR1_FOES.pick(dice, self.danger)], 180.0);
        build.foe(3.5, 8.5, 0, "monster_infantry", 0.0, patrol=[[3.5, 8.5], [float(self.long) - 4.5, 8.5]]);
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, d, "monster_gunner", 180.0, patrol=[[float(self.long) - 4.5, float(self.wide) - 3.0], [9.5, float(self.wide) - 3.0]]);
        crate_pile(build, 5, 1, 0, 0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, d, Q2_HEALTH, "q2");
    }
}

"""The key room: a control deck over a tank of water, the key on the
deck."""
node HangarControl(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        deck: int = 6,
        climb_lift: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(22, 25);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.deck = dice.between(6, 7);
        self.climb_lift = dice.chance(0.4);
        self.low = -5;
        self.high = self.deck + 9;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        d = self.deck;
        room = build.room(1, 1, 0, self.long - 1, side, d + 8, variant=dice.below(3));
        build.level(room, d);
        build.doorway(room, self.enter);
        # The tank of water in the floor, the deck over the far end.
        build.pool(6, cy - 3, -4, self.long - 9, cy + 4, 0, 2, False, True, True);
        dx = self.long - 8;
        build.solid(dx, 1, d - 1, self.long - 1, side, d);
        if self.climb_lift {
            plat(build, room, dx - 3, 1, dx, 4, 0, d);
        } else {
            stair(build, dx - d, 1, 0, 0, d, 3);
        }
        # The deck's gate, raised by the switch on the wall by the way up.
        gate = build.opened(float(dx), 1.0, float(d), float(dx + 1), 5.0, float(d + 5));
        build.push(float(dx) - 4.5 if self.climb_lift else float(dx - d) - 0.5, 1.0, 1.5, 1) +>:Fires:+> gate;
        # A block in the near corner, a stash behind a panel in it.
        build.solid(2, 1, 0, 6, 5, 5);
        stash(build, 5, 3, 0, False, 1, "item_adrenaline");
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, d, side, 0, [3, 9], [HANGAR1_FOES.pick(dice, self.danger, True), HANGAR1_FOES.pick(dice, self.danger)]);
        up = build.touch(float(dx + 1), 1.0, float(d), float(dx + 3), float(side), float(d + 6));
        squad(build, up, [[4.5, 3.5, 0.0], [4.5, float(side) - 3.5, 0.0]], ["monster_infantry", HANGAR1_FOES.pick(dice, self.danger)], 0.0);
        build.foe(8.5, float(cy) + 0.5, -3, "monster_flipper", 0.0, patrol=[[8.5, float(cy) + 0.5], [float(self.long) - 11.5, float(cy) + 0.5]]);
        build.foe(float(self.long) - 3.5, 3.5, d, HANGAR1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(dx) + 2.5, float(side) - 3.5, 0, "monster_infantry", 180.0, patrol=[[float(dx) + 2.5, float(side) - 3.5], [float(dx) + 2.5, 5.5]]);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(side) - 3.0, float(d) + 2.0, 2);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the bay with its great door open on the sky; the
switch closes it and opens the way out."""
node BayDoor(Prefab) {
    has key: str = "",
        tall: int = 22,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bay door" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(32, 36);
        self.wide = dice.between(24, 28);
        self.tall = dice.between(20, 24);
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
        build.solid(2, self.wide - 6, 0, 6, self.wide - 1, 6);
        stash(build, self.wide - 6, 3, 0, False, -1, Q2_ARMOR);
        ex = self.long - 9;
        bay = build.room(wall + 1, 1, 0, ex, self.wide - 6, self.tall, variant=dice.below(3));
        build.level(bay, 4);
        build.widen(bay, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # The sky beyond the great door, over a sill too high to climb.
        build.room(wall + 1, self.wide - 5, 0, ex, self.wide - 1, self.tall, sky=True);
        build.solid(wall + 1, self.wide - 5, 0, ex, self.wide - 1, 5);
        build.widen(bay, wall + 6, self.wide - 6, 5, ex - 6, self.wide - 5, 16);
        gap = closing_door(build, float(wall + 6), float(self.wide - 6), 5.0, float(ex - 6), float(self.wide - 5), 16.0, 0);
        # The control platform, its stair; the switch.
        build.solid(wall + 1, 1, 0, wall + 7, 6, 4);
        stair(build, wall + 10, 1, 0, 2, 4, 3);
        # The crane catwalk across the bay, a lift up to it from the
        # control platform.
        build.level(bay, 10);
        build.solid(wall + 1, 9, 9, ex, 13, 10);
        plat(build, bay, wall + 3, 6, wall + 6, 9, 4, 10);
        build.foe(float(ex) - 2.5, 11.0, 10, "monster_infantry", 180.0, patrol=[[float(ex) - 2.5, 11.0], [float(wall) + 8.5, 11.0]]);
        build.supply(float(ex) - 1.5, 10.0, 10, "ammo_rockets", "q2");
        if self.shot {
            control = build.push(float(ex), float(cy) - 3.0, 6.0, 2, True);
        } else {
            control = build.push(float(wall + 4), 1.0, 5.2, 1);
        }
        build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0, True, "Close main hangar bay door.\nThe switch is on the control platform.");
        control +>:Fires:+> gap;
        control +>:Fires:+> build.objective("Bay door closing.\nGet to the way out.");
        control +>:Fires:+> quake(build, float(self.long // 2), float(cy), 2.0, 4);
        charges(build, control, [[float(wall + 8), float(self.wide) - 4.0, 10.0], [float(self.long // 2), float(self.wide) - 4.0, 12.0], [float(ex - 8), float(self.wide) - 4.0, 10.0]], 0.6);
        # The way out beyond the far wall, its door opening behind.
        out_room = build.room(ex + 1, 1, 0, self.long - 1, self.wide - 6, 10, variant=dice.below(3));
        build.widen(out_room, ex, cy - 2, 0, ex + 1, cy + 2, 8);
        late = build.delay(2.0);
        control +>:Fires:+> late;
        late +>:Fires:+> build.opened(float(ex), float(cy - 2), 0.0, float(ex + 1), float(cy + 2), 8.0);
        build.way_out(float(self.long) - 4.0, float(cy), 0);
        squad(build, late, [[float(ex) - 3.5, 3.5, 0.0], [float(ex) - 3.5, float(self.wide) - 9.5, 0.0]], [HANGAR1_FOES.pick(dice, self.danger, True), "monster_infantry"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, HANGAR1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2), float(cy) + 0.5, 0, "monster_infantry", 0.0, patrol=[[float(self.long // 2), 8.5], [float(self.long // 2), float(self.wide) - 9.5]]);
        build.foe(float(self.long // 2), float(cy) - 2.5, 10, HANGAR1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""hangar1's stretches: [name, role]."""
glob HANGAR1_STRETCHES: list[list[str]] = [
         ["apron", "start"],
         ["sump", "flow"],
         ["tunnel", "flow"],
         ["bay", "hub"],
         ["tunnel", "hub"],
         ["control", "keyroom"],
         ["door", "end"],
         ["door", "gate"]
     ];

"""One of hangar1's stretches by its name."""
def make_hangar1(name: str, key: str) -> Prefab {
    if name == "apron" {
        return HangarApron();
    }
    if name == "sump" {
        return FloodedSump();
    }
    if name == "tunnel" {
        return LaserTunnel();
    }
    if name == "bay" {
        return BayHangar();
    }
    if name == "control" {
        return HangarControl(key=key if key else "key_silver");
    }
    return BayDoor(key=key);
}
