"""Prefabs drawn from Quake II's fact3, the Sudden Death works: a short run
through the factory's upper works, a lobby over a slime duct, the duct
itself walked along its ledges, a production line raised on a gantry,
the key in a design office up a stair. fact3 holds few foes; its own
stretches keep few. Raised in fact3's own palette.

- `UpperLobby`: the start. A lobby, a slime duct cut across its floor
  under a grate of beams; ways on beyond.
- `SlimeDuct`: a duct of slime down a hall's length, ledges along both
  walls, a crossing at each end.
- `ProductionLine`: a hall, the line on a gantry down its middle up stairs
  at both ends, presses beside it; ways on from the floor and the gantry
  (a hub).
- `DesignOffice`: the key in an office up a stair over a drafting floor;
  taking it opens the closets.
- `Fact3Exit`: the end. A door (a key's, as a gate), the way out past a
  slime moat on a walk."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob FACT3: str = "q2:fact3";

"""fact3's foes, few: soldiers and gunners, a gladiator deeper in."""
def fact3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_soldier_ss"] if heavy else ["monster_soldier_light", "monster_soldier"], ["monster_gladiator"] if heavy else ["monster_gunner"], danger * 0.5));
}

"""The start: a lobby, a slime duct cut across its floor under a grate."""
node UpperLobby(Prefab) {
    has tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Upper lobby";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(22, 24);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(12, 14);
        self.low = -4;
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
        lobby = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        dx = self.long // 2 - 2;
        build.pool(dx, 1, -3, dx + 4, self.wide - 1, 0, 3, False, True);
        stair(build, dx + 1, self.wide - 3, -3, 0, 3, 2);
        for y in range(2, self.wide - 2, 2) {
            build.solid(dx, y, -1, dx + 4, y + 1, 0);
        }
        build.solid(dx, middle - 2, -1, dx + 4, middle + 2, 0);
        build.doorway(lobby, self.enter);
        for port in self.taken {
            build.doorway(lobby, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(1, 2)) {
            build.foe(float(dx + 7) + 0.5, 3.5 + float(index) * 6.0, 0, fact3_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A duct of slime down a hall's length, ledges along both walls, a
crossing at each end."""
node SlimeDuct(Prefab) {
    has tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime duct";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(10, 12);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        duct = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(5, 4, -3, self.long - 5, self.wide - 4, 0, 3, False, True, True);
        stair(build, self.long - 8, 4, -3, 0, 3, 2);
        stair(build, self.long - 8, self.wide - 6, -3, 0, 3, 2);
        for x in [9, self.long - 12] {
            build.solid(x, 4, -1, x + 3, self.wide - 4, 0);
        }
        build.doorway(duct, self.enter);
        for port in self.taken {
            build.doorway(duct, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, 0, fact3_foe(dice, self.danger, index == 1), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall, the line on a gantry down its middle up stairs at both ends,
presses beside it."""
node ProductionLine(Prefab) {
    has gantry: int = 5,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Production line";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.gantry = dice.between(4, 6);
        self.tall = self.gantry + 11;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 4.0, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.gantry),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gantry);
        g0 = 4 + self.gantry;
        build.solid(g0, middle - 2, self.gantry - 1, self.long - 1, middle + 2, self.gantry);
        stair(build, 4, middle - 2, 0, 0, self.gantry, 4);
        for x in range(g0 + 2, self.long - 3, 5) {
            build.solid(x, middle - 2, 0, x + 1, middle + 2, self.gantry - 1);
            build.solid(x, middle - 5, 0, x + 2, middle - 3, 4);
            build.solid(x, middle + 3, 0, x + 2, middle + 5, 4);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(g0 + 3 + index * 5) + 0.5, float(middle) + 0.5, self.gantry, fact3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, fact3_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.gantry, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an office up a stair over a drafting floor; taking it opens
the closets."""
node DesignOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 5,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Design office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(5, 6);
        self.tall = self.office + 8;
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
        build.level(room, self.office);
        build.doorway(room, self.enter);
        ox = self.long - 7;
        build.solid(ox, 1, self.office - 1, self.long - 1, side, self.office);
        stair(build, ox - self.office, 1, 0, 0, self.office, 3);
        for x in range(4, ox - 3, 4) {
            build.solid(x, cy - 1, 0, x + 2, cy + 2, 2);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.office, side, 0, [2, ox - 4], [fact3_foe(dice, self.danger, True), fact3_foe(dice, self.danger)]);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the way out past a slime moat on a walk."""
node Fact3Exit(Prefab) {
    has key: str = "",
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Works exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(12, 14);
        self.low = -4;
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        px0 = wall + 7;
        px1 = self.long - 4;
        build.pool(wall + 4, 2, -3, self.long - 1, self.wide - 2, 0, 3, False, True, True);
        build.solid(px0, middle - 3, -3, px1, middle + 3, 1);
        build.solid(wall + 4, middle - 1, -3, px0, middle + 1, 0);
        build.way_out(float(px0 + px1) * 0.5, float(middle), 1);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 3.5 + float(index) * 5.0, 0, fact3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact3's stretches: [name, role]."""
glob FACT3_STRETCHES: list[list[str]] = [
         ["lobby", "start"],
         ["duct", "flow"],
         ["line", "hub"],
         ["line", "flow"],
         ["office", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact3's stretches by its name."""
def make_fact3(name: str, key: str) -> Prefab {
    if name == "lobby" {
        return UpperLobby();
    }
    if name == "duct" {
        return SlimeDuct();
    }
    if name == "line" {
        return ProductionLine();
    }
    if name == "office" {
        return DesignOffice(key=key if key else "key_silver");
    }
    return Fact3Exit(key=key);
}
