"""Prefabs drawn from Quake II's train, the Lost Station: a station sunk deep
in rock, platforms beside a track bed, a tunnel the track runs down with
walkways either side, a concourse on three levels joined by lifts, the
key in a signal box up a stair, water standing in the track bed's sump.
Raised in train's own palette.

- `StationPlatform`: the start. A platform beside a track bed sunk across
  the hall, a footbridge over it; ways on from the far platform and the
  bed's ends.
- `TrackTunnel`: a tunnel, the track bed down its middle and a walkway
  either side, water standing in a sump in the bed, a footbridge over it.
- `Concourse`: a concourse on three levels, a lift from each to the next;
  ways on from every level (a hub).
- `SignalBox`: the key in a signal box up a stair along the wall; taking
  it opens the closets on the floor.
- `StationExit`: the end. A door (a key's, as a gate) onto a platform, the
  way out at its end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush }

glob TRAIN: str = "q2:train";

"""The start: a platform beside a track bed, a footbridge over it."""
node StationPlatform(Prefab) {
    has bed: int = 3,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station platform";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.bed = dice.between(3, 4);
        self.tall = dice.between(13, 15);
        self.low = -self.bed - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 4), floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=-self.bed)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.bed;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        # The track bed across the hall's middle, x-long, rails in it.
        build.widen(hall, 1, middle - 3, low, self.long - 1, middle + 3, 0);
        for y in [middle - 2, middle + 1] {
            build.solid(1, y, low, self.long - 1, y + 1, low + 1);
        }
        stair(build, 3, middle - 4 + self.bed, low, 3, self.bed, 2);
        stair(build, self.long - 5, middle + 3 - self.bed, low, 1, self.bed, 2);
        # The footbridge over the bed.
        fx = self.long // 2 - 2;
        build.solid(fx, middle - 3, -1, fx + 4, middle + 3, 0);
        for x in range(fx, fx + 4) {
            build.keep(hall, x, middle - 4, 0);
            build.keep(hall, x, middle + 3, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, 4.5, 0, 0.0);
        build.supply(4.5, 2.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(self.wide) - 3.5, 0, q2_foe(dice, self.danger), 270.0);
        }
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, low, q2_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A tunnel, the track bed down its middle and a walkway either side, water
standing in a sump in the bed, a footbridge over it."""
node TrackTunnel(Prefab) {
    has bed: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Track tunnel";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(28, 32);
        self.wide = dice.between(14, 16);
        self.bed = dice.between(3, 4);
        self.tall = dice.between(11, 13);
        self.low = -self.bed - 4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=3.0, floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.bed;
        tunnel = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tunnel, low);
        build.widen(tunnel, 1, middle - 3, low, self.long - 1, middle + 3, 0);
        # The sump in the bed's middle, shallow enough to wade, steps out of it
        # at both ends.
        sx = self.long // 2 - 4;
        build.pool(sx, middle - 3, low - 2, sx + 8, middle + 3, low, 2, False, True, True);
        stair(build, sx + 6, middle - 1, low - 2, 0, 2, 2);
        # Steps down into the bed at either end, a footbridge over the sump
        # (the bed too shallow to walk under one anywhere else).
        stair(build, 2, middle - 4 + self.bed, low, 3, self.bed, 2);
        stair(build, self.long - 4, middle + 3 - self.bed, low, 1, self.bed, 2);
        build.solid(sx + 3, middle - 3, -1, sx + 6, middle + 3, 0);
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 6 - index * 5) + 0.5, 2.5 if index % 2 == 0 else float(self.wide) - 2.5, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A concourse on three levels, a lift from each to the next."""
node Concourse(Prefab) {
    has rise_by: int = 6,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Concourse";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.rise_by = dice.between(6, 7);
        self.tall = 2 * self.rise_by + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=2 * self.rise_by),
            Port(face=1, along=float(self.long // 2), floor=self.rise_by),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=self.rise_by)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        first = self.rise_by;
        second = 2 * self.rise_by;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, first);
        build.level(hall, second);
        step = kit_of(build.district).step;
        # The first level: a mezzanine over the floor's far two-thirds.
        m1 = self.long // 3;
        build.solid(m1, 1, first - 1, self.long - 1, self.wide - 1, first);
        build.widen(hall, m1 + 4, 6, first - 1, self.long - 8, self.wide - 6, first);
        # The second level: a gallery across the far end.
        m2 = self.long - 7;
        build.solid(m2, 1, second - 1, self.long - 1, self.wide - 1, second);
        build.widen(hall, m2 - 3, 2, first - 1, m2, 5, first);
        build.put_box({"classname": "func_plat", "height": str(first * 16), "speed": "200"}, float(m1 - 3), float(middle - 1), float(first) - 0.5, float(m1), float(middle + 2), float(first), step);
        build.put_box({"classname": "func_plat", "height": str((second - first) * 16), "speed": "200"}, float(m2 - 3), 2.0, float(second) - 0.5, float(m2), 5.0, float(second), step);
        for y in range(middle - 2, middle + 3) {
            build.keep(hall, m1, y, first);
        }
        for y in range(1, 6) {
            build.keep(hall, m2, y, second);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(m1 // 2) + 0.5, 3.5 + float(index) * 5.0, 0, q2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(m1 + 2) + 0.5, float(self.wide) - 3.0, first, q2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, second, q2_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, first + 4, q2_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, second, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, Q2_ARMOR, "q2");
    }
}

"""The key in a signal box up a stair along the wall; taking it opens the
closets on the floor."""
node SignalBox(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        box: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Signal box (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.box = dice.between(5, 7);
        self.tall = self.box + 8;
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
        build.level(hall, self.box);
        build.doorway(hall, self.enter);
        bx = self.long - 6;
        build.solid(bx, 1, self.box - 1, self.long - 1, 7, self.box);
        stair(build, bx - self.box, 1, 0, 0, self.box, 2);
        build.solid(bx, 7, self.box, self.long - 1, 8, self.box + 2);
        key_ambush(build, self.key, float(self.long) - 3.0, 4.0, self.box, side, 0, [3, bx - 3], [q2_foe(dice, self.danger, True), q2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.0, float(cy) + 3.5, 0, q2_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door onto a platform, the way out at its end."""
node StationExit(Prefab) {
    has key: str = "",
        bed: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Station exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = TRAIN;
        self.district = level_district(TRAIN);
        self.long = dice.between(24, 26);
        self.wide = dice.between(14, 16);
        self.bed = dice.between(3, 4);
        self.tall = dice.between(11, 13);
        self.low = -self.bed - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        platform = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(platform, -self.bed);
        build.doorway(hall, self.enter);
        build.widen(platform, wall, 2, 0, wall + 1, 6, 8);
        if self.key {
            build.rising_door(float(wall), 2.0, 0.0, float(wall + 1), 6.0, 8.0, {"key": self.key, "wait": "-1"});
        }
        build.widen(platform, wall + 1, 8, -self.bed, self.long - 1, self.wide - 1, 0);
        stair(build, wall + 3, 7 + self.bed, -self.bed, 3, self.bed, 2);
        build.way_out(float(self.long) - 3.5, 4.0, 0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 5.5, float(self.wide) - 3.0, -self.bed, q2_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""train's stretches: [name, role]."""
glob TRAIN_STRETCHES: list[list[str]] = [
         ["platform", "start"],
         ["tunnel", "flow"],
         ["concourse", "hub"],
         ["concourse", "flow"],
         ["signal", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of train's stretches by its name."""
def make_train(name: str, key: str) -> Prefab {
    if name == "platform" {
        return StationPlatform();
    }
    if name == "tunnel" {
        return TrackTunnel();
    }
    if name == "concourse" {
        return Concourse();
    }
    if name == "signal" {
        return SignalBox(key=key if key else "key_silver");
    }
    return StationExit(key=key);
}
