"""Prefabs drawn from e1m3, the Necropolis: its crypts and catacombs full of
zombies, its graveyard under the sky, its stair of doors raised by a shot
button, its platforms riding over the pits, its gold key down in a crypt
far below, its nave and the way out high over it. Raised in e1m3's own
palette.

- `CryptStair`: the start. A landing high at one end of a crypt and a
  grand stair down into it (or two flights down its side walls from a
  landing over a lower vault), pillars down its length and zombies waiting
  in the niches of its walls, roused as the player reaches a stair's foot.
- `Catacombs`: three passages each way crossing in a grid, their stretches
  between the crossings worn a step higher than the crossings, a tall crypt
  where the middle ones cross (or a flooded crossing, a footbridge over it
  where a foe is brought in behind the player by a teleporter), two of the
  grid's blocks fallen in to flooded cisterns the passages run beside,
  zombies in niches and shambling the passages; ways on in every direction
  (a hub as well as a stretch passed through); a closet in a block opens to
  a shot.
- `SunkenCrypt`: a crypt, its middle sunk under water, a ledge across its
  far end and the way on up on it; shooting the button on the ledge's face raises a stair out of the
  floor up to it (e1m3's stair of doors raised by a shot button), straight
  or turning up a side wall onto a platform and on; the crypt's dead wake
  as it rises and one is brought in behind; a gallery may run back along a
  side wall from the ledge, a closet at its end.
- `Graveyard`: a court under the sky, rows of graves, a broad channel of
  water across it under a stone footbridge (or stepping stones), and a terrace
  up a stair at the far end where ogres stand guard, roused as the player
  crosses; the terrace may roof a tomb, its dead and a closet in its wall.
- `PitFerry`: a pit (dry, flooded, or lava) crossed by platforms riding back and
  forth over it (e1m3's trains), a lift or stair up out of it, the far
  ledge's guard roused as the player lands.
- `GoldCrypt`: the key room. A hall over a crypt far below, reached down a
  stair winding round the walls of a well or by dropping down a shaft with
  a lift back up; the key on a dais down there (e1m3's gold key, down in
  its pit); taking it opens the closets in the crypt's wall and, a moment
  on, brings a foe in by a teleporter.
- `Nave`: a long nave with pews and two aisles of pillars, an altar on a
  dais and the way out upon it, or high on a gallery over it ridden up to
  on a lift (e1m3's way out high above); as a gate, a key door across the
  nave. Climbing to the altar brings a foe in behind the player by a
  teleporter (e1m3's teleported ambush) and wakes the pews' dead."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .roster { FoeMix }
import from .common { stair, pillars, apart, niches, spiral, ring_path, lift }
import from .e1m1_parts { deck, stash, bars }
import from .e1m2_parts { keep_box }

glob E1M3: str = "q1:e1m3";

"""e1m3's foes: zombies above all, ogres and scrags, fiends deeper in."""
glob E1M3_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_zombie", "monster_wizard"], strong=["monster_ogre"], heavy_light=["monster_zombie", "monster_zombie", "monster_ogre"], heavy_strong=["monster_demon1"]);

"""What a secret of e1m3's holds."""
def e1m3_reward(dice: Stream) -> str {
    return ["item_armor2", "item_artifact_super_damage", "weapon_rocketlauncher", "item_armor2"][dice.below(4)];
}

"""The start: a landing high at one end of a crypt, a grand stair down (or
two flights down its side walls from a landing over a lower vault)."""
node CryptStair(Prefab) {
    has landing: int = 7,
        drop: int = 9,
        crypt: int = 16,
        tall: int = 15,
        twin: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt stair";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.twin = dice.chance(0.5);
        self.landing = dice.between(7, 8) if self.twin else dice.between(6, 8);
        self.drop = dice.between(9, 11) if self.twin else dice.between(8, 10);
        self.crypt = dice.between(16, 20);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(14, 17);
        self.long = 1 + self.landing + self.drop + self.crypt + 1;
        self.low = -1;
        self.high = self.drop + self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.drop);
        self.leaves = [Port(face=0, along=middle - 3.0, floor=1), Port(face=0, along=middle + 3.0, floor=1)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 2, 0, self.long - 1, self.wide - 2, self.drop + self.tall, variant=dice.below(3));
        build.level(hall, self.drop);
        foot = 1 + self.landing;
        floor_x = foot + self.drop;
        stirred = build.waiting();
        if self.twin {
            # The landing a deck over a vault under it; two flights down the
            # side walls, a lift a cell, and the dead stir at either foot.
            deck(build, 1, 2, foot, self.wide - 2, self.drop);
            for flight_y in [2, self.wide - 5] {
                for step in range(self.drop) {
                    build.solid(foot + step, flight_y, 0, foot + step + 1, flight_y + 3, self.drop - 1 - step);
                }
                for y in range(flight_y, flight_y + 3) {
                    build.keep(hall, foot - 1, y, self.drop);
                }
                build.touch(float(floor_x), float(flight_y), 0.0, float(floor_x + 2), float(flight_y + 3), 6.0) +>:Fires:+> stirred;
            }
            for y in range(middle - 1, middle + 2) {
                build.keep(hall, foot - 1, y, self.drop);
            }
            # In the vault under the landing, a coffin and what lies by it.
            build.solid(2, middle - 1, 0, 5, middle + 1, 2);
            build.supply(float(foot) - 1.5, float(middle) + 0.5, 0, "item_health");
            build.foe(float(foot) - 1.5, 3.5, 0, E1M3_FOES.pick(dice, self.danger), 0.0, waits=stirred);
        } else {
            build.solid(1, 2, 0, foot, self.wide - 2, self.drop);
            # The stair down, four cells wide in the middle, a lift a cell.
            for step in range(self.drop) {
                build.solid(foot + step, middle - 2, 0, foot + step + 1, middle + 2, self.drop - 1 - step);
            }
            for y in range(middle - 3, middle + 3) {
                build.keep(hall, foot - 1, y, self.drop);
            }
            build.touch(float(floor_x), float(middle - 2), 0.0, float(floor_x + 2), float(middle + 2), 6.0) +>:Fires:+> stirred;
        }
        clear = [[0, middle - 3, floor_x + 2, middle + 3], [self.long - 3, middle - 6, self.long, middle + 6]];
        pillars(build, floor_x + 2, 4, self.long - 2, self.wide - 4, 0, self.drop + self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The ways on shut, opened by the button between them (e1m3's first
        # doors, opened by a button).
        if self.taken {
            opener = build.push(float(self.long - 1), float(middle), 2.5, 2);
            bars(build, opener, self.taken, self.long, self.wide);
            opener +>:Fires:+> stirred;
        }
        # Niches down both walls of the crypt below, a zombie in each.
        low_side = niches(build, hall, 1, floor_x + 1, self.long - 3, 0, 6, 3, False, -1);
        high_side = niches(build, hall, self.wide - 2, floor_x + 1, self.long - 3, 0, 6, 3, False, 1);
        for (index, at) in enumerate(low_side + high_side) {
            if index % 3 == 0 {
                build.foe(at[0], at[1], 0, E1M3_FOES.pick(dice, self.danger), 90.0 if at[1] < float(middle) else 270.0, waits=stirred);
            }
        }
        build.start(2.5, float(middle) + 0.5, self.drop, 0.0);
        build.supply(2.5, 3.5, self.drop, "item_shells");
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, E1M3_FOES.pick(dice, self.danger, True), 180.0, waits=stirred);
        # A zombie shambling down the crypt and back.
        build.foe(float(floor_x) + 1.5, float(middle) + 0.5, 0, "monster_zombie", 0.0, patrol=[[float(floor_x) + 1.5, float(middle) + 0.5], [float(self.long) - 4.5, float(middle) + 0.5]]);
        build.supply(float(self.long) - 2.5, 3.5, 0, "item_health");
    }
}

"""Three passages each way crossing in a grid, a step up between the
crossings; a tall crypt in the middle (or a flooded crossing under a
footbridge, and two blocks of the grid fallen in to cisterns); ways on in
every direction."""
node Catacombs(Prefab) {
    has block: int = 5,
        tall: int = 9,
        flooded: bool = False,
        raft: bool = False,
        barred: bool = False,
        hidden: bool = False,
        diagonal: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Catacombs";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.block = dice.between(5, 6);
        self.tall = dice.between(9, 10);
        self.flooded = dice.chance(0.8);
        self.raft = self.flooded and dice.chance(0.7);
        self.barred = dice.chance(0.7);
        self.diagonal = dice.chance(0.5);
        self.hidden = self.block == 6 and (not self.flooded or not self.diagonal) and dice.chance(0.7);
        self.long = 2 * self.block + 12;
        self.wide = 2 * self.block + 12;
        self.low = -6;
        self.high = self.tall + 9;
        lines = [float(2 + index * (self.block + 3)) + 1.5 for index in range(3)];
        self.enter = Port(face=2, along=lines[1], floor=1);
        self.leaves = [
            Port(face=0, along=lines[1], floor=1),
            Port(face=1, along=lines[1], floor=1),
            Port(face=3, along=lines[1], floor=1),
            Port(face=0, along=lines[0], floor=1),
            Port(face=1, along=lines[2], floor=1)
        ];
        visitor.place(self);
    }

    """Whether the grid's block (i, j) has fallen in to a cistern."""
    def wet_block(i: int, j: int) -> bool {
        return self.flooded and (i == j) == self.diagonal;
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        starts = [2 + index * (self.block + 3) for index in range(3)];
        passages: list[Space] = [];
        for at in starts {
            passages.append(build.room(at, 1, 0, at + 3, self.wide - 1, self.tall, variant=dice.below(2)));
            passages.append(build.room(1, at, 0, self.long - 1, at + 3, self.tall, variant=dice.below(2)));
        }
        mid = starts[1];
        crypt = build.room(mid - 2, mid - 2, 0, mid + 5, mid + 5, self.tall + 4);
        build.level(crypt, 0);
        # The passages between the crossings worn a step higher than the
        # crossings, but for the spine from the way in on through the crypt.
        for at in [starts[0], starts[2]] {
            for index in range(2) {
                build.solid(at, starts[index] + 3, 0, at + 3, starts[index + 1], 1);
                build.solid(starts[index] + 3, at, 0, starts[index + 1], at + 3, 1);
            }
        }
        build.solid(mid, starts[0] + 3, 0, mid + 3, mid - 2, 1);
        build.solid(mid, mid + 5, 0, mid + 3, starts[2], 1);
        # Two blocks of the grid fallen in: cisterns open beside the passages,
        # steps up out of each to the passage on their far side.
        for i in range(2) {
            for j in range(2) {
                if self.wet_block(i, j) {
                    x0 = starts[i] + 3;
                    y0 = starts[j] + 3;
                    build.room(x0, y0, 0, x0 + self.block, y0 + self.block, self.tall);
                    build.pool(x0, y0, -5, x0 + self.block, y0 + self.block, 0, 2);
                    for passage in passages {
                        for x in [x0 - 1, x0, x0 + 1] {
                            build.keep(passage, x, y0 + self.block, 1);
                        }
                    }
                }
            }
        }
        if self.flooded {
            # The crossing flooded, steps out at both sides, a footbridge on
            # along the way through; on it a foe is brought in behind.
            build.pool(mid - 2, mid - 2, -5, mid + 5, mid + 5, 0, 2, False, False);
            if self.raft {
                # A raft riding to and fro across the water along the way
                # through (e1m3's platforms riding on their own).
                build.train([3.0, 3.0, 1.0], [[float(mid - 2), float(mid), -1.0], [float(mid + 2), float(mid), -1.0]], 50.0, 2.0);
            } else {
                build.solid(mid - 2, mid, -1, mid + 5, mid + 3, 0);
            }
            # Each half of the water its own steps up, out onto the cross
            # passage beyond it.
            for (y0, y1) in [(mid - 2, mid), (mid + 3, mid + 5)] {
                for step in range(5) {
                    build.solid(mid + 4 - step, y0, -5, mid + 5 - step, y1, -4 + step);
                }
            }
            for across in range(3) {
                build.keep(crypt, mid - 3, mid + across, 0);
                build.keep(crypt, mid + 5, mid + across, 0);
            }
            on_bridge = build.touch(float(mid + 1), float(mid), 0.0, float(mid + 2), float(mid + 3), 6.0);
            on_bridge +>:Fires:+> build.summon(starts[0] + 3, starts[0] + 3, self.tall + 1, E1M3_FOES.pick(dice, self.danger, True), float(mid) - 3.5, float(mid) + 1.5, 0, 0.0);
        } else {
            # The middle crossing a crypt, taller and wider, coffins about it.
            for (cx, cy) in [(mid - 2, mid - 2), (mid + 4, mid - 2), (mid - 2, mid + 4), (mid + 4, mid + 4)] {
                build.solid(cx, cy, 0, cx + 1, cy + 1, 2);
            }
        }
        build.doorway(passages[3], self.enter);
        for port in self.taken {
            build.doorway(passages[0], port);
        }
        # Barred: bars across every way on, raised by the button on the way
        # in's wall (e1m3's bars lifted by a button).
        if self.barred and self.taken {
            lever = build.push(float(starts[0]) + 4.5, float(mid + 3), 2.5, 3);
            build.touch(1.0, float(mid), 0.0, 3.0, float(mid + 3), 6.0, True, "The ways on are barred");
            bars(build, lever, self.taken, self.long, self.wide);
        }
        # Niches in the blocks along the passages, between the crossings
        # (none in a block fallen in).
        spots: list[list[float]] = [];
        for index in range(2) {
            between = starts[index] + 3 + self.block // 2 - 1;
            for (line, at) in enumerate(starts) {
                if line == 0 or not self.wet_block(line - 1, index) {
                    spots.extend(niches(build, passages[0], at - 1, between, between + 2, 0, 6, 3, True, -1));
                }
                if line == 0 or not self.wet_block(index, line - 1) {
                    spots.extend(niches(build, passages[0], at - 1, between, between + 2, 0, 6, 3, False, -1));
                }
            }
        }
        # A closet in the first block, its door on the first passage's
        # side, opening to a shot.
        if self.hidden {
            stash(build, starts[0] + 3, starts[0] + 3, 0, 3, e1m3_reward(dice));
        }
        # The niches' dead stir when the player comes into the crypt.
        into = build.touch(float(mid), float(mid), 0.0, float(mid + 3), float(mid + 3), 6.0);
        stirred = build.waiting();
        into +>:Fires:+> stirred;
        for (index, at) in enumerate(spots) {
            if index % 4 == 0 {
                build.foe(at[0], at[1], 0, E1M3_FOES.pick(dice, self.danger), float(index * 90), waits=stirred);
            }
        }
        if not self.flooded {
            build.foe(float(mid) + 1.5, float(mid) + 1.5, 0, E1M3_FOES.pick(dice, self.danger, True), 0.0);
        }
        # Zombies shambling up and down the passages.
        lane = float(starts[1]) + 1.5;
        build.foe(lane, 2.5, 0, "monster_zombie", 90.0, patrol=[[lane, 2.5], [lane, float(starts[1]) - 3.5]]);
        far_lane = float(starts[2]) + 1.5;
        build.foe(2.5, far_lane, 0, "monster_zombie", 0.0, patrol=[[2.5, far_lane], [float(self.long) - 2.5, far_lane]]);
        build.supply(float(starts[0]) + 1.5, float(starts[0]) + 1.5, 0, "item_health");
        build.supply(float(starts[2]) + 1.5, float(starts[2]) + 1.5, 0, "item_rockets");
        build.supply(float(starts[2]) + 1.5, float(starts[0]) + 1.5, 0, "item_shells");
    }
}

"""A court under the sky: graves, a broad channel with a footbridge (or
stepping stones), a terrace up a stair at the far end (over a tomb, or on solid)."""
node Graveyard(Prefab) {
    has channel_x: int = 10,
        channel: int = 6,
        lane: int = 6,
        terrace: int = 5,
        tall: int = 16,
        top: int = 6,
        tomb: bool = False,
        stones: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Graveyard";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(27, 31);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(16, 18);
        self.channel_x = dice.between(9, 11);
        self.channel = dice.between(6, 7);
        self.tomb = dice.chance(0.5);
        self.stones = self.wide >= 17 and dice.chance(0.6);
        self.terrace = dice.between(7, 8) if self.tomb else dice.between(5, 6);
        self.top = 7 if self.tomb else 6;
        self.lane = dice.between(7, self.wide - 10) if self.stones else dice.between(3, self.wide - 6);
        self.low = -7;
        self.high = self.tall + 1;
        top_x = float(self.long - 1 - self.terrace) + float(self.terrace) * 0.5;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=1);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=self.top + 1),
            Port(face=1, along=top_x, floor=self.top + 1),
            Port(face=3, along=top_x, floor=self.top + 1)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.top);
        # The channel, steps up out of it at both ends.
        far_bank = self.channel_x + self.channel;
        build.pool(self.channel_x, 1, -6, far_bank, self.wide - 1, 0, 2, False, True, True);
        if self.stones {
            # Stepping stones: a long block in the middle, a cell of water to
            # jump either side of it.
            build.solid(self.channel_x + 1, self.lane, -6, far_bank - 1, self.lane + 3, 0);
        } else {
            # The footbridge a slab arching over the water, the channel
            # running on under it.
            build.solid(self.channel_x, self.lane, -1, far_bank, self.lane + 3, 0);
        }
        for across in range(3) {
            build.keep(court, self.channel_x - 1, self.lane + across, 0);
            build.keep(court, far_bank, self.lane + across, 0);
        }
        # The terrace, and its stair up the middle.
        terrace_x = self.long - 1 - self.terrace;
        middle = self.wide // 2;
        if self.tomb {
            # The terrace roofs a tomb: its front wall, a doorway in it at one
            # side, coffins and the dead within, a closet in its far wall.
            deck(build, terrace_x, 1, self.long - 1, self.wide - 1, self.top);
            build.solid(terrace_x, 1, 0, terrace_x + 1, self.wide - 1, self.top - 1);
            door_y = 2 if dice.chance(0.5) else self.wide - 5;
            build.widen(court, terrace_x, door_y, 0, terrace_x + 1, door_y + 3, 5);
            for y in range(3, self.wide - 3, 4) {
                if y + 2 < middle - 2 or y > middle + 2 {
                    build.solid(terrace_x + 3, y, 0, terrace_x + 5, y + 2, 1);
                }
            }
            stash(build, self.long - 5, middle - 2, 0, 2, e1m3_reward(dice));
            dead = build.waiting();
            # The tomb's door grinds open as the player crosses the channel,
            # and its dead come out.
            tomb_door = build.opened(float(terrace_x), float(door_y), 0.0, float(terrace_x + 1), float(door_y + 3), 5.0);
            for index in range(dice.between(2, 3)) {
                build.foe(float(terrace_x) + 2.5, 2.5 + float(index) * float(self.wide - 5) * 0.5, 0, E1M3_FOES.pick(dice, self.danger), 180.0, waits=dead);
            }
        } else {
            build.solid(terrace_x, 1, 0, self.long - 1, self.wide - 1, self.top);
        }
        stair(build, terrace_x - self.top, middle - 1, 0, 0, self.top, 3);
        for y in range(middle - 2, middle + 3) {
            build.keep(court, terrace_x, y, self.top);
            build.keep(court, terrace_x - 1, y, self.top);
        }
        # A second stair up the terrace's face against a side wall.
        side_y = 1 if self.lane > middle else self.wide - 4;
        side_stair = not self.tomb and far_bank + 2 < terrace_x - self.top;
        if side_stair {
            stair(build, terrace_x - self.top, side_y, 0, 0, self.top, 3);
            for y in range(side_y, side_y + 3) {
                build.keep(court, terrace_x, y, self.top);
                build.keep(court, terrace_x - 1, y, self.top);
            }
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # Graves in rows across the near half and between channel and stair.
        clear = [[0, int(self.enter.along) - 3, 4, int(self.enter.along) + 3], [self.channel_x - 2, self.lane - 1, far_bank + 2, self.lane + 4], [terrace_x - self.top - 2, middle - 3, terrace_x, middle + 4]];
        if self.tomb {
            clear.append([terrace_x - 3, 0, terrace_x, self.wide]);
        }
        if side_stair {
            clear.append([terrace_x - self.top - 2, side_y - 1, terrace_x, side_y + 4]);
        }
        for x in list(range(3, self.channel_x - 1, 3)) + list(range(far_bank + 2, terrace_x - 1, 3)) {
            for y in range(2, self.wide - 2, 4) {
                if apart([x, y, x + 1, y + 2], clear) {
                    build.solid(x, y, 0, x + 1, y + 2, dice.between(1, 2));
                }
            }
        }
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 2.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, E1M3_FOES.pick(dice, self.danger), 0.0);
        }
        # The terrace's guard is roused as the player crosses the channel.
        crossing = build.touch(float(self.channel_x), float(self.lane), 0.0, float(far_bank), float(self.lane + 3), 6.0);
        guard = build.waiting();
        crossing +>:Fires:+> guard;
        if self.tomb {
            crossing +>:Fires:+> tomb_door;
            crossing +>:Fires:+> dead;
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(terrace_x) + 2.5, 3.5 + float(index) * 4.0, self.top, E1M3_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        }
        # Zombies wandering the graves, either side of the channel.
        build.foe(float(far_bank) + 2.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[float(far_bank) + 1.5, 1.5], [float(far_bank) + 1.5, float(self.wide) - 2.5]]);
        build.foe(2.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[2.5, 2.5], [float(self.channel_x) - 1.5, 2.5], [float(self.channel_x) - 1.5, float(self.wide) - 2.5]]);
        build.supply(float(far_bank) + 2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, self.top, "item_rockets");
    }
}

"""A crypt, a ledge across its far end with the way on up on it; shooting
the button on the ledge's face raises a stair out of the floor to it."""
node SunkenCrypt(Prefab) {
    has ledge: int = 8,
        tall: int = 18,
        turning: bool = False,
        gallery: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sunken crypt";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.turning = dice.chance(0.5);
        self.gallery = not self.turning and dice.chance(0.7);
        self.ledge = dice.between(10, 12) if self.turning else dice.between(7, 9);
        self.long = dice.between(28, 32);
        self.wide = dice.between(14, 16);
        self.tall = self.ledge + dice.between(9, 11);
        self.low = -self.ledge - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=1);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=1, along=float(self.long - 3), floor=self.ledge), Port(face=3, along=float(self.long - 3), floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        crypt = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(crypt, self.ledge);
        ledge_x = self.long - 6;
        build.solid(ledge_x, 1, 0, self.long - 1, self.wide - 1, self.ledge);
        build.doorway(crypt, self.enter);
        for port in self.taken {
            build.doorway(crypt, port);
        }
        shot = build.cue([build.button(float(ledge_x), float(self.wide) - 2.5 if self.turning else 2.5, 4.0, 2, "", True)], "button");
        if self.turning {
            # The stair turns: a flight rises along the side wall onto a
            # platform, and a second rises out of the platform's top to the
            # ledge, both at the one shot.
            half = self.ledge // 2;
            second = self.ledge - half;
            rail_x = ledge_x - second - 4;
            build.level(crypt, half);
            build.solid(rail_x, half + 1, 0, ledge_x, half + 5, half);
            shot +>:Fires:+> build.rising_steps(rail_x, 1, 0, 1, half, 4);
            shot +>:Fires:+> build.rising_steps(rail_x + 4, half + 1, half, 0, second, 4);
            for y in range(half + 1, half + 5) {
                build.keep(crypt, ledge_x, y, self.ledge);
            }
            for x in range(rail_x, rail_x + 4) {
                build.keep(crypt, x, half + 1, half);
            }
            stair_from = rail_x;
        } else {
            # The stair that rises straight up the middle to the ledge.
            shot +>:Fires:+> build.rising_steps(ledge_x - self.ledge, middle - 2, 0, 0, self.ledge, 4);
            for y in range(middle - 2, middle + 2) {
                build.keep(crypt, ledge_x, y, self.ledge);
            }
            stair_from = ledge_x - self.ledge;
        }
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "Shoot the button!");
        # The crypt's middle sunk under water, a walk round it by the niches.
        if stair_from - 2 - 5 >= 4 {
            build.pool(5, 4, -3, stair_from - 2, self.wide - 4, 0, 2);
            build.foe(float(stair_from) * 0.5 + 2.5, float(middle) + 0.5, -2, "monster_fish", 0.0);
        }
        # The crypt's dead wake as the stair grinds up; a moment on, a foe is
        # brought in behind the player, from a closet sealed in the ledge.
        stirred = build.waiting();
        shot +>:Fires:+> stirred;
        later = build.delay(2.0);
        shot +>:Fires:+> later;
        later +>:Fires:+> build.summon(self.long - 5, 2, 1, E1M3_FOES.pick(dice, self.danger, True), 3.5, float(middle) + 0.5, 0, 0.0);
        spots = niches(build, crypt, 1, 4, stair_from - 2, 0, 6, 3, False, -1) + niches(build, crypt, self.wide - 2, 4, stair_from - 2, 0, 6, 3, False, 1);
        for (index, at) in enumerate(spots) {
            if index % 2 == 0 {
                build.foe(at[0], at[1], 0, E1M3_FOES.pick(dice, self.danger), 90.0 if at[1] < float(middle) else 270.0, waits=stirred);
            }
        }
        # The gallery back along the side wall from the ledge, its guards
        # woken with the dead, a closet at its end.
        if self.gallery {
            gy = self.wide - 5;
            deck(build, 1, gy, ledge_x, gy + 4, self.ledge);
            stash(build, 1, gy, self.ledge, 0, e1m3_reward(dice));
            # A stretch of its edge with no railing, to drop back down from.
            for x in range(7, 10) {
                build.keep(crypt, x, gy, self.ledge);
            }
            for index in range(dice.between(1, 2)) {
                build.foe(float(ledge_x) - 3.5 - float(index) * 5.0, float(gy) + 2.0, self.ledge, E1M3_FOES.pick(dice, self.danger), 270.0, waits=stirred);
            }
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, self.ledge, E1M3_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(3.5, 2.5, 0, "monster_zombie", 0.0, patrol=[[3.5, 2.5], [float(stair_from) - 2.5, 2.5]]);
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
    }
}

"""A pit crossed by platforms riding back and forth over it, a lift or a
stair up out of it to the near ledge, the far ledge's guard roused as the
player lands."""
node PitFerry(Prefab) {
    has near: int = 6,
        span: int = 12,
        far: int = 7,
        tall: int = 15,
        deep: int = 8,
        far_top: int = 0,
        lava: bool = False,
        wet: bool = False,
        two: bool = False,
        plat: bool = False,
        called: bool = False,
        up_y: int = 1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pit ferry";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.near = dice.between(6, 7);
        self.span = dice.between(12, 15);
        self.far = dice.between(7, 8);
        self.lava = dice.chance(0.3);
        self.wet = not self.lava and dice.chance(0.7);
        self.two = dice.chance(0.6);
        self.plat = dice.chance(0.5);
        self.called = dice.chance(0.45);
        self.far_top = [0, 0, 3, 6][dice.below(4)];
        self.wide = dice.between(16, 18) if self.two else dice.between(14, 16);
        self.tall = dice.between(14, 16);
        self.deep = dice.between(8, 9);
        self.up_y = 1 if dice.chance(0.5) else self.wide - 4;
        self.long = 1 + self.near + self.span + self.far + 1;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=1);
        far_x = float(self.long - 1 - self.far) + float(self.far) * 0.5;
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=self.far_top + 1),
            Port(face=1, along=far_x, floor=self.far_top + 1),
            Port(face=3, along=far_x, floor=self.far_top + 1)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 1 + self.near;
        x1 = x0 + self.span;
        depth_of = self.deep - 3 if self.wet else (2 if self.lava else 0);
        build.room(x0, 1, -self.deep, x1, self.wide - 1, 0, flood=depth_of, deadly=self.lava);
        if self.wet {
            # Flooded nearly to the ledges, what lives down there.
            build.foe(float(x0) + 5.5, float(self.wide // 2) + 0.5, -self.deep, "monster_fish", 180.0);
        }
        if self.far_top > 0 {
            build.level(hall, self.far_top);
            build.solid(x1, 1, 0, self.long - 1, self.wide - 1, self.far_top);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The way up out of the pit to the near ledge, along a side wall.
        if self.plat {
            lift(build, x0, self.up_y, x0 + 3, self.up_y + 3, -self.deep, 0);
        } else {
            stair(build, x0 + self.deep - 1, self.up_y, -self.deep, 2, self.deep, 3);
        }
        for y in range(self.up_y, self.up_y + 3) {
            build.keep(hall, x0 - 1, y, 0);
        }
        # The ferries: platforms riding over the pit from ledge to ledge and
        # back, two in lanes side by side going opposite ways when `two`.
        middle = self.wide // 2;
        lanes = [middle - 4, middle + 1] if self.two else [middle - 1];
        # Called, they wait until the button on the near ledge's wall is
        # pressed (e1m3's platforms set going by a button).
        call: Cue | None = None;
        if self.called {
            call = build.push(1.0, float(middle) + (3.5 if self.two else 2.5), 2.5, 0);
            build.touch(1.0, 1.0, 0.0, 3.0, float(self.wide - 1), 6.0, True, "Press the button to call the platforms");
        }
        for (index, lane) in enumerate(lanes) {
            near_stop = [float(x0), float(lane), -1.0];
            far_stop = [float(x1 - 3), float(lane), float(self.far_top - 1)];
            stops = [near_stop, far_stop] if index == 0 else [far_stop, near_stop];
            ride = build.train([3.0, 3.0, 1.0], stops, 70.0, 2.5, self.called);
            if call is not None {
                call +>:Fires:+> ride;
            }
            for across in range(3) {
                build.keep(hall, x0 - 1, lane + across, 0);
                build.keep(hall, x1, lane + across, self.far_top);
            }
        }
        # The far ledge's guard is roused as the player steps off.
        landed = build.touch(float(x1), 1.0, float(self.far_top), float(x1 + 2), float(self.wide - 1), float(self.far_top + 6));
        guard = build.waiting();
        landed +>:Fires:+> guard;
        # The far ledge's doors grind open as the player lands there.
        bars(build, landed, self.taken, self.long, self.wide);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * 4.0, self.far_top, E1M3_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(float(x1) + 2.5, 2.5, self.far_top, "monster_zombie", 90.0, patrol=[[float(x1) + 2.5, 2.5], [float(x1) + 2.5, float(self.wide) - 2.5]]);
        # The near ledge's edge unrailed beside the way up, to drop in from;
        # down in a dry pit, the dead and a closet under the near ledge.
        if not self.lava {
            drop_y = self.up_y + 3 if self.up_y == 1 else self.up_y - 3;
            for y in range(drop_y, drop_y + 3) {
                build.keep(hall, x0 - 1, y, 0);
            }
        }
        if not self.lava and not self.wet {
            for index in range(dice.between(1, 3)) {
                build.foe(float(x0) + 5.5 + float(index) * 3.0, float(middle) + 0.5, -self.deep, "monster_zombie", 180.0);
            }
            hide_y = self.wide - 6 if self.up_y == 1 else 2;
            stash(build, x0 - 4, hide_y, -self.deep, 0, e1m3_reward(dice));
        }
        build.foe(3.5, 2.5, 0, E1M3_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.far_top, "item_health");
    }
}

"""Where a stair of `steps` winding round the ring `width` cells wide inside
the box x0..x1, y0..y1 from the ring's cell `start` lands, when its four
cells of landing all lie on face `face`: the middle of the landing along
that face, or -1.0 when they do not."""
def ring_top(x0: int, y0: int, x1: int, y1: int, width: int, steps: int, start: int, face: int) -> float {
    path = ring_path(x0, y0, x1, y1, width);
    lap = len(path);
    low = 100000;
    high = -100000;
    for index in range(4) {
        cell = path[(start + steps + index) % lap];
        if cell[4] != face {
            return -1.0;
        }
        at = cell[1] if face % 2 == 0 else cell[0];
        low = min(low, at);
        high = max(high, at);
    }
    return float(low + high + 1) * 0.5;
}

"""A deep well of bones: a stair winding round an inner ring of its walls
from its floor to a landing high on one face, a walk round its foot, and a
lift up its middle beside the landing. By the dice the way in is at the
top and the ways on down at the foot, or the way in at the foot and the
way on at the top; the lift is there or not."""
node BoneWell(Prefab) {
    has climb: int = 16,
        start_at: int = 0,
        top_along: float = 0.0,
        down: bool = True,
        plat: bool = False,
        elevator: bool = False,
        barred: bool = False,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bone well";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(19, 21);
        self.wide = dice.between(19, 21);
        self.down = dice.chance(0.6);
        lift_kind = dice.weighted([0.2, 0.35, 0.45]);
        self.plat = lift_kind == 1;
        self.elevator = lift_kind == 2;
        self.barred = dice.chance(0.7);
        self.climb = dice.between(14, 20);
        face = 2 if self.down else 0;
        path = ring_path(4, 4, self.long - 4, self.wide - 4, 3);
        fits: list[int] = [];
        for begin in range(len(path)) {
            if ring_top(4, 4, self.long - 4, self.wide - 4, 3, self.climb, begin, face) > 0.0 {
                fits.append(begin);
            }
        }
        self.start_at = fits[dice.below(len(fits))];
        self.top_along = ring_top(4, 4, self.long - 4, self.wide - 4, 3, self.climb, self.start_at, face);
        self.tall = self.climb + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        cross = float(self.long // 2);
        if self.down {
            self.enter = Port(face=2, along=self.top_along, floor=self.climb);
            self.leaves = [Port(face=0, along=middle, floor=1), Port(face=1, along=cross, floor=1), Port(face=3, along=cross, floor=1)];
        } else {
            self.enter = Port(face=2, along=middle, floor=1);
            self.leaves = [Port(face=0, along=self.top_along, floor=self.climb), Port(face=1, along=cross, floor=1)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        well = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(well, self.climb // 2);
        build.level(well, self.climb);
        spiral(build, 4, 4, self.long - 4, self.wide - 4, 0, self.climb, 3, 4, self.start_at);
        # The walk from the high doorway across the foot's walk to the
        # landing, a deck over the walk below.
        low = int(self.top_along) - 2;
        if self.down {
            deck(build, 1, low, 4, low + 4, self.climb);
            for y in range(low, low + 4) {
                build.keep(well, 3, y, self.climb);
                build.keep(well, 4, y, self.climb);
            }
        } else {
            deck(build, self.long - 4, low, self.long - 1, low + 4, self.climb);
            for y in range(low, low + 4) {
                build.keep(well, self.long - 4, y, self.climb);
                build.keep(well, self.long - 5, y, self.climb);
            }
        }
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        # The lift up the middle, beside the landing.
        px = 7 if self.down else self.long - 10;
        if self.plat {
            lift(build, px, low, px + 3, low + 3, 0, self.climb);
        } elif self.elevator {
            build.train([3.0, 3.0, 1.0], [[float(px), float(low), -1.0], [float(px), float(low), float(self.climb - 1)]], 90.0, 2.5);
        }
        if self.plat or self.elevator {
            for y in range(low, low + 3) {
                build.keep(well, px - 1 if self.down else px + 3, y, self.climb);
            }
        }
        # A stretch of the landing walk's side unrailed, to drop from.
        for x in range(1, 4) {
            build.keep(well, x if self.down else self.long - 1 - x, low + 3, self.climb);
        }
        # Barred: the ways on shut until a button opens them: going down,
        # one high on the well's wall over the landing, to be shot; going
        # up, one in a corner of the foot.
        if self.barred and self.taken {
            if self.down {
                opener = build.cue([build.button(1.0, float(low) - 1.5, float(self.climb) + 4.0, 0, "", True)], "button");
            } else {
                opener = build.push(1.0, 2.5, 2.5, 0);
            }
            bars(build, opener, self.taken, self.long, self.wide);
        }
        # What waits on the stair wakes as the player passes its middle.
        path = ring_path(4, 4, self.long - 4, self.wide - 4, 3);
        lap = len(path);
        half = path[(self.start_at + self.climb // 2) % lap];
        roused = build.touch(float(half[0]), float(half[1]), float(self.climb // 2 + 1), float(half[2]), float(half[3]), float(self.climb // 2 + 7));
        above = build.waiting();
        roused +>:Fires:+> above;
        top = path[(self.start_at + self.climb + 1) % lap];
        build.foe(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.climb, E1M3_FOES.pick(dice, self.danger, True), 180.0, waits=above);
        for index in range(dice.between(1, 2)) {
            cell = path[(self.start_at + self.climb // 2 + 3 + index * 3) % lap];
            build.foe(float(cell[0] + cell[2]) * 0.5, float(cell[1] + cell[3]) * 0.5, self.climb // 2 + 4 + index * 3, E1M3_FOES.pick(dice, self.danger), 90.0, waits=above);
        }
        # The dead at the foot, one walking the walk round it.
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, "monster_zombie", 0.0);
        build.foe(1.5, 1.5, 0, "monster_zombie", 0.0, patrol=[[1.5, 1.5], [float(self.long) - 2.0, 1.5], [float(self.long) - 2.0, float(self.wide) - 2.0], [1.5, float(self.wide) - 2.0]]);
        build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, 0, "item_health");
        build.supply(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.climb, "item_rockets");
    }
}

"""The key room: a hall over a crypt far below, a stair winding down round
the walls of a well (or a shaft to drop down, a lift back up), the key on
a dais down there; taking it opens the closets in the crypt's wall and
brings a foe in by a teleporter."""
node GoldCrypt(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 14,
        tall: int = 10,
        depth: int = 16,
        winding: bool = False,
        start_at: int = 0,
        hidden: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold crypt (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(15, 16);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(10, 12);
        self.depth = dice.between(14, 18);
        self.winding = dice.chance(0.5);
        self.hidden = dice.chance(0.6);
        # Where round the well's ring its stair starts, so its top lands on
        # the well's near face, beside the hall's floor.
        if self.winding {
            path = ring_path(self.long - 13, 1, self.long - 1, self.hall_wide - 1, 3);
            lap = len(path);
            fits: list[int] = [];
            for begin in range(lap) {
                good = True;
                for index in range(4) {
                    if path[(begin + self.depth + index) % lap][4] != 2 {
                        good = False;
                    }
                }
                if good {
                    fits.append(begin);
                }
            }
            if fits {
                self.start_at = fits[dice.below(len(fits))];
            } else {
                self.winding = False;
            }
        }
        self.low = -self.depth - 6;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=1);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = self.hall_wide // 2;
        bottom = -self.depth;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        crypt = build.room(2, 1, bottom, self.long - 1, side, bottom + 8, variant=dice.below(3));
        build.level(crypt, bottom);
        wx0 = self.long - 13;
        way_up_z = 0;
        if self.winding {
            # The well at the hall's far end, open from the crypt up, and the
            # stair winding up round its walls to the hall's floor.
            well = build.room(wx0, 1, bottom + 8, self.long - 1, side, 0);
            build.level(well, bottom + self.depth // 2);
            path = ring_path(wx0, 1, self.long - 1, side, 3);
            lap = len(path);
            top_cells = spiral(build, wx0, 1, self.long - 1, side, bottom, self.depth, 3, 4, self.start_at);
            for cell in top_cells {
                for y in range(cell[1], cell[3]) {
                    build.keep(hall, wx0 - 1, y, 0);
                    build.keep(well, cell[0], y, 0);
                }
            }
            # Along the rim away from the stair's top, no railing: a body may
            # drop down the well.
            landed_ys = [y for cell in top_cells for y in range(cell[1], cell[3])];
            drop_y = 2 if min(landed_ys) > 6 else side - 4;
            for y in range(drop_y, drop_y + 3) {
                build.keep(hall, wx0 - 1, y, 0);
            }
            halfway = path[(self.start_at + self.depth // 2) % lap];
            way_up = [float(halfway[0]) + 0.5, float(halfway[1]) + 0.5];
            way_up_z = bottom + self.depth // 2 + 1;
            # A pool at the foot of the well, what drops down it lands in.
            build.pool(wx0 + 3, 4, bottom - 4, self.long - 4, side - 3, bottom, 2);
        } else {
            # A shaft down at the hall's far end, and the lift back up it.
            sx = self.long - 6;
            build.room(sx, cy - 2, bottom + 8, sx + 4, cy + 2, 0);
            lift(build, sx, cy - 2, sx + 4, cy + 2, bottom, 0);
            # No railing on its near side: a body drops down the shaft.
            for y in range(cy - 2, cy + 2) {
                build.keep(hall, sx - 1, y, 0);
            }
            build.touch(float(sx) - 2.0, float(cy - 2), 0.0, float(sx), float(cy + 2), 6.0, True, "The crypt lies below");
            way_up = [float(sx) - 1.5, float(cy) + 0.5];
            # A channel across the crypt between the dais and the lift, a dry
            # walk along its side by the closets.
            build.pool(10, 1, bottom - 4, 15, side - 3, bottom, 2);
        }
        # Pillars in the hall above.
        pillars(build, 4, 3, wx0 - 1, 4, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        pillars(build, 4, side - 3, wx0 - 1, side - 2, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        # Down in the crypt, the key on a low dais at its near end.
        build.solid(3, cy - 2, bottom, 9, cy + 2, bottom + 1);
        build.solid(4, cy - 1, bottom + 1, 6, cy + 1, bottom + 3);
        fields = {"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1"};
        build.put_at(fields, 7.0, float(cy) + 0.5, bottom + 1);
        taken = build.cue([fields], "key");
        # Taking it opens the closets in the crypt's wall, and a moment on a
        # foe is brought in where the way up begins.
        closets = [3, 7] if self.winding else [3, 7, 11, 15];
        for (index, at) in enumerate(closets) {
            closet = build.room(at, side + 1, bottom, at + 3, side + 4, bottom + 7);
            build.widen(closet, at, side, bottom, at + 3, side + 1, bottom + 6);
            taken +>:Fires:+> build.opened(float(at), float(side), float(bottom), float(at + 3), float(side + 1), float(bottom + 6));
            build.foe(float(at) + 1.5, float(side) + 2.5, bottom, E1M3_FOES.pick(dice, self.danger, index == 0), 270.0);
        }
        later = build.delay(2.5);
        taken +>:Fires:+> later;
        later +>:Fires:+> build.summon(2, 2, self.tall + 1, E1M3_FOES.pick(dice, self.danger, True), 13.5, float(cy) + 0.5, bottom, 180.0);
        # The crypt's dead wake as the player comes down.
        stirred = build.waiting();
        build.touch(float(wx0) - 2.0, 1.0, float(bottom), float(wx0 + 1), float(side), float(bottom + 6)) +>:Fires:+> stirred;
        for index in range(dice.between(2, 3)) {
            build.foe(10.5 + float(index) * 3.0, 2.5 + float(index % 2) * float(side - 4), bottom, E1M3_FOES.pick(dice, self.danger), 180.0, waits=stirred);
        }
        if self.hidden {
            stash(build, 2, 1, bottom, 0, e1m3_reward(dice));
        }
        build.foe(float(wx0) - 3.5, 2.5, 0, E1M3_FOES.pick(dice, self.danger), 0.0, patrol=[[float(wx0) - 3.5, 2.5], [3.5, 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(way_up[0], way_up[1], way_up_z, "item_spikes");
        build.supply(9.5, float(side) - 2.5, bottom, "item_health");
    }
}

"""A long nave: pews, two aisles of pillars, an altar on a dais and the
way out upon it, or high on a gallery over it up a lift; as a gate, a key
door across the nave."""
node Nave(Prefab) {
    has key: str = "",
        gate_x: int = 20,
        tall: int = 20,
        perch: int = 0,
        elevator: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nave" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.perch = dice.between(12, 15) if dice.chance(0.5) else 0;
        self.elevator = self.perch > 0 and dice.chance(0.5);
        self.long = dice.between(30, 32) if self.perch > 0 else dice.between(26, 30);
        self.wide = dice.between(13, 15);
        self.tall = max(dice.between(18, 22), self.perch + 10);
        self.gate_x = self.long - 1 - (dice.between(13, 14) if self.perch > 0 else dice.between(8, 9));
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=1);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(nave, self.enter);
        aisle = [[0, middle - 2, self.long, middle + 2]];
        pillars(build, 4, 3, self.gate_x - 1, 4, 0, self.tall, 3, aisle);
        pillars(build, 4, self.wide - 4, self.gate_x - 1, self.wide - 3, 0, self.tall, 3, aisle);
        # Pews either side of the aisle, short of the gate.
        for x in range(5, self.gate_x - 2, 2) {
            build.solid(x, 4, 0, x + 1, middle - 2, 1);
            build.solid(x, middle + 2, 0, x + 1, self.wide - 4, 1);
        }
        # The gate: a wall across with a way through the aisle, a key door in
        # it when the nave is a gate.
        build.solid(self.gate_x, 1, 0, self.gate_x + 1, middle - 2, self.tall);
        build.solid(self.gate_x, middle + 2, 0, self.gate_x + 1, self.wide - 1, self.tall);
        build.solid(self.gate_x, middle - 2, 8, self.gate_x + 1, middle + 2, self.tall);
        if self.key {
            build.rising_door(float(self.gate_x), float(middle - 2), 0.0, float(self.gate_x + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The altar dais, two lifts up by two steps.
        dais_x = self.gate_x + 3;
        build.solid(dais_x, 2, 0, self.long - 1, self.wide - 2, 1);
        build.solid(dais_x + 1, 2, 1, self.long - 1, self.wide - 2, 2);
        if self.perch > 0 {
            # The way out high on a gallery over the altar's end, ridden up
            # to on a lift standing on the dais.
            build.level(nave, self.perch);
            gx = self.long - 7;
            deck(build, gx, 1, self.long - 1, self.wide - 1, self.perch);
            if self.elevator {
                # A platform riding up and down between the dais and the
                # gallery without end.
                build.train([3.0, 3.0, 1.0], [[float(gx - 3), float(middle - 1), 1.0], [float(gx - 3), float(middle - 1), float(self.perch - 1)]], 90.0, 2.5);
            } else {
                lift(build, gx - 3, middle - 1, gx, middle + 2, 2, self.perch);
            }
            for y in range(middle - 1, middle + 2) {
                build.keep(nave, gx, y, self.perch);
            }
            build.way_out(float(self.long) - 3.5, float(middle), self.perch);
            build.foe(float(self.long) - 3.5, 2.5, self.perch, E1M3_FOES.pick(dice, self.danger, True), 180.0);
            build.supply(float(gx) + 1.5, float(self.wide) - 2.5, self.perch, "item_health");
        } else {
            build.way_out(float(dais_x + 1) + float(self.long - 2 - dais_x) * 0.5, float(middle), 2);
        }
        # Climbing to the altar brings a foe in behind, by a teleporter in a
        # closet sealed under the dais, and wakes the dead in the pews.
        altar = build.touch(float(dais_x), 2.0, 1.0, float(dais_x + 2), float(self.wide - 2), 7.0);
        altar +>:Fires:+> build.summon(dais_x + 2, 2, -8, E1M3_FOES.pick(dice, self.danger, True), float(self.gate_x) - 3.0, float(middle) + 0.5, 0, 0.0);
        pews = build.waiting();
        altar +>:Fires:+> pews;
        # And the closets in the walls either side of the gate burst open,
        # what waits in them coming at the player's back.
        for (index, cy) in enumerate([1, self.wide - 4]) {
            cx = self.gate_x - 4;
            build.solid(cx - 1, cy, 0, cx + 3, cy + 3, self.tall);
            closet = build.room(cx, cy if cy == 1 else cy + 1, 0, cx + 2, cy + 2 if cy == 1 else cy + 3, 6);
            door_y = cy + 2 if cy == 1 else cy;
            altar +>:Fires:+> build.opened(float(cx), float(door_y), 0.0, float(cx + 2), float(door_y + 1), 6.0);
            build.foe(float(cx) + 1.0, float(cy) + (1.0 if cy == 1 else 2.0), 0, E1M3_FOES.pick(dice, self.danger, index == 0), 0.0);
            build.keep(closet, cx, door_y, 0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(6.5 + float(index) * 3.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, E1M3_FOES.pick(dice, self.danger), 0.0, waits=pews);
        }
        build.foe(3.5, float(middle) + 0.5, 0, "monster_zombie", 0.0, patrol=[[3.5, float(middle) + 0.5], [float(self.gate_x) - 2.5, float(middle) + 0.5]]);
        build.foe(float(self.gate_x) - 2.5, float(middle) + 0.5, 0, E1M3_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_rockets");
    }
}

"""e1m3's stretches: [name, role]."""
glob E1M3_STRETCHES: list[list[str]] = [
         ["crypt_stair", "start"],
         ["catacombs", "flow"],
         ["catacombs", "hub"],
         ["graveyard", "flow"],
         ["sunken", "flow"],
         ["ferry", "flow"],
         ["well", "flow"],
         ["gold_crypt", "keyroom"],
         ["nave", "end"],
         ["nave", "gate"]
     ];

"""One of e1m3's stretches by its name."""
def make_e1m3(name: str, key: str) -> Prefab {
    if name == "crypt_stair" {
        return CryptStair();
    }
    if name == "catacombs" {
        return Catacombs();
    }
    if name == "graveyard" {
        return Graveyard();
    }
    if name == "sunken" {
        return SunkenCrypt();
    }
    if name == "ferry" {
        return PitFerry();
    }
    if name == "well" {
        return BoneWell();
    }
    if name == "gold_crypt" {
        return GoldCrypt(key=key if key else "key_gold");
    }
    return Nave(key=key);
}
