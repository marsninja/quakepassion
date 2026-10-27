"""Prefabs drawn from Quake II's base3, the Comm Center: a dish on the
surface, the base sunk far below it down a long lift shaft, a hall half
drowned with catwalks over the water, a control room round a sunken pit
of consoles whose main console sets off the unit's alarms, the key in a
vault opened from a booth up a lift. Raised in base3's own palette.

- `DishYard`: the start. A yard under the sky, a comm dish on a pedestal
  up a stair, a walkway from the pedestal high along the yard's wall; the
  help computer says to locate the communication center; guards appear on
  the walkway as the player climbs; a stash behind a panel shot open.
- `DescentShaft`: a shaft sunk far down, the long lift from a landing at
  its top to its floor, a gallery round it halfway down up a stair from
  the floor in some seeds; the floor dry or flooded shallow; a laser fence
  across a niche turned off by a button (a secret behind it); guards
  appear below as the lift goes down.
- `FloodedLevel`: a hall flooded below, a catwalk along its wall over the
  water broken in its middle (swum across, or bridged by a shot button),
  another along the far wall in some seeds; stairs up out of the water;
  sharks in it, guards appearing on the far side.
- `ControlCenter`: a control room, a pit of consoles sunk in its middle,
  galleries along two walls up stairs (a hub). Pressing the main console
  sets the alarms off: charges one after another, guards appearing, the
  doors on opening (base3's long chain of relays).
- `DishBooth`: the key room. A booth high on a wall up a lift; the key in
  a vault under the booth opened a moment after the booth's console is
  pressed, or lying in the booth; taking it opens the closets.
- `CommExit`: the end. A door (a key's, as a gate), a landing over a hall
  below, a stair (or a lift) down to the way out; the help computer says
  to locate the unit's exit, guards appear and charges go off below."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush, key_item }
import from .e4m6 { flood, onward_ports, port_door, pool_steps, told }
import from .base2 { spark_timer, blast_chain, spawn_in, panel_stash, guard_closet }

glob BASE3: str = "q2:base3";

"""base3's foes: soldiers and infantry, parasites and gunners deeper in."""
def base3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    if heavy and dice.chance(0.3 + 0.4 * danger) {
        return "monster_parasite";
    }
    return q2_foe(dice, danger, heavy);
}

"""A laser fence: Quake II's target_laser at (x, y), `z` lifts up, beaming
the way `direction` goes, and a hurting volume x0..x1, y0..y1, z0..z1 along
the beam; both switched off when `off` fires."""
def laser_fence(build: Raising, x: float, y: float, z: float, direction: int, box: list[float], off: Cue) {
    beam = {"classname": "target_laser", "spawnflags": "3", "dmg": "40", "angle": str(build.facing(direction))};
    build.put_point(beam, x, y, z, "q2");
    burn = {"classname": "trigger_hurt", "dmg": "20", "spawnflags": "2"};
    build.put_box(burn, box[0], box[1], box[2], box[3], box[4], box[5], "trigger");
    off +>:Fires:+> build.cue([beam, burn], "laser");
}

"""Crates at `spots` ([x, y] each) on lift `z`, broken open when shot."""
def crates(build: Raising, spots: list[list[int]], z: int) {
    for at in spots {
        build.breakable(float(at[0]), float(at[1]), float(z), float(at[0] + 1), float(at[1] + 1), float(z + 2), 10);
    }
}

"""The start: a yard, a comm dish on a pedestal up a stair, a walkway from
the pedestal along the yard's wall."""
node DishYard(Prefab) {
    has pedestal: int = 4,
        walk: int = 7,
        walkway: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish yard";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(22, 24);
        self.pedestal = dice.between(4, 5);
        self.walk = self.pedestal + 3;
        self.walkway = dice.chance(0.7);
        self.tall = dice.between(20, 24);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0), Port(face=1, along=float(self.long // 2), floor=self.pedestal)];
        if self.walkway {
            self.leaves.append(Port(face=0, along=float(self.wide - 6), floor=self.walk));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.pedestal);
        # The pedestal against the +y wall, a stair up its west side, the
        # dish on it: a mast and a broad plate tilted on top.
        build.solid(cx - 4, self.wide - 8, 0, cx + 4, self.wide - 1, self.pedestal);
        stair(build, cx - 4 - self.pedestal, self.wide - 6, 0, 0, self.pedestal, 3);
        build.solid(cx, self.wide - 4, self.pedestal, cx + 1, self.wide - 3, self.pedestal + 6);
        build.solid(cx - 3, self.wide - 5, self.pedestal + 6, cx + 4, self.wide - 2, self.pedestal + 7);
        for y in range(self.wide - 6, self.wide - 3) {
            build.keep(yard, cx - 4, y, self.pedestal);
        }
        # The walkway: up a short stair from the pedestal's east end, along
        # the +y wall over the yard to the far wall.
        if self.walkway {
            stair(build, cx + 4, self.wide - 8, self.pedestal, 0, 3, 3);
            build.solid(cx + 7, self.wide - 8, self.walk - 1, self.long - 1, self.wide - 4, self.walk);
            for y in range(self.wide - 8, self.wide - 5) {
                build.keep(yard, cx + 7, y, self.walk);
            }
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        into = build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0);
        into +>:Fires:+> build.objective("Locate the communication center");
        late = build.delay(2.0);
        into +>:Fires:+> late;
        late +>:Fires:+> build.sparks(float(cx) + 0.5, float(self.wide) - 4.1, float(self.pedestal) + 5.0, 3);
        # Climbing the pedestal, guards appear along the walkway (or on the
        # pedestal's far side).
        climb = build.touch(float(cx - 4 - self.pedestal), float(self.wide - 6), 0.0, float(cx - 4), float(self.wide - 3), float(self.pedestal + 6));
        if self.walkway {
            spawn_in(build, dice, self.danger, climb, [[float(cx + 9) + 0.5, float(self.wide) - 6.0], [float(self.long) - 3.5, float(self.wide) - 6.0]], self.walk, 180.0);
        }
        spawn_in(build, dice, self.danger, climb, [[float(cx + 2) + 0.5, float(self.wide) - 7.0], [float(self.long) - 4.5, 4.5]], 0, 180.0, True);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + index % 2 * 3) + 0.5, 3.5 + float(index) * 3.0, 0, base3_foe(dice, self.danger), 180.0);
        }
        build.foe(6.5, 5.5, 0, "monster_soldier", 0.0, patrol=[[6.5, 5.5], [float(self.long) - 6.5, 5.5]]);
        build.foe(float(cx) + 2.5, float(self.wide) - 6.5, self.pedestal, base3_foe(dice, self.danger, True), 270.0);
        spark_timer(build, float(cx) - 0.1, float(self.wide) - 3.5, float(self.pedestal) + 3.0, 2, 5.0);
        panel_stash(build, 6, 0);
        crates(build, [[self.long - 4, self.wide - 12], [3, self.wide - 4], [self.long - 3, 6]], 0);
        build.foe(float(self.long) - 5.5, 6.5, 0, "monster_infantry" if self.danger > 0.3 else "monster_soldier_light", 90.0, patrol=[[float(self.long) - 5.5, 6.5], [float(self.long) - 5.5, float(self.wide) - 10.5]]);
        build.touch(float(cx - 4), float(self.wide - 8), float(self.pedestal), float(cx + 4), float(self.wide - 1), float(self.pedestal + 6), True, "The communication center lies far below");
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A shaft sunk far down, the long lift from a landing at its top to its
floor, a gallery round it halfway down in some seeds."""
node DescentShaft(Prefab) {
    has deep: int = 20,
        gallery_here: bool = True,
        flooded: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Descent shaft";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(18, 22);
        self.gallery_here = dice.chance(0.6);
        self.flooded = dice.chance(0.35);
        self.tall = dice.between(9, 11);
        self.low = -self.deep - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        half = self.deep // 2;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=-self.deep),
            Port(face=1, along=float(self.long - 5), floor=-self.deep),
            Port(face=3, along=3.0, floor=0)
        ];
        if self.gallery_here {
            self.leaves.append(Port(face=3, along=float(self.long - 5), floor=-self.deep + half));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        half = self.deep // 2;
        shaft = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, 0);
        # The landing at the top, and the long lift beside it.
        build.solid(1, 1, low, 6, self.wide - 1, 0);
        build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "150"}, 6.0, float(middle - 2), -0.5, 10.0, float(middle + 2), 0.0, kit_of(build.district).step);
        for y in range(middle - 2, middle + 2) {
            build.keep(shaft, 5, y, 0);
        }
        # The gallery halfway down along the walls, up a stair along the -y
        # wall from the floor.
        if self.gallery_here {
            build.solid(11, self.wide - 4, low + half - 1, self.long - 1, self.wide - 1, low + half);
            build.solid(self.long - 4, 1, low + half - 1, self.long - 1, self.wide - 4, low + half);
            stair(build, self.long - 4 - half, 1, low, 0, half, 3);
            for y in range(1, 4) {
                build.keep(shaft, self.long - 4, y, low + half);
            }
            build.level(shaft, low + half);
            spawn_in(build, dice, self.danger, build.touch(float(self.long - 4 - half), 1.0, float(low), float(self.long - 4 - half + 3), 4.0, float(low + 6)), [[float(self.long) - 2.5, float(self.wide) - 6.5], [14.5, float(self.wide) - 2.5]], low + half, 180.0);
        }
        # The floor: shallow water over it in some seeds.
        if self.flooded {
            build.pool(11, 5, low - 2, self.long - 5, self.wide - 5, low, 2, False, True, True);
            if self.danger > 0.3 {
                build.foe(16.5, float(middle) + 0.5, low - 1, "monster_flipper", 0.0);
            }
        }
        # A niche in the landing's foot, a laser fence across it switched off
        # by the button beside it; a stash in it (a secret).
        build.room(2, self.wide - 6, low, 6, self.wide - 2, low + 5);
        off = build.push(6.0, float(self.wide) - 7.5, float(low) + 1.5, 0);
        laser_fence(build, 5.9, float(self.wide) - 2.1, float(low) + 1.5, 3, [5.0, float(self.wide - 6), float(low), 6.0, float(self.wide - 2), float(low + 4)], off);
        build.secret(2.0, float(self.wide - 6), float(low), 5.0, float(self.wide - 2), float(low + 3));
        build.supply(3.0, float(self.wide) - 4.0, low, Q2_ARMOR, "q2");
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Going down, guards appear on the floor and charges go off.
        down = build.touch(6.0, float(middle - 2), float(low), 10.0, float(middle + 2), float(low + 6));
        spawn_in(build, dice, self.danger, down, [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5], [14.5, 3.5]], low, 180.0, True);
        blast_chain(build, down, [[float(self.long) - 6.5, float(middle) + 0.5, float(low + 2)], [14.5, float(self.wide) - 3.5, float(low + 4)]]);
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "The lift goes down to the base");
        for (index, at) in enumerate([[float(self.long) - 1.1, float(middle) + 3.5, 2], [11.5, 1.1, 1], [11.5, float(self.wide) - 1.1, 3]]) {
            spark_timer(build, at[0], at[1], float(low) + 3.0 + float(index) * 4.0, int(at[2]), 4.0 + float(index));
        }
        build.foe(12.5, float(middle) + 3.5, low, "monster_soldier", 0.0, patrol=[[12.5, float(middle) + 3.5], [float(self.long) - 3.5, float(middle) + 3.5]]);
        build.foe(3.0, 3.0, 0, base3_foe(dice, self.danger), 0.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(middle) - 3.5, low, "ammo_bullets", "q2");
        # A teleporter on the floor back up to the landing.
        build.teleporter(12.5, float(self.wide) - 2.5, low, 2.5, 3.0, 0, 0.0);
        crates(build, [[self.long - 2, self.wide - 7]], low);
        build.touch(float(self.long - 6), float(middle - 3), float(low), float(self.long - 1), float(middle + 3), float(low + 6), True, "The communication center is ahead");
    }
}

"""A hall flooded below, a catwalk along its wall over the water broken in
its middle (swum across, or bridged by a shot button), another along the
far wall in some seeds."""
node FloodedLevel(Prefab) {
    has deep: int = 6,
        bridged: bool = False,
        both: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Flooded level";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.deep = dice.between(6, 7);
        self.bridged = dice.chance(0.4);
        self.both = dice.chance(0.5);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide - 3), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide - 3), floor=0), Port(face=1, along=float(self.long - 5), floor=0)];
        if self.both {
            self.leaves.append(Port(face=0, along=3.0, floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        walk_y = self.wide - 5;
        gx0 = self.long // 2 - 3;
        gx1 = self.long // 2 + 3;
        hall = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        # The water over the hall's floor, the catwalk a slab along the +y
        # wall over it but for the gap in its middle, a stair up out of the
        # water onto it either side of the gap.
        build.pool(1, 1, low, self.long - 1, self.wide - 1, 0, 2, False, False);
        build.solid(1, walk_y, -1, gx0, self.wide - 1, 0);
        build.solid(gx1, walk_y, -1, self.long - 1, self.wide - 1, 0);
        for x in list(range(4, gx0 - 3, 5)) + list(range(gx1 + 3, self.long - 2, 5)) {
            build.solid(x, walk_y, low, x + 1, walk_y + 1, -1);
        }
        stair(build, gx0 - 3, walk_y - self.deep, low, 1, self.deep, 3);
        stair(build, gx1, walk_y - self.deep, low, 1, self.deep, 3);
        for x in [gx0 - 3, gx0 - 2, gx0 - 1, gx1, gx1 + 1, gx1 + 2] {
            build.keep(hall, x, walk_y, 0);
        }
        if self.bridged {
            shot = build.push(float(self.long // 2) + 0.5, float(self.wide - 1), 6.0, 3, True);
            shot +>:Fires:+> build.drawn(float(gx0), float(walk_y), float(gx1), float(self.wide - 1), 0, self.deep + 1);
            for y in range(walk_y, self.wide - 1) {
                build.keep(hall, gx0 - 1, y, 0);
                build.keep(hall, gx1, y, 0);
            }
            build.touch(1.0, float(walk_y), 0.0, 4.0, float(self.wide - 1), 6.0, True, "Shoot the panel over the gap to bridge it");
        }
        # The second catwalk along the -y wall, its own stair out of the water.
        if self.both {
            build.solid(6, 1, -1, self.long - 1, 5, 0);
            stair(build, 3, 5 + self.deep - 1, low, 3, self.deep, 3);
            build.solid(1, 1, low, 6, 5, 0);
            build.foe(float(self.long) - 4.5, 2.5, 0, base3_foe(dice, self.danger), 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Crossing the gap, guards appear on the far side.
        across = build.touch(float(gx1), float(walk_y), 0.0, float(gx1 + 3), float(self.wide - 1), 6.0);
        spawn_in(build, dice, self.danger, across, [[float(self.long) - 3.5, float(self.wide) - 2.5], [float(gx1) + 6.5, float(self.wide) - 3.5]], 0, 180.0, True);
        for index in range(dice.between(1, 2)) {
            build.foe(float(6 + index * 8) + 0.5, 6.5, low, "monster_flipper", 0.0);
        }
        build.foe(3.5, float(self.wide) - 3.0, 0, "monster_soldier", 0.0, patrol=[[3.5, float(self.wide) - 3.0], [float(gx0) - 3.5, float(self.wide) - 3.0]]);
        spark_timer(build, float(gx0) + 0.5, float(self.wide) - 1.1, 3.0, 3, 4.0);
        build.supply(float(gx0) - 4.0, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        crates(build, [[gx0 - 6, self.wide - 2], [gx1 + 5, self.wide - 2]], 0);
        build.foe(float(gx1) + 3.5, float(self.wide) - 3.0, 0, "monster_soldier", 0.0, patrol=[[float(gx1) + 3.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.touch(float(gx0 - 3), float(walk_y), 0.0, float(gx0), float(self.wide - 1), 6.0, True, "The catwalk is broken: swim across" if not self.bridged else "");
        build.supply(2.5, float(self.wide) - 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A control room, a pit of consoles sunk in its middle, galleries along
two walls up stairs; the main console sets the alarms off and opens the
ways on."""
node ControlCenter(Prefab) {
    has sunk: int = 3,
        gallery: int = 7,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control center";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.sunk = dice.between(3, 4);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + 10;
        self.low = -self.sunk - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, -self.sunk);
        build.level(room, self.gallery);
        # The pit, steps down at its west and east ends, consoles in it.
        build.widen(room, cx - 7, cy - 4, -self.sunk, cx + 7, cy + 4, 0);
        stair(build, cx - 7 + self.sunk - 1, cy - 2, -self.sunk, 2, self.sunk, 4);
        stair(build, cx + 7 - self.sunk, cy - 2, -self.sunk, 0, self.sunk, 4);
        for x in [cx - 2, cx + 1] {
            build.solid(x, cy - 3, -self.sunk, x + 1, cy - 1, -self.sunk + 2);
            build.solid(x, cy + 1, -self.sunk, x + 1, cy + 3, -self.sunk + 2);
        }
        # The galleries along the +y and -y walls, slabs over pillars, a stair
        # up to each at the far end.
        under = self.gallery - 1;
        build.solid(6, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        build.solid(6, 1, under, self.long - 1, 4, self.gallery);
        pillars(build, 8, self.wide - 5, self.long - 6 - self.gallery, self.wide - 4, 0, under, 4, []);
        pillars(build, 8, 4, self.long - 6 - self.gallery, 5, 0, under, 4, []);
        stair(build, self.long - 4 - self.gallery, self.wide - 7, 0, 0, self.gallery, 3);
        stair(build, self.long - 4 - self.gallery, 4, 0, 0, self.gallery, 3);
        for x in range(self.long - 7, self.long - 4) {
            build.keep(room, x, self.wide - 4, self.gallery);
            build.keep(room, x, 3, self.gallery);
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        # The main console in the pit: pressed, the alarms go off, a chain of
        # relays: charges, the objective, the doors on, guards.
        build.solid(cx - 1, cy - 1, -self.sunk, cx + 1, cy + 1, -self.sunk + 2);
        alarm = build.push(float(cx - 1), float(cy), float(-self.sunk) + 0.6, 2);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "The main console is in the pit") +>:Fires:+> build.objective("Shut down the communication center at its main console");
        blast_chain(build, alarm, [[float(cx) - 5.5, 2.5, float(self.gallery) + 3.0], [float(cx) + 5.5, float(self.wide) - 2.5, float(self.gallery) + 3.0], [float(self.long) - 2.5, float(cy) + 0.5, 4.0]]);
        opening = build.delay(3.0);
        alarm +>:Fires:+> opening;
        for port in onward_ports(self) {
            opening +>:Fires:+> port_door(build, self, port);
        }
        done = told(build, 4.0, "Communications are down");
        alarm +>:Fires:+> done;
        done +>:Fires:+> build.objective("Primary objective complete: get out of the unit", False);
        wave = build.delay(5.0);
        alarm +>:Fires:+> wave;
        spawn_in(build, dice, self.danger, wave, [[10.5, 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]], self.gallery, 180.0, True);
        spawn_in(build, dice, self.danger, wave, [[3.5, 3.5], [3.5, float(self.wide) - 3.5]], 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 4 + index * 4) + 0.5, float(cy) + 0.5 + (2.0 if index == 1 else 0.0), -self.sunk, base3_foe(dice, self.danger), 0.0);
        }
        build.foe(7.5, float(cy) + 5.5, 0, "monster_soldier", 0.0, patrol=[[7.5, float(cy) + 5.5], [float(self.long) - 7.5, float(cy) + 5.5]]);
        build.foe(10.5, float(self.wide) - 2.5, self.gallery, base3_foe(dice, self.danger, True), 0.0);
        spark_timer(build, float(cx) - 2.1, float(cy) - 2.0, float(-self.sunk) + 1.5, 2, 3.0);
        spark_timer(build, float(cx) + 2.1, float(cy) + 2.0, float(-self.sunk) + 1.5, 0, 4.0);
        build.supply(float(self.long) - 2.5, 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
        crates(build, [[2, 5], [self.long - 2, self.wide - 6], [self.long - 2, 5]], 0);
        build.foe(8.5, float(self.wide) - 2.5, self.gallery, "monster_soldier", 0.0, patrol=[[8.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.touch(float(cx - 7), float(cy - 4), float(-self.sunk), float(cx + 7), float(cy + 4), float(-self.sunk + 6), True, "Press the main console");
    }
}

"""The key room: a booth high on a wall up a lift; the key in a vault under
it opened from the booth's console, or lying in the booth."""
node DishBooth(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        booth: int = 7,
        vault: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dish booth (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.booth = dice.between(7, 8);
        self.vault = dice.chance(0.6);
        self.tall = self.booth + 8;
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
        build.level(room, self.booth);
        build.doorway(room, self.enter);
        bx = self.long - 6;
        # The booth: a slab high on the far wall, a rail along its lip but
        # for the lift's head.
        build.solid(bx, 1, self.booth - 1, self.long - 1, side, self.booth);
        build.solid(bx, 1, self.booth, bx + 1, cy - 2, self.booth + 2);
        build.solid(bx, cy + 3, self.booth, bx + 1, side, self.booth + 2);
        build.put_box({"classname": "func_plat", "height": str(self.booth * 16), "speed": "200"}, float(bx - 3), float(cy - 1), float(self.booth) - 0.5, float(bx), float(cy + 2), float(self.booth), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, bx, y, self.booth);
        }
        console = build.push(float(self.long - 1), float(cy) + 3.5, float(self.booth) + 1.5, 2);
        if self.vault {
            # The vault under the booth behind a wall, its door opened a
            # moment after the console is pressed; the key in it.
            build.solid(bx - 1, 1, 0, bx, side, self.booth - 1);
            build.widen(room, bx - 1, cy + 3, 0, bx, cy + 6, 6);
            vault_door = build.opened(float(bx - 1), float(cy + 3), 0.0, float(bx), float(cy + 6), 6.0);
            late = told(build, 3.0, "The vault is open");
            console +>:Fires:+> late;
            late +>:Fires:+> vault_door;
            blast_chain(build, late, [[float(bx) + 2.5, 3.5, 3.0], [float(bx) + 2.5, float(side) - 3.5, 3.0]]);
            key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 0, side, 0, [2, bx - 6], [base3_foe(dice, self.danger, True), base3_foe(dice, self.danger)]);
            build.touch(float(bx - 4), float(cy - 2), 0.0, float(bx - 1), float(cy + 3), 6.0, True, "The vault opens from the booth's console");
        } else {
            key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.booth, side, 0, [2, bx - 6], [base3_foe(dice, self.danger, True), base3_foe(dice, self.danger)]);
            spawn_in(build, dice, self.danger, console, [[3.5, 3.5], [3.5, float(side) - 3.5]], 0, 0.0);
        }
        spawn_in(build, dice, self.danger, build.touch(float(bx - 3), float(cy - 1), float(self.booth), float(bx), float(cy + 2), float(self.booth + 6)), [[float(self.long) - 2.5, 2.5]], self.booth, 180.0);
        build.foe(float(self.long) - 2.5, float(side) - 2.5, self.booth, base3_foe(dice, self.danger), 180.0);
        build.foe(3.5, 3.0, 0, "monster_soldier", 0.0, patrol=[[3.5, 3.0], [float(bx) - 5.5, 3.0]]);
        spark_timer(build, float(self.long) - 1.1, float(cy) - 2.5, float(self.booth) + 2.0, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        crates(build, [[bx - 4, 1]], 0);
        build.foe(float(self.long) - 3.0, 2.5, self.booth, "monster_soldier", 90.0, patrol=[[float(self.long) - 3.0, 2.5], [float(self.long) - 3.0, float(side) - 2.5]]);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "The key is held here");
    }
}

"""The end: a door, a landing over a hall below, a stair (or a lift) down
to the way out."""
node CommExit(Prefab) {
    has key: str = "",
        deep: int = 7,
        by_lift: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Comm exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BASE3;
        self.district = level_district(BASE3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(6, 8);
        self.by_lift = dice.chance(0.4);
        self.tall = dice.between(10, 12);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        below = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(below, 0);
        build.doorway(hall, self.enter);
        build.widen(below, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The landing inside the door, a gantry on from it along the +y wall
        # over the hall below.
        build.solid(wall + 1, 1, low, wall + 3, self.wide - 1, 0);
        build.solid(wall + 3, self.wide - 4, -1, self.long - 1, self.wide - 1, 0);
        if self.by_lift {
            build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "200"}, float(wall + 3), float(middle - 2), -0.5, float(wall + 6), float(middle + 1), 0.0, kit_of(build.district).step);
            for y in range(middle - 2, middle + 1) {
                build.keep(below, wall + 2, y, 0);
            }
        } else {
            stair(build, wall + 2 + self.deep, middle - 2, low, 2, self.deep, 4);
        }
        build.way_out(float(self.long) - 3.5, float(middle), low);
        into = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        into +>:Fires:+> build.objective("Locate the unit's exit");
        spawn_in(build, dice, self.danger, into, [[float(self.long) - 4.5, 3.5], [float(self.long) - 7.5, float(middle) + 3.5]], low, 180.0, True);
        spawn_in(build, dice, self.danger, into, [[float(self.long) - 3.5, float(self.wide) - 2.5]], 0, 180.0);
        blast_chain(build, into, [[float(self.long) - 6.5, 3.5, float(low + 3)], [float(self.long) - 3.5, float(self.wide) - 6.5, float(low + 2)]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, base3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(2.5, 2.5, 0, "monster_soldier", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        spark_timer(build, float(self.long) - 1.1, float(middle) - 3.5, float(low) + 3.0, 2, 4.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        crates(build, [[self.long - 2, 2], [wall + 5, 2]], low);
        build.foe(float(wall) + 6.5, 3.5, low, "monster_soldier", 0.0, patrol=[[float(wall) + 6.5, 3.5], [float(self.long) - 3.5, 3.5]]);
    }
}

"""base3's stretches: [name, role]."""
glob BASE3_STRETCHES: list[list[str]] = [
         ["dish", "start"],
         ["shaft", "flow"],
         ["flooded", "flow"],
         ["control", "hub"],
         ["control", "flow"],
         ["booth", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of base3's stretches by its name."""
def make_base3(name: str, key: str) -> Prefab {
    if name == "dish" {
        return DishYard();
    }
    if name == "shaft" {
        return DescentShaft();
    }
    if name == "flooded" {
        return FloodedLevel();
    }
    if name == "control" {
        return ControlCenter();
    }
    if name == "booth" {
        return DishBooth(key=key if key else "key_silver");
    }
    return CommExit(key=key);
}
