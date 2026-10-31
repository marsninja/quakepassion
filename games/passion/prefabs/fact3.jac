"""Prefabs drawn from Quake II's fact3, the Sudden Death works: a short,
near empty run through the factory's upper works against the clock. A
lobby over a slime duct with a gallery over its far floor, a floor that
sinks a whole storey when its switch is thrown (fact3's lowering platform
door), the slime duct walked along its ledges to doors a shot switch
opens, a production line on a gantry among slamming presses, the key in
a design office, the way out past a slime moat. fact3 holds few foes; its
stretches keep few. Raised in fact3's own palette.

- `UpperLobby`: the start. A lobby, a slime duct cut across its floor
  under a grate of beams, a gallery along the far side up a stair; the
  clock's warning ("Get out before the works are sealed").
- `SinkingFloor`: a hall over a lower hall, a floor of it standing over a
  shaft that sinks a whole storey a moment after its switch is thrown
  (taking whoever is on it down); back up by a lift and a teleporter; the
  guards below wake as it goes down.
- `SlimeDuct`: a duct of slime down a hall's length, ledges along both
  walls and crossings, the doors at its far end opened by shooting the
  switch high over the slime.
- `ProductionLine`: a hall, the line on a gantry down its middle, up a
  stair or steps a switch raises (or a lift), presses slamming down
  beside it into pits; a stash in a press's base; ways on from the floor
  and the gantry (a hub).
- `DesignOffice`: the key in an office up a stair or steps a switch
  raises, over a drafting floor; taking it opens the closets.
- `WorksExit`: the end. A door (a key's, as a gate), the way out on a
  platform in a slime moat, reached on a walk or by a teleporter."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush, gate_into, lift }
import from .minefact { slab, hurt, burning, sparking, stash, port_door, crusher }

glob FACT3: str = "q2:fact3";

"""fact3's few foes: guards, gunners, a gladiator deeper in."""
glob FACT3_FOES: FoeMix = FoeMix(light=["monster_soldier_light", "monster_soldier"], strong=["monster_gunner"], heavy_light=["monster_gunner", "monster_soldier_ss"], heavy_strong=["monster_gladiator"], scale=0.5);

"""The start: a lobby, a slime duct across its floor under a grate, a
gallery along the far side."""
node UpperLobby(Prefab) {
    has deck: int = 6,
        by_lift: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Upper lobby";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(34, 36);
        self.wide = dice.between(18, 20);
        self.deck = 8;
        self.by_lift = dice.chance(0.4);
        self.tall = dice.between(13, 15);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        dx = self.long // 2 - 2;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(dice.between(dx + 14, self.long - 3)), floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        lobby = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(lobby, self.deck);
        dx = self.long // 2 - 2;
        burning(build, dx, 1, -3, dx + 4, self.wide - 1, 0, 3, 10);
        for y in range(2, self.wide - 2, 2) {
            build.solid(dx, y, -1, dx + 4, y + 1, 0);
        }
        build.solid(dx, middle - 2, -1, dx + 4, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(lobby, dx - 1, y, 0);
            build.keep(lobby, dx + 4, y, 0);
        }
        # The gallery along the south wall over the far floor, up a stair
        # along the wall or a lift.
        slab(build, dx + 12, 1, self.long - 1, 6, self.deck, 1);
        lift(build, dx + 12, 6, dx + 15, 9, 0, self.deck);
        for x in range(dx + 12, dx + 15) {
            build.keep(lobby, x, 5, self.deck);
        }
        if not self.by_lift {
            stair(build, dx + 4, 1, 0, 0, self.deck, 3);
            for y in range(1, 4) {
                build.keep(lobby, dx + 12, y, self.deck);
            }
        }
        build.doorway(lobby, self.enter);
        for port in self.taken {
            build.doorway(lobby, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(middle - 3), 0.0, 5.0, float(middle + 3), 6.0) +>:Fires:+> build.objective("Get out before the works are sealed.");
        sparking(build, float(dx) - 0.1, 2.5, 3.0, 2, 3.0);
        sparking(build, float(self.long) - 1.1, float(self.wide) - 3.5, 4.0, 2, 4.0);
        guard = build.waiting();
        build.touch(float(dx + 4), float(middle - 2), 0.0, float(dx + 6), float(middle + 2), 6.0) +>:Fires:+> guard;
        build.foe(float(self.long) - 3.5, 3.0, self.deck, FACT3_FOES.pick(dice, self.danger), 180.0, waits=guard);
        build.foe(float(dx + 7) + 0.5, float(self.wide) - 3.5, 0, FACT3_FOES.pick(dice, self.danger), 180.0, patrol=[[float(dx + 7) + 0.5, float(self.wide) - 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall over a lower hall, a floor of it that sinks a whole storey a
moment after its switch is thrown."""
node SinkingFloor(Prefab) {
    has drop: int = 11,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sinking floor";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(22, 26);
        self.wide = dice.between(18, 20);
        self.drop = dice.between(12, 15);
        self.tall = dice.between(9, 11);
        self.low = -2 * self.drop - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 2.0, floor=0);
        self.leaves = [Port(face=0, along=middle - 2.0, floor=-self.drop)];
        if dice.chance(0.3) {
            self.leaves.append(Port(face=3, along=float(self.long - 5), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.drop;
        sx = self.long // 2 - 3;
        sy = self.wide - 7;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, low);
        # The upper floor, a slab over the lower hall; the floor that sinks
        # against its north wall.
        slab(build, 1, 1, self.long - 1, self.wide - 1, 0, 1);
        build.widen(hall, sx, sy, -1, sx + 6, sy + 6, 0);
        sinks = build.sinking(float(sx), float(sy), float(sx + 6), float(sy + 6), 0, self.drop);
        throw = build.push(float(sx) + 3.0, float(self.wide - 1), 1.0, 3);
        late = build.delay(2.0);
        throw +>:Fires:+> late;
        late +>:Fires:+> sinks;
        for x in range(sx, sx + 6) {
            build.keep(hall, x, sy - 1, 0);
        }
        build.touch(float(sx - 2), float(sy - 2), 0.0, float(sx + 8), float(sy), 6.0, True, "Throw the switch and ride the floor down.");
        # Back up: a lift through the upper floor, or a teleporter.
        build.widen(hall, 2, 2, -1, 5, 5, 0);
        lift(build, 2, 2, 5, 5, low, 0);
        for x in range(2, 5) {
            build.keep(hall, x, 5, 0);
        }
        build.teleporter(float(self.long) - 4.5, 3.5, low, 3.5, float(middle) - 2.0, 0, 0.0);
        burning(build, 2, self.wide - 6, low - 3, 6, self.wide - 2, low, 3, 8);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        below = build.waiting();
        late +>:Fires:+> below;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.5, float(middle + 2 + index * 2) + 0.5, low, FACT3_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        sparking(build, float(sx) - 0.5, float(self.wide) - 1.1, 3.0, 3, 3.0);
        sparking(build, float(self.long) - 1.1, float(middle) + 3.5, float(low) + 3.0, 2, 4.0);
        build.supply(float(self.long) - 3.5, 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(sx) - 2.5, 3.5, low, "ammo_bullets", "q2");
    }
}

"""A duct of slime down a hall's length, ledges along both walls and
crossings, the doors at its far end opened by shooting the switch high
over the slime."""
node SlimeDuct(Prefab) {
    has tall: int = 11;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime duct";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(10, 12);
        self.low = -4;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.0, floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=0, along=3.0, floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=1, along=float(self.long // 2), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        duct = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        burning(build, 5, 4, -3, self.long - 5, self.wide - 4, 0, 3, 10);
        for x in [9, self.long - 12] {
            build.solid(x, 4, -1, x + 3, self.wide - 4, 0);
        }
        build.doorway(duct, self.enter);
        # The far doors, opened by shooting the switch high on the far wall
        # over the slime.
        trip = build.push(float(self.long - 1), float(middle) + 0.5, 6.0, 2, True);
        for port in self.taken {
            build.doorway(duct, port);
            if port.face == 0 {
                port_door(build, self.long, self.wide, port, trip);
            }
        }
        build.touch(float(self.long - 5), 1.0, 0.0, float(self.long - 1), float(self.wide - 1), 6.0, True, "Shoot the switch over the slime.");
        trip +>:Fires:+> build.sparks(float(self.long) - 1.2, float(middle) + 0.5, 7.0, 2);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 4) + 0.5, 2.5 if index == 0 else float(self.wide) - 2.5, 0, FACT3_FOES.pick(dice, self.danger, index == 1), 180.0);
        }
        sparking(build, 1.1, float(self.wide) - 3.5, 3.0, 0, 5.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall, the line on a gantry down its middle, presses slamming down
beside it."""
node ProductionLine(Prefab) {
    has gantry: int = 5,
        way_up: int = 0,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Production line";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.gantry = dice.between(6, 8);
        self.way_up = dice.below(3);
        self.tall = self.gantry + 11;
        self.low = -self.gantry - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle - 4.0, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.gantry),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gantry;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        g0 = 4 + g;
        build.solid(g0, middle - 2, g - 1, self.long - 1, middle + 2, g);
        if self.way_up == 0 {
            stair(build, 4, middle - 2, 0, 0, g, 4);
        } elif self.way_up == 1 {
            build.push(1.0, float(middle) + 3.5, 1.0, 0) +>:Fires:+> build.rising_steps(4, middle - 2, 0, 0, g, 4);
        } else {
            lift(build, g0 - 3, middle - 2, g0, middle + 1, 0, g);
        }
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, g0, y, g);
        }
        # Posts under the line; presses slamming down into pits beside it.
        for x in range(g0 + 2, self.long - 3, 5) {
            build.solid(x, middle - 2, 0, x + 1, middle + 2, g - 1);
        }
        for x in range(g0 + 3, self.long - 5, 10) {
            for py in [middle - 5, middle + 3] {
                build.widen(hall, x, py, -2, x + 2, py + 2, 0);
                crusher(build, float(x), float(py), [2.0, 2.0, 3.0], -2.0, 3.0, 100.0, 1.0, 30);
                hurt(build, float(x), float(py), -2.0, float(x + 2), float(py + 2), 0.0, 20);
            }
        }
        # A press's base by the south wall, a stash behind a panel in it.
        build.solid(1, self.wide - 6, 0, 5, self.wide - 2, 5);
        stash(build, 2, self.wide - 5, 0, 0, "ammo_grenades");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        up_line = build.waiting();
        build.touch(float(g0), float(middle - 2), float(g), float(g0 + 2), float(middle + 2), float(g + 6)) +>:Fires:+> up_line;
        for index in range(dice.between(1, 2)) {
            build.foe(float(g0 + 6 + index * 6) + 0.5, float(middle) + 0.5, g, FACT3_FOES.pick(dice, self.danger, index == 0), 180.0, waits=up_line);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5 + float(self.wide - 8), 0, "monster_soldier", 0.0, patrol=[[float(g0) + 0.5, float(self.wide) - 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        sparking(build, 5.1, float(self.wide) - 3.0, 3.0, 0, 3.0);
        sparking(build, float(self.long) - 1.1, float(middle) + 0.5, float(g) + 3.0, 2, 4.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, g, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in an office up a stair or steps a switch raises, over a
drafting floor."""
node DesignOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        office: int = 5,
        rising: bool = False,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Design office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(6, 8);
        self.rising = dice.chance(0.5);
        self.tall = self.office + 8;
        self.low = -self.office - 1;
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
        if self.rising {
            build.push(float(ox - self.office) - 1.5, 1.0, 1.0, 1) +>:Fires:+> build.rising_steps(ox - self.office, 1, 0, 0, self.office, 3);
        } else {
            stair(build, ox - self.office, 1, 0, 0, self.office, 3);
        }
        for y in range(1, 4) {
            build.keep(room, ox, y, self.office);
        }
        for x in range(4, ox - 3, 4) {
            build.solid(x, cy - 1, 0, x + 2, cy + 2, 2);
        }
        # A plan chest by the north wall, a stash behind a panel in it.
        build.solid(ox - 4, 4, 0, ox, 8, 6);
        stash(build, ox - 3, 5, 0, 2, Q2_ARMOR);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.office, side, 0, [2, ox - 4], [FACT3_FOES.pick(dice, self.danger, True), FACT3_FOES.pick(dice, self.danger)]);
        sparking(build, float(self.long) - 1.1, float(cy) - 3.5, float(self.office) + 2.0, 2, 4.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, the way out on a platform in a slime moat, reached on
a walk or by a teleporter."""
node WorksExit(Prefab) {
    has key: str = "",
        by_walk: bool = True,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Works exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = FACT3;
        self.district = level_district(FACT3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.by_walk = dice.chance(0.5);
        self.tall = dice.between(12, 14);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        px0 = wall + 7;
        px1 = self.long - 4;
        burning(build, wall + 4, 2, -3, self.long - 1, self.wide - 2, 0, 3, 10);
        build.solid(px0, middle - 3, -3, px1, middle + 3, 1);
        if self.by_walk {
            build.solid(wall + 4, middle - 1, -3, px0, middle + 2, 0);
        } else {
            build.teleporter(float(wall) + 2.5, float(middle) + 0.5, 0, float(px0) + 1.5, float(middle) + 0.5, 1, 0.0);
        }
        build.way_out(float(px0 + px1) * 0.5 + 1.0, float(middle), 1);
        sparking(build, float(wall) + 1.1, 3.5, 3.0, 0, 3.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 3.5 + float(index) * 5.0, 0, FACT3_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""fact3's stretches: [name, role]."""
glob FACT3_STRETCHES: list[list[str]] = [
         ["lobby", "start"],
         ["sinking", "flow"],
         ["duct", "flow"],
         ["line", "hub"],
         ["line", "flow"],
         ["office", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of fact3's stretches by its name."""
def make_fact3(name: str, key: str) -> Prefab {
    if name == "lobby" {
        return UpperLobby();
    }
    if name == "sinking" {
        return SinkingFloor();
    }
    if name == "duct" {
        return SlimeDuct();
    }
    if name == "line" {
        return ProductionLine();
    }
    if name == "office" {
        return DesignOffice(key=key if key else "key_silver");
    }
    return WorksExit(key=key);
}
