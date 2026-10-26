"""Prefabs drawn from Quake II's city1, the Outer Courts of the Strogg city:
courts under the sky round fountains, canals walked along their quays
and bridged, a plaza round a great fountain with terraces, the key in a
gatehouse up a stair. Raised in city1's own palette.

- `OuterCourt`: the start. A court under the sky, colonnades along two
  sides, gates out; ways on.
- `CanalWalk`: a canal down a court's middle, quays along both sides,
  bridges arching over it.
- `FountainPlaza`: a plaza round a great fountain, terraces up steps along
  two sides; ways on from the plaza and the terraces (a hub).
- `CityGatehouse`: the key in a gatehouse room up a stair; taking it opens
  the closets.
- `City1Exit`: the end. A door (a key's, as a gate), a court, the way out
  under an arch."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, gate_into }

glob CITY1: str = "q2:city1";

"""city1's foes: elite soldiers and hovers, gladiators and tank commanders
deeper in."""
def city1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_soldier_ss", "monster_gladiator"] if heavy else ["monster_soldier_ss", "monster_soldier_ss", "monster_hover"], ["monster_tank_commander"] if heavy else ["monster_gladiator"], danger * 0.3 if heavy else danger * 0.5));
}

"""The start: a court, colonnades along two sides, gates out."""
node OuterCourt(Prefab) {
    has tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Outer court";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(18, 22);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        clear = [[0, middle - 3, 5, middle + 3], [self.long // 2 - 3, 0, self.long // 2 + 3, self.wide], [self.long - 5, middle - 3, self.long, middle + 3]];
        pillars(build, 4, 5, self.long - 4, 6, 0, 10, 3, clear);
        pillars(build, 4, self.wide - 6, self.long - 4, self.wide - 5, 0, 10, 3, clear);
        build.solid(4, 1, 9, self.long - 4, 6, 10);
        build.solid(4, self.wide - 6, 9, self.long - 4, self.wide - 1, 10);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, city1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 12, "monster_hover", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A canal down a court's middle, quays along both sides, bridges arching
over it."""
node CanalWalk(Prefab) {
    has deep: int = 5,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canal walk";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(4, 6);
        self.tall = dice.between(16, 20);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=3.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.pool(1, middle - 3, -self.deep, self.long - 1, middle + 3, 0, 2, False, False);
        for x in [3, self.long // 2 - 1, self.long - 6] {
            stair(build, x, middle - 4 + self.deep, -self.deep, 3, self.deep, 2);
        }
        for x in [8, self.long - 11] {
            build.solid(x, middle - 3, -1, x + 3, middle + 3, 0);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 6) + 0.5, 3.0 if index % 2 == 0 else float(self.wide) - 3.0, 0, city1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 8, "monster_hover", 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A plaza round a great fountain, terraces up steps along two sides."""
node FountainPlaza(Prefab) {
    has terrace: int = 4,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fountain plaza";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.terrace = dice.between(3, 5);
        self.tall = dice.between(18, 22);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.terrace),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.terrace),
            Port(face=0, along=4.0, floor=self.terrace)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        plaza = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(plaza, self.terrace);
        build.pool(cx - 5, cy - 5, -3, cx + 5, cy + 5, 0, 2, False, True, True);
        build.solid(cx - 1, cy - 1, -3, cx + 1, cy + 1, 6);
        build.solid(1, 1, 0, self.long - 1, 6, self.terrace);
        build.solid(1, self.wide - 6, 0, self.long - 1, self.wide - 1, self.terrace);
        stair(build, 4, 6 + self.terrace - 1, 0, 3, self.terrace, 4);
        stair(build, 4, self.wide - 6 - self.terrace, 0, 1, self.terrace, 4);
        for x in range(4, 8) {
            build.keep(plaza, x, 5, self.terrace);
            build.keep(plaza, x, self.wide - 6, self.terrace);
        }
        build.doorway(plaza, self.enter);
        for port in self.taken {
            build.doorway(plaza, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 6) + 0.5, float(cy) + (7.0 if index % 2 == 0 else -7.0), 0, city1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 6.5, 3.0, self.terrace, city1_foe(dice, self.danger, True), 90.0);
        build.foe(float(cx) + 0.5, float(cy) + 4.5, 8, "monster_hover", 180.0);
        build.supply(float(cx) - 6.0, 3.0, self.terrace, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a gatehouse room up a stair; taking it opens the closets."""
node CityGatehouse(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City gatehouse (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.upper = dice.between(5, 6);
        self.tall = self.upper + 8;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.upper);
        build.doorway(room, self.enter);
        ux = self.long - 7;
        build.solid(ux, 1, 0, self.long - 1, side, self.upper);
        stair(build, ux - self.upper, cy - 2, 0, 0, self.upper, 4);
        for y in range(cy - 2, cy + 2) {
            build.keep(room, ux, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.upper, side, 0, [2, ux - 5], [city1_foe(dice, self.danger, True), city1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper, city1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a court, the way out under an arch."""
node City1Exit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Court arch" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 20);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        ax = self.long - 7;
        build.solid(ax, 1, 0, ax + 2, middle - 2, 12);
        build.solid(ax, middle + 2, 0, ax + 2, self.wide - 1, 12);
        build.solid(ax, middle - 2, 9, ax + 2, middle + 2, 12);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, city1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(ax) - 3.5, float(middle) + 3.5, 0, city1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""city1's stretches: [name, role]."""
glob CITY1_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["canal", "flow"],
         ["plaza", "hub"],
         ["plaza", "flow"],
         ["gatehouse", "keyroom"],
         ["arch", "end"],
         ["arch", "gate"]
     ];

"""One of city1's stretches by its name."""
def make_city1(name: str, key: str) -> Prefab {
    if name == "court" {
        return OuterCourt();
    }
    if name == "canal" {
        return CanalWalk();
    }
    if name == "plaza" {
        return FountainPlaza();
    }
    if name == "gatehouse" {
        return CityGatehouse(key=key if key else "key_silver");
    }
    return City1Exit(key=key);
}
