"""Prefabs drawn from e4m7, Azure Agony: blue halls drowned in water, a
lagoon ringed by a walkway, rooms joined only by a flooded tube swum
through, a cistern of ledges and galleries over deep water, the silver
key on an island. Raised in e4m7's own palette.

- `AzureLagoon`: the start. A lagoon in a hall, a walkway round it, rocks
  standing in it; ways on round the walkway.
- `DrownedPassage`: two rooms joined only by a tube full of water, swum
  through end to end.
- `AzureCistern`: deep water ringed by a ledge, lifts up from the ledge to
  galleries on two walls; ways on from the ledge and the galleries (a
  hub).
- `AzureIsle`: the key on an island in deep water, steps up onto it from
  the water; taking it opens the closets on the shore.
- `AzureExit`: the end. A door (a key's, as a gate) into a hall, the
  slipgate at the end of a pier over water."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush }

glob E4M7: str = "q1:e4m7";

"""e4m7's foes: spawn and vores, fiends and hell knights, a shambler
deeper in."""
def e4m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_demon1", "monster_hell_knight"] if heavy else ["monster_tarbaby", "monster_zombie", "monster_zombie"], ["monster_shalrath", "monster_shambler"] if heavy else ["monster_hell_knight"], danger * 0.3 if heavy else danger * 0.7));
}

"""The start: a lagoon in a hall, a walkway round it, rocks in it."""
node AzureLagoon(Prefab) {
    has deep: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure lagoon";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(5, 6);
        self.tall = dice.between(14, 16);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 6;
        x1 = self.long - 6;
        build.pool(x0, 4, -self.deep, x1, self.wide - 4, 0, 2, False, True, True);
        stair(build, x1 - self.deep, 4, -self.deep, 0, self.deep, 2);
        for rock in [[x0 + 5, middle - 1], [x1 - 7, middle]] {
            build.solid(rock[0], rock[1], -self.deep, rock[0] + 2, rock[1] + 2, 2);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 3.5 + float(index) * 5.0, 0, e4m7_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 6) + 0.5, float(middle) + 3.5, -self.deep + 1, "monster_fish", 0.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""Two rooms joined only by a tube full of water, swum through."""
node DrownedPassage(Prefab) {
    has tube: int = 5,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drowned passage";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(24, 28);
        self.wide = dice.between(14, 16);
        self.tube = dice.between(4, 5);
        self.tall = dice.between(11, 13);
        self.low = -2;
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
        near = 8;
        far = self.long - 8;
        first = build.room(1, 1, 0, near, self.wide - 1, self.tall, variant=dice.below(3));
        second = build.room(far, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(near, middle - 2, -1, far, middle + 2, self.tube, 2, True, False);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(second, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(near + 3 + index * 4) + 0.5, float(middle) + 0.5, 0, "monster_fish", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(far) + 3.5, 2.5 + float(index) * 4.0, 0, e4m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(3.5, float(self.wide) - 3.5, 0, e4m7_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""Deep water ringed by a ledge, lifts up from the ledge to galleries on
two walls."""
node AzureCistern(Prefab) {
    has deep: int = 7,
        gallery: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure cistern";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(6, 7);
        self.gallery = dice.between(8, 9);
        self.tall = self.gallery + 10;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        cistern = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cistern, self.gallery);
        build.pool(6, 6, -self.deep, self.long - 6, self.wide - 6, 0, 2, False, True, True);
        stair(build, self.long - 6 - self.deep, 6, -self.deep, 0, self.deep, 2);
        under = self.gallery - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(self.long - 4, 1, under, self.long - 1, self.wide - 4, self.gallery);
        step = kit_of(build.district).step;
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, 2.0, float(self.wide - 7), float(self.gallery) - 0.5, 5.0, float(self.wide - 4), float(self.gallery), step);
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, float(self.long - 7), 2.0, float(self.gallery) - 0.5, float(self.long - 4), 5.0, float(self.gallery), step);
        for x in range(1, 6) {
            build.keep(cistern, x, self.wide - 4, self.gallery);
        }
        for y in range(1, 6) {
            build.keep(cistern, self.long - 4, y, self.gallery);
        }
        build.doorway(cistern, self.enter);
        for port in self.taken {
            build.doorway(cistern, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, 7.5 + float(index) * 3.0, 0, e4m7_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.gallery, e4m7_foe(dice, self.danger, True), 270.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, -self.deep + 1, "monster_fish", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The key on an island in deep water, steps up onto it; taking it opens
the closets on the shore."""
node AzureIsle(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure isle (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
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
        x0 = 6;
        build.pool(x0, 1, -self.deep, self.long - 1, side, 0, 2);
        ix = self.long - 6;
        build.solid(ix - 2, cy - 2, -self.deep, ix + 2, cy + 2, 0);
        stair(build, ix - 2 - self.deep, cy - 1, -self.deep, 0, self.deep, 2);
        key_ambush(build, self.key, float(ix), float(cy), 0, side, 0, [1], [e4m7_foe(dice, self.danger, True)]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 4) + 0.5, float(cy) + 3.5, -self.deep + 1, "monster_fish", 0.0);
        }
        build.foe(3.0, 2.5, 0, e4m7_foe(dice, self.danger), 0.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a hall, the slipgate at the end of a pier over
water."""
node AzureExit(Prefab) {
    has key: str = "",
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(12, 14);
        self.low = -6;
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
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        x0 = wall + 3;
        build.pool(x0, 1, -5, self.long - 1, self.wide - 1, 0, 2, False, True, True);
        build.solid(x0, middle - 1, -5, self.long - 3, middle + 1, 0);
        build.solid(self.long - 5, middle - 2, -5, self.long - 1, middle + 2, 0);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 3.5, 3.5, -4, "monster_fish", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m7's stretches: [name, role]."""
glob E4M7_STRETCHES: list[list[str]] = [
         ["lagoon", "start"],
         ["drowned", "flow"],
         ["cistern", "hub"],
         ["cistern", "flow"],
         ["isle", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m7's stretches by its name."""
def make_e4m7(name: str, key: str) -> Prefab {
    if name == "lagoon" {
        return AzureLagoon();
    }
    if name == "drowned" {
        return DrownedPassage();
    }
    if name == "cistern" {
        return AzureCistern();
    }
    if name == "isle" {
        return AzureIsle(key=key if key else "key_silver");
    }
    return AzureExit(key=key);
}
