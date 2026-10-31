"""Prefabs drawn from Quake II's waste2, Pumping Station One: terraces down
into the station under a gallery, the station's great pump hall whose two
pistons start when it is switched on, filter beds under a walkway, a
gallery of stairs winding up over themselves, the pump control room, the
lift up to the way out. Raised in waste2's own palette.

- `StationEntry`: the start. Terraces stepping down into the station, a
  gallery along one wall over them with a gap to drop through; guards
  appear on the lowest terrace as the player comes down; a stash behind a
  panel in a block on the lowest terrace.
- `PumpStation`: a hub. Two great pistons in a pit of water, a control
  platform up a lift, a catwalk across the hall over the pistons up a
  stair, joined to the platform. The switch on the control wall starts the
  station (waste2's "Pumping Station One activated"): the pistons drive,
  the water sprays, the ways on open and guards come. A switch shot high
  on the platform's face blows a panel off a stash (waste2's shot secret).
- `FilterBeds`: deep beds of water across a hall, swum under the planks over them, a
  walkway along the high wall over its walk, up a stair, or thrown up to
  by a pad in some seeds.
- `ValveGallery`: a narrow gallery of stairs winding up over a flooded well,
  two flights or three, landings stacked at its ends, sometimes a lift to
  the first.
- `PumpControl`: the key room. A control deck over the floor of a room, a
  sump of water under it, the key on the deck up a lift or a stair; taking
  it opens the closets.
- `StationExit`: the end. A door (a key's, as a gate), then a shaft, the
  way out on a platform high at its end, up a tall lift (waste2's) or a
  long stair."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, stash, crate_pile, squad, keep_box, plat, port_door }

glob WASTE2: str = "q2:waste2";

"""waste2's foes: gunners and soldiers, flyers and technicians, gladiators
and berserkers deeper in."""
glob WASTE2_FOES: FoeMix = FoeMix(light=["monster_soldier", "monster_gunner", "monster_gunner"], strong=["monster_berserk"], heavy_light=["monster_gladiator", "monster_gunner"], heavy_strong=["monster_gladiator"], scale=0.6, heavy_scale=0.4, flying="monster_flyer", flying_other="monster_floater", flying_odds=0.3);

"""The start: terraces down into the station under a gallery."""
node StationEntry(Prefab) {
    has tall: int = 16,
        first_y: int = 4,
        second_y: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station entry";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(15, 17);
        self.first_y = dice.between(2, self.wide - 9);
        self.second_y = dice.between(2, self.wide - 9);
        self.low = -7;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=cy - 2.0, floor=-6), Port(face=3, along=float(self.long - 10), floor=-6)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, -6, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, -3);
        # The terraces, three lifts apart, stairs down each.
        build.solid(1, 1, -6, 9, self.wide - 1, 0);
        build.solid(9, 1, -6, 16, self.wide - 1, -3);
        stair(build, 11, self.first_y, -3, 2, 3, 3);
        stair(build, 18, self.second_y, -6, 2, 3, 3);
        # The gallery along the high wall over the terraces, a gap in its
        # rail over the lowest to drop through.
        build.solid(9, self.wide - 5, -1, self.long - 1, self.wide - 1, 0);
        keep_box(build, hall, self.long - 9, self.wide - 5, self.long - 6, self.wide - 4, 0);
        # A block on the lowest terrace, a stash behind a panel in it.
        build.solid(self.long - 6, 1, -6, self.long - 1, 5, 0);
        stash(build, 5, self.long - 4, -6, False, 1, Q2_ARMOR);
        open_ways(build, hall, self);
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(cy - 3), 0.0, 5.0, float(cy + 3), 8.0) +>:Fires:+> build.objective("Activate Pumping Station One.");
        # Coming down, guards appear on the lowest terrace.
        down = build.touch(9.0, 1.0, -3.0, 11.0, float(self.wide - 5), 3.0);
        squad(build, down, [[float(self.long) - 8.5, float(cy) - 1.5, -6.0], [float(self.long) - 4.5, float(cy) + 1.5, -6.0]], [WASTE2_FOES.pick(dice, self.danger), WASTE2_FOES.pick(dice, self.danger, True)], 180.0);
        build.foe(10.5, float(self.wide) - 3.0, 0, "monster_soldier", 0.0, patrol=[[10.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.foe(20.5, float(cy) + 0.5, -6, "monster_gunner", 0.0, patrol=[[20.5, float(cy) + 0.5], [float(self.long) - 8.5, float(cy) + 0.5]]);
        build.foe(12.5, float(cy) + 1.5, -3, WASTE2_FOES.pick(dice, self.danger), 180.0);
        sparking(build, dice.uniform(3.0, 5.0), float(self.long) - 1.2, float(cy) - 3.0, -3.0, 2);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The pump hall: two pistons in a pit of water, a control platform, a
catwalk across over the pistons; the station's switch starts it all."""
node PumpStation(Prefab) {
    has control: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump station";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(34, 38);
        self.wide = dice.between(26, 30);
        self.control = dice.between(7, 8);
        self.tall = self.control + dice.between(24, 28);
        self.low = -8;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=cy - 3.0, floor=self.control), Port(face=1, along=cx, floor=self.control), Port(face=3, along=cx, floor=self.control)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        c = self.control;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, c);
        build.level(hall, -7);
        # The pit of water and the pistons in it.
        build.pool(cx - 6, cy - 5, -7, cx + 6, cy + 5, 0, 2, False, True, True);
        pistons = [build.train([3.0, 3.0, 6.0], [[float(cx - 1), float(cy - 4), -7.0], [float(cx - 1), float(cy - 4), -1.0]], 40.0, 1.5, True), build.train([3.0, 3.0, 6.0], [[float(cx - 1), float(cy + 1), -1.0], [float(cx - 1), float(cy + 1), -7.0]], 40.0, 1.5, True)];
        # The control platform, its lift; the catwalk across, its stair,
        # and the walk joining them along the low wall.
        build.solid(self.long - 8, 1, 0, self.long - 1, self.wide - 6, c);
        plat(build, hall, self.long - 11, cy - 1, self.long - 8, cy + 2, 0, c);
        build.solid(cx - 2, 1, c - 1, cx + 2, self.wide - 1, c);
        build.solid(cx + 2, 1, c - 1, self.long - 8, 5, c);
        stair(build, cx - 2 - c, 1, 0, 0, c, 3);
        # A stash in the platform behind a panel a shot switch blows off.
        build.room(self.long - 8, 5, 0, self.long - 5, 8, 4);
        panel = build.breakable(float(self.long - 8), 5.0, 0.0, float(self.long - 7), 8.0, 4.0, 200);
        build.secret(float(self.long - 7), 5.0, 0.0, float(self.long - 5), 8.0, 3.0);
        build.supply(float(self.long) - 6.0, 6.5, 0, "item_adrenaline", "q2");
        # A closet deep in the platform the station's guards teleport out of.
        guards_in = build.summon(self.long - 4, 10, 0, WASTE2_FOES.pick(dice, self.danger, True), float(self.long) - 4.0, 3.0, c, 180.0);
        hidden = build.push(float(self.long - 8), 6.5, 5.5, 2, True);
        hidden +>:Fires:+> panel;
        charges(build, hidden, [[float(self.long) - 9.0, 6.5, 2.0]], 0.3);
        open_ways(build, hall, self);
        # The station's switch: the pistons drive, the water sprays, the
        # ways on open, guards come.
        start = build.push(float(self.long - 1), float(cy) + 3.5, float(c) + 1.2, 2);
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0, True, "The station's switch is on the control platform");
        notice = build.delay(0.2);
        notice.items[0]["message"] = "Pumping Station One\nactivated";
        start +>:Fires:+> notice;
        for piston in pistons {
            start +>:Fires:+> piston;
        }
        start +>:Fires:+> build.sparks(float(cx) - 3.0, float(cy) - 2.0, -1.0, 1);
        start +>:Fires:+> build.sparks(float(cx) + 3.0, float(cy) + 2.0, -1.0, 3);
        for port in self.taken {
            port_door(build, self, port, start);
        }
        late = build.delay(1.5);
        start +>:Fires:+> late;
        late +>:Fires:+> guards_in;
        squad(build, late, [[float(cx) - 9.5, 4.5, 0.0], [float(cx) - 9.5, float(self.wide) - 4.5, 0.0], [float(cx), float(self.wide) - 3.0, float(c)]], [WASTE2_FOES.pick(dice, self.danger, True), WASTE2_FOES.pick(dice, self.danger), "monster_gunner"], 0.0);
        build.foe(float(cx), 3.0, c, "monster_gunner", 90.0, patrol=[[float(cx), 3.0], [float(cx), float(self.wide) - 3.0]]);
        build.foe(4.5, 4.5, 0, "monster_soldier", 0.0, patrol=[[4.5, 4.5], [4.5, float(self.wide) - 4.5], [float(cx) - 8.5, float(self.wide) - 4.5]]);
        build.foe(float(self.long) - 4.5, 3.0, c, WASTE2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 6, WASTE2_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) - 6.0, c, "ammo_rockets", "q2");
    }
}

"""Shallow beds of water across a hall, planks over them, a walkway along
the high wall over its walk."""
node FilterBeds(Prefab) {
    has walk: int = 8,
        tall: int = 17,
        pad: bool = False,
        planks: list[int] = [];

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Filter beds";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(32, 36);
        self.wide = dice.between(20, 24);
        self.walk = dice.between(8, 9);
        self.tall = self.walk + dice.between(14, 18);
        self.pad = dice.chance(0.5);
        self.planks = [dice.between(3, self.wide - 9) for index in range(3)];
        self.low = -8;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy - 2.0, floor=0);
        self.leaves = [Port(face=0, along=cy - 2.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.walk), Port(face=3, along=13.0, floor=0), Port(face=1, along=float(self.long // 2 + 2), floor=self.walk)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        w = self.walk;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, w);
        # The beds, shallow water across the hall short of the high walk,
        # a plank over each.
        beds: list[int] = [];
        x = 6;
        while x + 5 <= self.long - 7 and len(beds) < 3 {
            beds.append(x);
            x += 9;
        }
        for (index, bx) in enumerate(beds) {
            build.pool(bx, 1, -7, bx + 6, self.wide - 5, 0, 2, False, True, True);
            py = self.planks[index];
            build.solid(bx, py, -1, bx + 6, py + 3, 0);
        }
        # The walkway along the high wall, its stair at the near end.
        build.solid(2 + w, self.wide - 5, w - 1, self.long - 1, self.wide - 1, w);
        stair(build, 2, self.wide - 4, 0, 0, w, 3);
        if self.pad and len(beds) >= 2 {
            # A pad between the beds throws the player up onto the walkway.
            gx = beds[1] - 2;
            build.jump_pad(float(gx), float(self.wide - 8), 0, float(gx), float(self.wide - 3), w);
            keep_box(build, hall, gx - 2, self.wide - 5, gx + 3, self.wide - 4, w);
        }
        # A block in the far low corner, a stash behind a panel in it.
        build.solid(self.long - 6, 1, 0, self.long - 1, 5, 6);
        stash(build, 5, self.long - 4, 0, False, 1, "item_adrenaline");
        open_ways(build, hall, self);
        first = build.touch(float(beds[0] - 2), 1.0, 0.0, float(beds[0]), float(self.wide - 5), 6.0);
        squad(build, first, [[float(beds[-1]) + 2.5, float(cy) - 1.0, 5.0], [float(self.long) - 4.5, float(cy) + 2.5, 0.0]], [WASTE2_FOES.pick(dice, self.danger, False, True), WASTE2_FOES.pick(dice, self.danger)], 180.0);
        up = build.touch(float(2 + w), float(self.wide - 5), float(w), float(4 + w), float(self.wide - 1), float(w + 6));
        squad(build, up, [[float(self.long) - 4.5, float(self.wide) - 3.0, float(w)]], [WASTE2_FOES.pick(dice, self.danger, True)], 180.0);
        build.foe(float(self.long) - 6.5, float(self.wide) - 3.0, w, "monster_soldier", 180.0, patrol=[[float(self.long) - 6.5, float(self.wide) - 3.0], [float(4 + w) + 0.5, float(self.wide) - 3.0]]);
        build.foe(3.5, float(self.wide) - 7.0, 0, "monster_gunner", 0.0, patrol=[[3.5, float(self.wide) - 7.0], [3.5, 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(beds[0] + 7 + index * 9) + 0.5, float(cy) - 2.5, 0, WASTE2_FOES.pick(dice, self.danger), 180.0);
        }
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(self.wide) - 3.0, float(w) + 2.0, 2);
        build.supply(float(self.long) - 3.0, float(cy) - 1.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2), float(self.wide) - 3.0, w, "ammo_bullets", "q2");
    }
}

"""A narrow gallery of stairs winding up over themselves, landings stacked
at its ends."""
node ValveGallery(Prefab) {
    has flight: int = 9,
        flights: int = 2,
        tall: int = 26,
        lift_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Valve gallery";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(24, 28);
        self.wide = dice.between(12, 14);
        self.flight = 9;
        self.flights = dice.between(2, 3);
        self.tall = self.flights * self.flight + 8;
        self.lift_up = dice.chance(0.5);
        self.low = -8;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        h = self.flight;
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=h)];
        if self.flights == 2 {
            self.leaves.append(Port(face=1, along=3.5, floor=2 * h));
            self.leaves.append(Port(face=3, along=3.5, floor=2 * h));
        } else {
            self.leaves.append(Port(face=0, along=cy, floor=3 * h));
            self.leaves.append(Port(face=1, along=float(self.long) - 3.5, floor=3 * h));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        h = self.flight;
        gallery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for k in range(1, self.flights + 1) {
            top = k * h;
            build.level(gallery, top);
            if k % 2 == 1 {
                # Up the low band from the near end, a walk on to the far.
                stair(build, 6, 1, top - h, 0, h, 3);
                build.solid(6 + h, 1, top - 1, self.long - 6, 4, top);
                build.solid(self.long - 6, 1, top - 1, self.long - 1, self.wide - 1, top);
            } else {
                # Back up the high band from the far end, a walk on to the
                # near.
                stair(build, self.long - 7, self.wide - 4, top - h, 2, h, 3);
                build.solid(6, self.wide - 4, top - 1, self.long - 6 - h, self.wide - 1, top);
                build.solid(1, 1, top - 1, 6, self.wide - 1, top);
            }
        }
        if self.lift_up {
            plat(build, gallery, self.long - 9, 4, self.long - 6, 7, 0, h);
        }
        # The well under the flights, deep, a stair up out of it.
        build.pool(8, 5, -7, self.long - 10, self.wide - 4, 0, 2, False, False);
        stair(build, 14, 5, -7, 2, 7, 2);
        # A valve's stash behind a panel in the first flight's side.
        stash(build, 4, 11, 0, False, 1, Q2_ARMOR);
        open_ways(build, gallery, self);
        first = build.touch(float(self.long - 6), 1.0, float(h), float(self.long - 4), float(self.wide - 1), float(h + 6));
        far_end = self.long - 3 if self.flights % 2 == 1 else 3;
        squad(build, first, [[float(far_end) + 0.5, float(cy) + 0.5, float(self.flights * h)], [7.5, float(self.wide) - 2.5, float(2 * h)]], [WASTE2_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        build.foe(float(self.long - 8), 2.5, h, "monster_soldier", 180.0, patrol=[[float(self.long - 8), 2.5], [float(7 + h), 2.5]]);
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, 0, WASTE2_FOES.pick(dice, self.danger), 0.0);
        build.foe(float(self.long // 2), float(cy) + 0.5, h + 4, WASTE2_FOES.pick(dice, self.danger, False, True), 0.0);
        sparking(build, dice.uniform(3.0, 5.0), 1.2, float(cy) + 0.5, float(h) + 2.0, 0);
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, h, Q2_HEALTH, "q2");
        build.supply(3.0, float(cy) + 0.5, 0, "ammo_grenades", "q2");
    }
}

"""The key room: a control deck over the floor, a sump of water under it,
the key on the deck."""
node PumpControl(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        deck: int = 6,
        stairs: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump control (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.long = dice.between(22, 25);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.deck = dice.between(7, 8);
        self.stairs = dice.chance(0.5);
        self.low = -6;
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
        dx = self.long - 9;
        build.solid(dx, 1, d - 1, self.long - 1, side, d);
        # The sump under the deck, steps out of it.
        build.pool(dx + 1, cy - 3, -5, self.long - 2, cy + 3, 0, 2, False, True, True);
        if self.stairs {
            stair(build, dx - d, 1, 0, 0, d, 3);
        } else {
            plat(build, room, dx - 3, 2, dx, 5, 0, d);
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, d, side, 0, [3, 9], [WASTE2_FOES.pick(dice, self.danger, True), WASTE2_FOES.pick(dice, self.danger)]);
        up = build.touch(float(dx), 1.0, float(d), float(dx + 2), float(side), float(d + 6));
        squad(build, up, [[4.5, 3.5, 0.0], [4.5, float(side) - 3.5, 0.0]], ["monster_gunner", WASTE2_FOES.pick(dice, self.danger)], 0.0);
        charges(build, up, [[float(dx) - 3.0, float(cy), 3.0]], 0.5);
        build.foe(float(self.long) - 3.5, 3.5, d, WASTE2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(5.5, float(cy) + 0.5, 0, "monster_soldier", 0.0, patrol=[[5.5, float(cy) + 0.5], [float(dx) - 3.5, float(cy) + 0.5]]);
        sparking(build, dice.uniform(4.0, 6.0), float(self.long) - 1.2, float(side) - 3.0, float(d) + 2.0, 2);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a shaft, the way out on a platform high at its end up
a tall lift or a long stair."""
node StationExit(Prefab) {
    has key: str = "",
        height: int = 14,
        stairs: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE2;
        self.district = level_district(WASTE2);
        self.height = dice.between(12, 16);
        self.stairs = dice.chance(0.5);
        self.long = 20 + self.height + dice.between(0, 2);
        self.wide = dice.between(16, 20);
        self.low = -1;
        self.high = self.height + 9;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wall = 8;
        e = self.height;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        build.doorway(hall, self.enter);
        shaft = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, e + 8, variant=dice.below(3));
        build.level(shaft, e);
        build.widen(shaft, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # The platform high at the far end, the way out on it.
        px = self.long - 9;
        build.solid(px, 1, e - 1, self.long - 1, self.wide - 1, e);
        plat(build, shaft, px - 3, cy - 1, px, cy + 2, 0, e);
        if self.stairs {
            stair(build, px - e, 1, 0, 0, e, 3);
        }
        build.way_out(float(self.long) - 4.0, float(cy), e);
        up = build.touch(float(px), 1.0, float(e), float(px + 2), float(self.wide - 1), float(e + 6));
        squad(build, up, [[float(self.long) - 3.5, 3.5, float(e)], [float(px) - 6.5, float(cy) + 3.5, 0.0]], [WASTE2_FOES.pick(dice, self.danger, True), WASTE2_FOES.pick(dice, self.danger)], 180.0);
        charges(build, up, [[float(px) - 2.0, 2.5, float(e - 3)], [float(px) - 2.0, float(self.wide) - 2.5, float(e - 3)]], 0.4);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, WASTE2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px) + 3.5, float(cy) + 0.5, 0, WASTE2_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(px) - 4.5, float(cy) + 0.5, e - 3, WASTE2_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste2's stretches: [name, role]."""
glob WASTE2_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["beds", "flow"],
         ["gallery", "flow"],
         ["station", "hub"],
         ["beds", "hub"],
         ["control", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of waste2's stretches by its name."""
def make_waste2(name: str, key: str) -> Prefab {
    if name == "entry" {
        return StationEntry();
    }
    if name == "beds" {
        return FilterBeds();
    }
    if name == "gallery" {
        return ValveGallery();
    }
    if name == "station" {
        return PumpStation();
    }
    if name == "control" {
        return PumpControl(key=key if key else "key_silver");
    }
    return StationExit(key=key);
}
