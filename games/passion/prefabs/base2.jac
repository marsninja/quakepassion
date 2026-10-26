"""Prefabs drawn from Quake II's base2, the Installation: halls of steel
behind blast doors, a lobby under a gallery, a corridor with a catwalk
over its doors, a reactor in a pit bridged to, the key in a server room
of racks. Raised in base2's own palette.

- `InstallationLobby`: the start. A lobby, a gallery round three of its
  walls up a stair; ways on from the floor and the gallery.
- `BlastCorridor`: a corridor shut across by blast doors one after
  another, a catwalk along its wall over them up a stair at its near end.
- `ReactorRing`: a reactor column in a pit, bridges from the floor round
  it out to the column's foot; ways on round the walls (a hub).
- `ServerRacks`: rows of racks across a room, the key at its far end;
  taking it opens the closets.
- `InstallationExit`: the end. A door (a key's, as a gate), an airlock and
  the way out beyond it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush }

glob BASE2: str = "q2:base2";

"""The start: a lobby, a gallery round three walls up a stair."""
node InstallationLobby(Prefab) {
    has gallery: int = 6,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation lobby";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.gallery), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        lobby = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(lobby, self.gallery);
        under = self.gallery - 1;
        build.solid(6, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(self.long - 4, 5, under, self.long - 1, self.wide - 4, self.gallery);
        stair(build, self.long - 4 - self.gallery, self.wide - 7, 0, 0, self.gallery, 3);
        for x in range(self.long - 7, self.long - 4) {
            build.keep(lobby, x, self.wide - 4, self.gallery);
        }
        pillars(build, 8, self.wide - 5, self.long - 6 - self.gallery, self.wide - 4, 0, under, 4, []);
        build.doorway(lobby, self.enter);
        for port in self.taken {
            build.doorway(lobby, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(middle) - 2.5, 0, q2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, self.gallery, q2_foe(dice, self.danger, True), 180.0);
        build.foe(10.5, float(self.wide) - 2.5, self.gallery, q2_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, 7.5, self.gallery, Q2_HEALTH, "q2");
    }
}

"""A corridor shut across by blast doors, a catwalk along its wall over
them up a stair at its near end."""
node BlastCorridor(Prefab) {
    has walk: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blast corridor";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(12, 14);
        self.walk = dice.between(6, 7);
        self.tall = self.walk + 7;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float((self.wide - 4) // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.walk), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cw = self.wide - 4;
        middle = cw // 2;
        corridor = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(corridor, self.walk);
        # The catwalk along the north wall, a stair up to it at the near end.
        build.solid(1 + self.walk, cw, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        stair(build, 1, cw, 0, 0, self.walk, 3);
        # The blast doors across the corridor below the catwalk.
        for x in [self.long // 3, 2 * self.long // 3] {
            build.solid(x, 1, 0, x + 1, cw, self.tall);
            build.widen(corridor, x, middle - 2, 0, x + 1, middle + 2, 6);
            build.rising_door(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 6.0, {"wait": "-1"});
        }
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 3 + 3 + index * 4) + 0.5, float(middle) + 0.5, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, self.walk, q2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 4, q2_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.walk, "ammo_bullets", "q2");
    }
}

"""A reactor column in a pit, bridges from the floor round it out to the
column's foot."""
node ReactorRing(Prefab) {
    has deep: int = 5,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor ring";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.deep = dice.between(5, 6);
        self.tall = dice.between(18, 22);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        # The pit round the column, a stair up out of it in two corners.
        build.widen(hall, 6, 6, low, self.long - 6, self.wide - 6, 0);
        build.solid(cx - 2, cy - 2, low, cx + 2, cy + 2, self.tall);
        stair(build, 6, 6 + self.deep - 1, low, 3, self.deep, 2);
        stair(build, self.long - 8, self.wide - 6 - self.deep, low, 1, self.deep, 2);
        # Bridges from the west and east floors to the column's foot.
        build.solid(6, cy - 1, -1, cx - 2, cy + 1, 0);
        build.solid(cx + 2, cy - 1, -1, self.long - 6, cy + 1, 0);
        for y in [cy - 1, cy] {
            build.keep(hall, 5, y, 0);
            build.keep(hall, self.long - 6, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 3) + 0.5, float(cy) + 4.5, low, q2_foe(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(3.5 + float(index) * (float(self.long) - 7.0), 3.5, 0, q2_foe(dice, self.danger, index == 0), 90.0);
        }
        build.supply(float(cx) + 3.0, float(cy) + 0.5, 0, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""Rows of racks across a room, the key at its far end; taking it opens the
closets."""
node ServerRacks(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Server racks (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(10, 12);
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
        # The racks: rows across the room, a gap at alternate ends.
        for (index, x) in enumerate(range(5, self.long - 4, 4)) {
            if index % 2 == 0 {
                build.solid(x, 1, 0, x + 1, side - 3, 6);
            } else {
                build.solid(x, 4, 0, x + 1, side, 6);
            }
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [1], [q2_foe(dice, self.danger, True)]);
        build.foe(float(self.long) - 2.5, 2.5, 0, q2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, 0, q2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, an airlock and the way out beyond it."""
node InstallationExit(Prefab) {
    has key: str = "",
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(11, 13);
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
        lock = wall + 5;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        airlock = build.room(wall + 1, middle - 3, 0, lock, middle + 3, 8, variant=dice.below(3));
        bay = build.room(lock + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(airlock, wall, middle - 2, 0, wall + 1, middle + 2, 7);
        build.widen(bay, lock, middle - 2, 0, lock + 1, middle + 2, 7);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 7.0, {"key": self.key, "wait": "-1"});
        }
        build.rising_door(float(lock), float(middle - 2), 0.0, float(lock + 1), float(middle + 2), 7.0, {"wait": "-1"});
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(lock) + 3.5, 2.5, 0, q2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""base2's stretches: [name, role]."""
glob BASE2_STRETCHES: list[list[str]] = [
         ["lobby", "start"],
         ["corridor", "flow"],
         ["reactor", "hub"],
         ["reactor", "flow"],
         ["racks", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of base2's stretches by its name."""
def make_base2(name: str, key: str) -> Prefab {
    if name == "lobby" {
        return InstallationLobby();
    }
    if name == "corridor" {
        return BlastCorridor();
    }
    if name == "reactor" {
        return ReactorRing();
    }
    if name == "racks" {
        return ServerRacks(key=key if key else "key_silver");
    }
    return InstallationExit(key=key);
}
