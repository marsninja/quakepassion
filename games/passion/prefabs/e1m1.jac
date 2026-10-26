"""Prefabs drawn from e1m1, the Slipgate Complex: five stretches of it,
each made again at its scale with its flow, and varied by a seed.

- `Gatehouse`: the start. The run begins on a platform over a hall (a
  hint at its edge, as e1m1's "You can jump down" triggers); the hall's
  far floor is a lift's top, which a button on its wall lowers into a well
  (e1m1's elevator), waking what waits in the hall; the way on leaves from
  the well's foot. A closet behind a wall that opens when shot is a secret.
- `ComputerHall`: a hall of two floors: a raised balcony along one wall
  with stairs up to it, a ledge over an arcade along the other, a catwalk
  across between them, crates on the floor; ways out on both floors (a hub
  a key's branch can leave). A grunt walks a round among the crates; the
  balcony's guard wakes as the player reaches the stairs' top.
- `SlimeWalkways`: a slime pit crossed by islands. Walking up to the edge
  of each shore and island draws the walkway up out of the slime to the
  next (e1m1's bridges, fired by the trigger before each); a button on each
  landing counts, and all of them together open the door out (e1m1's door
  fired by a counter of its three buttons).
- `Slipgate`: the end. A channel across the room, a bridge drawn across it
  by shooting a button on the far wall, and the slipgate on a raised dais
  beyond, its guard woken as the player climbs it.
- `DropShaft`: a high ledge over a deep room: a drop down into it (one
  way), what waits below woken by the landing, and a lift back up to the
  ledge for a body that must return.
- `StorageVault`: the key room. The key on a platform at the vault's far
  end, ridden up to on a lift; taking it opens the closets along the side
  wall below."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires, PORT_WIDE, PORT_HIGH }
import from ..kits { kit_of }
import from .common { stair, key_ambush, lift }

glob E1M1: str = "q1:e1m1";

"""A foe for e1m1's stretches: grunts and dogs, knights as a run goes
deeper, and an ogre now and then where `heavy`."""
def e1m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    kinds = ["monster_army", "monster_dog", "monster_knight", "monster_ogre"];
    weights = [5.0, 2.0, 4.0 * danger, (2.0 * danger) if heavy else 0.0];
    return kinds[dice.weighted(weights)];
}

"""The start: a hall, a button on its wall, and a floor that lowers into a
well to the way on."""
node Gatehouse(Prefab) {
    has hall_long: int = 9,
        hall_wide: int = 9,
        hall_high: int = 10,
        drop: int = 10,
        well: int = 4,
        well_y: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gatehouse";
        self.source = E1M1;
        self.hall_long = dice.between(12, 16);
        self.hall_wide = dice.between(12, 14);
        self.hall_high = dice.between(12, 15);
        self.drop = dice.between(10, 14);
        self.well = dice.between(5, 6);
        self.well_y = 1 + (self.hall_wide - self.well) // 2;
        self.long = 1 + self.hall_long + self.well + 1;
        self.wide = self.hall_wide + 2;
        self.low = -self.drop - 1;
        self.high = self.hall_high + 1;
        self.enter = Port(face=2, along=self.wide // 2, floor=0);
        self.leaves = [Port(face=0, along=self.well_y + 2, floor=-self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        well_x = 1 + self.hall_long;
        hall = build.room(1, 1, 0, well_x + self.well, 1 + self.hall_wide, self.hall_high, variant=dice.below(3));
        shaft = build.room(well_x, self.well_y, -self.drop, well_x + self.well, self.well_y + self.well, 0);
        # No railing round the well: its top is floor until it lowers.
        for y in range(self.well_y - 1, self.well_y + self.well + 1) {
            build.keep(hall, well_x - 1, y, 0);
        }
        for x in range(well_x, well_x + self.well) {
            build.keep(hall, x, self.well_y - 1, 0);
            build.keep(hall, x, self.well_y + self.well, 0);
        }
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # The platform the run begins on, three lifts over the hall, its
        # stair down; a hint at its edge.
        mid = 1 + self.hall_wide // 2;
        build.solid(1, 1, 0, 5, 1 + self.hall_wide, 3);
        stair(build, 7, mid - 1, 0, 2, 3, 3);
        for y in range(mid - 1, mid + 2) {
            build.keep(hall, 4, y, 3);
        }
        build.touch(4.0, 1.0, 3.0, 5.0, float(1 + self.hall_wide), 8.0, True, "You can jump down from here");
        # The well's floor, lowered by the button on the hall's side wall;
        # what waits in the hall wakes as it goes down.
        fields = {"classname": "func_door", "angle": "-2", "speed": "90", "wait": "-1", "lip": "8"};
        build.put_box(fields, float(well_x), float(self.well_y), float(-self.drop), float(well_x + self.well), float(self.well_y + self.well), 0.0, kit.step);
        side = 1 + self.hall_wide;
        press = build.push(float(well_x) - 1.5, float(side), 2.5, 3);
        press +>:Fires:+> build.cue([fields], "floor");
        wake = build.waiting();
        press +>:Fires:+> wake;
        build.start(2.5, float(mid), 3, 0.0);
        build.supply(2.5, 1.5, 3, "item_shells");
        for index in range(dice.between(1, 3)) {
            build.foe(float(well_x) - 2.5 - float(index) * 2.0, float(self.hall_wide) - 1.5 - float(index % 2) * 2.0, 0, e1m1_foe(dice, self.danger), 270.0, waits=wake);
        }
        build.foe(float(well_x) - 1.5, 6.5, 0, e1m1_foe(dice, self.danger), 180.0, patrol=[[float(well_x) - 1.5, 6.5], [9.5, 6.5]]);
        if dice.chance(0.5) {
            build.supply(float(well_x) - 2.5, float(self.hall_wide) - 0.5, 0, "item_health");
        }
        # The secret: a closet in a block beside the platform, behind a
        # stretch of its wall that opens when shot.
        build.solid(6, 1, 0, 14, 5, self.hall_high);
        build.room(9, 1, 0, 11, 3, 4);
        build.secret_door(9.0, 3.0, 0.0, 11.0, 5.0, 4.0, 3);
        build.secret(9.0, 1.0, 0.0, 11.0, 3.0, 3.0);
        build.supply(10.0, 2.0, 0, "item_armor1");
    }
}

"""A hall of two floors: a raised balcony along its far side with stairs up
to it, a ledge over an arcade along its near side, a catwalk across between
them, crates on its floor; ways out on both floors."""
node ComputerHall(Prefab) {
    has deep: int = 5,
        ledge: int = 4,
        balcony: int = 8,
        stairs_x: int = 6,
        walk_x: int = 12,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Computer hall";
        self.source = E1M1;
        self.long = dice.between(24, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.deep = dice.between(5, 6);
        self.ledge = dice.between(4, 5);
        self.balcony = dice.between(7, 9);
        self.stairs_x = dice.between(4, 6);
        self.walk_x = dice.between(self.stairs_x + self.balcony + 3, self.long - 6);
        self.low = -1;
        self.high = self.tall + 1;
        shelf = self.wide - 1 - self.deep;
        ground = [self.ledge + 3, shelf - 6];
        self.enter = Port(face=2, along=float(dice.between(ground[0], max(ground[0], ground[1]))), floor=0);
        self.leaves = [
            Port(face=0, along=float(shelf + self.deep // 2), floor=self.balcony),
            Port(face=1, along=float(dice.between(self.long - 8, self.long - 4)), floor=self.balcony),
            Port(face=3, along=float(dice.between(4, self.walk_x - 3)), floor=self.balcony),
            Port(face=0, along=float(dice.between(ground[0], max(ground[0], ground[1]))), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shelf = self.wide - 1 - self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.balcony);
        # The balcony, raised on solid along the far side.
        build.solid(1, shelf, 0, self.long - 1, self.wide - 1, self.balcony);
        for step in range(self.balcony) {
            build.solid(self.stairs_x + step, shelf - 3, 0, self.stairs_x + step + 1, shelf, step + 1);
        }
        top = self.stairs_x + self.balcony - 1;
        for x in [top - 2, top, top + 1] {
            build.keep(hall, x, shelf, self.balcony);
        }
        # The ledge along the near side: a slab over an arcade of pillars.
        edge_y = 1 + self.ledge;
        build.solid(1, 1, self.balcony - 1, self.long - 1, edge_y, self.balcony);
        for x in range(5, self.long - 3, 5) {
            build.solid(x, edge_y - 1, 0, x + 1, edge_y, self.balcony - 1);
        }
        # The catwalk across, two cells wide, from the ledge to the balcony.
        build.solid(self.walk_x, edge_y, self.balcony - 1, self.walk_x + 2, shelf, self.balcony);
        for x in [self.walk_x, self.walk_x + 1] {
            build.keep(hall, x, edge_y - 1, self.balcony);
            build.keep(hall, x, shelf, self.balcony);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        balcony_y = float(shelf) + float(self.deep) * 0.5;
        # The balcony's guard wakes as the player comes to the stairs' top.
        wake = build.touch(float(top - 1), float(shelf), float(self.balcony), float(top + 2), float(self.wide - 1), float(self.balcony + 6));
        guard = build.waiting();
        wake +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5 - float(index) * 5.0, balcony_y, self.balcony, e1m1_foe(dice, self.danger), 270.0, waits=guard);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.5 - float(index) * 6.0, float(edge_y) - 1.5, self.balcony, e1m1_foe(dice, self.danger), 90.0);
        }
        # What stands on the floor, then crates clear of it, of the way in,
        # the stairs and their foot, the catwalk's shadow and each other.
        way_in = int(self.enter.along);
        kept: list[list[int]] = [[0, way_in - 3, 5, way_in + 3], [self.stairs_x - 3, shelf - 5, top + 2, shelf], [self.walk_x - 1, edge_y, self.walk_x + 3, shelf]];
        # Nor before a way out on the floor.
        for port in self.taken {
            if port.floor == 0 and port.face == 0 {
                kept.append([self.long - 6, int(port.along) - 3, self.long, int(port.along) + 3]);
            }
        }
        for index in range(dice.between(3, 5)) {
            x = self.long // 3 + index * 3;
            y = edge_y + 1 + (index % 2) * 3;
            build.foe(float(x) + 0.5, float(y) + 0.5, 0, e1m1_foe(dice, self.danger, True), 180.0);
            kept.append([x, y, x + 1, y + 1]);
        }
        # A grunt walking his round along the floor under the ledge.
        build.foe(4.5, float(edge_y) + 0.5, 0, "monster_army", 0.0, patrol=[[4.5, float(edge_y) + 0.5], [float(self.long) - 3.5, float(edge_y) + 0.5]]);
        kept.append([3, edge_y, self.long - 3, edge_y + 1]);
        build.supply(float(self.long) - 2.5, float(edge_y) + 1.5, 0, "item_health");
        kept.append([self.long - 3, edge_y + 1, self.long - 2, edge_y + 2]);
        build.supply(2.5, float(shelf) - 1.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, 2.5, self.balcony, "item_health");
        crates = dice.between(4, 7);
        tries = 0;
        while crates > 0 and tries < 50 {
            tries += 1;
            x = dice.between(4, self.long - 4);
            y = dice.between(edge_y, shelf - 2);
            box = [x, y, x + 2, y + 2];
            clear = True;
            for other in kept {
                if box[0] < other[2] + 1 and other[0] < box[2] + 1 and box[1] < other[3] + 1 and other[1] < box[3] + 1 {
                    clear = False;
                }
            }
            if not clear {
                continue;
            }
            kept.append(box);
            build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 4));
            crates -= 1;
        }
        if dice.chance(0.5) {
            build.supply(float(self.stairs_x) - 1.5, balcony_y, self.balcony, "weapon_supershotgun");
        }
    }
}

"""A slime pit crossed by islands; a button on each shore and island draws
up the bridge to the next, and the buttons together open the door out."""
node SlimeWalkways(Prefab) {
    has shore: int = 4,
        far_shore: int = 3,
        span: int = 8,
        # Islands are short along the way across (three cells) and wide
        # across it, so a landing stays near both its bridges.
        island_long: int = 3,
        island: int = 6,
        islands: int = 2,
        walk: int = 8,
        headroom: int = 12,
        lanes: list[int] = [],
        island_y: list[int] = [];

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime walkways";
        self.source = E1M1;
        self.islands = dice.between(2, 3);
        self.span = dice.between(8, 9);
        self.wide = dice.between(18, 22);
        self.headroom = dice.between(14, 16);
        self.long = 1 + self.shore + self.islands * (self.span + self.island_long) + self.span + self.far_shore + 1;
        self.low = -1;
        self.high = self.walk + self.headroom + 1;
        # Each island lies where its bridges meet the last landing three
        # cells wide at least; each lane is a bridge's three cells.
        self.island_y = [];
        self.lanes = [];
        before_low = 1;
        before_high = self.wide - 1;
        for index in range(self.islands + 1) {
            if index < self.islands {
                low = max(2, before_low - self.island + 3);
                high = min(self.wide - 2 - self.island, before_high - 3);
                y = dice.between(low, max(low, high));
                self.island_y.append(y);
                lane_low = max(before_low, y);
                lane_high = min(before_high, y + self.island) - 3;
                self.lanes.append(dice.between(lane_low, max(lane_low, lane_high)));
                before_low = y;
                before_high = y + self.island;
            } else {
                self.lanes.append(dice.between(before_low, before_high - 3));
            }
        }
        self.enter = Port(face=2, along=dice.between(3, self.wide - 3), floor=self.walk);
        self.leaves = [Port(face=0, along=dice.between(3, self.wide - 3), floor=self.walk)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        upper = build.room(1, 1, self.walk, self.long - 1, self.wide - 1, self.walk + self.headroom, variant=dice.below(4));
        build.room(1 + self.shore, 1, 0, self.long - 1 - self.far_shore, self.wide - 1, self.walk, flood=6, deadly=True);
        build.doorway(upper, self.enter);
        # Steps up out of the slime to the near shore, along the side wall
        # the first bridge keeps clear of (none to the islands or the far
        # shore, which would go round the bridges).
        low_side = self.lanes[0] >= 4;
        for step in range(self.walk) {
            y0 = 1 if low_side else self.wide - 3;
            build.solid(1 + self.shore + step, y0, 0, 2 + self.shore + step, y0 + 2, self.walk - step);
        }
        # The landings in order: the near shore, the islands, the far shore,
        # each [x0, x1, y0, y1].
        landings: list[list[int]] = [[1, 1 + self.shore, 1, self.wide - 1]];
        for index in range(self.islands) {
            x = 1 + self.shore + self.span + index * (self.span + self.island_long);
            y = self.island_y[index];
            build.solid(x, y, 0, x + self.island_long, y + self.island, self.walk);
            landings.append([x, x + self.island_long, y, y + self.island]);
        }
        landings.append([self.long - 1 - self.far_shore, self.long - 1, 1, self.wide - 1]);
        buttons = len(landings) - 1;
        count = build.tally(buttons, "The way on is open");
        build.touch(1.0, 1.0, float(self.walk), float(1 + self.shore), float(self.wide - 1), float(self.walk + 6), True, "You must press the buttons to open the door");
        for index in range(buttons) {
            landing = landings[index];
            onward = landings[index + 1];
            lane = self.lanes[index];
            # The walkway on rises out of the slime as the player walks up to
            # the landing's edge.
            near = build.touch(float(landing[1] - 2), float(lane), float(self.walk), float(landing[1]), float(lane + 3), float(self.walk + 6));
            near +>:Fires:+> build.drawn(float(landing[1]), float(lane), float(onward[0]), float(lane + 3), self.walk, self.walk + 1);
            for across in range(3) {
                build.keep(upper, landing[1] - 1, lane + across, self.walk);
                build.keep(upper, onward[0], lane + across, self.walk);
            }
            # A column beside the lane on this landing, its button facing
            # back the way the player came: each counts toward the door.
            column_x = landing[1] - 2;
            column_y = lane - 1 if lane - 1 >= landing[2] else lane + 3;
            build.solid(column_x, column_y, self.walk, column_x + 1, column_y + 1, self.walk + 4);
            build.push(float(column_x), float(column_y) + 0.5, float(self.walk) + 1.2, 2) +>:Fires:+> count;
            if index > 0 {
                build.foe(float(landing[0]) + 1.5, float(lane) + 1.5, self.walk, e1m1_foe(dice, self.danger), 180.0);
            }
        }
        for port in self.taken {
            build.doorway(upper, port);
            low = port.along - float(port.wide) * 0.5;
            high = port.along + float(port.wide) * 0.5;
            fields = {"wait": "-1"};
            count +>:Fires:+> build.cue([fields], "door");
            if port.face == 0 {
                build.rising_door(float(self.long - 1), low, float(self.walk), float(self.long), high, float(self.walk + port.high), fields);
            } elif port.face == 1 {
                build.rising_door(low, float(self.wide - 1), float(self.walk), high, float(self.wide), float(self.walk + port.high), fields);
            } else {
                build.rising_door(low, 0.0, float(self.walk), high, 1.0, float(self.walk + port.high), fields);
            }
        }
        far = landings[-1];
        for index in range(dice.between(1, 2)) {
            build.foe(float(far[0]) + 1.5, float(far[2]) + 2.5 + float(index) * 4.0, self.walk, e1m1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(landings[1][0]) + 0.5, float(self.lanes[1]) + 1.5, self.walk, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, self.walk, "item_spikes");
        if dice.chance(0.4) {
            build.supply(float(landings[-2][0]) + 0.5, float(self.lanes[-1]) + 1.5, self.walk, "weapon_nailgun");
        }
    }
}

"""The end: a channel across the room, a bridge drawn over it by shooting
the button on the far wall, and the slipgate on its dais beyond."""
node Slipgate(Prefab) {
    has near: int = 4,
        channel: int = 5,
        dais: int = 7,
        tall: int = 13,
        deadly: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slipgate";
        self.source = E1M1;
        self.near = dice.between(6, 8);
        self.channel = dice.between(5, 6);
        self.dais = dice.between(9, 11);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(16, 18);
        self.deadly = dice.chance(0.6);
        self.long = 1 + self.near + self.channel + self.dais + 1;
        self.low = -6;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=self.wide // 2, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        cut = 1 + self.near;
        build.room(cut, 1, -5, cut + self.channel, self.wide - 1, 0, flood=4, deadly=self.deadly);
        build.doorway(room, self.enter);
        # Steps up out of the channel to the near side, along a side wall.
        for step in range(5) {
            build.solid(cut + step, 1, -5, cut + step + 1, 3, -step);
        }
        lane = self.wide // 2 - 1;
        bridge = build.name("bridge");
        build.bridge(float(cut), float(lane), float(cut + self.channel), float(lane + 3), 0, 6, bridge);
        for across in range(3) {
            build.keep(room, cut - 1, lane + across, 0);
            build.keep(room, cut + self.channel, lane + across, 0);
        }
        # The button high on the far wall, off to one side of the gate.
        build.button(float(self.long - 1), float(self.wide) - 2.5, 7.0, 2, bridge, True);
        # The dais, a lift up and a lift more, a cell of floor before each.
        land = cut + self.channel;
        build.solid(land + 1, 1, 0, self.long - 1, self.wide - 1, 1);
        build.solid(land + 3, 1, 1, self.long - 1, self.wide - 1, 2);
        # The slipgate: a pad between two pillars under a lintel.
        gate_x = land + 3 + (self.long - 1 - land - 3) // 2 + 1;
        gate_y = self.wide // 2;
        build.solid(gate_x, gate_y - 2, 2, gate_x + 1, gate_y - 1, 9);
        build.solid(gate_x, gate_y + 1, 2, gate_x + 1, gate_y + 2, 9);
        build.solid(gate_x, gate_y - 2, 9, gate_x + 1, gate_y + 2, 10);
        build.way_out(float(gate_x), float(gate_y), 2);
        build.touch(float(gate_x - 3), float(gate_y - 3), 2.0, float(gate_x), float(gate_y + 3), 8.0, False, "Walk into the slipgate to exit");
        # The gate's guard wakes as the player climbs onto the dais.
        climb = build.touch(float(land), 1.0, 0.0, float(land + 2), float(self.wide - 1), 6.0);
        guard = build.waiting();
        climb +>:Fires:+> guard;
        for index in range(dice.between(3, 5)) {
            build.foe(float(land + 4) + float(index % 2) * 2.0, 2.5 + float(index) * 2.5, 2, e1m1_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        if dice.chance(0.5) {
            build.supply(2.5, float(self.wide) - 2.5, 0, "item_armor1");
        }
    }
}

"""A high ledge over a deep room: a drop down into it, and a lift back up
for a body that must return."""
node DropShaft(Prefab) {
    has ledge: int = 4,
        top: int = 13,
        tall: int = 24,
        lift_y: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drop shaft";
        self.source = E1M1;
        self.long = dice.between(16, 20);
        self.wide = dice.between(13, 16);
        self.top = dice.between(12, 15);
        self.tall = self.top + dice.between(9, 12);
        self.ledge = dice.between(4, 5);
        self.lift_y = dice.between(2, self.wide - 6);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=self.top);
        self.leaves = [
            Port(face=0, along=float(dice.between(3, self.wide - 3)), floor=0),
            Port(face=1, along=float(dice.between(self.ledge + 5, self.long - 4)), floor=0),
            Port(face=3, along=float(dice.between(self.ledge + 5, self.long - 4)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(room, self.top);
        edge_x = 1 + self.ledge;
        build.solid(1, 1, 0, edge_x, self.wide - 1, self.top);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # The lift beside the ledge: it waits at the floor below and rises
        # to the ledge when stepped on.
        build.put_box({"classname": "func_plat", "height": str(self.top * 16), "speed": "180"}, float(edge_x), float(self.lift_y), float(self.top) - 0.5, float(edge_x + 2), float(self.lift_y + 3), float(self.top), kit.step);
        for y in range(self.lift_y - 1, self.lift_y + 4) {
            build.keep(room, edge_x - 1, y, self.top);
            build.keep(room, edge_x, y, 0);
        }
        # A stretch of the ledge's edge with no railing, to drop from.
        drop_y = self.wide - 5 if self.lift_y < self.wide // 2 else 3;
        for y in range(drop_y - 1, drop_y + 3) {
            build.keep(room, edge_x - 1, y, self.top);
        }
        # Crates on the floor below, and what waits there.
        for index in range(dice.between(3, 5)) {
            x = edge_x + 4 + dice.below(max(1, self.long - edge_x - 8));
            y = 2 + dice.below(max(1, self.wide - 5));
            build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 4));
        }
        # What waits below wakes as a body lands from the ledge.
        landed = build.touch(float(edge_x), float(drop_y - 1), 0.0, float(edge_x + 4), float(drop_y + 3), 6.0);
        below = build.waiting();
        landed +>:Fires:+> below;
        for index in range(dice.between(3, 5)) {
            build.foe(float(self.long) - 2.5 - float(index % 2) * 3.0, 2.5 + float(index) * 2.5, 0, e1m1_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.supply(2.5, 2.5, self.top, "item_spikes");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""The key room: a vault, the key on a platform at its far end ridden up to
on a lift, the closets along its side wall opening when the key is taken."""
node StorageVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        shelf: int = 5,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Storage vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M1;
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.shelf = dice.between(5, 6);
        self.tall = self.shelf + dice.between(10, 12);
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
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(4));
        build.level(vault, self.shelf);
        build.doorway(vault, self.enter);
        ledge_x = self.long - 7;
        build.solid(ledge_x, 1, 0, self.long - 1, side, self.shelf);
        lift(build, ledge_x - 3, 2, ledge_x, 5, 0, self.shelf);
        for y in range(1, 6) {
            build.keep(vault, ledge_x, y, self.shelf);
            build.keep(vault, ledge_x - 1, y, 0);
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(side // 2) + 0.5, self.shelf, side, 0, [3, ledge_x - 6], [e1m1_foe(dice, self.danger, True), e1m1_foe(dice, self.danger)]);
        # Crates on the floor below, clear of the way in, the lift and the
        # closets' doors.
        for index in range(dice.between(2, 4)) {
            x = 6 + index * 3;
            y = 7 + (index % 2) * 3;
            if x + 2 < ledge_x - 4 {
                build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 3));
            }
        }
        build.foe(4.5, 3.5, 0, e1m1_foe(dice, self.danger), 0.0, patrol=[[4.5, 3.5], [float(ledge_x) - 4.5, 3.5]]);
        build.foe(float(self.long) - 3.5, 3.5, self.shelf, e1m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""e1m1's stretches: [name, role] (start, flow, hub, keyroom, end, gate)."""
glob E1M1_STRETCHES: list[list[str]] = [["gatehouse", "start"], ["hall", "flow"], ["hall", "hub"], ["walkways", "flow"], ["drop", "flow"], ["vault", "keyroom"], ["slipgate", "end"]];

"""One of e1m1's stretches by its name."""
def make_e1m1(name: str, key: str) -> Prefab {
    if name == "gatehouse" {
        return Gatehouse();
    }
    if name == "hall" {
        return ComputerHall();
    }
    if name == "walkways" {
        return SlimeWalkways();
    }
    if name == "drop" {
        return DropShaft();
    }
    if name == "vault" {
        return StorageVault(key=key if key else "key_silver");
    }
    return Slipgate();
}
