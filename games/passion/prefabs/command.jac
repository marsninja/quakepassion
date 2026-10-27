"""Prefabs drawn from Quake II's command, the Command Center: the lower
concourse under the upper one, the coolant chambers whose valves are shut
one by one, the tank hall under its mezzanine, the pump station, the CPU
core in its coolant moat that dies once its three valves are closed, the
communications room where the key lies, and the way to the launch.
Raised in command's own palette.

- `CommandEntry`: the start. A vestibule and its door, a concourse under
  a mezzanine reached by a great lift (or a stair); the objectives
  ("Destroy the black hole generator. Shut off the coolant to the CPU");
  crates that burst when shot; a ledge high in a corner only a rocket
  jump reaches (command's "You crazy rocket jumper" secret).
- `CoolantChamber`: a coolant tank sunk in the floor round its pump
  column, galleries along both walls and a catwalk across past the
  column; the valve (on the column at the catwalk, or down at the tank's
  foot) shuts the chamber down ("Chamber deactivated"), the floaters come
  and the coolant gate on the floor opens. A pump rides in the tank.
- `TankHall`: a hall under a mezzanine over half its floor, up lifts (or a
  stair), a bridge from it to a sniper's nest on a pillar; tanks on the
  floor, crates; ways on from both floors (a hub).
- `PumpStation`: a pump room of two floors, the lower a flooded basin
  under the upper, the pumps rising and falling at the near end, a
  lift up, a partition with its door across the upper floor.
- `CPUCore`: the core CPU in its coolant moat, a ledge round it, bridges
  over the moat, a gallery round the walls up lifts; three valves (one
  on the core, one on the gallery, one down in the moat) count down to
  the coolant cut, the core burning out ("Core CPU is no longer
  functional") and the doors on opening ("Access now possible").
- `CommsRoom`: the key on a dais in the communications room, coolant in
  a pool before it and a trench behind it, a gallery along two walls up a stair or a lift; taking it opens the closets.
- `LaunchAccess`: the end. A door (a key's, as a gate) into the launch
  bay, a catwalk along its wall, the launch platform up a lift (or a
  stair) with the way out on it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, apart }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, squad, rounds, beamed, held_door, key_taken, closets }

glob COMMAND: str = "q2:command";

"""command's foes: gunners and iron maidens, floaters, gladiators and
tanks deeper in."""
def command_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_gunner", "monster_soldier_light", "monster_chick"], ["monster_tank"] if heavy else ["monster_floater"], danger * 0.3 if heavy else danger * 0.6));
}

"""Crates on a floor (lift `z`) that burst when shot: `count` of them two
cells square and two or three lifts high, at points of the box x0..x1,
y0..y1 clear of `clear` ([x0, y0, x1, y1] each, kept a cell off)."""
def crates(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 10 {
        tries += 1;
        x = dice.between(x0, max(x0, x1 - 2));
        y = dice.between(y0, max(y0, y1 - 2));
        box = [x, y, x + 2, y + 2];
        if not apart(box, clear) {
            continue;
        }
        clear.append(box);
        build.breakable(float(x), float(y), float(z), float(x + 2), float(y + 2), float(z + dice.between(2, 3)), 10);
        placed += 1;
    }
}

"""A box of the prefab's cells that hurts whoever stands in it (`damage`
a tenth of a second): a pump's shaft, a machine's works."""
def hurting(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage), "asset_game": "q2"}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""The start: a vestibule, a concourse under a mezzanine up a great lift
or a stair."""
node CommandEntry(Prefab) {
    has up: int = 9,
        deck_x: int = 14,
        by_lift: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Command entry";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.up = 9;
        self.tall = self.up + 10;
        self.by_lift = dice.chance(0.6);
        self.deck_x = dice.between(13, 15) if self.by_lift else dice.between(16, 17);
        self.low = -9;
        self.high = self.tall + 2;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 3), floor=0),
            Port(face=1, along=9.0, floor=0),
            Port(face=0, along=float(middle + 3), floor=self.up),
            Port(face=3, along=float(self.long - 5), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        dx = self.deck_x;
        vestibule = build.room(1, 1, 0, 6, self.wide - 1, 10, variant=dice.below(3));
        hall = build.room(7, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.up);
        # The vestibule's door into the concourse.
        build.widen(hall, 6, middle - 2, 0, 7, middle + 2, 8);
        build.rising_door(6.0, float(middle - 2), 0.0, 7.0, float(middle + 2), 8.0, {"wait": "-1"});
        # The mezzanine over the concourse's far part, up a great lift or a
        # stair along the wall.
        deck(build, dx, 1, self.long - 1, self.wide - 1, self.up);
        if self.by_lift {
            lift(build, dx - 3, middle - 1, dx, middle + 2, 0, self.up);
            keep_box(build, hall, dx, middle - 1, dx + 1, middle + 2, self.up);
            build.touch(float(dx - 5), float(middle - 1), 0.0, float(dx - 3), float(middle + 2), 6.0, True, "The lift rises to the upper concourse");
        } else {
            stair(build, dx - self.up, 1, 0, 0, self.up, 3);
            keep_box(build, hall, dx, 1, dx + 1, 4, self.up);
        }
        # A flooded sump under the mezzanine's far corner, a stair out.
        build.pool(self.long - 8, self.wide - 7, -5, self.long - 2, self.wide - 1, 0, 2, steps=False);
        stair(build, self.long - 8, self.wide - 7, -5, 0, 5, 2);
        # A ledge high in the corner only a rocket jump reaches.
        deck(build, 7, self.wide - 4, 10, self.wide - 1, 14);
        build.secret(7.0, float(self.wide - 4), 14.0, 10.0, float(self.wide - 1), 17.0);
        build.supply(8.5, float(self.wide) - 2.5, 14, "item_health_mega", "q2");
        build.doorway(vestibule, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Destroy the black hole generator. Shut off the coolant to the CPU");
        # Crates on the concourse floor, clear of the ways and the lift.
        clear = [[self.long - 9, self.wide - 8, self.long, self.wide], [6, middle - 3, 10, middle + 3], [dx - 6, middle - 3, dx + 1, middle + 3], [dx - self.up - 1, 1, dx + 1, 5], [self.long - 5, middle - 6, self.long - 1, middle + 6], [7, self.wide - 4, 12, self.wide - 1]];
        crates(build, dice, 8, 2, self.long - 3, self.wide - 2, 0, dice.between(3, 4), clear);
        # The mezzanine's guards come out as the player arrives up there.
        arrive = build.touch(float(dx), 1.0, float(self.up), float(dx + 2), float(self.wide - 1), float(self.up + 6));
        squad(build, arrive, [[float(self.long) - 4.5, 3.5, float(self.up)], [float(self.long) - 4.5, float(self.wide) - 3.5, float(self.up)]], [command_foe(dice, self.danger, True), "monster_gunner"], 180.0);
        beamed(build, arrive, 2, 2, -8, command_foe(dice, self.danger), float(dx) + 6.5, float(middle) + 0.5, self.up, 180.0);
        rounds(build, "monster_gunner", [[float(dx) + 2.5, 3.5], [float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(middle) + 0.5], [float(dx) + 2.5, float(middle) + 0.5]], 0);
        for index in range(dice.between(1, 2)) {
            build.foe(11.5 + float(index) * 3.0, 3.5 + float(index) * 10.0, 0, command_foe(dice, self.danger), 180.0);
        }
        build.foe(float(dx) - 2.5, float(middle) + 5.5, 6, "monster_floater", 180.0);
        sparking(build, float(self.long) - 1.2, float(middle) + 5.0, float(self.up) + 2.0, 2, 4.0);
        sparking(build, 6.2, float(middle) + 3.5, 3.0, 0, 6.0);
        build.supply(float(self.long) - 3.5, float(middle) + 0.5, self.up, Q2_HEALTH, "q2");
    }
}

"""A coolant tank round its pump column, galleries along both walls, a
catwalk past the column; the valve shuts the chamber down."""
node CoolantChamber(Prefab) {
    has gal: int = 6,
        deep: int = 6,
        sunk_valve: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Coolant chamber";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(22, 24);
        self.wide = dice.between(20, 22);
        self.gal = 6;
        self.deep = dice.between(5, 6);
        self.sunk_valve = dice.chance(0.4);
        self.tall = 16;
        self.low = -9;
        self.high = 21;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gal),
            Port(face=3, along=float(self.long - 5), floor=self.gal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gal;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, g);
        # The tank, a stair up out of it, the pump column in its middle.
        build.pool(6, 5, -self.deep, self.long - 6, self.wide - 5, 0, 2, steps=False);
        stair(build, 6, 5, -self.deep, 0, self.deep, 2);
        build.solid(cx - 1, cy - 1, -self.deep, cx + 1, cy + 1, self.tall);
        # The galleries, the stair up to the near one, the catwalk across
        # past the column.
        deck(build, 2 + g, 1, self.long - 1, 5, g);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g);
        stair(build, 2, 1, 0, 0, g, 3);
        keep_box(build, room, 2 + g, 1, 3 + g, 4, g);
        deck(build, cx + 1, 5, cx + 4, self.wide - 5, g);
        keep_box(build, room, cx + 1, 4, cx + 4, 5, g);
        keep_box(build, room, cx + 1, self.wide - 5, cx + 4, self.wide - 4, g);
        # The valve: on the column at the catwalk, or down at the tank's foot.
        if self.sunk_valve {
            valve = build.push(float(cx), float(cy - 1), float(-self.deep) + 1.5, 3);
            build.touch(4.0, float(cy - 2), 0.0, 6.0, float(cy + 2), 6.0, True, "The chamber's valve lies at the foot of the tank");
        } else {
            valve = build.push(float(cx + 1), float(cy), float(g) + 1.5, 0);
        }
        shut = build.delay(3.0);
        valve +>:Fires:+> shut;
        shut +>:Fires:+> build.objective("Chamber deactivated", False);
        blast_chain(build, valve, [[float(cx) - 1.5, float(cy) - 1.5, 3.0], [float(cx) + 1.5, float(cy) + 1.5, 8.0], [float(cx) - 1.5, float(cy) + 1.5, 12.0]], 0.5);
        valve +>:Fires:+> build.breakable(float(cx - 1), float(cy + 1), float(-self.deep), float(cx + 1), float(cy + 2), float(2 - self.deep), 20);
        squad(build, valve, [[float(cx) - 4.0, float(cy) + 3.0, 8.0], [float(cx) + 5.0, float(cy) - 3.0, 8.0]], ["monster_floater"], 180.0);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
            if port.floor == 0 and port.face == 0 {
                held_door(build, self, port, shut, "The coolant gate opens once the chamber is shut down");
            }
        }
        # The pump riding in the tank beside the column.
        build.train([2.0, 2.0, 2.0], [[float(cx - 3), float(cy - 1), float(1 - self.deep)], [float(cx - 3), float(cy - 1), 2.0]], 30.0, 1.5);
        hurting(build, float(cx - 3), float(cy - 1), float(1 - self.deep), float(cx - 1), float(cy + 1), 4.0, 8);
        rounds(build, "monster_gunner", [[float(g) + 4.5, 3.0], [float(self.long) - 3.0, 3.0]], g);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 5.0, 0, command_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(cx) + 2.5, float(self.wide) - 3.0, g, command_foe(dice, self.danger), 270.0);
        sparking(build, float(cx) - 1.2, float(cy) + 0.5, float(g) + 2.0, 2, 3.0);
        sparking(build, float(self.long) - 1.2, float(cy) + 3.0, 3.0, 2, 5.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "ammo_bullets", "q2");
    }
}

"""A hall under a mezzanine over half its floor, a bridge from it to a
sniper's nest on a pillar; tanks on the floor."""
node TankHall(Prefab) {
    has mez: int = 9,
        stairs: bool = False,
        nest_x: int = 14,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tank hall";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.mez = 9;
        self.tall = 20;
        self.stairs = dice.chance(0.4);
        self.nest_x = dice.between(14, self.long - 14) if self.stairs else dice.between(14, self.long - 12);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle - 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 4), floor=0),
            Port(face=3, along=float(self.long // 2 + 4), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.mez),
            Port(face=0, along=float(self.wide - 5), floor=self.mez)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        my = middle + 2;
        m = self.mez;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, m);
        # The mezzanine over the far half, up lifts or a stair.
        deck(build, 1, my, self.long - 1, self.wide - 1, m);
        if self.stairs {
            stair(build, self.long - 2, my - 3, 0, 2, m, 3);
            keep_box(build, hall, self.long - 11, my, self.long - 8, my + 1, m);
        } else {
            lift(build, 6, my - 3, 9, my, 0, m);
            keep_box(build, hall, 6, my, 9, my + 1, m);
            lift(build, self.long - 9, my - 3, self.long - 6, my, 0, m);
            keep_box(build, hall, self.long - 9, my, self.long - 6, my + 1, m);
        }
        # A flooded sump in the near corner, a stair up out of it.
        build.pool(3, 1, -6, 12, 7, 0, 2, steps=False);
        stair(build, 3, 5, -6, 0, 6, 2);
        # The sniper's nest on a pillar over the near half, a bridge to it.
        nx = self.nest_x;
        build.solid(nx - 1, 4, 0, nx + 3, 8, m);
        deck(build, nx, 8, nx + 3, my, m);
        keep_box(build, hall, nx, my - 1, nx + 3, my, m);
        keep_box(build, hall, nx, 7, nx + 3, 8, m);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        clear = [[0, 0, 13, 8], [0, middle - 5, 5, middle + 2], [self.long - 6, middle - 7, self.long, middle - 1], [self.long // 2, 0, self.long // 2 + 8, 5], [nx - 2, 3, nx + 4, 9], [4, my - 5, 11, my], [self.long - 11, my - 5, self.long - 4, my], [self.long - 5, 1, self.long, my], [self.long - 12, my - 4, self.long, my]];
        crates(build, dice, 3, 2, self.long - 3, my - 1, 0, dice.between(4, 5), clear);
        # The tanks on the floor; guards come onto the mezzanine and the nest
        # as the player comes in.
        build.foe(float(self.long) - 7.5, float(middle) - 6.5, 0, "monster_tank" if self.danger > 0.3 else "monster_gladiator", 180.0);
        rounds(build, command_foe(dice, self.danger, True), [[13.5, 2.5], [float(self.long) - 6.5, 2.5]], 0);
        come_in = build.touch(1.0, float(middle - 5), 0.0, 4.0, float(middle + 1), 8.0);
        squad(build, come_in, [[float(nx) + 1.0, 6.0, float(m)], [float(self.long) - 4.5, float(self.wide) - 3.5, float(m)], [8.5, float(self.wide) - 4.5, float(m)]], ["monster_gunner", command_foe(dice, self.danger, True), command_foe(dice, self.danger)], 270.0);
        beamed(build, come_in, self.long - 5, 2, -8, command_foe(dice, self.danger, True), float(self.long // 2) + 0.5, float(middle) - 2.5, 0, 180.0);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 6, "monster_floater", 180.0);
        sparking(build, float(self.long) - 1.2, float(my) + 4.0, float(m) + 2.0, 2, 4.0);
        sparking(build, 1.2, float(my) - 3.0, 3.0, 0, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(nx) + 1.0, 5.5, m, "ammo_rockets", "q2");
        build.supply(float(self.long) - 3.5, float(self.wide) - 6.5, m, Q2_ARMOR, "q2");
    }
}

"""A pump room of two floors, a channel of water under the upper floor,
pumps rising and falling, a lift up, a partition across the upper floor."""
node PumpStation(Prefab) {
    has up: int = 9,
        part_x: int = 18,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump station";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.up = 9;
        self.tall = 27;
        self.part_x = dice.between(15, self.long - 8);
        self.low = -9;
        # Room over the partition's door for the rock it rises into.
        self.high = 30;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle - 5), floor=0),
            Port(face=1, along=9.0, floor=0),
            Port(face=0, along=float(middle + 4), floor=self.up),
            Port(face=3, along=float(self.long - 5), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        u = self.up;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, u);
        # The upper floor over all but the near end, the lift up to it.
        deck(build, 8, 1, self.long - 1, self.wide - 1, u);
        lift(build, 5, middle + 3, 8, middle + 6, 0, u);
        keep_box(build, room, 8, middle + 3, 9, middle + 6, u);
        # The lower floor under the upper a flooded basin, a dry walk along
        # its far wall and by the way on, a stair up out of it.
        build.pool(8, 1, -4, self.long - 4, self.wide - 3, 0, 2, steps=False);
        stair(build, 11, middle - 1, -4, 2, 4, 3);
        # The pumps at the near end, rising and falling.
        for (index, py) in enumerate([3, self.wide - 6]) {
            build.solid(2, py - 1, 0, 6, py + 3, 1);
            build.train([2.0, 2.0, 3.0], [[3.0, float(py), 1.0], [3.0, float(py), float(u + 3)]], 40.0 + 10.0 * float(index), 1.0);
            hurting(build, 3.0, float(py), 1.0, 5.0, float(py + 2), float(u + 6), 10);
        }
        # The partition across the upper floor, its door.
        px = self.part_x;
        build.solid(px, 1, u, px + 1, self.wide - 1, self.tall);
        build.widen(room, px, middle - 2, u, px + 1, middle + 2, u + 8);
        build.rising_door(float(px), float(middle - 2), float(u), float(px + 1), float(middle + 2), float(u + 8), {"wait": "-1"});
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # Guards come onto the upper floor as the lift brings the player up,
        # and beyond the partition as its door opens.
        arrive = build.touch(8.0, float(middle + 3), float(u), 11.0, float(middle + 6), float(u + 6));
        squad(build, arrive, [[float(px) - 1.5, 3.5, float(u)], [float(px) - 3.5, float(self.wide) - 3.5, float(u)]], [command_foe(dice, self.danger), "monster_gunner"], 180.0);
        beyond = build.touch(float(px + 1), float(middle - 2), float(u), float(px + 3), float(middle + 2), float(u + 6));
        squad(build, beyond, [[float(self.long) - 3.5, 3.5, float(u)], [float(self.long) - 3.5, float(self.wide) - 3.5, float(u)]], [command_foe(dice, self.danger, True), command_foe(dice, self.danger)], 180.0);
        beamed(build, beyond, 2, middle - 2, -8, command_foe(dice, self.danger), float(px) + 4.5, float(middle) + 0.5, u, 180.0);
        rounds(build, "monster_gunner", [[9.5, float(self.wide) - 2.0], [float(self.long) - 2.5, float(self.wide) - 2.0], [float(self.long) - 2.5, 3.0]], 0);
        build.foe(4.5, float(middle) + 0.5, 6, "monster_floater", 0.0);
        broken = stash(build, 9, 2, u, 0, Q2_ARMOR, 6);
        broken +>:Fires:+> build.sparks(13.2, 4.0, float(u) + 2.0, 0);
        sparking(build, 6.2, 4.0, 3.0, 0, 3.0);
        sparking(build, float(px) - 0.2, float(middle) + 4.0, float(u) + 3.0, 2, 4.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, u, "ammo_grenades", "q2");
    }
}

"""The core CPU in its coolant moat, a ledge round it, a gallery round the
walls; three valves count down to the core burning out."""
node CPUCore(Prefab) {
    has gal: int = 9,
        slime: bool = False,
        bridges: int = 2,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "CPU core";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(28, 30);
        self.wide = dice.between(28, 30);
        self.gal = 9;
        self.tall = 22;
        self.slime = dice.chance(0.35);
        self.bridges = dice.between(1, 2);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long - 8), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        g = self.gal;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, g);
        # The moat, the ledge round the core, the core to the roof; a stair
        # up out of the moat, footbridges over it.
        build.pool(cx - 6, cy - 6, -5, cx + 6, cy + 6, 0, 3 if self.slime else 2, steps=False);
        build.solid(cx - 4, cy - 4, -5, cx + 4, cy + 4, 0);
        build.solid(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.tall);
        stair(build, cx - 6, cy - 6, -5, 0, 5, 2);
        deck(build, cx - 6, cy - 1, cx - 4, cy + 2, 0);
        if self.bridges > 1 {
            deck(build, cx + 4, cy - 1, cx + 6, cy + 2, 0);
        }
        # The gallery round the walls, up lifts at two corners.
        deck(build, 1, 1, self.long - 1, 5, g);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, g);
        deck(build, 1, 5, 5, self.wide - 5, g);
        deck(build, self.long - 5, 5, self.long - 1, self.wide - 5, g);
        lift(build, 5, 5, 8, 8, 0, g);
        keep_box(build, room, 5, 4, 8, 5, g);
        lift(build, self.long - 8, self.wide - 8, self.long - 5, self.wide - 5, 0, g);
        keep_box(build, room, self.long - 8, self.wide - 5, self.long - 5, self.wide - 4, g);
        # The three valves: on the core's face, on the gallery's wall, down
        # in the moat on the ledge's face. All closed, the coolant is cut,
        # the core burns out, and the doors open.
        count = build.tally(3, "The coolant to the CPU is cut");
        build.push(float(cx - 3), float(cy) + 0.5, 1.5, 2) +>:Fires:+> count;
        build.push(float(cx) + 0.5, float(self.wide - 1), float(g) + 1.5, 3) +>:Fires:+> count;
        build.push(float(cx + 4), float(cy) + 3.0, -3.5, 0) +>:Fires:+> count;
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "Three valves feed the core its coolant");
        burn = build.delay(4.0);
        count +>:Fires:+> burn;
        last = blast_chain(build, burn, [[float(cx - 3), float(cy - 3), 4.0], [float(cx + 3), float(cy + 3), 8.0], [float(cx - 3), float(cy + 3), 12.0], [float(cx + 3), float(cy - 3), 16.0]], 0.4);
        for (index, at) in enumerate([[cx - 3, cy], [cx + 3, cy], [cx, cy - 3], [cx, cy + 3]]) {
            last +>:Fires:+> build.sparks(float(at[0]) + 0.5, float(at[1]) + 0.5, 6.0 + float(index) * 2.0, index);
        }
        last +>:Fires:+> build.objective("Core CPU is no longer functional");
        for corner in [[cx - 4, cy - 4], [cx + 3, cy - 4], [cx - 4, cy + 3], [cx + 3, cy + 3]] {
            burn +>:Fires:+> build.breakable(float(corner[0]), float(corner[1]), 0.0, float(corner[0] + 1), float(corner[1] + 1), 3.0, 30);
        }
        access = build.delay(2.0);
        last +>:Fires:+> access;
        access +>:Fires:+> build.objective("Access now possible to the launch", False);
        squad(build, burn, [[float(cx) - 6.0, float(cy) - 9.0, 10.0], [float(cx) + 6.0, float(cy) + 9.0, 10.0]], ["monster_floater"], 180.0);
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
            if port.floor == 0 {
                held_door(build, self, port, access, "The core CPU has locked this door");
            }
        }
        beamed(build, count, 2, 2, -8, command_foe(dice, self.danger, True), float(cx) + 0.5, float(cy) - 9.5, 0, 90.0);
        rounds(build, "monster_gunner", [[3.0, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [3.0, float(self.wide) - 3.0]], g);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) - 9.5 + float(index) * 9.5, float(cy) + 10.0, 0, command_foe(dice, self.danger, index == 0), 270.0);
        }
        build.foe(float(cx) + 0.5, float(cy) - 8.0, 0, command_foe(dice, self.danger), 90.0);
        sparking(build, float(cx) - 3.2, float(cy) - 2.0, 3.0, 2, 3.5);
        sparking(build, float(cx) + 3.2, float(cy) + 2.0, 5.0, 0, 4.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, g, "ammo_cells", "q2");
        build.supply(float(cx) - 3.5, float(cy) - 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on a dais in the communications room, a gallery along two
walls; taking it opens the closets."""
node CommsRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        gal: int = 7,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Comms room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.gal = 7;
        self.by_lift = dice.chance(0.5);
        self.tall = 16;
        self.low = -9;
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
        g = self.gal;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, g);
        build.doorway(room, self.enter);
        # The gallery along the near wall and the far end, up a stair or a
        # lift; the consoles on it.
        deck(build, 8, 1, self.long - 1, 5, g);
        deck(build, self.long - 5, 5, self.long - 1, side, g);
        if self.by_lift {
            lift(build, 5, 1, 8, 4, 0, g);
        } else {
            stair(build, 1, 1, 0, 0, g, 3);
        }
        keep_box(build, room, 8, 1, 9, 4, g);
        build.solid(self.long - 2, 6, g, self.long - 1, side - 2, g + 2);
        # The dais in the middle, two steps up, the key on it.
        dx = self.long // 2 - 2;
        # Coolant in a pool before the dais (a causeway along its side) and
        # a trench behind it, a stair up out of each.
        build.pool(dx - 7, cy + 2, -4, dx - 3, side - 2, 0, 2, steps=False);
        stair(build, dx - 7, cy + 2, -4, 0, 4, 2);
        build.pool(dx + 3, 3, -4, dx + 7, side - 2, 0, 2, steps=False);
        stair(build, dx + 6, 3, -4, 2, 4, 2);
        build.solid(dx - 3, cy - 3, 0, dx + 3, cy + 3, 1);
        build.solid(dx - 2, cy - 2, 1, dx + 2, cy + 2, 2);
        taken = key_taken(build, self.key, float(dx), float(cy), 2);
        closets(build, taken, side, 0, [3, self.long - 9], [command_foe(dice, self.danger, True), command_foe(dice, self.danger)]);
        squad(build, taken, [[float(self.long) - 3.0, float(side) - 3.5, float(g)], [12.5, 3.0, float(g)]], [command_foe(dice, self.danger), "monster_gunner"], 180.0);
        beamed(build, taken, self.long - 5, side - 5, -8, command_foe(dice, self.danger, True), float(dx) - 5.5, float(cy) + 0.5, 0, 0.0);
        taken +>:Fires:+> build.sparks(float(self.long) - 2.2, float(cy) + 0.5, float(g) + 1.0, 2);
        rounds(build, "monster_gunner", [[9.5, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(side) - 3.0]], g);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, 0, command_foe(dice, self.danger), 180.0);
        sparking(build, float(self.long) - 2.2, float(cy) - 2.5, float(g) + 1.5, 2, 3.0);
        sparking(build, 1.2, float(side) - 3.0, 3.0, 0, 5.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door into the launch bay, a catwalk along its wall, the
launch platform up a lift or a stair, the way out on it."""
node LaunchAccess(Prefab) {
    has key: str = "",
        top: int = 12,
        by_lift: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Launch access" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = COMMAND;
        self.district = level_district(COMMAND);
        self.long = dice.between(30, 32);
        self.wide = dice.between(18, 20);
        self.top = 12;
        self.by_lift = dice.chance(0.5);
        self.tall = self.top + 10;
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
        bay = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(bay, self.top);
        build.level(bay, 6);
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Access now possible to the launch");
        # The launch platform at the far end, up a lift or a stair along
        # the wall.
        px = self.long - 9;
        build.solid(px, 2, 0, self.long - 1, self.wide - 2, self.top);
        if self.by_lift {
            lift(build, px - 3, middle - 1, px, middle + 2, 0, self.top);
            keep_box(build, bay, px, middle - 1, px + 1, middle + 2, self.top);
        } else {
            stair(build, px - self.top, self.wide - 5, 0, 0, self.top, 3);
            keep_box(build, bay, px, self.wide - 5, px + 1, self.wide - 2, self.top);
        }
        build.way_out(float(self.long) - 4.0, float(middle), self.top);
        # Water under the catwalk, a stair up out of it.
        build.pool(wall + 4, 1, -4, px - 1, 4, 0, 2, steps=False);
        stair(build, px - 5, 1, -4, 0, 4, 3);
        # The catwalk along the near wall, its guards.
        deck(build, wall + 1, 1, px, 4, 6);
        stair(build, wall + 3, 4, 0, 0, 6, 3);
        keep_box(build, bay, wall + 7, 3, wall + 10, 4, 6);
        come_in = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        squad(build, come_in, [[float(px) - 3.5, 2.5, 6.0], [float(px) + 3.5, float(middle) + 3.0, float(self.top)]], [command_foe(dice, self.danger, True), "monster_gunner"], 180.0);
        on_top = build.touch(float(px), 2.0, float(self.top), float(px + 3), float(self.wide - 2), float(self.top + 6));
        blast_chain(build, on_top, [[float(px) - 2.0, 3.0, 2.0], [float(px) - 2.0, float(self.wide) - 3.0, 2.0]], 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, command_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(px) - 5.5, float(middle) + 2.5, 0, command_foe(dice, self.danger, True), 180.0);
        sparking(build, float(px) - 0.2, 3.5, 4.0, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 4.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""command's stretches: [name, role]."""
glob COMMAND_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["chamber", "flow"],
         ["pumps", "flow"],
         ["core", "flow"],
         ["tanks", "hub"],
         ["pumps", "hub"],
         ["comms", "keyroom"],
         ["launch", "end"],
         ["launch", "gate"]
     ];

"""One of command's stretches by its name."""
def make_command(name: str, key: str) -> Prefab {
    if name == "entry" {
        return CommandEntry();
    }
    if name == "chamber" {
        return CoolantChamber();
    }
    if name == "pumps" {
        return PumpStation();
    }
    if name == "core" {
        return CPUCore();
    }
    if name == "tanks" {
        return TankHall();
    }
    if name == "comms" {
        return CommsRoom(key=key if key else "key_silver");
    }
    return LaunchAccess(key=key);
}
