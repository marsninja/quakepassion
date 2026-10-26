"""Prefabs drawn from Quake II's command, the Command Center: the Strogg's
command, a gate over a flooded moat, a pen where tanks are kept behind
bars, a command deck of tiers over a drowned floor, the key in the
briefing room up a lift. Raised in command's own palette.

- `CommandGate`: the start. A hall, a moat of water across it with a
  bridge, the command's doors beyond; ways on.
- `TankPen`: a pen of cages along a hall, a raised walk past them, the way
  on at its end.
- `CommandDeck`: a deck of three tiers stepping up over a flooded floor,
  stairs between; ways on from the floor and the tiers (a hub).
- `BriefingRoom`: the key in a briefing room up a lift; taking it opens
  the closets.
- `CommandExit`: the end. A door (a key's, as a gate), a hall of
  consoles, the way out on a dais."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }

glob COMMAND: str = "q2:command";

"""command's foes: gunners and iron maidens, floaters, gladiators and
tanks deeper in."""
def command_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_gunner", "monster_soldier_light", "monster_chick"], ["monster_tank"] if heavy else ["monster_floater"], danger * 0.3 if heavy else danger * 0.6));
}

"""The start: a hall, a moat of water across it with a bridge."""
node CommandGate(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Command gate";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(15, 17);
        self.low = -6;
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        mx = 10;
        build.pool(mx, 1, -5, mx + 5, self.wide - 1, 0, 2, False, True, True);
        stair(build, mx, self.wide - 6, -5, 0, 5, 2);
        stair(build, mx, 3, -5, 0, 5, 2);
        build.solid(mx, middle - 2, -1, mx + 5, middle + 2, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(mx + 8 + index % 2 * 4) + 0.5, 3.5 + float(index) * 4.0, 0, command_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A pen of cages along a hall, a raised walk past them."""
node TankPen(Prefab) {
    has walk: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tank pen";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.walk = dice.between(2, 3);
        self.tall = dice.between(13, 15);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=self.walk);
        self.leaves = [Port(face=0, along=3.0, floor=self.walk), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        pen = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pen, self.walk);
        build.solid(1, 1, 0, self.long - 1, 6, self.walk);
        # The cages: bays along the north side between walls, the floor
        # before them reached by a stair down off the walk's far end.
        for x in range(4, self.long - 7, 5) {
            build.solid(x, 9, 0, x + 1, self.wide - 1, 7);
        }
        stair(build, self.long - 4, 6 + self.walk - 1, 0, 3, self.walk, 3);
        build.doorway(pen, self.enter);
        for port in self.taken {
            build.doorway(pen, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 10) + 1.0, float(self.wide) - 3.5, 0, command_foe(dice, self.danger, index == 0), 270.0);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, self.walk, command_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 3.5, self.walk, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A deck of three tiers stepping up over a flooded floor, stairs between."""
node CommandDeck(Prefab) {
    has step_up: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Command deck";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.step_up = dice.between(3, 4);
        self.tall = 3 * self.step_up + 11;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        top = 3 * self.step_up;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=top),
            Port(face=1, along=float(self.long - 8), floor=2 * self.step_up),
            Port(face=3, along=8.0, floor=0),
            Port(face=1, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.step_up;
        deck = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.pool(5, 4, -3, 12, self.wide - 4, 0, 2, False, True, True);
        stair(build, 9, 4, -3, 0, 3, 2);
        build.solid(5, middle - 1, -3, 12, middle + 1, 0);
        edges = [self.long - 15, self.long - 10, self.long - 5];
        for (index, x0) in enumerate(edges) {
            top = (index + 1) * r;
            build.level(deck, top);
            build.solid(x0, 1, 0, self.long - 1, self.wide - 1, top);
            stair(build, x0 - r, middle - 2, top - r, 0, r, 4);
            for y in range(middle - 2, middle + 2) {
                build.keep(deck, x0, y, top);
            }
        }
        build.doorway(deck, self.enter);
        for port in self.taken {
            build.doorway(deck, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(edges[0]) - 4.5, 4.5 + float(index) * 6.0, 0, command_foe(dice, self.danger), 0.0);
        }
        for (index, x0) in enumerate(edges) {
            build.foe(float(x0) + 2.5, float(middle) + 4.5, (index + 1) * r, command_foe(dice, self.danger, index == 2), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 3 * r, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a briefing room up a lift; taking it opens the closets."""
node BriefingRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        upper: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Briefing room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.upper = dice.between(6, 7);
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
        build.solid(ux, 1, self.upper - 1, self.long - 1, side, self.upper);
        build.solid(ux + 2, cy - 2, self.upper, self.long - 2, cy + 2, self.upper + 1);
        lift(build, ux - 3, cy - 1, ux, cy + 2, 0, self.upper);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, ux, y, self.upper);
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.upper + 1, side, 0, [2, ux - 5], [command_foe(dice, self.danger, True), command_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, 2.5, self.upper, command_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a hall of consoles, the way out on a dais."""
node CommandExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Command exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        for x in range(wall + 3, self.long - 6, 3) {
            build.solid(x, 1, 0, x + 2, 3, 2);
            build.solid(x, self.wide - 3, 0, x + 2, self.wide - 1, 2);
        }
        dx = self.long - 6;
        build.solid(dx, 2, 0, self.long - 1, self.wide - 2, 2);
        stair(build, dx - 2, middle - 2, 0, 0, 2, 4);
        build.way_out(float(self.long) - 3.0, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, command_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 3.5, float(middle) + 3.0, 0, command_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""command's stretches: [name, role]."""
glob COMMAND_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["pen", "flow"],
         ["deck", "hub"],
         ["deck", "flow"],
         ["briefing", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of command's stretches by its name."""
def make_command(name: str, key: str) -> Prefab {
    if name == "gate" {
        return CommandGate();
    }
    if name == "pen" {
        return TankPen();
    }
    if name == "deck" {
        return CommandDeck();
    }
    if name == "briefing" {
        return BriefingRoom(key=key if key else "key_silver");
    }
    return CommandExit(key=key);
}
