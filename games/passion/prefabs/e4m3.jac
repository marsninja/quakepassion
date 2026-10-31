"""Prefabs drawn from e4m3, the Elder God Shrine: a shrine of stone in a
court opened by shooting its window, crypts of the dead whose doors fly
open as the player passes, a nave whose altar calls fiends in by
teleporter in wave after wave, an arena whose foes' deaths are counted
to open the way on, walls that are not there (secrets behind them), the
key in a cage its guardian's death opens. Raised in e4m3's own palette.

- `ShrineCourt`: the start. A court under the sky, a pool between four
  obelisks, the shrine across its far end, its door up a plinth; by the
  dice the door opens only when the window high over it is shot ("You
  must shoot the window"), which brings fiends in by teleporter. A wall
  of the court that is not there hides a quad damage.
- `ZombieCrypts`: a corridor between rows of crypts, each shut by a door
  that flies open as the player comes level with it; the far crypt's
  button opens the corridor's end ("This door is opened elsewhere."); a
  lift up to a gallery over the corridor's end.
- `ElderNave`: a nave between colonnades, a deep font down its middle by
  the dice, galleries over the aisles up
  stairs (or a lift), an altar at its head with a teleporter up to a
  gallery; reaching the altar brings fiends in by teleporter in waves, a
  relay timing each; a secret behind a wall that is not there; ways on
  from the floor, the altar and the galleries (a hub).
- `CountedArena`: a hall, an arena sunk in its middle round an altar,
  flooded to the waist by the dice; its foes wake as it is entered and their deaths are counted: the last opens
  the way on ("The door has opened.") and brings in more by teleporter.
- `GuardianCage`: the key room. The key in a cage at a hall's far end
  that opens when its guardian dies; taking the key opens the closets
  and teleports the dead in; a secret behind a wall that is not there.
- `ShrineExit`: the end. A door (a key's, as a gate) into a shrine, the
  slipgate on an island in a pool reached stone by stone ("Are you sure
  you want to leave"), the dead teleported in as it is crossed."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix }
import from .common { stair, pillars, key_ambush, lift, key_item }
import from .e3m5 { keep_run, sealed_way, bursting }
import from .e3m6 { rounds }
import from .e3m7 { relayed }
import from .e4m6 { flood }

glob E4M3: str = "q1:e4m3";

"""e4m3's foes: the dead above all, knights, fiends and spawn deeper in."""
glob E4M3_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_zombie", "monster_knight"], strong=["monster_wizard"], heavy_light=["monster_knight", "monster_ogre"], heavy_strong=["monster_demon1", "monster_tarbaby"]);

"""A wall that is not there: an opening of the prefab's cells x0..x1,
y0..y1 from lift z (`high` lifts) cut as the air of `space` and filled by
an illusion drawn as the district's wall, into a closet `closet`
[x0, y0, x1, y1] carved beyond it, a secret in the closet and a pickup of
`kind`."""
def false_wall(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, high: int, closet: list[int], kind: str) {
    build.room(closet[0], closet[1], z, closet[2], closet[3], z + high);
    build.widen(space, x0, y0, z, x1, y1, z + high);
    build.put_box({"classname": "func_illusionary"}, float(x0), float(y0), float(z), float(x1), float(y1), float(z + high), kit_of(build.district).wall);
    build.secret(float(closet[0]), float(closet[1]), float(z), float(closet[2]), float(closet[3]), float(z + 3));
    build.supply(float(closet[0] + closet[2]) * 0.5, float(closet[1] + closet[3]) * 0.5, z, kind);
}

"""A wave of foes teleported in when `cue` fires, `seconds` on: each a
summon from a sealed closet of the prefab's cells under `spots` (x0, y0,
z0 each) to the matching point of `lands` ([x, y, z] each)."""
def wave(build: Raising, cue: Cue, seconds: float, kinds: list[str], spots: list[list[int]], lands: list[list[float]]) {
    later = relayed(build, cue, seconds);
    for index in range(min(len(kinds), len(spots), len(lands))) {
        spot = spots[index];
        land = lands[index];
        later +>:Fires:+> build.summon(spot[0], spot[1], spot[2], kinds[index], land[0], land[1], int(land[2]), 180.0);
    }
}

import from ..space { Space }

"""The start: a court, a pool between obelisks, the shrine's door up a
plinth, opened by shooting the window over it."""
node ShrineCourt(Prefab) {
    has plinth: int = 3,
        tall: int = 20,
        window: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shrine court";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(30, 34);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(18, 22);
        self.plinth = dice.between(3, 4);
        self.window = dice.chance(0.6);
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.plinth), Port(face=1, along=6.0, floor=0), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        court = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.plinth);
        sx = long - 8;
        build.solid(sx, 1, 0, long - 1, wide - 1, self.tall - 2);
        build.widen(court, sx, middle - 2, self.plinth, long - 1, middle + 2, self.plinth + 8);
        build.solid(sx - 4, middle - 3, 0, sx, middle + 3, self.plinth);
        stair(build, sx - 4 - self.plinth, middle - 2, 0, 0, self.plinth, 4);
        keep_run(build, court, sx - 4, middle - 2, sx - 3, middle + 2, self.plinth);
        # The pool and the obelisks round it.
        px = 5;
        build.pool(px, middle - 5, -6, px + 8, middle + 5, 0, 2);
        for corner in [[px - 2, middle - 7], [px + 9, middle - 7], [px - 2, middle + 6], [px + 9, middle + 6]] {
            build.solid(corner[0], corner[1], 0, corner[0] + 1, corner[1] + 1, 8);
        }
        # The shrine's door, shut until the window over it is shot (by the
        # dice); shot, it brings fiends in by teleporter behind.
        if self.window {
            door: dict[str, str] = {"wait": "-1", "message": "You must shoot the window"};
            build.rising_door(float(sx), float(middle - 2), float(self.plinth), float(sx + 1), float(middle + 2), float(self.plinth + 8), door);
            shot = build.cue([build.button(float(sx), float(middle) + 0.5, float(self.plinth) + 10.0, 2, "", True)], "button");
            relayed(build, shot, 0.5) +>:Fires:+> build.cue([door], "door");
            build.touch(float(sx - 4 - self.plinth), float(middle - 2), 0.0, float(sx - 4), float(middle + 2), 6.0, True, "You must shoot the window");
            wave(build, shot, 2.0, [E4M3_FOES.pick(dice, self.danger, True), "monster_demon1" if self.danger > 0.3 else "monster_knight"], [[1, 1, -8], [1, wide - 5, -8]], [[3.5, 3.5, 0.0], [3.5, float(wide) - 3.5, 0.0]]);
        } else {
            # The door opened by a button beside it on the plinth.
            door2: dict[str, str] = {"wait": "-1", "message": "This door is opened elsewhere."};
            build.rising_door(float(sx), float(middle - 2), float(self.plinth), float(sx + 1), float(middle + 2), float(self.plinth + 8), door2);
            press = build.push(float(sx), float(middle) + 2.5, float(self.plinth) + 1.2, 2);
            relayed(build, press, 0.5) +>:Fires:+> build.cue([door2], "door");
            wave(build, press, 2.0, [E4M3_FOES.pick(dice, self.danger, True)], [[1, 1, -8]], [[3.5, 3.5, 0.0]]);
        }
        # A wall of the court that is not there, a closet behind with the
        # quad damage.
        false_wall(build, court, sx, 3, sx + 1, 6, 0, 5, [sx + 1, 3, sx + 4, 6], "item_artifact_super_damage");
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        # The dead rise round the pool as a body comes to it; knights walk
        # the court.
        near = build.touch(float(px - 3), float(middle - 8), 0.0, float(px + 11), float(middle + 8), 6.0);
        dead = build.waiting();
        near +>:Fires:+> dead;
        for index in range(dice.between(3, 4)) {
            build.foe(float(px) + 1.5 + float(index) * 5.0, 2.5 if index % 2 == 0 else float(wide) - 2.5, 0, E4M3_FOES.pick(dice, self.danger), 180.0, waits=dead);
        }
        rounds(build, "monster_knight", float(sx) - 6.5, 2.5, float(sx) - 6.5, float(wide) - 2.5, 0);
        up = build.touch(float(sx - 4 - self.plinth), float(middle - 3), 0.0, float(sx - 4), float(middle + 3), 6.0);
        porch = build.waiting();
        up +>:Fires:+> porch;
        build.foe(float(sx) - 2.0, float(middle) + 0.5, self.plinth, E4M3_FOES.pick(dice, self.danger, True), 180.0, waits=porch);
        build.supply(float(sx) - 2.5, 2.5, 0, "item_health");
    }
}

"""A corridor between rows of crypts, each door flying open as a body comes
level with it, the corridor's end opened by the far crypt's button."""
node ZombieCrypts(Prefab) {
    has tall: int = 11,
        gallery: int = 7;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zombie crypts";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(16, 18);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(9, 10);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0), Port(face=0, along=float(self.wide - 3), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        hx = long - 7;
        corridor = build.room(1, 6, 0, hx, wide - 6, self.tall, variant=dice.below(3));
        end = build.room(hx, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(end, self.gallery);
        build.room(1, 1, 0, 3, wide - 1, self.tall, variant=dice.below(3));
        build.widen(corridor, 3, 6, 0, 4, wide - 6, self.tall);
        # The end hall sealed from the corridor until the far crypt's
        # button is pressed.
        build.solid(hx - 1, 6, 0, hx, wide - 6, self.tall);
        build.widen(end, hx - 1, middle - 2, 0, hx, middle + 2, 7);
        end_door: dict[str, str] = {"wait": "-1", "message": "This door is opened elsewhere."};
        build.rising_door(float(hx - 1), float(middle - 2), 0.0, float(hx), float(middle + 2), 7.0, end_door);
        opens = build.cue([end_door], "door");
        x = 4;
        index = 0;
        last_x = 4;
        while x + 5 <= hx - 2 {
            # A touch across the corridor level with the pair of crypts
            # sets both their doors flying open.
            level = build.touch(float(x), 6.0, 0.0, float(x + 5), float(wide - 6), 6.0);
            loose = build.waiting();
            level +>:Fires:+> loose;
            for south in [True, False] {
                y0 = 1 if south else wide - 5;
                door_y = 5 if south else wide - 6;
                crypt = build.room(x, y0, 0, x + 5, y0 + 4, 7, variant=dice.below(3));
                build.widen(crypt, x + 1, door_y, 0, x + 4, door_y + 1, 6);
                level +>:Fires:+> bursting(build, float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 6.0);
                build.foe(float(x) + 2.5, float(y0) + 2.0, 0, "monster_zombie" if index % 3 != 2 else E4M3_FOES.pick(dice, self.danger, True), 90.0 if south else 270.0, waits=loose);
                if index % 2 == 0 {
                    build.supply(float(x) + 4.0, float(y0) + 1.0, 0, "item_health" if south else "item_spikes");
                }
                index += 1;
            }
            last_x = x;
            x += 6;
        }
        # The button in the far north crypt opens the end hall.
        relayed(build, build.push(float(last_x) + 2.5, float(wide - 1), 1.2, 3), 0.5) +>:Fires:+> opens;
        # A gallery over the end hall's far side, a lift up to it.
        g = self.gallery;
        build.solid(long - 4, 1, g - 1, long - 1, wide - 1, g);
        lift(build, hx, wide - 5, long - 4, wide - 2, 0, g);
        keep_run(build, end, long - 4, wide - 5, long - 3, wide - 2, g);
        keep_run(build, end, hx, wide - 6, long - 4, wide - 1, 0);
        build.doorway(corridor, self.enter);
        for port in self.taken {
            build.doorway(end, port);
        }
        inside = build.touch(float(hx), float(middle - 2), 0.0, float(long - 4), float(middle + 2), 6.0);
        end_guard = build.waiting();
        inside +>:Fires:+> end_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(long) - 5.5, 3.5 + float(index) * 3.0, 0, E4M3_FOES.pick(dice, self.danger), 180.0, waits=end_guard);
        }
        build.foe(float(long) - 2.5, float(middle) + 0.5, g, E4M3_FOES.pick(dice, self.danger, True), 180.0, waits=end_guard);
        rounds(build, "monster_zombie", 5.5, float(middle) + 0.5, float(hx) - 3.5, float(middle) + 0.5, 0);
    }
}

"""A nave between colonnades, galleries over the aisles, an altar at its
head that calls fiends in by teleporter in waves."""
node ElderNave(Prefab) {
    has gallery: int = 6,
        altar: int = 3,
        tall: int = 20,
        climb: int = 0,
        font: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elder nave";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(24, 26);
        self.gallery = dice.between(6, 7);
        self.altar = dice.between(3, 4);
        self.tall = self.gallery + dice.between(12, 14);
        self.climb = dice.below(2);
        self.font = dice.chance(0.7);
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.altar),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=4.0, floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        nave = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(4));
        build.level(nave, self.gallery);
        build.level(nave, self.altar);
        under = self.gallery - 1;
        south = 7;
        north = wide - 7;
        build.solid(6, 1, under, long - 1, south, self.gallery);
        build.solid(6, north, under, long - 1, wide - 1, self.gallery);
        for x in range(7, long - 1, 3) {
            build.solid(x, south - 1, 0, x + 1, south, under);
            build.solid(x, north, 0, x + 1, north + 1, under);
        }
        if self.climb == 0 {
            stair(build, long - 14, south, 0, 0, self.gallery, 2);
            stair(build, long - 14, north - 2, 0, 0, self.gallery, 2);
            keep_run(build, nave, long - 9, south - 1, long - 6, south, self.gallery);
            keep_run(build, nave, long - 9, north, long - 6, north + 1, self.gallery);
        } else {
            lift(build, 6, south, 9, south + 3, 0, self.gallery);
            lift(build, 6, north - 3, 9, north, 0, self.gallery);
            keep_run(build, nave, 6, south - 1, 9, south, self.gallery);
            keep_run(build, nave, 6, north, 9, north + 1, self.gallery);
            keep_run(build, nave, 5, south, 10, south + 4, 0);
            keep_run(build, nave, 5, north - 4, 10, north, 0);
        }
        # The altar at the nave's head, a stair up its face.
        ax = long - 6;
        build.solid(ax, middle - 3, 0, long - 1, middle + 3, self.altar);
        stair(build, ax - self.altar, middle - 2, 0, 0, self.altar, 4);
        build.teleporter(float(long) - 3.0, float(middle) + 2.0, self.altar, 10.0, float(wide) - 3.5, self.gallery, 0.0);
        # Reaching the altar calls fiends in by teleporter, in waves.
        reached = build.touch(float(ax - self.altar), float(middle - 2), 0.0, float(ax), float(middle + 2), 6.0);
        kinds = [E4M3_FOES.pick(dice, self.danger, True), "monster_demon1" if self.danger > 0.4 else "monster_knight"];
        wave(build, reached, 1.0, kinds, [[1, 1, -8], [1, 5, -8]], [[8.5, float(middle) - 3.5, 0.0], [8.5, float(middle) + 3.5, 0.0]]);
        wave(build, reached, 12.0, [E4M3_FOES.pick(dice, self.danger), E4M3_FOES.pick(dice, self.danger)], [[1, wide - 5, -8], [1, wide - 9, -8]], [[float(long) - 10.5, float(middle) + 0.5, 0.0], [12.5, float(middle) - 4.5, 0.0]]);
        # A font down the nave's middle, deep, a stair out at each end of
        # its near side.
        if self.font {
            build.pool(11, middle - 3, -6, ax - self.altar - 2, middle + 3, 0, 2, False, True, True);
        }
        # A wall of the south gallery that is not there, a closet behind.
        build.solid(14, 1, self.gallery, 18, 4, self.gallery + 6);
        false_wall(build, nave, 15, 3, 17, 4, self.gallery, 4, [15, 1, 17, 3], "item_armor2");
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        entered = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 6.0);
        pews = build.waiting();
        entered +>:Fires:+> pews;
        # On the nave's floor beside the font, short of the stairs up, and
        # one in the aisle.
        for index in range(dice.between(3, 4)) {
            at = [9.5 + float(index) * 2.0, float(middle) + (4.5 if index % 2 == 0 else -4.5)] if index < 3 else [10.5, 3.5];
            build.foe(at[0], at[1], 0, E4M3_FOES.pick(dice, self.danger), 0.0, waits=pews);
        }
        rounds(build, E4M3_FOES.pick(dice, self.danger, True), 12.5, 3.5, float(long) - 4.5, 3.5, self.gallery);
        rounds(build, "monster_knight", float(long) - 4.5, float(wide) - 3.5, 12.5, float(wide) - 3.5, self.gallery);
        build.supply(float(long) - 3.0, float(middle) - 1.5, self.altar, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""A hall, an arena sunk round an altar; its foes' deaths counted open the
way on and bring in more by teleporter."""
node CountedArena(Prefab) {
    has sunk: int = 4,
        tall: int = 16,
        count: int = 3,
        flooded: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Counted arena";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 24);
        self.sunk = dice.between(4, 6);
        self.tall = dice.between(15, 17);
        self.count = dice.between(2, 3);
        self.flooded = dice.chance(0.6);
        self.low = -self.sunk - 8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cy = wide // 2;
        low = -self.sunk;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        # The arena sunk in the middle, a stair down at each end, an altar
        # standing in it.
        ax0 = 7;
        ax1 = long - 7;
        build.widen(hall, ax0, 6, low, ax1, wide - 6, 0);
        stair(build, ax0 + 1, 6 + self.sunk - 1, low, 3, self.sunk, 3);
        stair(build, ax1 - 4, wide - 6 - self.sunk, low, 1, self.sunk, 3);
        keep_run(build, hall, ax0 + 1, 5, ax0 + 4, 6, 0);
        keep_run(build, hall, ax1 - 4, wide - 6, ax1 - 1, wide - 5, 0);
        mx = (ax0 + ax1) // 2;
        build.solid(mx - 2, cy - 2, low, mx + 2, cy + 2, 1);
        # Flooded by the dice to a body's waist, the stairs rising out of it.
        if self.flooded {
            flood(build, ax0, 6, low, ax1, wide - 6, -1);
        }
        keep_run(build, hall, ax0 - 1, 6, ax0, wide - 6, 0);
        keep_run(build, hall, ax1, 6, ax1 + 1, wide - 6, 0);
        # The arena's foes, woken as it is entered; their deaths counted.
        into = build.touch(float(ax0), 6.0, float(low), float(ax1), float(wide - 6), float(low + 4));
        guard = build.waiting();
        into +>:Fires:+> guard;
        tally_name = build.name("tally");
        counted = build.tally(self.count, "The door has opened.");
        counted.items[0]["targetname"] = tally_name;
        for index in range(self.count) {
            build.foe(float(mx - 5 + index * 4) + 0.5, float(cy) + (3.5 if index % 2 == 0 else -3.5), low, "monster_hell_knight" if index == 0 and self.danger > 0.3 else "monster_knight", 0.0, tally_name, guard);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(mx) + 0.5, float(cy) + 0.5, 1, "monster_wizard", 0.0, waits=guard);
        }
        # The last death opens the way on and teleports more in.
        build.doorway(hall, self.enter);
        for port in self.taken {
            sealed_way(build, hall, long, wide, port, counted, "This door is opened elsewhere.");
        }
        wave(build, counted, 1.0, [E4M3_FOES.pick(dice, self.danger, True)], [[1, 1, low - 8]], [[float(long) - 4.5, float(cy) + 0.5, 0.0]]);
        # A wall of the hall that is not there, a closet behind.
        build.solid(1, 1, 0, 5, 5, 6);
        false_wall(build, hall, 2, 4, 4, 5, 0, 5, [1, 1, 4, 4], "item_health");
        rounds(build, "monster_knight", 6.5, 3.5, float(long) - 3.5, 3.5, 0);
        rounds(build, "monster_zombie", float(long) - 3.5, float(wide) - 3.5, 3.5, float(wide) - 3.5, 0);
        build.supply(2.5, float(wide) - 2.5, 0, "item_rockets");
        build.supply(float(mx) + 0.5, float(cy) + 0.5, 1, "item_health");
    }
}

"""The key in a cage at a hall's far end that opens when its guardian dies;
taking the key opens the closets and teleports the dead in."""
node GuardianCage(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guardian cage (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(14, 16);
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
        long = self.long;
        side = self.hall_wide - 1;
        cy = side // 2;
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        cx = long - 5;
        build.solid(cx + 1, cy - 3, 0, long - 1, cy - 2, 7);
        build.solid(cx + 1, cy + 2, 0, long - 1, cy + 3, 7);
        build.solid(cx, cy - 3, 6, long - 1, cy + 3, self.tall);
        cage = build.name("cage");
        build.rising_door(float(cx), float(cy - 2), 0.0, float(cx + 1), float(cy + 2), 6.0, {"targetname": cage, "wait": "-1"});
        guardian = "monster_shambler" if self.danger > 0.7 else "monster_hell_knight";
        build.foe(float(cx) - 4.5, float(cy) + 0.5, 0, guardian, 180.0, cage);
        fields: dict[str, str] = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(long) - 2.5, float(cy) + 0.5, 0);
        taken = build.cue([fields], "key");
        for at in [3, cx - 5] {
            build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(hall, at, side, 0, at + 3, side + 1, 6);
            taken +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E4M3_FOES.pick(dice, self.danger) if at == 3 else "monster_zombie", 270.0);
        }
        wave(build, taken, 1.5, ["monster_zombie", "monster_zombie"], [[1, 1, -9], [6, 1, -9]], [[4.5, float(cy) - 2.5, 0.0], [4.5, float(cy) + 3.5, 0.0]]);
        # A wall by the way in that is not there, a closet behind.
        build.solid(5, 1, 0, 9, 4, 6);
        false_wall(build, hall, 6, 3, 8, 4, 0, 5, [6, 1, 8, 3], "item_spikes");
        # A store by the cage, its door sunk by a button on the south wall.
        if dice.chance(0.6) {
            build.solid(9, 1, 0, 13, 4, 6);
            build.room(10, 1, 0, 12, 4, 5);
            relayed(build, build.push(14.5, 1.0, 1.2, 1), 0.5) +>:Fires:+> build.sinking(10.0, 3.0, 12.0, 4.0, 5, 5);
            build.supply(11.0, 2.0, 0, "item_health");
        }
        come = build.touch(1.0, 1.0, 0.0, 5.0, float(side), 6.0);
        dead = build.waiting();
        come +>:Fires:+> dead;
        build.foe(4.5, 2.5, 0, "monster_zombie", 0.0, waits=dead);
        build.foe(float(cx) - 7.5, float(side) - 2.5, 0, E4M3_FOES.pick(dice, self.danger), 180.0, waits=dead);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
    }
}

"""The end: a door into a shrine, the slipgate on an island in a pool
reached stone by stone."""
node ShrineExit(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shrine exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M3;
        self.district = level_district(E4M3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
        self.low = -9;
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
        wall = 8;
        hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=dice.below(3));
        shrine = build.room(wall + 1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(shrine, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # The pool to the far wall, stones across to the island, steps up
        # out of the water onto the island's far side.
        x0 = wall + 3;
        build.pool(x0, 1, -4, long - 1, wide - 1, 0, 2);
        ix = long - 5;
        build.solid(ix - 2, middle - 2, -4, ix + 2, middle + 2, 0);
        if dice.chance(0.5) {
            for at in [x0 + 1, x0 + 3, x0 + 5] {
                if at < ix - 3 {
                    build.solid(at, middle - 1, -4, at + 1, middle + 1, 0);
                }
            }
        } else {
            # A causeway just over the water instead, out to the island.
            build.solid(x0, middle - 1, -1, ix - 2, middle + 2, 0);
        }
        stair(build, ix - 1, middle - 6, -4, 1, 4, 2);
        build.way_out(float(ix), float(middle), 0);
        build.touch(float(ix - 2), float(middle - 2), 0.0, float(ix + 2), float(middle + 2), 6.0, False, "Are you sure you want to leave");
        # Crossing the stones, the dead teleported in on the shore behind.
        crossing = build.touch(float(x0), float(middle - 1), -1.0, float(x0 + 6), float(middle + 1), 5.0);
        wave(build, crossing, 1.0, ["monster_zombie", E4M3_FOES.pick(dice, self.danger, True)], [[1, 1, -9], [1, wide - 5, -9]], [[float(wall) + 1.5, 2.5, 0.0], [float(wall) + 1.5, float(wide) - 2.5, 0.0]]);
        hall_in = build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0);
        hall_guard = build.waiting();
        hall_in +>:Fires:+> hall_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E4M3_FOES.pick(dice, self.danger, index == 0), 180.0, waits=hall_guard);
        }
        build.foe(float(x0) + 2.5, float(middle) + 4.5, -3, "monster_fish", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m3's stretches: [name, role]."""
glob E4M3_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["crypts", "flow"],
         ["nave", "hub"],
         ["nave", "flow"],
         ["arena", "flow"],
         ["arena", "hub"],
         ["cage", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m3's stretches by its name."""
def make_e4m3(name: str, key: str) -> Prefab {
    if name == "court" {
        return ShrineCourt();
    }
    if name == "crypts" {
        return ZombieCrypts();
    }
    if name == "nave" {
        return ElderNave();
    }
    if name == "arena" {
        return CountedArena();
    }
    if name == "cage" {
        return GuardianCage(key=key if key else "key_silver");
    }
    return ShrineExit(key=key);
}
