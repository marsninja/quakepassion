"""Prefabs drawn from e4m5, Hell's Atrium: an atrium under the sky ringed by
columns round a fountain, a stair climbing in two flights about a
landing, a hall ringed by a gallery up a broad stair, the key on an
island of lava a drawbridge reaches. Raised in e4m5's own palette.

- `AtriumCourt`: the start. A court under the sky, a fountain in its
  middle, a ring of columns round it; ways on from three sides.
- `AtriumStairs`: a stair climbing in two flights, the first along one
  side to a landing, the second back along the other to a floor high over
  the way in; ways on from the landing and the top.
- `AtriumHall`: a hall ringed by a gallery, a broad stair up to it; ways
  on from the gallery and the floor (a hub).
- `LavaIsle`: the key on an island in lava, a drawbridge to it let down by
  shooting a button; taking the key opens the closets.
- `AtriumExit`: the end. A door (a key's, as a gate) into a court, the
  slipgate in the fountain's basin."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E4M5: str = "q1:e4m5";

"""e4m5's foes: the dead and spawn, fiends, hell knights and vores deeper
in."""
def e4m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_demon1"] if heavy else ["monster_zombie", "monster_zombie", "monster_tarbaby"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""The start: a court, a fountain, a ring of columns round it."""
node AtriumCourt(Prefab) {
    has tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium court";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 28);
        self.tall = dice.between(18, 22);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.pool(cx - 3, cy - 3, -3, cx + 3, cy + 3, 0, 2);
        build.solid(cx - 1, cy, -3, cx, cy + 1, 5);
        # The ring of columns, a gap in it before each way on.
        for x in range(cx - 7, cx + 8, 2) {
            for y in [cy - 7, cy + 7] {
                if abs(x - cx) > 2 {
                    build.solid(x, y, 0, x + 1, y + 1, 10);
                }
            }
        }
        for y in range(cy - 5, cy + 6, 2) {
            for x in [cx - 7, cx + 7] {
                if abs(y - cy) > 2 {
                    build.solid(x, y, 0, x + 1, y + 1, 10);
                }
            }
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "item_shells");
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx + 9) + 0.5, 3.5 + float(index) * 5.0, 0, e4m5_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 4.5, float(cy) + 4.5, 0, e4m5_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""A stair climbing in two flights about a landing to a floor high over the
way in."""
node AtriumStairs(Prefab) {
    has flight: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium stairs";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(20, 22);
        self.wide = dice.between(14, 16);
        self.flight = dice.between(4, 5);
        self.tall = 2 * self.flight + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle // 2) + 1.0, floor=0);
        self.leaves = [Port(face=1, along=4.0, floor=2 * self.flight), Port(face=0, along=float(self.wide // 2), floor=self.flight)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        top = 2 * self.flight;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.flight);
        build.level(hall, top);
        # The first flight along the south half, climbing east to the
        # landing across the far end.
        lx = 8 + self.flight;
        build.solid(lx, 1, 0, self.long - 1, self.wide - 1, self.flight);
        stair(build, lx - self.flight, 1, 0, 0, self.flight, middle - 1);
        # The second flight back along the north half from the landing to
        # the top floor over the near end's north half.
        build.solid(1, middle, 0, lx - self.flight, self.wide - 1, top);
        stair(build, lx - 1, middle, self.flight, 2, self.flight, self.wide - 1 - middle);
        for y in range(1, middle) {
            build.keep(hall, lx, y, self.flight);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 4.0, self.flight, e4m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(3.5, float(self.wide) - 3.0, top, e4m5_foe(dice, self.danger), 0.0);
        build.supply(3.5, float(middle) + 2.0, top, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A hall ringed by a gallery, a broad stair up to it."""
node AtriumHall(Prefab) {
    has gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium hall";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.gallery);
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.gallery);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(1, 4, under, 4, self.wide - 4, self.gallery);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.gallery);
        stair(build, self.long - 4 - self.gallery, middle - 3, 0, 0, self.gallery, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(hall, self.long - 4, y, self.gallery);
        }
        clear = [[0, middle - 3, 6, middle + 3], [self.long - 6 - self.gallery, middle - 4, self.long, middle + 4], [2, self.wide - 6, 7, self.wide]];
        pillars(build, 6, 6, self.long - 5, self.wide - 5, 0, under, 5, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.5), 0, e4m5_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, self.gallery, e4m5_foe(dice, self.danger, True), 180.0);
        }
        build.supply(2.5, 2.5, self.gallery, "item_health");
        build.supply(float(self.long) - 6.5, float(middle) - 5.5, 0, "item_rockets");
    }
}

"""The key on an island in lava, a drawbridge to it let down by shooting a
button; taking the key opens the closets."""
node LavaIsle(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava isle (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M5;
        self.district = level_district(E4M5);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -3, x1, side - 2, 0, 4, False, False);
        cx = (x0 + x1) // 2;
        cy = side // 2;
        build.solid(cx - 1, cy - 1, -3, cx + 2, cy + 2, 0);
        span = build.name("span");
        build.bridge(float(x0), float(cy - 1), float(cx - 1), float(cy + 2), 0, 4, span);
        build.button(1.0, float(cy - 4) + 0.5, 2.0, 0, span, True);
        for y in range(cy - 1, cy + 2) {
            build.keep(hall, x0 - 1, y, 0);
        }
        key_ambush(build, self.key, float(cx) + 0.5, float(cy) + 0.5, 0, side, 0, [2], [e4m5_foe(dice, self.danger, True)]);
        build.foe(float(self.long) - 2.5, 2.0, 0, e4m5_foe(dice, self.danger), 180.0);
        build.foe(3.0, 2.5, 0, "monster_zombie", 0.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a court, the slipgate in the fountain's basin."""
node AtriumExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(15, 17);
        self.low = -3;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        court = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, -2);
        build.doorway(hall, self.enter);
        build.widen(court, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The basin, dry now, two steps down all round its near side.
        bx = self.long - 9;
        build.widen(court, bx, middle - 4, -2, self.long - 3, middle + 4, 0);
        stair(build, bx + 1, middle - 4, -2, 2, 2, 8);
        build.way_out(float(self.long) - 5.5, float(middle), -2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(bx) - 2.5, 2.5, 0, e4m5_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m5's stretches: [name, role]."""
glob E4M5_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["stairs", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["isle", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m5's stretches by its name."""
def make_e4m5(name: str, key: str) -> Prefab {
    if name == "court" {
        return AtriumCourt();
    }
    if name == "stairs" {
        return AtriumStairs();
    }
    if name == "hall" {
        return AtriumHall();
    }
    if name == "isle" {
        return LavaIsle(key=key if key else "key_gold");
    }
    return AtriumExit(key=key);
}
