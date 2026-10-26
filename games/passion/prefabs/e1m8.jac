"""Prefabs drawn from e1m8, Ziggurat Vertigo: narrow ways over a void, a
ziggurat climbed tier by tier, a key on a small ziggurat out in the void.
Raised in e1m8's own palette. A fall into the void lands in water far
below, and a lift there rises back to where the way began.

- `VoidLanding`: the start. A platform at the edge of a deep void, a
  narrow way across it (no railings) to the far platform.
- `Ziggurat`: a hall and a stepped ziggurat in it, a step up each tier's
  face; a bridge from its top to a way on high in the wall, and ways on
  from the floor (a hub).
- `VertigoWalk`: a narrow way across a void, turning and stepping up, a
  cell's gap here and there to leap.
- `SilverAltar`: a small ziggurat out in a void, reached by a narrow way,
  the key on its top; taking it opens the closets high in the walls.
- `VoidExit`: the end. A narrow way to a platform and the way out on it;
  as a gate, a key door in a wall across the platform."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }

glob E1M8: str = "q1:e1m8";

"""e1m8's foes: ogres on the platforms, scrags in the void."""
def e1m8_foe(dice: Stream, danger: float, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre", "monster_knight"], ["monster_shambler"], danger * 0.3));
}

"""A void: the room's floor a pit `depth` lifts deep over the box x0..x1,
y0..y1, water at its foot with steps up out of it along its near side,
and at the steps' head a lift rising to lift 0 at the pit's near edge,
where the way began. (`lift_x`, `lift_y` are kept for the callers; the
lift always stands at the steps' head.)"""
def void_pit(build: Raising, room: Space, x0: int, x1: int, y0: int, y1: int, depth: int, lift_x: int, lift_y: int) {
    build.widen(room, x0, y0, -depth, x1, y1, 0);
    build.pool(x0, y0, -depth, x1, y1, -depth + 4, 2);
    at_y = y0 + 4;
    build.solid(x0, at_y, -depth, x0 + 2, at_y + 3, -depth + 4);
    build.put_box({"classname": "func_plat", "height": str((depth - 4) * 16), "speed": "220"}, float(x0), float(at_y), -0.5, float(x0 + 2), float(at_y + 3), 0.0, kit_of(build.district).step);
    for x in range(x0 - 1, x0 + 3) {
        for y in range(at_y - 1, at_y + 4) {
            build.keep(room, x, y, 0);
        }
    }
}

"""Keep every cell of a narrow way clear of railings."""
def bare(build: Raising, room: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(room, x, y, z);
        }
    }
}

"""The start: a platform at a void's edge, a narrow way across it."""
node VoidLanding(Prefab) {
    has depth: int = 20,
        lane: int = 8,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void landing";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(24, 28);
        self.wide = dice.between(18, 22);
        self.depth = dice.between(18, 22);
        self.tall = dice.between(12, 16);
        self.lane = dice.between(4, self.wide - 7);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        void_pit(build, room, 7, self.long - 7, 1, self.wide - 1, self.depth, 7, 1);
        # The way across: two cells wide, a jog halfway.
        half = self.long // 2;
        build.solid(7, self.lane, -1, half, self.lane + 2, 0);
        jog = max(3, min(self.wide - 5, self.lane + dice.between(-4, 4)));
        build.solid(half - 2, min(self.lane, jog), -1, half, max(self.lane, jog) + 2, 0);
        build.solid(half - 2, jog, -1, self.long - 7, jog + 2, 0);
        bare(build, room, 6, 1, self.long - 6, self.wide - 1, 0);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        build.start(2.5, float(self.wide // 2) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        for index in range(dice.between(1, 2)) {
            build.foe(float(half) + 0.5, float(self.wide // 2) + 0.5, 6, e1m8_foe(dice, self.danger, True), 180.0);
        }
        build.foe(float(self.long) - 3.5, float(self.wide // 2) + 0.5, 0, e1m8_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""A hall and a stepped ziggurat; a bridge from its top to a way on high,
and ways on from the floor."""
node Ziggurat(Prefab) {
    has tiers: int = 6,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ziggurat";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.tiers = dice.between(5, 6);
        self.long = 6 + 4 * self.tiers + 10;
        self.wide = 6 + 4 * self.tiers + 6;
        self.tall = 2 * self.tiers + dice.between(12, 14);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=2 * self.tiers), Port(face=1, along=float(self.long // 2 - 4), floor=0), Port(face=3, along=float(self.long // 2 - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        cx = self.long // 2 - 2;
        cy = self.wide // 2;
        biggest = 2 * self.tiers + 1;
        for tier in range(self.tiers) {
            radius = biggest - 2 * tier;
            top = 2 * (tier + 1);
            build.solid(cx - radius, cy - radius, 0, cx + radius, cy + radius, top);
            build.level(hall, top);
            # A step a lift below the tier's top against its west and east
            # faces, on the tier below.
            build.solid(cx - radius - 1, cy - 1, 0, cx - radius, cy + 1, top - 1);
            build.solid(cx + radius, cy - 1, 0, cx + radius + 1, cy + 1, top - 1);
            for (x, y) in [(cx - radius - 1, cy - 1), (cx - radius - 1, cy), (cx + radius, cy - 1), (cx + radius, cy)] {
                build.keep(hall, x, y, top - 1);
                build.keep(hall, x, y, top);
            }
        }
        # The bridge from the top east to the way on high in the wall.
        summit = 2 * self.tiers;
        last = biggest - 2 * (self.tiers - 1);
        build.solid(cx + last, cy - 2, summit - 1, self.long - 1, cy + 2, summit);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 0.5, float(cy) + 0.5, summit + 4 + index * 2, e1m8_foe(dice, self.danger, True), float(index * 120));
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, summit, e1m8_foe(dice, self.danger), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(4.5, 4.5 + float(index) * float(self.wide - 9), 0, e1m8_foe(dice, self.danger), 0.0);
        }
        build.supply(float(cx) - 1.5, float(cy) + 0.5, summit, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_rockets");
    }
}

"""A narrow way across a void, turning and stepping up, a cell's gap to
leap here and there."""
node VertigoWalk(Prefab) {
    has depth: int = 18,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vertigo walk";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.depth = dice.between(16, 20);
        self.tall = dice.between(14, 16);
        self.low = -self.depth - 1;
        self.high = self.tall + 4;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=2), Port(face=1, along=float(self.long - 3), floor=2)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall + 2, variant=dice.below(3));
        void_pit(build, room, 4, self.long - 4, 1, self.wide - 1, self.depth, 4, self.wide - 4);
        # The far ledge two lifts up.
        build.solid(self.long - 4, 1, 0, self.long - 1, self.wide - 1, 2);
        # The way: segments two cells wide along a line wandering across the
        # void, a lift up halfway, a cell's gap between some segments.
        x = 4;
        y = self.wide // 2 - 1;
        lift = 0;
        while x < self.long - 4 {
            run = min(self.long - 4 - x, dice.between(3, 5));
            build.solid(x, y, lift - 1, x + run, y + 2, lift);
            x += run;
            if x >= self.long // 2 and lift < 2 {
                lift += 1;
            }
            if x < self.long - 6 and dice.chance(0.35) {
                x += 1;
            }
            shifted = max(3, min(self.wide - 5, y + dice.between(-3, 3)));
            if shifted != y and x < self.long - 4 {
                build.solid(x, min(y, shifted), lift - 1, x + 2, max(y, shifted) + 2, lift);
                y = shifted;
                x += 2;
            }
        }
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 0);
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 1);
        bare(build, room, 3, 1, self.long - 3, self.wide - 1, 2);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 7) + 0.5, float(self.wide // 2) + 3.5, 5, e1m8_foe(dice, self.danger, True), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(self.wide // 2) + 0.5, 2, e1m8_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 2, "item_health");
    }
}

"""A small ziggurat out in a void, the key on its top; taking it opens the
closets high in the walls."""
node SilverAltar(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        depth: int = 18,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver altar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(24, 28);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.depth = dice.between(16, 20);
        self.tall = dice.between(16, 18);
        self.low = -self.depth - 1;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        void_pit(build, room, 5, self.long - 2, 1, side, self.depth, 5, 1);
        # The small ziggurat: three tiers on a pillar out of the void.
        cx = (5 + self.long - 2) // 2 + 1;
        build.solid(cx - 4, middle - 4, -self.depth, cx + 4, middle + 4, 0);
        for tier in range(3) {
            radius = 3 - tier;
            build.solid(cx - radius, middle - radius, 0, cx + radius, middle + radius, 2 * (tier + 1));
        }
        build.solid(5, middle - 1, -1, cx - 4, middle + 1, 0);
        # Steps up the tiers' west face.
        for tier in range(3) {
            radius = 3 - tier;
            build.solid(cx - radius - 1, middle - 1, 0, cx - radius, middle + 1, 2 * tier + 1);
        }
        bare(build, room, 4, middle - 2, cx + 4, middle + 2, 0);
        build.doorway(room, self.enter);
        ambush = build.name("ambush");
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, float(cx) + 0.5, float(middle) + 0.5, 6);
        for index in range(3) {
            x = 6 + index * 6;
            if x + 3 >= self.long - 2 {
                break;
            }
            closet = build.room(x, side + 1, 6, x + 3, side + 4, 13);
            build.widen(closet, x, side, 6, x + 3, side + 1, 12);
            build.rising_door(float(x), float(side), 6.0, float(x + 3), float(side + 1), 12.0, {"targetname": ambush, "wait": "-1"});
            build.foe(float(x) + 1.5, float(side) + 2.5, 6, e1m8_foe(dice, self.danger, True), 270.0);
        }
        build.foe(float(cx) + 2.5, float(middle) + 2.5, 0, e1m8_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a narrow way to a platform and the way out; as a gate, a key
door in a wall across the platform."""
node VoidExit(Prefab) {
    has key: str = "",
        depth: int = 18,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M8;
        self.district = level_district(E1M8);
        self.long = dice.between(24, 28);
        self.wide = dice.between(14, 16);
        self.depth = dice.between(16, 20);
        self.tall = dice.between(14, 16);
        self.low = -self.depth - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        platform = self.long - 9;
        void_pit(build, room, 4, platform, 1, self.wide - 1, self.depth, 4, 1);
        build.solid(4, middle - 1, -1, platform, middle + 1, 0);
        bare(build, room, 3, middle - 2, platform + 1, middle + 2, 0);
        # A wall across the platform with the way through it; the door is a
        # key's when the stretch is a gate.
        wall = platform + 2;
        build.solid(wall, 1, 0, wall + 1, middle - 2, self.tall);
        build.solid(wall, middle + 2, 0, wall + 1, self.wide - 1, self.tall);
        build.solid(wall, middle - 2, 8, wall + 1, middle + 2, self.tall);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(float(self.long) - 4.0, float(middle), 0);
        build.doorway(room, self.enter);
        for index in range(dice.between(1, 2)) {
            build.foe(float(platform // 2) + 0.5, float(middle) + 3.5, 5, e1m8_foe(dice, self.danger, True), 180.0);
        }
        build.foe(float(wall) - 1.5, float(middle) + 3.5, 0, e1m8_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e1m8's stretches: [name, role]."""
glob E1M8_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["ziggurat", "hub"],
         ["ziggurat", "flow"],
         ["vertigo", "flow"],
         ["altar", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e1m8's stretches by its name."""
def make_e1m8(name: str, key: str) -> Prefab {
    if name == "landing" {
        return VoidLanding();
    }
    if name == "ziggurat" {
        return Ziggurat();
    }
    if name == "vertigo" {
        return VertigoWalk();
    }
    if name == "altar" {
        return SilverAltar(key=key if key else "key_silver");
    }
    return VoidExit(key=key);
}
