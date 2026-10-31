"""Prefabs drawn from e1m2, the Castle of the Damned: a castle of brick and
wood standing in water, its moat and gate, its galleries and barred halls,
its drawbridge over a flooded pit, the trains and the fiends of its last
hall, and its silver key high in a tower room. Raised in e1m2's own
palette. Each stretch takes its shape from its dice as well as its sizes:
which way a crossing goes, a stair or a lift, where the button is, whether
a secret or an ambush is there at all.

- `MoatGate`: the start. A terrace over a court under the sky (a stash in
  its face), a broad moat across the court crossed by a causeway or swum, and
  the castle's wall: a gate through it whose portcullis sinks as the
  player comes up to it, a wall-walk on top (stacked over the gate and
  widened by a hoarding over the bailey) with guards woken from the
  terrace, climbed to by a stair or a lift from the bailey, and a way on
  from it high up. Ramparts run back along the side walls over the court
  and the moat: one (most often) up a stair from the terrace, the other
  ending in a drop into the court.
- `SpikeCorridor`: a hall with a walkway along one wall over an arcade, a
  broad channel of water down its floor;
  spikes fly from the wall while anyone walks the walkway (or the floor
  under it: e1m2's trap corridor); a drop from the walkway's far end wakes
  what waits below and brings one more in by a teleporter, and a stair or
  a lift climbs back; a channel of water or crates below. A way out on
  the floor below sits behind a portcullis that sinks as it is neared.
- `BarredHall`: a tall hall barred at its far end (one gateway or two).
  Shooting (or pressing) the button raises the bars, and scrags are sent in
  behind the player by teleporters (e1m2's shot button and its teleported
  wizards); galleries on both sides joined by a catwalk across the far end
  or the middle, the floor flooded either side of a causeway (or crates
  about it), a way out from the gallery.
- `Drawbridge`: a flooded pit across a hall; the bridge is drawn up out of
  the water by a button on a balcony over the way in (ridden up to by a
  lift), or by shooting one on the far wall (e1m2's drawbridge); an
  underwater niche holds a secret; crossing wakes the far side's guards
  and sends a scrag in behind.
- `FloodedPassage`: two rooms joined only under water, the near room's far
  half all pool (a pocket of air off the tunnel a secret), or a hall whose middle is a pool to swim across;
  an upper floor over the far room, climbed to by a stair or a lift, runs
  back over the near room, its edge a drop: the way back without the swim.
- `FerryHall`: a ledge, a flooded (or dry, the floor running on under the
  ledges) pit and a far ledge; a button starts the trains that ferry a
  body across, and a few seconds on the closets in the far ledge's wall
  open and fiends come out (e1m2's trains and the trap that follows them).
  Steps up to both ledges, a lift to a catwalk high across the pit, and a
  teleporter back from the far ledge.
- `GreatHall`: the hub: a gallery round the walls (or two galleries and a
  catwalk across) over an arcade, a stair or a lift, a flooded nave with a
  deep well in it, aisles dry along the galleries, a teleporter up to the far gallery; ways out on both floors; the gallery's
  guards wake at its top.
- `KeyTower`: the key room. The key high on a dais (an undercroft under
  it) up a stair or a lift, a balcony along one wall joined to it; the
  closets in one wall open as the climb begins and those in the other as
  the key is taken, and a foe is sent in behind (e1m2's knights let out as
  its silver key is fetched); the undercroft flooded, the quad in a stash
  by its dry walk.
- `CastleExit`: the end: a hall with balconies its length, a broad channel
  of water across it under a causeway, a door in its far wall (a key's, as
  a gate, or one that opens as it is neared, sometimes bringing a foe in
  behind) and the way out under an arch beyond, raised on a dais or sunk
  in a court."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, lift, apart }
import from .e1m5 { crenels }
import from .e1m2_parts { slab, keep_box, arcade, stash, closets, spike_wall, key_cue, sump }

glob E1M2: str = "q1:e1m2";

"""e1m2's foes: knights and grunts, scrags where there is room to fly
(`flying`), ogres where `heavy`, fiends as a run goes deeper."""
def e1m2_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return q1_foe(dice, q1_palette(["monster_wizard", "monster_wizard", "monster_knight"], ["monster_ogre"], danger));
    }
    if heavy {
        return q1_foe(dice, q1_palette(["monster_ogre", "monster_knight"], ["monster_demon1"], danger));
    }
    return q1_foe(dice, q1_palette(["monster_knight", "monster_knight", "monster_army", "monster_dog"], ["monster_ogre"], danger));
}

"""A portcullis before a way out (`port`, of a prefab `long` by `wide`): a
block across the doorway's inner cell that sinks into the floor when its
cue fires. The prefab's box must reach nine lifts under the port's floor."""
def port_gate(build: Raising, long: int, wide: int, port: Port) -> Cue {
    low = int(port.along) - port.wide // 2;
    high = low + port.wide;
    top = port.floor + 8;
    if port.face == 0 {
        return build.sinking(float(long - 2), float(low), float(long - 1), float(high), top, 8);
    }
    if port.face == 2 {
        return build.sinking(1.0, float(low), 2.0, float(high), top, 8);
    }
    if port.face == 1 {
        return build.sinking(float(low), float(wide - 2), float(high), float(wide - 1), top, 8);
    }
    return build.sinking(float(low), 1.0, float(high), 2.0, top, 8);
}

"""The touch before a way out (`port`): the box of the room's cells in
front of its doorway, `deep` cells in."""
def port_touch(build: Raising, long: int, wide: int, port: Port, deep: int) -> Cue {
    low = float(int(port.along) - port.wide // 2);
    high = low + float(port.wide);
    z0 = float(port.floor);
    if port.face == 0 {
        return build.touch(float(long - 2 - deep), low, z0, float(long - 2), high, z0 + 6.0);
    }
    if port.face == 2 {
        return build.touch(2.0, low, z0, float(2 + deep), high, z0 + 6.0);
    }
    if port.face == 1 {
        return build.touch(low, float(wide - 2 - deep), z0, high, float(wide - 2), z0 + 6.0);
    }
    return build.touch(low, 2.0, z0, high, float(2 + deep), z0 + 6.0);
}

"""The start: a terrace over a court, a moat, the castle's wall and gate
with a wall-walk over it, the bailey behind."""
node MoatGate(Prefab) {
    has terr: int = 5,
        top: int = 5,
        court: int = 4,
        moat: int = 6,
        bank: int = 3,
        wall_h: int = 9,
        bailey: int = 12,
        lane: int = 8,
        tall: int = 20,
        crossing: int = 0,
        climb: int = 0,
        rampart: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Moat gate";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.terr = dice.between(5, 6);
        self.court = dice.between(2, 3);
        self.moat = dice.between(11, 14);
        self.bank = dice.between(3, 4);
        self.wall_h = dice.between(9, 10);
        self.bailey = self.wall_h + dice.between(2, 4);
        self.wide = dice.between(19, 22);
        self.lane = dice.between(7, self.wide - 11);
        self.crossing = dice.below(2);
        self.climb = dice.below(2);
        self.rampart = dice.chance(0.7);
        wall_x = 1 + self.terr + self.top + self.court + self.moat + self.bank;
        self.long = wall_x + 4 + self.bailey + 1;
        self.tall = self.wall_h + dice.between(9, 11);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=self.top);
        self.leaves = [
            Port(face=0, along=float(dice.between(6, self.wide - 3)), floor=0),
            Port(face=3, along=float(wall_x + 2), floor=self.wall_h),
            Port(face=1, along=float(wall_x + 4 + self.bailey // 2 + 1), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.top);
        build.level(court, self.wall_h);
        terrace_x = 1 + self.terr;
        mid = self.wide // 2;
        # The terrace the run begins on, its stair down, a stretch of its
        # edge left open to drop from, and a stash in its face.
        build.solid(1, 1, 0, terrace_x, self.wide - 1, self.top);
        stair(build, terrace_x + self.top - 1, mid - 1, 0, 2, self.top, 3);
        keep_box(build, court, terrace_x - 1, mid - 2, terrace_x + 1, mid + 3, self.top);
        keep_box(build, court, terrace_x - 1, mid + 3, terrace_x, mid + 6, self.top);
        stash(build, terrace_x, 2, 0, 2, "item_armor1");
        # The moat, crossed by a causeway (the moat on each side of it with
        # its own steps out) or swum, steps up out of it on the far side.
        moat_x = terrace_x + self.top + self.court;
        far_x = moat_x + self.moat;
        build.pool(moat_x, 1, -6, far_x, self.wide - 1, 0, 2, False, True, self.crossing == 0);
        if self.crossing == 0 {
            build.solid(moat_x, self.lane, -6, far_x, self.lane + 4, 0);
            keep_box(build, court, moat_x - 1, self.lane, far_x + 1, self.lane + 4, 0);
        } else {
            for step in range(6) {
                build.solid(far_x - 2, 1 + step, -6, far_x, 2 + step, -5 + step);
            }
            keep_box(build, court, far_x - 3, 5, far_x + 1, 8, 0);
        }
        # The wall, a gate through it, the wall-walk on top behind crenels.
        wall_x = far_x + self.bank;
        build.solid(wall_x, 1, 0, wall_x + 4, self.wide - 1, self.wall_h);
        build.widen(court, wall_x, self.lane, 0, wall_x + 4, self.lane + 4, 8);
        crenels(build, wall_x, 5, self.wide - 5, self.wall_h, False);
        # A rampart along the side wall from the terrace to the wall-walk,
        # over the court and the moat, a stair up to it from the terrace.
        if self.rampart {
            climb = self.wall_h - self.top;
            stair(build, 2, 1, self.top, 0, climb, 3);
            slab(build, 2 + climb, 1, wall_x, 4, self.wall_h);
            keep_box(build, court, 1 + climb, 1, 3 + climb, 5, self.wall_h);
        }
        # A second rampart along the far side wall from the wall-walk back
        # over the moat, its end open to drop from into the court.
        slab(build, terrace_x + 1, self.wide - 4, wall_x, self.wide - 1, self.wall_h);
        keep_box(build, court, terrace_x + 1, self.wide - 5, terrace_x + 2, self.wide - 1, self.wall_h);
        # The portcullis sinks as the player comes up to the gate.
        at_gate = build.touch(float(wall_x - 3), float(self.lane), 0.0, float(wall_x), float(self.lane + 4), 6.0);
        at_gate +>:Fires:+> build.sinking(float(wall_x + 1), float(self.lane), float(wall_x + 2), float(self.lane + 4), 8, 8);
        # Up to the wall-walk from the bailey: a stair against the side
        # wall, or a lift.
        bailey_x = wall_x + 4;
        if self.climb == 0 {
            stair(build, bailey_x + self.wall_h - 1, 1, 0, 2, self.wall_h, 3);
        } else {
            lift(build, bailey_x, 1, bailey_x + 3, 4, 0, self.wall_h);
            keep_box(build, court, bailey_x, 1, bailey_x + 4, 5, 0);
        }
        keep_box(build, court, wall_x + 2, 1, bailey_x + 4, 5, self.wall_h);
        # A hoarding over the bailey's near part, the wall-walk widened.
        slab(build, bailey_x, 5, bailey_x + 3, self.wide - 1, self.wall_h);
        # The bailey flooded ankle deep behind the wall (the castle stands in
        # water), a step up out of it at either end.
        build.pool(bailey_x + 3, 5, -2, self.long - 3, self.wide - 3, 0, 2, False, False);
        stair(build, bailey_x + 4, self.lane, -2, 2, 2, 3);
        stair(build, self.long - 5, self.lane, -2, 0, 2, 3);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(mid) + 0.5, self.top, 0.0);
        build.supply(2.5, float(self.wide) - 2.5, self.top, "item_shells");
        # The wall's guards wake as the player steps to the terrace's edge.
        rim = build.touch(float(terrace_x - 1), 1.0, float(self.top), float(terrace_x), float(self.wide - 1), float(self.top + 6));
        guards = build.waiting();
        rim +>:Fires:+> guards;
        count = dice.between(2, 3);
        for index in range(count) {
            y = 6.5 + float(index) * float(self.wide - 9) / float(max(1, count - 1));
            build.foe(float(wall_x) + 2.5, y, self.wall_h, e1m2_foe(dice, self.danger), 180.0, waits=guards);
        }
        # A knight walks the bank under the wall; what is in the bailey
        # comes at the gate as it opens.
        build.foe(float(wall_x) - 1.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(wall_x) - 1.5, 2.5], [float(wall_x) - 1.5, float(self.wide) - 2.5]]);
        bailey = build.waiting();
        at_gate +>:Fires:+> bailey;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5 - float(index % 2) * 2.0, float(self.lane) + float(index) * 2.0 - 1.5, 0, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=bailey);
        }
        if dice.chance(0.4) {
            build.foe(float(moat_x) + float(self.moat) * 0.5, float(self.wide) - 6.5, -6, "monster_fish", 90.0);
        }
        build.foe(float(far_x) - 1.5, float(self.wide) - 2.5, self.wall_h, "monster_army", 180.0, patrol=[[float(far_x) - 1.5, float(self.wide) - 2.5], [float(terrace_x) + 3.5, float(self.wide) - 2.5]]);
        build.supply(float(wall_x) - 1.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(bailey_x) + 1.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A hall with a walkway along one wall over an arcade, spikes from the
wall, a drop to the floor below and a stair or lift back up."""
node SpikeCorridor(Prefab) {
    has below_w: int = 10,
        g: int = 6,
        tall: int = 15,
        climb: int = 0,
        trap: int = 0,
        water: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike corridor";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.long = dice.between(24, 30);
        self.below_w = dice.between(9, 12);
        self.wide = 1 + self.below_w + 5 + 1;
        self.g = dice.between(6, 7);
        self.tall = self.g + dice.between(8, 10);
        self.climb = dice.below(2);
        self.trap = dice.below(2);
        self.water = dice.chance(0.95);
        self.low = -9;
        self.high = self.tall + 1;
        walk_y = 1 + self.below_w;
        self.enter = Port(face=2, along=float(walk_y + 2), floor=self.g);
        self.leaves = [
            Port(face=0, along=float(walk_y + 2), floor=self.g),
            Port(face=0, along=float(dice.between(6, walk_y - 3)), floor=0)
        ];
        if not self.water {
            self.leaves.append(Port(face=3, along=float(dice.between(12, self.long - 6)), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        walk_y = 1 + self.below_w;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.g);
        # The walkway, a slab along the far wall over an arcade.
        slab(build, 1, walk_y, self.long - 1, self.wide - 1, self.g);
        start = 2 + self.g + 2;
        arcade(build, walk_y, start + 2, self.long - 3, 0, self.g - 1, 4, False);
        # Up from the floor at the walkway's near end: a stair, or a lift.
        if self.climb == 0 {
            stair(build, 2, walk_y - 3, 0, 0, self.g, 3);
            keep_box(build, hall, self.g - 1, walk_y - 3, self.g + 3, walk_y + 1, self.g);
        } else {
            lift(build, 2, walk_y - 3, 5, walk_y, 0, self.g);
            keep_box(build, hall, 1, walk_y - 4, 6, walk_y + 1, self.g);
            keep_box(build, hall, 1, walk_y - 4, 6, walk_y, 0);
        }
        # The walkway's far end is open to drop from.
        drop_x = self.long - 9;
        keep_box(build, hall, drop_x, walk_y, drop_x + 4, walk_y + 1, self.g);
        # A broad channel of water along the near wall below, or crates.
        if self.water {
            build.pool(start + 2, 1, -4, self.long - 6, walk_y - 5, 0, 2);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                # The way out below behind a portcullis that sinks as it is
                # neared.
                port_touch(build, self.long, self.wide, port, 3) +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        # The spikes: from the far wall across the walkway, or from the near
        # wall across the floor, while anyone walks there.
        if self.trap == 0 {
            walking = build.touch(float(start), float(walk_y), float(self.g), float(drop_x), float(self.wide - 1), float(self.g + 6), False);
            spike_wall(build, walking, self.wide - 1, start + 1, drop_x, float(self.g) + 1.5, 3, False, 3);
        } else {
            walking = build.touch(float(start), 1.0, 0.0, float(self.long - 4), float(walk_y), 6.0, False);
            spike_wall(build, walking, 1, start + 1, self.long - 4, 1.5, 3, False, 1);
        }
        # What waits below wakes as a body lands from the walkway.
        landed = build.touch(float(drop_x), float(walk_y - 3), 0.0, float(drop_x + 4), float(walk_y), 6.0);
        below = build.waiting();
        landed +>:Fires:+> below;
        landed +>:Fires:+> build.summon(drop_x - 7, walk_y - 4, -8, e1m2_foe(dice, self.danger, True), float(drop_x) - 3.5, float(walk_y) - 2.5, 0, 0.0);
        for index in range(dice.between(2, 4)) {
            build.foe(float(self.long) - 3.5 - float(index % 2) * 3.0, float(walk_y) - 4.5 - float(index // 2) * 2.0, 0, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(float(start) + 2.5, float(walk_y) - 1.5, 0, "monster_army", 0.0, patrol=[[float(start) + 2.5, float(walk_y) - 1.5], [float(self.long) - 4.5, float(walk_y) - 1.5]]);
        build.foe(float(self.long) - 3.5, float(walk_y) + 2.5, self.g, e1m2_foe(dice, self.danger), 180.0);
        build.foe(float(start) + 1.5, float(walk_y) + 2.5, self.g, "monster_knight", 0.0, patrol=[[float(start) + 1.5, float(walk_y) + 2.5], [float(drop_x) - 1.5, float(walk_y) + 2.5]]);
        if not self.water {
            kept: list[list[int]] = [[0, 0, start + 1, walk_y + 1], [drop_x - 1, walk_y - 4, self.long, walk_y + 1], [start, walk_y - 2, self.long, walk_y]];
            for port in self.taken {
                if port.floor == 0 {
                    kept.append([int(port.along) - 4, 0, int(port.along) + 4, 4] if port.face == 3 else [self.long - 7, int(port.along) - 4, self.long, int(port.along) + 4]);
                }
            }
            for index in range(dice.between(2, 4)) {
                x = dice.between(start, self.long - 5);
                y = dice.between(2, walk_y - 4);
                if apart([x, y, x + 2, y + 2], kept) {
                    build.solid(x, y, 0, x + 2, y + 2, dice.between(1, 3));
                    kept.append([x, y, x + 2, y + 2]);
                }
            }
        }
        build.supply(float(self.long) - 2.5, float(walk_y) + 1.5, self.g, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A tall hall barred at its far end; a button raises the bars and brings
scrags in by teleporters; galleries on both sides and a catwalk."""
node BarredHall(Prefab) {
    has hall: int = 20,
        chamber: int = 7,
        g: int = 7,
        tall: int = 19,
        twin: bool = False,
        middle: bool = False,
        press: int = 0,
        wet: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Barred hall";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.hall = dice.between(25, 28);
        self.chamber = dice.between(6, 8);
        self.wide = dice.between(20, 23);
        self.wet = dice.chance(0.95);
        self.g = dice.between(7, 8);
        self.tall = dice.between(18, 21);
        self.twin = dice.chance(0.5);
        self.middle = dice.chance(0.5);
        self.press = dice.below(3);
        bar_x = 1 + self.hall;
        self.long = bar_x + 1 + self.chamber + 1;
        self.low = -9;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid), floor=0),
            Port(face=3, along=float(dice.between(self.g + 9, bar_x - 4)), floor=self.g),
            Port(face=1, along=float(bar_x + 1 + self.chamber // 2 + 1), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        bar_x = 1 + self.hall;
        hall = build.room(1, 1, 0, bar_x, self.wide - 1, self.tall, variant=dice.below(3));
        chamber = build.room(bar_x + 1, 1, 0, self.long - 1, self.wide - 1, 12, variant=dice.below(3));
        build.level(hall, self.g);
        # Gallery A along the near side, over an arcade, its stair up.
        stair_top = 5 + self.g;
        slab(build, 1, 1, bar_x, 5, self.g);
        arcade(build, 4, stair_top + 2, bar_x - 3, 0, self.g - 1, 4, False);
        stair(build, 5, 5, 0, 0, self.g, 3);
        keep_box(build, hall, stair_top - 2, 3, stair_top + 2, 8, self.g);
        # Gallery B along the far side, and a catwalk across the hall between
        # them, at its far end or over its middle.
        walk_x = 1 + self.hall // 2 if self.middle else bar_x - 4;
        slab(build, 1, self.wide - 5, bar_x, self.wide - 1, self.g);
        arcade(build, self.wide - 5, stair_top + 2, bar_x - 3, 0, self.g - 1, 4, False);
        slab(build, walk_x, 5, walk_x + 4, self.wide - 5, self.g);
        keep_box(build, hall, walk_x - 1, 4, walk_x + 5, 6, self.g);
        keep_box(build, hall, walk_x - 1, self.wide - 6, walk_x + 5, self.wide - 4, self.g);
        # The hall's floor flooded either side of a causeway up its middle
        # (steps out of each side onto the causeway), or crates two lifts high
        # about it, clear of the ways through.
        if self.wet {
            build.pool(stair_top + 2, 6, -3, bar_x - 4, self.wide - 6, 0, 2, False, True, True);
            build.solid(stair_top + 2, mid - 2, -3, bar_x - 4, mid + 2, 0);
            keep_box(build, hall, stair_top + 1, mid - 2, bar_x - 3, mid + 2, 0);
        } else {
            kept: list[list[int]] = [[0, mid - 4, 6, mid + 4], [4, 4, stair_top + 2, 9], [bar_x - 4, mid - 6, bar_x + 1, mid + 6], [1, self.wide - 8, bar_x, self.wide - 5]];
            for index in range(dice.between(2, 4)) {
                x = dice.between(stair_top + 2, bar_x - 6);
                y = dice.between(6, self.wide - 9);
                if apart([x, y, x + 2, y + 2], kept) {
                    build.solid(x, y, 0, x + 2, y + 2, 2);
                    kept.append([x, y, x + 2, y + 2]);
                }
            }
        }
        # The bars: one gateway or two through the wall between hall and
        # chamber, each a door that rises when the button fires.
        gates = [[mid - 4, 3], [mid + 1, 3]] if self.twin else [[mid - 2, 4]];
        if self.press == 0 {
            button = build.push(float(bar_x), float(mid) + 0.5, float(self.g) + 3.0, 2, True);
        } elif self.press == 1 {
            button = build.push(float(bar_x), 3.0, float(self.g) + 1.2, 2);
        } else {
            button = build.push(1.0, float(mid) + 4.5, 10.0, 0, True);
        }
        for gate in gates {
            build.widen(chamber, bar_x, gate[0], 0, bar_x + 1, gate[0] + gate[1], 8);
            button +>:Fires:+> build.opened(float(bar_x), float(gate[0]), 0.0, float(bar_x + 1), float(gate[0] + gate[1]), 8.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall if port.floor > 0 else chamber, port);
        }
        if self.press != 1 {
            build.touch(2.0, float(mid - 2), 0.0, 5.0, float(mid + 2), 6.0, True, "Shoot the button to raise the bars");
        }
        # Scrags sent in behind the player by teleporters sealed under the
        # floor as the button fires.
        for index in range(dice.between(2, 3)) {
            button +>:Fires:+> build.summon(4 + index * 5, mid - 1, -8, e1m2_foe(dice, self.danger, False, True), float(4 + index * 4) + 0.5, float(mid) + 0.5, 3, 0.0);
        }
        inside = build.waiting();
        button +>:Fires:+> inside;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 3.0, 0, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=inside);
        }
        # The gallery's guards wake as the player comes halfway down the hall.
        halfway = build.touch(float(self.hall // 2), 4.0, 0.0, float(self.hall // 2 + 3), float(self.wide - 4), 6.0);
        guards = build.waiting();
        halfway +>:Fires:+> guards;
        build.foe(float(bar_x) - 2.5, 3.0, self.g, e1m2_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(bar_x) - 2.5, float(self.wide) - 3.0, self.g, e1m2_foe(dice, self.danger, True), 180.0, waits=guards);
        round_y = float(mid) + 0.5 if self.wet else float(self.wide) - 6.5;
        build.foe(float(stair_top) + 3.5, round_y, 0, "monster_knight", 0.0, patrol=[[float(stair_top) + 3.5, round_y], [float(bar_x) - 6.5, round_y]]);
        build.supply(float(bar_x) - 1.5, 2.5, self.g, "item_shells");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A flooded pit across a hall, the bridge drawn up out of the water by a
button on a balcony over the way in or on the far wall."""
node Drawbridge(Prefab) {
    has near: int = 8,
        span: int = 8,
        far_side: int = 5,
        walk: int = 8,
        headroom: int = 18,
        lane: int = 4,
        press: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drawbridge";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.near = dice.between(8, 10);
        self.span = dice.between(8, 9);
        self.far_side = dice.between(5, 7);
        self.wide = dice.between(16, 19);
        self.headroom = dice.between(17, 19);
        self.lane = dice.between(5, self.wide - 8);
        self.press = dice.below(2);
        self.long = 1 + self.near + self.span + self.far_side + 1;
        self.low = -1;
        self.high = self.walk + self.headroom + 1;
        self.enter = Port(face=2, along=float(dice.between(5, self.wide - 6)), floor=self.walk);
        far = float(self.long - 1 - self.far_side // 2 - 1);
        self.leaves = [
            Port(face=0, along=float(dice.between(4, self.wide - 4)), floor=self.walk),
            Port(face=1, along=far, floor=self.walk),
            Port(face=3, along=far, floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        top = self.walk + 9;
        upper = build.room(1, 1, self.walk, self.long - 1, self.wide - 1, self.walk + self.headroom, variant=dice.below(3));
        build.level(upper, top);
        cut = 1 + self.near;
        land = cut + self.span;
        build.room(cut, 1, 0, land, self.wide - 1, self.walk);
        for z in range(0, self.walk - 1) {
            for y in range(1, self.wide - 1) {
                for x in range(cut, land) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        build.doorway(upper, self.enter);
        for port in self.taken {
            build.doorway(upper, port);
        }
        # Steps up out of the water to the near side, along the wall the
        # bridge keeps clear of.
        low_side = self.lane >= self.wide // 2;
        steps_y = 1 if low_side else self.wide - 3;
        for step in range(self.walk) {
            build.solid(cut + step, steps_y, 0, cut + step + 1, steps_y + 2, self.walk - step);
        }
        bridge = build.drawn(float(cut), float(self.lane), float(land), float(self.lane + 3), self.walk, self.walk + 1);
        for across in range(3) {
            build.keep(upper, cut - 1, self.lane + across, self.walk);
            build.keep(upper, land, self.lane + across, self.walk);
        }
        # The balcony along the near wall over the way in, a lift up to it
        # in the corner away from the steps.
        slab(build, 1, 1, 6, self.wide - 1, top);
        lift_y = self.wide - 4 if low_side else 1;
        lift(build, 6, lift_y, 9, lift_y + 3, self.walk, top);
        keep_box(build, upper, 4, lift_y - 1, 10, lift_y + 4, top);
        keep_box(build, upper, 5, lift_y - 1, 10, lift_y + 4, self.walk);
        if self.press == 0 {
            button = build.push(1.0, float(self.wide // 2) + 0.5, float(top) + 1.2, 0);
        } else {
            button = build.push(float(self.long - 1), float(self.wide) - 3.5 if low_side else 3.5, float(self.walk) + 6.0, 2, True);
            build.touch(1.0, 1.0, float(self.walk), float(cut), float(self.wide - 1), float(self.walk + 6), True, "Shoot the button across the water");
        }
        button +>:Fires:+> bridge;
        # An underwater niche in the pit's far wall: a secret, and armor.
        niche_y = self.wide - 4 if low_side else 2;
        build.room(land, niche_y, 0, land + 2, niche_y + 2, 3);
        for z in range(0, 3) {
            for y in range(niche_y, niche_y + 2) {
                for x in range(land, land + 2) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        build.secret(float(land), float(niche_y), 0.0, float(land + 2), float(niche_y + 2), 3.0);
        build.supply(float(land) + 1.0, float(niche_y) + 1.0, 0, "item_armor2" if dice.chance(0.3) else "item_armor1");
        # Scrags over the water; the far side's guards wake as the bridge's
        # end is reached; the balcony's archer watches the pit.
        for index in range(dice.between(1, 2)) {
            build.foe(float(cut) + 2.5 + float(index) * 3.0, float(self.wide) * 0.5, self.walk + 4, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        across = build.touch(float(land), float(self.lane), float(self.walk), float(land + 2), float(self.lane + 3), float(self.walk + 6));
        guards = build.waiting();
        across +>:Fires:+> guards;
        across +>:Fires:+> build.summon(2, self.wide // 2 - 1, 1, e1m2_foe(dice, self.danger, False, True), float(cut) - 2.5, float(self.wide) * 0.5, self.walk + 3, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5 - float(index % 2) * 2.0, 2.5 + float(index) * 3.5, self.walk, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(2.5, float(self.wide) * 0.5, top, "monster_army", 0.0);
        build.foe(float(self.long) - 2.5, 2.5, self.walk, "monster_knight", 90.0, patrol=[[float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5]]);
        build.supply(2.5, 2.5, self.walk, "item_health");
        build.supply(2.0, float(self.wide) - 2.5, top, "item_shells");
    }
}

"""Two rooms joined only under water, or a hall with a pool to swim across
in its middle; a mezzanine in the far room."""
node FloodedPassage(Prefab) {
    has room_a: int = 9,
        tunnel: int = 6,
        room_b: int = 10,
        lane: int = 5,
        tall: int = 18,
        open_water: bool = False,
        lifted: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded passage";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.open_water = dice.chance(0.5);
        self.room_a = dice.between(8, 11);
        self.tunnel = dice.between(7, 9) if self.open_water else dice.between(5, 7);
        self.lifted = dice.chance(0.5);
        self.room_b = (4 if self.lifted else 10) + dice.between(5, 7);
        self.wide = dice.between(15, 18);
        self.tall = dice.between(18, 20);
        self.lane = dice.between(4, self.wide - 9);
        self.long = 1 + self.room_a + self.tunnel + self.room_b + 1;
        self.low = -8;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(3, mid - 3)), floor=0),
            Port(face=0, along=float(dice.between(mid + 2, self.wide - 3)), floor=9),
            Port(face=3, along=float(self.long - 1 - self.room_b // 2 - 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        wall_x = 1 + self.room_a;
        far_x = wall_x + self.tunnel;
        if self.open_water {
            # One hall, its middle a pool from wall to wall, steps up out of
            # it on both shores.
            first = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
            second = first;
            build.pool(wall_x, 1, -6, far_x, self.wide - 1, 0, 2);
            for step in range(6) {
                build.solid(far_x - 2, 1 + step, -6, far_x, 2 + step, -5 + step);
            }
            # Pillars standing in the water.
            for x in range(wall_x + 3, far_x - 2, 3) {
                build.solid(x, mid - 1, -6, x + 1, mid + 1, self.tall);
            }
            build.secret(float(wall_x + 2), float(self.wide - 3), -6.0, float(far_x - 2), float(self.wide - 1), -3.0);
            build.supply(float(wall_x + 3), float(self.wide) - 2.0, -6, "item_armor1");
        } else {
            first = build.room(1, 1, 0, wall_x, self.wide - 1, self.tall, variant=dice.below(3));
            second = build.room(far_x, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
            # A pool against the wall in each room, six lifts deep, the tunnel
            # under the wall between them, water to the brim; steps up out of
            # each pool along its far side.
            near_pool = wall_x - 5;
            build.room(near_pool, 1, -6, wall_x, self.wide - 1, 0);
            build.room(far_x, self.lane - 1, -6, far_x + 5, self.lane + 5, 0);
            build.room(wall_x, self.lane, -6, far_x, self.lane + 3, -2);
            for step in range(6) {
                build.solid(near_pool, self.lane - 1 + step, -6, near_pool + 1, self.lane + step, -5 + step);
                build.solid(far_x + 4, self.lane - 1 + step, -6, far_x + 5, self.lane + step, -5 + step);
            }
            for z in range(-6, 0) {
                for y in range(1, self.wide - 1) {
                    for x in range(near_pool, far_x + 5) {
                        in_lane = self.lane - 1 <= y < self.lane + 5;
                        pool = x < wall_x or (x >= far_x and in_lane);
                        tunnel = wall_x <= x < far_x and self.lane <= y < self.lane + 3 and z < -2;
                        if pool or tunnel {
                            build.liquid(x, y, z, 2);
                        }
                    }
                }
            }
            # A pocket of air off the tunnel's roof: a secret, and a reward.
            pocket_x = wall_x + self.tunnel // 2 - 1;
            build.room(pocket_x, self.lane, -2, pocket_x + 2, self.lane + 3, 1);
            build.secret(float(pocket_x), float(self.lane), -2.0, float(pocket_x + 2), float(self.lane + 3), 1.0);
            build.supply(float(pocket_x) + 1.0, float(self.lane) + 1.5, -6, "item_armor1");
            build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "The way on is under the water");
        }
        # An upper floor over the far room's far end (and its pool) on
        # pillars, a stair or a lift up to it beside the side wall, the way
        # out from it.
        mezz_x = far_x + (4 if self.lifted else 10);
        slab(build, mezz_x, 1, self.long - 1, self.wide - 1, 9);
        # Its pillars clear of the far pool's steps, whose top they would
        # shut.
        for y in range(3, self.wide - 5, 4) {
            if self.open_water or not self.lifted or y < self.lane - 2 or y >= self.lane + 6 {
                build.solid(mezz_x, y, 0, mezz_x + 1, y + 1, 8);
            }
        }
        if self.lifted {
            lift(build, far_x + 1, self.wide - 4, far_x + 4, self.wide - 1, 0, 9);
            keep_box(build, second, far_x, self.wide - 5, far_x + 5, self.wide - 1, 0);
        } else {
            stair(build, far_x + 1, self.wide - 4, 0, 0, 9, 3);
        }
        keep_box(build, second, mezz_x - 2, self.wide - 5, mezz_x + 1, self.wide - 1, 9);
        build.level(second, 9);
        # The upper floor runs back over the wall into the near room (clear
        # of the climb), its near edge open to drop from: a way back without
        # the swim.
        back_x = wall_x - 4;
        if not self.open_water {
            build.widen(second, wall_x, 1, 9, far_x, self.wide - 5, self.tall);
        }
        slab(build, back_x, 1, mezz_x, self.wide - 5, 9);
        keep_box(build, second, back_x, 3, back_x + 1, 7, 9);
        build.foe(float(back_x) + 1.5, 2.5, 9, "monster_army", 90.0, patrol=[[float(back_x) + 1.5, 2.5], [float(back_x) + 1.5, float(self.wide) - 6.5]]);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(second, port);
        }
        # The far room's watch wakes as the swimmer climbs out.
        out = build.touch(float(far_x), 1.0, -2.0, float(far_x + 6), float(self.wide - 1), 6.0);
        watch = build.waiting();
        out +>:Fires:+> watch;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * 2.5, 0, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=watch);
        }
        build.foe(float(self.long) - 2.5, float(self.wide) - 2.5, 9, e1m2_foe(dice, self.danger), 180.0, waits=watch);
        build.foe(2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall_x) + 1.5 + float(index) * 2.0, float(self.lane) + 1.5, -5, "monster_fish", 0.0);
        }
        build.supply(float(far_x) + 6.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
    }
}

"""A ledge, a pit and a far ledge; trains ferry a body across when a button
starts them, and closets in the far ledge's wall open a few seconds on."""
node FerryHall(Prefab) {
    has near: int = 6,
        span: int = 12,
        far_side: int = 6,
        hw: int = 18,
        ledge: int = 6,
        tall: int = 22,
        wet: bool = True,
        twin: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ferry hall";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.near = dice.between(6, 7);
        self.span = dice.between(11, 14);
        self.far_side = dice.between(6, 8);
        self.hw = dice.between(17, 20);
        self.wide = self.hw + 6;
        self.tall = self.ledge + dice.between(15, 17);
        self.wet = dice.chance(0.95);
        self.twin = dice.chance(0.5);
        self.long = 1 + self.near + self.span + self.far_side + 1;
        self.low = -1;
        self.high = self.tall + 1;
        mid = 5 + self.hw // 2;
        land = 1 + self.near + self.span;
        self.enter = Port(face=2, along=float(mid), floor=self.ledge);
        self.leaves = [
            Port(face=0, along=float(mid), floor=self.ledge),
            Port(face=1, along=float(land + 3), floor=self.ledge)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        hall = build.room(1, y0, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        cut = 1 + self.near;
        land = cut + self.span;
        mid = y0 + self.hw // 2;
        # The pit: water to a lift under the ledges, or a dry floor running
        # on under the ledges (slabs on pillars); steps up to both ledges
        # along the side walls.
        if self.wet {
            build.solid(1, y0, 0, cut, self.wide - 1, self.ledge);
            build.solid(land, y0, 0, self.long - 1, self.wide - 1, self.ledge);
            build.pool(cut, y0, 0, land, self.wide - 1, self.ledge, 2, False, False);
        } else {
            slab(build, 1, y0, cut, self.wide - 1, self.ledge);
            slab(build, land, y0, self.long - 1, self.wide - 1, self.ledge);
            arcade(build, cut - 1, y0 + 2, self.wide - 2, 0, self.ledge - 1, 4, True);
            arcade(build, land, y0 + 2, self.wide - 2, 0, self.ledge - 1, 4, True);
        }
        stair(build, cut + self.ledge - 1, y0, 0, 2, self.ledge, 2);
        stair(build, land - self.ledge, self.wide - 3, 0, 0, self.ledge, 2);
        keep_box(build, hall, cut - 1, y0, cut + 1, y0 + 3, self.ledge);
        keep_box(build, hall, land - 1, self.wide - 4, land + 1, self.wide - 1, self.ledge);
        # The trains, platforms that ride from ledge to ledge and back once
        # the button starts them.
        lanes = [mid - 5, mid + 2] if self.twin else [mid - 1];
        start = build.push(1.0, float(mid) + 3.5, float(self.ledge) + 1.2, 0);
        for lane in lanes {
            ride = build.train([3.0, 3.0, 1.0], [[float(cut), float(lane), float(self.ledge - 1)], [float(land - 3), float(lane), float(self.ledge - 1)]], 90.0, 2.0, True);
            start +>:Fires:+> ride;
            for across in range(3) {
                build.keep(hall, cut - 1, lane + across, self.ledge);
                build.keep(hall, land, lane + across, self.ledge);
            }
        }
        # A lift from the near ledge's corner up to a catwalk high across the
        # pit by the side wall, its far end over the far ledge open to drop
        # from.
        high = self.ledge + 9;
        lift(build, cut - 3, self.wide - 4, cut, self.wide - 1, self.ledge, high);
        slab(build, cut, self.wide - 4, land + 2, self.wide - 1, high);
        keep_box(build, hall, cut - 4, self.wide - 5, cut + 1, self.wide - 1, high);
        keep_box(build, hall, cut - 4, self.wide - 5, cut, self.wide - 1, self.ledge);
        keep_box(build, hall, land + 1, self.wide - 5, land + 2, self.wide - 1, high);
        build.level(hall, high);
        build.foe(float(cut) + float(self.span) * 0.5, float(self.wide) - 2.5, high, e1m2_foe(dice, self.danger), 180.0);
        # A few seconds on, the closets in the far ledge's side wall open.
        later = build.delay(4.0);
        start +>:Fires:+> later;
        starts = [at for at in [land + 1, land + 5] if at + 3 <= self.long - 1];
        closets(build, later, y0, starts, self.ledge, 3, [e1m2_foe(dice, self.danger, True), e1m2_foe(dice, self.danger, True)]);
        build.touch(1.0, float(y0), float(self.ledge), 4.0, float(self.wide - 1), float(self.ledge + 6), True, "Press the button to start the ferries");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 3)) {
            build.foe(float(cut) + 3.5 + float(index) * 3.0, float(mid) + 0.5, self.ledge + 5, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(land) + 1.5, float(y0) + 2.5, self.ledge, "monster_knight", 90.0, patrol=[[float(land) + 1.5, float(y0) + 2.5], [float(land) + 1.5, float(self.wide) - 3.5]]);
        # A teleporter in the far ledge's corner back to the near ledge.
        build.teleporter(float(self.long) - 2.5, float(y0) + 3.5, self.ledge, 3.5, float(y0) + 3.5, self.ledge, 0.0);
        if self.wet and dice.chance(0.5) {
            build.foe(float(cut) + float(self.span) * 0.5, float(mid) + 0.5, 1, "monster_fish", 0.0);
        }
        build.supply(2.5, float(y0) + 1.5, self.ledge, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.ledge, "item_rockets");
    }
}

"""The hub: a gallery round the walls (or two galleries and a catwalk across
the middle) over an arcade, a stair or a lift up, a fountain."""
node GreatHall(Prefab) {
    has gallery: int = 10,
        tall: int = 24,
        ring: bool = True,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Great hall";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.long = dice.between(27, 32);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(22, 26);
        self.gallery = dice.between(10, 11);
        self.ring = dice.chance(0.5);
        self.climb = dice.below(2);
        self.low = -12;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2 + dice.between(-3, 3)), floor=self.gallery),
            Port(face=3, along=float(self.long // 2 + 6 + dice.between(0, 3)), floor=self.gallery),
            Port(face=1, along=float(self.long - 6), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        inner = 5;
        far_y = self.wide - 5;
        cx = self.long // 2;
        cy = self.wide // 2;
        # The galleries along both long walls over arcades; round the short
        # walls too, or a catwalk across the middle between them.
        slab(build, 1, 1, self.long - 1, inner, self.gallery);
        slab(build, 1, far_y, self.long - 1, self.wide - 1, self.gallery);
        arcade(build, inner - 1, 6, self.long - 4, 0, self.gallery - 1, 5, False);
        arcade(build, far_y, 6, self.long - 9, 0, self.gallery - 1, 5, False);
        if self.ring {
            slab(build, 1, inner, 4, far_y, self.gallery);
            slab(build, self.long - 4, inner, self.long - 1, far_y, self.gallery);
        } else {
            # The catwalk clear of the stair's climb.
            walk_x = min(max(cx, 8 + self.gallery), self.long - 9);
            slab(build, walk_x, inner, walk_x + 4, far_y, self.gallery);
            for y in range(inner - 1, far_y + 1) {
                build.keep(hall, walk_x, y, self.gallery);
                build.keep(hall, walk_x + 3, y, self.gallery);
            }
        }
        # Up to the near gallery: a stair along it, or a lift.
        stair_x = 6;
        if self.climb == 0 {
            stair(build, stair_x, inner, 0, 0, self.gallery, 2);
            keep_box(build, hall, stair_x + self.gallery - 3, inner - 1, stair_x + self.gallery + 1, inner + 2, self.gallery);
        } else {
            lift(build, stair_x, inner, stair_x + 3, inner + 3, 0, self.gallery);
            keep_box(build, hall, stair_x - 1, inner - 1, stair_x + 4, inner + 4, self.gallery);
            keep_box(build, hall, stair_x - 1, inner, stair_x + 4, inner + 4, 0);
        }
        top_x = stair_x + (self.gallery if self.climb == 0 else 2);
        # The flooded nave: a pool from the middle to near the far end, a well
        # in its bed, steps up out of it, aisles dry along both galleries.
        build.pool(cx - 5, inner + 2, -5, self.long - 5, far_y - 1, 0, 2);
        sump(build, cx + 3, cy - 1, -11, -5, 3);
        # A teleporter in the floor up to the far gallery.
        build.teleporter(float(cx) - 7.5, float(cy) + 0.5, 0, float(self.long) - 7.5, float(self.wide) - 3.0, self.gallery, 180.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The gallery's guards wake as the player comes up onto it.
        onto = build.touch(float(top_x - 2), 1.0, float(self.gallery), float(top_x + 2), float(inner), float(self.gallery + 6));
        guards = build.waiting();
        onto +>:Fires:+> guards;
        build.foe(float(self.long) - 3.5, 2.5, self.gallery, e1m2_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 6.5, float(self.wide) - 2.5, self.gallery, e1m2_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(5.5, float(self.wide) - 2.5, self.gallery, "monster_knight", 0.0, patrol=[[5.5, float(self.wide) - 2.5], [float(self.long) - 9.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 6 + index * 4) + 0.5, float(inner) + 0.5, 0, e1m2_foe(dice, self.danger), 180.0);
        }
        build.foe(8.5, float(far_y) - 0.5, 0, "monster_army", 0.0, patrol=[[8.5, float(far_y) - 0.5], [float(self.long) - 8.5, float(far_y) - 0.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, self.gallery + 4, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        build.supply(2.5, float(cy) + 4.5, 0, "item_health");
        build.foe(float(cx) + 4.5, float(cy) + 0.5, -4, "monster_fish", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, "item_rockets");
        build.supply(float(cx) + 0.5, 2.5, self.gallery, "item_health");
    }
}

"""The key room: the key high on a dais up a stair or a ledge ridden up to;
closets opening as the climb begins and as the key is taken; the quad in a
stash in the dais."""
node KeyTower(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 14,
        tall: int = 18,
        dais: int = 6,
        rise_to: int = 8,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key tower (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.hall_wide = dice.between(14, 16);
        self.tall = dice.between(19, 22);
        self.dais = dice.between(9, 11);
        self.rise_to = dice.between(8, 10);
        self.climb = dice.below(2);
        self.long = self.dais + self.rise_to + dice.between(13, 16);
        # Closets stand beyond both side walls.
        self.wide = self.hall_wide + 8;
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(4 + dice.between(3, self.hall_wide - 4)), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        y1 = 5 + self.hall_wide - 2;
        hall = build.room(1, y0, 0, self.long - 1, y1, self.tall, variant=dice.below(3));
        build.level(hall, self.rise_to);
        dais_x = self.long - 1 - self.dais;
        # The dais a slab on pillars, an undercroft under it.
        slab(build, dais_x, y0, self.long - 1, y1, self.rise_to);
        arcade(build, dais_x, y0 + 2, y1 - 4, 0, self.rise_to - 1, 3, True);
        # A balcony along the near side wall at the dais's height, joined to
        # it, over the closets' doors.
        slab(build, 3, y0, dais_x, y0 + 4, self.rise_to);
        arcade(build, y0 + 3, 6, dais_x - 2, 0, self.rise_to - 1, 4, False);
        # The undercroft flooded, but for a dry walk by its side wall.
        build.pool(dais_x + 1, y0 + 3, -4, self.long - 1, y1, 0, 2);
        # Up to the dais: a stair along the side wall, or a lift.
        stair_x = dais_x - self.rise_to;
        if self.climb == 0 {
            stair(build, stair_x, y1 - 3, 0, 0, self.rise_to, 3);
            keep_box(build, hall, dais_x - 1, y1 - 4, dais_x + 1, y1, self.rise_to);
            foot = [stair_x - 3, y1 - 4, stair_x, y1];
            clear_x = stair_x - 1;
        } else {
            lift(build, dais_x - 3, y1 - 3, dais_x, y1, 0, self.rise_to);
            keep_box(build, hall, dais_x - 4, y1 - 4, dais_x + 1, y1, self.rise_to);
            keep_box(build, hall, dais_x - 4, y1 - 4, dais_x, y1, 0);
            foot = [dais_x - 6, y1 - 4, dais_x - 3, y1];
            clear_x = dais_x - 4;
        }
        build.doorway(hall, self.enter);
        # The closets on one side wall open as the climb begins; those on the
        # other as the key is taken.
        climbing = build.touch(float(foot[0]), float(foot[1]), 0.0, float(foot[2]), float(foot[3]), 6.0);
        near_side = [at for at in [4, 9, 14, 19] if at + 3 <= dais_x - 1];
        closets(build, climbing, y0, near_side[:3], 0, 3, [e1m2_foe(dice, self.danger), "monster_knight"]);
        taken = key_cue(build, self.key, float(dais_x) + float(self.dais) * 0.5, float(y0 + y1) * 0.5, self.rise_to);
        far_side = [at for at in [3, 8, 13] if at + 3 < clear_x];
        closets(build, taken, y1, far_side, 0, 1, [e1m2_foe(dice, self.danger, True), e1m2_foe(dice, self.danger)]);
        # And a foe is sent in behind the taker, at the dais's foot.
        taken +>:Fires:+> build.summon(3, (y0 + y1) // 2 - 1, -8, e1m2_foe(dice, self.danger, True), float(stair_x) - 2.5, float(y0 + y1) * 0.5, 0, 0.0);
        # The quad in a stash in the undercroft's side wall.
        stash(build, y0, dais_x + 2, 0, 3, "item_artifact_super_damage");
        build.foe(4.5, float(y0) + 5.5, 0, "monster_knight", 0.0, patrol=[[4.5, float(y0) + 5.5], [float(stair_x) - 2.5, float(y0) + 5.5]]);
        build.foe(float(dais_x) - 3.5, float(y0) + 1.5, self.rise_to, e1m2_foe(dice, self.danger), 180.0);
        # Crates two lifts high about the hall's middle.
        kept: list[list[int]] = [[0, int(self.enter.along) - 3, 6, int(self.enter.along) + 3]];
        for index in range(dice.between(2, 3)) {
            x = dice.between(6, max(6, clear_x - 6));
            y = dice.between(y0 + 7, max(y0 + 7, y1 - 6));
            if apart([x, y, x + 2, y + 2], kept) {
                build.solid(x, y, 0, x + 2, y + 2, 2);
                kept.append([x, y, x + 2, y + 2]);
            }
        }
        build.foe(float(self.long) - 2.5, float(y0) + 1.5, self.rise_to, e1m2_foe(dice, self.danger, True), 180.0);
        if dice.chance(0.6) {
            build.foe(float(dais_x) - 4.5, float(y0 + y1) * 0.5, 6, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        build.supply(2.5, float(y1) - 2.5, 0, "item_health");
        build.supply(float(dais_x) + 1.5, float(y1) - 1.5, self.rise_to, "item_spikes");
    }
}

"""The end: a pillared hall with balconies, a door in its far wall, the way
out under an arch beyond, on a dais or down in a sunken court."""
node CastleExit(Prefab) {
    has key: str = "",
        wall_x: int = 16,
        tall: int = 16,
        balcony: int = 6,
        sunk: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Castle exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M2;
        self.district = level_district(E1M2);
        self.long = dice.between(31, 35);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 18);
        self.balcony = dice.between(6, 7);
        self.sunk = dice.chance(0.5);
        self.wall_x = self.long - 1 - dice.between(10, 12);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        hall = build.room(1, 1, 0, self.wall_x, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        build.doorway(hall, self.enter);
        # Balconies along both walls the hall's length, a stair up to
        # each from the floor.
        bx = self.balcony + 3;
        slab(build, bx, 1, self.wall_x, 4, self.balcony);
        slab(build, bx, self.wide - 4, self.wall_x, self.wide - 1, self.balcony);
        stair(build, bx - self.balcony, 1, 0, 0, self.balcony, 3);
        stair(build, bx - self.balcony, self.wide - 4, 0, 0, self.balcony, 3);
        keep_box(build, hall, bx - 1, 1, bx + 1, 4, self.balcony);
        keep_box(build, hall, bx - 1, self.wide - 4, bx + 1, self.wide - 1, self.balcony);
        # A channel of water across the hall under the balconies, a
        # footbridge over it in the middle, steps out on both sides of it.
        cut = max(bx + 1, self.wall_x - 9);
        build.pool(cut, 1, -4, cut + 7, self.wide - 1, 0, 2, False, True, True);
        build.solid(cut, mid - 2, -4, cut + 7, mid + 2, 0);
        keep_box(build, hall, cut - 1, mid - 2, cut + 8, mid + 2, 0);
        for line in [3, self.wide - 4] {
            arcade(build, line, bx + 2, cut - 1, 0, self.balcony - 1, 3, False);
            arcade(build, line, cut + 8, self.wall_x - 1, 0, self.balcony - 1, 3, False);
        }
        # The door through the far wall: a key's, or one that opens as the
        # player comes up to it.
        floor = -4 if self.sunk else 0;
        chamber = build.room(self.wall_x + 1, 1, floor, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.widen(chamber, self.wall_x, mid - 2, 0, self.wall_x + 1, mid + 2, 8);
        near = build.touch(float(self.wall_x - 4), float(mid - 2), 0.0, float(self.wall_x), float(mid + 2), 6.0);
        if self.key {
            build.rising_door(float(self.wall_x), float(mid - 2), 0.0, float(self.wall_x + 1), float(mid + 2), 8.0, {"key": self.key, "wait": "-1"});
        } else {
            near +>:Fires:+> build.opened(float(self.wall_x), float(mid - 2), 0.0, float(self.wall_x + 1), float(mid + 2), 8.0);
        }
        # Beyond: a landing, then a stair down into a sunken court, or a dais
        # up two steps; the arch and the way out on it.
        landing_x = self.wall_x + 1;
        if self.sunk {
            build.solid(landing_x, 1, -4, landing_x + 2, self.wide - 1, 0);
            stair(build, landing_x + 5, mid - 2, -4, 2, 4, 4);
            gate_floor = -4;
        } else {
            build.solid(landing_x + 3, 2, 0, self.long - 1, self.wide - 2, 1);
            build.solid(landing_x + 4, 2, 1, self.long - 1, self.wide - 2, 2);
            gate_floor = 2;
        }
        gate_x = self.long - 4;
        build.solid(gate_x, mid - 2, gate_floor, gate_x + 1, mid - 1, gate_floor + 7);
        build.solid(gate_x, mid + 1, gate_floor, gate_x + 1, mid + 2, gate_floor + 7);
        build.solid(gate_x, mid - 2, gate_floor + 7, gate_x + 1, mid + 2, gate_floor + 8);
        build.way_out(float(gate_x) + 0.5, float(mid), gate_floor);
        build.touch(float(gate_x - 3), float(mid - 3), float(gate_floor), float(gate_x), float(mid + 3), float(gate_floor + 6), False, "Pass through the arch to exit");
        # The balconies' guards wake as the player nears the door; knights
        # wait beyond it.
        guards = build.waiting();
        near +>:Fires:+> guards;
        if dice.chance(0.6) {
            near +>:Fires:+> build.summon(3, mid - 1, -8, e1m2_foe(dice, self.danger, True), 3.5, float(mid) + 0.5, 0, 0.0);
        }
        for y in [2.5, float(self.wide) - 2.5] {
            build.foe(float(self.wall_x) - 2.5, y, self.balcony, e1m2_foe(dice, self.danger, True), 180.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x) - 2.5, 3.5 + float(index) * 3.0, gate_floor, e1m2_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(3.5, float(mid) + 0.5, 0, "monster_knight", 0.0, patrol=[[3.5, float(mid) + 0.5], [float(self.wall_x) - 5.5, float(mid) + 0.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.wall_x) - 1.5, 2.0, self.balcony, "item_rockets");
    }
}

"""e1m2's stretches: [name, role] (start, flow, hub, keyroom, end, gate)."""
glob E1M2_STRETCHES: list[list[str]] = [
         ["moat", "start"],
         ["spikes", "flow"],
         ["barred", "flow"],
         ["drawbridge", "flow"],
         ["flooded", "flow"],
         ["ferry", "flow"],
         ["great", "hub"],
         ["key", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e1m2's stretches by its name (`key` the key a key room holds or
a gate wants)."""
def make_e1m2(name: str, key: str) -> Prefab {
    if name == "moat" {
        return MoatGate();
    }
    if name == "spikes" {
        return SpikeCorridor();
    }
    if name == "barred" {
        return BarredHall();
    }
    if name == "drawbridge" {
        return Drawbridge();
    }
    if name == "flooded" {
        return FloodedPassage();
    }
    if name == "ferry" {
        return FerryHall();
    }
    if name == "great" {
        return GreatHall();
    }
    if name == "key" {
        return KeyTower(key=key if key else "key_silver");
    }
    return CastleExit(key=key);
}
