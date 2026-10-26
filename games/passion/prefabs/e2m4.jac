"""Prefabs drawn from e2m4, the Ebon Fortress: a fortress climbing high
over its yards, ramps up its walls, shafts ridden up by lifts, a hall of
galleries one over another, the silver key over a pit of lava crossed
pillar by pillar, a bridge out over a chasm. Raised in e2m4's own
palette.

- `FortressRamp`: the start. A yard under the sky, a ramp up along its
  wall to a terrace across its far end; ways on from the terrace and the
  yard.
- `LiftShaft`: a tall shaft, a lift up to a ledge along one wall and
  another from it to a ledge high on the next; scrags in the air.
- `EbonHall`: a hall of two galleries, one over the other on two walls,
  stairs up to each; ways on from the floor and both galleries (a hub).
- `SilverKeep`: a pit of lava across a hall crossed by jumping pillar to
  pillar, the key on the far side; taking it opens the closets.
- `ChasmGate`: the end. A door (a key's, as a gate) out onto a bridge over
  a chasm of lava, the slipgate on the far side."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E2M4: str = "q1:e2m4";

"""e2m4's foes: the dead and ogres, fiends and hell knights deeper in,
scrags in the air."""
def e2m4_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_wizard";
    }
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"] if heavy else ["monster_zombie", "monster_ogre", "monster_zombie"], ["monster_demon1", "monster_hell_knight"] if heavy else ["monster_ogre"], danger));
}

"""The start: a yard, a ramp up along its wall to a terrace."""
node FortressRamp(Prefab) {
    has terrace: int = 10,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fortress ramp";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(22, 26);
        self.terrace = dice.between(9, 11);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.terrace), Port(face=1, along=float(self.long - 4), floor=self.terrace), Port(face=1, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.terrace);
        tx = self.long - 8;
        build.solid(tx, 1, 0, self.long - 1, self.wide - 1, self.terrace);
        # The ramp along the south wall, climbing east to the terrace.
        stair(build, tx - self.terrace, 1, 0, 0, self.terrace, 3);
        for y in range(1, 4) {
            build.keep(yard, tx, y, self.terrace);
        }
        # Buttresses along the terrace's face.
        for y in range(6, self.wide - 2, 4) {
            build.solid(tx - 1, y, 0, tx, y + 1, self.terrace - 2);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(tx) + 3.5, 4.5 + float(index) * 5.0, self.terrace, e2m4_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2) + 0.5, float(middle) + 2.5, 6 + index * 2, e2m4_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(tx) - 4.5, float(self.wide) - 3.5, 0, e2m4_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.terrace, "item_health");
    }
}

"""A tall shaft, a lift up to a ledge along one wall and another from it
to a ledge high on the next."""
node LiftShaft(Prefab) {
    has first: int = 9,
        second: int = 18,
        tall: int = 27;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lift shaft";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        self.first = dice.between(8, 10);
        self.second = self.first + dice.between(8, 10);
        self.tall = self.second + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2) - 2.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2) - 2.0, floor=self.second), Port(face=1, along=float(self.long // 2), floor=self.first)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        step = kit_of(build.district).step;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.first);
        build.level(shaft, self.second);
        # The first ledge along the north wall, the second along the east.
        build.solid(1, self.wide - 5, self.first - 1, self.long - 1, self.wide - 1, self.first);
        build.solid(self.long - 4, 1, self.second - 1, self.long - 1, self.wide - 1, self.second);
        # The lifts: the first up to the north ledge at its west end, the
        # second from that ledge's east end up beside the east ledge.
        build.put_box({"classname": "func_plat", "height": str(self.first * 16), "speed": "200"}, 2.0, float(self.wide - 8), float(self.first) - 0.5, 5.0, float(self.wide - 5), float(self.first), step);
        build.put_box({"classname": "func_plat", "height": str((self.second - self.first) * 16), "speed": "200"}, float(self.long - 7), float(self.wide - 8), float(self.second) - 0.5, float(self.long - 4), float(self.wide - 5), float(self.second), step);
        for x in range(1, 6) {
            build.keep(shaft, x, self.wide - 5, self.first);
        }
        for x in range(self.long - 8, self.long - 3) {
            build.keep(shaft, x, self.wide - 5, self.first);
        }
        for y in range(self.wide - 9, self.wide - 4) {
            build.keep(shaft, self.long - 4, y, self.second);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) - 1.5, 5 + index * 5, e2m4_foe(dice, self.danger, False, True), float(index * 120));
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.0, self.first, e2m4_foe(dice, self.danger), 270.0);
        build.foe(float(self.long) - 2.5, 3.5, self.second, e2m4_foe(dice, self.danger, True), 90.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.second, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A hall of two galleries, one over the other on two walls, stairs up to
each; ways on from the floor and both galleries."""
node EbonHall(Prefab) {
    has lower: int = 6,
        upper: int = 12,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ebon hall";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 26);
        self.lower = dice.between(6, 7);
        self.upper = self.lower + 6;
        self.tall = self.upper + dice.between(9, 11);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=5.0, floor=self.upper),
            Port(face=1, along=float(self.long // 2), floor=self.lower),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=middle, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.lower);
        build.level(hall, self.upper);
        # The lower gallery along the north wall, a stair up to it climbing
        # east beside it.
        gy = self.wide - 5;
        build.solid(1, gy, self.lower - 1, self.long - 1, self.wide - 1, self.lower);
        stair(build, 3, gy - 3, 0, 0, self.lower, 3);
        for x in range(2 + self.lower - 2, 3 + self.lower) {
            build.keep(hall, x, gy, self.lower);
        }
        # The upper gallery along the east wall, a stair up to it along the
        # lower gallery.
        gx = self.long - 5;
        build.solid(gx, 1, self.upper - 1, self.long - 1, self.wide - 1, self.upper);
        stair(build, gx - 6, gy, self.lower, 0, 6, 3);
        # Pillars under the galleries' edges.
        for x in range(8, gx - 6, 5) {
            build.solid(x, gy, 0, x + 1, gy + 1, self.lower - 1);
        }
        for y in range(5, gy - 1, 5) {
            if abs(y - middle) > 3 {
                build.solid(gx, y, 0, gx + 1, y + 1, self.upper - 1);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) - 2.5, 0, e2m4_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 6) + 0.5, float(self.wide) - 2.5, self.lower, e2m4_foe(dice, self.danger), 270.0);
        }
        build.foe(float(self.long) - 2.5, 4.5, self.upper, e2m4_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 9, e2m4_foe(dice, self.danger, False, True), 0.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.upper, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""A pit of lava across a hall crossed pillar to pillar, the key on the
far side; taking it opens the closets."""
node SilverKeep(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        hops: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver keep (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.hops = dice.between(3, 4);
        self.long = 3 * self.hops + 13;
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
        self.low = -4;
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
        build.doorway(hall, self.enter);
        # The pit from x 5, a pillar two cells long every three cells, a
        # cell of lava between each and the next (and the shores).
        far = 3 * self.hops + 6;
        build.pool(5, 1, -3, far, side, 0, 4, False, False);
        for hop in range(self.hops) {
            x = 6 + hop * 3;
            build.solid(x, cy - 1, -3, x + 2, cy + 2, 0);
        }
        key_ambush(build, self.key, float(far) + 3.5, float(cy) + 0.5, 0, side, 0, [1, far + 2], [e2m4_foe(dice, self.danger, True), e2m4_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, e2m4_foe(dice, self.danger), 180.0);
        build.foe(float(far) - 3.5, float(cy) + 3.5, 6, e2m4_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door out onto a bridge over a chasm of lava, the slipgate on
the far side."""
node ChasmGate(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chasm gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 20);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gate_x = 9;
        hall = build.room(1, 1, 0, gate_x, self.wide - 1, 12, variant=dice.below(3));
        chasm = build.room(gate_x + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chasm, -8);
        build.doorway(hall, self.enter);
        build.widen(chasm, gate_x, middle - 2, 0, gate_x + 1, middle + 2, 9);
        if self.key {
            build.rising_door(float(gate_x), float(middle - 2), 0.0, float(gate_x + 1), float(middle + 2), 9.0, {"key": self.key, "wait": "-1"});
        }
        # The chasm, lava at its bottom, the bridge over it.
        far = self.long - 6;
        build.widen(chasm, gate_x + 3, 1, -5, far, self.wide - 1, 0);
        build.pool(gate_x + 3, 1, -8, far, self.wide - 1, -5, 4, False, False);
        build.solid(gate_x + 3, middle - 2, -1, far, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(chasm, gate_x + 2, y, 0);
            build.keep(chasm, far, y, 0);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x) - 3.5, 2.5 + float(index) * 4.0, 0, e2m4_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x + 6 + index * 4) + 0.5, float(middle) + 4.5, 5, e2m4_foe(dice, self.danger, False, True), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 0, e2m4_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m4's stretches: [name, role]."""
glob E2M4_STRETCHES: list[list[str]] = [
         ["ramp", "start"],
         ["shaft", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["keep", "keyroom"],
         ["chasm", "end"],
         ["chasm", "gate"]
     ];

"""One of e2m4's stretches by its name."""
def make_e2m4(name: str, key: str) -> Prefab {
    if name == "ramp" {
        return FortressRamp();
    }
    if name == "shaft" {
        return LiftShaft();
    }
    if name == "hall" {
        return EbonHall();
    }
    if name == "keep" {
        return SilverKeep(key=key if key else "key_silver");
    }
    return ChasmGate(key=key);
}
