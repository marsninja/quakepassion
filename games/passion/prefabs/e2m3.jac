"""Prefabs drawn from e2m3, the Crypt of Decay: crypts of copper and stone
over deep water, walkways over cisterns, a hall crossed by bridges over
a pit, the gold key in a vault below. Raised in e2m3's own palette.

- `CryptGate`: the start. A nave sunk between buttresses along its walls,
  the dead waiting in the bays between them.
- `Cistern`: a walkway over a cistern, deep water at its bottom; a stair
  up its wall for whoever falls.
- `BridgeHall`: a hall round a pit, bridges across it from wall to wall
  crossing in its middle, a pool in the pit's floor, lifts up out of it;
  ways on from the ledges round it (a hub).
- `KnightVault`: a vault below, down a stair from a ledge, the key on a
  bier at its far end; taking it opens the closets in its wall.
- `CryptExit`: the end. A hall, a door (a key's, as a gate), a stair up to
  a gallery and the slipgate on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E2M3: str = "q1:e2m3";

"""e2m3's foes: the dead and ogres, hell knights growing with the danger
(a shambler waits in the vault, late in a run)."""
def e2m3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_hell_knight"], danger));
}

"""The start: a nave sunk between buttresses, the dead in the bays."""
node CryptGate(Prefab) {
    has tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt gate";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(24, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(14, 16);
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
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, -2);
        # The sunken nave, two steps down at each end.
        build.widen(nave, 7, 4, -2, self.long - 7, self.wide - 4, 0);
        stair(build, 8, 4, -2, 2, 2, self.wide - 8);
        stair(build, self.long - 9, 4, -2, 0, 2, self.wide - 8);
        # Buttresses along the side walls, bays between them.
        clear = [[0, middle - 3, 4, middle + 3], [self.long - 7, 0, self.long, 4], [self.long - 7, self.wide - 4, self.long, self.wide]];
        pillars(build, 4, 1, self.long - 6, 2, 0, self.tall, 3, clear);
        pillars(build, 4, self.wide - 2, self.long - 6, self.wide - 1, 0, self.tall, 3, clear);
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(3, 4)) {
            build.foe(float(5 + index * 3) + 0.5, 1.5 if index % 2 == 0 else float(self.wide) - 1.5, 0, "monster_zombie", 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, float(middle) + 0.5, -2, e2m3_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""A walkway over a cistern, deep water at its bottom, a stair up its wall."""
node Cistern(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(15, 17);
        self.low = -9;
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
        build.level(hall, -5);
        x0 = 7;
        x1 = self.long - 7;
        # The cistern: a dry floor five lifts down at its near end, deep
        # water beyond it, a stair up the near wall from the dry floor.
        build.widen(hall, x0, 1, -5, x1, self.wide - 1, 0);
        build.pool(x0 + 5, 1, -8, x1, self.wide - 1, -5, 2);
        stair(build, x0 + 4, 1, -5, 2, 5, 2);
        # The walkway over it, three cells wide, piers down to the water.
        build.solid(x0, middle - 1, -1, x1, middle + 2, 0);
        for x in range(x0 + 6, x1 - 1, 5) {
            build.solid(x, middle - 1, -8, x + 1, middle, -1);
            build.solid(x, middle + 1, -8, x + 1, middle + 2, -1);
        }
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 8 + index * 6) + 0.5, 3.5, -8, "monster_fish", 90.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 2.5 + float(index) * 4.0, 0, e2m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0 + 2) + 0.5, float(self.wide) - 3.5, -5, "monster_zombie", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(x0) + 2.5, float(self.wide) - 2.5, -5, "item_rockets");
    }
}

"""A hall round a pit, bridges across it crossing in its middle, a pool in
the pit's floor; ways on from the ledges round it."""
node BridgeHall(Prefab) {
    has pit: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bridge hall";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(26, 30);
        self.tall = dice.between(16, 20);
        self.pit = dice.between(6, 7);
        self.low = -self.pit - 4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=float(self.wide - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        low = -self.pit;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        build.widen(hall, 6, 6, low, self.long - 6, self.wide - 6, 0);
        build.pool(cx - 3, cy - 3, low - 3, cx + 3, cy + 3, low, 2);
        # Lifts up out of the pit in two corners, waiting at their feet.
        for corner in [[6, 6], [self.long - 8, self.wide - 8]] {
            build.put_box({"classname": "func_plat", "height": str(self.pit * 16), "speed": "200"}, float(corner[0]), float(corner[1]), -0.5, float(corner[0] + 2), float(corner[1] + 2), 0.0, kit_of(build.district).step);
        }
        # The bridges, crossing in the middle.
        build.solid(6, cy - 2, -1, self.long - 6, cy + 2, 0);
        build.solid(cx - 2, 6, -1, cx + 2, self.wide - 6, 0);
        for at in range(-2, 2) {
            build.keep(hall, 5, cy + at, 0);
            build.keep(hall, self.long - 6, cy + at, 0);
            build.keep(hall, cx + at, 5, 0);
            build.keep(hall, cx + at, self.wide - 6, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 4) + 0.5, float(cy) + 5.5, low, e2m3_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) - 4.5, 0, e2m3_foe(dice, self.danger, True), 270.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * (float(self.wide) - 7.0), 0, e2m3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) - 1.5, float(cy) + 0.5, low - 2, "monster_fish", 0.0);
        build.supply(3.0, 3.0, 0, "item_health");
        build.supply(float(self.long) - 9.0, float(cy) + 5.5, low, "item_spikes");
        build.supply(3.0, float(self.wide) - 3.0, 0, "item_shells");
    }
}

"""A vault below, down a stair from a ledge, the key on a bier at its far
end; taking it opens the closets in its wall."""
node KnightVault(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 18,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Knight vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(22, 24);
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
        low = -self.deep;
        vault = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, 0);
        build.doorway(vault, self.enter);
        # The ledge in at the near end, a stair down off it.
        build.solid(1, 1, low, 6, side, 0);
        stair(build, 6 + self.deep - 1, cy - 2, low, 2, self.deep, 4);
        for y in range(cy - 2, cy + 2) {
            build.keep(vault, 5, y, 0);
        }
        # The bier at the far end, the key on it.
        build.solid(self.long - 6, cy - 1, low, self.long - 3, cy + 2, low + 1);
        pillars(build, 9 + self.deep, 3, self.long - 7, 4, low, self.tall, 4, []);
        pillars(build, 9 + self.deep, side - 4, self.long - 7, side - 3, low, self.tall, 4, []);
        key_ambush(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, low + 1, side, low, [7 + self.deep, self.long - 7], ["monster_shambler" if self.danger > 0.6 else e2m3_foe(dice, self.danger, True), "monster_zombie"]);
        build.foe(float(self.long) - 2.5, 2.5, low, e2m3_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 3.5, low, "monster_zombie", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a hall, a door (a key's, as a gate), a stair up to a gallery
and the slipgate on it."""
node CryptExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(15, 17);
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
        wall = self.long - 13;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 12, variant=dice.below(3));
        chapel = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chapel, 6);
        build.doorway(hall, self.enter);
        build.widen(chapel, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        stair(build, wall + 2, middle - 2, 0, 0, 6, 4);
        build.solid(wall + 8, 1, 0, self.long - 1, self.wide - 1, 6);
        for y in range(middle - 2, middle + 2) {
            build.keep(chapel, wall + 8, y, 6);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 6);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 6, e2m3_foe(dice, self.danger, True), 180.0);
        build.foe(float(wall) + 3.5, 2.5, 0, "monster_zombie", 90.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m3's stretches: [name, role]."""
glob E2M3_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["cistern", "flow"],
         ["bridges", "hub"],
         ["bridges", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m3's stretches by its name."""
def make_e2m3(name: str, key: str) -> Prefab {
    if name == "gate" {
        return CryptGate();
    }
    if name == "cistern" {
        return Cistern();
    }
    if name == "bridges" {
        return BridgeHall();
    }
    if name == "vault" {
        return KnightVault(key=key if key else "key_gold");
    }
    return CryptExit(key=key);
}
