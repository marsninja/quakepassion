"""Prefabs drawn from Quake II's hangar1, the Outer Hangar: an apron under
the sky by a water inlet, a docking basin round a ship's hull moored in
it, the great hangar with a ship on its floor under catwalks, the key in
the flight office. Raised in hangar1's own palette.

- `HangarApron`: the start. An apron under the sky, a water inlet cut into
  its side, a control tower by the far wall; ways on from three sides.
- `DockingBasin`: a basin of water, a hull moored in it, walkways round the
  basin and a gangway over to the hull's deck; the way on beyond.
- `HangarHall`: the hangar, a ship on its floor, catwalks along both walls
  up stairs, a bridge between them over the ship; ways on from the floor
  and the catwalks (a hub).
- `FlightOffice`: the key in an office up a stair over the hangar floor;
  taking it opens the closets.
- `HangarExit`: the end. A door (a key's, as a gate), a launch pad under
  the sky, the way out on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into }

glob HANGAR1: str = "q2:hangar1";

"""hangar1's foes: infantry and gunners, hovers and flyers, a tank deeper
in."""
def hangar1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_infantry", "monster_gunner"] if heavy else ["monster_infantry", "monster_infantry", "monster_hover"], ["monster_tank"] if heavy else ["monster_gunner"], danger * 0.3 if heavy else danger * 0.6));
}

"""The start: an apron under the sky, a water inlet cut into its side, a
control tower by the far wall."""
node HangarApron(Prefab) {
    has tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar apron";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.tall = dice.between(20, 24);
        self.low = -6;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        apron = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.pool(10, self.wide - 7, -5, self.long - 8, self.wide - 1, 0, 2);
        stair(build, self.long - 13, self.wide - 7, -5, 0, 5, 2);
        build.solid(self.long - 7, 3, 0, self.long - 3, 7, 12);
        build.doorway(apron, self.enter);
        for port in self.taken {
            build.doorway(apron, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(12 + index * 4) + 0.5, 4.5 + float(index % 2) * 4.0, 0, hangar1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(14) + 0.5, float(self.wide) - 4.0, -4, "monster_flipper", 0.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 10, "monster_hover", 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A basin of water, a hull moored in it, walkways round the basin and a
gangway over to the hull's deck."""
node DockingBasin(Prefab) {
    has deck: int = 3,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Docking basin";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.deck = dice.between(2, 3);
        self.tall = dice.between(16, 20);
        self.low = -7;
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
        bay = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 5;
        x1 = self.long - 5;
        build.pool(x0, 4, -6, x1, self.wide - 4, 0, 2, False, True, True);
        stair(build, x1 - 6, 4, -6, 0, 6, 2);
        stair(build, x1 - 6, self.wide - 6, -6, 0, 6, 2);
        # The hull: a long block in the basin's middle, its deck a little
        # over the walkways, gangways to it from the near and far walks.
        hx0 = x0 + 4;
        hx1 = x1 - 4;
        build.solid(hx0, middle - 3, -6, hx1, middle + 3, self.deck);
        build.solid(hx0 + 4, middle - 1, self.deck, hx0 + 8, middle + 1, self.deck + 4);
        build.solid(x0, middle - 1, self.deck - 1, hx0, middle + 1, self.deck);
        stair(build, x0 - self.deck, middle - 1, 0, 0, self.deck, 2);
        stair(build, hx1 + self.deck - 1, middle - 1, 0, 2, self.deck, 2);
        build.solid(hx1 + self.deck, middle - 1, -1, x1, middle + 1, 0);
        build.doorway(bay, self.enter);
        for port in self.taken {
            build.doorway(bay, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(hx0 + 10 + index * 3) + 0.5, float(middle) + 1.5, self.deck, hangar1_foe(dice, self.danger, index == 0), 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 6) + 0.5, 6.0, -5, "monster_flipper", 0.0);
        }
        build.foe(float(x1) + 2.5, 3.0, 0, hangar1_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(hx0) + 2.0, float(middle) + 2.0, self.deck, "ammo_bullets", "q2");
    }
}

"""The hangar, a ship on its floor, catwalks along both walls up stairs, a
bridge between them over the ship."""
node HangarHall(Prefab) {
    has walk: int = 9,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hangar hall";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.walk = dice.between(8, 10);
        self.tall = self.walk + 14;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.walk),
            Port(face=0, along=float(self.wide - 3), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hangar = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hangar, self.walk);
        # The ship: hull, cabin and wings on the floor.
        build.solid(cx - 7, cy - 2, 0, cx + 7, cy + 2, 5);
        build.solid(cx - 3, cy - 7, 2, cx + 1, cy + 7, 3);
        build.solid(cx + 3, cy - 1, 5, cx + 6, cy + 1, 7);
        under = self.walk - 1;
        build.solid(1, 1, under, self.long - 1, 4, self.walk);
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.walk);
        build.solid(self.long - 4, 4, under, self.long - 1, self.wide - 4, self.walk);
        stair(build, 3, 4, 0, 0, self.walk, 2);
        stair(build, 3, self.wide - 6, 0, 0, self.walk, 2);
        build.doorway(hangar, self.enter);
        for port in self.taken {
            build.doorway(hangar, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(cx - 9 + index * 6) + 0.5, float(cy) + (4.5 if index % 2 == 0 else -4.5), 0, hangar1_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 4.5, float(cy) + 0.5, 7, hangar1_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, 2.5, self.walk, hangar1_foe(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, float(cy) + 0.5, self.walk, Q2_ARMOR, "q2");
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an office up a stair over the hangar floor; taking it opens
the closets."""
node FlightOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flight office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(5, 7);
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
        build.solid(ox, 5, self.office, ox + 1, side - 1, self.office + 2);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.office, side, 0, [3, ox - 4], [hangar1_foe(dice, self.danger, True), hangar1_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, float(side) - 2.5, self.office, hangar1_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a launch pad under the sky, the way out on it."""
node HangarExit(Prefab) {
    has key: str = "",
        pad: int = 2,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Launch pad" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = HANGAR1;
        self.district = level_district(HANGAR1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.pad = dice.between(1, 2);
        self.tall = dice.between(18, 22);
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
        px = self.long - 10;
        build.solid(px, middle - 4, 0, self.long - 2, middle + 4, self.pad);
        stair(build, px - self.pad, middle - 2, 0, 0, self.pad, 4);
        build.way_out(float(px) + 4.0, float(middle), self.pad);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, hangar1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 0, hangar1_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""hangar1's stretches: [name, role]."""
glob HANGAR1_STRETCHES: list[list[str]] = [
         ["apron", "start"],
         ["basin", "flow"],
         ["hangar", "hub"],
         ["hangar", "flow"],
         ["office", "keyroom"],
         ["pad", "end"],
         ["pad", "gate"]
     ];

"""One of hangar1's stretches by its name."""
def make_hangar1(name: str, key: str) -> Prefab {
    if name == "apron" {
        return HangarApron();
    }
    if name == "basin" {
        return DockingBasin();
    }
    if name == "hangar" {
        return HangarHall();
    }
    if name == "office" {
        return FlightOffice(key=key if key else "key_silver");
    }
    return HangarExit(key=key);
}
