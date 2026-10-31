"""Prefabs drawn from e3m3, the Tomb of Terror: a tomb behind its facade,
doors "opened elsewhere", plates in the floor that bring the dead and
scrags in by teleporter, a gate a plate holds open for a while across a
trench of lava ridden over on a platform, spikes shot up out of the floor
as the player passes, chambers joined only by teleporters, and the
silver key on a ledge teleported up to. Raised in e3m3's own palette.

- `TombFacade`: the start. A court under the sky, the tomb's facade
  across its far end, its door up a stair on a plinth, shut until a
  button high on the facade is shot ("This door is opened elsewhere."); a
  balcony over the door off the facade's top, reached up a stair along
  the court's north wall. A plate in the court brings scrags in.
- `TimedGate`: a trench of lava across a hall, a platform riding to and
  fro over it (and in some stones a jump apart), a gate beyond held open
  a while by a plate on either side of it (e3m3's doors a plate opens for
  some seconds); a walkway high along the wall back over the lava.
- `SpikeHall`: a causeway down a flooded hall, shooting spikes up a moment
  after the player steps by, ribs off it over the water to crypts of the
  dead, a gallery over the water ridden up to by a lift, a hell knight
  brought in as the player passes its middle.
- `TombNave`: a nave, a channel of water down its middle, galleries along
  both sides up stairs at the far end and bridged at the near; a plate on
  the floor brings the dead in, and a way on is opened by a button on a
  gallery (a hub).
- `TeleportMaze`: three chambers walled off from each other, a teleporter
  from each to the next and one from the last back to the first, a pool
  of lava in the middle one; arriving brings the dead in.
- `SilverSepulchre`: the key room. A sepulchre, the key on a ledge high
  on its far wall reached by a teleporter and dropped from; taking it
  opens the closets and brings hell knights in.
- `TombExit`: the end. A door (a key's, as a gate) into a crypt, crypts in
  its wall opening on the dead as the player comes in, the slipgate sunk
  down three steps at its far end."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires, RockWant }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix }
import from .common { stair, pillars, lift }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_stash, e2m4_closets }
import from .e2m7 { e2m7_plate }
import from .e3_parts { ridged_bed }

glob E3M3: str = "q1:e3m3";

"""e3m3's foes: the dead and ogres, scrags, hell knights deeper in."""
glob E3M3_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_ogre", "monster_wizard", "monster_zombie"], strong=["monster_hell_knight"], heavy_light=["monster_hell_knight", "monster_ogre"], heavy_strong=["monster_demon1"]);

"""A gate a plate holds open for a while: a door of the prefab's cells
x0..x1, y0..y1 from lift `z`, `high` lifts tall, that sinks into the floor
when its cue fires and comes back up `seconds` later; rock under it."""
def e3m3_timed(build: Raising, x0: float, y0: float, x1: float, y1: float, z: int, high: int, seconds: int) -> Cue {
    fields = {"classname": "func_door", "angle": "-2", "speed": "80", "wait": str(seconds), "lip": "2"};
    build.put_box(fields, x0, y0, float(z), x1, y1, float(z + high), kit_of(build.district).door);
    corners = build.box_units(x0, y0, float(z - high), x1, y1, float(z));
    build.rocks.append(RockWant(low=corners[0], high=corners[1]));
    build.casting.doors += 1;
    return build.cue([fields], "gate");
}

"""Spikes shot straight up out of the floor at the prefab's cell points
`spots` ([x, y] each) on lift `z`, all fired by one cue."""
def e3m3_floor_spikes(build: Raising, spots: list[list[float]], z: int) -> Cue {
    items: list[dict[str, str]] = [];
    for spot in spots {
        fields = {"classname": "trap_spikeshooter", "angle": "-1"};
        build.put_point(fields, spot[0], spot[1], float(z) + 0.1, "q1");
        items.append(fields);
    }
    return build.cue(items, "spikes");
}

"""The start: a court, the tomb's facade, its door up a stair on a plinth,
opened elsewhere."""
node TombFacade(Prefab) {
    has plinth: int = 3,
        stash: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb facade";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.plinth = dice.between(3, 4);
        self.stash = dice.chance(0.85);
        self.tall = self.plinth + 9 + dice.between(9, 11);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        top = self.plinth + 9;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.plinth), Port(face=0, along=4.0, floor=top), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        p = self.plinth;
        top = p + 9;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, p);
        build.level(court, top);
        # The facade, solid to its top, its door through it at the plinth's
        # top; a balcony off its top over the door.
        fx = self.long - 7;
        build.solid(fx, 1, 0, self.long - 1, self.wide - 1, top);
        build.widen(court, fx, middle - 2, p, self.long - 1, middle + 2, p + 8);
        build.solid(fx - 5, middle - 4, 0, fx, middle + 4, p);
        stair(build, fx - 5 - p, middle - 2, 0, 0, p, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(court, fx - 5, y, p);
        }
        build.solid(fx - 3, middle - 4, top - 1, fx, middle + 4, top);
        # The stair up the court's north wall to the facade's top.
        stair(build, fx - top, self.wide - 4, 0, 0, top, 3);
        for y in range(self.wide - 4, self.wide - 1) {
            build.keep(court, fx, y, top);
        }
        # Columns along the facade's face.
        for y in range(2, self.wide - 5, 3) {
            if abs(y - middle) > 4 {
                build.solid(fx - 1, y, 0, fx, y + 1, top);
            }
        }
        # The door shut until the button high on the facade is shot.
        shot = build.push(float(fx), float(middle) + 4.5, float(top) - 3.0, 2, True);
        for port in self.taken {
            build.doorway(court, port);
            if port.floor == p {
                shot +>:Fires:+> e2m4_bars(build, float(fx), float(middle - 2), float(fx + 1), float(middle + 2), p, 8, "This door is opened elsewhere.");
            }
        }
        topped = [port for port in self.taken if port.floor == top and port.face == 0];
        # A plate in the court brings scrags in over it.
        plate = e2m7_plate(build, float(fx // 2), float(middle - 1), float(fx // 2 + 2), float(middle + 1), 0);
        for port in topped {
            plate +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, top, 8, "This door is opened elsewhere.");
        }
        late = build.delay(0.5);
        plate +>:Fires:+> late;
        for index in range(dice.between(2, 3)) {
            late +>:Fires:+> build.summon(1 + index * 4, 2, -9, "monster_wizard", float(fx // 2) - 2.5 + float(index) * 3.0, float(middle) + 3.5, 5, 180.0);
        }
        guard = build.waiting();
        plate +>:Fires:+> guard;
        build.foe(float(fx) - 2.0, float(middle) + 0.5, top, E3M3_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        build.foe(float(fx) + 3.5, 3.5, top, E3M3_FOES.pick(dice, self.danger), 90.0, patrol=[[float(fx) + 3.5, 3.5], [float(fx) + 3.5, float(self.wide) - 6.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(fx) - 8.5 + float(index) * 2.0, 3.5 + float(index) * 5.0, 0, E3M3_FOES.pick(dice, self.danger), 180.0);
        }
        if self.stash {
            build.solid(1, self.wide - 6, 0, 7, self.wide - 1, 8);
            e2m4_stash(build, 3, self.wide - 4, 5, self.wide - 1, 0, 3, "item_artifact_super_damage");
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.supply(float(fx) - 3.0, float(self.wide) - 6.5, 0, "item_health");
    }
}

"""A trench of lava across a hall, a platform riding over it, a gate a
plate holds open beyond."""
node TimedGate(Prefab) {
    has stones: bool = True,
        walk: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Timed gate";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(31, 34);
        self.wide = dice.between(20, 23);
        self.stones = dice.chance(0.5);
        self.walk = True;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float((self.wide - 5) // 2);
        self.enter = Port(face=2, along=float((self.wide - 5) // 2), floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        inner = self.wide - 5;
        middle = inner // 2;
        hall = build.room(1, 1, 0, self.long - 1, inner, self.tall, variant=dice.below(3));
        # The trench of lava, seven cells wide; the platform riding over it
        # on its south half, stones a jump apart on its north in some.
        rx = 9;
        build.pool(rx, 1, -6, rx + 7, inner, 0, 4, False, False);
        build.train([3.0, 4.0, 1.0], [[float(rx), 2.0, -1.0], [float(rx + 4), 2.0, -1.0]], 90.0, 2.0);
        for y in range(2, 6) {
            build.keep(hall, rx - 1, y, 0);
            build.keep(hall, rx + 7, y, 0);
        }
        if self.stones {
            for at in [rx + 1, rx + 3, rx + 5] {
                build.solid(at, inner - 6, -6, at + 1, inner - 4, 0);
            }
        }
        # The gate: a wall across the hall with the gate in its middle, a
        # plate on each side holding it open a while.
        gx = self.long - 9;
        build.solid(gx, 1, 0, gx + 1, middle - 2, self.tall);
        build.solid(gx, middle + 2, 0, gx + 1, inner, self.tall);
        build.solid(gx, middle - 2, 8, gx + 1, middle + 2, self.tall);
        gate = e3m3_timed(build, float(gx), float(middle - 2), float(gx + 1), float(middle + 2), 0, 8, 7);
        e2m7_plate(build, float(gx - 4), float(middle - 1), float(gx - 2), float(middle + 1), 0) +>:Fires:+> gate;
        # Beyond the gate the floor stands a step lower.
        build.widen(hall, gx + 1, 3, -1, self.long - 3, inner, 0);
        e2m7_plate(build, float(gx + 2), float(middle - 1), float(gx + 4), float(middle + 1), -1) +>:Fires:+> gate;
        # The walkway high along the north wall from beyond the gate back
        # over the lava, a stair up to it, its near end open to drop from.
        if self.walk {
            build.level(hall, 8);
            build.solid(5, inner - 3, 7, gx, inner, 8);
            lift(build, gx - 4, inner - 6, gx - 1, inner - 3, 0, 8);
            for x in range(gx - 4, gx - 1) {
                build.keep(hall, x, inner - 3, 8);
                build.keep(hall, x, inner - 7, 0);
            }
            for x in range(5, 8) {
                build.keep(hall, x, inner - 4, 8);
            }
            build.foe(10.5, float(inner) - 1.5, 8, "monster_ogre", 0.0, patrol=[[10.5, float(inner) - 1.5], [float(gx) - 2.5, float(inner) - 1.5]]);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What keeps the far side wakes as the gate opens.
        beyond = build.waiting();
        gate +>:Fires:+> beyond;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 4.0, 0, E3M3_FOES.pick(dice, self.danger, index == 0), 180.0, waits=beyond);
        }
        # Closets beyond the gate open with it.
        e2m4_closets(build, [gx + 2, gx + 5], inner, 0, gate, beyond, ["monster_zombie", E3M3_FOES.pick(dice, self.danger, True)]);
        build.foe(float(rx + 9) + 0.5, 3.0, 0, E3M3_FOES.pick(dice, self.danger), 90.0, patrol=[[float(rx + 9) + 0.5, 3.0], [float(rx + 9) + 0.5, float(inner) - 8.5]]);
        build.foe(float(rx + 3) + 0.5, float(middle) + 0.5, 5, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(gx) - 2.5, 2.5, 0, "item_shells");
        build.solid(1, 1, 0, 6, 6, 7);
        e2m4_stash(build, 2, 2, 4, 4, 0, 1, "item_artifact_envirosuit");
        build.supply(float(self.long) - 2.5, float(inner) - 1.5, 0, "item_health");
    }
}

"""A causeway down a flooded hall, ribs off it over the water to crypts in
the south wall, spikes shot up out of the causeway behind the player, a
gallery over the water to the north."""
node SpikeHall(Prefab) {
    has gallery: int = 12,
        deep: int = 7,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike hall";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(21, 23);
        self.deep = dice.between(6, 7);
        self.tall = dice.between(21, 25);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=10.0, floor=0);
        self.leaves = [Port(face=0, along=10.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = self.gallery;
        d = self.deep;
        # The apron and the far landing across the hall's ends, a causeway
        # between them, water to both sides of it.
        x0 = 6;
        x1 = long - 6;
        south = 8;
        north = 13;
        hall = build.room(1, 4, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        build.pool(x0, 4, -d, x1, south, 0, 2, False, False);
        build.pool(x0, north, -d, x1, wide - 1, 0, 2, False, False);
        ridged_bed(build, x0, 4, x1, south, -d, 5);
        ridged_bed(build, x0, north, x1, wide - 1, -d, 4);
        # Steps up out of the water onto the causeway, at both ends of the
        # north side and at the far end of the south.
        stair(build, x1 - d, 6, -d, 0, d, 2);
        stair(build, x1 - d, north, -d, 0, d, 2);
        stair(build, x0 + d - 1, north, -d, 2, d, 2);
        # Off the causeway's edges into the water.
        for x in range(x0 + d + 1, x0 + d + 5) {
            build.keep(hall, x, north - 1, 0);
        }
        for y in range(north + 3, north + 7) {
            build.keep(hall, x0 - 1, y, 0);
        }
        # The gallery over the north water, a lift up at its near end from
        # the apron.
        build.solid(5, wide - 6, g - 1, long - 1, wide - 1, g);
        lift(build, 2, wide - 6, 5, wide - 3, 0, g);
        for y in range(wide - 6, wide - 3) {
            build.keep(hall, 5, y, g);
            build.keep(hall, 1, y, 0);
        }
        # Spikes shot up out of the causeway a moment after the player steps
        # by each stretch.
        for at in range(8, long - 8, 6) {
            stepping = build.touch(float(at), float(south), 0.0, float(at + 2), float(north), 6.0, False);
            late = build.delay(0.8);
            stepping +>:Fires:+> late;
            late +>:Fires:+> e3m3_floor_spikes(build, [[float(at + 3) + 0.5, float(south) + 1.5], [float(at + 3) + 0.5, float(south) + 3.5], [float(at + 4) + 0.5, float(south) + 2.5]], 0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # A hell knight brought in behind the player at the causeway's
        # middle; the crypts open on the dead, a rib over the water from each
        # to the causeway.
        half = build.touch(float(long // 2), float(south), 0.0, float(long // 2 + 2), float(north), 6.0);
        late_knight = build.delay(1.0);
        half +>:Fires:+> late_knight;
        late_knight +>:Fires:+> build.summon(1, 6, -8, "monster_hell_knight" if self.danger > 0.3 else "monster_ogre", float(long // 2) - 5.5, float(south) + 2.5, 0, 0.0);
        dead = build.waiting();
        half +>:Fires:+> dead;
        for (index, at) in enumerate([x for x in [9, 15, 21] if x + 3 < x1 - d]) {
            build.solid(at, 4, -1, at + 3, south, 0);
            crypt = build.room(at, 1, 0, at + 3, 3, 7);
            build.widen(crypt, at, 3, 0, at + 3, 4, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), 3.0, 0.0, float(at + 3), 4.0, 6.0, fields);
            half +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, 2.0, 0, "monster_zombie" if index % 2 == 0 else E3M3_FOES.pick(dice, self.danger), 90.0, waits=dead);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(long) - 3.5, 6.5 + float(index) * 4.0, 0, "monster_zombie" if index > 0 else E3M3_FOES.pick(dice, self.danger), 180.0, waits=dead);
        }
        build.foe(float(long) - 3.5, float(wide) - 3.0, g, E3M3_FOES.pick(dice, self.danger, True), 180.0, patrol=[[float(long) - 3.5, float(wide) - 3.0], [8.5, float(wide) - 3.0]]);
        # Rockets on the bed of the north water.
        build.supply(float(long // 2) + 0.5, float(wide) - 4.5, 1 - d, "item_rockets");
        build.supply(2.5, 5.5, 0, "item_health");
        build.supply(float(long) - 2.5, float(wide) - 3.0, g, "item_health");
    }
}

"""A nave, a channel of water down its middle, galleries along both sides;
a plate brings the dead in; a way on opened by a button on a gallery."""
node TombNave(Prefab) {
    has gallery: int = 9,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb nave";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(19, 22);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, g);
        # The channel down the middle, one footbridge over it, steps out.
        cx0 = 8;
        cx1 = self.long - 8;
        build.pool(cx0, middle - 2, -6, cx1, middle + 2, 0, 2);
        ridged_bed(build, cx0, middle - 2, cx1, middle + 2, -6, 6);
        fx = self.long // 2 - 1;
        build.solid(fx, middle - 2, -1, fx + 3, middle + 2, 0);
        stair(build, cx1 - 6, middle, -6, 0, 6, 2);
        # The aisles a step down from the nave's ends, either side of the
        # water.
        build.widen(nave, 8, 1, -1, self.long - 4 - g, middle - 2, 0);
        build.widen(nave, 8, middle + 2, -1, self.long - 4 - g, self.wide - 1, 0);
        # The galleries, a stair up to each at the far end, a bridge between
        # them at the near end.
        under = g - 1;
        build.solid(1, 1, under, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, under, self.long - 1, self.wide - 1, g);
        stair(build, self.long - 3 - g, 5, 0, 0, g, 2);
        stair(build, self.long - 3 - g, self.wide - 7, 0, 0, g, 2);
        build.solid(3, 5, under, 6, self.wide - 5, g);
        for x in range(self.long - 6, self.long - 2) {
            build.keep(nave, x, 4, g);
            build.keep(nave, x, self.wide - 5, g);
        }
        for x in range(3, 6) {
            build.keep(nave, x, 4, g);
            build.keep(nave, x, self.wide - 5, g);
        }
        # The way on along the floor opened by a button on the south
        # gallery's wall.
        press = build.push(float(self.long // 2) + 4.5, 1.0, float(g) + 1.2, 1);
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
            if port.floor == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "This door is opened elsewhere.");
            }
        }
        # A plate before the footbridge brings the dead in behind; a hell
        # knight with them.
        plate = e2m7_plate(build, float(fx - 6), float(middle + 3), float(fx - 4), float(middle + 5), -1);
        late = build.delay(0.5);
        plate +>:Fires:+> late;
        for index in range(3) {
            late +>:Fires:+> build.summon(1 + index * 4, 1, -8, "monster_zombie" if index > 0 else E3M3_FOES.pick(dice, self.danger, True), 9.5 + float(index) * 2.0, float(middle) - 4.5, 0, 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 5) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, E3M3_FOES.pick(dice, self.danger), 0.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 8) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0, g, E3M3_FOES.pick(dice, self.danger, True), 0.0, patrol=[[float(8 + index * 8) + 0.5, 3.0 if index == 0 else float(self.wide) - 3.0], [float(self.long) - 8.5, 3.0 if index == 0 else float(self.wide) - 3.0]]);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 10, "monster_wizard", 180.0);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(4.5, float(middle) + 0.5, g, "item_rockets");
        # A stash under the north gallery's near end, behind a wall shot open.
        build.solid(1, self.wide - 5, 0, 3, self.wide - 1, g - 1);
        build.solid(3, self.wide - 5, 0, 6, self.wide - 1, g - 1);
        e2m4_stash(build, 2, self.wide - 3, 4, self.wide - 1, 0, 3, "item_artifact_super_damage");
    }
}

"""Three chambers walled off from each other, a teleporter from each to
the next and one from the last back to the first."""
node TeleportMaze(Prefab) {
    has lava: bool = True,
        tall: int = 13;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport maze";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 14);
        self.lava = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=4), Port(face=1, along=float(self.long - 5), floor=4), Port(face=3, along=float(self.long - 5), floor=4)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        a1 = 8;
        b1 = 19;
        # Three chambers on three floors, the middle one sunk, the last
        # raised.
        first = build.room(1, 1, 0, a1, self.wide - 1, self.tall, variant=dice.below(3));
        build.room(a1 + 1, 1, -4, b1, self.wide - 1, self.tall, variant=dice.below(3));
        third = build.room(b1 + 1, 1, 4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        # A pool of lava in the middle chamber's floor, a walk round it, a
        # platform riding to and fro over it.
        if self.lava {
            build.pool(a1 + 4, 4, -10, b1 - 3, self.wide - 4, -4, 4, False, False);
            build.train([3.0, 3.0, 1.0], [[float(a1 + 4), float(middle - 1), -5.0], [float(b1 - 6), float(middle - 1), -5.0]], 60.0, 2.0);
        }
        build.teleporter(float(a1) - 2.0, float(middle) + 3.0, 0, float(a1) + 2.5, float(middle) + 0.5, -4, 0.0);
        build.teleporter(float(b1) - 2.0, 2.5, -4, float(b1) + 2.5, float(middle) + 0.5, 4, 0.0);
        build.teleporter(float(b1) + 2.5, float(self.wide) - 3.0, 4, 3.0, 3.0, 0, 0.0);
        # A button in the middle chamber opens the last's far way on.
        build.solid(b1 - 4, self.wide - 3, -4, b1 - 3, self.wide - 2, -1);
        press = build.push(float(b1 - 4), float(self.wide) - 2.5, -2.8, 2);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(third, port);
            low = port.along - 2.0;
            if port.face == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), low, float(self.long - 1), low + 4.0, 4, 8, "This door is opened elsewhere.");
            } elif port.face == 1 {
                press +>:Fires:+> e2m4_bars(build, low, float(self.wide - 2), low + 4.0, float(self.wide - 1), 4, 8, "This door is opened elsewhere.");
            } else {
                press +>:Fires:+> e2m4_bars(build, low, 1.0, low + 4.0, 2.0, 4, 8, "This door is opened elsewhere.");
            }
        }
        # Arriving in each chamber brings the dead in.
        for (index, at) in enumerate([a1 + 1, b1 + 1]) {
            fz = -4 if index == 0 else 4;
            come = build.touch(float(at), float(middle - 2), float(fz), float(at + 3), float(middle + 3), float(fz + 6));
            late = build.delay(0.5);
            come +>:Fires:+> late;
            late +>:Fires:+> build.summon(1 + index * 4, 2, -8, "monster_zombie" if index == 0 else E3M3_FOES.pick(dice, self.danger, True), float(at) + 1.5, float(middle) + (3.5 if index == 0 else -3.5), fz, 180.0);
            dead = build.waiting();
            come +>:Fires:+> dead;
            build.foe(float(at) + 1.5, float(middle) - 3.5, fz, E3M3_FOES.pick(dice, self.danger), 180.0, waits=dead);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(a1) + 2.5, 2.5 + float(index) * 10.0, -4, E3M3_FOES.pick(dice, self.danger), 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 3.5 + float(index) * 4.0, 4, E3M3_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(4.5, float(self.wide) - 3.5, 0, "monster_zombie", 0.0, patrol=[[4.5, float(self.wide) - 3.5], [4.5, 3.5]]);
        build.supply(float(a1) + 2.5, float(self.wide) - 2.5, -4, "item_health");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 4, "item_spikes");
    }
}

"""The key room: a sepulchre, the key on a ledge high on its far wall
reached by a teleporter; taking it opens the closets."""
node SilverSepulchre(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        ledge: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver sepulchre (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(7, 9);
        self.tall = self.ledge + 8;
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
        k = self.ledge;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, k);
        build.doorway(hall, self.enter);
        lx = self.long - 6;
        build.solid(lx, 1, k - 1, self.long - 1, side, k);
        for y in range(2, side - 1) {
            build.keep(hall, lx, y, k);
        }
        # The floor before the ledge a step down.
        build.widen(hall, 8, 3, -1, lx, side - 1, 0);
        build.teleporter(float(self.long // 2) - 2.0, float(cy) + 0.5, -1, float(self.long) - 3.0, 3.0, k, 90.0);
        for y in [3, side - 4] {
            build.solid(5, y, 0, 8, y + 2, 2);
        }
        # The key; taking it opens the closets and brings hell knights in.
        taken = e2m4_key(build, self.key, float(self.long) - 3.0, float(side) - 3.0, k);
        out = build.waiting();
        taken +>:Fires:+> out;
        e2m4_closets(build, [2, lx - 5], side, 0, taken, out, [E3M3_FOES.pick(dice, self.danger, True), "monster_zombie"]);
        late = build.delay(1.0);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -8, E3M3_FOES.pick(dice, self.danger, True), float(lx) - 2.5, float(cy) + 0.5, 0, 180.0);
        # Spikes up out of the ledge as the player lands on it.
        onto = build.touch(float(self.long - 5), 1.0, float(k), float(self.long - 1), 5.0, float(k + 6));
        late_spikes = build.delay(1.0);
        onto +>:Fires:+> late_spikes;
        late_spikes +>:Fires:+> e3m3_floor_spikes(build, [[float(self.long) - 4.5, float(cy) + 0.5], [float(self.long) - 2.5, float(cy) + 2.5]], k);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, k, E3M3_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 3.0, float(cy) + 0.5], [float(self.long) - 3.0, float(side) - 5.5]]);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door into a crypt, crypts in its wall opening on the dead,
the slipgate sunk down three steps at its far end."""
node TombExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Tomb exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M3;
        self.district = level_district(E3M3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(19, 21);
        self.tall = dice.between(13, 15);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide - 5) // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        inner = self.wide - 5;
        middle = inner // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, inner, 10, variant=dice.below(3));
        crypt = build.room(wall + 1, 1, 0, self.long - 1, inner, self.tall, variant=dice.below(3));
        build.level(crypt, -3);
        build.doorway(hall, self.enter);
        build.widen(crypt, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key);
        }
        sx = self.long - 8;
        build.widen(crypt, sx, 2, -3, self.long - 1, inner - 1, 0);
        stair(build, sx + 2, 2, -3, 2, 3, inner - 3);
        build.way_out(float(self.long) - 3.0, float(middle), -3);
        pillars(build, wall + 3, 2, sx - 1, 3, 0, self.tall, 3, []);
        # The crypts in the north wall open on the dead as the player comes
        # in.
        coming = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        dead = build.waiting();
        coming +>:Fires:+> dead;
        e2m4_closets(build, [x for x in [wall + 2, wall + 7, wall + 12] if x + 3 < sx], inner, 0, coming, dead, ["monster_zombie", E3M3_FOES.pick(dice, self.danger, True)]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E3M3_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 3.5, -3, E3M3_FOES.pick(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m3's stretches: [name, role]."""
glob E3M3_STRETCHES: list[list[str]] = [
         ["facade", "start"],
         ["gate", "flow"],
         ["spikes", "flow"],
         ["maze", "flow"],
         ["nave", "hub"],
         ["nave", "flow"],
         ["sepulchre", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m3's stretches by its name."""
def make_e3m3(name: str, key: str) -> Prefab {
    if name == "facade" {
        return TombFacade();
    }
    if name == "gate" {
        return TimedGate();
    }
    if name == "spikes" {
        return SpikeHall();
    }
    if name == "maze" {
        return TeleportMaze();
    }
    if name == "nave" {
        return TombNave();
    }
    if name == "sepulchre" {
        return SilverSepulchre(key=key if key else "key_silver");
    }
    return TombExit(key=key);
}
