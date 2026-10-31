"""Prefabs drawn from e4m4, the Palace of Hate: a palace of halls under
dark stone, a reflecting pool with a healing pool hidden under it, a
target shot over a balcony that bursts open a fiend's door, deep water
crossed by a raft riding to and fro, a throne whose approach brings
fiends in by teleporter, alcoves behind slow doors a button lowers one
after another, knights and fiends walking their rounds, the silver key
on a high shelf. Raised in e4m4's own palette.

- `HateAntechamber`: the start. A reflecting pool in a hall, twin stairs
  up either side to a balcony across its far end; a target over the
  balcony, shot, bursts open a door in the side wall on a fiend; under the
  pool's water an alcove, the healing pool ("You have found a healing
  pool!"). Knights walk the floor and the balcony.
- `FishGallery`: a long gallery, deep water across its middle, swum (fish
  in it) or crossed on a raft riding from shore to shore; a walkway along
  one wall over the water, a lift up to it; boarding the raft teleports a
  foe in on the far shore.
- `HateThrone`: a throne on a dais at a hall's head, galleries along its
  sides ridden up to by lifts; climbing to the dais teleports fiends in
  behind; a button on the dais sinks the doors of two alcoves; a closet in
  the dais behind a wall that opens when shot (a secret); ways on from the
  dais, the galleries and the floor (a hub).
- `SinkingAlcoves`: a long hall of alcoves either side, each behind a slow
  door; a button at the hall's head lowers them one after another (relays
  timing each), knights and supplies behind; a gallery over the far end
  climbed by a stair, the way on there or below.
- `PalaceVault`: the key room. The key on a shelf high on a vault's far
  wall, a lift up to it; taking it opens the closets and teleports a fiend
  in.
- `PalaceExit`: the end. A door (a key's, as a gate) into a hall, the
  slipgate on a dais between braziers ("Are you sure you want to exit"),
  doors either side of the dais bursting open as it is approached."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix }
import from .common { stair, pillars, key_ambush, lift, key_item }
import from .e3m5 { keep_run, sealed_way, bursting }
import from .e3m6 { rounds }
import from .e3m7 { relayed }

glob E4M4: str = "q1:e4m4";

"""e4m4's foes: fiends and knights, scrags, hell knights deeper in."""
glob E4M4_FOES: FoeMix = FoeMix(light=["monster_knight", "monster_knight", "monster_wizard"], strong=["monster_demon1"], heavy_light=["monster_demon1", "monster_hell_knight"], heavy_strong=["monster_shambler"], heavy_scale=0.4);

"""The start: a reflecting pool, twin stairs up to a balcony, a target shot
to burst a fiend's door, the healing pool under the water."""
node HateAntechamber(Prefab) {
    has balcony: int = 6,
        tall: int = 16,
        twin: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hate antechamber";
        self.twin = dice.chance(0.5);
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(23, 25);
        self.balcony = dice.between(6, 7);
        self.tall = self.balcony + 15;
        self.low = -7;
        self.high = self.tall + 1;
        side = self.wide - 4;
        middle = float(side // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=0, along=float(side - 3), floor=self.balcony), Port(face=3, along=8.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        side = self.wide - 4;
        middle = side // 2;
        b = self.balcony;
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, b);
        bx = long - 5;
        build.solid(bx, 1, b - 1, long - 1, side, b);
        stair(build, bx - b, 1, 0, 0, b, 3);
        if self.twin {
            stair(build, bx - b, side - 3, 0, 0, b, 3);
        } else {
            lift(build, bx - 3, side - 3, bx, side, 0, b);
            keep_run(build, hall, bx - 4, side - 4, bx, side, 0);
        }
        keep_run(build, hall, bx, 1, bx + 1, 4, b);
        keep_run(build, hall, bx, side - 3, bx + 1, side, b);
        keep_run(build, hall, bx, middle - 1, bx + 1, middle + 2, b);
        # The reflecting pool, and under its water at the far end the
        # healing pool, an alcove (a secret).
        build.pool(7, middle - 3, -5, bx - 3, middle + 3, 0, 2);
        hx = bx - 5;
        build.room(hx, middle + 3, -5, hx + 2, middle + 5, -2);
        for z in range(-5, -2) {
            for y in range(middle + 3, middle + 5) {
                for x in range(hx, hx + 2) {
                    build.liquid(x, y, z, 2);
                }
            }
        }
        found = build.secret(float(hx), float(middle + 3), -5.0, float(hx + 2), float(middle + 5), -2.0);
        found.items[0]["message"] = "You have found a healing pool!";
        build.put_at({"classname": "item_health", "spawnflags": "2", "asset_game": "q1"}, float(hx) + 1.0, float(middle) + 4.0, -5);
        # The target over the balcony: shot, it bursts open the door in the
        # north wall on what waits there.
        shot = build.cue([build.button(float(long - 1), float(middle) + 0.5, float(b) + 4.0, 2, "", True)], "button");
        burst = relayed(build, shot, 0.3);
        loose = build.waiting();
        burst +>:Fires:+> loose;
        for at in [6, 11] {
            build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(hall, at, side, 0, at + 3, side + 1, 6);
            burst +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, "monster_demon1" if at == 6 and self.danger > 0.2 else "monster_knight", 270.0, waits=loose);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        # Knights walk the floor either side of the pool and the balcony.
        rounds(build, "monster_knight", 6.5, 5.5, float(bx) - 3.5, 5.5, 0);
        rounds(build, "monster_knight", float(bx) - 3.5, float(side) - 4.5, 6.5, float(side) - 4.5, 0);
        rounds(build, E4M4_FOES.pick(dice, self.danger), float(long) - 2.5, 2.5, float(long) - 2.5, float(side) - 2.5, b);
        build.supply(float(long) - 2.5, 2.5, b, "item_health");
    }
}

"""A long gallery, deep water across its middle, swum or crossed on a raft,
a walkway along one wall over the water."""
node FishGallery(Prefab) {
    has deep: int = 8,
        tall: int = 15,
        walk: int = 7,
        raft: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fish gallery";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(30, 32);
        self.wide = dice.between(14, 16);
        self.deep = dice.between(7, 9);
        self.walk = dice.between(7, 8);
        self.tall = self.walk + dice.between(11, 13);
        self.raft = dice.chance(0.6);
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 1.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 1.0, floor=0), Port(face=3, along=float(self.long - 3), floor=0), Port(face=0, along=float(self.wide - 3), floor=self.walk)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        d = self.deep;
        u = self.walk;
        gallery = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(gallery, u);
        x0 = 9;
        x1 = long - 9;
        build.pool(x0, 1, -d, x1, wide - 1, 0, 2);
        stair(build, x1 - d, 1, -d, 0, d, 2);
        # The raft riding from shore to shore across the water.
        ty = middle - 2;
        build.train([3.0, 3.0, 1.0], [[float(x0), float(ty), -1.0], [float(x1 - 3), float(ty), -1.0]], 90.0, 2.0);
        if not self.raft {
            # Stepping stones across beside the raft's way, two cells of
            # water between each.
            for x in range(x0 + 1, x1 - 1, 3) {
                build.solid(x, ty + 4, -d, x + 1, ty + 6, 0);
            }
            keep_run(build, gallery, x0 - 1, ty + 4, x0, ty + 6, 0);
            keep_run(build, gallery, x1, ty + 4, x1 + 1, ty + 6, 0);
        }
        keep_run(build, gallery, x0 - 1, ty - 1, x0, ty + 4, 0);
        keep_run(build, gallery, x1, ty - 1, x1 + 1, ty + 4, 0);
        # The walkway along the north wall over the water, a lift up to it
        # on the near shore, drops into the water.
        wy = wide - 4;
        build.solid(3, wy, u - 1, long - 1, wide - 1, u);
        lift(build, 3, wy - 3, 6, wy, 0, u);
        keep_run(build, gallery, 3, wy, 7, wy + 1, u);
        keep_run(build, gallery, 2, wy - 4, 7, wy, 0);
        keep_run(build, gallery, x0 + 3, wy, x0 + 7, wy + 1, u);
        pillars(build, 3, 2, x0 - 1, wy - 4, 0, u - 1, 3, [[0, middle - 4, x0, middle + 3], [2, wy - 5, 8, wy]]);
        build.doorway(gallery, self.enter);
        for port in self.taken {
            build.doorway(gallery, port);
        }
        # Boarding the raft teleports a foe in on the far shore.
        aboard = build.touch(float(x0), float(ty), -1.0, float(x0 + 3), float(ty + 3), 5.0);
        aboard +>:Fires:+> build.summon(1, 1, -d - 2, E4M4_FOES.pick(dice, self.danger), float(x1) + 3.5, float(middle) + 0.5, 0, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 2 + index * 3) + 0.5, float(middle) + 0.5, -d + 1, "monster_fish", 0.0, patrol=[[float(x0 + 2 + index * 3) + 0.5, 2.5], [float(x0 + 2 + index * 3) + 0.5, float(wide) - 2.5]]);
        }
        rounds(build, "monster_knight", 4.5, float(wide) - 2.5, float(long) - 3.5, float(wide) - 2.5, u);
        rounds(build, E4M4_FOES.pick(dice, self.danger), float(x1) + 3.5, 2.5, float(x1) + 3.5, float(wy) - 1.5, 0);
        build.foe(float(long) - 2.5, float(middle) - 1.5, 0, E4M4_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(long) - 2.5, 2.5, 0, "item_health");
        build.supply(float(long) - 2.5, float(wide) - 2.5, u, "item_spikes");
    }
}

"""A throne on a dais at a hall's head, galleries along its sides ridden up
to by lifts, fiends teleported in as the dais is climbed."""
node HateThrone(Prefab) {
    has dais: int = 5,
        gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hate throne";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.dais = dice.between(5, 6);
        self.gallery = dice.between(8, 9);
        self.tall = self.gallery + dice.between(15, 17);
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.dais),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, self.dais);
        build.level(hall, g);
        dx = long - 8;
        build.solid(dx, 6, 0, long - 1, wide - 6, self.dais);
        stair(build, dx - self.dais, middle - 3, 0, 0, self.dais, 6);
        keep_run(build, hall, dx, middle - 3, dx + 1, middle + 3, self.dais);
        build.solid(long - 3, middle - 5, self.dais, long - 2, middle - 3, self.dais + 4);
        under = g - 1;
        build.solid(10, 1, under, long - 1, 5, g);
        build.solid(10, wide - 5, under, long - 1, wide - 1, g);
        lift(build, 7, 1, 10, 4, 0, g);
        lift(build, 7, wide - 4, 10, wide - 1, 0, g);
        keep_run(build, hall, 10, 1, 11, 4, g);
        keep_run(build, hall, 10, wide - 4, 11, wide - 1, g);
        keep_run(build, hall, 15, 4, 19, 5, g);
        # A closet in the dais's flank behind a wall that opens when shot.
        build.room(dx + 1, 7, 0, dx + 4, 10, 4);
        build.secret_door(float(dx), 7.0, 0.0, float(dx + 1), 10.0, 4.0, 0);
        build.secret(float(dx + 1), 7.0, 0.0, float(dx + 4), 10.0, 3.0);
        build.supply(float(dx) + 2.5, 8.5, 0, "item_artifact_super_damage" if dice.chance(0.4) else "item_armor2");
        # A button on the dais sinks the doors of the alcoves under the
        # galleries, one after the other.
        press = build.push(float(long - 1), float(middle) + 2.5, float(self.dais) + 1.2, 2);
        for (index, south) in enumerate([True, False]) {
            y0 = 1 if south else wide - 6;
            y1 = 6 if south else wide - 1;
            build.solid(12, y0, 0, 18, y1, under);
            build.room(13, y0, 0, 17, y1, 5);
            door_y = 5 if south else wide - 6;
            relayed(build, press, 0.5 + float(index) * 2.0) +>:Fires:+> build.sinking(13.0, float(door_y), 17.0, float(door_y + 1), 5, 5);
            build.supply(15.0, float(y0 + y1) * 0.5, 0, "item_health" if south else "item_rockets");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Climbing to the dais teleports fiends in behind.
        climb = build.touch(float(dx - self.dais), float(middle - 3), 0.0, float(dx), float(middle + 3), 6.0);
        climb +>:Fires:+> build.summon(1, 1, -8, E4M4_FOES.pick(dice, self.danger, True), 5.5, float(middle) - 3.5, 0, 0.0);
        climb +>:Fires:+> build.summon(1, wide - 5, -8, "monster_demon1" if self.danger > 0.3 else "monster_knight", 5.5, float(middle) + 3.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            y = float(middle) + (3.5 if index % 2 == 0 else -3.5);
            rounds(build, E4M4_FOES.pick(dice, self.danger), float(8 + index * 4) + 0.5, y, float(dx) - 7.5, y, 0);
        }
        guard = build.waiting();
        climb +>:Fires:+> guard;
        build.foe(float(long) - 5.5, float(middle) + 0.5, self.dais, E4M4_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        rounds(build, "monster_knight", 11.5, 3.0, float(long) - 3.5, 3.0, g);
        rounds(build, E4M4_FOES.pick(dice, self.danger), float(long) - 3.5, float(wide) - 3.0, 11.5, float(wide) - 3.0, g);
        build.supply(float(long) - 2.5, 7.5, self.dais, "item_health");
        build.supply(3.5, float(wide) - 6.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""A long hall of alcoves behind slow doors a button lowers one after
another, a gallery over its far end."""
node SinkingAlcoves(Prefab) {
    has gallery: int = 8,
        tall: int = 17,
        pairs: int = 3;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sinking alcoves";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.pairs = dice.between(2, 3);
        self.long = 12 + self.pairs * 5 + dice.between(9, 11);
        self.wide = dice.between(17, 19);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(13, 15);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery), Port(face=1, along=float(self.long - 4), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        g = self.gallery;
        hall = build.room(1, 5, 0, long - 1, wide - 5, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The alcoves in pairs down both walls, each behind a slow door the
        # button at the hall's head lowers, one pair after another.
        press = build.push(4.5, float(wide - 5), 1.5, 3);
        build.touch(1.0, 5.0, 0.0, 4.0, float(wide - 5), 6.0, True, "A button lowers the doors");
        for index in range(self.pairs) {
            ax = 8 + index * 5;
            later = relayed(build, press, 1.0 + float(index) * 2.5);
            behind = build.waiting();
            later +>:Fires:+> behind;
            for south in [True, False] {
                y0 = 1 if south else wide - 5;
                door_y = 4 if south else wide - 5;
                build.room(ax, y0, 0, ax + 3, y0 + 4, 6);
                later +>:Fires:+> build.sinking(float(ax), float(door_y), float(ax + 3), float(door_y + 1), 6, 6);
                if (index + (1 if south else 0)) % 2 == 0 {
                    build.foe(float(ax) + 1.5, float(y0) + 1.5, 0, "monster_knight" if index < 2 else E4M4_FOES.pick(dice, self.danger), 90.0 if south else 270.0, waits=behind);
                } else {
                    build.supply(float(ax) + 1.5, float(y0) + 1.5, 0, "item_health" if south else "item_shells");
                }
            }
        }
        # The gallery over the far end, a stair up along its edge.
        gx = long - 8;
        build.solid(gx, 5, g - 1, long - 1, wide - 5, g);
        stair(build, gx - g, 5, 0, 0, g, 3);
        keep_run(build, hall, gx, 5, gx + 1, 8, g);
        keep_run(build, hall, gx, middle - 1, gx + 1, middle + 2, g);
        # The north-east corner of the box over the gallery for the way on
        # on its north face.
        build.widen(hall, long - 7, wide - 5, g, long - 1, wide - 1, g + 9);
        build.solid(long - 7, wide - 5, g - 1, long - 1, wide - 1, g);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        up = build.touch(float(gx - 3), 5.0, float(g - 3), float(gx + 1), 8.0, float(g + 4));
        guard = build.waiting();
        up +>:Fires:+> guard;
        build.foe(float(long) - 3.5, float(middle) + 0.5, g, E4M4_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        rounds(build, E4M4_FOES.pick(dice, self.danger), 5.5, float(middle) + 0.5, float(gx) - 2.5, float(middle) + 0.5, 0);
        rounds(build, "monster_knight", float(long) - 3.5, 7.5, float(long) - 3.5, float(wide) - 6.5, g);
        build.supply(float(long) - 2.5, float(wide) - 7.5, g, "item_health");
    }
}

"""The key on a shelf high on a vault's far wall, a lift up to it; taking
it opens the closets and teleports a fiend in."""
node PalaceVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        shelf: int = 8,
        tall: int = 16,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.climb = dice.below(2);
        self.title = "Palace vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.shelf = dice.between(7, 9);
        self.tall = self.shelf + 13;
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        side = self.hall_wide - 1;
        cy = side // 2;
        vault = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, self.shelf);
        build.doorway(vault, self.enter);
        sx = long - 5;
        build.solid(sx, 1, self.shelf - 1, long - 1, side, self.shelf);
        if self.climb == 0 {
            lift(build, sx - 3, cy - 1, sx, cy + 2, 0, self.shelf);
            keep_run(build, vault, sx, cy - 2, sx + 1, cy + 3, self.shelf);
            keep_run(build, vault, sx - 4, cy - 2, sx, cy + 3, 0);
        } else {
            # A stair up the south wall to the shelf.
            stair(build, sx - self.shelf, 1, 0, 0, self.shelf, 3);
            keep_run(build, vault, sx, 1, sx + 1, 4, self.shelf);
        }
        fields: dict[str, str] = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(long) - 2.5, float(cy) + 0.5, self.shelf);
        taken = build.cue([fields], "key");
        for at in [2, sx - 6] {
            build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(vault, at, side, 0, at + 3, side + 1, 6);
            taken +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E4M4_FOES.pick(dice, self.danger, at == 2), 270.0);
        }
        taken +>:Fires:+> build.summon(1, 1, -8, "monster_demon1" if self.danger > 0.3 else "monster_knight", 3.5, float(cy) + 0.5, 0, 0.0);
        rounds(build, "monster_knight", float(long) - 2.5, 2.5, float(long) - 2.5, float(side) - 2.5, self.shelf);
        rounds(build, E4M4_FOES.pick(dice, self.danger), 3.5, 2.5, float(sx) - 5.5, 2.5, 0);
        build.foe(float(sx) - 4.5, float(cy) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a hall, the slipgate on a dais between braziers,
doors either side of the dais bursting open as it is approached."""
node PalaceExit(Prefab) {
    has key: str = "",
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M4;
        self.district = level_district(E4M4);
        self.long = dice.between(24, 26);
        self.wide = dice.between(19, 21);
        self.tall = dice.between(18, 21);
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide - 5) // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        side = self.wide - 5;
        middle = side // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, side, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        dais_x = long - 7;
        if dice.chance(0.5) {
            # A moat before the dais, a bridge over it.
            build.pool(dais_x - 8, 1, -4, dais_x - 4, side, 0, 2, False, True, True);
            build.solid(dais_x - 8, middle - 1, -1, dais_x - 4, middle + 2, 0);
        }
        build.solid(dais_x, middle - 4, 0, long - 1, middle + 4, 3);
        stair(build, dais_x - 3, middle - 2, 0, 0, 3, 4);
        for y in [middle - 4, middle + 3] {
            build.solid(dais_x - 2, y, 0, dais_x - 1, y + 1, 3);
        }
        build.way_out(float(long) - 3.5, float(middle), 3);
        build.touch(float(dais_x), float(middle - 2), 3.0, float(dais_x + 2), float(middle + 2), 9.0, False, "Are you sure you want to exit");
        # Approaching the dais bursts open the doors in the north wall.
        near = build.touch(float(dais_x - 5), 1.0, 0.0, float(dais_x - 3), float(side), 6.0);
        burst = relayed(build, near, 0.5);
        loose = build.waiting();
        burst +>:Fires:+> loose;
        for at in [dais_x - 9, dais_x - 4] {
            if at >= wall + 2 {
                build.room(at, side + 1, 0, at + 3, side + 4, 7);
                build.widen(room, at, side, 0, at + 3, side + 1, 6);
                burst +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
                build.foe(float(at) + 1.5, float(side) + 2.5, 0, E4M4_FOES.pick(dice, self.danger, at == dais_x - 4), 270.0, waits=loose);
            }
        }
        hall_in = build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0);
        hall_guard = build.waiting();
        hall_in +>:Fires:+> hall_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E4M4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=hall_guard);
        }
        rounds(build, "monster_knight", float(wall) + 2.5, 2.5, float(dais_x) - 3.5, 2.5, 0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m4's stretches: [name, role]."""
glob E4M4_STRETCHES: list[list[str]] = [
         ["antechamber", "start"],
         ["fish", "flow"],
         ["throne", "hub"],
         ["throne", "flow"],
         ["alcoves", "flow"],
         ["alcoves", "hub"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m4's stretches by its name."""
def make_e4m4(name: str, key: str) -> Prefab {
    if name == "antechamber" {
        return HateAntechamber();
    }
    if name == "fish" {
        return FishGallery();
    }
    if name == "throne" {
        return HateThrone();
    }
    if name == "alcoves" {
        return SinkingAlcoves();
    }
    if name == "vault" {
        return PalaceVault(key=key if key else "key_silver");
    }
    return PalaceExit(key=key);
}
