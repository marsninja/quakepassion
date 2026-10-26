"""Prefabs drawn from e1m5, Gloom Keep: a keep of courtyards under the sky,
its walls walked along their tops, its throne hall, its key at the top of
a tower, its gate. Raised in e1m5's own palette.

- `KeepCourtyard`: the start. A courtyard under the sky, a wall-walk round
  three of its sides climbed by stairs, crenels along its edge.
- `Battlements`: a lower ward and the wall-walk over it; the way in at the
  ward, a stair up a corner, the way on along the top (and one below).
- `ThroneKeep`: the keep's hall, pillars down its sides, a throne on a
  high dais at its head; ways on from the floor and the dais (a hub).
- `KeyTower`: a tall tower, a lift up its middle to its top floor and the
  key there; taking it opens the rooms off the floor below, and what
  waits in them meets the climber coming down.
- `PortcullisGate`: the end. A gatehouse, a portcullis (a key's, as a
  gate), and a drawbridge over the moat beyond to the way out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, apart }

glob E1M5: str = "q1:e1m5";

"""e1m5's foes: knights above all, ogres on the walls, fiends deeper in."""
def e1m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_knight", "monster_knight", "monster_ogre"] if heavy else ["monster_knight", "monster_knight", "monster_army"], ["monster_demon1"] if heavy else ["monster_ogre"], danger));
}

"""Crenels along a wall-walk's open edge: a merlon a cell square and two
lifts high every other cell from `start` to `finish` along the line
(x when `along_x`) at `line`, on lift `z`."""
def crenels(build: Raising, line: int, start: int, finish: int, z: int, along_x: bool) {
    for at in range(start, finish, 2) {
        if along_x {
            build.solid(at, line, z, at + 1, line + 1, z + 2);
        } else {
            build.solid(line, at, z, line + 1, at + 1, z + 2);
        }
    }
}

"""The start: a courtyard under the sky, a wall-walk round three sides."""
node KeepCourtyard(Prefab) {
    has walk: int = 8,
        deep: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep courtyard";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(18, 22);
        self.walk = dice.between(8, 9);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=3, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=float(self.wide - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.walk);
        inner_y0 = 1 + self.deep;
        inner_y1 = self.wide - 1 - self.deep;
        far_x = self.long - 1 - self.deep;
        # The wall-walk: north, south and east, solid to its top.
        build.solid(1, 1, 0, self.long - 1, inner_y0, self.walk);
        build.solid(1, inner_y1, 0, self.long - 1, self.wide - 1, self.walk);
        build.solid(far_x, inner_y0, 0, self.long - 1, inner_y1, self.walk);
        crenels(build, inner_y0 - 1, self.walk + 7, far_x, self.walk, True);
        crenels(build, inner_y1, self.walk + 7, far_x, self.walk, True);
        # Stairs up to the walk at the near end of each side, along the wall.
        stair(build, 4, inner_y0, 0, 0, self.walk, 2);
        stair(build, 4, inner_y1 - 2, 0, 0, self.walk, 2);
        for x in [3 + self.walk, 4 + self.walk] {
            build.keep(court, x, inner_y0 - 1, self.walk);
            build.keep(court, x, inner_y1, self.walk);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # The ground way on east runs under the wall-walk: a gate through it.
        build.widen(court, far_x, self.wide // 2 - 2, 0, self.long - 1, self.wide // 2 + 2, 8);
        build.start(2.5, float(self.wide // 2) + 0.5, 0, 0.0);
        build.supply(2.5, float(inner_y0) + 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(self.wide // 2) + 2.5, 0, e1m5_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(far_x) + 1.5, float(inner_y0 + 2 + index * 4) + 0.5, self.walk, e1m5_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.0, self.walk, "item_health");
    }
}

"""A lower ward and the wall-walk over it: in at the ward, up a corner
stair, on along the top."""
node Battlements(Prefab) {
    has walk: int = 9,
        deep: int = 4,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Battlements";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(26, 32);
        self.wide = dice.between(16, 20);
        self.tall = dice.between(18, 22);
        self.walk = dice.between(8, 10);
        self.deep = dice.between(4, 5);
        self.low = -1;
        self.high = self.tall + 1;
        top_y = float(self.wide - 1 - self.deep) + float(self.deep) * 0.5;
        self.enter = Port(face=2, along=float((self.wide - self.deep) // 2), floor=0);
        self.leaves = [Port(face=0, along=top_y, floor=self.walk), Port(face=1, along=float(self.long - 6), floor=self.walk), Port(face=0, along=float((self.wide - self.deep) // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        ward = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ward, self.walk);
        wall_y = self.wide - 1 - self.deep;
        # The wall, solid to its walk, along the far side; crenels on its
        # inner edge; a tower stair up its near end.
        build.solid(1, wall_y, 0, self.long - 1, self.wide - 1, self.walk);
        crenels(build, wall_y, self.walk + 5, self.long - 2, self.walk, True);
        stair(build, 2, wall_y - 2, 0, 0, self.walk, 2);
        for x in [self.walk, self.walk + 1, self.walk + 2] {
            build.keep(ward, x, wall_y, self.walk);
        }
        # Buttresses against the wall below, and a well in the ward.
        for x in range(self.walk + 5, self.long - 3, 5) {
            build.solid(x, wall_y - 1, 0, x + 1, wall_y, self.walk - 2);
        }
        build.pool(self.long // 2 - 1, 2, -4, self.long // 2 + 2, 8, 0, 2);
        build.doorway(ward, self.enter);
        for port in self.taken {
            build.doorway(ward, port);
        }
        for index in range(dice.between(2, 4)) {
            build.foe(float(self.long // 3 + index * 4) + 0.5, 3.5 + float(index % 2) * 3.0, 0, e1m5_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 4 - index * 6) + 0.5, float(wall_y) + float(self.deep) * 0.5, self.walk, e1m5_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.walk, "item_rockets");
    }
}

"""The keep's hall, pillars down its sides, a throne on a high dais at its
head; ways on from the floor and the dais."""
node ThroneKeep(Prefab) {
    has dais: int = 6,
        rise_to: int = 6,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Throne keep";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(20, 24);
        self.dais = dice.between(6, 7);
        self.rise_to = dice.between(5, 7);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        dais_y = float(self.wide - 3);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.rise_to),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.rise_to);
        dais_x = self.long - 1 - self.dais;
        build.solid(dais_x, 4, 0, self.long - 1, self.wide - 1, self.rise_to);
        stair(build, dais_x - self.rise_to, middle - 2, 0, 0, self.rise_to, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, dais_x, y, self.rise_to);
        }
        # The throne: a block on the dais against the far wall.
        build.solid(self.long - 3, middle - 6, self.rise_to, self.long - 2, middle - 3, self.rise_to + 3);
        clear = [[0, middle - 3, 5, middle + 3], [dais_x - self.rise_to - 1, middle - 3, dais_x, middle + 3], [self.long // 2 - 3, 0, self.long // 2 + 3, 4], [self.long // 2 - 3, self.wide - 4, self.long // 2 + 3, self.wide]];
        pillars(build, 5, 4, dais_x - 1, 5, 0, self.tall, 4, clear);
        pillars(build, 5, self.wide - 5, dais_x - 1, self.wide - 4, 0, self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, e1m5_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 2.5, self.rise_to, e1m5_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.rise_to, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A tall tower, a lift up its middle to its top floor and the key there;
taking the key opens the rooms off the floor below."""
node KeyTower(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        top: int = 20,
        tall: int = 28,
        landing: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key tower (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(16, 18);
        self.hall_wide = dice.between(16, 18);
        # The rooms off the landing stand beyond the tower's far wall.
        self.wide = self.hall_wide + 4;
        self.landing = dice.between(9, 11);
        self.top = self.landing + dice.between(9, 11);
        self.tall = self.top + 8;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        step = kit_of(build.district).step;
        cx = self.long // 2;
        cy = self.hall_wide // 2;
        side = self.hall_wide - 1;
        tower = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(tower, self.landing);
        build.level(tower, self.top);
        build.doorway(tower, self.enter);
        # Two floors: a gallery at the landing round the walls, and the top
        # floor round the walls higher still, both slabs a lift thick, the
        # middle open for the lifts.
        for (floor_at, ring) in [(self.landing, 4), (self.top, 4)] {
            build.solid(1, 1, floor_at - 1, self.long - 1, 1 + ring, floor_at);
            build.solid(1, side - ring, floor_at - 1, self.long - 1, side, floor_at);
            build.solid(1, 1 + ring, floor_at - 1, 1 + ring, side - ring, floor_at);
            build.solid(self.long - 1 - ring, 1 + ring, floor_at - 1, self.long - 1, side - ring, floor_at);
        }
        # The lifts: one from the floor to the landing, one from the landing
        # to the top, each a plat waiting at its foot.
        build.put_box({"classname": "func_plat", "height": str(self.landing * 16), "speed": "200"}, float(cx - 3), float(cy - 1), float(self.landing) - 0.5, float(cx - 1), float(cy + 2), float(self.landing), step);
        build.put_box({"classname": "func_plat", "height": str((self.top - self.landing) * 16), "speed": "200"}, float(cx + 1), float(cy - 1), float(self.top) - 0.5, float(cx + 3), float(cy + 2), float(self.top), step);
        # A walk across at the landing from the gallery's west side to the
        # first lift's top and on to the foot of the second, and one at the
        # top from the second lift's top to the top floor's east side.
        build.solid(1 + 4, cy - 1, self.landing - 1, cx - 3, cy + 2, self.landing);
        build.solid(cx - 1, cy - 1, self.landing - 1, cx + 3, cy + 2, self.landing);
        build.solid(cx + 3, cy - 1, self.top - 1, self.long - 5, cy + 2, self.top);
        for x in range(cx - 4, cx + 4) {
            for y in range(cy - 2, cy + 3) {
                build.keep(tower, x, y, self.landing);
                build.keep(tower, x, y, self.top);
            }
        }
        ambush = build.name("ambush");
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1", "target": ambush}, float(self.long) - 3.0, float(cy) + 0.5, self.top);
        # Rooms off the landing behind doors the key opens.
        for (index, x) in enumerate([4, self.long - 7]) {
            closet = build.room(x, side + 1, self.landing, x + 3, side + 4, self.landing + 7);
            build.widen(closet, x, side, self.landing, x + 3, side + 1, self.landing + 6);
            build.rising_door(float(x), float(side), float(self.landing), float(x + 3), float(side + 1), float(self.landing + 6), {"targetname": ambush, "wait": "-1"});
            build.foe(float(x) + 1.5, float(side) + 2.5, self.landing, e1m5_foe(dice, self.danger, index == 0), 270.0);
        }
        build.foe(3.0, 3.0, self.top, e1m5_foe(dice, self.danger), 0.0);
        build.foe(float(self.long) - 3.0, 3.0, 0, e1m5_foe(dice, self.danger), 90.0);
        build.supply(3.0, float(side) - 2.0, self.landing, "item_health");
    }
}

"""The end: a gatehouse, a portcullis (a key's, as a gate), a drawbridge
over the moat to the way out."""
node PortcullisGate(Prefab) {
    has key: str = "",
        moat_x: int = 12,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Portcullis gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M5;
        self.district = level_district(E1M5);
        self.long = dice.between(26, 30);
        self.wide = dice.between(14, 18);
        self.tall = dice.between(16, 18);
        self.moat_x = self.long // 2;
        self.low = -7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.moat_x - 2, self.wide - 1, self.tall, variant=dice.below(3));
        outside = build.room(self.moat_x - 1, 1, 0, self.long - 1, self.wide - 1, self.tall, sky=True);
        build.doorway(hall, self.enter);
        # The gatehouse wall with its portcullis.
        gate_x = self.moat_x - 2;
        build.widen(outside, gate_x, middle - 2, 0, gate_x + 1, middle + 2, 9);
        if self.key {
            build.rising_door(float(gate_x), float(middle - 2), 0.0, float(gate_x + 1), float(middle + 2), 9.0, {"key": self.key, "wait": "-1"});
        }
        # The moat and the drawbridge (down, a span of planks over it).
        build.pool(self.moat_x, 1, -6, self.moat_x + 5, self.wide - 1, 0, 2);
        build.solid(self.moat_x, middle - 2, -1, self.moat_x + 5, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(outside, self.moat_x - 1, y, 0);
            build.keep(outside, self.moat_x + 5, y, 0);
        }
        build.way_out(float(self.long) - 4.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x) - 3.5, 3.5 + float(index) * 4.0, 0, e1m5_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 6.5, 3.5 + float(index) * 5.0, 0, e1m5_foe(dice, self.danger, True), 180.0);
        }
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e1m5's stretches: [name, role]."""
glob E1M5_STRETCHES: list[list[str]] = [
         ["courtyard", "start"],
         ["battlements", "flow"],
         ["throne", "hub"],
         ["throne", "flow"],
         ["tower", "keyroom"],
         ["portcullis", "end"],
         ["portcullis", "gate"]
     ];

"""One of e1m5's stretches by its name."""
def make_e1m5(name: str, key: str) -> Prefab {
    if name == "courtyard" {
        return KeepCourtyard();
    }
    if name == "battlements" {
        return Battlements();
    }
    if name == "throne" {
        return ThroneKeep();
    }
    if name == "tower" {
        return KeyTower(key=key if key else "key_gold");
    }
    return PortcullisGate(key=key);
}
