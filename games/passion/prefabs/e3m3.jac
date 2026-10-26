"""Prefabs drawn from e3m3, the Tomb of Terror: a tomb behind its facade,
chambers walled off from each other and joined only by teleporters, a
nave with water down its middle and galleries along its sides, the
silver key on a ledge teleported up to. Raised in e3m3's own palette.

- `TombFacade`: the start. A court under the sky, the tomb's facade across
  its far end, its door up a stair on a plinth.
- `TeleportMaze`: three chambers walled off from each other, a teleporter
  from each to the next and one from the last back to the first.
- `TombNave`: a nave, a channel of water down its middle and a footbridge
  over it, galleries along both sides up stairs at the far end and
  bridged at the near; ways on from the floor and the galleries (a hub).
- `SilverSepulchre`: a sepulchre, the key on a ledge high on its far wall
  reached by a teleporter and dropped from; taking it opens the closets.
- `TombExit`: the end. A door (a key's, as a gate) into a crypt, the
  slipgate sunk down three steps at its far end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E3M3: str = "q1:e3m3";

"""e3m3's foes: the dead and ogres, scrags, hell knights deeper in."""
def e3m3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_ogre"] if heavy else ["monster_zombie", "monster_ogre", "monster_wizard"], ["monster_demon1"] if heavy else ["monster_hell_knight"], danger));
}

"""The start: a court, the tomb's facade, its door up a stair on a plinth."""
node TombFacade(Prefab) {
    has plinth: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb facade";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.plinth = dice.between(3, 4);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.plinth), Port(face=1, along=6.0, floor=0), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.plinth);
        # The facade, its door through it at the plinth's top.
        fx = self.long - 6;
        build.solid(fx, 1, 0, self.long - 1, self.wide - 1, self.tall - 4);
        build.widen(court, fx, middle - 2, self.plinth, self.long - 1, middle + 2, self.plinth + 8);
        build.solid(fx - 5, middle - 4, 0, fx, middle + 4, self.plinth);
        stair(build, fx - 5 - self.plinth, middle - 2, 0, 0, self.plinth, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(court, fx - 5, y, self.plinth);
        }
        # Columns along the facade's face.
        for y in range(2, self.wide - 2, 3) {
            if abs(y - middle) > 4 {
                build.solid(fx - 1, y, 0, fx, y + 1, self.tall - 4);
            }
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx) - 8.5 + float(index) * 2.0, 3.5 + float(index) * 5.0, 0, e3m3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(fx) - 3.0, float(middle) + 0.5, self.plinth, e3m3_foe(dice, self.danger, True), 180.0);
        build.supply(float(fx) - 3.0, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""Three chambers walled off from each other, a teleporter from each to
the next and one from the last back to the first."""
node TeleportMaze(Prefab) {
    has tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport maze";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(11, 13);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        a1 = 8;
        b1 = 17;
        first = build.room(1, 1, 0, a1, self.wide - 1, self.tall, variant=dice.below(3));
        build.room(a1 + 1, 1, 0, b1, self.wide - 1, self.tall, variant=dice.below(3));
        third = build.room(b1 + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.teleporter(float(a1) - 2.0, float(middle) + 3.0, 0, float(a1) + 2.5, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(b1) - 2.0, 3.0, 0, float(b1) + 2.5, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(b1) + 2.5, float(self.wide) - 3.0, 0, 3.0, 3.0, 0, 0.0);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(third, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(a1) + 4.5, 3.5 + float(index) * 6.0, 0, e3m3_foe(dice, self.danger), 180.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 3.5 + float(index) * 4.0, 0, e3m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5, float(self.wide) - 3.5, 0, "monster_zombie", 0.0);
        build.supply(float(a1) + 4.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_spikes");
    }
}

"""A nave, a channel of water down its middle and a footbridge over it,
galleries along both sides up stairs at the far end and bridged at the
near."""
node TombNave(Prefab) {
    has gallery: int = 7,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb nave";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(18, 22);
        self.gallery = dice.between(7, 8);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, self.gallery);
        # The channel down the middle, one footbridge over it, steps up out
        # of it at both ends.
        cx0 = 8;
        cx1 = self.long - 8;
        build.pool(cx0, middle - 2, -3, cx1, middle + 2, 0, 2);
        fx = self.long // 2 - 1;
        build.solid(fx, middle - 2, -3, fx + 3, middle + 2, 0);
        stair(build, fx - 3, middle - 2, -3, 0, 3, 2);
        stair(build, fx + 5, middle - 2, -3, 2, 3, 2);
        stair(build, cx1 - 3, middle - 2, -3, 0, 3, 2);
        # The galleries, a stair up to each at the far end, a bridge between
        # them at the near end.
        under = self.gallery - 1;
        build.solid(1, 1, under, self.long - 1, 5, self.gallery);
        build.solid(1, self.wide - 5, under, self.long - 1, self.wide - 1, self.gallery);
        stair(build, self.long - 3 - self.gallery, 5, 0, 0, self.gallery, 2);
        stair(build, self.long - 3 - self.gallery, self.wide - 7, 0, 0, self.gallery, 2);
        build.solid(3, 5, under, 6, self.wide - 5, self.gallery);
        for x in range(self.long - 6, self.long - 2) {
            build.keep(nave, x, 4, self.gallery);
            build.keep(nave, x, self.wide - 5, self.gallery);
        }
        for x in range(3, 6) {
            build.keep(nave, x, 4, self.gallery);
            build.keep(nave, x, self.wide - 5, self.gallery);
        }
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 5) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, e3m3_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 8) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0, self.gallery, e3m3_foe(dice, self.danger, True), 0.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 9, "monster_wizard", 180.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(4.5, float(middle) + 0.5, self.gallery, "item_rockets");
    }
}

"""A sepulchre, the key on a ledge high on its far wall reached by a
teleporter and dropped from; taking it opens the closets."""
node SilverSepulchre(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        ledge: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver sepulchre (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(7, 9);
        self.tall = self.ledge + 8;
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
        lx = self.long - 5;
        build.solid(lx, 1, self.ledge - 1, self.long - 1, side, self.ledge);
        for y in range(2, side - 1) {
            build.keep(hall, lx, y, self.ledge);
        }
        build.teleporter(float(self.long // 2) - 1.0, float(cy) + 0.5, 0, float(self.long) - 3.0, 3.0, self.ledge, 90.0);
        # Sarcophagi on the floor.
        for y in [3, side - 4] {
            build.solid(5, y, 0, 8, y + 2, 2);
        }
        key_ambush(build, self.key, float(self.long) - 3.0, float(side) - 3.0, self.ledge, side, 0, [2, lx - 5], [e3m3_foe(dice, self.danger, True), "monster_zombie"]);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, self.ledge, e3m3_foe(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a crypt, the slipgate sunk down three steps at its
far end."""
node TombExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(13, 15);
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        crypt = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(crypt, -3);
        build.doorway(hall, self.enter);
        build.widen(crypt, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        sx = self.long - 8;
        build.widen(crypt, sx, 2, -3, self.long - 1, self.wide - 2, 0);
        stair(build, sx + 2, 2, -3, 2, 3, self.wide - 4);
        build.way_out(float(self.long) - 3.0, float(middle), -3);
        pillars(build, wall + 3, 2, sx - 1, 3, 0, self.tall, 3, []);
        pillars(build, wall + 3, self.wide - 3, sx - 1, self.wide - 2, 0, self.tall, 3, []);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e3m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 3.5, -3, e3m3_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m3's stretches: [name, role]."""
glob E3M3_STRETCHES: list[list[str]] = [
         ["facade", "start"],
         ["maze", "flow"],
         ["nave", "hub"],
         ["nave", "flow"],
         ["sepulchre", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m3's stretches by its name."""
def make_e3m3(name: str, key: str) -> Prefab {
    if name == "facade" {
        return TombFacade();
    }
    if name == "maze" {
        return TeleportMaze();
    }
    if name == "nave" {
        return TombNave();
    }
    if name == "sepulchre" {
        return SilverSepulchre(key=key if key else "key_silver");
    }
    return TombExit(key=key);
}
