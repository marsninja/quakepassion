"""Prefabs drawn from e1m1, the Slipgate Complex: seven stretches of it,
each made again at its scale with its flow, and varied by a seed.

- `Gatehouse`: the start. The run begins on a platform over a hall (a
  hint at its edge, as e1m1's "You can jump down" triggers); the hall's
  far floor is a lift's top, which a button on its wall lowers into a well
  (e1m1's elevator), waking what waits in the hall; the way on leaves from
  the well's foot. A closet behind a wall that opens when shot is a secret.
- `ServiceWays`: narrow ways: a corridor climbing by steps past closets, a
  stair hall up to a gallery over a slime pit, a way down into the pit and
  a footbridge over its channel to the button that opens the ways on.
- `ComputerHall`: the hub: a hall of many levels: a raised balcony along one
  wall with stairs up to it and a control booth at its end, a lower ledge
  over an arcade along the other, a catwalk across between them, raised
  aisles under both, crates on the floor; ways out on all of them. A grunt
  walks a round among the crates; the balcony's guard wakes as the player
  reaches the stairs' top.
- `SlimeWalkways`: a slime pit crossed by islands, each a step higher than
  the last, the pit's bed stepping with them. Walking up to the edge of
  each shore and island draws the walkway up out of the slime to the next
  (e1m1's bridges, fired by the trigger before each); a button on each
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
import from .common { stair, key_ambush, lift, apart }
import from .e1m1_parts { deck, stash, bars }
import from .e1m2_parts { keep_box }

glob E1M1: str = "q1:e1m1";

"""A foe for e1m1's stretches: grunts and dogs, knights as a run goes
deeper, and an ogre now and then where `heavy`."""
def e1m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    kinds = ["monster_army", "monster_dog", "monster_knight", "monster_ogre"];
    weights = [5.0, 2.0, 4.0 * danger, (2.0 * danger) if heavy else 0.0];
    return kinds[dice.weighted(weights)];
}

"""What a secret of e1m1's holds: armor, the quad, a better gun."""
def e1m1_reward(dice: Stream) -> str {
    return ["item_armor2", "item_artifact_super_damage", "weapon_supernailgun", "item_armor2"][dice.below(4)];
}

"""The start: a deck high at one end of a hall, a stair down from it, a
button on the hall's wall and a floor that lowers into a well to the way
on. By the dice the hall's floor is whole, a closet in its wall opening
to a shot (a secret), or a moat of water across it under a footbridge, a
secret alcove down at its bottom."""
node Gatehouse(Prefab) {
    has hall_long: int = 9,
        hall_wide: int = 9,
        hall_high: int = 10,
        drop: int = 10,
        well: int = 4,
        well_y: int = 3,
        deck_top: int = 7,
        deck_long: int = 4,
        moat: bool = False,
        moat_x: int = 0,
        moat_long: int = 5,
        stair_low: bool = True,
        button_low: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gatehouse";
        self.source = E1M1;
        self.hall_wide = dice.between(12, 14);
        self.deck_top = dice.between(6, 8);
        self.deck_long = dice.between(4, 5);
        foot = 1 + self.deck_long + self.deck_top;
        self.moat = dice.chance(0.7);
        if self.moat {
            self.moat_long = dice.between(5, 7);
            self.moat_x = foot + 3;
            self.hall_long = self.moat_x + self.moat_long + dice.between(5, 7) - 1;
        } else {
            self.hall_long = foot + dice.between(8, 10) - 1;
        }
        self.hall_high = self.deck_top + dice.between(8, 10);
        self.drop = dice.between(10, 14);
        self.well = dice.between(5, 6);
        self.well_y = dice.between(2, self.hall_wide - self.well);
        self.stair_low = dice.chance(0.5);
        self.button_low = dice.chance(0.5);
        self.long = 1 + self.hall_long + self.well + 1;
        self.wide = self.hall_wide + 2;
        self.low = -self.drop - 1;
        self.high = self.hall_high + 1;
        self.enter = Port(face=2, along=self.wide // 2, floor=self.deck_top);
        self.leaves = [Port(face=0, along=float(self.well_y) + float(self.well) * 0.5, floor=-self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        well_x = 1 + self.hall_long;
        side = 1 + self.hall_wide;
        mid = 1 + self.hall_wide // 2;
        hall = build.room(1, 1, 0, well_x + self.well, side, self.hall_high, variant=dice.below(3));
        build.level(hall, self.deck_top);
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
        # The deck the run begins on, high over the hall's floor (which runs
        # on under it), and its stair down along a side wall; a hint at its
        # edge, where no railing stands.
        rim = self.deck_long;
        deck(build, 1, 1, 1 + rim, side, self.deck_top);
        stair_y = 1 if self.stair_low else side - 3;
        stair(build, rim + self.deck_top, stair_y, 0, 2, self.deck_top, 3);
        for y in range(stair_y, stair_y + 3) {
            build.keep(hall, rim, y, self.deck_top);
        }
        for y in range(mid - 1, mid + 2) {
            build.keep(hall, rim, y, self.deck_top);
        }
        build.touch(float(rim), float(mid - 1), float(self.deck_top), float(rim + 1), float(mid + 2), float(self.deck_top + 5), True, "You can jump down from here");
        build.start(2.5, float(mid) + 0.5, self.deck_top, 0.0);
        build.supply(2.5, float(stair_y) + 1.5, self.deck_top, "item_shells");
        # Under the deck, a box of shells and what keeps watch there.
        under_y = side - 2.5 if self.stair_low else 2.5;
        build.supply(2.5, under_y, 0, "item_spikes");
        foot = 1 + rim + self.deck_top;
        if self.moat {
            # The moat across the hall, steps out of it on both sides, the
            # footbridge over it, and down at its far side an alcove under
            # the water with a reward: a secret.
            x0 = self.moat_x;
            x1 = self.moat_x + self.moat_long;
            water = build.pool(x0, 1, -7, x1, side, 0, 2, False, True, True);
            build.solid(x0, mid - 1, -1, x1, mid + 2, 0);
            for across in range(3) {
                build.keep(hall, x0 - 1, mid - 1 + across, 0);
                build.keep(hall, x1, mid - 1 + across, 0);
            }
            nook_y = 2 if dice.chance(0.5) else side - 3;
            build.widen(water, x1, nook_y, -7, x1 + 2, nook_y + 2, -4);
            for x in range(x1, x1 + 2) {
                for y in range(nook_y, nook_y + 2) {
                    for z in range(-7, -4) {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
            build.secret(float(x1), float(nook_y), -7.0, float(x1 + 2), float(nook_y + 2), -5.0);
            build.supply(float(x1) + 1.0, float(nook_y) + 1.0, -7, e1m1_reward(dice));
        } else {
            # A closet in the hall's wall across from the button, behind a
            # stretch of wall that opens when shot: a secret.
            stash(build, foot + 1, side - 4 if self.button_low else 1, 0, 1 if not self.button_low else 3, e1m1_reward(dice));
        }
        # The well's floor, lowered by the button on the hall's side wall;
        # what waits in the hall wakes as it goes down.
        fields = {"classname": "func_door", "angle": "-2", "speed": "90", "wait": "-1", "lip": "8"};
        build.put_box(fields, float(well_x), float(self.well_y), float(-self.drop), float(well_x + self.well), float(self.well_y + self.well), 0.0, kit.step);
        if self.button_low {
            press = build.push(float(well_x) - 1.5, 1.0, 2.5, 1);
        } else {
            press = build.push(float(well_x) - 1.5, float(side), 2.5, 3);
        }
        press +>:Fires:+> build.cue([fields], "floor");
        wake = build.waiting();
        press +>:Fires:+> wake;
        for index in range(dice.between(1, 3)) {
            build.foe(float(well_x) - 2.5, 2.5 + float(index) * 4.0, 0, e1m1_foe(dice, self.danger), 180.0, waits=wake);
        }
        build.foe(float(well_x) - 1.5, float(mid) + 0.5, 0, e1m1_foe(dice, self.danger), 180.0, patrol=[[float(well_x) - 1.5, float(mid) + 0.5], [float(foot) + 1.5, float(mid) + 0.5]]);
        if dice.chance(0.5) {
            build.supply(float(well_x) - 2.5, float(mid) + 2.5, 0, "item_health");
        }
    }
}

"""A hall of many levels: a raised balcony along its far side, a control
booth a step up behind a partition at the balcony's end, a ledge a step
lower over an arcade along its near side, a catwalk (or two) across between
them, aisles a step up under both, crates on its floor; ways out on all of
them, each over a sill. By the dice the balcony stands on solid or runs
over an aisle of computer banks, it is climbed by a stair or ridden up to
on a lift, and a closet at the ledge's end opens to a shot (a secret)."""
node ComputerHall(Prefab) {
    has deep: int = 5,
        ledge: int = 4,
        balcony: int = 8,
        stairs_x: int = 6,
        walk_x: int = 12,
        tall: int = 20,
        lifted: bool = False,
        hollow: bool = False,
        second_x: int = 0,
        stash_end: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Computer hall";
        self.source = E1M1;
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.deep = dice.between(5, 6);
        self.ledge = dice.between(4, 5);
        self.balcony = dice.between(7, 9);
        self.stairs_x = dice.between(4, 5);
        self.lifted = dice.chance(0.4);
        self.hollow = dice.chance(0.55);
        low_walk = self.stairs_x + self.balcony + 3;
        self.walk_x = dice.between(low_walk, max(low_walk, self.long - 11));
        self.second_x = self.walk_x + 6 if dice.chance(0.45) and self.walk_x + 9 <= self.long - 8 else 0;
        self.stash_end = dice.chance(0.6) and self.walk_x + 3 <= self.long - 6 and (self.second_x == 0 or self.second_x + 3 <= self.long - 6);
        self.low = -1;
        self.high = self.tall + 1;
        shelf = self.wide - 1 - self.deep;
        ground = [self.ledge + 3, shelf - 6];
        self.enter = Port(face=2, along=float(dice.between(ground[0], max(ground[0], ground[1]))), floor=1);
        self.leaves = [
            Port(face=0, along=float(shelf + self.deep // 2), floor=self.balcony + 1),
            Port(face=1, along=float(dice.between(self.long - 5, self.long - 3)), floor=self.balcony + 1),
            Port(face=3, along=float(dice.between(4, self.walk_x - 3)), floor=self.balcony - 1),
            Port(face=0, along=float(dice.between(ground[0], max(ground[0], ground[1]))), floor=1)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shelf = self.wide - 1 - self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.balcony);
        build.level(hall, self.balcony - 1);
        top = self.stairs_x + self.balcony - 1;
        # The balcony along the far side: on solid, or a deck over a lower
        # aisle, pillars under its edge, computer banks along the wall.
        if self.hollow {
            deck(build, 1, shelf, self.long - 1, self.wide - 1, self.balcony);
            build.solid(1, shelf, 0, self.long - 1, self.wide - 1, 1);
            for x in range(4, self.long - 3, 5) {
                if x < top - 3 or x > top + 2 {
                    build.solid(x, shelf, 0, x + 1, shelf + 1, self.balcony - 1);
                }
            }
            for x in range(3, self.long - 4, 4) {
                build.solid(x, self.wide - 2, 1, x + 2, self.wide - 1, 3);
            }
        } else {
            build.solid(1, shelf, 0, self.long - 1, self.wide - 1, self.balcony);
        }
        if self.lifted {
            lift(build, top - 2, shelf - 3, top + 1, shelf, 0, self.balcony);
        } else {
            for step in range(self.balcony) {
                build.solid(self.stairs_x + step, shelf - 3, 0, self.stairs_x + step + 1, shelf, step + 1);
            }
        }
        for x in [top - 2, top - 1, top, top + 1] {
            build.keep(hall, x, shelf, self.balcony);
        }
        # The control booth at the balcony's end: a partition across it, a
        # gap in that, and the booth's floor a step up.
        booth = self.long - 8;
        build.solid(booth, shelf, self.balcony + 7, booth + 1, self.wide - 1, self.tall);
        build.solid(booth, shelf, self.balcony, booth + 1, shelf + 1, self.balcony + 7);
        build.solid(booth, shelf + 4, self.balcony, booth + 1, self.wide - 1, self.balcony + 7);
        build.solid(booth + 1, shelf, self.balcony, self.long - 1, self.wide - 1, self.balcony + 1);
        # The ledge along the near side, a step lower: a slab over an arcade
        # of pillars, an aisle a step up under it.
        edge_y = 1 + self.ledge;
        ledge_z = self.balcony - 1;
        build.solid(1, 1, ledge_z - 1, self.long - 1, edge_y, ledge_z);
        build.solid(1, 1, 0, self.long - 1, edge_y, 1);
        for x in range(5, self.long - 3, 5) {
            build.solid(x, edge_y - 1, 1, x + 1, edge_y, ledge_z - 1);
        }
        # The catwalks across, three cells wide, from the ledge to the balcony.
        walks = [self.walk_x] if self.second_x == 0 else [self.walk_x, self.second_x];
        for walk in walks {
            deck(build, walk, edge_y, walk + 3, shelf, self.balcony);
            for x in range(walk, walk + 3) {
                build.keep(hall, x, edge_y - 1, ledge_z);
                build.keep(hall, x, shelf, self.balcony);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        balcony_y = float(shelf) + float(self.deep) * 0.5;
        # The balcony's guard wakes as the player comes to the stairs' top.
        wake = build.touch(float(top - 2), float(shelf), float(self.balcony), float(top + 2), float(self.wide - 1), float(self.balcony + 6));
        guard = build.waiting();
        wake +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 10.5 - float(index) * 4.0, balcony_y, self.balcony, e1m1_foe(dice, self.danger), 270.0, waits=guard);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.walk_x) - 2.5 - float(index) * 4.0, float(edge_y) - 1.5, ledge_z, e1m1_foe(dice, self.danger), 90.0);
        }
        # The closet at the ledge's far end, behind a wall that opens when
        # shot.
        if self.stash_end {
            stash(build, self.long - 5, 1, ledge_z, 2, e1m1_reward(dice));
        }
        # Under a hollow balcony, a grunt among the banks.
        if self.hollow {
            build.foe(float(self.long) - 4.5, float(self.wide) - 3.5, 1, e1m1_foe(dice, self.danger), 180.0);
            build.supply(3.5, float(self.wide) - 3.5, 1, "item_shells");
        }
        # What stands on the floor, then crates clear of it, of the way in,
        # the stairs and their foot, the catwalks' shadows and each other.
        way_in = int(self.enter.along);
        kept: list[list[int]] = [[0, way_in - 3, 5, way_in + 3], [self.stairs_x - 3, shelf - 5, top + 2, shelf]];
        for walk in walks {
            kept.append([walk - 1, edge_y, walk + 4, shelf]);
        }
        # Nor before a way out on the floor.
        for port in self.taken {
            if port.floor <= 1 and port.face == 0 {
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
        build.supply(float(self.walk_x) - 1.5, 2.5, ledge_z, "item_health");
        crates = dice.between(4, 7);
        tries = 0;
        while crates > 0 and tries < 50 {
            tries += 1;
            x = dice.between(4, self.long - 4);
            y = dice.between(edge_y, shelf - 2);
            box = [x, y, x + 2, y + 2];
            if not apart(box, kept) {
                continue;
            }
            kept.append(box);
            build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 4));
            crates -= 1;
        }
        if dice.chance(0.5) {
            build.supply(float(self.long) - 3.5, balcony_y, self.balcony + 1, "weapon_supershotgun");
        }
    }
}

"""Narrow ways: a corridor climbing by steps past closets, a stair hall up to
a gallery over a slime pit; a stair down into the pit and a footbridge (or a
long stone a leap from each bank) over its channel to the button that opens
the ways on from the gallery."""
node ServiceWays(Prefab) {
    has rise_to: int = 6,
        stones: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Service ways";
        self.source = E1M1;
        self.long = dice.between(28, 32);
        self.wide = dice.between(26, 28);
        self.rise_to = dice.between(7, 8);
        self.stones = dice.chance(0.5);
        self.low = -6;
        self.high = self.rise_to + 13;
        self.enter = Port(face=2, along=7.0, floor=1);
        self.leaves = [
            Port(face=1, along=float(dice.between(9, self.long - 12)), floor=self.rise_to + 1),
            Port(face=0, along=float(self.wide - 3), floor=self.rise_to + 1)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        top = self.rise_to;
        # The corridor along the near side, a step up every few cells, its
        # closets off it each a step up again.
        corridor = build.room(1, 5, 0, self.long - 1, 9, 10, variant=dice.below(3));
        steps_at = [7, 14, 21];
        for (index, x) in enumerate(steps_at) {
            build.solid(x, 5, index, self.long - 1, 9, index + 1);
        }
        end_z = len(steps_at);
        build.doorway(corridor, self.enter);
        for (index, x) in enumerate([2, 9, 16]) {
            closet = build.room(x, 1, index + 1, x + 4, 4, index + 9);
            build.widen(closet, x, 4, index + 1, x + 3, 5, index + 8);
        }
        build.supply(4.0, 2.5, 1, "item_shells");
        build.foe(11.0, 2.5, 2, e1m1_foe(dice, self.danger), 90.0);
        build.supply(18.0, 2.5, 3, "item_health");
        # The stair hall at the corridor's end, up to the gallery.
        hall_x = self.long - 6;
        stair_hall = build.room(hall_x, 9, end_z, self.long - 2, self.wide - 6, top + 12, variant=dice.below(3));
        climb = top - end_z;
        stair(build, hall_x, 10, end_z, 1, climb, 4);
        # The gallery along the far side, the pit open under its edge.
        gallery = build.room(4, self.wide - 6, top, self.long - 1, self.wide - 1, top + 11, variant=dice.below(3));
        build.level(gallery, top);
        build.widen(gallery, hall_x, self.wide - 7, top, self.long - 2, self.wide - 6, top + 8);
        build.solid(hall_x, 10 + climb, end_z, self.long - 2, self.wide - 6, top);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        # The pit under the gallery: a floor of stone, a channel of slime
        # across it, a stair down from the gallery along its near end.
        pit = build.room(5, 10, 0, self.long - 7, self.wide - 6, top + 11, variant=dice.below(3));
        build.level(pit, 0);
        channel_x0 = 11;
        channel_x1 = self.long - 12;
        build.pool(channel_x0, 10, -4, channel_x1, self.wide - 6, 0, 3, False, True);
        down_y = self.wide - 6 - top;
        stair(build, 5, down_y, 0, 1, top, 3);
        for x in range(5, 8) {
            build.keep(gallery, x, self.wide - 6, top);
            build.keep(pit, x, self.wide - 7, top);
        }
        lane = (10 + self.wide - 6) // 2 - 1;
        if self.stones {
            build.solid(channel_x0 + 1, lane, -4, channel_x1 - 1, lane + 3, 0);
            keep_box(build, pit, channel_x0 + 1, lane, channel_x1 - 1, lane + 3, 0);
        } else {
            build.solid(channel_x0, lane, -1, channel_x1, lane + 3, 0);
        }
        for across in range(3) {
            build.keep(pit, channel_x0 - 1, lane + across, 0);
            build.keep(pit, channel_x1, lane + across, 0);
        }
        # The button on the pit's far wall opens the ways on from the gallery.
        press = build.push(float(self.long - 7), float(lane) + 1.5, 1.2, 2);
        bars(build, press, self.taken, self.long, self.wide);
        build.touch(float(self.long - 4), float(self.wide - 5), float(top), float(self.long - 2), float(self.wide - 2), float(top + 6), True, "This door is opened from below");
        # What keeps the far bank wakes as the button is pressed; a grunt walks
        # the corridor and another the gallery.
        far_bank = build.waiting();
        press +>:Fires:+> far_bank;
        build.foe(float(hall_x) - 2.5, float(self.wide) - 3.5, top, e1m1_foe(dice, self.danger, True), 270.0, waits=far_bank);
        build.foe(3.5, 7.0, 0, "monster_army", 0.0, patrol=[[3.5, 7.0], [float(self.long) - 3.5, 7.0]]);
        build.foe(float(self.long) - 9.5, float(self.wide) - 3.5, top, e1m1_foe(dice, self.danger), 180.0);
        build.foe(float(channel_x1) + 2.5, float(self.wide) - 9.5, 0, e1m1_foe(dice, self.danger), 180.0);
        build.supply(8.5, 12.5, 0, "item_spikes");
        build.supply(float(channel_x1) + 2.5, 12.5, 0, "item_health");
    }
}

"""A slime pit crossed by islands, each a step higher; walking to each landing's edge draws up
the bridge to the next, a button on each counts, and the buttons together
open the door out. By the dice the way out is on the far shore, or high
on a gallery over it, up a stair from the far shore."""
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
        island_y: list[int] = [],
        gallery: bool = False,
        climb_y: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime walkways";
        self.source = E1M1;
        self.islands = dice.between(2, 3);
        self.span = dice.between(8, 9);
        self.wide = dice.between(18, 22);
        self.gallery = dice.chance(0.5);
        self.far_shore = 6 if self.gallery else 3;
        self.headroom = dice.between(16, 18) if self.gallery else dice.between(14, 16);
        self.long = 1 + self.shore + self.islands * (self.span + self.island_long) + self.span + self.far_shore + 1;
        self.low = -1;
        self.high = self.walk + self.headroom + self.islands + 2;
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
        # The stair up to the gallery climbs the far shore beside the last
        # bridge's landing, never on it.
        self.climb_y = 2 if self.lanes[-1] >= 9 else self.wide - 8;
        self.enter = Port(face=2, along=dice.between(3, self.wide - 3), floor=self.walk);
        self.leaves = [Port(face=0, along=dice.between(3, self.wide - 3), floor=self.walk + self.islands + 1 + (6 if self.gallery else 0))];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        upper = build.room(1, 1, self.walk, self.long - 1, self.wide - 1, self.walk + self.headroom + self.islands + 1, variant=dice.below(4));
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
        # each [x0, x1, y0, y1], each a step higher than the last; the pit's
        # bed steps too, every other reach two lifts up.
        landings: list[list[int]] = [[1, 1 + self.shore, 1, self.wide - 1]];
        for index in range(self.islands) {
            x = 1 + self.shore + self.span + index * (self.span + self.island_long);
            y = self.island_y[index];
            build.solid(x, y, 0, x + self.island_long, y + self.island, self.walk + index + 1);
            landings.append([x, x + self.island_long, y, y + self.island]);
            if index % 2 == 0 {
                build.solid(x - self.span, 1, 0, x, self.wide - 1, 2);
            }
        }
        far_top = self.walk + self.islands + 1;
        build.solid(self.long - 1 - self.far_shore, 1, self.walk, self.long - 1, self.wide - 1, far_top);
        build.level(upper, far_top);
        landings.append([self.long - 1 - self.far_shore, self.long - 1, 1, self.wide - 1]);
        buttons = len(landings) - 1;
        count = build.tally(buttons, "The way on is open");
        build.touch(1.0, 1.0, float(self.walk), float(1 + self.shore), float(self.wide - 1), float(self.walk + 6), True, "You must press the buttons to open the door");
        for index in range(buttons) {
            landing = landings[index];
            onward = landings[index + 1];
            lane = self.lanes[index];
            here_z = self.walk + index;
            # The walkway on rises out of the slime as the player walks up to
            # the landing's edge, a step short of the next landing's top.
            near = build.touch(float(landing[1] - 2), float(lane), float(here_z), float(landing[1]), float(lane + 3), float(here_z + 6));
            near +>:Fires:+> build.drawn(float(landing[1]), float(lane), float(onward[0]), float(lane + 3), here_z, here_z + 1);
            for across in range(3) {
                build.keep(upper, landing[1] - 1, lane + across, here_z);
                build.keep(upper, onward[0], lane + across, here_z + 1);
            }
            # A column beside the lane on this landing, its button facing
            # back the way the player came: each counts toward the door.
            column_x = landing[1] - 2;
            column_y = lane - 1 if lane - 1 >= landing[2] else lane + 3;
            build.solid(column_x, column_y, here_z, column_x + 1, column_y + 1, here_z + 4);
            build.push(float(column_x), float(column_y) + 0.5, float(here_z) + 1.2, 2) +>:Fires:+> count;
            if index > 0 {
                build.foe(float(landing[0]) + 1.5, float(lane) + 1.5, here_z, e1m1_foe(dice, self.danger), 180.0);
            }
        }
        for port in self.taken {
            build.doorway(upper, port);
            low = port.along - float(port.wide) * 0.5;
            high = port.along + float(port.wide) * 0.5;
            fields = {"wait": "-1"};
            count +>:Fires:+> build.cue([fields], "door");
            if port.face == 0 {
                build.rising_door(float(self.long - 1), low, float(port.floor), float(self.long), high, float(port.floor + port.high), fields);
            } elif port.face == 1 {
                build.rising_door(low, float(self.wide - 1), float(port.floor), high, float(self.wide), float(port.floor + port.high), fields);
            } else {
                build.rising_door(low, 0.0, float(port.floor), high, 1.0, float(port.floor + port.high), fields);
            }
        }
        far = landings[-1];
        if self.gallery {
            # The gallery over the far shore, and its stair up the shore.
            raised = far_top + 6;
            build.level(upper, raised);
            deck(build, self.long - 4, 1, self.long - 1, self.wide - 1, raised);
            for step in range(6) {
                build.solid(self.long - 7, self.climb_y + step, far_top, self.long - 4, self.climb_y + step + 1, far_top + step + 1);
            }
            for y in range(self.climb_y + 3, self.climb_y + 6) {
                build.keep(upper, self.long - 4, y, raised);
            }
            for index in range(dice.between(1, 2)) {
                build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7), raised, e1m1_foe(dice, self.danger, True), 180.0);
            }
        }
        for index in range(dice.between(1, 2)) {
            far_x = float(self.long) - 2.5 if self.gallery else float(far[0]) + 1.5;
            build.foe(far_x, float(far[2]) + 2.5 + float(index) * 4.0, far_top, e1m1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(landings[1][0]) + 0.5, float(self.lanes[1]) + 1.5, self.walk + 1, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, self.walk, "item_spikes");
        # Something lies on the far shore and its gallery whatever foes are
        # thinned: the flood of places starts from there too.
        build.supply(float(far[0]) + 1.5, float(far[2]) + 1.5, far_top, "item_shells");
        if self.gallery {
            build.supply(float(self.long) - 2.5, float(self.wide // 2) + 0.5, far_top + 6, "item_health");
        }
        if dice.chance(0.4) {
            build.supply(float(landings[-2][0]) + 0.5, float(self.lanes[-1]) + 1.5, self.walk + self.islands, "weapon_nailgun");
        }
    }
}

"""The end: a channel across the room, a bridge drawn over it by shooting
the button on the far wall, and the slipgate on its dais beyond. By the
dice the channel holds lava, slime or water, the button sits high at
either side, and a gallery runs along a side wall over the near floor and
the channel, ridden up to on a lift, its guards woken as the player comes
in."""
node Slipgate(Prefab) {
    has near: int = 4,
        channel: int = 5,
        dais: int = 7,
        tall: int = 13,
        deadly: bool = True,
        gallery: bool = False,
        gallery_low: bool = True,
        button_low: bool = False;

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
        self.gallery = dice.chance(0.5);
        self.gallery_low = dice.chance(0.5);
        self.button_low = dice.chance(0.5);
        self.long = 1 + self.near + self.channel + self.dais + 1;
        self.low = -6;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=self.wide // 2, floor=1);
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
        build.button(float(self.long - 1), 2.5 if self.button_low else float(self.wide) - 2.5, 7.0, 2, bridge, True);
        # The gallery along a side wall, over the near floor and the channel,
        # and the lift up to it; its guards wake as the player comes in.
        if self.gallery {
            high = 7;
            build.level(room, high);
            g0 = 1 if self.gallery_low else self.wide - 4;
            deck(build, 2, g0, cut + self.channel + 2, g0 + 3, high);
            lift_y = g0 + 3 if self.gallery_low else g0 - 3;
            edge_y = g0 + 2 if self.gallery_low else g0;
            lift(build, cut - 4, lift_y, cut - 1, lift_y + 3, 0, high);
            for x in range(cut - 5, cut) {
                build.keep(room, x, edge_y, high);
            }
            come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0);
            snipers = build.waiting();
            come_in +>:Fires:+> snipers;
            for index in range(dice.between(1, 2)) {
                build.foe(float(cut + 2 + index * 3) + 0.5, float(g0) + 1.5, high, e1m1_foe(dice, self.danger), 0.0, waits=snipers);
            }
            build.supply(3.5, float(g0) + 1.5, high, "item_rockets" if dice.chance(0.5) else "item_armor1");
        }
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

"""A high ledge over a deep room: a drop down into it, what waits below
woken by the landing, and a way back up for a body that must return. By
the dice the way back is a lift or a teleporter (e1m1's), the ledge stands
on solid or overhangs the floor, a catwalk runs on from it across the
room to a way out high in the far wall, and a closet down on the floor
opens to a shot (a secret)."""
node DropShaft(Prefab) {
    has ledge: int = 4,
        top: int = 13,
        tall: int = 24,
        lift_y: int = 3,
        drop_y: int = 8,
        walk_y: int = 6,
        teleport: bool = False,
        hollow: bool = False,
        catwalk: bool = False,
        stash_low: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drop shaft";
        self.source = E1M1;
        self.long = dice.between(16, 20);
        self.catwalk = dice.chance(0.45);
        self.wide = dice.between(15, 17) if self.catwalk else dice.between(13, 16);
        self.top = dice.between(12, 15);
        self.tall = self.top + dice.between(9, 12);
        self.ledge = dice.between(4, 5);
        self.teleport = dice.chance(0.5);
        self.hollow = self.teleport or dice.chance(0.3);
        self.stash_low = dice.chance(0.5);
        # Along the ledge's edge: the way back up at one end, the stretch
        # to drop from at the other, the catwalk between.
        if dice.chance(0.5) {
            self.lift_y = 2;
            self.drop_y = self.wide - 5;
        } else {
            self.lift_y = self.wide - 5;
            self.drop_y = 2;
        }
        self.walk_y = self.wide // 2 - 1;
        self.low = -1;
        self.high = self.tall + 1;
        far_side = self.long - 9 if self.stash_low else self.long - 4;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=self.top);
        self.leaves = [
            Port(face=0, along=float(dice.between(8 if self.stash_low else 3, self.wide - 3)), floor=1),
            Port(face=1, along=float(dice.between(self.ledge + 5, self.long - 4)), floor=1),
            Port(face=3, along=float(dice.between(self.ledge + 5, max(self.ledge + 5, far_side))), floor=1)
        ];
        if self.catwalk {
            self.leaves.append(Port(face=0, along=float(self.walk_y) + 1.5, floor=self.top));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(room, self.top);
        edge_x = 1 + self.ledge;
        if self.hollow {
            # The ledge a deck over the floor, pillars under its edge.
            deck(build, 1, 1, edge_x, self.wide - 1, self.top);
            for y in range(2, self.wide - 2, 4) {
                build.solid(edge_x - 1, y, 0, edge_x, y + 1, self.top - 1);
            }
            build.supply(2.5, float(self.wide // 2) + 0.5, 0, "item_health");
        } else {
            build.solid(1, 1, 0, edge_x, self.wide - 1, self.top);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # The way back up: a lift beside the ledge that waits at the floor
        # below and rises when stepped on, or a teleporter on the floor that
        # sends a body up onto the ledge.
        clear: list[list[int]] = [[edge_x, self.lift_y - 1, edge_x + 4, self.lift_y + 4], [edge_x, self.drop_y - 1, edge_x + 4, self.drop_y + 4]];
        if self.teleport {
            build.teleporter(float(edge_x) + 2.5, float(self.lift_y) + 1.5, 0, 2.5, float(self.lift_y) + 1.5, self.top, 0.0);
        } else {
            lift(build, edge_x, self.lift_y, edge_x + 2, self.lift_y + 3, 0, self.top);
            for y in range(self.lift_y - 1, self.lift_y + 4) {
                build.keep(room, edge_x - 1, y, self.top);
                build.keep(room, edge_x, y, 0);
            }
        }
        # A stretch of the ledge's edge with no railing, to drop from.
        for y in range(self.drop_y - 1, self.drop_y + 3) {
            build.keep(room, edge_x - 1, y, self.top);
        }
        # The catwalk on across the room to the far wall's way out.
        if self.catwalk {
            deck(build, edge_x, self.walk_y, self.long - 1, self.walk_y + 3, self.top);
            for y in range(self.walk_y, self.walk_y + 3) {
                build.keep(room, edge_x - 1, y, self.top);
            }
            build.foe(float(self.long) - 3.5, float(self.walk_y) + 1.5, self.top, e1m1_foe(dice, self.danger), 180.0);
        }
        # The closet down on the floor, against the -y wall near the far end.
        if self.stash_low {
            stash(build, self.long - 6, 1, 0, 1, e1m1_reward(dice));
            clear.append([self.long - 7, 1, self.long - 1, 7]);
        }
        for port in self.taken {
            if port.floor <= 1 {
                at = int(port.along);
                if port.face == 0 {
                    clear.append([self.long - 5, at - 3, self.long, at + 3]);
                } elif port.face == 1 {
                    clear.append([at - 3, self.wide - 5, at + 3, self.wide]);
                } else {
                    clear.append([at - 3, 0, at + 3, 5]);
                }
            }
        }
        # Crates on the floor below, clear of what must stay open.
        placed = 0;
        tries = 0;
        crates = dice.between(3, 5);
        while placed < crates and tries < 40 {
            tries += 1;
            x = edge_x + 4 + dice.below(max(1, self.long - edge_x - 8));
            y = 2 + dice.below(max(1, self.wide - 5));
            if apart([x, y, x + 2, y + 2], clear) {
                build.solid(x, y, 0, x + 2, y + 2, dice.between(2, 4));
                clear.append([x, y, x + 2, y + 2]);
                placed += 1;
            }
        }
        # What waits below wakes as a body lands from the ledge.
        landed = build.touch(float(edge_x), float(self.drop_y - 1), 0.0, float(edge_x + 4), float(self.drop_y + 3), 6.0);
        below = build.waiting();
        landed +>:Fires:+> below;
        first_y = 7.5 if self.stash_low else 2.5;
        for index in range(dice.between(3, 5)) {
            foe_y = first_y + float(index) * 2.5;
            if foe_y < float(self.wide) - 2.0 {
                build.foe(float(self.long) - 2.5 - float(index % 2) * 3.0, foe_y, 0, e1m1_foe(dice, self.danger, index == 0), 180.0, waits=below);
            }
        }
        build.supply(2.5, 2.5, self.top, "item_spikes");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""The key room: a vault, the key on a platform at its far end, the
closets along its side wall opening when the key is taken. By the dice the
platform stands on solid and is ridden up to on a lift, or it is a deck
over the vault's floor climbed by a stair along the wall, crates stored
under it."""
node StorageVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        shelf: int = 5,
        tall: int = 16,
        stair_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Storage vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M1;
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.stair_up = dice.chance(0.5);
        self.shelf = dice.between(6, 7) if self.stair_up else dice.between(5, 6);
        self.tall = self.shelf + dice.between(10, 12);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=1);
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
        if self.stair_up {
            deck(build, ledge_x, 1, self.long - 1, side, self.shelf);
            stair(build, ledge_x - self.shelf, 1, 0, 0, self.shelf, 3);
            for y in range(1, 4) {
                build.keep(vault, ledge_x, y, self.shelf);
            }
            # Crates stored under the deck, and a box of shells among them.
            build.solid(self.long - 3, side - 4, 0, self.long - 1, side - 2, 2);
            build.solid(self.long - 3, 4, 0, self.long - 1, 6, 3);
            build.supply(float(ledge_x) + 1.5, float(side // 2) + 0.5, 0, "item_shells");
        } else {
            build.solid(ledge_x, 1, 0, self.long - 1, side, self.shelf);
            lift(build, ledge_x - 3, 2, ledge_x, 5, 0, self.shelf);
            for y in range(1, 6) {
                build.keep(vault, ledge_x, y, self.shelf);
                build.keep(vault, ledge_x - 1, y, 0);
            }
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
        round_y = 5.5 if self.stair_up else 3.5;
        round_end = float(ledge_x) - (1.5 if self.stair_up else 4.5);
        build.foe(4.5, round_y, 0, e1m1_foe(dice, self.danger), 0.0, patrol=[[4.5, round_y], [round_end, round_y]]);
        build.foe(float(self.long) - 3.5, 3.5, self.shelf, e1m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""e1m1's stretches: [name, role] (start, flow, hub, keyroom, end, gate)."""
glob E1M1_STRETCHES: list[list[str]] = [["gatehouse", "start"], ["ways", "flow"], ["hall", "hub"], ["walkways", "flow"], ["drop", "flow"], ["vault", "keyroom"], ["slipgate", "end"]];

"""One of e1m1's stretches by its name."""
def make_e1m1(name: str, key: str) -> Prefab {
    if name == "gatehouse" {
        return Gatehouse();
    }
    if name == "ways" {
        return ServiceWays();
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
