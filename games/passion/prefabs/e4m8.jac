"""Prefabs drawn from e4m8, the Nameless City: a dead city under the sky,
streets between blocks of stone, terraces stepping down the slope it
stands on, a plaza round a building climbed by a stair winding up its
outside, the key on a roof reached by a lift. Raised in e4m8's own
palette.

- `CityStreet`: the start. A street between blocks of buildings, alleys
  between them, a plaza up steps at its far end; ways on from the plaza
  and the alleys.
- `CityTerraces`: terraces stepping down a slope one below another,
  buildings standing on them, stairs down between; ways on from the top
  terrace and the bottom.
- `NamelessPlaza`: a plaza round a building, a stair winding up its
  outside to the roof and a bridge from the roof to a way on high in the
  plaza's wall; ways on below too (a hub).
- `RooftopKey`: the key on a building's roof in a court, a lift up to it;
  taking it opens the closets.
- `CityExit`: the end. A door (a key's, as a gate) into a court, the
  slipgate in a temple up a stair."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, spiral, ring_landing }

glob E4M8: str = "q1:e4m8";

"""e4m8's foes: the dead above all, ogres and fiends, hell knights and a
shambler deeper in."""
def e4m8_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_demon1"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_hell_knight", "monster_shambler"] if heavy else ["monster_demon1"], danger * 0.5 if heavy else danger));
}

"""Blocks of buildings along both sides of a street between `x0` and `x1`,
`deep` cells deep, an alley between each and the next and one at `alley`
(x) left open on both sides."""
def city_blocks(build: Raising, dice: Stream, x0: int, x1: int, wide: int, deep: int, z: int, alley: int) {
    x = x0;
    while x + 4 <= x1 {
        span = dice.between(4, 6);
        end = min(x + span, x1);
        if end > alley - 3 and x < alley + 3 {
            x = alley + 3;
            continue;
        }
        build.solid(x, 1, z, end, 1 + deep, z + dice.between(6, 12));
        build.solid(x, wide - 1 - deep, z, end, wide - 1, z + dice.between(6, 12));
        x = end + 2;
    }
}

"""The start: a street between blocks, a plaza up steps at its far end."""
node CityStreet(Prefab) {
    has plaza: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City street";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(18, 22);
        self.plaza = dice.between(3, 4);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.plaza), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        street = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(street, self.plaza);
        px = self.long - 8;
        city_blocks(build, dice, 4, px - 1, self.wide, 5, 0, self.long // 2);
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.plaza);
        stair(build, px - self.plaza, middle - 3, 0, 0, self.plaza, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(street, px, y, self.plaza);
        }
        build.doorway(street, self.enter);
        for port in self.taken {
            build.doorway(street, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, e4m8_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.plaza, e4m8_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.plaza, "item_health");
    }
}

"""Terraces stepping down a slope one below another, buildings on them,
stairs down between."""
node CityTerraces(Prefab) {
    has drop: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City terraces";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.drop = dice.between(4, 5);
        self.tall = dice.between(13, 15);
        self.low = -2 * self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        bottom = -2 * self.drop;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=bottom), Port(face=3, along=float(self.long - 4), floor=bottom), Port(face=1, along=5.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bottom = -2 * self.drop;
        slope = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(slope, 0);
        build.level(slope, -self.drop);
        third = self.long // 3;
        build.solid(1, 1, bottom, third, self.wide - 1, 0);
        build.solid(third, 1, bottom, 2 * third, self.wide - 1, -self.drop);
        stair(build, third + self.drop - 1, middle - 2, -self.drop, 2, self.drop, 4);
        stair(build, 2 * third + self.drop - 1, 2, bottom, 2, self.drop, 3);
        # Buildings on the terraces, clear of the stairs' heads and feet.
        for (index, floor_at) in enumerate([0, -self.drop, bottom]) {
            x0 = index * third + (self.drop + 1 if index > 0 else 2);
            y0 = 2 if index == 0 else self.wide - 6;
            build.solid(x0, y0, floor_at, x0 + 4, y0 + 4, floor_at + dice.between(5, 8));
        }
        build.doorway(slope, self.enter);
        for port in self.taken {
            build.doorway(slope, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(2 * third + 4 + index * 3) + 0.5, float(middle) + 1.5, bottom, e4m8_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(third + self.drop + 3) + 0.5, float(middle) + 0.5, -self.drop, e4m8_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, bottom, "item_health");
        build.supply(float(third) - 2.5, 2.5, 0, "item_shells");
    }
}

"""A plaza round a building, a stair winding up its outside to the roof, a
bridge from the roof to a way on high in the plaza's wall."""
node NamelessPlaza(Prefab) {
    has steps: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless plaza";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        cx = self.long // 2;
        cy = self.wide // 2;
        fits: list[int] = [];
        for steps in range(8, 20) {
            landing = ring_landing(cx - 6, cy - 6, cx + 6, cy + 6, 2, steps, 3);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 12;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(cx - 6, cy - 6, cx + 6, cy + 6, 2, self.steps, 3);
        middle = float(cy);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps), Port(face=3, along=float(cx), floor=0), Port(face=1, along=float(cx), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        plaza = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(plaza, self.steps);
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.steps);
        landing = spiral(build, cx - 6, cy - 6, cx + 6, cy + 6, 0, self.steps, 2, 3);
        mid = landing[1];
        build.solid(mid[2], mid[1] - 3, self.steps - 1, self.long - 1, mid[1] + 4, self.steps);
        for y in range(mid[1] - 3, mid[1] + 4) {
            build.keep(plaza, mid[2] - 1, y, self.steps);
        }
        build.doorway(plaza, self.enter);
        for port in self.taken {
            build.doorway(plaza, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx + 8) + 0.5, 3.5 + float(index) * 5.0, 0, e4m8_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps, e4m8_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.steps, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""The key on a building's roof in a court, a lift up to it; taking it
opens the closets."""
node RooftopKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        roof: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rooftop key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.roof = dice.between(6, 8);
        self.tall = self.roof + 9;
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
        court = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.roof);
        build.doorway(court, self.enter);
        bx = self.long - 8;
        build.solid(bx, cy - 3, 0, self.long - 2, cy + 3, self.roof);
        build.put_box({"classname": "func_plat", "height": str(self.roof * 16), "speed": "200"}, float(bx - 3), float(cy - 1), float(self.roof) - 0.5, float(bx), float(cy + 2), float(self.roof), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(court, bx, y, self.roof);
        }
        key_ambush(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, self.roof, side, 0, [2, bx - 4], [e4m8_foe(dice, self.danger, True), "monster_zombie"]);
        build.foe(float(self.long) - 3.5, float(cy) - 2.0, self.roof, e4m8_foe(dice, self.danger), 180.0);
        build.foe(3.0, 2.5, 0, "monster_zombie", 0.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a court, the slipgate in a temple up a stair."""
node CityExit(Prefab) {
    has key: str = "",
        temple: int = 4,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.temple = dice.between(3, 5);
        self.tall = dice.between(16, 20);
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
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        court = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.temple);
        build.doorway(hall, self.enter);
        build.widen(court, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        tx = self.long - 7;
        build.solid(tx, 2, 0, self.long - 1, self.wide - 2, self.temple);
        stair(build, tx - self.temple, middle - 2, 0, 0, self.temple, 4);
        pillars(build, tx + 1, 3, self.long - 1, self.wide - 3, self.temple, self.temple + 8, 3, [[tx - 1, middle - 3, self.long, middle + 3]]);
        build.way_out(float(self.long) - 3.5, float(middle), self.temple);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m8_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(tx) - 5.5, 3.0, 0, e4m8_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m8's stretches: [name, role]."""
glob E4M8_STRETCHES: list[list[str]] = [
         ["street", "start"],
         ["terraces", "flow"],
         ["plaza", "hub"],
         ["plaza", "flow"],
         ["rooftop", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m8's stretches by its name."""
def make_e4m8(name: str, key: str) -> Prefab {
    if name == "street" {
        return CityStreet();
    }
    if name == "terraces" {
        return CityTerraces();
    }
    if name == "plaza" {
        return NamelessPlaza();
    }
    if name == "rooftop" {
        return RooftopKey(key=key if key else "key_gold");
    }
    return CityExit(key=key);
}
