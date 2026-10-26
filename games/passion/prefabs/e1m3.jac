"""Prefabs drawn from e1m3, the Necropolis: its crypts and catacombs full of
zombies, its graveyard under the sky, its gold key in a crypt, its nave.
Raised in e1m3's own palette.

- `CryptStair`: the start. A landing high at one end of a crypt, a grand
  stair down into it, pillars down its length and zombies waiting in the
  niches of its walls, roused as the player reaches the stair's foot.
- `Catacombs`: three passages each way crossing in a grid, a tall crypt
  where the middle ones cross, zombies in niches along them; ways on in
  every direction (a hub as well as a stretch passed through). A zombie
  shambles the middle passage; the niches' dead stir in the crypt.
- `SunkenCrypt`: a crypt, a ledge across its far end and the way on up on
  it; shooting the button on the ledge's face raises a stair out of the
  floor up to it (e1m3's stair of doors raised by a shot button), and the
  crypt's dead wake as it rises.
- `Graveyard`: a court under the sky, rows of graves, a channel of water
  across it under a stone footbridge, and a terrace up a stair at the far
  end where ogres stand guard, roused as the player crosses the bridge.
- `GoldCrypt`: a vaulted chamber, a sarcophagus on a low dais and the key
  beside it; taking it opens the closets in the wall.
- `Nave`: a long nave with pews and two aisles of pillars, an altar on a
  dais and the way out upon it; as a gate, a key door across the nave.
  Climbing to the altar brings a foe in behind the player by a teleporter
  (e1m3's teleported ambush) and wakes the pews' dead."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, apart, niches }

glob E1M3: str = "q1:e1m3";

"""e1m3's foes: zombies above all, ogres and scrags, fiends deeper in."""
def e1m3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_zombie", "monster_zombie", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_wizard"], ["monster_demon1"] if heavy else ["monster_ogre"], danger));
}

"""The start: a landing high at one end of a crypt, a grand stair down."""
node CryptStair(Prefab) {
    has landing: int = 7,
        drop: int = 9,
        crypt: int = 16,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt stair";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.landing = dice.between(6, 8);
        self.drop = dice.between(8, 10);
        self.crypt = dice.between(16, 20);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(14, 17);
        self.long = 1 + self.landing + self.drop + self.crypt + 1;
        self.low = -1;
        self.high = self.drop + self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.drop);
        self.leaves = [Port(face=0, along=middle - 3.0, floor=0), Port(face=0, along=middle + 3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 2, 0, self.long - 1, self.wide - 2, self.drop + self.tall, variant=dice.below(3));
        build.level(hall, self.drop);
        build.solid(1, 2, 0, 1 + self.landing, self.wide - 2, self.drop);
        # The stair down, four cells wide in the middle, a lift a cell.
        foot = 1 + self.landing;
        for step in range(self.drop) {
            build.solid(foot + step, middle - 2, 0, foot + step + 1, middle + 2, self.drop - 1 - step);
        }
        for y in range(middle - 3, middle + 3) {
            build.keep(hall, foot - 1, y, self.drop);
        }
        floor_x = foot + self.drop;
        clear = [[0, middle - 3, floor_x + 2, middle + 3], [self.long - 3, middle - 6, self.long, middle + 6]];
        pillars(build, floor_x + 2, 4, self.long - 2, self.wide - 4, 0, self.drop + self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Niches down both walls of the crypt below, a zombie in each.
        low_side = niches(build, hall, 1, floor_x + 1, self.long - 3, 0, 6, 3, False, -1);
        high_side = niches(build, hall, self.wide - 2, floor_x + 1, self.long - 3, 0, 6, 3, False, 1);
        # The dead in the niches stir as the player reaches the stair's foot.
        foot_touch = build.touch(float(floor_x), float(middle - 2), 0.0, float(floor_x + 2), float(middle + 2), 6.0);
        stirred = build.waiting();
        foot_touch +>:Fires:+> stirred;
        for (index, at) in enumerate(low_side + high_side) {
            if index % 3 == 0 {
                build.foe(at[0], at[1], 0, e1m3_foe(dice, self.danger), 90.0 if at[1] < float(middle) else 270.0, waits=stirred);
            }
        }
        build.start(2.5, float(middle) + 0.5, self.drop, 0.0);
        build.supply(2.5, 3.5, self.drop, "item_shells");
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, e1m3_foe(dice, self.danger, True), 180.0, waits=stirred);
        build.supply(float(self.long) - 2.5, 3.5, 0, "item_health");
    }
}

"""Three passages each way crossing in a grid, a tall crypt in the middle;
ways on in every direction."""
node Catacombs(Prefab) {
    has block: int = 5,
        tall: int = 9;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Catacombs";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.block = dice.between(5, 6);
        self.tall = dice.between(9, 10);
        self.long = 2 * self.block + 12;
        self.wide = 2 * self.block + 12;
        self.low = -1;
        self.high = self.tall + 5;
        lines = [float(2 + index * (self.block + 3)) + 1.5 for index in range(3)];
        self.enter = Port(face=2, along=lines[1], floor=0);
        self.leaves = [
            Port(face=0, along=lines[1], floor=0),
            Port(face=1, along=lines[1], floor=0),
            Port(face=3, along=lines[1], floor=0),
            Port(face=0, along=lines[0], floor=0),
            Port(face=1, along=lines[2], floor=0)
        ];
        visitor.place(self);
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
        # The middle crossing is a crypt, taller and wider, coffins about it.
        mid = starts[1];
        crypt = build.room(mid - 2, mid - 2, 0, mid + 5, mid + 5, self.tall + 4);
        build.level(crypt, 0);
        for (cx, cy) in [(mid - 2, mid - 2), (mid + 4, mid - 2), (mid - 2, mid + 4), (mid + 4, mid + 4)] {
            build.solid(cx, cy, 0, cx + 1, cy + 1, 2);
        }
        build.doorway(passages[3], self.enter);
        for port in self.taken {
            build.doorway(passages[0], port);
        }
        # Niches in the blocks along the passages, between the crossings.
        spots: list[list[float]] = [];
        for index in range(2) {
            between = starts[index] + 3 + self.block // 2 - 1;
            for at in starts {
                spots.extend(niches(build, passages[0], at - 1, between, between + 2, 0, 6, 3, True, -1));
                spots.extend(niches(build, passages[0], at - 1, between, between + 2, 0, 6, 3, False, -1));
            }
        }
        # The niches' dead stir when the player comes into the crypt.
        into = build.touch(float(mid), float(mid), 0.0, float(mid + 3), float(mid + 3), 6.0);
        stirred = build.waiting();
        into +>:Fires:+> stirred;
        for (index, at) in enumerate(spots) {
            if index % 4 == 0 {
                build.foe(at[0], at[1], 0, e1m3_foe(dice, self.danger), float(index * 90), waits=stirred);
            }
        }
        build.foe(float(mid) + 1.5, float(mid) + 1.5, 0, e1m3_foe(dice, self.danger, True), 0.0);
        # A zombie shambling up and down the middle passage.
        lane = float(starts[1]) + 1.5;
        build.foe(lane, 2.5, 0, "monster_zombie", 90.0, patrol=[[lane, 2.5], [lane, float(self.wide) - 2.5]]);
        build.supply(float(starts[0]) + 1.5, float(starts[0]) + 1.5, 0, "item_health");
        build.supply(float(starts[2]) + 1.5, float(starts[2]) + 1.5, 0, "item_rockets");
        build.supply(float(starts[2]) + 1.5, float(starts[0]) + 1.5, 0, "item_shells");
    }
}

"""A court under the sky: graves, a channel with a footbridge, a terrace
up a stair at the far end."""
node Graveyard(Prefab) {
    has channel_x: int = 10,
        lane: int = 6,
        terrace: int = 5,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Graveyard";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(24, 28);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(16, 18);
        self.channel_x = dice.between(9, 11);
        self.terrace = dice.between(5, 6);
        self.lane = dice.between(3, self.wide - 6);
        self.low = -7;
        self.high = self.tall + 1;
        top_x = float(self.long - 1 - self.terrace) + float(self.terrace) * 0.5;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=6),
            Port(face=1, along=top_x, floor=6),
            Port(face=3, along=top_x, floor=6)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, 6);
        # The channel, steps up out of it at both ends, and the stone footbridge
        # over it.
        build.pool(self.channel_x, 1, -6, self.channel_x + 4, self.wide - 1, 0, 2, False, True, True);
        # The footbridge a slab arching over the water, the channel running
        # on under it.
        build.solid(self.channel_x, self.lane, -1, self.channel_x + 4, self.lane + 3, 0);
        for across in range(3) {
            build.keep(court, self.channel_x - 1, self.lane + across, 0);
            build.keep(court, self.channel_x + 4, self.lane + across, 0);
        }
        # The terrace, six lifts up, and its stair.
        terrace_x = self.long - 1 - self.terrace;
        middle = self.wide // 2;
        build.solid(terrace_x, 1, 0, self.long - 1, self.wide - 1, 6);
        stair(build, terrace_x - 6, middle - 1, 0, 0, 6, 3);
        for y in range(middle - 2, middle + 3) {
            build.keep(court, terrace_x, y, 6);
            build.keep(court, terrace_x - 1, y, 6);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # Graves in rows across the near half and between channel and stair.
        clear = [[0, int(self.enter.along) - 3, 4, int(self.enter.along) + 3], [self.channel_x - 2, self.lane - 1, self.channel_x + 6, self.lane + 4], [terrace_x - 8, middle - 3, terrace_x, middle + 4]];
        for x in list(range(3, self.channel_x - 1, 3)) + list(range(self.channel_x + 6, terrace_x - 1, 3)) {
            for y in range(2, self.wide - 2, 4) {
                if apart([x, y, x + 1, y + 2], clear) {
                    build.solid(x, y, 0, x + 1, y + 2, dice.between(1, 2));
                }
            }
        }
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 2.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, e1m3_foe(dice, self.danger), 0.0);
        }
        # The terrace's guard is roused as the player crosses the bridge.
        crossing = build.touch(float(self.channel_x), float(self.lane), 0.0, float(self.channel_x + 4), float(self.lane + 3), 6.0);
        guard = build.waiting();
        crossing +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(terrace_x) + 2.5, 3.5 + float(index) * 4.0, 6, e1m3_foe(dice, self.danger, True), 180.0, waits=guard);
        }
        # A zombie wandering the graves past the channel.
        build.foe(float(self.channel_x) + 6.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[float(self.channel_x) + 5.5, 1.5], [float(self.channel_x) + 5.5, float(self.wide) - 2.5]]);
        build.supply(float(self.channel_x) + 6.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 6, "item_rockets");
    }
}

"""A crypt, a ledge across its far end with the way on up on it; shooting
the button on the ledge's face raises a stair out of the floor to it."""
node SunkenCrypt(Prefab) {
    has ledge: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sunken crypt";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.ledge = dice.between(7, 9);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.tall = self.ledge + dice.between(9, 11);
        self.low = -self.ledge - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
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
        # The stair that rises when the button on the ledge's face is shot.
        steps = build.rising_steps(ledge_x - self.ledge, middle - 2, 0, 0, self.ledge, 4);
        shot = build.cue([build.button(float(ledge_x), 2.5, 4.0, 2, "", True)], "button");
        shot +>:Fires:+> steps;
        for y in range(middle - 2, middle + 2) {
            build.keep(crypt, ledge_x, y, self.ledge);
        }
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "Shoot the button!");
        # The crypt's dead wake as the stair grinds up.
        stirred = build.waiting();
        shot +>:Fires:+> stirred;
        spots = niches(build, crypt, 1, 4, ledge_x - self.ledge - 2, 0, 6, 3, False, -1) + niches(build, crypt, self.wide - 2, 4, ledge_x - self.ledge - 2, 0, 6, 3, False, 1);
        for (index, at) in enumerate(spots) {
            if index % 2 == 0 {
                build.foe(at[0], at[1], 0, e1m3_foe(dice, self.danger), 90.0 if at[1] < float(middle) else 270.0, waits=stirred);
            }
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, self.ledge, e1m3_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
    }
}

"""A vaulted crypt, a sarcophagus on a low dais and the key beside it;
taking the key opens the closets in the wall."""
node GoldCrypt(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 14,
        tall: int = 12,
        closets: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gold crypt (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(18, 22);
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(12, 14);
        self.closets = dice.between(2, 3);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        cx = self.long // 2 + 2;
        cy = self.hall_wide // 2;
        # The dais a lift high, the sarcophagus on it, pillars round them.
        build.solid(cx - 3, cy - 3, 0, cx + 4, cy + 3, 1);
        build.solid(cx - 1, cy - 1, 1, cx + 2, cy + 1, 3);
        for (px, py) in [(cx - 5, cy - 5), (cx + 5, cy - 5), (cx - 5, cy + 4), (cx + 5, cy + 4)] {
            build.solid(px, py, 0, px + 1, py + 1, self.tall);
        }
        ambush = build.name("ambush");
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, float(cx) + 3.0, float(cy) + 0.5, 1);
        for index in range(self.closets) {
            x = 3 + index * 5;
            if x + 3 >= self.long - 2 {
                break;
            }
            closet = build.room(x, side + 1, 0, x + 3, side + 4, 7);
            build.widen(closet, x, side, 0, x + 3, side + 1, 6);
            build.rising_door(float(x), float(side), 0.0, float(x + 3), float(side + 1), 6.0, {"targetname": ambush, "wait": "-1"});
            build.foe(float(x) + 1.5, float(side) + 2.5, 0, e1m3_foe(dice, self.danger, index == 0), 270.0);
        }
        build.foe(float(cx) - 4.5, 2.5, 0, e1m3_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""A long nave: pews, two aisles of pillars, an altar on a dais and the
way out upon it; as a gate, a key door across the nave."""
node Nave(Prefab) {
    has key: str = "",
        gate_x: int = 20,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nave" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M3;
        self.district = level_district(E1M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(13, 15);
        self.tall = dice.between(18, 22);
        self.gate_x = self.long - 1 - dice.between(8, 9);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
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
        pillars(build, 4, 3, self.long - 2, 4, 0, self.tall, 3, aisle);
        pillars(build, 4, self.wide - 4, self.long - 2, self.wide - 3, 0, self.tall, 3, aisle);
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
        # The altar dais, two lifts up by two steps, and the way out on it.
        dais_x = self.gate_x + 3;
        build.solid(dais_x, 2, 0, self.long - 1, self.wide - 2, 1);
        build.solid(dais_x + 1, 2, 1, self.long - 1, self.wide - 2, 2);
        build.way_out(float(dais_x + 1) + float(self.long - 2 - dais_x) * 0.5, float(middle), 2);
        # Climbing to the altar brings a foe in behind, by a teleporter in a
        # closet sealed under the dais, and wakes the dead in the pews.
        altar = build.touch(float(dais_x), 2.0, 1.0, float(dais_x + 2), float(self.wide - 2), 7.0);
        altar +>:Fires:+> build.summon(dais_x + 2, 2, -8, e1m3_foe(dice, self.danger, True), float(self.gate_x) - 3.0, float(middle) + 0.5, 0, 0.0);
        pews = build.waiting();
        altar +>:Fires:+> pews;
        for index in range(dice.between(2, 3)) {
            build.foe(6.5 + float(index) * 3.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, e1m3_foe(dice, self.danger), 0.0, waits=pews);
        }
        build.foe(3.5, float(middle) + 0.5, 0, "monster_zombie", 0.0, patrol=[[3.5, float(middle) + 0.5], [float(self.gate_x) - 2.5, float(middle) + 0.5]]);
        build.foe(float(self.gate_x) - 2.5, float(middle) + 0.5, 0, e1m3_foe(dice, self.danger, True), 180.0);
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
    if name == "gold_crypt" {
        return GoldCrypt(key=key if key else "key_gold");
    }
    return Nave(key=key);
}
