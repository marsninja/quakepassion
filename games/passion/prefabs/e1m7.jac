"""Prefabs drawn from e1m7, the House of Chthon: ledges along a lava
cavern, pillars of stone to leap across a lava lake, and the arena where
Chthon rises (here its shamblers wait instead). Raised in e1m7's own
palette. e1m7 holds no keys, so it gives no key room or gate.

- `ChthonApproach`: the start. A ledge along a cavern's wall stepping down
  toward a lava floor, a stone shelf at its foot.
- `LavaPillars`: a lava lake crossed by leaping from pillar to pillar of
  stone, a cell apart, a ledge round its far side; scrags over it.
- `ChthonArena`: the end. A great pit of lava, a ring of stone round it,
  an island in its middle; shooting the button over the far ledge draws a
  bridge up out of the lava to the way out there."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, stalactites }

glob E1M7: str = "q1:e1m7";

"""e1m7's foes: zombies, and shamblers where it matters."""
def e1m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    if heavy {
        return "monster_shambler";
    }
    return q1_foe(dice, q1_palette(["monster_zombie", "monster_zombie", "monster_knight"], ["monster_ogre"], danger));
}

"""The start: a ledge along a cavern's wall stepping down toward lava."""
node ChthonApproach(Prefab) {
    has top: int = 10,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon approach";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.top = dice.between(9, 11);
        self.tall = self.top + dice.between(10, 12);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=self.top);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, self.top);
        # The lava floor, the shelf at the far end.
        build.pool(1, 5, -3, self.long - 6, self.wide - 1, 0, 4, False, False);
        stair(build, self.long - 9, 5, -3, 0, 3, 2);
        # The ledge along the near wall, four cells deep, stepping down a
        # lift every two cells from the top to the floor.
        x = 1;
        lift = self.top;
        while lift > 0 and x < self.long - 6 {
            build.solid(x, 1, 0, min(self.long - 6, x + 2), 5, lift);
            x += 2;
            lift -= 1;
        }
        build.solid(x, 1, 0, self.long - 6, 5, max(lift, 0));
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        stalactites(build, dice, 3, 5, self.long - 6, self.wide - 2, self.tall, dice.between(6, 10));
        build.start(2.5, 3.0, self.top, 0.0);
        build.supply(2.5, 2.0, self.top, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 3.5, 0, e1m7_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A lava lake crossed by leaping from pillar to pillar, a ledge round its
far side."""
node LavaPillars(Prefab) {
    has shore: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava pillars";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(16, 20);
        self.low = -4;
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
        lava_x0 = 1 + self.shore;
        lava_x1 = self.long - 1 - self.shore;
        build.pool(lava_x0, 1, -3, lava_x1, self.wide - 1, 0, 4);
        # Pillars two cells square, two cells apart, wandering across.
        # A cell's leap between pillars (over lava a leap must be sure).
        x = lava_x0 + 1;
        y = middle - 1;
        while x + 2 <= lava_x1 - 1 {
            build.solid(x, y, -3, x + 2, y + 2, 0);
            x += 3;
            y = max(3, min(self.wide - 5, y + dice.between(-1, 1)));
        }
        if x - 3 + 2 < lava_x1 - 1 {
            build.solid(lava_x1 - 3, y, -3, lava_x1 - 1, y + 2, 0);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        stalactites(build, dice, lava_x0, 2, lava_x1, self.wide - 2, self.tall, dice.between(8, 12));
        for index in range(dice.between(1, 2)) {
            build.foe(float(lava_x0 + 4 + index * 6) + 0.5, float(middle) + 3.5, 6, "monster_wizard", 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(lava_x1) + 2.5, 3.5 + float(index) * 4.5, 0, e1m7_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_cells");
    }
}

"""The end: a great lava pit, a ring of stone round it, an island in its
middle; a shot button over the far ledge draws the bridge to the way out."""
node ChthonArena(Prefab) {
    has ring: int = 4,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon arena";
        self.source = E1M7;
        self.district = level_district(E1M7);
        self.long = dice.between(30, 34);
        self.wide = dice.between(26, 30);
        self.tall = dice.between(24, 28);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(arena, self.enter);
        # The lava pit inside the ring, the island in its middle, the far
        # ledge with the way out across from the near ring.
        pit_x0 = 1 + self.ring;
        pit_x1 = self.long - 1 - self.ring - 4;
        build.pool(pit_x0, 1 + self.ring, -3, pit_x1, self.wide - 1 - self.ring, 0, 4);
        cx = (pit_x0 + pit_x1) // 2;
        # The island short along the bridges' line (three cells), wide across.
        build.solid(cx - 1, middle - 4, -3, cx + 2, middle + 4, 1);
        # The far ledge: the ring's east side widened, two lifts up, steps up
        # to it from the ring at its ends; the bridge across to it.
        ledge_x = pit_x1;
        build.solid(ledge_x, 1, 0, self.long - 1, self.wide - 1, 2);
        build.solid(ledge_x - 1, 1, 0, ledge_x, 1 + self.ring, 1);
        build.solid(ledge_x - 1, self.wide - 1 - self.ring, 0, ledge_x, self.wide - 1, 1);
        bridge = build.name("bridge");
        build.bridge(float(cx + 2), float(middle - 1), float(ledge_x), float(middle + 2), 1, 5, bridge);
        build.bridge(float(pit_x0), float(middle - 1), float(cx - 1), float(middle + 2), 1, 5, bridge);
        build.solid(pit_x0 - 1, middle - 1, 0, pit_x0, middle + 2, 1);
        for y in range(middle - 1, middle + 2) {
            build.keep(arena, pit_x0 - 1, y, 1);
            build.keep(arena, cx - 1, y, 1);
            build.keep(arena, cx + 1, y, 1);
            build.keep(arena, ledge_x, y, 2);
        }
        build.button(float(self.long - 1), float(middle) + 5.5, 8.0, 2, bridge, True);
        build.way_out(float(self.long) - 4.0, float(middle), 2);
        for index in range(1 if self.danger < 0.5 else 2) {
            build.foe(float(cx) + 0.5, float(middle) + 0.5 + float(index) * 2.0, 1, e1m7_foe(dice, self.danger, True), 180.0);
        }
        # What the shamblers want: a rocket launcher and rockets at the mouth.
        build.supply(3.5, float(middle) + 0.5, 0, "weapon_rocketlauncher");
        build.supply(3.5, float(middle) + 2.5, 0, "item_rockets");
        build.supply(3.5, float(middle) - 1.5, 0, "item_rockets");
        for index in range(dice.between(2, 3)) {
            build.foe(3.0, 3.5 + float(index) * 6.0, 0, e1m7_foe(dice, self.danger), 0.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_cells");
        build.supply(float(self.long) - 2.5, 2.5, 2, "item_armor2");
    }
}

"""e1m7's stretches: [name, role]."""
glob E1M7_STRETCHES: list[list[str]] = [["approach", "start"], ["pillars", "flow"], ["arena", "end"]];

"""One of e1m7's stretches by its name."""
def make_e1m7(name: str, key: str) -> Prefab {
    if name == "approach" {
        return ChthonApproach();
    }
    if name == "pillars" {
        return LavaPillars();
    }
    return ChthonArena();
}
