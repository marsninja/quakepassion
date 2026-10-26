"""Prefabs drawn from Quake II's jail3, the Security Complex: a complex high
in the mountains, a checkpoint with a raised booth, ramps switching back
up a cliff under the sky, a core of two rings of walkways round a shaft,
the key in a cage a button opens. Raised in jail3's own palette.

- `Checkpoint`: the start. A hall, a booth raised by one wall up steps, a
  barrier wall across the far end with a gate through it; ways on beyond.
- `CliffRamps`: a cliff face under the sky climbed by ramps switching back
  along it, the way on at the top.
- `ComplexCore`: a shaft through a room, a walkway round it on the floor
  and another round it high up, stairs between on opposite sides; ways on
  from both (a hub).
- `ButtonCage`: the key in a cage at a room's far end, a button on the
  wall that opens it; taking the key opens the closets.
- `ComplexExit`: the end. A door (a key's, as a gate), a ramp up to a
  landing, the way out on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob JAIL3: str = "q2:jail3";

"""jail3's foes: gunners and infantry, flyers and hovers, gladiators and a
tank deeper in."""
def jail3_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover" if dice.chance(0.4) else "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_gunner", "monster_infantry", "monster_medic"], ["monster_tank"] if heavy else ["monster_gladiator"], danger * 0.5 if heavy else danger));
}

"""The start: a hall, a booth raised by one wall, a barrier wall across the
far end with a gate."""
node Checkpoint(Prefab) {
    has booth: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Checkpoint";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.booth = dice.between(3, 4);
        self.tall = dice.between(13, 15);
        self.low = -1;
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
        build.level(hall, self.booth);
        bx = self.long - 7;
        build.solid(bx, 1, 0, bx + 1, middle - 2, self.tall);
        build.solid(bx, middle + 3, 0, bx + 1, self.wide - 1, self.tall);
        build.solid(bx, middle - 2, 8, bx + 1, middle + 3, self.tall);
        # The booth by the north wall, up steps from the hall.
        build.solid(8, self.wide - 5, 0, 13, self.wide - 1, self.booth);
        stair(build, 8 - self.booth, self.wide - 4, 0, 0, self.booth, 2);
        build.solid(8, self.wide - 5, self.booth, 13, self.wide - 4, self.booth + 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(bx) - 3.5, 3.5 + float(index) * 3.0, 0, jail3_foe(dice, self.danger), 180.0);
        }
        build.foe(11.0, float(self.wide) - 2.5, self.booth, jail3_foe(dice, self.danger), 270.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, jail3_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A cliff face under the sky climbed by ramps switching back along it."""
node CliffRamps(Prefab) {
    has flight: int = 6,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cliff ramps";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.flight = dice.between(5, 6);
        self.tall = 3 * self.flight + 10;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=2, along=float(self.wide - 3), floor=3 * self.flight), Port(face=1, along=float(self.long // 2), floor=3 * self.flight)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        f = self.flight;
        cliff = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [f, 2 * f, 3 * f] {
            build.level(cliff, z);
        }
        # Three ledges stepping back up the cliff (the north wall), each a
        # band deeper than the one below; a ramp up to each from the one
        # below, switching back.
        bands = [self.wide - 10, self.wide - 7, self.wide - 4];
        for (index, y0) in enumerate(bands) {
            top = (index + 1) * f;
            build.solid(1, y0, 0, self.long - 1, self.wide - 1, top);
        }
        # Ramp 1 climbs east along the floor's edge to the first ledge's east
        # end; ramp 2 climbs west on the first ledge; ramp 3 east on the second.
        stair(build, self.long - 2 - f, bands[0] - 3, 0, 0, f, 3);
        stair(build, f + 1, bands[0], f, 2, f, 3);
        stair(build, self.long - 2 - f, bands[1], 2 * f, 0, f, 3);
        for x in range(self.long - 5, self.long - 1) {
            build.keep(cliff, x, bands[0], f);
        }
        build.doorway(cliff, self.enter);
        for port in self.taken {
            build.doorway(cliff, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) - 3.0, 6 + index * 5, jail3_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(4.0, float(self.wide) - 2.5, 3 * f, jail3_foe(dice, self.danger, True), 0.0);
        build.foe(float(self.long // 2) + 0.5, float(bands[0]) + 1.5, f, jail3_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(bands[1]) + 1.5, 2 * f, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A shaft through a room, a walkway round it on the floor and another
high up, stairs between on opposite sides."""
node ComplexCore(Prefab) {
    has upper: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Complex core";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.upper = dice.between(8, 9);
        self.tall = self.upper + 10;
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.upper),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        core = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(core, self.upper);
        # The shaft in the middle, a pit far down with a floor, railed.
        build.widen(core, cx - 4, cy - 4, -7, cx + 4, cy + 4, 0);
        build.solid(cx - 4, cy - 4, -7, cx + 4, cy + 4, -6);
        stair(build, cx - 4, cy + 3, -6, 3, 6, 2);
        # The upper ring: a walkway five cells wide round the walls.
        under = self.upper - 1;
        build.solid(1, 1, under, self.long - 1, 6, self.upper);
        build.solid(1, self.wide - 6, under, self.long - 1, self.wide - 1, self.upper);
        build.solid(1, 6, under, 6, self.wide - 6, self.upper);
        build.solid(self.long - 6, 6, under, self.long - 1, self.wide - 6, self.upper);
        # Stairs up to it on the west and east, along the walkway's inner
        # edge.
        stair(build, 6, 6 + self.upper, 0, 3, self.upper, 3);
        stair(build, self.long - 9, self.wide - 7 - self.upper, 0, 1, self.upper, 3);
        build.doorway(core, self.enter);
        for port in self.taken {
            build.doorway(core, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 6 + index * 4) + 0.5, float(cy) + 6.5, 0, jail3_foe(dice, self.danger), 270.0);
        }
        build.foe(float(cx) + 0.5, 3.5, self.upper, jail3_foe(dice, self.danger, True), 90.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 4, jail3_foe(dice, self.danger, False, True), 0.0);
        build.supply(float(cx) + 2.0, float(cy) + 2.0, -6, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, self.upper, Q2_HEALTH, "q2");
    }
}

"""The key in a cage at a room's far end, a button on the wall that opens
it; taking the key opens the closets."""
node ButtonCage(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Button cage (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(12, 14);
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
        build.doorway(room, self.enter);
        cx = self.long - 5;
        build.solid(cx + 1, cy - 3, 0, self.long - 1, cy - 2, 7);
        build.solid(cx + 1, cy + 2, 0, self.long - 1, cy + 3, 7);
        build.solid(cx, cy - 3, 6, self.long - 1, cy + 3, self.tall);
        cage = build.name("cage");
        build.rising_door(float(cx), float(cy - 2), 0.0, float(cx + 1), float(cy + 2), 6.0, {"targetname": cage, "wait": "-1"});
        build.button(float(self.long - 1), float(cy) + 5.5, 1.3, 2, cage);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [3, cx - 5], [jail3_foe(dice, self.danger, True), jail3_foe(dice, self.danger)]);
        build.foe(float(cx) - 3.5, 2.5, 0, jail3_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a ramp up to a landing, the way out on it."""
node ComplexExit(Prefab) {
    has key: str = "",
        landing: int = 4,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Complex exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL3;
        self.district = level_district(JAIL3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.landing = dice.between(3, 5);
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
        lx = self.long - 6;
        build.solid(lx, 1, 0, self.long - 1, self.wide - 1, self.landing);
        stair(build, lx - self.landing, 2, 0, 0, self.landing, 3);
        build.way_out(float(self.long) - 3.0, float(middle), self.landing);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, jail3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(lx) - 3.5, float(self.wide) - 3.0, 0, jail3_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail3's stretches: [name, role]."""
glob JAIL3_STRETCHES: list[list[str]] = [
         ["checkpoint", "start"],
         ["cliff", "flow"],
         ["core", "hub"],
         ["core", "flow"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail3's stretches by its name."""
def make_jail3(name: str, key: str) -> Prefab {
    if name == "checkpoint" {
        return Checkpoint();
    }
    if name == "cliff" {
        return CliffRamps();
    }
    if name == "core" {
        return ComplexCore();
    }
    if name == "cage" {
        return ButtonCage(key=key if key else "key_silver");
    }
    return ComplexExit(key=key);
}
