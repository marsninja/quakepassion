"""Prefabs drawn from e1m6, the Door to Chthon: halls over lava, stone
causeways across it, corridors of doors, a key on an island the lava
keeps until a bridge rises, and the great door. Raised in e1m6's own
palette.

- `LavaOverlook`: the start. A hall at the head of a stair down to a lava
  pit, a causeway winding across it to the far side.
- `LavaCauseway`: a long hall floored with lava, a straight causeway down
  it, ogres on ledges high on its sides and a lift up to one of them; ways
  on at the causeway's end and from the ledge.
- `DoorHall`: a corridor lined with doors, rooms behind them, ways on at
  its ends and from its middle (a hub).
- `LavaKeyShrine`: the key on a stone island in a lava pool; a button on the
  shore draws a bridge up out of the lava to it; taking the key opens the
  closets.
- `ChthonDoor`: the end. A great door, sixteen lifts high (a key's, as a
  gate), a lava moat beyond it and the way out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, apart }

glob E1M6: str = "q1:e1m6";

"""e1m6's foes: ogres above all, zombies and scrags, a fiend deeper in."""
def e1m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre", "monster_knight"] if heavy else ["monster_ogre", "monster_zombie", "monster_knight"], ["monster_demon1"] if heavy else ["monster_wizard"], danger));
}

"""The start: a hall at the head of a stair down to a lava pit, a causeway
winding across it."""
node LavaOverlook(Prefab) {
    has hall: int = 8,
        drop: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava overlook";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.hall = dice.between(7, 9);
        self.drop = dice.between(5, 7);
        self.long = 1 + self.hall + self.drop + dice.between(16, 20) + 1;
        self.wide = dice.between(16, 20);
        self.tall = dice.between(14, 18);
        self.low = -4;
        self.high = self.drop + self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=self.drop);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        pit = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.drop + self.tall, variant=dice.below(3));
        build.level(pit, self.drop);
        build.solid(1, 1, 0, 1 + self.hall, self.wide - 1, self.drop);
        foot = 1 + self.hall;
        for step in range(self.drop) {
            build.solid(foot + step, middle - 2, 0, foot + step + 1, middle + 2, self.drop - 1 - step);
        }
        # The pit floor: lava, the causeway winding across it to the far
        # landing four cells deep.
        lava_x0 = foot + self.drop;
        lava_x1 = self.long - 5;
        build.pool(lava_x0, 1, -3, lava_x1, self.wide - 1, 0, 4);
        y = middle - 1;
        x = lava_x0;
        while x < lava_x1 {
            run = min(lava_x1 - x, dice.between(3, 5));
            build.solid(x, y, -3, x + run, y + 3, 0);
            x += run;
            if x < lava_x1 {
                turn = dice.between(-4, 4);
                low = max(2, min(self.wide - 5, y + turn));
                build.solid(x - 3, min(y, low), -3, x, max(y, low) + 3, 0);
                y = low;
            }
        }
        build.solid(lava_x1, 1, -3, self.long - 1, self.wide - 1, 0);
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        build.start(2.5, float(middle) + 0.5, self.drop, 0.0);
        build.supply(2.5, 2.5, self.drop, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 4.0, 0, e1m6_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A long hall floored with lava, a causeway down it, ogres on high ledges
and a lift up to one."""
node LavaCauseway(Prefab) {
    has ledge: int = 9,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava causeway";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(28, 34);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(18, 22);
        self.ledge = dice.between(8, 10);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        build.pool(4, 1, -3, self.long - 4, self.wide - 1, 0, 4);
        build.solid(4, middle - 2, -3, self.long - 4, middle + 2, 0);
        # The ledges along both sides high up, slabs over the lava.
        build.solid(4, 1, self.ledge - 1, self.long - 1, 4, self.ledge);
        build.solid(4, self.wide - 4, self.ledge - 1, self.long - 1, self.wide - 1, self.ledge);
        # The lift at the far end up to the north ledge: a plat waiting at the
        # causeway's end.
        step = kit_of(build.district).step;
        build.solid(self.long - 4, 4, -3, self.long - 1, self.wide - 4, 0);
        build.put_box({"classname": "func_plat", "height": str(self.ledge * 16), "speed": "160"}, float(self.long - 4), float(self.wide - 7), float(self.ledge) - 0.5, float(self.long - 1), float(self.wide - 4), float(self.ledge), step);
        for x in range(self.long - 5, self.long - 1) {
            build.keep(hall, x, self.wide - 5, self.ledge);
            build.keep(hall, x, self.wide - 4, self.ledge);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 4)) {
            side = 2.5 if index % 2 == 0 else float(self.wide) - 2.5;
            build.foe(float(8 + index * 5) + 0.5, side, self.ledge, e1m6_foe(dice, self.danger, True), 90.0 if index % 2 == 0 else 270.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, e1m6_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(6.5, 2.5, self.ledge, "item_rockets");
    }
}

"""A corridor lined with doors, rooms behind them; ways on at its ends and
from its middle."""
node DoorHall(Prefab) {
    has rooms: int = 4,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Door hall";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.rooms = dice.between(3, 4);
        self.long = 2 + self.rooms * 7 + 1;
        self.wide = 20;
        self.tall = dice.between(10, 12);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=10.0, floor=0);
        self.leaves = [Port(face=0, along=10.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 8, 0, self.long - 1, 12, self.tall, variant=dice.below(3));
        # A cross passage through the middle to the side ways on.
        mid = self.long // 2;
        build.room(mid - 2, 1, 0, mid + 2, self.wide - 1, self.tall);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Rooms off both sides behind doors, a monster or a pickup in each.
        for index in range(self.rooms) {
            x = 2 + index * 7;
            if abs(x + 2 - mid) < 5 {
                continue;
            }
            for (y0, y1, door_y) in [(2, 7, 7), (13, 18, 12)] {
                room = build.room(x, y0, 0, x + 5, y1, self.tall - 2);
                build.widen(room, x + 1, door_y, 0, x + 4, door_y + 1, 7);
                build.put_box({"classname": "func_door", "angle": "-1", "speed": "120", "wait": "4", "lip": "8"}, float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 7.0, kit_of(build.district).door);
                build.rock_round(float(x + 1), float(door_y), 7.0, float(x + 4), float(door_y + 1), 19.0);
                if dice.chance(0.6) {
                    build.foe(float(x) + 2.5, float(y0 + y1) * 0.5, 0, e1m6_foe(dice, self.danger), 90.0 if y0 == 2 else 270.0);
                } else {
                    build.supply(float(x) + 2.5, float(y0 + y1) * 0.5, 0, ["item_health", "item_rockets", "item_spikes", "item_shells"][dice.below(4)]);
                }
            }
        }
        build.foe(float(mid) + 0.5, 10.5, 0, e1m6_foe(dice, self.danger, True), 180.0);
    }
}

"""The key on a stone island in a lava pool; a button on the shore draws a
bridge up out of the lava to it."""
node LavaKeyShrine(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        shore: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava key shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(15, 17);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(15, 18);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        middle = self.hall_wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        # The lava, from the shore to the far wall, three lifts deep; the
        # island in it, the bridge sunk under the lava's floor until fired.
        lava_x = 1 + self.shore;
        build.pool(lava_x, 1, -3, self.long - 1, side, 0, 4);
        island_x = lava_x + 3;
        build.solid(island_x, middle - 3, -3, self.long - 3, middle + 3, 0);
        bridge = build.name("bridge");
        build.bridge(float(lava_x), float(middle - 1), float(island_x), float(middle + 2), 0, 4, bridge);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, lava_x - 1, y, 0);
            build.keep(hall, island_x, y, 0);
        }
        build.solid(lava_x - 2, middle - 4, 0, lava_x - 1, middle - 3, 4);
        build.button(float(lava_x - 1), float(middle) - 3.5, 1.3, 0, bridge);
        ambush = build.name("ambush");
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, float(island_x) + 3.5, float(middle) + 0.5, 0);
        for index in range(2) {
            x = 2 + index * 4;
            closet = build.room(x, side + 1, 0, x + 3, side + 4, 7);
            build.widen(closet, x, side, 0, x + 3, side + 1, 6);
            build.rising_door(float(x), float(side), 0.0, float(x + 3), float(side + 1), 6.0, {"targetname": ambush, "wait": "-1"});
            build.foe(float(x) + 1.5, float(side) + 2.5, 0, e1m6_foe(dice, self.danger, index == 0), 270.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a great door sixteen lifts high (a key's, as a gate), a lava
moat beyond it, and the way out."""
node ChthonDoor(Prefab) {
    has key: str = "",
        door_x: int = 12,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon door" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(22, 24);
        self.door_x = self.long // 2 - 2;
        self.low = -4;
        self.high = self.tall + 18;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.door_x, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(self.door_x + 1, 1, 0, self.long - 1, self.wide - 1, self.tall);
        build.doorway(hall, self.enter);
        # The great door: eight cells wide, sixteen lifts high, rising into
        # the wall over it.
        build.widen(beyond, self.door_x, middle - 4, 0, self.door_x + 1, middle + 4, 16);
        fields = {"wait": "-1", "speed": "60"};
        if self.key {
            fields["key"] = self.key;
        }
        build.rising_door(float(self.door_x), float(middle - 4), 0.0, float(self.door_x + 1), float(middle + 4), 16.0, fields);
        pillars(build, 4, 3, self.door_x - 2, 4, 0, self.tall, 4, [[0, middle - 3, 5, middle + 3]]);
        pillars(build, 4, self.wide - 4, self.door_x - 2, self.wide - 3, 0, self.tall, 4, [[0, middle - 3, 5, middle + 3]]);
        # Beyond: a lava moat crossed by a stone way, the way out past it.
        moat_x = self.door_x + 4;
        build.pool(moat_x, 1, -3, moat_x + 4, self.wide - 1, 0, 4);
        build.solid(moat_x, middle - 2, -3, moat_x + 4, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(beyond, moat_x - 1, y, 0);
            build.keep(beyond, moat_x + 4, y, 0);
        }
        build.way_out(float(self.long) - 4.0, float(middle), 0);
        for index in range(dice.between(3, 4)) {
            build.foe(float(self.door_x) - 3.5 - float(index % 2) * 3.0, 3.5 + float(index) * 3.5, 0, e1m6_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_rockets");
    }
}

"""e1m6's stretches: [name, role]."""
glob E1M6_STRETCHES: list[list[str]] = [
         ["overlook", "start"],
         ["causeway", "flow"],
         ["doors", "hub"],
         ["doors", "flow"],
         ["shrine", "keyroom"],
         ["door", "end"],
         ["door", "gate"]
     ];

"""One of e1m6's stretches by its name."""
def make_e1m6(name: str, key: str) -> Prefab {
    if name == "overlook" {
        return LavaOverlook();
    }
    if name == "causeway" {
        return LavaCauseway();
    }
    if name == "doors" {
        return DoorHall();
    }
    if name == "shrine" {
        return LavaKeyShrine(key=key if key else "key_gold");
    }
    return ChthonDoor(key=key);
}
