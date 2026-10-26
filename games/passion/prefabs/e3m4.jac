"""Prefabs drawn from e3m4, Satan's Dark Delight: dark halls over black
water, a pier across a flooded pit, a tower of lifts one over another, a
great altar bridged to from the walls, a vault beyond a wall dived under.
e3m4 holds no keys; its key room and gate are drawn from its vaults.
Raised in e3m4's own palette.

- `DarkPier`: the start. A pit of water across a hall, a pier over it, a
  lift up to a ledge by the far wall; ways on from the floor and ledge.
- `ElevatorTower`: a tower of three lifts, each up to a ledge on the wall
  across from the last, the way on from the top ledge.
- `DelightAltar`: a hall round a great altar, stairs up its sides,
  bridges from its top to ways on high in two walls; ways on below too
  (a hub).
- `DivedVault`: a pool across a vault, a wall down into it to dive under,
  the key beyond; taking it opens the closets on the near side.
- `DelightExit`: the end. A door (a key's, as a gate), a hall of pillars
  standing in water, the slipgate on a dais."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M4: str = "q1:e3m4";

"""e3m4's foes: ogres above all, the dead and scrags, fiends deeper in."""
def e3m4_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"] if heavy else ["monster_ogre", "monster_zombie", "monster_wizard"], ["monster_demon1"] if heavy else ["monster_ogre"], danger));
}

"""The start: a pit of water across a hall, a pier over it, a lift up to a
ledge by the far wall."""
node DarkPier(Prefab) {
    has ledge: int = 6,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dark pier";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(14, 16);
        self.ledge = dice.between(6, 7);
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0), Port(face=0, along=3.0, floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        x0 = 7;
        x1 = self.long - 7;
        build.pool(x0, 1, -4, x1, self.wide - 1, 0, 2, False, True, True);
        build.solid(x0, middle - 1, -4, x1, middle + 2, 0);
        for x in range(x0 + 3, x1 - 1, 5) {
            build.solid(x, middle - 2, -4, x + 1, middle - 1, 4);
            build.solid(x, middle + 2, -4, x + 1, middle + 3, 4);
        }
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        # The ledge in the far south corner, the lift up to it.
        build.solid(self.long - 5, 1, self.ledge - 1, self.long - 1, 6, self.ledge);
        build.put_box({"classname": "func_plat", "height": str(self.ledge * 16), "speed": "200"}, float(self.long - 5), 6.0, float(self.ledge) - 0.5, float(self.long - 2), 9.0, float(self.ledge), kit_of(build.district).step);
        for x in range(self.long - 5, self.long - 1) {
            build.keep(hall, x, 5, self.ledge);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, float(self.wide) - 3.5 - float(index) * 3.0, 0, e3m4_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, 3.0, self.ledge, e3m4_foe(dice, self.danger, True), 180.0);
        build.foe(float(x0 + 4) + 0.5, 3.5, -3, "monster_fish", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A tower of three lifts, each up to a ledge on the wall across from the
last; the way on from the top ledge."""
node ElevatorTower(Prefab) {
    has rise_by: int = 6,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elevator tower";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(16, 18);
        self.wide = dice.between(14, 16);
        self.rise_by = dice.between(6, 7);
        self.tall = 3 * self.rise_by + 9;
        self.low = -1;
        self.high = self.tall + 1;
        top = 3 * self.rise_by;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=top), Port(face=1, along=float(self.long // 2), floor=top)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        step = kit_of(build.district).step;
        first = self.rise_by;
        second = 2 * self.rise_by;
        top = 3 * self.rise_by;
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [first, second, top] {
            build.level(tower, z);
        }
        north = self.wide - 4;
        # The ledges: the first and the top along the north wall, the
        # second along the south.
        build.solid(1, north, first - 1, self.long - 1, self.wide - 1, first);
        build.solid(1, 1, second - 1, self.long - 1, 4, second);
        build.solid(1, north, top - 1, self.long - 1, self.wide - 1, top);
        # The lifts: the first up beside the first ledge, the second across
        # from it up to the south ledge, the third back up to the north.
        build.put_box({"classname": "func_plat", "height": str(first * 16), "speed": "200"}, 7.0, float(north - 3), float(first) - 0.5, 10.0, float(north), float(first), step);
        build.put_box({"classname": "func_plat", "height": str((second - first) * 16), "speed": "200"}, float(self.long - 6), 4.0, float(second) - 0.5, float(self.long - 3), float(north), float(second), step);
        build.put_box({"classname": "func_plat", "height": str((top - second) * 16), "speed": "200"}, 2.0, 4.0, float(top) - 0.5, 5.0, float(north), float(top), step);
        for x in range(1, self.long - 1) {
            build.keep(tower, x, north, first);
            build.keep(tower, x, 3, second);
            build.keep(tower, x, north, top);
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, first, e3m4_foe(dice, self.danger), 270.0);
        build.foe(float(self.long // 2) + 0.5, 2.5, second, e3m4_foe(dice, self.danger, True), 90.0);
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, second + 3, "monster_wizard", 0.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, top, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""A hall round a great altar, stairs up its sides, bridges from its top
to ways on high in two walls."""
node DelightAltar(Prefab) {
    has altar: int = 6,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Delight altar";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(18, 22);
        self.altar = dice.between(6, 7);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.altar),
            Port(face=0, along=middle, floor=self.altar),
            Port(face=3, along=float(self.long // 2) + 6.0, floor=0),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.altar);
        # The altar, a block in the middle, a stair up its west and south.
        ax0 = cx - 4;
        ax1 = cx + 4;
        ay0 = cy - 4;
        ay1 = cy + 4;
        build.solid(ax0, ay0, 0, ax1, ay1, self.altar);
        stair(build, ax0 - self.altar, cy - 2, 0, 0, self.altar, 4);
        stair(build, cx - 2, ay0 - self.altar, 0, 1, self.altar, 4);
        # The bridges: north to the wall and east to the wall.
        build.solid(cx - 2, ay1, self.altar - 1, cx + 2, self.wide - 1, self.altar);
        build.solid(ax1, cy - 2, self.altar - 1, self.long - 1, cy + 2, self.altar);
        for at in range(-2, 2) {
            build.keep(hall, cx + at, ay1 - 1, self.altar);
            build.keep(hall, ax1 - 1, cy + at, self.altar);
            build.keep(hall, ax0, cy + at, self.altar);
            build.keep(hall, cx + at, ay0, self.altar);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, e3m4_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.altar, e3m4_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 4.5, float(cy) + 6.5, 10, "monster_wizard", 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.altar, "item_health");
        build.supply(float(self.long) - 3.5, 3.5, 0, "item_rockets");
    }
}

"""A pool across a vault, a wall down into it to dive under, the key
beyond; taking it opens the closets on the near side."""
node DivedVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 14,
        deep: int = 6,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dived vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(14, 16);
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
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(vault, self.enter);
        x0 = 7;
        x1 = self.long - 6;
        build.pool(x0, 1, -self.deep, x1, side, 0, 2);
        stair(build, x1 - self.deep, side - 2, -self.deep, 0, self.deep, 2);
        wall = (x0 + x1) // 2;
        build.solid(wall, 1, -1, wall + 1, side, self.tall);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [2], [e3m4_foe(dice, self.danger, True)]);
        build.foe(float(wall) + 2.5, float(cy) + 0.5, -self.deep + 1, "monster_fish", 0.0);
        build.foe(float(self.long) - 2.5, 2.5, 0, e3m4_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a hall of pillars standing in water, the slipgate on a
dais."""
node DelightExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Delight exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M4;
        self.district = level_district(E3M4);
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
        room = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # Shallow water across the room, pillars standing in it, a dais at
        # its far end.
        dais_x = self.long - 6;
        build.pool(wall + 3, 1, -2, dais_x, self.wide - 1, 0, 2, False, True, True);
        stair(build, dais_x - 2, middle - 2, -2, 0, 2, 4);
        pillars(build, wall + 5, 3, dais_x - 2, self.wide - 3, -2, self.tall, 4, [[0, middle - 3, self.long, middle + 3]]);
        build.solid(dais_x, 1, 0, self.long - 1, self.wide - 1, 1);
        build.way_out(float(self.long) - 3.0, float(middle), 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m4_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dais_x) + 2.5, 3.0, 1, e3m4_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m4's stretches: [name, role]."""
glob E3M4_STRETCHES: list[list[str]] = [
         ["pier", "start"],
         ["elevators", "flow"],
         ["altar", "hub"],
         ["altar", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m4's stretches by its name."""
def make_e3m4(name: str, key: str) -> Prefab {
    if name == "pier" {
        return DarkPier();
    }
    if name == "elevators" {
        return ElevatorTower();
    }
    if name == "altar" {
        return DelightAltar();
    }
    if name == "vault" {
        return DivedVault(key=key if key else "key_silver");
    }
    return DelightExit(key=key);
}
