"""Prefabs drawn from e1m4, the Grisly Grotto: caves of rock and water,
lakes to swim or cross by their islands, teleporters up to high ledges,
the silver key on an island, a climb up a waterfall's shaft. Raised in
e1m4's own palette.

- `GrottoMouth`: the start. A rough cave, boulders against its walls and
  stalactites over it, a stream across its floor.
- `FloodedCaverns`: a lake across a cavern, swum or crossed by jumping
  from rock to rock; scrags over it and fish in it.
- `TeleportGrotto`: a tall cavern, a pool in its middle, ledges high on
  three of its walls reached by teleporters on its floor; ways on from
  the ledges and the floor (a hub).
- `SilverGrotto`: a deep lake, the key on an island in its middle; taking
  it opens the closets high in the wall, and scrags come out.
- `WaterfallClimb`: a tall shaft, a basin of water at its foot, ramps of
  rock up its walls switching back to a way on high up.
- `GrottoExit`: the end. A cave, the slipgate on a rock ledge up a stair at
  its far end; as a gate, a key door across the ledge's mouth."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, boulders, stalactites, apart }

glob E1M4: str = "q1:e1m4";

"""e1m4's foes: knights and ogres on the rock, scrags in the air."""
def e1m4_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_knight", "monster_knight", "monster_ogre"] if heavy else ["monster_knight", "monster_knight"], ["monster_ogre"] if heavy else ["monster_ogre", "monster_wizard"], danger));
}

"""The start: a rough cave with a stream across it."""
node GrottoMouth(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grotto mouth";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(18, 22);
        self.wide = dice.between(14, 18);
        self.tall = dice.between(12, 16);
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        stream_x = self.long // 2;
        build.pool(stream_x, 1, -2, stream_x + 3, self.wide - 1, 0, 2);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        clear = [[0, middle - 3, 5, middle + 3], [self.long - 5, middle - 3, self.long, middle + 3], [self.long - 7, self.wide - 5, self.long, self.wide], [self.long - 7, 0, self.long, 5], [stream_x - 1, 0, stream_x + 4, self.wide]];
        boulders(build, dice, 1, 1, self.long - 1, self.wide - 1, 0, dice.between(6, 10), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(stream_x) + 4.5 + float(index) * 2.0, 3.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger), 180.0);
        }
        build.foe(float(stream_x) + 1.5, float(middle) + 0.5, 6, e1m4_foe(dice, self.danger, False, True), 180.0);
    }
}

"""A lake across a cavern, swum or crossed by jumping from rock to rock."""
node FloodedCaverns(Prefab) {
    has shore: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded caverns";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(14, 18);
        self.low = -9;
        self.high = self.tall + 1;
        far = float(self.long - 1 - self.shore) + float(self.shore) * 0.5;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=far, floor=0), Port(face=3, along=far, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        lake_x0 = 1 + self.shore;
        lake_x1 = self.long - 1 - self.shore;
        build.pool(lake_x0, 1, -8, lake_x1, self.wide - 1, 0, 2);
        # Steps up out of it onto the far shore too.
        stair(build, lake_x1 - 8, 1, -8, 0, 8, 2);
        # Rocks across the lake, two cells apart, zigzagging about the middle.
        x = lake_x0 + 2;
        index = 0;
        while x + 3 <= lake_x1 - 2 {
            y = middle - 1 + (dice.between(-3, 3) if index > 0 else 0);
            y = max(2, min(self.wide - 5, y));
            build.solid(x, y, -8, x + 3, y + 3, 0);
            x += 5;
            index += 1;
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        near = [[0, middle - 3, lake_x0, middle + 3], [lake_x0 - 1, 0, lake_x0 + 1, self.wide]];
        boulders(build, dice, 1, 1, lake_x0, self.wide - 1, 0, dice.between(2, 4), near);
        far_clear = [[lake_x1 - 1, 0, lake_x1 + 1, self.wide], [self.long - 5, middle - 3, self.long, middle + 3], [lake_x1, self.wide - 5, self.long, self.wide], [lake_x1, 0, self.long, 5]];
        boulders(build, dice, lake_x1, 1, self.long - 1, self.wide - 1, 0, dice.between(2, 4), far_clear);
        stalactites(build, dice, lake_x0, 2, lake_x1, self.wide - 2, self.tall, dice.between(8, 12));
        for index in range(dice.between(1, 2)) {
            build.foe(float(lake_x0 + 3 + index * 5), float(middle) + 3.5, -6, "monster_fish", 90.0);
        }
        for index in range(dice.between(1, 3)) {
            build.foe(float(lake_x0 + 4 + index * 4), float(middle) + 0.5, 7, e1m4_foe(dice, self.danger, False, True), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(lake_x1) + 2.5, 3.5 + float(index) * 4.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A tall cavern, a pool in its middle, ledges high on three walls reached
by teleporters on its floor; ways on from the ledges and the floor."""
node TeleportGrotto(Prefab) {
    has ledge: int = 11,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport grotto";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(22, 26);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(22, 26);
        self.ledge = dice.between(10, 12);
        self.low = -4;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=1, along=cx, floor=self.ledge),
            Port(face=0, along=cy, floor=self.ledge),
            Port(face=3, along=cx, floor=self.ledge),
            Port(face=0, along=cy - 6.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.ledge);
        build.pool(cx - 2, cy - 2, -3, cx + 2, cy + 2, 0, 2);
        under = self.ledge - 1;
        # The ledges, slabs a lift thick high on the north, east and south.
        build.solid(6, self.wide - 5, under, self.long - 6, self.wide - 1, self.ledge);
        build.solid(self.long - 5, 6, under, self.long - 1, self.wide - 6, self.ledge);
        build.solid(6, 1, under, self.long - 6, 5, self.ledge);
        # A stretch of each ledge's edge with no railing, to drop from.
        for x in range(cx - 4, cx + 1) {
            build.keep(cave, x, self.wide - 6, self.ledge);
            build.keep(cave, x, 5, self.ledge);
        }
        for y in range(cy + 2, cy + 6) {
            build.keep(cave, self.long - 6, y, self.ledge);
        }
        build.teleporter(float(cx) + 0.5, float(self.wide) - 7.5, 0, float(cx) + 0.5, float(self.wide) - 3.0, self.ledge, 90.0);
        build.teleporter(float(self.long) - 7.5, float(cy) + 0.5, 0, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, 0.0);
        build.teleporter(float(cx) + 0.5, 7.5, 0, float(cx) + 0.5, 3.0, self.ledge, 270.0);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        stalactites(build, dice, 6, 6, self.long - 6, self.wide - 6, self.tall, dice.between(6, 10));
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 3.0, float(cy) + 4.5, 0, e1m4_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, self.ledge + 4, e1m4_foe(dice, self.danger, False, True), 0.0);
        }
        build.foe(float(self.long) - 3.0, float(cy) - 3.5, self.ledge, e1m4_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 2.5, float(self.wide) - 3.0, self.ledge, "item_health");
        build.supply(float(cx) + 3.5, 3.0, self.ledge, "item_spikes");
    }
}

"""A deep lake, the key on an island in its middle; taking it opens the
closets high in the wall."""
node SilverGrotto(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver grotto (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(20, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(17, 19);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(cave, self.enter);
        build.pool(5, 2, -8, self.long - 2, side - 1, 0, 2);
        ix = (5 + self.long - 2) // 2;
        iy = side // 2;
        build.solid(ix - 3, iy - 3, -8, ix + 3, iy + 3, 0);
        ambush = build.name("ambush");
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, float(ix) + 0.5, float(iy) + 0.5, 0);
        # Closets high in the far wall, scrags in them.
        for index in range(3) {
            x = 5 + index * 5;
            if x + 3 >= self.long - 2 {
                break;
            }
            closet = build.room(x, side + 1, 8, x + 3, side + 4, 15);
            build.widen(closet, x, side, 8, x + 3, side + 1, 14);
            build.rising_door(float(x), float(side), 8.0, float(x + 3), float(side + 1), 14.0, {"targetname": ambush, "wait": "-1"});
            build.foe(float(x) + 1.5, float(side) + 2.5, 8, e1m4_foe(dice, self.danger, False, True), 270.0);
        }
        stalactites(build, dice, 5, 2, self.long - 2, side - 1, self.tall, dice.between(6, 10));
        build.foe(float(ix) + 2.5, float(iy) + 2.5, 0, e1m4_foe(dice, self.danger, True), 180.0);
        build.foe(float(ix) - 4.0, float(iy) + 0.5, -6, "monster_fish", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""A tall shaft, a basin at its foot, ramps of rock switching back up its
walls to a way on high up."""
node WaterfallClimb(Prefab) {
    has first: int = 10,
        second: int = 9,
        tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Waterfall climb";
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(16, 18);
        self.wide = dice.between(14, 16);
        self.first = self.long - 6;
        self.second = self.long - 7;
        self.tall = self.first + self.second + dice.between(9, 11);
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=2, along=float(self.wide - 3), floor=self.first + self.second)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(4, 4, -4, self.long - 4, self.wide - 4, 0, 2);
        # The first ramp along the near wall, climbing east, a lift a cell,
        # three lifts thick; a walk along the east wall at its top.
        for step in range(self.first) {
            lift = step + 1;
            build.solid(3 + step, 1, max(0, lift - 3), 4 + step, 4, lift);
        }
        build.solid(self.long - 4, 1, max(0, self.first - 3), self.long - 1, self.wide - 1, self.first);
        # The second ramp along the far wall, climbing west to a landing.
        top = self.first + self.second;
        for step in range(self.second) {
            lift = self.first + step + 1;
            build.solid(self.long - 5 - step, self.wide - 4, max(0, lift - 3), self.long - 4 - step, self.wide - 1, lift);
        }
        build.solid(1, self.wide - 4, top - 3, self.long - 4 - self.second, self.wide - 1, top);
        for index in range(4) {
            build.level(shaft, index * (top // 4));
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 6 + index * 6, e1m4_foe(dice, self.danger, False, True), float(index * 120));
        }
        build.foe(2.5, float(self.wide) - 2.5, top, e1m4_foe(dice, self.danger, True), 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide // 2) + 0.5, self.first, "item_health");
    }
}

"""The end: a cave, the slipgate on a rock ledge up a stair; as a gate, a
key door across the ledge's mouth."""
node GrottoExit(Prefab) {
    has key: str = "",
        ledge_x: int = 14,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Grotto exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M4;
        self.district = level_district(E1M4);
        self.long = dice.between(20, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(14, 16);
        self.ledge_x = self.long - 1 - 6;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(cave, self.enter);
        # The ledge three lifts up, a wall across its mouth with a way in.
        wall = self.ledge_x - 1;
        build.solid(self.ledge_x, 1, 0, self.long - 1, self.wide - 1, 3);
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 11, wall + 1, middle + 2, self.tall);
        stair(build, wall - 3, middle - 2, 0, 0, 3, 4);
        build.solid(wall, middle - 2, 0, wall + 1, middle + 2, 3);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 3.0, float(wall + 1), float(middle + 2), 11.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(float(self.ledge_x) + 3.0, float(middle), 3);
        clear = [[0, middle - 3, 5, middle + 3], [wall - 5, middle - 3, wall + 1, middle + 3]];
        boulders(build, dice, 1, 1, wall, self.wide - 1, 0, dice.between(4, 7), clear);
        stalactites(build, dice, 3, 3, wall - 1, self.wide - 3, self.tall, dice.between(5, 8));
        for index in range(dice.between(3, 4)) {
            build.foe(float(wall) - 5.5 - float(index % 2) * 3.0, 2.5 + float(index) * 3.0, 0, e1m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e1m4's stretches: [name, role]."""
glob E1M4_STRETCHES: list[list[str]] = [
         ["mouth", "start"],
         ["caverns", "flow"],
         ["teleports", "hub"],
         ["teleports", "flow"],
         ["silver", "keyroom"],
         ["waterfall", "flow"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e1m4's stretches by its name."""
def make_e1m4(name: str, key: str) -> Prefab {
    if name == "mouth" {
        return GrottoMouth();
    }
    if name == "caverns" {
        return FloodedCaverns();
    }
    if name == "teleports" {
        return TeleportGrotto();
    }
    if name == "silver" {
        return SilverGrotto(key=key if key else "key_silver");
    }
    if name == "waterfall" {
        return WaterfallClimb();
    }
    return GrottoExit(key=key);
}
