"""Prefabs drawn from Quake II's jail1, the Main Gate: broken ground
climbing to the prison's outer wall over its moat, a hall barred by the
security grid's lasers, the gatehouse whose portcullis a guard's button
raises, a yard round a guard tower whose top works the main gate, the
flooded tunnels under the moat, the warden's office over the cells, and a
cell block of two tiers. Raised in jail1's own palette.

- `PrisonApproach`: the start. Ground broken into ledges climbs to a
  plateau before the moat; a bridge (or a drawbridge lowered by a post's
  button) over the moat into the gate's tunnel through the wall, snipers on
  the wall's top. Halfway up, guards appear on the plateau and mortar
  charges burst by the moat; a nook under the water by the wall is a
  secret.
- `SecurityGrid`: a hall barred by gates of lasers, a catwalk over them up
  a stair to a control booth over the hall's far end; a button in the booth
  (or a shot one on its front) shuts the grid down: the lasers die, its
  generators blow apart, guards come.
- `Gatehouse`: a guard room, a portcullis across its far end raised by a
  button on a balcony up a stair (or a lift); a second balcony across now
  and then, where guards appear when the player comes up to the
  portcullis.
- `GuardTowerYard`: a yard of rubble round a guard tower, a stair (or a
  lift) up the tower and a bridge (fixed or drawn by a button) to the
  wall-walk over an arcade; the winch on the tower's top opens the main
  gate below (or the gates open as a body nears). Ways on below and from
  the walk (a hub).
- `MoatTunnels`: the channels under the moat: walkways along a flooded
  channel crossed by bridges, a guard post over the far end up a stair or
  a lift; a grate under the water breaks on a stash (a secret); guards
  appear on the post as the player crosses.
- `WardenOffice`: the key room. A hall, the warden's office on a balcony
  over it up a stair or a lift, the key on his desk; taking it opens the
  cells along the near wall and switches on lasers across the hall.
- `CellBlock`: the end. A door (a key's, as a gate), a cell block of two
  tiers, galleries along both walls joined by a bridge, the way out at the
  far end on the floor or the far gallery; reaching the bridge opens the
  upper cells."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, lift, boulders, apart }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, stash, keep_row, called_lift, closets, gate_pair, post_button, laser, laser_grid }

glob JAIL1: str = "q2:jail1";

"""jail1's foes: infantry and gunners, flyers, berserkers and a gladiator
deeper in."""
glob JAIL1_FOES: FoeMix = FoeMix(light=["monster_infantry", "monster_infantry", "monster_gunner"], strong=["monster_berserk"], heavy_light=["monster_gunner", "monster_berserk"], heavy_strong=["monster_gladiator"], heavy_scale=0.6, flying="monster_flyer");


"""The start: broken ground climbing to a plateau, the moat, the wall."""
node PrisonApproach(Prefab) {
    has plateau: int = 5,
        blocks: int = 6,
        rows: int = 5,
        wall: int = 11,
        drawbridge: bool = False,
        heights: list[list[int]] = [],
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Prison approach";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.plateau = dice.between(6, 8);
        self.blocks = dice.between(9, 11);
        self.wide = dice.between(22, 25);
        self.rows = (self.wide - 2) // 3;
        self.wall = dice.between(10, 12);
        self.drawbridge = dice.chance(0.45);
        self.long = 1 + 2 * self.blocks + 7 + 9 + 5 + 1;
        self.tall = self.plateau + self.wall + 8;
        self.low = self.plateau - 31;
        self.high = self.tall + 1;
        # The ground's heights, a block two cells along by a row three
        # across: the middle row climbs a lift a block at most; the others
        # wander up to three lifts over or under it, level with it at both
        # ends, a block never more than two lifts over the one before it
        # (so a body can always jump back down the way it came).
        lane = self.rows // 2;
        self.heights = [];
        for row in range(self.rows) {
            line: list[int] = [];
            offset = 0;
            last = 0;
            for block in range(self.blocks) {
                rise = int(round(float(self.plateau) * float(block) / float(self.blocks - 1)));
                if row != lane and 0 < block < self.blocks - 1 {
                    room = min(3, block, self.blocks - 1 - block);
                    choices = [step for step in [-2, -1, 0, 1, 2] if abs(offset + step) <= room and abs(max(0, rise + offset + step) - last) <= 2];
                    offset += choices[dice.below(len(choices))] if choices else 0;
                } else {
                    offset = 0;
                }
                last = max(0, rise + offset);
                line.append(last);
            }
            self.heights.append(line);
        }
        tx = 1 + 2 * self.blocks;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.plateau),
            Port(face=1, along=float(tx + 3), floor=self.plateau),
            Port(face=3, along=float(tx + 3), floor=self.plateau)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        top = self.plateau;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, top);
        # The broken ground, block by block.
        for row in range(self.rows) {
            y0 = 1 + row * 3;
            y1 = y0 + 3 if row < self.rows - 1 else self.wide - 1;
            for block in range(self.blocks) {
                height = self.heights[row][block];
                if height > 0 {
                    build.solid(1 + block * 2, y0, 0, 3 + block * 2, y1, height);
                }
            }
        }
        # The plateau, the moat, the wall.
        tx = 1 + 2 * self.blocks;
        mx = tx + 7;
        wx = mx + 9;
        build.solid(tx, 1, 0, mx, self.wide - 1, top);
        # (As deep as its steps out at both ends climb before they reach the
        # bridge in the middle.)
        dm = min(14, middle - 3);
        build.pool(mx, 1, top - dm, wx, self.wide - 1, top, 2, False, True, True);
        build.solid(wx, 1, 0, self.long - 1, self.wide - 1, top + self.wall);
        build.widen(ground, wx, middle - 2, top, self.long - 1, middle + 2, top + 8);
        for y in range(2, self.wide - 2, 2) {
            build.solid(wx, y, top + self.wall, wx + 1, y + 1, top + self.wall + 2);
        }
        # The way over the moat: a bridge, or a drawbridge lowered by the
        # button on a post at its head.
        if self.drawbridge {
            bridge = build.drawn(float(mx), float(middle - 2), float(wx), float(middle + 2), top, dm + 2);
            post_button(build, mx - 1, middle + 3, top, 2) +>:Fires:+> bridge;
            build.touch(float(mx - 3), float(middle - 2), float(top), float(mx - 1), float(middle + 2), float(top + 6), True, "The drawbridge is worked from the post");
        } else {
            build.solid(mx, middle - 2, top - 1, wx, middle + 2, top);
        }
        for y in range(middle - 2, middle + 2) {
            build.keep(ground, mx - 1, y, top);
            build.keep(ground, wx, y, top);
        }
        # A nook under the water at the wall's foot, a secret.
        build.room(wx, 3, top - dm, wx + 2, 6, top - dm + 3);
        for z in range(top - dm, top - dm + 3) {
            for y in range(3, 6) {
                for x in range(wx, wx + 2) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        build.secret(float(wx), 3.0, float(top - dm), float(wx + 2), 6.0, float(top - dm + 2));
        build.supply(float(wx) + 1.0, 4.5, top - dm, Q2_ARMOR, "q2");
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        lane_y = float(1 + (self.rows // 2) * 3) + 1.5;
        build.start(2.5, lane_y, 0, 0.0);
        build.supply(2.5, lane_y - 2.0, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Penetrate the outer jail defenses");
        # Halfway up, guards appear on the plateau and charges burst by the
        # moat; snipers on the wall's top.
        half = 1 + (self.blocks // 2) * 2;
        halfway = build.touch(float(half), 1.0, 0.0, float(half + 1), float(self.wide - 1), float(top + 8));
        guards(build, halfway, [[float(tx) + 1.5, 3.5], [float(tx) + 2.5, float(self.wide) - 3.5]], top, JAIL1_FOES.squad(dice, self.danger, 2, True), 180.0);
        charges(build, halfway, [[float(mx) + 3.5, 3.5, float(top)], [float(mx) + 3.5, float(self.wide) - 4.5, float(top)], [float(tx) - 1.5, float(middle) + 4.5, float(top) + 1.0]], 0.7);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wx) + 2.5, 3.5 + float(index) * 6.0, top + self.wall, JAIL1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(tx) + 1.5, 5.5, top, "monster_infantry", 90.0, patrol=[[float(tx) + 1.5, 5.5], [float(tx) + 1.5, float(self.wide) - 5.5]]);
        for index in range(dice.between(1, 2)) {
            block = 1 + index * 2;
            row = 0 if index == 0 else self.rows - 1;
            build.foe(float(2 + block * 2), float(2 + row * 3) + 0.5, self.heights[row][block], JAIL1_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(tx) + 2.5, float(middle) + 3.5, top, Q2_HEALTH, "q2");
    }
}

"""A hall barred by gates of lasers, a catwalk over them to a control
booth over its far end."""
node SecurityGrid(Prefab) {
    has booth: int = 12,
        gates: int = 2,
        shot: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security grid";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(17, 19);
        self.gates = dice.between(2, 3);
        self.shot = dice.chance(0.4);
        self.tall = self.booth + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2 - 1);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=middle, floor=self.booth),
            Port(face=3, along=6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2 - 1;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.booth);
        # The stair up the north wall, the catwalk on along it to the booth.
        stair(build, 2, self.wide - 4, 0, 0, self.booth, 3);
        bx = self.long - 7;
        build.solid(self.booth + 2, self.wide - 4, self.booth - 1, bx, self.wide - 1, self.booth);
        # The booth over the hall's far end: its floor a slab over the floor
        # below, a front wall with a window over the hall and a door from the
        # catwalk.
        build.solid(bx, 1, self.booth - 1, self.long - 1, self.wide - 1, self.booth);
        build.solid(bx, 1, self.booth, bx + 1, self.wide - 1, self.tall);
        build.widen(hall, bx, self.wide - 4, self.booth, bx + 1, self.wide - 1, self.booth + 6);
        build.widen(hall, bx, middle - 2, self.booth + 2, bx + 1, middle + 2, self.booth + 5);
        # The gates of lasers across the hall, each by a generator.
        span = bx - 14;
        xs: list[float] = [];
        generators: list[Cue] = [];
        for gate in range(self.gates) {
            x = 12 + (span * gate) // max(1, self.gates - 1) if self.gates > 1 else 12 + span // 2;
            xs.append(float(x) + 0.5);
            generators.append(build.breakable(float(x + 1), 1.0, 0.0, float(x + 3), 3.0, 3.0, 40));
        }
        beams = laser_grid(build, xs, 1.2, 0, [1.0, 2.5, 4.0]);
        for x in xs {
            build.touch(x - 2.5, 1.0, 0.0, x - 1.5, float(self.wide - 4), 6.0, True, "Security grid active");
        }
        # The grid's switch: in the booth, or a shot one on its front.
        if self.shot {
            press = build.push(float(bx), float(middle) - 4.5, float(self.booth) + 2.0, 2, True);
        } else {
            press = build.push(float(self.long) - 4.5, 1.0, float(self.booth) + 1.5, 1);
        }
        for beam in beams {
            press +>:Fires:+> beam;
        }
        for generator in generators {
            press +>:Fires:+> generator;
        }
        charges(build, press, [[x + 2.0, 2.0, 2.0] for x in xs], 0.4);
        press +>:Fires:+> build.objective("Security grid destroyed");
        guards(build, press, [[float(bx) - 2.5, float(middle) + 2.5], [float(bx) + 2.5, 3.5]], 0, JAIL1_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        build.foe(float(self.booth) + 3.5, float(self.wide) - 2.5, self.booth, "monster_infantry", 0.0, patrol=[[float(self.booth) + 3.5, float(self.wide) - 2.5], [float(bx) - 1.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx) + 2.5 + float(index) * 1.5, float(middle) + 3.5 - float(index) * 4.0, self.booth, JAIL1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, JAIL1_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.booth, "ammo_bullets", "q2");
        sparking(build, float(bx) - 0.2, float(middle) + 0.5, float(self.booth) - 2.0, 2, 3.5);
    }
}

"""A guard room, a portcullis across its far end raised by a button on a
balcony."""
node Gatehouse(Prefab) {
    has balcony: int = 6,
        north: bool = True,
        by_lift: bool = False,
        second: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gatehouse";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(24, 27);
        self.wide = dice.between(18, 20);
        self.balcony = dice.between(9, 10);
        self.north = dice.chance(0.5);
        self.by_lift = dice.chance(0.35);
        self.second = dice.chance(0.6);
        self.tall = self.balcony + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        px = self.long - 7;
        room = build.room(1, 1, 0, px, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(px + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.balcony);
        # The portcullis across the opening in the far wall.
        build.widen(beyond, px, middle - 3, 0, px + 1, middle + 3, 8);
        portcullis = build.opened(float(px), float(middle - 3), 0.0, float(px + 1), float(middle + 3), 8.0);
        # The balcony along one side wall up a stair (or a lift), the
        # button on the far wall at its end.
        y0 = self.wide - 4 if self.north else 1;
        y1 = y0 + 3;
        if self.by_lift {
            # The stair climbs from the portcullis end; the button on the
            # near wall at the balcony's far end.
            build.solid(1, y0, self.balcony - 1, px - 1 - self.balcony, y1, self.balcony);
            stair(build, px - 2, y0, 0, 2, self.balcony, 3);
            build.push(1.0, float(y0) + 1.5, float(self.balcony) + 1.3, 0) +>:Fires:+> portcullis;
        } else {
            build.solid(4 + self.balcony, y0, self.balcony - 1, px, y1, self.balcony);
            stair(build, 4, y0, 0, 0, self.balcony, 3);
            build.push(float(px), float(y0) + 1.5, float(self.balcony) + 1.3, 2) +>:Fires:+> portcullis;
        }
        build.touch(float(px - 3), float(middle - 3), 0.0, float(px), float(middle + 3), 6.0, True, "The portcullis is worked from the balcony");
        # A second balcony across now and then; guards appear on it as the
        # player comes up to the portcullis.
        come_up = build.touch(float(px - 5), float(middle - 3), 0.0, float(px - 3), float(middle + 3), 6.0);
        if self.second {
            z0 = self.wide - 4 if not self.north else 1;
            build.solid(8, z0, self.balcony - 1, px, z0 + 3, self.balcony);
            guards(build, come_up, [[float(px) - 2.5, float(z0) + 1.5], [float(px) - 7.5, float(z0) + 1.5]], self.balcony, JAIL1_FOES.squad(dice, self.danger, 2), 180.0);
        } else {
            guards(build, come_up, [[float(px) + 3.5, float(middle) + 3.5]], 0, JAIL1_FOES.squad(dice, self.danger, 1, True), 180.0);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(px) - 3.5 - float(index) * 3.0, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, JAIL1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5 if self.by_lift else float(px) - 2.5, float(y0) + 1.5, self.balcony, JAIL1_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(px) + 3.0, float(middle) + 0.5, 0, "monster_infantry", 90.0, patrol=[[float(px) + 3.0, 3.5], [float(px) + 3.0, float(self.wide) - 3.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(px) - 0.2, float(middle) + 4.0, 3.0, 2, 4.0);
    }
}

"""A yard of rubble round a guard tower, a bridge from its top to the
wall-walk over an arcade; the winch on its top opens the gates below."""
node GuardTowerYard(Prefab) {
    has tower: int = 9,
        by_lift: bool = False,
        drawn_bridge: bool = False,
        winch: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard tower yard";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(34, 36);
        self.wide = dice.between(25, 27);
        self.tower = dice.between(11, 12);
        self.by_lift = dice.chance(0.4);
        self.drawn_bridge = dice.chance(0.4);
        self.winch = dice.chance(0.65);
        self.tall = self.tower + 12;
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tower),
            Port(face=0, along=float(self.wide - 3), floor=self.tower),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=middle - 3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.tower);
        # The wall-walk along the north wall, a slab over an arcade, and on
        # along the east wall.
        walk_y = self.wide - 5;
        build.solid(1, walk_y, self.tower - 1, self.long - 1, self.wide - 1, self.tower);
        for x in range(4, self.long - 4, 4) {
            build.solid(x, walk_y, 0, x + 1, walk_y + 1, self.tower - 1);
        }
        build.solid(self.long - 4, cy + 2, 0, self.long - 1, walk_y, self.tower);
        # The tower, a stair (or a lift called down) up its west face; a
        # bridge from its top north to the walk, fixed or drawn out by the
        # button on the tower's top.
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tower);
        if self.by_lift {
            post_button(build, cx - 5, cy - 4, 0, 3) +>:Fires:+> called_lift(build, cx - 6, cy - 3, cx - 3, cy, 0, self.tower);
            keep_row(build, yard, cx - 3, cy - 3, self.tower, 0, 3);
        } else {
            stair(build, cx - 3 - self.tower, cy - 3, 0, 0, self.tower, 3);
            keep_row(build, yard, cx - 3, cy - 3, self.tower, 0, 3);
        }
        if self.drawn_bridge {
            bridge = build.drawn(float(cx - 2), float(cy + 3), float(cx + 2), float(walk_y), self.tower, self.tower + 1);
            build.solid(cx + 2, cy + 2, self.tower, cx + 3, cy + 3, self.tower + 3);
            build.push(float(cx + 2), float(cy) + 2.5, float(self.tower) + 1.0, 2) +>:Fires:+> bridge;
        } else {
            build.solid(cx - 2, cy + 3, self.tower - 1, cx + 2, walk_y, self.tower);
        }
        keep_row(build, yard, cx - 2, cy + 2, self.tower, 1, 4);
        keep_row(build, yard, cx - 2, walk_y, self.tower, 1, 4);
        # Rubble about the yard.
        # A cistern sunk in the yard's far corner, steps out at both ends.
        build.pool(cx + 5, 2, -6, self.long - 6, cy - 4, 0, 2, False, True, True);
        clear = [[cx + 4, 1, self.long - 5, cy - 3], [0, cy - 4, 5, cy + 4], [cx - 7 - self.tower, cy - 6, cx + 4, cy + 4], [cx - 4, 0, cx + 4, 5], [self.long - 6, cy - 6, self.long, cy], [cx - 4, walk_y - 3, cx + 4, walk_y], [0, walk_y - 2, self.long, walk_y]];
        boulders(build, dice, 1, 1, self.long - 4, walk_y, 0, dice.between(4, 6), clear);
        # A field of rubble heaped on the yard's floor, one to three lifts.
        for index in range(dice.between(10, 16)) {
            x = dice.between(2, self.long - 7);
            y = dice.between(2, walk_y - 4);
            if apart([x, y, x + 2, y + 2], clear) {
                build.solid(x, y, 0, x + 2, y + 2, dice.between(1, 3));
            }
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        # The winch on the tower's top opens the gates below; else they open
        # as a body nears.
        low_ports = [port for port in self.taken if port.floor == 0];
        if self.winch {
            build.solid(cx + 1, cy - 3, self.tower, cx + 2, cy - 2, self.tower + 3);
            press = build.push(float(cx + 1), float(cy) - 2.5, float(self.tower) + 1.0, 2);
            for port in low_ports {
                press +>:Fires:+> shutter(build, self, port);
            }
            for port in low_ports {
                if port.face == 0 {
                    build.touch(float(self.long - 4), float(cy - 6), 0.0, float(self.long - 1), float(cy), 6.0, True, "The gate is worked from the tower");
                }
            }
        } else {
            auto_shutters(build, dice, self, low_ports, 0.7);
        }
        # Climbing the tower, guards appear on the walk.
        climb = build.touch(float(cx - 3 - self.tower), float(cy - 3), 0.0, float(cx - self.tower), float(cy), 6.0);
        guards(build, climb, [[float(cx) + 0.5, float(self.wide) - 3.0], [float(self.long) - 2.5, float(cy) + 4.5]], self.tower, JAIL1_FOES.squad(dice, self.danger, 2), 270.0);
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * 4.0, 0, JAIL1_FOES.pick(dice, self.danger, index == 0), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.tower, JAIL1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(3.5, float(self.wide) - 3.0, self.tower, "monster_infantry", 0.0, patrol=[[3.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.foe(float(cx) + 6.5, 4.5, 12, JAIL1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(float(cx) - 1.5, float(cy) + 1.5, self.tower, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.5, 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The channels under the moat: walkways along a flooded channel crossed
by bridges, a guard post over the far end."""
node MoatTunnels(Prefab) {
    has post: int = 12,
        by_lift: bool = False,
        grate: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Moat tunnels";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(36, 38);
        self.wide = dice.between(19, 21);
        self.by_lift = dice.chance(0.45);
        self.grate = dice.chance(0.7);
        self.tall = self.post + 7;
        self.low = -16;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.post),
            Port(face=1, along=7.0, floor=0),
            Port(face=3, along=float(self.long - 3), floor=self.post)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tunnel, self.post);
        # The channel down the middle, steps up out of it at its near end;
        # bridges across it a lift over the water.
        cx1 = self.long - 8;
        build.pool(4, cy - 3, -14, cx1, cy + 4, 0, 2);
        # (The steps out of the channel climb its first fourteen cells.)
        for bx in [19, cx1 - 4] {
            build.solid(bx, cy - 3, -1, bx + 3, cy + 4, 0);
            for x in range(bx, bx + 3) {
                build.keep(tunnel, x, cy - 4, 0);
                build.keep(tunnel, x, cy + 4, 0);
            }
        }
        # A cistern under the north walkway, flooded, opening off the
        # channel under the water.
        build.room(13, cy + 4, -14, cx1 - 1, self.wide - 2, -3);
        for z in range(-14, -3) {
            for y in range(cy + 4, self.wide - 2) {
                for x in range(13, cx1 - 1) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        build.supply(float(cx1) - 2.5, float(self.wide) - 3.5, -14, "ammo_cells", "q2");
        # A nook under the south walkway, open to the channel under the
        # water, behind a grate that breaks (a secret), or open.
        build.room(21, cy - 6, -14, 24, cy - 3, -11);
        for z in range(-14, -11) {
            for y in range(cy - 6, cy - 3) {
                for x in range(21, 24) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        if self.grate {
            build.breakable(21.0, float(cy - 4), -14.0, 24.0, float(cy - 3), -11.0, 15);
        }
        build.secret(21.0, float(cy - 6), -14.0, 24.0, float(cy - 4), -12.0);
        build.supply(22.5, float(cy) - 5.5, -14, "ammo_rockets", "q2");
        # The guard post over the far end, a slab over the floor, up a stair
        # along the south wall or a lift.
        gx = self.long - 8;
        build.solid(gx, 1, self.post - 1, self.long - 1, self.wide - 1, self.post);
        if self.by_lift {
            post_button(build, gx - 4, 4, 0, 1) +>:Fires:+> called_lift(build, gx - 3, 1, gx, 4, 0, self.post);
        } else {
            stair(build, gx - self.post, 1, 0, 0, self.post, 3);
        }
        keep_row(build, tunnel, gx, 1, self.post, 0, 3);
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.6);
        # Crossing the far bridge, guards appear on the post.
        crossing = build.touch(float(cx1 - 4), float(cy - 3), 0.0, float(cx1 - 1), float(cy + 4), 6.0);
        guards(build, crossing, [[float(self.long) - 3.5, float(cy) + 0.5], [float(self.long) - 3.5, float(self.wide) - 3.5]], self.post, JAIL1_FOES.squad(dice, self.danger, 2, True), 180.0);
        build.foe(3.5, 2.5, 0, "monster_infantry", 0.0, patrol=[[3.5, 2.5], [float(self.long) - 21.5, 2.5]]);
        build.foe(float(cx1) - 2.5, float(self.wide) - 2.5, 0, "monster_infantry", 180.0, patrol=[[float(cx1) - 2.5, float(self.wide) - 2.5], [5.5, float(self.wide) - 2.5]]);
        build.foe(float(gx) + 1.5, float(cy) + 0.5, 0, JAIL1_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.post, Q2_HEALTH, "q2");
        sparking(build, 6.5, float(self.wide) - 1.2, 5.0, 3, 3.0);
        sparking(build, float(cx1) - 1.5, 1.2, 5.0, 1, 4.5);
    }
}

"""The key room: a hall, the warden's office on a balcony over it, the
key on his desk; taking it opens the cells and switches on lasers."""
node WardenOffice(Prefab) {
    has key: str = "key_silver",
        office: int = 7,
        by_lift: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Warden office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(22, 25);
        self.wide = dice.between(22, 24);
        self.office = dice.between(6, 7);
        self.by_lift = dice.chance(0.4);
        self.tall = self.office + 8;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide + 4) // 2 - 1), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = 4;
        middle = (self.wide + 4) // 2 - 1;
        hall = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.office);
        build.doorway(hall, self.enter);
        # The office: a balcony along the north wall over the hall, up a
        # stair at its near end or a lift called down.
        oy = self.wide - 6;
        build.solid(5 + self.office, oy, self.office - 1, self.long - 1, self.wide - 1, self.office);
        if self.by_lift {
            post_button(build, 1 + self.office, oy - 2, 0, 3) +>:Fires:+> called_lift(build, 2 + self.office, oy, 5 + self.office, oy + 3, 0, self.office);
        } else {
            stair(build, 5, self.wide - 4, 0, 0, self.office, 3);
        }
        keep_row(build, hall, 5 + self.office, oy, self.office, 0, 3);
        # The desk at the balcony's far end, the key before it; taking it
        # opens the cells along the near wall, switches on lasers across the
        # hall and brings guards in.
        build.solid(self.long - 3, oy + 1, self.office, self.long - 2, self.wide - 2, self.office + 2);
        taken = key_cue(build, self.key, float(self.long) - 4.5, float(oy) + 2.5, self.office);
        closets(build, taken, [3, 8, 13] if dice.chance(0.5) else [4, 11], side, -1, 0, JAIL1_FOES.squad(dice, self.danger, 3, True), 90.0);
        for x in [8.5, 14.5] {
            taken +>:Fires:+> laser(build, x, float(side) + 1.2, 2.0, 1, False);
        }
        taken +>:Fires:+> build.objective("The warden's key. The alarm is up");
        guards(build, taken, [[2.5, float(self.wide) - 6.5]], 0, JAIL1_FOES.squad(dice, self.danger, 1), 0.0);
        build.foe(float(self.long) - 6.5, float(self.wide) - 2.5, self.office, JAIL1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(4.5, float(middle) - 1.5, 0, "monster_infantry", 0.0, patrol=[[4.5, float(middle) - 1.5], [float(self.long) - 3.5, float(middle) - 1.5]]);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(middle) - 2.5, 3.0, 2, 5.0);
    }
}

"""The end: a door, a cell block of two tiers, galleries along both walls
joined by a bridge, the way out at the far end."""
node CellBlock(Prefab) {
    has key: str = "",
        gallery: int = 9,
        out_high: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell block" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL1;
        self.district = level_district(JAIL1);
        self.long = dice.between(28, 31);
        self.wide = dice.between(22, 24);
        self.out_high = dice.chance(0.45);
        self.tall = self.gallery + 12;
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
        wall = 7;
        g = self.gallery;
        block = gate_pair(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(block, g);
        # The galleries along both walls, a slab over the aisle and the
        # ground cells; cell walls on both tiers.
        for south in [True, False] {
            y0 = 1 if south else self.wide - 7;
            build.solid(wall + 1, y0, g - 1, self.long - 1, y0 + 6, g);
            cell_y = 1 if south else self.wide - 4;
            for x in range(wall + 4, self.long - 1, 4) {
                build.solid(x, cell_y, 0, x + 1, cell_y + 3, g - 1);
                build.solid(x, cell_y, g, x + 1, cell_y + 3, g + 6);
            }
        }
        # A stair up to the south gallery at the near end, a bridge across
        # to the north one.
        stair(build, wall + 3, 7, 0, 0, g, 3);
        mid = (wall + self.long) // 2;
        build.solid(mid, 7, g - 1, mid + 3, self.wide - 7, g);
        keep_row(build, block, mid, 6, g, 1, 3);
        keep_row(build, block, mid, self.wide - 7, g, 1, 3);
        # The way out at the far end: on the floor, or on the far gallery.
        if self.out_high {
            build.way_out(float(self.long) - 3.0, float(self.wide) - 4.0, g);
        } else {
            build.way_out(float(self.long) - 3.0, float(middle), 0);
        }
        # Reaching the bridge opens the upper cells: guards come out.
        on_bridge = build.touch(float(mid), 7.0, float(g), float(mid + 3), float(self.wide - 7), float(g + 6));
        for (index, x) in enumerate(range(wall + 5, self.long - 4, 8)) {
            door = build.opened(float(x), 4.0, float(g), float(x + 3), 5.0, float(g + 6));
            on_bridge +>:Fires:+> door;
            build.solid(x - 1, 1, g, x, 4, g + 6);
            build.foe(float(x) + 1.5, 2.5, g, JAIL1_FOES.pick(dice, self.danger, index == 0), 90.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, JAIL1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 3.5, float(middle) + 0.5, 0, "monster_infantry", 0.0, patrol=[[float(wall) + 3.5, float(middle) + 0.5], [float(self.long) - 5.5, float(middle) + 0.5]]);
        build.foe(float(self.long) - 4.5, float(self.wide) - 5.5, g, JAIL1_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 1.2, float(middle) + 3.5, 3.0, 2, 4.0);
    }
}

"""jail1's stretches: [name, role]."""
glob JAIL1_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["grid", "flow"],
         ["gatehouse", "flow"],
         ["tower", "hub"],
         ["tower", "flow"],
         ["tunnels", "flow"],
         ["tunnels", "hub"],
         ["warden", "keyroom"],
         ["cells", "end"],
         ["cells", "gate"]
     ];

"""One of jail1's stretches by its name."""
def make_jail1(name: str, key: str) -> Prefab {
    if name == "approach" {
        return PrisonApproach();
    }
    if name == "grid" {
        return SecurityGrid();
    }
    if name == "gatehouse" {
        return Gatehouse();
    }
    if name == "tower" {
        return GuardTowerYard();
    }
    if name == "tunnels" {
        return MoatTunnels();
    }
    if name == "warden" {
        return WardenOffice(key=key if key else "key_silver");
    }
    return CellBlock(key=key);
}
