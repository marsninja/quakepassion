"""Prefabs drawn from e2m7, Underearth: caves deep under the earth and halls
cut into them, buttons shot to open the ways on, a river of lava crossed
by a span of rock or stone by stone, the gold key in a cage opened by a
button high on a wall. Raised in e2m7's own palette.

- `UnderearthCave`: the start. A cave, boulders and stalactites, a shelf
  of rock up a stair at its far end; ways on from the floor and the shelf.
- `ButtonGallery`: a long hall, its ways on shut until three buttons high
  on its walls are shot.
- `LavaRiver`: a cave, a river of lava across it crossed by a span of rock
  or by stones a jump apart, a shelf up on the far side; ways on from the
  far side and the shelf (a hub).
- `CagedKey`: the key in a cage at a hall's far end, opened by shooting a
  button high on the wall; taking it opens the closets.
- `UnderearthExit`: the end. A cave, a ramp of rock up to the slipgate on
  a shelf; as a gate, a key door at the ramp's foot."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, boulders, stalactites, key_ambush }

glob E2M7: str = "q1:e2m7";

"""e2m7's foes: the dead and ogres, scrags, hell knights deeper in."""
def e2m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_zombie", "monster_ogre", "monster_wizard"], ["monster_demon1"] if heavy else ["monster_hell_knight"], danger));
}

"""The start: a cave, a shelf of rock up a stair at its far end."""
node UnderearthCave(Prefab) {
    has shelf: int = 5,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Underearth cave";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(22, 26);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(14, 16);
        self.shelf = dice.between(4, 6);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.shelf), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.shelf);
        sx = self.long - 7;
        build.solid(sx, 1, 0, self.long - 1, self.wide - 1, self.shelf);
        stair(build, sx - self.shelf, middle - 2, 0, 0, self.shelf, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(cave, sx, y, self.shelf);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        clear = [[0, middle - 3, 5, middle + 3], [sx - self.shelf - 1, middle - 3, sx, middle + 3], [self.long // 2 - 3, 0, self.long // 2 + 3, 4], [self.long // 2 - 3, self.wide - 4, self.long // 2 + 3, self.wide]];
        boulders(build, dice, 1, 1, sx, self.wide - 1, 0, dice.between(4, 7), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(5, 8));
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx) - 5.5 + float(index) * 2.0, 3.5 + float(index) * 4.0, 0, e2m7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.shelf, e2m7_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.shelf, "item_health");
    }
}

"""A long hall, its ways on shut until three buttons high on its walls are
shot."""
node ButtonGallery(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Button gallery";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(12, 14);
        self.tall = dice.between(13, 15);
        self.low = -1;
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # Buttresses down both walls.
        for x in range(4, self.long - 4, 4) {
            build.solid(x, 1, 0, x + 1, 2, self.tall);
            build.solid(x, self.wide - 2, 0, x + 1, self.wide - 1, self.tall);
        }
        count = build.name("count");
        out = build.name("out");
        # The buttons, high on the walls between the buttresses, alternating
        # sides down the hall.
        spots = [[6, 0], [self.long // 2, 1], [self.long - 7, 0]];
        for spot in spots {
            along = float(spot[0] + (1 if spot[0] % 4 == 0 else 0)) + 0.5;
            if spot[1] == 0 {
                build.button(along, 1.0, 8.0, 1, count, True);
            } else {
                build.button(along, float(self.wide - 1), 8.0, 3, count, True);
            }
        }
        build.counter(2.5, 2.5, 0, count, len(spots), out, "The way on is open");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            low = port.along - float(port.wide) * 0.5;
            high = port.along + float(port.wide) * 0.5;
            fields = {"targetname": out, "wait": "-1"};
            if port.face == 0 {
                build.rising_door(float(self.long - 1), low, 0.0, float(self.long), high, float(port.high), fields);
            } elif port.face == 1 {
                build.rising_door(low, float(self.wide - 1), 0.0, high, float(self.wide), float(port.high), fields);
            } else {
                build.rising_door(low, 0.0, 0.0, high, 1.0, float(port.high), fields);
            }
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + (1.5 if index % 2 == 0 else -1.5), 0, e2m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 7, "monster_wizard", 180.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_spikes");
        build.supply(float(self.long) - 3.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""A cave, a river of lava across it crossed by a span of rock or by stones
a jump apart, a shelf up on the far side."""
node LavaRiver(Prefab) {
    has shelf: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava river";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(16, 20);
        self.shelf = dice.between(5, 6);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=self.shelf),
            Port(face=3, along=float(self.long - 5), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=self.shelf)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.shelf);
        # The river across the cave, five cells wide.
        rx = 11;
        build.pool(rx, 1, -3, rx + 5, self.wide - 1, 0, 4, False, False);
        # The span of rock across it on the south half, the stones on the
        # north: a cell of lava between each stone and the next.
        build.solid(rx, 3, -3, rx + 5, 6, 0);
        for at in [rx + 1, rx + 3] {
            build.solid(at, self.wide - 6, -3, at + 1, self.wide - 4, 0);
        }
        for y in range(3, 6) {
            build.keep(cave, rx - 1, y, 0);
            build.keep(cave, rx + 5, y, 0);
        }
        # The shelf along the far end's north side, a stair up to its face.
        sx = self.long - 8;
        sy = self.wide - 7;
        build.solid(sx, sy, 0, self.long - 1, self.wide - 1, self.shelf);
        stair(build, sx, sy - self.shelf, 0, 1, self.shelf, 3);
        for x in range(sx, sx + 3) {
            build.keep(cave, x, sy, self.shelf);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(6, 10));
        for index in range(dice.between(2, 3)) {
            build.foe(float(rx + 8 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, e2m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(rx) + 2.5, float(middle) + 0.5, 6, "monster_wizard", 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, self.shelf, e2m7_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.0, self.shelf, "item_health");
        build.supply(3.5, 3.5, 0, "item_spikes");
    }
}

"""The key in a cage at a hall's far end, opened by shooting a button high
on the wall; taking it opens the closets."""
node CagedKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Caged key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
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
        cy = side // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The cage: walls round the far end's middle, a door across its
        # front that a button high on the near wall opens.
        cx = self.long - 5;
        build.solid(cx, cy - 3, 0, cx + 1, cy - 2, 7);
        build.solid(cx, cy + 2, 0, cx + 1, cy + 3, 7);
        build.solid(cx + 1, cy - 3, 0, self.long - 1, cy - 2, 7);
        build.solid(cx + 1, cy + 2, 0, self.long - 1, cy + 3, 7);
        build.solid(cx, cy - 3, 6, self.long - 1, cy + 3, self.tall);
        cage = build.name("cage");
        build.rising_door(float(cx), float(cy - 2), 0.0, float(cx + 1), float(cy + 2), 6.0, {"targetname": cage, "wait": "-1"});
        build.button(1.0, float(cy) + 3.5, 8.0, 0, cage, True);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [3, cx - 5], [e2m7_foe(dice, self.danger, True), e2m7_foe(dice, self.danger)]);
        build.foe(float(cx) - 2.5, 2.5, 0, e2m7_foe(dice, self.danger), 180.0);
        build.foe(float(cx) - 4.5, float(cy) + 0.5, 8, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a cave, a ramp of rock up to the slipgate on a shelf; as a
gate, a key door at the ramp's foot."""
node UnderearthExit(Prefab) {
    has key: str = "",
        shelf: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Underearth exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M7;
        self.district = level_district(E2M7);
        self.long = dice.between(22, 26);
        self.wide = dice.between(14, 18);
        self.tall = dice.between(15, 17);
        self.shelf = dice.between(5, 7);
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
        sx = self.long - 7;
        build.solid(sx, 1, 0, self.long - 1, self.wide - 1, self.shelf);
        # The ramp up along the south wall, a wall across the cave before
        # it with the way to the ramp's foot.
        wall = sx - self.shelf - 3;
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 8, wall + 1, middle + 2, self.tall);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        stair(build, sx - self.shelf, 1, 0, 0, self.shelf, 3);
        for y in range(1, 4) {
            build.keep(cave, sx, y, self.shelf);
        }
        build.way_out(float(self.long) - 3.5, float(middle), self.shelf);
        clear = [[0, middle - 3, 5, middle + 3], [wall - 4, middle - 3, wall + 1, middle + 3]];
        boulders(build, dice, 1, 1, wall, self.wide - 1, 0, dice.between(3, 6), clear);
        stalactites(build, dice, 3, 3, self.long - 3, self.wide - 3, self.tall, dice.between(4, 7));
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, self.shelf, e2m7_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m7's stretches: [name, role]."""
glob E2M7_STRETCHES: list[list[str]] = [
         ["cave", "start"],
         ["buttons", "flow"],
         ["river", "hub"],
         ["river", "flow"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m7's stretches by its name."""
def make_e2m7(name: str, key: str) -> Prefab {
    if name == "cave" {
        return UnderearthCave();
    }
    if name == "buttons" {
        return ButtonGallery();
    }
    if name == "river" {
        return LavaRiver();
    }
    if name == "cage" {
        return CagedKey(key=key if key else "key_gold");
    }
    return UnderearthExit(key=key);
}
