"""Prefabs drawn from e1m5, Gloom Keep: a keep of courtyards under the sky,
its walls walked along their tops, spikes flying across its walks and
bridges, its flooded crypts and the great lift up out of them, its throne
hall, the vault whose cells hold the keep's worst, its key at the top of a
tower, its gate and drawbridge. Raised in e1m5's own palette. Each stretch
takes its shape from its dice as well as its sizes.

- `KeepCourtyard`: the start. A courtyard under the sky, wall-walks on
  three sides on arcades (stairs or lifts up to them), a well; stepping
  out wakes the walks' guards and brings scrags in by teleporters (e1m5's
  first ambush); a stash in the corner tower's base.
- `Battlements`: a ward and the wall-walk over a covered gallery along it,
  a tower stair or a lift up, sometimes a bridge across the ward from the
  walk; spikes fly across the walk (or the gallery under it) while anyone
  is there (e1m5's spike traps); reaching the walk's end brings scrags in.
- `ThroneKeep`: the hub: the keep's hall, its dais and two galleries at
  the dais's height in a U over the aisles and an undercroft, a grand
  stair up (a stash in its flank). Pressing the button on the throne opens
  the cells under the south gallery and brings fiends in by teleporters.
- `KeyTower`: the key room: a tall tower, lifts up its middle to a landing
  and the top floor, the key there; taking it opens the rooms off the
  landing and sends one more in behind; a stash at its foot.
- `SpikeBridge`: a hall cut by a flooded channel, crossed on a platform
  riding to and fro (e1m5's train) or on a bridge drawn up by a shot
  button; spikes fly across the crossing; a balcony over the far floor
  (a lift up to it) whose archers wake as the player lands; an underwater
  niche a secret.
- `FloodedCrypt`: a crypt flooded between its ends, columns standing in
  the water; crossed on a catwalk (a lift up to it, scrags sent in on the
  way) or from column to column, or swum; the great lift on the far side
  up to a gallery and a way on high (e1m5's tall plat).
- `ShamblerVault`: a vault walled off at its far end, galleries over the
  cells along both sides, a channel across it under a causeway. The
  button (on a plinth, or high on the far wall reached by a catwalk) opens
  the door on, and the cells, and what is worst in the keep comes out
  (e1m5's shamblers), fiends sent in behind; a stash in a stair.
- `PortcullisGate`: the end: a gatehouse with balconies, a portcullis (a
  key's, as a gate, or one opened as it is neared), a moat beyond with a
  drawbridge drawn by a button, the way out on the far bank; a secret
  teleporter in a stash to the far bank (e1m5's secret way out)."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, apart, lift }
import from .e1m2_parts { slab, keep_box, keep_ring, arcade, stash, closets, spike_wall, key_cue, flood, sump, low_rocks }

glob E1M5: str = "q1:e1m5";

"""e1m5's foes: knights above all, ogres on the walls, fiends deeper in."""
def e1m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_knight", "monster_knight", "monster_ogre"] if heavy else ["monster_knight", "monster_knight", "monster_army"], ["monster_demon1"] if heavy else ["monster_ogre"], danger));
}

"""The worst a vault holds: a shambler deep in a run, else ogres and
fiends."""
def e1m5_worst(dice: Stream, danger: float) -> str {
    if danger >= 0.6 and dice.chance(0.6) {
        return "monster_shambler";
    }
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"], ["monster_demon1"], danger));
}

"""Crenels along a wall-walk's open edge: a merlon a cell square and two
lifts high every other cell from `start` to `finish` along the line
(x when `along_x`) at `line`, on lift `z`."""
def crenels(build: Raising, line: int, start: int, finish: int, z: int, along_x: bool) {
    for at in range(start, finish, 2) {
        if along_x {
            build.solid(at, line, z, at + 1, line + 1, z + 2);
        } else {
            build.solid(line, at, z, line + 1, at + 1, z + 2);
        }
    }
}

"""The start: a courtyard under the sky, wall-walks on three sides."""
node KeepCourtyard(Prefab) {
    has walk: int = 9,
        deep: int = 4,
        tall: int = 20,
        lifted: bool = False,
        well: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep courtyard";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(20, 23);
        self.walk = dice.between(9, 10);
        self.lifted = dice.chance(0.4);
        self.well = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=3, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=float(self.wide - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.walk);
        mid = self.wide // 2;
        y0 = 1 + self.deep;
        y1 = self.wide - 1 - self.deep;
        far_x = self.long - 1 - self.deep;
        # The corner tower's base, and the walks on arcades: south, north,
        # and east over the gate passage.
        build.solid(1, 1, 0, 5, y0, self.walk);
        slab(build, 5, 1, self.long - 1, y0, self.walk);
        slab(build, 1, y1, self.long - 1, self.wide - 1, self.walk);
        slab(build, far_x, y0, self.long - 1, y1, self.walk);
        arcade(build, y0 - 1, 9, far_x - 1, 0, self.walk - 1, 4, False);
        arcade(build, y1, 9, far_x - 1, 0, self.walk - 1, 4, False);
        arcade(build, far_x, y0 + 1, mid - 3, 0, self.walk - 1, 4, True);
        arcade(build, far_x, mid + 4, y1 - 1, 0, self.walk - 1, 4, True);
        crenels(build, y0 - 1, self.walk + 9, far_x, self.walk, True);
        crenels(build, y1, self.walk + 9, far_x, self.walk, True);
        # Up to the south and north walks: a stair against each, or a lift.
        for at in [y0, y1 - 3] {
            if self.lifted {
                lift(build, 5, at, 8, at + 3, 0, self.walk);
                keep_box(build, court, 4, at - 1, 9, at + 4, self.walk);
                keep_box(build, court, 4, at, 9, at + 3, 0);
            } else {
                stair(build, 5, at, 0, 0, self.walk, 3);
                keep_box(build, court, 3 + self.walk, at - 1, 6 + self.walk, at + 4, self.walk);
            }
        }
        # The well.
        if self.well {
            build.pool(self.long // 2 - 2, mid - 2, -5, self.long // 2 + 3, mid + 3, 0, 2);
            sump(build, self.long // 2, mid, -10, -5, 2);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        stash(build, y0, 1, 0, 3, "item_armor1");
        # A hoist by the east walk, riding up to it and down again.
        build.train([3.0, 3.0, 1.0], [[float(far_x - 3), float(y1 - 6), -1.0], [float(far_x - 3), float(y1 - 6), float(self.walk - 1)]], 100.0, 2.0);
        keep_box(build, court, far_x - 1, y1 - 7, far_x + 1, y1 - 2, self.walk);
        blocks = [[4, y0, 16, y0 + 4], [4, y1 - 4, 16, y1], [self.long // 2 - 3, mid - 3, self.long // 2 + 4, mid + 6], [far_x - 4, mid - 3, far_x, mid + 3], [self.long // 2 - 1, mid + 3, self.long // 2 + 8, mid + 6], [far_x - 5, y1 - 8, far_x, y1 - 1]];
        low_rocks(build, dice, 9, y0, far_x, y1, 0, dice.between(3, 5), 2, blocks);
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) + 2.5, 0, "item_shells");
        # Stepping out wakes the walks' guards and brings scrags in.
        out = build.touch(4.0, float(y0), 0.0, 7.0, float(y1), 6.0);
        guards = build.waiting();
        out +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(far_x) + 2.0, float(y0 + 2 + index * 4) + 0.5, self.walk, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        }
        for index in range(2) {
            out +>:Fires:+> build.summon(9 + index * 5, 1, -8, "monster_wizard", float(self.long // 2 + index * 3) + 0.5, float(mid) + 0.5, 6, 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(mid) + 4.5, 0, e1m5_foe(dice, self.danger), 180.0);
        }
        build.foe(10.5, float(self.wide) - 3.0, self.walk, "monster_knight", 0.0, patrol=[[10.5, float(self.wide) - 3.0], [float(far_x) - 1.5, float(self.wide) - 3.0]]);
        build.foe(float(far_x) + 2.0, float(y0) + 1.0, self.walk, "monster_army", 90.0, patrol=[[float(far_x) + 2.0, float(y0) + 1.0], [float(far_x) + 2.0, float(y1) - 1.0]]);
        build.supply(float(self.long) - 2.5, 2.5, self.walk, "item_health");
    }
}

"""A ward and the wall-walk over a covered gallery along it; spikes across
the walk or the gallery; sometimes a bridge across the ward."""
node Battlements(Prefab) {
    has walk: int = 9,
        deep: int = 5,
        tall: int = 20,
        lifted: bool = False,
        bridge: bool = False,
        low_spikes: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Battlements";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(20, 23);
        self.walk = dice.between(9, 10);
        self.lifted = dice.chance(0.4);
        self.bridge = dice.chance(0.5);
        self.low_spikes = dice.chance(0.5);
        self.low = -11;
        self.high = self.tall + 1;
        wall_y = self.wide - 1 - self.deep;
        self.enter = Port(face=2, along=float(dice.between(3, wall_y - 7)), floor=0);
        self.leaves = [
            Port(face=0, along=float(wall_y + 3), floor=self.walk),
            Port(face=1, along=float(self.long - 6), floor=self.walk),
            Port(face=0, along=float(dice.between(3, wall_y - 4)), floor=0)
        ];
        if self.bridge {
            self.leaves.append(Port(face=3, along=float(self.long // 2 + 1), floor=self.walk));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        ward = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ward, self.walk);
        wall_y = self.wide - 1 - self.deep;
        bx = self.long // 2 - 1;
        # The walk along the far side, over a covered gallery on columns.
        slab(build, 1, wall_y, self.long - 1, self.wide - 1, self.walk);
        arcade(build, wall_y, 8, self.long - 3, 0, self.walk - 1, 4, False);
        if self.bridge {
            crenels(build, wall_y, self.walk + 6, bx - 1, self.walk, True);
            crenels(build, wall_y, bx + 5, self.long - 2, self.walk, True);
            # A bridge across the ward from the walk to the near wall.
            slab(build, bx, 1, bx + 4, wall_y, self.walk);
            keep_box(build, ward, bx - 1, wall_y - 1, bx + 5, wall_y + 2, self.walk);
        } else {
            crenels(build, wall_y, self.walk + 6, self.long - 2, self.walk, True);
        }
        # Up a tower stair at the near end, or a lift.
        if self.lifted {
            lift(build, 2, wall_y - 3, 5, wall_y, 0, self.walk);
            keep_box(build, ward, 1, wall_y - 4, 6, wall_y + 1, self.walk);
            keep_box(build, ward, 1, wall_y - 4, 6, wall_y, 0);
            top_x = 4;
        } else {
            stair(build, 2, wall_y - 3, 0, 0, self.walk, 3);
            keep_box(build, ward, self.walk - 1, wall_y - 3, self.walk + 3, wall_y + 1, self.walk);
            top_x = self.walk + 1;
        }
        # A hoist at the ward's far end, a platform riding up to the walk
        # and down again.
        hx = self.long - 7;
        build.train([3.0, 3.0, 1.0], [[float(hx), float(wall_y - 3), -1.0], [float(hx), float(wall_y - 3), float(self.walk - 1)]], 100.0, 2.0);
        keep_box(build, ward, hx - 1, wall_y - 1, hx + 4, wall_y + 1, self.walk);
        keep_box(build, ward, hx - 1, wall_y - 4, hx + 4, wall_y, 0);
        # A well in the ward (under the bridge, when there is one), blocks of
        # stone about it.
        build.pool(bx - 1, 3, -5, bx + 5, 9, 0, 2);
        sump(build, bx + 2, 5, -10, -5, 2);
        blocks = [[bx - 2, 0, bx + 6, 10], [self.long // 3 - 1, wall_y - 5, self.long // 3 + 10, wall_y], [self.long - 9, 0, self.long, wall_y], [0, 0, self.walk + 4, wall_y]];
        low_rocks(build, dice, 1, 1, self.long - 1, wall_y, 0, dice.between(3, 5), 2, blocks);
        build.doorway(ward, self.enter);
        for port in self.taken {
            build.doorway(ward, port);
        }
        # The spikes, across the walk or the gallery under it, while anyone
        # walks there.
        sx = self.walk + 6;
        if self.low_spikes {
            walking = build.touch(float(sx), float(wall_y), 0.0, float(self.long - 4), float(self.wide - 1), 6.0, False);
            spike_wall(build, walking, self.wide - 1, sx + 1, self.long - 4, 1.5, 3, False, 3);
        } else {
            walking = build.touch(float(sx), float(wall_y), float(self.walk), float(self.long - 4), float(self.wide - 1), float(self.walk + 6), False);
            spike_wall(build, walking, self.wide - 1, sx + 1, self.long - 4, float(self.walk) + 1.5, 3, False, 3);
        }
        # The walk's guards wake at the climb's top; scrags come in as its
        # far end is reached.
        topped = build.touch(float(top_x - 2), float(wall_y - 1), float(self.walk), float(top_x + 2), float(self.wide - 1), float(self.walk + 6));
        guards = build.waiting();
        topped +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 4 - index * 6) + 0.5, float(wall_y) + 2.5, self.walk, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        }
        far_end = build.touch(float(self.long - 8), float(wall_y), float(self.walk), float(self.long - 4), float(self.wide - 1), float(self.walk + 6));
        for index in range(2) {
            far_end +>:Fires:+> build.summon(4 + index * 5, 1, -8, "monster_wizard", float(self.long // 2 - 4 + index * 6) + 0.5, float(wall_y // 2) + 0.5, 6, 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 3 + index * 4) + 0.5, float(wall_y) - 3.5, 0, e1m5_foe(dice, self.danger), 0.0);
        }
        build.foe(float(sx) + 0.5, float(self.wide) - 2.5, 0, "monster_knight", 0.0, patrol=[[float(sx) + 0.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.walk, "item_rockets");
    }
}

"""The hub: the keep's hall, a dais and galleries at its height in a U, a
grand stair up; the button on the throne opens the cells."""
node ThroneKeep(Prefab) {
    has dais: int = 7,
        rise_to: int = 9,
        hw: int = 18,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Throne keep";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(30, 34);
        self.hw = dice.between(18, 22);
        self.wide = self.hw + 6;
        self.tall = dice.between(22, 26);
        self.dais = dice.between(7, 8);
        self.low = -11;
        self.high = self.tall + 1;
        mid = (5 + self.wide - 1) // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid), floor=self.rise_to),
            Port(face=1, along=float(self.long // 2), floor=self.rise_to),
            Port(face=3, along=float(self.long // 2), floor=self.rise_to),
            Port(face=0, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        y1 = self.wide - 1;
        mid = (y0 + y1) // 2;
        r = self.rise_to;
        hall = build.room(1, y0, 0, self.long - 1, y1, self.tall, variant=dice.below(4));
        build.level(hall, r);
        dais_x = self.long - 1 - self.dais;
        # The dais over an undercroft, and the galleries along both walls at
        # its height over the aisles, joined to it.
        slab(build, dais_x, y0, self.long - 1, y1, r);
        slab(build, 6, y0, dais_x, y0 + 4, r);
        slab(build, 6, y1 - 4, dais_x, y1, r);
        arcade(build, dais_x, y0 + 5, y1 - 5, 0, r - 1, 3, True);
        arcade(build, y0 + 3, 9, dais_x - 1, 0, r - 1, 4, False);
        arcade(build, y1 - 4, 9, dais_x - 1, 0, r - 1, 4, False);
        # The grand stair up to the dais, a stash in its flank.
        stair(build, dais_x - r, mid - 2, 0, 0, r, 4);
        keep_box(build, hall, dais_x - 2, mid - 3, dais_x + 1, mid + 3, r);
        stash(build, mid + 2, dais_x - 4, 0, 3, "item_artifact_super_damage");
        # Two long basins either side of the middle aisle, wells in them.
        basin_x1 = dais_x - r - 2;
        for at in [mid - 5, mid + 2] {
            build.pool(6, at, -5, basin_x1, at + 3, 0, 2);
            sump(build, basin_x1 - 4, at, -10, -5, 3);
        }
        # The throne against the far wall off the middle, the button on it.
        build.solid(self.long - 3, mid - 7, r, self.long - 2, mid - 3, r + 3);
        press = build.push(float(self.long - 3), float(mid) - 5.0, float(r) + 1.5, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.face == 3 {
                # Out through the cells' wall from the south gallery.
                low = int(port.along) - 2;
                build.widen(hall, low, 1, r, low + 4, y0, r + 8);
                slab(build, low, 1, low + 4, y0, r);
            }
            build.doorway(hall, port);
        }
        # The cells under the south gallery, the worst of the keep in them.
        away = self.long // 2;
        starts = [x for x in [7, 12, 17, 22, 27] if x + 3 <= dais_x - 1 and (x + 3 <= away - 3 or x >= away + 3)];
        closets(build, press, y0, starts[:3], 0, 3, [e1m5_worst(dice, self.danger), e1m5_foe(dice, self.danger, True)]);
        for index in range(2) {
            press +>:Fires:+> build.summon(dais_x + 1 + index * 3, mid - 1, -9, e1m5_foe(dice, self.danger, True), float(dais_x) - 3.5, float(mid + 4 + index * 2) + 0.5, 0, 180.0);
        }
        # The galleries' guards wake as the stair is climbed.
        climbing = build.touch(float(dais_x - r - 2), float(mid - 2), 0.0, float(dais_x - r + 1), float(mid + 2), 6.0);
        guards = build.waiting();
        climbing +>:Fires:+> guards;
        press +>:Fires:+> guards;
        build.foe(float(dais_x) - 3.5, float(y0) + 2.0, r, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(dais_x) - 3.5, float(y1) - 2.0, r, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(mid) + (1.0 if index % 2 == 0 else -1.0), 0, e1m5_foe(dice, self.danger), 0.0);
        }
        build.foe(3.5, float(mid) + 0.5, 0, "monster_knight", 0.0, patrol=[[3.5, float(mid) + 0.5], [float(dais_x) - r - 3.5, float(mid) + 0.5]]);
        build.foe(float(self.long) - 4.5, float(mid) + 2.5, r, e1m5_foe(dice, self.danger, True), 180.0);
        build.foe(8.5, float(y1) - 2.0, r, "monster_knight", 0.0, patrol=[[8.5, float(y1) - 2.0], [float(dais_x) - 2.5, float(y1) - 2.0]]);
        build.supply(float(self.long) - 2.5, float(y1) - 2.5, r, "item_health");
        build.supply(2.5, float(y0) + 1.5, 0, "item_spikes");
    }
}

"""A tall tower, lifts up its middle to a landing and the top floor and the
key there; taking it opens the rooms off the landing."""
node KeyTower(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        top: int = 20,
        tall: int = 28,
        landing: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key tower (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(16, 18);
        self.hall_wide = dice.between(16, 18);
        # The rooms off the landing (and the stash) stand beyond the tower's
        # far wall.
        self.wide = self.hall_wide + 4;
        self.landing = dice.between(9, 11);
        self.top = self.landing + dice.between(9, 11);
        self.tall = self.top + 8;
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        step = kit_of(build.district).step;
        cx = self.long // 2;
        cy = self.hall_wide // 2;
        side = self.hall_wide - 1;
        tower = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(tower, self.landing);
        build.level(tower, self.top);
        build.doorway(tower, self.enter);
        # Two floors: a gallery at the landing round the walls, and the top
        # floor round the walls higher still, the middle open for the lifts.
        for floor_at in [self.landing, self.top] {
            build.solid(1, 1, floor_at - 1, self.long - 1, 5, floor_at);
            build.solid(1, side - 4, floor_at - 1, self.long - 1, side, floor_at);
            build.solid(1, 5, floor_at - 1, 5, side - 4, floor_at);
            build.solid(self.long - 5, 5, floor_at - 1, self.long - 1, side - 4, floor_at);
        }
        # The lifts: one from the floor to the landing, one from the landing
        # to the top, each a plat waiting at its foot.
        build.put_box({"classname": "func_plat", "height": str(self.landing * 16), "speed": "200"}, float(cx - 3), float(cy - 1), float(self.landing) - 0.5, float(cx - 1), float(cy + 2), float(self.landing), step);
        build.put_box({"classname": "func_plat", "height": str((self.top - self.landing) * 16), "speed": "200"}, float(cx + 1), float(cy - 1), float(self.top) - 0.5, float(cx + 3), float(cy + 2), float(self.top), step);
        build.solid(5, cy - 1, self.landing - 1, cx - 3, cy + 2, self.landing);
        build.solid(cx - 1, cy - 1, self.landing - 1, cx + 3, cy + 2, self.landing);
        build.solid(cx + 3, cy - 1, self.top - 1, self.long - 5, cy + 2, self.top);
        for x in range(cx - 4, cx + 4) {
            for y in range(cy - 2, cy + 3) {
                build.keep(tower, x, y, self.landing);
                build.keep(tower, x, y, self.top);
            }
        }
        # The key on the top floor: taking it opens the rooms off the
        # landing, and sends one more in behind, onto the landing.
        taken = key_cue(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.top);
        closets(build, taken, side, [4, self.long - 7], self.landing, 1, [e1m5_foe(dice, self.danger, True), e1m5_foe(dice, self.danger)]);
        taken +>:Fires:+> build.summon(cx - 1, cy - 1, -8, e1m5_foe(dice, self.danger, True), 3.0, 3.0, self.landing, 0.0);
        stash(build, side, cx - 1, 0, 1, "item_armor2");
        blocks = [[cx - 5, cy - 3, cx + 5, cy + 4], [0, cy - 3, 5, cy + 3], [cx - 3, side - 3, cx + 3, side], [1, 1, self.long - 1, 5]];
        low_rocks(build, dice, 1, 1, self.long - 1, side, 0, dice.between(2, 4), 2, blocks);
        build.foe(3.0, 3.0, self.top, e1m5_foe(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.0, 3.0, 0, e1m5_foe(dice, self.danger), 90.0, patrol=[[float(self.long) - 3.0, 3.0], [3.0, 3.0]]);
        build.supply(3.0, float(side) - 2.0, self.landing, "item_health");
    }
}

"""A hall cut by a flooded channel, crossed on a riding platform or a
drawn bridge, spikes flying across; a balcony over the far floor."""
node SpikeBridge(Prefab) {
    has near: int = 8,
        span: int = 9,
        far_side: int = 9,
        lane: int = 6,
        tall: int = 18,
        ridden: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike bridge";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.near = dice.between(7, 9);
        self.span = dice.between(8, 10);
        self.far_side = dice.between(8, 10);
        self.wide = dice.between(16, 19);
        self.tall = dice.between(18, 20);
        self.ridden = dice.chance(0.5);
        self.lane = dice.between(8, self.wide - 6);
        if not self.ridden and self.lane - 4 < 4 and self.lane + 7 > self.wide - 1 {
            self.ridden = True;
        }
        self.long = 1 + self.near + self.span + self.far_side + 1;
        self.low = -12;
        self.high = self.tall + 1;
        land = 1 + self.near + self.span;
        self.enter = Port(face=2, along=float(dice.between(9, self.wide - 3)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(8, self.wide - 3)), floor=0),
            Port(face=1, along=float(land + 3), floor=0),
            Port(face=0, along=3.0, floor=9)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 9);
        cut = 1 + self.near;
        land = cut + self.span;
        # The channel, steps up out of it at both banks, a well in its bed.
        build.pool(cut, 1, -6, land, self.wide - 1, 0, 2, False, False);
        for step in range(6) {
            build.solid(cut + step, 1, -6, cut + step + 1, 3, -step);
            build.solid(land - 1 - step, 1, -6, land - step, 3, -step);
        }
        sump(build, cut + self.span // 2 - 1, 4, -11, -6, 2);
        # A niche under the near bank's water: a secret, and armor.
        build.room(cut - 2, 4, -6, cut, 6, -3);
        flood(build, cut - 2, 4, -6, cut, 6, -3);
        build.secret(float(cut - 2), 4.0, -6.0, float(cut), 6.0, -3.0);
        build.supply(float(cut) - 1.0, 5.0, -6, "item_armor1");
        # The crossing: a platform riding to and fro, or a bridge drawn up
        # by shooting the button on the far floor's wall.
        # The crossing: a platform riding to and fro (e1m5's train), and
        # sometimes a bridge too, beside it, drawn up by shooting the button
        # high on the far wall.
        build.train([3.0, 3.0, 1.0], [[float(cut), float(self.lane), -1.0], [float(land - 3), float(self.lane), -1.0]], 150.0, 1.0);
        lanes = [self.lane];
        if not self.ridden {
            other = self.lane - 4 if self.lane - 4 >= 4 else self.lane + 4;
            lanes.append(other);
            shot = build.push(float(self.long - 1), float(self.wide // 2) + 0.5, 12.0, 2, True);
            shot +>:Fires:+> build.drawn(float(cut), float(other), float(land), float(other + 3), 0, 7);
            build.touch(1.0, 1.0, 0.0, float(cut), float(self.wide - 1), 6.0, True, "Shoot the button across the water");
        }
        for lane in lanes {
            for across in range(3) {
                build.keep(hall, cut - 1, lane + across, 0);
                build.keep(hall, land, lane + across, 0);
            }
        }
        # The spikes fly across the crossing from both side walls.
        crossing = build.touch(float(cut), 1.0, -3.0, float(land), float(self.wide - 1), 6.0, False);
        spike_wall(build, crossing, 1, cut + 1, land, 1.5, 3, False, 1);
        spike_wall(build, crossing, self.wide - 1, cut + 2, land, 1.5, 3, False, 3);
        # The balcony over the far floor, a lift up to it.
        slab(build, self.long - 5, 1, self.long - 1, self.wide - 1, 9);
        lift(build, self.long - 8, 1, self.long - 5, 4, 0, 9);
        keep_box(build, hall, self.long - 9, 1, self.long - 4, 5, 9);
        keep_box(build, hall, self.long - 9, 1, self.long - 4, 5, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Landing on the far floor wakes the balcony's archers and brings a
        # foe in behind.
        landed = build.touch(float(land), 1.0, 0.0, float(land + 2), float(self.wide - 1), 6.0);
        archers = build.waiting();
        landed +>:Fires:+> archers;
        landed +>:Fires:+> build.summon(2, 2, -10, e1m5_foe(dice, self.danger, True), float(cut) - 2.5, float(self.lane) + 1.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * 4.0, 9, e1m5_foe(dice, self.danger, index == 0), 180.0, waits=archers);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(land) + 4.5, 6.5 + float(index) * 4.0, 0, e1m5_foe(dice, self.danger), 180.0);
        }
        build.foe(3.5, 2.5, 0, "monster_knight", 90.0, patrol=[[3.5, 2.5], [3.5, float(self.wide) - 2.5]]);
        if dice.chance(0.5) {
            build.foe(float(cut) + float(self.span) * 0.5, float(self.wide) - 3.5, -5, "monster_fish", 0.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 9, "item_rockets");
    }
}

"""A crypt flooded between its ends, columns in the water, crossed on a
catwalk or column to column or swum; the great lift up on the far side."""
node FloodedCrypt(Prefab) {
    has near: int = 6,
        span: int = 13,
        far_side: int = 9,
        tall: int = 21,
        catwalk: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded crypt";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.near = dice.between(6, 7);
        self.span = dice.between(12, 15);
        self.far_side = dice.between(9, 10);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(20, 22);
        self.catwalk = dice.chance(0.6);
        self.long = 1 + self.near + self.span + self.far_side + 1;
        self.low = -14;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        land = 1 + self.near + self.span;
        self.enter = Port(face=2, along=float(dice.between(mid + 5, self.wide - 3)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(3, mid - 3)), floor=0),
            Port(face=3, along=float(land + 3), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=12)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        crypt = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(crypt, 7);
        build.level(crypt, 12);
        cut = 1 + self.near;
        land = cut + self.span;
        # The flood: steps down into it from each end along a side wall,
        # wells in its bed.
        build.pool(cut, 1, -7, land, self.wide - 1, 0, 2, False, False);
        for step in range(7) {
            build.solid(cut + step, 1, -7, cut + step + 1, 3, -step);
            build.solid(land - 1 - step, self.wide - 3, -7, land - step, self.wide - 1, -step);
        }
        sump(build, cut + 4, mid, -13, -7, 3);
        sump(build, land - 7, mid - 4, -13, -7, 3);
        # Columns standing in the water along the south side; a raft riding
        # to and fro across the flood along the north side.
        for x in range(cut + 3, land - 2, 4) {
            build.solid(x, 4, -7, x + 1, 5, self.tall);
        }
        raft = self.wide - 7;
        build.train([3.0, 3.0, 1.0], [[float(cut), float(raft), -1.0], [float(land - 3), float(raft), -1.0]], 120.0, 2.0);
        for across in range(3) {
            build.keep(crypt, cut - 1, raft + across, 0);
            build.keep(crypt, land, raft + across, 0);
        }
        if self.catwalk {
            # A lift on the near floor up to a catwalk across the flood, its
            # far end over the far floor open to drop from; scrags are sent
            # in as it is crossed.
            lift(build, 2, mid - 1, 5, mid + 2, 0, 7);
            keep_box(build, crypt, 1, mid - 2, 6, mid + 3, 0);
            slab(build, 5, mid - 1, land + 2, mid + 2, 7);
            keep_box(build, crypt, 1, mid - 2, 7, mid + 3, 7);
            keep_box(build, crypt, land + 1, mid - 2, land + 2, mid + 3, 7);
            halfway = build.touch(float(cut + self.span // 2 - 1), float(mid - 1), 7.0, float(cut + self.span // 2 + 2), float(mid + 2), 13.0);
            for index in range(2) {
                halfway +>:Fires:+> build.summon(2 + index * 0, 2 + index * 5, -9, "monster_wizard", float(cut + 3 + index * 6) + 0.5, float(mid) + 3.5, 8, 0.0);
            }
        } else {
            # Square columns to stand on, a jump apart, down the middle.
            for x in range(cut + 1, land - 2, 4) {
                build.solid(x, mid - 1, -7, x + 2, mid + 1, 0);
                keep_ring(build, crypt, x, mid - 1, x + 2, mid + 1, 0);
            }
        }
        # The great lift on the far floor up to a gallery along the far wall,
        # a way on from it.
        slab(build, self.long - 5, 1, self.long - 1, self.wide - 1, 12);
        lift(build, self.long - 8, self.wide - 5, self.long - 5, self.wide - 1, 0, 12);
        keep_box(build, crypt, self.long - 9, self.wide - 6, self.long - 4, self.wide - 1, 12);
        keep_box(build, crypt, self.long - 9, self.wide - 6, self.long - 4, self.wide - 1, 0);
        build.doorway(crypt, self.enter);
        for port in self.taken {
            build.doorway(crypt, port);
        }
        # The far floor's guards wake as a body comes up out of the water.
        out = build.touch(float(land - 2), 1.0, -2.0, float(land + 2), float(self.wide - 1), 6.0);
        guards = build.waiting();
        out +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 6.5, 3.5 + float(index) * 3.0, 0, e1m5_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(self.long) - 2.5, 3.5, 12, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cut + 3 + index * 5) + 0.5, float(mid) + 3.5, -6, "monster_fish", 0.0);
        }
        build.foe(2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[2.5, 2.5], [2.5, float(mid) - 3.5]]);
        build.foe(float(self.long) - 2.5, float(self.wide) - 6.5, 12, "monster_knight", 270.0, patrol=[[float(self.long) - 2.5, float(self.wide) - 6.5], [float(self.long) - 2.5, 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 12, "item_rockets");
    }
}

"""A vault walled off at its far end, galleries over the cells along both
sides; the button opens the way on and the cells."""
node ShamblerVault(Prefab) {
    has hw: int = 14,
        tall: int = 18,
        plinth: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shambler vault";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(30, 33);
        self.hw = dice.between(14, 16);
        self.wide = self.hw + 8;
        self.tall = dice.between(18, 20);
        self.plinth = dice.chance(0.5);
        self.low = -11;
        self.high = self.tall + 1;
        mid = (5 + self.wide - 5) // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid - 2), floor=0), Port(face=0, along=float(mid + 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        y1 = self.wide - 5;
        mid = (y0 + y1) // 2;
        door_x = self.long - 7;
        hall = build.room(1, y0, 0, door_x, y1, self.tall, variant=dice.below(3));
        chamber = build.room(door_x + 1, y0, 0, self.long - 1, y1, 12, variant=dice.below(3));
        build.level(hall, 7);
        build.widen(chamber, door_x, mid - 2, 0, door_x + 1, mid + 2, 8);
        door = build.opened(float(door_x), float(mid - 2), 0.0, float(door_x + 1), float(mid + 2), 8.0);
        # Galleries along both walls over the cells, stairs up at the near
        # end (a stash in one).
        for (at, edge) in [(y0, y0 + 3), (y1 - 4, y1 - 4)] {
            stair(build, 4, at, 0, 0, 7, 4);
            slab(build, 11, at, door_x, at + 4, 7);
            arcade(build, edge, 16, door_x - 1, 0, 6, 4, False);
            keep_box(build, hall, 9, at, 12, at + 4, 7);
        }
        stash(build, y0 + 4, 8, 0, 3, "item_artifact_super_damage");
        # A channel across the hall under a causeway, steps out on both sides.
        build.pool(12, y0, -4, 15, y1, 0, 2, False, True, True);
        build.solid(12, mid - 2, -4, 15, mid + 2, 0);
        keep_box(build, hall, 11, mid - 2, 16, mid + 2, 0);
        sump(build, 13, mid - 5, -9, -4, 2);
        # The button: on a post on a plinth in the hall, or high on the far
        # wall over the door, pressed from a catwalk between the galleries.
        if self.plinth {
            px = door_x - 8;
            build.solid(px, mid - 1, 0, px + 3, mid + 2, 2);
            build.solid(px - 1, mid - 1, 0, px, mid + 2, 1);
            build.solid(px + 1, mid, 2, px + 2, mid + 1, 4);
            press = build.push(float(px + 2), float(mid) + 0.5, 2.5, 0);
        } else {
            slab(build, door_x - 3, y0 + 4, door_x, y1 - 4, 7);
            keep_box(build, hall, door_x - 3, y0 + 3, door_x, y0 + 5, 7);
            keep_box(build, hall, door_x - 3, y1 - 5, door_x, y1 - 3, 7);
            press = build.push(float(door_x), float(mid) + 0.5, 8.2, 2);
        }
        press +>:Fires:+> door;
        blocks = [[door_x - 10, mid - 3, door_x + 1, mid + 4], [16, mid + 2, door_x, mid + 5], [0, mid - 3, 17, mid + 3]];
        low_rocks(build, dice, 16, y0 + 5, door_x - 1, y1 - 5, 0, dice.between(2, 4), 2, blocks);
        # The cells along both walls under the galleries.
        starts = [x for x in [17, 22, 27] if x + 3 <= door_x - 1];
        closets(build, press, y0, starts, 0, 3, [e1m5_worst(dice, self.danger), e1m5_foe(dice, self.danger, True)]);
        closets(build, press, y1, starts[:2], 0, 1, [e1m5_foe(dice, self.danger, True), e1m5_worst(dice, self.danger)]);
        press +>:Fires:+> build.summon(4, mid - 1, -8, e1m5_foe(dice, self.danger, True), 9.5, float(mid) + 0.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        # The galleries' archers wake as the causeway is crossed.
        crossing = build.touch(12.0, float(mid - 2), 0.0, 15.0, float(mid + 2), 6.0);
        archers = build.waiting();
        crossing +>:Fires:+> archers;
        build.foe(float(door_x) - 2.5, float(y0) + 2.0, 7, e1m5_foe(dice, self.danger, True), 180.0, waits=archers);
        build.foe(float(door_x) - 2.5, float(y1) - 2.0, 7, e1m5_foe(dice, self.danger), 180.0, waits=archers);
        build.foe(17.5, float(mid) + 3.5, 0, "monster_knight", 0.0, patrol=[[17.5, float(mid) + 3.5], [float(door_x) - 2.5, float(mid) + 3.5]]);
        build.foe(12.5, float(y0) + 2.0, 7, "monster_army", 0.0, patrol=[[12.5, float(y0) + 2.0], [float(door_x) - 4.5, float(y0) + 2.0]]);
        inside = build.waiting();
        press +>:Fires:+> inside;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, float(y0) + 2.5 + float(index) * 3.0, 0, e1m5_foe(dice, self.danger, index == 0), 180.0, waits=inside);
        }
        build.supply(2.5, float(mid) + 3.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(y1) - 2.5, 0, "item_rockets");
    }
}

"""The end: a gatehouse, a portcullis, a moat and a drawbridge drawn by a
button, the way out on the far bank; a secret teleporter there."""
node PortcullisGate(Prefab) {
    has key: str = "",
        gate_x: int = 14,
        tall: int = 18,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Portcullis gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(32, 36);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(18, 20);
        self.shot = dice.chance(0.5);
        self.gate_x = dice.between(14, 16);
        self.low = -12;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        g = self.gate_x;
        hall = build.room(1, 1, 0, g, self.wide - 1, self.tall, variant=dice.below(3));
        outside = build.room(g + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, sky=True);
        build.level(hall, 7);
        build.doorway(hall, self.enter);
        # Balconies along both walls of the gatehouse, stairs up to them.
        for at in [1, self.wide - 4] {
            stair(build, 4, at, 0, 0, 7, 3);
            slab(build, 11, at, g, at + 3, 7);
            keep_box(build, hall, 9, at, 12, at + 3, 7);
        }
        # The portcullis: a key's, or one that rises as it is neared.
        build.widen(outside, g, mid - 2, 0, g + 1, mid + 2, 9);
        near = build.touch(float(g - 3), float(mid - 2), 0.0, float(g), float(mid + 2), 6.0);
        if self.key {
            build.rising_door(float(g), float(mid - 2), 0.0, float(g + 1), float(mid + 2), 9.0, {"key": self.key, "wait": "-1"});
        } else {
            near +>:Fires:+> build.opened(float(g), float(mid - 2), 0.0, float(g + 1), float(mid + 2), 9.0);
        }
        # The moat and the drawbridge, drawn up by the button beside the gate
        # (or by shooting the one on the far bank); steps out of the moat on
        # both banks.
        moat_x = g + 4;
        far_x = moat_x + 6;
        build.pool(moat_x, 1, -6, far_x, self.wide - 1, 0, 2, False, False);
        for step in range(6) {
            build.solid(moat_x + step, 1, -6, moat_x + step + 1, 3, -step);
            build.solid(far_x - 1 - step, self.wide - 3, -6, far_x - step, self.wide - 1, -step);
        }
        sump(build, moat_x + 2, 4, -11, -6, 2);
        bridge = build.drawn(float(moat_x), float(mid - 2), float(far_x), float(mid + 2), 0, 7);
        for y in range(mid - 2, mid + 2) {
            build.keep(outside, moat_x - 1, y, 0);
            build.keep(outside, far_x, y, 0);
        }
        if self.shot {
            press = build.push(float(self.long - 1), float(mid) + 3.5, 4.0, 2, True);
            build.touch(float(g + 1), 1.0, 0.0, float(moat_x), float(self.wide - 1), 6.0, True, "Shoot the button across the moat");
        } else {
            press = build.push(float(g + 1), float(mid) + 3.5, 1.2, 0);
        }
        press +>:Fires:+> bridge;
        # The far bank, the way out on a terrace up two steps.
        build.solid(far_x + 4, 2, 0, self.long - 1, self.wide - 2, 1);
        build.solid(far_x + 5, 2, 1, self.long - 1, self.wide - 2, 2);
        build.way_out(float(self.long) - 4.0, float(mid), 2);
        # The secret way: a stash in the gatehouse's corner, a teleporter in
        # it to the far bank.
        build.solid(1, 1, 0, 4, 4, self.tall);
        build.room(1, 1, 0, 3, 3, 4);
        build.secret_door(1.0, 3.0, 0.0, 3.0, 4.0, 4.0, 3);
        build.secret(1.0, 1.0, 0.0, 3.0, 3.0, 3.0);
        build.teleporter(2.0, 2.0, 0, float(far_x) + 2.5, float(mid) + 0.5, 0, 0.0);
        # The balconies' guards wake as the gate is neared; a foe comes in
        # behind; the far bank's guards wait.
        guards = build.waiting();
        near +>:Fires:+> guards;
        near +>:Fires:+> build.summon(6, mid - 1, -9, e1m5_foe(dice, self.danger, True), 4.5, float(mid) + 0.5, 0, 0.0);
        build.foe(float(g) - 2.5, 2.5, 7, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(g) - 2.5, float(self.wide) - 2.5, 7, e1m5_foe(dice, self.danger, True), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(g) - 4.5, 5.5 + float(index) * 2.5, 0, e1m5_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 6.5, 3.5 + float(index) * 5.0, 2, e1m5_foe(dice, self.danger, True), 180.0);
        }
        build.foe(float(far_x) + 2.5, 3.5, 0, "monster_knight", 90.0, patrol=[[float(far_x) + 2.5, 3.5], [float(far_x) + 2.5, float(self.wide) - 3.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""e1m5's stretches: [name, role]."""
glob E1M5_STRETCHES: list[list[str]] = [
         ["courtyard", "start"],
         ["battlements", "flow"],
         ["throne", "hub"],
         ["throne", "flow"],
         ["tower", "keyroom"],
         ["spikes", "flow"],
         ["crypt", "flow"],
         ["vault", "flow"],
         ["portcullis", "end"],
         ["portcullis", "gate"]
     ];

"""One of e1m5's stretches by its name."""
def make_e1m5(name: str, key: str) -> Prefab {
    if name == "courtyard" {
        return KeepCourtyard();
    }
    if name == "battlements" {
        return Battlements();
    }
    if name == "throne" {
        return ThroneKeep();
    }
    if name == "tower" {
        return KeyTower(key=key if key else "key_gold");
    }
    if name == "spikes" {
        return SpikeBridge();
    }
    if name == "crypt" {
        return FloodedCrypt();
    }
    if name == "vault" {
        return ShamblerVault();
    }
    return PortcullisGate(key=key);
}
