"""Prefabs drawn from Quake II's boss1, the Inner Chamber: the way into the
Makron's lair, a hall of turning gears whose two levers raise the great
lift, lava crossed on plinths a jump apart under energy fields, the
chamber round its lava pit and its updraft, the reliquary, and the
Makron's arena whose doors open to two levers. Raised in boss1's own
palette.

- `ChamberApproach`: the start. A hall of tall columns, a stair up to a
  gallery across its far end, lasers burning across between the columns
  for a while as the player comes in; "Destroy the Makron".
- `GearHall`: a hall of turning gears (platforms riding the walls), a
  lever on each balcony; both thrown, the counter raises the great lift's
  steps to the way on high and the flyers come out.
- `LavaPlinths`: a hall over lava crossed on plinths a jump apart (or by
  the walk round the wall), energy fields across the walk shut off by a
  lever at each end.
- `InnerChamber`: a chamber round a pit of lava, walled into rooms under its
  tiers, a tier up stairs on two sides, an updraft from the pit's ledge to the tier, a teleporter from
  the far tier back to the floor. A hub.
- `Reliquary`: the key on an island in a moat of lava beyond a low
  antechamber, the bridge drawn by the lever at the far end of the gallery
  over the moat; taking the key opens the closets.
- `MakronArena`: the end. A door (a key's, as a gate), the arena round
  the Makron's dais; the levers on its two sides open the doors to the
  way out, the flyers come down, the Makron's laughter rings."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, gate_into, lift }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, rounds, beamed, held_door, key_taken, closets, pad_to, hurting, laser_burst, barrels }
import from .city2 { random_sparks }
import from .q2d_parts { wall_x, step_ways }

glob BOSS1: str = "q2:boss1";

"""boss1's foes: iron maidens and flyers, gladiators deeper in."""
glob BOSS1_FOES: FoeMix = FoeMix(light=["monster_chick", "monster_flyer", "monster_flyer"], strong=["monster_gladiator"], heavy_light=["monster_chick", "monster_gladiator"], scale=0.5);

"""An energy field across a way: a box of the prefab's cells that hurts
whoever is in it (a trigger_hurt), switched off for good when `cue`
fires. Answers nothing; the field's cue is wired from `cue`."""
def energy_field(build: Raising, cue: Cue, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
    fields = {"classname": "trigger_hurt", "dmg": "5", "spawnflags": "2", "asset_game": "q2"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, "trigger");
    cue +>:Fires:+> build.cue([fields], "field");
}

"""The start: a hall of tall columns, a stair up to a gallery across its
far end."""
node ChamberApproach(Prefab) {
    has gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chamber approach";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.gallery = dice.between(11, 12);
        self.tall = self.gallery + 10;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.gallery),
            Port(face=1, along=float(self.long - 4), floor=self.gallery),
            Port(face=0, along=3.5, floor=0),
            Port(face=3, along=8.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        gx = self.long - 7;
        deck(build, gx, 1, self.long - 1, self.wide - 1, g);
        deck(build, 12, self.wide - 4, gx, self.wide - 1, g);
        stair(build, gx - g, middle - 2, 0, 0, g, 4);
        keep_box(build, hall, gx, middle - 2, gx + 1, middle + 2, g);
        clear = [[0, middle - 3, 5, middle + 3], [6, 0, 11, 4], [6, self.wide - 4, 11, self.wide], [gx - g - 1, middle - 3, gx, middle + 3]];
        pillars(build, 4, 4, gx - 1, self.wide - 4, 0, self.tall, 4, clear);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0);
        come_in +>:Fires:+> build.objective("Destroy the Makron");
        # Lasers burn across between the columns for a while as the player
        # comes in; the gallery's guards come forward as the stair is climbed.
        laser_burst(build, come_in, 8.5, 1.1, 1.5, 1, 6.0);
        laser_burst(build, come_in, 16.5, float(self.wide) - 1.1, 1.5, 3, 8.0);
        climb = build.touch(float(gx - g), float(middle - 2), 2.0, float(gx - g + 3), float(middle + 2), 8.0);
        squad(build, climb, [[float(self.long) - 3.0, 3.0, float(g)], [float(self.long) - 3.0, float(self.wide) - 3.0, float(g)], [15.5, float(self.wide) - 2.5, float(g)]], [BOSS1_FOES.pick(dice, self.danger, True), "monster_chick", "monster_flyer"], 180.0);
        beamed(build, climb, 2, 2, -8, BOSS1_FOES.pick(dice, self.danger), float(gx) - 3.0, 3.0, 0, 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(gx) - 3.5, 3.0 + float(index) * 5.0, 6, "monster_flyer", 180.0);
        }
        rounds(build, "monster_chick", [[6.5, float(middle) + 4.0], [float(gx) - 3.5, float(middle) + 4.0]], 0);
        stash(build, 4, self.wide - 6, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.sparks(6.0, float(self.wide) - 6.2, 3.0, 3);
        for (index, ty) in enumerate([2, self.wide - 4]) {
            build.train([2.0, 2.0, 1.0], [[6.0, float(ty), float(g + 4)], [float(gx) - 4.0, float(ty), float(g + 4)]], 50.0 + 20.0 * float(index), 2.0);
        }
        barrels(build, dice, 5, 1, gx - g - 1, self.wide - 1, 0, 2, clear + [[3, self.wide - 7, 9, self.wide]]);
        random_sparks(build, [[float(self.long) - 1.2, float(middle) - 3.0, float(g) + 3.0, 2.0], [1.2, 3.0, 4.0, 0.0], [1.2, float(self.wide) - 3.0, 6.0, 0.0]], 3.5);
        build.supply(float(self.long) - 2.5, 2.5, g, Q2_HEALTH, "q2");
    }
}

"""A hall of turning gears, a lever on each balcony; both thrown, the
great lift's steps rise to the way on high."""
node GearHall(Prefab) {
    has bal: int = 8,
        top: int = 14,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Gear hall";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.bal = 9;
        self.top = dice.between(15, 17);
        self.tall = self.top + dice.between(16, 20);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=self.top),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2 + 3), floor=self.bal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        b = self.bal;
        t = self.top;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, b);
        build.level(hall, t);
        # The balconies along both side walls, a stair up to each.
        deck(build, 4 + b, 1, self.long - 5, 5, b);
        deck(build, 4 + b, self.wide - 5, self.long - 5, self.wide - 1, b);
        stair(build, 4, 1, 0, 0, b, 3);
        stair(build, 4, self.wide - 4, 0, 0, b, 3);
        keep_box(build, hall, 4 + b, 1, 5 + b, 4, b);
        keep_box(build, hall, 4 + b, self.wide - 4, 5 + b, self.wide - 1, b);
        # The great lift's landing at the far end, high; its steps rise from
        # the floor once both levers are thrown.
        build.solid(self.long - 5, 1, 0, self.long - 1, self.wide - 1, t);
        count = build.tally(2, "The great lift is rising");
        build.push(float(self.long - 5), 3.0, float(b) + 1.5, 2) +>:Fires:+> count;
        build.push(float(self.long - 5), float(self.wide) - 3.0, float(b) + 1.5, 2) +>:Fires:+> count;
        steps = build.rising_steps(self.long - 5 - t, middle - 2, 0, 0, t, 4);
        count +>:Fires:+> steps;
        keep_box(build, hall, self.long - 5, middle - 2, self.long - 4, middle + 2, t);
        build.touch(float(self.long - 7 - t), float(middle - 2), 0.0, float(self.long - 5 - t), float(middle + 2), 6.0, True, "Two levers raise the great lift");
        # The gears: platforms riding up and down the side walls.
        for (index, gy) in enumerate([6, self.wide - 9]) {
            build.train([3.0, 3.0, 1.0], [[float(4 + b + 3 + index * 4), float(gy), 1.0], [float(4 + b + 3 + index * 4), float(gy), float(t - 3)]], 40.0 + 15.0 * float(index), 1.5);
        }
        # Both levers thrown: the flyers come out, charges go off.
        squad(build, count, [[float(self.long // 2), float(middle), float(t)], [float(self.long // 2) + 4.0, float(middle) - 4.0, float(t)], [float(self.long // 2) - 4.0, float(middle) + 4.0, float(t)]], ["monster_flyer"], 180.0);
        blast_chain(build, count, [[float(self.long) - 6.0, float(middle) - 5.0, 2.0], [float(self.long) - 6.0, float(middle) + 5.0, 2.0]], 0.3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        up = build.touch(float(4 + b), 1.0, float(b), float(6 + b), 5.0, float(b + 6));
        squad(build, up, [[float(self.long) - 8.0, float(self.wide) - 3.0, float(b)]], [BOSS1_FOES.pick(dice, self.danger, True)], 180.0);
        beamed(build, up, 2, 2, -8, BOSS1_FOES.pick(dice, self.danger), float(self.long // 2), float(middle) + 0.5, 0, 0.0);
        rounds(build, "monster_chick", [[8.5, float(middle)], [float(self.long) - 9.5, float(middle)]], 0);
        for at in [[5, middle - 5], [5, middle + 3]] {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 2), float(at[1] + 2), 2.0, 10);
        }
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, t, BOSS1_FOES.pick(dice, self.danger, True), 180.0);
        random_sparks(build, [[1.2, float(middle) + 4.0, 3.0, 0.0], [float(self.long) - 5.2, float(middle) + 3.0, float(t) - 3.0, 2.0], [float(self.long) - 5.2, float(middle) - 3.0, 4.0, 2.0]], 3.0);
        build.supply(2.5, float(middle) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.0, t, "ammo_cells", "q2");
    }
}

"""A hall over lava crossed on plinths a jump apart, the walk round the
wall under energy fields shut off by a lever at each end."""
node LavaPlinths(Prefab) {
    has hops: int = 4,
        walk_side: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava plinths";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.hops = dice.between(3, 5);
        self.long = 3 * self.hops + 13;
        self.wide = dice.between(16, 18);
        self.tall = dice.between(30, 34);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        far = 3 * self.hops + 6;
        build.pool(5, 4, -3, far, self.wide - 1, 0, 4, False, False);
        for hop in range(self.hops) {
            x = 6 + hop * 3;
            build.solid(x, middle - 1, -3, x + 2, middle + 2, 0);
        }
        # The energy fields across the walk round the wall, each shut off by
        # the lever at its end of the hall.
        near_lever = build.push(1.0, 2.5, 1.5, 0);
        far_lever = build.push(float(self.long - 1), 2.5, 1.5, 2);
        energy_field(build, near_lever, 9.0, 1.0, 0.0, 10.0, 4.0, 5.0);
        energy_field(build, far_lever, float(far - 4), 1.0, 0.0, float(far - 3), 4.0, 5.0);
        near_lever +>:Fires:+> build.sparks(9.5, 1.2, 4.0, 1);
        far_lever +>:Fires:+> build.sparks(float(far) - 3.5, 1.2, 4.0, 1);
        build.touch(1.0, 4.0, 0.0, 4.0, float(self.wide - 1), 6.0, True, "Energy fields guard the walk; the plinths are a jump apart");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Flyers come over the lava as the player reaches the plinths.
        on_plinths = build.touch(6.0, float(middle - 1), 0.0, 8.0, float(middle + 2), 6.0);
        squad(build, on_plinths, [[float(far) - 2.0, float(middle) + 4.0, 5.0], [float(far) - 6.0, float(middle) - 2.0, 6.0]], ["monster_flyer"], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 4) + 0.5, float(middle) + 3.5, 5, BOSS1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(far) + 3.0, float(middle) + 0.5, 0, BOSS1_FOES.pick(dice, self.danger, True), 180.0);
        random_sparks(build, [[float(self.long) - 1.2, float(middle), 3.0, 2.0], [1.2, float(self.wide) - 3.0, 3.0, 0.0]], 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(far) + 3.0, 2.5, 0, "ammo_cells", "q2");
    }
}

"""A chamber round a pit of lava, a tier up stairs on two sides, an updraft
from the pit's ledge to the tier."""
node InnerChamber(Prefab) {
    has tier: int = 7,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Inner chamber";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tier = 9;
        self.tall = self.tier + dice.between(16, 19);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=1);
        self.leaves = [
            Port(face=0, along=middle, floor=1),
            Port(face=1, along=float(self.long - 6), floor=self.tier),
            Port(face=3, along=float(self.long - 6), floor=self.tier),
            Port(face=1, along=float(self.long // 2), floor=1)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        t = self.tier;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, t);
        # The pit of lava in the middle, a ledge round it.
        build.pool(cx - 4, cy - 4, -4, cx + 4, cy + 4, 0, 4, False, False);
        # The tiers along both side walls over the floor, stairs up at the
        # near end.
        deck(build, 4 + t, 1, self.long - 1, 6, t);
        deck(build, 4 + t, self.wide - 6, self.long - 1, self.wide - 1, t);
        stair(build, 4, 1, 0, 0, t, 3);
        stair(build, 4, self.wide - 4, 0, 0, t, 3);
        keep_box(build, hall, 4 + t, 1, 5 + t, 4, t);
        keep_box(build, hall, 4 + t, self.wide - 4, 5 + t, self.wide - 1, t);
        # The updraft from the floor by the pit up to the near tier, and the
        # teleporter from the far end of the far tier back to the floor.
        pad_to(build, float(cx) + 0.5, 8.5, 0, float(cx) + 0.5, 3.5, t);
        keep_box(build, hall, cx - 1, 5, cx + 2, 6, t);
        build.teleporter(float(self.long) - 3.0, float(self.wide) - 3.0, t, 3.0, float(cy) + 0.5, 0, 0.0);
        # Walls under the tiers cut the floor in three: arches on sills on
        # either side of the pit, the far rooms beyond a wall of their own.
        wall_x(build, hall, cx - 3, 1, cy - 4, 0, t - 1, [[cy - 9, cy - 5]]);
        wall_x(build, hall, cx - 3, cy + 4, self.wide - 1, 0, t - 1, [[cy + 5, cy + 9]]);
        wall_x(build, hall, self.long - 6, 1, self.wide - 1, 0, t - 1, [[cy - 3, cy + 3], [self.wide - 5, self.wide - 2]]);
        step_ways(build, self);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The chamber's guards come out on the tiers as the player comes in.
        come_in = build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0);
        squad(build, come_in, [[float(self.long) - 4.0, 3.5, float(t)], [float(self.long) - 4.0, float(self.wide) - 3.5, float(t)], [float(cx) + 7.0, float(cy) + 0.5, 0.0]], [BOSS1_FOES.pick(dice, self.danger, True), "monster_chick", "monster_gladiator" if self.danger > 0.5 else "monster_chick"], 180.0);
        beamed(build, come_in, 2, 2, -8, BOSS1_FOES.pick(dice, self.danger), float(cx) - 7.0, float(cy) + 0.5, 0, 0.0);
        rounds(build, "monster_chick", [[float(cx) - 7.0, float(cy) - 7.0], [float(cx) + 7.0, float(cy) - 7.0], [float(cx) + 7.0, float(cy) + 7.0], [float(cx) - 7.0, float(cy) + 7.0]], 0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 8, "monster_flyer", 0.0);
        hidden_closet(build, self.long - 6, cy + 4, 0, 2, Q2_ARMOR, 6);
        for at in [[cx - 8, cy - 2], [cx + 6, cy - 2]] {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 2), float(at[1] + 2), 2.0, 10);
        }
        build.train([2.0, 2.0, 1.0], [[float(4 + t), float(self.wide) - 4.0, float(t + 5)], [float(self.long) - 4.0, float(self.wide) - 4.0, float(t + 5)]], 45.0, 2.0);
        random_sparks(build, [[1.2, float(cy) + 6.0, 3.0, 0.0], [float(self.long) - 1.2, 8.0, float(t) + 3.0, 2.0], [float(cx) + 0.5, float(cy) - 4.2, -1.0, 3.0]], 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, 3.5, t, "ammo_rockets", "q2");
    }
}

"""The key on an island in a moat of lava in the reliquary, a low
antechamber before it; the bridge is drawn from the lever at the far end of
the gallery over the moat; taking the key opens the closets."""
node Reliquary(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reliquary (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(26, 29);
        self.hall_wide = dice.between(21, 23);
        self.wide = self.hall_wide + 4;
        self.tall = 17;
        self.low = -9;
        self.high = 18;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        wall = 7;
        ante = build.room(1, 1, 0, wall, side, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, 10);
        build.doorway(ante, self.enter);
        build.widen(room, wall, cy - 2, 1, wall + 1, cy + 2, 9);
        # The moat round the island, three cells wide, a lane along each
        # side wall, the bridge drawn out from the near floor to the island.
        ix0 = self.long - 10;
        ix1 = self.long - 4;
        iy0 = cy - 3;
        iy1 = cy + 3;
        build.pool(ix0 - 3, iy0 - 3, -3, self.long - 1, iy1 + 3, 0, 4, False, False);
        build.solid(ix0, iy0, -3, ix1, iy1, 0);
        build.solid(ix1 - 4, cy - 1, 0, ix1 - 1, cy + 2, 1);
        bridge = build.drawn(float(ix0 - 3), float(cy - 1), float(ix0), float(cy + 2), 0, 4);
        keep_box(build, room, ix0 - 4, cy - 1, ix0 - 3, cy + 2, 0);
        keep_box(build, room, ix0, cy - 1, ix0 + 1, cy + 2, 0);
        # The gallery along the high wall over the lane, up a lift from the
        # near floor, the bridge's lever at its far end.
        deck(build, wall + 1, side - 4, self.long - 1, side, 10);
        lift(build, wall + 1, side - 7, wall + 4, side - 4, 0, 10);
        keep_box(build, room, wall + 1, side - 5, wall + 4, side - 4, 10);
        lever = build.push(float(self.long - 1), float(side) - 2.0, 11.5, 2);
        lever +>:Fires:+> bridge;
        lever +>:Fires:+> build.sparks(float(ix0) - 1.5, float(cy) + 0.5, 1.0, 0);
        build.touch(float(wall + 1), float(cy - 3), 0.0, float(wall + 3), float(cy + 3), 6.0, True, "The bridge is drawn from the far end of the gallery");
        taken = key_taken(build, self.key, float(ix1 - 3) + 0.5, float(cy) + 0.5, 1);
        closets(build, taken, side, 0, [wall + 5, self.long - 9], [BOSS1_FOES.pick(dice, self.danger, True), BOSS1_FOES.pick(dice, self.danger)]);
        squad(build, taken, [[float(wall) + 6.5, float(side) - 2.0, 10.0], [float(self.long) - 4.5, float(side) - 2.0, 10.0]], ["monster_chick", "monster_flyer"], 180.0);
        beamed(build, taken, 2, 2, -8, BOSS1_FOES.pick(dice, self.danger, True), float(wall) + 3.5, float(cy) + 0.5, 0, 0.0);
        build.foe(float(ix0) + 1.5, float(iy1) - 1.5, 0, BOSS1_FOES.pick(dice, self.danger), 180.0);
        rounds(build, "monster_chick", [[float(wall) + 3.5, 2.5], [float(self.long) - 3.5, 2.5]], 0);
        build.breakable(2.0, float(side) - 4.0, 0.0, 4.0, float(side) - 2.0, 2.0, 10);
        random_sparks(build, [[float(self.long) - 1.2, float(cy) - 6.0, 3.0, 2.0], [1.2, float(cy), 3.0, 0.0]], 3.0);
        build.supply(float(wall) + 3.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into the arena round the Makron's dais; the levers on
its two sides open the doors to the way out."""
node MakronArena(Prefab) {
    has key: str = "",
        dais: int = 3,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Makron arena" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BOSS1;
        self.district = level_district(BOSS1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.dais = dice.between(2, 3);
        self.tall = 22;
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
        arena = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(arena, self.dais);
        build.level(arena, 10);
        # The Makron's dais in the arena's middle, two steps up.
        mx = (wall + 1 + self.long - 7) // 2;
        build.solid(mx - 4, middle - 4, 0, mx + 4, middle + 4, self.dais);
        build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0, True, "The Makron's arena");
        # Balconies along both side walls, a lever at the far end of each.
        deck(build, wall + 11, 1, self.long - 7, 5, 10);
        deck(build, wall + 11, self.wide - 5, self.long - 7, self.wide - 1, 10);
        stair(build, wall + 1, 1, 0, 0, 10, 3);
        stair(build, wall + 1, self.wide - 4, 0, 0, 10, 3);
        keep_box(build, arena, wall + 11, 1, wall + 12, 4, 10);
        keep_box(build, arena, wall + 11, self.wide - 4, wall + 12, self.wide - 1, 10);
        count = build.tally(2, "The Makron's doors open");
        build.push(float(self.long - 7), 3.0, 11.5, 2) +>:Fires:+> count;
        build.push(float(self.long - 7), float(self.wide) - 3.0, 11.5, 2) +>:Fires:+> count;
        for (index, ty) in enumerate([2, self.wide - 4]) {
            build.train([2.0, 2.0, 1.0], [[float(wall + 12), float(ty), 15.0], [float(self.long) - 10.0, float(ty), 15.0]], 40.0 + 20.0 * float(index), 1.5);
        }
        for at in [[wall + 4, middle - 6], [wall + 4, middle + 4]] {
            build.breakable(float(at[0]), float(at[1]), 0.0, float(at[0] + 2), float(at[1] + 2), 2.0, 10);
        }
        # The way out beyond the far wall's doors.
        build.solid(self.long - 7, 1, 0, self.long - 6, self.wide - 1, self.tall);
        out = build.room(self.long - 6, middle - 4, 0, self.long - 1, middle + 4, 9);
        build.widen(out, self.long - 7, middle - 2, 0, self.long - 6, middle + 2, 8);
        count +>:Fires:+> build.opened(float(self.long - 7), float(middle - 2), 0.0, float(self.long - 6), float(middle + 2), 8.0);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        # The Makron (late in a run; his gladiators else) on the dais, the
        # flyers coming down at each lever, his laughter.
        boss = "monster_jorg" if self.danger > 0.85 else ("monster_gladiator" if self.danger > 0.4 else "monster_chick");
        build.foe(float(mx) + 0.5, float(middle) + 0.5, self.dais, boss, 180.0);
        squad(build, count, [[float(mx), 4.0, 10.0], [float(mx), float(self.wide) - 4.0, 10.0], [float(mx) + 4.0, float(middle), 12.0]], ["monster_flyer"], 180.0);
        laugh = build.timer(14.0);
        laugh +>:Fires:+> build.sparks(float(mx) + 0.5, float(middle) + 0.5, float(self.dais) + 6.0, 0);
        blast_chain(build, count, [[float(mx) - 5.0, float(middle) - 5.0, 1.0], [float(mx) + 5.0, float(middle) + 5.0, 1.0], [float(self.long) - 8.0, float(middle), 2.0]], 0.3);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, BOSS1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        rounds(build, "monster_chick", [[float(wall) + 13.0, 3.0], [float(self.long) - 9.0, 3.0]], 10);
        random_sparks(build, [[float(self.long) - 7.2, float(middle) - 4.0, 3.0, 2.0], [float(self.long) - 7.2, float(middle) + 4.0, 3.0, 2.0]], 2.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""boss1's stretches: [name, role]."""
glob BOSS1_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["gears", "flow"],
         ["plinths", "flow"],
         ["chamber", "hub"],
         ["chamber", "flow"],
         ["reliquary", "keyroom"],
         ["arena", "end"],
         ["arena", "gate"]
     ];

"""One of boss1's stretches by its name."""
def make_boss1(name: str, key: str) -> Prefab {
    if name == "approach" {
        return ChamberApproach();
    }
    if name == "gears" {
        return GearHall();
    }
    if name == "plinths" {
        return LavaPlinths();
    }
    if name == "chamber" {
        return InnerChamber();
    }
    if name == "reliquary" {
        return Reliquary(key=key if key else "key_silver");
    }
    return MakronArena(key=key);
}
