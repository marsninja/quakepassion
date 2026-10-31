"""Prefabs drawn from Quake III's q3tourney1, Power Station 0218: a power
station's tall halls on one floor and the works under and over it: a core
ringed by a walk, conduits charged with power in trenches crossed by
catwalks, turbine halls with gantries overhead, consoles sparking, and
the charged fields that burn whoever walks into them (the original's
three hurts). Quake III's arenas hold no foes of their own; q3tourney1's
are army, enforcer, ogre. Raised in q3tourney1's own palette.

- `ControlRoom`: the start. A control room, consoles along one wall (and
  by the seed a desk in its middle), a mezzanine along the other up a
  stair (or a lift), a panel sparking. A few steps in, the mezzanine's
  guard comes to the rail.
- `PowerCore`: the core, a column floor to roof, its foot ringed by a
  charged field, a walk round it high up reached by a stair (from one
  side or up the wall) and a bridge from the walk to the way on (across
  the far end or the side, by the seed); its panels spark.
- `ConduitTrench`: a hall split by a trench of charged conduits, steps
  down into it at both ends, catwalks across it (two or three), and by
  the seed a gantry high across the hall, up a stair along the far wall.
- `TurbineHall`: the hub. Turbine housings down the middle, gantries
  high along both long walls and one crossing between the housings, a
  stair up at one corner and a lift at the other (which corners by the
  seed); the housings' blades burn who comes too close.
- `TransformerVault`: the key room. The key on a dais at the far end up a
  stair (or a lift), charged coils either side of the way up, a catwalk
  from the dais back along the wall over the floor to a drop; taking the
  key opens the closets.
- `ReactorGate`: the end (or a gate, the door a key's). A hall, the
  reactor room: the way out on a dais ringed by a charged channel, a
  bridge (or two) over it; a gallery over the far end."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, lift }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, hurt, wake_later, columns }

glob Q3TOURNEY1: str = "q3:q3tourney1",
     Q3TOURNEY1_LIGHT: list[str] = ["monster_army", "monster_enforcer"],
     Q3TOURNEY1_HEAVY: list[str] = ["monster_ogre"];

"""A foe for q3tourney1's stretches."""
glob STATION_FOES: FoeMix = FoeMix(light=Q3TOURNEY1_LIGHT, strong=Q3TOURNEY1_HEAVY, heavy_light=Q3TOURNEY1_HEAVY, scale=0.5);

"""The start: a control room, consoles, a mezzanine up a stair."""
node ControlRoom(Prefab) {
    has mezz: int = 6,
        side: int = 0,
        use_lift: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control room";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.mezz = dice.between(6, 7);
        self.side = dice.below(2);
        self.use_lift = dice.chance(0.4);
        self.tall = self.mezz + 22;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        my0 = 1 if self.side == 0 else self.wide - 6;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(my0) + 2.5, floor=self.mezz), Port(face=3 if self.side == 0 else 1, along=float(self.long - 5), floor=self.mezz)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        m = self.mezz;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, m);
        # The mezzanine along one wall, and the way up to it along its lip.
        my0 = 1 if self.side == 0 else self.wide - 6;
        lip = my0 + 4 if self.side == 0 else my0;
        sy = my0 + 5 if self.side == 0 else my0 - 3;
        deck(build, 1, my0, self.long - 1, my0 + 5, m, 2);
        if self.use_lift {
            lift(build, self.long - 7, sy, self.long - 4, sy + 3, 0, m);
            keep_box(build, room, self.long - 7, lip, self.long - 4, lip + 1, m);
        } else {
            s0 = dice.between(5, 8);
            stair(build, s0, sy, 0, 0, m, 3);
            keep_box(build, room, s0 + m - 3, lip, s0 + m, lip + 1, m);
        }
        # Consoles along the other wall, a desk in the middle by the seed.
        cy0 = self.wide - 2 if self.side == 0 else 1;
        build.solid(6, cy0, 0, self.long - 6, cy0 + 1, 2);
        if dice.chance(0.5) {
            desk_y = middle + 2 if self.side == 0 else middle - 3;
            build.solid(self.long // 2 - 2, desk_y, 0, self.long // 2 + 2, desk_y + 1, 2);
        }
        build.timer(4.0) +>:Fires:+> build.sparks(float(self.long // 2) + 0.5, float(cy0) + (-0.2 if self.side == 0 else 1.2), 2.5, 3 if self.side == 0 else 1);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(float(self.long) - 3.0, float(my0) + 2.5, m, Q3_ARMOR, "q3");
        build.foe(float(self.long) - 4.5, py + (2.0 if self.side == 0 else -2.0), 0, STATION_FOES.pick(dice, self.danger), 180.0);
        # A few steps in, the mezzanine's guard comes to the rail.
        walked = build.touch(6.0, 1.0, 0.0, 8.0, float(self.wide - 1), 6.0);
        guard = wake_later(build, walked, 1.0);
        build.foe(float(self.long // 2) + 0.5, float(my0) + 2.5, m, STATION_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        build.supply(float(self.long) - 3.0, float(cy0) + (-1.5 if self.side == 0 else 2.5), 0, Q3_HEALTH, "q3");
    }
}

"""The core: a column floor to roof, a charged field round its foot, a
walk round it high up, a stair up and a bridge on."""
node PowerCore(Prefab) {
    has ring: int = 6,
        stair_wall: bool = False,
        bridge_side: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Power core";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.ring = dice.between(6, 7);
        self.stair_wall = dice.chance(0.5);
        self.bridge_side = dice.chance(0.5);
        self.tall = self.ring + 22;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        if self.bridge_side {
            self.leaves = [Port(face=1, along=float(self.long // 2), floor=self.ring), Port(face=3, along=float(self.long - 5), floor=0), Port(face=0, along=4.0, floor=0)];
        } else {
            self.leaves = [Port(face=0, along=middle, floor=self.ring), Port(face=3, along=float(self.long - 5), floor=0), Port(face=1, along=float(self.long - 5), floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        cx = self.long // 2;
        r = self.ring;
        station = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(station, r);
        # The walk round the core, the core through it, the charged field
        # round the core's foot under the walk.
        deck(build, cx - 5, cy - 5, cx + 5, cy + 5, r, 1);
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.tall);
        hurt(build, float(cx - 4), float(cy - 4), 0.0, float(cx + 4), float(cy + 4), 3.0, 5);
        # The way up: a stair straight at the walk's near side, or up the
        # -y wall and a landing out to it.
        if self.stair_wall {
            stair(build, cx - 4 - r, 1, 0, 0, r, 3);
            deck(build, cx - 5, 1, cx - 2, cy - 5, r, 1);
            keep_box(build, station, cx - 5, 1, cx - 4, 4, r);
        } else {
            stair(build, cx - 5 - r, cy + 2, 0, 0, r, 3);
            keep_box(build, station, cx - 5, cy + 2, cx - 4, cy + 5, r);
        }
        # The bridge from the walk to the way on high.
        if self.bridge_side {
            deck(build, cx - 2, cy + 5, cx + 2, self.wide - 1, r, 1);
        } else {
            deck(build, cx + 5, cy - 2, self.long - 1, cy + 2, r, 1);
        }
        build.doorway(station, self.enter);
        for port in self.taken {
            build.doorway(station, port);
        }
        build.timer(3.0) +>:Fires:+> build.sparks(float(cx) + 2.2, float(cy) + 0.5, 3.0, 0);
        build.timer(5.0) +>:Fires:+> build.sparks(float(cx) - 2.2, float(cy) - 0.5, 4.0, 2);
        build.foe(float(cx) + 0.5, float(cy - 4) + 0.5, r, STATION_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, float(cy + 3) + 0.5, r, STATION_FOES.pick(dice, self.danger), 180.0);
        # A guard walks the far side of the hall.
        build.foe(float(cx) + 8.5, 3.5, 0, STATION_FOES.pick(dice, self.danger), 90.0, patrol=[[float(cx) + 8.5, 3.5], [float(cx) + 8.5, float(self.wide) - 3.5]]);
        # Up on the walk, what waits by the ways on comes for the climber.
        up = build.touch(float(cx - 5), float(cy - 5), float(r), float(cx + 5), float(cy + 5), float(r + 6));
        late = wake_later(build, up, 2.0);
        build.foe(float(self.long) - 3.0, 3.0, 0, STATION_FOES.pick(dice, self.danger), 180.0, waits=late);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, 0, STATION_FOES.pick(dice, self.danger), 180.0, waits=late);
        build.supply(float(cx - 4) + 0.5, float(cy - 4) + 0.5, r, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, "ammo_bullets", "q2");
    }
}

"""A hall split by a trench of charged conduits, catwalks across it, a
gantry high across the hall by the seed."""
node ConduitTrench(Prefab) {
    has trench: int = 7,
        gantry: bool = False,
        gx: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Conduit trench";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.trench = dice.between(6, self.wide - 11);
        self.gantry = dice.chance(0.6);
        self.gx = self.long // 2 + dice.between(-2, 2);
        self.tall = 28;
        self.low = -6;
        self.high = self.tall + 1;
        near_mid = float(1 + self.trench) * 0.5;
        far_mid = float(self.trench + 4 + self.wide - 1) * 0.5;
        self.enter = Port(face=2, along=near_mid, floor=0);
        if self.gantry {
            self.leaves = [Port(face=0, along=far_mid, floor=0), Port(face=0, along=near_mid, floor=0), Port(face=1, along=float(self.gx), floor=7), Port(face=3, along=float(self.gx), floor=7)];
        } else {
            self.leaves = [Port(face=0, along=far_mid, floor=0), Port(face=0, along=near_mid, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        ty = self.trench;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, -5);
        # The trench, its steps down at both ends, the charge in its floor.
        build.widen(hall, 5, ty, -5, self.long - 5, ty + 4, 0);
        stair(build, 9, ty, -5, 2, 5, 4);
        stair(build, self.long - 10, ty, -5, 0, 5, 4);
        hurt(build, 10.0, float(ty), -5.0, float(self.long - 10), float(ty + 4), -3.0, 10);
        # Catwalks across it.
        spots = [13, self.long // 2 - 1, self.long - 16] if dice.chance(0.5) else [14, self.long - 17];
        for x in spots {
            deck(build, x, ty, x + 3, ty + 4, 0, 1);
        }
        if self.gantry {
            build.level(hall, 7);
            # The gantry high across the hall, wall to wall, and its stair
            # up along the far wall.
            deck(build, self.gx - 2, 1, self.gx + 2, self.wide - 1, 7, 1);
            stair(build, self.gx + 8, self.wide - 4, 0, 2, 7, 3);
            build.foe(float(self.gx) + 0.5, 3.0, 7, STATION_FOES.pick(dice, self.danger), 90.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.timer(3.0) +>:Fires:+> build.sparks(float(self.long // 3) + 0.5, float(ty) + 2.0, -4.0, 1);
        build.timer(4.5) +>:Fires:+> build.sparks(float(2 * self.long // 3) + 0.5, float(ty) + 2.0, -4.0, 3);
        far_y = float(ty + 4 + self.wide - 1) * 0.5;
        near_y = float(1 + ty) * 0.5;
        build.foe(float(self.long // 2) + 0.5, far_y, 0, STATION_FOES.pick(dice, self.danger), 180.0);
        build.foe(5.5, near_y, 0, STATION_FOES.pick(dice, self.danger), 0.0, patrol=[[5.5, near_y], [float(self.long) - 5.5, near_y]]);
        # At the first catwalk, what waits at the far end comes on.
        first = build.touch(float(spots[0]), float(ty), 0.0, float(spots[0] + 3), float(ty + 4), 6.0);
        late = wake_later(build, first, 1.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * float(self.wide - 5) / 2.0, 0, STATION_FOES.pick(dice, self.danger, index == 1), 180.0, waits=late);
        }
        build.supply(float(self.long // 2) + 0.5, float(ty) + 2.0, -5, "item_regen", "q3");
        build.supply(3.0, near_y, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, far_y, 0, Q3_HEALTH, "q3");
    }
}

"""The hub: turbine housings down the middle, gantries high along both
long walls and one crossing, a stair and a lift up."""
node TurbineHall(Prefab) {
    has gantry: int = 7,
        gx: int = 16,
        corner: int = 0,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Turbine hall";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(32, 34);
        self.wide = dice.between(24, 26);
        self.gantry = dice.between(7, 8);
        self.gx = self.long // 2 + dice.between(-2, 2);
        self.corner = dice.below(2);
        self.tall = self.gantry + 22;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2 + 6), floor=self.gantry), Port(face=3, along=float(self.long // 2 - 6), floor=self.gantry), Port(face=0, along=3.0, floor=self.gantry)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        g = self.gantry;
        gx = self.gx;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gantries along both walls and the one crossing between them.
        deck(build, 1, 1, self.long - 1, 5, g, 1);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g, 1);
        deck(build, gx - 2, 5, gx + 2, self.wide - 5, g, 1);
        # The turbine housings either side of the crossing; their blades
        # burn who comes too close.
        for x0 in [gx - 10, gx + 6] {
            build.solid(x0, cy - 2, 0, x0 + 4, cy + 2, g + 3);
            hurt(build, float(x0 - 1), float(cy - 3), 0.0, float(x0 + 5), float(cy + 3), 3.0, 4);
        }
        # A stair up at one corner, a lift at the other.
        if self.corner == 0 {
            stair(build, 6, 5, 0, 0, g, 3);
            keep_box(build, hall, 3 + g, 4, 6 + g, 5, g);
            lift(build, self.long - 6, self.wide - 8, self.long - 3, self.wide - 5, 0, g);
            keep_box(build, hall, self.long - 6, self.wide - 5, self.long - 3, self.wide - 4, g);
        } else {
            stair(build, 6, self.wide - 8, 0, 0, g, 3);
            keep_box(build, hall, 3 + g, self.wide - 5, 6 + g, self.wide - 4, g);
            lift(build, self.long - 6, 5, self.long - 3, 8, 0, g);
            keep_box(build, hall, self.long - 6, 4, self.long - 3, 5, g);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.timer(4.0) +>:Fires:+> build.sparks(float(gx - 6) + 0.2, float(cy) + 0.5, 4.0, 0);
        build.supply(float(gx) + 0.5, float(cy) + 0.5, g, "item_quad", "q3");
        build.foe(float(gx) + 0.5, 3.0, g, STATION_FOES.pick(dice, self.danger), 90.0);
        build.foe(4.5, float(cy) + 5.5, 0, STATION_FOES.pick(dice, self.danger), 0.0, patrol=[[4.5, float(cy) + 5.5], [float(self.long) - 4.5, float(cy) + 5.5]]);
        build.foe(float(self.long) - 4.5, float(cy) - 4.5, 0, STATION_FOES.pick(dice, self.danger), 180.0);
        # On the crossing, the far gantries' guards come on.
        crossing = build.touch(float(gx - 2), 5.0, float(g), float(gx + 2), float(self.wide - 5), float(g + 6));
        late = wake_later(build, crossing, 1.5);
        build.foe(float(self.long) - 3.5, 3.0, g, STATION_FOES.pick(dice, self.danger, True), 180.0, waits=late);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, g, STATION_FOES.pick(dice, self.danger), 180.0, waits=late);
        build.supply(3.0, 3.0, g, Q3_ARMOR, "q3");
        build.supply(3.0, float(cy) - 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on a dais up a stair, charged coils either side
of the way up, a catwalk from the dais back along the wall."""
node TransformerVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        dais: int = 6,
        use_lift: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Transformer vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.dais = dice.between(6, 7);
        self.use_lift = dice.chance(0.4);
        self.tall = self.dais + 22;
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
        d = self.dais;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, d);
        build.doorway(room, self.enter);
        dx = self.long - 8;
        build.solid(dx, 2, 0, self.long - 1, side - 1, d);
        if self.use_lift {
            lift(build, dx - 3, cy - 1, dx, cy + 2, 0, d);
        } else {
            stair(build, dx - d, cy - 1, 0, 0, d, 3);
        }
        keep_box(build, room, dx, cy - 1, dx + 1, cy + 2, d);
        # The coils either side of the way up, the charge between them and
        # the walls.
        columns(build, [[dx - 1, cy - 3], [dx - 1, cy + 3]], 0, d + 3);
        hurt(build, float(dx - 2), 2.0, 0.0, float(dx), float(cy - 2), 4.0, 6);
        hurt(build, float(dx - 2), float(cy + 3), 0.0, float(dx), float(side - 1), 4.0, 6);
        # The catwalk from the dais back along the -y wall to a drop.
        deck(build, 4, 1, dx, 4, d, 1);
        keep_box(build, room, 4, 1, 5, 4, d);
        key_ambush(build, self.key, float(self.long) - 4.0, float(cy) + 0.5, d, side, 0, [2, 7], [STATION_FOES.pick(dice, self.danger, True), STATION_FOES.pick(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 4.0, d, STATION_FOES.pick(dice, self.danger), 180.0);
        build.foe(8.5, 2.5, d, STATION_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(cy) + 2.5, 0, Q3_HEALTH, "q3");
        build.timer(3.0) +>:Fires:+> build.sparks(float(dx) - 0.5, float(cy) - 2.0, float(d) + 2.0, 2);
        build.timer(3.7) +>:Fires:+> build.sparks(float(dx) - 0.5, float(cy) + 3.0, float(d) + 2.0, 2);
    }
}

"""The end (or a gate): a hall, the reactor room, the way out on a dais
ringed by a charged channel, a bridge over it."""
node ReactorGate(Prefab) {
    has key: str = "",
        both: bool = False,
        gallery: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY1;
        self.district = level_district(Q3TOURNEY1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.both = dice.chance(0.5);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 22;
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.gallery);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The reactor: a dais ringed by a charged channel, steps out of the
        # channel at its far side, a bridge (or two) over it.
        dx0 = wall + 7;
        dx1 = dx0 + 6;
        dy0 = middle - 3;
        dy1 = middle + 3;
        build.widen(room, dx0 - 2, dy0 - 2, -3, dx1 + 2, dy1 + 2, 0);
        build.level(room, -3);
        build.solid(dx0, dy0, -3, dx1, dy1, 1);
        hurt(build, float(dx0 - 2), float(dy0 - 2), -3.0, float(dx1 + 2), float(dy1 + 2), -1.0, 10);
        stair(build, dx1, dy1 + 1, -3, 3, 3, 2);
        deck(build, dx0 - 2, middle - 1, dx0, middle + 2, 0, 1);
        if self.both {
            deck(build, dx1, middle - 1, dx1 + 2, middle + 2, 0, 1);
        }
        build.way_out(float(dx0) + 3.0, py, 1);
        # The gallery over the far end, up a stair along the wall.
        deck(build, self.long - 5, 1, self.long - 1, self.wide - 1, self.gallery, 1);
        stair(build, self.long - 5 - self.gallery, 1, 0, 0, self.gallery, 3);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.0, 3.5 + float(index) * float(self.wide - 7) / 2.0, self.gallery, STATION_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(dx0) - 4.5, 3.0, 0, STATION_FOES.pick(dice, self.danger), 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, STATION_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(dx0) - 4.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
        build.timer(3.5) +>:Fires:+> build.sparks(float(dx0) + 0.5, float(dy0) - 1.0, -2.0, 1);
    }
}

"""q3tourney1's stretches: [name, role]."""
glob Q3TOURNEY1_STRETCHES: list[list[str]] = [
         ["control", "start"],
         ["core", "flow"],
         ["trench", "flow"],
         ["turbines", "hub"],
         ["turbines", "flow"],
         ["vault", "keyroom"],
         ["reactor", "end"],
         ["reactor", "gate"]
     ];

"""One of q3tourney1's stretches by its name."""
def make_q3tourney1(name: str, key: str) -> Prefab {
    if name == "control" {
        return ControlRoom();
    }
    if name == "core" {
        return PowerCore();
    }
    if name == "trench" {
        return ConduitTrench();
    }
    if name == "turbines" {
        return TurbineHall();
    }
    if name == "vault" {
        return TransformerVault(key=key if key else "key_silver");
    }
    return ReactorGate(key=key);
}
