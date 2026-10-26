"""Prefabs drawn from e4m2, the Tower of Despair: a tower standing in a
court, climbed by a stair winding round its outside, ledges up a shaft
teleported to one from the next, a hall round a sunken arena, the silver
key on a pillar's top up a stair round it. Raised in e4m2's own palette.

- `DespairTower`: the start. A court under the sky, a tower in its middle,
  a stair winding up round the tower's outside to a landing and a bridge
  from it to a way on high in the court's wall; ways on below too.
- `DespairTeleports`: a shaft of ledges, south, north and south again, a
  teleporter on the floor and on each ledge to the next; the way on from
  the top.
- `DespairHall`: a hall, an arena sunk in its middle, a gallery along two
  walls ridden up to by lifts; ways on from the floor and the gallery (a
  hub).
- `DespairSummit`: a pillar in a hall, a stair winding up round it, the
  key on its top; taking it opens the closets.
- `DespairExit`: the end. A door (a key's, as a gate) onto a balcony over
  a pit, a narrow bridge to the slipgate; a stair up out of the pit."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, spiral, ring_landing }

glob E4M2: str = "q1:e4m2";

"""e4m2's foes: knights and ogres, hell knights and vores deeper in."""
def e4m2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_knight", "monster_knight", "monster_ogre"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""The start: a tower in a court, a stair winding up round its outside to
a landing and a bridge to a way on high in the court's wall."""
node DespairTower(Prefab) {
    has steps: int = 24,
        tall: int = 32;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair tower";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        cx = self.long // 2;
        cy = self.wide // 2;
        fits: list[int] = [];
        for steps in range(18, 32) {
            landing = ring_landing(cx - 7, cy - 7, cx + 7, cy + 7, 3, steps, 5);
            if landing and landing[0] == 1.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 8;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(cx - 7, cy - 7, cx + 7, cy + 7, 3, self.steps, 5);
        middle = float(cy);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=top[1], floor=self.steps), Port(face=0, along=middle, floor=0), Port(face=3, along=float(cx), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.steps);
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.steps);
        landing = spiral(build, cx - 7, cy - 7, cx + 7, cy + 7, 0, self.steps, 3, 5);
        mid = landing[2];
        build.solid(mid[0] - 3, mid[3], self.steps - 1, mid[0] + 4, self.wide - 1, self.steps);
        for x in range(mid[0] - 3, mid[0] + 4) {
            build.keep(court, x, mid[3] - 1, self.steps);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 4.5 + float(index) * 6.0, 0, e4m2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps, e4m2_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx + 5) + 0.5, float(cy) + 0.5, 14, e4m2_foe(dice, self.danger), 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.steps, "item_health");
    }
}

"""A shaft of ledges, a teleporter on the floor and on each ledge to the
next."""
node DespairTeleports(Prefab) {
    has rise_by: int = 6,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair teleports";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(16, 18);
        self.wide = dice.between(16, 18);
        self.rise_by = dice.between(6, 7);
        self.tall = 3 * self.rise_by + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=3.5, floor=3 * self.rise_by), Port(face=3, along=float(self.long // 2), floor=3 * self.rise_by)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        first = self.rise_by;
        second = 2 * self.rise_by;
        top = 3 * self.rise_by;
        cx = self.long // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [first, second, top] {
            build.level(shaft, z);
        }
        north = self.wide - 6;
        build.solid(1, 1, first - 1, self.long - 1, 6, first);
        build.solid(1, north, second - 1, self.long - 1, self.wide - 1, second);
        build.solid(1, 1, top - 1, self.long - 1, 6, top);
        for x in range(2, self.long - 2) {
            build.keep(shaft, x, 5, first);
            build.keep(shaft, x, north, second);
            build.keep(shaft, x, 5, top);
        }
        build.teleporter(float(cx) + 0.5, float(self.wide // 2) + 0.5, 0, float(cx) + 0.5, 3.0, first, 0.0);
        build.teleporter(3.5, 3.5, first, float(cx) + 0.5, float(self.wide) - 3.0, second, 0.0);
        build.teleporter(3.5, float(self.wide) - 3.5, second, float(self.long) - 4.0, 3.5, top, 0.0);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        build.foe(float(self.long) - 3.5, 3.0, first, e4m2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, second, e4m2_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, 3.0, top, e4m2_foe(dice, self.danger), 0.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(cx) - 3.5, float(self.wide) - 3.0, second, "item_shells");
    }
}

"""A hall, an arena sunk in its middle, a gallery along two walls ridden up
to by lifts."""
node DespairHall(Prefab) {
    has gallery: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair hall";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 11;
        self.low = -4;
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, -3);
        build.level(hall, self.gallery);
        # The arena, three steps down at either end.
        build.widen(hall, 7, 7, -3, self.long - 7, self.wide - 7, 0);
        stair(build, 9, 7, -3, 2, 3, self.wide - 14);
        stair(build, self.long - 10, 7, -3, 0, 3, self.wide - 14);
        # The gallery along the north and east walls, lifts up to it.
        under = self.gallery - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(self.long - 4, 1, under, self.long - 1, self.wide - 4, self.gallery);
        step = kit_of(build.district).step;
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, 3.0, float(self.wide - 7), float(self.gallery) - 0.5, 6.0, float(self.wide - 4), float(self.gallery), step);
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "200"}, float(self.long - 7), 3.0, float(self.gallery) - 0.5, float(self.long - 4), 6.0, float(self.gallery), step);
        for x in range(2, 7) {
            build.keep(hall, x, self.wide - 4, self.gallery);
        }
        for y in range(2, 7) {
            build.keep(hall, self.long - 4, y, self.gallery);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(11 + index * 2) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), -3, e4m2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.gallery, e4m2_foe(dice, self.danger, True), 270.0);
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.gallery, e4m2_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, "item_health");
        build.supply(3.0, 3.0, 0, "item_spikes");
    }
}

"""A pillar in a hall, a stair winding up round it, the key on its top;
taking it opens the closets."""
node DespairSummit(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        steps: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair summit (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.steps = dice.between(8, 11);
        self.tall = self.steps + 8;
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
        cx = self.long // 2 + 1;
        cy = side // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.steps);
        build.doorway(hall, self.enter);
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.steps);
        spiral(build, cx - 4, cy - 4, cx + 4, cy + 4, 0, self.steps, 2, 2);
        key_ambush(build, self.key, float(cx), float(cy), self.steps, side, 0, [2, self.long - 5], [e4m2_foe(dice, self.danger, True), e4m2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, e4m2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door onto a balcony over a pit, a narrow bridge to the
slipgate; a stair up out of the pit."""
node DespairExit(Prefab) {
    has key: str = "",
        deep: int = 8,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(7, 8);
        self.tall = dice.between(11, 13);
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
        build.doorway(hall, self.enter);
        build.widen(pit, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        x0 = wall + 4;
        x1 = self.long - 6;
        build.solid(wall + 1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, middle - 3, low, self.long - 1, middle + 3, 0);
        build.solid(x0, middle - 1, -1, x1, middle + 1, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        for y in [middle - 1, middle] {
            build.keep(pit, x0 - 1, y, 0);
            build.keep(pit, x1, y, 0);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0 + 10) + 0.5, float(self.wide) - 2.5, low, e4m2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m2's stretches: [name, role]."""
glob E4M2_STRETCHES: list[list[str]] = [
         ["tower", "start"],
         ["teleports", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["summit", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m2's stretches by its name."""
def make_e4m2(name: str, key: str) -> Prefab {
    if name == "tower" {
        return DespairTower();
    }
    if name == "teleports" {
        return DespairTeleports();
    }
    if name == "hall" {
        return DespairHall();
    }
    if name == "summit" {
        return DespairSummit(key=key if key else "key_silver");
    }
    return DespairExit(key=key);
}
