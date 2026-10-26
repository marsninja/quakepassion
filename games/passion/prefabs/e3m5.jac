"""Prefabs drawn from e3m5, the Wind Tunnels: shafts and tunnels that climb
and fall far, the wind throwing a body up them, water pooled at their
feet. e3m5 holds no keys; its key room and gate are drawn from its
ledges. Raised in e3m5's own palette.

- `WindIntake`: the start. A hall, a ledge high across its far end that
  the wind (a jump pad) throws a body up to; ways on from the floor and
  the ledge.
- `WindShaft`: a tall shaft, a pool at its foot, a jump pad by it throwing
  a body up to a ledge far above and the way on there.
- `TunnelJunction`: tunnels meeting in a tall chamber at three heights,
  ledges at each, pads throwing a body from each to the next; ways on
  at every height (a hub).
- `WindLedge`: the key on a ledge high up a hall, a pad up to it; taking
  it opens the closets at the foot.
- `WindExit`: the end. A door (a key's, as a gate) into a shaft, the
  slipgate on a ledge a pad throws a body up to."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush }

glob E3M5: str = "q1:e3m5";

"""e3m5's foes: scrags above all, ogres and fiends, hell knights deeper in."""
def e3m5_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_demon1"] if heavy else ["monster_ogre", "monster_wizard"], ["monster_hell_knight"], danger));
}

"""The start: a hall, a ledge high across its far end the wind throws a
body up to."""
node WindIntake(Prefab) {
    has ledge: int = 8,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind intake";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.ledge = dice.between(7, 9);
        self.tall = self.ledge + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        lx = self.long - 6;
        build.solid(lx, 1, 0, self.long - 1, self.wide - 1, self.ledge);
        build.jump_pad(float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 1.0, float(middle) + 0.5, self.ledge);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, float(middle) + 3.5 - float(index) * 6.0, 5, e3m5_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, self.ledge, e3m5_foe(dice, self.danger, True), 180.0);
        build.foe(float(lx) - 5.5, 3.5, 0, e3m5_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, "item_health");
    }
}

"""A tall shaft, a pool at its foot, a jump pad by it throwing a body up to
a ledge far above."""
node WindShaft(Prefab) {
    has ledge: int = 14,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind shaft";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(16, 18);
        self.wide = dice.between(14, 16);
        self.ledge = dice.between(12, 15);
        self.tall = self.ledge + 10;
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=self.ledge), Port(face=1, along=float(self.long - 3), floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.ledge);
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, self.wide - 1, self.ledge);
        build.pool(3, 2, -4, lx - 3, middle - 2, 0, 2);
        build.jump_pad(float(lx) - 3.0, float(middle) + 2.5, 0, float(lx) + 1.0, float(middle) + 2.5, self.ledge);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 4 + index * 4, e3m5_foe(dice, self.danger, False, True), float(index * 120));
        }
        build.foe(float(self.long) - 2.5, float(middle) + 3.5, self.ledge, e3m5_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.ledge, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""Tunnels meeting in a tall chamber at three heights, ledges at each, pads
throwing a body from each to the next."""
node TunnelJunction(Prefab) {
    has middle_ledge: int = 7,
        top_ledge: int = 14,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tunnel junction";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(22, 24);
        self.wide = dice.between(22, 24);
        self.middle_ledge = dice.between(6, 8);
        self.top_ledge = self.middle_ledge + dice.between(6, 8);
        self.tall = self.top_ledge + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.top_ledge),
            Port(face=1, along=float(self.long // 2), floor=self.middle_ledge),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        chamber = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chamber, self.middle_ledge);
        build.level(chamber, self.top_ledge);
        # The middle ledge along the north wall, the top along the east.
        build.solid(1, self.wide - 6, self.middle_ledge - 1, self.long - 1, self.wide - 1, self.middle_ledge);
        build.solid(self.long - 6, 1, self.top_ledge - 1, self.long - 1, self.wide - 1, self.top_ledge);
        # Pads: the floor to the middle ledge, the middle ledge to the top.
        build.jump_pad(float(cx) - 3.0, float(self.wide) - 9.0, 0, float(cx) - 3.0, float(self.wide) - 5.0, self.middle_ledge);
        build.jump_pad(float(self.long) - 9.0, float(self.wide) - 3.5, self.middle_ledge, float(self.long) - 5.0, float(self.wide) - 3.5, self.top_ledge);
        for x in range(2, self.long - 6) {
            build.keep(chamber, x, self.wide - 6, self.middle_ledge);
        }
        for y in range(2, self.wide - 2) {
            build.keep(chamber, self.long - 6, y, self.top_ledge);
        }
        build.doorway(chamber, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) + 0.5, float(cy) - 2.5 + float(index) * 3.0, 4 + index * 5, e3m5_foe(dice, self.danger, False, True), float(index * 120));
        }
        build.foe(float(cx) + 2.5, float(self.wide) - 3.0, self.middle_ledge, e3m5_foe(dice, self.danger), 270.0);
        build.foe(float(self.long) - 3.0, 4.5, self.top_ledge, e3m5_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(self.wide) - 4.5, self.top_ledge, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""The key on a ledge high up a hall, a pad up to it; taking it opens the
closets at the foot."""
node WindLedge(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 14,
        ledge: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind ledge (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(8, 10);
        self.tall = self.ledge + 9;
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        build.doorway(hall, self.enter);
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, side, self.ledge);
        for y in range(2, side - 1) {
            build.keep(hall, lx, y, self.ledge);
        }
        build.jump_pad(float(lx) - 3.0, float(cy) + 0.5, 0, float(lx) + 1.0, float(cy) + 0.5, self.ledge);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, side, 0, [2, lx - 5], [e3m5_foe(dice, self.danger, True), e3m5_foe(dice, self.danger)]);
        build.foe(float(self.long // 2) + 0.5, float(cy) - 2.5, 6, e3m5_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a shaft, the slipgate on a ledge a pad throws a
body up to."""
node WindExit(Prefab) {
    has key: str = "",
        ledge: int = 10,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M5;
        self.district = level_district(E3M5);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.ledge = dice.between(9, 11);
        self.tall = self.ledge + 10;
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
        shaft = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.ledge);
        build.doorway(hall, self.enter);
        build.widen(shaft, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        lx = self.long - 6;
        build.solid(lx, 1, self.ledge - 2, self.long - 1, self.wide - 1, self.ledge);
        build.jump_pad(float(lx) - 3.0, float(middle) + 0.5, 0, float(lx) + 1.0, float(middle) + 0.5, self.ledge);
        build.way_out(float(self.long) - 3.0, float(middle), self.ledge);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(lx) - 3.5, float(middle) + 0.5, 6, e3m5_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m5's stretches: [name, role]."""
glob E3M5_STRETCHES: list[list[str]] = [
         ["intake", "start"],
         ["shaft", "flow"],
         ["junction", "hub"],
         ["junction", "flow"],
         ["ledge", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m5's stretches by its name."""
def make_e3m5(name: str, key: str) -> Prefab {
    if name == "intake" {
        return WindIntake();
    }
    if name == "shaft" {
        return WindShaft();
    }
    if name == "junction" {
        return TunnelJunction();
    }
    if name == "ledge" {
        return WindLedge(key=key if key else "key_silver");
    }
    return WindExit(key=key);
}
