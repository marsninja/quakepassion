"""Prefabs drawn from e2m6, the Dismal Oubliette: dungeons of brick and wood
sunk deep, a ledge over a pit, a well wound down into, a block of cells
with a gallery over them, the gold key at the bottom of a drowned pit, a
way out on an island. Raised in e2m6's own palette.

- `OublietteLedge`: the start. A ledge over a pit, a stair down the wall
  to its floor and a pool in it; ways on below and from the ledge.
- `DeepWell`: a well entered at its top, a stair winding down round its
  walls to the bottom and a pool there; ways on at the foot.
- `CellBlock`: a corridor between two rows of cells, a gallery over each
  row, a stair up at the far end and a bridge across between them; ways on
  from the corridor and the galleries (a hub).
- `DrownedKey`: a deep pool, the key on its floor; taking it opens the
  closets in the wall.
- `DismalExit`: the end. A door (a key's, as a gate) into a cavern, a pool
  across it, the slipgate on an island in the pool."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, spiral }
import from .e2m2 { spiral_landing }

glob E2M6: str = "q1:e2m6";

"""e2m6's foes: the dead and fiends, hell knights and ogres, a vore deeper
in."""
def e2m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_shalrath"] if heavy else ["monster_demon1"], danger * 0.5 if heavy else danger));
}

"""The start: a ledge over a pit, a stair down the wall to its floor."""
node OublietteLedge(Prefab) {
    has deep: int = 8,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Oubliette ledge";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 22);
        self.deep = dice.between(7, 8);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=1, along=float(self.long - 4), floor=-self.deep), Port(face=1, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        pit = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        # The ledge along the near end, the stair down the south wall.
        build.solid(1, 1, low, 8, self.wide - 1, 0);
        stair(build, 7 + self.deep, 1, low, 2, self.deep, 3);
        build.pool(14, middle - 2, low - 3, self.long - 6, middle + 3, low, 2);
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 4)) {
            build.foe(float(12 + index * 4) + 0.5, float(self.wide) - 3.5, low, e2m6_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, low, e2m6_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, low, "item_health");
    }
}

"""A well entered at its top, a stair winding down round its walls to the
bottom and a pool there."""
node DeepWell(Prefab) {
    has steps: int = 28,
        tall: int = 36;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Deep well";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        fits: list[int] = [];
        for steps in range(20, 34) {
            landing = spiral_landing(self.long, self.wide, steps, 5);
            if landing and landing[0] == 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 9;
        self.low = -4;
        self.high = self.tall + 1;
        top = spiral_landing(self.long, self.wide, self.steps, 5);
        self.enter = Port(face=2, along=top[1], floor=self.steps);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        well = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(well, self.steps // 2);
        build.level(well, self.steps);
        spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 5);
        build.pool(5, 5, -3, self.long - 5, self.wide - 5, 0, 2);
        build.doorway(well, self.enter);
        for port in self.taken {
            build.doorway(well, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 4 + index * 6, "monster_wizard", float(index * 120));
        }
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 0, e2m6_foe(dice, self.danger, True), 180.0);
        build.foe(2.5, 2.5, 1, e2m6_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""A corridor between two rows of cells, a gallery over each row, a stair
up at the far end and a bridge across between them."""
node CellBlock(Prefab) {
    has gallery: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cell block";
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.gallery = 7;
        self.tall = dice.between(15, 17);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        block = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(block, self.gallery);
        under = self.gallery - 1;
        # The cells: walls a cell thick every four cells along each row.
        cells: list[list[float]] = [];
        for x in range(4, self.long - 11, 4) {
            build.solid(x, 1, 0, x + 1, 5, under);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 1, under);
            cells.append([float(x) + 2.0, 2.5]);
            cells.append([float(x) + 2.0, float(self.wide) - 2.5]);
        }
        # The galleries over the rows, the stair up to the south one at the
        # far end, the bridge across to the north one.
        build.solid(1, 1, under, self.long - 1, 5, self.gallery);
        build.solid(1, self.wide - 5, under, self.long - 1, self.wide - 1, self.gallery);
        stair(build, self.long - 4 - self.gallery, 5, 0, 0, self.gallery, 3);
        build.solid(self.long - 4, 5, under, self.long - 1, self.wide - 5, self.gallery);
        for x in range(self.long - 7, self.long - 3) {
            build.keep(block, x, 4, self.gallery);
        }
        for y in range(5, self.wide - 5) {
            build.keep(block, self.long - 4, y, self.gallery);
        }
        build.doorway(block, self.enter);
        for port in self.taken {
            build.doorway(block, port);
        }
        count = dice.between(3, 5);
        for index in range(min(count, len(cells))) {
            cell = cells[(index * 3) % len(cells)];
            build.foe(cell[0], cell[1], 0, "monster_zombie" if index % 2 == 0 else e2m6_foe(dice, self.danger), 90.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 8) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0, self.gallery, e2m6_foe(dice, self.danger, True), 0.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.gallery, "item_health");
        build.supply(float(self.long) - 6.5, float(middle) + 3.5, 0, "item_spikes");
    }
}

"""A deep pool, the key on its floor; taking it opens the closets."""
node DrownedKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 7,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drowned key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M6;
        self.district = level_district(E2M6);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 3;
        build.pool(x0, 3, -self.deep, x1, side - 2, 0, 2);
        key_ambush(build, self.key, float(x1) - 3.5, float(cy) + 0.5, -self.deep, side, 0, [2, self.long - 5], [e2m6_foe(dice, self.danger, True), e2m6_foe(dice, self.danger)]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 5) + 0.5, float(cy) + 2.5, -self.deep + 1, "monster_fish", 0.0);
        }
        build.foe(float(self.long) - 2.5, 2.5, 0, e2m6_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a cavern, a pool across it, the slipgate on an
island in the pool."""
node DismalExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dismal exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M6;
        self.district = level_district(E2M6);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
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
        cavern = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(cavern, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The pool across the cavern to its far wall, the island in it, steps
        # up out of the water onto the island from its south side.
        x0 = wall + 4;
        build.pool(x0, 1, -5, self.long - 1, self.wide - 1, 0, 2);
        ix = (x0 + self.long - 1) // 2 + 1;
        build.solid(ix - 2, middle - 2, -5, ix + 2, middle + 2, 0);
        stair(build, ix - 1, middle - 7, -5, 1, 5, 2);
        build.way_out(float(ix), float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m6_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 2.5, float(middle) + 3.5, -4, "monster_fish", 0.0);
        build.foe(float(ix) + 1.0, float(middle) + 1.0, 0, e2m6_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m6's stretches: [name, role]."""
glob E2M6_STRETCHES: list[list[str]] = [
         ["ledge", "start"],
         ["well", "flow"],
         ["cells", "hub"],
         ["cells", "flow"],
         ["drowned", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m6's stretches by its name."""
def make_e2m6(name: str, key: str) -> Prefab {
    if name == "ledge" {
        return OublietteLedge();
    }
    if name == "well" {
        return DeepWell();
    }
    if name == "cells" {
        return CellBlock();
    }
    if name == "drowned" {
        return DrownedKey(key=key if key else "key_gold");
    }
    return DismalExit(key=key);
}
