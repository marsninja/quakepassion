"""Prefabs drawn from Quake II's power1, the Power Plant: a yard under the
sky before the plant's face with a pipe gantry high over it, a turbine hall
with catwalks over its machines, a fan shaft between two ledges, the
reactor hall round its core over a pit, the red key's vault far down a
lift, a switchyard to leave by. Raised in power1's own palette.

- `PlantGate`: the start. A rock shelf the run begins on over a yard, the
  plant's porch across its far end, a gantry high along one wall reached
  by a stair or a lift, sometimes a pipe bridge across the yard from it.
  The help computer gives the mission (power1's two objectives); charges
  go off now and then far over the yard; guards appear on the porch as the
  player crosses; crates that break, and a stash in a rock outcrop behind
  a panel that breaks when shot.
- `TurbineHall`: turbines in a row down a hall (in a trench, or on its
  floor), a catwalk along one wall or both, bridges between them over the
  turbines. Halfway along, panels burst, iron maidens appear and the crane
  starts along the roof (power1's relay chain to its train); guards appear
  on the catwalk as the player climbs.
- `FanShaft`: a shaft between two ledges joined by a walk along its wall,
  the floor far below; up by an updraft (power1's wind), a stair or a
  freight train, and a lift; entered at the top or the bottom. Flyers come
  in as the player reaches the bottom; a vent panel hides a stash.
- `ReactorHall`: a hub. The reactor core standing in a pit, a gallery
  round the hall's walls, bridges from it to the core's top, a lift and a
  stair out of the pit. The objective moves on; the core's charges pulse;
  flyers appear over the pit as the player reaches the gallery; a stash in
  the core's foot.
- `KeyVault`: the key room. A gallery over a deep vault, a lift (and
  sometimes a stair along the wall) down, the key on a dais at the bottom
  guarded by a tank; taking it opens the closets; charges go off.
- `Switchyard`: the end. A hall, a door (a key's, as a gate), a yard of
  transformers under the sky; the way out on a tower, or behind a barrier
  that sinks when a button is shot."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, shelling, stash, crate_pile, squad, keep_box, plat }

glob POWER1: str = "q2:power1";

"""power1's foes: berserkers and iron maidens, flyers and hovers, gladiators
deeper in."""
glob POWER1_FOES: FoeMix = FoeMix(light=["monster_berserk", "monster_chick", "monster_soldier"], strong=["monster_chick"], heavy_light=["monster_berserk", "monster_chick"], heavy_strong=["monster_gladiator"], scale=0.7, heavy_scale=0.5, flying="monster_flyer", flying_other="monster_hover", flying_odds=0.4);

"""The start: a shelf over a yard, the plant's porch across its end, a
gantry high along one wall."""
node PlantGate(Prefab) {
    has porch: int = 3,
        gantry: int = 10,
        tall: int = 24,
        climb_lift: bool = False,
        porch_side: bool = False,
        crossing: bool = True,
        cross_x: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Plant gate";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(22, 26);
        self.porch = dice.between(3, 4);
        self.gantry = self.porch + dice.between(6, 7);
        self.tall = self.gantry + dice.between(10, 12);
        self.climb_lift = dice.chance(0.4);
        self.porch_side = dice.chance(0.5);
        self.crossing = dice.chance(0.6);
        self.cross_x = dice.between(self.long - 14, self.long - 11);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.porch), Port(face=0, along=3.0, floor=self.gantry), Port(face=1, along=float(self.long // 2 + 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.porch);
        build.level(yard, self.gantry);
        # The shelf the run begins on, three lifts up, a stair down.
        build.solid(1, 6, 0, 6, self.wide - 1, 3);
        stair(build, 8, cy - 1, 0, 2, 3, 3);
        # The plant's porch across the far end, its steps in the middle or
        # to one side.
        px = self.long - 7;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.porch);
        steps_y = self.wide - 9 if self.porch_side else cy - 2;
        stair(build, px - self.porch, steps_y, 0, 0, self.porch, 4);
        keep_box(build, yard, px, steps_y, px + 1, steps_y + 4, self.porch);
        # The gantry along the low wall, a stair or a lift up to it.
        start_x = 7 + self.gantry;
        if self.climb_lift {
            start_x = 10;
            plat(build, yard, 7, 1, 10, 4, 0, self.gantry);
        } else {
            stair(build, 7, 1, 0, 0, self.gantry, 4);
        }
        build.solid(start_x, 1, self.gantry - 1, self.long - 1, 5, self.gantry);
        # A pipe bridge across the yard from the gantry to a perch on the
        # far wall.
        if self.crossing {
            build.solid(self.cross_x, 5, self.gantry - 1, self.cross_x + 3, self.wide - 1, self.gantry);
            build.solid(self.cross_x - 1, self.wide - 4, self.gantry - 1, self.cross_x + 4, self.wide - 1, self.gantry);
            build.supply(float(self.cross_x) + 1.5, float(self.wide) - 2.5, self.gantry, Q2_ARMOR, "q2");
            build.foe(float(self.cross_x) + 1.5, float(self.wide) - 3.0, self.gantry, "monster_soldier", 270.0);
        }
        # A rock outcrop on the far wall, a stash behind a panel in it.
        build.solid(8, self.wide - 5, 0, 12, self.wide - 1, 6);
        if dice.chance(0.7) {
            stash(build, self.wide - 5, 9, 0, False, -1, "item_adrenaline");
        }
        crate_pile(build, self.long - 9, 1, 0, 2, 2);
        open_ways(build, yard, self);
        build.start(2.5, float(cy) + 2.5, 3, 0.0);
        build.supply(2.5, float(self.wide) - 2.5, 3, "ammo_shells", "q2");
        mission = build.touch(1.0, 6.0, 3.0, 6.0, float(self.wide - 1), 9.0);
        mission +>:Fires:+> build.objective("Infiltrate and destroy\nthe Strogg power plant");
        mission +>:Fires:+> build.objective("Find the reactor.\nExpose the reactor core.", False);
        # Far over the yard, charges go off now and then.
        shelling(build, dice.uniform(7.0, 10.0), [[float(self.long) - 4.0, 4.0, float(self.tall - 5)], [float(self.long) - 9.0, float(self.wide) - 4.0, float(self.tall - 4)], [float(self.long // 2), float(cy), float(self.tall - 3)]]);
        sparking(build, 4.0, float(self.long) - 1.2, float(cy) + 3.5, float(self.porch) + 3.0, 2);
        # Guards appear on the porch as the player crosses the yard.
        crossing = build.touch(float(self.long // 2 - 1), 5.0, 0.0, float(self.long // 2 + 1), float(self.wide - 1), 6.0);
        squad(build, crossing, [[float(self.long) - 4.5, float(cy) - 4.5, float(self.porch)], [float(self.long) - 3.5, float(cy) + 4.5, float(self.porch)]], [POWER1_FOES.pick(dice, self.danger, True), POWER1_FOES.pick(dice, self.danger)], 180.0);
        crossing +>:Fires:+> build.explosion(float(px) - 1.0, float(cy) + 5.5, 2.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 - 3 + index * 4) + 0.5, float(cy) + 3.5 - float(index % 2) * 6.0, 0, POWER1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(10.5, float(cy) + 1.5, 0, "monster_soldier", 0.0, patrol=[[10.5, float(cy) + 1.5], [float(px) - 5.5, float(cy) + 1.5], [float(px) - 5.5, float(self.wide) - 6.5], [14.5, float(self.wide) - 6.5]]);
        build.foe(float(self.long) - 4.5, 3.0, self.gantry, POWER1_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, self.gantry + 4, POWER1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.porch, Q2_HEALTH, "q2");
    }
}

"""Turbines in a row down a hall, catwalks along its walls over them."""
node TurbineHall(Prefab) {
    has walk: int = 7,
        tall: int = 17,
        both: bool = True,
        climb_lift: bool = False,
        trench: bool = False,
        turbines: list[int] = [],
        crossings: list[int] = [];

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Turbine hall";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(31, 37);
        self.wide = dice.between(21, 24);
        self.walk = dice.between(9, 10);
        self.tall = self.walk + dice.between(9, 11);
        self.both = dice.chance(0.55);
        self.climb_lift = dice.chance(0.4);
        self.trench = dice.chance(0.5);
        self.turbines = [];
        x = 10;
        while x + 4 <= self.long - 10 {
            self.turbines.append(x);
            x += 7;
        }
        gaps = [at + 4 for at in self.turbines[:-1]];
        order = dice.order(len(gaps));
        self.crossings = [gaps[order[0]]];
        if self.both and len(gaps) > 2 and dice.chance(0.5) {
            self.crossings.append(gaps[order[1]]);
        }
        self.low = -4 if self.trench else -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=3.0, floor=self.walk), Port(face=3, along=float(self.long - 6), floor=self.walk)];
        if self.both {
            self.leaves.append(Port(face=1, along=float(dice.between(12, self.long - 5)), floor=self.walk));
        } else {
            self.leaves.append(Port(face=1, along=float(self.long // 2), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        base = 0;
        if self.trench {
            # The turbines stand in a trench three lifts deep, steps down at
            # each end.
            base = -3;
            build.widen(hall, 7, cy - 4, -3, self.long - 7, cy + 4, 0);
            build.level(hall, -3);
            stair(build, 9, cy - 4, -3, 2, 3, 8);
            stair(build, self.long - 10, cy - 4, -3, 0, 3, 8);
        }
        for x in self.turbines {
            build.solid(x, cy - 2, base, x + 4, cy + 2, base + 5);
            build.solid(x + 1, cy - 1, base + 5, x + 3, cy + 1, base + 7);
        }
        # The catwalk along the low wall and its stair or lift.
        start_x = 3 + self.walk;
        if self.climb_lift {
            start_x = 7;
            plat(build, hall, 3, 1, 6, 4, 0, self.walk);
            build.solid(6, 1, self.walk - 1, 7, 5, self.walk);
        } else {
            stair(build, 3, 1, 0, 0, self.walk, 4);
        }
        build.solid(start_x, 1, self.walk - 1, self.long - 1, 5, self.walk);
        far_y = self.wide - 1;
        if self.both {
            far_y = self.wide - 5;
            build.solid(8, self.wide - 5, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        }
        for x in self.crossings {
            build.solid(x, 5, self.walk - 1, x + 3, far_y, self.walk);
        }
        if not self.both {
            # A perch on the far wall at the bridge's end.
            x = self.crossings[0];
            build.solid(x - 1, self.wide - 4, self.walk - 1, x + 4, self.wide - 1, self.walk);
            build.supply(float(x) + 1.5, float(self.wide) - 2.5, self.walk, "ammo_grenades", "q2");
        }
        open_ways(build, hall, self);
        # Halfway along, panels burst, maidens appear, the crane starts.
        mid = self.long // 2;
        halfway = build.touch(float(mid - 1), 5.0, float(base), float(mid + 1), float(self.wide - 5), 6.0);
        for side in [0, 1] {
            panel_y = 5.0 if side == 0 else float(self.wide - 6);
            burst = build.breakable(float(mid + 3 + side * 4), panel_y, 0.0, float(mid + 5 + side * 4), panel_y + 1.0, 3.0, 10);
            halfway +>:Fires:+> burst;
        }
        charges(build, halfway, [[float(mid + 4), 5.5, float(base + 2)], [float(mid + 8), float(self.wide - 6), float(base + 2)]], 0.2);
        later = build.delay(0.4);
        halfway +>:Fires:+> later;
        squad(build, later, [[float(self.long) - 4.5, float(cy) - 6.5, 0.0], [float(self.long) - 4.5, float(cy) + 6.5, 0.0]], ["monster_chick", POWER1_FOES.pick(dice, self.danger)], 180.0);
        crane = build.train([3.0, 4.0, 1.0], [[5.0, float(cy - 2), float(self.tall - 3)], [float(self.long - 8), float(cy - 2), float(self.tall - 3)]], 90.0, 2.0, True);
        start_crane = build.delay(1.0);
        halfway +>:Fires:+> start_crane;
        start_crane +>:Fires:+> crane;
        # The crane's controls on the catwalk's wall start it too, and a
        # panel by them shorts.
        controls = build.push(float(self.long) - 9.5, 1.0, float(self.walk) + 1.2, 1);
        controls +>:Fires:+> crane;
        controls +>:Fires:+> build.sparks(float(self.long) - 11.5, 1.2, float(self.walk) + 2.0, 1);
        # Guards appear along the catwalk as the player climbs.
        top = build.touch(float(start_x - 2), 1.0, float(self.walk), float(start_x + 1), 5.0, float(self.walk + 6));
        squad(build, top, [[float(self.long) - 4.5, 3.0, float(self.walk)], [float(self.long // 2) + 2.5, 3.0, float(self.walk)]], [POWER1_FOES.pick(dice, self.danger), "monster_gunner"], 180.0);
        for at in self.turbines[:2] {
            sparking(build, dice.uniform(3.0, 5.0), float(at) + 2.0, float(cy) + 2.2, float(base + 3), 1);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, float(cy) + (5.5 if index % 2 == 0 else -5.5), 0, POWER1_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(4.5, float(cy) + 5.5, 0, "monster_berserk", 0.0, patrol=[[4.5, float(cy) + 5.5], [float(self.long) - 4.5, float(cy) + 5.5], [float(self.long) - 4.5, float(cy) - 5.5], [14.5, float(cy) - 5.5]]);
        if self.both {
            build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, self.walk, POWER1_FOES.pick(dice, self.danger, True), 180.0);
        }
        build.supply(float(self.long) - 2.5, float(cy) + 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, 3.0, self.walk, "ammo_bullets", "q2");
    }
}

"""A shaft between two ledges joined by a walk along its wall, the floor far
below; an updraft, a stair or a freight train up, and a lift."""
node FanShaft(Prefab) {
    has top: int = 12,
        tall: int = 21,
        upward: bool = True,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Fan shaft";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.top = dice.between(12, 16);
        self.long = self.top + dice.between(10, 12);
        self.wide = dice.between(16, 18);
        self.tall = self.top + dice.between(8, 10);
        self.upward = dice.chance(0.6);
        self.climb = dice.below(3);
        self.low = -1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy + 1.0, floor=0 if self.upward else self.top);
        self.leaves = [Port(face=0, along=cy + 1.0, floor=self.top), Port(face=0, along=cy + 1.0, floor=0), Port(face=3, along=float(self.long // 2), floor=self.top)];
        if self.climb != 1 {
            self.leaves.append(Port(face=1, along=float(self.long // 2), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        top = self.top;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, top);
        # The two ledges, slabs across the shaft's ends, and the walk along
        # its low wall between them.
        far = self.long - 7;
        build.solid(1, 1, top - 1, 7, self.wide - 1, top);
        build.solid(far, 1, top - 1, self.long - 1, self.wide - 1, top);
        build.solid(7, 1, top - 1, far, 5, top);
        # A block in the floor under the walk, a vent's stash in it.
        build.solid(9, 1, 0, 13, 5, 6);
        if dice.chance(0.6) {
            stash(build, 5, 10, 0, False, 1, Q2_ARMOR);
        }
        # The lift up to the far ledge, always.
        plat_y = self.wide - 5 if self.climb != 1 else cy - 2;
        plat(build, shaft, far - 3, plat_y, far, plat_y + 3, 0, top);
        if self.climb == 0 {
            # The updraft: a pad three cells back from the far ledge's edge.
            build.jump_pad(float(far) - 3.0, float(cy) + 0.5, 0, float(far) + 3.0, float(cy) + 0.5, top);
            keep_box(build, shaft, far, cy - 2, far + 1, cy + 3, top);
            build.supply(float(far) - 3.0, float(cy) + 3.5, 0, "ammo_cells", "q2");
        } elif self.climb == 1 {
            # A stair up the high wall to the far ledge.
            stair(build, far - top, self.wide - 5, 0, 0, top, 4);
        } else {
            # A freight platform riding up and down by the far ledge.
            build.train([3.0, 3.0, 1.0], [[float(far - 3), float(cy - 1), 0.0], [float(far - 3), float(cy - 1), float(top - 1)]], 70.0, 3.0);
            keep_box(build, shaft, far, cy - 1, far + 1, cy + 2, top);
        }
        open_ways(build, shaft, self);
        # Flyers come in as the player reaches the bottom.
        bottom = build.touch(8.0, 5.0, 0.0, float(far - 1), float(self.wide - 5), 6.0);
        squad(build, bottom, [[float(far) - 2.5, float(cy) - 2.5, float(top - 4)], [float(far) - 6.5, float(cy) + 3.5, float(top - 3)]], ["monster_flyer", POWER1_FOES.pick(dice, self.danger, False, True)], 180.0);
        sparking(build, dice.uniform(3.0, 6.0), float(far) + 0.5, float(cy) + 0.5, float(top) - 1.6, 2);
        build.foe(float(far) + 3.5, float(cy) + 0.5, top, POWER1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(3.5, float(cy) + 0.5, top if self.upward else 0, POWER1_FOES.pick(dice, self.danger), 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(far) - 6.5 + float(index) * 3.0, float(self.wide) - 3.5, 0, POWER1_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(self.long // 2) + 0.5, 3.0, top, Q2_HEALTH, "q2");
    }
}

"""The reactor's core standing in a pit, a gallery round the hall, bridges
from it to the core's top."""
node ReactorHall(Prefab) {
    has gallery: int = 9,
        deep: int = 7,
        tall: int = 20,
        bridges: int = 1,
        pit_stair: bool = True,
        updraft: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor hall";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(32, 35);
        self.wide = dice.between(30, 33);
        self.gallery = dice.between(9, 10);
        self.deep = dice.between(8, 10);
        self.tall = self.gallery + dice.between(10, 12);
        self.bridges = dice.between(1, 3);
        self.pit_stair = dice.chance(0.6);
        self.updraft = dice.chance(0.6);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=1, along=float(self.long // 2 + 6), floor=self.gallery),
            Port(face=3, along=float(self.long // 2 - 6), floor=self.gallery),
            Port(face=0, along=cy - 6.0, floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gallery;
        low = -self.deep;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        build.level(hall, low);
        # The pit, the core in it, its top level with the gallery.
        build.widen(hall, cx - 6, cy - 6, low, cx + 6, cy + 6, 0);
        build.solid(cx - 3, cy - 3, low, cx + 3, cy + 3, g);
        build.solid(cx - 2, cy - 2, g, cx + 2, cy + 2, g + 2);
        # The gallery round the walls.
        build.solid(1, 1, g - 1, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(1, 5, g - 1, 5, self.wide - 5, g);
        build.solid(self.long - 5, 5, g - 1, self.long - 1, self.wide - 5, g);
        # Bridges from the gallery to the core's top.
        build.solid(5, cy - 1, g - 1, cx - 3, cy + 2, g);
        if self.bridges >= 2 {
            build.solid(cx - 1, cy + 3, g - 1, cx + 2, self.wide - 5, g);
        }
        if self.bridges >= 3 {
            build.solid(cx + 3, cy - 1, g - 1, self.long - 5, cy + 2, g);
        }
        # Up to the gallery: a lift in a corner, a stair along the floor.
        plat(build, hall, 5, 5, 8, 8, 0, g);
        stair(build, 5, self.wide - 5 - g, 0, 1, g, 4);
        keep_box(build, hall, 5, self.wide - 6, 9, self.wide - 5, g);
        if self.updraft {
            # An updraft from the floor up onto the gallery along the low
            # wall, three cells back from its edge.
            build.jump_pad(float(cx + 9), 8.0, 0, float(cx + 9), 2.5, g);
            keep_box(build, hall, cx + 7, 4, cx + 12, 5, g);
        }
        # Out of the pit: a lift by the core, a stair up its far side.
        plat(build, hall, cx - 6, cy - 6, cx - 3, cy - 3, low, 0);
        if self.pit_stair {
            stair(build, cx + 3, cy + 6 - self.deep, low, 1, self.deep, 3);
            keep_box(build, hall, cx + 3, cy + 6, cx + 6, cy + 7, 0);
        } else {
            plat(build, hall, cx + 3, cy + 3, cx + 6, cy + 6, low, 0);
        }
        # The core's foot hides a stash behind a panel.
        if dice.chance(0.5) {
            stash(build, cx - 3, cy + 1, low, True, -1, Q2_ARMOR);
        }
        open_ways(build, hall, self);
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0) +>:Fires:+> build.objective("Expose the reactor core.\nThe way down is in the pit.", False);
        # The core's charges pulse.
        pulse = build.timer(dice.uniform(5.0, 7.0));
        charges(build, pulse, [[float(cx) - 3.2, float(cy), float(g - 3)], [float(cx), float(cy) + 3.2, float(g - 4)], [float(cx) + 3.2, float(cy), float(g - 5)]], 0.3);
        sparking(build, 3.0, float(cx) - 3.2, float(cy) - 2.0, float(low + 2), 2);
        # Flyers appear over the pit as the player reaches the gallery.
        up_lift = build.touch(4.0, 4.0, float(g), 9.0, 9.0, float(g + 6));
        up_stair = build.touch(5.0, float(self.wide - 6), float(g), 9.0, float(self.wide - 4), float(g + 6));
        crew = build.waiting();
        up_lift +>:Fires:+> crew;
        up_stair +>:Fires:+> crew;
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(cy) - 5.0, g + 2, POWER1_FOES.pick(dice, self.danger, False, True), 90.0, waits=crew);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 3 + index * 3) + 0.5, float(cy) + 4.5, low, POWER1_FOES.pick(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, g + 2, POWER1_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 3.0, float(cy) + 6.5, g, POWER1_FOES.pick(dice, self.danger), 180.0);
        build.foe(9.5, 3.0, 0, "monster_berserk", 0.0, patrol=[[9.5, 3.0], [float(self.long) - 3.5, 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0], [9.5, float(self.wide) - 3.0]]);
        build.supply(float(cx) + 4.5, float(cy) - 4.5, low, Q2_HEALTH, "q2");
        build.supply(3.0, 3.0, g, "ammo_cells", "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""The key room: a gallery over a deep vault, the key on a dais at its
bottom, a lift down and up."""
node KeyVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        deep: int = 12,
        stairs: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Key vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.deep = dice.between(12, 16);
        self.long = self.deep + dice.between(14, 16);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.stairs = dice.chance(0.6);
        self.low = -self.deep - 1;
        self.high = 11;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        low = -self.deep;
        vault = build.room(1, 1, low, self.long - 1, side, 10, variant=dice.below(3));
        build.level(vault, 0);
        # The gallery the way in opens on: a slab over the vault's floor.
        build.solid(1, 1, -1, 7, side, 0);
        build.doorway(vault, self.enter);
        # A lift down and back up beside it, a stair down the low wall.
        plat(build, vault, 7, side - 5, 10, side - 2, low, 0);
        if self.stairs {
            stair(build, 6 + self.deep, 1, low, 2, self.deep, 3);
            keep_box(build, vault, 7, 1, 8, 4, 0);
        }
        # The dais at the far end, the key on it.
        build.solid(self.long - 6, cy - 3, low, self.long - 1, cy + 4, low + 2);
        stair(build, self.long - 8, cy - 1, low, 0, 2, 3);
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, low + 2, side, low, [10, self.long - 8], [POWER1_FOES.pick(dice, self.danger, True), POWER1_FOES.pick(dice, self.danger)]);
        # Climbing onto the dais sets off the charges round the vault.
        on_dais = build.touch(float(self.long - 6), float(cy - 3), float(low + 2), float(self.long - 4), float(cy + 4), float(low + 8));
        charges(build, on_dais, [[float(self.long) - 2.0, 2.5, float(low + 6)], [12.0, 2.5, float(low + 7)], [12.0, float(side) - 2.0, float(low + 6)]], 0.4);
        # Guards appear on the floor as the player reaches it.
        landed = build.touch(8.0, 4.0, float(low), 12.0, float(side - 1), float(low + 6));
        squad(build, landed, [[float(self.long) - 9.5, 3.5, float(low)], [float(self.long) - 9.5, float(side) - 3.5, float(low)]], [POWER1_FOES.pick(dice, self.danger), "monster_chick"], 180.0);
        guard = "monster_supertank" if self.danger > 0.75 else ("monster_tank" if self.danger > 0.3 else "monster_gladiator");
        build.foe(float(self.long) - 9.5, float(cy) + 0.5, low, guard, 180.0);
        build.foe(4.0, 3.5, 0, POWER1_FOES.pick(dice, self.danger), 0.0);
        sparking(build, 5.0, float(self.long) - 1.2, float(cy) - 4.5, float(low + 4), 2);
        build.supply(3.0, float(side) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 9.5, float(cy) + 3.5, low, "ammo_rockets", "q2");
    }
}

"""The end: a hall, a door, a yard of transformers under the sky, the way
out on a tower or behind a barrier that sinks when a button is shot."""
node Switchyard(Prefab) {
    has key: str = "",
        tower: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Switchyard" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = POWER1;
        self.district = level_district(POWER1);
        self.long = dice.between(30, 33);
        self.wide = dice.between(21, 24);
        self.tall = dice.between(18, 22);
        self.tower = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        yard = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.doorway(hall, self.enter);
        build.widen(yard, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # Transformers in two rows down the yard, against its walls.
        for x in range(wall + 4, self.long - 16, 5) {
            build.solid(x, 1, 0, x + 3, cy - 4, 3);
            build.solid(x, cy + 4, 0, x + 3, self.wide - 1, 3);
            build.solid(x + 1, 2, 3, x + 2, cy - 5, 6);
            build.solid(x + 1, cy + 5, 3, x + 2, self.wide - 2, 6);
        }
        sparking(build, dice.uniform(3.0, 5.0), float(wall + 5), float(cy) - 3.8, 3.0, 1);
        sparking(build, dice.uniform(4.0, 6.0), float(wall + 5), float(cy) + 3.8, 3.0, 3);
        if self.tower {
            # The way out on a tower up a stair.
            tx = self.long - 10;
            build.solid(tx, cy - 4, 0, self.long - 4, cy + 4, 6);
            stair(build, tx - 6, cy - 1, 0, 0, 6, 3);
            keep_box(build, yard, tx, cy - 1, tx + 1, cy + 2, 6);
            build.way_out(float(self.long) - 7.0, float(cy), 6);
            on_top = build.touch(float(tx), float(cy - 4), 6.0, float(tx + 2), float(cy + 4), 12.0);
            charges(build, on_top, [[float(tx) - 3.0, 3.0, 4.0], [float(tx) - 3.0, float(self.wide) - 3.0, 4.0], [float(tx) - 8.0, float(cy), 6.0]], 0.3);
            build.foe(float(self.long) - 5.5, float(cy) + 2.5, 6, POWER1_FOES.pick(dice, self.danger, True), 180.0);
        } else {
            # A fence across the yard, its gap barred by a block that sinks
            # when the button over it is shot; the way out beyond.
            fx = self.long - 9;
            build.solid(fx, 1, 0, fx + 1, self.wide - 1, 9);
            build.widen(yard, fx, cy - 2, 0, fx + 1, cy + 2, 8);
            barrier = build.sinking(float(fx), float(cy - 2), float(fx + 1), float(cy + 2), 8, 8);
            build.push(float(fx), float(cy) + 4.5, 6.0, 2, True) +>:Fires:+> barrier;
            build.touch(float(fx - 4), 1.0, 0.0, float(fx - 3), float(self.wide - 1), 8.0, True, "Shoot the switch to drop the barrier");
            build.way_out(float(self.long) - 4.0, float(cy), 0);
            build.foe(float(self.long) - 4.5, float(cy) + 5.5, 0, POWER1_FOES.pick(dice, self.danger, True), 180.0);
        }
        # Guards appear in the yard as the player comes through the door.
        through = build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0);
        squad(build, through, [[float(self.long) - 12.5, float(cy) - 1.5, 0.0], [float(self.long) - 12.5, float(cy) + 2.5, 0.0]], [POWER1_FOES.pick(dice, self.danger), POWER1_FOES.pick(dice, self.danger)], 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, POWER1_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 6.5, float(cy) + 0.5, 9, POWER1_FOES.pick(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""power1's stretches: [name, role]."""
glob POWER1_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["turbines", "flow"],
         ["turbines", "hub"],
         ["shaft", "flow"],
         ["reactor", "hub"],
         ["reactor", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of power1's stretches by its name."""
def make_power1(name: str, key: str) -> Prefab {
    if name == "gate" {
        return PlantGate();
    }
    if name == "turbines" {
        return TurbineHall();
    }
    if name == "shaft" {
        return FanShaft();
    }
    if name == "reactor" {
        return ReactorHall();
    }
    if name == "vault" {
        return KeyVault(key=key if key else "key_silver");
    }
    return Switchyard(key=key);
}
