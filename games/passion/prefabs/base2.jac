"""Prefabs drawn from Quake II's base2, the Installation: the sewer tunnels
under it, halls of steel behind blast doors, a lobby under a gallery, a
pump room's catwalks over its machine floor, a reactor in a pit bridged
to, the key in a server room of racks, the airlock at the end of the unit.
Raised in base2's own palette.

- `SewerEntry`: the start. A flooded channel down a sewer tunnel,
  walkways along both sides, catwalks across it and a gallery high along
  one wall; the help computer says to use the tunnels to get into the
  installation. Charges go off along the channel as the player crosses,
  guards appear on the far walkway, a button by the far door opens the way
  on, a stash behind a panel breaks open when shot (a secret).
- `InstallationLobby`: a lobby, a gallery round two of its walls up a
  stair; guards appear on the gallery as the player climbs, and a button
  up there opens the lobby's doors below. A start as well as a stretch
  passed through.
- `BlastCorridor`: a corridor shut across by two blast doors, a catwalk
  along its wall over them up a stair; the first opens by its button and
  sets charges off, the second by a button high over it, shot; guards
  appear on the catwalk and behind the second door.
- `PumpRoom`: a catwalk round the walls high over a machine floor and its
  channel, a lift down (or a stair); guards appear below as the player
  starts down; pipes broken open when shot hide a stash; ways on from the
  catwalk and the floor below.
- `ReactorRing`: a reactor column in a pit, bridges from the floor round
  it out to the column's foot (one drawn out by a shot button in some
  seeds), a lift or a stair up out of the pit; guards appear in the pit
  as the player crosses and charges go off on the column (a hub).
- `ServerRacks`: the key room. Rows of racks across a room, a catwalk over
  them, the key at its far end; taking it opens the closets and brings
  guards in.
- `InstallationExit`: the end. A door (a key's, as a gate), an airlock
  whose inner door a button opens a moment later, charges going off in
  the bay beyond as it opens, guards appearing there, a gantry over the
  bay, and the way out ("This is the end of the unit")."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, pillars, key_ambush }
import from .e4m6 { flood, onward_ports, port_door, pool_steps, told }

glob BASE2: str = "q2:base2";

"""Sparks out of (x, y), `z` lifts up, the way `direction` goes, every
`seconds` or so."""
def spark_timer(build: Raising, x: float, y: float, z: float, direction: int, seconds: float) {
    build.timer(seconds) +>:Fires:+> build.sparks(x, y, z, direction);
}

"""Charges at `points` ([x, y, z] each), going off one after another when
`cue` fires."""
def blast_chain(build: Raising, cue: Cue, points: list[list[float]]) {
    for (index, at) in enumerate(points) {
        late = build.delay(0.1 + 0.3 * float(index));
        cue +>:Fires:+> late;
        late +>:Fires:+> build.explosion(at[0], at[1], at[2]);
    }
}

"""Guards that appear at `spots` ([x, y] each) on lift `z` when `cue`
fires (Quake II's trigger-spawned foes), facing `angle`."""
def spawn_in(build: Raising, dice: Stream, danger: float, cue: Cue, spots: list[list[float]], z: int, angle: float, heavy: bool = False) {
    wave = build.waiting();
    cue +>:Fires:+> wave;
    for (index, at) in enumerate(spots) {
        build.foe(at[0], at[1], z, q2_foe(dice, danger, heavy and index == 0), angle, waits=wave);
    }
}

"""A guard's closet in a block of solid: its door three cells wide, the
cells x..x+3 at y..y+1 facing +y (`face` 1) or x..x+1 at y..y+3 facing +x
(`face` 0), the closet two cells deep behind it, on lift `z`; the door
opens when `cue` fires and the guard appears in it then."""
def guard_closet(build: Raising, dice: Stream, danger: float, x: int, y: int, face: int, cue: Cue, z: int, heavy: bool = False) {
    wave = build.waiting();
    cue +>:Fires:+> wave;
    if face == 1 {
        build.room(x, y - 2, z, x + 3, y, z + 6);
        cue +>:Fires:+> build.opened(float(x), float(y), float(z), float(x + 3), float(y + 1), float(z + 6));
        build.foe(float(x) + 1.5, float(y) - 1.0, z, q2_foe(dice, danger, heavy), 90.0, waits=wave);
    } else {
        build.room(x - 2, y, z, x, y + 3, z + 6);
        cue +>:Fires:+> build.opened(float(x), float(y), float(z), float(x + 1), float(y + 3), float(z + 6));
        build.foe(float(x) - 1.0, float(y) + 1.5, z, q2_foe(dice, danger, heavy), 0.0, waits=wave);
    }
}

"""A stash in a block against the prefab's -y wall at x..x+4 (lifts z..):
a closet behind a panel that breaks when shot, a secret, armor in it."""
def panel_stash(build: Raising, x: int, z: int) {
    build.solid(x, 1, z, x + 4, 4, z + 7);
    build.room(x + 1, 1, z, x + 3, 3, z + 4);
    build.breakable(float(x + 1), 3.0, float(z), float(x + 3), 4.0, float(z + 4), 20);
    build.secret(float(x + 1), 1.0, float(z), float(x + 3), 3.0, float(z + 3));
    build.supply(float(x) + 2.0, 2.0, z, Q2_ARMOR, "q2");
}

"""The start: a flooded channel down a sewer tunnel, walkways, catwalks
across, a gallery high along a wall."""
node SewerEntry(Prefab) {
    has deep: int = 6,
        upper: int = 7,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sewer entry";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(30, 34);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(6, 7);
        self.upper = 7;
        self.tall = self.upper + dice.between(7, 8);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=3, along=float(self.long - 3), floor=0),
            Port(face=1, along=float(self.long - 5), floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        sewer = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(sewer, self.upper);
        x0 = 9;
        x1 = self.long - 6;
        # The channel, steps up out of it at its near end.
        build.pool(x0, cy - 3, -self.deep, x1, cy + 3, 0, 2, False, False);
        pool_steps(build, x0, cy - 3, self.deep, 2);
        pool_steps(build, x0, cy + 1, self.deep, 2);
        # Two catwalks across it.
        xa = x0 + (x1 - x0) // 3;
        xb = x0 + 2 * (x1 - x0) // 3;
        for x in [xa, xb] {
            build.solid(x, cy - 3, -1, x + 3, cy + 3, 0);
            for dx in range(3) {
                build.keep(sewer, x + dx, cy - 4, 0);
                build.keep(sewer, x + dx, cy + 3, 0);
            }
        }
        # The gallery high along the +y wall, up a stair from the near floor.
        build.solid(x0, self.wide - 4, self.upper - 1, self.long - 1, self.wide - 1, self.upper);
        stair(build, x0 - self.upper, self.wide - 4, 0, 0, self.upper, 3);
        for y in range(self.wide - 4, self.wide - 1) {
            build.keep(sewer, x0 - 1, y, self.upper);
        }
        build.doorway(sewer, self.enter);
        for port in self.taken {
            build.doorway(sewer, port);
        }
        # The help computer, and its relays winding on.
        told_in = build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0);
        told_in +>:Fires:+> build.objective("Use the sewer tunnels to gain access to the installation");
        chain = told_in;
        for seconds in [1.0, 1.0, 3.0] {
            late = build.delay(seconds);
            chain +>:Fires:+> late;
            chain = late;
        }
        chain +>:Fires:+> build.sparks(float(x0) + 0.5, 1.1, 4.0, 1);
        # Crossing the first catwalk sets charges off along the channel and
        # brings guards onto the far walkway.
        first = build.touch(float(xa), float(cy - 3), 0.0, float(xa + 3), float(cy + 3), 6.0);
        blast_chain(build, first, [[float(xa + 4), float(cy) + 0.5, -2.0], [float(xa + 7), float(cy) - 1.5, -2.0], [float(xb + 3), float(cy) + 1.5, -2.0]]);
        spawn_in(build, dice, self.danger, first, [[float(xb) + 1.5, 2.5], [float(xb) + 4.5, 2.5], [float(x1) - 2.5, float(self.wide) - 6.5]], 0, 180.0);
        second = build.touch(float(xb), float(cy - 3), 0.0, float(xb + 3), float(cy + 3), 6.0);
        spawn_in(build, dice, self.danger, second, [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 6.5]], 0, 180.0, True);
        spawn_in(build, dice, self.danger, second, [[float(xb) + 2.5, float(self.wide) - 2.5]], self.upper, 180.0);
        # The far door: the ways on along the floor open by the button by it.
        press = build.push(float(self.long - 1), 3.5, 1.5, 2);
        for port in onward_ports(self) {
            if port.floor == 0 {
                press +>:Fires:+> port_door(build, self, port);
            }
        }
        build.touch(float(x1), 1.0, 0.0, float(self.long - 1), float(self.wide - 1), 6.0, True, "This door is opened by the button beside it");
        if self.danger > 0.3 {
            build.foe(float(x0 + 4) + 0.5, float(cy) + 0.5, 1 - self.deep, "monster_flipper", 0.0);
        }
        build.foe(float(x0) + 1.5, 2.5, 0, "monster_soldier", 0.0, patrol=[[float(x0) + 1.5, 2.5], [float(x1) - 1.5, 2.5]]);
        spark_timer(build, float(xa) + 1.5, float(self.wide) - 1.1, 3.0, 3, 4.0);
        spark_timer(build, float(x1) - 0.5, 1.1, 3.0, 1, 5.0);
        panel_stash(build, 2, 0);
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(4.5, float(cy) + 0.5, 0, "ammo_shells", "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x1) - 2.5, float(self.wide) - 2.5, self.upper, "ammo_bullets", "q2");
    }
}

"""A lobby, a gallery round two walls up a stair; a button on the gallery
opens the doors below."""
node InstallationLobby(Prefab) {
    has gallery: int = 6,
        opening: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation lobby";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(24, 26);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(7, 8);
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
        # The button on the gallery opens the lobby's doors below.
        press = build.push(float(self.long - 1), float(self.wide) - 6.5, float(self.gallery) + 1.5, 2);
        for port in onward_ports(self) {
            if port.floor == 0 {
                press +>:Fires:+> port_door(build, self, port);
            }
        }
        # Guards' closets in a block along the -y wall open with the button.
        bx0 = self.long // 2 + 4;
        if bx0 + 4 < self.long - 5 {
            build.solid(bx0, 1, 0, self.long - 5, 4, 8);
            for x in range(bx0 + 1, self.long - 8, 4) {
                guard_closet(build, dice, self.danger, x, 3, 1, press, 0);
            }
        }
        build.touch(float(self.long - 8), float(self.wide - 8), 0.0, float(self.long - 4), float(self.wide - 4), 6.0, True, "The doors are opened from the gallery");
        # Coming in, the objective moves on; at the stair's top, guards
        # appear along the gallery.
        into = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 8.0);
        into +>:Fires:+> build.objective("Reach the installation's inner halls" if self.opening else "Open the lobby's doors from the gallery");
        top = build.touch(float(self.long - 7), float(self.wide - 7), float(self.gallery), float(self.long - 4), float(self.wide - 4), float(self.gallery + 6));
        spawn_in(build, dice, self.danger, top, [[8.5, float(self.wide) - 2.5], [12.5, float(self.wide) - 2.5], [float(self.long) - 2.5, 7.5]], self.gallery, 0.0);
        late = build.delay(2.0);
        top +>:Fires:+> late;
        spawn_in(build, dice, self.danger, late, [[float(self.long // 2) + 0.5, 3.5]], 0, 90.0, True);
        spark_timer(build, float(self.long) - 1.1, 3.5, 3.0, 2, 4.0);
        spark_timer(build, 6.5, float(self.wide) - 4.9, float(self.gallery) - 2.0, 3, 6.0);
        panel_stash(build, 4, 0);
        if self.opening {
            build.start(2.5, float(middle) + 0.5, 0, 0.0);
            build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(middle) - 2.5, 0, q2_foe(dice, self.danger), 180.0);
        }
        build.foe(7.5, float(middle) + 1.5, 0, "monster_soldier", 0.0, patrol=[[7.5, float(middle) + 1.5], [float(self.long) - 9.5, float(middle) + 1.5]]);
        build.supply(float(self.long) - 2.5, 7.5, self.gallery, Q2_HEALTH, "q2");
    }
}

"""A corridor shut across by two blast doors, a catwalk along its wall
over them up a stair at its near end."""
node BlastCorridor(Prefab) {
    has walk: int = 6,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Blast corridor";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(30, 34);
        self.wide = dice.between(13, 15);
        self.walk = dice.between(6, 7);
        self.tall = self.walk + 8;
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
        # The catwalk along the +y wall, a stair up to it at the near end;
        # drops off it near its far end.
        build.solid(1 + self.walk, cw, self.walk - 1, self.long - 1, self.wide - 1, self.walk);
        stair(build, 1, cw, 0, 0, self.walk, 3);
        for x in range(self.long - 7, self.long - 3) {
            build.keep(corridor, x, cw, self.walk);
        }
        # The blast doors across the corridor below the catwalk.
        da = self.long // 3;
        db = 2 * self.long // 3;
        doors: list[Cue] = [];
        for x in [da, db] {
            build.solid(x, 1, 0, x + 1, cw, self.tall);
            build.widen(corridor, x, middle - 2, 0, x + 1, middle + 2, 6);
            doors.append(build.opened(float(x), float(middle - 2), 0.0, float(x + 1), float(middle + 2), 6.0));
        }
        # The first opens by its button and sets charges off beyond; the
        # second by the button high over it, shot.
        first = build.push(float(da), 1.5, 1.5, 2);
        first +>:Fires:+> doors[0];
        blast_chain(build, first, [[float(da) + 2.5, float(middle) + 0.5, 4.0], [float(da) + 5.5, float(middle) - 1.5, 4.0], [float(db) - 2.5, float(middle) + 1.5, 4.0]]);
        spawn_in(build, dice, self.danger, first, [[float(da) + 3.5, float(self.wide) - 2.5], [float(db) + 2.5, float(self.wide) - 2.5]], self.walk, 180.0);
        build.solid(da + 3, 1, 0, db - 2, 4, self.walk - 1);
        for x in range(da + 4, db - 5, 4) {
            guard_closet(build, dice, self.danger, x, 3, 1, first, 0);
        }
        second = build.push(float(db), float(middle) + 0.5, 8.0, 2, True);
        second +>:Fires:+> doors[1];
        spawn_in(build, dice, self.danger, second, [[float(db) + 3.5, float(middle) + 0.5], [float(db) + 6.5, float(middle) - 1.5]], 0, 180.0, True);
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(corridor, port);
        }
        build.foe(float(da) + 2.5, float(middle) + 0.5, 0, "monster_soldier", 0.0, patrol=[[float(da) + 2.5, float(middle) + 0.5], [float(db) - 2.5, float(middle) + 0.5]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 4, q2_foe(dice, self.danger, False, True), 180.0);
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, self.walk, q2_foe(dice, self.danger), 180.0);
        build.touch(1.0, 1.0, 0.0, 4.0, float(cw), 6.0, True, "The blast doors open from their buttons");
        spark_timer(build, float(db) - 0.1, 1.5, 4.0, 2, 3.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(self.wide) - 2.5, self.walk, "ammo_bullets", "q2");
    }
}

"""A catwalk round the walls high over a machine floor and its channel, a
lift (or a stair) down; ways on from the catwalk and the floor below."""
node PumpRoom(Prefab) {
    has deep: int = 12,
        by_stair: bool = False,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump room";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(10, 12);
        self.by_stair = dice.chance(0.4);
        self.tall = dice.between(9, 11);
        self.low = -self.deep - 3;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=4.0, floor=-self.deep),
            Port(face=1, along=float(self.long - 8), floor=-self.deep),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.deep;
        pump = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pump, 0);
        # The catwalk round the walls, four cells wide, a slab high over the
        # floor.
        c = 5;
        build.solid(1, 1, -1, self.long - 1, c, 0);
        build.solid(1, self.wide - c, -1, self.long - 1, self.wide - 1, 0);
        build.solid(1, c, -1, c, self.wide - c, 0);
        build.solid(self.long - c, c, -1, self.long - 1, self.wide - c, 0);
        # The machine floor's channel, and its machines.
        build.pool(c + 5, middle - 2, low - 2, self.long - c - 3, middle + 2, low, 2, False, True, True);
        for (index, x) in enumerate(range(c + 4, self.long - c - 4, 5)) {
            build.solid(x, c + 1, low, x + 2, c + 3, low + 3 + index % 2);
            build.solid(x, self.wide - c - 3, low, x + 2, self.wide - c - 1, low + 3 + (index + 1) % 2);
        }
        # Down: a lift from the catwalk's inner edge, or a stair along the -x
        # wall under the catwalk.
        lx = self.long - c - 3;
        if self.by_stair {
            stair(build, c, c, low, 1, self.deep, 3);
            for x in range(c, c + 3) {
                build.keep(pump, x, c - 1, 0);
            }
            top_x = float(c) + 1.5;
        } else {
            build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "200"}, float(lx), float(c), -0.5, float(lx + 3), float(c + 3), 0.0, kit_of(build.district).step);
            for x in range(lx - 1, lx + 4) {
                build.keep(pump, x, c - 1, 0);
            }
            top_x = float(lx) + 1.5;
        }
        build.doorway(pump, self.enter);
        for port in self.taken {
            build.doorway(pump, port);
        }
        # Starting down, guards appear on the machine floor.
        if self.by_stair {
            start_down = build.touch(float(c - 3), float(c + self.deep - 3), 0.0, float(c), float(c + self.deep), 6.0);
        } else {
            start_down = build.touch(top_x - 2.0, float(c - 2), 0.0, top_x + 2.0, float(c), 6.0);
        }
        spawn_in(build, dice, self.danger, start_down, [[float(self.long // 2) + 0.5, 3.0], [float(self.long) - 8.5, float(self.wide) - 3.0], [8.5, 3.0]], low, 90.0, True);
        build.solid(1, middle - 4, low, 4, middle + 4, low + 7);
        for y in [middle - 4, middle] {
            guard_closet(build, dice, self.danger, 3, y, 0, start_down, low);
        }
        lower = build.push(float(self.long - 1), float(middle) - 2.5, float(low) + 1.5, 2);
        for port in onward_ports(self) {
            if port.floor < 0 {
                lower +>:Fires:+> port_door(build, self, port);
            }
        }
        build.touch(float(self.long - 6), float(middle - 5), float(low), float(self.long - 1), float(middle), float(low + 6), True, "The lower doors open from the button on the end wall");
        # A machine block under the catwalk's corner, a panel in its face
        # broken open when shot, a stash behind it.
        build.solid(self.long - 6, self.wide - c - 5, low, self.long - 1, self.wide - c, low + 6);
        build.room(self.long - 5, self.wide - c - 4, low, self.long - 1, self.wide - c - 1, low + 4);
        build.breakable(float(self.long - 6), float(self.wide - c - 4), float(low), float(self.long - 5), float(self.wide - c - 1), float(low + 4), 25);
        build.secret(float(self.long - 5), float(self.wide - c - 4), float(low), float(self.long - 1), float(self.wide - c - 1), float(low + 3));
        build.supply(float(self.long) - 2.5, float(self.wide - c) - 2.5, low, Q2_ARMOR, "q2");
        spark_timer(build, float(c + 4) + 1.0, float(c + 3) - 0.1, float(low) + 2.0, 1, 3.0);
        spark_timer(build, float(self.long - c - 6) + 1.0, float(self.wide - c - 3) + 0.1, float(low) + 2.0, 3, 5.0);
        build.foe(float(c) + 4.5, 3.0, low, "monster_soldier", 0.0, patrol=[[float(c) + 4.5, 3.0], [float(self.long - c) - 4.5, 3.0]]);
        build.foe(float(self.long // 2) + 0.5, 2.5, 0, q2_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 0.5, 0, q2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) - 2.5, 2.5, low, "ammo_bullets", "q2");
    }
}

"""A reactor column in a pit, bridges from the floor round it out to the
column's foot."""
node ReactorRing(Prefab) {
    has deep: int = 6,
        drawn_bridge: bool = False,
        lift_out: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Reactor ring";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(26, 28);
        self.deep = dice.between(6, 7);
        self.drawn_bridge = dice.chance(0.4);
        self.lift_out = dice.chance(0.5);
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
        # The pit round the column, a stair up out of it in one corner and a
        # stair or a lift in the other.
        build.widen(hall, 6, 6, low, self.long - 6, self.wide - 6, 0);
        build.solid(cx - 2, cy - 2, low, cx + 2, cy + 2, self.tall);
        stair(build, 6 + self.deep - 1, 6, low, 2, self.deep, 3);
        if self.lift_out {
            build.put_box({"classname": "func_plat", "height": str(self.deep * 16), "speed": "200"}, float(self.long - 9), float(self.wide - 9), -0.5, float(self.long - 6), float(self.wide - 6), 0.0, kit_of(build.district).step);
            for x in range(self.long - 9, self.long - 6) {
                build.keep(hall, x, self.wide - 6, 0);
            }
        } else {
            stair(build, self.long - 6 - self.deep, self.wide - 9, low, 0, self.deep, 3);
        }
        # Bridges from the west and east floors to the column's foot, the
        # east one drawn out by a shot button on the column in some seeds.
        build.solid(6, cy - 2, -1, cx - 2, cy + 2, 0);
        if self.drawn_bridge {
            shot = build.push(float(cx + 2), float(cy) + 0.5, 6.0, 0, True);
            shot +>:Fires:+> build.drawn(float(cx + 2), float(cy - 2), float(self.long - 6), float(cy + 2), 0, self.deep + 1);
        } else {
            build.solid(cx + 2, cy - 2, -1, self.long - 6, cy + 2, 0);
        }
        for y in range(cy - 2, cy + 2) {
            build.keep(hall, 5, y, 0);
            build.keep(hall, self.long - 6, y, 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Crossing to the column, guards appear in the pit and charges go off
        # up the column.
        crossing = build.touch(float(cx - 5), float(cy - 2), 0.0, float(cx - 2), float(cy + 2), 6.0);
        spawn_in(build, dice, self.danger, crossing, [[8.5, float(cy) + 5.5], [float(self.long) - 8.5, float(cy) - 5.5], [float(cx) + 0.5, 8.5]], low, 90.0);
        blast_chain(build, crossing, [[float(cx) - 2.5, float(cy) - 2.5, 8.0], [float(cx) + 2.5, float(cy) + 2.5, 12.0]]);
        crossing +>:Fires:+> build.objective("Destroy the reactor's guards and press on", False);
        build.solid(1, self.wide - 8, 0, 4, self.wide - 1, 8);
        guard_closet(build, dice, self.danger, 3, self.wide - 7, 0, crossing, 0, True);
        guard_closet(build, dice, self.danger, 3, self.wide - 4, 0, crossing, 0);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "The reactor's column is guarded");
        for (index, side) in enumerate([[float(cx) - 2.1, float(cy) + 1.0, 2], [float(cx) + 2.1, float(cy) - 1.0, 0], [float(cx) + 1.0, float(cy) + 2.1, 1]]) {
            spark_timer(build, side[0], side[1], 4.0 + float(index) * 3.0, int(side[2]), 3.0 + float(index));
        }
        for index in range(dice.between(2, 3)) {
            build.foe(3.5 + float(index) * (float(self.long) - 7.0), 3.5, 0, q2_foe(dice, self.danger, index == 0), 90.0);
        }
        build.foe(6.5, float(self.wide) - 3.5, 0, "monster_soldier", 0.0, patrol=[[6.5, float(self.wide) - 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]]);
        build.supply(float(cx) + 3.0, float(cy) + 0.5, 0, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q2_HEALTH, "q2");
        build.supply(8.5, 8.5, low, "ammo_grenades", "q2");
    }
}

"""Rows of racks across a room, a catwalk over them, the key at its far
end; taking it opens the closets and brings guards in."""
node ServerRacks(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        walk: int = 8,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Server racks (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.walk = 8;
        self.tall = self.walk + dice.between(6, 7);
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
        build.level(room, self.walk);
        build.doorway(room, self.enter);
        # The racks: rows across the room, a gap at alternate ends; one of
        # them breaks open when shot.
        for (index, x) in enumerate(range(5, self.long - 4, 4)) {
            if index % 2 == 0 {
                build.solid(x, 5, 0, x + 1, side - 3, 6);
            } else {
                build.solid(x, 6, 0, x + 1, side - 3, 6);
                build.breakable(float(x), float(side - 3), 0.0, float(x + 1), float(side), 6.0, 15);
            }
        }
        # The catwalk along the -y wall over the racks' ends, up a stair.
        build.solid(1 + self.walk, 1, self.walk - 1, self.long - 1, 4, self.walk);
        stair(build, 1, 1, 0, 0, self.walk, 3);
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0, side, 0, [1], [q2_foe(dice, self.danger, True)]);
        # Guards brought in as the key is taken.
        taken = build.touch(float(self.long - 4), float(cy - 2), 0.0, float(self.long - 1), float(cy + 3), 6.0);
        spawn_in(build, dice, self.danger, taken, [[6.5, float(cy) + 0.5], [3.5, float(side) - 2.5]], 0, 0.0);
        spawn_in(build, dice, self.danger, taken, [[float(self.long // 2) + 0.5, 2.5]], self.walk, 0.0);
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0) +>:Fires:+> build.objective("Take the key from the server room");
        spark_timer(build, 5.5, float(side) - 3.0, 4.0, 3, 3.5);
        spark_timer(build, 9.5, 6.1, 3.0, 1, 5.0);
        build.foe(float(self.long) - 2.5, 2.5, 0, q2_foe(dice, self.danger), 180.0);
        build.foe(3.5, float(cy) + 0.5, 0, "monster_soldier", 0.0, patrol=[[3.5, float(cy) + 0.5], [3.5, float(side) - 2.5]]);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 2.5, self.walk, "ammo_bullets", "q2");
    }
}

"""The end: a door, an airlock whose inner door a button opens, the bay
beyond and the way out."""
node InstallationExit(Prefab) {
    has key: str = "",
        gantry: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Installation exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BASE2;
        self.district = level_district(BASE2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.gantry = dice.chance(0.7);
        self.tall = dice.between(13, 15);
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
        lock = wall + 6;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        airlock = build.room(wall + 1, middle - 3, 0, lock, middle + 3, 8, variant=dice.below(3));
        bay = build.room(lock + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(airlock, wall, middle - 2, 0, wall + 1, middle + 2, 7);
        build.widen(bay, lock, middle - 2, 0, lock + 1, middle + 2, 7);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 7.0, {"key": self.key, "wait": "-1"});
        }
        # The inner door, opened a moment after the airlock's button.
        inner = build.opened(float(lock), float(middle - 2), 0.0, float(lock + 1), float(middle + 2), 7.0);
        press = build.push(float(lock), float(middle) + 2.5, 1.5, 2);
        cycle = told(build, 3.5, "The airlock is cycling");
        press +>:Fires:+> cycle;
        cycle +>:Fires:+> inner;
        # As it opens, charges go off in the bay and guards appear there.
        blast_chain(build, cycle, [[float(lock) + 4.5, 3.5, 3.0], [float(lock) + 7.5, float(self.wide) - 3.5, 3.0], [float(self.long) - 4.5, 4.5, 6.0], [float(self.long) - 6.5, float(self.wide) - 4.5, 2.0]]);
        spawn_in(build, dice, self.danger, cycle, [[float(lock) + 5.5, float(middle) + 3.5], [float(self.long) - 5.5, 5.5]], 0, 180.0, True);
        build.solid(lock + 3, 1, 0, self.long - 4, 4, 8);
        for x in range(lock + 4, self.long - 7, 4) {
            guard_closet(build, dice, self.danger, x, 3, 1, cycle, 0);
        }
        build.touch(float(wall + 1), float(middle - 3), 0.0, float(wall + 3), float(middle + 3), 6.0, True, "Press the button to cycle the airlock");
        # The gantry along the bay's +y wall over its floor, up a stair.
        if self.gantry {
            build.solid(lock + 1 + 6, self.wide - 4, 5, self.long - 1, self.wide - 1, 6);
            stair(build, lock + 1, self.wide - 4, 0, 0, 6, 3);
            spawn_in(build, dice, self.danger, cycle, [[float(self.long) - 3.5, float(self.wide) - 2.5]], 6, 180.0);
        }
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        build.touch(float(self.long - 6), float(middle - 3), 0.0, float(self.long - 1), float(middle + 3), 6.0, True, "This is the end of the unit");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(2.5, 2.5, 0, "monster_soldier", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        spark_timer(build, float(wall + 1) + 0.1, float(middle) - 2.0, 4.0, 0, 3.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""base2's stretches: [name, role]."""
glob BASE2_STRETCHES: list[list[str]] = [
         ["sewer", "start"],
         ["lobby_start", "start"],
         ["lobby", "flow"],
         ["corridor", "flow"],
         ["pump", "flow"],
         ["pump", "hub"],
         ["reactor", "hub"],
         ["reactor", "flow"],
         ["racks", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of base2's stretches by its name."""
def make_base2(name: str, key: str) -> Prefab {
    if name == "sewer" {
        return SewerEntry();
    }
    if name == "lobby_start" {
        return InstallationLobby(opening=True);
    }
    if name == "lobby" {
        return InstallationLobby();
    }
    if name == "corridor" {
        return BlastCorridor();
    }
    if name == "pump" {
        return PumpRoom();
    }
    if name == "reactor" {
        return ReactorRing();
    }
    if name == "racks" {
        return ServerRacks(key=key if key else "key_silver");
    }
    return InstallationExit(key=key);
}
