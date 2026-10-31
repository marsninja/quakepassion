"""Prefabs drawn from e3m2, the Vaults of Zin: a castle of vaults behind
door after door, doors that are "opened elsewhere", crypts that open on
the dead as the player walks by, a floor that falls away into a pit of
them, ceilings that slam down, ogres brought in by teleporter when a
plate is stepped on, vaults behind doors that open when shot, and the
gold key caged across a pit of the dead. Raised in e3m2's own palette.

- `ZinGate`: the start. A court of vaults, a ledge along its south wall up
  a stair; the way on through the far wall stays shut ("This door is
  opened elsewhere.") until the button on the ledge is pushed. Walking
  into the court opens the crypts in its north wall on their dead; a door
  in the wall opens on a stash when shot; a teleporter off the ledge's
  end in some.
- `CollapseHall`: a hall over a pit of the dead: the floor across its
  middle falls away as the player steps onto it, dropping into the pit
  (e3m2's floor that drops); in some a bridge over the open pit instead.
  A stair climbs out of the pit along its north wall to the far floor; a
  way on leaves from the pit too.
- `CrusherCorridor`: a corridor, closets along it opening on the dead,
  ceilings over its south half that slam down when anyone walks under
  (e3m2's crushers); the way on at its end opened by a button in a bay.
- `ZinHall`: a great hall, a balcony across its far end reached by a
  teleporter in its middle and dropped from; a plate in its floor brings
  ogres in by teleporter and opens a door elsewhere; vaults behind doors
  that open when shot along its north wall (a hub).
- `ZinVault`: the key room. A pit of the dead across a vault, a bridge
  over it, a stair (or a lift) out of it at each end, a gallery over it; the key in a cage beyond, its
  bars opened by a button down on the pit's floor; taking the key opens
  the closets and brings a fiend in.
- `ZinExit`: the end. A door (the gold door, as a gate) into a chapel,
  the slipgate on a dais between pillars ("Walk through the rune gate"),
  crypts along its walls opening on the dead as the player comes up the
  nave."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix }
import from .common { stair, pillars, lift }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_closets, e2m4_stash }
import from .e2m7 { e2m7_plate }

glob E3M2: str = "q1:e3m2";

"""e3m2's foes: the dead and ogres, scrags, fiends and a shambler deeper
in."""
glob E3M2_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_zombie", "monster_ogre", "monster_wizard"], strong=["monster_ogre"], heavy_light=["monster_ogre", "monster_ogre", "monster_demon1"], heavy_strong=["monster_demon1", "monster_shambler"], heavy_scale=0.7);

"""A door to be shot open: a door of the prefab's cells that rises when
it takes a hit."""
def e3m2_shot_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
    build.rising_door(x0, y0, z0, x1, y1, z1, {"health": "1", "wait": "-1"});
}

"""A ceiling that slams down when its cue fires and rises again, hurting
whoever it comes down on (e3m2's crushers): a block of the prefab's cells
x0..x1, y0..y1 in the ceiling over a way `high` lifts tall from lift
`floor`, coming down to a lift and a half over the floor."""
def e3m2_crusher(build: Raising, x0: float, y0: float, x1: float, y1: float, floor: int, high: int) -> Cue {
    fields = {"classname": "func_door", "angle": "-2", "speed": "250", "wait": "1", "lip": "-8", "dmg": "40"};
    build.put_box(fields, x0, y0, float(floor + high), x1, y1, float(floor + 2 * high - 2), kit_of(build.district).door);
    build.casting.doors += 1;
    return build.cue([fields], "crusher");
}

"""The start: a court of vaults, a ledge up a stair, the way on opened
elsewhere, crypts in the north wall."""
node ZinGate(Prefab) {
    has ledge: int = 9,
        tele: bool = True,
        stash: bool = True,
        lifted: bool = False,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin gate";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(19, 21);
        self.tele = dice.chance(0.8);
        self.stash = dice.chance(0.6);
        self.lifted = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        inner = self.wide - 5;
        self.enter = Port(face=2, along=float(inner // 2), floor=0);
        self.leaves = [Port(face=0, along=float(inner // 2), floor=0), Port(face=3, along=float(self.long - 6), floor=0), Port(face=0, along=3.0, floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        inner = self.wide - 5;
        middle = inner // 2;
        e = self.ledge;
        court = build.room(1, 1, 0, self.long - 1, inner, self.tall, variant=dice.below(3));
        build.level(court, e);
        # The ledge along the south wall, a stair up beside it, the button
        # on a post at its end.
        build.solid(6, 1, e - 1, self.long - 1, 7, e);
        if self.lifted {
            lift(build, 6, 7, 9, 10, 0, e);
            for x in range(6, 9) {
                build.keep(court, x, 6, e);
                build.keep(court, x, 11, 0);
            }
        } else {
            stair(build, 6, 7, 0, 0, e, 3);
            for x in range(e + 3, e + 7) {
                build.keep(court, x, 6, e);
            }
        }
        build.solid(self.long - 4, 2, e, self.long - 3, 3, e + 3);
        press = build.push(float(self.long - 4), 2.5, float(e) + 1.2, 2);
        if self.tele {
            build.teleporter(float(self.long) - 7.5, 3.0, e, float(self.long) - 4.5, float(middle) + 3.5, 0, 180.0);
        }
        for port in self.taken {
            build.doorway(court, port);
            if port.face == 0 and port.floor == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "This door is opened elsewhere.");
            }
        }
        # What waits by the way on wakes as the button is pushed.
        waiting_by = build.waiting();
        press +>:Fires:+> waiting_by;
        for index in range(2) {
            build.foe(float(self.long) - 4.5, float(middle) - 2.5 + float(index) * 5.0, 0, E3M2_FOES.pick(dice, self.danger, index == 0), 180.0, waits=waiting_by);
        }
        # Walking into the court opens the crypts on their dead.
        into = build.touch(float(self.long // 2 - 2), 6.0, 0.0, float(self.long // 2 + 2), float(inner), 6.0);
        dead = build.waiting();
        into +>:Fires:+> dead;
        e2m4_closets(build, [x for x in [8, 14, 20] if x + 3 < self.long - 4], inner, 0, into, dead, ["monster_zombie", "monster_zombie", E3M2_FOES.pick(dice, self.danger)]);
        # A door in the north wall that opens on a stash when shot.
        if self.stash {
            vault = build.room(2, inner + 1, 0, 5, inner + 4, 6);
            build.widen(vault, 2, inner, 0, 5, inner + 1, 5);
            e3m2_shot_door(build, 2.0, float(inner), 0.0, 5.0, float(inner + 1), 5.0);
            build.secret(2.0, float(inner + 1), 0.0, 5.0, float(inner + 4), 3.0);
            build.supply(3.5, float(inner) + 2.5, 0, "item_artifact_super_damage");
        }
        build.foe(8.5, 3.0, e, "monster_ogre", 0.0, patrol=[[8.5, 3.0], [float(self.long) - 9.5, 3.0]]);
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, 0, "monster_zombie", 180.0, patrol=[[float(self.long) - 6.5, float(middle) + 0.5], [10.5, float(middle) + 0.5]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 6, "monster_wizard", 180.0);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, float(inner) - 2.5, 0, "item_health");
    }
}

"""A hall over a pit of the dead, the floor across its middle falling
away underfoot; a stair out of the pit to the far floor."""
node CollapseHall(Prefab) {
    has trap: bool = True,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Collapse hall";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.trap = dice.chance(0.6);
        self.low = -11;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float((self.wide - 4) // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=3, along=12.0, floor=-9)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        pit = build.room(8, 1, -9, self.long - 8, self.wide - 1, 0, variant=dice.below(3));
        build.level(pit, -9);
        # The stair out of the pit along its north wall to the far floor.
        stair(build, self.long - 17, self.wide - 4, -9, 0, 9, 3);
        mid = (self.wide - 4) // 2;
        # A lift up out of the pit's south edge to the far floor.
        lift(build, self.long - 11, 1, self.long - 8, 4, -9, 0);
        for y in range(1, 4) {
            build.keep(hall, self.long - 8, y, 0);
        }
        stepped = build.touch(8.0, 4.0, 0.0, 10.0, float(self.wide - 4), 6.0);
        dead = build.waiting();
        stepped +>:Fires:+> dead;
        if self.trap {
            # The floor across the pit, a slab that falls to the pit's floor
            # as the player steps onto it.
            fields = {"classname": "func_door", "angle": "-2", "speed": "300", "wait": "-1", "lip": str(-8 * 16)};
            build.put_box(fields, 8.0, 4.0, -1.0, float(self.long - 8), float(self.wide - 4), 0.0, kit_of(build.district).step);
            build.casting.doors += 1;
            stepped +>:Fires:+> build.cue([fields], "floor");
        } else {
            build.solid(8, mid - 1, -1, self.long - 8, mid + 2, 0);
            for y in range(mid - 1, mid + 2) {
                build.keep(hall, 7, y, 0);
                build.keep(hall, self.long - 8, y, 0);
            }
        }
        build.doorway(hall, self.enter);
        # The far floor's way on opened by a button down in the pit.
        press = build.push(float(self.long // 2) + 0.5, 1.0, -7.8, 1);
        for port in self.taken {
            build.doorway(pit if port.floor < 0 else hall, port);
            if port.face == 0 and port.floor == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "This door is opened elsewhere.");
            }
        }
        # A teleporter in the pit's corner back up to the near floor.
        build.teleporter(float(self.long) - 9.5, float(self.wide) - 6.5, -9, 3.5, 3.5, 0, 0.0);
        # A stash in the pit's near wall, behind a wall that opens when shot.
        e2m4_stash(build, 4, 6, 6, 8, -9, 0, "item_artifact_super_damage");
        for index in range(dice.between(3, 5)) {
            build.foe(float(10 + index * 3) + 0.5, 3.5 + float(index % 3) * 3.0, -9, "monster_zombie" if index > 0 else E3M2_FOES.pick(dice, self.danger, True), 90.0, waits=dead);
        }
        build.foe(float(self.long) - 4.5, 2.5, 0, E3M2_FOES.pick(dice, self.danger), 90.0, patrol=[[float(self.long) - 4.5, 2.5], [float(self.long) - 4.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long // 2) + 0.5, float(mid) + 0.5, 5, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_rockets");
        build.supply(14.5, float(self.wide) - 6.5, -9, "item_health");
    }
}

"""A corridor, bays of the dead along it, ceilings over it that slam
down; the way on opened by a button in a bay."""
node CrusherCorridor(Prefab) {
    has crushers: int = 2,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crusher corridor";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(26, 30);
        self.wide = 12;
        self.crushers = dice.between(2, 3);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=3.5, floor=0);
        self.leaves = [Port(face=0, along=3.5, floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        corridor = build.room(1, 1, 0, self.long - 1, 6, self.tall - 1, variant=dice.below(3));
        build.level(corridor, 9);
        bays: list[int] = [];
        for x in range(4, self.long - 5, 6) {
            bays.append(x);
        }
        build.room(bays[-1], 6, 0, bays[-1] + 3, 9, 12);
        # A walkway high over the corridor's north half, a lift up to it in
        # the last bay.
        build.solid(1, 3, 8, self.long - 1, 6, 9);
        lift(build, bays[-1], 6, bays[-1] + 3, 9, 0, 9);
        for x in range(bays[-1], bays[-1] + 3) {
            build.keep(corridor, x, 5, 9);
        }
        build.foe(4.5, 4.5, 9, E3M2_FOES.pick(dice, self.danger, True), 0.0);
        build.supply(2.5, 4.5, 9, "item_health");
        # The ceilings that slam down on whoever walks under them.
        for index in range(self.crushers) {
            cx = 7 + index * ((self.long - 18) // max(1, self.crushers - 1)) if self.crushers > 1 else self.long // 2;
            # Each comes down over the corridor's south half, the north half
            # left clear to slip by on.
            under = build.touch(float(cx - 1), 1.0, 0.0, float(cx + 4), 6.0, 6.0, False);
            under +>:Fires:+> e3m2_crusher(build, float(cx), 1.0, float(cx + 3), 3.0, 0, 8);
        }
        build.doorway(corridor, self.enter);
        # The way on at the corridor's end opened by a button in the last
        # bay.
        press = build.push(float(bays[-1]) + 1.5, 9.0, 1.2, 3);
        for port in self.taken {
            build.doorway(corridor, port);
            if port.face == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), 1.0, float(self.long - 1), 6.0, 0, 8, "This door is opened elsewhere.");
            }
        }
        # The dead in the bays stir as the player comes in.
        coming = build.touch(1.0, 1.0, 0.0, 3.0, 6.0, 6.0);
        dead = build.waiting();
        coming +>:Fires:+> dead;
        e2m4_closets(build, bays[:-1], 6, 0, coming, dead, ["monster_zombie", E3M2_FOES.pick(dice, self.danger)]);
        build.foe(float(bays[-1]) + 1.5, 7.5, 0, E3M2_FOES.pick(dice, self.danger), 270.0, waits=dead);
        build.foe(float(self.long) - 4.5, 3.5, 0, E3M2_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 4.5, 3.5], [4.5, 3.5]]);
        build.supply(float(self.long // 2) + 0.5, 3.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_shells");
    }
}

"""A great hall, a balcony across its far end reached by a teleporter; a
plate in its floor brings ogres in; vaults behind doors shot open."""
node ZinHall(Prefab) {
    has balcony: int = 9,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin hall";
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(20, 24);
        self.low = -9;
        self.high = self.tall + 1;
        inner = self.wide - 5;
        middle = float(inner // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.balcony), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=4.0, floor=0), Port(face=3, along=float(self.long - 4), floor=self.balcony)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        inner = self.wide - 5;
        middle = inner // 2;
        b = self.balcony;
        hall = build.room(1, 1, 0, self.long - 1, inner, self.tall, variant=dice.below(4));
        build.level(hall, b);
        bx = self.long - 10;
        build.solid(bx, 1, b - 1, self.long - 1, inner, b);
        for y in range(3, inner - 2) {
            build.keep(hall, bx, y, b);
        }
        build.teleporter(float(self.long // 2) - 2.0, float(middle) + 0.5, 0, float(self.long) - 3.5, float(middle) + 0.5, b, 180.0);
        lift(build, bx - 3, inner - 4, bx, inner - 1, 0, b);
        for y in range(inner - 4, inner - 1) {
            build.keep(hall, bx, y, b);
            build.keep(hall, bx - 4, y, 0);
        }
        clear = [[bx - 5, inner - 6, bx, inner], [0, middle - 3, 5, middle + 3], [self.long // 2 - 5, middle - 3, self.long // 2 + 1, middle + 3], [2, inner - 5, 7, inner], [self.long // 2 - 3, 0, self.long // 2 + 3, 4]];
        pillars(build, 5, 4, bx - 1, 5, 0, self.tall, 4, clear);
        pillars(build, 5, inner - 4, bx - 1, inner - 3, 0, self.tall, 4, clear);
        # The plate in the floor's corner: ogres brought in by teleporter,
        # and a door elsewhere opened.
        plate = e2m7_plate(build, 3.0, float(inner - 4), 5.0, float(inner - 2), 0);
        late = build.delay(0.5);
        plate +>:Fires:+> late;
        for index in range(dice.between(2, 4)) {
            late +>:Fires:+> build.summon(1 + (index % 2) * 4, 2 + (index // 2) * 4, -8, "monster_ogre", float(self.long // 2) - 4.5 + float(index) * 3.0, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 and port.face == 3 {
                plate +>:Fires:+> e2m4_bars(build, port.along - 2.0, 1.0, port.along + 2.0, 2.0, 0, 8, "This door is opened elsewhere.");
            }
            if port.floor == b and port.face == 0 {
                build.solid(7, inner - 3, 0, 8, inner - 2, 3);
                build.push(7.0, float(inner) - 2.5, 1.2, 2) +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, b, 8, "This door is opened elsewhere.");
            }
        }
        # Vaults along the north wall behind doors that open when shot.
        for (index, at) in enumerate([9, self.long // 2 + 2]) {
            vault = build.room(at, inner + 1, 0, at + 3, inner + 4, 6);
            build.widen(vault, at, inner, 0, at + 3, inner + 1, 5);
            e3m2_shot_door(build, float(at), float(inner), 0.0, float(at + 3), float(inner + 1), 5.0);
            if index == 0 {
                build.secret(float(at), float(inner + 1), 0.0, float(at + 3), float(inner + 4), 3.0);
                build.supply(float(at) + 1.5, float(inner) + 2.5, 0, "item_armor2");
            } else {
                build.supply(float(at) + 1.5, float(inner) + 2.5, 0, "item_rockets");
            }
        }
        # What keeps the balcony wakes as the player comes through the
        # teleporter; the dead walk the floor.
        arrive = build.touch(float(self.long - 5), float(middle - 2), float(b), float(self.long - 2), float(middle + 3), float(b + 6));
        guard = build.waiting();
        arrive +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * (float(inner) - 7.0), b, E3M2_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(6 + index * 2) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, E3M2_FOES.pick(dice, self.danger), 0.0, patrol=[[float(6 + index * 2) + 0.5, 6.5], [float(6 + index * 2) + 0.5, float(inner) - 6.5]]);
        }
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, b, "item_health");
        build.supply(2.5, 2.5, 0, "item_shells");
    }
}

"""The key room: a pit of the dead across a vault, a bridge over it, the
key caged beyond, its bars opened by a button down in the pit."""
node ZinVault(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        lifted: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.lifted = dice.chance(0.5);
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(26, 28);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
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
        px0 = 6;
        px1 = self.long - 9;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        pit = build.room(px0, 1, -7, px1, side, 0, variant=dice.below(3));
        build.level(pit, -7);
        build.doorway(vault, self.enter);
        # The bridge over the pit, the stairs out of it at each end.
        build.solid(px0, cy - 1, -1, px1, cy + 2, 0);
        for y in range(cy - 1, cy + 2) {
            build.keep(vault, px0 - 1, y, 0);
            build.keep(vault, px1, y, 0);
        }
        stair(build, px0 + 6, 1, -7, 2, 7, 3);
        if self.lifted {
            lift(build, px1 - 3, side - 3, px1, side, -7, 0);
            for y in range(side - 3, side) {
                build.keep(vault, px1, y, 0);
            }
        } else {
            stair(build, px1 - 7, side - 3, -7, 0, 7, 3);
        }
        e2m4_stash(build, px0 - 4, cy + 3, px0 - 2, cy + 5, -7, 0, "item_artifact_envirosuit");
        # The cage at the far end, its bars opened by a button on the pit's
        # north wall down on its floor.
        cage = self.long - 4;
        build.solid(cage, 1, 0, cage + 1, cy - 2, self.tall);
        build.solid(cage, cy + 2, 0, cage + 1, side, self.tall);
        build.solid(cage, cy - 2, 8, cage + 1, cy + 2, self.tall);
        bars = e2m4_bars(build, float(cage), float(cy - 2), float(cage + 1), float(cy + 2), 0, 8, "This door is opened elsewhere.");
        build.push(float(px0 + px1) * 0.5, float(side), -5.8, 3) +>:Fires:+> bars;
        # The dead in the pit stir as the player sets foot on the bridge.
        onto = build.touch(float(px0), float(cy - 1), 0.0, float(px0 + 2), float(cy + 2), 6.0);
        dead = build.waiting();
        onto +>:Fires:+> dead;
        for index in range(dice.between(3, 5)) {
            build.foe(float(px0 + 3 + index * 2) + 0.5, float(cy) + (3.5 if index % 2 == 0 else -3.5), -7, "monster_zombie", 90.0, waits=dead);
        }
        # The key; taking it opens the closets and brings a fiend in.
        taken = e2m4_key(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 0);
        out = build.waiting();
        taken +>:Fires:+> out;
        e2m4_closets(build, [2, px1 + 1], side, 0, taken, out, [E3M2_FOES.pick(dice, self.danger, True), E3M2_FOES.pick(dice, self.danger)]);
        late = build.delay(1.5);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -8, "monster_shambler" if self.danger > 0.6 else "monster_demon1", float(px1) + 2.5, float(cy) + 0.5, 0, 0.0);
        build.foe(float(px1) + 4.5, 2.5, 0, E3M2_FOES.pick(dice, self.danger), 180.0, patrol=[[float(px1) + 4.5, 2.5], [float(px1) + 4.5, float(side) - 4.5]]);
        # A gallery along the south wall over the pit, a lift up to it from
        # the far floor.
        build.level(vault, 7);
        build.solid(px0, 1, 6, self.long - 4, 4, 7);
        lift(build, px1 + 1, 4, px1 + 4, 7, 0, 7);
        for x in range(px1 + 1, px1 + 4) {
            build.keep(vault, x, 3, 7);
        }
        build.foe(float(px0) + 2.5, 2.5, 7, E3M2_FOES.pick(dice, self.danger), 0.0);
        build.supply(float(px0 + px1) * 0.5, 2.5, 7, "item_health");
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(px0 + 2) + 0.5, float(side) - 2.5, -7, "item_health");
    }
}

"""The end: a door into a chapel, crypts along its nave, the slipgate on a
dais between pillars."""
node ZinExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zin exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M2;
        self.district = level_district(E3M2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(15, 17);
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
        chapel = build.room(wall + 1, 1, 0, self.long - 1, inner, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(chapel, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key);
        }
        # The dais at the far end, a step up, pillars either side of the
        # slipgate.
        dx = self.long - 7;
        build.solid(dx, 1, 0, self.long - 1, inner, 1);
        build.solid(dx + 2, middle - 3, 1, dx + 3, middle - 2, self.tall - 3);
        build.solid(dx + 2, middle + 2, 1, dx + 3, middle + 3, self.tall - 3);
        build.way_out(float(self.long) - 3.5, float(middle), 1);
        build.touch(float(dx - 2), float(middle - 3), 0.0, float(dx), float(middle + 3), 6.0, True, "Walk through the rune gate to go on");
        pillars(build, wall + 5, 5, dx - 2, 6, 0, self.tall, 4, [[wall, middle - 3, wall + 5, middle + 3]]);
        pillars(build, wall + 4, inner - 3, dx - 2, inner - 2, 0, self.tall, 4, [[wall, middle - 3, wall + 4, middle + 3]]);
        # The crypts along the north wall open as the player comes up the
        # nave; fiends are brought in behind.
        nave = build.touch(float(wall + 6), 1.0, 0.0, float(wall + 8), float(inner), 6.0);
        dead = build.waiting();
        nave +>:Fires:+> dead;
        e2m4_closets(build, [x for x in [wall + 4, wall + 9, wall + 14] if x + 3 < dx], inner, 0, nave, dead, ["monster_zombie", E3M2_FOES.pick(dice, self.danger, True)]);
        late = build.delay(2.0);
        nave +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -8, E3M2_FOES.pick(dice, self.danger, True), float(wall) + 2.5, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E3M2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(dx) - 2.5, float(middle) + 0.5, 0, E3M2_FOES.pick(dice, self.danger), 180.0, patrol=[[float(dx) - 2.5, 2.5], [float(dx) - 2.5, float(inner) - 2.5]]);
        # A gallery along the nave's south wall, a lift up to it.
        build.level(chapel, 9);
        build.solid(wall + 1, 1, 8, dx, 4, 9);
        lift(build, wall + 1, 4, wall + 4, 7, 0, 9);
        for x in range(wall + 1, wall + 4) {
            build.keep(chapel, x, 3, 9);
        }
        build.foe(float(dx) - 3.5, 2.5, 9, E3M2_FOES.pick(dice, self.danger), 180.0, patrol=[[float(dx) - 3.5, 2.5], [float(wall) + 5.5, 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m2's stretches: [name, role]."""
glob E3M2_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["collapse", "flow"],
         ["crusher", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m2's stretches by its name."""
def make_e3m2(name: str, key: str) -> Prefab {
    if name == "gate" {
        return ZinGate();
    }
    if name == "collapse" {
        return CollapseHall();
    }
    if name == "crusher" {
        return CrusherCorridor();
    }
    if name == "hall" {
        return ZinHall();
    }
    if name == "vault" {
        return ZinVault(key=key if key else "key_gold");
    }
    return ZinExit(key=key);
}
