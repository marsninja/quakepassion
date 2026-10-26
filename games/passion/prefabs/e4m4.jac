"""Prefabs drawn from e4m4, the Palace of Hate: a palace of halls under
dark stone, a reflecting pool between stairs up to a balcony, a gallery
whose floor gives way to deep water full of fish, a throne on a dais
under galleries ridden up to, the silver key on a high shelf. Raised in
e4m4's own palette.

- `HateAntechamber`: the start. A reflecting pool in a hall, twin stairs up
  either side to a balcony across its far end; ways on from the balcony
  and the floor.
- `FishGallery`: a long gallery, deep water across its middle wall to wall,
  swum across with fish in it.
- `HateThrone`: a throne on a dais at a hall's head, galleries along its
  sides ridden up to by lifts; ways on from the dais, the galleries and
  the floor (a hub).
- `PalaceVault`: the key on a shelf high on a vault's far wall, a lift up
  to it; taking it opens the closets.
- `PalaceExit`: the end. A door (a key's, as a gate) into a hall, the
  slipgate on a dais between braziers."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E4M4: str = "q1:e4m4";

"""e4m4's foes: fiends and knights, scrags, hell knights deeper in."""
def e4m4_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_demon1", "monster_hell_knight"] if heavy else ["monster_knight", "monster_knight", "monster_wizard"], ["monster_shambler"] if heavy else ["monster_demon1"], danger * 0.4 if heavy else danger));
}

"""The start: a reflecting pool, twin stairs up to a balcony."""
node HateAntechamber(Prefab) {
    has balcony: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hate antechamber";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.balcony = dice.between(6, 7);
        self.tall = self.balcony + 10;
        self.low = -3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=1, along=float(self.long - 3), floor=self.balcony), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        bx = self.long - 5;
        build.solid(bx, 1, self.balcony - 1, self.long - 1, self.wide - 1, self.balcony);
        stair(build, bx - self.balcony, 1, 0, 0, self.balcony, 3);
        stair(build, bx - self.balcony, self.wide - 4, 0, 0, self.balcony, 3);
        for y in [1, 2, 3, self.wide - 4, self.wide - 3, self.wide - 2] {
            build.keep(hall, bx, y, self.balcony);
        }
        build.pool(7, middle - 3, -2, bx - 3, middle + 3, 0, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx) - 3.5, 5.5 + float(index) * 4.0, 0, e4m4_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.balcony, e4m4_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.balcony, "item_health");
    }
}

"""A long gallery, deep water across its middle wall to wall, swum across
with fish in it."""
node FishGallery(Prefab) {
    has deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fish gallery";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(12, 14);
        self.deep = dice.between(5, 6);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
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
        gallery = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 9;
        x1 = self.long - 9;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2);
        stair(build, x1 - self.deep, self.wide - 3, -self.deep, 0, self.deep, 2);
        pillars(build, 3, 2, x0 - 1, self.wide - 2, 0, self.tall, 3, [[0, middle - 3, x0, middle + 3]]);
        pillars(build, x1 + 2, 2, self.long - 3, self.wide - 2, 0, self.tall, 3, [[x1, middle - 3, self.long, middle + 3], [self.long - 6, 0, self.long, self.wide]]);
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 2 + index * 3) + 0.5, float(middle) + 0.5, -self.deep + 1, "monster_fish", 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 3.5, 2.5 + float(index) * 3.5, 0, e4m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A throne on a dais at a hall's head, galleries along its sides ridden up
to by lifts."""
node HateThrone(Prefab) {
    has dais: int = 5,
        gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hate throne";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.dais = dice.between(4, 5);
        self.gallery = dice.between(8, 9);
        self.tall = self.gallery + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.dais),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
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
        build.level(hall, self.dais);
        build.level(hall, self.gallery);
        dx = self.long - 8;
        build.solid(dx, 6, 0, self.long - 1, self.wide - 6, self.dais);
        stair(build, dx - self.dais, middle - 3, 0, 0, self.dais, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(hall, dx, y, self.dais);
        }
        build.solid(self.long - 3, middle - 5, self.dais, self.long - 2, middle - 3, self.dais + 4);
        under = self.gallery - 1;
        build.solid(10, 1, under, self.long - 1, 5, self.gallery);
        build.solid(10, self.wide - 5, under, self.long - 1, self.wide - 1, self.gallery);
        step = kit_of(build.district).step;
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, 7.0, 1.0, float(self.gallery) - 0.5, 10.0, 4.0, float(self.gallery), step);
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, 7.0, float(self.wide - 4), float(self.gallery) - 0.5, 10.0, float(self.wide - 1), float(self.gallery), step);
        for y in [1, 2, 3, self.wide - 4, self.wide - 3, self.wide - 2] {
            build.keep(hall, 10, y, self.gallery);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, e4m4_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 5.5, float(middle) + 0.5, self.dais, e4m4_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long - 6) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0, self.gallery, e4m4_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 7.5, self.dais, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The key on a shelf high on a vault's far wall, a lift up to it; taking
it opens the closets."""
node PalaceVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        shelf: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.shelf = dice.between(7, 9);
        self.tall = self.shelf + 8;
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
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, self.shelf);
        build.doorway(vault, self.enter);
        sx = self.long - 5;
        build.solid(sx, 1, self.shelf - 1, self.long - 1, side, self.shelf);
        build.put_box({"classname": "func_plat", "height": str(self.shelf * 16), "speed": "200"}, float(sx - 3), float(cy - 1), float(self.shelf) - 0.5, float(sx), float(cy + 2), float(self.shelf), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(vault, sx, y, self.shelf);
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.shelf, side, 0, [2, sx - 6], [e4m4_foe(dice, self.danger, True), e4m4_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, self.shelf, e4m4_foe(dice, self.danger), 180.0);
        build.foe(float(sx) - 4.5, float(cy) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a hall, the slipgate on a dais between braziers."""
node PalaceExit(Prefab) {
    has key: str = "",
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(14, 16);
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
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        dais_x = self.long - 7;
        build.solid(dais_x, middle - 4, 0, self.long - 1, middle + 4, 3);
        stair(build, dais_x - 3, middle - 2, 0, 0, 3, 4);
        for y in [middle - 4, middle + 3] {
            build.solid(dais_x - 2, y, 0, dais_x - 1, y + 1, 3);
        }
        build.way_out(float(self.long) - 3.5, float(middle), 3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dais_x) - 4.5, 2.5, 0, e4m4_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m4's stretches: [name, role]."""
glob E4M4_STRETCHES: list[list[str]] = [
         ["antechamber", "start"],
         ["fish", "flow"],
         ["throne", "hub"],
         ["throne", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m4's stretches by its name."""
def make_e4m4(name: str, key: str) -> Prefab {
    if name == "antechamber" {
        return HateAntechamber();
    }
    if name == "fish" {
        return FishGallery();
    }
    if name == "throne" {
        return HateThrone();
    }
    if name == "vault" {
        return PalaceVault(key=key if key else "key_silver");
    }
    return PalaceExit(key=key);
}
