"""Prefabs drawn from e3m7, the Haunted Halls: halls of wood and stone that
teleport a body about them, a foyer climbing to a gallery round three
walls, lifts and slime, a hall of pads up to balconies at many heights.
e3m7 holds no keys; its key room and gate are drawn from its crypts.
Raised in e3m7's own palette.

- `HauntedFoyer`: the start. A foyer, a grand stair up to a gallery round
  three of its walls; ways on from the floor and the gallery.
- `SlimeLifts`: a hall over a trench of slime, a lift up to a walkway
  across it and down the far side by stairs; a teleporter back.
- `PadGallery`: a hall of teleporters, each up to a balcony on a wall at
  its own height; ways on from the floor and every balcony (a hub).
- `HauntedCrypt`: a crypt below, the key on a tomb, a lift back up;
  taking the key opens the closets.
- `HauntedExit`: the end. A door (a key's, as a gate), a teleporter to a
  sealed chamber and the slipgate in it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M7: str = "q1:e3m7";

"""e3m7's foes: ogres and the dead, scrags, hell knights and vores deeper
in."""
def e3m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_zombie", "monster_zombie"], ["monster_shalrath"] if heavy else ["monster_wizard"], danger * 0.5 if heavy else danger));
}

"""The start: a foyer, a grand stair up to a gallery round three walls."""
node HauntedFoyer(Prefab) {
    has gallery: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted foyer";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.gallery), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        foyer = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(foyer, self.gallery);
        under = self.gallery - 1;
        # The gallery: along the north and east walls and the south wall's
        # far half, a slab a lift thick.
        build.solid(5, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(self.long - 5, 1, under, self.long - 1, self.wide - 4, self.gallery);
        build.solid(self.long // 2, 1, under, self.long - 5, 4, self.gallery);
        # The grand stair up the middle to the east gallery.
        sx = self.long - 5 - self.gallery;
        stair(build, sx, middle - 2, 0, 0, self.gallery, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(foyer, self.long - 5, y, self.gallery);
        }
        build.doorway(foyer, self.enter);
        for port in self.taken {
            build.doorway(foyer, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(sx) - 3.5, 4.5 + float(index) * 5.0, 0, e3m7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(self.wide) - 2.5, self.gallery, e3m7_foe(dice, self.danger, True), 180.0);
        build.foe(10.5, float(self.wide) - 2.5, self.gallery, e3m7_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 3.0, 2.5, self.gallery, "item_health");
    }
}

"""A hall over a trench of slime, a lift up to a walkway across it, stairs
down the far side; a teleporter back."""
node SlimeLifts(Prefab) {
    has walk: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime lifts";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(26, 28);
        self.wide = dice.between(14, 16);
        self.walk = dice.between(5, 6);
        self.tall = self.walk + 9;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The trench of slime across the middle.
        tx0 = 10;
        tx1 = 16;
        build.pool(tx0, 1, -3, tx1, self.wide - 1, 0, 3);
        stair(build, tx1 - 3, self.wide - 3, -3, 0, 3, 2);
        # The walkway over it from the lift's top to the far stair's.
        wx0 = tx0 - 3;
        wx1 = tx1 + 1;
        build.solid(wx0, middle - 1, self.walk - 1, wx1, middle + 2, self.walk);
        build.put_box({"classname": "func_plat", "height": str(self.walk * 16), "speed": "180"}, float(wx0 - 3), float(middle - 1), float(self.walk) - 0.5, float(wx0), float(middle + 2), float(self.walk), kit_of(build.district).step);
        stair(build, wx1 + self.walk - 1, middle - 1, 0, 2, self.walk, 3);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, wx0, y, self.walk);
        }
        build.teleporter(float(self.long) - 4.0, 3.0, 0, 3.0, 3.0, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(tx1) + 6.5 + float(index % 2) * 2.0, 3.5 + float(index) * 3.0, 0, e3m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(tx0 + tx1) * 0.5, float(middle) + 0.5, self.walk, e3m7_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A hall of teleporters, each up to a balcony on a wall at its own
height."""
node PadGallery(Prefab) {
    has north: int = 5,
        east: int = 9,
        south: int = 13,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pad gallery";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(24, 26);
        self.wide = dice.between(22, 24);
        self.north = dice.between(5, 6);
        self.east = self.north + dice.between(4, 5);
        self.south = self.east + dice.between(4, 5);
        self.tall = self.south + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.north),
            Port(face=0, along=middle, floor=self.east),
            Port(face=3, along=float(self.long // 2), floor=self.south),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        for z in [self.north, self.east, self.south] {
            build.level(hall, z);
        }
        # The balconies: north, east and south, each a slab at its height.
        build.solid(7, self.wide - 4, self.north - 1, self.long - 6, self.wide - 1, self.north);
        build.solid(self.long - 4, 6, self.east - 1, self.long - 1, self.wide - 6, self.east);
        build.solid(7, 1, self.south - 1, self.long - 6, 4, self.south);
        for x in range(8, self.long - 7) {
            build.keep(hall, x, self.wide - 4, self.north);
            build.keep(hall, x, 3, self.south);
        }
        for y in range(7, self.wide - 7) {
            build.keep(hall, self.long - 4, y, self.east);
        }
        # The pads, in a row across the floor's middle.
        build.teleporter(float(cx) - 4.0, float(cy) + 0.5, 0, float(cx) + 0.5, float(self.wide) - 2.5, self.north, 90.0);
        build.teleporter(float(cx), float(cy) + 0.5, 0, float(self.long) - 2.5, float(cy) + 0.5, self.east, 0.0);
        build.teleporter(float(cx) + 4.0, float(cy) + 0.5, 0, float(cx) + 0.5, 2.5, self.south, 270.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 3.0, float(cy) + 4.5, 0, e3m7_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 4.5, float(self.wide) - 2.5, self.north, e3m7_foe(dice, self.danger), 270.0);
        build.foe(float(self.long) - 2.5, float(cy) + 3.5, self.east, e3m7_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 8, "monster_wizard", 0.0);
        build.supply(float(cx) - 4.5, 2.5, self.south, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""A crypt below, the key on a tomb, a lift back up; taking the key opens
the closets."""
node HauntedCrypt(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted crypt (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(6, 7);
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
        low = -self.deep;
        crypt = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(crypt, 0);
        build.doorway(crypt, self.enter);
        # The landing in, the drop off it, and the lift back up.
        build.solid(1, 1, low, 6, side, 0);
        build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "200"}, 6.0, float(cy - 1), -0.5, 9.0, float(cy + 2), 0.0, kit_of(build.district).step);
        for y in range(2, side - 1) {
            build.keep(crypt, 5, y, 0);
        }
        build.solid(self.long - 6, cy - 1, low, self.long - 3, cy + 2, low + 2);
        pillars(build, 11, 3, self.long - 7, side - 2, low, self.tall, 4, [[9, cy - 2, self.long, cy + 3]]);
        key_ambush(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, low + 2, side, low, [10, self.long - 6], [e3m7_foe(dice, self.danger, True), "monster_zombie"]);
        build.foe(float(self.long) - 2.5, 2.5, low, e3m7_foe(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 3.5, low, "monster_zombie", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a teleporter to a sealed chamber, the slipgate in it."""
node HauntedExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(13, 15);
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
        sealed = self.long - 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, sealed, self.wide - 1, self.tall, variant=dice.below(3));
        chamber = build.room(sealed + 1, 1, 0, self.long - 1, self.wide - 1, 10, variant=dice.below(3));
        build.level(chamber, 0);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        build.teleporter(float(sealed) - 3.0, float(middle) + 0.5, 0, float(sealed) + 2.5, float(middle) + 0.5, 0, 0.0);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        pillars(build, wall + 3, 3, sealed - 4, self.wide - 3, 0, self.tall, 4, [[0, middle - 2, self.long, middle + 3]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(sealed) - 2.5, 2.5, 0, e3m7_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m7's stretches: [name, role]."""
glob E3M7_STRETCHES: list[list[str]] = [
         ["foyer", "start"],
         ["lifts", "flow"],
         ["pads", "hub"],
         ["pads", "flow"],
         ["crypt", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m7's stretches by its name."""
def make_e3m7(name: str, key: str) -> Prefab {
    if name == "foyer" {
        return HauntedFoyer();
    }
    if name == "lifts" {
        return SlimeLifts();
    }
    if name == "pads" {
        return PadGallery();
    }
    if name == "crypt" {
        return HauntedCrypt(key=key if key else "key_silver");
    }
    return HauntedExit(key=key);
}
