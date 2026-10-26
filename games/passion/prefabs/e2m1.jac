"""Prefabs drawn from e2m1, the Installation: a base built over water, its
docks and canals, tunnels flooded to be swum under, a pumping hall with a
pit and a catwalk round it, a key on an island raised to by a bridge, a
bunker for the slipgate. Raised in e2m1's own palette.

- `InstallationDock`: the start. A dock either side of a canal, a control
  deck at its far end up a stair.
- `FloodedTunnels`: a tunnel under water most of its length, a wall down
  into the water across it to dive under; fish in it.
- `PumpingStation`: a tall hall, machinery in a pit in its middle, a
  catwalk round its walls ridden up to by lifts; ways on from the floor
  and the catwalk (a hub).
- `KeyLab`: the key on an island in a pool of slime, a bridge to it drawn
  out by a button shot; taking it opens the closets in the wall.
- `SlipgateBunker`: the end. A stair down into a bunker, the slipgate at
  its foot; as a gate, a key door at the stair's head."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E2M1: str = "q1:e2m1";

"""e2m1's foes: grunts and dogs, enforcers growing with the danger."""
def e2m1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_enforcer", "monster_army"] if heavy else ["monster_army", "monster_army", "monster_dog"], ["monster_enforcer"], danger));
}

"""The start: a dock either side of a canal, a control deck up a stair."""
node InstallationDock(Prefab) {
    has deck: int = 5,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation dock";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(12, 14);
        self.deck = dice.between(5, 6);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 6), floor=0), Port(face=1, along=float(self.long - 5), floor=self.deck)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        dock = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(dock, self.deck);
        # The canal down the middle, from past the near end to short of the far.
        build.pool(7, middle - 1, -4, self.long - 3, middle + 2, 0, 2);
        # Steps up out of it at its far end too, past the footbridge.
        stair(build, self.long - 7, middle - 1, -4, 0, 4, 2);
        # A footbridge over it near the start.
        build.solid(10, middle - 1, -1, 12, middle + 2, 0);
        # The control deck along the far end's north side, a stair up to it.
        deck_x = self.long - 10;
        deck_y = self.wide - 5;
        build.solid(deck_x, deck_y, 0, self.long - 1, self.wide - 1, self.deck);
        stair(build, deck_x - self.deck, deck_y, 0, 0, self.deck, 2);
        for y in [deck_y, deck_y + 1] {
            build.keep(dock, deck_x, y, self.deck);
        }
        build.doorway(dock, self.enter);
        for port in self.taken {
            build.doorway(dock, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(14 + index * 4) + 0.5, 3.5 + float(index % 2) * 2.0, 0, e2m1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, self.deck, e2m1_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.deck, "item_health");
    }
}

"""A tunnel under water most of its length, a wall down into the water
across it to dive under."""
node FloodedTunnels(Prefab) {
    has deep: int = 7,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded tunnels";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(12, 14);
        self.tall = dice.between(11, 13);
        self.deep = dice.between(6, 7);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 5;
        x1 = self.long - 5;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2);
        # The far shore's steps up out of the water, climbing east.
        stair(build, x1 - self.deep, 1, -self.deep, 0, self.deep, 2);
        # The wall across, down into the water: under it is the way on.
        build.solid(10, 1, -1, 11, self.wide - 1, self.tall);
        # Pipes along the walls over the water.
        for x in range(14, x1 - 1, 4) {
            build.solid(x, self.wide - 2, 0, x + 1, self.wide - 1, self.tall);
        }
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(13 + index * 6) + 0.5, float(self.wide // 2) + 0.5, -self.deep + 1, "monster_fish", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 1.5, 2.5 + float(index) * 3.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A tall hall, machinery in a pit in its middle, a catwalk round its walls
ridden up to by lifts; ways on from the floor and the catwalk."""
node PumpingStation(Prefab) {
    has walk: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pumping station";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(19, 22);
        self.walk = dice.between(8, 9);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, -4);
        build.level(hall, self.walk);
        # The pit, four lifts down, a stair down into it at each end.
        build.widen(hall, 8, 7, -4, self.long - 8, self.wide - 7, 0);
        stair(build, 11, middle - 1, -4, 2, 4, 3);
        stair(build, self.long - 12, middle - 1, -4, 0, 4, 3);
        pillars(build, 9, 8, self.long - 9, self.wide - 8, -4, 3, 3, [[10, middle - 2, 13, middle + 3], [self.long - 13, middle - 2, self.long - 9, middle + 3]]);
        # The catwalk round the walls, a lift thick, three cells wide.
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(1, 4, under, 4, self.wide - 4, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        # Lifts up to it in two corners, waiting at their feet.
        step = kit_of(build.district).step;
        for corner in [[4, 4], [self.long - 6, self.wide - 6]] {
            build.put_box({"classname": "func_plat", "height": str(self.walk * 16), "speed": "200"}, float(corner[0]), float(corner[1]), float(self.walk) - 0.5, float(corner[0] + 2), float(corner[1] + 2), float(self.walk), step);
            for x in range(corner[0] - 1, corner[0] + 3) {
                for y in range(corner[1] - 1, corner[1] + 3) {
                    build.keep(hall, x, y, self.walk);
                }
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(middle) - 3.5, -4, e2m1_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 7) + 0.5, float(self.wide) - 2.5, self.walk, e2m1_foe(dice, self.danger, True), 270.0);
        }
        build.foe(float(self.long) - 5.5, 5.5, 0, e2m1_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(self.wide) - 2.5, self.walk, "item_health");
        build.supply(float(self.long // 2) + 0.5, float(middle) + 0.5, -4, "item_shells");
        build.supply(float(self.long) - 2.5, 2.5, self.walk, "item_armor1");
    }
}

"""The key on an island in a pool of slime, a bridge to it drawn out by a
button shot; taking it opens the closets in the far wall."""
node KeyLab(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key lab (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        lab = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(lab, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -3, x1, side - 2, 0, 3);
        cx = (x0 + x1) // 2;
        cy = side // 2;
        build.solid(cx - 1, cy - 1, -3, cx + 2, cy + 2, 0);
        # The bridge from the near shore out to the island, drawn out when
        # the button on the near wall is shot.
        span = build.name("span");
        build.bridge(float(x0), float(cy - 1), float(cx - 1), float(cy + 2), 0, 4, span);
        build.button(1.0, float(cy - 4) + 0.5, 2.0, 0, span, True);
        for y in range(cy - 1, cy + 2) {
            build.keep(lab, x0 - 1, y, 0);
        }
        key_ambush(build, self.key, float(cx) + 0.5, float(cy) + 0.5, 0, side, 0, [3, self.long - 6], [e2m1_foe(dice, self.danger, True), e2m1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, e2m1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a stair down into a bunker, the slipgate at its foot; as a
gate, a key door at the stair's head."""
node SlipgateBunker(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slipgate bunker" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M1;
        self.district = level_district(E2M1);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(12, 14);
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = self.long - 11;
        hall = build.room(1, 1, 0, wall, self.wide - 1, self.tall, variant=dice.below(3));
        bunker = build.room(wall + 1, 1, -4, self.long - 1, self.wide - 1, self.tall - 2, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(bunker, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        stair(build, wall + 4, middle - 2, -4, 2, 4, 4);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        pillars(build, 3, 3, wall - 1, self.wide - 3, 0, self.tall, 4, [[0, middle - 3, 4, middle + 3], [wall - 4, middle - 3, wall, middle + 3]]);
        build.way_out(float(self.long) - 4.0, float(middle), -4);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m1_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * (float(self.wide) - 5.0), -4, e2m1_foe(dice, self.danger, True), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m1's stretches: [name, role]."""
glob E2M1_STRETCHES: list[list[str]] = [
         ["dock", "start"],
         ["tunnels", "flow"],
         ["station", "hub"],
         ["station", "flow"],
         ["lab", "keyroom"],
         ["bunker", "end"],
         ["bunker", "gate"]
     ];

"""One of e2m1's stretches by its name."""
def make_e2m1(name: str, key: str) -> Prefab {
    if name == "dock" {
        return InstallationDock();
    }
    if name == "tunnels" {
        return FloodedTunnels();
    }
    if name == "station" {
        return PumpingStation();
    }
    if name == "lab" {
        return KeyLab(key=key if key else "key_silver");
    }
    return SlipgateBunker(key=key);
}
