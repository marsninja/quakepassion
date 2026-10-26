"""Prefabs drawn from e4m3, the Elder God Shrine: a shrine of stone in a
court, crypts of the dead behind door after door, a nave between aisles
with galleries over them, the key in a cage its guardian's death opens.
Raised in e4m3's own palette.

- `ShrineCourt`: the start. A court under the sky, a pool between four
  obelisks, the shrine across its far end, its door up a plinth.
- `ZombieCrypts`: a corridor between rows of crypts, each shut by a door,
  the dead (and what they guarded) inside.
- `ElderNave`: a nave between colonnades, galleries over the aisles up
  stairs at the far end, an altar at its head with a teleporter up to a
  gallery; ways on from the floor, the altar and the galleries (a hub).
- `GuardianCage`: the key in a cage at a hall's far end that opens when
  its guardian dies; taking the key opens the closets.
- `ShrineExit`: the end. A door (a key's, as a gate) into a shrine, the
  slipgate on an island in a pool reached stone by stone."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush }

glob E4M3: str = "q1:e4m3";

"""e4m3's foes: the dead above all, knights, fiends and spawn deeper in."""
def e4m3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_knight", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_knight"], ["monster_demon1", "monster_tarbaby"] if heavy else ["monster_wizard"], danger));
}

"""The start: a court, a pool between obelisks, the shrine's door up a
plinth."""
node ShrineCourt(Prefab) {
    has plinth: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shrine court";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(18, 22);
        self.plinth = dice.between(3, 4);
        self.low = -4;
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
        sx = self.long - 8;
        build.solid(sx, 1, 0, self.long - 1, self.wide - 1, 12);
        build.widen(court, sx, middle - 2, self.plinth, self.long - 1, middle + 2, self.plinth + 8);
        build.solid(sx - 4, middle - 3, 0, sx, middle + 3, self.plinth);
        stair(build, sx - 4 - self.plinth, middle - 2, 0, 0, self.plinth, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(court, sx - 4, y, self.plinth);
        }
        # The pool and the obelisks round it.
        px = self.long // 2 - 5;
        build.pool(px, middle - 3, -3, px + 6, middle + 3, 0, 2);
        for corner in [[px - 2, middle - 5], [px + 7, middle - 5], [px - 2, middle + 4], [px + 7, middle + 4]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 1, corner[1] + 1, 8);
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(3, 4)) {
            build.foe(float(px + 8 + index % 2 * 2) + 0.5, 3.5 + float(index) * 4.0, 0, e4m3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(sx) - 2.0, float(middle) + 0.5, self.plinth, e4m3_foe(dice, self.danger, True), 180.0);
        build.supply(float(sx) - 2.5, 2.5, 0, "item_health");
    }
}

"""A corridor between rows of crypts, each shut by a door, the dead inside."""
node ZombieCrypts(Prefab) {
    has tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zombie crypts";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(10, 12);
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
        corridor = build.room(1, 6, 0, self.long - 6, self.wide - 6, self.tall, variant=dice.below(3));
        build.room(self.long - 6, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.room(1, 1, 0, 3, self.wide - 1, self.tall, variant=dice.below(3));
        build.widen(corridor, 3, 6, 0, 4, self.wide - 6, self.tall);
        x = 4;
        index = 0;
        while x + 5 <= self.long - 7 {
            for south in [True, False] {
                y0 = 1 if south else self.wide - 5;
                door_y = 5 if south else self.wide - 6;
                crypt = build.room(x, y0, 0, x + 5, y0 + 4, 7, variant=dice.below(3));
                build.widen(crypt, x + 1, door_y, 0, x + 4, door_y + 1, 6);
                build.rising_door(float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 6.0, {"wait": "-1"});
                build.foe(float(x) + 2.5, float(y0) + 2.0, 0, "monster_zombie" if index % 3 != 2 else e4m3_foe(dice, self.danger, True), 90.0 if south else 270.0);
                if index % 2 == 0 {
                    build.supply(float(x) + 4.0, float(y0) + 1.0, 0, "item_health" if south else "item_spikes");
                }
                index += 1;
            }
            x += 6;
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * (float(self.wide) - 7.0), 0, e4m3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, e4m3_foe(dice, self.danger), 180.0);
    }
}

"""A nave between colonnades, galleries over the aisles up stairs at the
far end, an altar at its head, a teleporter from it up to a gallery."""
node ElderNave(Prefab) {
    has gallery: int = 6,
        altar: int = 3,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elder nave";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(24, 26);
        self.gallery = dice.between(6, 7);
        self.altar = dice.between(3, 4);
        self.tall = self.gallery + dice.between(12, 14);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.altar),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(nave, self.gallery);
        build.level(nave, self.altar);
        under = self.gallery - 1;
        south = 7;
        north = self.wide - 7;
        build.solid(6, 1, under, self.long - 1, south, self.gallery);
        build.solid(6, north, under, self.long - 1, self.wide - 1, self.gallery);
        for x in range(7, self.long - 1, 3) {
            build.solid(x, south - 1, 0, x + 1, south, under);
            build.solid(x, north, 0, x + 1, north + 1, under);
        }
        stair(build, self.long - 14, south, 0, 0, self.gallery, 2);
        stair(build, self.long - 14, north - 2, 0, 0, self.gallery, 2);
        for x in range(self.long - 9, self.long - 6) {
            build.keep(nave, x, south - 1, self.gallery);
            build.keep(nave, x, north, self.gallery);
        }
        # The altar at the nave's head, a stair up its face.
        ax = self.long - 6;
        build.solid(ax, middle - 3, 0, self.long - 1, middle + 3, self.altar);
        stair(build, ax - self.altar, middle - 2, 0, 0, self.altar, 4);
        build.teleporter(float(self.long) - 3.0, float(middle) + 2.0, self.altar, 10.0, float(self.wide) - 3.5, self.gallery, 0.0);
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, e4m3_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(12 + index * 6) + 0.5, 3.5 if index == 0 else float(self.wide) - 3.5, self.gallery, e4m3_foe(dice, self.danger, True), 0.0);
        }
        build.supply(float(self.long) - 3.0, float(middle) - 1.5, self.altar, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The key in a cage at a hall's far end that opens when its guardian dies;
taking the key opens the closets."""
node GuardianCage(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guardian cage (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(14, 16);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
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
        build.doorway(hall, self.enter);
        cx = self.long - 5;
        build.solid(cx + 1, cy - 3, 0, self.long - 1, cy - 2, 7);
        build.solid(cx + 1, cy + 2, 0, self.long - 1, cy + 3, 7);
        build.solid(cx, cy - 3, 6, self.long - 1, cy + 3, self.tall);
        cage = build.name("cage");
        build.rising_door(float(cx), float(cy - 2), 0.0, float(cx + 1), float(cy + 2), 6.0, {"targetname": cage, "wait": "-1"});
        guardian = "monster_shambler" if self.danger > 0.7 else "monster_hell_knight";
        build.foe(float(cx) - 4.5, float(cy) + 0.5, 0, guardian, 180.0, cage);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [3, cx - 5], [e4m3_foe(dice, self.danger), "monster_zombie"]);
        build.foe(4.5, 2.5, 0, "monster_zombie", 0.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The end: a door into a shrine, the slipgate on an island in a pool
reached stone by stone."""
node ShrineExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shrine exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
        self.low = -5;
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
        shrine = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(shrine, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The pool to the far wall, stones across to the island, steps up
        # out of the water onto the island's far side.
        x0 = wall + 3;
        build.pool(x0, 1, -4, self.long - 1, self.wide - 1, 0, 2);
        ix = self.long - 5;
        build.solid(ix - 2, middle - 2, -4, ix + 2, middle + 2, 0);
        for at in [x0 + 1, x0 + 3, x0 + 5] {
            if at < ix - 3 {
                build.solid(at, middle - 1, -4, at + 1, middle + 1, 0);
            }
        }
        stair(build, ix - 1, middle - 6, -4, 1, 4, 2);
        build.way_out(float(ix), float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 2.5, float(middle) + 4.5, -3, "monster_fish", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m3's stretches: [name, role]."""
glob E4M3_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["crypts", "flow"],
         ["nave", "hub"],
         ["nave", "flow"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m3's stretches by its name."""
def make_e4m3(name: str, key: str) -> Prefab {
    if name == "court" {
        return ShrineCourt();
    }
    if name == "crypts" {
        return ZombieCrypts();
    }
    if name == "nave" {
        return ElderNave();
    }
    if name == "cage" {
        return GuardianCage(key=key if key else "key_silver");
    }
    return ShrineExit(key=key);
}
