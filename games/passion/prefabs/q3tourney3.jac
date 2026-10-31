"""Prefabs drawn from Quake III's q3tourney3, Hell's Gate: gothic ledges
and outcrops at three heights over a fiery abyss under an open sky, thrown
between by jump pads set low on the outcrops, narrow bridges, a court before
a great gate, fires bursting on timers, a floor low in the abyss under the
court. Quake III's arenas hold no foes of their
own; q3tourney3's are hell_knight, knight, demon1. Raised in
q3tourney3's own palette. The abyss's floor, too far
down to reckon on, burns whoever falls, and jump pads or teleporters on it
send them back up.

- `HellsPorch`: the start. A porch over the abyss under an arch, a stair
  down its side to a terrace, a pad from the terrace's lip up to the far
  ledge and one from the far ledge back down; by the seed a narrow bridge along the other side too, a stair up
  at its end. From the terrace, the far ledge's guards come on.
- `GateBridge`: a narrow bridge over the abyss to a landing and a stair up
  to the stage beyond; by the seed broken in the middle (a pad across the
  break each way, the bridge a lane wider), and an outcrop low off its
  side to drop to, a pad back up.
- `AbyssPads`: outcrops over the abyss, a low one and a high one on
  opposite sides, thrown between pad to pad from the near ledge to the far
  one (and by the seed a long pad from the near ledge straight to the
  high one); a long pad from the far ledge back over to the near one.
- `GateCourt`: the hub. A court before a great gate: the stage high in the
  middle up a flying stair, terraces low along both walls down stairs
  from the near ledge, pads from the terraces up to the stage, fires
  flaring at the gate's columns; under the stage the abyss's low floor,
  stepped down to from a terrace, a pad back up.
- `BrimstoneShrine`: the key room. The key on a shrine high in the middle
  of the abyss, a narrow walk round it along one wall (or both) and the far
  one, a step off the far walk to a low outcrop and a pad from it up to the
  shrine; taking it opens closets on the entry ledge, a teleporter back.
- `HellsGate`: the end (or a gate, the door a key's). A hall, a deck over
  the abyss, a narrow bridge (or a pad) to the stage, the way out under
  the great gate's arch; fires burst along the bridge."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, void_floor, void_pads, throw, wake_later, flying_stair, columns }
import from .q3open_parts { OPEN_AIR, VOID_DROP, foot_shelf }

glob Q3TOURNEY3: str = "q3:q3tourney3",
     Q3TOURNEY3_LIGHT: list[str] = ["monster_hell_knight", "monster_knight"],
     Q3TOURNEY3_HEAVY: list[str] = ["monster_demon1"];

"""A foe for q3tourney3's stretches."""
glob HELL_FOES: FoeMix = FoeMix(light=Q3TOURNEY3_LIGHT, strong=Q3TOURNEY3_HEAVY, heavy_light=Q3TOURNEY3_HEAVY, scale=0.5);

"""A fire bursting on a timer at (x, y), `z` lifts up (the original's
timed fires)."""
def burst(build: Raising, x: float, y: float, z: float, seconds: float) {
    build.timer(seconds) +>:Fires:+> build.explosion(x, y, z);
}

"""The start: a porch over the abyss under an arch, a terrace down its
side, a pad from it up to the far ledge, a bridge by the seed."""
node HellsPorch(Prefab) {
    has terrace_side: int = 0,
        bridge: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hell's porch";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(30, 32);
        self.wide = dice.between(18, 20);
        self.terrace_side = dice.below(2);
        self.bridge = dice.chance(0.5);
        self.tall = 4 + OPEN_AIR;
        self.low = -VOID_DROP - 5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        other = 1 if self.terrace_side == 0 else 3;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(ty) + 4.0, floor=4), Port(face=3 if self.terrace_side == 0 else 1, along=float(self.long - 3), floor=4), Port(face=other, along=5.0, floor=0), Port(face=other, along=float(self.long - 3), floor=4)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -VOID_DROP - 4;
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        bridge_y = self.wide - 5 if self.terrace_side == 0 else 2;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, 4] {
            build.level(hall, z);
        }
        # The porch, its arch.
        deck(build, 1, 1, 10, self.wide - 1, 0, 3);
        columns(build, [[9, 2], [9, self.wide - 3]], 0, 10);
        build.solid(9, 2, 10, 10, self.wide - 2, 11);
        # The terrace down the porch's side, the far ledge, the pad up.
        deck(build, 10, ty, 18, ty + 8, -4, 2);
        stair(build, 13, ty + 2, -4, 2, 4, 3);
        deck(build, self.long - 7, 1, self.long - 1, self.wide - 1, 4, 3);
        throw(build, hall, 15.0, float(ty) + 4.0, -4, float(self.long) - 3.5, float(ty) + 4.0, 4, [17, ty + 2, 18, ty + 6], [self.long - 7, ty + 2, self.long - 6, ty + 6]);
        # A pad from the far ledge back down to the terrace, beside the one
        # that lands there.
        back_y = ty + 8 if self.terrace_side == 0 else ty - 1;
        throw(build, hall, float(self.long) - 3.5, float(back_y) + 0.5, 4, 12.0, float(ty) + 6.5, -4, [self.long - 7, back_y - 1, self.long - 6, back_y + 2], [17, ty + 5, 18, ty + 8]);
        if self.bridge {
            # The narrow bridge along the other side, a stair up at its end.
            deck(build, 10, bridge_y, self.long - 11, bridge_y + 3, 0, 2);
            stair(build, self.long - 11, bridge_y, 0, 0, 4, 3);
        }
        other_y = float(ty + 8 + bridge_y) * 0.5 if self.terrace_side == 0 else float(bridge_y + 3 + ty) * 0.5;
        void_pads(build, hall, 1, 1, self.long - 1, self.wide - 1, low, [[22.0, float(ty) + 4.0, 15.0, float(ty) + 6.5, -4.0], [18.0, other_y, float(self.long) - 3.5, other_y, 4.0]], [[17, ty + 5, 18, ty + 8, -4], [self.long - 7, int(other_y) - 1, self.long - 6, int(other_y) + 2, 4]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(16.0, float(ty) + 1.5, -4, "weapon_plasmagun", "q3");
        burst(build, 9.5, 1.5, 1.0, 5.0);
        burst(build, 9.5, float(self.wide) - 1.5, 1.0, 6.0);
        build.foe(7.5, py + 3.0, 0, HELL_FOES.pick(dice, self.danger), 0.0);
        build.foe(12.0, float(ty) + 6.5, -4, HELL_FOES.pick(dice, self.danger), 0.0);
        # From the terrace, the far ledge's guards come on.
        terrace = build.touch(10.0, float(ty), -4.0, 18.0, float(ty + 8), 2.0);
        guards = wake_later(build, terrace, 1.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7), 4, HELL_FOES.pick(dice, self.danger, index == 1), 180.0, waits=guards);
        }
        build.supply(float(self.long) - 3.5, py, 4, Q3_HEALTH, "q3");
    }
}

"""A narrow bridge over the abyss to a landing and a stair up to the stage;
broken in the middle by the seed, an outcrop low off its side."""
node GateBridge(Prefab) {
    has stage: int = 3,
        broken: bool = False,
        outcrop: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate bridge";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(30, 32);
        self.wide = dice.between(16, 18);
        self.stage = dice.between(3, 4);
        self.broken = dice.chance(0.5);
        self.outcrop = [0, 1, 3][dice.below(3)];
        self.tall = self.stage + OPEN_AIR;
        self.low = -VOID_DROP - 6;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.stage), Port(face=1, along=float(self.long - 3), floor=self.stage), Port(face=3, along=float(self.long - 8), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -VOID_DROP - 5;
        land = self.long - 10;
        st = self.stage;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, st, -5] {
            build.level(hall, z);
        }
        deck(build, 1, 1, 7, self.wide - 1, 0, 3);
        # The bridge, broken by the seed and a pad across the break.
        g = (7 + land) // 2 - 2;
        if self.broken {
            # Broken, it is a lane wider: a pad across the break each way,
            # one in each lane.
            deck(build, 7, middle - 1, g, middle + 3, 0, 2);
            deck(build, g + 4, middle - 1, land, middle + 3, 0, 2);
            throw(build, hall, float(g) - 2.5, float(middle), 0, float(g) + 7.5, float(middle), 0, [g - 1, middle - 1, g, middle + 3], [g + 4, middle - 1, g + 5, middle + 3]);
            throw(build, hall, float(g) + 5.0, float(middle) + 2.0, 0, float(g) - 4.5, float(middle) + 2.0, 0, None, None);
        } else {
            deck(build, 7, middle - 1, land, middle + 2, 0, 2);
        }
        # The landing, the stage beyond it up a stair.
        deck(build, land, 1, land + 4, self.wide - 1, 0, 3);
        deck(build, land + 4, 1, self.long - 1, self.wide - 1, st, 3);
        stair(build, land + 4 - st, middle - 1, 0, 0, st, 3);
        open_y = 3.0;
        if self.outcrop != 0 {
            # An outcrop low off the bridge's side, a drop to it, a pad from
            # it back up to the near ledge.
            oy = 2 if self.outcrop == 3 else self.wide - 7;
            deck(build, 12, oy, 18, oy + 5, -5, 2);
            keep_box(build, hall, 13, middle - 1 if self.outcrop == 3 else middle + 1, 16, middle if self.outcrop == 3 else middle + 2, 0);
            throw(build, hall, 16.0, float(oy) + 2.5, -5, 4.0, float(oy) + 2.5, 0, None, [6, oy + 1, 7, oy + 4]);
            build.supply(13.5, float(oy) + 2.5, -5, "item_armor_body", "q3");
            open_y = float(self.wide) - 3.0 if self.outcrop == 3 else 3.0;
        }
        void_pads(build, hall, 1, 1, self.long - 1, self.wide - 1, low, [[float(land) - 6.0, open_y, float(land) + 2.0, open_y, 0.0]], [[land, int(open_y) - 1, land + 1, int(open_y) + 2, 0]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(land) + 1.5, py + 3.5, 0, HELL_FOES.pick(dice, self.danger), 180.0);
        # On the landing, the stage's guards come on.
        landed = build.touch(float(land), 1.0, 0.0, float(land + 3), float(self.wide - 1), 6.0);
        guards = wake_later(build, landed, 0.5);
        build.foe(float(self.long) - 3.0, py, st, HELL_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.0, 3.0, st, HELL_FOES.pick(dice, self.danger), 180.0);
        burst(build, float(land) + 2.0, 1.5, 1.0, 4.5);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, st, Q3_HEALTH, "q3");
    }
}

"""Outcrops over the abyss, low and high on opposite sides, thrown
between pad to pad from the near ledge to the far one."""
node AbyssPads(Prefab) {
    has side: int = 0,
        shortcut: bool = False,
        far_z: int = 4,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abyss pads";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(34, 36);
        self.wide = dice.between(22, 24);
        self.side = dice.below(2);
        self.shortcut = dice.chance(0.5);
        self.far_z = [2, 4][dice.below(2)];
        self.tall = 4 + OPEN_AIR;
        self.low = -VOID_DROP - 5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.far_z), Port(face=1, along=float(self.long - 3), floor=self.far_z), Port(face=3, along=float(self.long - 3), floor=self.far_z)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -VOID_DROP - 4;
        fz = self.far_z;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, 4, fz] {
            build.level(hall, z);
        }
        far = self.long - 7;
        deck(build, 1, 1, 7, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, fz, 3);
        # The low outcrop near, the high one beyond on the other side.
        wy = 2 if self.side == 0 else self.wide - 8;
        ey = self.wide - 8 if self.side == 0 else 2;
        deck(build, 10, wy, 16, wy + 6, -4, 2);
        deck(build, 18, ey, 24, ey + 6, 4, 2);
        facing = ey if self.side == 0 else ey + 5;
        keep_box(build, hall, 18, facing, 24, facing + 1, 4);
        throw(build, hall, 4.0, float(wy) + 3.0, 0, 12.0, float(wy) + 3.0, -4, [6, wy + 1, 7, wy + 5], [10, wy + 1, 11, wy + 5]);
        throw(build, hall, 14.5, float(wy) + 3.0, -4, 20.0, float(ey) + 3.0, 4, None, [18, ey, 19, ey + 6]);
        throw(build, hall, 22.5, float(ey) + 3.0, 4, float(self.long) - 3.5, float(ey) + 3.0, fz, [23, ey + 1, 24, ey + 5], [far, ey + 1, far + 1, ey + 5]);
        if self.shortcut {
            throw(build, hall, 4.0, float(ey) + 3.0, 0, 20.0, float(ey) + 3.0, 4, [6, ey + 1, 7, ey + 5], None);
        }
        # The way back: a long pad from the far ledge over the low outcrop
        # to the near ledge.
        throw(build, hall, float(far) + 2.0, float(wy) + 3.0, fz, 3.0, py, 0, [far, wy + 1, far + 1, wy + 5], [6, middle - 1, 7, middle + 2]);
        void_pads(build, hall, 1, 1, self.long - 1, self.wide - 1, low, [[13.0, py, 4.0, py, 0.0], [22.0, py, float(self.long) - 3.5, py, float(fz)]], [[6, middle - 1, 7, middle + 2, 0], [far, middle - 1, far + 1, middle + 2, fz]]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(12.5, float(wy) + 5.0, -4, HELL_FOES.pick(dice, self.danger), 0.0);
        build.foe(22.0, float(ey) + 1.5, 4, HELL_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(11.0, float(wy) + 1.5, -4, "item_armor_shard", "q3");
        build.supply(19.5, float(ey) + 5.0, 4, "item_enviro", "q3");
        # On the high outcrop, the far ledge's guards come on.
        high = build.touch(18.0, float(ey), 4.0, 24.0, float(ey + 6), 10.0);
        guards = wake_later(build, high, 1.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7), fz, HELL_FOES.pick(dice, self.danger), 180.0, waits=guards);
        }
        burst(build, float(far) + 1.0, 2.0, float(fz) + 1.0, 5.0);
        build.supply(float(self.long) - 3.5, py, fz, Q3_HEALTH, "q3");
    }
}

"""The hub: a court before a great gate, the stage high in its middle up
a flying stair, terraces low along both walls, pads up from them."""
node GateCourt(Prefab) {
    has stage: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gate court";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(32, 34);
        self.wide = dice.between(26, 28);
        self.stage = 4;
        self.tall = 4 + OPEN_AIR;
        self.low = -VOID_DROP - 15;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=4), Port(face=1, along=float(self.long - 4), floor=-4), Port(face=3, along=float(self.long - 4), floor=-4), Port(face=1, along=5.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -VOID_DROP - 14;
        court = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, 4] {
            build.level(court, z);
        }
        # The near ledge, the terraces along both walls down stairs from it,
        # the stage up a flying stair.
        deck(build, 1, 1, 10, self.wide - 1, 0, 3);
        deck(build, 10, 1, self.long - 1, 6, -4, 2);
        deck(build, 10, self.wide - 6, self.long - 1, self.wide - 1, -4, 2);
        stair(build, 13, 1, -4, 2, 4, 3);
        stair(build, 13, self.wide - 4, -4, 2, 4, 3);
        deck(build, 14, 8, self.long - 1, self.wide - 8, 4, 3);
        flying_stair(build, 10, middle - 1, 0, 0, 4, 3, 2);
        # Pads from the terraces up to the stage.
        px = self.long // 2 + dice.between(-2, 2);
        throw(build, court, float(px), 3.5, -4, float(px), 11.0, 4, [px - 2, 5, px + 3, 6], [px - 2, 8, px + 3, 9]);
        throw(build, court, float(px + 6), float(self.wide) - 3.5, -4, float(px + 6), float(self.wide) - 11.0, 4, [px + 4, self.wide - 6, px + 9, self.wide - 5], [px + 4, self.wide - 9, px + 9, self.wide - 8]);
        # The great gate: columns and a lintel across the stage's far end.
        columns(build, [[self.long - 3, 9], [self.long - 3, self.wide - 10]], 4, 16);
        build.solid(self.long - 4, 9, 14, self.long - 1, self.wide - 9, 16);
        burst(build, float(self.long) - 2.5, 10.5, 5.0, 4.0);
        burst(build, float(self.long) - 2.5, float(self.wide) - 10.5, 5.0, 5.0);
        # The abyss's low floor under the stage, stepped down to from the -y
        # terrace, a pad from it back up to the near ledge.
        foot_shelf(build, court, 11, 5, self.long - 3, self.wide - 5, -14, [self.long - 11, 5, self.long - 5, 6], -4, 13.0, 7.5, 6.0, 7.5, 0, [9, 6, 10, 9]);
        build.supply(float(self.long) - 5.5, 7.0, -14, "ammo_rockets", "q3");
        build.foe(20.5, float(middle) + 0.5, -14, HELL_FOES.pick(dice, self.danger), 0.0);
        void_floor(build, 1, 1, self.long - 1, self.wide - 1, low, 4.0, py, 0, 0.0, 12);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(16 + index * 6) + 0.5, 3.5, -4, HELL_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.5, -4, HELL_FOES.pick(dice, self.danger), 180.0);
        # Up on the stage's stair, the stage's guards come on.
        climb = build.touch(10.0, float(middle - 1), 1.0, 14.0, float(middle + 2), 8.0);
        guards = wake_later(build, climb, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 6.5, float(middle) - 2.5 + float(index) * 2.5, 4, HELL_FOES.pick(dice, self.danger, index == 1), 180.0, waits=guards);
        }
        build.supply(float(px) + 0.5, float(middle) + 0.5, 4, "weapon_railgun", "q3");
        build.supply(4.0, 3.0, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, 3.5, -4, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.5, -4, "ammo_cells", "q3");
    }
}

"""The key room: a shrine high in the middle of the abyss, a narrow walk round
it from the entry ledge to the far wall, a step off the walk down to a low
outcrop and a pad from there up to the shrine."""
node BrimstoneShrine(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        side: int = 0,
        both: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Brimstone shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(30, 32);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.side = dice.below(2);
        self.both = dice.chance(0.5);
        self.tall = 6 + OPEN_AIR;
        self.low = -VOID_DROP - 5;
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
        low = -VOID_DROP - 4;
        room = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, 6] {
            build.level(room, z);
        }
        build.doorway(room, self.enter);
        deck(build, 1, 1, 11, side, 0, 3);
        # The walk round the abyss, along one wall (or both) and the far one.
        lane = 1 if self.side == 0 else side - 3;
        deck(build, 11, lane, self.long - 5, lane + 3, 0, 2);
        if self.both {
            other = side - 3 if self.side == 0 else 1;
            deck(build, 11, other, self.long - 5, other + 3, 0, 2);
        }
        deck(build, self.long - 5, 1, self.long - 1, side, 0, 2);
        # The shrine in the middle of it all.
        sx1 = self.long - 10;
        deck(build, 15, 6, sx1, side - 5, 6, 3);
        # The low outcrop off the far walk, the pad up from it to the shrine.
        deck(build, self.long - 9, cy - 3, self.long - 5, cy + 4, -4, 2);
        keep_box(build, room, self.long - 5, cy - 2, self.long - 4, cy + 3, 0);
        throw(build, room, float(self.long) - 7.0, float(cy) + 0.5, -4, float(sx1) - 3.5, float(cy) + 0.5, 6, None, [sx1 - 1, cy - 2, sx1, cy + 3]);
        # From the shrine, a teleporter back to the entry ledge.
        build.teleporter(17.5, float(cy) + 3.5, 6, 4.0, float(cy) + 0.5, 0, 0.0);
        void_floor(build, 1, 1, self.long - 1, side, low, 4.0, float(cy) + 0.5, 0, 0.0, 12);
        key_ambush(build, self.key, 17.5, float(cy) - 1.5, 6, side, 0, [2, 7], [HELL_FOES.pick(dice, self.danger, True), HELL_FOES.pick(dice, self.danger)]);
        build.foe(float(sx1) - 2.5, float(cy) - 2.5, 6, HELL_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(lane) + 1.5, 0, HELL_FOES.pick(dice, self.danger), 180.0);
        burst(build, float(sx1) + 1.0, float(cy) + 0.5, 7.0, 4.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 8.0, float(cy) + 3.0, -4, "ammo_cells", "q3");
    }
}

"""The end (or a gate): a hall, a deck over the abyss, a narrow bridge (or
a pad) to the stage, the way out under the great gate's arch."""
node HellsGate(Prefab) {
    has key: str = "",
        bridge: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hell's gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY3;
        self.district = level_district(Q3TOURNEY3);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.bridge = dice.chance(0.6);
        self.tall = 4 + OPEN_AIR;
        self.low = -VOID_DROP - 5;
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
        low = -VOID_DROP - 4;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        void = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, 4);
        build.doorway(hall, self.enter);
        build.widen(void, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        ex = wall + 7;
        deck(build, wall + 1, 1, ex, self.wide - 1, 0, 3);
        sx = self.long - 9;
        deck(build, sx, 1, self.long - 1, self.wide - 1, 4, 3);
        if self.bridge {
            deck(build, ex, middle - 1, sx - 4, middle + 2, 0, 2);
            stair(build, sx - 4, middle - 1, 0, 0, 4, 3);
        } else {
            throw(build, void, float(ex) - 2.5, py, 0, float(sx) + 3.0, py, 4, [ex - 1, middle - 1, ex, middle + 2], [sx, middle - 1, sx + 1, middle + 2]);
        }
        # The great gate's arch over the way out.
        columns(build, [[self.long - 3, middle - 4], [self.long - 3, middle + 4]], 4, 16);
        build.solid(self.long - 4, middle - 4, 14, self.long - 2, middle + 5, 16);
        build.way_out(float(self.long) - 3.5, py, 4);
        void_floor(build, wall + 1, 1, self.long - 1, self.wide - 1, low, float(wall) + 3.0, py, 0, 0.0, 12);
        # Fires burst along the bridge's sides; halfway over, the stage's
        # guards come on.
        burst(build, float(ex + sx) * 0.5, float(middle) - 2.5, 1.0, 3.0);
        burst(build, float(ex + sx) * 0.5 + 3.0, float(middle) + 3.5, 1.0, 4.0);
        halfway = build.touch(float(ex + 3), 1.0, 0.0, float(ex + 5), float(self.wide - 1), 6.0);
        guards = wake_later(build, halfway, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 5.5, py - 3.0 + float(index) * 3.0, 4, HELL_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, HELL_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(ex) - 2.0, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3tourney3's stretches: [name, role]."""
glob Q3TOURNEY3_STRETCHES: list[list[str]] = [
         ["porch", "start"],
         ["bridge", "flow"],
         ["pads", "flow"],
         ["court", "hub"],
         ["court", "flow"],
         ["shrine", "keyroom"],
         ["gate", "end"],
         ["gate", "gate"]
     ];

"""One of q3tourney3's stretches by its name."""
def make_q3tourney3(name: str, key: str) -> Prefab {
    if name == "porch" {
        return HellsPorch();
    }
    if name == "bridge" {
        return GateBridge();
    }
    if name == "pads" {
        return AbyssPads();
    }
    if name == "court" {
        return GateCourt();
    }
    if name == "shrine" {
        return BrimstoneShrine(key=key if key else "key_silver");
    }
    return HellsGate(key=key);
}
