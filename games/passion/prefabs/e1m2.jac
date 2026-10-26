"""Prefabs drawn from e1m2, the Castle of the Damned: seven stretches of
it, each made again at its scale with its flow, and varied by a seed. They
are raised in the Stone Keep's materials (the kit read off e1m2).

- `MoatGate`: the start. An open court under the sky, a moat of water
  across it and a stone bridge over the moat to the castle's gate.
- `KeyHall`: a key (silver or gold) on a high dais up a stair along the
  wall; taking it opens the closets in the walls, and what waits in them
  comes out (e1m2's ambushes as its keys are taken). It ends a branch: the
  way back is the way in.
- `DrawbridgePit`: a deep pit of water across a hall. A lift rises to a
  balcony in the corner, and the button there draws the bridge up out of
  the water (e1m2's bridge 10, drawn out by a button far from it); steps
  lead up out of the water to the near side only.
- `SilverGate`: the end. A hall walled across, a key door in the wall
  (e1m2's silver doors), and the way out in the chamber beyond.
- `GreatHall`: a hub of two floors: a gallery round the walls over an
  arcade, stairs up to it, a fountain in the middle, and ways out on both
  floors (where a level's locked door and its key's branch part).
- `Tower`: a tall shaft and a stair winding up round its walls, a lift a
  step, to a way out high up; the middle open to fall back down.
- `FloodedPassage`: two rooms joined only under water: a pool in each, and
  a flooded tunnel between them to swim."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { kit_of }

glob E1M2: str = "q1:e1m2",
     # The Stone Keep: e1m2's kit.
     E1M2_DISTRICT: int = 1;

"""A foe for e1m2's stretches: knights and grunts, a dog now and then,
scrags where there is room to fly (`flying`), ogres as a run goes deeper
where `heavy`."""
def e1m2_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    kinds = ["monster_knight", "monster_army", "monster_dog", "monster_wizard", "monster_ogre"];
    weights = [5.0, 2.0, 1.0, (4.0 if flying else 0.0), (1.0 + 3.0 * danger) if heavy else 0.0];
    return kinds[dice.weighted(weights)];
}

"""The start: a court under the sky, a moat across it, a bridge to the
gate."""
node MoatGate(Prefab) {
    has moat_x: int = 7,
        moat: int = 5,
        lane: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Moat gate";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.moat_x = dice.between(8, 10);
        self.moat = dice.between(6, 7);
        self.long = self.moat_x + self.moat + dice.between(10, 14);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(16, 20);
        self.lane = dice.between(3, self.wide - 6);
        self.low = -7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        far = self.moat_x + self.moat + (self.long - 1 - self.moat_x - self.moat) // 2;
        self.leaves = [
            Port(face=0, along=float(dice.between(3, self.wide - 3)), floor=0),
            Port(face=1, along=float(far), floor=0),
            Port(face=3, along=float(far), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.room(self.moat_x, 1, -6, self.moat_x + self.moat, self.wide - 1, 0, flood=5);
        # The bridge: stone under the lane, the moat's floor to the court's.
        build.solid(self.moat_x, self.lane, -6, self.moat_x + self.moat, self.lane + 3, 0);
        for across in range(3) {
            build.keep(court, self.moat_x - 1, self.lane + across, 0);
            build.keep(court, self.moat_x + self.moat, self.lane + across, 0);
            for along in range(self.moat_x, self.moat_x + self.moat) {
                build.keep(court, along, self.lane + across, 0);
            }
        }
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(self.wide) * 0.5, 0, 0.0);
        build.supply(2.5, 1.5, 0, "item_shells");
        far = float(self.moat_x + self.moat);
        for index in range(dice.between(2, 4)) {
            build.foe(far + 2.5 + float(index) * 2.0, 2.5 + float(index % 2) * float(self.wide - 5), 0, e1m2_foe(dice, self.danger), 180.0);
        }
        if dice.chance(0.6) {
            build.supply(far + 1.5, float(self.wide) - 2.5, 0, "item_health");
        }
    }
}

"""A hall, its silver key on a high dais up a stair; taking the key opens
the closets in its walls."""
node KeyHall(Prefab) {
    has key: str = "key_silver",
        hall_long: int = 16,
        hall_wide: int = 12,
        tall: int = 16,
        dais: int = 6,
        rise_to: int = 7,
        closets: int = 2;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key hall (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.hall_wide = dice.between(16, 18);
        self.tall = dice.between(18, 22);
        self.dais = dice.between(6, 7);
        self.rise_to = dice.between(8, 10);
        self.hall_long = self.dais + self.rise_to + dice.between(12, 16);
        self.closets = dice.between(2, 3);
        self.long = self.hall_long;
        # Closets stand beyond the hall's side wall.
        self.wide = self.hall_wide + 4;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.hall_wide - 4)), floor=0);
        # Out from the top of the dais, past the key, or by the near side.
        self.leaves = [
            Port(face=0, along=float(dice.between(3, self.hall_wide - 4)), floor=self.rise_to),
            Port(face=3, along=float(dice.between(4, self.hall_long - self.dais - self.rise_to - 2)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.rise_to);
        # The dais at the far end, and the stair up to it along the side
        # wall, a lift a step.
        dais_x = self.long - 1 - self.dais;
        build.solid(dais_x, 1, 0, self.long - 1, side, self.rise_to);
        stair_x = dais_x - self.rise_to;
        for step in range(self.rise_to) {
            build.solid(stair_x + step, side - 3, 0, stair_x + step + 1, side, step + 1);
        }
        for x in [dais_x - 1, dais_x] {
            for y in [side - 3, side - 2, side - 1] {
                build.keep(hall, x, y, self.rise_to);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The key on the dais: taking it fires the closets' doors.
        ambush = build.name("ambush");
        key_x = float(dais_x) + float(self.dais) * 0.5;
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, key_x, float(self.hall_wide) * 0.5, self.rise_to);
        for index in range(self.closets) {
            cx = 3 + index * 5;
            if cx + 3 >= stair_x {
                break;
            }
            closet = build.room(cx, side + 1, 0, cx + 3, side + 4, 7);
            build.widen(closet, cx, side, 0, cx + 3, side + 1, 6);
            build.rising_door(float(cx), float(side), 0.0, float(cx + 3), float(side + 1), 6.0, {"targetname": ambush, "wait": "-1"});
            build.foe(float(cx) + 1.5, float(side) + 2.5, 0, e1m2_foe(dice, self.danger, True), 270.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(dais_x) - 2.5 - float(index) * 3.0, 2.5 + float(index % 2) * 3.0, 0, e1m2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(dais_x) + 1.5, float(self.hall_wide) - 3.5, self.rise_to, e1m2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(dais_x) + 1.5, 1.5, self.rise_to, "item_spikes");
        if dice.chance(0.5) {
            build.supply(key_x, 2.5, self.rise_to, "weapon_supershotgun");
        }
    }
}

"""A deep pit of water across a hall; a lift to a balcony whose button
draws the bridge up out of the water."""
node DrawbridgePit(Prefab) {
    has near: int = 6,
        span: int = 8,
        far_side: int = 3,
        walk: int = 8,
        headroom: int = 12,
        lane: int = 4,
        balcony: int = 4;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drawbridge pit";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.near = dice.between(7, 9);
        self.span = dice.between(8, 9);
        self.wide = dice.between(15, 18);
        self.headroom = dice.between(16, 18);
        self.balcony = dice.between(5, 7);
        self.lane = dice.between(4, self.wide - 7);
        self.long = 1 + self.near + self.span + self.far_side + 1;
        self.low = -1;
        self.high = self.walk + self.headroom + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.lane + 1)), floor=self.walk);
        self.leaves = [Port(face=0, along=float(dice.between(3, self.wide - 3)), floor=self.walk)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        upper = build.room(1, 1, self.walk, self.long - 1, self.wide - 1, self.walk + self.headroom, variant=dice.below(3));
        cut = 1 + self.near;
        build.room(cut, 1, 0, cut + self.span, self.wide - 1, self.walk, flood=4);
        build.doorway(upper, self.enter);
        for port in self.taken {
            build.doorway(upper, port);
        }
        # Steps up out of the water to the near side, along the wall the
        # bridge keeps clear of.
        for step in range(self.walk) {
            build.solid(cut + step, 1, 0, cut + step + 1, 3, self.walk - step);
        }
        bridge = build.name("bridge");
        build.bridge(float(cut), float(self.lane), float(cut + self.span), float(self.lane + 3), self.walk, self.walk + 1, bridge);
        for across in range(3) {
            build.keep(upper, cut - 1, self.lane + across, self.walk);
            build.keep(upper, cut + self.span, self.lane + across, self.walk);
        }
        # The balcony in the near corner, and the lift beside it: a plat
        # that waits at the floor and rises when stepped on.
        top = self.walk + self.balcony;
        side = self.wide - 1;
        build.solid(1, side - 3, self.walk, 4, side, top);
        build.put_box({"classname": "func_plat", "height": str(self.balcony * 16), "speed": "120"}, 4.0, float(side - 3), float(top) - 0.5, 6.0, float(side), float(top), kit_of(build.district).step);
        for x in [3, 4, 5] {
            for y in [side - 3, side - 2, side - 1] {
                build.keep(upper, x, y, top);
                build.keep(upper, x, y, self.walk);
            }
        }
        build.button(2.5, float(side), float(top) + 1.5, 3, bridge);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cut) + 2.5 + float(index) * 3.0, float(self.wide) * 0.5, self.walk + 4, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(self.lane) + 1.5, self.walk, e1m2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, self.walk, "item_health");
        if dice.chance(0.5) {
            build.supply(1.5, float(side) - 1.5, top, "item_armor1");
        }
    }
}

"""The end: a hall walled across, the silver-key door in the wall, and the
way out in the chamber beyond."""
node SilverGate(Prefab) {
    has key: str = "key_silver",
        wall_x: int = 9,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = ("Gold" if self.key == "key_gold" else "Silver") + " gate";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.long = dice.between(22, 26);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(16, 18);
        self.wall_x = self.long - 1 - dice.between(6, 7);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.wall_x, self.wide - 1, self.tall, variant=dice.below(3));
        chamber = build.room(self.wall_x + 1, 1, 0, self.long - 1, self.wide - 1, self.tall);
        build.doorway(hall, self.enter);
        middle = self.wide // 2;
        build.widen(chamber, self.wall_x, middle - 2, 0, self.wall_x + 1, middle + 2, 8);
        build.rising_door(float(self.wall_x), float(middle - 2), 0.0, float(self.wall_x + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        # Pillars down the hall, a pair a few cells apart.
        for x in range(4, self.wall_x - 2, 4) {
            build.solid(x, 2, 0, x + 1, 3, self.tall);
            build.solid(x, self.wide - 3, 0, x + 1, self.wide - 2, self.tall);
        }
        gate_x = float(self.wall_x + 1) + float(self.long - 2 - self.wall_x) * 0.5;
        build.way_out(gate_x, float(middle), 0);
        for index in range(dice.between(3, 5)) {
            build.foe(float(self.wall_x) - 2.5 - float(index % 2) * 4.0, 2.5 + float(index) * 2.5, 0, e1m2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        if dice.chance(0.5) {
            build.supply(2.5, float(self.wide) - 2.5, 0, "item_rockets");
        }
    }
}

"""A hub of two floors: a gallery round the walls over an arcade, stairs up
to it, a fountain in the middle; ways out on both floors."""
node GreatHall(Prefab) {
    has gallery: int = 10,
        ring: int = 3,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Great hall";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.long = dice.between(26, 32);
        self.wide = dice.between(22, 28);
        self.tall = dice.between(22, 26);
        self.gallery = dice.between(10, 11);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2 + dice.between(-3, 3)), floor=self.gallery),
            Port(face=3, along=float(self.long // 2 + 6 + dice.between(0, 3)), floor=self.gallery),
            Port(face=0, along=float(self.wide - 6), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        inner = 1 + self.ring;
        far_x = self.long - 1 - self.ring;
        far_y = self.wide - 1 - self.ring;
        # The gallery: a slab round the walls a lift thick, over an arcade.
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, inner, self.gallery);
        build.solid(1, far_y, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(1, inner, under, inner, far_y, self.gallery);
        build.solid(far_x, inner, under, self.long - 1, far_y, self.gallery);
        for x in range(inner + 3, far_x - 2, 5) {
            build.solid(x, inner - 1, 0, x + 1, inner, under);
            build.solid(x, far_y, 0, x + 1, far_y + 1, under);
        }
        for y in range(inner + 3, far_y - 2, 5) {
            build.solid(inner - 1, y, 0, inner, y + 1, under);
            build.solid(far_x, y, 0, far_x + 1, y + 1, under);
        }
        # The stairs up to the gallery's near side, along it, a lift a step.
        stair_x = self.long // 2 - self.gallery // 2;
        for step in range(self.gallery) {
            build.solid(stair_x + step, inner, 0, stair_x + step + 1, inner + 2, step + 1);
        }
        for x in [stair_x + self.gallery - 2, stair_x + self.gallery - 1, stair_x + self.gallery] {
            build.keep(hall, x, inner - 1, self.gallery);
            build.keep(hall, x, inner, self.gallery);
        }
        # The fountain: a pool of water in the middle, steps up out of it.
        cx = self.long // 2;
        cy = self.wide // 2 + 3;
        build.pool(cx - 3, cy - 2, -3, cx + 3, cy + 2, 0, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 6 + index * 4) + 0.5, float(cy) - 4.5, 0, e1m2_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, self.gallery + 4, e1m2_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(far_x) + 1.5, float(self.wide // 2) + 0.5, self.gallery, e1m2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, "item_rockets");
        build.supply(float(cx) + 0.5, float(self.wide) - 2.5, self.gallery, "item_health");
    }
}

"""A tall shaft and a stair winding up round its walls to a way out high
up."""
node Tower(Prefab) {
    has side_cells: int = 12,
        tall: int = 34,
        climb: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tower";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.side_cells = dice.between(11, 13);
        self.long = self.side_cells + 2;
        self.wide = self.side_cells + 2;
        # Round the walls: along the near side, up the far, back along the
        # top and down the last, a cell a lift.
        n = self.side_cells;
        self.climb = (n - 4) + (n - 4) + (n - 4) + (n - 7);
        self.tall = self.climb + dice.between(9, 11);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=2.0, floor=0);
        # Out through the near wall where the stair ends, high up.
        self.leaves = [Port(face=2, along=7.0, floor=self.climb)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        n = self.side_cells;
        shaft = build.room(1, 1, 0, n + 1, n + 1, self.tall, variant=dice.below(3));
        # The path's cells, each a step: [x, y] of a band two wide by the wall.
        path: list[list[int]] = [];
        for x in range(4, n) {
            path.append([x, 1]);
        }
        for y in range(3, n - 1) {
            path.append([n - 1, y]);
        }
        for x in range(n - 2, 2, -1) {
            path.append([x, n - 1]);
        }
        for y in range(n - 2, n - 2 - (n - 7), -1) {
            path.append([1, y]);
        }
        # Corners are landings, as high as the step before them.
        build.solid(n - 1, 1, 0, n + 1, 3, n - 4);
        build.solid(n - 1, n - 1, max(0, (n - 4) + (n - 4) - 3), n + 1, n + 1, (n - 4) + (n - 4));
        build.solid(1, n - 1, max(0, self.climb - (n - 7) - 3), 3, n + 1, self.climb - (n - 7));
        for (index, cell) in enumerate(path) {
            lift = index + 1;
            # A floating stair three lifts thick: the shaft open under it.
            low = max(0, lift - 3);
            if cell[1] == 1 {
                build.solid(cell[0], 1, low, cell[0] + 1, 3, lift);
            } elif cell[0] == n - 1 {
                build.solid(n - 1, cell[1], low, n + 1, cell[1] + 1, lift);
            } elif cell[1] == n - 1 {
                build.solid(cell[0], n - 1, low, cell[0] + 1, n + 1, lift);
            } else {
                build.solid(1, cell[1], low, 3, cell[1] + 1, lift);
            }
            if index % 6 == 5 {
                build.level(shaft, lift);
            }
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(n // 2) + 0.5, float(n // 2) + 0.5, 8 + index * 8, e1m2_foe(dice, self.danger, False, True), float(index * 90));
        }
        build.foe(2.0, 6.5, self.climb, e1m2_foe(dice, self.danger, True), 0.0);
        build.supply(float(n - 1) + 0.5, 2.0, n - 4, "item_health");
    }
}

"""Two rooms joined only under water: a pool in each, a flooded tunnel
between."""
node FloodedPassage(Prefab) {
    has room_a: int = 9,
        tunnel: int = 6,
        room_b: int = 9,
        lane: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded passage";
        self.source = E1M2;
        self.district = E1M2_DISTRICT;
        self.room_a = dice.between(9, 12);
        self.tunnel = dice.between(5, 7);
        self.room_b = dice.between(10, 13);
        self.wide = dice.between(14, 17);
        self.tall = dice.between(14, 16);
        self.lane = dice.between(4, self.wide - 9);
        self.long = 1 + self.room_a + self.tunnel + self.room_b + 1;
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 3)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(3, self.wide - 3)), floor=0),
            Port(face=1, along=float(self.long - 1 - self.room_b // 2), floor=0),
            Port(face=3, along=float(self.long - 1 - self.room_b // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        wall_x = 1 + self.room_a;
        far_x = wall_x + self.tunnel;
        first = build.room(1, 1, 0, wall_x, self.wide - 1, self.tall, variant=dice.below(3));
        second = build.room(far_x, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # A pool against the wall in each room, six lifts deep, and the tunnel
        # under the wall between them, all of it water to the brim; steps up
        # out of each pool along its far side.
        near_pool = wall_x - 5;
        build.room(near_pool, self.lane - 1, -6, wall_x, self.lane + 5, 0);
        build.room(far_x, self.lane - 1, -6, far_x + 5, self.lane + 5, 0);
        build.room(wall_x, self.lane, -6, far_x, self.lane + 3, -2);
        for step in range(6) {
            build.solid(near_pool, self.lane - 1 + step, -6, near_pool + 1, self.lane + step, -5 + step);
            build.solid(far_x + 4, self.lane - 1 + step, -6, far_x + 5, self.lane + step, -5 + step);
        }
        for z in range(-6, 0) {
            for y in range(self.lane - 1, self.lane + 5) {
                for x in range(near_pool, far_x + 5) {
                    pool = x < wall_x or x >= far_x;
                    tunnel = not pool and self.lane <= y < self.lane + 3 and z < -2;
                    if pool or tunnel {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
        }
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(second, port);
        }
        build.foe(float(wall_x) - 6.5, 2.5, 0, e1m2_foe(dice, self.danger), 0.0);
        if dice.chance(0.4 + 0.4 * self.danger) {
            build.foe(float(far_x) + 2.0, float(self.lane) + 1.5, -5, "monster_fish", 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * 3.5, 0, e1m2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(far_x) + 5.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_shells");
    }
}

"""e1m2's stretches: [name, role] (start, flow, hub, keyroom, end, gate)."""
glob E1M2_STRETCHES: list[list[str]] = [["moat", "start"], ["pit", "flow"], ["tower", "flow"], ["flooded", "flow"], ["great", "hub"], ["key", "keyroom"], ["gate", "gate"]];

"""One of e1m2's stretches by its name (`key` the key a key room holds or
a gate wants)."""
def make_e1m2(name: str, key: str) -> Prefab {
    if name == "moat" {
        return MoatGate();
    }
    if name == "pit" {
        return DrawbridgePit();
    }
    if name == "tower" {
        return Tower();
    }
    if name == "flooded" {
        return FloodedPassage();
    }
    if name == "great" {
        return GreatHall();
    }
    if name == "key" {
        return KeyHall(key=key if key else "key_silver");
    }
    return SilverGate(key=key if key else "key_silver");
}
