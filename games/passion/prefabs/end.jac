"""Prefabs drawn from `end`, Shub-Niggurath's Pit: the last pit, lakes of
lava crossed by a causeway or only by teleporter, an island in a moat of
slime with teleporters out to balconies, the way out at the pit's
bottom. `end` holds no keys; its key room and gate are drawn from its
islands. Shub-Niggurath herself is left out (she dies only by the
original's telefrag). Raised in end's own palette.

- `PitApproach`: the start. A lake of lava across a hall, a narrow
  causeway over it; ways on from the far shore.
- `TeleportIslands`: a lake of lava, an island in its middle, teleporters
  from the near shore to the island, the island to the far shore, and
  the far shore back.
- `ShubHall`: an island in a moat of slime, teleporters onto it and from
  it to balconies on two walls; ways on from the floor and the balconies
  (a hub).
- `PitKey`: the key on an island in lava, a teleporter out and one back;
  taking it opens the closets.
- `ShubPit`: the end. A door (a key's, as a gate), a stair down round a
  pit to its floor and the slipgate there."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush, spiral, ring_path }

glob END: str = "q1:end";

"""end's foes: vores and shamblers, scrags and fiends."""
def end_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_demon1", "monster_demon1", "monster_shalrath"] if heavy else ["monster_wizard", "monster_wizard", "monster_demon1"], ["monster_shambler", "monster_shalrath"] if heavy else ["monster_shalrath"], danger * 0.3));
}

"""The start: a lake of lava across a hall, a narrow causeway over it."""
node PitApproach(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pit approach";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
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
        x0 = 7;
        x1 = self.long - 6;
        build.pool(x0, 1, -3, x1, self.wide - 1, 0, 4, False, False);
        build.solid(x0, middle - 1, -3, x1, middle + 1, 0);
        for y in [middle - 1, middle] {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 4 + index * 5) + 0.5, float(middle) + 4.5, 5, "monster_wizard", 180.0);
        }
        build.foe(float(x1) + 2.5, float(middle) + 3.5, 0, end_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""A lake of lava, an island in its middle, teleporters from shore to
island to shore and back."""
node TeleportIslands(Prefab) {
    has tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport islands";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(13, 15);
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
        x0 = 7;
        x1 = self.long - 6;
        build.pool(x0, 1, -3, x1, self.wide - 1, 0, 4, False, False);
        ix = (x0 + x1) // 2;
        build.solid(ix - 3, middle - 3, -3, ix + 3, middle + 3, 1);
        build.teleporter(4.0, float(middle) + 0.5, 0, float(ix) - 1.5, float(middle) - 1.5, 1, 0.0);
        build.teleporter(float(ix) + 1.5, float(middle) + 1.5, 1, float(x1) + 3.0, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(x1) + 2.5, 3.0, 0, 3.0, 3.0, 0, 180.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(ix) + 1.5, float(middle) - 1.5, 1, end_foe(dice, self.danger), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 3.0, float(self.wide) - 3.0 - float(index) * 2.5, 0, end_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_cells");
    }
}

"""An island in a moat of slime, teleporters onto it and from it to
balconies on two walls."""
node ShubHall(Prefab) {
    has balcony: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shub hall";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.balcony = dice.between(6, 7);
        self.tall = self.balcony + 11;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.balcony),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        build.pool(cx - 7, cy - 6, -3, cx + 7, cy + 6, 0, 3, False, True, True);
        build.solid(cx - 4, cy - 3, -3, cx + 4, cy + 3, 1);
        under = self.balcony - 1;
        build.solid(cx - 6, self.wide - 4, under, cx + 6, self.wide - 1, self.balcony);
        build.solid(cx - 6, 1, under, cx + 6, 4, self.balcony);
        build.teleporter(4.0, float(cy) + 0.5, 0, float(cx) - 2.5, float(cy) + 0.5, 1, 0.0);
        build.teleporter(float(cx) + 1.5, float(cy) + 1.5, 1, float(cx) + 0.5, float(self.wide) - 2.5, self.balcony, 90.0);
        build.teleporter(float(cx) + 1.5, float(cy) - 1.5, 1, float(cx) + 0.5, 2.5, self.balcony, 270.0);
        for x in range(cx - 5, cx + 5) {
            build.keep(hall, x, self.wide - 4, self.balcony);
            build.keep(hall, x, 3, self.balcony);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx + 9) + 0.5, 3.5 + float(index) * 5.0, 0, end_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) - 1.5, float(cy) - 1.5, 1, end_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) - 4.5, 2.5, self.balcony, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""The key on an island in lava, a teleporter out and one back; taking it
opens the closets."""
node PitKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pit key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
        self.low = -4;
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
        x1 = self.long - 2;
        build.pool(x0, 3, -3, x1, side - 2, 0, 4, False, False);
        cx = (x0 + x1) // 2 + 1;
        build.solid(cx - 2, cy - 2, -3, cx + 2, cy + 2, 1);
        build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy), 1, 0.0);
        build.teleporter(float(cx) + 1.0, float(cy) + 1.0, 1, 3.0, 3.0, 0, 180.0);
        key_ambush(build, self.key, float(cx) + 1.0, float(cy) - 1.0, 1, side, 0, [2], [end_foe(dice, self.danger, True)]);
        build.foe(3.0, float(side) - 3.0, 0, end_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a stair down round a pit to its floor, the slipgate
there."""
node ShubPit(Prefab) {
    has key: str = "",
        deep: int = 12,
        tall: int = 6;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shub pit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(10, 14);
        self.tall = 8;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        pit = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.level(pit, low);
        build.doorway(hall, self.enter);
        build.widen(pit, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # A landing inside the door, the stair down round the pit's walls
        # from the landing's north end, east and on round to the floor.
        build.solid(wall + 1, 1, low, wall + 4, self.wide - 1, 0);
        path = ring_path(wall + 1, 1, self.long - 1, self.wide - 1, 2);
        top = 0;
        for (index, cell) in enumerate(path) {
            if cell[4] == 1 and cell[0] == wall + 4 {
                top = index;
            }
        }
        spiral(build, wall + 1, 1, self.long - 1, self.wide - 1, low, self.deep, 2, 0, top - self.deep + 1 + len(path));
        build.keep(pit, wall + 3, self.wide - 2, 0);
        build.keep(pit, wall + 3, self.wide - 3, 0);
        build.way_out(float(self.long + wall) * 0.5 + 1.0, float(middle), low);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, end_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 2.5, low, end_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""end's stretches: [name, role]."""
glob END_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["islands", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["key", "keyroom"],
         ["pit", "end"],
         ["pit", "gate"]
     ];

"""One of end's stretches by its name."""
def make_end(name: str, key: str) -> Prefab {
    if name == "approach" {
        return PitApproach();
    }
    if name == "islands" {
        return TeleportIslands();
    }
    if name == "hall" {
        return ShubHall();
    }
    if name == "key" {
        return PitKey(key=key if key else "key_gold");
    }
    return ShubPit(key=key);
}
