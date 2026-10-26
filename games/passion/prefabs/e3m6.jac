"""Prefabs drawn from e3m6, the Chambers of Torment: torture yards sunk
below their walkways, a narrow bridge high over a chasm, a pit climbed out
of by teleporter, the key on a pillar over a pit reached by teleporter.
Raised in e3m6's own palette.

- `TormentYard`: the start. A floor sunk below walkways round three of its
  sides, a stair down into it; ways on from the floor and the walkways.
- `TormentBridge`: a narrow bridge high over a chasm, a stair up the
  chasm's wall for whoever falls; ogres below.
- `TormentPit`: a pit below a ledge, a stair up from its floor to the
  ledge, a teleporter on its floor to a ledge high on its far wall; ways
  on from the ledges and the pit (a hub).
- `TormentPillar`: the key on a pillar in a pit, a teleporter out to it
  and one back; taking the key opens the closets.
- `TormentExit`: the end. A door (a key's, as a gate) into a chamber, the
  slipgate on a dais between racks."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M6: str = "q1:e3m6";

"""e3m6's foes: ogres and scrags, hell knights, vores deeper in."""
def e3m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_ogre", "monster_wizard"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.3 if heavy else danger * 0.7));
}

"""The start: a floor sunk below walkways round three sides, a stair down."""
node TormentYard(Prefab) {
    has sunk: int = 4,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment yard";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(24, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(15, 17);
        self.sunk = dice.between(4, 5);
        self.low = -self.sunk - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.sunk), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.sunk;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(yard, low);
        build.widen(yard, 7, 5, low, self.long - 1, self.wide - 5, 0);
        stair(build, 6 + self.sunk, 5, low, 2, self.sunk, self.wide - 10);
        # Gallows on the sunk floor.
        clear = [[6 + self.sunk, 4, 8 + self.sunk, self.wide - 4], [self.long - 4, middle - 3, self.long, middle + 3]];
        pillars(build, 9 + self.sunk, 7, self.long - 3, self.wide - 7, low, low + 7, 4, clear);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 4) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), low, e3m6_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.5, 3.0, 0, e3m6_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 4, "monster_wizard", 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""A narrow bridge high over a chasm, a stair up the chasm's wall."""
node TormentBridge(Prefab) {
    has deep: int = 10,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment bridge";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(26, 28);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(9, 10);
        self.tall = dice.between(11, 13);
        self.low = -self.deep - 1;
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
        low = -self.deep;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        x0 = 6;
        x1 = self.long - 7;
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        build.solid(x0, middle - 1, -1, x1, middle + 1, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        for y in [middle - 1, middle] {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 12 + index * 3) + 0.5, float(self.wide) - 3.5 - float(index) * 2.0, low, e3m6_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 3.5, 3, "monster_wizard", 180.0);
        build.foe(float(x1) + 3.5, float(middle) + 3.5, 0, e3m6_foe(dice, self.danger, True), 180.0);
        build.supply(float(x0 + 13) + 0.5, 3.0, low, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""A pit below a ledge, a stair up from its floor, a teleporter on its
floor to a ledge high on its far wall."""
node TormentPit(Prefab) {
    has deep: int = 6,
        high_ledge: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment pit";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(24, 26);
        self.wide = dice.between(22, 24);
        self.deep = dice.between(5, 6);
        self.high_ledge = dice.between(6, 7);
        self.tall = self.high_ledge + 10;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.high_ledge),
            Port(face=1, along=3.0, floor=0),
            Port(face=3, along=float(self.long // 2) + 2.0, floor=-self.deep),
            Port(face=0, along=4.0, floor=-self.deep)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        low = -self.deep;
        pit = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.level(pit, self.high_ledge);
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        stair(build, 5 + self.deep, 1, low, 2, self.deep, 3);
        build.solid(self.long - 5, 1, self.high_ledge - 1, self.long - 1, self.wide - 1, self.high_ledge);
        for y in range(2, self.wide - 2) {
            build.keep(pit, self.long - 5, y, self.high_ledge);
        }
        build.teleporter(float(self.long // 2) + 0.5, float(cy) + 0.5, low, float(self.long) - 3.0, float(cy) + 3.5, self.high_ledge, 180.0);
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 3) + 0.5, float(cy) + (4.5 if index % 2 == 0 else -4.5), low, e3m6_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 3.0, 3.5, self.high_ledge, e3m6_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.5, self.high_ledge, "item_health");
        build.supply(3.0, float(self.wide) - 3.0, 0, "item_rockets");
    }
}

"""The key on a pillar in a pit, a teleporter out to it and one back;
taking the key opens the closets."""
node TormentPillar(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment pillar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M6;
        self.district = level_district(E3M6);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(13, 15);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, low);
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 2;
        build.widen(hall, x0, 1, low, x1, side, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        cx = (x0 + x1) // 2 + 1;
        build.solid(cx - 2, cy - 2, low, cx + 2, cy + 2, 0);
        build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy), 0, 0.0);
        build.teleporter(float(cx) + 1.0, float(cy) + 1.0, 0, 3.0, 3.0, 0, 180.0);
        key_ambush(build, self.key, float(cx) + 1.0, float(cy) - 1.0, 0, side, 0, [2], [e3m6_foe(dice, self.danger, True)]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + self.deep + 1 + index * 2) + 0.5, float(side) - 2.5, low, e3m6_foe(dice, self.danger), 270.0);
        }
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a chamber, the slipgate on a dais between racks."""
node TormentExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Torment exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M6;
        self.district = level_district(E3M6);
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        chamber = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(chamber, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # Racks: low blocks along both walls.
        for x in range(wall + 3, self.long - 6, 4) {
            build.solid(x, 1, 0, x + 2, 3, 2);
            build.solid(x, self.wide - 3, 0, x + 2, self.wide - 1, 2);
        }
        dais_x = self.long - 6;
        build.solid(dais_x, 2, 0, self.long - 1, self.wide - 2, 2);
        stair(build, dais_x - 2, middle - 2, 0, 0, 2, 4);
        build.way_out(float(self.long) - 3.0, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m6_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dais_x) - 3.5, float(middle) + 3.0, 0, e3m6_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m6's stretches: [name, role]."""
glob E3M6_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["bridge", "flow"],
         ["pit", "hub"],
         ["pit", "flow"],
         ["pillar", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m6's stretches by its name."""
def make_e3m6(name: str, key: str) -> Prefab {
    if name == "yard" {
        return TormentYard();
    }
    if name == "bridge" {
        return TormentBridge();
    }
    if name == "pit" {
        return TormentPit();
    }
    if name == "pillar" {
        return TormentPillar(key=key if key else "key_gold");
    }
    return TormentExit(key=key);
}
