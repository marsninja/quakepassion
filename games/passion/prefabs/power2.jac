"""Prefabs drawn from Quake II's power2, the Reactor: a lobby under a
control balcony with a laser fence below it, coolant channels with walks
and a gantry along them, the core chamber whose two conduits must be shot
out to expose it, a vent shaft of floors stacked over each other climbed
on updrafts, the data vault, the meltdown run along a catwalk over slime.
Raised in power2's own palette.

- `ReactorLobby`: the start. A lobby, a coolant pit of slime across its
  middle with a walkway over it, the control balcony across its far end
  up one stair or two; a laser fence across the way out under the
  balcony, switched off by a button on it. The help computer gives the
  mission (power2's coolant objective); guards appear on the balcony as
  the player nears its stair; a panel by the door breaks on a stash.
- `CoolantChannel`: a deep channel of coolant (water, or slime in the hot
  runs) down a hall, walks along both sides, a gantry over one walk up a
  stair, a bridge across, and sometimes a second drawn out by a button.
  Charges go off along the channel as the player gets halfway; flyers
  come in over it.
- `CoreChamber`: a hub. The core standing in a moat of slime, bridges over
  the moat, a gallery along the walls up a stair, lasers over the moat's
  corners. The two conduits on the core's faces, shot out (power2's
  counter of two), set off a chain of blasts, shake the chamber, drop the
  lasers, bring the guards and open the ways on.
- `VentShaft`: three floors stacked in a shaft, each open where the next
  is not, climbed by updrafts (power2's trigger_push) and lifts, or
  dropped down through; entered at the top or the bottom.
- `DataVault`: the key room. Racks on a server floor under a mezzanine,
  the key on the mezzanine up a lift (or a stair); taking it opens the
  closets below; the mezzanine's touch sets off charges.
- `MeltdownRun`: the end. A door (a key's, as a gate), then a catwalk over
  slime far below to the way out; as the player crosses, the reactor's
  blasts follow and the floor shakes."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, shelling, stash, crate_pile, squad, keep_box, plat, port_door, hurting, laser, quake }

glob POWER2: str = "q2:power2";

"""power2's foes: gunners and berserkers, iron maidens and flyers,
gladiators deeper in."""
glob POWER2_FOES: FoeMix = FoeMix(light=["monster_gunner", "monster_berserk", "monster_chick"], strong=["monster_gladiator"], heavy_light=["monster_gladiator", "monster_berserk"], scale=0.5, heavy_scale=0.4, flying="monster_flyer");

"""The start: a lobby, a slime pit across it, the control balcony across
its far end, a laser fence under the balcony."""
node ReactorLobby(Prefab) {
    has balcony: int = 8,
        tall: int = 18,
        twin: bool = False,
        pit: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor lobby";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(31, 35);
        self.wide = dice.between(20, 24);
        self.balcony = dice.between(8, 9);
        self.tall = self.balcony + dice.between(9, 11);
        self.twin = dice.chance(0.5);
        self.pit = dice.chance(0.7);
        self.low = -5;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.balcony), Port(face=1, along=float(self.long - 4), floor=self.balcony), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        b = self.balcony;
        lobby = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(lobby, b);
        # The control balcony across the far end, its stairs up the walls.
        bx = self.long - 8;
        build.solid(bx, 1, b - 1, self.long - 1, self.wide - 1, b);
        stair(build, bx - b, 1, 0, 0, b, 3);
        if self.twin {
            stair(build, bx - b, self.wide - 4, 0, 0, b, 3);
        }
        # The coolant pit across the middle, slime, a walkway over it.
        if self.pit {
            x0 = 9;
            x1 = bx - b - 2;
            if x1 - x0 >= 5 {
                build.pool(x0, cy - 3, -4, x1, cy + 4, 0, 3, False, True, True);
                hurting(build, float(x0), float(cy - 3), -4.0, float(x1), float(cy + 4), -1.0, 10);
                walk_x = (x0 + x1) // 2 - 1;
                build.solid(walk_x, cy - 3, -1, walk_x + 3, cy + 4, 0);
                keep_box(build, lobby, walk_x, cy - 4, walk_x + 3, cy + 5, 0);
            }
        }
        # A block by the way in, a stash in it behind a panel.
        build.solid(6, self.wide - 5, 0, 10, self.wide - 1, 6);
        stash(build, self.wide - 5, 7, 0, False, -1, "item_pack");
        open_ways(build, lobby, self);
        # The laser fence under the balcony and its switch on the balcony.
        fence: list[Cue] = [];
        for z in [1.0, 2.5]{
            fence.append(laser(build, float(self.long) - 4.5, 1.1, z, float(self.long) - 4.5, float(self.wide) - 1.1, z));
        }
        control = build.push(float(self.long) - 1.0, float(cy) + 4.5, float(b) + 1.2, 2);
        for beam in fence {
            control +>:Fires:+> beam;
        }
        build.touch(float(bx - 3), 5.0, 0.0, float(bx - 2), float(self.wide - 5), 6.0, True, "The laser fence is switched from the balcony");
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        mission = build.touch(1.0, float(cy - 3), 0.0, 5.0, float(cy + 3), 8.0);
        mission +>:Fires:+> build.objective("Shut down the reactor");
        mission +>:Fires:+> build.objective("Go to the Cooling Facility.\nLower coolant for reactor.", False);
        # Guards appear on the balcony as the player nears its stair.
        near = build.touch(float(bx - b - 2), 1.0, 0.0, float(bx - b), float(self.wide - 1), 6.0);
        squad(build, near, [[float(self.long) - 4.5, float(cy) - 3.5, float(b)], [float(self.long) - 3.5, float(cy) + 2.5, float(b)]], [POWER2_FOES.pick(dice, self.danger), POWER2_FOES.pick(dice, self.danger, True)], 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(bx) + 0.5, 1.2, float(b) - 2.5, 1);
        # Up on the balcony a panel blows and flyers come in over the lobby.
        above = build.touch(float(bx), 1.0, float(b), float(bx + 2), float(self.wide - 1), float(b + 6));
        above +>:Fires:+> build.explosion(float(bx) + 1.0, float(self.wide) - 2.0, float(b) + 3.0);
        squad(build, above, [[float(bx) - 6.5, float(cy) + 0.5, float(b)]], ["monster_flyer"], 0.0);
        crate_pile(build, bx + 1, self.wide - 3, 0, 0, 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx - 4 - index * 3) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, POWER2_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(bx) + 1.5, 3.0, 0, "monster_gunner", 90.0, patrol=[[float(bx) + 1.5, 3.0], [float(bx) + 1.5, float(self.wide) - 6.0]]);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, b, Q2_HEALTH, "q2");
    }
}

"""A deep channel of coolant down a hall, walks along both sides, a gantry
over one walk."""
node CoolantChannel(Prefab) {
    has gantry: int = 9,
        tall: int = 18,
        deep: int = 6,
        slime: bool = False,
        bridge_x: int = 16,
        drawn_x: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Coolant channel";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(30, 36);
        self.wide = dice.between(19, 22);
        self.gantry = dice.between(9, 10);
        self.tall = self.gantry + dice.between(8, 10);
        self.deep = 6;
        self.slime = dice.chance(0.5);
        self.bridge_x = dice.between(self.long // 2 - 3, self.long - 9);
        self.drawn_x = dice.between(8, self.bridge_x - 6) if dice.chance(0.6) and self.bridge_x - 6 >= 8 else 0;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.5, floor=0);
        self.leaves = [Port(face=0, along=3.5, floor=0), Port(face=0, along=float(self.wide) - 3.0, floor=self.gantry), Port(face=1, along=float(self.long - 8), floor=0), Port(face=3, along=float(self.long - 8), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        g = self.gantry;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The channel down the middle, its steps up at the near end.
        code = 3 if self.slime else 2;
        build.pool(1, cy - 3, -self.deep, self.long - 1, cy + 3, 0, code, False, True, True);
        if self.slime {
            hurting(build, 1.0, float(cy - 3), float(-self.deep), float(self.long // 2), float(cy + 3), -1.0, 8);
            hurting(build, float(self.long // 2), float(cy - 3), float(-self.deep), float(self.long - 1), float(cy + 3), -1.0, 8);
        }
        # The bridge across, and the one a button draws out.
        build.solid(self.bridge_x, cy - 3, -1, self.bridge_x + 3, cy + 3, 0);
        keep_box(build, hall, self.bridge_x, cy - 4, self.bridge_x + 3, cy + 4, 0);
        if self.drawn_x > 0 {
            press = build.push(float(self.drawn_x) + 4.5, 1.0, 1.2, 1);
            press +>:Fires:+> build.drawn(float(self.drawn_x), float(cy - 3), float(self.drawn_x + 3), float(cy + 3), 0, self.deep + 1);
            keep_box(build, hall, self.drawn_x, cy - 4, self.drawn_x + 3, cy + 4, 0);
            build.touch(float(self.drawn_x - 2), 1.0, 0.0, float(self.drawn_x), float(cy - 3), 6.0, True, "A switch on the wall draws the bridge out");
        }
        # The gantry over the far walk, its stair at the near end.
        build.solid(11, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        stair(build, 11 - g, self.wide - 5, 0, 0, g, 4);
        open_ways(build, hall, self);
        # Halfway along, charges go off down the channel; flyers come in.
        halfway = build.touch(float(self.long // 2 - 1), 1.0, 0.0, float(self.long // 2 + 1), float(cy - 3), 6.0);
        charges(build, halfway, [[float(self.long // 2 + 3), float(cy), -1.0], [float(self.long // 2 + 7), float(cy), -1.0], [float(self.long // 2 + 11), float(cy), -1.0]], 0.3);
        squad(build, halfway, [[float(self.long) - 6.5, float(cy) - 1.0, 4.0], [float(self.long) - 9.5, float(cy) + 1.0, 5.0]], ["monster_flyer"], 180.0);
        up = build.touch(10.0, float(self.wide - 5), float(g), 13.0, float(self.wide - 1), float(g + 6));
        squad(build, up, [[float(self.long) - 4.5, float(self.wide) - 3.0, float(g)]], [POWER2_FOES.pick(dice, self.danger, True)], 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(self.long) - 1.2, float(cy) - 4.0, 2.5, 2);
        sparking(build, dice.uniform(4.0, 6.0), 11.5, float(self.wide) - 5.2, float(g) - 2.0, 3);
        crate_pile(build, 13, self.wide - 3, 0, 0, 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, float(cy) + (4.5 if index % 2 == 0 else -4.5), 0, POWER2_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(4.5, float(cy) + 4.5, 0, "monster_berserk", 0.0, patrol=[[4.5, float(cy) + 4.5], [float(self.long) - 4.5, float(cy) + 4.5]]);
        build.foe(float(self.long) - 6.5, float(self.wide) - 3.0, g, POWER2_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(cy) + 4.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 3.0, g, "ammo_bullets", "q2");
    }
}

"""The core in a moat of slime, bridges over the moat, a gallery up a
stair; its two conduits shot out expose it and open the ways on."""
node CoreChamber(Prefab) {
    has gallery: int = 9,
        tall: int = 20,
        wrap: bool = False,
        bridges: list[int] = [];

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Core chamber";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(32, 35);
        self.wide = dice.between(30, 33);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(10, 12);
        self.wrap = dice.chance(0.5);
        self.bridges = [2] + [face for face in [0, 1, 3] if dice.chance(0.55)];
        if len(self.bridges) == 1 {
            self.bridges.append(0);
        }
        self.low = -4;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=float(self.wide - 8), floor=self.gallery), Port(face=3, along=float(self.long // 2 - 8), floor=0)];
        if self.wrap {
            self.leaves.append(Port(face=1, along=float(self.long // 2), floor=self.gallery));
        } else {
            self.leaves.append(Port(face=1, along=float(self.long // 2 - 6), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The moat: four strips of slime round the core's platform.
        strips = [[cx - 7, cy - 7, cx + 7, cy - 4], [cx - 7, cy + 4, cx + 7, cy + 7], [cx - 7, cy - 4, cx - 4, cy + 4], [cx + 4, cy - 4, cx + 7, cy + 4]];
        for strip in strips {
            build.pool(strip[0], strip[1], -3, strip[2], strip[3], 0, 3);
            hurting(build, float(strip[0]), float(strip[1]), -3.0, float(strip[2]), float(strip[3]), -1.0, 10);
        }
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.tall);
        # Bridges over the moat (face 2 always, the way in's side).
        for face in self.bridges {
            if face == 2 {
                build.solid(cx - 7, cy - 1, -1, cx - 4, cy + 2, 0);
            } elif face == 0 {
                build.solid(cx + 4, cy - 1, -1, cx + 7, cy + 2, 0);
            } elif face == 1 {
                build.solid(cx - 1, cy + 4, -1, cx + 2, cy + 7, 0);
            } else {
                build.solid(cx - 1, cy - 7, -1, cx + 2, cy - 4, 0);
            }
        }
        # The gallery along the far wall (and the high wall), its stair.
        build.solid(self.long - 5, 1, g - 1, self.long - 1, self.wide - 1, g);
        if self.wrap {
            build.solid(1, self.wide - 5, g - 1, self.long - 5, self.wide - 1, g);
        }
        stair(build, self.long - 5 - g, 1, 0, 0, g, 4);
        open_ways(build, hall, self);
        # Lasers over the moat's corners.
        beams: list[Cue] = [];
        for corner in [[-1, -1], [1, -1], [-1, 1], [1, 1]] {
            beams.append(laser(build, float(cx) + float(corner[0]) * 4.2, float(cy) + float(corner[1]) * 4.2, 0.6, float(cx) + float(corner[0]) * 6.8, float(cy) + float(corner[1]) * 6.8, 0.6));
        }
        # The two conduits on the core's faces: shot out together, they
        # expose the core.
        both = build.tally(2, "Conduit destroyed");
        build.push(float(cx), float(cy - 2), 4.0, 3, True) +>:Fires:+> both;
        build.push(float(cx), float(cy + 2), 4.0, 1, True) +>:Fires:+> both;
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0, True, "Destroy the two conduits feeding the core");
        charges(build, both, [[float(cx) - 2.2, float(cy) - 1.0, 3.0], [float(cx) + 2.2, float(cy) + 1.0, 6.0], [float(cx), float(cy) - 2.2, 9.0], [float(cx), float(cy) + 2.2, 12.0]], 0.3);
        both +>:Fires:+> quake(build, float(cx), float(cy), 4.0, 4);
        both +>:Fires:+> build.objective("Reactor core exposed.\nProceed.", False);
        for beam in beams {
            both +>:Fires:+> beam;
        }
        for port in self.taken {
            port_door(build, self, port, both);
        }
        late = build.delay(1.5);
        both +>:Fires:+> late;
        squad(build, late, [[float(self.long) - 3.0, float(cy) + 3.5, float(g)], [float(cx) + 9.5, float(cy) - 9.5, 0.0], [float(cx) - 9.5, float(cy) + 9.5, 0.0]], [POWER2_FOES.pick(dice, self.danger, True), POWER2_FOES.pick(dice, self.danger)], 180.0);
        up = build.touch(float(self.long - 6), 1.0, float(g), float(self.long - 1), 5.0, float(g + 6));
        squad(build, up, [[float(self.long) - 3.0, float(self.wide) - 4.5, float(g)]], [POWER2_FOES.pick(dice, self.danger)], 270.0);
        pulse = build.timer(dice.uniform(4.0, 6.0));
        pulse +>:Fires:+> build.sparks(float(cx) - 2.2, float(cy) + 1.5, 2.0, 2);
        pulse +>:Fires:+> build.sparks(float(cx) + 2.2, float(cy) - 1.5, 2.0, 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 3 + index * 3) + 0.5, float(cy) + 3.0, 0, POWER2_FOES.pick(dice, self.danger), 270.0);
        }
        build.foe(float(self.long) - 3.0, 4.5, g, "monster_gunner", 90.0, patrol=[[float(self.long) - 3.0, 4.5], [float(self.long) - 3.0, float(self.wide) - 4.5]]);
        build.foe(float(cx) + 0.5, float(cy) + 9.5, 6, "monster_flyer", 270.0);
        build.supply(float(cx) - 3.0, float(cy) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "ammo_cells", "q2");
        build.supply(3.0, 3.0, 0, "ammo_rockets", "q2");
    }
}

"""Three floors stacked in a shaft, each open where the next is not,
climbed by updrafts and lifts."""
node VentShaft(Prefab) {
    has first: int = 9,
        second: int = 18,
        tall: int = 26,
        flip: bool = False,
        pads: bool = True,
        freight: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vent shaft";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(20, 23);
        self.wide = dice.between(16, 19);
        self.first = 9;
        self.second = 18;
        self.tall = self.second + dice.between(8, 9);
        self.flip = dice.chance(0.4);
        self.pads = dice.chance(0.65);
        self.freight = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        if self.flip {
            # Entered at the top, left at the foot.
            self.enter = Port(face=2, along=cy, floor=self.second);
            self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.first), Port(face=3, along=float(self.long // 2), floor=0)];
        } else {
            self.enter = Port(face=2, along=cy, floor=0);
            self.leaves = [Port(face=0, along=cy, floor=self.second), Port(face=0, along=cy, floor=0), Port(face=1, along=3.0, floor=self.first), Port(face=3, along=float(self.long - 5), floor=self.second)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        f1 = self.first;
        f2 = self.second;
        open_x = self.long - 8;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, f1);
        build.level(shaft, f2);
        if not self.flip {
            # The first floor over the near end, the second over the far.
            build.solid(1, 1, f1 - 1, open_x, self.wide - 1, f1);
            build.solid(8, 1, f2 - 1, self.long - 1, self.wide - 1, f2);
            plat(build, shaft, open_x, self.wide - 4, open_x + 3, self.wide - 1, 0, f1);
            if self.freight {
                build.train([3.0, 3.0, 1.0], [[5.0, float(self.wide - 4), float(f1)], [5.0, float(self.wide - 4), float(f2 - 1)]], 60.0, 3.0);
                keep_box(build, shaft, 8, self.wide - 4, 9, self.wide - 1, f2);
            } else {
                plat(build, shaft, 5, self.wide - 4, 8, self.wide - 1, f1, f2);
            }
            if self.pads {
                build.jump_pad(float(open_x) + 3.0, float(cy) + 0.5, 0, float(open_x) - 3.0, float(cy) + 0.5, f1);
                keep_box(build, shaft, open_x - 1, cy - 2, open_x, cy + 3, f1);
                build.jump_pad(5.0, float(cy) + 0.5, f1, 11.0, float(cy) + 0.5, f2);
                keep_box(build, shaft, 8, cy - 2, 9, cy + 3, f2);
            }
            touched = build.touch(1.0, 1.0, float(f1), float(open_x), float(self.wide - 1), float(f1 + 6));
        } else {
            # Entered over the near end at the top: the second floor over
            # the near end, the first over the far, each edge walked off.
            build.solid(1, 1, f2 - 1, open_x, self.wide - 1, f2);
            build.solid(8, 1, f1 - 1, self.long - 1, self.wide - 1, f1);
            keep_box(build, shaft, open_x - 1, 3, open_x, self.wide - 4, f2);
            keep_box(build, shaft, 8, 3, 9, self.wide - 4, f1);
            plat(build, shaft, 5, self.wide - 4, 8, self.wide - 1, 0, f1);
            if self.freight {
                build.train([3.0, 3.0, 1.0], [[float(open_x), float(self.wide - 4), float(f1)], [float(open_x), float(self.wide - 4), float(f2 - 1)]], 60.0, 3.0);
                keep_box(build, shaft, open_x - 1, self.wide - 4, open_x, self.wide - 1, f2);
            } else {
                plat(build, shaft, open_x, self.wide - 4, open_x + 3, self.wide - 1, f1, f2);
            }
            touched = build.touch(8.0, 1.0, float(f1), float(self.long - 1), float(self.wide - 1), float(f1 + 6));
        }
        # A block on the ground floor, a vent's stash in it.
        build.solid(2, 1, 0, 6, 5, 6);
        if dice.chance(0.6) {
            stash(build, 5, 3, 0, False, 1, Q2_ARMOR);
        }
        open_ways(build, shaft, self);
        squad(build, touched, [[float(self.long // 2), float(cy) - 2.0, float(f1 + 3)], [float(self.long // 2) + 2.0, float(cy) + 3.0, float(f2 + 2)]], ["monster_flyer", POWER2_FOES.pick(dice, self.danger, False, True)], 180.0);
        top_floor = build.touch(1.0, 1.0, float(f2), float(self.long - 1), float(self.wide - 1), float(f2 + 6));
        charges(build, top_floor, [[float(self.long // 2), float(cy), float(f1 + 2)], [float(self.long // 2) - 3.0, float(cy) + 3.0, float(f1 + 4)]], 0.4);
        sparking(build, dice.uniform(3.0, 5.0), 1.2, float(cy) + 2.5, float(f1) + 2.0, 0);
        sparking(build, dice.uniform(3.0, 6.0), float(self.long) - 1.2, float(cy) - 2.5, float(f2) + 2.0, 2);
        build.foe(float(self.long) - 4.5, float(cy) + 2.5, 0, POWER2_FOES.pick(dice, self.danger), 180.0);
        build.foe(4.5, float(cy) - 2.5, f1 if not self.flip else f2, POWER2_FOES.pick(dice, self.danger), 0.0);
        far_floor = f2 if not self.flip else f1;
        build.foe(float(self.long) - 4.5, float(cy) - 2.5, far_floor, POWER2_FOES.pick(dice, self.danger, True), 180.0, patrol=[[float(self.long) - 4.5, float(cy) - 2.5], [11.5, float(cy) - 2.5]]);
        build.supply(float(self.long) - 3.0, 3.0, far_floor, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2), float(self.wide) - 3.0, 0, "ammo_grenades", "q2");
    }
}

"""The key room: racks on a server floor under a mezzanine, the key on the
mezzanine up a lift."""
node DataVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        mezzanine: int = 7,
        tall: int = 15,
        stairs: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Data vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(22, 25);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.mezzanine = dice.between(7, 8);
        self.tall = self.mezzanine + 8;
        self.stairs = dice.chance(0.5);
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
        m = self.mezzanine;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, m);
        build.doorway(vault, self.enter);
        # The mezzanine over the far end of the floor.
        mx = self.long - 8;
        build.solid(mx, 1, m - 1, self.long - 1, side, m);
        plat(build, vault, mx - 3, 2, mx, 5, 0, m);
        if self.stairs {
            stair(build, mx - m, side - 4, 0, 0, m, 3);
        }
        # Racks on the server floor, under the mezzanine too.
        for x in range(6, self.long - 3, 4) {
            if x + 1 < mx - 4 or x >= mx + 1 {
                build.solid(x, 6, 0, x + 1, side - 5, 4);
            }
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, m, side, 0, [3, mx - 6], [POWER2_FOES.pick(dice, self.danger, True), POWER2_FOES.pick(dice, self.danger)]);
        coming = build.touch(1.0, float(cy - 2), 0.0, 3.0, float(cy + 3), 8.0);
        squad(build, coming, [[float(mx) - 2.0, float(cy) + 0.5, float(m + 2)]], ["monster_flyer"], 180.0);
        up = build.touch(float(mx), 1.0, float(m), float(mx + 2), float(side), float(m + 6));
        charges(build, up, [[float(mx) - 4.0, float(cy), 3.0], [float(mx) - 8.0, float(cy) + 3.0, 3.0]], 0.4);
        squad(build, up, [[4.5, 3.5, 0.0], [4.5, float(side) - 3.5, 0.0]], [POWER2_FOES.pick(dice, self.danger), "monster_berserk"], 0.0);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, 3.5, float(m) + 2.0, 2);
        build.foe(float(self.long) - 3.5, 3.5, m, POWER2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(mx) + 3.5, 3.5, 0, POWER2_FOES.pick(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, then a catwalk over slime far below to the way out,
the reactor's blasts following the player across."""
node MeltdownRun(Prefab) {
    has key: str = "",
        tall: int = 14,
        deep: int = 9,
        bend: bool = False,
        raised: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Meltdown run" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = POWER2;
        self.district = level_district(POWER2);
        self.long = dice.between(30, 34);
        self.wide = dice.between(18, 22);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(12, 14);
        self.bend = dice.chance(0.5);
        self.raised = dice.chance(0.5);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        build.doorway(hall, self.enter);
        pit = build.room(wall + 1, 1, -self.deep, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.widen(pit, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # Slime far below; the landings at each end, the catwalk between.
        build.pool(wall + 1, 1, -self.deep, self.long - 1, self.wide - 1, -self.deep + 3, 3, True, False);
        third = (self.long - wall - 2) // 3;
        for part in range(3) {
            hurting(build, float(wall + 1 + part * third), 1.0, float(-self.deep), float(wall + 1 + (part + 1) * third if part < 2 else self.long - 1), float(self.wide - 1), float(-self.deep + 3), 20);
        }
        build.solid(wall + 1, 1, -self.deep + 3, wall + 4, self.wide - 1, 0);
        far = self.long - 10;
        build.solid(far, 1, -self.deep + 3, self.long - 1, self.wide - 1, 0);
        if self.bend {
            # A dog-leg: out along the low wall, across, along the high.
            mid = (wall + 4 + far) // 2;
            build.solid(wall + 4, cy - 1, -1, mid, cy + 2, 0);
            build.solid(mid, 3, -1, mid + 3, cy + 2, 0);
            build.solid(mid, 3, -1, far, 6, 0);
        } else {
            build.solid(wall + 4, cy - 1, -1, far, cy + 2, 0);
        }
        top = 0;
        if self.raised {
            top = 4;
            build.solid(self.long - 6, cy - 3, 0, self.long - 2, cy + 3, 4);
            stair(build, self.long - 10, cy - 1, 0, 0, 4, 3);
            keep_box(build, pit, self.long - 6, cy - 1, self.long - 5, cy + 2, 4);
        }
        build.way_out(float(self.long) - 4.0, float(cy), top);
        # Across the catwalk the blasts follow; at the end the floor shakes.
        onto = build.touch(float(wall + 4), float(cy - 1), 0.0, float(wall + 6), float(cy + 2), 6.0);
        charges(build, onto, [[float(wall + 3), 2.0, -2.0], [float(wall + 3), float(self.wide) - 2.0, -2.0], [float(wall + 9), 3.0, -4.0], [float(wall + 13), float(self.wide) - 3.0, -4.0], [float(far - 2), 3.0, -4.0]], 0.5);
        midway = build.touch(float(far - 4), 1.0, 0.0, float(far - 2), float(self.wide - 1), 6.0);
        charges(build, midway, [[float(far) + 2.0, 2.0, 3.0], [float(far) + 2.0, float(self.wide) - 2.0, 3.0]], 0.3);
        midway +>:Fires:+> build.sparks(float(far) - 3.0, 1.2, 3.0, 1);
        landed = build.touch(float(far), 1.0, 0.0, float(far + 2), float(self.wide - 1), 6.0);
        landed +>:Fires:+> quake(build, float(far), float(cy), 2.0, 3);
        squad(build, landed, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 3.5, float(self.wide) - 3.5, 0.0]], [POWER2_FOES.pick(dice, self.danger, True), POWER2_FOES.pick(dice, self.danger)], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, POWER2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(far) - 6.5, float(cy) + 5.5, 4, "monster_flyer", 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""power2's stretches: [name, role]."""
glob POWER2_STRETCHES: list[list[str]] = [
         ["lobby", "start"],
         ["channel", "flow"],
         ["vents", "flow"],
         ["core", "hub"],
         ["channel", "hub"],
         ["vault", "keyroom"],
         ["meltdown", "end"],
         ["meltdown", "gate"]
     ];

"""One of power2's stretches by its name."""
def make_power2(name: str, key: str) -> Prefab {
    if name == "lobby" {
        return ReactorLobby();
    }
    if name == "channel" {
        return CoolantChannel();
    }
    if name == "vents" {
        return VentShaft();
    }
    if name == "core" {
        return CoreChamber();
    }
    if name == "vault" {
        return DataVault(key=key if key else "key_silver");
    }
    return MeltdownRun(key=key);
}
