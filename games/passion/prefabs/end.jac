"""Prefabs drawn from `end`, Shub-Niggurath's Pit: the last pit, a flooded
cavern the run begins over, lakes of lava crossed only by teleporter, an
island in a moat of slime with teleporters out to balconies, a shambler
whose death lifts a great door, a shaft climbed by a stair winding twice
round its walls through spike traps, the way out at the pit's bottom.
`end` holds no keys; its key room and gate are drawn from its islands.
Shub-Niggurath herself is left out (she dies only by the original's
telefrag). Raised in end's own palette.

- `PitApproach`: the start. A deep lake across a cavern, fish in it,
  crossed by a causeway or by a teleporter; scrags rise from it as the
  player crosses; a drowned alcove under the far shore (a secret).
- `TeleportIslands`: a lake of lava, one island or two, teleporters from
  the near shore from island to island to the far shore and back, and one
  up to a ledge high over the far shore (a secret, a drop back down); a
  fiend brought in behind the player as the first island is reached.
- `ShubHall`: an island in a moat of slime (or lava), teleporters onto it
  or a bridge, teleporters from it to balconies on two walls; the vores
  on the balconies wake as the player reaches the island; ways on from
  the floor and the balconies (a hub).
- `ShamblerGate`: a hall, galleries along its walls, a moat of lava across
  it bridged to a dais before a great door; the shambler (a lesser
  guardian early in a run) on the dais, and only its death lifts the door
  (end's shambler opening its door).
- `SpikeClimb`: a shaft, slime at its foot, a stair winding up its walls
  round and round over itself to a way on high up; spikes shoot across
  the stair at each turn of the climb (end's spike traps up its stair).
- `PitKey`: the key on an island in lava, a teleporter out and one back
  (or two islands); taking the key opens the closets and brings a vore in.
- `ShubPit`: the end. A door (a key's, as a gate), a stair down round a
  pit to its floor and the slipgate there, spikes along the stair, the
  pit's guards waking as the player comes down."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush, spiral, ring_path, ring_landing }
import from .e4m6 { flood, onward_ports, port_door, pool_steps }
import from .e4m7 { counted_foe }

glob END: str = "q1:end";

"""end's foes: vores and shamblers, scrags and fiends."""
def end_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_demon1", "monster_demon1", "monster_shalrath"] if heavy else ["monster_wizard", "monster_wizard", "monster_demon1"], ["monster_shambler", "monster_shalrath"] if heavy else ["monster_shalrath"], danger * 0.3));
}

"""A hurting volume of the prefab's cells (Quake's trigger_hurt), `damage`
a touch."""
def hurt(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, damage: int) {
    build.put_box({"classname": "trigger_hurt", "dmg": str(damage)}, x0, y0, z0, x1, y1, z1, "trigger");
}

"""A spike shooter in the outer wall beside a cell of a stair winding
round a box (`cell` as `ring_path` gives it, the face of the wall it
stands against last), `z` lifts up, shooting across the stair; fired by
`cue`."""
def wall_spikes(build: Raising, cell: list[int], z: float, cue: Cue) {
    face = cell[4];
    cx = float(cell[0] + cell[2]) * 0.5;
    cy = float(cell[1] + cell[3]) * 0.5;
    if face == 3 {
        cue +>:Fires:+> build.spikes(cx, float(cell[1]) + 0.1, z, 1);
    } elif face == 1 {
        cue +>:Fires:+> build.spikes(cx, float(cell[3]) - 0.1, z, 3);
    } elif face == 0 {
        cue +>:Fires:+> build.spikes(float(cell[2]) - 0.1, cy, z, 2);
    } else {
        cue +>:Fires:+> build.spikes(float(cell[0]) + 0.1, cy, z, 0);
    }
}

"""The start: a deep lake across a cavern, a causeway or a teleporter
over it."""
node PitApproach(Prefab) {
    has deep: int = 8,
        causeway: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pit approach";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(14, 16);
        self.deep = dice.between(8, 9);
        self.causeway = dice.chance(0.6);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        x0 = 7;
        x1 = self.long - 7;
        build.pool(x0, 1, -self.deep, x1, self.wide - 1, 0, 2, False, False);
        pool_steps(build, x0, 1, self.deep, 2);
        pool_steps(build, x0, self.wide - 3, self.deep, 2);
        if self.causeway {
            # A causeway three cells wide over the water, on piers.
            build.solid(x0, middle - 1, -1, x1, middle + 2, 0);
            for x in range(x0 + 3, x1 - 1, 5) {
                build.solid(x, middle - 1, -self.deep, x + 1, middle + 2, -1);
            }
            for y in range(middle - 1, middle + 2) {
                build.keep(hall, x0 - 1, y, 0);
                build.keep(hall, x1, y, 0);
            }
            crossing = build.touch(float((x0 + x1) // 2 - 1), float(middle - 1), 0.0, float((x0 + x1) // 2 + 1), float(middle + 2), 6.0);
        } else {
            build.teleporter(4.0, float(middle) + 0.5, 0, float(x1) + 3.0, float(middle) + 0.5, 0, 0.0);
            build.teleporter(float(x1) + 3.0, 3.0, 0, 3.0, 3.0, 0, 180.0);
            crossing = build.touch(float(x1), float(middle - 3), 0.0, float(x1 + 6), float(middle + 3), 6.0);
        }
        # The drowned alcove under the far shore.
        ay = 2 if dice.chance(0.5) else self.wide - 5;
        build.room(x1, ay, -self.deep, x1 + 3, ay + 3, 4 - self.deep);
        flood(build, x1, ay, -self.deep, x1 + 3, ay + 3, 4 - self.deep);
        build.secret(float(x1), float(ay), float(-self.deep), float(x1 + 3), float(ay + 3), float(4 - self.deep));
        build.supply(float(x1) + 2.0, float(ay) + 1.5, -self.deep, "item_artifact_super_damage");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, 2.5, 0, "item_shells");
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "Shub-Niggurath's Pit");
        # Scrags rise from over the lake as the player crosses.
        risen = build.waiting();
        rising = build.delay(0.8);
        crossing +>:Fires:+> rising;
        rising +>:Fires:+> risen;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 4 + index * 5) + 0.5, float(middle) + (4.5 if index % 2 == 0 else -3.5), 4, "monster_wizard", 180.0, waits=risen);
        }
        for index in range(2) {
            build.foe(float(x0 + 3 + index * 6) + 0.5, float(middle) + 3.5, 2 - self.deep, "monster_fish", 0.0);
        }
        build.foe(float(x1) + 3.5, 2.5, 0, "monster_demon1" if self.danger > 0.2 else "monster_wizard", 90.0, patrol=[[float(x1) + 3.5, 2.5], [float(x1) + 3.5, float(self.wide) - 2.5]]);
        build.foe(float(x1) + 2.5, float(middle) + 3.5, 0, end_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""A lake of lava, one island or two, teleporters from shore to island to
shore and back, and one up to a ledge over the far shore."""
node TeleportIslands(Prefab) {
    has two: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Teleport islands";
        self.source = END;
        self.district = level_district(END);
        self.two = dice.chance(0.5);
        self.long = dice.between(30, 32) if self.two else dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(14, 16);
        self.low = -4;
        self.high = self.tall + 8;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 7);
        x0 = 7;
        x1 = self.long - 6;
        build.pool(x0, 1, -3, x1, self.wide - 1, 0, 4, False, False);
        hurt(build, float(x0), 1.0, -3.0, float(x1), float(self.wide - 1), -1.0, 20);
        # The islands, a teleporter on each to the next.
        islands: list[list[int]] = [];
        if self.two {
            islands = [[x0 + (x1 - x0) // 3, middle - 4], [x0 + 2 * (x1 - x0) // 3, middle + 3]];
        } else {
            islands = [[(x0 + x1) // 2, middle]];
        }
        for at in islands {
            build.solid(at[0] - 3, at[1] - 2, -3, at[0] + 3, at[1] + 2, 1);
        }
        first = islands[0];
        build.teleporter(4.0, float(middle) + 0.5, 0, float(first[0]) - 1.5, float(first[1]) - 0.5, 1, 0.0);
        if self.two {
            second = islands[1];
            build.teleporter(float(first[0]) + 1.5, float(first[1]) + 0.5, 1, float(second[0]) - 1.5, float(second[1]) - 0.5, 1, 0.0);
            last = second;
        } else {
            last = first;
        }
        build.teleporter(float(last[0]) + 1.5, float(last[1]) + 0.5, 1, float(x1) + 3.0, float(middle) + 0.5, 0, 0.0);
        build.teleporter(float(x1) + 2.5, 3.0, 0, 3.0, 3.0, 0, 180.0);
        # The ledge high over the far shore, a teleporter up to it from the
        # last island's far corner; a drop back down.
        ly0 = middle + 3;
        ly1 = self.wide - 3;
        build.solid(self.long - 4, ly0, 6, self.long - 1, ly1, 7);
        for y in range(ly0, ly1) {
            build.keep(hall, self.long - 4, y, 7);
        }
        for x in range(self.long - 4, self.long - 1) {
            build.keep(hall, x, ly0, 7);
            build.keep(hall, x, ly1 - 1, 7);
        }
        build.teleporter(float(last[0]) - 1.5, float(last[1]) + 1.0, 1, float(self.long) - 2.5, float(ly0) + 1.5, 7, 180.0);
        build.secret(float(self.long - 4), float(ly0), 7.0, float(self.long - 1), float(ly1), 10.0);
        build.supply(float(self.long) - 2.5, float(ly1) - 1.5, 7, "item_artifact_super_damage" if dice.chance(0.4) else "item_armor2");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Reaching the first island brings a fiend in behind the player and
        # wakes the scrags over the lava.
        landed = build.touch(float(first[0] - 3), float(first[1] - 2), 1.0, float(first[0] + 3), float(first[1] + 2), 7.0);
        landed +>:Fires:+> build.summon(1, 1, self.tall + 1, "monster_demon1", 3.5, float(middle) + 3.5, 0, 0.0);
        scrags = build.waiting();
        landed +>:Fires:+> scrags;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 3 + index * 4) + 0.5, 2.5 + float(index % 2) * float(self.wide - 5), 5, "monster_wizard", 90.0, waits=scrags);
        }
        build.foe(float(last[0]) + 1.5, float(last[1]) - 1.5, 1, end_foe(dice, self.danger), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 3.0, float(self.wide) - 8.0 - float(index) * 2.5, 0, end_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_cells");
    }
}

"""An island in a moat, teleporters (or a bridge) onto it and teleporters
from it to balconies on two walls."""
node ShubHall(Prefab) {
    has balcony: int = 6,
        bridged: bool = False,
        lava: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shub hall";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.balcony = dice.between(7, 8);
        self.bridged = dice.chance(0.4);
        self.lava = dice.chance(0.35);
        self.tall = self.balcony + 11;
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.balcony),
            Port(face=1, along=4.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.balcony);
        build.pool(cx - 7, cy - 6, -3, cx + 7, cy + 6, 0, 4 if self.lava else 3, False, True, True);
        build.solid(cx - 4, cy - 3, -3, cx + 4, cy + 3, 1);
        # The balconies: slabs along the side walls over the floor.
        under = self.balcony - 1;
        build.solid(cx - 6, self.wide - 4, under, cx + 6, self.wide - 1, self.balcony);
        build.solid(cx - 6, 1, under, cx + 6, 4, self.balcony);
        if self.bridged {
            build.solid(cx - 7, cy - 1, -1, cx - 4, cy + 2, 1);
            for y in range(cy - 1, cy + 2) {
                build.keep(hall, cx - 8, y, 0);
            }
        } else {
            build.teleporter(4.0, float(cy) + 0.5, 0, float(cx) - 2.5, float(cy) + 0.5, 1, 0.0);
        }
        build.teleporter(float(cx) + 1.5, float(cy) + 1.5, 1, float(cx) + 0.5, float(self.wide) - 2.5, self.balcony, 90.0);
        build.teleporter(float(cx) + 1.5, float(cy) - 1.5, 1, float(cx) + 0.5, 2.5, self.balcony, 270.0);
        # And back down from each balcony's end.
        build.teleporter(float(cx) - 4.5, float(self.wide) - 2.5, self.balcony, 3.0, float(self.wide) - 3.0, 0, 0.0);
        build.teleporter(float(cx) - 4.5, 2.5, self.balcony, 3.0, 3.0, 0, 0.0);
        for x in range(cx - 5, cx + 5) {
            build.keep(hall, x, self.wide - 4, self.balcony);
            build.keep(hall, x, 3, self.balcony);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The balconies' vores wake as the player reaches the island.
        island = build.touch(float(cx - 4), float(cy - 3), 1.0, float(cx + 4), float(cy + 3), 7.0);
        above = build.waiting();
        island +>:Fires:+> above;
        build.foe(float(cx) + 4.5, float(self.wide) - 2.5, self.balcony, "monster_shalrath" if self.danger > 0.3 else "monster_wizard", 270.0, waits=above);
        build.foe(float(cx) + 4.5, 2.5, self.balcony, end_foe(dice, self.danger), 90.0, waits=above);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 9) + 0.5, 3.5 + float(index) * 5.0, 0, end_foe(dice, self.danger), 180.0);
        }
        build.foe(float(cx) - 1.5, float(cy) - 1.5, 1, end_foe(dice, self.danger, True), 180.0);
        build.foe(3.5, 6.5, 0, "monster_demon1" if self.danger > 0.2 else "monster_wizard", 90.0, patrol=[[3.5, 6.5], [3.5, float(self.wide) - 6.5]]);
        build.supply(float(cx) - 2.5, 2.5, self.balcony, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""A hall, galleries along its walls, a moat of lava bridged to a dais
before a great door; the guardian on the dais, and only its death lifts
the door."""
node ShamblerGate(Prefab) {
    has gallery: int = 8,
        both: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shambler gate";
        self.source = END;
        self.district = level_district(END);
        self.gallery = dice.between(8, 9);
        self.both = dice.chance(0.6);
        self.long = dice.between(34, 36);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(18, 22);
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gx = self.long - 10;
        hall = build.room(1, 1, 0, gx, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(gx + 1, 1, 0, self.long - 1, self.wide - 1, 14, variant=dice.below(3));
        build.level(hall, self.gallery);
        # The great door: eight cells wide, twelve lifts high, lifted when
        # the guardian dies.
        build.widen(beyond, gx, middle - 4, 0, gx + 1, middle + 4, 12);
        door = build.opened(float(gx), float(middle - 4), 0.0, float(gx + 1), float(middle + 4), 12.0);
        # The dais before it, two lifts up, the moat of lava before the dais
        # and the bridge over it.
        dx = gx - 6;
        build.solid(dx, 1, 0, gx, self.wide - 1, 1);
        build.solid(dx + 1, 1, 1, gx - 1, self.wide - 1, 2);
        mx = dx - 6;
        build.pool(mx, 1, -6, dx - 1, self.wide - 1, 0, 4, False, False);
        pool_steps(build, mx, 1, 5, 2);
        pool_steps(build, mx, self.wide - 3, 5, 2);
        hurt(build, float(mx), 1.0, -6.0, float(dx - 1), float(self.wide - 1), -1.0, 25);
        build.solid(mx, middle - 2, -1, dx - 1, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(hall, mx - 1, y, 0);
            build.keep(hall, dx - 1, y, 0);
        }
        # The galleries along the side walls over the hall's floor, up a
        # stair at the near end.
        sides = [0, 1] if self.both else [1];
        g = 4;
        for side in sides {
            y0 = 1 if side == 0 else self.wide - 1 - g;
            build.solid(2 + self.gallery, y0, self.gallery - 1, gx - 1, y0 + g, self.gallery);
            stair(build, 2, y0, 0, 0, self.gallery, g);
            for y in range(y0, y0 + g) {
                build.keep(hall, 2 + self.gallery, y, self.gallery);
                build.keep(hall, 1 + self.gallery, y, self.gallery);
            }
            build.foe(float(dx) + 2.5, float(y0) + 2.0, self.gallery, "monster_wizard", 180.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(beyond, port);
        }
        # The guardian; its death lifts the door and wakes what waits beyond.
        slain = build.cue([], "slain");
        grinding = build.delay(1.0);
        slain +>:Fires:+> grinding;
        grinding +>:Fires:+> door;
        beyond_wake = build.waiting();
        slain +>:Fires:+> beyond_wake;
        guardian = "monster_shambler" if self.danger > 0.4 else ("monster_ogre" if self.danger < 0.15 else "monster_demon1");
        counted_foe(build, float(gx) - 3.0, float(middle) + 0.5, 2, guardian, 180.0, slain);
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "The great door opens only when its guardian is dead");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 4.0, 0, end_foe(dice, self.danger), 180.0, waits=beyond_wake);
        }
        build.foe(4.5, float(middle) + 0.5, 0, "monster_demon1" if self.danger > 0.2 else "monster_wizard", 0.0, patrol=[[4.5, float(middle) + 0.5], [float(mx) - 2.5, float(middle) + 0.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(dx) + 2.5, 2.5, 2, "item_rockets");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""A shaft, slime at its foot, a stair winding up round its walls over
itself to a way on high up, spikes shooting across it as it climbs."""
node SpikeClimb(Prefab) {
    has steps: int = 30,
        tall: int = 38;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike climb";
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(12, 14);
        self.wide = dice.between(12, 14);
        lap = len(ring_path(1, 1, self.long - 1, self.wide - 1, 3));
        fits: list[int] = [];
        for steps in range(lap + 2, lap + 14) {
            landing = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, steps, 4);
            if landing and landing[0] != 2.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 8;
        self.low = -3;
        self.high = self.tall + 1;
        top = ring_landing(1, 1, self.long - 1, self.wide - 1, 3, self.steps, 4);
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=int(top[0]), along=top[1], floor=self.steps), Port(face=0, along=float(self.wide // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.steps // 2);
        build.level(shaft, self.steps);
        build.pool(4, 4, -2, self.long - 4, self.wide - 4, 0, 3, False, True, True);
        landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 4);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        # Spikes across the stair at each quarter of the climb, while
        # anyone is on it.
        for quarter in range(1, 5) {
            at = quarter * self.steps // 5;
            cell = path[at % len(path)];
            z = at + 1;
            trap = build.touch(float(cell[0]), float(cell[1]), float(z), float(cell[2]), float(cell[3]), float(z + 5), False);
            trap.items[0]["wait"] = "1";
            wall_spikes(build, cell, float(z) + 1.5, trap);
        }
        # What waits at the top wakes as the player passes the climb's
        # middle; scrags fly the shaft.
        half = path[(self.steps // 2) % len(path)];
        roused = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        above = build.waiting();
        roused +>:Fires:+> above;
        top = landing[2];
        build.foe(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.steps, end_foe(dice, self.danger, True), 180.0, waits=above);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 6 + index * 8, "monster_wizard", float(index * 120));
        }
        build.supply(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5 + 0.5, self.steps, "item_health");
        mid = path[(self.steps // 3) % len(path)];
        build.supply(float(mid[0] + mid[2]) * 0.5, float(mid[1] + mid[3]) * 0.5, self.steps // 3 + 1, "item_rockets");
    }
}

"""The key on an island in lava (or the second of two), a teleporter out
and one back; taking it opens the closets and brings a vore in."""
node PitKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        two: bool = False,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pit key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = END;
        self.district = level_district(END);
        self.two = dice.chance(0.45);
        self.long = dice.between(26, 28) if self.two else dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.tall = dice.between(13, 15);
        self.low = -4;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        x0 = 6;
        x1 = self.long - 2;
        build.pool(x0, 3, -3, x1, side - 2, 0, 4, False, False);
        hurt(build, float(x0), 3.0, -3.0, float(x1), float(side - 2), -1.0, 20);
        cx = (x0 + x1) // 2 + 1 if not self.two else x1 - 4;
        build.solid(cx - 2, cy - 2, -3, cx + 2, cy + 2, 1);
        if self.two {
            ax = x0 + 5;
            build.solid(ax - 2, cy - 2, -3, ax + 2, cy + 2, 1);
            build.teleporter(3.5, float(cy) + 0.5, 0, float(ax) - 1.0, float(cy), 1, 0.0);
            build.teleporter(float(ax) + 1.0, float(cy) + 1.0, 1, float(cx) - 1.0, float(cy), 1, 0.0);
            build.foe(float(ax) + 0.5, float(cy) - 1.0, 1, end_foe(dice, self.danger), 0.0);
        } else {
            build.teleporter(3.5, float(cy) + 0.5, 0, float(cx) - 1.0, float(cy), 1, 0.0);
        }
        build.teleporter(float(cx) + 1.0, float(cy) + 1.0, 1, 3.0, 3.0, 0, 180.0);
        key_ambush(build, self.key, float(cx) + 1.0, float(cy) - 1.0, 1, side, 0, [2], [end_foe(dice, self.danger, True)]);
        # The vore brought in at the shore as the key is taken.
        taken = build.touch(float(cx), float(cy - 2), 1.0, float(cx + 2), float(cy), 6.0);
        taken +>:Fires:+> build.summon(1, 1, self.tall + 1, "monster_shalrath" if self.danger > 0.3 else "monster_wizard", 4.0, float(side) - 4.0, 0, 0.0);
        build.foe(3.0, float(side) - 3.0, 0, end_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a stair down round a pit to its floor, the slipgate
there."""
node ShubPit(Prefab) {
    has key: str = "",
        deep: int = 12,
        tall: int = 6;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Shub pit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = END;
        self.district = level_district(END);
        self.long = dice.between(22, 24);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(10, 14);
        self.tall = 8;
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
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        pit = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.level(pit, low);
        build.doorway(hall, self.enter);
        build.widen(pit, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        # A landing inside the door, the stair down round the pit's walls
        # from the landing's north end, east and on round to the floor.
        build.solid(wall + 1, 1, low, wall + 4, self.wide - 1, 0);
        path = ring_path(wall + 1, 1, self.long - 1, self.wide - 1, 2);
        top = 0;
        for (index, cell) in enumerate(path) {
            if cell[4] == 1 and cell[0] == wall + 4 {
                top = index;
            }
        }
        start = top - self.deep + 1 + len(path);
        spiral(build, wall + 1, 1, self.long - 1, self.wide - 1, low, self.deep, 2, 0, start);
        build.keep(pit, wall + 3, self.wide - 2, 0);
        build.keep(pit, wall + 3, self.wide - 3, 0);
        build.way_out(float(self.long + wall) * 0.5 + 1.0, float(middle), low);
        # Spikes along the stair down, and the pit's guards waking as the
        # player comes halfway down.
        half = path[(start + self.deep // 2) % len(path)];
        z = low + self.deep // 2 + 1;
        halfway = build.touch(float(half[0]), float(half[1]), float(z), float(half[2]), float(half[3]), float(z + 6));
        wall_spikes(build, half, float(z) + 1.5, halfway);
        guards = build.waiting();
        later = build.delay(2.0);
        halfway +>:Fires:+> later;
        later +>:Fires:+> guards;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.5, float(middle) + 2.5 - float(index) * 5.0, low, end_foe(dice, self.danger, True), 180.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, end_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long + wall) * 0.5, float(middle) + 0.5, low + 4, "monster_wizard", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""end's stretches: [name, role]."""
glob END_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["islands", "flow"],
         ["hall", "hub"],
         ["hall", "flow"],
         ["shambler", "flow"],
         ["climb", "flow"],
         ["key", "keyroom"],
         ["pit", "end"],
         ["pit", "gate"]
     ];

"""One of end's stretches by its name."""
def make_end(name: str, key: str) -> Prefab {
    if name == "approach" {
        return PitApproach();
    }
    if name == "islands" {
        return TeleportIslands();
    }
    if name == "hall" {
        return ShubHall();
    }
    if name == "shambler" {
        return ShamblerGate();
    }
    if name == "climb" {
        return SpikeClimb();
    }
    if name == "key" {
        return PitKey(key=key if key else "key_gold");
    }
    return ShubPit(key=key);
}
