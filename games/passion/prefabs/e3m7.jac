"""Prefabs drawn from e3m7, the Haunted Halls: halls of wood and stone that
teleport a body about them, doors opened elsewhere, buttons shot to draw
out bridges and raise stairs, lifts held up until a button lets them
down, spikes that fly in turns, secret doors that open the floor, the
dead lying in wait. e3m7 holds no keys; its key room and gate are drawn
from its crypts. Raised in e3m7's own palette.

- `HauntedFoyer`: the start. A foyer, a gallery round three of its walls
  climbed by a grand stair (or a lift in a corner), a teleporter up to it;
  the way on from the floor is a door opened from the gallery ("This door
  is opened elsewhere"), whose button brings in an ogre; a closet under
  the gallery behind a wall that opens when shot.
- `DrawbridgeHall`: a hall across a pit, the dead in it; a button on the
  far wall, shot, draws out a bridge over the pit (or, pressed down in the
  pit, raises a stair out of its floor up to the far side); a lift up out
  of the pit and a teleporter back; a secret closet in the pit's wall.
- `SlimeLifts`: a hall over a deep cistern trench, a lift (or a stair) up
  to a walkway across it and a stair down the far side, stepping stones
  across for whoever would jump; a teleporter back.
- `StairOfDoors`: a hall, a ledge high across its far end over a crypt;
  a button shot high on the wall raises a stair of doors up to the ledge
  (or a lift held up on the ledge comes down when a button is pressed); a
  secret door in the wall that, opened, opens a niche on the quad damage.
- `SpikeRhythm`: a long corridor under a walkway; spikes fly across it in
  two volleys a second apart while anyone is in it (e3m7's timed trap);
  a stair (or a lift) up to the walkway at its end, a button there opening
  the corridor's far door, a teleporter back to the corridor's head.
- `PadGallery`: a hall of teleporters, each up to a balcony at its own
  height; a lift to the lowest; guards woken on each; a secret closet on
  the highest; ways on from the floor and every balcony (a hub).
- `HauntedCrypt`: the key room. A crypt below a landing, the key on a
  tomb; taking it opens the closets and teleports the dead in; up again by
  a lift (or a stair a button raises); a secret alcove.
- `HauntedExit`: the end. A door (a key's, as a gate), a hall under a
  balcony, the teleporter to the sealed chamber of the slipgate behind a
  door a button shot high on the wall opens."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, lift, key_item, apart }
import from .e3m5 { keep_run, sealed_way, bursting }
import from .e3m6 { rounds }

glob E3M7: str = "q1:e3m7";

"""e3m7's foes: ogres and the dead, scrags, hell knights and vores deeper
in."""
def e3m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_hell_knight"] if heavy else ["monster_ogre", "monster_zombie", "monster_zombie"], ["monster_shalrath"] if heavy else ["monster_wizard"], danger * 0.5 if heavy else danger));
}

"""A secret door (as `secret_door`) that fires its cue as it opens (e3m7's
secret doors that open the floor behind them)."""
def secret_opener(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) -> Cue {
    kit = kit_of(build.district);
    fields: dict[str, str] = {"classname": "func_door_secret", "angle": str(build.facing(direction)), "sounds": "1"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, kit.wall);
    reach = max(x1 - x0, y1 - y0) + 1.0;
    build.rock_round(x0 - reach, y0 - reach, z0, x1 + reach, y1 + reach, z1 + 1.0);
    return build.cue([fields], "secret");
}

"""A relay that fires what it is wired to `seconds` after `cue` fires
(e3m7's buttons work their doors through relays)."""
def relayed(build: Raising, cue: Cue, seconds: float) -> Cue {
    later = build.delay(seconds);
    cue +>:Fires:+> later;
    return later;
}

"""Tombs and racks: `count` blocks two or three cells across and two or
three lifts high on the floor box x0..x1, y0..y1 on lift `z`, each a cell
clear of `clear` and of each other (low enough to climb onto and drop
from)."""
def raised_blocks(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    taken: list[list[int]] = list(clear);
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 10 {
        tries += 1;
        wide = dice.between(2, 3);
        deep = dice.between(2, 3);
        x = dice.between(x0, max(x0, x1 - wide));
        y = dice.between(y0, max(y0, y1 - deep));
        box = [x, y, x + wide, y + deep];
        if not apart(box, taken) {
            continue;
        }
        taken.append(box);
        build.solid(x, y, z, x + wide, y + deep, z + dice.between(2, 3));
        placed += 1;
    }
}

"""A lift held up at lift `top` until its cue fires, then a lift like any
other (Quake's func_plat with a targetname)."""
def held_lift(build: Raising, x0: int, y0: int, x1: int, y1: int, bottom: int, top: int) -> Cue {
    fields: dict[str, str] = {"classname": "func_plat", "height": str((top - bottom) * 16), "speed": "200"};
    build.put_box(fields, float(x0), float(y0), float(top) - 0.5, float(x1), float(y1), float(top), kit_of(build.district).step);
    return build.cue([fields], "plat");
}

"""The start: a foyer, a gallery round three walls, the way on from the
floor opened from the gallery."""
node HauntedFoyer(Prefab) {
    has gallery: int = 9,
        tall: int = 19,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted foyer";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(24, 28);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + 10;
        self.climb = dice.below(2);
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.gallery), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        g = self.gallery;
        middle = wide // 2;
        foyer = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(foyer, g);
        under = g - 1;
        # The gallery: along the north and east walls and the south wall's
        # far half, a slab a lift thick.
        build.solid(5, wide - 4, under, long - 1, wide - 1, g);
        build.solid(long - 5, 1, under, long - 1, wide - 4, g);
        build.solid(long // 2, 1, under, long - 5, 4, g);
        if self.climb == 0 {
            # The grand stair up the middle to the east gallery.
            sx = long - 5 - g;
            stair(build, sx, middle - 2, 0, 0, g, 4);
            keep_run(build, foyer, long - 5, middle - 2, long - 4, middle + 2, g);
            top = [long - 6, middle - 2, long - 3, middle + 2];
        } else {
            top = [5, wide - 4, 8, wide - 1];
        }
        # A lift in the north-west corner up to the north gallery.
        lift(build, 1, wide - 4, 5, wide - 1, 0, g);
        keep_run(build, foyer, 5, wide - 4, 6, wide - 1, g);
        keep_run(build, foyer, 1, wide - 5, 6, wide - 4, 0);
        # Drops off the galleries' inner edges.
        keep_run(build, foyer, 6, wide - 5, long - 5, wide - 4, g);
        keep_run(build, foyer, long // 2, 4, long - 5, 5, g);
        keep_run(build, foyer, long - 6, 5, long - 5, wide - 4, g);
        # Tombs on the floor's west half.
        raised_blocks(build, dice, 6, 5, long - 7, wide - 8, 0, dice.between(4, 6), [[0, middle - 3, long, middle + 3], [long // 2 - 1, 1, long // 2 + 7, 6]]);
        # A teleporter in the south-west corner up to the east gallery.
        build.teleporter(3.5, 3.5, 0, float(long) - 3.0, 6.5, g, 90.0);
        # A closet under the south gallery behind a wall that opens when
        # shot (a secret).
        cx = long // 2 + 1;
        build.solid(cx - 1, 1, 0, cx + 5, 5, under);
        build.room(cx, 1, 0, cx + 3, 3, 4);
        build.secret_door(float(cx), 3.0, 0.0, float(cx + 3), 5.0, 4.0, 3);
        build.secret(float(cx), 1.0, 0.0, float(cx + 3), 3.0, 3.0);
        build.supply(float(cx) + 1.5, 2.0, 0, "item_armor2");
        # The way on from the floor opened from the gallery, its button
        # bringing in an ogre behind.
        press = build.push(float(long // 2) + 2.5, float(wide - 1), float(g) + 1.2, 3);
        build.doorway(foyer, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, foyer, long, wide, port, relayed(build, press, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(foyer, port);
            }
        }
        press +>:Fires:+> build.summon(1, 1, -7, e3m7_foe(dice, self.danger, True), 6.5, float(middle) + 0.5, 0, 0.0);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 2.5, 0, "item_shells");
        # The dead lie in wait about the floor, stirring as a body reaches
        # the middle; the gallery's guard wakes as it is reached.
        stir = build.touch(float(long // 2 - 3), float(middle - 3), 0.0, float(long // 2 + 1), float(middle + 3), 6.0);
        dead = build.waiting();
        stir +>:Fires:+> dead;
        for index in range(dice.between(2, 3)) {
            build.foe(8.5 + float(index) * 3.0, float(wide) - 6.5, 0, "monster_zombie", 270.0, waits=dead);
        }
        reached = build.touch(float(top[0]), float(top[1]), float(g), float(top[2]), float(top[3]), float(g + 6));
        guard = build.waiting();
        reached +>:Fires:+> guard;
        build.foe(float(long) - 3.0, float(wide) - 2.5, g, e3m7_foe(dice, self.danger, True), 180.0, waits=guard);
        rounds(build, e3m7_foe(dice, self.danger), 10.5, float(wide) - 2.5, float(long) - 7.5, float(wide) - 2.5, g);
        build.supply(float(long) - 3.0, 2.5, g, "item_health");
    }
}

"""A hall across a pit: a bridge drawn out over it by a shot button (or a
stair raised out of its floor by a button in it), a lift up out of it."""
node DrawbridgeHall(Prefab) {
    has deep: int = 9,
        tall: int = 14,
        form: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drawbridge hall";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(15, 17);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.form = dice.below(2);
        self.low = -2 * self.deep - 4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        low = -self.deep;
        hall = build.room(1, 1, low, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        x0 = 8;
        x1 = long - 9;
        build.solid(1, 1, low, x0, wide - 1, 0);
        build.solid(x1, 1, low, long - 1, wide - 1, 0);
        lane = middle - 1;
        if self.form == 0 {
            # The bridge over the pit, drawn out when the button on the far
            # wall is shot.
            shot = build.cue([build.button(float(long - 1), float(wide) - 3.5, 5.0, 2, "", True)], "button");
            relayed(build, shot, 0.5) +>:Fires:+> build.drawn(float(x0), float(lane), float(x1), float(lane + 3), 0, self.deep + 1);
            keep_run(build, hall, x0 - 1, 1, x0, wide - 1, 0);
            keep_run(build, hall, x0 - 1, lane, x0, lane + 3, 0);
            keep_run(build, hall, x1, lane, x1 + 1, lane + 3, 0);
            build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Shoot the button across the pit");
            dead_by = shot;
        } else {
            # A stair raised out of the pit's floor up to the far side by
            # the button down in the pit.
            steps = build.rising_steps(x1 - self.deep, lane, low, 0, self.deep, 3);
            press = build.push(float(x1 - self.deep - 3) + 0.5, float(wide - 1), float(low) + 1.2, 3);
            relayed(build, press, 0.5) +>:Fires:+> steps;
            keep_run(build, hall, x1, lane, x1 + 1, lane + 3, 0);
            keep_run(build, hall, x0 - 1, 2, x0, wide - 2, 0);
            dead_by = press;
        }
        # A lift up out of the pit onto the far side, a teleporter on its
        # floor back to the near side.
        lift(build, x1 - 3, 1, x1, 4, low, 0);
        keep_run(build, hall, x1, 1, x1 + 1, 4, 0);
        keep_run(build, hall, x1 - 4, 1, x1, 5, low);
        build.teleporter(float(x0) + 2.5, 2.5, low, 3.5, 3.5, 0, 0.0);
        keep_run(build, hall, x1, 4, x1 + 1, wide - 5, 0);
        raised_blocks(build, dice, x0 + 2, lane + 4, x1 - 5, wide - 4, low, 4, [[x1 - self.deep - 5, wide - 3, x1 - self.deep, wide - 1]]);
        # A closet in the far side's foot, behind a wall that opens when
        # shot (a secret).
        build.room(x1 + 1, wide - 5, low, x1 + 3, wide - 2, low + 4);
        build.secret_door(float(x1), float(wide - 5), float(low), float(x1 + 1), float(wide - 2), float(low + 4), 0);
        build.secret(float(x1 + 1), float(wide - 5), float(low), float(x1 + 3), float(wide - 2), float(low + 3));
        build.supply(float(x1) + 2.0, float(wide) - 3.5, low, "item_artifact_super_damage" if dice.chance(0.4) else "item_health");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The dead in the pit stir as the bridge (or the stair) moves; the
        # far side's guard wakes as a body drops in.
        stirred = build.waiting();
        dead_by +>:Fires:+> stirred;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 4 + index * 4) + 0.5, float(wide) - 3.5, low, "monster_zombie", 270.0, waits=stirred);
        }
        fell = build.touch(float(x0), 1.0, float(low), float(x1), float(wide - 1), float(low + 4));
        guard = build.waiting();
        fell +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 3.5, 4.5 + float(index) * 5.0, 0, e3m7_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        rounds(build, e3m7_foe(dice, self.danger), float(x0) + 2.5, float(middle) + 0.5, float(x1) - 5.5, float(middle) + 0.5, low);
        build.supply(2.5, float(wide) - 2.5, 0, "item_health");
        build.supply(float(long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""A hall over a deep cistern trench, a lift up to a walkway across it and
a stair down the far side, stepping stones across the trench for whoever
would jump, a teleporter back."""
node SlimeLifts(Prefab) {
    has walk: int = 7,
        deep: int = 7,
        tall: int = 16,
        stair_up: bool = True,
        stones: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern lifts";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(15, 17);
        self.walk = dice.between(6, 7);
        self.deep = dice.between(7, 9);
        self.tall = self.walk + 10;
        self.stair_up = dice.chance(0.5);
        self.stones = dice.chance(0.6);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        u = self.walk;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The trench across the middle, steps up out of it at both sides.
        tx0 = 9;
        tx1 = long - 9;
        build.pool(tx0, 1, -self.deep, tx1, wide - 1, 0, 2, False, True, True);
        stair(build, tx1 - self.deep, wide - 3, -self.deep, 0, self.deep, 2);
        if self.stones {
            # Stepping stones across, a cell of water between each.
            for x in range(tx0 + 3, tx1 - 1, 2) {
                build.solid(x, middle + 3, -self.deep, x + 1, middle + 5, 0);
            }
            keep_run(build, hall, tx0 - 1, middle + 3, tx0, middle + 5, 0);
            keep_run(build, hall, tx1, middle + 3, tx1 + 1, middle + 5, 0);
        }
        # The walkway over it from the lift's top to the far stair's.
        wx0 = 3 + u if self.stair_up else tx0 - 3;
        wx1 = tx1 + 1;
        build.solid(wx0, middle - 2, u - 1, wx1, middle + 1, u);
        if self.stair_up {
            stair(build, 3, middle - 2, 0, 0, u, 3);
        } else {
            lift(build, wx0 - 3, middle - 2, wx0, middle + 1, 0, u);
        }
        stair(build, wx1 + u - 1, middle - 2, 0, 2, u, 3);
        keep_run(build, hall, wx0, middle - 2, wx0 + 1, middle + 1, u);
        keep_run(build, hall, wx0 - 4, middle - 3, wx0, middle + 2, 0);
        build.teleporter(float(long) - 4.0, 3.0, 0, 3.0, 3.0, 0, 0.0);
        press = build.cue([build.button(float(long - 1), float(middle) + 3.5, float(u) + 2.0, 2, "", True)], "button");
        build.doorway(hall, self.enter);
        for port in self.taken {
            sealed_way(build, hall, long, wide, port, relayed(build, press, 0.5), "This door is opened elsewhere.");
        }
        build.touch(float(tx1 + 1), 1.0, 0.0, float(tx1 + 3), float(wide - 1), 6.0, True, "This door is opened elsewhere.");
        # The walkway's guard wakes as the lift rises; the dead wait on the
        # far side.
        rising = build.touch(float(wx0 - 3), float(middle - 2), float(u - 2), float(wx0 + 2), float(middle + 1), float(u + 4));
        guard = build.waiting();
        rising +>:Fires:+> guard;
        build.foe(float(tx0 + tx1) * 0.5, float(middle) - 0.5, u, e3m7_foe(dice, self.danger, True), 180.0, waits=guard);
        for index in range(dice.between(2, 3)) {
            build.foe(float(tx1) + 5.5 + float(index % 2) * 2.0, 3.5 + float(index) * 3.0, 0, e3m7_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        rounds(build, "monster_zombie", float(tx1) + 2.5, 2.5, float(tx1) + 2.5, float(wide) - 3.5, 0);
        build.supply(2.5, float(wide) - 2.5, 0, "item_health");
        build.supply(float(long) - 2.5, float(wide) - 2.5, 0, "item_spikes");
    }
}

"""A hall, a ledge high across its far end over a crypt, a stair of doors
raised by a shot button (or a lift let down by a button), a secret door
that opens a niche."""
node StairOfDoors(Prefab) {
    has ledge: int = 9,
        tall: int = 18,
        form: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Stair of doors";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(24, 28);
        self.wide = dice.between(16, 18);
        self.ledge = dice.between(9, 10);
        self.tall = self.ledge + dice.between(8, 10);
        self.form = dice.below(2);
        self.low = -self.ledge - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.ledge), Port(face=1, along=float(self.long - 4), floor=self.ledge), Port(face=3, along=float(self.long - 4), floor=self.ledge), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        h = self.ledge;
        middle = wide // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, h);
        # The ledge across the far end, a slab over the crypt under it.
        lx = long - 8;
        build.solid(lx, 1, h - 1, long - 1, wide - 1, h);
        for y in [3, wide - 4] {
            build.solid(lx, y, 0, lx + 1, y + 1, h - 1);
        }
        if self.form == 0 {
            # The stair of doors along the north wall, raised by the button
            # shot high on the ledge's face.
            steps = build.rising_steps(lx - h, wide - 5, 0, 0, h, 4);
            shot = build.cue([build.button(float(lx - 4), 1.0, float(h) + 3.0, 1, "", True)], "button");
            relayed(build, shot, 0.5) +>:Fires:+> steps;
            keep_run(build, hall, lx, wide - 5, lx + 1, wide - 1, h);
            build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Shoot the button high on the ledge");
            raised = shot;
        } else {
            # A lift held up at the ledge until the button by the way in
            # lets it down.
            held = held_lift(build, lx - 3, wide - 5, lx, wide - 1, 0, h);
            press = build.push(1.0, float(wide) - 3.5, 1.5, 0);
            relayed(build, press, 1.0) +>:Fires:+> held;
            keep_run(build, hall, lx, wide - 5, lx + 1, wide - 1, h);
            keep_run(build, hall, lx - 4, wide - 6, lx, wide - 1, 0);
            raised = press;
        }
        # Drops from the ledge's edge back to the floor.
        keep_run(build, hall, lx, 1, lx + 1, wide - 1, h);
        raised_blocks(build, dice, 3, 5, lx - 2, wide - 7, 0, 4, [[0, middle - 2, long, middle + 2], [7, 1, 14, 5]]);
        # A secret door in the south wall that, opened, opens a niche on
        # the ledge with the quad damage in it.
        build.solid(8, 1, 0, 13, 4, 6);
        build.room(9, 1, 0, 12, 3, 4);
        opened = secret_opener(build, 9.0, 3.0, 0.0, 12.0, 4.0, 4.0, 3);
        build.secret(9.0, 1.0, 0.0, 12.0, 3.0, 3.0);
        build.solid(long - 4, 3, h, long - 1, 8, self.tall);
        build.room(long - 3, 4, h, long - 1, 7, h + 5);
        build.widen(hall, long - 4, 4, h, long - 3, 7, h + 5);
        relayed(build, opened, 0.5) +>:Fires:+> build.opened(float(long - 4), 4.0, float(h), float(long - 3), 7.0, float(h + 5));
        build.supply(float(long) - 2.0, 5.5, h, "item_artifact_super_damage");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The dead under the ledge stir as the stair rises (or the lift
        # comes down); the ledge's guard wakes as it is reached.
        stirred = build.waiting();
        raised +>:Fires:+> stirred;
        for index in range(dice.between(2, 3)) {
            build.foe(float(lx) + 2.5 + float(index) * 2.0, 4.5 + float(index) * 3.0, 0, "monster_zombie", 180.0, waits=stirred);
        }
        up = build.touch(float(lx), float(wide - 5), float(h), float(lx + 3), float(wide - 1), float(h + 6));
        guard = build.waiting();
        up +>:Fires:+> guard;
        build.foe(float(long) - 5.5, 2.5, h, e3m7_foe(dice, self.danger, True), 180.0, waits=guard);
        up +>:Fires:+> build.summon(1, 1, -h - 2, e3m7_foe(dice, self.danger), 5.5, float(middle) + 0.5, 0, 0.0);
        rounds(build, "monster_ogre", 4.5, float(middle) + 0.5, float(lx) - 3.5, float(middle) + 0.5, 0);
        build.supply(2.5, 2.5, 0, "item_shells");
        build.supply(float(long) - 2.5, float(wide) - 2.5, h, "item_health");
    }
}

"""A long corridor under a walkway, spikes flying across it in two volleys
a second apart, the walkway climbed to at its end."""
node SpikeRhythm(Prefab) {
    has walk: int = 8,
        tall: int = 16,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike rhythm";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(13, 15);
        self.walk = dice.between(9, 10);
        self.tall = self.walk + dice.between(7, 9);
        self.climb = dice.below(2);
        self.low = -8;
        self.high = self.tall + 1;
        wy = self.wide - 6;
        self.enter = Port(face=2, along=float(wy // 2 + 1), floor=0);
        self.leaves = [
            Port(face=0, along=float(wy // 2), floor=0),
            Port(face=1, along=6.0, floor=self.walk),
            Port(face=0, along=float(self.wide - 3), floor=self.walk),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        u = self.walk;
        wy = wide - 6;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, u);
        # The walkway along the north, the whole length, on corbels.
        build.solid(1, wy, u - 1, long - 1, wide - 1, u);
        for x in range(7, long - 8, 6) {
            build.solid(x, wy, 0, x + 1, wy + 1, u - 1);
        }
        if self.climb == 0 {
            stair(build, long - 3 - u, wy - 3, 0, 0, u, 3);
            keep_run(build, hall, long - 5, wy, long - 2, wy + 1, u);
        } else {
            lift(build, long - 5, wy - 3, long - 2, wy, 0, u);
            keep_run(build, hall, long - 6, wy, long - 1, wy + 1, u);
            keep_run(build, hall, long - 6, wy - 4, long - 1, wy, 0);
        }
        keep_run(build, hall, 10, wy, 13, wy + 1, u);
        lift(build, 7, wy - 3, 10, wy, 0, u);
        keep_run(build, hall, 6, wy, 11, wy + 1, u);
        # The trap: shooters along the south wall, half firing as a body
        # comes into the corridor's middle, half a second after.
        a = 7;
        b = long - 9;
        zone = build.touch(float(a), 1.0, 0.0, float(b), float(wy), 5.0, False);
        zone.items[0]["wait"] = "1.5";
        later = build.delay(1.0);
        zone +>:Fires:+> later;
        for x in range(a + 1, b - 1, 2) {
            volley = zone if (x - a) % 4 == 1 else later;
            volley +>:Fires:+> build.spikes(float(x) + 0.5, 1.2, 2.5, 1);
        }
        for x in range(a + 2, b - 1, 4) {
            later +>:Fires:+> build.spikes(float(x) + 0.5, float(wide) - 1.2, 2.5, 3);
        }
        # A button on the walkway opens the corridor's far doors; a
        # teleporter at the far end back to the corridor's head.
        press = build.push(float(long // 2) + 0.5, float(wide - 1), float(u) + 1.2, 3);
        build.teleporter(float(long) - 8.5, 3.0, 0, 3.5, float(wy // 2) + 0.5, 0, 0.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, hall, long, wide, port, relayed(build, press, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(hall, port);
            }
        }
        keep_run(build, hall, 7, wy, long - 6, wy + 1, u);
        # A closet under the walkway at the corridor's head, behind a wall
        # that opens when shot (a secret).
        build.solid(2, wy, 0, 6, wide - 1, u - 1);
        build.room(3, wy + 2, 0, 5, wide - 2, 4);
        build.secret_door(3.0, float(wy), 0.0, 5.0, float(wy + 2), 4.0, 1);
        build.secret(3.0, float(wy + 2), 0.0, 5.0, float(wide - 2), 3.0);
        build.supply(4.0, float(wide) - 3.0, 0, "item_armor1");
        # The walkway's guard wakes with the first volley; hell knights
        # walk the corridor.
        guard = build.waiting();
        zone +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(long) - 8.5 - float(index) * 6.0, float(wide) - 2.5, u, e3m7_foe(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        rounds(build, e3m7_foe(dice, self.danger, True), float(long) - 5.5, 3.5, 9.5, 3.5, 0);
        build.supply(float(long) - 2.5, float(wide) - 2.5, u, "item_health");
    }
}

"""A hall of teleporters, each up to a balcony on a wall at its own
height."""
node PadGallery(Prefab) {
    has north: int = 6,
        east: int = 10,
        south: int = 14,
        tall: int = 23;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pad gallery";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(24, 26);
        self.wide = dice.between(22, 24);
        self.north = dice.between(6, 7);
        self.east = self.north + dice.between(4, 5);
        self.south = self.east + dice.between(4, 5);
        self.tall = self.south + 9;
        self.low = -7;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.north),
            Port(face=0, along=middle, floor=self.east),
            Port(face=3, along=float(self.long // 2), floor=self.south),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cx = long // 2;
        cy = wide // 2;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(4));
        for z in [self.north, self.east, self.south] {
            build.level(hall, z);
        }
        # The balconies: north, east and south, each a slab at its height.
        build.solid(7, wide - 4, self.north - 1, long - 6, wide - 1, self.north);
        build.solid(long - 4, 6, self.east - 1, long - 1, wide - 6, self.east);
        build.solid(7, 1, self.south - 1, long - 6, 4, self.south);
        keep_run(build, hall, 8, wide - 4, long - 7, wide - 3, self.north);
        keep_run(build, hall, 8, 3, long - 7, 4, self.south);
        keep_run(build, hall, long - 4, 7, long - 3, wide - 7, self.east);
        # The pads, in a row across the floor's middle.
        build.teleporter(float(cx) - 4.0, float(cy) + 0.5, 0, float(cx) + 0.5, float(wide) - 2.5, self.north, 90.0);
        build.teleporter(float(cx), float(cy) + 0.5, 0, float(long) - 2.5, float(cy) + 0.5, self.east, 0.0);
        build.teleporter(float(cx) + 4.0, float(cy) + 0.5, 0, float(cx) + 0.5, 2.5, self.south, 270.0);
        # A lift by the north balcony's west end.
        lift(build, 4, wide - 4, 7, wide - 1, 0, self.north);
        keep_run(build, hall, 7, wide - 4, 8, wide - 1, self.north);
        keep_run(build, hall, 3, wide - 5, 8, wide - 4, 0);
        lift(build, long - 7, wide - 9, long - 4, wide - 6, 0, self.east);
        keep_run(build, hall, long - 5, wide - 9, long - 3, wide - 6, self.east);
        keep_run(build, hall, long - 8, wide - 10, long - 4, wide - 5, 0);
        store = build.push(float(long - 1), float(cy) - 2.5, float(self.east) + 1.2, 2);
        build.solid(1, 1, 0, 4, 6, 6);
        build.room(1, 2, 0, 4, 5, 5);
        relayed(build, store, 0.5) +>:Fires:+> build.opened(3.0, 2.0, 0.0, 4.0, 5.0, 5.0);
        build.supply(2.0, 3.5, 0, "item_rockets");
        # A closet off the south balcony behind a wall that opens when shot
        # (a secret).
        build.solid(long - 9, 1, self.south, long - 6, 4, self.tall);
        build.room(long - 8, 1, self.south, long - 6, 3, self.south + 4);
        build.secret_door(float(long - 9), 1.0, float(self.south), float(long - 8), 3.0, float(self.south + 4), 0);
        build.secret(float(long - 8), 1.0, float(self.south), float(long - 6), 3.0, float(self.south + 3));
        build.supply(float(long) - 7.0, 2.0, self.south, "item_artifact_super_damage" if dice.chance(0.3) else "item_armor2");
        # The floor's way on opened by a button on the north balcony.
        press = build.push(float(long - 8) + 0.5, float(wide - 1), float(self.north) + 1.2, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, hall, long, wide, port, relayed(build, press, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(hall, port);
            }
        }
        raised_blocks(build, dice, 3, 3, long - 5, wide - 7, 0, 5, [[0, cy - 3, 4, cy + 3], [3, 3, 7, wide - 6], [3, cy + 3, 12, cy + 6], [cx - 6, cy - 2, cx + 6, cy + 3], [long - 9, 1, long, wide], [0, 0, 5, 7]]);
        # Each balcony's guard wakes as a body is set down there.
        landings = [[float(cx) + 0.5, float(wide) - 2.5, float(self.north)], [float(long) - 2.5, float(cy) + 0.5, float(self.east)], [float(cx) + 0.5, 2.5, float(self.south)]];
        for (index, spot) in enumerate(landings) {
            arrived = build.touch(spot[0] - 1.5, spot[1] - 1.5, spot[2], spot[0] + 1.5, spot[1] + 1.5, spot[2] + 6.0);
            guard = build.waiting();
            arrived +>:Fires:+> guard;
            if index == 0 {
                build.foe(float(cx) + 5.5, float(wide) - 2.5, self.north, e3m7_foe(dice, self.danger), 180.0, waits=guard);
            } elif index == 1 {
                build.foe(float(long) - 2.5, float(cy) + 4.5, self.east, e3m7_foe(dice, self.danger, True), 270.0, waits=guard);
            } else {
                build.foe(float(cx) - 4.5, 2.5, self.south, e3m7_foe(dice, self.danger, True), 0.0, waits=guard);
            }
        }
        for index in range(dice.between(2, 3)) {
            build.foe(4.5 + float(index) * 3.0, float(cy) + 4.5, 0, e3m7_foe(dice, self.danger), 0.0);
        }
        rounds(build, "monster_zombie", 4.5, 4.5, 4.5, float(wide) - 6.5, 0);
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 8, "monster_wizard", 0.0);
        build.supply(float(cx) - 4.5, 2.5, self.south, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""The key room: a crypt below a landing, the key on a tomb; taking it opens
the closets and teleports the dead in."""
node HauntedCrypt(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 7,
        tall: int = 12,
        steps_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted crypt (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(7, 8);
        self.tall = dice.between(11, 13);
        self.steps_up = dice.chance(0.5);
        self.low = -2 * self.deep - 2;
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
        low = -self.deep;
        crypt = build.room(1, 1, low, long - 1, side, self.tall, variant=dice.below(3));
        build.level(crypt, 0);
        build.doorway(crypt, self.enter);
        # The landing in, the drop off it, and the way back up.
        build.solid(1, 1, low, 6, side, 0);
        keep_run(build, crypt, 5, 2, 6, side - 1, 0);
        if self.steps_up {
            # A stair raised up the landing's face by the button on it.
            steps = build.rising_steps(6 + self.deep - 1, cy - 1, low, 2, self.deep, 3);
            relayed(build, build.push(float(6 + self.deep) + 1.5, float(side), float(low) + 1.2, 3), 0.5) +>:Fires:+> steps;
            build.touch(6.0, 1.0, float(low), 10.0, float(side), float(low + 4), True, "A button raises the stair");
        } else {
            lift(build, 6, cy - 1, 9, cy + 2, low, 0);
        }
        build.solid(long - 6, cy - 1, low, long - 3, cy + 2, low + 2);
        # A closet in the landing's foot, its door sunk by the button on
        # the crypt's far wall: health in it.
        build.room(3, side - 4, low, 6, side - 1, low + 5);
        store = build.push(float(long - 1), float(side) - 2.5, float(low) + 1.2, 2);
        relayed(build, store, 0.5) +>:Fires:+> build.sinking(5.0, float(side - 4), 6.0, float(side - 1), low + 5, 5);
        build.supply(4.0, float(side) - 2.5, low, "item_health");
        pillars(build, 12, 3, long - 7, side - 2, low, self.tall, 4, [[5, cy - 3, long, cy + 4]]);
        # The key on the tomb: taking it opens the closets and teleports
        # the dead in behind.
        fields: dict[str, str] = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(long) - 4.5, float(cy) + 0.5, low + 2);
        taken = build.cue([fields], "key");
        for (index, at) in enumerate([10, long - 6]) {
            build.room(at, side + 1, low, at + 3, side + 4, low + 7);
            build.widen(crypt, at, side, low, at + 3, side + 1, low + 6);
            taken +>:Fires:+> bursting(build, float(at), float(side), float(low), float(at + 3), float(side + 1), float(low + 6));
            build.foe(float(at) + 1.5, float(side) + 2.5, low, e3m7_foe(dice, self.danger, True) if index == 0 else "monster_zombie", 270.0);
        }
        taken +>:Fires:+> build.summon(1, 1, low - 7, "monster_zombie", 3.5, 3.5, 0, 0.0);
        # A secret alcove off the crypt's floor behind a wall that opens
        # when shot.
        build.solid(long - 5, 1, low, long - 1, 4, low + 5);
        build.room(long - 3, 1, low, long - 1, 3, low + 4);
        build.secret_door(float(long - 5), 1.0, float(low), float(long - 3), 3.0, float(low + 4), 0);
        build.secret(float(long - 3), 1.0, float(low), float(long - 1), 3.0, float(low + 3));
        build.supply(float(long) - 2.0, 2.0, low, "item_health");
        fell = build.touch(6.0, 1.0, float(low), float(long - 1), float(side), float(low + 4));
        dead = build.waiting();
        fell +>:Fires:+> dead;
        build.foe(float(long) - 2.5, float(side) - 2.5, low, e3m7_foe(dice, self.danger), 180.0, waits=dead);
        rounds(build, "monster_zombie", 10.5, float(cy) + 3.5, float(long) - 7.5, float(cy) + 3.5, low);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a hall under a balcony, the teleporter to the sealed
chamber of the slipgate behind a door a shot button opens."""
node HauntedExit(Prefab) {
    has key: str = "",
        tall: int = 16,
        balcony: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Haunted exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M7;
        self.district = level_district(E3M7);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.balcony = dice.between(7, 8);
        self.tall = self.balcony + dice.between(8, 9);
        self.low = -7;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        b = self.balcony;
        wall = 8;
        sealed = long - 8;
        hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, sealed, wide - 1, self.tall, variant=dice.below(3));
        chamber = build.room(sealed + 1, 1, 0, long - 1, wide - 1, 10, variant=dice.below(3));
        build.level(chamber, 0);
        build.level(room, b);
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The balcony along the north wall, foes on it.
        build.solid(wall + 1, wide - 4, b - 1, sealed, wide - 1, b);
        keep_run(build, room, wall + 1, wide - 4, sealed, wide - 3, b);
        # The teleporter to the sealed chamber, in an alcove behind a door
        # that the button shot high on the far wall opens.
        ax = sealed - 4;
        build.solid(ax - 1, 1, 0, sealed, 5, self.tall);
        build.room(ax, 1, 0, sealed, 4, 7);
        build.widen(room, ax, 4, 0, sealed, 5, 6);
        shot = build.cue([build.button(float(sealed), float(middle) + 0.5, 9.0, 2, "", True)], "button");
        alcove = build.opened(float(ax), 4.0, 0.0, float(sealed), 5.0, 6.0);
        relayed(build, shot, 0.5) +>:Fires:+> alcove;
        lift(build, wall + 1, wide - 7, wall + 4, wide - 4, 0, b);
        keep_run(build, room, wall + 1, wide - 4, wall + 4, wide - 3, b);
        build.push(float(sealed), float(wide) - 2.5, float(b) + 1.2, 2) +>:Fires:+> alcove;
        raised_blocks(build, dice, wall + 2, 1, ax - 2, wide - 5, 0, 4, [[wall, middle - 3, long, middle + 3], [wall, wide - 8, wall + 5, wide - 1]]);
        build.teleporter(float(ax) + 2.0, 2.5, 0, float(sealed) + 2.5, float(middle) + 0.5, 0, 0.0);
        build.touch(float(ax - 3), 4.0, 0.0, float(sealed), 8.0, 6.0, True, "This door is opened elsewhere.");
        build.way_out(float(long) - 3.0, float(middle), 0);
        pillars(build, wall + 3, 7, sealed - 3, wide - 5, 0, b - 1, 4, [[0, middle - 2, long, middle + 3]]);
        # Coming through the door wakes the balcony's foes and teleports in
        # the dead behind.
        through = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guard = build.waiting();
        through +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall + 3 + index * 4) + 0.5, float(wide) - 2.5, b, e3m7_foe(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        through +>:Fires:+> build.summon(1, 1, -7, "monster_zombie", 4.5, float(middle) + 0.5, 0, 0.0);
        rounds(build, e3m7_foe(dice, self.danger), float(wall) + 2.5, float(middle) + 0.5, float(ax) - 2.5, float(middle) + 0.5, 0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m7's stretches: [name, role]."""
glob E3M7_STRETCHES: list[list[str]] = [
         ["foyer", "start"],
         ["drawbridge", "flow"],
         ["slime", "flow"],
         ["stair", "flow"],
         ["stair", "hub"],
         ["spikes", "flow"],
         ["pads", "hub"],
         ["pads", "flow"],
         ["crypt", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m7's stretches by its name."""
def make_e3m7(name: str, key: str) -> Prefab {
    if name == "foyer" {
        return HauntedFoyer();
    }
    if name == "drawbridge" {
        return DrawbridgeHall();
    }
    if name == "slime" {
        return SlimeLifts();
    }
    if name == "stair" {
        return StairOfDoors();
    }
    if name == "spikes" {
        return SpikeRhythm();
    }
    if name == "pads" {
        return PadGallery();
    }
    if name == "crypt" {
        return HauntedCrypt(key=key if key else "key_silver");
    }
    return HauntedExit(key=key);
}
