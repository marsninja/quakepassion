"""Prefabs drawn from e4m5, Hell's Atrium: an atrium under the sky ringed by
columns round a fountain, doors that fly open on hell knights as the
court is crossed, a stair climbing in two flights about a landing, a hall
ringed by a gallery with teleporters between floor and gallery and its
ways opened by a shot target, a pit far below reached by a lift where
fiends and spawn wait, the key on an island of lava. Raised in e4m5's own
palette.

- `AtriumCourt`: the start. A court under the sky, a fountain (or a dry
  basin round a statue) in its middle, a ring of columns round it, two
  corner blocks whose doors fly open on hell knights as a body reaches the
  fountain; ways on from three sides.
- `AtriumStairs`: a stair climbing in two flights (or a lift), the first
  along one side to a landing, the second back along the other to a floor
  high over the way in; a closet in that floor's foot behind a wall that
  opens when shot; ways on from the landing and the top.
- `AtriumHall`: a hall ringed by a gallery, a broad stair up to it,
  teleporters from the floor up to the gallery and back down; a target on
  the gallery's wall, shot, opens the floor's ways on; ways on from the
  gallery and the floor (a hub).
- `AtriumPit`: a ledge round a deep pit, a lift down into it, the way on
  from its floor; fiends and spawn below wake as the lift comes down; a
  teleporter on the pit's floor back up to the ledge.
- `LavaIsle`: the key room. The key on an island in lava, a drawbridge to
  it let down by shooting a button (or a teleporter out to it and back);
  taking the key opens the closets and teleports a hell knight in.
- `AtriumExit`: the end. A door (a key's, as a gate) into a court, the
  slipgate in the fountain's basin ("Are you sure you want to exit"),
  doors flying open on what waits as the basin is reached."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, lift, key_item }
import from .e3m5 { keep_run, sealed_way, bursting }
import from .e3m6 { rounds }
import from .e3m7 { relayed }

glob E4M5: str = "q1:e4m5";

"""e4m5's foes: the dead and spawn, fiends, hell knights and vores deeper
in."""
def e4m5_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_hell_knight", "monster_demon1"] if heavy else ["monster_zombie", "monster_zombie", "monster_tarbaby"], ["monster_shalrath"] if heavy else ["monster_hell_knight"], danger * 0.5 if heavy else danger));
}

"""A block of the prefab's cells x0..x0+5, y0..y0+5 (eight lifts high)
holding a closet whose door, on the block's face `face` (1 its +y face,
3 its -y face), flies open when `cue` fires; a foe of `kind` inside,
lying in wait on `loose`."""
def burst_block(build: Raising, x0: int, y0: int, face: int, cue: Cue, loose: Cue, kind: str) {
    build.solid(x0, y0, 0, x0 + 5, y0 + 5, 8);
    build.room(x0 + 1, y0 + 1, 0, x0 + 4, y0 + 5 if face == 1 else y0 + 4, 7);
    if face == 3 {
        build.room(x0 + 1, y0, 0, x0 + 4, y0 + 1, 6);
    }
    door_y = y0 + 4 if face == 1 else y0;
    cue +>:Fires:+> bursting(build, float(x0 + 1), float(door_y), 0.0, float(x0 + 4), float(door_y + 1), 6.0);
    build.foe(float(x0) + 2.5, float(y0) + 2.5, 0, kind, 90.0 if face == 1 else 270.0, waits=loose);
}

"""The start: a court, a fountain, a ring of columns round it, doors flying
open on hell knights."""
node AtriumCourt(Prefab) {
    has tall: int = 20,
        fountain: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium court";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(18, 22);
        self.fountain = dice.chance(0.6);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        cx = long // 2;
        cy = wide // 2;
        court = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        if self.fountain {
            build.pool(cx - 3, cy - 3, -3, cx + 3, cy + 3, 0, 2);
            build.solid(cx - 1, cy, -3, cx, cy + 1, 5);
        } else {
            # A dry basin a lift down round a statue on a plinth.
            build.widen(court, cx - 3, cy - 3, -1, cx + 3, cy + 3, 0);
            build.solid(cx - 1, cy - 1, -1, cx + 1, cy + 1, 7);
        }
        for x in range(cx - 7, cx + 8, 2) {
            for y in [cy - 7, cy + 7] {
                if abs(x - cx) > 2 {
                    build.solid(x, y, 0, x + 1, y + 1, 10);
                }
            }
        }
        for y in range(cy - 5, cy + 6, 2) {
            for x in [cx - 7, cx + 7] {
                if abs(y - cy) > 2 {
                    build.solid(x, y, 0, x + 1, y + 1, 10);
                }
            }
        }
        # Corner blocks whose doors fly open on hell knights as a body comes
        # to the fountain.
        near = build.touch(float(cx - 5), float(cy - 5), 0.0, float(cx + 5), float(cy + 5), 6.0);
        burst = relayed(build, near, 0.5);
        loose = build.waiting();
        burst +>:Fires:+> loose;
        burst_block(build, long - 7, 2, 1, burst, loose, "monster_hell_knight");
        burst_block(build, long - 7, wide - 7, 3, burst, loose, e4m5_foe(dice, self.danger, True));
        # The atrium's gates opened by a target shot high on the far wall.
        shot = build.cue([build.button(float(long - 1), float(cy) + 0.5, 9.0, 2, "", True)], "button");
        build.touch(1.0, 1.0, 0.0, 4.0, float(wide - 1), 6.0, True, "Shoot the target over the far gate");
        build.doorway(court, self.enter);
        for port in self.taken {
            sealed_way(build, court, long, wide, port, relayed(build, shot, 0.5), "This door is opened elsewhere.");
        }
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "item_shells");
        # The dead walk the ring of columns; spawn lie in wait by the
        # fountain.
        rounds(build, "monster_zombie", float(cx - 9) + 0.5, float(cy - 9) + 0.5, float(cx + 4) + 0.5, float(cy - 9) + 0.5, 0);
        rounds(build, e4m5_foe(dice, self.danger), float(cx + 4) + 0.5, float(cy + 9) + 0.5, float(cx - 9) + 0.5, float(cy + 9) + 0.5, 0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 4.5, float(cy) + 4.5 - float(index) * 9.0, 0, e4m5_foe(dice, self.danger), 180.0, waits=loose);
        }
        build.supply(float(long) - 2.5, float(cy) + 0.5, 0, "item_health");
    }
}

"""A stair climbing in two flights about a landing to a floor high over the
way in."""
node AtriumStairs(Prefab) {
    has flight: int = 4,
        tall: int = 18,
        climb: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium stairs";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(20, 22);
        self.wide = dice.between(14, 16);
        self.flight = dice.between(4, 5);
        self.tall = 2 * self.flight + 10;
        self.climb = dice.below(2);
        self.low = -1;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle // 2) + 1.0, floor=0);
        self.leaves = [Port(face=1, along=4.0, floor=2 * self.flight), Port(face=0, along=float(self.wide // 2), floor=self.flight)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        top = 2 * self.flight;
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.flight);
        build.level(hall, top);
        lx = 8 + self.flight;
        build.solid(lx, 1, 0, long - 1, wide - 1, self.flight);
        if self.climb == 0 {
            stair(build, lx - self.flight, 1, 0, 0, self.flight, middle - 1);
        } else {
            lift(build, lx - 3, 1, lx, 4, 0, self.flight);
            keep_run(build, hall, lx - 4, 1, lx, 5, 0);
        }
        build.solid(1, middle, 0, lx - self.flight, wide - 1, top);
        stair(build, lx - 1, middle, self.flight, 2, self.flight, wide - 1 - middle);
        keep_run(build, hall, lx, 1, lx + 1, middle, self.flight);
        # A closet in the high floor's foot behind a wall that opens when
        # shot (a secret).
        build.room(3, middle + 1, 0, 6, middle + 4, 4);
        build.secret_door(3.0, float(middle), 0.0, 6.0, float(middle + 1), 4.0, 1);
        build.secret(3.0, float(middle + 1), 0.0, 6.0, float(middle + 4), 3.0);
        build.supply(4.5, float(middle) + 2.5, 0, "item_artifact_super_damage" if dice.chance(0.3) else "item_armor1");
        top_press = build.push(1.0, float(wide) - 2.5, float(top) + 1.2, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == self.flight {
                sealed_way(build, hall, long, wide, port, relayed(build, top_press, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(hall, port);
            }
        }
        # The landing's guard wakes as it is reached; hell knights walk the
        # high floor.
        landed = build.touch(float(lx), 1.0, float(self.flight), float(lx + 3), float(middle), float(self.flight + 6));
        guard = build.waiting();
        landed +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(long) - 3.5, 3.5 + float(index) * 3.0, self.flight, e4m5_foe(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        rounds(build, e4m5_foe(dice, self.danger), 3.5, float(wide) - 3.0, float(lx - self.flight) - 2.5, float(wide) - 3.0, top);
        build.supply(3.5, float(middle) + 2.0, top, "item_health");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A hall ringed by a gallery, a broad stair up to it, teleporters between
floor and gallery, a shot target opening the floor's ways on."""
node AtriumHall(Prefab) {
    has gallery: int = 8,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium hall";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery),
            Port(face=1, along=4.0, floor=0)
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
        hall = build.room(1, 1, 0, long - 1, wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, g);
        under = g - 1;
        build.solid(1, 1, under, long - 1, 4, g);
        build.solid(1, wide - 4, under, long - 1, wide - 1, g);
        build.solid(1, 4, under, 4, wide - 4, g);
        build.solid(long - 4, 4, under, long - 1, wide - 4, g);
        stair(build, long - 4 - g, middle - 3, 0, 0, g, 6);
        keep_run(build, hall, long - 4, middle - 3, long - 3, middle + 3, g);
        keep_run(build, hall, 8, 3, 12, 4, g);
        clear = [[0, middle - 3, 7, middle + 3], [long - 6 - g, middle - 4, long, middle + 4], [2, wide - 6, 9, wide], [6, 5, 12, 10]];
        pillars(build, 6, 6, long - 5, wide - 5, 0, under, 5, clear);
        # Teleporters: from the floor up onto the gallery's far corner, and
        # from the gallery's near corner back down.
        if dice.chance(0.6) {
            build.teleporter(8.5, 7.5, 0, float(long) - 2.5, float(wide) - 2.5, g, 180.0);
            build.teleporter(2.5, float(wide) - 2.5, g, 6.5, float(middle) + 0.5, 0, 0.0);
        } else {
            # A lift up to the gallery's south-west corner instead.
            lift(build, 4, 4, 7, 7, 0, g);
            keep_run(build, hall, 4, 3, 7, 4, g);
            keep_run(build, hall, 3, 4, 8, 8, 0);
        }
        # A target on the gallery's far wall, shot, opens the floor's ways
        # on.
        shot = build.cue([build.button(float(long - 1), float(middle) + 0.5, float(g) + 3.0, 2, "", True)], "button");
        build.doorway(hall, self.enter);
        for port in self.taken {
            if port.floor == 0 {
                sealed_way(build, hall, long, wide, port, relayed(build, shot, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(hall, port);
            }
        }
        # The floor's dead wake as a body comes in; hell knights walk the
        # gallery.
        come = build.touch(1.0, float(middle - 3), 0.0, 5.0, float(middle + 3), 6.0);
        dead = build.waiting();
        come +>:Fires:+> dead;
        for index in range(dice.between(3, 4)) {
            build.foe(float(8 + index * 4) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -4.5), 0, e4m5_foe(dice, self.danger), 0.0, waits=dead);
        }
        rounds(build, "monster_hell_knight", 6.5, 2.5, float(long) - 3.5, 2.5, g);
        rounds(build, e4m5_foe(dice, self.danger), float(long) - 3.5, float(wide) - 2.5, 6.5, float(wide) - 2.5, g);
        build.supply(2.5, 2.5, g, "item_health");
        build.supply(float(long) - 6.5, float(middle) - 5.5, 0, "item_rockets");
    }
}

"""A ledge round a deep pit, a lift down into it, the way on from its floor,
a teleporter back up."""
node AtriumPit(Prefab) {
    has deep: int = 12,
        tall: int = 8,
        stair_down: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium pit";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(24, 28);
        self.wide = dice.between(20, 22);
        self.deep = dice.between(10, 14);
        self.tall = dice.between(8, 10);
        self.stair_down = dice.chance(0.4);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.deep), Port(face=1, along=float(self.long - 6), floor=-self.deep), Port(face=3, along=float(self.long - 6), floor=-self.deep), Port(face=1, along=4.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        low = -self.deep;
        pit = build.room(1, 1, low, long - 1, wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.level(pit, low);
        # The ledge round the west end and along both side walls.
        build.solid(1, 1, low, 7, wide - 1, 0);
        build.solid(7, 1, -1, long - 8, 4, 0);
        build.solid(7, wide - 4, -1, long - 8, wide - 1, 0);
        keep_run(build, pit, 7, 4, long - 8, 5, 0);
        keep_run(build, pit, 7, wide - 5, long - 8, wide - 4, 0);
        # Down into the pit: a lift by the ledge's edge, or a stair winding
        # down the west wall's face.
        if self.stair_down {
            stair(build, 7 + self.deep - 1, middle - 1, low, 2, self.deep, 3);
            mark = [7, middle - 1, 7 + self.deep, middle + 2];
        } else {
            lift(build, 7, middle - 1, 10, middle + 2, low, 0);
            keep_run(build, pit, 6, middle - 1, 7, middle + 2, 0);
            mark = [7, middle - 1, 10, middle + 2];
        }
        # A teleporter on the pit's floor back up to the ledge.
        build.teleporter(float(long) - 4.5, float(middle) + 0.5, low, 3.5, float(middle) + 0.5, 0, 0.0);
        floor_press = build.push(float(long) - 8.5, float(wide - 1), float(low) + 1.2, 3);
        build.doorway(pit, self.enter);
        for port in self.taken {
            if port.floor == low {
                sealed_way(build, pit, long, wide, port, relayed(build, floor_press, 0.5), "This door is opened elsewhere.");
            } else {
                build.doorway(pit, port);
            }
        }
        # A closet in the ledge's foot behind a wall that opens when shot.
        build.room(3, 2, low, 6, 5, low + 4);
        build.secret_door(6.0, 2.0, float(low), 7.0, 5.0, float(low + 4), 2);
        build.secret(3.0, 2.0, float(low), 6.0, 5.0, float(low + 3));
        build.supply(4.5, 3.5, low, "item_artifact_super_damage" if dice.chance(0.4) else "item_armor2");
        # Fiends and spawn below wake as a body comes down.
        down = build.touch(float(mark[0]), float(mark[1]), float(low), float(mark[2]), float(mark[3]), float(low + 6));
        below = build.waiting();
        down +>:Fires:+> below;
        for index in range(dice.between(2, 3)) {
            build.foe(float(16 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), low, "monster_demon1" if index == 0 and self.danger > 0.3 else e4m5_foe(dice, self.danger), 180.0, waits=below);
        }
        rounds(build, "monster_tarbaby", float(long) - 6.5, 6.5, float(long) - 6.5, float(wide) - 6.5, low);
        rounds(build, "monster_zombie", 9.5, 2.5, float(long) - 9.5, 2.5, 0);
        build.supply(float(long) - 2.5, 2.5, low, "item_health");
        build.supply(3.5, 2.5, 0, "item_rockets");
    }
}

"""The key on an island in lava, a drawbridge to it let down by shooting a
button (or a teleporter out and back); taking the key opens the closets."""
node LavaIsle(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        tall: int = 14,
        drawbridge: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava isle (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
        self.drawbridge = dice.chance(0.6);
        self.low = -8;
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
        hall = build.room(1, 1, 0, long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = long - 3;
        build.pool(x0, 3, -3, x1, side - 2, 0, 4, False, False);
        cx = (x0 + x1) // 2;
        cy = side // 2;
        build.solid(cx - 1, cy - 1, -3, cx + 2, cy + 2, 0);
        if self.drawbridge {
            shot = build.cue([build.button(1.0, float(cy - 4) + 0.5, 2.0, 0, "", True)], "button");
            shot +>:Fires:+> build.drawn(float(x0), float(cy - 1), float(cx - 1), float(cy + 2), 0, 4);
            keep_run(build, hall, x0 - 1, cy - 1, x0, cy + 2, 0);
            build.touch(1.0, 1.0, 0.0, 4.0, float(side), 6.0, True, "Shoot the button to let the bridge down");
        } else {
            build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) + 0.5, float(cy) - 0.5, 0, 0.0);
            build.teleporter(float(cx) + 0.5, float(cy) + 1.0, 0, 3.0, 3.0, 0, 180.0);
        }
        key_ambush(build, self.key, float(cx) + 0.5, float(cy) + 0.5, 0, side, 0, [2, long - 6], [e4m5_foe(dice, self.danger, True), e4m5_foe(dice, self.danger)]);
        rounds(build, e4m5_foe(dice, self.danger), float(long) - 2.5, 2.0, float(long) - 2.5, float(side) - 2.0, 0);
        build.foe(3.0, 2.5, 0, "monster_zombie", 0.0);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
    }
}

"""The end: a door into a court, the slipgate in the fountain's basin, doors
flying open as the basin is reached."""
node AtriumExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Atrium exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M5;
        self.district = level_district(E4M5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(21, 23);
        self.tall = dice.between(15, 17);
        self.low = -3;
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
        wall = 8;
        hall = build.room(1, 1, 0, wall, side, 10, variant=dice.below(3));
        court = build.room(wall + 1, 1, 0, long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(court, -2);
        build.doorway(hall, self.enter);
        build.widen(court, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        bx = long - 9;
        build.widen(court, bx, middle - 4, -2, long - 3, middle + 4, 0);
        stair(build, bx + 1, middle - 4, -2, 2, 2, 8);
        build.way_out(float(long) - 5.5, float(middle), -2);
        build.touch(float(bx + 2), float(middle - 3), -2.0, float(long - 3), float(middle + 3), 4.0, False, "Are you sure you want to exit");
        # Reaching the basin's rim, the doors in the north wall fly open.
        rim = build.touch(float(bx - 3), 1.0, 0.0, float(bx), float(side), 6.0);
        burst = relayed(build, rim, 0.5);
        loose = build.waiting();
        burst +>:Fires:+> loose;
        for at in [wall + 2, bx - 3] {
            build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(court, at, side, 0, at + 3, side + 1, 6);
            burst +>:Fires:+> bursting(build, float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, e4m5_foe(dice, self.danger, at == wall + 2), 270.0, waits=loose);
        }
        hall_in = build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0);
        hall_guard = build.waiting();
        hall_in +>:Fires:+> hall_guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m5_foe(dice, self.danger, index == 0), 180.0, waits=hall_guard);
        }
        if dice.chance(0.7) {
            build.room(2, side + 1, 0, 5, side + 4, 4);
            build.secret_door(2.0, float(side), 0.0, 5.0, float(side + 1), 4.0, 1);
            build.secret(2.0, float(side + 1), 0.0, 5.0, float(side + 4), 3.0);
            build.supply(3.5, float(side) + 2.5, 0, "item_artifact_super_damage");
        }
        rounds(build, "monster_zombie", float(wall) + 2.5, 2.5, float(bx) - 2.5, 2.5, 0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m5's stretches: [name, role]."""
glob E4M5_STRETCHES: list[list[str]] = [
         ["court", "start"],
         ["stairs", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["pit", "flow"],
         ["pit", "hub"],
         ["isle", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m5's stretches by its name."""
def make_e4m5(name: str, key: str) -> Prefab {
    if name == "court" {
        return AtriumCourt();
    }
    if name == "stairs" {
        return AtriumStairs();
    }
    if name == "hall" {
        return AtriumHall();
    }
    if name == "pit" {
        return AtriumPit();
    }
    if name == "isle" {
        return LavaIsle(key=key if key else "key_gold");
    }
    return AtriumExit(key=key);
}
