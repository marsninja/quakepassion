"""Prefabs drawn from e4m2, the Tower of Despair: a tower standing in a
court, climbed by a stair winding round its outside, cages of knights let
loose by a button ("You opened the cages!"), a window shot to open a
secret, ledges up a shaft teleported to one from the next, a hall round a
sunken arena, doors opened by shooting them, secrets behind buttons and
lifts, the silver key on a pillar's top up a stair round it. Raised in
e4m2's own palette.

- `DespairTower`: the start. A court under the sky, a tower in its middle,
  a stair winding up round its outside to a landing and a bridge from it
  to a way on high in the court's wall; cages along the court's wall that
  a button at the tower's foot opens; a window high on the wall that, shot
  ("The window is key to a secret."), opens a closet. Knights walk the
  court.
- `DespairTeleports`: a shaft of ledges, south, north and south again, a
  teleporter on the floor and on each ledge to the next (and a lift to the
  first), the guard of each waking as a body arrives; a closet on the top
  ledge behind a wall that opens when shot.
- `DespairHall`: a hall, an arena sunk in its middle, a gallery along two
  walls ridden up to by lifts (one held up until a button lets it down);
  the arena's knights wake as it is entered; a button opens a secret door
  in the gallery's wall; ways on from the floor and the gallery (a hub).
- `ShotGates`: a hall, a dais in its middle walled round by doors that
  open only when shot, a teleporter on the dais up to a gallery high on
  the far wall and the way on there; a lift back down; knights on rounds.
- `DespairSummit`: the key room. A pillar in a hall, a stair winding up
  round it, the key on its top; taking it opens the closets; a teleporter
  on the top back down.
- `DespairExit`: the end. A door (a key's, as a gate) onto a balcony over
  a pit ("Are you sure you want to exit?"), a bridge to the slipgate (or a
  teleporter down to it), a stair up out of the pit."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, spiral, ring_landing, lift }
import from .e3m5 { keep_run, sealed_way }
import from .e3m6 { rounds }
import from .e3m7 { relayed, held_lift, secret_opener }

glob E4M2: str = "q1:e4m2";

"""e4m2's foes: knights and ogres, hell knights and vores deeper in."""
def e4m2_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_knight", "monster_knight", "monster_ogre"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""A door of the prefab's cells x0..x1, y0..y1, z0..z1 that opens (rising)
only when shot (e4m2's doors with health)."""
def shot_door(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) {
    build.rising_door(x0, y0, z0, x1, y1, z1, {"health": "1", "wait": "-1"});
}

"""A closet's door (the prefab's cells at..at+3 on the line y = `side`,
lifts z..z+6) that bursts open when fired: answers its fields."""
def build_burst(build: Raising, at: int, side: int, z: int) -> dict[str, str] {
    fields: dict[str, str] = {"wait": "-1", "speed": "400"};
    build.rising_door(float(at), float(side), float(z), float(at + 3), float(side + 1), float(z + 6), fields);
    return fields;
}

"""A secret closet behind a wall that opens when shot: the closet's cells
x0..x1, y0..y1 from lift z (four lifts high) carved out of solid, the
door the cells `door` [x0, y0, x1, y1] beside it sliding the way
`direction` goes, a secret in it and a pickup of `kind`."""
def shot_closet(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, door: list[int], direction: int, kind: str) {
    build.room(x0, y0, z, x1, y1, z + 4);
    build.secret_door(float(door[0]), float(door[1]), float(z), float(door[2]), float(door[3]), float(z + 4), direction);
    build.secret(float(x0), float(y0), float(z), float(x1), float(y1), float(z + 3));
    build.supply(float(x0 + x1) * 0.5, float(y0 + y1) * 0.5, z, kind);
}

"""The start: a court, a tower in its middle climbed by a stair round its
outside, cages a button opens, a window shot to open a secret."""
node DespairTower(Prefab) {
    has steps: int = 24,
        tall: int = 32,
        cages: int = 3,
        window: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair tower";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(28, 30);
        self.wide = dice.between(28, 30);
        self.cages = dice.between(2, 4);
        self.window = dice.chance(0.7);
        cx = self.long // 2;
        cy = (self.wide - 4) // 2;
        fits: list[int] = [];
        for steps in range(18, 32) {
            landing = ring_landing(cx - 7, cy - 7, cx + 7, cy + 7, 3, steps, 5);
            if landing and landing[0] == 1.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 8;
        self.low = -7;
        self.high = self.tall + 1;
        top = ring_landing(cx - 7, cy - 7, cx + 7, cy + 7, 3, self.steps, 5);
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [Port(face=1, along=top[1], floor=self.steps), Port(face=0, along=float(cy), floor=0), Port(face=3, along=float(cx), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        side = self.wide - 4;
        cx = long // 2;
        cy = side // 2;
        court = build.room(1, 1, 0, long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.steps);
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.steps);
        landing = spiral(build, cx - 7, cy - 7, cx + 7, cy + 7, 0, self.steps, 3, 5);
        mid = landing[2];
        build.solid(mid[0] - 3, mid[3], self.steps - 1, mid[0] + 4, self.wide - 1, self.steps);
        keep_run(build, court, mid[0] - 3, mid[3] - 1, mid[0] + 4, mid[3], self.steps);
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "item_shells");
        # Cages along the south wall, their bars sunk by the button at the
        # tower's foot, a knight in each.
        cage_press: dict[str, str] = build.button(float(cx - 4), float(cy) + 1.5, 1.5, 2, "", False);
        cage_press["message"] = "You opened the cages!";
        opened = build.cue([cage_press], "button");
        loose = build.waiting();
        opened +>:Fires:+> loose;
        spots = [at for at in [2, 7, cx + 4, cx + 9] if at + 4 <= long - 2 and (at + 4 <= cx - 3 or at - 1 >= cx + 3)];
        for (index, at) in enumerate(spots[:self.cages]) {
            build.solid(at - 1, 1, 0, at + 4, 5, 8);
            build.room(at, 1, 0, at + 3, 5, 6);
            opened +>:Fires:+> build.sinking(float(at), 4.0, float(at + 3), 5.0, 6, 6);
            build.foe(float(at) + 1.5, 2.5, 0, "monster_knight" if index % 2 == 0 else e4m2_foe(dice, self.danger), 90.0, waits=loose);
        }
        # The window high on the east wall: shot, it opens a closet in the
        # wall by the way in (a secret).
        if self.window {
            build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 4), 6.0, True, "The window is key to a secret.");
            shot = build.cue([build.button(float(long - 1), float(cy) + 0.5, 10.0, 2, "", True)], "button");
            build.solid(1, side - 3, 0, 5, self.wide - 1, 7);
            build.room(1, side - 2, 0, 4, self.wide - 1, 5);
            build.widen(court, 4, side - 2, 0, 5, self.wide - 1, 5);
            relayed(build, shot, 0.5) +>:Fires:+> build.opened(4.0, float(side - 2), 0.0, 5.0, float(self.wide - 1), 5.0);
            build.secret(1.0, float(side - 2), 0.0, 4.0, float(self.wide - 1), 3.0);
            build.supply(2.5, float(side) + 0.5, 0, "item_artifact_super_damage");
        }
        # Knights walk the court; the tower's guard wakes halfway up.
        rounds(build, "monster_knight", float(long) - 3.5, 7.5, float(long) - 3.5, float(side) - 3.5, 0);
        rounds(build, e4m2_foe(dice, self.danger), 7.5, float(side) + 1.5, float(long) - 6.5, float(side) + 1.5, 0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps, e4m2_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx + 5) + 0.5, float(cy) + 0.5, 14, e4m2_foe(dice, self.danger), 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.steps, "item_health");
    }
}

"""A shaft of ledges, a teleporter on the floor and on each ledge to the
next, a lift to the first."""
node DespairTeleports(Prefab) {
    has rise_by: int = 6,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair teleports";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(18, 20);
        self.wide = dice.between(16, 18);
        self.rise_by = dice.between(6, 7);
        self.tall = 3 * self.rise_by + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=3.5, floor=3 * self.rise_by), Port(face=3, along=float(self.long // 2), floor=3 * self.rise_by)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        first = self.rise_by;
        second = 2 * self.rise_by;
        top = 3 * self.rise_by;
        cx = long // 2;
        shaft = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        for z in [first, second, top] {
            build.level(shaft, z);
        }
        north = wide - 6;
        build.solid(1, 1, first - 1, long - 1, 6, first);
        build.solid(1, north, second - 1, long - 1, wide - 1, second);
        build.solid(1, 1, top - 1, long - 1, 6, top);
        keep_run(build, shaft, 2, 5, long - 2, 6, first);
        keep_run(build, shaft, 2, north, long - 2, north + 1, second);
        keep_run(build, shaft, 2, 5, long - 6, 6, top);
        build.teleporter(float(cx) + 0.5, float(wide // 2) + 0.5, 0, float(cx) + 0.5, 3.0, first, 0.0);
        build.teleporter(3.5, 3.5, first, float(cx) + 0.5, float(wide) - 3.0, second, 0.0);
        build.teleporter(3.5, float(wide) - 3.5, second, float(long) - 4.0, 3.5, top, 0.0);
        # A lift by the east wall up to the first ledge.
        lift(build, long - 4, 6, long - 1, 9, 0, first);
        keep_run(build, shaft, long - 4, 5, long - 1, 6, first);
        keep_run(build, shaft, long - 5, 6, long - 1, 10, 0);
        # A closet off the top ledge behind a wall that opens when shot.
        build.solid(1, 1, top, 6, 5, top + 6);
        shot_closet(build, 2, 1, 4, 3, top, [2, 3, 4, 5], 3, "item_armor2");
        shot = build.cue([build.button(float(long // 2) + 0.5, float(wide - 1), float(top) + 2.0, 3, "", True)], "button");
        build.doorway(shaft, self.enter);
        for port in self.taken {
            sealed_way(build, shaft, long, wide, port, relayed(build, shot, 0.5), "This door is opened elsewhere.");
        }
        # Each ledge's guard wakes as a body arrives on it.
        for (z, y, x) in [(first, 3.0, float(cx) + 0.5), (second, float(wide) - 3.0, float(cx) + 0.5), (top, 3.5, float(long) - 8.0)] {
            arrived = build.touch(x - 1.5, y - 1.5, float(z), x + 1.5, y + 1.5, float(z + 6));
            guard = build.waiting();
            arrived +>:Fires:+> guard;
            build.foe(x - 5.0 if x > 6.0 else x + 5.0, y, z, e4m2_foe(dice, self.danger, z == second), 180.0, waits=guard);
        }
        rounds(build, "monster_knight", 3.5, float(wide // 2) + 0.5, float(long) - 6.5, float(wide // 2) + 0.5, 0);
        build.supply(2.5, float(wide) - 2.5, 0, "item_health");
        build.supply(float(cx) - 3.5, float(wide) - 3.0, second, "item_shells");
    }
}

"""A hall, an arena sunk in its middle, a gallery along two walls ridden
up to by lifts, a secret door a button opens."""
node DespairHall(Prefab) {
    has gallery: int = 6,
        tall: int = 18,
        held: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair hall";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.gallery = dice.between(6, 7);
        self.tall = self.gallery + 11;
        self.held = dice.chance(0.5);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 2.5), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = self.gallery;
        middle = wide // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, -3);
        build.level(hall, g);
        # The arena, three steps down at either end.
        build.widen(hall, 7, 7, -3, long - 7, wide - 7, 0);
        stair(build, 9, 7, -3, 2, 3, wide - 14);
        stair(build, long - 10, 7, -3, 0, 3, wide - 14);
        # The gallery along the north and east walls, lifts up to it (the
        # east one held up until the button by the way in lets it down).
        under = g - 1;
        build.solid(1, wide - 4, under, long - 1, wide - 1, g);
        build.solid(long - 4, 1, under, long - 1, wide - 4, g);
        lift(build, 3, wide - 7, 6, wide - 4, 0, g);
        if self.held {
            down = held_lift(build, long - 7, 3, long - 4, 6, 0, g);
            relayed(build, build.push(1.0, 3.5, 1.5, 0), 0.5) +>:Fires:+> down;
        } else {
            lift(build, long - 7, 3, long - 4, 6, 0, g);
        }
        keep_run(build, hall, 2, wide - 4, 7, wide - 3, g);
        keep_run(build, hall, long - 4, 2, long - 3, 7, g);
        keep_run(build, hall, 10, wide - 4, 14, wide - 3, g);
        # A secret door in the gallery's north wall, opened by the button on
        # the arena's floor: a closet with a prize.
        sx = long // 2 + 2;
        build.solid(sx, wide - 4, 0, sx + 5, wide - 1, under);
        build.room(sx + 1, wide - 3, 0, sx + 4, wide - 1, 4);
        sd: dict[str, str] = {"classname": "func_door_secret", "angle": str(build.facing(1)), "sounds": "1"};
        build.put_box(sd, float(sx + 1), float(wide - 4), 0.0, float(sx + 4), float(wide - 3), 4.0, kit_of(build.district).wall);
        build.rock_round(float(sx - 3), float(wide - 8), 0.0, float(sx + 8), float(wide), 5.0);
        build.push(float(long // 2) + 0.5, float(wide - 7), -2.8, 3) +>:Fires:+> build.cue([sd], "secret");
        build.secret(float(sx + 1), float(wide - 3), 0.0, float(sx + 4), float(wide - 1), 3.0);
        build.supply(float(sx) + 2.5, float(wide) - 2.0, 0, "item_artifact_super_damage" if dice.chance(0.3) else "item_armor2");
        floor_way = build.push(float(long // 2) - 2.5, float(wide - 1), float(g) + 1.2, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, hall, long, wide, port, relayed(build, floor_way, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(hall, port);
            }
        }
        # The arena's knights wake as a body comes down into it; knights walk
        # the gallery.
        into = build.touch(7.0, 7.0, -3.0, float(long - 7), float(wide - 7), 3.0);
        pit = build.waiting();
        into +>:Fires:+> pit;
        for index in range(dice.between(3, 4)) {
            build.foe(float(11 + index * 2) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), -3, e4m2_foe(dice, self.danger), 0.0, waits=pit);
        }
        rounds(build, "monster_knight", 8.5, float(wide) - 2.5, float(long) - 5.5, float(wide) - 2.5, g);
        rounds(build, e4m2_foe(dice, self.danger), 3.5, 3.5, 3.5, float(wide) - 8.5, 0);
        build.foe(float(long) - 2.5, float(middle) + 0.5, g, e4m2_foe(dice, self.danger, True), 180.0);
        build.supply(float(long) - 2.5, float(wide) - 2.5, g, "item_health");
        build.supply(3.0, 3.0, 0, "item_spikes");
    }
}

"""A hall, a dais walled round by doors that open when shot, a teleporter
on it up to a gallery high on the far wall."""
node ShotGates(Prefab) {
    has gallery: int = 12,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shot gates";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(24, 28);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(11, 14);
        self.tall = self.gallery + 9;
        self.low = -1;
        self.high = self.tall + 1;
        g = self.gallery;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=g), Port(face=1, along=float(self.long - 3), floor=g), Port(face=3, along=float(self.long - 3), floor=g)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = self.gallery;
        cy = wide // 2;
        cx = long // 2 - 1;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        build.level(hall, 1);
        # The gallery across the far end, high.
        gx = long - 6;
        build.solid(gx, 1, g - 1, long - 1, wide - 1, g);
        keep_run(build, hall, gx, 3, gx + 1, 6, g);
        # The dais, two lifts up, walled round with a door in each wall that
        # opens when shot.
        build.solid(cx - 3, cy - 3, 0, cx + 4, cy + 4, 1);
        for (x0, y0, x1, y1) in [(cx - 3, cy - 3, cx + 4, cy - 2), (cx - 3, cy + 3, cx + 4, cy + 4), (cx - 3, cy - 2, cx - 2, cy + 3), (cx + 3, cy - 2, cx + 4, cy + 3)] {
            build.solid(x0, y0, 1, x1, y1, 9);
        }
        build.solid(cx - 3, cy - 3, 9, cx + 4, cy + 4, 10);
        for (x0, y0, x1, y1) in [(cx - 1, cy - 3, cx + 2, cy - 2), (cx - 1, cy + 3, cx + 2, cy + 4), (cx - 3, cy - 1, cx - 2, cy + 2), (cx + 3, cy - 1, cx + 4, cy + 2)] {
            build.widen(hall, x0, y0, 1, x1, y1, 7);
            shot_door(build, float(x0), float(y0), 1.0, float(x1), float(y1), 7.0);
        }
        build.teleporter(float(cx) + 0.5, float(cy) + 0.5, 1, float(long) - 3.5, float(cy) + 0.5, g, 180.0);
        build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Shoot the doors open");
        # A lift back down from the gallery.
        lift(build, gx - 3, 2, gx, 5, 0, g);
        keep_run(build, hall, gx - 4, 1, gx, 6, 0);
        # A closet in the gallery's end wall behind a wall that opens when
        # shot (a secret).
        build.solid(long - 4, cy - 7, g, long - 1, cy - 2, g + 6);
        shot_closet(build, long - 3, cy - 6, long - 1, cy - 3, g, [long - 4, cy - 6, long - 3, cy - 3], 0, "item_health");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Knights walk round the dais; the gallery's guard wakes as a body
        # is set down there.
        rounds(build, "monster_knight", float(cx) - 5.5, float(cy) - 5.5, float(cx) + 6.5, float(cy) - 5.5, 0);
        rounds(build, e4m2_foe(dice, self.danger), float(cx) + 6.5, float(cy) + 6.5, float(cx) - 5.5, float(cy) + 6.5, 0);
        arrived = build.touch(float(long - 5), float(cy - 2), float(g), float(long - 2), float(cy + 3), float(g + 6));
        guard = build.waiting();
        arrived +>:Fires:+> guard;
        build.foe(float(gx) + 1.5, 2.5, g, e4m2_foe(dice, self.danger, True), 90.0, waits=guard);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 12, "monster_wizard", 0.0, waits=guard);
        build.supply(3.0, 3.0, 0, "item_shells");
        build.supply(float(long) - 2.5, float(cy) + 3.5, g, "item_health");
    }
}

"""A pillar in a hall, a stair winding up round it, the key on its top;
taking it opens the closets."""
node DespairSummit(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        steps: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair summit (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(17, 19);
        self.wide = self.hall_wide + 4;
        self.steps = dice.between(8, 12);
        self.tall = self.steps + 8;
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
        long = self.long;
        cx = long // 2 + 1;
        cy = side // 2;
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.steps);
        build.doorway(hall, self.enter);
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.steps);
        spiral(build, cx - 4, cy - 4, cx + 4, cy + 4, 0, self.steps, 2, 2);
        key_ambush(build, self.key, float(cx) - 0.5, float(cy) - 0.5, self.steps, side, 0, [2, long - 5], [e4m2_foe(dice, self.danger, True), e4m2_foe(dice, self.danger)]);
        # A teleporter on the top back down by the way in.
        build.teleporter(float(cx) + 0.5, float(cy) + 0.5, self.steps, 3.0, 3.0, 0, 0.0);
        # A closet in the east wall behind a wall that opens when shot.
        build.solid(long - 4, 1, 0, long - 1, 6, 6);
        shot_closet(build, long - 3, 2, long - 1, 5, 0, [long - 4, 2, long - 3, 5], 0, "item_rockets");
        halfway = build.touch(float(cx - 4), float(cy - 4), 3.0, float(cx + 4), float(cy + 4), float(self.steps));
        up = build.waiting();
        halfway +>:Fires:+> up;
        build.foe(float(cx) + 0.5, float(cy) + 1.0, self.steps, e4m2_foe(dice, self.danger), 180.0, waits=up);
        rounds(build, "monster_knight", 3.5, float(side) - 2.5, float(long) - 5.5, float(side) - 2.5, 0);
        build.foe(float(long) - 2.5, float(side) - 4.5, 0, e4m2_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) - 4.5, 0, "item_health");
    }
}

"""The end: a door onto a balcony over a pit, a bridge to the slipgate (or
a teleporter down to it); a stair up out of the pit; closets bursting
open in the pit's wall."""
node DespairExit(Prefab) {
    has key: str = "",
        deep: int = 8,
        tall: int = 12,
        bridged: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Despair exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M2;
        self.district = level_district(E4M2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(19, 21);
        self.deep = dice.between(7, 9);
        self.tall = dice.between(11, 13);
        self.bridged = dice.chance(0.5);
        self.low = -self.deep - 1;
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
        low = -self.deep;
        wall = 7;
        hall = build.room(1, 1, 0, wall, side, 10, variant=dice.below(3));
        pit = build.room(wall + 1, 1, low, long - 1, side, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.doorway(hall, self.enter);
        build.widen(pit, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        x0 = wall + 4;
        x1 = long - 6;
        build.solid(wall + 1, 1, low, x0, side, 0);
        build.solid(x1, middle - 3, low, long - 1, middle + 3, 0);
        if self.bridged {
            build.solid(x0, middle - 1, -1, x1, middle + 2, 0);
            keep_run(build, pit, x0 - 1, middle - 1, x0, middle + 2, 0);
            keep_run(build, pit, x1, middle - 1, x1 + 1, middle + 2, 0);
        } else {
            # A teleporter on the balcony down onto the slipgate's island,
            # whose stair climbs from the pit.
            build.teleporter(float(x0) - 2.0, float(middle) + 3.5, 0, float(x1) + 2.5, float(middle) + 0.5, 0, 0.0);
            stair(build, x1 - self.deep, middle - 1, low, 0, self.deep, 3);
        }
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 3);
        keep_run(build, pit, x0 - 1, 1, x0, 4, 0);
        build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0, False, "Are you sure you want to exit?");
        build.way_out(float(long) - 3.0, float(middle), 0);
        # The pit's knights wake as the balcony is reached, and closets in
        # the pit's north wall burst open on more.
        reached = build.touch(float(wall + 1), 1.0, 0.0, float(x0), float(side), 6.0);
        below = build.waiting();
        reached +>:Fires:+> below;
        burst = build.delay(1.0);
        reached +>:Fires:+> burst;
        for at in [x0 + 3, x0 + 9] {
            if at + 3 <= x1 - 1 {
                build.room(at, side + 1, low, at + 3, side + 4, low + 7);
                build.widen(pit, at, side, low, at + 3, side + 1, low + 6);
                burst +>:Fires:+> build.cue([build_burst(build, at, side, low)], "door");
                build.foe(float(at) + 1.5, float(side) + 2.5, low, e4m2_foe(dice, self.danger, at == x0 + 3), 270.0);
            }
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 6 + index * 4) + 0.5, float(side) - 2.5, low, e4m2_foe(dice, self.danger), 180.0, waits=below);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 3.0, 0, e4m2_foe(dice, self.danger, index == 0), 180.0);
        }
        rounds(build, "monster_knight", float(x0 + 2) + 0.5, 3.5, float(x1) - 1.5, 3.5, low);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m2's stretches: [name, role]."""
glob E4M2_STRETCHES: list[list[str]] = [
         ["tower", "start"],
         ["teleports", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["gates", "flow"],
         ["gates", "hub"],
         ["summit", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m2's stretches by its name."""
def make_e4m2(name: str, key: str) -> Prefab {
    if name == "tower" {
        return DespairTower();
    }
    if name == "teleports" {
        return DespairTeleports();
    }
    if name == "hall" {
        return DespairHall();
    }
    if name == "gates" {
        return ShotGates();
    }
    if name == "summit" {
        return DespairSummit(key=key if key else "key_silver");
    }
    return DespairExit(key=key);
}
