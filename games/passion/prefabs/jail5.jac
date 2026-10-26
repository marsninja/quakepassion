"""Prefabs drawn from Quake II's jail5, the Guard House: a courtyard under
the sky round a fountain, a battlement walked between two towers, a
barracks of bunks under a gallery, the key in the captain's quarters up
a tower. Raised in jail5's own palette.

- `GuardCourtyard`: the start. A courtyard, a fountain in it, the guard
  house's porch up steps; ways on from the porch and the yard.
- `Battlement`: a wall under the sky between two towers, its top walked
  from one tower's stair to the other's; the yard below.
- `Barracks`: a hall of bunks in rows, a gallery round it up a stair;
  ways on from the floor and the gallery (a hub).
- `CaptainQuarters`: the key in the captain's room at the top of a tower
  up a stair winding round it; taking it opens the closets below.
- `GuardExit`: the end. A door (a key's, as a gate) out to a yard, the
  way out on a dais in it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, spiral }
import from .e1m5 { crenels }

glob JAIL5: str = "q2:jail5";

"""jail5's foes: soldiers and flyers, mutants and a tank deeper in."""
def jail5_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_soldier_ss", "monster_mutant"] if heavy else ["monster_soldier", "monster_soldier_ss", "monster_soldier_light"], ["monster_tank"] if heavy else ["monster_mutant", "monster_infantry"], danger * 0.5 if heavy else danger));
}

"""The start: a courtyard, a fountain, the guard house's porch up steps."""
node GuardCourtyard(Prefab) {
    has porch: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard courtyard";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.porch = dice.between(3, 4);
        self.tall = dice.between(18, 22);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.porch), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.porch);
        px = self.long - 7;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.porch);
        stair(build, px - self.porch, middle - 3, 0, 0, self.porch, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(yard, px, y, self.porch);
        }
        fx = self.long // 2 - 4;
        build.pool(fx, middle - 3, -3, fx + 6, middle + 3, 0, 2);
        build.solid(fx + 2, middle, -3, fx + 3, middle + 1, 4);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(px) - 3.5, 3.5 + float(index) * 6.0, 0, jail5_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, self.porch, jail5_foe(dice, self.danger, True), 180.0);
        build.foe(float(fx) + 3.0, float(middle) + 5.0, 7, jail5_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.porch, Q2_HEALTH, "q2");
    }
}

"""A wall under the sky between two towers, its top walked from one
tower's stair to the other's; the yard below."""
node Battlement(Prefab) {
    has wall: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Battlement";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.wall = dice.between(7, 9);
        self.tall = self.wall + 12;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=4.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.wall), Port(face=1, along=float(self.long // 2), floor=self.wall)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, self.wall);
        wy = self.wide - 6;
        # The wall along the north side, its top walked, merlons on its edge.
        build.solid(1, wy, 0, self.long - 1, self.wide - 1, self.wall);
        crenels(build, wy, 9, self.long - 9, self.wall, True);
        # Towers at both ends, a stair up the west one's face to the walk.
        build.solid(1, wy - 3, 0, 6, wy, self.wall + 4);
        build.solid(self.long - 6, wy - 3, 0, self.long - 1, wy, self.wall + 4);
        stair(build, 6, wy - self.wall, 0, 1, self.wall, 3);
        for x in range(6, 9) {
            build.keep(ground, x, wy, self.wall);
        }
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 5) + 0.5, float(self.wide) - 3.0, self.wall, jail5_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(12 + index * 5) + 0.5, 3.5, 0, jail5_foe(dice, self.danger, index == 0), 90.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(wy) - 4.0, self.wall + 2, jail5_foe(dice, self.danger, False, True), 90.0);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, self.wall, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, 0, "ammo_bullets", "q2");
    }
}

"""A hall of bunks in rows, a gallery round it up a stair."""
node Barracks(Prefab) {
    has gallery: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Barracks";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gallery);
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.gallery);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.gallery);
        stair(build, 5, 4, 0, 0, self.gallery, 2);
        for x in [5 + self.gallery - 2, 5 + self.gallery - 1] {
            build.keep(hall, x, 3, self.gallery);
        }
        # Bunks: low blocks in rows across the floor, aisles between.
        for x in range(8, self.long - 6, 4) {
            for y in [6, self.wide - 8] {
                build.solid(x, y, 0, x + 2, y + 2, 2);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(9 + index * 4) + 0.5, float(middle) + 0.5, 0, jail5_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 5) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, self.gallery, jail5_foe(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in the captain's room at the top of a tower up a stair winding
round it; taking it opens the closets below."""
node CaptainQuarters(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        steps: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Captain quarters (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, self.steps);
        build.doorway(hall, self.enter);
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.steps);
        spiral(build, cx - 4, cy - 4, cx + 4, cy + 4, 0, self.steps, 2, 2);
        key_ambush(build, self.key, float(cx), float(cy), self.steps, side, 0, [2, self.long - 5], [jail5_foe(dice, self.danger, True), jail5_foe(dice, self.danger)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, jail5_foe(dice, self.danger), 180.0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps + 4, jail5_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door out to a yard, the way out on a dais in it."""
node GuardExit(Prefab) {
    has key: str = "",
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL5;
        self.district = level_district(JAIL5);
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
        dx = self.long - 7;
        build.solid(dx, middle - 4, 0, self.long - 1, middle + 4, 2);
        stair(build, dx - 2, middle - 2, 0, 0, 2, 4);
        build.way_out(float(self.long) - 3.5, float(middle), 2);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, jail5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 3.5, 2.5, 0, jail5_foe(dice, self.danger, True), 180.0);
        build.foe(float(dx) - 2.0, float(middle) + 4.5, 6, jail5_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail5's stretches: [name, role]."""
glob JAIL5_STRETCHES: list[list[str]] = [
         ["courtyard", "start"],
         ["battlement", "flow"],
         ["barracks", "hub"],
         ["barracks", "flow"],
         ["captain", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail5's stretches by its name."""
def make_jail5(name: str, key: str) -> Prefab {
    if name == "courtyard" {
        return GuardCourtyard();
    }
    if name == "battlement" {
        return Battlement();
    }
    if name == "barracks" {
        return Barracks();
    }
    if name == "captain" {
        return CaptainQuarters(key=key if key else "key_silver");
    }
    return GuardExit(key=key);
}
