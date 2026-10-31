"""Prefabs drawn from Quake II's cool1, the Cooling Facility: an intake
cavern over a coolant basin, a hall whose great pistons carry the player
up to its catwalk, the pump room whose two valves drain the coolant, a
cooling tower climbed round its walls or ridden up its middle, the valve
tank, the drained outfall. Raised in cool1's own palette.

- `CoolingIntake`: the start. A perch high over an intake basin, a stair
  (or only a lift) down to its floor, a catwalk along the far wall from
  the perch to a gantry over the far end; a barge riding across the basin
  (cool1's trains). The help computer gives the mission; hovers and
  technicians patrol; guards appear as the player comes down; a stash
  under the perch behind a panel.
- `PistonHall`: a hall, a catwalk along one wall, great pistons rising and
  falling beside it that carry the player up (cool1's train lifts), and a
  stair or a lift at the end. Guards appear on the catwalk as the player
  passes the hall's middle; technicians come in over the catwalk.
- `PumpRoom`: a hub. The pump's great housing in the middle, a gantry
  along two walls up a stair, a slime sump in a corner. Its two valves,
  one on the housing and one on the gantry (cool1's counter), drain the
  coolant: the objective moves on, the room shakes, guards teleport in
  and the ways on open.
- `CoolingTower`: a tower climbed by a stair winding round its walls, or
  ridden up its middle on a freight platform, entered at the foot or at
  the top. What waits at the top wakes as the player passes halfway.
- `ValveTank`: the key room. A tank in a hall, the key on its top up a
  lift (or a freight platform); taking it brings guards through
  teleporters and opens the closets; a panel in the tank's foot hides a
  stash.
- `DrainOutfall`: the end. A door (a key's, as a gate), then the drained
  outfall: terraces stepping down to the old channel, a bridge drawn out
  over the water left in it by shooting a switch, the way out beyond."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, spiral, ring_path, ring_landing }
import from .plant_parts { key_doors, open_ways, charges, sparking, stash, crate_pile, squad, keep_box, plat, port_door, hurting, quake }

glob COOL1: str = "q2:cool1";

"""cool1's foes: gunners and iron maidens, berserkers, gladiators deeper
in; hovers and technicians in the air."""
glob COOL1_FOES: FoeMix = FoeMix(light=["monster_gunner", "monster_chick", "monster_berserk"], strong=["monster_gladiator"], heavy_light=["monster_gunner", "monster_gladiator"], scale=0.5, heavy_scale=0.4, flying="monster_hover", flying_other="monster_floater", flying_odds=0.35);

"""The start: a perch high over an intake basin, a catwalk round to a
gantry over the far end."""
node CoolingIntake(Prefab) {
    has perch: int = 10,
        tall: int = 20,
        stairs: bool = True,
        barge: bool = True,
        foul: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cooling intake";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(22, 26);
        self.perch = dice.between(10, 12);
        self.tall = self.perch + dice.between(9, 11);
        self.stairs = dice.chance(0.6);
        self.barge = dice.chance(0.6);
        self.foul = not self.barge and dice.chance(0.6);
        self.low = -5;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=self.perch);
        self.leaves = [Port(face=0, along=cy, floor=self.perch), Port(face=0, along=cy, floor=0), Port(face=3, along=float(self.long - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        p = self.perch;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, p);
        # The perch, the gantry over the far end, the catwalk between them
        # along the high wall: slabs over the floor below.
        build.solid(1, 1, p - 1, 8, self.wide - 1, p);
        build.solid(self.long - 8, 1, p - 1, self.long - 1, self.wide - 1, p);
        build.solid(8, self.wide - 5, p - 1, self.long - 8, self.wide - 1, p);
        # Down from the perch: a lift always, a stair along the low wall.
        plat(build, hall, 8, 5, 11, 8, 0, p);
        if self.stairs {
            stair(build, 7 + p, 1, 0, 2, p, 3);
        }
        # The intake basin, a barge riding across it.
        x0 = 13;
        x1 = self.long - 10;
        build.pool(x0, cy - 3, -4, x1, cy + 4, 0, 3 if self.foul else 2, False, True, True);
        if self.foul {
            hurting(build, float(x0), float(cy - 3), -4.0, float(x1), float(cy + 4), -1.0, 8);
        }
        if self.barge {
            build.train([3.0, 3.0, 1.0], [[float(x0 + 2), float(cy - 1), -1.0], [float(x1 - 3), float(cy - 1), -1.0]], 50.0, 3.0);
        }
        # A block under the perch, a stash behind a panel in it.
        build.solid(1, self.wide - 6, 0, 5, self.wide - 1, 6);
        stash(build, self.wide - 6, 2, 0, False, -1, "item_adrenaline");
        open_ways(build, hall, self);
        build.start(3.0, float(cy) + 0.5, p, 0.0);
        build.supply(3.0, float(cy) - 2.0, p, "ammo_shells", "q2");
        mission = build.touch(1.0, 1.0, float(p), 8.0, float(self.wide - 1), float(p + 6));
        mission +>:Fires:+> build.objective("Activate cooling pump to\nlower coolant around\nreactor.");
        # Guards appear on the floor as the player comes down.
        down = build.touch(12.0, 1.0, 0.0, 13.0, float(self.wide - 5), float(p));
        squad(build, down, [[float(self.long) - 10.5, 3.5, 0.0], [float(self.long) - 10.5, float(self.wide) - 7.5, 0.0], [float(x1) - 2.0, float(cy) + 0.5, 6.0]], [COOL1_FOES.pick(dice, self.danger), COOL1_FOES.pick(dice, self.danger, True), "monster_floater"], 180.0);
        basin = build.touch(float(x0), 1.0, 0.0, float(x0 + 2), float(self.wide - 5), 6.0);
        squad(build, basin, [[float(x1) - 1.0, float(cy) - 1.0, 5.0], [float(x1) + 2.5, float(self.wide) - 7.5, 0.0]], ["monster_floater", COOL1_FOES.pick(dice, self.danger)], 180.0);
        build.foe(float(x0) + 1.5, float(cy) + 0.5, 4, "monster_hover", 0.0, patrol=[[float(x0) + 1.5, float(cy) + 0.5], [float(x1) - 1.5, float(cy) + 0.5]]);
        build.foe(float(self.long) - 4.0, 3.5, p, "monster_gunner", 90.0, patrol=[[float(self.long) - 4.0, 3.5], [float(self.long) - 4.0, float(self.wide) - 3.5]]);
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.0, p, COOL1_FOES.pick(dice, self.danger), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 2.5, 3.5 + float(index) * 4.0, 0, COOL1_FOES.pick(dice, self.danger), 180.0);
        }
        sparking(build, dice.uniform(3.0, 5.0), float(self.long) - 8.2, float(cy) + 2.5, float(p) - 3.0, 2);
        crate_pile(build, self.long - 7, self.wide - 3, 0, 0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, p, Q2_HEALTH, "q2");
    }
}

"""A hall, a catwalk along one wall, great pistons beside it that carry
the player up."""
node PistonHall(Prefab) {
    has walk: int = 9,
        tall: int = 18,
        pistons: int = 2,
        stairs: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Piston hall";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(32, 36);
        self.wide = dice.between(18, 21);
        self.walk = dice.between(9, 10);
        self.tall = self.walk + dice.between(8, 10);
        self.pistons = dice.between(2, 3);
        self.stairs = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=3, along=float(self.long // 2), floor=self.walk), Port(face=1, along=float(self.long // 2), floor=0)];
        if not self.stairs {
            self.leaves.append(Port(face=0, along=3.0, floor=self.walk));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        u = self.walk;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The catwalk along the low wall, and a stair down its far end or a
        # lift at its near end.
        end_x = self.long - 1;
        if self.stairs {
            end_x = self.long - 1 - u;
            stair(build, self.long - 2, 1, 0, 2, u, 4);
            build.solid(6, 1, u - 1, end_x, 5, u);
        } else {
            plat(build, hall, 3, 1, 6, 4, 0, u);
            build.solid(6, 1, u - 1, end_x, 5, u);
        }
        # The pistons beside the catwalk, rising and falling.
        x = 9;
        for index in range(self.pistons) {
            if x + 3 < end_x - 2 {
                build.train([3.0, 3.0, 1.0], [[float(x), 5.0, 0.0], [float(x), 5.0, float(u - 1)]], 55.0 + float(index) * 10.0, 2.0);
                keep_box(build, hall, x, 4, x + 3, 5, u);
            }
            x += 9;
        }
        # Cooling pipes along the high wall, low enough to step over.
        for px in range(6, self.long - 12, 8) {
            if abs(px + 2 - self.long // 2) > 5 {
                build.solid(px, self.wide - 3, 0, px + 4, self.wide - 1, 2);
            }
        }
        # A store at the far corner, its shutter rising on what waits in it
        # as the player comes to the hall's end.
        build.solid(self.long - 6, self.wide - 6, 0, self.long - 1, self.wide - 1, 7);
        build.room(self.long - 5, self.wide - 5, 0, self.long - 2, self.wide - 2, 6);
        shutter = build.opened(float(self.long - 6), float(self.wide - 5), 0.0, float(self.long - 5), float(self.wide - 2), 6.0);
        open_ways(build, hall, self);
        far_end = build.touch(float(self.long - 10), 5.0, 0.0, float(self.long - 8), float(self.wide - 1), 6.0);
        far_end +>:Fires:+> shutter;
        squad(build, far_end, [[float(self.long) - 3.5, float(self.wide) - 3.5, 0.0]], [COOL1_FOES.pick(dice, self.danger, True)], 180.0);
        # Past the hall's middle, guards appear on the catwalk; technicians
        # come in over it.
        mid = self.long // 2;
        halfway = build.touch(float(mid - 1), 5.0, 0.0, float(mid + 1), float(self.wide - 1), 6.0);
        squad(build, halfway, [[float(end_x) - 3.5, 3.0, float(u)], [float(mid) + 4.5, 3.0, float(u)]], ["monster_gunner", COOL1_FOES.pick(dice, self.danger)], 180.0);
        up = build.touch(6.0, 1.0, float(u), float(end_x), 5.0, float(u + 6));
        squad(build, up, [[float(mid), 8.0, float(u + 3)]], [COOL1_FOES.pick(dice, self.danger, False, True)], 180.0);
        build.foe(4.5, float(cy) + 1.5, 0, "monster_berserk", 0.0, patrol=[[4.5, float(cy) + 1.5], [float(self.long) - 4.5, float(cy) + 1.5]]);
        build.foe(8.5, 3.0, u, "monster_gunner", 0.0, patrol=[[8.5, 3.0], [float(end_x) - 2.5, 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(mid + 3 + index * 4) + 0.5, float(cy) + 3.5, 0, COOL1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        sparking(build, dice.uniform(3.0, 5.0), 8.0, 5.2, float(u) - 2.0, 1);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(cy) + 2.0, 3.0, 2);
        crate_pile(build, mid - 7, self.wide - 6, 0, 0, 1);
        build.supply(float(self.long) - 3.0, float(cy) - 2.0, 0, Q2_HEALTH, "q2");
        build.supply(float(mid) + 0.5, 3.0, u, "ammo_bullets", "q2");
    }
}

"""The pump's housing in the middle of a room, a gantry along two walls,
two valves that drain the coolant and open the ways on."""
node PumpRoom(Prefab) {
    has gallery: int = 9,
        tall: int = 20,
        sump: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump room";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(26, 30);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(9, 11);
        self.sump = True;
        self.low = -4;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy - 4.0, floor=0), Port(face=1, along=float(self.long - 9), floor=self.gallery), Port(face=3, along=float(self.long // 2 - 6), floor=0), Port(face=0, along=float(self.wide - 8), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gallery;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, g);
        # The pump's housing, floor to roof, its intakes round its foot.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.tall);
        for side in [-1, 1] {
            build.solid(cx - 1, cy + side * 4 - (1 if side < 0 else 0), 0, cx + 1, cy + side * 4 + (1 if side > 0 else 0), 2);
        }
        # The gantry along the far wall and the high wall, its stair up the
        # low wall.
        build.solid(self.long - 5, 1, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(cx - 2, self.wide - 5, g - 1, self.long - 5, self.wide - 1, g);
        stair(build, self.long - 5 - g, 1, 0, 0, g, 4);
        # The slime sump in the near high corner.
        if self.sump {
            build.pool(3, self.wide - 9, -3, 9, self.wide - 3, 0, 3);
            hurting(build, 3.0, float(self.wide - 9), -3.0, 9.0, float(self.wide - 3), -1.0, 10);
        }
        open_ways(build, room, self);
        # The two valves: one on the housing's face, one on the gantry's
        # wall. Together they drain the coolant.
        drained = build.tally(2, "Valve open");
        first_valve = build.push(float(cx - 4), float(cy) + 0.5, 1.5, 2);
        first_valve +>:Fires:+> drained;
        squad(build, first_valve, [[float(self.long) - 3.0, float(cy) + 0.5, float(g)], [float(cx) + 6.5, 4.5, 0.0]], [COOL1_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        build.push(float(self.long - 1), float(self.wide) - 3.5, float(g) + 1.2, 2) +>:Fires:+> drained;
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0, True, "Open both valves to drain the coolant");
        drained +>:Fires:+> build.objective("Coolant systems drained.\nReturn to the Reactor.");
        drained +>:Fires:+> quake(build, float(cx), float(cy), 2.0, 3);
        charges(build, drained, [[float(cx) - 4.2, float(cy) - 3.0, 4.0], [float(cx) + 4.2, float(cy) + 3.0, 5.0]], 0.5);
        for port in self.taken {
            port_door(build, self, port, drained);
        }
        # Guards teleport in as the coolant drains.
        late = build.delay(1.0);
        drained +>:Fires:+> late;
        late +>:Fires:+> build.summon(cx - 3, cy - 3, 1, COOL1_FOES.pick(dice, self.danger, True), float(cx) - 7.5, float(cy) + 0.5, 0, 0.0);
        late +>:Fires:+> build.summon(cx, cy, 1, COOL1_FOES.pick(dice, self.danger), float(self.long) - 3.0, float(self.wide) - 6.5, g, 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(cx) + 4.2, float(cy) - 2.0, 3.0, 0);
        build.foe(float(self.long) - 3.0, 4.5, g, "monster_gunner", 90.0, patrol=[[float(self.long) - 3.0, 4.5], [float(self.long) - 3.0, float(self.wide) - 3.0], [float(cx), float(self.wide) - 3.0]]);
        build.foe(5.5, 4.5, 0, COOL1_FOES.pick(dice, self.danger), 0.0, patrol=[[5.5, 4.5], [float(cx) - 6.5, 4.5], [float(cx) - 6.5, float(cy) + 5.5]]);
        build.foe(float(cx) + 6.5, float(cy) + 0.5, 0, COOL1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, float(cy) + 7.5, 6, "monster_hover", 270.0);
        build.supply(float(cx) - 6.0, float(cy) - 6.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "ammo_cells", "q2");
    }
}

"""A tower climbed by a stair winding round its walls, or ridden up its
middle on a freight platform."""
node CoolingTower(Prefab) {
    has steps: int = 18,
        tall: int = 28,
        upward: bool = True,
        freight: bool = True,
        face: int = 1,
        along: float = 8.0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cooling tower";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        fits: list[int] = [];
        for steps in range(14, 25) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 6);
            if landing and int(landing[0]) != 2 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 6);
        self.face = int(top[0]);
        self.along = top[1];
        self.tall = self.steps + 10;
        self.upward = dice.chance(0.6);
        self.freight = dice.chance(0.6);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        high_way = Port(face=self.face, along=self.along, floor=self.steps);
        if self.upward {
            self.enter = Port(face=2, along=cy, floor=0);
            self.leaves = [high_way, Port(face=0, along=cy, floor=0)];
        } else {
            self.enter = high_way;
            self.leaves = [Port(face=2, along=cy, floor=0), Port(face=0, along=cy, floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tower, self.steps // 2);
        build.level(tower, self.steps);
        landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 6);
        mid = landing[3];
        # The freight platform up the middle, by the landing's inner edge.
        if self.freight {
            a = int(self.along);
            if self.face == 1 {
                box = [a - 1, self.wide - 7];
                keep_box(build, tower, a - 1, self.wide - 4, a + 2, self.wide - 3, self.steps);
            } elif self.face == 3 {
                box = [a - 1, 4];
                keep_box(build, tower, a - 1, 3, a + 2, 4, self.steps);
            } else {
                box = [self.long - 7, a - 1];
                keep_box(build, tower, self.long - 4, a - 1, self.long - 3, a + 2, self.steps);
            }
            build.train([3.0, 3.0, 1.0], [[float(box[0]), float(box[1]), 0.0], [float(box[0]), float(box[1]), float(self.steps - 1)]], 70.0, 3.0);
        }
        if not self.freight {
            # The fan well in the middle: coolant gone foul.
            mx = self.long // 2;
            my = self.wide // 2;
            build.pool(mx - 2, my - 2, -3, mx + 2, my + 2, 0, 3);
            hurting(build, float(mx - 2), float(my - 2), -3.0, float(mx + 2), float(my + 2), -1.0, 10);
        }
        open_ways(build, tower, self);
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        # What waits up top wakes as the player passes the stair's middle.
        half = path[self.steps // 2];
        roused = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        squad(build, roused, [[float(mid[0] + mid[2]) * 0.5, float(mid[1] + mid[3]) * 0.5, float(self.steps)]], [COOL1_FOES.pick(dice, self.danger, True)], 180.0);
        foot = build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0);
        squad(build, foot, [[float(self.long) - 5.5, float(cy) + 0.5, 0.0], [float(self.long // 2), float(cy) - 3.0, 6.0]], [COOL1_FOES.pick(dice, self.danger), "monster_floater"], 180.0);
        late = build.delay(2.0);
        roused +>:Fires:+> late;
        late +>:Fires:+> build.sparks(float(mid[0]) + 0.5, float(mid[1]) + 0.5, float(self.steps + 3), 3);
        roused +>:Fires:+> build.sparks(float(half[0]) + 0.5, float(half[1]) + 0.5, float(self.steps // 2 + 4), 1);
        for index in range(dice.between(1, 2)) {
            cell = path[self.steps // 2 + index * 3];
            build.foe(float(cell[0] + cell[2]) * 0.5, float(cell[1] + cell[3]) * 0.5, self.steps // 2 + index * 3 + 1, COOL1_FOES.pick(dice, self.danger), 90.0);
        }
        middle_x = float(self.long // 2);
        build.foe(middle_x, float(cy), self.steps // 2, "monster_hover", 0.0, patrol=[[middle_x - 2.0, float(cy) - 2.0], [middle_x + 2.0, float(cy) - 2.0], [middle_x + 2.0, float(cy) + 2.0], [middle_x - 2.0, float(cy) + 2.0]]);
        build.foe(float(self.long) - 5.5, 5.0, 0, COOL1_FOES.pick(dice, self.danger), 180.0);
        sparking(build, dice.uniform(3.0, 5.0), 1.2, float(cy) + 3.0, 3.0, 0);
        build.supply(5.0, float(self.wide) - 5.5, 0, Q2_HEALTH, "q2");
        top = landing[5];
        build.supply(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.steps, "ammo_rockets", "q2");
    }
}

"""The key room: a tank in a hall, the key on its top up a lift."""
node ValveTank(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        tank: int = 8,
        freight: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Valve tank (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(23, 26);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.tank = dice.between(8, 9);
        self.freight = dice.chance(0.5);
        self.low = -1;
        self.high = self.tank + 9;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        t = self.tank;
        room = build.room(1, 1, 0, self.long - 1, side, t + 8, variant=dice.below(3));
        build.level(room, t);
        build.doorway(room, self.enter);
        tx0 = self.long - 12;
        build.solid(tx0, cy - 4, 0, self.long - 4, cy + 4, t);
        plat(build, room, tx0 - 3, cy - 1, tx0, cy + 2, 0, t);
        if self.freight {
            build.train([3.0, 3.0, 1.0], [[float(self.long - 10), float(cy + 4), 0.0], [float(self.long - 10), float(cy + 4), float(t - 1)]], 60.0, 3.0);
            keep_box(build, room, self.long - 10, cy + 3, self.long - 7, cy + 4, t);
        }
        # The tank's foot hides a stash behind a panel.
        stash(build, self.long - 4, cy - 1, 0, True, 1, Q2_ARMOR);
        key_ambush(build, self.key, float(self.long) - 8.0, float(cy) + 0.5, t, side, 0, [3, 9], [COOL1_FOES.pick(dice, self.danger, True), COOL1_FOES.pick(dice, self.danger)]);
        # On the tank's top, guards come through teleporters.
        coming = build.touch(1.0, float(cy - 2), 0.0, 3.0, float(cy + 3), 8.0);
        squad(build, coming, [[float(tx0) - 1.5, 3.5, 0.0], [float(self.long) - 2.5, float(side) - 3.5, 0.0]], ["monster_gunner", COOL1_FOES.pick(dice, self.danger)], 180.0);
        on_top = build.touch(float(tx0), float(cy - 4), float(t), float(self.long - 4), float(cy + 4), float(t + 6));
        on_top +>:Fires:+> build.summon(tx0 + 1, cy - 3, 1, COOL1_FOES.pick(dice, self.danger), 4.0, 3.5, 0, 0.0);
        on_top +>:Fires:+> build.summon(tx0 + 1, cy + 1, 1, COOL1_FOES.pick(dice, self.danger, True), 4.0, float(side) - 3.5, 0, 0.0);
        on_top +>:Fires:+> build.explosion(float(tx0) - 1.0, float(cy) - 5.0, 4.0);
        sparking(build, dice.uniform(4.0, 6.0), float(tx0) - 0.2, float(cy) - 3.0, 3.0, 2);
        build.foe(float(self.long) - 2.5, 3.5, 0, COOL1_FOES.pick(dice, self.danger), 180.0);
        build.foe(5.5, float(cy) + 0.5, 0, "monster_berserk", 0.0, patrol=[[5.5, float(cy) + 0.5], [float(tx0) - 4.5, 3.5], [float(tx0) - 4.5, float(side) - 3.5]]);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, terraces stepping down the drained outfall, a bridge
drawn out over the water left in its channel, the way out beyond."""
node DrainOutfall(Prefab) {
    has key: str = "",
        tall: int = 16,
        steps_y: int = 4,
        channel: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drain outfall" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = COOL1;
        self.district = level_district(COOL1);
        self.long = dice.between(37, 40);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(15, 17);
        self.steps_y = dice.between(3, self.wide - 6);
        self.channel = dice.chance(0.6);
        self.low = -10;
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
        stash(build, self.wide - 6, 3, 0, False, -1, "item_adrenaline");
        drain = build.room(wall + 1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(drain, 0);
        build.level(drain, -3);
        build.widen(drain, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # The terraces, three lifts apart, stairs down each.
        build.solid(wall + 1, 1, -6, wall + 7, self.wide - 1, 0);
        build.solid(wall + 7, 1, -6, wall + 13, self.wide - 1, -3);
        stair(build, wall + 9, self.steps_y, -3, 2, 3, 3);
        stair(build, wall + 15, self.wide - 3 - self.steps_y, -6, 2, 3, 3);
        if self.channel {
            # The old channel, water left in it, a bridge drawn out over it
            # when the switch on the far wall is shot.
            c0 = self.long - 11;
            build.pool(c0, 1, -9, c0 + 5, self.wide - 1, -6, 2, False, True, True);
            switch_cue = build.push(float(self.long - 1), float(self.wide) - 3.5, -3.5, 2, True);
            switch_cue +>:Fires:+> build.drawn(float(c0), float(cy - 1), float(c0 + 5), float(cy + 2), -6, 4);
            keep_box(build, drain, c0 - 1, cy - 1, c0, cy + 2, -6);
            keep_box(build, drain, c0 + 5, cy - 1, c0 + 6, cy + 2, -6);
            build.touch(float(c0 - 3), 1.0, -6.0, float(c0 - 1), float(self.wide - 1), 0.0, True, "Shoot the switch to draw the bridge out");
        }
        build.way_out(float(self.long) - 3.5, float(cy), -6);
        through = build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0);
        squad(build, through, [[float(wall + 10) + 0.5, 3.5, -3.0], [float(wall + 10) + 0.5, float(self.wide) - 3.5, -3.0]], [COOL1_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        through +>:Fires:+> build.explosion(float(wall + 4), 2.0, 3.0);
        # Coming down the terraces, guards appear by the way out.
        first = build.touch(float(wall + 7), 1.0, -3.0, float(wall + 9), float(self.wide - 1), 3.0);
        squad(build, first, [[float(self.long) - 3.5, 3.5, -6.0], [float(self.long) - 3.5, float(self.wide) - 3.5, -6.0]], [COOL1_FOES.pick(dice, self.danger, True), COOL1_FOES.pick(dice, self.danger)], 180.0);
        charges(build, first, [[float(self.long) - 6.0, 2.5, -2.0], [float(self.long) - 6.0, float(self.wide) - 2.5, -2.0]], 0.6);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, COOL1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall + 16) + 0.5, float(cy) + 0.5, -6, "monster_gunner", 0.0, patrol=[[float(wall + 16) + 0.5, 3.5], [float(wall + 16) + 0.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long) - 8.5, float(cy) + 0.5, 0, "monster_hover", 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""cool1's stretches: [name, role]."""
glob COOL1_STRETCHES: list[list[str]] = [
         ["intake", "start"],
         ["pistons", "flow"],
         ["tower", "flow"],
         ["pumps", "hub"],
         ["pistons", "hub"],
         ["tank", "keyroom"],
         ["outfall", "end"],
         ["outfall", "gate"]
     ];

"""One of cool1's stretches by its name."""
def make_cool1(name: str, key: str) -> Prefab {
    if name == "intake" {
        return CoolingIntake();
    }
    if name == "pistons" {
        return PistonHall();
    }
    if name == "tower" {
        return CoolingTower();
    }
    if name == "pumps" {
        return PumpRoom();
    }
    if name == "tank" {
        return ValveTank(key=key if key else "key_silver");
    }
    return DrainOutfall(key=key);
}
