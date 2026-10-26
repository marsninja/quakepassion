"""Prefabs drawn from e2m2, the Ogre Citadel: a citadel of wood and brick
under the sky, its moat, its walls with ogres along their tops, a tower
climbed by a stair winding up its walls, a keep in a courtyard bridged to
from high up, the gold key on a gallery. Raised in e2m2's own palette.

- `CitadelApproach`: the start. Open ground, a moat across it bridged, the
  citadel's wall beyond with its gate, ogres along the wall's top. The
  gate's portcullis sinks only when both buttons on the wall are shot
  (e2m2's "Shoot the buttons" counter), and spikes fly across the passage
  through the wall while anyone is in it (its spike shooters).
- `SpiralTower`: a tower, a stair winding up round its walls to a landing
  and the way on high up (and one at its foot); what waits up top wakes as
  the player passes the stair's middle.
- `CitadelCourt`: a courtyard round a keep, a stair up the keep and a
  bridge from its top to a way on high in the courtyard's wall; ways on
  below too (a hub). A platform rides up and down beside the keep (e2m2's
  train), knights walk round it, and its guard wakes at the stair's top.
- `OgreGoldHall`: a hall, a gallery across its far end ridden up to by a
  lift, the key on the gallery; taking it opens the closets in the wall.
- `CitadelSally`: the end. A hall, a gate out (a key's, as a gate) to a
  yard, the slipgate on a dais up a stair, ogres on the wall over it,
  roused as the player comes through the gate."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, ring_path, spiral }
import from .e1m5 { crenels }

glob E2M2: str = "q1:e2m2";

"""e2m2's foes: knights and ogres, fiends and a shambler deeper in."""
def e2m2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_knight"] if heavy else ["monster_knight", "monster_knight", "monster_zombie"], ["monster_demon1"] if heavy else ["monster_ogre"], danger));
}

"""The start: open ground, a moat bridged, the citadel's wall and gate."""
node CitadelApproach(Prefab) {
    has wall: int = 10,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel approach";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.wall = dice.between(10, 12);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 9), floor=0), Port(face=1, along=float(self.long - 9), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, self.wall);
        # The moat across the ground, and the bridge over it.
        build.pool(10, 1, -6, 15, self.wide - 1, 0, 2);
        build.solid(10, middle - 2, -1, 15, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(ground, 9, y, 0);
            build.keep(ground, 15, y, 0);
        }
        # The citadel's wall, its gate through it, merlons along its top.
        wall_x = self.long - 6;
        build.solid(wall_x, 1, 0, self.long - 1, self.wide - 1, self.wall);
        build.widen(ground, wall_x, middle - 2, 0, self.long - 1, middle + 2, 8);
        crenels(build, wall_x, 1, self.wide - 1, self.wall, False);
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        # The portcullis sinks into the ground when both buttons on the
        # wall's face are shot.
        both = build.tally(2, "The gate is open");
        for side in [-5, 5] {
            build.cue([build.button(float(wall_x), float(middle + side) + 0.5, 5.0, 2, "", True)], "button") +>:Fires:+> both;
        }
        both +>:Fires:+> build.sinking(float(wall_x), float(middle - 2), float(wall_x + 1), float(middle + 2), 8, 8);
        build.touch(9.0, 1.0, 0.0, 10.0, float(self.wide - 1), 8.0, True, "Shoot the buttons to open the gate");
        # Spikes across the passage through the wall while anyone is in it.
        inside = build.touch(float(wall_x + 1), float(middle - 2), 0.0, float(self.long - 2), float(middle + 2), 6.0, False);
        inside +>:Fires:+> build.spikes(float(wall_x) + 3.0, float(middle - 2) + 0.2, 2.5, 1);
        inside +>:Fires:+> build.spikes(float(wall_x) + 4.0, float(middle + 2) - 0.2, 2.5, 3);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall_x) + 2.5, 2.5 + float(index) * 5.0, self.wall, "monster_ogre", 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall_x) - 3.5, float(middle) + 3.5 - float(index) * 7.0, 0, e2m2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(wall_x) - 2.5, 2.5, 0, "item_health");
    }
}

"""The landing's floor, face and middle along that face for a spiral of
`steps` up a ring three cells wide round the box 1..long-1, 1..wide-1:
[face, along], or [] when the landing turns a corner."""
def spiral_landing(long: int, wide: int, steps: int, landing: int) -> list[float] {
    path = ring_path(1, 1, long - 1, wide - 1, 3);
    lap = len(path);
    face = path[steps % lap][4];
    for index in range(landing) {
        if path[(steps + index) % lap][4] != face {
            return [];
        }
    }
    cell = path[(steps + landing // 2) % lap];
    along = float(cell[0]) + 0.5 if face % 2 == 1 else float(cell[1]) + 0.5;
    return [float(face), along];
}

"""A tower, a stair winding up its walls to a landing and the way on."""
node SpiralTower(Prefab) {
    has steps: int = 18,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spiral tower";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        fits: list[int] = [];
        for steps in range(14, 23) {
            landing = spiral_landing(self.long, self.wide, steps, 6);
            if landing and landing[0] != 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 10;
        self.low = -1;
        self.high = self.tall + 1;
        top = spiral_landing(self.long, self.wide, self.steps, 6);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=int(top[0]), along=top[1], floor=self.steps), Port(face=0, along=float(self.wide // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tower, self.steps // 2);
        build.level(tower, self.steps);
        landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 6);
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        mid = landing[3];
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        # What waits up top wakes as the player passes the stair's middle.
        half = path[self.steps // 2];
        roused = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        above = build.waiting();
        roused +>:Fires:+> above;
        build.foe(float(mid[0] + mid[2]) * 0.5, float(mid[1] + mid[3]) * 0.5, self.steps, e2m2_foe(dice, self.danger, True), 180.0, waits=above);
        for index in range(dice.between(1, 2)) {
            cell = path[self.steps // 2 + index * 3];
            build.foe(float(cell[0] + cell[2]) * 0.5, float(cell[1] + cell[3]) * 0.5, self.steps // 2 + index * 3 + 1, e2m2_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, e2m2_foe(dice, self.danger), 180.0);
        build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, 0, "item_health");
        top = landing[5];
        build.supply(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.steps, "item_rockets");
    }
}

"""A courtyard round a keep, a stair up the keep and a bridge from its top
to a way on high in the courtyard's wall."""
node CitadelCourt(Prefab) {
    has keep_top: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel court";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 28);
        self.tall = dice.between(20, 24);
        self.keep_top = dice.between(8, 9);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=self.keep_top), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.keep_top);
        # The keep, solid to its top, a stair up along its south face.
        kx0 = 10;
        kx1 = self.long - 9;
        ky0 = 8;
        ky1 = self.wide - 8;
        build.solid(kx0, ky0, 0, kx1, ky1, self.keep_top);
        stair(build, kx0, ky0 - 3, 0, 0, self.keep_top, 3);
        for x in range(kx0 + self.keep_top - 3, kx0 + self.keep_top) {
            build.keep(court, x, ky0, self.keep_top);
        }
        # The bridge from the keep's north side to the wall's way on.
        bx = self.long // 2;
        build.solid(bx - 2, ky1, self.keep_top - 1, bx + 2, self.wide - 1, self.keep_top);
        for x in range(bx - 2, bx + 2) {
            build.keep(court, x, ky1, self.keep_top);
            build.keep(court, x, ky1 - 1, self.keep_top);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # A platform riding up and down beside the keep's far face.
        build.train([3.0, 3.0, 1.0], [[float(kx1), float(ky0 + 2), 0.0], [float(kx1), float(ky0 + 2), float(self.keep_top - 1)]], 80.0, 3.0);
        for y in range(ky0 + 2, ky0 + 5) {
            build.keep(court, kx1 - 1, y, self.keep_top);
        }
        # The keep's guard wakes as the player comes up the stair.
        top_touch = build.touch(float(kx0 + self.keep_top - 3), float(ky0), float(self.keep_top), float(kx0 + self.keep_top + 1), float(ky0 + 3), float(self.keep_top + 6));
        guard = build.waiting();
        top_touch +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(kx0 + 3 + index * 4) + 0.5, float(ky0) + 3.5, self.keep_top, e2m2_foe(dice, self.danger, True), 270.0, waits=guard);
        }
        # Knights walking their round about the keep.
        ring = [[float(kx0) - 2.5, float(ky1) + 2.5], [float(kx1) + 4.5, float(ky1) + 2.5], [float(kx1) + 4.5, float(ky0) - 4.5], [float(kx0) - 2.5, float(ky0) - 4.5]];
        build.foe(float(kx0) - 2.5, float(ky1) + 2.5, 0, "monster_knight", 0.0, patrol=ring);
        for index in range(dice.between(2, 4)) {
            build.foe(float(kx1) + 3.5, 4.5 + float(index) * 5.0, 0, e2m2_foe(dice, self.danger), 180.0);
        }
        build.supply(float(kx1) - 2.5, float(ky0) + 2.5, self.keep_top, "item_health");
        build.supply(3.5, 3.5, 0, "item_spikes");
        build.supply(float(self.long) - 3.5, float(self.wide) - 3.5, 0, "item_health");
    }
}

"""A hall, a gallery across its far end ridden up to by a lift, the key on
the gallery; taking it opens the closets in the wall."""
node OgreGoldHall(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        gallery: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ogre hall (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.gallery = dice.between(7, 9);
        self.tall = self.gallery + 9;
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
        build.level(hall, self.gallery);
        build.doorway(hall, self.enter);
        gx = self.long - 7;
        build.solid(gx, 1, 0, self.long - 1, side, self.gallery);
        build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "180"}, float(gx - 3), float(cy - 1), float(self.gallery) - 0.5, float(gx), float(cy + 2), float(self.gallery), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(hall, gx, y, self.gallery);
        }
        pillars(build, 4, 3, gx - 4, 4, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        pillars(build, 4, side - 3, gx - 4, side - 2, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.gallery, side, 0, [4, 9], [e2m2_foe(dice, self.danger, True), e2m2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.5, 3.5, self.gallery, e2m2_foe(dice, self.danger, True), 180.0);
        build.foe(float(gx) - 6.5, float(cy) + 0.5, 0, e2m2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a hall, a gate out to a yard, the slipgate on a dais up a
stair, ogres on the wall over it."""
node CitadelSally(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel sally" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(26, 28);
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
        gate_x = 11;
        hall = build.room(1, 1, 0, gate_x, self.wide - 1, 12, variant=dice.below(3));
        yard = build.room(gate_x + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, sky=True);
        build.doorway(hall, self.enter);
        build.widen(yard, gate_x, middle - 2, 0, gate_x + 1, middle + 2, 9);
        if self.key {
            build.rising_door(float(gate_x), float(middle - 2), 0.0, float(gate_x + 1), float(middle + 2), 9.0, {"key": self.key, "wait": "-1"});
        }
        # The dais at the yard's far end, a stair up its face.
        dais_x = self.long - 6;
        build.solid(dais_x, middle - 3, 0, self.long - 1, middle + 3, 4);
        stair(build, dais_x - 4, middle - 2, 0, 0, 4, 4);
        build.way_out(float(self.long) - 3.0, float(middle), 4);
        # The wall-walk along the yard's north side, ogres on it.
        build.solid(gate_x + 1, self.wide - 4, 0, self.long - 1, self.wide - 1, 8);
        crenels(build, self.wide - 5, gate_x + 2, self.long - 2, 8, True);
        through = build.touch(float(gate_x + 1), float(middle - 2), 0.0, float(gate_x + 3), float(middle + 2), 6.0);
        wall_guard = build.waiting();
        through +>:Fires:+> wall_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(gate_x + 4 + index * 6) + 0.5, float(self.wide) - 2.5, 8, "monster_ogre", 270.0, waits=wall_guard);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x) - 3.5, 2.5 + float(index) * 4.0, 0, e2m2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dais_x) - 2.5, 2.5, 0, e2m2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m2's stretches: [name, role]."""
glob E2M2_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["tower", "flow"],
         ["court", "hub"],
         ["court", "flow"],
         ["hall", "keyroom"],
         ["sally", "end"],
         ["sally", "gate"]
     ];

"""One of e2m2's stretches by its name."""
def make_e2m2(name: str, key: str) -> Prefab {
    if name == "approach" {
        return CitadelApproach();
    }
    if name == "tower" {
        return SpiralTower();
    }
    if name == "court" {
        return CitadelCourt();
    }
    if name == "hall" {
        return OgreGoldHall(key=key if key else "key_gold");
    }
    return CitadelSally(key=key);
}
